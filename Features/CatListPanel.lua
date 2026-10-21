local addonName, ns = ...
local Options = ns.Options
local factories = Options.factories
local Theme = ns.Theme

-- The panel that unfolds under a category row: the rule band, the placement controls and the pin rack, and
-- the layout that places them. It is rebuilt for the row it belongs to and pooled on the list, so the same
-- frames are rebound instead of made again.
function factories.catlistpanel(env)
  local Cats, row = env.Cats, env.row
  local relayout, debounce, T = env.relayout, env.debounce, env.T
  local BASE_FONT, CHIP, CHIP_GAP = env.baseFont, env.chip, env.chipGap
  local CAT_ROW_H, PANEL_PAD, RAIL_X = env.rowH, env.panelPad, env.railX
  local COND_H, ADD_COND_W = env.condH, env.addCondW
  local makeBox = env.makeBox
  local makeChip, makePlusSlot, makePinEntry = env.makeChip, env.makePlusSlot, env.makePinEntry
  local makeCond, makeDropBtn, makeSortBtn = env.makeCond, env.makeDropBtn, env.makeSortBtn
  local makePrioPick, makeShowBoxes = env.makePrioPick, env.makeShowBoxes
  local condItem, itemName, pinFromCursor = env.condItem, env.itemName, env.pinFromCursor
  -- The word picker and the word sheet are built further down the list, after this factory has run, so they
  -- arrive on the env table later and these two read it when the click comes rather than at build time.
  local openCatPicker = function(...) return env.openCatPicker(...) end
  local showCatHelp = function(...) return env.showCatHelp(...) end
  -- The panel under a category row: the rule as chips (join switch + a "+" per extra condition, with the
  -- whole band switchable to plain text), then how the section is ordered, where it shows and how it claims
  -- a contested item, then the pin rack. Drawn as the row's own inside — a hairline closes the row off and
  -- a short accent spine under the grip ties them.
  local function buildPanel(i)
    local p = row.build[i]
    if p then return p end
    p = CreateFrame("Frame", nil, row)
    p.chips, p.ghosts, p.conds = {}, {}, {}

    -- Accent rail down the panel's left, with the content indented past it: the rail is the one signal
    -- that everything here belongs to the row above, and the indent puts the whole editor right of the
    -- name column so a stack of open panels never intrudes on the list of names down the left edge. RAIL_X
    -- sits right of where a row's name begins; the top hairline runs from the rail to the right edge.
    local top = Theme:Rect(p, "stroke", "BACKGROUND")
    ns.SnapPoint(top, "TOPLEFT", p, "TOPLEFT", RAIL_X, 0)
    top:SetPoint("TOPRIGHT", p, "TOPRIGHT")
    top:SetHeight(ns.PX(p))
    p.top = top
    local spine = Theme:Rect(p, "accent", "BACKGROUND")
    spine:SetPoint("TOPLEFT", RAIL_X, 0)
    spine:SetPoint("BOTTOMLEFT", RAIL_X, 0)
    spine:SetWidth(ns.PX(p, 2))
    spine:SetAlpha(0.45)
    p.spine = spine

    -- LocalText, not a bare SetText: a pooled label set once would freeze in its build-time language.
    local hcap = Theme:Label(p, BASE_FONT - 2, "faint")
    ns.LocalText(hcap, "Pinned")
    p.hcap = hcap
    local hcount = Theme:Label(p, BASE_FONT - 2, "dim")
    p.hcount = hcount

    -- One hairline seams the rule band off from the placement/pins below it.
    p.seam1 = Theme:Rect(p, "strokeSoft", "ARTWORK"); ns.PixelLine(p.seam1, 1)

    p.sortBtn = makeSortBtn(p)
    p.showBoxes = makeShowBoxes(p)
    p.prioPick = makePrioPick(p)

    -- Rule editor. The chips and the join dropdown are read into { mode, conds } and handed to
    -- RuleFromParts, which writes the canonical English string SetSearchById stores. The join is a labelled
    -- dropdown ("Match: All"), same shape as Sort/Priority/Show-in, so it reads as clickable at 0-1
    -- conditions too where a bare pair of words did not; p.wpeMode/p.wpeSetMode are set per layout.
    local matchSpec = {
      keys = function() return { "all", "any" } end,
      get = function() return p.wpeMode or "all" end,
      set = function(v) if p.wpeSetMode then p.wpeSetMode(v) end end,
      label = function(k) return k == "any" and "Any" or "All" end,
      desc = "All: every condition must match. Any: one condition is enough.",
    }
    p.matchBtn = makeDropBtn(p, "Match", matchSpec, function()
      return T((p.wpeMode == "any") and "Any" or "All")
    end)
    -- Live count of what the rule catches right now, so a flip all<->any or a Not shows its effect at once.
    p.matchCount = Theme:Label(p, BASE_FONT - 2, "faint")

    -- Adding a condition is the same "+" plate the pin rack leads with: one control for "add one of these",
    -- and no sentence standing on the row for the player to guess at.
    -- A 3px arm sits centred only on an odd-sized plate: FitMarkPlus ties arm thickness to the plate's
    -- parity (snapParity), so an even plate (26) only ever yields an even arm, and forcing 3 on an even
    -- plate splits it, one sleeve a pixel longer than the other. So this one
    -- plate is drawn odd (25) and the arm asked for 3: the same reason the favorites cell comes out even,
    -- read the other way. ADD_COND_W stays the wrap reserve; only the drawn plate loses 1px.
    local addCond = makePlusSlot(p, ADD_COND_W - 1, COND_H - 1)
    addCond.wpeMarkW = 3
    ns.FitMarkPlus(addCond)
    addCond:SetScript("OnClick", function()
      openCatPicker(addCond, function(token) if p.wpeAddCond then p.wpeAddCond(token) end end)
    end)
    ns.AddTip(addCond, "Add condition", "top")
    p.addCond = addCond

    -- Raw escape: a rule too structured for chips (brackets, mixed & and |, ! over a group) shows here
    -- instead, and the "edit as text" toggle opens it for a simple rule too. Commits like the old field.
    local rawBox = makeBox(p, "Rule", 400)
    rawBox:SetScript("OnEditFocusLost", function(s)
      ns.SetEdge(s, Theme:C("stroke")); s.ph:SetShown(s:GetText() == "")
      if p.wpeId then Cats:SetSearchById(p.wpeId, s:GetText()); relayout(); Options:ReflowPages() end
    end)
    rawBox:SetScript("OnTextChanged", function(s)
      s.ph:SetShown(s:GetText() == "")
      if not s:HasFocus() then return end
      -- Only commit the rule and redraw the bags while typing; NOT ReflowPages, which rebuilds this very
      -- panel and drops the editbox focus mid-word (a space or a pause fired it). The panel is reflowed
      -- once on focus-lost.
      debounce(function()
        if s:HasFocus() and p.wpeId then Cats:SetSearchById(p.wpeId, s:GetText()); relayout() end
      end)
    end)
    p.rawBox = rawBox
    -- Chips or the rule as plain text: an icon toggle, filled while the band is in its text form, so the
    -- panel face carries no sentence to click on and the state is visible at a glance. What it does is in
    -- the tooltip, which follows the state.
    local rawToggle = CreateFrame("Button", nil, p, "BackdropTemplate")
    ns.SnapBox(rawToggle, 22, 22, true)
    ns.PixelBackdrop(rawToggle)
    -- The face of the toggle is drawn, not typed: a letter says nothing at all in the languages whose
    -- alphabet is another one, and this panel is read in Chinese and Korean too, where that shape is a
    -- shape and no word. The caret is the one mark that
    -- means "text" without being a word in any language: it is the pointer every system shows over a
    -- piece of editable text, and drawn it follows the theme, the density and the ink of its state the
    -- way the X and the plus already do.
    ns.MarkCaret(rawToggle, true)
    local function paintRaw(s)
      ns.SetBg(s, Theme:C(s.wpeRaw and "panelHi" or "bg"))
      local er, eg, eb = Theme:C(s.wpeRaw and "accent" or (s.wpeHot and "accent" or "strokeSoft"))
      ns.SetEdge(s, er, eg, eb, 1)
      -- The text-mode state shows in the plate and the accent edge, not by filling the caret: the mark
      -- keeps the window ink (dim at rest, text live/under the pointer) so the glyph is never painted over.
      ns.TintMarkX(s, (s.wpeRaw or s.wpeHot) and "text" or "dim")
    end
    rawToggle.Repaint = paintRaw
    paintRaw(rawToggle)
    Theme:Track(rawToggle, paintRaw)
    -- ReflowPages, not relayout: the panel is drawn in the row rebuild, so a bag redraw would leave the
    -- flag flipped but the panel showing its old face.
    rawToggle:SetScript("OnClick", function() p.wpeRaw = not p.wpeRaw; Options:ReflowPages() end)
    rawToggle:SetScript("OnEnter", function(s) s.wpeHot = true; paintRaw(s) end)
    rawToggle:SetScript("OnLeave", function(s) s.wpeHot = nil; paintRaw(s) end)
    ns.AddTip(rawToggle, function() return T(p.wpeRaw and "Use chips" or "Edit as text") end, "top")
    p.rawToggle = rawToggle

    -- "?": every word the search takes, as a list to read. Shown in the text form only (the chip form is
    -- built from the picker, which already names every word), so it starts hidden and a text-mode layout
    -- brings it out. Drawn, like the X, the plus, the lock and the caret: a question mark out of the
    -- player's font was the last thing on this row that followed the face rather than the theme.
    local helpToggle = ns.CreateGlyphButton(p, "?", 22)
    ns.AddTip(helpToggle, "Search words", "top")
    helpToggle:SetScript("OnClick", function(s) showCatHelp(s) end)
    helpToggle:Hide()
    p.helpToggle = helpToggle

    -- The drop zone is built in the layout. While a piece rides the cursor it shows over the pin band as
    -- the place a release would land; driven by CURSOR_CHANGED, one watcher for every panel. The pin entry
    -- lights the same way, so both the wide band and the field itself flag as drop targets during a drag.
    p.SyncDrop = function(s)
      local on = CursorHasItem() and s:IsShown()
      if s.zone then s.zone:SetShown(on or false) end
      if s.pinEntry and s.pinEntry.SyncDrag then s.pinEntry:SyncDrag() end
    end

    row.build[i] = p
    return p
  end

  -- Lay out one row's panel and return its height. `entry` is the saved category row.
  local function layoutBuild(p, ids, width, entry)
    -- Content indents to PANEL_PAD, right of the accent rail, so the open editor stays out of the name
    -- column; rpad is the usual right inset.
    local y, pad, rpad = 9, PANEL_PAD, 24
    local usable = width - pad - rpad

    -- Rule as chips, or the raw text box when RuleParts can't flatten it (or the player chose text).
    local raw = Cats:SearchById(p.wpeId)
    local parts = ns.RuleParts and ns.RuleParts(raw) or nil
    local useChips = parts ~= nil and not p.wpeRaw

    -- One write path for every chip edit: read mode + chips, write the canonical rule, relayout.
    local function commitRule()
      if not p.wpeId then return end
      local rule = ns.RuleFromParts(p.wpeMode or "all", p.wpeConds or {})
      Cats:SetSearchById(p.wpeId, rule)
      relayout()
      Options:ReflowPages()
    end

    if useChips then
      -- The join is authoritative only when the rule carries a separator (2+ conditions); at 0-1 the
      -- string cannot hold one, so the remembered pick stands in and a flip there is preserved across the
      -- reflow rather than snapping back to "all". A 2+ rule updates the memory to whatever it spells out.
      if #parts.conds >= 2 then
        p.wpeMode = parts.mode
        row.matchMode[p.wpeId] = parts.mode
      else
        p.wpeMode = row.matchMode[p.wpeId] or parts.mode
      end
      p.wpeConds = parts.conds
      p.wpeSetMode = function(mode)
        if p.wpeMode == mode then return end
        p.wpeMode = mode
        row.matchMode[p.wpeId] = mode
        commitRule()
      end
      p.wpeAddCond = function(token)
        p.wpeConds[#p.wpeConds + 1] = { axis = nil, token = token }
        commitRule()
      end

      -- Rule line: the join dropdown, the live count beside it, the text toggle at the right. The dropdown
      -- is always live and full-strength, even at 0-1 conditions — a labelled dropdown reads as clickable
      -- where a bare word pair did not, and flipping it there is harmless.
      p.matchBtn:ClearAllPoints()
      p.matchBtn:SetPoint("TOPLEFT", pad, -(y - 5))
      p.matchBtn:Show()
      p.matchBtn:Refresh()
      p.rawToggle.wpeRaw = nil
      p.rawToggle:Repaint()
      p.rawToggle:ClearAllPoints()
      p.rawToggle:SetPoint("TOPRIGHT", -rpad, -(y - 5))
      p.rawToggle:Show()
      -- The "?" belongs to the text form only: a chip rule is built from the picker, which already names
      -- every word, so the word list would only crowd a mode that does not need it.
      p.helpToggle:Hide()
      if not (InCombatLockdown and InCombatLockdown()) then
        local n = Cats:Preview(raw) or 0
        p.matchCount:SetText(ns.LN("catches %d in bags", n))
        p.matchCount:ClearAllPoints()
        ns.SnapPoint(p.matchCount, "LEFT", p.matchBtn, "RIGHT", 12, 0)
        -- Bounded on the right so a long translation stops before the text-toggle instead of running under it.
        p.matchCount:SetPoint("RIGHT", p.rawToggle, "LEFT", -8, 0)
        p.matchCount:SetJustifyH("LEFT")
        p.matchCount:SetWordWrap(false)
        p.matchCount:Show()
      else
        p.matchCount:Hide()
      end
      p.rawBox:Hide()
      y = y + BASE_FONT + 10

      -- Condition chips, wrapping from the panel's left edge.
      local x, line, last = 0, 0, 0
      for k, cond in ipairs(parts.conds) do
        local chip = makeCond(p, k)
        chip.wpeNeg = cond.neg or false
        chip.wpeToken = cond.token
        -- An exact-id word shows the item it names, art and all; every other word keeps the label the
        -- picker gives it. The rule is never rewritten, and the token rides the chip's tooltip.
        local id = condItem(cond.token)
        local word = (id and itemName(id)) or (ns.TokenDisplay and ns.TokenDisplay(cond.token)) or cond.token
        -- "Not" stays red: it is the one word in a rule that turns it inside out, and a chip is read at a
        -- glance. Only the word is coloured, never the plate, so nothing sinks into Blood's red surfaces.
        local label = cond.neg and ("|cffe64d4d" .. T("Not") .. "|r " .. word) or word
        local left = 7
        if id then
          chip.ic:SetTexture(ns.PinIcon(id))
          chip.ic:ClearAllPoints()
          chip.ic:SetPoint("LEFT", 6, 0)
          chip.ic:Show()
          left = 25
        else
          chip.ic:Hide()
        end
        chip.Text:ClearAllPoints()
        chip.Text:SetPoint("LEFT", left, 0)
        chip.Text:SetPoint("RIGHT", -7, 0)
        chip.Text:SetText(label)
        -- A label that has not drawn yet measures 0; estimate from the letters so a fresh chip is not
        -- clipped on its first pass, and let the real width take over on the next layout.
        local wordW = math.ceil(chip.Text:GetStringWidth() or 0)
        if wordW <= 0 then wordW = math.ceil(#word * BASE_FONT * 0.6) end
        local w = math.min(usable, wordW + left + 7)
        chip:SetWidth(w)
        chip.wpeOnToggle = function(neg)
          p.wpeConds[k].neg = neg or nil
          commitRule()
        end
        chip.wpeOnRemove = function()
          table.remove(p.wpeConds, k)
          commitRule()
        end
        if x > 0 and x + w > usable then x = 0; line = line + 1 end
        chip:ClearAllPoints()
        chip:SetPoint("TOPLEFT", pad + x, -(y + line * (COND_H + 4)))
        chip:Repaint()
        chip:Show()
        x = x + w + 4
        last = k
      end
      for k = last + 1, #p.conds do if p.conds[k] then p.conds[k]:Hide() end end
      -- The "+" plate follows the chips on the last line and wraps like one of them.
      local aw = ADD_COND_W
      if x > 0 and x + aw > usable then x = 0; line = line + 1 end
      p.addCond:ClearAllPoints()
      -- Snapped, not raw SetPoint: x accumulates measured (fractional) chip widths, and a
      -- fractionally-standing plate rounds the two bars' edges independently, so the junction
      -- lands off-centre and the left arm reads shorter. The old parity-snapped 4px survived
      -- this (even edges round symmetric); the literal 3px does not. Same fix as the Favorites
      -- ghosts, which ride SnapPoint for exactly this reason.
      ns.SnapPoint(p.addCond, "TOPLEFT", p, "TOPLEFT", pad + x, -(y + line * (COND_H + 4)))
      p.addCond:Show()
      y = y + (line + 1) * (COND_H + 4) + 8
    else
      -- Raw fallback. The toggle keeps the chip mode's top-line position (top-right at y-5) so it does not
      -- jump when the band flips; it stays filled here, and is hidden only when the rule cannot be chips at
      -- all (nothing to go back to). The box sits on its own line below, at a fixed offset — not anchored to
      -- the placeholder, which measured 0 on a fresh pass and threw the box around.
      p.matchBtn:Hide()
      p.matchCount:Hide(); p.addCond:Hide()
      for k = 1, #p.conds do if p.conds[k] then p.conds[k]:Hide() end end
      local canChips = parts ~= nil
      if canChips then
        p.rawToggle.wpeRaw = true
        p.rawToggle:Repaint()
        p.rawToggle:ClearAllPoints()
        p.rawToggle:SetPoint("TOPRIGHT", -rpad, -(y - 5))
        p.rawToggle:Show()
      else
        p.rawToggle:Hide()
      end
      -- The "?" lives in the text form, where the picker is out of reach and the word list is the only
      -- place a hand-written rule can look one up. Beside the text toggle when the rule can still be chips,
      -- else alone in the corner.
      p.helpToggle:ClearAllPoints()
      if canChips then
        p.helpToggle:SetPoint("RIGHT", p.rawToggle, "LEFT", -6, 0)
      else
        p.helpToggle:SetPoint("TOPRIGHT", -rpad, -(y - 5))
      end
      p.helpToggle:Show()
      y = y + BASE_FONT + 10
      p.rawBox:ClearAllPoints()
      p.rawBox:SetPoint("TOPLEFT", pad, -y)
      p.rawBox:SetWidth(usable)
      if not p.rawBox:HasFocus() then
        p.rawBox:SetText(raw)
        p.rawBox.ph:SetShown(raw == "")
      end
      p.rawBox:Show()
      y = y + CAT_ROW_H + 6
    end

    -- One seam between the rule band (Match) and the behaviour + pins below it, drawn from the content
    -- indent to the right edge so it reads as a divider inside the editor, not across the whole panel.
    y = y + 8
    p.seam1:ClearAllPoints()
    p.seam1:SetPoint("TOPLEFT", pad, -y)
    p.seam1:SetPoint("TOPRIGHT", -rpad, -y)
    p.seam1:Show()
    y = y + 8

    -- Placement, top to bottom: how this section is ordered, where it shows, and how it claims a contested
    -- item. Each control takes its own line at the panel's indent — its own caption leads it, so the three
    -- captions align down the left edge and their controls align down a shared column past the widest
    -- caption — instead of chasing one row a longer language ("Anzeigen in", "Priorität") would push off the
    -- right. One line each never overflows, whatever the translation.
    local CTRL_STEP = BASE_FONT + 14
    -- The shared caption column: the widest of the three captions, so every control starts at the same x.
    local capCol = 0
    for _, ctrl in ipairs({ p.sortBtn, p.showBoxes, p.prioPick }) do
      local cw = ctrl.cap and (ctrl.cap:GetStringWidth() or 0) or 0
      if cw > capCol then capCol = cw end
    end
    local function placeRow(ctrl)
      ctrl.wpeCapCol = capCol
      ctrl:Show()
      ctrl:Refresh()
      ctrl:ClearAllPoints()
      ctrl:SetPoint("TOPLEFT", pad, -y)
      y = y + CTRL_STEP
    end
    placeRow(p.sortBtn)
    placeRow(p.showBoxes)
    placeRow(p.prioPick)

    -- Pins, always visible: "Pinned N" caption then one rack led by the "+" slot. The slot is what a pin
    -- looks like when there is none — the place and the act are the same object — and it is the drop target
    -- for a piece dragged in from the bags or the bank, so filing by hand needs no id typed at all.
    p.hcap:ClearAllPoints()
    p.hcap:SetPoint("TOPLEFT", pad, -y)
    p.hcap:Show()
    p.hcount:ClearAllPoints()
    ns.SnapPoint(p.hcount, "LEFT", p.hcap, "RIGHT", 5, 0)
    p.hcount:SetText(tostring(#ids))
    p.hcount:Show()
    local capY = y
    y = y + BASE_FONT + 10
    -- Pinned art chips from the left, wrapping. The id-entry field goes on its own line under them.
    local x, line, lastChip = 0, 0, 0
    for k = 1, #ids do
      local chip = makeChip(p, k)
      chip.wpeId = ids[k]
      chip.ic:SetTexture(ns.PinIcon(ids[k]))
      if x > 0 and usable - x < CHIP then x = 0; line = line + 1 end
      chip:ClearAllPoints()
      chip:SetPoint("TOPLEFT", pad + x, -(y + line * (CHIP + CHIP_GAP)))
      chip:Show()
      x = x + CHIP + CHIP_GAP
      lastChip = k
    end
    for k = lastChip + 1, #p.chips do if p.chips[k] then p.chips[k]:Hide() end end
    for k = 1, #p.ghosts do if p.ghosts[k] then p.ghosts[k]:Hide() end end
    -- Rack height, then the id-entry field below it: a text box that previews the item as its id is typed.
    if #ids > 0 then y = y + (line + 1) * CHIP + line * CHIP_GAP + 6 end
    local entry = makePinEntry(p)
    entry:ClearAllPoints()
    entry:SetPoint("TOPLEFT", pad, -y)
    entry:SetWidth(math.min(usable, 340))
    entry:Show()
    entry:Preview()
    y = y + CHIP + 6 + 8
    -- The band the drop covers: from the caption line down to the bottom of the rack, so a release anywhere
    -- on the pins files the held piece. Shown only mid drag, so an idle rack never eats a click meant for
    -- the chip under it.
    local zone = p.zone
    if not zone then
      zone = CreateFrame("Button", nil, p, "BackdropTemplate")
      zone:SetFrameLevel(p:GetFrameLevel() + 8)
      ns.PixelBackdrop(zone)
      zone:RegisterForClicks("LeftButtonUp")
      zone:SetScript("OnReceiveDrag", function() pinFromCursor(p) end)
      zone:SetScript("OnClick", function() pinFromCursor(p) end)
      -- A faint accent wash + dashed-look edge while a piece is held, so the whole band reads as one drop
      -- target rather than an invisible catcher. Brightens on hover over it.
      zone:SetScript("OnEnter", function(s)
        ns.SetBg(s, select(1, Theme:C("accent")), select(2, Theme:C("accent")), select(3, Theme:C("accent")), 0.16)
      end)
      zone:SetScript("OnLeave", function(s)
        ns.SetBg(s, select(1, Theme:C("accent")), select(2, Theme:C("accent")), select(3, Theme:C("accent")), 0.08)
      end)
      zone:Hide()
      p.zone = zone
    end
    local ar, ag, ab = Theme:C("accent")
    ns.SetBg(zone, ar, ag, ab, 0.08)
    ns.SetEdge(zone, ar, ag, ab, 0.5)
    zone:ClearAllPoints()
    zone:SetPoint("TOPLEFT", p, "TOPLEFT", pad - 6, -capY)
    zone:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -(rpad - 6), 4)
    p:SyncDrop()
    return y
  end
  return buildPanel, layoutBuild
end
