local addonName, ns = ...

local Theme = ns.Theme

local P = {}
ns.Profiles = P

local RESERVED = "Default"
local LIST = "profiles"
local SELECTED = "profile"
local PREFIX = "!WPE1!"
local SCHEMA = 1
local MAX_NAME = 40
local FALLBACK_NAME = "Imported"

local function trim(s)
  s = tostring(s or "")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  if #s > MAX_NAME then s = s:sub(1, MAX_NAME) end
  return s
end

function P:Names()
  local out = {}
  local t = WarpeeDB and WarpeeDB[LIST]
  if t then
    for k in pairs(t) do out[#out + 1] = k end
    table.sort(out)
  end
  return out
end

function P:List()
  local out = { RESERVED }
  local n = self:Names()
  for i = 1, #n do out[#out + 1] = n[i] end
  return out
end

function P:Active()
  local n = WarpeeDB and WarpeeDB[SELECTED]
  if n and WarpeeDB[LIST] and WarpeeDB[LIST][n] then return n end
  return RESERVED
end

local WINDOWS = {
  { key = "pos",       get = function() return ns.Bags and ns.Bags.frame end },
  { key = "bankPos",   get = function() return ns.Bank and ns.Bank.frame end },
  { key = "bagWinPos", get = function() return ns.Bags and ns.Bags.bagWindow end },
  { key = "pocketPos", get = function() return ns.Pocket and ns.Pocket.frame end },
}

-- A window the user has never dragged has no saved position, so a profile captured then
-- would carry no opinion about it and the window would keep whatever place the previous
-- profile left behind. Reading the live spot instead pins every window into every
-- profile, and GetLeft/GetBottom are UIParent based whichever way the frame is anchored.
local function livePos(frame)
  if not frame then return nil end
  local l, b = frame:GetLeft(), frame:GetBottom()
  if not (l and b) then return nil end
  return { p = "BOTTOMLEFT", rp = "BOTTOMLEFT",
           x = ns.SnapValue(frame, l), y = ns.SnapValue(frame, b) }
end

function P:Capture()
  local out = {}
  if not WarpeeDB then return out end
  for k in pairs(ns.DEFAULTS) do
    local v = WarpeeDB[k]
    if v ~= nil then out[k] = ns.CopyDeep(v) end
  end
  for i = 1, #WINDOWS do
    local w = WINDOWS[i]
    if out[w.key] == nil then out[w.key] = livePos(w.get()) end
  end
  return out
end

function P:Store(name)
  name = trim(name)
  if name == "" or name == RESERVED then return false end
  WarpeeDB[LIST] = WarpeeDB[LIST] or {}
  WarpeeDB[LIST][name] = self:Capture()
  return true
end

function P:StoreEmpty(name)
  name = trim(name)
  if name == "" or name == RESERVED then return false end
  WarpeeDB[LIST] = WarpeeDB[LIST] or {}
  WarpeeDB[LIST][name] = {}
  return true
end

function P:Delete(name)
  if not (WarpeeDB and WarpeeDB[LIST] and WarpeeDB[LIST][name]) then return false end
  if name == self:Active() then return false end
  WarpeeDB[LIST][name] = nil
  return true
end

function P:Rename(old, new)
  old, new = trim(old), trim(new)
  if old == "" or new == "" or old == new or new == RESERVED then return false end
  local t = WarpeeDB and WarpeeDB[LIST]
  if not (t and t[old]) then return false end
  if t[new] then return false end
  t[new] = t[old]
  t[old] = nil
  if WarpeeDB[SELECTED] == old then WarpeeDB[SELECTED] = new end
  return true
end

function P:Apply(name)
  if not WarpeeDB then return false end
  if name == RESERVED then
    ns.WipeConfig(WarpeeDB)
    WarpeeDB[SELECTED] = nil
    ns.FillComputed(WarpeeDB)
    ns.SanitizeConfig(WarpeeDB)
    return true
  end
  local t = WarpeeDB[LIST] and WarpeeDB[LIST][name]
  if not t then return false end
  ns.WipeConfig(WarpeeDB)
  for k, v in pairs(t) do
    if ns.DEFAULTS[k] ~= nil then WarpeeDB[k] = ns.CopyDeep(v) end
  end
  WarpeeDB[SELECTED] = name
  ns.FillComputed(WarpeeDB)
  ns.SanitizeConfig(WarpeeDB)
  return true
end

function P:ApplyLive(name)
  if not self:Apply(name) then return false end
  if ns.Ready then
    ns.Applying = true
    local ok, err = pcall(ns.ApplyAll)
    ns.Applying = false
    if not ok then error(err, 0) end
  end
  return true
end

function P:SyncActive()
  if ns.Applying or not WarpeeDB then return false end
  local active = self:Active()
  if active == RESERVED then return false end
  local t = WarpeeDB[LIST]
  if not (t and t[active]) then return false end
  t[active] = self:Capture()
  return true
end

function P:Reset()
  return self:ApplyLive(RESERVED)
end

local function codec()
  local C = C_EncodingUtil
  if not (C and C.SerializeCBOR and C.EncodeBase64) then return nil end
  local M = Enum and Enum.CompressionMethod
  if not (M and M.Deflate) then return nil end
  return C, M.Deflate, Enum.CompressionLevel and Enum.CompressionLevel.OptimizeForSize
end

local function packPayload(env)
  local C, method, level = codec()
  if not C then return "" end
  local ok, ser = pcall(C.SerializeCBOR, env)
  if not ok or not ser then return "" end
  local ok2, comp
  if level then
    ok2, comp = pcall(C.CompressString, ser, method, level)
  else
    ok2, comp = pcall(C.CompressString, ser, method)
  end
  if not ok2 or not comp then return "" end
  local ok3, enc = pcall(C.EncodeBase64, comp)
  if not ok3 or not enc then return "" end
  return enc
end

local function unpackPayload(enc)
  local C, method = codec()
  if not C then return nil, "Not supported on this client" end
  local ok, dec = pcall(C.DecodeBase64, enc)
  if not ok or not dec then return nil, "Damaged profile code" end
  local ok2, raw = pcall(C.DecompressString, dec, method)
  if not ok2 or not raw then return nil, "Damaged profile code" end
  local ok3, env = pcall(C.DeserializeCBOR, raw)
  if not ok3 or type(env) ~= "table" then return nil, "Damaged profile code" end
  return env
end

local function upgrade(data, schema)
  schema = tonumber(schema) or 1
  if schema > SCHEMA then return nil end
  return data
end

function P:Export(name)
  name = name or self:Active()
  local data
  if name == RESERVED then
    data = self:Capture()
  else
    data = WarpeeDB and WarpeeDB[LIST] and WarpeeDB[LIST][name]
  end
  if type(data) ~= "table" then return "" end
  return PREFIX .. packPayload({ _v = SCHEMA, _n = name, d = data })
end

function P:Import(str, name)
  if type(str) ~= "string" then return false, "Nothing to import" end
  str = str:gsub("^%s+", ""):gsub("%s+$", "")
  if str == "" then return false, "Nothing to import" end
  if str:sub(1, #PREFIX) ~= PREFIX then return false, "Not a profile code" end
  local env, err = unpackPayload(str:sub(#PREFIX + 1))
  if not env then return false, err end
  if not env.d or type(env.d) ~= "table" then return false, "Not a profile code" end
  local data = upgrade(env.d, env._v)
  if not data then return false, "Saved by a newer version" end
  name = trim(name)
  if name == "" then name = trim(env._n) end
  if name == "" or name == RESERVED then name = FALLBACK_NAME end
  local clean = {}
  for k, v in pairs(data) do
    if ns.DEFAULTS[k] ~= nil then clean[k] = v end
  end
  WarpeeDB[LIST] = WarpeeDB[LIST] or {}
  WarpeeDB[LIST][name] = clean
  self:ApplyLive(name)
  return true, name
end

local API = {}
ns.API = API

function API:ImportProfile(str, key)
  return ns.Profiles:Import(str, key)
end

function API:ExportProfile(key)
  return ns.Profiles:Export(key)
end

function API:ApplyProfile(key)
  if not ns.Profiles:ApplyLive(trim(key)) then return false, "Unknown profile" end
  return true
end

function API:ResetProfile()
  ns.Profiles:ApplyLive(RESERVED)
  return true
end

function API:GetProfiles()
  return ns.Profiles:List()
end

function API:GetActiveProfile()
  return ns.Profiles:Active()
end

_G.WarpeeAPI = API

local PAD = 12
local ROW_H = 22
local DD_H = 26
local STR_H = 24
local MIN_W = 340
local GAP = 6
local DD_TOP = 38
local FIELD_GAP = 12
local ROW_GAP = 6
local SHARE_GAP = 16
local CODE_GAP = 8
local FIELD_TOP = DD_TOP + DD_H + FIELD_GAP
local PANEL_H = FIELD_TOP + ROW_H + ROW_GAP + ROW_H + SHARE_GAP
              + ROW_H + CODE_GAP + STR_H + PAD
local PANEL_HEADER_EXTRA = 14

local function T(s)
  if type(s) ~= "string" or s == "" then return s end
  return ns.L[s]
end

local function say(msg)
  print("|cffd9a85fWarpee|r |cffffffff" .. msg .. "|r")
end

local function makeButton(parent, text, onClick)
  local b = ns.CreateButton(parent, "", 80, ROW_H)
  ns.LocalText(b.Text, text)
  b:SetScript("OnClick", onClick)
  return b
end

local function autoButton(parent, text, onClick)
  local b = makeButton(parent, text, onClick)
  b:SetWidth(math.max(58, b.Text:GetStringWidth() + 18))
  return b
end

-- CreateButton paints itself through Theme:Track, and that registry keeps one callback
-- per object, so registering another would replace the hover and disabled states.
-- Rebuilding the paint here keeps both and only swaps the ink the button rests in.
local function tintButton(b, inkKey, edgeKey)
  if not b then return end
  local function paint(s)
    local hot = s.wpeHot and not s.offDuty
    local fade = s.offDuty
    s:SetBackdropColor(Theme:C(hot and "panelHi" or "panel"))
    s:SetBackdropBorderColor(Theme:C(fade and "strokeSoft"
                                     or (hot and "accent" or (edgeKey or "stroke"))))
    if s.Text then
      s.Text:SetTextColor(Theme:C(fade and "faint" or (hot and "accent" or inkKey)))
    end
    if s.wpeIconPaint then s.wpeIconPaint(s) end
  end
  b.Repaint = paint
  Theme:Track(b, paint)
  if b.Text then
    Theme:Track(b.Text, function(s)
      local p = s:GetParent()
      local hot = p and p.wpeHot and not p.offDuty
      s:SetTextColor(Theme:C((p and p.offDuty) and "faint" or (hot and "accent" or inkKey)))
    end)
  end
  paint(b)
end

function P:Paint()
  local f = self.panel
  if not f then return end
  local active = self:Active()
  f.dd.Text:SetText(active == RESERVED and T("Default") or active)
  if ns.SetButtonEnabled then
    ns.SetButtonEnabled(f.delBtn, active ~= RESERVED)
  end
end

function P:Has(name)
  return (name == RESERVED) or (WarpeeDB and WarpeeDB[LIST] and WarpeeDB[LIST][name] ~= nil)
end

function P:Select(name)
  if not self:Has(name) then return end
  self.sel = name
  self:Paint()
end

function P:BuildPanel()
  if self.panel then return self.panel end
  local f = CreateFrame("Frame", "WarpeeProfilesFrame", UIParent, "BackdropTemplate")
  Theme:Panel(f, "bg", "stroke")
  Theme:Window(f)
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(s) ns.DragStart(s) end)
  f:SetScript("OnDragStop", function(s)
    if not s.wpeMoving then return end
    s.wpeMoving = nil
    s:StopMovingOrSizing()
  end)
  f:Hide()
  ns.EscClose(f)
  self.panel = f

  local title = Theme:Title(f, 15, "accent")
  ns.LocalText(title, "Profiles")
  title:SetPoint("TOPLEFT", PAD, -10)
  f.title = title

  local close = ns.CreateGlyphButton(f, "×", 22)
  close:SetPoint("TOPRIGHT", -7, -7)
  close:SetScript("OnClick", function() f:Hide() end)
  f.closeBtn = close

  local nameBox = ns.CreateSearchBox(f, nil, "Profile name")
  f.nameBox = nameBox

  local dup = autoButton(f, "Duplicate current", function()
    local n = trim(nameBox:GetText())
    if not P:Store(n) then say(T("Enter a profile name")) return end
    nameBox:SetText("")
    P:ApplyLive(n)
    say(T("Created %s"):format(n))
    P:Paint()
  end)

  local fresh = autoButton(f, "Create empty", function()
    local n = trim(nameBox:GetText())
    if not P:StoreEmpty(n) then say(T("Enter a profile name")) return end
    nameBox:SetText("")
    P:ApplyLive(n)
    say(T("Created %s"):format(n))
    P:Paint()
  end)

  local dd = ns.CreateButton(f, "", MIN_W - PAD * 2, DD_H)
  dd.Text:ClearAllPoints()
  dd.Text:SetPoint("LEFT", dd, "LEFT", 8, 0)
  dd.Text:SetPoint("RIGHT", dd, "RIGHT", -26, 0)
  dd.Text:SetJustifyH("LEFT")
  dd:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -DD_TOP)
  local arrow = ns.ArrowGlyph(dd, "down", 11)
  arrow:SetPoint("RIGHT", dd, "RIGHT", -8, 0)
  f.ddArrow = arrow
  tintButton(dd, "accent")
  dd:SetScript("OnClick", function(s)
    if not ns.OpenDropdown then return end
    ns.OpenDropdown(s, {
      get = function() return P:Active() end,
      set = function(name)
        -- Re-picking the entry that is already active would re-apply it, and for a profile
        -- with no stored copy of its own, Default among them, that wipes back to factory.
        if name ~= P:Active() then P:ApplyLive(name) end
      end,
      keys = function() return P:List() end,
      label = function(k) return k == RESERVED and T("Default") or k end,
    }, function()
      P:Paint()
      if ns.Options and ns.Options.Refresh then ns.Options:Refresh() end
    end)
  end)
  f.dd = dd

  local delX = ns.CreateGlyphButton(f, "×", DD_H)
  delX:SetPoint("LEFT", dd, "RIGHT", GAP, 0)
  delX:SetScript("OnClick", function()
    local active = P:Active()
    if active == RESERVED then return end
    StaticPopupDialogs["WARPEE_DEL_PROFILE"].text = T("Delete profile %s?")
    StaticPopup_Show("WARPEE_DEL_PROFILE", active, nil, active)
  end)
  tintButton(delX, "gaugeHi", "gaugeHi")
  ns.AddTip(delX, function()
    if P:Active() ~= RESERVED then return nil end
    return T("Cannot delete the default profile")
  end, "top")
  f.delBtn = delX

  local ren = autoButton(f, "Rename", function()
    local n = trim(nameBox:GetText())
    if n == "" then say(T("Enter a profile name")) return end
    if not P:Rename(P:Active(), n) then say(T("That name is taken")) return end
    nameBox:SetText("")
    P:Paint()
  end)

  nameBox:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -FIELD_GAP)
  nameBox:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -FIELD_TOP)
  ren:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -ROW_GAP)
  dup:SetPoint("LEFT", ren, "RIGHT", GAP, 0)
  fresh:SetPoint("LEFT", dup, "RIGHT", GAP, 0)

  local exp = autoButton(f, "Export", function()
    local active = P:Active()
    local text = P:Export(active)
    if text == "" then say(T("Nothing to export")) return end
    f.str:SetText(text)
    f.str:SetFocus()
    f.str:HighlightText()
    say(T("Exported %s, press Ctrl and C to copy"):format(active))
  end)
  exp:SetPoint("TOPLEFT", ren, "BOTTOMLEFT", 0, -SHARE_GAP)

  local imp = autoButton(f, "Import", function()
    local ok, res = P:Import(f.str:GetText(), nameBox:GetText())
    if not ok then say(T(res)) return end
    say(T("Imported %s"):format(res))
    P:Paint()
  end)
  imp:SetPoint("LEFT", exp, "RIGHT", GAP, 0)
  tintButton(exp, "dim")
  tintButton(imp, "dim")

  local str = CreateFrame("EditBox", nil, f, "BackdropTemplate")
  str:SetAutoFocus(false)
  str:SetFont(ns.Fonts:Current(), 11, "")
  str:SetTextColor(Theme:C("text"))
  str:SetHeight(STR_H)
  ns.PixelBackdrop(str)
  str:SetBackdropColor(Theme:C(Theme:IsLight() and "slot" or "bg"))
  str:SetBackdropBorderColor(Theme:C("stroke"))
  str:SetTextInsets(6, 6, 4, 4)
  str:SetPoint("TOPLEFT", exp, "BOTTOMLEFT", 0, -CODE_GAP)
  str:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, PAD)
  str:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
  Theme:Track(str, function(s)
    s:SetBackdropColor(Theme:C(Theme:IsLight() and "slot" or "bg"))
    s:SetTextColor(Theme:C("text"))
  end)
  f.str = str

  local hint = Theme:Label(str, 11, "dim")
  ns.LocalText(hint, "Profile code")
  hint:SetPoint("LEFT", str, "LEFT", 7, 0)
  local function refreshHint(s) hint:SetShown(s:GetText() == "") end
  str:SetScript("OnTextChanged", refreshHint)
  str:SetScript("OnEditFocusLost", function(s) refreshHint(s) end)
  refreshHint(str)
  f.strHint = hint

  f.row1 = { ren, dup, fresh }
  f.row2 = { exp, imp }
  f:SetHeight(PANEL_H)
  self:Reflow()
  self:ApplySkin()

  return f
