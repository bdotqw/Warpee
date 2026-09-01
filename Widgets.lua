local addonName, ns = ...
local Theme = ns.Theme

local CLASS_RING = "Interface\\TargetingFrame\\UI-Classes-Circles"

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
  b:SetBackdropColor(Theme:C("panel"))
  b:SetBackdropBorderColor(Theme:C("stroke"))
  Theme:Track(b, function(x)
    x:SetBackdropColor(Theme:C("panel")); x:SetBackdropBorderColor(Theme:C("stroke"))
  end)

  local side = (dir == "left" or dir == "right")
  local caret = ns.ArrowGlyph(b, side and dir or "down", side and 11 or 8)
  b.caret = caret

  local ic = b:CreateTexture(nil, "ARTWORK")
  ic:SetSize(14, 14)
  ic:SetTexture(CLASS_RING)
  b.icon = ic

  local fs = Theme:Label(b, 12, "text")
  fs:SetJustifyH("LEFT")
  b.Text = fs

  if dir == "left" then
    caret:SetPoint("LEFT", PADX, 0)
    ic:SetPoint("LEFT", caret, "RIGHT", GAP, 0)
    fs:SetPoint("LEFT", ic, "RIGHT", GAP, 0)
    fs:SetPoint("RIGHT", -PADX, 0)
  else
    ic:SetPoint("LEFT", PADX, 0)
    fs:SetPoint("LEFT", ic, "RIGHT", GAP, 0)
    caret:SetPoint("RIGHT", -PADX, 0)
    fs:SetPoint("RIGHT", caret, "LEFT", -GAP, 0)
  end
  local function caretColor(k) b.caret:SetTint(k) end
  b:SetScript("OnEnter", function(s)
    s:SetBackdropColor(Theme:C("panelHi"))
    s:SetBackdropBorderColor(Theme:C("accent"))
    caretColor("accent")
  end)
  b:SetScript("OnLeave", function(s)
    s:SetBackdropColor(Theme:C("panel"))
    s:SetBackdropBorderColor(Theme:C("stroke"))
    caretColor("dim")
  end)
  return b
end

function ns.PaintCharTag(b, name, class)
  if not b then return end
  local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
  if coords then
    b.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4]); b.icon:Show()
  else
    b.icon:Hide()
  end
  b.Text:SetText(name or "?")
  local col = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if col then b.Text:SetTextColor(col.r, col.g, col.b) else b.Text:SetTextColor(Theme:C("text")) end
  local caret = math.ceil((b.caret and b.caret:GetWidth()) or 8)
  if caret <= 0 then caret = 8 end
  local extra = 8 + 14 + 6 + 6 + 8 + caret + 2
  b:SetWidth(math.max(78, math.ceil(b.Text:GetStringWidth()) + extra))
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
  frame:StartMoving()
  frame.wpeMoving = true
end

local moveBars = {}

local function barArrow(bar, dir, fn)
  local b = CreateFrame("Button", nil, bar)
  ns.SnapBox(b, 16, 16)
  local glyph = ns.ArrowGlyph(b, dir, 11)
  glyph:SetPoint("CENTER")
  b:SetScript("OnEnter", function(s) s.hover = true; glyph:SetTint("accent") end)
  b:SetScript("OnLeave", function(s) s.hover = nil; glyph:SetTint("dim") end)
  b:SetScript("OnClick", function() fn(IsShiftKeyDown() and 10 or 1) end)
  return b
end

