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
  { key = "optPos",    get = function() return ns.Options and ns.Options.frame end },
}

-- A window the user has never dragged has no saved position, so a snapshot taken then
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

function P:Snapshot()
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
  WarpeeDB[LIST][name] = self:Snapshot()
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
  t[active] = self:Snapshot()
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
    data = self:Snapshot()
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
local NAME_TOP = 38
local DD_TOP = 100
local STR_H = 24
local MIN_W = 340
local GAP = 6
local ZONE_GAP = 16
local PANEL_H = 234

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

local function rowWidth(list)
  local w = 0
  for i = 1, #list do w = w + list[i]:GetWidth() end
  return w + (#list - 1) * GAP
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

  local close = ns.CreateGlyphButton(f, "×", 22)
  close:SetPoint("TOPRIGHT", -7, -7)
  close:SetScript("OnClick", function() f:Hide() end)

  local nameBox = ns.CreateSearchBox(f, nil, "Profile name")
  nameBox:SetPoint("TOPLEFT", PAD, -NAME_TOP)
  nameBox:SetPoint("TOPRIGHT", -PAD, -NAME_TOP)
  f.nameBox = nameBox

  local dup = autoButton(f, "Duplicate current", function()
    local n = trim(nameBox:GetText())
    if not P:Store(n) then say(T("Enter a profile name")) return end
    P:ApplyLive(n)
    say(T("Created %s"):format(n))
    P:Paint()
  end)
  dup:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -6)

  local fresh = autoButton(f, "Create empty", function()
    local n = trim(nameBox:GetText())
    if not P:StoreEmpty(n) then say(T("Enter a profile name")) return end
    P:ApplyLive(n)
    say(T("Created %s"):format(n))
    P:Paint()
  end)
  fresh:SetPoint("LEFT", dup, "RIGHT", GAP, 0)

  local dd = ns.CreateButton(f, "", MIN_W - PAD * 2, ROW_H)
  dd.Text:ClearAllPoints()
  dd.Text:SetPoint("LEFT", dd, "LEFT", 8, 0)
  dd.Text:SetPoint("RIGHT", dd, "RIGHT", -22, 0)
  dd.Text:SetJustifyH("LEFT")
  dd:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -DD_TOP)
  local arrow = ns.ArrowGlyph(dd, "down", 9)
  arrow:SetPoint("RIGHT", dd, "RIGHT", -8, 0)
  dd:SetScript("OnClick", function(s)
    if not ns.OpenDropdown then return end
    ns.OpenDropdown(s, {
      get = function() return P:Active() end,
      set = function(name) P:ApplyLive(name) end,
      keys = function() return P:List() end,
      label = function(k) return k == RESERVED and T("Default") or k end,
    }, function()
      P:Paint()
      if ns.Options and ns.Options.Refresh then ns.Options:Refresh() end
    end)
  end)
  f.dd = dd

  local ren = autoButton(f, "Rename", function()
    local n = trim(nameBox:GetText())
    if n == "" then say(T("Enter a profile name")) return end
    if not P:Rename(P:Active(), n) then say(T("That name is taken")) return end
    P:Paint()
  end)
  ren:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -8)

  local del = autoButton(f, "Delete", function()
    local active = P:Active()
    if active == RESERVED then return end
    StaticPopupDialogs["WARPEE_DEL_PROFILE"].text = T("Delete profile %s?")
    StaticPopup_Show("WARPEE_DEL_PROFILE", active, nil, active)
  end)
  del:SetPoint("LEFT", ren, "RIGHT", GAP, 0)
  f.delBtn = del

  local exp = autoButton(f, "Export", function()
    local active = P:Active()
    local text = P:Export(active)
    if text == "" then say(T("Nothing to export")) return end
    f.str:SetText(text)
    f.str:SetFocus()
    f.str:HighlightText()
    say(T("Exported %s, press Ctrl and C to copy"):format(active))
  end)
  exp:SetPoint("TOPLEFT", ren, "BOTTOMLEFT", 0, -ZONE_GAP)

  local imp = autoButton(f, "Import", function()
    local ok, res = P:Import(f.str:GetText(), nameBox:GetText())
    if not ok then say(T(res)) return end
    say(T("Imported %s"):format(res))
    P:Paint()
  end)
  imp:SetPoint("LEFT", exp, "RIGHT", GAP, 0)

  local str = CreateFrame("EditBox", nil, f, "BackdropTemplate")
  str:SetAutoFocus(false)
  str:SetFont(ns.Fonts:Current(), 11, "")
  str:SetTextColor(Theme:C("text"))
  str:SetHeight(STR_H)
  ns.PixelBackdrop(str)
  str:SetBackdropColor(Theme:C(Theme:IsLight() and "slot" or "bg"))
  str:SetBackdropBorderColor(Theme:C("stroke"))
  str:SetTextInsets(6, 6, 4, 4)
  str:SetPoint("TOPLEFT", exp, "BOTTOMLEFT", 0, -8)
  str:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, PAD)
  str:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
  Theme:Track(str, function(s)
    s:SetBackdropColor(Theme:C(Theme:IsLight() and "slot" or "bg"))
    s:SetTextColor(Theme:C("text"))
  end)
  f.str = str

  f.row1 = { dup, fresh }
  f.row2 = { ren, del }
  f.row3 = { exp, imp }
  f.autoBtns = { dup, fresh, ren, del, exp, imp }
  f:SetHeight(PANEL_H)
  self:Reflow()

  return f
end

function P:Reflow()
  local f = self.panel
  if not f then return end
  for i = 1, #f.autoBtns do
    local b = f.autoBtns[i]
    b:SetWidth(math.max(58, b.Text:GetStringWidth() + 18))
  end
  local W = math.max(rowWidth(f.row1), rowWidth(f.row2), rowWidth(f.row3), MIN_W) + PAD * 2
  f:SetWidth(W)
  f.dd:SetWidth(W - PAD * 2)
  f.str:SetWidth(W - PAD * 2)
  self:Paint()
end

function P:Toggle()
  local f = self:BuildPanel()
  if f:IsShown() then
    f:Hide()
    return
  end
  self:Paint()
  local opts = ns.Options and ns.Options.frame
  f:ClearAllPoints()
  if opts and opts:IsShown() then
    f:SetPoint("TOPLEFT", opts, "TOPRIGHT", 8, 0)
  else
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
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
