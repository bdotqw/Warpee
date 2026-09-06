local addonName, ns = ...
local Theme = ns.Theme
local Bags = ns.Bags
local L = ns.L
local function T(s)
  if type(s) ~= "string" or s == "" then return s end
  return L[s]
end

local Options = {}
ns.Options = Options

local WIN_W, WIN_H = 700, 700
local PAD = 18
local HEADER_H = 42
local TAB_H = 30
local BASE_FONT = 15
local ROW_GAP = 10
local SCROLL_W = 8
local CONTENT_W = WIN_W - PAD * 2 - SCROLL_W - 6

local function relayout()
  Bags:Refont()
  if Bags.frame and Bags.frame:IsShown() then Bags:Layout() end
  if ns.Bank and ns.Bank.Refresh then ns.Bank:Refresh() end
  if ns.Pocket and ns.Pocket.Apply then ns.Pocket:Apply() end
  if ns.GuildBankSkin and ns.GuildBankSkin.Restyle then ns.GuildBankSkin:Restyle() end
  local P = ns.CharPicker
  if P and P.frame and P.frame:IsShown() and P.Paint then P:Paint(true) end
  C_Timer.After(0, function()
    if Bags.frame and Bags.frame:IsShown() then Bags:FitHeader() end
  end)
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
local function mmHideGet() return WarpeeDB.hideMinimapIcon and true or false end
local function mmHideSet(v)
  WarpeeDB.hideMinimapIcon = v and true or false
  if ns.ApplyMinimapIcon then ns.ApplyMinimapIcon() end
end
local function localeGet() return ns.LocalePick() end
local function localeSet(v)
  WarpeeDB.locale = v
  ns.Fonts:Settle()
  ns.Fonts:Refresh()
  if Options.ReflowPages then Options:ReflowPages() end
  if ns.ApplyLocaleText then ns.ApplyLocaleText() end
  relayout()
  if Options.ApplyFont then Options:ApplyFont() end
end
local function localeKeys() return ns.LOCALES end
local function localeLabel(k) return ns.L[ns.LOCALE_LABELS[k] or k] end

local function sClearGet() return WarpeeDB.searchClear ~= false end
local function sClearSet(v) WarpeeDB.searchClear = v and true or false end
local function sLinkGet() return WarpeeDB.searchLink ~= false end
local function sLinkSet(v) WarpeeDB.searchLink = v and true or false end
local function lockSet(v)
  WarpeeDB.lockWindows = v and true or nil
  ns.ApplyWindowLock()
end
local function hideFieldsGet() return WarpeeDB.hideMoveFields and true or false end
local function hideFieldsSet(v)
  WarpeeDB.hideMoveFields = v and true or nil
  ns.ApplyWindowLock()
end

local ANCHORS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
local ANCHOR_LABELS = { TOPLEFT = "Top left", TOPRIGHT = "Top right",
                        BOTTOMLEFT = "Bottom left", BOTTOMRIGHT = "Bottom right" }
local STYLES = { "flat", "plate", "deep" }
local STYLE_LABELS = { flat = "Transparent", plate = "Highlight", deep = "Solid" }
local THEME_LABELS = {}
for i = #Theme.THEME_ORDER, 1, -1 do
  local k = Theme.THEME_ORDER[i]
  local t = Theme.THEMES[k]
  if t then THEME_LABELS[k] = t.label or k else table.remove(Theme.THEME_ORDER, i) end
end
local function themeGet() return WarpeeDB.theme or "midnight" end
local function themeSet(v)
  WarpeeDB.theme = v
  Theme:Restyle(v)
end

local function fontKeys()
  return ns.Fonts:List()
end

local function tip(frame, text, side)
  if not text then return end
  if frame.EnableMouse then frame:EnableMouse(true) end
  ns.AddTip(frame, function() return T(text) end, side or "right")
end

