local addonName, ns = ...
local Options = ns.Options
local factories = Options.factories
local Theme = ns.Theme
local L = ns.L

-- The badge page's two rows: the picker with its preview and the order list that reorders the marks on a
-- cell. They share the anchor vocabulary and the badge table, so they travel together. The shared values
-- come from Options.lua through ns.OptionControlsEnv, like every other page file.
local env = ns.OptionControlsEnv
local T = env.T
local BASE_FONT = env.baseFont
local CONTENT_W = env.contentW
local track = env.track
local tip = env.tip
local field = env.field
local relayoutLive = env.relayoutLive
local ANCHOR_LABELS = env.anchorLabels
local bg = env.bg

function factories.badges(parent, spec)
  local PREV = bg.prev
  local row = CreateFrame("Frame", nil, parent)
  row.dynamic = true

  local cell = CreateFrame("Frame", nil, row, "BackdropTemplate")
  ns.SnapBox(cell, PREV, PREV)
  ns.PixelBackdrop(cell)
  cell:EnableMouse(true)

  local mark = CreateFrame("Frame", nil, cell, "BackdropTemplate")
  ns.PixelBackdrop(mark)
  -- Above every badge frame in the preview, including the lifted one being edited: the ring has to be
  -- seen around it.
  mark:SetFrameLevel(cell:GetFrameLevel() + 20)
  mark:Hide()

  local readout = track(Theme:Label(row, BASE_FONT - 1, "accentInk"), -1)
  readout:SetJustifyH("LEFT")

  local hint = track(Theme:Label(row, BASE_FONT - 3, "dim"), -3)
  hint:SetJustifyH("LEFT")

  -- The preview keeps its badges in the same per-badge frames the cells use, so the order the list sets
  -- is what the player sees here too.
  local art, chips = {}, {}
  for _, d in ipairs(ns.BADGES) do
    local holder = ns.BadgeFrame(cell, d.key)
    if d.tex then
      local t = holder:CreateTexture(nil, "OVERLAY")
      ns.BadgeArt(t, d.key)
      art[d.key] = t
    else
      art[d.key] = Theme:Label(holder, BASE_FONT, "overlay")
    end
  end

  local function factor() return PREV / bg.cell() end

  local function measure(key)
    local d = ns.BADGE[key] or ns.BADGES[1]
    -- Read everything off the resolved def's key, not the raw argument: the fallback above is only real
    -- if an unknown key then draws from BADGES[1] too, otherwise art[key] is nil and GetStringWidth throws.
    key = d.key or key
    if d.tex then
      local sz = math.max(6, PREV * (ns.Badge(key).s or d.s))
      return sz, sz
    end
    local o = art[key]
    return o:GetStringWidth() or 0, o:GetStringHeight() or 0
  end

  local function span(key)
    local f = factor()
    if f <= 0 then f = 1 end
    local w, h = measure(key or bg.sel)
    return w / f, h / f,
           (cell:GetWidth() or 0) / f, (cell:GetHeight() or 0) / f
  end

  bg.spanW = function(key) local w = span(key); return w end

  bg.fit = function(field, v, key)
    local w, h, W, H = span(key)
    local g = (key and ns.Badge(key)) or bg.cur()
    local c = g.c or ""
    local horiz = field == "x"
    local size, box = horiz and w or h, horiz and W or H
    v = math.floor((tonumber(v) or 0) + 0.5)
    if size <= 0 or box <= 0 then return v end
    local lo, hi
    if horiz then
      local base = c:find("LEFT") and 0 or box
      local shift = (0.5 - bg.alignOff[bg.alignOf(g)]) * size
      lo, hi = -base - shift, box - base - shift
    elseif c:find("BOTTOM") then lo, hi = -size / 2, box - size / 2
    else lo, hi = size / 2 - box, size / 2 end
    if v < lo then return math.ceil(lo) end
    if v > hi then return math.floor(hi) end
    return v
  end

  local function paintChip(c)
    local sel, on = c.wpeKey == bg.sel, ns.Badge(c.wpeKey).on
    local hover = c:IsMouseOver()
    ns.SetBg(c, Theme:C(hover and "panelHi" or "panel"))
    ns.SetEdge(c, Theme:C(sel and "accent" or (hover and "accentInk" or "stroke")))
    -- Selection and hover show in the edge; the label keeps its ink (faint only when the badge is off),
    -- so the word is never painted over.
    c.Text:SetTextColor(Theme:C((not on) and "faint" or "text"))
  end

  local function paint()
    bg.normalize()
    local f, solo = factor(), bg.soloGet()
    ns.SetBg(cell, Theme:C("panel"))
    ns.SetEdge(cell, Theme:C("stroke"))
    ns.SetBg(mark, 0, 0, 0, 0)
    ns.SetEdge(mark, Theme:C("accent"))
    for _, d in ipairs(ns.BADGES) do
      local g, o, sel = ns.Badge(d.key), art[d.key], d.key == bg.sel
      local vis = (g.on and (sel or not solo)) and true or false
      local dim = sel and 1 or 0.35
      if d.tex then
        local sz = measure(d.key)
        o:SetSize(sz, sz)
        o:SetVertexColor(1, 1, 1, dim)
      else
        local cr, cg, cb = Theme:C("overlay")
        -- Through the same helper the grid draws with, so the preview shows the floor where
        -- the floor is what decides the size. It is magnified by f, not drawn at f.
        ns.SetOutlined(o, math.floor(ns.BadgeSize(d.key, bg.cell(), g) * f + 0.5))
        o:SetText(ns.BadgeSample(d.key) or d.key)
        o:SetTextColor(cr, cg, cb, dim)
      end
      -- Through the per-badge frame the cells also use, so the order from the list is the order the
      -- preview shows. The one being edited is lifted over the rest: a badge you cannot see is a badge
      -- you cannot drag. The stack count keeps the lowest place it has on a cell.
      local at, n = ns.BadgeOrderAt(d.key)
      local holder = ns.BadgeFrame(cell, d.key)
      holder:SetFrameLevel(ns.BadgeLevel(cell, d.key, at, n, sel))
      o:ClearAllPoints()
      -- The offsets go through the same call the grid places with, so the preview cannot show a
      -- placement the cell would not make -- the panel is magnified, and the rule holds at any
      -- magnification: an inset never rounds away to nothing.
      o:SetPoint(ns.BadgePoint(g), cell, g.c, ns.BadgeOffset(g.x, f), ns.BadgeOffset(g.y, f))
      o:SetShown(vis)
      if sel then
        local cl, ct = cell:GetLeft(), cell:GetTop()
        local ol, ot = o:GetLeft(), o:GetTop()
        mark:ClearAllPoints()
        if cl and ct and ol and ot then
          ns.SnapSize(mark, (o:GetWidth() or 0) + 6, (o:GetHeight() or 0) + 6)
          ns.SnapPoint(mark, "TOPLEFT", cell, "TOPLEFT", ol - cl - 3, ot - ct + 3)
        else
          mark:SetPoint("TOPLEFT", o, "TOPLEFT", -3, 3)
          mark:SetPoint("BOTTOMRIGHT", o, "BOTTOMRIGHT", 3, -3)
        end
        mark:SetShown(vis)
      end
    end
    local g = bg.cur()
    readout:SetText(("%s\nx %d\ny %d")
      :format(T(ANCHOR_LABELS[g.c] or g.c), g.x or 0, g.y or 0))
    readout:SetTextColor(Theme:C("accentInk"))
    hint:SetText(bg.hintText())
    for _, c in ipairs(chips) do paintChip(c) end
  end

  local function layoutChips()
    local path, gap, cols = ns.Fonts:Current(), 6, 3
    local w = math.floor((CONTENT_W - gap * (cols - 1)) / cols)
    for i, c in ipairs(chips) do
      c.Text:SetFont(path, BASE_FONT - 2, ns.OutlineFlags())
      c:SetWidth(w)
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", row, "TOPLEFT",
        ((i - 1) % cols) * (w + gap), -math.floor((i - 1) / cols) * 26)
    end
    return math.ceil(#chips / cols) * 26
  end

  for _, d in ipairs(ns.BADGES) do
    local c = ns.CreateButton(row, T(d.n or d.key), 62, 22)
    c.wpeKey = d.key
    ns.LocalText(c, d.n or d.key)
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    c:SetScript("OnEnter", paintChip)
    c:SetScript("OnLeave", paintChip)
    c:SetScript("OnClick", function(s, button)
      local g = ns.Badge(s.wpeKey)
      -- fixed: the right click that hides the other badges does nothing on the one that cannot go.
      if button == "RightButton" then
        if g.on and not d.fixed then g.on = false; bg.bump() end
      else
        if not g.on then g.on = true; bg.bump() end
        bg.sel = s.wpeKey
      end
      Options:ReflowPages()
    end)
    tip(c, d.t)
    chips[#chips + 1] = c
  end

  local function cursorXY()
    local s = cell:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    return cx / s - (cell:GetLeft() or 0), cy / s - (cell:GetBottom() or 0)
  end

  local function corner(o)
    local g = bg.cur()
    local c = g.c or "TOPLEFT"
    local cl, cb = cell:GetLeft() or 0, cell:GetBottom() or 0
    local a = bg.alignOf(g)
    local l, r = o:GetLeft() or 0, o:GetRight() or 0
    local x = (a == "left" and l or (a == "right" and r or (l + r) / 2)) - cl
    local y = (c:find("BOTTOM") and (o:GetBottom() or 0) or (o:GetTop() or 0)) - cb
    return x, y
  end

  local function place(px, py)
    local g, f = bg.cur(), factor()
    local c = g.c or "TOPLEFT"
    local W, H = cell:GetWidth() or 0, cell:GetHeight() or 0
    g.x = bg.pin("x", (c:find("LEFT") and px or (px - W)) / f)
    g.y = bg.pin("y", (c:find("BOTTOM") and py or (py - H)) / f)
  end

  local function center(px, py)
    local g, f = bg.cur(), factor()
    local c = g.c or "TOPLEFT"
    local w, h = measure(bg.sel)
    local W, H = cell:GetWidth() or 0, cell:GetHeight() or 0
    local l = math.min(W, math.max(0, px)) - w / 2
    local d = math.min(H, math.max(0, py)) - h / 2
    local ref = l + bg.alignOff[bg.alignOf(g)] * w
    g.x = bg.pin("x", (ref - (c:find("LEFT") and 0 or W)) / f)
    g.y = bg.pin("y", (c:find("BOTTOM") and d or (d + h - H)) / f)
  end

  local grab
  local function stop()
    grab = nil
    cell:SetScript("OnUpdate", nil)
    bg.bump()
    Options:ReflowPages()
  end

  local function hit(px, py)
    local first
    -- Walked backwards, so of several badges under the cursor the click takes the one drawn over the
    -- others -- among the unselected ones that is the last one built. The current selection still wins
    -- outright, so a click on the badge already chosen never moves the choice.
    for i = #ns.BADGES, 1, -1 do
      local d = ns.BADGES[i]
      local o = art[d.key]
      if ns.Badge(d.key).on and o:IsShown() then
        local l = (o:GetLeft() or 0) - (cell:GetLeft() or 0)
        local b = (o:GetBottom() or 0) - (cell:GetBottom() or 0)
        if px >= l - 3 and px <= l + (o:GetWidth() or 0) + 3
           and py >= b - 3 and py <= b + (o:GetHeight() or 0) + 3 then
          if d.key == bg.sel then return d.key end
          first = first or d.key
        end
      end
    end
    return first
  end

  cell:SetScript("OnMouseDown", function(s, button)
    if button ~= "LeftButton" then return end
    local px, py = cursorXY()
    local under = hit(px, py)
    if under and under ~= bg.sel then
      bg.sel = under
      Options:ReflowPages()
    end
    local g, o = bg.cur(), art[bg.sel]
    local w, h = o:GetWidth() or 0, o:GetHeight() or 0
    local ox = (o:GetLeft() or 0) + w / 2 - (cell:GetLeft() or 0)
    local oy = (o:GetBottom() or 0) + h / 2 - (cell:GetBottom() or 0)
    local held = g.on and math.abs(px - ox) <= w / 2 + 4
                      and math.abs(py - oy) <= h / 2 + 4
    if not held then g.on = true; center(px, py); paint() end
    local cx, cy = corner(o)
    grab = { dx = cx - px, dy = cy - py }
    s:SetScript("OnUpdate", function()
      if not (grab and IsMouseButtonDown("LeftButton")) then stop(); return end
      local x, y = cursorXY()
      place(x + grab.dx, y + grab.dy)
      paint()
    end)
  end)

  row.Refresh = function()
    local h = layoutChips()
    cell:ClearAllPoints()
    ns.SnapPoint(cell, "TOPLEFT", row, "TOPLEFT",
      math.floor((CONTENT_W - PREV) / 2), -(h + 16))
    readout:ClearAllPoints()
    readout:SetPoint("LEFT", row, "TOPLEFT", 2, -(h + 16 + PREV / 2))
    hint:ClearAllPoints()
    hint:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -(h + 16 + PREV + 3))
    hint:SetWidth(CONTENT_W)
    paint()
    local hh = 0
    if (hint:GetText() or "") ~= "" then
      hh = math.max(14, math.ceil(hint:GetStringHeight() or 14))
    end
    local moved = false
    for _, d in ipairs(ns.BADGES) do
      local g = ns.Badge(d.key)
      local x, y = bg.fit("x", g.x, d.key), bg.fit("y", g.y, d.key)
      if x ~= g.x or y ~= g.y then g.x, g.y = x, y; moved = true end
    end
    if moved then
      -- Paced like every slider: a size drag re-fits badges every frame.
      relayoutLive()
    end
    row:SetHeight(h + PREV + 18 + hh)
  end
  row.Rebuild = row.Refresh
  bg.repaint = paint
  row.Refresh()
  tip(cell, spec.desc)
  return row
end

-- The badge order: one line per badge, the top line drawn over the ones below it, moved the same way the
-- category list moves a row — grab the dots and drag, one accent line marking the slot the drop lands in.
-- The stack count gets a line of its own at the bottom with no grip: it is the game's own number on the
-- button, under every frame of ours, so nothing here can lift it over the others.
function factories.badgeorder(parent, spec)
  local row = CreateFrame("Frame", nil, parent)
  row.items = {}
  row.dynamic = true
  local LINE_H = 22
  local dragFrom, grabOff, dragLvl, dropTo

  -- The cursor's height down the list, in the list's own coordinates. nil while the scale is not ready, so
  -- every caller can bail instead of guessing.
  local function cursorOff()
    local scale = row:GetEffectiveScale()
    if not scale or scale == 0 then return nil end
    local _, cy = GetCursorPosition()
    return (row:GetTop() or 0) - (cy / scale)
  end

  -- The line the held row would be inserted before, read off the float's own middle rather than the bare
  -- cursor: the float rides at cursor - grabOff, so keying the slot off the cursor aimed half a line away
  -- from what the eye sees. Past the last movable line the answer is that line plus one, which is the top
  -- of the fixed count.
  local function dropSlot()
    local off = cursorOff()
    if not off then return nil end
    local n = #ns.BadgeOrder()
    local cy = off - (grabOff or 0) + LINE_H / 2
    for i = 1, n do
      if cy < (i - 1) * LINE_H + LINE_H / 2 then return i end
    end
    return n + 1
  end

  -- The line marking the slot, on its own thin frame lifted above the lines: they are child frames, so a
  -- texture on the parent would draw under them and vanish on a line's own edge.
  local function dropMark()
    local m = row.dropMark
    if m then return m end
    local f = CreateFrame("Frame", nil, row)
    f:SetHeight(2)
    f:SetFrameLevel(row:GetFrameLevel() + 30)
    local line = Theme:Rect(f, "accent", "OVERLAY")
    line:SetAllPoints(f)
    f:Hide()
    row.dropMark = f
    return f
  end

  local function onDragUpdate()
    local off = cursorOff()
    if not off then return end
    local fr = dragFrom and row.items[dragFrom]
    if fr then
      local fy = off - (grabOff or 0)
      local maxY = math.max(0, #ns.BadgeOrder() * LINE_H - LINE_H)
      if fy < 0 then fy = 0 elseif fy > maxY then fy = maxY end
      fr:ClearAllPoints()
      fr:SetPoint("TOPLEFT", 0, -fy)
      fr:SetPoint("TOPRIGHT", 0, -fy)
    end
    dropTo = dropSlot()
    -- A line's own place takes no marker: a drop there moves nothing, and both edges of that place are the
    -- same non-move, so the line would read as two different targets on a line already where it would land.
    if dragFrom and (dropTo == dragFrom or dropTo == dragFrom + 1) then dropTo = nil end
    local m = dropMark()
    if dropTo then
      local y = -(dropTo - 1) * LINE_H
      m:ClearAllPoints()
      m:SetPoint("TOPLEFT", 0, y)
      m:SetPoint("TOPRIGHT", 0, y)
      m:Show()
    else
      m:Hide()
    end
  end

  local function startDrag(i)
    dragFrom = i
    row.dragging = i
    local off = cursorOff()
    grabOff = off and (off - (i - 1) * LINE_H) or (LINE_H / 2)
    -- Lifted so the held line reads as picked up and is not drawn under the lines it passes. Put back on
    -- drop, since the rebuild does not touch a line's level.
    local fr = row.items[i]
    if fr then
      dragLvl = fr:GetFrameLevel()
      fr:SetFrameLevel(row:GetFrameLevel() + 20)
    end
    row:SetScript("OnUpdate", onDragUpdate)
  end

  local function stopDrag()
    row:SetScript("OnUpdate", nil)
    row.dragging = nil
    if row.dropMark then row.dropMark:Hide() end
    local from = dragFrom
    local fr = from and row.items[from]
    if fr and dragLvl then fr:SetFrameLevel(dragLvl) end
    dragFrom, dragLvl, dropTo = nil, nil, nil
    if not from then return end
    local slot = dropSlot()
    -- Back on its own place is not a move: rebuild to put the float back and leave the order alone, rather
    -- than writing the same list and re-dressing every cell for a drag that changed nothing.
    if not slot or slot == from or slot == from + 1 then row.Rebuild(); return end
    -- One move of one line, to the slot the marker showed. The count is not in this list, so it stays.
    local order = ns.BadgeOrder()
    local v = table.remove(order, from)
    if v then table.insert(order, slot > from and slot - 1 or slot, v) end
    WarpeeDB.badgeOrder = order
    -- The cells keep their frames; only the level each one draws at moves, so this is the same re-dress a
    -- font or theme change takes, and the preview beside it follows the new order.
    ns.BadgeOrderBump()
    bg.bump()
    row.Rebuild()
  end

  -- The grip: six dots in two columns, the glyph the category list uses for this same gesture, which a
  -- player already reads as "grab and drag this". One gesture for one action: no arrows beside it.
  local function makeGrip(c)
    local b = CreateFrame("Button", nil, c)
    ns.SnapBox(b, 12, LINE_H, true)
    b.dots = {}
    for k = 1, 6 do
      local d = b:CreateTexture(nil, "ARTWORK")
      d:SetColorTexture(Theme:C("dim"))
      ns.SnapSize(d, 2, 2)
      local col = (k - 1) % 2
      local rowk = math.floor((k - 1) / 2)
      d:SetPoint("CENTER", b, "CENTER", col == 0 and -2 or 2, (rowk - 1) * 4 + 2)
      b.dots[k] = d
    end
    local function paint(key)
      for _, d in ipairs(b.dots) do d:SetColorTexture(Theme:C(key)) end
    end
    Theme:Track(b, function() paint("dim") end)
    b:SetScript("OnEnter", function()
      paint("accent")
      GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
      GameTooltip:SetText(ns.L["Drag to reorder"], 1, 1, 1)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() paint("dim"); GameTooltip:Hide() end)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function() startDrag(c.wpeAt) end)
    b:SetScript("OnDragStop", stopDrag)
    return b
  end

  local function line(i, key, fixed)
    local r = row.items[i]
    if not r then
      r = CreateFrame("Frame", nil, row)
      r:SetHeight(LINE_H)
      -- The colour key is fixed when the line is built, because the theme tracker owns it from then on:
      -- a line is either one of the ordered badges or the fixed count, never both.
      r.name = track(Theme:Label(r, BASE_FONT - 1, fixed and "faint" or "text"), -1)
      r.name:SetJustifyH("LEFT")
      r.grip = makeGrip(r)
      ns.SnapPoint(r.grip, "LEFT", r, "LEFT", 1, 0)
      ns.SnapPoint(r.name, "LEFT", r.grip, "RIGHT", 8, 0)
      row.items[i] = r
    end
    local d = ns.BADGE[key] or {}
    r.wpeKey = key
    -- What the drag reads: nil on the count, which is not in the list at all.
    r.wpeAt = fixed and nil or i
    r.name:SetText(T(d.n or key))
    ns.LocalText(r.name, d.n or key)
    r.grip:SetShown(not fixed)
    return r
  end

  row.Rebuild = function()
    local order = ns.BadgeOrder()
    local n = #order
    for i = 1, n do
      local r = line(i, order[i], false)
      -- The held line is placed by the drag pass while it is in the air; the next rebuild puts it back.
      if row.dragging ~= i then
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, -((i - 1) * LINE_H))
        r:SetPoint("TOPRIGHT", 0, -((i - 1) * LINE_H))
      end
      r:Show()
    end
    -- The count is the one badge nobody orders: the game's own string on the button, under every frame of
    -- ours, so its line stands last and carries no grip.
    local c = line(n + 1, "count", true)
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", 0, -(n * LINE_H))
    c:SetPoint("TOPRIGHT", 0, -(n * LINE_H))
    c:Show()
    for i = n + 2, #row.items do row.items[i]:Hide() end
    row:SetHeight((n + 1) * LINE_H)
  end
  row.Refresh = row.Rebuild
  row.Rebuild()
  return row
end
