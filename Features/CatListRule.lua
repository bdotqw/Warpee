local addonName, ns = ...
local Options = ns.Options
local factories = Options.factories
local Theme = ns.Theme

-- What the rule band under a category row is made of: the chips for the words, the id field that pins an
-- item, and the placement controls (match, sort, priority, where the section shows). Each builder takes the
-- panel it dresses; the caller owns the panel and the list.
function factories.catlistrule(env)
  local Cats = env.Cats
  local act = env.act
  local relayout = env.relayout
  local openDropdown = env.openDropdown
  local BASE_FONT, CHIP = env.baseFont, env.chip
  local T = env.T
  local CAT_SORT_KEYS, SORT_LABELS = env.sortKeys, env.sortLabels
  -- The item an exact-id word names. Both spellings are read, "id6948" the one the parser takes and
  -- "id:6948" the one people type; only what the rule already contains is read, nothing is invented from a
  -- word it does not contain.
  local function condItem(word)
    if type(word) ~= "string" then return nil end
    local n = word:match("^id(%d+)$") or word:match("^id:(%d+)$")
    return n and tonumber(n) or nil
  end

  -- The shared reader (Items/ItemButton.lua), so the label this page draws for an id and the name the id
  -- field previews can never read the item two different ways.
  local function itemName(id)
    return ns.PinName(id)
  end

  -- The release half of a drag: take the held piece off the cursor and pin it to this section. Nothing is
  -- moved — a pin is a saved table entry — and the lift was the player's own click on a bag cell, so this
  -- only reads the cursor and clears it. Out of combat, since the cursor is not an addon's to clear while
  -- the game guards it; a refusal leaves the piece where the player was holding it.
  local function pinFromCursor(panel)
    local ctype, id = GetCursorInfo()
    if ctype ~= "item" or not id or not panel.wpeId then return end
    if InCombatLockdown() then return end
    ClearCursor()
    act(function() Cats:PinItem(id, panel.wpeId) end)
  end

  -- The "+" plate: the "add one of these" control, used by the rule row for a condition. A piece riding
  -- the cursor lights it too, since it doubles as a drop target.
  local function paintPlus(s)
    local on = s.wpeHot or s.wpeDrop
    ns.SetBg(s, Theme:C(on and "panelHi" or "bg"))
    local er, eg, eb = Theme:C(on and "accent" or "emptyLine")
    ns.SetEdge(s, er, eg, eb, on and 1 or 0.55)
    -- Hover/drop shows in the plate and the border; the mark lifts to the window ink but never fills
    -- accent, the same rule the header marks follow.
    ns.TintMarkX(s, on and "text" or "faint")
  end

  local function makePlusSlot(parent, w, h)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    ns.SnapBox(b, w, h)
    ns.PixelBackdrop(b)
    b:RegisterForClicks("LeftButtonUp")
    ns.MarkPlus(b)
    ns.TintMarkX(b, "faint")
    b.Repaint = paintPlus
    paintPlus(b)
    Theme:Track(b, paintPlus)
    b:SetScript("OnEnter", function(s) s.wpeHot = true; paintPlus(s) end)
    b:SetScript("OnLeave", function(s) s.wpeHot = nil; paintPlus(s) end)
    b:Hide()
    return b
  end

  -- The pin entry: the shared id field (Core/Widgets.lua) — digits only, previewing the item as it is
  -- typed, so a player sees the icon and name before committing and knows the id is right. Enter (or the
  -- check) pins it; it is also a drop target, so dragging a piece in from the bags files it with no id at
  -- all. One per panel, built lazily.
  local function makePinEntry(panel)
    local e = panel.pinEntry
    if e then return e end
    e = ns.CreateIdField(panel, {
      hint = "Drop an item here, or type an id",
      height = CHIP,
      font = BASE_FONT - 1,
      smallFont = BASE_FONT - 2,
      -- The commit lands on the section this panel edits; the field clears itself afterwards.
      onCommit = function(id)
        if panel.wpeId then act(function() Cats:PinItem(id, panel.wpeId) end) end
      end,
    })
    -- A shift-clicked link or a dragged piece files straight in, same as the old rack did. The whole frame
    -- is the drop target and a click focuses the number box, so both ways in land on the one field.
    e:SetScript("OnReceiveDrag", function() pinFromCursor(panel) end)
    e:SetScript("OnMouseUp", function() if CursorHasItem() then pinFromCursor(panel) else e.box:SetFocus() end end)
    e:SetScript("OnMouseDown", function() e.box:SetFocus() end)
    ns.AddTip(e, "Drop an item here to pin it, or type its id. Pins beat rules, so a pinned item always lands in this category.", "top")
    -- Lit while a piece rides the cursor, so the field flags itself as a drop target the moment a drag starts.
    e.SyncDrag = function(s) s.wpeDrag = CursorHasItem() and s:IsShown() or nil; s:Repaint() end
    panel.pinEntry = e
    return e
  end

  -- One rule condition. The plate stays neutral in every theme; only the word "Not" is coloured, so nothing
  -- merges on Blood's dark-red surfaces. taint free — edits the saved rule only.
  local COND_H = 26
  -- Width of the "+" plate that adds a condition: a square target the chip's own height, no words.
  local ADD_COND_W = 26
  local function makeCond(panel, k)
    local b = panel.conds[k]
    if b then return b end
    b = CreateFrame("Button", nil, panel, "BackdropTemplate")
    b:SetHeight(COND_H)
    ns.PixelBackdrop(b)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    -- The item's art when the chip names one: "id6948" is bookkeeping, the picture is what a player knows.
    -- Left of the text, hidden for every other word, and never shown for a word the rule did not name.
    local ic = b:CreateTexture(nil, "ARTWORK")
    ic:SetPoint("LEFT", 6, 0)
    ns.SnapSize(ic, COND_H - 6, COND_H - 6)
    ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ic:Hide()
    b.ic = ic
    local fs = Theme:Label(b, BASE_FONT - 2, "text")
    fs:SetPoint("LEFT", 7, 0)
    fs:SetPoint("RIGHT", -7, 0)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    b.Text = fs
    local function paint(s)
      local br, bg, bb = Theme:C("panelHi")
      ns.SetBg(s, br, bg, bb, 1)
      local ek, eg, eb = Theme:C(s.wpeHot and "accent" or "strokeSoft")
      ns.SetEdge(s, ek, eg, eb)
      s.Text:SetTextColor(Theme:C("text"))
    end
    b.Repaint = paint
    b:SetScript("OnEnter", function(s) s.wpeHot = true; paint(s) end)
    b:SetScript("OnLeave", function(s) s.wpeHot = nil; paint(s) end)
    b:SetScript("OnClick", function(s, button)
      if button == "RightButton" then
        if s.wpeOnRemove then s.wpeOnRemove() end
      else
        s.wpeNeg = not s.wpeNeg
        if s.wpeOnToggle then s.wpeOnToggle(s.wpeNeg) end
      end
    end)
    -- The token the rule actually stores rides the tooltip, so a hand-written rule stays legible under a
    -- chip that shows the item's name instead of the word that was typed.
    ns.AddTip(b, function() return T("Left click flips to Not, right click removes") end, "top",
      function(s) return { { text = s.wpeToken or "" } } end)
    panel.conds[k] = b
    return b
  end


  -- A labelled dropdown button in the panel's placement row: "Caption: value ▾", width follows its text,
  -- lights on hover, opens `spec` on click. Shared shape for Show-in, Priority and Sort so the row reads
  -- as one set of controls. `valueText()` returns what the closed button shows.
  local function makeDropBtn(panel, capKey, spec, valueText)
    local btn = CreateFrame("Button", nil, panel)
    ns.SnapBox(btn, 120, 22, true)
    local cap = Theme:Label(btn, BASE_FONT - 2, "faint")
    cap:SetPoint("LEFT", 0, 0)
    cap:SetJustifyH("LEFT")
    ns.LocalText(cap, capKey)
    local arrow = ns.ArrowGlyph(btn, "down", 9)
    arrow:SetPoint("RIGHT", -2, 0)
    local cur = Theme:Label(btn, BASE_FONT - 2, "text")
    cur:SetPoint("RIGHT", arrow, "LEFT", -4, 0)
    cur:SetJustifyH("RIGHT")
    cur:SetWordWrap(false)
    btn.cap, btn.cur = cap, cur
    local function refresh()
      cur:SetText(valueText())
      arrow:SetTint("dim")
      -- caption + gap + value + gap + chevron; measured so no translation is clipped. When a caption column
      -- is set (the placement rows share one), the caption half is padded to it so the value block starts at
      -- the same x as the other rows' controls — the value is right-anchored, so a wider button aligns it.
      local capSpan = math.max(cap:GetStringWidth() or 0, btn.wpeCapCol or 0)
      btn:SetWidth(capSpan + 6 + (cur:GetStringWidth() or 0) + 6 + 9 + 4)
    end
    btn.wpeDrop = { spec = spec, onPick = refresh }
    btn:SetScript("OnClick", function(s) openDropdown(s, spec, refresh) end)
    btn:SetScript("OnEnter", function(s)
      arrow:SetTint("accent")
      if spec.desc then ns.ShowTip(s, { { text = spec.desc } }, "top") end
    end)
    btn:SetScript("OnLeave", function() arrow:SetTint("dim"); ns.HideTip() end)
    btn.Refresh = refresh
    return btn
  end

  -- Per-category sort override, keyed by id. Stores only the draw order — plain relayout, no taint.
  local function makeSortBtn(panel)
    local spec = {
      keys = function() return CAT_SORT_KEYS end,
      get = function() return Cats:SortOf(panel.wpeId) end,
      set = function(v) if panel.wpeId then Cats:SetSortById(panel.wpeId, v); relayout() end end,
      label = function(k) return ns.L[SORT_LABELS[k] or k] end,
      desc = "The order this one section takes, overriding the sort above it. Default follows that sort. By rule draws items in the order a search's | parts are written; By expansion groups by expansion, newest first.",
    }
    return makeDropBtn(panel, "Sort", spec, function()
      return T(SORT_LABELS[Cats:SortOf(panel.wpeId)] or "Default")
    end)
  end

  -- Claim priority as one pick out of five: five cells in a single plate with the current one filled in the
  -- accent, so the control reads as "choose one of these" exactly the way the join switch does, instead of a
  -- few loose glyphs with a number somewhere between them. The cells carry the numbers themselves, so
  -- nothing has to be decoded to read the answer. -2..+2, keyed by id; stores only the number — plain
  -- relayout, no taint.
  local PRIO_VALS = { -2, -1, 0, 1, 2 }
  local PRIO_CELL_W, PRIO_CELL_GAP, PRIO_PAD = 26, 2, 2
  local PRIO_DESC = "Which section claims an item that more than one rule matches: the higher priority wins, whatever the order in the list. Left at 0, the section higher in the list wins, as before."
  local function makePrioPick(panel)
    local box = CreateFrame("Frame", nil, panel)
    box:SetHeight(22)
    local cap = Theme:Label(box, BASE_FONT - 2, "faint")
    cap:SetPoint("LEFT", 0, 0)
    ns.LocalText(cap, "Priority")
    -- The cells sit on a bare layout frame: each already carries its own fill and edge, so a plate
    -- behind them only laid a second background under the row. Transparent, it just spaces the cells.
    local strip = CreateFrame("Frame", nil, box, "BackdropTemplate")
    ns.PixelBackdrop(strip)
    local function paintStrip(s)
      ns.SetBg(s, 0, 0, 0, 0)
      ns.SetEdge(s, 0, 0, 0, 0)
    end
    paintStrip(strip)
    Theme:Track(strip, paintStrip)
    ns.SnapPoint(strip, "LEFT", cap, "RIGHT", 8, 0)
    local cells = {}
    for i, v in ipairs(PRIO_VALS) do
      local b = CreateFrame("Button", nil, strip, "BackdropTemplate")
      ns.PixelBackdrop(b)
      ns.SnapSize(b, PRIO_CELL_W, 18)
      ns.SnapPoint(b, "TOPLEFT", strip, "TOPLEFT", PRIO_PAD + (i - 1) * (PRIO_CELL_W + PRIO_CELL_GAP), -PRIO_PAD)
      local fs = Theme:Label(b, BASE_FONT - 2, "dim")
      fs:SetPoint("CENTER")
      fs:SetJustifyH("CENTER")
      fs:SetText((v > 0 and "+" or "") .. v)
      b.Text, b.wpeVal = fs, v
      -- Selected cell reads by its recessed plate and accent edge, not by painting the number accent: the
      -- ink stays text so the word is never covered by the highlight colour.
      local function paint(s)
        local on, hot = s.wpeOn, s.wpeHot
        ns.SetBg(s, Theme:C(on and "panelHi" or "bg"))
        local er, eg, eb = Theme:C(on and "accent" or (hot and "accent" or "strokeSoft"))
        ns.SetEdge(s, er, eg, eb, 1)
        s.Text:SetTextColor(Theme:C((on or hot) and "text" or "dim"))
      end
      b.Repaint = paint
      paint(b)
      Theme:Track(b, paint)
      b:RegisterForClicks("LeftButtonUp")
      b:SetScript("OnEnter", function(s) s.wpeHot = true; paint(s) end)
      b:SetScript("OnLeave", function(s) s.wpeHot = nil; paint(s) end)
      b:SetScript("OnClick", function()
        if not panel.wpeId then return end
        Cats:SetPrioById(panel.wpeId, v)
        -- The row is drawn once per rebuild, so the control repaints itself here: relayout() alone would
        -- leave the old value on screen until something else redrew the panel.
        box.Refresh()
        relayout()
      end)
      ns.AddTip(b, function() return T("Priority") .. " " .. ((v > 0 and "+" or "") .. v) end, "top",
        function() return { { text = PRIO_DESC } } end)
      cells[i] = b
    end
    ns.SnapSize(strip, PRIO_PAD * 2 + #PRIO_VALS * PRIO_CELL_W + (#PRIO_VALS - 1) * PRIO_CELL_GAP, 22)
    box.Refresh = function()
      local v = panel.wpeId and Cats:PrioOf(panel.wpeId) or 0
      for i, b in ipairs(cells) do
        b.wpeOn = (PRIO_VALS[i] == v) or nil
        b:Repaint()
      end
      -- The strip starts at the shared caption column, so the cells line up under the other rows' controls.
      local col = math.max(cap:GetStringWidth() or 0, box.wpeCapCol or 0)
      strip:ClearAllPoints()
      ns.SnapPoint(strip, "LEFT", box, "LEFT", col + 8, 0)
      -- The row anchors whatever follows off this box's right edge, so it has to hold its own width.
      ns.SnapSize(box, col + 8 + (strip:GetWidth() or 0), 22)
    end
    box.cap = cap
    return box
  end

  -- "Show in" as three checkboxes, the very box the category rows lead with: "where does this show" is
  -- three on/off answers, and this window already has one shape for on and off — an empty square against
  -- one filled with the accent — so the question needs no control of its own to learn. One click each,
  -- nothing to open and nothing to read twice. Stores only c.hide — plain relayout, no taint. Empty and
  -- Other never carry it; the Warband box is dropped when the account bank is not in use.
  local SHOW_WINDOWS = { { "bags", "Bags" }, { "bank", "Bank" }, { "warband", "Warband" } }
  local SHOW_BOX, SHOW_BOX_GAP, SHOW_LABEL_GAP = 13, 12, 5
  local function makeShowBoxes(panel)
    local box = CreateFrame("Frame", nil, panel)
    box:SetHeight(22)
    local cap = Theme:Label(box, BASE_FONT - 2, "faint")
    cap:SetPoint("LEFT", 0, 0)
    ns.LocalText(cap, "Show in")
    local cells = {}
    for _, wk in ipairs(SHOW_WINDOWS) do
      local key, label = wk[1], wk[2]
      -- The box is a frame, so the click lives on a button that carries the box and its name together:
      -- the whole "tick + word" is the target, as it is on a category row.
      local c = CreateFrame("Button", nil, box)
      c:SetHeight(22)
      c:RegisterForClicks("LeftButtonUp")
      local chk = ns.CreateCheckBox(c, SHOW_BOX)
      ns.SnapPoint(chk, "LEFT", c, "LEFT", 0, 0)
      local fs = Theme:Label(c, BASE_FONT - 2, "dim")
      ns.SnapPoint(fs, "LEFT", chk, "RIGHT", SHOW_LABEL_GAP, 0)
      fs:SetJustifyH("LEFT")
      fs:SetWordWrap(false)
      ns.LocalText(fs, label)
      c.Text, c.chk, c.wpeKey = fs, chk, key
      local function paint(s)
        local on, hot = s.wpeOn, s.wpeHot
        s.chk:SetKeys("slot", on and "bg" or (hot and "accent" or "stroke"),
                      on and "accent" or (hot and "accent" or "stroke"))
        s.chk.mark:SetShown(on)
        s.Text:SetTextColor(Theme:C((on or hot) and "text" or "dim"))
      end
      c.Repaint = paint
      paint(c)
      Theme:Track(c, paint)
      c:SetScript("OnEnter", function(s) s.wpeHot = true; paint(s) end)
      c:SetScript("OnLeave", function(s) s.wpeHot = nil; paint(s) end)
      c:SetScript("OnClick", function()
        if not panel.wpeId then return end
        Cats:ToggleHidden(panel.wpeId, key)
        -- Repaint here, not only in the layout: the panel is redrawn on a rebuild, and a click has to
        -- show its own result at once or the box looks like it did nothing.
        box.Refresh()
        relayout()
      end)
      ns.AddTip(c, "Which windows this category shows in. Unchecked windows drop its items through to the next matching category.", "top")
      cells[#cells + 1] = c
    end
    box.Refresh = function()
      local x = 0
      -- The boxes start at the shared caption column (so this row's cells line up under Sort's value and
      -- Priority's cells), falling back to just past this caption when no column is set.
      local col = math.max(cap:GetStringWidth() or 0, box.wpeCapCol or 0)
      for _, c in ipairs(cells) do
        -- The Warband box goes away when the account bank is not in use, and the rest close up behind it.
        if c.wpeKey ~= "warband" or ns.WarbandActive() then
          -- Measured off the word, so a longer language widens the target instead of clipping the name.
          local w = SHOW_BOX + SHOW_LABEL_GAP + math.ceil(c.Text:GetStringWidth() or 0)
          if w <= SHOW_BOX + SHOW_LABEL_GAP then w = SHOW_BOX + SHOW_LABEL_GAP + SHOW_BOX end
          c:SetWidth(w)
          c:ClearAllPoints()
          ns.SnapPoint(c, "LEFT", box, "LEFT", col + 8 + x, 0)
          c.wpeOn = (panel.wpeId and not Cats:HiddenIn(panel.wpeId, c.wpeKey)) and true or nil
          c:Repaint()
          c:Show()
          x = x + w + SHOW_BOX_GAP
        else
          c:Hide()
        end
      end
      if x > 0 then x = x - SHOW_BOX_GAP end
      -- The row positions this box by its own edges, so it has to be as wide as what it holds: a
      -- zero-width box would put whatever follows it on top of the boxes instead of after them.
      ns.SnapSize(box, col + 8 + x, 22)
    end
    box.cap = cap
    return box
  end
  return condItem, itemName, paintPlus, makePlusSlot, makePinEntry,
    makeCond, makeDropBtn, makeSortBtn, makePrioPick, makeShowBoxes, COND_H, ADD_COND_W
end
