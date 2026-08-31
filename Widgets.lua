local addonName, ns = ...
local Theme = ns.Theme

local CLASS_RING = "Interface\\TargetingFrame\\UI-Classes-Circles"

function ns.CreateCharTag(parent, height, dir)
  local PADX, GAP = 8, 6
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetHeight(height or 22)
  b:SetBackdrop({ bgFile = Theme.WHITE, edgeFile = Theme.WHITE, edgeSize = 1 })
  b:SetBackdropColor(Theme:C("panel"))
  b:SetBackdropBorderColor(Theme:C("stroke"))
  Theme:Track(b, function(x)
    x:SetBackdropColor(Theme:C("panel")); x:SetBackdropBorderColor(Theme:C("stroke"))
  end)

  local caret = CreateFrame("Frame", nil, b)
  b.caret = {}
  if dir == "left" or dir == "right" then
    caret:SetSize(3, 7)
    for i = 1, 3 do
      local t = Theme:Rect(caret, "dim", "ARTWORK")
      t:SetWidth(1)
      t:SetHeight((dir == "right") and (7 - (i - 1) * 2) or (3 + (i - 1) * 2))
      t:SetPoint("LEFT", caret, "LEFT", i - 1, 0)
      b.caret[i] = t
    end
  else
    caret:SetSize(7, 4)
    for i = 1, 3 do
      local t = Theme:Rect(caret, "dim", "ARTWORK")
      t:SetHeight(1)
      t:SetWidth(7 - (i - 1) * 2)
      t:SetPoint("TOP", caret, "TOP", 0, -(i - 1))
      b.caret[i] = t
    end
  end

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
  local function caretColor(k) for _, t in ipairs(b.caret) do t:SetVertexColor(Theme:C(k)) end end
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
  b:SetWidth(math.max(78, math.ceil(b.Text:GetStringWidth()) + 48))
end

function ns.WindowsLocked()
  return (WarpeeDB and WarpeeDB.lockWindows) and true or false
end

function ns.DragStart(frame)
  if ns.WindowsLocked() then return end
  frame:StartMoving()
  frame.wpeMoving = true
end

local moveBars = {}

local function barArrow(bar, dir, fn)
  local b = CreateFrame("Button", nil, bar)
  b:SetSize(14, 16)
  local tris = {}
  local N, STEP = 5, 2
  local span = N * STEP
  for i = 1, N do
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetTexture(Theme.WHITE)
    t:SetVertexColor(Theme:C("dim"))
    local off = (i - 1) * STEP - span / 2 + STEP / 2
    if dir == "left" or dir == "right" then
      t:SetWidth(STEP)
      t:SetHeight((dir == "right") and (span - (i - 1) * STEP) or (STEP + (i - 1) * STEP))
      t:SetPoint("CENTER", b, "CENTER", off, 0)
    else
      t:SetHeight(STEP)
      t:SetWidth((dir == "up") and (STEP + (i - 1) * STEP) or (span - (i - 1) * STEP))
      t:SetPoint("CENTER", b, "CENTER", 0, -off)
    end
    tris[i] = t
  end
  local function tint(key) for _, t in ipairs(tris) do t:SetVertexColor(Theme:C(key)) end end
  b:SetScript("OnEnter", function() tint("accent") end)
  b:SetScript("OnLeave", function() tint("dim") end)
  b:SetScript("OnClick", function() fn(IsShiftKeyDown() and 10 or 1) end)
  return b
end

local function barField(bar, apply)
  local e = CreateFrame("EditBox", nil, bar, "BackdropTemplate")
  e:SetSize(40, 16)
  e:SetBackdrop({ bgFile = Theme.WHITE, edgeFile = Theme.WHITE, edgeSize = 1 })
  e:SetBackdropColor(Theme:C("bg"))
  e:SetBackdropBorderColor(Theme:C("stroke"))
  e:SetFont("Fonts\\ARIALN.TTF", 11, "")
  e:SetTextColor(Theme:C("text"))
  e:SetJustifyH("CENTER")
  e:SetAutoFocus(false)
  e:SetMaxLetters(6)
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
  l, b = math.floor(l + 0.5), math.floor(b + 0.5)
  local w = frame:GetWidth() or 0
  local sw = UIParent:GetWidth() or 0
  frame:ClearAllPoints()
  if sw > 0 and (l + w * 0.5) > sw * 0.5 then
    local rx = math.floor(l + w - sw + 0.5)
    frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", rx, b)
    if WarpeeDB then WarpeeDB[dbKey] = { p = "BOTTOMRIGHT", rp = "BOTTOMRIGHT", x = rx, y = b } end
  else
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)
    if WarpeeDB then WarpeeDB[dbKey] = { p = "BOTTOMLEFT", rp = "BOTTOMLEFT", x = l, y = b } end
  end
  if frame.wpeBar then frame.wpeBar:Refresh() end
