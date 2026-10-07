local addonName, ns = ...

local TABLES, COINS, SHORTS, WORDS, ALIAS, WORDMAP, PRIMARY = {}, {}, {}, {}, {}, {}, {}
local PLURAL = {}
local order
local FALLBACK = { esMX = "esES" }

-- The raw stored value for a key: the current language first, then its fallback, then nil. A value may be a
-- string or, for a count phrase whose noun bends with the number, a list of forms read by ns.LN.
local function lookupKey(code, k)
  local t = TABLES[code]
  local v = t and t[k]
  if v == nil then
    local fb = TABLES[FALLBACK[code]]
    v = fb and fb[k]
  end
  return v
end

-- English and German split at one versus many; Russian takes a third form for the 2-4 tail. A language
-- with no rule of its own reads the plain string form and never asks, so the default here only has to be
-- safe for the two-form languages that do store a list. The rule is a property of the language, so a
-- locale file may hand its own through def.plural; these seed the shipped set. CJK and Korean count with a
-- measure word and never bend the noun, so they get no rule and keep a single string for every count phrase.
local function twoForm(n) return (n == 1) and 1 or 2 end
-- French and Portuguese keep the singular for zero as well as one.
local function romance(n) return (n <= 1) and 1 or 2 end
local function slavic(n)
  local m10, m100 = n % 10, n % 100
  if m10 == 1 and m100 ~= 11 then return 1 end
  if m10 >= 2 and m10 <= 4 and not (m100 >= 12 and m100 <= 14) then return 2 end
  return 3
end
PLURAL.enUS = twoForm
PLURAL.deDE = twoForm
PLURAL.esES = twoForm
PLURAL.itIT = twoForm
PLURAL.frFR = romance
PLURAL.ptBR = romance
PLURAL.ruRU = slavic

local function pluralPick(code)
  return PLURAL[code] or PLURAL[FALLBACK[code]] or PLURAL.enUS
end

-- A localized count phrase: the value may be one string (same wording for every number, formatted as is) or
-- a list of forms, one per plural class, picked by the language's own rule. The number is the first format
-- argument, extra args follow. So "catches %d in bags" bends the noun on ruRU ("1 предмет" / "2 предмета"
-- / "5 предметов") and stays one string where the language does not bend it.
function ns.LN(key, n, ...)
  local code = ns.LocalePick()
  local v = lookupKey(code, key)
  local s
  if type(v) == "table" then
    local idx = pluralPick(code)(n)
    s = v[idx] or v[#v] or key
  else
    s = v or key
  end
  return s:format(n, ...)
end

local L = setmetatable({}, { __index = function(_, k)
  local v = lookupKey(ns.LocalePick(), k)
  -- A plural-list value is only ever read through ns.LN; a bare L[key] on such a key would hand back a
  -- table, so fall to the key text rather than let a caller format a table.
  if type(v) == "table" then return k end
  return v or k
end })
ns.L = L

ns.LOCALES = { "enUS" }
ns.LOCALE_LABELS = { enUS = "English" }

COINS.enUS = { g = "g", s = "s", c = "c" }
SHORTS.enUS = { dec = ".", units = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } }

-- English carries its own plural on the count phrases where the noun rides the number: "1 item" against
-- "5 items". Count phrases whose noun does not attach to the number ("catches 5 in bags") stay plain keys
-- with no list. English keeps no full strings table, so this holds only the keys that bend; a key absent
-- here still falls straight through to itself.
TABLES.enUS = {
  ["%d items"] = { "%d item", "%d items" },
  ["%d items for %s"] = { "%d item for %s", "%d items for %s" },
  ["%d items could not be sold and stayed in the bags"] = {
    "%d item could not be sold and stayed in the bags",
    "%d items could not be sold and stayed in the bags",
  },
  ["%d bound pieces stay in the bags"] = {
    "%d bound piece stays in the bags",
    "%d bound pieces stay in the bags",
  },
}

ALIAS.enGB = "enUS"

local aliasMap, aliasByCode, wordCache, ilvlPrefixes

