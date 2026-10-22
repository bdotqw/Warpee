local addonName, ns = ...
local Options = ns.Options
local factories = Options.factories
local Theme = ns.Theme

-- The key binding row: the visible button, the capture listener that hears a key anywhere on screen, the
-- fullscreen catcher for mouse buttons and the wheel, and the rules for unbinding. It travels as one unit
-- because the capture only works from a top-level frame, never from a button inside this window.
-- The shared values come from Options.lua through ns.OptionControlsEnv, the same table the page chrome
-- reads; the row is asked for while a page is built, after every file has loaded.
local env = ns.OptionControlsEnv
local T = env.T
local BASE_FONT = env.baseFont
local track = env.track
local tip = env.tip
local offDuty = env.offDuty

local KEY_MODS = {
  LCTRL = true, RCTRL = true, LSHIFT = true, RSHIFT = true, LALT = true, RALT = true,
}

-- Click the button, press a key, a mouse button, or the wheel, done: the binding is
-- written the way the game stores them, so the client's own key list stays in sync.
-- Escape cancels, a right click outside the capture unbinds. SetBinding is protected
-- in combat, so capture never starts there, and a press that lands mid combat is
-- dropped instead of applied.
-- The capture itself follows the game's own KeybindListener shape: one top level
-- button, no parent, that receives OnKeyDown only while its script is set. A nested
-- button inside the options window never sees a keypress arrive, no matter how it is
-- enabled, which is why the capture does not live on the visible button. The mouse
-- buttons and the wheel arrive through a fullscreen catcher instead: keys have no
-- position, clicks do, and the catcher owns them all while the capture runs, with
-- left and right reserved for cancel.
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

local mouseCatcher
local function catcherClick(_, button)
  if not keyListen then return end
  button = (button or ""):upper()
  if button == "LEFTBUTTON" or button == "RIGHTBUTTON" then keyListen("CANCEL") return end
  keyListen(button)
end

local function catcherWheel(_, delta)
  if not keyListen then return end
  keyListen((delta or 0) > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
end

local function startListen(fn)
  keyListen = fn
  keyListener:SetScript("OnKeyDown", listenerKeyDown)
  keyListener:Show()
  if not mouseCatcher then
    mouseCatcher = CreateFrame("Button", nil, UIParent)
    mouseCatcher:SetAllPoints(UIParent)
    mouseCatcher:SetFrameStrata("FULLSCREEN_DIALOG")
    mouseCatcher:RegisterForClicks("AnyUp")
    mouseCatcher:EnableMouseWheel(true)
    mouseCatcher:Hide()
  end
  mouseCatcher:SetScript("OnClick", catcherClick)
  mouseCatcher:SetScript("OnMouseWheel", catcherWheel)
  mouseCatcher:Show()
end

local function stopListen()
  if not keyListen then return end
  keyListen = nil
  keyListener:SetScript("OnKeyDown", nil)
  keyListener:Hide()
  if mouseCatcher then
    mouseCatcher:SetScript("OnClick", nil)
    mouseCatcher:SetScript("OnMouseWheel", nil)
    mouseCatcher:Hide()
  end
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
  ns.SetBg(btn, Theme:C("panel"))
  ns.SetEdge(btn, Theme:C("stroke"))
  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  local cur = track(Theme:Label(btn, BASE_FONT - 1, "text"), -1)
  cur:SetPoint("CENTER")
  local capturing = false

  local function keyText()
    -- GetBindingKey returns BOTH slots; take the first non-empty so a key set only in the second
    -- slot still reads as bound instead of "Not bound".
    local k1, k2 = GetBindingKey and GetBindingKey(spec.binding)
    local k = (k1 and k1 ~= "" and k1) or (k2 and k2 ~= "" and k2) or nil
    if k then return k end
    return T("Not bound")
  end

  local function paint()
    local on = not (spec.disabled and spec.disabled())
    row.off = not on
    offDuty(row, not on)
    if capturing then
      cur:SetText(T("Press a key..."))
      cur:SetTextColor(Theme:C("accent"))
      ns.SetEdge(btn, Theme:C("accent"))
    else
      cur:SetText(keyText())
      cur:SetTextColor(Theme:C(on and "text" or "faint"))
      ns.SetEdge(btn, Theme:C("stroke"))
    end
    nameFS:SetTextColor(Theme:C(on and "text" or "faint"))
    ns.SetBg(btn, Theme:C("panel"))
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
    if key == "ESCAPE" or key == "CANCEL" then stop() return end
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
    if capturing or row.off then return end
    ns.SetBg(s, Theme:C("panelHi"))
    ns.SetEdge(s, Theme:C("accent"))
  end)
  btn:SetScript("OnLeave", function(s)
    if capturing then return end
    paint()
  end)

  btn:SetScript("OnClick", function(_, button)
    if spec.disabled and spec.disabled() then return end
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
  tip(row, spec.desc)
  tip(btn, "Right-click to unbind")
  paint()
  return row
end