end

function ns.PlaceWindow(frame, dbKey, def)
  local p = WarpeeDB and WarpeeDB[dbKey]
  frame:ClearAllPoints()
  if p and p.p then
    frame:SetPoint(p.p, UIParent, p.rp or p.p, p.x or 0, p.y or 0)
  elseif def then
    frame:SetPoint(def.p, UIParent, def.rp or def.p, def.x or 0, def.y or 0)
  else
    frame:SetPoint("CENTER")
  end
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

  local xl = Theme:Label(bar, 11, "faint")
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

  local yl = Theme:Label(bar, 11, "faint")
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
  local bg = Theme:Rect(bar, "bg", "BACKGROUND")
  bg:SetPoint("TOPLEFT", -4, 3)
  bg:SetPoint("BOTTOMRIGHT", 4, -3)
  bg:SetAlpha(0.85)

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

  bar:SetShown(not ns.WindowsLocked())
  frame.wpeBar = bar
  moveBars[#moveBars + 1] = bar
  return bar
end

function ns.ApplyWindowLock()
  local locked = ns.WindowsLocked()
  for _, bar in ipairs(moveBars) do
    bar:SetShown(not locked)
    if not locked then bar:Refresh() end
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
  b:SetSize(width or 78, height or 22)
  if b.SetMotionScriptsWhileDisabled then b:SetMotionScriptsWhileDisabled(true) end
  b:SetBackdrop({ bgFile = Theme.WHITE, edgeFile = Theme.WHITE, edgeSize = 1 })
  b:SetBackdropColor(Theme:C("panel"))
  b:SetBackdropBorderColor(Theme:C("stroke"))
  Theme:Track(b, function(s)
    s:SetBackdropColor(Theme:C("panel"))
    s:SetBackdropBorderColor(Theme:C(s.offDuty and "strokeSoft" or "stroke"))
    if s.Text then s.Text:SetTextColor(Theme:C(s.offDuty and "faint" or "text")) end
  end)
  local fs = Theme:Label(b, 12, "text")
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
  b.Text:SetFont("Fonts\\FRIZQT__.TTF", math.max(13, math.floor((size or 22) * 0.6)), "")
  return b
end

function ns.CreateSearchBox(parent, onChanged)
  local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
  box:SetHeight(22)
  box:SetBackdrop({ bgFile = Theme.WHITE, edgeFile = Theme.WHITE, edgeSize = 1 })
  box:SetBackdropColor(Theme:C("bg"))
  box:SetBackdropBorderColor(Theme:C("stroke"))
  Theme:Track(box, function(s)
    s:SetBackdropColor(Theme:C("bg"))
    if not s:HasFocus() then s:SetBackdropBorderColor(Theme:C("stroke")) end
  end)
  box:SetFont("Fonts\\ARIALN.TTF", 13, "")
  box:SetTextColor(Theme:C("text"))
  box:SetTextInsets(8, 8, 0, 0)
  box:SetAutoFocus(false)

  local hint = Theme:Label(box, 13, "dim")
  hint:SetPoint("LEFT", 8, 0)
  hint:SetText("Search")
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

function ns.SearchTip(box)
  ns.AddTip(box, "Search", "top", function()
    return {
      { text = "Plain words match the name, type and subtype.", color = "dim", size = 12 },
      { text = "cloth leather mail plate cosmetic", color = "faint", size = 12 },
      { text = "dagger sword axe mace polearm staff bow gun crossbow wand fist warglaive",
        color = "faint", size = 12 },
      { text = "head neck shoulder back chest wrist hands waist legs feet finger trinket 1h 2h",
        color = "faint", size = 12 },
      { text = "poor common uncommon rare epic legendary heirloom",
        color = "faint", size = 12 },
      { text = "gear reagent consumable quest keystone token gem recipe bag mount pet glyph",
        color = "faint", size = 12 },
      { text = "boe bop warbound locked", color = "faint", size = 12 },
      { text = "ilvl600   ilvl>600   ilvl<300   ilvl600-650", color = "faint", size = 12 },
      { text = "Put ! in front of anything to exclude it.", color = "dim", size = 12 },
    }
  end)
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