function ns.AddLocale(code, label, def)
  ns.LOCALES[#ns.LOCALES + 1] = code
  ns.LOCALE_LABELS[code] = label
  TABLES[code] = def.strings
  COINS[code] = def.coin
  SHORTS[code] = def.short
  if def.plural then PLURAL[code] = def.plural end
  if def.words then WORDS[#WORDS + 1] = def.words; WORDMAP[code] = def.words end
  -- The words the language names its things by, folded once here: a language takes several spellings for
  -- one thing, and without a name of its own the label a concept is drawn under would be whichever of
  -- them the word map happened to hand back first.
  if def.primary then
    local set = {}
    for _, w in ipairs(def.primary) do set[ns.SearchFold(w)] = true end
    PRIMARY[code] = set
  end
  for _, c in ipairs(def.also or {}) do ALIAS[c] = code end
  aliasMap, aliasByCode, wordCache, ilvlPrefixes = nil, nil, {}, nil
  order = nil
end

-- Raw strings of one language, for readers that look across languages.
function ns.LocaleStrings(code)
  return TABLES[code]
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
  -- The search-words window rebuilds from the live locale, so an open one follows a language switch.
  if ns.RefreshSearchWords then ns.RefreshSearchWords() end
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

-- Capitalize the first character only, leaving the rest as written. The first character may be a
-- multi-byte utf-8 letter (a Cyrillic word, say), so its byte length is measured before it is handed to
-- ns.Upper; a CJK or digit first character has no capital and passes through unchanged.
function ns.UpperFirst(s)
  if type(s) ~= "string" or s == "" then return s end
  local b = s:byte(1)
  local len = 1
  if b >= 240 then len = 4 elseif b >= 224 then len = 3 elseif b >= 192 then len = 2 end
  return ns.Upper(s:sub(1, len)) .. s:sub(len + 1)
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

-- Whether this is the spelling the language on screen names the thing by (see def.primary above). The
-- picker's labels and the help sheet's group heads read it; a language that names none keeps the first
-- spelling its word map hands back.
function ns.SearchPrimary(word)
  local code = ns.LocalePick()
  local set = PRIMARY[code] or PRIMARY[FALLBACK[code]]
  return (set and set[ns.SearchFold(word)] == true) or false
end

-- A localized word resolved to the English token it stands for. The language on screen is asked first,
-- then every language's map as a fallback: so a word is read the way the player's own language means it,
-- and only a word their language has no meaning for falls through to another language's reading. Without
-- the first pass a spelling two languages give different meanings (German "hast" = haste, French "hast" =
-- polearm; "cintura" waist in Spanish, belt in Italian) resolved to whichever language loaded last, which
-- is not the one on screen. The merged map is still there, so cross-language search keeps working.
function ns.SearchAlias(token)
  if not aliasMap then
    aliasMap, aliasByCode = {}, {}
    for _, t in ipairs(WORDS) do
      for k, v in pairs(t) do aliasMap[ns.SearchFold(k)] = v end
    end
    for code, t in pairs(WORDMAP) do
      local set = {}
      for k, v in pairs(t) do set[ns.SearchFold(k)] = v end
      aliasByCode[code] = set
    end
  end
  local folded = ns.SearchFold(token)
  local code = ns.LocalePick()
  local own = aliasByCode[code] or aliasByCode[FALLBACK[code]]
  if own and own[folded] ~= nil then return own[folded] end
  return aliasMap[folded]
end

-- Spellings of the item-level prefix itself ("gs", "илвл", "装等"): a token starting with one
-- reads as ilvl plus whatever follows it, so gs400 and 装等400 parse like ilvl400. Gathered from
-- every language's word map, so they work whatever the interface language is; longest first,
-- so a longer spelling wins over its own prefix.
function ns.IlvlPrefixes()
  if not ilvlPrefixes then
    ilvlPrefixes = {}
    for _, t in ipairs(WORDS) do
      for k, v in pairs(t) do
        if v == "ilvl" then ilvlPrefixes[#ilvlPrefixes + 1] = ns.SearchFold(k) end
      end
    end
    table.sort(ilvlPrefixes, function(a, b) return #a > #b end)
  end
  return ilvlPrefixes
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
