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
    local ink = hot and "accent" or (s.offDuty and "faint" or (lightInk and "overlay" or "text"))
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
    local hot = p and p.wpeHot and not p.offDuty
    local key = hot and "accent" or ((p and p.offDuty) and "faint" or (lightInk and "overlay" or "text"))
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
        out = text:match("|H(item:[^|]+)|h") or text:match("^(item:[^|%s]+)")
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
