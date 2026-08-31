local addonName, ns = ...
local Theme = ns.Theme
local Bags = ns.Bags

local Options = {}
ns.Options = Options

local WIN_W, WIN_H = 640, 700
local PAD = 18
local HEADER_H = 42
local TAB_H = 30
local BASE_FONT = 15
local ROW_GAP = 10
local SCROLL_W = 8
local CONTENT_W = WIN_W - PAD * 2 - SCROLL_W - 6

local function relayout()
  if Bags.frame and Bags.frame:IsShown() then Bags:Layout() end
  if ns.Bank and ns.Bank.Refresh then ns.Bank:Refresh() end
end

local function field(name)
  local get = function() return Bags[name] end
  local set = function(v) Bags[name] = v; WarpeeDB[name] = v; relayout() end
  return get, set
end

local function styleField(name)
  local get = function() return Bags[name] end
  local set = function(v)
    Bags[name] = v; WarpeeDB[name] = v
    Bags.styleGen = (Bags.styleGen or 0) + 1
    relayout()
  end
  return get, set
end

local function dbField(name, default)
  local get = function() return WarpeeDB[name] or default end
  local set = function(v)
    WarpeeDB[name] = v
    if ns.Bank then ns.Bank:Refresh() end
  end
  return get, set
end

local function autoField(key)
  local get = function() return WarpeeDB.autoOpen and WarpeeDB.autoOpen[key] end
  local set = function(v)
    WarpeeDB.autoOpen = WarpeeDB.autoOpen or {}
    WarpeeDB.autoOpen[key] = v and true or false
  end
  return get, set
end

local function lockGet() return WarpeeDB.lockWindows and true or false end
local function lockSet(v)
  WarpeeDB.lockWindows = v and true or nil
  ns.ApplyWindowLock()
end

local ANCHORS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
local ANCHOR_LABELS = { TOPLEFT = "Top left", TOPRIGHT = "Top right",
                        BOTTOMLEFT = "Bottom left", BOTTOMRIGHT = "Bottom right" }
local STYLES = { "flat", "plate", "tile", "deep" }
local STYLE_LABELS = { flat = "Off", plate = "Light", tile = "Medium", deep = "Strong" }
local THEME_LABELS = {}
for _, k in ipairs(Theme.THEME_ORDER) do THEME_LABELS[k] = Theme.THEMES[k].label end
local function themeGet() return WarpeeDB.theme or "midnight" end
local function themeSet(v)
  WarpeeDB.theme = v
  Theme:Restyle(v)
end

local function fontKeys()
  return ns.Fonts:List()
end

local function tip(frame, text)
  if not text then return end
  if frame.EnableMouse then frame:EnableMouse(true) end
  ns.AddTip(frame, text, "right")
end

