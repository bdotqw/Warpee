local addonName, ns = ...
local Theme = ns.Theme

local TRI = {
  up    = { { 1, 1, 0 }, { 3, -1, 0 } },
  down  = { { 2, 1, 0 }, { 4, -1, 0 } },
  left  = { { 1, 0, -1 }, { 2, 0, 1 } },
  right = { { 3, 0, -1 }, { 4, 0, 1 } },
}

local function applyTri(t)
  local host = t:GetParent() or t
  local side = (t.wpeDir == "left" or t.wpeDir == "right")
  local w = side and ns.PX(host, t.wpeW or 8) or ns.SnapOdd(host, t.wpeW or 8)
  local h = side and ns.SnapOdd(host, t.wpeH or 8) or ns.PX(host, t.wpeH or 8)
  t:SetSize(w, h)
  for i = 1, 4 do t:SetVertexOffset(i, 0, 0) end
  for _, v in ipairs(TRI[t.wpeDir] or TRI.down) do
    t:SetVertexOffset(v[1], v[2] * w * 0.5, v[3] * h * 0.5)
  end
end

function ns.Triangle(parent, dir, w, h, colorKey, layer, sub)
  local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub)
  t:SetColorTexture(1, 1, 1, 1)
  t.wpeDir = TRI[dir] and dir or "down"
  t.wpeW, t.wpeH = w or 8, h or w or 8
  t.wpeKey = colorKey or "dim"
  t:SetVertexColor(Theme:C(t.wpeKey))
  t.SetTint = function(s, key)
    s.wpeKey = key or s.wpeKey
    s:SetVertexColor(Theme:C(s.wpeKey))
  end
  t.SetDir = function(s, d)
    if TRI[d] then s.wpeDir = d end
    applyTri(s)
  end
  t.SetSpan = function(s, ww, hh)
    s.wpeW, s.wpeH = ww or s.wpeW, hh or s.wpeH
    applyTri(s)
  end
  Theme:Track(t, function(s) s:SetVertexColor(Theme:C(s.wpeKey)) end)
  ns.PixelJob(t, applyTri, "tri")
  return t
end

function ns.ArrowGlyph(parent, dir, size)
  local d = TRI[dir] and dir or "down"
  local side = (d == "left" or d == "right")
  local n = math.max(4, size or 9)
  local minor = math.max(3, math.floor(n * 0.62 + 0.5))
  local w, h = side and minor or n, side and n or minor
  local f = CreateFrame("Frame", nil, parent)
  local t = ns.Triangle(f, d, w, h, "dim")
  t:SetPoint("TOPLEFT")
  ns.PixelJob(f, function(s)
    t:SetSpan()
    s:SetSize(t:GetWidth(), t:GetHeight())
  end, "fit")
  f.tri, f.parts = t, { t }
  f.Tint = function(_, key) t:SetTint(key) end
  f.SetTint = function(s, key) s.wpeTint = key; t:SetTint(key) end
  f.SetDir = function(_, nd) t:SetDir(nd) end
  return f
end

function ns.CreateCharTag(parent, height, dir)
  local PADX, GAP = 8, 6
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  ns.SnapBox(b, nil, height or 22)
  ns.PixelBackdrop(b)
  local bgKey = "panel"
  b.wpeInkKey = "text"

  local side = (dir == "left" or dir == "right")
  local caret = ns.ArrowGlyph(b, side and dir or "down", side and 11 or 8)
  b.caret = caret

  local fs = Theme:Label(b, 12, "text")
  fs:SetJustifyH("LEFT")
  fs:SetFont(ns.Fonts:Current(), 12, ns.OutlineFlags())
  b.Text = fs
  local function paintText(s)
    local p = s:GetParent()
    local col = p and p.wpeClassColor
    if col then s:SetTextColor(col.r, col.g, col.b)
    else s:SetTextColor(Theme:C((p and p.wpeInkKey) or "text")) end
  end
  b.TextPaint = paintText
  paintText(fs)
  Theme:Track(fs, paintText)

  local function repaint(s)
    local hot = s.wpeHot and s:IsEnabled()
    ns.SetBg(s, Theme:C(hot and "panelHi" or bgKey))
    ns.SetEdge(s, Theme:C(hot and "accent" or "stroke"))
    s.caret:SetTint(hot and "accent" or (s:IsEnabled() and "dim" or "faint"))
    if s.TextPaint then s.TextPaint(s.Text) end
  end
  b.Repaint = repaint
  b:SetMotionScriptsWhileDisabled(true)
  repaint(b)
  Theme:Track(b, repaint)

  if dir == "left" then
    caret:SetPoint("LEFT", PADX, 0)
    fs:SetPoint("LEFT", caret, "RIGHT", GAP, 0)
    fs:SetPoint("RIGHT", -PADX, 0)
  else
    fs:SetPoint("LEFT", PADX, 0)
    caret:SetPoint("RIGHT", -PADX, 0)
    fs:SetPoint("RIGHT", caret, "LEFT", -GAP, 0)
  end
  b:SetScript("OnEnter", function(s)
    if not s:IsEnabled() then return end
    s.wpeHot = true
    s:Repaint()
  end)
  b:SetScript("OnLeave", function(s)
    s.wpeHot = nil
    s:Repaint()
  end)
  return b
end

function ns.PaintCharTag(b, name, class)
  if not b then return end
  b.Text:SetText(name or "?")
  local col = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  b.wpeClassColor = col
  if col then b.Text:SetTextColor(col.r, col.g, col.b) else b.Text:SetTextColor(Theme:C(b.wpeInkKey or "text")) end
  local caret = math.ceil((b.caret and b.caret:GetWidth()) or 8)
  if caret <= 0 then caret = 8 end
  local extra = 8 + 6 + 8 + caret + 2
  local w = math.max(78, math.ceil(b.Text:GetStringWidth()) + extra)
  -- The width is measured, so it is put on the pixel grid here and handed to the box job as
  -- well: the job is what re-fits it when the ui scale moves, and a measured width set raw
  -- leaves one border of the tag between two physical pixels.
  b.wpeBoxW = w
  b:SetWidth(ns.SnapValue(b, w))
end

function ns.WindowsLocked()
  return (WarpeeDB and WarpeeDB.lockWindows) and true or false
end

function ns.MoveFieldsHidden()
  return (WarpeeDB and WarpeeDB.hideMoveFields) and true or false
end

function ns.MoveBarsVisible()
  return not ns.WindowsLocked() and not ns.MoveFieldsHidden()
end

function ns.DragStart(frame)
  if ns.WindowsLocked() then return end
  ns.DragMove(frame)
end

-- The mechanical half of a drag, without the lock check: the pocket keeps its own lock rather
-- than the one that governs the bags and the bank, and it decides for itself when to start.
function ns.DragMove(frame)
  frame:StartMoving()
  frame.wpeMoving = true
  Theme:LiftArt(frame)
  if not frame.wpeDropHook then
    frame.wpeDropHook = true
    frame:HookScript("OnDragStop", function(s) Theme:DropArt(s) end)
  end
end

function ns.MoveWindowTo(frame, dbKey, nx, ny)
  local l, b = frame:GetLeft(), frame:GetBottom()
  if not (l and b) then return end
  ns.PlaceRect(frame, dbKey, nil, nx or l, ny or b)
  if ns.Profiles and ns.Profiles.SyncActive then ns.Profiles:SyncActive() end
end

function ns.NudgeWindow(frame, dbKey, dx, dy)
  local l, b = frame:GetLeft(), frame:GetBottom()
  if not (l and b) then return end
  ns.MoveWindowTo(frame, dbKey, math.floor(l + 0.5) + dx, math.floor(b + 0.5) + dy)
end

local moveBars = {}
local barFace

local function barArrow(bar, dir, fn)
  local b = CreateFrame("Button", nil, bar)
  ns.SnapBox(b, 16, 16)
  local glyph = ns.ArrowGlyph(b, dir, 11)
  glyph:SetPoint("CENTER")
  b.wpeGlyph, b.wpeDir = glyph, dir
  b:SetScript("OnEnter", function(s) s.hover = true; glyph:SetTint("accent") end)
  b:SetScript("OnLeave", function(s) s.hover = nil; glyph:SetTint("dim") end)
  b:SetScript("OnClick", function() fn(IsShiftKeyDown() and 10 or 1) end)
  return b
end

function ns.SizeArrow(b, px)
  if not (b and b.wpeGlyph) then return end
  px = math.max(12, px or 16)
  if b.wpeArrowSize == px then return end
  b.wpeArrowSize = px
  ns.SnapBox(b, px, px)
  local n = math.max(7, px - 5)
  local minor = math.max(3, math.floor(n * 0.62 + 0.5))
  local t = b.wpeGlyph.tri
  if b.wpeDir == "left" or b.wpeDir == "right" then t:SetSpan(minor, n)
  else t:SetSpan(n, minor) end
  b.wpeGlyph:SetSize(t:GetWidth(), t:GetHeight())
end

-- The drag half of a scrollbar: press plants the thumb, the cursor carries it, release lets go, and the
-- thumb wears three tints on the way (resting, hovered, held). Four scrollbars in the addon had these ten
-- lines each -- the settings dropdown, a settings page, the help sheet and the character picker -- and they
-- differed only in what a scroll means to their own list. So the two halves that are the caller's are
-- handed in: `scrollTo(v)` moves the list (and usually repaints it), `span()` is how far it can travel.
-- The caller clamps v itself; this only says where the cursor went.
function ns.ScrollThumb(thumb, tex, sf, scrollTo, span)
  thumb:EnableMouse(true)
  thumb:SetScript("OnMouseDown", function(s)
    s.grabY = select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
    s.grabScroll = sf:GetVerticalScroll() or 0
    s:SetScript("OnUpdate", function(t)
      local y = select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
      local travel = sf:GetHeight() - t:GetHeight()
      if travel <= 0 then return end
      scrollTo(t.grabScroll + (t.grabY - y) * span() / travel)
    end)
    tex:SetVertexColor(Theme:C("accent"))
  end)
  thumb:SetScript("OnMouseUp", function(s)
    s:SetScript("OnUpdate", nil)
    tex:SetVertexColor(Theme:C("faint"))
  end)
  thumb:SetScript("OnEnter", function() tex:SetVertexColor(Theme:C("dim")) end)
  thumb:SetScript("OnLeave", function(s)
    if not s:GetScript("OnUpdate") then tex:SetVertexColor(Theme:C("faint")) end
  end)
end

local function barField(bar, apply)
  local e = CreateFrame("EditBox", nil, bar, "BackdropTemplate")
  ns.SnapBox(e, 40, 16)
  ns.PixelBackdrop(e)
  ns.SetBg(e, Theme:C("slot"))
  ns.SetEdge(e, Theme:C("stroke"))
  e:SetFontObject(ns.Fonts:Object(11, ns.OutlineFlags()))
  e:SetTextColor(Theme:C("text"))
  e:SetJustifyH("CENTER")
  e:SetAutoFocus(false)
  e:SetMaxLetters(6)
  Theme:Track(e, function(s)
    ns.SetBg(s, Theme:C("slot"))
    ns.SetEdge(s, Theme:C(s:HasFocus() and "accent" or "stroke"))
    s:SetTextColor(Theme:C("text"))
  end)
  e:SetScript("OnEditFocusGained", function(s) ns.SetEdge(s, Theme:C("accent")) end)
  e:SetScript("OnEditFocusLost", function(s)
    ns.SetEdge(s, Theme:C("stroke"))
    apply(tonumber(s:GetText()))
  end)
  e:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
  e:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
  return e
