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

function P:Snapshot()
  local out = {}
  if not WarpeeDB then return out end
  for k in pairs(ns.DEFAULTS) do
    local v = WarpeeDB[k]
    if v ~= nil then out[k] = ns.CopyDeep(v) end
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
  if ns.Ready then ns.ApplyAll() end
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
local LIST_TOP = 96
local ROWS_MAX = 8
local STR_H = 24
local MIN_W = 320
local GAP = 6

local function T(s)
  if type(s) ~= "string" or s == "" then return s end
  return ns.L[s]
end

local function say(msg)
  print("|cffd9a85fWarpee|r |cffffffff" .. msg .. "|r")
end

local function makeButton(parent, text, h, onClick)
  local b = ns.CreateButton(parent, T(text), 80, h or ROW_H)
  b:SetScript("OnClick", onClick)
  return b
end

local function autoButton(parent, text, onClick)
  local b = makeButton(parent, text, ROW_H, onClick)
  b:SetWidth(math.max(58, b.Text:GetStringWidth() + 18))
  return b
end

local function rowWidth(list)
  local w = 0
  for i = 1, #list do w = w + list[i]:GetWidth() end
  return w + (#list - 1) * GAP
end

local function paintRow(b)
  if not b.Text then return end
  if b.sel then
    b:SetBackdropBorderColor(Theme:C("accent"))
    b.Text:SetTextColor(Theme:C("accent"))
  else
    b:SetBackdropBorderColor(Theme:C("stroke"))
    b.Text:SetTextColor(Theme:C("text"))
  end
end

local function panelHeight(shown)
  return LIST_TOP + shown * (ROW_H + 3) + 8 + ROW_H + 8 + STR_H + PAD
end

function P:Paint()
  local f = self.panel
  if not f then return end
  local names = self:List()
  local active = self:Active()
  local shown = 1
  for i = 1, ROWS_MAX do
    local b = f.rows[i]
    local name = names[i]
    if name then
      b.wpeName = name
      b.Text:SetText(name == RESERVED and T("Default") or name)
      b.sel = (name == active)
      b:Show()
      paintRow(b)
      shown = i
    else
      b.wpeName = nil
      b:Hide()
    end
  end
  f.actions:ClearAllPoints()
  f.actions:SetPoint("TOPLEFT", f.rows[shown], "BOTTOMLEFT", 0, -8)
  f:SetHeight(panelHeight(shown))
end

function P:SwitchTo(name)
  if name == self:Active() then return end
  if not self:ApplyLive(name) then say(T("Unknown profile")) return end
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
  nameBox:SetPoint("TOPLEFT", PAD, -38)
  nameBox:SetPoint("TOPRIGHT", -PAD, -38)
  f.nameBox = nameBox

  local addCopy = autoButton(f, "Duplicate current", function()
    local n = nameBox:GetText()
    if not P:Store(n) then say(T("Enter a profile name")) return end
    P:ApplyLive(trim(n))
  end)
  addCopy:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -6)

  local addEmpty = autoButton(f, "Create empty", function()
    local n = nameBox:GetText()
    if not P:StoreEmpty(n) then say(T("Enter a profile name")) return end
    P:ApplyLive(trim(n))
  end)
  addEmpty:SetPoint("LEFT", addCopy, "RIGHT", GAP, 0)

  local del = autoButton(f, "Delete", function()
    local n = P:Active()
    if n == RESERVED then say(T("Cannot delete the default profile")) return end
    P:ApplyLive(RESERVED)
    if not P:Delete(n) then say(T("Cannot delete the active profile")) return end
    P:Paint()
  end)
  del:SetPoint("LEFT", addEmpty, "RIGHT", GAP, 0)

  local ren = autoButton(f, "Rename", function()
    local n = trim(nameBox:GetText())
    if n == "" then say(T("Enter a profile name")) return end
    if not P:Rename(P:Active(), n) then say(T("That name is taken")) return end
    P:Paint()
  end)
  ren:SetPoint("LEFT", del, "RIGHT", GAP, 0)

  f.rows = {}
  for i = 1, ROWS_MAX do
    local b = ns.CreateButton(f, "", MIN_W - PAD * 2, ROW_H)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(LIST_TOP + (i - 1) * (ROW_H + 3)))
    b:Hide()
    b:SetScript("OnClick", function(s)
      if s.wpeName then P:SwitchTo(s.wpeName) end
    end)
    Theme:Track(b, function(s) paintRow(s) end)
    f.rows[i] = b
  end

  local exp = autoButton(f, "Export", function()
    local text = P:Export(P:Active())
    if text == "" then say(T("Nothing to export")) return end
    f.str:SetText(text)
    f.str:SetFocus()
    f.str:HighlightText()
    say(T("Press Ctrl and C to copy"))
  end)
  exp:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -LIST_TOP)
  f.actions = exp

  local imp = autoButton(f, "Import", function()
    local ok, res = P:Import(f.str:GetText(), nameBox:GetText())
    if not ok then say(T(res)) return end
    say(res)
    P:Paint()
  end)
  imp:SetPoint("LEFT", exp, "RIGHT", GAP, 0)

  local reset = autoButton(f, "Reset to default", function()
    P:ApplyLive(RESERVED)
    P:Paint()
  end)
  reset:SetPoint("LEFT", imp, "RIGHT", GAP, 0)

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
  str:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
  Theme:Track(str, function(s)
    s:SetBackdropColor(Theme:C(Theme:IsLight() and "slot" or "bg"))
    s:SetTextColor(Theme:C("text"))
  end)
  f.str = str

  local contentW = math.max(rowWidth({ addCopy, addEmpty, del, ren }),
                            rowWidth({ exp, imp, reset }), MIN_W)
  local W = contentW + PAD * 2
  f:SetSize(W, panelHeight(1))
  str:SetWidth(W - PAD * 2)
  for i = 1, ROWS_MAX do f.rows[i]:SetWidth(W - PAD * 2) end

  return f
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