local function barField(bar, apply)
  local e = CreateFrame("EditBox", nil, bar, "BackdropTemplate")
  ns.SnapBox(e, 40, 16)
  ns.PixelBackdrop(e)
  e:SetBackdropColor(Theme:C("slot"))
  e:SetBackdropBorderColor(Theme:C("stroke"))
  e:SetFont(ns.Fonts:Current(), 11, "")
  e:SetTextColor(Theme:C("text"))
  e:SetJustifyH("CENTER")
  e:SetAutoFocus(false)
  e:SetMaxLetters(6)
  Theme:Track(e, function(s)
    s:SetBackdropColor(Theme:C("slot"))
    s:SetBackdropBorderColor(Theme:C(s:HasFocus() and "accent" or "stroke"))
    s:SetTextColor(Theme:C("text"))
  end)
  e:SetScript("OnEditFocusGained", function(s) s:SetBackdropBorderColor(Theme:C("accent")) end)
  e:SetScript("OnEditFocusLost", function(s)
    s:SetBackdropBorderColor(Theme:C("stroke"))
    apply(tonumber(s:GetText()))
  end)
  e:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
  e:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
  return e
end

function ns.Rebase(frame, dbKey)
  local l, b = frame:GetLeft(), frame:GetBottom()
  if not (l and b) then return end
  l, b = ns.SnapValue(frame, l), ns.SnapValue(frame, b)
  local w = frame:GetWidth() or 0
  local sw = UIParent:GetWidth() or 0
  frame:ClearAllPoints()
  if sw > 0 and (l + w * 0.5) > sw * 0.5 then
    frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", ns.SnapValue(frame, l + w - sw), b)
    ns.AlignToScreen(frame)
    local _, _, _, rx, ry = frame:GetPoint()
    if WarpeeDB then WarpeeDB[dbKey] = { p = "BOTTOMRIGHT", rp = "BOTTOMRIGHT", x = rx or 0, y = ry or b } end
  else
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)
    ns.AlignToScreen(frame)
    local _, _, _, lx, ly = frame:GetPoint()
    if WarpeeDB then WarpeeDB[dbKey] = { p = "BOTTOMLEFT", rp = "BOTTOMLEFT", x = lx or l, y = ly or b } end
  end
  if frame.wpeBar then frame.wpeBar:Refresh() end
end

function ns.PlaceWindow(frame, dbKey, def)
  local p = WarpeeDB and WarpeeDB[dbKey]
  frame:ClearAllPoints()
  if p and p.p then
    ns.SnapPoint(frame, p.p, UIParent, p.rp or p.p, p.x or 0, p.y or 0)
  elseif def then
    ns.SnapPoint(frame, def.p, UIParent, def.rp or def.p, def.x or 0, def.y or 0)
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

  local function nudge(dx, dy)
    local l, b = frame:GetLeft(), frame:GetBottom()
    if not (l and b) then return end
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT",
      math.floor(l + 0.5) + dx, math.floor(b + 0.5) + dy)
    ns.Rebase(frame, dbKey)
  end

  local function moveTo(nx, ny)
    local l, b = frame:GetLeft(), frame:GetBottom()
    if not (l and b) then return end
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT",
      nx or math.floor(l + 0.5), ny or math.floor(b + 0.5))
    ns.Rebase(frame, dbKey)
  end

  local xl = Theme:Label(bar, 11, "dim")
  xl:SetPoint("LEFT", 1, 0)
  xl:SetText("X")
  bar.xLabel = xl
  local xf = barField(bar, function(v) moveTo(v, nil) end)
  xf:SetPoint("LEFT", xl, "RIGHT", 4, 0)
  bar.xField = xf
  local xm = barArrow(bar, "left", function(step) nudge(-step, 0) end)
  xm:SetPoint("LEFT", xf, "RIGHT", 2, 0)
  local xp = barArrow(bar, "right", function(step) nudge(step, 0) end)
  xp:SetPoint("LEFT", xm, "RIGHT", 0, 0)

  local yl = Theme:Label(bar, 11, "dim")
  yl:SetPoint("LEFT", xp, "RIGHT", 10, 0)
  yl:SetText("Y")
  bar.yLabel = yl
  local yf = barField(bar, function(v) moveTo(nil, v) end)
  yf:SetPoint("LEFT", yl, "RIGHT", 4, 0)
  bar.yField = yf
  local ym = barArrow(bar, "down", function(step) nudge(0, -step) end)
  ym:SetPoint("LEFT", yf, "RIGHT", 2, 0)
  local yp = barArrow(bar, "up", function(step) nudge(0, step) end)
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
    s.xLabel:SetFont(path, size, "")
    s.yLabel:SetFont(path, size, "")
    s.xField:SetFont(path, size, "")
    s.yField:SetFont(path, size, "")
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