local fonts = {}
local function track(fs, delta)
  fonts[#fonts + 1] = { fs = fs, delta = delta or 0 }
  return fs
end

local rows = {}
local factories = {}

local SECTION_CLOSED = {}

local bg = { sel = "ilvl" }
bg.aligns = { "left", "right", "center" }
bg.alignOff = { left = 0, center = 0.5, right = 1 }
bg.alignLabels = { left = "Grows left to right", right = "Grows right to left",
                   center = "Grows from the center" }
bg.alignKeys = function() return bg.aligns end
bg.alignLabel = function(k) return bg.alignLabels[k] or bg.alignLabels.left end
bg.alignOf = function(g)
  local a = g and g.a
  if a and bg.alignOff[a] then return a end
  return ((g and g.c) or ""):find("LEFT") and "left" or "right"
end
bg.cur = function() return ns.Badge(bg.sel) end
bg.def = function() return ns.BADGE[bg.sel] or ns.BADGES[1] end
bg.bump = function()
  Bags.styleGen = (Bags.styleGen or 0) + 1
  if bg.repaint then bg.repaint() end
  relayout()
end
bg.soloGet = function() return WarpeeDB.badgeSolo and true or false end
bg.soloSet = function(v)
  WarpeeDB.badgeSolo = v and true or false
  if bg.repaint then bg.repaint() end
end
bg.getter = function(f) return function() return bg.cur()[f] end end
bg.setter = function(f) return function(v) bg.cur()[f] = v; bg.bump() end end
bg.pin = function(f, v) return bg.fit and bg.fit(f, v) or bg.clamp(v) end
bg.reseat = function(g)
  g.x, g.y = bg.pin("x", g.x), bg.pin("y", g.y)
end
bg.cGet = bg.getter("c")
bg.cSet = function(v)
  local g = bg.cur()
  g.c = v
  bg.reseat(g)
  bg.bump()
end
bg.aGet = function() return bg.alignOf(bg.cur()) end
bg.aSet = function(v)
  local g = bg.cur()
  local old = bg.alignOf(g)
  if old == v or not bg.alignOff[v] then return end
  local w = bg.spanW and bg.spanW(bg.sel) or 0
  g.a = v
  g.x = bg.pin("x", (g.x or 0) + (bg.alignOff[v] - bg.alignOff[old]) * w)
  bg.bump()
end
bg.xGet, bg.yGet = bg.getter("x"), bg.getter("y")
bg.xSet = function(v) bg.cur().x = bg.pin("x", v); bg.bump() end
bg.ySet = function(v) bg.cur().y = bg.pin("y", v); bg.bump() end
bg.sGet = bg.getter("s")
bg.sSet = function(v)
  local g = bg.cur()
  g.s = v
  bg.bump()
  local x, y = bg.pin("x", g.x), bg.pin("y", g.y)
  if x ~= g.x or y ~= g.y then g.x, g.y = x, y; bg.bump() end
end
bg.kGet = function() return bg.cur().k or 4 end
bg.kSet = bg.setter("k")
bg.isTex   = function() return bg.def().tex and true or false end
bg.isText  = function() return not bg.def().tex end
bg.notFit  = function() return bg.sel ~= "outfit" end
bg.label   = function(key) return (ns.BADGE[key] or {}).n or key end
bg.prev    = 132
bg.max     = 56
bg.clamp   = function(v)
  v = math.floor(v + 0.5)
  if v > bg.max then return bg.max elseif v < -bg.max then return -bg.max end
  return v
end
bg.shown = function()
  local n = 0
  for _, d in ipairs(ns.BADGES) do if ns.Badge(d.key).on then n = n + 1 end end
  return n
end

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
  return (L["%d of %d"]):format(n, #list)
end

local dropdown

local function closeDropdown()
  if dropdown then dropdown:Hide() end
end
ns.CloseDropdown = closeDropdown

local function dropdownFont()
  return ns.Fonts:Current()
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

  r:SetScript("OnEnter", function(s)
    s.bg:Show()
    if dropdown and dropdown.desc then
      ns.ShowTip(s, { { text = dropdown.desc } }, "right")
    end
  end)
  r:SetScript("OnLeave", function(s) s.bg:Hide(); ns.HideTip() end)
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
    local v = math.min(span, math.max(0, s:GetVerticalScroll() - d * 40))
    s:SetVerticalScroll(math.min(span, ns.SnapScroll(s, v)))
  end)

  m.rows, m.sf, m.child, m.catcher = {}, sf, child, catcher
  m:SetScript("OnHide", function() catcher:Hide(); ns.HideTip() end)
  catcher:SetScript("OnClick", closeDropdown)
  ns.EscClose(m)
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
    r.Text:SetFont(dropdownFont(), BASE_FONT - 1, "")
    r.Text:SetText(T(spec.label(key)))
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
  ns.SnapSize(m, w, visible * rowH + 8)
  m.child:SetSize(w - 8, #keys * rowH)

  local span = math.max(0, #keys * rowH - visible * rowH)
  m.sf:SetVerticalScroll(math.min(span, ns.SnapScroll(m.sf, (curIndex - 1) * rowH - rowH * 3)))

  m.owner = anchor
  m.desc = spec.desc
  ns.HideTip()
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
  return ns.ArrowGlyph(parent, dir, dir == "down" and 10 or 12)
end

function factories.header(parent, spec)
  local row = CreateFrame(spec.key and "Button" or "Frame", nil, parent)
  row:SetHeight(30)
  local line = Theme:Rect(row, "strokeSoft", "ARTWORK")
  ns.PixelLine(line, 1)
  line:SetPoint("BOTTOMLEFT", 0, 0)
  line:SetPoint("BOTTOMRIGHT", 0, 0)
  local fs = track(Theme:Label(row, BASE_FONT, "azure"), 0)
  fs:SetPoint("BOTTOMLEFT", spec.key and 22 or 0, 6)
  fs:SetText(T(spec.name):upper())
  if not spec.key then
    local plain = spec.state and track(Theme:Label(row, BASE_FONT - 3, "faint"), -3)
    if plain then plain:SetPoint("BOTTOMRIGHT", 0, 7) end
    row.Refresh = function()
      fs:SetText(T(spec.name):upper())
      if plain then plain:SetText((spec.state and spec.state()) or "") end
    end
    row.Refresh()
    return row
  end

  local down = caretGroup(row, "down")
  down:SetPoint("BOTTOMLEFT", 0, 8)
  local right = caretGroup(row, "right")
  right:SetPoint("BOTTOMLEFT", 3, 5)
  local state = track(Theme:Label(row, BASE_FONT - 3, "faint"), -3)
  state:SetPoint("BOTTOMRIGHT", 0, 7)

  row.Refresh = function()
    fs:SetText(T(spec.name):upper())
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
  fs:SetText(T(spec.name))
  row:SetHeight(fs:GetStringHeight() + 6)
  row.autoHeight = fs
  row.Refresh = function() fs:SetText(T(spec.name)) end
  return row
end

function factories.toggle(parent, spec)
  local row = CreateFrame("Button", nil, parent)
  row:SetHeight(26)

  local box = ns.CreateCheckBox(row, 18)
  ns.SnapPoint(box, "TOPLEFT", row, "TOPLEFT", 1, -4)
  local mark = box.mark

  local fs = track(Theme:Label(row, BASE_FONT, "text"), 0)
  fs:SetPoint("LEFT", box, "RIGHT", 8, 0)
  fs:SetPoint("RIGHT", -2, 0)
  fs:SetJustifyH("LEFT")
  local function paintBox(hover)
    if row.off then
      box:SetKeys("slot", "strokeSoft", "faint")
    elseif row.on then
      box:SetKeys("slot", "bg", hover and "accentInk" or "accent")
    else
      box:SetKeys("slot", hover and "accent" or "stroke", "accent")
    end
  end
  row.Refresh = function()
    if type(spec.name) == "function" then
      fs:SetText(T(spec.name()) or "")
    else
      fs:SetText(T(spec.name))
    end
    local off = (spec.disabled and spec.disabled()) and true or false
    local on = spec.get() and true or false
    mark:SetShown(on)
    fs:SetTextColor(Theme:C(off and "faint" or (on and "text" or "dim")))
    row:SetEnabled(not off)
    row.off, row.on = off, on
    paintBox(not off and row:IsMouseOver())
  end
  row:SetScript("OnClick", function()
    if row.off then return end
    spec.set(not spec.get())
    row.Refresh()
    Options:Refresh()
  end)
  row:SetScript("OnEnter", function()
    if row.off then return end
    paintBox(true)
  end)
  row:SetScript("OnLeave", function()
    paintBox(false)
  end)
  row.Refresh()
  tip(row, spec.desc)
  return row
end

local KEY_MODS = {
  LCTRL = true, RCTRL = true, LSHIFT = true, RSHIFT = true, LALT = true, RALT = true,
}

-- Click the button, press a key, done: the binding is written the way the game stores
-- them, so the client's own key list stays in sync. Escape cancels, a right click
-- unbinds. SetBinding is protected in combat, so capture never starts there, and a
-- press that lands mid combat is dropped instead of applied.
-- The capture itself follows the game's own KeybindListener shape: one top level
-- button, no parent, that receives OnKeyDown only while its script is set. A nested
-- button inside the options window never sees a keypress arrive, no matter how it is
-- enabled, which is why the capture does not live on the visible button.
local keyListener = CreateFrame("Button")
keyListener:SetSize(1, 1)
keyListener:EnableMouse(false)
keyListener:SetFrameStrata("DIALOG")
local keyListen = nil

local function listenerKeyDown(_, key)
  if not keyListen then return end
  local swallow = keyListener.SetPropagateKeyboardInput
  if swallow then pcall(swallow, keyListener, false) end
  keyListen(key)
end

local function startListen(fn)
  keyListen = fn
  keyListener:SetScript("OnKeyDown", listenerKeyDown)
  keyListener:Show()
end

local function stopListen()
  if not keyListen then return end
  keyListen = nil
  keyListener:SetScript("OnKeyDown", nil)
  keyListener:Hide()
end

function factories.keybind(parent, spec)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(46)

  local nameFS = track(Theme:Label(row, BASE_FONT, "text"), 0)
  nameFS:SetPoint("TOPLEFT", 1, -1)
  nameFS:SetText(T(spec.name))

  local btn = CreateFrame("Button", nil, row, "BackdropTemplate")
  ns.SnapBox(btn, nil, 24)
  btn:SetPoint("BOTTOMLEFT", 1, 0)
  btn:SetPoint("BOTTOMRIGHT", -1, 0)
  ns.PixelBackdrop(btn)
  btn:SetBackdropColor(Theme:C("panel"))
  btn:SetBackdropBorderColor(Theme:C("stroke"))
  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  local cur = track(Theme:Label(btn, BASE_FONT - 1, "text"), -1)
  cur:SetPoint("CENTER")
  local capturing = false

  local function keyText()
    local k = GetBindingKey and GetBindingKey(spec.binding)
    if k and k ~= "" then return k end
    return T("Not bound")
  end

  local function paint()
    if capturing then
      cur:SetText(T("Press a key..."))
      cur:SetTextColor(Theme:C("accent"))
      btn:SetBackdropBorderColor(Theme:C("accent"))
    else
      cur:SetText(keyText())
      cur:SetTextColor(Theme:C("text"))
      btn:SetBackdropBorderColor(Theme:C("stroke"))
    end
    btn:SetBackdropColor(Theme:C("panel"))
  end

  local function stop()
    if not capturing then return end
    capturing = false
    stopListen()
    paint()
  end

  local function save()
    SaveBindings((GetCurrentBindingSet and GetCurrentBindingSet()) or 1)
  end

  local function onKey(key)
    if not capturing then stopListen() return end
    if key == "ESCAPE" then stop() return end
    if KEY_MODS[key] then return end
    stop()
    if InCombatLockdown() then return end
    local combo = (IsControlKeyDown() and "CTRL-" or "")
               .. (IsAltKeyDown() and "ALT-" or "")
               .. (IsShiftKeyDown() and "SHIFT-" or "")
               .. key
    local k1, k2 = GetBindingKey(spec.binding)
    if k1 then SetBinding(k1) end
    if k2 then SetBinding(k2) end
    if SetBinding(combo, spec.binding) then save() end
    paint()
  end

  row.Refresh = function()
    nameFS:SetText(T(spec.name))
    paint()
  end

  btn:SetScript("OnEnter", function(s)
    if capturing then return end
    s:SetBackdropColor(Theme:C("panelHi"))
    s:SetBackdropBorderColor(Theme:C("accent"))
  end)
  btn:SetScript("OnLeave", function(s)
    if capturing then return end
    paint()
  end)

  btn:SetScript("OnClick", function(_, button)
    if capturing then stop() return end
    if button == "RightButton" then
      if InCombatLockdown() then return end
      local k1, k2 = GetBindingKey and GetBindingKey(spec.binding)
      if k1 then SetBinding(k1) end
      if k2 then SetBinding(k2) end
      if k1 or k2 then save() end
      paint()
      return
    end
    if InCombatLockdown() then return end
    capturing = true
    startListen(onKey)
    paint()
  end)

  btn:SetScript("OnHide", stop)
  row:SetScript("OnHide", stop)
  paint()
  return row
end

function factories.input(parent, spec)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(28)

  local fs = track(Theme:Label(row, BASE_FONT, "text"), 0)
  fs:SetPoint("LEFT", 1, 0)
  fs:SetText(T(spec.name))

  local box = CreateFrame("EditBox", nil, row, "BackdropTemplate")
  ns.SnapBox(box, 66, 24, true)
  ns.SnapPoint(box, "TOPRIGHT", row, "TOPRIGHT", -1, -2)
  ns.PixelBackdrop(box)
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
    fs:SetText(T(spec.name))
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
  fs:SetText(T(spec.name))

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
    if spec.format then return spec.format(v) end
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
    if math.abs((spec.get() or 0) - v) > 1e-4 then
      spec.set(v)
      local now = spec.get()
      if now and math.abs(now - v) > 1e-4 then
        sl.quiet = true
        sl:SetValue(now)
        sl.quiet = nil
        paint(now)
      end
      Options:Refresh()
    end
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
    fs:SetText(T(spec.name))
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
  local bare = (spec.name == nil or spec.name == "")
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(bare and 26 or 46)

  local nameFS
  if not bare then
    nameFS = track(Theme:Label(row, BASE_FONT, "text"), 0)
    nameFS:SetPoint("TOPLEFT", 1, -1)
    nameFS:SetText(T(spec.name))
  end

  local btn = CreateFrame("Button", nil, row, "BackdropTemplate")
  ns.SnapBox(btn, nil, 24)
  btn:SetPoint("BOTTOMLEFT", 1, bare and 1 or 0)
  btn:SetPoint("BOTTOMRIGHT", -1, bare and 1 or 0)
  ns.PixelBackdrop(btn)
  btn:SetBackdropColor(Theme:C("panel"))
  btn:SetBackdropBorderColor(Theme:C("stroke"))

  local cur = track(Theme:Label(btn, BASE_FONT - 1, "text"), -1)
  cur:SetPoint("LEFT", 7, 0)
  cur:SetPoint("RIGHT", -18, 0)
  cur:SetJustifyH("LEFT")

  local arrowBox = ns.ArrowGlyph(btn, "down", 9)
  arrowBox:SetPoint("RIGHT", -7, 0)
  local function arrowColor(key) arrowBox:SetTint(key) end

  row.Refresh = function()
    local off = (spec.disabled and spec.disabled()) and true or false
    row.off = off
    if nameFS then nameFS:SetText(T(spec.name)) end
    cur:SetText(T(spec.label(spec.get())) or "")
    cur:SetTextColor(Theme:C(off and "faint" or "text"))
    btn:SetBackdropColor(Theme:C("panel"))
    btn:SetBackdropBorderColor(Theme:C(off and "strokeSoft" or "stroke"))
    arrowColor(off and "faint" or "dim")
    btn:SetEnabled(not off)
  end
  row.Refresh()

  btn:SetScript("OnEnter", function(s)
    local open = dropdown and dropdown:IsShown() and dropdown.owner == s
    if spec.desc and not open then ns.ShowTip(row, { { text = spec.desc } }, "top") end
    if row.off then return end
    s:SetBackdropColor(Theme:C("panelHi"))
    s:SetBackdropBorderColor(Theme:C("accent"))
    arrowColor("accent")
  end)
  btn:SetScript("OnLeave", function(s)
    ns.HideTip()
    if row.off then return end
    s:SetBackdropColor(Theme:C("panel"))
    s:SetBackdropBorderColor(Theme:C("stroke"))
    arrowColor("dim")
  end)
  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  btn:SetScript("OnClick", function(s, button)
    if row.off then return end
    if button == "RightButton" then
      cycle(spec, -1)
      row.Refresh()
      return
    end
    openDropdown(s, spec, row.Refresh)
  end)
  tip(row, spec.desc, "top")
  return row
end

local CLASS_RING = "Interface\\TargetingFrame\\UI-Classes-Circles"
local CHAR_COLS = 3
local CHAR_CELL_H, CHAR_HEAD_H, CHAR_DEL_H = 24, 22, 26

local function charHead(row, i)
  local h = row.heads[i]
  if h then return h end
  h = CreateFrame("Frame", nil, row)
  h:SetHeight(CHAR_HEAD_H)
  local line = Theme:Rect(h, "strokeSoft", "ARTWORK")
  ns.PixelLine(line, 1)
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
  if Bags and Bags.BrowseState then Bags:BrowseState() end
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

local function dropWarband()
  if not ns.Vault:DropWarband() then return end
  if ns.Bank and ns.Bank.frame and ns.Bank.frame:IsShown() then ns.Bank:Repaint() end
  if Bags and Bags.BrowseState then Bags:BrowseState() end
  if ns.Options and ns.Options.ReflowPages then ns.Options:ReflowPages() end
end

StaticPopupDialogs["WARPEE_DROP_WARBAND"] = {
  text = "Delete the saved Warband bank?",
  button1 = _G.DELETE or "Delete",
  button2 = _G.CANCEL or "Cancel",
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  showAlert = true,
  OnAccept = function() dropWarband() end,
}

local function charCell(row, i)
  local c = row.cells[i]
  if c then return c end
  c = CreateFrame("Button", nil, row)
  c:SetHeight(CHAR_CELL_H)
  local box = ns.CreateCheckBox(c, 16)
  ns.SnapPoint(box, "TOPLEFT", c, "TOPLEFT", 1, -4)
  local mark = box.mark
  local minus = Theme:Rect(box, "gaugeHi", "OVERLAY")
  ns.PixelLine(minus, 2)
  minus:SetPoint("LEFT", box, "LEFT", ns.PixelFloor(box, 3), 0)
  minus:SetPoint("RIGHT", box, "RIGHT", -ns.PixelFloor(box, 3), 0)
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
    if row.delMode then
      s.box:SetKeys(nil, "gaugeHi", nil)
      s.Text:SetTextColor(Theme:C("gaugeHi"))
      return
    end
    if s.warband then return end
    if not ns.Vault:Hidden(s.key or "") then
      s.box:SetKeys(nil, "bg", "accentInk")
    else
      s.box:SetKeys(nil, "accent", nil)
    end
  end)
  c:SetScript("OnLeave", function(s)
    s:Paint()
  end)
  c:SetScript("OnClick", function(s)
    if s.warband then
      if not row.delMode then return end
      StaticPopupDialogs["WARPEE_DROP_WARBAND"].text = L["Delete the saved Warband bank?"]
      StaticPopup_Show("WARPEE_DROP_WARBAND")
      return
    end
    if not s.key then return end
    if row.delMode then
      StaticPopupDialogs["WARPEE_DROP_CHAR"].text = L["Delete saved bags and bank of %s?"]
      StaticPopup_Show("WARPEE_DROP_CHAR", s.Text:GetText() or s.key, nil, s.key)
      return
    end
    ns.Vault:SetHidden(s.key, not ns.Vault:Hidden(s.key))
    s:Paint()
    if s:IsMouseOver() then s:GetScript("OnEnter")(s) end
  end)
  c.Paint = function(s)
    if s.warband then
      s.mark:SetShown(not row.delMode)
      s.minus:SetShown(row.delMode and true or false)
      s.box:SetKeys("slot", row.delMode and "gaugeHi" or "strokeSoft",
        row.delMode and "accent" or "dim")
      s.Text:SetTextColor(Theme:C(row.delMode and "text" or "dim"))
      return
    end
    local on = not ns.Vault:Hidden(s.key or "")
    if row.delMode then
      s.mark:Hide()
      s.minus:Show()
      s.box:SetKeys("slot", "gaugeHi", "accent")
      s.Text:SetTextColor(Theme:C(on and "text" or "dim"))
    else
      s.minus:Hide()
      s.mark:SetShown(on)
      s.box:SetKeys("slot", on and "bg" or "stroke", "accent")
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

  local del = ns.CreateButton(row, L["Delete mode"], 104, CHAR_DEL_H)
  ns.LocalText(del, "Delete mode")
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
    local wbSaved = (ns.Vault and ns.Vault:Saved("warband")) and true or false
    if #list == 0 and not wbSaved then row.delMode = nil end
    local path = ns.Fonts:Current()
    local colW = math.floor((CONTENT_W - (CHAR_COLS - 1) * 8) / CHAR_COLS)
    del.Text:SetFont(path, math.max(7, BASE_FONT - 1), "")
    del:SetWidth(math.max(104, math.ceil(del.Text:GetStringWidth()) + 26))
    del:SetShown(#list > 0 or wbSaved)
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
      c.key, c.warband = e.key, nil
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
    if wbSaved then
      if y > 0 then y = y + 6 end
      hi = hi + 1
      local h = charHead(row, hi)
      h:ClearAllPoints()
      h:SetPoint("TOPLEFT", 0, -y)
      h:SetPoint("TOPRIGHT", 0, -y)
      h.Text:SetText((L["Account"]):upper())
      h.Text:SetFont(path, math.max(7, BASE_FONT - 3), "")
      h:Show()
      y = y + CHAR_HEAD_H + 2
      ci = ci + 1
      local c = charCell(row, ci)
      c.key, c.warband = nil, true
      c:SetWidth(colW)
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", 0, -y)
      c.icon:Hide()
      c.Text:SetText(L["Warband bank"])
      c.Text:SetFont(path, math.max(7, BASE_FONT - 2), "")
      c:Paint()
      c:Show()
      y = y + CHAR_CELL_H
    end
    for i = hi + 1, #row.heads do row.heads[i]:Hide() end
    for i = ci + 1, #row.cells do row.cells[i]:Hide() end
    if #list > 0 or wbSaved then
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
    if c.id and ns.Vendor and ns.Vendor:Blocked(c.id) then ns.Vendor:Toggle(c.id) end
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
  empty:SetText(L["Alt-click an item in your bags while this tab is open."])
  ns.LocalText(empty, "Alt-click an item in your bags while this tab is open.")
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
  mark:SetFrameLevel(cell:GetFrameLevel() + 1)
  mark:Hide()

  local readout = track(Theme:Label(row, BASE_FONT - 1, "accentInk"), -1)
  readout:SetJustifyH("LEFT")

  local art, chips = {}, {}
  for _, d in ipairs(ns.BADGES) do
    if d.tex then
      local t = cell:CreateTexture(nil, "OVERLAY")
      ns.BadgeArt(t, d.key)
      art[d.key] = t
    else
      art[d.key] = Theme:Label(cell, BASE_FONT, "overlay")
    end
  end

  local function factor() return PREV / (Bags.iconSize or 40) end

  local function measure(key)
    local d = ns.BADGE[key] or ns.BADGES[1]
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
    c:SetBackdropColor(Theme:C(hover and "panelHi" or "panel"))
    c:SetBackdropBorderColor(Theme:C(sel and "accent" or (hover and "accentInk" or "stroke")))
    c.Text:SetTextColor(Theme:C((not on) and "faint" or (sel and "accentInk" or "text")))
  end

  local function paint()
    local f, solo = factor(), bg.soloGet()
    cell:SetBackdropColor(Theme:C("panel"))
    cell:SetBackdropBorderColor(Theme:C("stroke"))
    mark:SetBackdropColor(0, 0, 0, 0)
    mark:SetBackdropBorderColor(Theme:C("accent"))
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
        ns.SetOutlined(o, math.max(6, math.floor((g.s or d.s) * f + 0.5)))
        o:SetText(ns.BadgeSample(d.key) or d.key)
        o:SetTextColor(cr, cg, cb, dim)
      end
      o:SetDrawLayer("OVERLAY", sel and 7 or 5)
      o:ClearAllPoints()
      o:SetPoint(ns.BadgePoint(g), cell, g.c, (g.x or 0) * f, (g.y or 0) * f)
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
    for _, c in ipairs(chips) do paintChip(c) end
  end

  local function layoutChips()
    local path, gap, cols = ns.Fonts:Current(), 6, 3
    local w = math.floor((CONTENT_W - gap * (cols - 1)) / cols)
    for i, c in ipairs(chips) do
      c.Text:SetFont(path, BASE_FONT - 2, "")
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
      if button == "RightButton" then
        if g.on then g.on = false; bg.bump() end
      else
        if not g.on then g.on = true; bg.bump() end
        bg.sel = s.wpeKey
      end
      Options:ReflowPages()
    end)
    tip(c, d.t, "top")
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
    for _, d in ipairs(ns.BADGES) do
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
    paint()
    local moved = false
    for _, d in ipairs(ns.BADGES) do
      local g = ns.Badge(d.key)
      local x, y = bg.fit("x", g.x, d.key), bg.fit("y", g.y, d.key)
      if x ~= g.x or y ~= g.y then g.x, g.y = x, y; moved = true end
    end
    if moved then bg.bump() end
    row:SetHeight(h + PREV + 26)
  end
  row.Rebuild = row.Refresh
  bg.repaint = paint
  row.Refresh()
  tip(cell, spec.desc)
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
        local function advance(extra)
          y = ns.SnapValue(row, y + row:GetHeight() + extra)
        end
        row:SetHeight(ns.SnapEven(row, row:GetHeight()))
        local sy = ns.SnapValue(row, y)
        if spec.col then
          local total = spec.of or 2
          local colW = total == 3 and thirdW or halfW
          row:SetWidth(colW)
          ns.SnapPoint(row, "TOPLEFT", page, "TOPLEFT",
            (spec.col - 1) * (colW + (total == 3 and 10 or 14)), -sy)
          local nextCol = nx and nx.col
          if spec.col >= total or not nextCol or nextCol <= spec.col then
            advance(ROW_GAP)
          end
        elseif spec.half == "left" then
          ns.SnapPoint(row, "TOPLEFT", page, "TOPLEFT", 0, -sy)
          row:SetWidth(halfW)
          if not (nx and nx.half == "right") then advance(ROW_GAP) end
        elseif spec.half == "right" then
          ns.SnapPoint(row, "TOPRIGHT", page, "TOPRIGHT", 0, -sy)
          row:SetWidth(halfW)
          advance(ROW_GAP)
        else
          ns.SnapPoint(row, "TOPLEFT", page, "TOPLEFT", 0, -sy)
          ns.SnapPoint(row, "TOPRIGHT", page, "TOPRIGHT", 0, -sy)
          advance(spec.type == "header" and 7 or ROW_GAP)
        end
      end
    end
    page:SetHeight(ns.SnapValue(page, y + 4))
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
  local thumbTex = Theme:Rect(thumb, "faint", "ARTWORK")
  thumbTex:SetAllPoints(thumb)
  sf.bar, sf.page = bar, page

  local function range()
    return math.max(0, page:GetHeight() - sf:GetHeight())
  end

  local function paintBar()
    local span, view = range(), sf:GetHeight()
    if span <= 0 or not sf:IsShown() then bar:Hide(); return end
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
    sf:SetVerticalScroll(math.min(span, ns.SnapScroll(sf, v)))
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
    thumbTex:SetVertexColor(Theme:C("faint"))
  end)
  thumb:SetScript("OnEnter", function() thumbTex:SetVertexColor(Theme:C("dim")) end)
  thumb:SetScript("OnLeave", function(s)
    if not s:GetScript("OnUpdate") then thumbTex:SetVertexColor(Theme:C("faint")) end
  end)
  return sf
end

local colsGet, colsSet       = field("cols")
local sizeGet, sizeSet       = field("iconSize")
local gapGet, gapSet         = field("gap")
local styleGet, styleSet     = styleField("slotStyle")
local fontGet, fontSet       = styleField("font")
local zoomGet, zoomSet       = styleField("iconZoom")
local edgeGet, edgeSet       = styleField("borderWidth")
local mergeGet, mergeSet     = field("mergeReagents")
local flow = {}
flow.topGet, flow.topSet = field("reagentTop")
flow.hideGet, flow.hideSet = field("hideReagents")
flow.offGet = function() return mergeGet() or flow.hideGet() end
flow.revGet, flow.revSet = field("revFill")
flow.upGet, flow.upSet   = field("fillUp")
local questGet, questSet     = styleField("questMarks")
local newGet, newSet         = styleField("newItemGlow")
local function gridAlphaGet() return Theme:GridAlpha() end
local function gridAlphaSet(v) WarpeeDB.gridAlpha = v; Theme:ApplyGridAlpha() end
local gaugeGet, gaugeSet     = field("showGauge")
local fav = {}
fav.showGet = function() return ns.Fav:Enabled() end
fav.showSet = function(v)
  WarpeeDB.favShow = v and true or false
  relayout()
end
fav.countGet = function() return ns.Fav:Count() end
fav.countSet = function(v)
  WarpeeDB.favCount = tonumber(v) or 6
  relayout()
end
fav.recentGet = function() return ns.Recent and ns.Recent:Enabled() end
fav.recentSet = function(v)
  WarpeeDB.recentShow = v and true or false
  relayout()
end
fav.pkGet = function() return ns.Pocket and ns.Pocket:Enabled() end
fav.pkSet = function(v)
  WarpeeDB.pocketShow = v and true or false
  if ns.Pocket then ns.Pocket:Apply() end
  relayout()
end
fav.pkRowsGet = function() return ns.Pocket and ns.Pocket:Rows() or 5 end
fav.pkRowsSet = function(v)
  WarpeeDB.pocketRows = tonumber(v) or 5
  if ns.Pocket then ns.Pocket:Refresh() end
end
fav.pkColsGet = function() return ns.Pocket and ns.Pocket:Cols() or 6 end
fav.pkColsSet = function(v)
  WarpeeDB.pocketCols = tonumber(v) or 6
  if ns.Pocket then ns.Pocket:Refresh() end
end
fav.pkSizeGet = function()
  return tonumber(WarpeeDB.pocketIconSize) or (Bags.iconSize or 40)
end
fav.pkSizeSet = function(v)
  WarpeeDB.pocketIconSize = tonumber(v) or 40
  if ns.Pocket then ns.Pocket:Refresh() end
end
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
local qColorGet, qColorSet   = styleField("qualityColorIlvl")
local qBorderGet, qBorderSet = styleField("qualityBorder")
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
    desc = "Color scheme for the whole addon." },
  { type = "select", name = "Font", get = fontGet,
    set = function(v) WarpeeDB.fontWish = nil; fontSet(v); Options:ApplyFont() end,
    keys = fontKeys, label = function(k) return k end,
    desc = "Used for every label Warpee draws. Other addons can add to this list." },
  { type = "select", name = "Language", get = localeGet, set = localeSet,
    keys = localeKeys, label = localeLabel,
    desc = "Language for the addon's own text. Item names always come from the game." },
  { type = "header", name = "Windows" },
  { type = "toggle", name = "Lock windows", col = 1, get = lockGet, set = lockSet,
    desc = "Freeze every window in place. Unlocked, the bags and the bank show X/Y fields along their bottom edge. Type a value, or nudge with the arrows (Shift = 10)." },
  { type = "toggle", name = "Hide X/Y fields", col = 2, get = hideFieldsGet, set = hideFieldsSet,
    disabled = function() return lockGet() end,
    desc = "The windows stay movable by dragging, but the X/Y fields are not drawn." },
  { type = "toggle", name = "Capacity bar", col = 1, get = gaugeGet, set = gaugeSet,
    desc = "Fill bar in the bags header showing how full they are." },
  { type = "toggle", name = "Hide minimap icon", col = 2, get = mmHideGet, set = mmHideSet,
    desc = "Takes the Warpee button off the minimap." },
  { type = "header", name = "Search" },
  { type = "toggle", name = "Clear on close", col = 1, get = sClearGet, set = sClearSet,
    desc = "Empty the search box when the window closes, so it opens unfiltered next time." },
  { type = "toggle", name = "Bags and bank together", col = 2, get = sLinkGet, set = sLinkSet,
    desc = "While both windows are open, typing in either box searches both at once." },
  { type = "header", name = "Money" },
  { type = "select", name = "Gold format", get = goldFmtGet, set = goldFmtSet,
    keys = function() return GOLD_FORMATS end, label = function(k) return GOLD_FORMAT_LABELS[k] or k end,
    desc = "Grouping for printed amounts. Short abbreviates to K and M." },
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

