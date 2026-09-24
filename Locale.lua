local addonName, ns = ...

local TABLES, COINS, SHORTS, WORDS, ALIAS, WORDMAP = {}, {}, {}, {}, {}, {}
local order
local FALLBACK = { esMX = "esES" }

local L = setmetatable({}, { __index = function(_, k)
  local code = ns.LocalePick()
  local t = TABLES[code]
  local v = t and t[k]
  if v == nil then
    local fb = TABLES[FALLBACK[code]]
    v = fb and fb[k]
  end
  return v or k
end })
ns.L = L

ns.LOCALES = { "enUS" }
ns.LOCALE_LABELS = { enUS = "English" }

COINS.enUS = { g = "g", s = "s", c = "c" }
SHORTS.enUS = { dec = ".", units = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } }

ALIAS.enGB = "enUS"

local aliasMap, wordCache

function ns.AddLocale(code, label, def)
  ns.LOCALES[#ns.LOCALES + 1] = code
  ns.LOCALE_LABELS[code] = label
  TABLES[code] = def.strings
  COINS[code] = def.coin
  SHORTS[code] = def.short
  if def.words then WORDS[#WORDS + 1] = def.words; WORDMAP[code] = def.words end
  for _, c in ipairs(def.also or {}) do ALIAS[c] = code end
  aliasMap, wordCache = nil, {}
  order = nil
end

local watched, globals = {}, {}

local function paint(w)
  local o = w.obj
  local t = (o.Text ~= nil) and o.Text or o
  if t.SetText then t:SetText(L[w.key]) end
end

function ns.LocalText(obj, key)
  if not obj then return obj end
  -- One watcher per object, kept on it. The list below is never pruned, so an object that
  -- registers again, as a reused label does on every paint of its page, used to add a fresh
  -- entry for the whole session and paint the same string once per entry on every language
  -- change.
  local w = obj.wpeLocal
  if w then
    w.key = key
    paint(w)
    return obj
  end
  w = { obj = obj, key = key }
  obj.wpeLocal = w
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
  -- A language change moves the item badges too, not only the labels above: the bind tag reads
  -- ns.L["BoE"]/["BoA"]/["WuE"], which localize on some clients, and the badge is only rewritten when
  -- UpdateItemButton's link guard misses. Nil every cell's link so it misses on all of them, and bump
  -- the style generation so the bank's own paint guard (styleGenSeen) rebuilds its pools the same way a
  -- font change does. Without this a bound item kept its old-language tag until it was dragged.
  if ns.ClearItemPaint then ns.ClearItemPaint() end
  if ns.Bags then ns.Bags.styleGen = (ns.Bags.styleGen or 0) + 1 end
  if ns.Bags and ns.Bags.frame and ns.Bags.frame:IsShown() and ns.Bags.Layout then
    ns.Bags:Layout()
  end
  if ns.Bank and ns.Bank.frame and ns.Bank.frame:IsShown() and ns.Bank.Refresh then
    ns.Bank:Refresh()
  end
  if ns.Pocket and ns.Pocket.Apply then ns.Pocket:Apply() end
  if ns.Profiles and ns.Profiles.Reflow then ns.Profiles:Reflow() end
end

-- Section headers are set in capitals, and Lua 5.1 maps case for ascii alone: a German
-- header came out "OBERFLäche" and every Russian one was left as written, since all its
-- letters take two bytes. The three ranges the shipped locales need are folded here by
-- hand, the way ns.SearchFold folds them the other way. A byte outside them is left alone,
-- and a run that is not a valid pair never matches and comes back as it was.
function ns.Upper(s)
  if type(s) ~= "string" then return s end
  local folded = s:gsub("[\194\195\208\209][\128-\191]", function(pair)
    local a, b = pair:byte(1, 2)
    if a == 195 then
      -- Latin-1 supplement, less the multiplication sign. Sharp s has no one-byte capital
      -- and is left as it is, the way the game's own capitals leave it.
      if b >= 160 and b <= 190 and b ~= 183 then
        return "\195" .. string.char(b - 32)
      end
    elseif a == 208 then
      -- Cyrillic U+0430 through U+043F, the low half of the alphabet.
      if b >= 176 and b <= 191 then return "\208" .. string.char(b - 32) end
    elseif a == 209 then
      -- Cyrillic U+0440 through U+044F, then U+0451 on its own.
      if b >= 128 and b <= 143 then return "\208" .. string.char(b + 32) end
      if b == 145 then return "\208\129" end
    end
    return pair
  end)
  return folded:upper()
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
      or ns.ClientLocale()
      or "enUS"
end

function ns.ClientLocale()
  return supported(GetLocale and GetLocale()) or "enUS"
end

-- The dropdown is read in scripts and not in the alphabet. The latin languages sit together, so
-- a player looking for their own scans one block instead of the whole list; cyrillic follows;
-- Han comes last, where the fonts that can draw it already are. Within a block the order is the
-- alphabet of the names, which is the one thing everybody already knows how to read. The
-- client's own language is lifted out of its block to the very top, because that is the one being
-- looked for in almost every visit, and a language nobody has placed yet falls to the end, where
-- a new one is easy to find.
local SCRIPT_RANK = {
  enUS = 1, deDE = 1, esES = 1, esMX = 1, frFR = 1, itIT = 1, ptBR = 1,
  ruRU = 2,
  zhCN = 3, zhTW = 3, koKR = 3,
}

local function byScript(a, b)
  local ra, rb = SCRIPT_RANK[a] or 9, SCRIPT_RANK[b] or 9
  if ra ~= rb then return ra < rb end
  return (ns.LOCALE_LABELS[a] or a) < (ns.LOCALE_LABELS[b] or b)
end

function ns.LocaleOrder()
  if order then return order end
  local list = {}
  for _, code in ipairs(ns.LOCALES) do list[#list + 1] = code end
  table.sort(list, byScript)
  local client = ns.ClientLocale()
  for i, code in ipairs(list) do
    if code == client then
      table.remove(list, i)
      table.insert(list, 1, code)
      break
    end
  end
  order = list
  return order
end

function ns.CoinLetter(key)
  local code = ns.LocalePick()
  local t = COINS[code] or COINS[FALLBACK[code]] or COINS.enUS
  return t[key] or key
end

function ns.ShortForm()
  local code = ns.LocalePick()
  return SHORTS[code] or SHORTS[FALLBACK[code]] or SHORTS.enUS
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

-- The words the language being read adds of its own, each with the token it stands for, in the spelling
-- the locale file wrote it. The parser resolves every language's words whatever the interface is set to,
-- but these are offered back in one language only — the one on screen — and each is resolved through the
-- same alias lookup a typed word goes through, so what is offered is what typing it would do. Cached by
-- language: switching locale mid-session is a thing the options allow, and a stale list would offer the
-- words of the language the player just left.
function ns.SearchWords()
  local code = ns.LocalePick()
  local hit = wordCache[code]
  if hit then return hit end
  local out, seen = {}, {}
  for _, c in ipairs({ code, FALLBACK[code] }) do
    local t = WORDMAP[c]
    if t then
      for k in pairs(t) do
        -- A word with a space in it cannot be typed as a token, so it is not offered as one.
        if type(k) == "string" and not k:find("%s") and not seen[k] then
          local plain = ns.SearchAlias(k)
          if plain then seen[k] = true; out[#out + 1] = { k, plain } end
        end
      end
    end
  end
  wordCache[code] = out
  return out
end