local fonts = {}
local function track(fs, delta)
  fonts[#fonts + 1] = { fs = fs, delta = delta or 0 }
  return fs
end

local rows = {}
local factories = {}

local SECTION_CLOSED = {}

local function sectionOpen(key)
  if not key then return true end
  local t = WarpeeDB and WarpeeDB.optSections
  local v = t and t[key]
  if v == nil then return not SECTION_CLOSED[key] end
  return v and true or false
end

local function sectionToggle(key)
  local on = sectionOpen(key)
  WarpeeDB.optSections = WarpeeDB.optSections or {}
  WarpeeDB.optSections[key] = not on
end

local function onOf(list)
  local n = 0
  for _, fn in ipairs(list) do if fn() then n = n + 1 end end
  return ("%d of %d"):format(n, #list)
end

local dropdown

local function closeDropdown()
  if dropdown then dropdown:Hide() end
end

local function dropdownFont()
  return ns.Fonts:Path((Bags and Bags.font) or "Arial Narrow")
end

local function makeMenuRow(parent, index, rowH)
  local r = CreateFrame("Button", nil, parent)
  r:SetHeight(rowH)
  r:SetPoint("TOPLEFT", 0, -(index - 1) * rowH)
  r:SetPoint("TOPRIGHT", 0, -(index - 1) * rowH)

  local bg = Theme:Rect(r, "panelHi", "BACKGROUND")
  bg:SetAllPoints(r)
  bg:Hide()
  r.bg = bg

  local dot = Theme:Rect(r, "accent", "ARTWORK")
  dot:SetSize(3, rowH - 8)
  dot:SetPoint("LEFT", 2, 0)
  dot:Hide()
  r.dot = dot

  local fs = track(Theme:Label(r, BASE_FONT - 1, "text"), -1)
  fs:SetFont(dropdownFont(), BASE_FONT - 1, "")
  fs:SetPoint("LEFT", 10, 0)
  fs:SetPoint("RIGHT", -8, 0)
  fs:SetJustifyH("LEFT")
  r.Text = fs

  r:SetScript("OnEnter", function(s) s.bg:Show() end)
  r:SetScript("OnLeave", function(s) s.bg:Hide() end)
  return r
end

local function ensureDropdown()
  if dropdown then return dropdown end

  local catcher = CreateFrame("Button", nil, UIParent)
  catcher:SetAllPoints(UIParent)
  catcher:SetFrameStrata("FULLSCREEN_DIALOG")
  catcher:RegisterForClicks("AnyUp")
  catcher:Hide()

  local m = CreateFrame("Frame", "WarpeeDropdown", UIParent, "BackdropTemplate")
  m:Hide()
  Theme:Panel(m, "panel", "accent")
  m:SetFrameStrata("FULLSCREEN_DIALOG")
  m:SetFrameLevel(catcher:GetFrameLevel() + 10)
  m:EnableMouse(true)
  m:SetClampedToScreen(true)

  local sf = CreateFrame("ScrollFrame", nil, m)
  sf:SetPoint("TOPLEFT", 4, -4)
  sf:SetPoint("BOTTOMRIGHT", -4, 4)
  local child = CreateFrame("Frame", nil, sf)
  child:SetPoint("TOPLEFT")
  sf:SetScrollChild(child)
  sf:EnableMouseWheel(true)
  sf:SetScript("OnMouseWheel", function(s, d)
    local span = math.max(0, child:GetHeight() - s:GetHeight())
    s:SetVerticalScroll(math.min(span, math.max(0, s:GetVerticalScroll() - d * 40)))
  end)

  m.rows, m.sf, m.child, m.catcher = {}, sf, child, catcher
  m:SetScript("OnHide", function() catcher:Hide() end)
  catcher:SetScript("OnClick", closeDropdown)
  tinsert(UISpecialFrames, "WarpeeDropdown")
  dropdown = m
  return m
end

local function openDropdown(anchor, spec, onPick)
  local m = ensureDropdown()
  if m:IsShown() and m.owner == anchor then closeDropdown(); return end

  local keys = spec.keys()
  local rowH = BASE_FONT + 11
  local cur = spec.get()
  local curIndex = 1
  for i, key in ipairs(keys) do
    local r = m.rows[i]
    if not r then r = makeMenuRow(m.child, i, rowH); m.rows[i] = r end
    r:SetHeight(rowH)
    r.dot:SetSize(3, rowH - 8)
    r.Text:SetText(spec.label(key))
    local on = (key == cur)
    r.dot:SetShown(on)
    r.Text:SetTextColor(Theme:C(on and "accentInk" or "text"))
    r.bg:Hide()
    r:SetScript("OnClick", function()
      closeDropdown()
      spec.set(key)
      if onPick then onPick() end
    end)
    r:Show()
    if on then curIndex = i end
  end
  for i = #keys + 1, #m.rows do m.rows[i]:Hide() end

  local w = math.max(anchor:GetWidth(), 120)
  local visible = math.min(#keys, 14)
  m:SetSize(w, visible * rowH + 8)
  m.child:SetSize(w - 8, #keys * rowH)

  local span = math.max(0, #keys * rowH - visible * rowH)
  m.sf:SetVerticalScroll(math.min(span, math.max(0, (curIndex - 1) * rowH - rowH * 3)))

  m.owner = anchor
  m:ClearAllPoints()
  local below = anchor:GetBottom() or 0
  if below - m:GetHeight() < 20 then
    m:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 2)
  else
    m:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
  end
  m.catcher:Show()
  m:Show()
end

local function caretGroup(parent, dir)
  local g = CreateFrame("Frame", nil, parent)
  if dir == "down" then g:SetSize(9, 5) else g:SetSize(5, 9) end
  for i = 1, 3 do
    local t = Theme:Rect(g, "dim", "ARTWORK")
    if dir == "down" then
      t:SetHeight(1)
      t:SetWidth(9 - (i - 1) * 3)
      t:SetPoint("TOP", g, "TOP", 0, -(i - 1) * 2)
    else
      t:SetWidth(1)
      t:SetHeight(9 - (i - 1) * 3)
      t:SetPoint("LEFT", g, "LEFT", (i - 1) * 2, 0)
    end
  end
  return g
end

function factories.header(parent, spec)
  local row = CreateFrame(spec.key and "Button" or "Frame", nil, parent)
  row:SetHeight(30)
  local line = Theme:Rect(row, "strokeSoft", "ARTWORK")
  line:SetHeight(1)
  line:SetPoint("BOTTOMLEFT", 0, 0)
  line:SetPoint("BOTTOMRIGHT", 0, 0)
  local fs = track(Theme:Label(row, BASE_FONT, "azure"), 0)
  fs:SetPoint("BOTTOMLEFT", spec.key and 15 or 0, 6)
  fs:SetText(spec.name:upper())
  if not spec.key then return row end

  local down = caretGroup(row, "down")
  down:SetPoint("BOTTOMLEFT", 0, 10)
  local right = caretGroup(row, "right")
  right:SetPoint("BOTTOMLEFT", 2, 8)
  local state = track(Theme:Label(row, BASE_FONT - 3, "faint"), -3)
  state:SetPoint("BOTTOMRIGHT", 0, 7)

  row.Refresh = function()
    local on = sectionOpen(spec.key)
    down:SetShown(on)
    right:SetShown(not on)
    state:SetText((spec.state and spec.state()) or "")
  end
  row:SetScript("OnClick", function()
    sectionToggle(spec.key)
    row.Refresh()
    Options:ReflowPages()
  end)
  row:SetScript("OnEnter", function() fs:SetTextColor(Theme:C("accentInk")) end)
  row:SetScript("OnLeave", function() fs:SetTextColor(Theme:C("azure")) end)
  row.Refresh()
  return row
end

function factories.description(parent, spec)
  local row = CreateFrame("Frame", nil, parent)
  local fs = track(Theme:Label(row, BASE_FONT - 2, "dim"), -2)
  fs:SetPoint("TOPLEFT")
  fs:SetWidth(CONTENT_W)
  fs:SetJustifyH("LEFT")
  fs:SetSpacing(2)
  fs:SetText(spec.name)
  row:SetHeight(fs:GetStringHeight() + 6)
  row.autoHeight = fs
  return row
end

function factories.toggle(parent, spec)
  local row = CreateFrame("Button", nil, parent)
  row:SetHeight(26)

  local box = CreateFrame("Frame", nil, row, "BackdropTemplate")
  box:SetSize(18, 18)
  box:SetPoint("LEFT", 1, 0)
  box:SetBackdrop({ bgFile = Theme.WHITE, edgeFile = Theme.WHITE, edgeSize = 1 })
  box:SetBackdropColor(Theme:C("panelHi"))
  box:SetBackdropBorderColor(Theme:C("stroke"))

  local mark = Theme:Rect(box, "accent", "OVERLAY")
  mark:SetPoint("TOPLEFT", 3, -3)
  mark:SetPoint("BOTTOMRIGHT", -3, 3)
  mark:Hide()

  local fs = track(Theme:Label(row, BASE_FONT, "text"), 0)
  fs:SetPoint("LEFT", box, "RIGHT", 8, 0)
  fs:SetPoint("RIGHT", -2, 0)
  fs:SetJustifyH("LEFT")
  if type(spec.name) ~= "function" then fs:SetText(spec.name) end

  row.Refresh = function()
    if type(spec.name) == "function" then fs:SetText(spec.name() or "") end
    local off = (spec.disabled and spec.disabled()) and true or false
    local on = spec.get() and true or false
    mark:SetShown(on)
    mark:SetVertexColor(Theme:C(off and "faint" or "accent"))
    fs:SetTextColor(Theme:C(off and "faint" or (on and "text" or "dim")))
    box:SetBackdropBorderColor(Theme:C(off and "strokeSoft" or "stroke"))
    row:SetEnabled(not off)
    row.off = off
  end
  row:SetScript("OnClick", function()
    if row.off then return end
    spec.set(not spec.get())
    row.Refresh()
    Options:Refresh()
  end)
  row:SetScript("OnEnter", function()
    if row.off then return end
    box:SetBackdropBorderColor(Theme:C("accent"))
  end)
  row:SetScript("OnLeave", function()
    box:SetBackdropBorderColor(Theme:C(row.off and "strokeSoft" or "stroke"))
  end)
  row.Refresh()
  tip(row, spec.desc)
  return row
end

function factories.input(parent, spec)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(28)

  local fs = track(Theme:Label(row, BASE_FONT, "text"), 0)
  fs:SetPoint("LEFT", 1, 0)
  fs:SetText(spec.name)

  local box = CreateFrame("EditBox", nil, row, "BackdropTemplate")
  box:SetSize(66, 24)
  box:SetPoint("RIGHT", -1, 0)
  box:SetBackdrop({ bgFile = Theme.WHITE, edgeFile = Theme.WHITE, edgeSize = 1 })
  box:SetBackdropColor(Theme:C("bg"))
  box:SetBackdropBorderColor(Theme:C("stroke"))
  Theme:Track(box, function(s)
    s:SetBackdropColor(Theme:C("bg"))
    s:SetTextColor(Theme:C("text"))
    if not s:HasFocus() then s:SetBackdropBorderColor(Theme:C("stroke")) end
  end)
  box:SetFont(dropdownFont(), BASE_FONT - 1, "")
  track(box, -1)
  box:SetTextColor(Theme:C("text"))
  box:SetJustifyH("CENTER")
  box:SetAutoFocus(false)
  box:SetNumeric(true)
  box:SetMaxLetters(4)

  row.Refresh = function()
    if not box:HasFocus() then box:SetText(tostring(spec.get() or 0)) end
  end

  local function apply()
    local v = tonumber(box:GetText()) or spec.get() or 0
    if spec.min and v < spec.min then v = spec.min end
    if spec.max and v > spec.max then v = spec.max end
    spec.set(v)
    row.Refresh()
    Options:Refresh()
  end

  box:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
  box:SetScript("OnEscapePressed", function(s) s:ClearFocus(); row.Refresh() end)
  box:SetScript("OnEditFocusGained", function(s) s:SetBackdropBorderColor(Theme:C("accent")) end)
  box:SetScript("OnEditFocusLost", function(s)
    s:SetBackdropBorderColor(Theme:C("stroke"))
    apply()
  end)

  row.Refresh()
  tip(row, spec.desc)
  return row
end

function factories.range(parent, spec)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(46)

  local fs = track(Theme:Label(row, BASE_FONT, "text"), 0)
  fs:SetPoint("TOPLEFT", 1, -1)
  fs:SetText(spec.name)

  local val = track(Theme:Label(row, BASE_FONT, "accentInk"), 0)
  val:SetPoint("TOPRIGHT", -1, -1)

  local s = CreateFrame("Slider", nil, row)
  s:SetOrientation("HORIZONTAL")
  s:SetHeight(18)
  s:SetPoint("BOTTOMLEFT", 1, 2)
  s:SetPoint("BOTTOMRIGHT", -1, 2)
  s:SetMinMaxValues(spec.min, spec.max)
  s:SetValueStep(spec.step or 1)
  s:SetObeyStepOnDrag(true)

  local track_ = Theme:Rect(s, "panelHi", "BACKGROUND")
  track_:SetHeight(6)
  track_:SetPoint("LEFT", 0, 0)
  track_:SetPoint("RIGHT", 0, 0)

  local fill = Theme:Rect(s, "accent", "ARTWORK")
  fill:SetHeight(6)
  fill:SetPoint("LEFT", track_, "LEFT", 0, 0)

  local thumb = s:CreateTexture(nil, "OVERLAY")
  thumb:SetTexture(Theme.WHITE)
  thumb:SetVertexColor(Theme:C("accentInk"))
  thumb:SetSize(9, 18)
  s:SetThumbTexture(thumb)

  local function snap(v)
    local step = spec.step or 1
    local n = math.floor((v - spec.min) / step + 0.5)
    local out = spec.min + n * step
    if out > spec.max then out = spec.max elseif out < spec.min then out = spec.min end
    return out
  end

  local function label(v)
    if (spec.step or 1) < 1 then return string.format("%.2f", v) end
    return tostring(v)
  end

  local function paint(v)
    val:SetText(label(v))
    local span = spec.max - spec.min
    local w = s:GetWidth() or 0
    fill:SetWidth(span > 0 and math.max(0.001, w * (v - spec.min) / span) or 0.001)
  end

  s:SetScript("OnValueChanged", function(sl, v)
    v = snap(v)
    paint(v)
    if sl.quiet then return end
    if math.abs((spec.get() or 0) - v) > 1e-4 then spec.set(v) end
  end)
  s:SetScript("OnSizeChanged", function() paint(snap(s:GetValue())) end)
  s:SetScript("OnEnter", function(sl)
    if not sl.offDuty then thumb:SetVertexColor(Theme:C("text")) end
  end)
  s:SetScript("OnLeave", function(sl)
    thumb:SetVertexColor(Theme:C(sl.offDuty and "faint" or "accentInk"))
  end)

  row.Refresh = function()
    local on = not (spec.disabled and spec.disabled())
    s.offDuty = not on
    s:EnableMouse(on)
    fs:SetTextColor(Theme:C(on and "text" or "faint"))
    val:SetTextColor(Theme:C(on and "accentInk" or "faint"))
    thumb:SetVertexColor(Theme:C(on and "accentInk" or "faint"))
    fill:SetVertexColor(Theme:C(on and "accent" or "strokeSoft"))
    s.quiet = true
    s:SetValue(spec.get())
    s.quiet = nil
    paint(spec.get())
  end
  row.Refresh()
  tip(row, spec.desc)
  row.slider = s
  return row
end

local function cycle(spec, dir)
  local keys = spec.keys()
  local cur, idx = spec.get(), 1
  for i, k in ipairs(keys) do if k == cur then idx = i; break end end
  idx = idx + dir
  if idx < 1 then idx = #keys elseif idx > #keys then idx = 1 end
  spec.set(keys[idx])
end

function factories.select(parent, spec)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(46)

  local fs = track(Theme:Label(row, BASE_FONT, "text"), 0)
  fs:SetPoint("TOPLEFT", 1, -1)
  fs:SetText(spec.name)

  local btn = CreateFrame("Button", nil, row, "BackdropTemplate")
  btn:SetHeight(24)
  btn:SetPoint("BOTTOMLEFT", 1, 0)
  btn:SetPoint("BOTTOMRIGHT", -1, 0)
  btn:SetBackdrop({ bgFile = Theme.WHITE, edgeFile = Theme.WHITE, edgeSize = 1 })
  btn:SetBackdropColor(Theme:C("panel"))
  btn:SetBackdropBorderColor(Theme:C("stroke"))

  local cur = track(Theme:Label(btn, BASE_FONT - 1, "text"), -1)
  cur:SetPoint("LEFT", 7, 0)
  cur:SetPoint("RIGHT", -18, 0)
  cur:SetJustifyH("LEFT")

  local arrowBox = CreateFrame("Frame", nil, btn)
  arrowBox:SetSize(9, 5)
  arrowBox:SetPoint("RIGHT", -7, 0)
  local arrow = {}
  for i = 1, 4 do
    local t = Theme:Rect(arrowBox, "dim", "ARTWORK")
    t:SetHeight(1)
    t:SetWidth(9 - (i - 1) * 2)
    t:SetPoint("TOP", arrowBox, "TOP", 0, -(i - 1))
    arrow[i] = t
  end
  local function arrowColor(key)
    for _, t in ipairs(arrow) do t:SetVertexColor(Theme:C(key)) end
  end

  row.Refresh = function() cur:SetText(spec.label(spec.get()) or "") end
  row.Refresh()

  btn:SetScript("OnEnter", function(s)
    s:SetBackdropColor(Theme:C("panelHi"))
    s:SetBackdropBorderColor(Theme:C("accent"))
    arrowColor("accent")
  end)
  btn:SetScript("OnLeave", function(s)
    s:SetBackdropColor(Theme:C("panel"))
    s:SetBackdropBorderColor(Theme:C("stroke"))
    arrowColor("dim")
  end)
  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  btn:SetScript("OnClick", function(s, button)
    if button == "RightButton" then
      cycle(spec, -1)
      row.Refresh()
      return
    end
    openDropdown(s, spec, row.Refresh)
  end)
  tip(row, spec.desc)
  return row
end

local CLASS_RING = "Interface\\TargetingFrame\\UI-Classes-Circles"
local CHAR_COLS = 3
local CHAR_CELL_H, CHAR_HEAD_H, CHAR_DEL_H = 24, 22, 20

local function charHead(row, i)
  local h = row.heads[i]
  if h then return h end
  h = CreateFrame("Frame", nil, row)
  h:SetHeight(CHAR_HEAD_H)
  local line = Theme:Rect(h, "strokeSoft", "ARTWORK")
  line:SetHeight(1)
  line:SetPoint("BOTTOMLEFT", 0, 0)
  line:SetPoint("BOTTOMRIGHT", 0, 0)
  local fs = track(Theme:Label(h, BASE_FONT - 3, "azure"), -3)
  fs:SetPoint("BOTTOMLEFT", 0, 5)
  h.Text = fs
  row.heads[i] = h
  return h
end

local function dropChar(key)
  if not (key and ns.Vault:Delete(key)) then return end
  if ns.Bank and ns.Bank.frame then
    ns.Bank:UpdateCharBtn()
    if ns.Bank.frame:IsShown() then ns.Bank:Repaint() end
  end
  if Bags and Bags.snap and ns.Vault:ViewKey("bags") == ns.Vault:Owner() then
    Bags.snap = nil
    Bags:UpdateCharTag()
    if Bags.frame and Bags.frame:IsShown() then Bags:Layout() end
  end
  if ns.CharPicker then ns.CharPicker:Close() end
  if ns.Options and ns.Options.ReflowPages then ns.Options:ReflowPages() end
end

StaticPopupDialogs["WARPEE_DROP_CHAR"] = {
  text = "Delete saved bags and bank of %s?",
  button1 = _G.DELETE or "Delete",
  button2 = _G.CANCEL or "Cancel",
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  showAlert = true,
  OnAccept = function(_, key) dropChar(key) end,
}

local function charCell(row, i)
  local c = row.cells[i]
  if c then return c end
  c = CreateFrame("Button", nil, row)
  c:SetHeight(CHAR_CELL_H)
  local box = CreateFrame("Frame", nil, c, "BackdropTemplate")
  box:SetSize(16, 16)
  box:SetPoint("LEFT", 1, 0)
  box:SetBackdrop({ bgFile = Theme.WHITE, edgeFile = Theme.WHITE, edgeSize = 1 })
  box:SetBackdropColor(Theme:C("panelHi"))
  box:SetBackdropBorderColor(Theme:C("stroke"))
  local mark = Theme:Rect(box, "accent", "OVERLAY")
  mark:SetPoint("TOPLEFT", 3, -3)
  mark:SetPoint("BOTTOMRIGHT", -3, 3)
  mark:Hide()
  local minus = Theme:Rect(box, "gaugeHi", "OVERLAY")
  minus:SetHeight(2)
  minus:SetPoint("LEFT", 3, 0)
  minus:SetPoint("RIGHT", -3, 0)
  minus:Hide()
  c.box, c.mark, c.minus = box, mark, minus
  local ic = c:CreateTexture(nil, "ARTWORK")
  ic:SetSize(15, 15)
  ic:SetPoint("LEFT", box, "RIGHT", 5, 0)
  ic:SetTexture(CLASS_RING)
  c.icon = ic
  local fs = track(Theme:Label(c, BASE_FONT - 2, "text"), -2)
  fs:SetPoint("LEFT", ic, "RIGHT", 4, 0)
  fs:SetPoint("RIGHT", -2, 0)
  fs:SetJustifyH("LEFT")
  c.Text = fs

  c:SetScript("OnEnter", function(s)
    s.box:SetBackdropBorderColor(Theme:C(row.delMode and "gaugeHi" or "accent"))
    if row.delMode then s.Text:SetTextColor(Theme:C("gaugeHi")) end
  end)
  c:SetScript("OnLeave", function(s)
    s.box:SetBackdropBorderColor(Theme:C(row.delMode and "gaugeHi" or "stroke"))
    s:Paint()
  end)
  c:SetScript("OnClick", function(s)
    if not s.key then return end
    if row.delMode then
      StaticPopup_Show("WARPEE_DROP_CHAR", s.Text:GetText() or s.key, nil, s.key)
      return
    end
    local visible = not ns.Vault:Hidden(s.key)
    ns.Vault:SetHidden(s.key, visible)
    s.mark:SetShown(not visible)
    s.Text:SetTextColor(Theme:C((not visible) and "text" or "dim"))
  end)
  c.Paint = function(s)
    local on = not ns.Vault:Hidden(s.key or "")
    if row.delMode then
      s.mark:Hide()
      s.minus:Show()
      s.box:SetBackdropBorderColor(Theme:C("gaugeHi"))
      s.Text:SetTextColor(Theme:C(on and "text" or "dim"))
    else
      s.minus:Hide()
      s.mark:SetShown(on)
      s.box:SetBackdropBorderColor(Theme:C("stroke"))
      s.Text:SetTextColor(Theme:C(on and "text" or "dim"))
    end
  end
  row.cells[i] = c
  return c
end

function factories.chars(parent, spec)
  local row = CreateFrame("Frame", nil, parent)
  row.heads, row.cells = {}, {}
  row.dynamic = true

  local del = ns.CreateButton(row, "Delete mode", 86, CHAR_DEL_H)
  local function paintDel(hover)
    local key = row.delMode and "gaugeHi" or (hover and "accent" or "dim")
    del:SetBackdropColor(Theme:C(hover and "panelHi" or "panel"))
    del:SetBackdropBorderColor(Theme:C(key))
    del.Text:SetTextColor(Theme:C(key))
  end
  del:SetScript("OnEnter", function() paintDel(true) end)
  del:SetScript("OnLeave", function() paintDel(false) end)
  del:SetScript("OnClick", function()
    row.delMode = (not row.delMode) or nil
    row.Rebuild()
    paintDel(del:IsMouseOver())
  end)
  row.delBtn, row.paintDel = del, paintDel

  row.Rebuild = function()
    local list = (ns.Vault and ns.Vault:Chars(true)) or {}
    if #list == 0 then row.delMode = nil end
    local path = ns.Fonts:Path((Bags and Bags.font) or "Arial Narrow")
    local colW = math.floor((CONTENT_W - (CHAR_COLS - 1) * 8) / CHAR_COLS)
    del.Text:SetFont(path, math.max(7, BASE_FONT - 2), "")
    del:SetWidth(math.max(86, math.ceil(del.Text:GetStringWidth()) + 20))
    del:SetShown(#list > 0)
    paintDel(false)
    local y, hi, ci, col, realm = 0, 0, 0, 0, nil
    for _, e in ipairs(list) do
      if e.realm ~= realm then
        realm = e.realm
        if col > 0 then y = y + CHAR_CELL_H; col = 0 end
        if y > 0 then y = y + 6 end
        hi = hi + 1
        local h = charHead(row, hi)
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", 0, -y)
        h:SetPoint("TOPRIGHT", 0, -y)
        h.Text:SetText((realm or "?"):upper())
        h.Text:SetFont(path, math.max(7, BASE_FONT - 3), "")
        h:Show()
        y = y + CHAR_HEAD_H + 2
      end
      ci = ci + 1
      local c = charCell(row, ci)
      c.key = e.key
      c:SetWidth(colW)
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", col * (colW + 8), -y)
      local coords = e.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[e.class]
      if coords then
        c.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4]); c.icon:Show()
      else
        c.icon:Hide()
      end
      c.Text:SetText(e.name)
      c.Text:SetFont(path, math.max(7, BASE_FONT - 2), "")
      c:Paint()
      c:Show()
      col = col + 1
      if col >= CHAR_COLS then col = 0; y = y + CHAR_CELL_H end
    end
    if col > 0 then y = y + CHAR_CELL_H end
    for i = hi + 1, #row.heads do row.heads[i]:Hide() end
    for i = ci + 1, #row.cells do row.cells[i]:Hide() end
    if #list > 0 then
      del:ClearAllPoints()
      del:SetPoint("TOP", row, "TOP", 0, -(y + 8))
      y = y + 8 + CHAR_DEL_H
    end
    row:SetHeight(math.max(CHAR_CELL_H, y))
  end
  row.Refresh = row.Rebuild
  Options.charsRow = row
  return row
end

local BL_ROW_H = 22

local function blackRow(row, i)
  local c = row.items[i]
  if c then return c end
  c = CreateFrame("Frame", nil, row)
  c:SetHeight(BL_ROW_H)
  local ic = c:CreateTexture(nil, "ARTWORK")
  ic:SetSize(16, 16)
  ic:SetPoint("LEFT", 1, 0)
  c.icon = ic
  local x = ns.CreateGlyphButton(c, "×", 18)
  x:SetPoint("RIGHT", -1, 0)
  x:SetScript("OnClick", function()
    if c.id and ns.Vendor then ns.Vendor:Unblock(c.id) end
    Options:ReflowPages()
  end)
  c.del = x
  local fs = track(Theme:Label(c, BASE_FONT - 2, "text"), -2)
  fs:SetFont(dropdownFont(), BASE_FONT - 2, "")
  fs:SetPoint("LEFT", ic, "RIGHT", 6, 0)
  fs:SetPoint("RIGHT", x, "LEFT", -6, 0)
  fs:SetJustifyH("LEFT")
  c.Text = fs
  row.items[i] = c
  return c
end

function factories.blacklist(parent, spec)
  local row = CreateFrame("Frame", nil, parent)
  row.items = {}
  row.dynamic = true
  local empty = track(Theme:Label(row, BASE_FONT - 2, "faint"), -2)
  empty:SetFont(dropdownFont(), BASE_FONT - 2, "")
  empty:SetPoint("TOPLEFT")
  empty:SetWidth(CONTENT_W)
  empty:SetJustifyH("LEFT")
  empty:SetText("Alt-click an item in your bags while this tab is open.")
  row.empty = empty
  row.Rebuild = function()
    local list = ns.Vendor and ns.Vendor:BlackList() or {}
    local y = 0
    row.empty:SetShown(#list == 0)
    if #list == 0 then
      y = math.ceil(row.empty:GetStringHeight()) + 4
    else
      for i, e in ipairs(list) do
        local c = blackRow(row, i)
        c.id = e.id
        c.Text:SetText(e.name or tostring(e.id))
        local tex = (select(10, C_Item.GetItemInfo(e.id)))
        c.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", 0, -y)
        c:SetPoint("TOPRIGHT", 0, -y)
        c:Show()
        y = y + BL_ROW_H + 2
      end
    end
    for i = #list + 1, #row.items do row.items[i]:Hide() end
    row:SetHeight(math.max(BL_ROW_H, y))
  end
  row.Refresh = row.Rebuild
  row.Rebuild()
  Options.blackRow = row
  return row
end

local function buildPage(parent, list)
  local page = CreateFrame("Frame", nil, parent)
  page:SetPoint("TOPLEFT")
  page:SetWidth(CONTENT_W)
  page.rows = {}
  for _, spec in ipairs(list) do
    local row = factories[spec.type](page, spec)
    page.rows[#page.rows + 1] = { row = row, spec = spec }
    if row.Refresh then rows[#rows + 1] = row end
  end
  page.Relayout = function()
    local y = 0
    local halfW = math.floor((CONTENT_W - 14) / 2)
    local thirdW = math.floor((CONTENT_W - 20) / 3)
    local function gone(spec)
      return (spec.hidden and spec.hidden())
             or (spec.section and not sectionOpen(spec.section)) and true or false
    end
    local function nextSpec(from)
      for j = from + 1, #page.rows do
        local s = page.rows[j].spec
        if not gone(s) then return s end
      end
    end
    for index, entry in ipairs(page.rows) do
      local row, spec = entry.row, entry.spec
      if gone(spec) then
        row:Hide()
      else
        row:Show()
        if row.dynamic and row.Rebuild then row.Rebuild() end
        if row.autoHeight then row:SetHeight(row.autoHeight:GetStringHeight() + 6) end
        row:ClearAllPoints()
        if spec.type == "header" and y > 0 then y = y + 12 end
        local nx = nextSpec(index)
        if spec.col then
          local total = spec.of or 2
          local colW = total == 3 and thirdW or halfW
          row:SetWidth(colW)
          row:SetPoint("TOPLEFT", (spec.col - 1) * (colW + (total == 3 and 10 or 14)), -y)
          local nextCol = nx and nx.col
          if spec.col >= total or not nextCol or nextCol <= spec.col then
            y = y + row:GetHeight() + ROW_GAP
          end
        elseif spec.half == "left" then
          row:SetPoint("TOPLEFT", 0, -y)
          row:SetWidth(halfW)
          if not (nx and nx.half == "right") then y = y + row:GetHeight() + ROW_GAP end
        elseif spec.half == "right" then
          row:SetPoint("TOPRIGHT", 0, -y)
          row:SetWidth(halfW)
          y = y + row:GetHeight() + ROW_GAP
        else
          row:SetPoint("TOPLEFT", 0, -y)
          row:SetPoint("TOPRIGHT", 0, -y)
          y = y + row:GetHeight() + (spec.type == "header" and 7 or ROW_GAP)
        end
      end
    end
    page:SetHeight(y + 4)
  end
  page.Relayout()
  return page
end

local function makeScrollArea(parent, list)
  local sf = CreateFrame("ScrollFrame", nil, parent)
  local page = buildPage(sf, list)
  sf:SetScrollChild(page)

  local bar = CreateFrame("Frame", nil, parent)
  bar:SetWidth(SCROLL_W)
  local trackTex = Theme:Rect(bar, "panel", "BACKGROUND")
  trackTex:SetAllPoints(bar)
  local thumb = CreateFrame("Frame", nil, bar)
  thumb:SetWidth(SCROLL_W)
  local thumbTex = Theme:Rect(thumb, "emptyLine", "ARTWORK")
  thumbTex:SetAllPoints(thumb)
  sf.bar, sf.page = bar, page

  local function range()
    return math.max(0, page:GetHeight() - sf:GetHeight())
  end

  local function paintBar()
    local span, view = range(), sf:GetHeight()
    if span <= 0 then bar:Hide(); return end
    bar:Show()
    local h = math.max(20, view * view / page:GetHeight())
    thumb:SetHeight(h)
    local frac = sf:GetVerticalScroll() / span
    thumb:ClearAllPoints()
    thumb:SetPoint("TOP", bar, "TOP", 0, -frac * (view - h))
  end
  sf.PaintBar = function() paintBar() end

  local function scrollTo(v)
    local span = range()
    v = math.min(span, math.max(0, v))
    sf:SetVerticalScroll(v)
    paintBar()
  end
  sf.ScrollTo = function(_, v) scrollTo(v) end

  sf:EnableMouseWheel(true)
  sf:SetScript("OnMouseWheel", function(s, d) scrollTo(s:GetVerticalScroll() - d * 34) end)
  sf:SetScript("OnSizeChanged", paintBar)

  thumb:EnableMouse(true)
  thumb:SetScript("OnMouseDown", function(s)
    s.grabY = select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
    s.grabScroll = sf:GetVerticalScroll()
    s:SetScript("OnUpdate", function(t)
      local y = select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
      local view = sf:GetHeight()
      local travel = view - t:GetHeight()
      if travel <= 0 then return end
      scrollTo(t.grabScroll + (t.grabY - y) * range() / travel)
    end)
    thumbTex:SetVertexColor(Theme:C("accent"))
  end)
  thumb:SetScript("OnMouseUp", function(s)
    s:SetScript("OnUpdate", nil)
    thumbTex:SetVertexColor(Theme:C("emptyLine"))
  end)
  thumb:SetScript("OnEnter", function() thumbTex:SetVertexColor(Theme:C("dim")) end)
  thumb:SetScript("OnLeave", function(s)
    if not s:GetScript("OnUpdate") then thumbTex:SetVertexColor(Theme:C("emptyLine")) end
  end)
  return sf
end

local colsGet, colsSet       = field("cols")
local sizeGet, sizeSet       = field("iconSize")
local gapGet, gapSet         = field("gap")
local styleGet, styleSet     = field("slotStyle")
local fontGet, fontSet       = styleField("font")
local zoomGet, zoomSet       = styleField("iconZoom")
local edgeGet, edgeSet       = styleField("borderWidth")
local mergeGet, mergeSet     = field("mergeReagents")
local questGet, questSet     = styleField("questMarks")
local newGet, newSet         = styleField("newItemGlow")
local junkGet, junkSet       = field("junkIcon")
local function gridAlphaGet() return Theme:GridAlpha() end
local function gridAlphaSet(v) WarpeeDB.gridAlpha = v; Theme:ApplyGridAlpha() end
local gaugeGet, gaugeSet     = field("showGauge")
local lettersGet, lettersSet = field("goldLetters")
local onlyGet, onlySet       = field("goldOnly")

local GOLD_FORMATS = { "commas", "dots", "spaces", "short" }
local GOLD_FORMAT_LABELS = {
  commas = "Commas (5,000,000)",
  dots   = "Dots (5.000.000)",
  spaces = "Spaces (5 000 000)",
  short  = "Short (5M, 284.4K)",
}
local function goldFmtGet() return WarpeeDB.goldFormat or "commas" end
local function goldFmtSet(v) WarpeeDB.goldFormat = v; relayout() end
local qColorGet, qColorSet   = field("qualityColorIlvl")
local qBorderGet, qBorderSet = field("qualityBorder")
local ilvlSizeGet, ilvlSizeSet     = styleField("ilvlSize")
local ilvlAnchorGet, ilvlAnchorSet = styleField("ilvlAnchor")
local ilvlXGet, ilvlXSet           = styleField("ilvlX")
local ilvlYGet, ilvlYSet           = styleField("ilvlY")
local countSizeGet, countSizeSet     = styleField("countSize")
local countAnchorGet, countAnchorSet = styleField("countAnchor")
local countXGet, countXSet           = styleField("countX")
local countYGet, countYSet           = styleField("countY")
local bankColsGet, bankColsSet = dbField("bankCols", 24)
local wbColsGet, wbColsSet     = dbField("warbandCols", 24)
local bankSizeGet, bankSizeSet = dbField("bankIconSize", 40)

local function anchorKeys() return ANCHORS end
local function anchorLabel(k) return ANCHOR_LABELS[k] or k end

local aucGet, aucSet   = autoField("auction")
local bankGet, bankSet = autoField("bank")
local gbGet, gbSet     = autoField("guildbank")
local mailGet, mailSet = autoField("mail")
local profGet, profSet = autoField("professions")
local tradeGet, tradeSet = autoField("trade")
local vendGet, vendSet = autoField("vendor")

SECTION_CLOSED.autoopen = true

local GENERAL_PAGE = {
  { type = "header", name = "Look" },
  { type = "select", name = "Theme", get = themeGet, set = themeSet,
    keys = function() return Theme.THEME_ORDER end, label = function(k) return THEME_LABELS[k] or k end,
    desc = "Color scheme for the whole addon. All four are dark, so item icons stay readable." },
  { type = "select", name = "Font", get = fontGet,
    set = function(v) fontSet(v); Options:ApplyFont() end,
    keys = fontKeys, label = function(k) return k end,
    desc = "Used for every label Warpee draws. Other addons can add fonts to this list." },
  { type = "header", name = "Windows" },
  { type = "toggle", name = "Lock windows", col = 1, get = lockGet, set = lockSet,
    desc = "Freeze the bags, bank and bag-list windows in place. While unlocked each one shows X/Y fields at its top-left: type a value or nudge with the arrows (Shift = 10). Y is the bottom edge, so matching Y lines both windows up." },
  { type = "toggle", name = "Capacity bar", col = 2, get = gaugeGet, set = gaugeSet,
    desc = "Fill bar in the bags header showing how full they are." },
  { type = "header", name = "Money" },
  { type = "select", name = "Gold format", get = goldFmtGet, set = goldFmtSet,
    keys = function() return GOLD_FORMATS end, label = function(k) return GOLD_FORMAT_LABELS[k] or k end,
    desc = "Grouping for every amount Warpee prints. Short abbreviates to K and M." },
  { type = "toggle", name = "Gold only", col = 1, get = onlyGet, set = onlySet,
    desc = "Show gold only, hide silver and copper." },
  { type = "toggle", name = "Coin letters", col = 2, get = lettersGet, set = lettersSet,
    desc = "On = g/s/c letters. Off = coin icons." },
  { type = "header", name = "Open bags with", key = "autoopen",
    state = function()
      return onOf({ aucGet, bankGet, gbGet, mailGet, profGet, tradeGet, vendGet })
    end },
  { type = "description", section = "autoopen",
    name = "The bags open together with these windows and close with them again." },
  { type = "toggle", name = "Bank", col = 1, section = "autoopen", get = bankGet, set = bankSet },
  { type = "toggle", name = "Vendor", col = 2, section = "autoopen", get = vendGet, set = vendSet },
  { type = "toggle", name = "Mail", col = 1, section = "autoopen", get = mailGet, set = mailSet },
  { type = "toggle", name = "Auction house", col = 2, section = "autoopen",
    get = aucGet, set = aucSet },
  { type = "toggle", name = "Trade", col = 1, section = "autoopen",
    get = tradeGet, set = tradeSet },
  { type = "toggle", name = "Guild bank", col = 2, section = "autoopen", get = gbGet, set = gbSet },
  { type = "toggle", name = "Professions", col = 1, section = "autoopen",
    get = profGet, set = profSet },
}

SECTION_CLOSED.ilvlnum = true
SECTION_CLOSED.countnum = true

local ITEMS_PAGE = {
  { type = "header", name = "Markers" },
  { type = "toggle", name = "Quality border", col = 1, get = qBorderGet, set = qBorderSet,
    desc = "Draw a rarity-colored border around uncommon+ items." },
  { type = "toggle", name = "Quest marker", col = 2, get = questGet, set = questSet,
    desc = "Blizzard quest art: exclamation mark for an unaccepted quest, border for a quest item." },
  { type = "toggle", name = "New item glow", col = 1, get = newGet, set = newSet,
    desc = "Quality-colored glow on items the game still counts as new. Static, no pulsing." },
  { type = "toggle", name = "Junk coin", col = 2, get = junkGet, set = junkSet,
    desc = "Gold coin marker on poor-quality (grey) items." },
  { type = "range", name = "Border thickness", min = 1, max = 6, step = 1,
    get = edgeGet, set = edgeSet, disabled = function() return not qBorderGet() end,
    desc = "Thickness of the quality border." },
  { type = "header", name = "Item level number", key = "ilvlnum",
    state = function()
      return ("%d px, %s"):format(ilvlSizeGet(), (anchorLabel(ilvlAnchorGet())):lower())
    end },
  { type = "toggle", name = "Color by quality", col = 1, section = "ilvlnum",
    get = qColorGet, set = qColorSet,
    desc = "Tint the number with the item's rarity color." },
  { type = "select", name = "Corner", get = ilvlAnchorGet, set = ilvlAnchorSet,
    section = "ilvlnum", keys = anchorKeys, label = anchorLabel,
    desc = "Which corner of the slot the number sits in." },
  { type = "range", name = "Size", min = 6, max = 24, step = 1, section = "ilvlnum",
    get = ilvlSizeGet, set = ilvlSizeSet, half = "left" },
  { type = "range", name = "X offset", min = -20, max = 20, step = 1, section = "ilvlnum",
    get = ilvlXGet, set = ilvlXSet, half = "right" },
  { type = "range", name = "Y offset", min = -20, max = 20, step = 1, section = "ilvlnum",
    get = ilvlYGet, set = ilvlYSet, half = "left" },
  { type = "header", name = "Stack count number", key = "countnum",
    state = function()
      return ("%d px, %s"):format(countSizeGet(), (anchorLabel(countAnchorGet())):lower())
    end },
  { type = "select", name = "Corner", get = countAnchorGet, set = countAnchorSet,
    section = "countnum", keys = anchorKeys, label = anchorLabel,
    desc = "Which corner of the slot the stack size sits in." },
  { type = "range", name = "Size", min = 6, max = 24, step = 1, section = "countnum",
    get = countSizeGet, set = countSizeSet, half = "left" },
  { type = "range", name = "X offset", min = -20, max = 20, step = 1, section = "countnum",
    get = countXGet, set = countXSet, half = "right" },
  { type = "range", name = "Y offset", min = -20, max = 20, step = 1, section = "countnum",
    get = countYGet, set = countYSet, half = "left" },
}

SECTION_CLOSED.bankgrid = true

local GRID_PAGE = {
  { type = "header", name = "Bags grid" },
  { type = "range", name = "Icon size", min = 24, max = 56, step = 1, get = sizeGet, set = sizeSet,
    half = "left", desc = "Size of one slot in the bags." },
  { type = "range", name = "Slots per row", min = 6, max = 24, step = 1, get = colsGet, set = colsSet,
    half = "right", desc = "How wide the bag window grows." },
  { type = "range", name = "Spacing", min = 0, max = 16, step = 1, get = gapGet, set = gapSet,
    half = "left", desc = "Gap between slots, in every grid." },
  { type = "range", name = "Icon zoom", min = 0.8, max = 1.2, step = 0.01,
    get = zoomGet, set = zoomSet, half = "right",
    desc = "1.00 = icon fills the slot. Less pulls it away from the border, more crops it." },
  { type = "toggle", name = "Merge reagents", col = 1, get = mergeGet, set = mergeSet,
    desc = "Drop the REAGENTS caption and lay the reagent bag out with the main bags." },
  { type = "header", name = "Slot look" },
  { type = "select", name = "Slot background", get = styleGet, set = styleSet,
    keys = function() return STYLES end, label = function(k) return STYLE_LABELS[k] or k end,
    desc = "Fill behind every icon, lightest to darkest. Off leaves the slot empty so the plate shows through." },
  { type = "range", name = "Spacing opacity", min = 0, max = 1, step = 0.01,
    get = gridAlphaGet, set = gridAlphaSet,
    desc = "The plate behind the slots, visible in the gaps — at Spacing 0 there are no gaps to show it." },
  { type = "header", name = "Bank and Warband grid", key = "bankgrid",
    state = function() return ("%d and %d wide"):format(bankColsGet(), wbColsGet()) end },
  { type = "description", section = "bankgrid",
    name = "The bank holds hundreds of slots, so it keeps its own width and icon size, independent of the bags." },
  { type = "range", name = "Icon size", min = 24, max = 56, step = 1, section = "bankgrid",
    get = bankSizeGet, set = bankSizeSet,
    desc = "One icon size for both bank tabs." },
  { type = "range", name = "Bank slots per row", min = 8, max = 40, step = 1, section = "bankgrid",
    get = bankColsGet, set = bankColsSet, half = "left" },
  { type = "range", name = "Warband slots per row", min = 8, max = 40, step = 1,
    section = "bankgrid", get = wbColsGet, set = wbColsSet, half = "right" },
}

local function tipOnGet() return WarpeeDB.tipCounts ~= false end
local function tipOnSet(v) WarpeeDB.tipCounts = v and true or false end
local function tipBankGet() return WarpeeDB.tipBank ~= false end
local function tipBankSet(v) WarpeeDB.tipBank = v and true or false end
local function tipWbGet() return WarpeeDB.tipWarband ~= false end
local function tipWbSet(v) WarpeeDB.tipWarband = v and true or false end
local function tipOff() return not tipOnGet() end

local CHARS_PAGE = {
  { type = "header", name = "Item tooltips",
    state = function() return onOf({ tipOnGet, tipBankGet, tipWbGet }) end },
  { type = "toggle", name = "Count across characters", col = 1, get = tipOnGet, set = tipOnSet,
    desc = "Adds an Inventory block to item tooltips: how many of that item each character carries." },
  { type = "toggle", name = "Include bank", col = 2, get = tipBankGet, set = tipBankSet,
    disabled = tipOff,
    desc = "Count each character's bank too. Off = bags only." },
  { type = "toggle", name = "Include Warband", col = 1, get = tipWbGet, set = tipWbSet,
    disabled = tipOff,
    desc = "Count the shared Warband bank on its own line." },
  { type = "header", name = "Characters" },
  { type = "description",
    name = "Unchecked characters stay saved but are hidden from the character list." },
  { type = "chars" },
}

local function vIlvlGet() return tonumber(WarpeeDB.vendorIlvl) or 0 end
local function vIlvlSet(v)
  WarpeeDB.vendorIlvl = tonumber(v) or 0
  if Bags and Bags.VendorState then Bags:VendorState() end
end
local function vBoEGet() return WarpeeDB.vendorKeepBoE ~= false end
local function vBoESet(v) WarpeeDB.vendorKeepBoE = v and true or false end
local function vWbGet() return WarpeeDB.vendorKeepWarbound ~= false end
local function vWbSet(v) WarpeeDB.vendorKeepWarbound = v and true or false end
local function vGemGet() return WarpeeDB.vendorKeepGems ~= false end
local function vGemSet(v) WarpeeDB.vendorKeepGems = v and true or false end
local function vGreyGet() return WarpeeDB.vendorGrey ~= false end
local function vGreySet(v) WarpeeDB.vendorGrey = v and true or false end
local function vRepGet() return WarpeeDB.vendorRepair and true or false end
local function vRepSet(v) WarpeeDB.vendorRepair = v and true or false end
local REPAIR_BY = { "player", "guild", "both" }
local REPAIR_LABELS = { player = "Your gold", guild = "Guild bank",
                        both = "Guild bank, then your gold" }
local function vRepByGet() return WarpeeDB.vendorRepairBy or "player" end
local function vRepBySet(v) WarpeeDB.vendorRepairBy = v or "player" end
local function vRelicGet() return WarpeeDB.vendorRelics ~= false end
local function vRelicSet(v) WarpeeDB.vendorRelics = v and true or false end

local function vMinGet() return tonumber(WarpeeDB.vendorIlvlMin) or 0 end
local function vMinSet(v) WarpeeDB.vendorIlvlMin = tonumber(v) or 0 end
local function vConsumGet() return WarpeeDB.vendorConsum and true or false end
local function vConsumSet(v) WarpeeDB.vendorConsum = v and true or false end
local function vAutoGet() return WarpeeDB.vendorAuto and true or false end
local function vAutoSet(v) WarpeeDB.vendorAuto = v and true or false end
local function vTokenGet() return WarpeeDB.vendorTokens and true or false end
local function vTokenSet(v) WarpeeDB.vendorTokens = v and true or false end
local function vTokensOff() return not (WarpeeDB.vendorTokens and true or false) end
local function vExpGet(i)
  local t = WarpeeDB.vendorTokenExp
  return (t and t[i]) and true or false
end
local function vExpSet(i, v)
  WarpeeDB.vendorTokenExp = WarpeeDB.vendorTokenExp or {}
  WarpeeDB.vendorTokenExp[i] = v and true or false
end
local function expName(i)
  local n = _G["EXPANSION_NAME" .. i]
  if type(n) == "string" and n ~= "" then return n end
  return "Expansion " .. i
end

SECTION_CLOSED.tokenexp = true
SECTION_CLOSED.locked = true

local VENDOR_PAGE = {
  { type = "header", name = "Gear by item level" },
  { type = "input", name = "Item level from", col = 1, min = 0, max = 9999,
    get = vMinGet, set = vMinSet,
    desc = "Gear at or above this item level is sold, so nothing below it is touched." },
  { type = "input", name = "Item level under", col = 2, min = 0, max = 9999,
    get = vIlvlGet, set = vIlvlSet,
    desc = "Gear under this item level is sold. Zero keeps every piece of gear." },
  { type = "header", name = "Also sell",
    state = function()
      return onOf({ vGreyGet, vRelicGet, vTokenGet, vConsumGet })
    end },
  { type = "toggle", name = "Auto sell junk", col = 1, get = vGreyGet, set = vGreySet,
    desc = "Sell every grey item, whatever it is and whatever its item level. Runs by itself the moment a merchant opens, without pressing the button." },
  { type = "toggle", name = "Legion relics", col = 2, get = vRelicGet, set = vRelicSet,
    desc = "Sell artifact relics from Legion. They have no use and no appearance, so the item level is ignored." },
  { type = "toggle", name = "Tier tokens", col = 1, get = vTokenGet, set = vTokenSet,
    desc = "Sell raid armour tokens that a vendor turns into a set piece, item level ignored. Only the tokens Warpee knows by item id, from the expansions ticked below." },
  { type = "toggle", name = "Old consumables", col = 2, get = vConsumGet, set = vConsumSet,
    desc = "Sell potions, elixirs, flasks, food and bandages from expansions older than the previous one. Off by default, since old food can still be worth keeping." },
  { type = "header", name = "Token expansions", key = "tokenexp",
    state = function()
      local t = WarpeeDB.vendorTokenExp or {}
      local cur = LE_EXPANSION_LEVEL_CURRENT
                  or (GetExpansionLevel and GetExpansionLevel()) or 0
      local n = 0
      for i = 0, cur do if t[i] then n = n + 1 end end
      return ("%d of %d"):format(n, cur + 1)
    end },
  { type = "description", section = "tokenexp",
    name = "Which expansions tier tokens may be sold from. The four newest are kept by default, so the set you are working on stays in the bags." },
  { type = "header", name = "Never sell",
    state = function() return onOf({ vBoEGet, vWbGet, vGemGet }) end },
  { type = "toggle", name = "Keep BoE", col = 1, get = vBoEGet, set = vBoESet,
    desc = "Skip gear that is not bound yet, so it can still go to the auction house." },
  { type = "toggle", name = "Keep warbound", col = 2, get = vWbGet, set = vWbSet,
    desc = "Skip warbound gear. Its appearance is learned only once worn, and an alt can still use it." },
  { type = "toggle", name = "Keep gems and enchants", col = 1, get = vGemGet, set = vGemSet,
    desc = "Skip any piece that has a gem socketed or an enchant applied, so what you paid for is not sold off with it." },
  { type = "header", name = "Locked items", key = "locked",
    state = function()
      local n = 0
      for _ in pairs(WarpeeDB.vendorBlack or {}) do n = n + 1 end
      return (n == 1) and "1 item" or ("%d items"):format(n)
    end },
  { type = "description", section = "locked",
    name = "Alt-click an item in the bags or the bank to lock it, and a small padlock appears on the slot. Alt-click it again, or press the cross here, to unlock. Locked items are never sold, whatever the settings above say." },
  { type = "blacklist", section = "locked" },
  { type = "header", name = "Repair" },
  { type = "toggle", name = "Auto repair", col = 1, get = vRepGet, set = vRepSet,
    desc = "Repair everything as soon as a merchant who offers repairs opens. A merchant without repairs is left alone, with no message." },
  { type = "select", name = "Repair paid by", get = vRepByGet, set = vRepBySet,
    keys = function() return REPAIR_BY end,
    label = function(k) return REPAIR_LABELS[k] or k end,
    desc = "Where the money comes from. The guild bank is used only if your withdraw limit covers the whole bill, otherwise nothing is taken from it." },
  { type = "toggle", name = "Sell on open", col = 1, get = vAutoGet, set = vAutoSet,
    desc = "Run the whole sell list as soon as a merchant window opens, not just the junk." },
}

do
  local cur = LE_EXPANSION_LEVEL_CURRENT
              or (GetExpansionLevel and GetExpansionLevel()) or 0
  local at
  for i, row in ipairs(VENDOR_PAGE) do
    if row.type == "header" and row.name == "Never sell" then at = i; break end
  end
  local rows = {}
  for i = 0, cur do
    rows[#rows + 1] = {
      type = "toggle", name = expName(i), col = (i % 2 == 0) and 1 or 2,
      section = "tokenexp",
      get = function() return vExpGet(i) end,
      set = function(v) vExpSet(i, v) end,
      disabled = vTokensOff,
      desc = "Sell tier tokens from this expansion. Unticked keeps them, so the sets you are still working on stay in the bags.",
    }
  end
  if at then
    for k = #rows, 1, -1 do table.insert(VENDOR_PAGE, at, rows[k]) end
  end
end

local PAGES = {
  { name = "General", list = GENERAL_PAGE },
  { name = "Grid", list = GRID_PAGE },
  { name = "Items", list = ITEMS_PAGE },
  { name = "Vendor", list = VENDOR_PAGE },
  { name = "Characters", list = CHARS_PAGE },
}

local function paintTab(b)
  if b.sel then
    b:SetBackdropColor(Theme:C("panelHi"))
    b:SetBackdropBorderColor(Theme:C("accent"))
    b.Text:SetTextColor(Theme:C("accent"))
  else
    b:SetBackdropColor(Theme:C("panel"))
    b:SetBackdropBorderColor(Theme:C("stroke"))
    b.Text:SetTextColor(Theme:C("dim"))
  end
end

function Options:Select(index)
  closeDropdown()
  self.current = index
  for i, tab in ipairs(self.tabs) do
    tab.sel = (i == index)
    paintTab(tab)
    self.areas[i]:SetShown(i == index)
    self.areas[i].bar:SetShown(i == index)
  end
  local area = self.areas[index]
  area:ScrollTo(0)
  area:PaintBar()
end

function Options:ApplyFont()
  local path = ns.Fonts:Path((Bags and Bags.font) or "Arial Narrow")
  for _, e in ipairs(fonts) do
    e.fs:SetFont(path, math.max(7, BASE_FONT + e.delta), "")
  end
  for _, tab in ipairs(self.tabs) do
    tab:SetWidth(math.max(70, tab.Text:GetStringWidth() + 22))
  end
  for i, area in ipairs(self.areas) do
    area.page.Relayout()
    area:PaintBar()
  end
end

function Options:ReflowPages()
  if not self.areas then return end
  if self.tabs then for _, tab in ipairs(self.tabs) do paintTab(tab) end end
  for _, row in ipairs(rows) do row.Refresh() end
  for _, area in ipairs(self.areas) do
    area.page.Relayout()
    area:PaintBar()
  end
end

function Options:Refresh()
  for _, row in ipairs(rows) do row.Refresh() end
end

function Options:Build()
  if self.frame then return self.frame end


  local f = CreateFrame("Frame", "WarpeeOptionsFrame", UIParent, "BackdropTemplate")
  f:Hide()
  Theme:Panel(f, "bg", "stroke")
  f:SetSize(WIN_W, math.min(WIN_H, UIParent:GetHeight() - 60))
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(s)
    s:StopMovingOrSizing()
    local p, _, rp, x, y = s:GetPoint()
    WarpeeDB.optPos = { p = p, rp = rp, x = x, y = y }
  end)
  f:SetScript("OnMouseDown", function(s) Theme:Raise(s) end)
  Theme:Window(f, "WarpeeOptionsFrame")
  f:SetScript("OnHide", function()
    local row = Options.charsRow
    if row and row.delMode then
      row.delMode = nil
      if row.Rebuild then row.Rebuild() end
    end
    ns.HideTip()
  end)
  self.frame = f

  local title = Theme:Title(f, BASE_FONT + 2, "accent")
  title:SetPoint("TOPLEFT", PAD, -10)
  title:SetText("WARPEE")
  track(title, 2)
  self.title = title

  local close = ns.CreateGlyphButton(f, "×", 28)
  close:SetPoint("TOPRIGHT", -PAD, -8)
  close:SetScript("OnClick", function() self:Close() end)
  track(close.Text, 2)

  local line = Theme:Rect(f, "strokeSoft", "ARTWORK")
  line:SetHeight(1)
  line:SetPoint("TOPLEFT", PAD, -HEADER_H)
  line:SetPoint("TOPRIGHT", -PAD, -HEADER_H)

  self.tabs, self.areas = {}, {}
  local prev
  for i, pageDef in ipairs(PAGES) do
    local tab = ns.CreateButton(f, pageDef.name, 90, TAB_H)
    track(tab.Text, -1)
    tab:SetWidth(math.max(70, tab.Text:GetStringWidth() + 22))
    if prev then
      tab:SetPoint("TOPLEFT", prev, "TOPRIGHT", 5, 0)
    else
      tab:SetPoint("TOPLEFT", PAD, -(HEADER_H + 7))
    end
    tab:HookScript("OnLeave", paintTab)
    tab:SetScript("OnClick", function() self:Select(i) end)
    prev = tab
    self.tabs[i] = tab

    local area = makeScrollArea(f, pageDef.list)
    area:SetPoint("TOPLEFT", PAD, -(HEADER_H + TAB_H + 14))
    area:SetPoint("BOTTOMRIGHT", -(PAD + SCROLL_W + 6), PAD)
    area.bar:SetPoint("TOPLEFT", area, "TOPRIGHT", 6, 0)
    area.bar:SetPoint("BOTTOMLEFT", area, "BOTTOMRIGHT", 6, 0)
    self.areas[i] = area
  end

  self:ApplyFont()
  self:Select(1)
  return f
end

function Options:Open()
  local f = self:Build()
  local pos = WarpeeDB and WarpeeDB.optPos
  f:ClearAllPoints()
  if pos then
    f:SetPoint(pos.p, UIParent, pos.rp, pos.x, pos.y)
  else
    f:SetPoint("CENTER", UIParent, "CENTER", 260, 0)
  end
  self:Refresh()
  self:ApplyFont()
  f:Show()
  Theme:Raise(f)
end

function Options:Close()
  closeDropdown()
  if self.frame then self.frame:Hide() end
end

function Options:Toggle()
  if self.frame and self.frame:IsShown() then self:Close() else self:Open() end
end