end

-- A window is stored as the corner it hangs from plus the offset of that corner from the
-- same corner of the screen. The corner is what decides which way the window grows when its
-- contents change, so it is picked and never guessed: every move re-anchors on the rectangle
-- the window already occupies and leaves the corner alone. Only a record that carries no
-- usable corner falls back to the half of the screen the window is standing on.
function ns.CornerOk(a)
  if a == "CENTER" or a == "TOPLEFT" or a == "TOPRIGHT" or a == "BOTTOMLEFT"
     or a == "BOTTOMRIGHT" then return a end
end

local function cornerOffsets(angle, l, b, w, h, sw, sh)
  if angle == "TOPLEFT" then return l, b + h - sh end
  if angle == "TOPRIGHT" then return l + w - sw, b + h - sh end
  if angle == "BOTTOMRIGHT" then return l + w - sw, b end
  if angle == "CENTER" then return l + w * 0.5 - sw * 0.5, b + h * 0.5 - sh * 0.5 end
  return l, b
end

-- The rectangle a record describes, for a window that cannot be measured where it stands:
-- the pocket is usually closed when its corner is changed, and a closed frame has no rect.
local function recordRect(frame, rec, sw, sh)
  if not (frame and rec) then return nil end
  local w, h = frame:GetWidth() or 0, frame:GetHeight() or 0
  local x, y = tonumber(rec.x) or 0, tonumber(rec.y) or 0
  local a = ns.CornerOk(rec.p) or "CENTER"
  if a == "TOPLEFT" then return x, sh - h + y end
  if a == "TOPRIGHT" then return sw - w + x, sh - h + y end
  if a == "BOTTOMRIGHT" then return sw - w + x, y end
  if a == "CENTER" then return sw * 0.5 - w * 0.5 + x, sh * 0.5 - h * 0.5 + y end
  return x, y
end

function ns.PlaceRect(frame, dbKey, angle, l, b, fallback)
  if not (frame and l and b) then return end
  local sw, sh = UIParent:GetWidth() or 0, UIParent:GetHeight() or 0
  if sw <= 0 or sh <= 0 then return end
  local rec = WarpeeDB and WarpeeDB[dbKey]
  local w, h = frame:GetWidth() or 0, frame:GetHeight() or 0
  angle = ns.CornerOk(angle) or (rec and ns.CornerOk(rec.p)) or ns.CornerOk(fallback)
  if not angle then angle = (l + w * 0.5) > sw * 0.5 and "BOTTOMRIGHT" or "BOTTOMLEFT" end
  local x, y = cornerOffsets(angle, l, b, w, h, sw, sh)
  frame:ClearAllPoints()
  ns.SnapPoint(frame, angle, UIParent, angle, x, y)
  ns.AlignToScreen(frame)
  local _, _, _, rx, ry = frame:GetPoint()
  -- Layout also calls this after a resize, and the window is still standing where the
  -- previous profile left it at that point. Saving that would overwrite the position the
  -- profile switch has just loaded, before ApplyAll gets to place the window. The offsets
  -- are read back after the clamp and the sub-pixel pass, so what is stored is the
  -- rectangle that is on screen rather than the one that was asked for.
  if WarpeeDB and not ns.Applying then
    WarpeeDB[dbKey] = { p = angle, rp = angle, x = rx or x, y = ry or y }
  end
  if frame.wpeBar then frame.wpeBar:Refresh() end
end

-- The record a window standing on `l, b` would be filed under, under the corner it already
-- carries. Profiles read a live rectangle through this for a window nothing has saved yet,
-- and a corner written here is one the window keeps.
function ns.RectRecord(frame, dbKey, l, b)
  if not (frame and l and b) then return nil end
  local sw, sh = UIParent:GetWidth() or 0, UIParent:GetHeight() or 0
  if sw <= 0 or sh <= 0 then return nil end
  local rec = WarpeeDB and WarpeeDB[dbKey]
  local angle = ns.CornerOk(rec and rec.p) or "BOTTOMLEFT"
  local x, y = cornerOffsets(angle, l, b, frame:GetWidth() or 0, frame:GetHeight() or 0, sw, sh)
  return { p = angle, rp = angle, x = ns.SnapValue(frame, x), y = ns.SnapValue(frame, y) }
end

function ns.Rebase(frame, dbKey, fallback)
  if not frame then return end
  local l, b = frame:GetLeft(), frame:GetBottom()
  if not (l and b) then return end
  ns.PlaceRect(frame, dbKey, nil, ns.SnapValue(frame, l), ns.SnapValue(frame, b), fallback)
  if ns.Profiles and ns.Profiles.SyncActive then ns.Profiles:SyncActive() end
end

-- Changing the corner is a statement about growth, not about position: the window stays on
-- the rectangle it holds and only the numbers that describe it are rewritten.
function ns.SetAngle(frame, dbKey, angle)
  if not (frame and ns.CornerOk(angle)) then return end
  if ns.Applying then return end
  if not (WarpeeDB and WarpeeDB[dbKey]) then return end
  local sw, sh = UIParent:GetWidth() or 0, UIParent:GetHeight() or 0
  if sw <= 0 or sh <= 0 then return end
  local l, b = frame:GetLeft(), frame:GetBottom()
  if not (l and b) then l, b = recordRect(frame, WarpeeDB[dbKey], sw, sh) end
  if not (l and b) then return end
  ns.PlaceRect(frame, dbKey, angle, l, b)
  if ns.Options and ns.Options.RefreshSoon then ns.Options:RefreshSoon() end
  if ns.Profiles and ns.Profiles.SyncActive then ns.Profiles:SyncActive() end
end

function ns.PlaceWindow(frame, dbKey, def)
  local p = WarpeeDB and WarpeeDB[dbKey]
  local stored = p and ns.CornerOk(p.p)
  local rec = stored and p or def
  local angle = rec and ns.CornerOk(rec.p)
  frame:ClearAllPoints()
  if angle then
    ns.SnapPoint(frame, angle, UIParent, ns.CornerOk(rec.rp) or angle, rec.x or 0, rec.y or 0)
  else
    frame:SetPoint("CENTER")
  end
  ns.AlignToScreen(frame)
  if frame.wpeBar then frame.wpeBar:Refresh() end
end