function ns.CreateButton(parent, text, width, height, template)
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
  b:SetBackdropColor(Theme:C("panel"))
  b:SetBackdropBorderColor(Theme:C("stroke"))
  Theme:Track(b, function(s)
    s:SetBackdropColor(Theme:C("panel"))
    s:SetBackdropBorderColor(Theme:C(s.offDuty and "strokeSoft" or "stroke"))
    if s.Text then s.Text:SetTextColor(Theme:C(s.offDuty and "faint" or "text")) end
  end)
  local fs = Theme:Label(b, 12, "text")
  Theme:Track(fs, function(s)
    local p = s:GetParent()
    s:SetTextColor(Theme:C((p and p.offDuty) and "faint" or "text"))
  end)
  fs:SetPoint("CENTER")
  fs:SetText(text)
  b.Text = fs
  local hook = template and b.HookScript or b.SetScript
  hook(b, "OnEnter", function(s)
    if s.offDuty then return end
    s:SetBackdropColor(Theme:C("panelHi"))
    s:SetBackdropBorderColor(Theme:C("accent"))
    s.Text:SetTextColor(Theme:C("accent"))
  end)
  hook(b, "OnLeave", function(s)
    if s.offDuty then return end
    s:SetBackdropColor(Theme:C("panel"))
    s:SetBackdropBorderColor(Theme:C("stroke"))
    s.Text:SetTextColor(Theme:C("text"))
  end)
  return b
end

function ns.SetButtonEnabled(b, on)
  if not b then return end
  on = on and true or false
  b.offDuty = not on
  b:SetEnabled(on)
  b:SetBackdropColor(Theme:C("panel"))
  b:SetBackdropBorderColor(Theme:C(on and "stroke" or "strokeSoft"))
  b.Text:SetTextColor(Theme:C(on and "text" or "faint"))
end

function ns.CreateGlyphButton(parent, glyph, size)
  local b = ns.CreateButton(parent, glyph, size or 22, size or 22)
  b.Text:SetFont(ns.Fonts:Current(), math.max(16, math.floor((size or 22) * 0.74)), "")
  return b
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

function ns.CreateSearchBox(parent, onChanged)
  local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
  ns.SnapBox(box, nil, 22)
  ns.PixelBackdrop(box)
  box:SetBackdropColor(Theme:C("bg"))
  box:SetBackdropBorderColor(Theme:C("stroke"))
  Theme:Track(box, function(s)
    s:SetBackdropColor(Theme:C("bg"))
    if not s:HasFocus() then s:SetBackdropBorderColor(Theme:C("stroke")) end
  end)
  box:SetFont(ns.Fonts:Current(), 13, "")
  box:SetTextColor(Theme:C("text"))
  box:SetTextInsets(8, 8, 0, 0)
  box:SetAutoFocus(false)

  local hint = Theme:Label(box, 13, "dim")
  hint:SetPoint("LEFT", 8, 0)
  ns.LocalText(hint, "Search")
  box.Hint = hint

  local function refreshHint(s) hint:SetShown(s:GetText() == "") end
  box:SetScript("OnTextChanged", function(s)
    refreshHint(s)
    if onChanged then onChanged(s:GetText()) end
  end)
  box:SetScript("OnEditFocusGained", function(s) s:SetBackdropBorderColor(Theme:C("accent")) end)
  box:SetScript("OnEditFocusLost", function(s) s:SetBackdropBorderColor(Theme:C("stroke")); refreshHint(s) end)
  box:SetScript("OnEscapePressed", function(s) s:SetText(""); s:ClearFocus() end)
  box:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
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
