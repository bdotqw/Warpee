local addonName, ns = ...
local Options = ns.Options
local factories = Options.factories
local Theme = ns.Theme

-- The sheet that lists every word the search takes. It is a window of its own, hung beside the settings
-- window at the button that opened it, and filled from the live locale on every open.
function factories.catlisthelp(env)
  local BASE_FONT = env.baseFont
  local SCROLL_W = env.scrollW
  local dropdownFont = env.dropdownFont
  local T = env.T
  local AXIS_LABEL = env.axisLabel
  local PICK_AXES = env.axes
  -- The words the search takes, as a list to read rather than a menu to pick from: the band's "+" picks a
  -- word for a chip, this one answers which words exist at all. One window for the whole addon, filled on
  -- every open so a language change and a new token both reach it without a reload.
  local catHelp
  local HELP_ROWH, HELP_MAXH, HELP_PAD = BASE_FONT + 6, 430, 10
  -- Wider than the picker's columns: a group is one long list, so the width decides how many lines it wraps
  -- into rather than how wide a single word is. The width comes from the sample below and not from the
  -- longest word, or every sheet would open at its narrowest and read as a wall of short lines.
  local HELP_MINW, HELP_MAXW = 380, 820
  local HELP_SAMPLE = "abcdefghijklmnopqrstuvwxyz, "
  -- Where the title, the close button and the legend sit under the window's top edge: a row per skin and
  -- one row for every theme that draws no art up there. Literal numbers on purpose, because each skin's
  -- strip is a fixed height and a helper reading the skin back only hides which skin wants what. The
  -- plain art lays its moulding deeper than the strip its own title sits in, so its row clears it; the
  -- flat band across the top carries the window's own name, so there the title and the close button sit
  -- inside the band (10 and 4) and only the legend moves under it. A theme with no skin keeps 8/5/26.
  local HELP_TOP = {
    blizzard = { 28, 25, 46 },
    blizzardflat = { 10, 4, 40 },
  }
  local HELP_TOP_PLAIN = { 8, 5, 26 }

  local function catHelpFrame()
    if catHelp then return catHelp end
    local m = CreateFrame("Frame", "WarpeeSearchWords", UIParent, "BackdropTemplate")
    Theme:Panel(m, "bg", "stroke")
    -- Named, so Escape closes it with the rest of the addon's windows rather than the game menu.
    Theme:Window(m, "WarpeeSearchWords")
    -- FULLSCREEN_DIALOG, the strata the word picker already uses, so the sheet stays over the settings window
    -- whatever happens to it afterwards. DIALOG is not enough: the settings window sits in that strata too and
    -- raises itself on every click, and each raise lifts the page inside it over the sheet as well, so a wheel
    -- or a click inside the sheet's rectangle then lands on the page instead -- the page scrolls, and the sheet
    -- looks like it moved with it. One stratum above the window it hangs off rather than a raise-order race.
    m:SetFrameStrata("FULLSCREEN_DIALOG")
    -- One repaint after the move: the art a skin builds is sunk against the strata its window stood in when it
    -- was built, and this one has just gone up a stratum, so the plate is asked for again where it now belongs.
    Theme:WindowArt(m)
    -- The words stand on the same plate as every other window; fillHelp sizes the sheet and fits it again.
    Theme:Plate(m)
    m:SetClampedToScreen(true)
    m:EnableMouse(true)
    m:SetMovable(true)
    m:RegisterForDrag("LeftButton")
    m:SetScript("OnDragStart", function(s) s:StartMoving() end)
    -- Once the player has put it somewhere that is where it opens next time; until then it hangs off the
    -- button that opened it, so the list sits beside the rule it explains.
    m:SetScript("OnDragStop", function(s) s:StopMovingOrSizing(); s.wpeMoved = true end)
    -- Where the sheet stands, in one place: hung off the settings window at the offset read from the button
    -- that opened it, never off the row that button sits in. Those rows live in the page inside that window,
    -- and the page is what scrolls, so an anchor to a row carries the whole sheet, title and legend with it,
    -- on every wheel turn that reaches the page. A spot with no host means the screen. Applied on every show,
    -- because a spot is only right while the points are rewritten, and left alone after a drag, where the
    -- player has said where it goes.
    local function placeSheet(s)
      local sp = s.wpeSpot
      if s.wpeMoved or not sp then return end
      s:ClearAllPoints()
      local x, y = sp.x, sp.y
      -- Keep the whole sheet on screen vertically. Hung off a "?" low in a centred settings window, a
      -- tall list ran off the bottom edge and half of it was lost (SetClampedToScreen does not help once
      -- the sheet is anchored to another frame). The top is pulled down no further than leaves the bottom
      -- above the screen's floor, and never raised above its ceiling; its height is known here because the
      -- fill sizes it before showing it.
      if sp.host then
        local htop = sp.host:GetTop()
        local sh = s:GetHeight() or 0
        local screenH = UIParent:GetHeight() or 0
        if htop and sh > 0 and screenH > 0 then
          local top = math.max(sh, math.min(screenH, htop + y))
          y = top - htop
        end
      end
      -- To the right of the settings window, level with the button that opened it: the sheet's left edge
      -- sits a short gap past the window's right edge, so it never lands on top of the page it explains.
      s:SetPoint("TOPLEFT", sp.host or UIParent, sp.host and "TOPRIGHT" or "TOPLEFT", x, y)
    end
    m.Place = placeSheet
    m:SetScript("OnShow", function(s) placeSheet(s) end)
    m:Hide()

    local title = Theme:Title(m, 14, "accent")
    ns.LocalText(title, "Search words")
    m.title = title

    local close = ns.CreateGlyphButton(m, "\195\151", 22)
    close:SetScript("OnClick", function() m:Hide() end)
    -- Dim at rest, text under the pointer, like the window close marks elsewhere.
    close.wpeIconPaint = function(s)
      local hot = s.wpeHot and not s.offDuty
      ns.TintMarkX(s, hot and "text" or "dim")
    end
    close.wpeIconPaint(close)
    m.close = close

    -- What the words are for, and the two marks a hand-written rule uses. Read through the same words the
    -- band's join dropdown shows, so the legend reads in the window's own language everywhere.
    local legend = Theme:Label(m, BASE_FONT - 2, "dim")
    legend:SetJustifyH("LEFT")
    legend:SetWordWrap(true)
    m.legend = legend

    -- The child is anchored and sized, and its width is reset on every fill: a scroll frame clips what
    -- sits inside a child it cannot measure, and an unsized child took the whole list with it — the rows
    -- were drawn into a zero-width viewport, so the window showed its title and legend and nothing else.
    -- Every other scroll in the addon sizes its child for the same reason.
    local sc = CreateFrame("ScrollFrame", nil, m)
    local child = CreateFrame("Frame", nil, sc)
    child:SetPoint("TOPLEFT")
    child:SetSize(160, HELP_ROWH)
    sc:SetScrollChild(child)
    sc:EnableMouseWheel(true)
    m.sc, m.child = sc, child

    -- Two pools, because a row's colour is its kind: an axis name keeps the accent, a word keeps the text
    -- colour, and both are tracked by the theme so a repaint never has to know which kind it is looking at.
    m.hdrRows, m.wordRows = {}, {}
    local function hdr(i)
      local r = m.hdrRows[i]
      if r then return r end
      r = Theme:Label(child, BASE_FONT - 1, "accent")
      r:SetJustifyH("LEFT")
      r:SetWordWrap(false)
      m.hdrRows[i] = r
      return r
    end
    local function word(i)
      local r = m.wordRows[i]
      if r then return r end
      r = Theme:Label(child, BASE_FONT - 1, "text")
      r:SetJustifyH("LEFT")
      r:SetWordWrap(false)
      m.wordRows[i] = r
      return r
    end
    m.hdr, m.word = hdr, word

    -- The bar follows the picker's own: out of the way while the list fits, and dragging the thumb jumps
    -- the scroll, since the list is longer than the window in every language.
    local bar = CreateFrame("Frame", nil, m)
    bar:SetWidth(SCROLL_W)
    Theme:Rect(bar, "panel", "BACKGROUND"):SetAllPoints(bar)
    local thumb = CreateFrame("Frame", nil, bar)
    thumb:SetWidth(SCROLL_W)
    local thumbTex = Theme:Rect(thumb, "faint", "ARTWORK")
    thumbTex:SetAllPoints(thumb)
    m.bar, m.thumb, m.thumbTex = bar, thumb, thumbTex
    local function span() return math.max(0, m.child:GetHeight() - sc:GetHeight()) end
    local function paintBar()
      local sp, view = span(), sc:GetHeight()
      if sp <= 0 or not m:IsShown() then bar:Hide(); return end
      bar:Show()
      local ch = m.child:GetHeight()
      local h = math.max(20, view * view / (ch > 0 and ch or view))
      thumb:SetHeight(h)
      local frac = (sc:GetVerticalScroll() or 0) / sp
      thumb:ClearAllPoints()
      thumb:SetPoint("TOP", bar, "TOP", 0, -frac * math.max(0, (bar:GetHeight() or view) - h))
    end
    m.PaintBar = paintBar
    local function scroll(v)
      local sp = span()
      sc:SetVerticalScroll(math.min(sp, math.max(0, v)))
      paintBar()
    end
    local function wheel(d) scroll((sc:GetVerticalScroll() or 0) - d * HELP_ROWH * 2) end
    sc:SetScript("OnMouseWheel", function(s, d) wheel(d) end)
    -- The whole window takes the wheel, not only the list: the sheet floats over the settings page, and a
    -- wheel that reached that page would scroll it and drag the sheet along with whatever it is hung off.
    m:EnableMouseWheel(true)
    m:SetScript("OnMouseWheel", function(s, d) wheel(d) end)
    ns.ScrollThumb(thumb, thumbTex, sc, scroll, span)

    -- Off-screen scratch string in the row font, so each open measures the real rendered words and sizes
    -- the window to them rather than trusting a number, the same way the picker sizes its columns.
    local measure = m:CreateFontString(nil, "ARTWORK")
    measure:SetFont(dropdownFont(), BASE_FONT - 1, ns.OutlineFlags())
    measure:Hide()
    m.measure = measure

    catHelp = m
    return m
  end

  -- One group as a single plain comma list: every word the search takes under that axis, the canonical word
  -- of a concept first and the spellings the parser also takes for it right behind, so related words stay
  -- next to each other and the group reads as one run. Flat on purpose: a mark between concepts only broke
  -- the rhythm of the list (a colour only scattered it, and a fancier glyph is not in every font the player
  -- may pick), while adjacency already says what belongs to one thing. Lowercase throughout, because that
  -- is how the words are written into the field, and every word in it is one the language on screen spells:
  -- a language's list is its own, so no other language's words stand in it.
  local function helpList(list)
    local words = {}
    for _, c in ipairs(list) do
      local head = ns.SearchFold(c.head or c.token or "")
      words[#words + 1] = head
      for _, w in ipairs(c.words) do
        if ns.SearchFold(w) ~= head then words[#words + 1] = w end
      end
    end
    return table.concat(words, ", ")
  end

  -- Draw the list for the language in force right now. Run on every open and again from the locale pass,
  -- so nothing is captured at creation: the words, the legend, the measured width and the row font all
  -- come from the live locale, and an open window follows a language switch without a reload.
  local function fillHelp(m, anchor, keepScroll)
    -- Where the button sits inside the settings window, read once per open: the sheet opens to the RIGHT of
    -- the window, its top level with the button that opened it. Hung off the window (not the row the button
    -- sits in), so a wheel turn that scrolls the page inside the window never drags the sheet with it.
    if anchor then
      local host = Options.frame
      local atop = anchor:GetTop()
      local htop = host and host:GetTop()
      if atop and htop then
        -- x: a short gap past the window's right edge. y: the button's top below the window's top, so the
        -- sheet lines up with the "?" rather than the window's corner.
        m.wpeSpot = { host = host, x = 6, y = -(htop - atop) }
      else
        local ax, ay = anchor:GetLeft(), anchor:GetBottom()
        if ax and ay then m.wpeSpot = { x = ax, y = ay - 6 } end
      end
    end
    -- Grouped by the axes the editor names, in its own order, with any axis it does not name kept at the
    -- end rather than dropped. A group holds concepts, and a concept holds the words for it.
    local byAxis, order, rank = {}, {}, {}
    for _, c in ipairs(ns.SearchConcepts and ns.SearchConcepts() or {}) do
      local t = byAxis[c.axis]
      if not t then t = {}; byAxis[c.axis] = t; order[#order + 1] = c.axis end
      t[#t + 1] = c
    end
    -- The parser also reads things no dictionary holds: an id names one exact item, a bare
    -- number is an item level. Neither gets a row of its own — both shapes live in the legend
    -- above, which is where a shape to type belongs; the list below keeps real words only.
    for i, ax in ipairs(PICK_AXES) do rank[ax] = i end
    table.sort(order, function(a, b)
      local ia, ib = rank[a] or (#PICK_AXES + 1), rank[b] or (#PICK_AXES + 1)
      if ia ~= ib then return ia < ib end
      return a < b
    end)

    local mm = m.measure
    -- Re-read on every fill: a language or font change can swap the face the rows draw in.
    mm:SetFont(dropdownFont(), BASE_FONT - 1, ns.OutlineFlags())
    local wide = 0
    for _, ax in ipairs(order) do
      mm:SetText(T(AXIS_LABEL[ax] or ax))
      wide = math.max(wide, mm:GetStringWidth() or 0)
      for _, c in ipairs(byAxis[ax]) do
        mm:SetText(c.head or c.token or "")
        wide = math.max(wide, (mm:GetStringWidth() or 0) + 10)
        for _, w in ipairs(c.words) do
          mm:SetText(w)
        wide = math.max(wide, (mm:GetStringWidth() or 0) + 40)
        end
      end
    end
    local pad = HELP_PAD
    -- Read on every fill rather than once at creation: the skin can change while the sheet is open, and
    -- the theme pass refills it on the spot. A skin the table does not name gets the plain row.
    local top3 = HELP_TOP[Theme.skin] or HELP_TOP_PLAIN
    local titleY, closeY, legendY = top3[1], top3[2], top3[3]
    -- The header scrolls with the list instead of sitting over it: a frozen header kept riding
    -- down over the top rows on its way past. Except in the flat skin, whose band art covers
    -- the top 32 of the window: there the title stays frozen inside the band and the scroll
    -- starts below it, so content never rides onto the texture. The close button stays on
    -- the window either way.
    local flat = Theme.skin == "blizzardflat"
    m.title:SetParent(flat and m or m.child)
    m.legend:SetParent(m.child)
    -- Band 32 + 4: the same 4 the bar keeps from the close button elsewhere, here from the texture.
    local scTop = flat and 36 or titleY
    -- Two-and-a-bit runs of the sample is about eighty characters in the row font, whatever the language
    -- or the face: a comfortable measure to read a list at. The longest word still has to fit on one line,
    -- and the whole window still has to fit across the screen.
    mm:SetText(HELP_SAMPLE)
    local fit = math.ceil((mm:GetStringWidth() or 0) * 2.8) + pad * 2 + SCROLL_W + 20
    local width = math.max(fit, math.min(HELP_MAXW, math.ceil(wide) + pad * 2 + SCROLL_W + 20))
    width = math.max(HELP_MINW, math.min(HELP_MAXW, width,
                                     math.floor((UIParent:GetWidth() or 1000) * 0.7)))
    -- The text ends 12 short of the bar, not 4, so wrapped lines do not sit against it,
    -- and the scrolling title stays clear of the close button on its way past.
    local innerW = width - pad * 2 - SCROLL_W - 12
    m.child:SetWidth(innerW)

    m.title:ClearAllPoints()
    m.close:ClearAllPoints()
    m.close:SetPoint("TOPRIGHT", -4, -closeY)
    m.legend:ClearAllPoints()
    if flat then
      -- Frozen inside the band, full width like the scrolling title elsewhere.
      m.title:SetPoint("TOPLEFT", pad, -titleY)
    else
      m.title:SetPoint("TOPLEFT", 0, 0)
    end
    m.title:SetWidth(innerW)
    m.legend:SetPoint("TOPLEFT", 10, -(legendY - scTop))
    m.legend:SetWidth(innerW - 10)
    m.legend:SetText((T("Type several words: an item must match all of them. %s = space, %s = |, %s = !. For example, (mount | toy) !quest means mounts or toys, but no quest items. More forms: id:6948; 400; ilvl400; ilvl>400; ilvl>=400; ilvl<400; ilvl<=400; ilvl400-450.")):format(T("All"), T("Any"), T("Not")))
    local legendH = math.ceil(m.legend:GetStringHeight() or 0)

    -- The header is part of the scrollable child, so the groups start below the legend inside it.
    local n, y = 0, (legendY - scTop) + legendH + 14
    for _, ax in ipairs(order) do
      n = n + 1
      local r = m.hdr(n)
      local label = T(AXIS_LABEL[ax] or ax)
      r:SetText(label)
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", 10, -y)
      r:SetWidth(innerW - 10)
      r:Show()
      y = y + HELP_ROWH
      -- One row per group, holding the whole group, so a group takes as many lines as its list needs and
      -- no more: a wrapped row is measured from its own text in the font it is drawn in.
      n = n + 1
      local row = m.word(n)
      row:SetWordWrap(true)
      -- Air between the wrapped lines: the face is outlined, and at one line's spacing a long list reads as
      -- a block rather than as lines.
      if row.SetSpacing then row:SetSpacing(3) end
      row:SetText(helpList(byAxis[ax]))
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", 40, -y)
      row:SetWidth(innerW - 40)
      row:Show()
      -- A full step of air after each list: in some languages the next header sat on the
      -- previous synonyms, so the gap is a real one, not a hairline.
      y = y + math.max(HELP_ROWH, math.ceil(row:GetStringHeight() or 0) + 2) + 12
    end
    -- pairs, not a range: both pools are indexed by the shared row counter, so they hold holes and # has
    -- no answer for them. A row past this fill's last index is one an earlier, longer list built.
    for i, r in pairs(m.hdrRows) do if i > n then r:Hide() end end
    for i, r in pairs(m.wordRows) do if i > n then r:Hide() end end
    m.child:SetHeight(math.max(HELP_ROWH, y))

    -- The scroll starts at scTop; the window fits what stands above plus the visible list.
    -- The bar starts below the close button: in the scrolling mode the list reaches the top
    -- of the window, and the bar would otherwise run under the ×. The close button is 22 tall.
    local barTop = math.max(scTop, closeY + 22 + 4)
    local listH = math.max(HELP_ROWH * 3, math.min(y, HELP_MAXH - scTop - pad))
    m.sc:ClearAllPoints()
    m.sc:SetPoint("TOPLEFT", pad, -scTop)
    m.sc:SetPoint("BOTTOMRIGHT", -(pad + SCROLL_W + 2), pad)
    m.bar:ClearAllPoints()
    m.bar:SetPoint("TOPRIGHT", -pad, -barTop)
    m.bar:SetPoint("BOTTOMRIGHT", -pad, pad)
    ns.SnapSize(m, width, scTop + listH + pad)
    Theme:FitPlateOf(m)
    -- Showing is what places it: OnShow re-applies the spot the anchor above wrote, so a sheet already open
    -- keeps the place it has and only a fresh open reads the button again.
    m:Show()
    m:Raise()
    -- Nothing inside is raised above the window: a level above the window's own broke the scroll frame's
    -- clipping once, and the list then drew straight over the title and the legend on its way past.
    -- A repaint keeps the reader's place, but the list it lands back on can be shorter (a language with
    -- tighter words), so the old offset is pulled in before the bar is drawn from it.
    local span = math.max(0, m.child:GetHeight() - m.sc:GetHeight())
    m.sc:SetVerticalScroll(keepScroll and math.min(span, m.sc:GetVerticalScroll() or 0) or 0)
    m.PaintBar()
  end

  local function showCatHelp(anchor)
    local m = catHelpFrame()
    if m:IsShown() then m:Hide(); return end
    fillHelp(m, anchor)
  end

  -- The locale pass runs this after a language switch so an open window repaints on the spot instead of
  -- waiting for the next open.
  ns.RefreshSearchWords = function()
    if catHelp and catHelp:IsShown() then fillHelp(catHelp, nil, true) end
  end

  -- Whether the pointer stands on the sheet, measured from the sheet's own rectangle rather than from what
  -- the mouse is over: it floats across the settings window and the page inside it, so the frame under the
  -- cursor can be one of the page's rows even while the cursor is well inside the sheet.
  ns.SearchWordsUnderCursor = function()
    local m = catHelp
    if not (m and m:IsShown()) then return false end
    local l, b = m:GetLeft(), m:GetBottom()
    local w, h = m:GetWidth(), m:GetHeight()
    local s = m:GetEffectiveScale()
    if not (l and b and w and h and s and s > 0) then return false end
    local x, y = GetCursorPosition()
    x, y = x / s, y / s
    return x >= l and x <= l + w and y >= b and y <= b + h
  end

  return showCatHelp
end