function ns.CreateMoveBar(frame, dbKey)
  if frame.wpeBar then return frame.wpeBar end
  local bar = CreateFrame("Frame", nil, frame)
  bar:SetHeight(16)
  bar:SetPoint("BOTTOM", frame, "BOTTOM", 0, 6)
  bar:SetFrameLevel(frame:GetFrameLevel() + 20)
  bar.key = dbKey

  local xl = Theme:Label(bar, 11, "dim")
  xl:SetPoint("LEFT", 1, 0)
  xl:SetText("X")
  bar.xLabel = xl
  local xf = barField(bar, function(v) ns.MoveWindowTo(frame, dbKey, v, nil) end)
  xf:SetPoint("LEFT", xl, "RIGHT", 4, 0)
  bar.xField = xf
  local xm = barArrow(bar, "left", function(step) ns.NudgeWindow(frame, dbKey, -step, 0) end)
  xm:SetPoint("LEFT", xf, "RIGHT", 2, 0)
  local xp = barArrow(bar, "right", function(step) ns.NudgeWindow(frame, dbKey, step, 0) end)
  xp:SetPoint("LEFT", xm, "RIGHT", 0, 0)

  local yl = Theme:Label(bar, 11, "dim")
  yl:SetPoint("LEFT", xp, "RIGHT", 10, 0)
  yl:SetText("Y")
  bar.yLabel = yl
  local yf = barField(bar, function(v) ns.MoveWindowTo(frame, dbKey, nil, v) end)
  yf:SetPoint("LEFT", yl, "RIGHT", 4, 0)
  bar.yField = yf
  local ym = barArrow(bar, "down", function(step) ns.NudgeWindow(frame, dbKey, 0, -step) end)
  ym:SetPoint("LEFT", yf, "RIGHT", 2, 0)
  local yp = barArrow(bar, "up", function(step) ns.NudgeWindow(frame, dbKey, 0, step) end)
  yp:SetPoint("LEFT", ym, "RIGHT", 0, 0)
  bar:SetWidth(176)

  bar.Refresh = function(s)
    local l, b = frame:GetLeft(), frame:GetBottom()
    if not (l and b) then return end
    if not s.xField:HasFocus() then s.xField:SetText(tostring(math.floor(l + 0.5))) end
    if not s.yField:HasFocus() then s.yField:SetText(tostring(math.floor(b + 0.5))) end
  end

  bar.Fonts = function(s, path, size)
    size = math.max(8, size or 11)
    local key = path .. ":" .. size
    -- Only when the face or the size moves: SetFont re-lays the text out on every call, and a
    -- relayout that changes neither would pay for it on each pass.
    if s.wpeFace ~= key then
      s.wpeFace = key
      -- Both halves take the file, not a font object, for the reason the header glyphs do: a
      -- string riding an object draws the face that object held when its text was written.
      s.xLabel:SetFont(path, size, ns.OutlineFlags())
      s.yLabel:SetFont(path, size, ns.OutlineFlags())
      s.xField:SetFont(path, size, ns.OutlineFlags())
      s.yField:SetFont(path, size, ns.OutlineFlags())
    end
    s:Refresh()
  end

  bar.Size = function(s, h)
    h = math.max(12, h or 16)
    s:SetHeight(h)
    for _, b in ipairs({ xm, xp, ym, yp }) do ns.SizeArrow(b, h) end
    local fw = math.floor(h * 2.5 + 0.5)
    ns.SnapBox(xf, fw, h)
    ns.SnapBox(yf, fw, h)
    s:SetWidth(ns.SnapValue(s, fw * 2 + h * 4 + 32))
  end

  bar:SetShown(ns.MoveBarsVisible())
  frame.wpeBar = bar
  moveBars[#moveBars + 1] = bar
  return bar
end

function ns.ApplyWindowLock()
  local show = ns.MoveBarsVisible()
  for _, bar in ipairs(moveBars) do
    bar:SetShown(show)
    if show then bar:Refresh() end
  end
end

-- An edit box does not take a new face while it lives. The file reaches GetFont and the pixels
-- stay as they were: writing the values again does not move them, and neither does a size the
-- box has already drawn. What draws the new face is a box built after the change, which is why
-- a reload put the digits right and why the bank's bar, built on its first open, was never the
-- one complained about. The bars are therefore built again on a face change, by the same code
-- that built them the first time. Only the face is compared, so a relayout or a theme change
-- leaves them alone, and a font picked a handful of times a session costs a handful of bars.
function ns.RebuildMoveBars()
  if #moveBars == 0 then return end
  local old = moveBars
  moveBars = {}
  for _, bar in ipairs(old) do
    local parent, key = bar:GetParent(), bar.key
    bar:Hide()
    if parent and key then
      parent.wpeBar = nil
      ns.CreateMoveBar(parent, key)
    end
  end
end

function ns.RefreshMoveBars()
  local path = ns.Fonts and ns.Fonts:Current()
  if not path then return end
  if barFace and barFace ~= path then ns.RebuildMoveBars() end
  barFace = path
  for _, bar in ipairs(moveBars) do
    local size
    if bar.key == "bankPos" and ns.Bank and ns.Bank.CellSize then
      size = ns.Bank:CellSize()
    elseif ns.Bags then
      size = ns.Bags.iconSize
    end
    local d = ns.Density(size)
    bar:Fonts(path, d.font - 4)
    bar:Size(d.moveH)
  end
end

-- The pocket is nudged far more often than it is typed at, and its window can be too narrow
-- for the band the other two carry. Labels and fields come to about 185px, and a pocket four
-- columns wide is 180 at factory sizes and 132 at the smallest icon, so the numbers would
-- hang off both edges. Four arrows come to 70 and fit any width, and the coordinates live in
-- the settings instead. Nothing here follows the global lock: the pocket decides that itself.
function ns.CreateNudgeRow(frame, dbKey)
  if frame.wpeNudge then return frame.wpeNudge end
  local row = CreateFrame("Frame", nil, frame)
  row:SetPoint("BOTTOM", frame, "BOTTOM", 0, 6)
  row:SetFrameLevel(frame:GetFrameLevel() + 20)
  row:SetHeight(16)
  row:SetWidth(70)
  row.wpeArrows = {}

  local prev
  for _, spec in ipairs({ { "left", -1, 0 }, { "right", 1, 0 },
                           { "down", 0, -1 }, { "up", 0, 1 } }) do
    local dir, dx, dy = spec[1], spec[2], spec[3]
    local b = barArrow(row, dir, function(step)
      ns.NudgeWindow(frame, dbKey, dx * step, dy * step)
    end)
    row.wpeArrows[#row.wpeArrows + 1] = b
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 2, 0) else b:SetPoint("LEFT", 0, 0) end
    prev = b
  end
  row.Size = function(s, px)
    px = math.max(12, px or 16)
    for _, b in ipairs(s.wpeArrows or {}) do ns.SizeArrow(b, px) end
    s:SetHeight(px)
    s:SetWidth(px * 4 + 6)
  end
  frame.wpeNudge = row
  return row
end

-- The seam is the gap two windows hold when they stand against each other. It is measured
-- between rectangles, so the art that hangs past a rectangle is not part of it; the number
-- below is what is left over after both skins have had their overhang, and is the one knob
-- to turn if the gap reads wrong on a theme. Recognition is a window around it, wide enough
-- to catch a window dropped by hand and narrow enough to leave alone one parked well away.
ns.SEAM_GAP = 4
local SEAM_TOL = 14
local seamBusy = false

local function seamRect(f)
  if not (f and f:IsShown()) then return nil end
  local l, b = f:GetLeft(), f:GetBottom()
  local w, h = f:GetWidth(), f:GetHeight()
  if not (l and b and w and h) then return nil end
  return l, b, l + w, b + h
end

local function pocketFrame()
  local f = ns.Pocket and ns.Pocket.frame
  if f and f:IsShown() and not f.wpeMoving then return f end
end

function ns.PocketSnapOn()
  return (WarpeeDB == nil) or WarpeeDB.pocketSnap ~= false
end

-- Which side of `mover` the pocket holds a seam on, and which edge of the mover it is lined
-- up with on the other axis. Read before a resize and replayed after it, so a size change
-- repairs a seam that already held instead of inventing one.
local function seamOf(mover, partner)
  local ml, mb, mr, mt = seamRect(mover)
  local pl, pb, pr, pt = seamRect(partner)
  if not (ml and pl) then return nil end
  local gap = ns.SnapValue(partner, ns.SEAM_GAP)
  local tol = gap + SEAM_TOL
  local side
  if mt > pb and mb < pt then
    if math.abs(pl - mr - gap) <= tol then side = "right"
    elseif math.abs(ml - pr - gap) <= tol then side = "left" end
  end
  if not side and mr > pl and ml < pr then
    if math.abs(pb - mt - gap) <= tol then side = "above"
    elseif math.abs(mb - pt - gap) <= tol then side = "below" end
  end
  if not side then return nil end
  local align
  if side == "above" or side == "below" then
    if math.abs(pl - ml) <= tol then align = "left"
    elseif math.abs(pr - mr) <= tol then align = "right"
    elseif math.abs(pl + pr - ml - mr) <= tol then align = "center" end
  else
    if math.abs(pt - mt) <= tol then align = "top"
    elseif math.abs(pb - mb) <= tol then align = "bottom"
    elseif math.abs(pt + pb - mt - mb) <= tol then align = "center" end
  end
  return { side = side, align = align }
end

-- The corner that keeps the pocket on its side of the seam while its own contents change:
-- the edge it shares with the mover stays put, and the pocket grows away from it.
local function seamCorner(rel)
  if rel.side == "right" then return rel.align == "bottom" and "BOTTOMLEFT" or "TOPLEFT" end
  if rel.side == "left" then return rel.align == "bottom" and "BOTTOMRIGHT" or "TOPRIGHT" end
  if rel.side == "above" then return rel.align == "right" and "BOTTOMRIGHT" or "BOTTOMLEFT" end
  return rel.align == "right" and "TOPRIGHT" or "TOPLEFT"
end

local function seamFix(mover, partner, rel, dbKey, fallback)
  local ml, mb, mr, mt = seamRect(mover)
  local pl, pb, pr, pt = seamRect(partner)
  if not (ml and pl) then return false end
  local gap = ns.SnapValue(partner, ns.SEAM_GAP)
  local dx, dy = 0, 0
  local vertical = (rel.side == "left" or rel.side == "right")
  if rel.side == "right" then dx = mr + gap - pl
  elseif rel.side == "left" then dx = ml - gap - pr
  elseif rel.side == "above" then dy = mt + gap - pb
  elseif rel.side == "below" then dy = mb - gap - pt
  else return false end
  if vertical then
    if rel.align == "top" then dy = mt - pt
    elseif rel.align == "bottom" then dy = mb - pb
    elseif rel.align == "center" then dy = (mt + mb - pt - pb) * 0.5 end
  else
    if rel.align == "left" then dx = ml - pl
    elseif rel.align == "right" then dx = mr - pr
    elseif rel.align == "center" then dx = (ml + mr - pl - pr) * 0.5 end
  end
  if math.abs(dx) < 0.01 and math.abs(dy) < 0.01 then return false end
  ns.PlaceRect(partner, dbKey, nil, pl + dx, pb + dy, fallback)
  return true
end

function ns.SeamWatch(mover)
  if seamBusy or not ns.PocketSnapOn() then return nil end
  local partner = pocketFrame()
  if not (partner and mover and partner ~= mover) then return nil end
  local rel = seamOf(mover, partner)
  if not rel then return nil end
  return { mover = mover, partner = partner, rel = rel }
end

function ns.SeamHeal(watch)
  if not (watch and watch.rel) or seamBusy then return end
  seamBusy = true
  seamFix(watch.mover, watch.partner, watch.rel, "pocketPos", "CENTER")
  seamBusy = false
end

-- On a drop the pocket is the one that gives way, whichever of the two was just put down.
-- Dragging the bags does not carry it, and it is never dragged along by a window it is not
-- standing against.
function ns.SeamDrop(mover)
  if seamBusy or not ns.PocketSnapOn() then return end
  local partner = pocketFrame()
  if not partner then return end
  if partner ~= mover then
    local rel = seamOf(mover, partner)
    if not rel then return end
    seamBusy = true
    ns.SetAngle(partner, "pocketPos", seamCorner(rel))
    seamFix(mover, partner, rel, "pocketPos", "CENTER")
    seamBusy = false
    return
  end
  local list = { ns.Bags and ns.Bags.frame, ns.Bank and ns.Bank.frame }
  for i = 1, 2 do
    local f = list[i]
    if f and f ~= partner and f:IsShown() then
      local rel = seamOf(f, partner)
      if rel then
        seamBusy = true
        ns.SetAngle(partner, "pocketPos", seamCorner(rel))
        seamFix(f, partner, rel, "pocketPos", "CENTER")
        seamBusy = false
        return
      end
    end
  end
end

function ns.CreateButton(parent, text, width, height, template, dark)
  local b
  if template then
    local ok, made = pcall(CreateFrame, "Button", nil, parent, "BackdropTemplate," .. template)
    if not ok or not made then return nil end
    b = made
  else
    b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  end
  ns.SnapBox(b, width or 78, height or 22)
  if b.SetMotionScriptsWhileDisabled then b:SetMotionScriptsWhileDisabled(true) end
  ns.PixelBackdrop(b)
  local lightInk = dark == true or dark == "icon"
  local function repaint(s)
    local hot = s.wpeHot and not s.offDuty
    local bg = hot and "panelHi" or "panel"
    -- The hover shows in the plate and the border, never in the ink: a label kept its colour under the
    -- pointer and only the box around it lights. Accent on the text itself read as the word being painted
    -- over, which is not wanted anywhere the window puts a control.
    local ink = s.offDuty and "faint" or (lightInk and "overlay" or "text")
    ns.SetBg(s, Theme:C(bg))
    ns.SetEdge(s, Theme:C(hot and "accent" or (s.offDuty and "strokeSoft" or "stroke")))
    if s.Text then s.Text:SetTextColor(Theme:C(ink)) end
    if s.wpeIconPaint then s.wpeIconPaint(s) end
  end
  b.Repaint = repaint
  repaint(b)
  Theme:Track(b, repaint)
  local fs = Theme:Label(b, 12, lightInk and "overlay" or "text")
  Theme:Track(fs, function(s)
    local p = s:GetParent()
    local key = (p and p.offDuty) and "faint" or (lightInk and "overlay" or "text")
    s:SetTextColor(Theme:C(key))
  end)
  fs:SetPoint("CENTER")
  fs:SetText(text)
  b.Text = fs
  local hook = template and b.HookScript or b.SetScript
  hook(b, "OnEnter", function(s)
    if s.offDuty then return end
    s.wpeHot = true
    s:Repaint()
  end)
  hook(b, "OnLeave", function(s)
    s.wpeHot = nil
    s:Repaint()
  end)
  return b
end

function ns.SetButtonEnabled(b, on)
  if not b then return end
  on = on and true or false
  b.offDuty = not on
  b:SetEnabled(on)
  b:Repaint()
end

-- Drawn X mark: two diagonal strokes, no font involved, so the mark never
-- depends on the font file picked in the settings. Each stroke wears a 1px
-- outline all around it, the way the old glyph's outline kept it readable on
-- any panel, lit or not -- and centred, so no side loses a pixel to a shadow.
local function addArm(mark, host, angleDeg, shadow)
  local sh
  if shadow then
    sh = host:CreateTexture(nil, "ARTWORK")
    sh:SetDrawLayer("ARTWORK", -1)
    sh:SetColorTexture(0, 0, 0, 0.85)
    mark.shadow[#mark.shadow + 1] = sh
    sh.wpeAngle = angleDeg
  end
  local d = host:CreateTexture(nil, "ARTWORK")
  d:SetDrawLayer("ARTWORK", 0)
  d:SetColorTexture(1, 1, 1, 1)
  mark[#mark + 1] = d
  d.wpeAngle = angleDeg
  return d
end
-- An arm is a rectangle centred in the host's box, so the grid position of its edges is decided
-- by the box: a box of even size across an axis puts that centre on a pixel boundary and wants an
-- even extent there, an odd one puts it between two pixels and wants an odd extent. The question
-- is asked of an arm's length and of its thickness alike, each on the axis it runs across.
local function snapParity(host, v, axis)
  local u = ns.PX(host, 1)
  local box = (axis == "y") and (host:GetHeight() or 0) or (host:GetWidth() or 0)
  local bpx = math.floor(box / u + 0.5)
  local n = math.max(2, math.floor((tonumber(v) or 0) / u + 0.5))
  if (n % 2 == 1) ~= (bpx % 2 == 1) then n = n + 1 end
  return n * u
end
local function fitArm(host, d, sh, len, px)
  d:ClearAllPoints()
  d:SetPoint("CENTER", host, "CENTER", 0, 0)
  local a = d.wpeAngle
  if a == 90 then
    -- Axis-aligned bars are sized straight, never rotated: rotating a bar on
    -- a discrete grid rounds its centre to one side on every size.
    d:SetSize(px, len)
  else
    d:SetSize(len, px)
    if a ~= 0 then d:SetRotation(math.rad(a)) end
  end
  if not sh then return end
  local u = ns.PX(host, 1)
  sh:ClearAllPoints()
  sh:SetPoint("CENTER", host, "CENTER", 0, 0)
  -- Proud of its arm on every side, the ends included. A bar the same length as the stroke rimmed
  -- the two long sides and left both tips bare, so there the stroke met the panel with nothing
  -- between them. The bar grows by a pixel at each end, which is the outline the mark has promised
  -- since it was drawn -- and because the growth is even and the stroke itself is snapped, an arm
  -- that lands on the grid still gets exactly one pixel on either side.
  sh:SetSize(len + 2 * u, px + 2 * u)
  sh:SetRotation(math.rad(sh.wpeAngle))
end
-- A measure that a mark is laid out by, in whole physical pixels and always an even count. The marks
-- that are built from axis-aligned rectangles rather than turned arms -- the padlock and the question
-- mark -- lay every one of their parts out from the centre of the box, and half of an odd measure is a
-- half pixel that would put an edge between two of them. Even measures keep every edge on a boundary
-- with that centre, and the parity shift those two fits apply keeps them there when the box itself is
-- an odd count of pixels across.
local function evenCount(v, least)
  local n = math.max(least or 2, math.floor(v + 0.5))
  return n + (n % 2)
end
function ns.MarkX(host)
  local mark = host.wpeMarkX
  if not mark then
    mark = { shadow = {} }
    addArm(mark, host, 45, true)
    addArm(mark, host, -45, true)
    host.wpeMarkX = mark
    host:HookScript("OnSizeChanged", function(s) ns.FitMarkX(s) end)
  end
  ns.FitMarkX(host)
  return mark
end
function ns.FitMarkX(host)
  local mark = host.wpeMarkX
  if not (mark and mark[1] and mark[2]) then return end
  local w = host:GetWidth() or 0
  if w <= 0 then return end
  local len = snapParity(host, math.sqrt(2) * w * 0.30)
  local px = ns.PX(host, host.wpeMarkW or 2)
  for i, d in ipairs(mark) do fitArm(host, d, mark.shadow[i], len, px) end
end
function ns.TintMarkX(host, key)
  local mark = host.wpeMarkX or host.wpeMarkPlus or host.wpeMarkLock or host.wpeMarkCaret
     or host.wpeMarkHelp or host.wpeMarkArrow
  if not mark then return end
  local r, g, b = Theme:C(key or "text")
  for _, d in ipairs(mark) do d:SetVertexColor(r, g, b) end
end
-- Drawn plus mark: horizontal and vertical strokes, same reason as MarkX.
-- No outline: at 2-3px a 1px rim rasterises unevenly and reads as a stray
-- pixel on one side, so the plus stays a clean bar.
function ns.MarkPlus(host, shadow)
  local mark = host.wpeMarkPlus
  if not mark then
    mark = { shadow = {} }
    addArm(mark, host, 0, shadow)
    addArm(mark, host, 90, shadow)
    -- The two strokes are never snapped to the pixel grid. The grid rounds every texture on its
    -- own, so the moment the window sits off the grid -- being dragged, or landed a fraction of a
    -- pixel away -- one bar rounds its edges out and the other rounds them in, and the arms stop
    -- being congruent: the plus reads 2px one way round and 4px the other. Left alone, both bars
    -- carry the same fractional offset and the mark stays square while the window moves, and exact
    -- the moment it lands, because the fit below already puts every edge on the grid for a box
    -- that sits on it.
    for _, d in ipairs(mark) do ns.NoPixelSnap(d) end
    for _, sh in ipairs(mark.shadow) do ns.NoPixelSnap(sh) end
    host.wpeMarkPlus = mark
    host:HookScript("OnSizeChanged", function(s) ns.FitMarkPlus(s) end)
  end
  ns.FitMarkPlus(host)
  return mark
end
function ns.FitMarkPlus(host)
  local mark = host.wpeMarkPlus
  if not (mark and mark[1] and mark[2]) then return end
  local w, h = host:GetWidth() or 0, host:GetHeight() or 0
  if w <= 0 or h <= 0 then return end
  local span = w * 0.45
  local want = ns.PX(host, host.wpeMarkW or 3)
  -- Each bar is measured on both axes: its length runs along one and its thickness across the
  -- other, and each of the two wants the parity of the box on the axis it reads (see snapParity).
  -- The thickness is asked the same question as the length, and that is the half of it the mark
  -- went without: a bar 2px thick on a box whose centre sits between two pixels has one edge
  -- rounding out and the other in, which is the 2px/4px the arms used to come out as.
  local lenX, lenY = snapParity(host, span, "x"), snapParity(host, span, "y")
  local thX, thY = snapParity(host, want, "x"), snapParity(host, want, "y")
  local u = ns.PX(host, 1)
  for i, d in ipairs(mark) do
    d:ClearAllPoints()
    d:SetPoint("CENTER", host, "CENTER", 0, 0)
    local sh = mark.shadow[i]
    if d.wpeAngle == 90 then
      d:SetSize(thX, lenY)
      -- Proud by a pixel on every side, the ends included, so the plus reads against a lit panel the
      -- same way the X's shadow carries it. Axis-aligned, never rotated: the plus bars are not either.
      if sh then sh:ClearAllPoints(); sh:SetPoint("CENTER", host, "CENTER", 0, 0); sh:SetSize(thX + 2 * u, lenY + 2 * u) end
    else
      d:SetSize(lenX, thY)
      if sh then sh:ClearAllPoints(); sh:SetPoint("CENTER", host, "CENTER", 0, 0); sh:SetSize(lenX + 2 * u, thY + 2 * u) end
    end
  end
end
-- Drawn padlock, for the same reason as the X and the plus: a mark drawn here can never be missing
-- from the font the player happened to pick, and it needs no ground built for it either, because its
-- own shadow travels with it (IconSilhouette is what an art mark needs instead).
-- Six marks and every one of them axis aligned: the four bars -- the body, the two legs of the
-- shackle and the bar that closes them at the top -- plus the two dark marks the keyhole is built
-- from. The only arc this file can draw is a turned bar (fitArm), and a turned bar is a staircase at
-- the size a header carries, where right angles stay crisp.
-- That shadow is a silhouette and not an outline: one pixel of black standing outside the shape
-- (see the shadow pass in the fit below). An outline -- a rim drawn round every bar on both of its
-- sides -- spends half of itself inside the mark, and the shackle is where it shows: the two
-- pixels between the legs fill up and the arch reads as one more solid block.
function ns.MarkLock(host, shadow)
  local mark = host.wpeMarkLock
  if not mark then
    mark = { shadow = {}, hole = {} }
    for _ = 1, 4 do
      local sh
      if shadow then
        sh = host:CreateTexture(nil, "ARTWORK")
        sh:SetDrawLayer("ARTWORK", -1)
        sh:SetColorTexture(0, 0, 0, 0.85)
        ns.NoPixelSnap(sh)
        mark.shadow[#mark.shadow + 1] = sh
      end
      local d = host:CreateTexture(nil, "ARTWORK")
      d:SetDrawLayer("ARTWORK", 0)
      d:SetColorTexture(1, 1, 1, 1)
      -- Never snapped to the pixel grid, the same call the plus makes on its two strokes: the bars
      -- carry the fractional offset the parity shift below hands them, and a grid that rounds each
      -- texture on its own would round them apart from each other and from the box.
      ns.NoPixelSnap(d)
      d.wpeShadow = sh
      mark[#mark + 1] = d
    end
    -- The keyhole, and the reason the shape reads as a padlock and not as a letter: without it the
    -- body is a closed block with an arch over it and the eye has to guess. A hole cannot be punched
    -- through a colour texture -- there is no alpha to cut away -- so these two sit over the body in
    -- the same near-black the outline bars wear, which is what the header behind the mark already is.
    -- They are kept in their own list so the ink pass (TintMarkX) never reaches them: the keyhole
    -- stays dark whatever colour the lock itself takes, the way a real hole would.
    for _ = 1, 2 do
      local d = host:CreateTexture(nil, "ARTWORK")
      -- Over the bars, since sitting on the body is the whole point of them.
      d:SetDrawLayer("ARTWORK", 1)
      d:SetColorTexture(0, 0, 0, 0.85)
      ns.NoPixelSnap(d)
      mark.hole[#mark.hole + 1] = d
    end
    host.wpeMarkLock = mark
    host:HookScript("OnSizeChanged", function(s) ns.FitMarkLock(s) end)
  end
  ns.FitMarkLock(host)
  return mark
end

-- Every measure is a whole number of physical pixels, and every one of them even: the bars are laid
-- out from the box centre, so half of an odd measure is a half pixel and would put a bar's edge
-- between two of them. Even measures keep every edge on a boundary with the centre, and the parity
-- shift below keeps them there when the box itself is an odd count of pixels across.
function ns.FitMarkLock(host)
  local mark = host and host.wpeMarkLock
  if not (mark and mark[1]) then return end
  local w, h = host:GetWidth() or 0, host:GetHeight() or 0
  if w <= 0 or h <= 0 then return end
  local u = ns.PX(host, 1)
  local bw = math.max(8, math.floor(w / u + 0.5))
  local bh = math.max(8, math.floor(h / u + 0.5))
  -- Drawn a shade inside its box rather than across it. At the box's own width the body came out as
  -- wide as the gear standing beside it and the mark read as the heaviest thing in the row; pulled
  -- in, it sits with the plus and the X instead of over them.
  local stroke = evenCount(bh * 0.075, 2)  -- what the shackle and the bar over it are drawn with
  local bodyW = evenCount(bw * 0.44, 10)
  local bodyH = evenCount(bh * 0.28, 6)
  local legH = evenCount(bh * 0.18, 4)
  -- The opening the shackle is read by, and the one measure the ground presses on. The silhouette
  -- stands a pixel proud of everything the mark is made of, so the bar above the gap and the body
  -- under it each spend one of those pixels inside the gap. A gap of two -- what the shackle had --
  -- loses both rows to them and the opening becomes a black bar, which is the shape the eye then
  -- reads as one solid block. Four leaves two whole rows of the panel showing through.
  local gapW = evenCount(bw * 0.18, 4)
  local shW = stroke * 2 + gapW
  -- The body has to stay wider than the shackle standing on it, or their edges line up and the
  -- shackle stops reading as a handle over a plate. One pixel of shoulder is what a small box can
  -- pay for that, and the width pass below takes the opening in first if even that is too much.
  bodyW = math.max(bodyW, shW + 2)
  -- A box too small for these proportions gets a smaller lock rather than one that runs over it: the
  -- opening goes first -- two pixels is still an opening -- and then the body comes in.
  while bodyW + 2 > bw - 2 and gapW > 2 do
    gapW = gapW - 2
    shW = stroke * 2 + gapW
    bodyW = math.max(bodyW, shW + 2)
  end
  while bodyW + 2 > bw - 2 and bodyW > 6 do bodyW = bodyW - 2 end
  -- A lock that can open (the pocket's) reserves headroom above the closed shackle so the body never
  -- jumps when it toggles: the shackle lifts into room that was already held empty, in both states. The
  -- badge's lock cannot open (no flag) and so reserves nothing, which keeps it byte-for-byte the shape
  -- it was. rise is one shackle-stroke and the opening it leaves above the body.
  local rise = host.wpeLockHinge and evenCount(bh * 0.14, 2) or 0
  -- What the box has to hold is the BLOCK: the closed shape with the room the opening shackle lifts
  -- into. It has to hold it with the ground on -- the ground is the mark's silhouette, a pixel proud on
  -- every side (see the shadow pass) -- so a block of bh - 2 is a block whose ground lands on the box's
  -- own edge rows, and the button paints its frame there. That is what happened at the smallest step of
  -- the pocket's header: the lock's ground painted over the bottom edge of its own square (owner, in
  -- game). A step further down the ink left the box as well, because the guard asked for bh - 3 - rise
  -- and then floored every measure: a box too small to pay for the floors kept the full-size lock and
  -- hung it outside its square.
  local block = function() return stroke + legH + bodyH + rise end
  -- So the block is fitted to the box in three passes: what the mark wants first (a clear pixel of
  -- frame all round the ground, which is how the plus and the X sit in their squares), then the clear
  -- pixel alone for a box the shape's own floors cannot come in far enough for (the ground then lands
  -- on the box's edge rows, which is inside), and the ground itself last, for a box too small even for
  -- that -- a lock badge on the smallest item cell can land at ten pixels across, where the mark is a
  -- speck and the ground is what was hanging outside. The measures give way in the order that costs the
  -- mark least: the reserved rise first (two is still room for the shackle to lift into, and the pose is
  -- what the state is read by), then the legs, then the body, then the stroke. Every step is two pixels,
  -- so the measures stay even and every edge stays on a boundary.
  local function shrink(target)
    while block() > target do
      if rise > 2 then rise = rise - 2
      elseif legH > 2 then legH = legH - 2
      elseif bodyH > 4 then bodyH = bodyH - 2
      elseif stroke > 2 then stroke = stroke - 2
      elseif bodyH > 2 then bodyH = bodyH - 2
      else break end
    end
  end
  shrink(math.max(4, bh - 4))
  if block() + 2 > bh - 2 then shrink(math.max(2, bh - 2)) end
  local GROUND = (block() + 2 <= bh) and 1 or 0
  -- The reserved rise is centred into the box with the lock, so the closed shackle sits the same whether
  -- or not the lock can open, and the body keeps its place when the shackle rises into the held room.
  local top = block() / 2 - rise
  local shiftX = (bw % 2 == 0) and 0 or 0.5
  local shiftY = (bh % 2 == 0) and 0 or 0.5
  local legX = (shW - stroke) / 2
  local bodyY = top - stroke - legH - bodyH / 2
  -- The keyhole: the round part high in the body and the slot under it, touching, so the two read as
  -- one shape. Both are an even count of pixels, the same parity the bars are held to, and one pixel
  -- of body is left above the hole and below the slot -- that margin is what makes it a hole in a
  -- plate instead of a gap splitting it.
  local holeW = evenCount(bodyW * 0.36, 2)
  local holeH = evenCount(bodyH * 0.30, 2)
  local slotW = evenCount(holeW * 0.5, 2)
  local slotH = evenCount(bodyH * 0.34, 2)
  -- A plate keeps a pixel of itself above and below what is cut out of it, or the keyhole reads as a gap
  -- splitting the plate rather than a hole in it. Six pixels of plate and up pay for both parts of the
  -- keyhole; four -- the smallest the fit takes the body to while it is a plate at all -- keep the round
  -- hole alone; and the two-pixel stub the smallest boxes end at gets no keyhole, because at that size
  -- the cut is the whole plate and the mark is read by its shackle and its body alone.
  if bodyH < 4 then holeH = 0 end
  if holeH == 0 then slotH = 0
  elseif holeH + slotH > bodyH - 2 then slotH = bodyH - 2 - holeH end
  local holeY = bodyY + bodyH / 2 - holeH / 2 - 1
  local slotY = holeY - holeH / 2 - slotH / 2
  -- The body first, then the two legs, then the bar: left and right, the legs stand at the shackle's
  -- own width and the bar spans their outer edges, so the three read as one shape over the body. The
  -- keyhole closes the list. Open (the pocket unlocked), the shackle hinges on the left: the left leg
  -- keeps its foot on the body and grows up to the raised bar, the bar lifts by the reserved rise, and
  -- the right leg hangs from the raised bar with its foot lifted clear of the body -- the universal
  -- open-padlock shape, read without any colour change.
  local legMidY = top - stroke - legH / 2
  local barY = top - stroke / 2
  local legs
  if host.wpeLockHinge and host.wpeLockOpen and rise > 0 then
    -- The shackle lifts a pixel short of the reserved headroom, so the open lock sits a touch lower in
    -- the box instead of pinned to its top edge. The body is left where the closed shape has it, so the
    -- toggle still moves nothing but the shackle.
    local lift = rise - 1
    local barHi = barY + lift
    legs = {
      { stroke, legH + lift, -legX, legMidY + lift / 2, -1, 0 },
      { stroke, legH, legX, barHi - stroke / 2 - legH / 2, 1, 0 },
      { shW, stroke, 0, barHi },
    }
  else
    legs = {
      { stroke, legH, -legX, legMidY, -1, 0 },
      { stroke, legH, legX, legMidY, 1, 0 },
      { shW, stroke, 0, barY },
    }
  end
  local parts = {
    { bodyW, bodyH, 0, bodyY },
    -- The fifth number is how far the part's ground is pushed sideways and the sixth how much it is
    -- allowed to grow (see the shadow pass).
    legs[1],
    legs[2],
    legs[3],
    { holeW, holeH, 0, holeY },
    { slotW, slotH, 0, slotY },
  }
  for i = 1, #parts do
    -- The keyhole's two marks live in a list of their own, so they take the last two entries of the
    -- parts table -- and no shadow: an outline drawn around a hole would fill it back in.
    local d = mark[i] or mark.hole[i - 4]
    local sh = (i <= 4) and mark.shadow[i] or nil
    local p = parts[i]
    if d then
      local x, y = (p[3] + shiftX) * u, (p[4] + shiftY) * u
      d:ClearAllPoints()
      d:SetPoint("CENTER", host, "CENTER", x, y)
      d:SetSize(p[1] * u, p[2] * u)
      d:SetShown(p[1] > 0 and p[2] > 0)
      if sh then
        -- The ground is the mark's silhouette, and the one rule it keeps is a pixel of it outside
        -- the shape and never a pixel inside. Grown on every side, that is what the body and the bar
        -- over the shackle get. The two legs cannot be grown that way: a pixel of theirs on the
        -- inner side lands between them and eats the opening the shackle is read by -- and the push
        -- alone, on a leg still grown, is worse, because it leaves two pixels of black hanging on
        -- the outside of each leg while the opening it was meant to save is spent anyway. They take
        -- their pixel sideways instead, the same rect moved out by one (p[6] = 0, p[5] = the push),
        -- which is a pixel of ground on the outside of each leg and none on the inside. The outer
        -- edge is then one pixel wide all the way round the mark, and the opening stays open.
        local grow = p[6] or GROUND
        sh:ClearAllPoints()
        sh:SetPoint("CENTER", host, "CENTER", x + (p[5] or 0) * u, y)
        sh:SetSize((p[1] + 2 * grow) * u, (p[2] + 2 * grow) * u)
        sh:SetShown(p[1] > 0 and p[2] > 0)
      end
    end
  end
end

-- Drawn text caret: a bar with a serif at each end, which is the shape the pointer takes over a
-- piece of editable text in every system there is. Drawn for the same reason the X, the plus and the
-- lock are -- but for one more of its own: the toggle it faces used to carry a letter, and a letter
-- says nothing at all where the alphabet is another one (the rule editor is read in Chinese and
-- Korean too, where a "T" is a shape and nothing else). The caret is furniture rather than a word:
-- nobody reads it as text in one language and as something else in another, and three rectangles of
-- the furniture this file already has are the whole of it.
function ns.MarkCaret(host, shadow)
  local mark = host.wpeMarkCaret
  if not mark then
    mark = { shadow = {} }
    -- Three marks: the bar and the two serifs that cap it.
    for _ = 1, 3 do
      local sh
      if shadow then
        sh = host:CreateTexture(nil, "ARTWORK")
        sh:SetDrawLayer("ARTWORK", -1)
        sh:SetColorTexture(0, 0, 0, 0.85)
        ns.NoPixelSnap(sh)
        mark.shadow[#mark.shadow + 1] = sh
      end
      local d = host:CreateTexture(nil, "ARTWORK")
      d:SetDrawLayer("ARTWORK", 0)
      d:SetColorTexture(1, 1, 1, 1)
      ns.NoPixelSnap(d)
      d.wpeShadow = sh
      mark[#mark + 1] = d
    end
    host.wpeMarkCaret = mark
    host:HookScript("OnSizeChanged", function(s) ns.FitMarkCaret(s) end)
  end
  ns.FitMarkCaret(host)
  return mark
end

-- The bar stands on the box centre and the two serifs cap it, each of them drawn at the bar's own
-- end rather than past it, so the three read as one piece of furniture: a bar with a foot and a head.
-- Every measure comes from snapParity, which asks the box and hands back a measure of that box's own
-- parity -- so on a box of an odd count of pixels across, where the centre sits between two of them,
-- the bar comes out that one pixel wider and every edge still lands on a boundary.
function ns.FitMarkCaret(host)
  local mark = host and host.wpeMarkCaret
  if not (mark and mark[1]) then return end
  local w, h = host:GetWidth() or 0, host:GetHeight() or 0
  if w <= 0 or h <= 0 then return end
  local u = ns.PX(host, 1)
  local t = snapParity(host, h * 0.09, "y")        -- the bar, and the serifs with it
  local len = snapParity(host, h * 0.55, "y")      -- how far the bar stands
  -- A box short of the caret's own height gets a shorter bar rather than one running over the edge.
  while len > 4 * u and len + 2 * u > h - 2 * u do len = len - 2 * u end
  local capW = snapParity(host, w * 0.27, "x")
  local capY = len / 2 - t / 2
  -- [width, height, x, y], the bar first and then the serif at each end of it.
  local parts = {
    { t, len, 0, 0 },
    { capW, t, 0, capY },
    { capW, t, 0, -capY },
  }
  for i, d in ipairs(mark) do
    local p = parts[i]
    d:ClearAllPoints()
    d:SetPoint("CENTER", host, "CENTER", p[3], p[4])
    d:SetSize(p[1], p[2])
    d:Show()
    local sh = mark.shadow[i]
    if sh then
      -- A pixel of ground on every side, the ends included, the same rule the plus and the lock
      -- follow. The serifs stand wide enough that the bar's own ground is hidden behind them at the
      -- two ends, so the band that reads is the one around the whole caret and nothing else.
      sh:ClearAllPoints()
      sh:SetPoint("CENTER", host, "CENTER", p[3], p[4])
      sh:SetSize(p[1] + 2 * u, p[2] + 2 * u)
      sh:Show()
    end
  end
end

-- Drawn question mark, for the same reason the X, the plus, the lock and the caret are drawn: it is
-- furniture of the addon and not a glyph out of whatever font the player picked, so it is the same
-- shape on every client and at every ui scale, and it wears its own ground instead of borrowing the
-- outline the font gave a string.
-- Every stroke is axis aligned and a whole count of physical pixels wide, and no two parts of it meet
-- at a corner: the bar over the bowl carries the leg that hangs under its left end and the side that
-- comes down under its right one, two steps bring the tail back to the centre column, and the dot sits
-- below the whole of it with a gap of its own. Corner-to-corner is how a pixel font draws a curve, and
-- it works there because every cell of the glyph is flat ink; here each part stands on its own pixel of
-- ground, so a mark whose parts met at corners reads as a row of separate blocks -- the shape this one
-- was drawn badly as the first time. The bowl is four strokes wide and the leg stands two strokes
-- deep, which is what leaves an opening inside it rather than a slot: the earlier mark carried its bar
-- over the whole five-stroke width of the glyph, and a bar that wide over a bowl that narrow is a
-- plate with a hole in it, not a hook.
function ns.MarkHelp(host, shadow)
  local mark = host.wpeMarkHelp
  if not mark then
    mark = { shadow = {} }
    for _ = 1, 6 do
      local sh
      if shadow then
        sh = host:CreateTexture(nil, "ARTWORK")
        sh:SetDrawLayer("ARTWORK", -1)
        sh:SetColorTexture(0, 0, 0, 0.85)
        mark.shadow[#mark.shadow + 1] = sh
      end
      local d = host:CreateTexture(nil, "ARTWORK")
      d:SetDrawLayer("ARTWORK", 0)
      d:SetColorTexture(1, 1, 1, 1)
      d.wpeShadow = sh
      mark[#mark + 1] = d
    end
    host.wpeMarkHelp = mark
    host:HookScript("OnSizeChanged", function(s) ns.FitMarkHelp(s) end)
  end
  ns.FitMarkHelp(host)
  return mark
end

-- The glyph is four strokes wide and eight tall, and the stroke is the one measure all of it follows:
-- every offset is a whole multiple of half of one and every part is one, two, three or four, which is
-- what keeps the whole mark on the pixel grid through the parity shift below. A box that cannot pay
-- for that at this thickness gets a thinner stroke, and one that cannot even for that loses the dot
-- and comes down to the hook -- which still reads as the mark, where a mark running over the edge of
-- its button does not.
function ns.FitMarkHelp(host)
  local mark = host and host.wpeMarkHelp
  if not (mark and mark[1]) then return end
  local w, h = host:GetWidth() or 0, host:GetHeight() or 0
  if w <= 0 or h <= 0 then return end
  local u = ns.PX(host, 1)
  local bw = math.max(8, math.floor(w / u + 0.5))
  local bh = math.max(8, math.floor(h / u + 0.5))
  local stroke = evenCount(bh * 0.09, 2)
  -- Eight strokes and the pixel of ground above and below them are what the glyph needs of the box.
  while stroke > 2 and (8 * stroke + 2 > bh - 2 or 4 * stroke + 2 > bw - 2) do stroke = stroke - 2 end
  local full = 8 * stroke + 2 <= bh - 2
  -- With the dot gone the hook sits high in its box, so the rest of the glyph comes down by a stroke
  -- and the mark stays centred on the plate it is drawn on.
  local drop = full and 0 or -stroke
  local parts = {
    { 4 * stroke, stroke, 0, 3.5 * stroke + drop },            -- the bar over the bowl
    { stroke, 2 * stroke, -1.5 * stroke, 2 * stroke + drop },  -- the leg under its left end
    { stroke, 3 * stroke, 1.5 * stroke, 1.5 * stroke + drop }, -- the side under its right one
    { 2 * stroke, stroke, stroke, -0.5 * stroke + drop },      -- the tail's first step to the centre
    { 2 * stroke, stroke, 0, -1.5 * stroke + drop },           -- and the second, under the first
  }
  if full then parts[#parts + 1] = { 2 * stroke, stroke, 0, -3.5 * stroke } end  -- the dot
  local shiftX = (bw % 2 == 0) and 0 or 0.5
  local shiftY = (bh % 2 == 0) and 0 or 0.5
  for i, d in ipairs(mark) do
    local p = parts[i]
    if p then
      local x, y = (p[3] + shiftX) * u, (p[4] + shiftY) * u
      d:ClearAllPoints()
      d:SetPoint("CENTER", host, "CENTER", x, y)
      d:SetSize(p[1] * u, p[2] * u)
      d:Show()
      local sh = mark.shadow[i]
      if sh then
        -- A pixel of ground on every side, the ends included, the same rule the other drawn marks
        -- follow. The bowl's ground eats one of the pixels inside its own opening from every side, the
        -- way the shackle's does, and the four that are left are what the hook is read by. The parts
        -- of the tail share their edges with the side above them and with each other, so the grounds
        -- they lay over one another are hidden behind the ink and the band that reads is the one
        -- around the whole shape and nothing else.
        sh:ClearAllPoints()
        sh:SetPoint("CENTER", host, "CENTER", x, y)
        sh:SetSize((p[1] + 2) * u, (p[2] + 2) * u)
        sh:Show()
      end
    else
      d:Hide()
      if mark.shadow[i] then mark.shadow[i]:Hide() end
    end
  end
end

-- Drawn down-arrow (the clean-up / sort action), for the same reason as the X, the plus and the lock:
-- a mark drawn here can never be missing from the font the player picked, and it carries its own ground.
-- The head is a stack of 1px-tall bars whose width grows by two a row -- the staircase a pixel font draws
-- a 45-degree edge as, and the only diagonal this file makes without turning a bar. The stem is one
-- vertical bar from a row inside the head up to the top. Each white part grows a 1px silhouette on every
-- side, the lock's rule, and the parts share edges so the grounds merge into one outline.
-- The head's row count follows the box, so the textures are pooled and reused per fit, not made once like
-- the lock's four: a fit shows the ones it used and hides the rest. The ink lives in mark's own array so
-- TintMarkX and ShowMark reach it over ipairs, exactly as the lock's bars do.
function ns.MarkArrow(host, shadow)
  local mark = host.wpeMarkArrow
  if not mark then
    mark = { shadow = {} }
    mark.wantShadow = shadow and true or false
    host.wpeMarkArrow = mark
    host:HookScript("OnSizeChanged", function(s) ns.FitMarkArrow(s) end)
  end
  ns.FitMarkArrow(host)
  return mark
end

-- One pooled texture of a layer, made on first need. The ink pool IS mark (numeric keys), so the tint and
-- show passes walk it with ipairs; the shadow pool is mark.shadow, which ShowMark already walks. No
-- NoPixelSnap: like the question mark, the many overlapping grounds must round to the grid together, or a
-- window landed off the grid rounds them apart and the outline frays. (The plus keeps snap off for the
-- opposite reason -- two congruent bars that must share one fractional offset -- but a stack of grounds is
-- the help mark's case, not the plus'.)
local function arrowPool(host, mark, layer, i)
  local pool = (layer == "shadow") and mark.shadow or mark
  local t = pool[i]
  if not t then
    t = host:CreateTexture(nil, "ARTWORK")
    if layer == "shadow" then
      t:SetDrawLayer("ARTWORK", -1); t:SetColorTexture(0, 0, 0, 0.85)
    else
      t:SetDrawLayer("ARTWORK", 0); t:SetColorTexture(1, 1, 1, 1)
    end
    pool[i] = t
  end
  return t
end

-- Every measure is a whole count of physical pixels. The footprint matches the atlas arrow this replaces
-- (it sat at 58% of the box wide, 66% tall), so the drawn mark drops into the header at the same weight
-- and stands level with the lock and the gear. The head is even-wide so its tip lands on the box centre
-- column; the parity shift keeps every edge on the grid when the box is an odd count across.
function ns.FitMarkArrow(host)
  local mark = host and host.wpeMarkArrow
  if not mark then return end
  local w, h = host:GetWidth() or 0, host:GetHeight() or 0
  if w <= 0 or h <= 0 then return end
  local u = ns.PX(host, 1)
  local bw = math.max(8, math.floor(w / u + 0.5))
  local bh = math.max(8, math.floor(h / u + 0.5))

  local headW = evenCount(bw * 0.34, 6)
  if headW > bw - 2 then headW = headW - 2 end
  local rows = headW / 2                         -- widths 2,4,...,headW over `rows` rows -> 45-degree sides
  local height = evenCount(bh * 0.40, rows + 2)  -- total height, floored so a little stem always clears the head
  if height > bh - 2 then height = height - 2 end
  local halfH = height / 2
  local stemW = evenCount(bw * 0.14, 2)

  local shiftX = (bw % 2 == 0) and 0 or 0.5
  local shiftY = (bh % 2 == 0) and 0 or 0.5

  local ni, ng = 0, 0
  local function place(wd, ht, x, y)
    ni = ni + 1
    local d = arrowPool(host, mark, "ink", ni)
    d:ClearAllPoints()
    d:SetPoint("CENTER", host, "CENTER", (x + shiftX) * u, (y + shiftY) * u)
    d:SetSize(wd * u, ht * u); d:Show()
    if mark.wantShadow then
      ng = ng + 1
      local sh = arrowPool(host, mark, "shadow", ng)
      sh:ClearAllPoints()
      sh:SetPoint("CENTER", host, "CENTER", (x + shiftX) * u, (y + shiftY) * u)
      sh:SetSize((wd + 2) * u, (ht + 2) * u); sh:Show()
    end
  end

  -- Head: row 0 is the tip (narrow, at the bottom), the last row is the widest (the shoulders). y runs up
  -- from the box centre, so the tip sits at -halfH and the head climbs from there.
  for r = 0, rows - 1 do
    place(2 + 2 * r, 1, 0, -halfH + 0.5 + r)
  end
  -- Stem: from one row up into the head (so it overlaps and the grounds merge) to the top edge.
  local stemBottom = (-halfH + rows) - 1
  local stemTop = halfH
  place(stemW, stemTop - stemBottom, 0, (stemTop + stemBottom) / 2)

  for i = ni + 1, #mark        do mark[i]:Hide() end
  for i = ng + 1, #mark.shadow do mark.shadow[i]:Hide() end
end

function ns.ShowMark(host, on)
  local mark = host.wpeMarkX or host.wpeMarkPlus or host.wpeMarkLock or host.wpeMarkCaret
     or host.wpeMarkHelp or host.wpeMarkArrow
  if not mark then return end
  on = on and true or false
  for _, d in ipairs(mark) do d:SetShown(on) end
  if mark.shadow then for _, sh in ipairs(mark.shadow) do sh:SetShown(on) end end
  if mark.hole then for _, d in ipairs(mark.hole) do d:SetShown(on) end end
end

-- The dark ground a header mark is read against. Text gets one from the font's own outline
-- (ns.OutlineFlags) and the drawn marks from their shadow bars, but a texture has neither -- and of
-- the header's six art marks only the two whose atlas carries a shadow baked into it (bag-main,
-- bags-icon-reagents) had any ground at all, so the remaining four sat flat on the band beside a
-- row of outlined marks. This is the same separator the marks wear, drawn under an icon: a black
-- copy of the icon's own art, one pixel proud on every side.
-- The copy takes the icon's alpha on every repaint, so a dimmed mark (the sell coin at rest) dims
-- its ground with it and neither can go see-through on its own; the icon's art is never touched, so
-- the mark keeps its own colours. It is tied to the icon's centre rather than to a point in the
-- button, so whatever moves or resizes the art carries the ground along -- and a wrapper around the
-- paint the host already runs is the whole wiring, which means no call site needs a second hook.
function ns.IconSilhouette(host, icon)
  if not (host and icon) then return end
  local sh = host.wpeIconShadow
  if not sh then
    sh = host:CreateTexture(nil, "ARTWORK")
    sh:SetDrawLayer("ARTWORK", -1)
    sh:SetColorTexture(0, 0, 0, 0.85)
    host.wpeIconShadow = sh
    local atlas = icon.GetAtlas and icon:GetAtlas()
    if atlas then
      sh:SetAtlas(atlas, false)
    else
      local file = icon:GetTexture()
      if file then sh:SetTexture(file) else sh:Hide() end
    end
    -- The art assignment above replaces the black fill, so the copy is
    -- blackened back here: without this the "silhouette" is a full-colour
    -- duplicate peeking out, which reads as a lit rim (the sell coin looked
    -- active at rest for exactly this reason).
    sh:SetVertexColor(0, 0, 0)
    sh:SetAlpha(icon:GetAlpha())
    sh:SetPoint("CENTER", icon, "CENTER")
    local paint = host.wpeIconPaint
    host.wpeIconPaint = function(s)
      if paint then paint(s) end
      sh:SetAlpha(icon:GetAlpha())
      ns.FitIconShadow(s)
    end
    host:HookScript("OnSizeChanged", function(s) ns.FitIconShadow(s) end)
  end
  ns.FitIconShadow(host)
  return sh
end

-- Proud of the art on every side, the ends included, the way the marks' bars grow over their
-- strokes. The size is put back on the pixel grid after the growth: an odd icon plus two physical
-- pixels is not a whole number of pixels, and a copy left between two of them is a grey edge the
-- mark around it does not have.
function ns.FitIconShadow(host)
  local sh = host and host.wpeIconShadow
  local icon = host and host.icon
  if not (sh and icon) then return end
  local w, h = icon:GetWidth() or 0, icon:GetHeight() or 0
  if w <= 0 or h <= 0 then return end
  local u = ns.PX(host, 1)
  sh:SetSize(ns.SnapValue(host, w + 2 * u), ns.SnapValue(host, h + 2 * u))
end

function ns.CreateGlyphButton(parent, glyph, size, dark)
  local b = ns.CreateButton(parent, glyph, size or 22, size or 22, nil, dark)
  -- The face is handed over as a file and never as a font object. A string that rides an
  -- object goes on drawing the face that object held when its text was written, so a font
  -- picked in the settings reached these buttons only after a reload: GetFont answered with
  -- the new file while the mark on screen stayed in the old one. This is the dress at
  -- creation; the size pass over the header applies the file again on every font change,
  -- which is what keeps the mark in step with the rest of the window. Repaint puts the ink
  -- back, since a face change can take the colour with it.
  b.Text:SetFont(ns.Fonts:Current(), math.max(16, math.floor((size or 22) * 0.74)), ns.OutlineFlags())
  b:Repaint()
  if glyph == "×" or glyph == "+" or glyph == "lock" or glyph == "?" or glyph == "arrow" then
    b.Text:SetText("")
    if glyph == "lock" then ns.MarkLock(b, true)
    elseif glyph == "+" then ns.MarkPlus(b, true)
    elseif glyph == "?" then ns.MarkHelp(b, true)
    elseif glyph == "arrow" then ns.MarkArrow(b, true)
    else ns.MarkX(b) end
    -- The hover shows in the box edge (SetEdge above), never in the mark ink: a cross or a plus kept its
    -- colour under the pointer instead of flashing accent, which read as the mark being painted over. The
    -- rest colour is the state's -- faint when off duty, the window's own ink otherwise.
    b.wpeIconPaint = function(s)
      ns.TintMarkX(s, s.offDuty and "faint" or ((dark == true or dark == "icon") and "overlay" or "text"))
    end
    b.wpeIconPaint(b)
  end
  return b
end

-- A header row is chained button to button, and a hidden frame keeps its points, so a
-- gap stays where it was. Re-chain the row through the shown ones only and hand back the
-- last one, which is the left edge whatever is hidden.
function ns.FlowRow(host, x, y, gap, list)
  local prev
  for _, b in ipairs(list) do
    if b and b:IsShown() then
      b:ClearAllPoints()
      if prev then
        ns.SnapPoint(b, "TOPRIGHT", prev, "TOPLEFT", -(gap or 4), 0)
      else
        ns.SnapPoint(b, "TOPRIGHT", host, "TOPRIGHT", x, y)
      end
      prev = b
    end
  end
  return prev
end

local function boxTex(box, layer)
  local t = box:CreateTexture(nil, layer or "BORDER")
  t:SetColorTexture(1, 1, 1, 1)
  return t
end

function ns.CreateCheckBox(parent, side)
  local box = CreateFrame("Frame", nil, parent)
  ns.SnapBox(box, side or 18, side or 18, true)
  local fill = boxTex(box, "BACKGROUND")
  fill:SetAllPoints(box)
  local mark = boxTex(box, "ARTWORK")
  mark:SetAllPoints(box)
  mark:Hide()
  local e = {}
  e[1] = boxTex(box, "OVERLAY"); e[1]:SetPoint("TOPLEFT");    e[1]:SetPoint("TOPRIGHT");    ns.PixelLine(e[1], 1)
  e[2] = boxTex(box, "OVERLAY"); e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); ns.PixelLine(e[2], 1)
  e[3] = boxTex(box, "OVERLAY"); e[3]:SetPoint("TOPLEFT");    e[3]:SetPoint("BOTTOMLEFT");  ns.PixelLine(e[3], 1, "w")
  e[4] = boxTex(box, "OVERLAY"); e[4]:SetPoint("TOPRIGHT");   e[4]:SetPoint("BOTTOMRIGHT"); ns.PixelLine(e[4], 1, "w")
  box.fill, box.edges, box.mark = fill, e, mark
  box.fillKey, box.edgeKey, box.markKey = "slot", "stroke", "accent"
  box.Repaint = function(s)
    s.fill:SetVertexColor(Theme:C(s.fillKey))
    for _, x in ipairs(s.edges) do x:SetVertexColor(Theme:C(s.edgeKey)) end
    s.mark:SetVertexColor(Theme:C(s.markKey))
  end
  box.SetKeys = function(s, fillKey, edgeKey, markKey)
    s.fillKey = fillKey or s.fillKey
    s.edgeKey = edgeKey or s.edgeKey
    s.markKey = markKey or s.markKey
    s:Repaint()
  end
  ns.PixelJob(box, function(s) s:Repaint() end, "checkbox")
  Theme:Track(box, function(s) s:Repaint() end)
  return box
end

function ns.CreateTextButton(parent, size)
  local b = CreateFrame("Button", nil, parent)
  local fs = b:CreateFontString(nil, "OVERLAY")
  fs:SetFontObject(ns.Fonts:Object(size or 10, ns.OutlineFlags()))
  fs:SetPoint("CENTER")
  b.Text = fs
  b.Paint = function(s)
    local key = (not s.wpeOn and "faint") or (s.wpeHot and "accent") or "azure"
    s.Text:SetTextColor(Theme:C(key))
  end
  b.SetOn = function(s, on)
    s.wpeOn = on and true or nil
    s:Paint()
  end
  b:SetScript("OnEnter", function(s) s.wpeHot = true; s:Paint() end)
  b:SetScript("OnLeave", function(s) s.wpeHot = nil; s:Paint() end)
  Theme:Track(b, function(s) s:Paint() end)
  b:Paint()
  return b
end

local linkBoxes = {}

-- Link insertion rides the game's dispatcher. Since the chat frame rework the item
-- modified click goes through ChatFrameUtil.InsertLink, which hands the link to
-- whichever frame it knows about: the macro editor, the professions search, the
-- communities chat, the chat itself, the auction house. The old global
-- ChatEdit_InsertLink is no longer called on that path, so the hook sits on the new
-- one and keeps the old global as a fallback. Both are hooksecurefunc: the game's
-- function runs first and untouched, ours only reads its argument afterwards.
local function linkInto(text)
  if type(text) ~= "string" then return false end
  for _, box in ipairs(linkBoxes) do
    if box:IsVisible() and box:HasFocus() then
      local out
      if box.wpeLinkID then
        -- The bare numeric item id: the only id-mode box (the category pin adder) is numeric, so it takes
        -- the number itself, not the item:… string a shift-click carries.
        local link = text:match("|H(item:[^|]+)|h") or text:match("^(item:[^|%s]+)")
        out = link and link:match("^item:(%d+)")
      else
        out = text:match("%[(.-)%]")
      end
      if not out or out == "" then return false end
      box:SetText(out)
      return true
    end
  end
  return false
end

if ChatFrameUtil and ChatFrameUtil.InsertLink then
  hooksecurefunc(ChatFrameUtil, "InsertLink", linkInto)
end
if ChatEdit_InsertLink then
  hooksecurefunc("ChatEdit_InsertLink", linkInto)
end

-- Register any edit box built outside CreateSearchBox to take a shift-clicked item link off the same
-- dispatcher. idMode true hands the box the bare item:... string, for a caller that wants the id;
-- false the bracketed name, like the search boxes. The category pin adder uses the id mode so a
-- shift-click on a bag item files it, no id typed by hand.
function ns.RegisterLinkBox(box, idMode)
  box.wpeLinkID = idMode and true or nil
  linkBoxes[#linkBoxes + 1] = box
end

function ns.CreateSearchBox(parent, onChanged, hintKey)
  local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
  ns.SnapBox(box, nil, 22)
  ns.PixelBackdrop(box)
  ns.SetBg(box, Theme:C(Theme:IsLight() and "slot" or "bg"))
  ns.SetEdge(box, Theme:C("stroke"))
  Theme:Track(box, function(s)
    ns.SetBg(s, Theme:C(Theme:IsLight() and "slot" or "bg"))
    s:SetTextColor(Theme:C("text"))
    if not s:HasFocus() then ns.SetEdge(s, Theme:C("stroke")) end
  end)
  box:SetFont(ns.Fonts:Current(), 13, ns.OutlineFlags())
  box:SetTextColor(Theme:C("text"))
  box:SetTextInsets(8, 8, 0, 0)
  box:SetAutoFocus(false)

  local hint = Theme:Label(box, 13, "dim")
  hint:SetPoint("LEFT", 8, 0)
  ns.LocalText(hint, hintKey or "Search")
  box.Hint = hint

  local function refreshHint(s) hint:SetShown(s:GetText() == "") end
  box:SetScript("OnTextChanged", function(s)
    refreshHint(s)
    if onChanged then onChanged(s:GetText()) end
  end)
  box:SetScript("OnEditFocusGained", function(s) ns.SetEdge(s, Theme:C("accent")) end)
  box:SetScript("OnEditFocusLost", function(s) ns.SetEdge(s, Theme:C("stroke")); refreshHint(s) end)
  box:SetScript("OnEscapePressed", function(s) s:SetText(""); s:ClearFocus() end)
  box:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
  linkBoxes[#linkBoxes + 1] = box
  return box
end

-- An item-id field: a number box that takes nothing but digits, and a live preview of the item the id
-- names — its icon, then its name — so what was typed is seen to resolve before it is committed. The "+"
-- plate beside the preview is the same "add one of these" control the racks lead with, and Enter does the
-- same thing; a shift-clicked item link lands as its bare id (RegisterLinkBox above). Two callers read it,
-- the category editor's pin entry and the pocket's picks panel, and it is written once here so the two
-- cannot drift into two different fields.
--
-- opts:
--   hint      localized key of the empty-state hint, which owns the field until a digit lands
--   height    height of the number box; the frame stands 6 taller
--   boxWidth  width of the number box
--   font      size of the number itself
--   smallFont size of the hint and of the name beside the icon (default: one less than font)
--   onCommit  function(id), called by Enter and by the "+" with an id that resolved
function ns.CreateIdField(parent, opts)
  opts = opts or {}
  local boxW = opts.boxWidth or 56
  local boxH = opts.height or 22
  local numSize = opts.font or 14
  local small = opts.smallFont or (numSize - 1)

  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  ns.SnapBox(f, nil, boxH + 6)
  ns.PixelBackdrop(f)
  -- The whole field carries a field/drop-zone border, so at rest it reads as "put something here" rather
  -- than as a bare label: it brightens on hover and while a piece rides the cursor, the two ways in.
  local function paint(s)
    local live = s.wpeHot or s.wpeDrag
    ns.SetBg(s, Theme:C(live and "panelHi" or "bg"))
    local er, eg, eb = Theme:C(live and "accent" or "strokeSoft")
    ns.SetEdge(s, er, eg, eb, live and 1 or 0.6)
  end
  f.Repaint = paint
  paint(f)
  Theme:Track(f, paint)
  f:EnableMouse(true)
  f:SetScript("OnEnter", function(s) s.wpeHot = true; paint(s) end)
  f:SetScript("OnLeave", function(s) s.wpeHot = nil; paint(s) end)
  -- The number box is only as wide as the digits need, so a click anywhere else on the field
  -- would land on the frame and never reach it: hand the focus over instead.
  f:SetScript("OnMouseDown", function(s, btn) if btn == "LeftButton" then s.box:SetFocus() end end)

  -- Left: the number box, borderless — the frame is the field, this is only where the digits land. Numeric,
  -- so a stray letter never sits in a field that means an item id, and the preview never eats the width the
  -- typed number needs.
  local box = CreateFrame("EditBox", nil, f)
  box:SetPoint("LEFT", 10, 0)
  box:SetWidth(boxW)
  box:SetHeight(boxH)
  box:SetFont(ns.Fonts:Current(), numSize, ns.OutlineFlags())
  box:SetTextColor(Theme:C("text"))
  box:SetAutoFocus(false)
  box:SetNumeric(true)
  box:SetMaxLetters(6)
  f.box = box

  -- One empty-state hint that names the way in, spanning the field so a long translation has room: it owns
  -- the field until a digit lands.
  local ph = Theme:Label(f, small, "faint")
  ph:SetPoint("LEFT", box, "LEFT", 0, 0)
  ph:SetPoint("RIGHT", f, "RIGHT", -8, 0)
  ph:SetJustifyH("LEFT")
  ph:SetWordWrap(false)
  ns.LocalText(ph, opts.hint or "Add ID")
  f.hint = ph

  -- The hairline shows only once something is typed: while the field is empty the hint owns the whole
  -- width, so a divider mid-hint would read as a break in the sentence.
  local div = Theme:Rect(f, "strokeSoft", "ARTWORK")
  ns.PixelLine(div, 1, "w")
  div:SetPoint("TOPLEFT", box, "TOPRIGHT", 6, -2)
  div:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 6, 2)
  div:Hide()
  f.div = div

  -- Right of the divider: the live preview of the item the id names — its icon, then its name. Empty until
  -- a valid id resolves.
  local ic = f:CreateTexture(nil, "ARTWORK")
  ic:SetPoint("LEFT", box, "RIGHT", 14, 0)
  ns.SnapSize(ic, boxH - 6, boxH - 6)
  ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  ic:Hide()
  f.ic = ic
  local name = Theme:Label(f, small, "text")
  name:SetPoint("LEFT", ic, "RIGHT", 5, 0)
  name:SetPoint("RIGHT", -30, 0)
  name:SetJustifyH("LEFT")
  name:SetWordWrap(false)
  name:Hide()
  f.name = name

  -- The commit control, lit once the id resolves. A "+" plate, the same "add one" affordance the rule row
  -- and the rack lead with, so it reads without a glyph the addon font may not carry.
  local ok = ns.CreateGlyphButton(f, "+", 16)
  -- 2px arms. The 16px plate is even, so snapParity keeps an even arm clean at 2 (an odd 3 would round up
  -- to 4 on this plate -- the symmetry trap the chip-add plus dodges with an odd plate).
  ok.wpeMarkW = 2
  ns.FitMarkPlus(ok)
  ns.SnapPoint(ok, "RIGHT", f, "RIGHT", -3, 0)
  ok:Hide()
  f.ok = ok

  -- Hidden ruler in the number's own font: the box grows with the typed digits, so the first
  -- ones never scroll out of sight while the preview still owns the width beside it.
  local measure = Theme:Label(f, numSize, "text")
  measure:Hide()

  local function fitBox()
    measure:SetText(box:GetText() or "")
    local want = measure:GetStringWidth() + 14
    local room = (f:GetWidth() or 0) - 110
    if room < boxW then room = boxW end
    if want < boxW then want = boxW end
    if want > room then want = room end
    box:SetWidth(want)
  end

  local function preview()
    local text = box:GetText() or ""
    fitBox()
    local id = tonumber(text)
    if not id and text ~= "" then id = C_Item.GetItemInfoInstant(text) end
    local empty = text == ""
    ph:SetShown(empty)
    div:SetShown(not empty)
    if id and id > 0 then
      local tex = ns.PinIcon(id)
      local nm = ns.PinName(id)
      if tex and nm then
        ic:SetTexture(tex); ic:Show()
        name:SetText(nm); name:Show()
        ok:Show()
        f.wpeId = id
        return
      end
    end
    -- Nothing valid yet: no icon, no name, no tick.
    ic:Hide(); name:Hide(); ok:Hide()
    f.wpeId = nil
  end
  f.Preview = preview

  local function commit()
    local id = f.wpeId
    if id and opts.onCommit then opts.onCommit(id) end
    box:SetText(""); box:ClearFocus(); preview()
  end
  f.Commit = commit
  box:SetScript("OnTextChanged", preview)
  box:SetScript("OnEnterPressed", commit)
  box:SetScript("OnEscapePressed", function(s) s:SetText(""); s:ClearFocus(); preview() end)
  ok:SetScript("OnClick", commit)
  ns.RegisterLinkBox(box, true)

  -- The face travels with the call: a pin entry is rebuilt with its page, but the pocket's panel is not, so
  -- the pocket hands its density font through on every paint.
  f.ApplyFont = function(s, path, num, sm)
    numSize, small = num or numSize, sm or small
    local fp = path or ns.Fonts:Current()
    box:SetFont(fp, numSize, ns.OutlineFlags())
    measure:SetFont(fp, numSize, ns.OutlineFlags())
    ph:SetFont(fp, small, ns.OutlineFlags())
    name:SetFont(fp, small, ns.OutlineFlags())
    fitBox()
  end
  -- The box height again, for a caller whose density moves: the pocket's panel is laid out on every paint
  -- and its step changes with the pocket's size, so the frame and the preview icon follow the box.
  f.SetBoxHeight = function(s, h)
    boxH = h
    box:SetHeight(h)
    ns.SnapSize(ic, h - 6, h - 6)
    ns.SnapBox(s, nil, h + 6)
  end
  return f
end

function ns.MirrorSearch(from, text)
  if ns.searchSyncing then return end
  if not (WarpeeDB and WarpeeDB.searchLink) then return end
  local B, K = ns.Bags, ns.Bank
  local other
  if from == "bags" then
    other = K and K.frame and K.frame:IsShown() and K.search
  else
    other = B and B.frame and B.frame:IsShown() and B.search
  end
  if not other then return end
  text = text or ""
  if other:GetText() == text then return end
  ns.searchSyncing = true
  other:SetText(text)
  ns.searchSyncing = false
end

function ns.ClearSearch(box)
  if not (box and WarpeeDB and WarpeeDB.searchClear) then return end
  if box:GetText() == "" then return end
  box:SetText("")
  box:ClearFocus()
end
