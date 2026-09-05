local addonName, ns = ...

local TABLES, COINS, SHORTS, WORDS, ALIAS = {}, {}, {}, {}, {}

local L = setmetatable({}, { __index = function(_, k)
  local t = TABLES[ns.LocalePick()]
  local v = t and t[k]
  return v or k
end })
ns.L = L

ns.LOCALES = { "enUS" }
ns.LOCALE_LABELS = { enUS = "English" }

COINS.enUS = { g = "g", s = "s", c = "c" }
SHORTS.enUS = { dec = ".", units = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } }

local aliasMap

function ns.AddLocale(code, label, def)
  ns.LOCALES[#ns.LOCALES + 1] = code
  ns.LOCALE_LABELS[code] = label
  TABLES[code] = def.strings
  COINS[code] = def.coin
  SHORTS[code] = def.short
  if def.words then WORDS[#WORDS + 1] = def.words end
  for _, c in ipairs(def.also or {}) do ALIAS[c] = code end
  aliasMap = nil
end

local watched, globals = {}, {}

local function paint(w)
  local o = w.obj
  local t = (o.Text ~= nil) and o.Text or o
  if t.SetText then t:SetText(L[w.key]) end
end

function ns.LocalText(obj, key)
  if not obj then return obj end
  local w = { obj = obj, key = key }
  watched[#watched + 1] = w
  paint(w)
  return obj
end

function ns.LocalGlobal(name, key)
  globals[name] = key
  _G[name] = L[key]
end

function ns.ApplyLocaleText()
  for _, w in ipairs(watched) do paint(w) end
  for name, key in pairs(globals) do _G[name] = L[key] end
  if ns.Bags and ns.Bags.frame and ns.Bags.frame:IsShown() and ns.Bags.Layout then
    ns.Bags:Layout()
  end
  if ns.Bank and ns.Bank.frame and ns.Bank.frame:IsShown() and ns.Bank.Refresh then
    ns.Bank:Refresh()
  end
end

local function supported(code)
  if type(code) ~= "string" then return nil end
  code = ALIAS[code] or code
  for _, v in ipairs(ns.LOCALES) do
    if v == code then return code end
  end
  return nil
end

function ns.LocalePick()
  return supported(WarpeeDB and WarpeeDB.locale)
      or supported(GetLocale and GetLocale())
      or "enUS"
end

function ns.CoinLetter(key)
  local t = COINS[ns.LocalePick()] or COINS.enUS
  return t[key] or key
end

function ns.ShortForm()
  return SHORTS[ns.LocalePick()] or SHORTS.enUS
end

local function foldByte(ch)
  local a, b = ch:byte(1, 2)
  if a == 208 then
    if b >= 144 and b <= 159 then return "\208" .. string.char(b + 32) end
    if b >= 160 and b <= 175 then return "\209" .. string.char(b - 32) end
    if b == 129 then return "\209\145" end
  elseif a == 195 then
    if b >= 128 and b <= 158 and b ~= 151 then return "\195" .. string.char(b + 32) end
  end
  return ch
end

function ns.SearchFold(s)
  if type(s) ~= "string" then return s end
  return (s:lower():gsub("[\195\208\209][\128-\191]", foldByte))
end

function ns.SearchAlias(token)
  if not aliasMap then
    aliasMap = {}
    for _, t in ipairs(WORDS) do
      for k, v in pairs(t) do aliasMap[ns.SearchFold(k)] = v end
    end
  end
  return aliasMap[ns.SearchFold(token)]
end
