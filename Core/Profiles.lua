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
    for k in pairs(t) do
      if k ~= RESERVED then out[#out + 1] = k end
    end
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
local function livePos(frame, key)
  if not frame then return nil end
  local l, b = frame:GetLeft(), frame:GetBottom()
  if not (l and b) then return nil end
  return ns.RectRecord(frame, key, ns.SnapValue(frame, l), ns.SnapValue(frame, b))
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
    if out[w.key] == nil then out[w.key] = livePos(w.get(), w.key) end
  end
  return out
end

function P:Store(name)
  name = trim(name)
  if not WarpeeDB or name == "" or name == RESERVED then return false end
  WarpeeDB[LIST] = WarpeeDB[LIST] or {}
  if WarpeeDB[LIST][name] then return false end
  WarpeeDB[LIST][name] = self:Capture()
  return true
end

function P:StoreEmpty(name)
  name = trim(name)
  if not WarpeeDB or name == "" or name == RESERVED then return false end
  WarpeeDB[LIST] = WarpeeDB[LIST] or {}
  if WarpeeDB[LIST][name] then return false end
  WarpeeDB[LIST][name] = {}
  return true
end

function P:Delete(name)
  if name == RESERVED then return false end
  if not (WarpeeDB and WarpeeDB[LIST] and WarpeeDB[LIST][name]) then return false end
  if name == self:Active() then return false end
  WarpeeDB[LIST][name] = nil
  return true
end

function P:Rename(old, new)
  old, new = trim(old), trim(new)
  if old == "" or new == "" or old == new then return false end
  if old == RESERVED or new == RESERVED then return false end
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
  local t = WarpeeDB[LIST] and WarpeeDB[LIST][name]
  if name ~= RESERVED and not t then return false end
  ns.WipeConfig(WarpeeDB)
  if t then
    for k, v in pairs(t) do
      if ns.DEFAULTS[k] ~= nil then WarpeeDB[k] = ns.CopyDeep(v) end
    end
  end
  WarpeeDB[SELECTED] = name ~= RESERVED and name or nil
  ns.FillComputed(WarpeeDB)
  ns.SanitizeConfig(WarpeeDB)
  if ns.Categories and ns.Categories.Migrate then ns.Categories:Migrate() end
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
  local t = WarpeeDB[LIST]
  if not t then return false end
  t[self:Active()] = self:Capture()
  return true
end

function P:ResetActive()
  if not WarpeeDB then return false end
  local active = self:Active()
  ns.WipeConfig(WarpeeDB)
  ns.FillComputed(WarpeeDB)
  ns.SanitizeConfig(WarpeeDB)
  if ns.Ready then
    ns.Applying = true
    local ok, err = pcall(ns.ApplyAll)
    ns.Applying = false
    if not ok then error(err, 0) end
  end
  WarpeeDB[LIST] = WarpeeDB[LIST] or {}
  WarpeeDB[LIST][active] = self:Capture()
  return true
end

-- A save written before the default profile was stored keeps its values in the live config
-- and has no copy to switch back to. Capture that live config as the default when it is the
-- profile in use, and seed it from the factory values otherwise, since what was active then
-- was a named profile.
function P:Migrate()
  if not WarpeeDB then return false end
  local t = WarpeeDB[LIST]
  if t and t[RESERVED] then return false end
  local seed = {}
  if self:Active() == RESERVED then
    seed = self:Capture()
  else
    ns.WipeConfig(seed)
  end
  WarpeeDB[LIST] = t or {}
  WarpeeDB[LIST][RESERVED] = seed
  return true
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

-- The keys a profile code does not carry. The category list is shared through its own code (the
-- CN_PREFIX one below), so a profile must not smuggle it too: two people trading profiles would
-- otherwise overwrite each other's category lists as a side effect of copying a theme or a layout,
-- which is the whole reason the list was split out into its own code. Stripped on export only — a
-- local profile still stores and switches the list, so picking a profile keeps its own categories.
local EXPORT_SKIP = { categories = true }

function P:Export(name)
  name = name or self:Active()
  local data = WarpeeDB and WarpeeDB[LIST] and WarpeeDB[LIST][name]
  if type(data) ~= "table" then
    if name ~= RESERVED then return "" end
    data = self:Capture()
  end
  -- A fresh shallow copy without the skipped keys, so the stored profile keeps its category list and
  -- only the code leaves without one. CopyDeep on each kept value so the payload never shares a table
  -- with the save.
  local out = {}
  for k, v in pairs(data) do
    if not EXPORT_SKIP[k] then out[k] = ns.CopyDeep(v) end
  end
  local body = packPayload({ _v = SCHEMA, _n = name, d = out })
  -- A codec that refuses is not a profile that came out empty. Both used to answer with the
  -- prefix and nothing after it, which reads as a code and fails on the other end as a
  -- damaged one; the empty string is what the panel already takes as "nothing to copy".
  if body == "" then return "" end
  return PREFIX .. body
end

function P:Import(str, name)
  if not ns.Ready then return false, "Not ready" end
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
  -- The name of a key is not enough to let its value through. A code from outside can carry a
  -- number where the default is a table, and the login path then dies inside fillComputed
  -- before the grid is built. A value of the wrong shape is dropped here, where it arrives,
  -- rather than saved and read back on the next login.
  local clean = {}
  for k, v in pairs(data) do
    local d = ns.DEFAULTS[k]
    if d ~= nil and type(v) == type(d) then clean[k] = ns.CopyDeep(v) end
  end
  -- A profile code no longer carries the category list (see EXPORT_SKIP), so an imported profile has
  -- none. Applying it as-is would let WipeConfig reset the player's list to the shipped default — a
  -- silent wipe of the categories he built, as a side effect of importing a layout. So the current list
  -- is carried into the imported profile: importing a profile keeps your categories, and a list is only
  -- ever replaced through its own code, which is exactly the split the two codes are for.
  if clean.categories == nil and type(WarpeeDB.categories) == "table" then
    clean.categories = ns.CopyDeep(WarpeeDB.categories)
  end
  WarpeeDB[LIST] = WarpeeDB[LIST] or {}
  WarpeeDB[LIST][name] = clean
  self:ApplyLive(name)
  return true, name
end

-- The category list travels in the same envelope as a profile and through the same packer, under a
-- prefix of its own: what a code holds is written on it, so a holder — our own paste field or another
-- addon's installer — never has to be told which of the two it is holding. The reason the two are
-- apart at all is that a profile is a whole machine: it carries window positions, cell sizes, theme
-- and the saved characters, and none of that means anything on somebody else's screen. A list of rules
-- does.
local CN_PREFIX = "!WPC1!"
local CN_SCHEMA = 1

-- The list as a code, ready to be pasted anywhere. Only the list and the order items take inside a
-- section travel; every other setting keeps its own value on the receiving side.
function P:ExportCategories()
  local list = ns.Categories and ns.Categories:ShareList() or {}
  local body = packPayload({ _v = CN_SCHEMA, _n = "categories",
                             d = { list = list, sort = WarpeeDB and WarpeeDB.catSort or nil } })
  if body == "" then return "" end
  return CN_PREFIX .. body
end

-- Take a category code. mode "replace" puts the code's list in place of the current one; anything else
-- merges, which is what the name says and what a caller that cannot ask for a choice should get: a
-- merge only adds rows, so a wrong guess never costs the player the list he built.
function P:ImportCategories(str, mode)
  if not ns.Ready then return false, "Not ready" end
  if type(str) ~= "string" then return false, "Nothing to import" end
  str = str:gsub("^%s+", ""):gsub("%s+$", "")
  if str == "" then return false, "Nothing to import" end
  if str:sub(1, #CN_PREFIX) ~= CN_PREFIX then return false, "Not a profile code" end
  local env = unpackPayload(str:sub(#CN_PREFIX + 1))
  local d = type(env) == "table" and env.d or nil
  if type(d) ~= "table" or type(d.list) ~= "table" then return false, "Damaged code" end
  if not upgrade(d, env._v) then return false, "Saved by a newer version" end
  local replace = (mode == "replace")
  local count, err = ns.Categories:TakeList(d.list, replace and "replace" or "merge", d.sort)
  if not count then return false, err or "Nothing to import" end
  if ns.Options then
    if ns.Options.catChanged then
      ns.Options.catChanged()
    elseif ns.Options.RefreshOpen then
      ns.Options:RefreshOpen()
    end
  end
  -- The editor was never opened in this session, so its own refresh path does not exist yet. Applying
  -- the state again is the heavy door, but it is the one that leaves the bag, the bank and the pocket
  -- classifying by the list that was just read in.
  if not (ns.Options and ns.Options.catChanged) and ns.ApplyAll then pcall(ns.ApplyAll) end
  return true, count, replace and "replace" or "merge"
end

-- Which kind of code this is, read off the code itself. Nil for anything else, including the empty
-- string, so a paste field can say what it is about to do before it does it.
function P:CodeKind(str)
  if type(str) ~= "string" then return nil end
  str = str:gsub("^%s+", ""):gsub("%s+$", "")
  if str:sub(1, #PREFIX) == PREFIX then return "profile" end
  if str:sub(1, #CN_PREFIX) == CN_PREFIX then return "categories" end
  return nil
end

-- The schema a code was written with. A holder that ships a code of its own wants this: it is how it
-- tells that the one already installed came from an older build and wants re-importing.
function P:CodeVersion(str)
  local kind = self:CodeKind(str)
  if not kind then return nil end
  local cut = #(kind == "categories" and CN_PREFIX or PREFIX)
  local s = str:gsub("^%s+", ""):gsub("%s+$", ""):sub(cut + 1)
  local env = unpackPayload(s)
  return type(env) == "table" and tonumber(env._v) or nil
end

-- One door for a code of either kind, so a caller can hand over whatever it was given. The kind
-- decides where it lands: a category code edits the list, a profile code becomes a profile and is
-- applied. Anything else is refused with the reason the paste fields already print.
function P:ImportAny(str, name, mode)
  local kind = self:CodeKind(str)
  if kind == "categories" then return self:ImportCategories(str, mode) end
  if kind == "profile" then return self:Import(str, name) end
  return false, "Not a profile code"
end

local API = {}
ns.API = API

-- The documented surface for anything outside the addon: another addon's installer, a macro, a script.
-- Every entry point works with the settings window closed and never raises: a code from outside is
-- read, not trusted. ImportCategories answers (ok, count | reason) and ImportAny takes either kind.
function API:ImportCategories(str, mode)
  return ns.Profiles:ImportCategories(str, mode)
end

function API:ExportCategories()
  return ns.Profiles:ExportCategories()
end

function API:ImportAny(str, mode)
  return ns.Profiles:ImportAny(str, nil, mode)
end

function API:CanImport(str)
  return ns.Profiles:CodeKind(str)
end

function API:GetVersion(str)
  return ns.Profiles:CodeVersion(str)
end

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
  return ns.Profiles:ResetActive()
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
              + ROW_H + SHARE_GAP + ROW_H + CODE_GAP + STR_H + PAD
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
    ns.SetBg(s, Theme:C(hot and "panelHi" or "panel"))
    ns.SetEdge(s, Theme:C(fade and "strokeSoft"
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
    ns.SetButtonEnabled(f.renBtn, active ~= RESERVED)
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
  f:SetScript("OnDragStart", function(s) ns.DragMove(s) end)
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

  local nameBox = ns.CreateSearchBox(f, nil, "New profile name")
  f.nameBox = nameBox

  local dup = autoButton(f, "Duplicate current", function()
    local n = trim(nameBox:GetText())
    if n == "" then say(T("Enter a profile name")) return end
    if not P:Store(n) then say(T("That name is taken")) return end
    nameBox:SetText("")
    P:ApplyLive(n)
    say(T("Created %s"):format(n))
    P:Paint()
  end)

  local fresh = autoButton(f, "Create empty", function()
    local n = trim(nameBox:GetText())
    if n == "" then say(T("Enter a profile name")) return end
    if not P:StoreEmpty(n) then say(T("That name is taken")) return end
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
  local ddSpec = {
    get = function() return P:Active() end,
    set = function(name)
      -- Re-picking the entry that is already active would re-apply it, and for a profile
      -- with no stored copy of its own, Default among them, that wipes back to factory.
      if name ~= P:Active() then P:ApplyLive(name) end
    end,
    keys = function() return P:List() end,
    label = function(k) return k == RESERVED and T("Default") or k end,
  }
  local ddPick = function()
    P:Paint()
    if ns.Options and ns.Options.Refresh then ns.Options:Refresh() end
  end
  dd.wpeDrop = { spec = ddSpec, onPick = ddPick }
  dd:SetScript("OnClick", function(s)
    if not ns.OpenDropdown then return end
    ns.OpenDropdown(s, ddSpec, ddPick)
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
    local cur = P:Active()
    if cur == RESERVED then return end
    local n = trim(nameBox:GetText())
    if n == "" then say(T("Enter a profile name")) return end
    if not P:Rename(cur, n) then say(T("That name is taken")) return end
    nameBox:SetText("")
    P:Paint()
  end)
  ns.AddTip(ren, function()
    if P:Active() ~= RESERVED then return nil end
    return T("Cannot rename the default profile")
  end, "top")
  f.renBtn = ren

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

  -- The field takes a code of either kind, since what a code holds is written on it: a profile code
  -- becomes a profile and is applied, a category code edits the list where it stands. A category code
  -- merges here rather than replacing: this panel is not the list's own editor and nobody is asked for a
  -- choice, so the direction that cannot cost the player his rows is the one taken.
  local imp = autoButton(f, "Import", function()
    local text = f.str:GetText()
    if P:CodeKind(text) == "categories" then
      local ok, res = P:ImportCategories(text, "merge")
      if not ok then say(T(res)) return end
      say(T("Imported sections: %d"):format(res))
      return
    end
    local ok, res = P:Import(f.str:GetText(), nameBox:GetText())
    if not ok then say(T(res)) return end
    say(T("Imported %s"):format(res))
    P:Paint()
  end)
  imp:SetPoint("LEFT", exp, "RIGHT", GAP, 0)
  tintButton(exp, "dim")
  tintButton(imp, "dim")

  local reset = autoButton(f, "Reset to defaults", function()
    local active = P:Active()
    StaticPopupDialogs["WARPEE_RESET_PROFILE"].text = T("Reset profile %s?")
    StaticPopup_Show("WARPEE_RESET_PROFILE",
                     active == RESERVED and T("Default") or active, nil, active)
  end)
  reset:SetPoint("TOPLEFT", exp, "BOTTOMLEFT", 0, -SHARE_GAP)
  tintButton(reset, "dim")

  local str = CreateFrame("EditBox", nil, f, "BackdropTemplate")
  str:SetAutoFocus(false)
  str:SetFont(ns.Fonts:Current(), 11, ns.OutlineFlags())
  str:SetTextColor(Theme:C("text"))
  str:SetHeight(STR_H)
  ns.PixelBackdrop(str)
  ns.SetBg(str, Theme:C(Theme:IsLight() and "slot" or "bg"))
  ns.SetEdge(str, Theme:C("stroke"))
  str:SetTextInsets(6, 6, 4, 4)
  str:SetPoint("TOPLEFT", reset, "BOTTOMLEFT", 0, -CODE_GAP)
  str:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, PAD)
  str:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
  Theme:Track(str, function(s)
    ns.SetBg(s, Theme:C(Theme:IsLight() and "slot" or "bg"))
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
  f.row3 = { reset }
  f:SetHeight(PANEL_H)
  self:Reflow()
  self:ApplySkin()

  return f
end

function P:Reflow()
  local f = self.panel
  if not f then return end
  local rows = { f.row1, f.row2, f.row3 }
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

StaticPopupDialogs["WARPEE_RESET_PROFILE"] = {
  text = "Reset profile %s?",
  button1 = _G.OKAY or "OK",
  button2 = _G.CANCEL or "Cancel",
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  showAlert = true,
  OnAccept = function(_, name)
    if not ns.Profiles:ResetActive() then return end
    ns.Profiles:Paint()
    if ns.Options and ns.Options.Refresh then ns.Options:Refresh() end
    say(T("Reset %s"):format(name == RESERVED and T("Default") or name))
  end,
}

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