end

function P:Reflow()
  local f = self.panel
  if not f then return end
  local rows = { f.row1, f.row2 }
  local need, widest = 0, 1
  for _, row in ipairs(rows) do
    widest = math.max(widest, #row)
    for i = 1, #row do
      need = math.max(need, row[i].Text:GetStringWidth() + 18)
    end
  end
  local W = math.max(need * widest + (widest - 1) * GAP, MIN_W) + PAD * 2
  f:SetWidth(W)
  local content = W - PAD * 2
  for _, row in ipairs(rows) do
    local w = math.floor((content - (#row - 1) * GAP) / #row)
    for i = 1, #row do row[i]:SetWidth(w) end
  end
  f.dd:SetWidth(content - DD_H - GAP)
  f.str:SetWidth(content)
  self:Paint()
end

function P:Place()
  local f = self.panel
  if not f then return end
  local opts = ns.Options and ns.Options.frame
  f:ClearAllPoints()
  if opts and opts:IsShown() then
    f:SetPoint("TOPLEFT", opts, "TOPRIGHT", 8, 0)
  else
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
end

-- The blizzard art draws its band lower than the plain themes do, so the header block
-- inside the panel moves down by the skin's title drop plus the panel's own extra. The
-- window itself never rises: it opens level with the settings it hangs off, and only the
-- body below grows, so the title and the close button sit inside that deeper band.
function P:ApplySkin()
  local f = self.panel
  if not f then return end
  local drop = Theme:TitleDrop()
  local shift = drop > 0 and (drop + PANEL_HEADER_EXTRA) or 0
  if f.title then
    f.title:ClearAllPoints()
    ns.SnapPoint(f.title, "TOPLEFT", f, "TOPLEFT", PAD, -(10 + shift))
  end
  if f.closeBtn then
    f.closeBtn:ClearAllPoints()
    ns.SnapPoint(f.closeBtn, "TOPRIGHT", f, "TOPRIGHT", -7, -(7 + shift))
  end
  if f.ddArrow then f.ddArrow:SetTint("accent") end
  if f.dd then
    f.dd:ClearAllPoints()
    ns.SnapPoint(f.dd, "TOPLEFT", f, "TOPLEFT", PAD, -(DD_TOP + shift))
  end
  if f.nameBox then
    f.nameBox:ClearAllPoints()
    if f.dd then
      ns.SnapPoint(f.nameBox, "TOPLEFT", f.dd, "BOTTOMLEFT", 0, -FIELD_GAP)
    end
    ns.SnapPoint(f.nameBox, "TOPRIGHT", f, "TOPRIGHT", -PAD, -(FIELD_TOP + shift))
  end
  f:SetHeight(PANEL_H + shift)
  if f:IsShown() then self:Place() end
end

function P:Toggle()
  local f = self:BuildPanel()
  if f:IsShown() then
    f:Hide()
    return
  end
  self:Paint()
  self:Place()
  f:Show()
  ns.Theme:Raise(f)
end

StaticPopupDialogs["WARPEE_DEL_PROFILE"] = {
  text = "Delete profile %s?",
  button1 = _G.DELETE or "Delete",
  button2 = _G.CANCEL or "Cancel",
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  showAlert = true,
  OnAccept = function(_, name)
    if name == ns.Profiles:Active() then ns.Profiles:ApplyLive(RESERVED) end
    if not ns.Profiles:Delete(name) then return end
    ns.Profiles:Paint()
  end,
}