local POCKET_PAGE = {
  { type = "header", name = "Pocket" },
  { type = "toggle", name = "Pocket window", col = 1, get = fav.pkGet, set = fav.pkSet,
    desc = "A small window of bookmark cells beside the bags, opened by the grid button in the header. Drag an item into a cell and the cell keeps it, wherever the item moves in your bags. Drag a cell onto another to swap them, and Ctrl + left click empties one." },
  { type = "range", name = "Pocket rows", min = 1, max = 6, step = 1, half = "left",
    get = fav.pkRowsGet, set = fav.pkRowsSet,
    disabled = function() return not fav.pkGet() end },
  { type = "range", name = "Slots per row", min = 4, max = 8, step = 1, half = "right",
    get = fav.pkColsGet, set = fav.pkColsSet,
    disabled = function() return not fav.pkGet() end },
  { type = "range", name = "Pocket slot size", min = 24, max = 56, step = 1, half = "left",
    get = fav.pkSizeGet, set = fav.pkSizeSet,
    disabled = function() return not fav.pkGet() end },
  { type = "keybind", name = "Pocket key", binding = "WARPEE_POCKET", half = "right" },
}

local ITEMS_PAGE = {
  { type = "header", name = "Markers" },
  { type = "toggle", name = "Reagent border", col = 1,
    get = function() return Bags.reagentTint end,
    set = function(v)
      Bags.reagentTint = v
      WarpeeDB.reagentTint = v
      Bags.styleGen = (Bags.styleGen or 0) + 1
      relayout()
    end,
    desc = "Tint the slots of the reagent bag and the reagent bank." },
  { type = "toggle", name = "Quality border", col = 2, get = qBorderGet, set = qBorderSet,
    desc = "A border around every item in its quality color." },
  { type = "toggle", name = "Quest marker", col = 1, get = questGet, set = questSet,
    desc = "Blizzard quest art: a mark for unaccepted quests, a border for quest items." },
  { type = "toggle", name = "New item glow", col = 2, get = newGet, set = newSet,
    desc = "Quality-colored glow on items the game still counts as new." },
  { type = "toggle", name = "Item level by quality", col = 1, get = qColorGet, set = qColorSet,
    disabled = function() return not ns.Badge("ilvl").on end,
    desc = "Tint the item level number with the item's quality color." },
  { type = "range", name = "Border thickness", min = 1, max = 6, step = 1,
    get = edgeGet, set = edgeSet,
    desc = "Thickness of the slot border." },
  { type = "header", name = "Badges", key = "badges",
    state = function()
      return ("%s, %d/%d"):format(T(bg.label(bg.sel)), bg.shown(), #ns.BADGES)
    end },
  { type = "badges", section = "badges",
    desc = "Drag a badge, or click where you want it. Left-click a name to show that badge, right-click the name to hide it." },
  { type = "toggle", name = "Show only the selected badge", col = 1, section = "badges",
    get = bg.soloGet, set = bg.soloSet,
    desc = "In the cell above, hide every badge except the selected one." },
  { type = "select", col = 2, section = "badges", get = bg.aGet, set = bg.aSet,
    keys = bg.alignKeys, label = bg.alignLabel, hidden = bg.isTex,
    desc = "Growth direction: which way the badge grows when the value gets longer." },
  { type = "select", name = "Corner", get = bg.cGet, set = bg.cSet, section = "badges",
    keys = anchorKeys, label = anchorLabel,
    desc = "Which corner of the slot the badge is pinned to." },
  { type = "range", name = "X offset", min = -56, max = 56, step = 1, section = "badges",
    get = bg.xGet, set = bg.xSet, half = "left" },
  { type = "range", name = "Y offset", min = -56, max = 56, step = 1, section = "badges",
    get = bg.yGet, set = bg.ySet, half = "right" },
  { type = "range", name = "Text size", min = 6, max = 24, step = 1, section = "badges",
    get = bg.sGet, set = bg.sSet, hidden = bg.isTex },
  { type = "range", name = "Badge scale", min = 0.2, max = 1, step = 0.02, section = "badges",
    get = bg.sGet, set = bg.sSet, hidden = bg.isText },
  { type = "range", name = "Letters", min = 2, max = 8, step = 1, section = "badges",
    get = bg.kGet, set = bg.kSet, hidden = bg.notFit,
    desc = "How many letters of the set name to show." },
  { type = "header", name = "Locked items", key = "locked",
    state = function()
      local n = 0
      for _ in pairs(WarpeeDB.vendorBlack or {}) do n = n + 1 end
      return (n == 1) and L["1 item"] or (L["%d items"]):format(n)
    end },
  { type = "description", section = "locked",
    name = "Alt-click an item to lock it: a padlock appears, and the item can no longer be sold, neither automatically nor by right-clicking at a merchant. Works in the bags, the bank, the favorites row and the pocket. Alt-click again, or the cross here, to unlock." },
  { type = "blacklist", section = "locked" },
}

SECTION_CLOSED.bankgrid = true

local GRID_PAGE = {
  { type = "header", name = "Bags grid" },
  { type = "range", name = "Slot size", min = 24, max = 56, step = 1, get = sizeGet, set = sizeSet,
    half = "left", desc = "Size of one slot in the bags." },
  { type = "range", name = "Slots per row", min = 6, max = 24, step = 1, get = colsGet, set = colsSet,
    half = "right", desc = "How wide the bag window grows." },
  { type = "range", name = "Spacing", min = 0, max = 16, step = 1, get = gapGet, set = gapSet,
    half = "left", desc = "Gap between slots, in every grid." },
  { type = "range", name = "Icon zoom", min = 0.8, max = 1.2, step = 0.01,
    get = zoomGet, set = zoomSet, half = "right",
    desc = "1.00 fills the slot. Less shrinks the icon, more crops it." },
  { type = "toggle", name = "Hide reagents", col = 1, of = 2,
    get = flow.hideGet, set = flow.hideSet,
    desc = "Leave the reagent bag out of the window. Its slots still count in the header, and reagents still go into it." },
  { type = "toggle", name = "Merge reagents", col = 2, of = 2, get = mergeGet, set = mergeSet,
    disabled = flow.hideGet,
    desc = "Lay the reagent bag out with the main bags, without its caption." },
  { type = "toggle", name = "Reagents on top", col = 1, of = 2,
    get = flow.topGet, set = flow.topSet, disabled = flow.offGet,
    desc = "Draw the reagent bag above the main bags instead of below them." },
  { type = "toggle", name = "Recent items", col = 2, of = 2, get = fav.recentGet, set = fav.recentSet,
    desc = "A row above the favorites holding what came into your bags this session, apart from gray items. Each arrival takes the first free cell, the oldest one leaves when the row is full, and the row clears on logout or a reload." },
  { type = "toggle", name = "Fill grid upwards", col = 1, of = 2,
    get = flow.upGet, set = flow.upSet,
    desc = "The rows of cells stack from the bottom edge up, so the part-filled last row sits at the top." },
  { type = "toggle", name = "Reverse slot order", col = 2, of = 2,
    get = flow.revGet, set = flow.revSet,
    desc = "The bag slots run backwards, so the last slot of the last bag takes the first cell. Nothing moves inside your bags, only the order the slots are drawn in." },
  { type = "header", name = "Favorites" },
  { type = "toggle", name = "Favorite slots", col = 1, get = fav.showGet, set = fav.showSet,
    desc = "A row of slots above the grid, always in sight. Drag an item onto one to keep it a click away, Ctrl + left click clears a slot." },
  { type = "range", name = "How many slots", min = 0, max = 14, step = 1,
    get = fav.countGet, set = fav.countSet,
    format = function(v) return (v or 0) <= 0 and T("As the grid") or tostring(v) end,
    disabled = function() return not fav.showGet() end,
    desc = "Never more than the grid is wide. Zero keeps the row as wide as the grid." },
  { type = "header", name = "Slot look" },
  { type = "select", name = "Slot background",
    get = styleGet, set = styleSet,
    keys = function() return STYLES end, label = function(k) return STYLE_LABELS[k] or k end,
    desc = "What sits behind every icon. Transparent shows the plate through the slot, Highlight lifts it out, Solid closes it off." },
  { type = "range", name = "Plate opacity", min = 0, max = 1, step = 0.01,
    get = gridAlphaGet, set = gridAlphaSet,
    desc = "The plate behind the slots. Transparent slots show it through every cell, and the gaps show it at any Spacing above 0." },
  { type = "header", name = "Bank and Warband grid", key = "bankgrid",
    state = function() return (L["%d and %d wide"]):format(bankColsGet(), wbColsGet()) end },
  { type = "description", section = "bankgrid",
    name = "The bank keeps its own width and icon size, apart from the bags." },
  { type = "range", name = "Bank slot size", min = 24, max = 56, step = 1, section = "bankgrid",
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

local snap = {}
snap.bagsGet = function() return WarpeeDB.keepBags ~= false end
snap.bagsSet = function(v) WarpeeDB.keepBags = v and true or false; relayout() end
snap.bankGet = function() return WarpeeDB.keepBank ~= false end
snap.bankSet = function(v) WarpeeDB.keepBank = v and true or false; relayout() end
snap.wbGet = function() return WarpeeDB.keepWarband ~= false end
snap.wbSet = function(v) WarpeeDB.keepWarband = v and true or false; relayout() end

local CHARS_PAGE = {
  { type = "header", name = "Item tooltips",
    state = function() return onOf({ tipOnGet, tipBankGet, tipWbGet }) end },
  { type = "toggle", name = "Count across characters", col = 1, get = tipOnGet, set = tipOnSet,
    desc = "Adds an Inventory block to item tooltips: how many each character carries." },
  { type = "toggle", name = "Include bank", col = 2, get = tipBankGet, set = tipBankSet,
    disabled = tipOff,
    desc = "Count each character's bank too. Off = bags only." },
  { type = "toggle", name = "Include Warband", col = 1, get = tipWbGet, set = tipWbSet,
    disabled = tipOff,
    desc = "Count the shared Warband bank on its own line." },
  { type = "header", name = "Snapshots",
    state = function() return onOf({ snap.bagsGet, snap.bankGet, snap.wbGet }) end },
  { type = "description",
    name = "Copies of what you carry, so another character's bags and bank open from your own window." },
  { type = "toggle", name = "Remember bags", col = 1, get = snap.bagsGet, set = snap.bagsSet,
    desc = "Save this character's bags and gold whenever the bag window opens. Off = the saved copy stops updating, and stays visible until you delete the character below." },
  { type = "toggle", name = "Remember bank", col = 2, get = snap.bankGet, set = snap.bankSet,
    desc = "Save the character bank while you stand at a banker." },
  { type = "toggle", name = "Remember Warband bank", col = 1, get = snap.wbGet, set = snap.wbSet,
    desc = "Save the shared Warband bank while you stand at a banker." },
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
local V = {}
function V.boeGet() return WarpeeDB.vendorKeepBoE ~= false end
function V.boeSet(v) WarpeeDB.vendorKeepBoE = v and true or false end
function V.wbGet() return WarpeeDB.vendorKeepWarbound ~= false end
function V.wbSet(v) WarpeeDB.vendorKeepWarbound = v and true or false end
function V.gemGet() return WarpeeDB.vendorKeepGems ~= false end
function V.gemSet(v) WarpeeDB.vendorKeepGems = v and true or false end
function V.greyGet() return WarpeeDB.vendorGrey ~= false end
function V.greySet(v) WarpeeDB.vendorGrey = v and true or false end
function V.repGet() return WarpeeDB.vendorRepair and true or false end
function V.repSet(v) WarpeeDB.vendorRepair = v and true or false end
V.REPAIR_BY = { "player", "guild", "both" }
V.REPAIR_LABELS = { player = "Your gold", guild = "Guild bank",
                    both = "Guild / yours" }
function V.repByGet() return WarpeeDB.vendorRepairBy or "player" end
function V.repBySet(v) WarpeeDB.vendorRepairBy = v or "player" end
function V.relicGet() return WarpeeDB.vendorRelics ~= false end
function V.relicSet(v) WarpeeDB.vendorRelics = v and true or false end

function V.minGet() return tonumber(WarpeeDB.vendorIlvlMin) or 0 end
function V.minSet(v) WarpeeDB.vendorIlvlMin = tonumber(v) or 0 end
function V.consumGet() return WarpeeDB.vendorConsum and true or false end
function V.consumSet(v) WarpeeDB.vendorConsum = v and true or false end
function V.autoGet() return WarpeeDB.vendorAuto and true or false end
function V.autoSet(v) WarpeeDB.vendorAuto = v and true or false end
function V.tokenGet() return WarpeeDB.vendorTokens and true or false end
function V.tokenSet(v) WarpeeDB.vendorTokens = v and true or false end
function V.tokensOff() return not (WarpeeDB.vendorTokens and true or false) end
function V.expGet(i)
  local t = WarpeeDB.vendorTokenExp
  return (t and t[i]) and true or false
end
function V.expSet(i, v)
  WarpeeDB.vendorTokenExp = WarpeeDB.vendorTokenExp or {}
  WarpeeDB.vendorTokenExp[i] = v and true or false
end
function V.expName(i)
  local n = _G["EXPANSION_NAME" .. i]
  if type(n) == "string" and n ~= "" then return n end
  return "Expansion " .. i
end

SECTION_CLOSED.tokenexp = true

local VENDOR_PAGE = {
  { type = "header", name = "Runs on its own" },
  { type = "description",
    name = "These start when a merchant window opens, with no click from you." },
  { type = "toggle", name = "Sell junk", col = 1, of = 3, get = V.greyGet, set = V.greySet,
    desc = "Sell every gray item, whatever its item level." },
  { type = "toggle", name = "Repair", col = 2, of = 3, get = V.repGet, set = V.repSet,
    desc = "Repair at merchants who offer it. Others are left alone, with no message." },
  { type = "select", name = "", col = 3, of = 3, get = V.repByGet, set = V.repBySet,
    keys = function() return V.REPAIR_BY end,
    label = function(k) return V.REPAIR_LABELS[k] or k end,
    disabled = function() return not V.repGet() end,
    desc = "Where the repair money comes from. The guild bank is used only if your withdraw limit covers the whole bill." },
  { type = "header", name = "The coin button" },
  { type = "description",
    name = "Everything below is sold by the coin in the bags header, unless you switch on automatic selling." },
  { type = "input", name = "Item level from", col = 1, min = 0, max = 9999,
    get = V.minGet, set = V.minSet,
    desc = "Gear at or above this item level is sold." },
  { type = "input", name = "Item level under", col = 2, min = 0, max = 9999,
    get = vIlvlGet, set = vIlvlSet,
    desc = "Gear under this item level is sold. Zero keeps every piece." },
  { type = "toggle", name = "Legion relics", col = 1, get = V.relicGet, set = V.relicSet,
    desc = "Sell Legion artifact relics. Item level ignored." },
  { type = "toggle", name = "Old consumables", col = 2, get = V.consumGet, set = V.consumSet,
    desc = "Sell potions, flasks, food and bandages older than the previous expansion." },
  { type = "toggle", name = "Tier tokens", col = 1, get = V.tokenGet, set = V.tokenSet,
    desc = "Sell raid armor tokens, item level ignored. Only from the expansions ticked below." },
  { type = "toggle", name = "Sell all of this automatically",
    get = V.autoGet, set = V.autoSet,
    desc = "Sell the list above at every merchant, without pressing the coin." },
  { type = "header", name = "Token expansions", key = "tokenexp",
    state = function()
      local t = WarpeeDB.vendorTokenExp or {}
      local none = ns.TOKEN_EXP_NONE or {}
      local cur = LE_EXPANSION_LEVEL_CURRENT
                  or (GetExpansionLevel and GetExpansionLevel()) or 0
      local n, all = 0, 0
      for i = 0, cur do
        if not none[i] then
          all = all + 1
          if t[i] then n = n + 1 end
        end
      end
      return (L["%d of %d"]):format(n, all)
    end },
  { type = "description", section = "tokenexp",
    name = "Which expansions tokens may be sold from. The four newest are kept by default. Expansions that never had tokens are not listed." },
  { type = "header", name = "Never sell",
    state = function() return onOf({ V.boeGet, V.wbGet, V.gemGet }) end },
  { type = "toggle", name = "Keep BoE", col = 1, get = V.boeGet, set = V.boeSet,
    desc = "Skip gear that is not bound yet, so it can go to the auction house." },
  { type = "toggle", name = "Keep warbound", col = 2, get = V.wbGet, set = V.wbSet,
    desc = "Skip warbound gear, since an alt can still use it." },
  { type = "toggle", name = "Keep socketed or enchanted", col = 1, get = V.gemGet, set = V.gemSet,
    desc = "Skip any piece with a gem socketed or an enchant applied." },
}

do
  local cur = LE_EXPANSION_LEVEL_CURRENT
              or (GetExpansionLevel and GetExpansionLevel()) or 0
  local at
  for i, row in ipairs(VENDOR_PAGE) do
    if row.type == "header" and row.name == "Never sell" then at = i; break end
  end
  local rows = {}
  local none = ns.TOKEN_EXP_NONE or {}
  local slot = 0
  for i = 0, cur do
    if not none[i] then
      rows[#rows + 1] = {
        type = "toggle", name = V.expName(i), col = (slot % 2 == 0) and 1 or 2,
        section = "tokenexp",
        get = function() return V.expGet(i) end,
        set = function(v) V.expSet(i, v) end,
        disabled = V.tokensOff,
        desc = "Sell tier tokens from this expansion.",
      }
      slot = slot + 1
    end
  end
  if at then
    for k = #rows, 1, -1 do table.insert(VENDOR_PAGE, at, rows[k]) end
  end
end

local PAGES = {
  { name = "General", list = GENERAL_PAGE },
  { name = "Grid", list = GRID_PAGE },
  { name = "Items", list = ITEMS_PAGE },
  { name = "Pocket", list = POCKET_PAGE },
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
  local path = ns.Fonts:Current()
  for _, e in ipairs(fonts) do
    e.fs:SetFont(path, math.max(7, BASE_FONT + e.delta), "")
  end
  local function measure()
    for _, tab in ipairs(self.tabs) do
      tab:SetWidth(math.max(70, tab.Text:GetStringWidth() + 22))
    end
    for i, area in ipairs(self.areas) do
      area.page.Relayout()
      area:PaintBar()
    end
  end
  measure()
  C_Timer.After(0, measure)
end

function Options:ReflowPages()
  if not self.areas then return end
  if self.tabs then
    local prev
    for i, tab in ipairs(self.tabs) do
      tab.Text:SetText(T(PAGES[i].name))
      tab:SetWidth(math.max(70, tab.Text:GetStringWidth() + 22))
      tab:ClearAllPoints()
      if prev then
        tab:SetPoint("TOPLEFT", prev, "TOPRIGHT", 5, 0)
      else
        ns.SnapPoint(tab, "TOPLEFT", self.frame, "TOPLEFT", PAD,
          -(HEADER_H + 7 + Theme:TopInset()))
      end
      prev = tab
      paintTab(tab)
    end
  end
  self:AnchorHeader()
  for _, row in ipairs(rows) do row.Refresh() end
  for _, area in ipairs(self.areas) do
    area.page.Relayout()
    area:ScrollTo(area:GetVerticalScroll())
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
  ns.SnapBox(f, WIN_W, math.min(WIN_H, UIParent:GetHeight() - 60), true)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(s) ns.DragStart(s) end)
  f:SetScript("OnDragStop", function(s)
    s:StopMovingOrSizing()
    local p, rp, x, y = ns.SnapFrame(s)
    if p then WarpeeDB.optPos = { p = p, rp = rp, x = x, y = y } end
  end)
  f:SetScript("OnMouseDown", function(s) Theme:Raise(s) end)
  Theme:Window(f, "WarpeeOptionsFrame")
  Theme:HeaderBand(f, HEADER_H + Theme:TopInset())
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
  self.closeBtn = close

  local line = Theme:Rect(f, "strokeSoft", "ARTWORK")
  ns.PixelLine(line, 1)
  line:SetPoint("TOPLEFT", PAD, -HEADER_H)
  line:SetPoint("TOPRIGHT", -PAD, -HEADER_H)
  self.headLine = line

  self.tabs, self.areas = {}, {}
  local prev
  for i, pageDef in ipairs(PAGES) do
    local tab = ns.CreateButton(f, T(pageDef.name), 90, TAB_H)
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
  self:AnchorHeader()
  self:Select(1)
  return f
end

function Options:AnchorHeader()
  local f = self.frame
  if not f then return end
  local top = Theme:TopInset()
  if self.title then
    self.title:ClearAllPoints()
    self.title:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(10 + top))
  end
  if self.closeBtn then
    self.closeBtn:ClearAllPoints()
    ns.SnapPoint(self.closeBtn, "TOPRIGHT", f, "TOPRIGHT", -PAD, -(8 + top))
  end
  if self.headLine then
    self.headLine:ClearAllPoints()
    self.headLine:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(HEADER_H + top))
    self.headLine:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -(HEADER_H + top))
  end
  local first = self.tabs and self.tabs[1]
  if first then
    first:ClearAllPoints()
    ns.SnapPoint(first, "TOPLEFT", f, "TOPLEFT", PAD, -(HEADER_H + 7 + top))
  end
  for _, area in ipairs(self.areas or {}) do
    area:ClearAllPoints()
    area:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(HEADER_H + TAB_H + 14 + top))
    area:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(PAD + SCROLL_W + 6), PAD)
  end
  local band = Theme:HeaderBand(f, HEADER_H + top)
  if self.headLine then self.headLine:SetShown(not band) end
end

function Options:Open()
  local f = self:Build()
  local pos = WarpeeDB and WarpeeDB.optPos
  f:ClearAllPoints()
  if pos then
    ns.SnapPoint(f, pos.p, UIParent, pos.rp, pos.x, pos.y)
  else
    ns.SnapPoint(f, "CENTER", UIParent, "CENTER", 260, 0)
  end
  self:Refresh()
  self:ApplyFont()
  f:Show()
  ns.AlignToScreen(f)
  Theme:Raise(f)
end

function Options:Close()
  closeDropdown()
  if self.frame then self.frame:Hide() end
end

function Options:Toggle()
  if self.frame and self.frame:IsShown() then self:Close() else self:Open() end
end
