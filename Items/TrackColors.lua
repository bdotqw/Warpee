local addonName, ns = ...

-- A track's hue is read off the game's own quality palette instead of being written down here. The
-- upgrade tracks walk the same ramp as item quality: Explorer grey, Adventurer white, Veteran green,
-- Champion blue, Hero purple, Myth orange. Taking the numbers from the client means the badge agrees
-- with the border beside it and with the colors the player already reads on a tooltip, and it means no
-- hex of ours has to be retuned when Blizzard repaints that ramp. Track, not quality: a piece wears the
-- hue of the track it sits on even when its own quality is a step apart.
local TRACK_QUALITY = {
  explorer = 0, adventurer = 1, veteran = 2, champion = 3, hero = 4, myth = 5,
}

-- Hero is the one track the client's ramp does not separate from its own quality: its step is the epic
-- purple, which is also what a hero-track piece already wears, so the two would print the same number in
-- the same hue. The upgrade window reads pink there, and the pink is what a player looks for on that
-- track. This is that pink at full strength: equal red and blue with the green held low, which is the
-- shape of a hue the eye names pink. A rose with the blue pulled down, or a pale rose lifted toward the
-- text, both came out lilac beside a bag of epic purples: the blue left in them is what made them read as
-- a second, softer epic. The full magenta cannot be mistaken for it and still sits 0.38 from the epic
-- purple and 0.62 from the legendary orange.
local OVERRIDE = { hero = { r = 1, g = 0.30, b = 1 } }

-- Enum.ItemQuality order, as the client paints it. Read lazily: the palette is a client global, and a
-- caller asking before it exists gets no hue at all rather than a guessed one.
local function hueOf(track)
  if not track then return nil end
  local c = OVERRIDE[track]
  if c then return c end
  local q = TRACK_QUALITY[track]
  c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
  if c then return c end
  return nil
end

-- C_Item.GetItemUpgradeInfo answers the track's own name, and the client translates it. The struct's
-- trackStringID would be locale free, but the client publishes no names for its values, and a guessed
-- number would color the wrong track without ever saying so, so every spelling this client can hand
-- back is listed instead. A name that is not here yields no hue at all, never a guessed one, and the
-- badge keeps the quality color it wore before tracks were read. German, Spanish, Italian and
-- Portuguese spell Champion and Veteran the way English does, so those two sit in the enUS block and
-- only the differing names are repeated here.
local TRACK = {
  -- enUS
  Explorer = "explorer", Delve = "explorer", Adventurer = "adventurer",
  Veteran = "veteran", Champion = "champion", Hero = "hero", Myth = "myth",
  -- deDE
  Forscher = "explorer", Abenteurer = "adventurer", Held = "hero", Mythos = "myth",
  -- esES, esMX
  Expedicionario = "explorer", Aventurero = "adventurer", ["Campeón"] = "champion",
  ["Héroe"] = "hero", Mito = "myth",
  -- frFR
  Explorateur = "explorer", Aventurier = "adventurer", ["Vétéran"] = "veteran",
  ["Héros"] = "hero", Mythe = "myth",
  -- itIT
  Esploratore = "explorer", Avventuriero = "adventurer", Campione = "champion", Eroe = "hero",
  -- ptBR
  Explorador = "explorer", Aventureiro = "adventurer", ["Campeão"] = "champion", ["Herói"] = "hero",
  -- ruRU
  ["Исследователь"] = "explorer", ["Искатель приключений"] = "adventurer", ["Ветеран"] = "veteran",
  ["Защитник"] = "champion", ["Герой"] = "hero", ["Легенда"] = "myth",
  -- koKR
  ["탐험가"] = "explorer", ["모험가"] = "adventurer", ["노련가"] = "veteran",
  ["챔피언"] = "champion", ["영웅"] = "hero", ["신화"] = "myth",
  -- zhCN
  ["探索者"] = "explorer", ["冒险者"] = "adventurer", ["老兵"] = "veteran",
  ["勇士"] = "champion", ["英雄"] = "hero", ["神话"] = "myth",
  -- zhTW
  ["探險者"] = "explorer", ["冒險者"] = "adventurer", ["精銳"] = "veteran",
  ["勇士"] = "champion", ["英雄"] = "hero", ["神話"] = "myth",
}

-- THE ONE SEASON LINE. A crest gives a crafted piece its tier and nothing else does: the piece carries
-- no upgrade track, and its item level overlaps the tiers either side of it, so the crest is read from
-- the link's bonus ids. Midnight season 2 hero and myth crests are the bonus ids 13835 and 13836. A
-- new season adds its own pair here and the old pair stays, because pieces made with it are still in
-- the bank. To find a season's pair, compare one recipe crafted twice, once at hero and once at myth:
-- the bonus id that differs between the two links is the crest.
local CREST = { [13835] = "hero", [13836] = "myth" }

-- Both answers are asked on every paint of every gear cell, and a bag update paints all of them, so they
-- are memoised per link. A link is per item instance and an upgrade rewrites it, so a stale entry is
-- unreachable rather than wrong. The table is a session one, capped and wiped like the addon's other
-- per-link memos, and nothing about it is saved.
local CACHE_MAX = 4000
local trackCache, crestCache, cached = {}, {}, 0

local function remember(cache, link, hue)
  if cached >= CACHE_MAX then
    wipe(trackCache)
    wipe(crestCache)
    cached = 0
  end
  cache[link] = hue or false
  cached = cached + 1
  return hue
end

-- Whether the client has cached the piece at all. A cell is painted before the item arrives, and
-- GetItemUpgradeInfo answers nothing for a link the client has never seen: that is not an answer to
-- remember, or the badge would stay plain on that piece until a reload.
local function itemKnown(link)
  local get = C_Item and C_Item.GetItemInfo
  if not get then return true end
  local ok, name = pcall(get, link)
  return ok and name ~= nil
end

local function TrackHue(link)
  if type(link) ~= "string" then return nil end
  local hit = trackCache[link]
  if hit ~= nil then return hit or nil end
  local get = C_Item and C_Item.GetItemUpgradeInfo
  if not get then return nil end
  local ok, info = pcall(get, link)
  if not ok then return nil end
  local hue
  if info then
    -- The names outlive the season: a piece keeps its trackString after the season that sold it ends, but
    -- the client takes the levels away, maxLevel comes back 0 and nothing can be upgraded. What is left is
    -- not a tracked piece, so this answer is kept as "no track" and the plate reads the crest and then the
    -- quality color, which is what the upgrade window and the character sheet print for last season's
    -- gear. The level, not the name, is the thing that says the track is still the player's.
    local maxLevel = tonumber(info.maxLevel) or 0
    if maxLevel <= 0 then return remember(trackCache, link, nil) end
    local key = TRACK[info.trackString or ""]
    -- A track this client named, with no palette to paint it yet, is not a piece that has no track: that
    -- answer must not be kept, or the badge would stay plain after the palette arrives. The override needs
    -- no palette, so that path is already an answer.
    if key and not OVERRIDE[key]
       and not (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[TRACK_QUALITY[key]]) then return nil end
    hue = hueOf(key)
  elseif not itemKnown(link) then
    return nil
  end
  return remember(trackCache, link, hue)
end

-- The link's bonus list: field 13 says how many bonus ids follow, so the walk stops at that count
-- instead of reading the remaining fields of the link as ids.
local function crestKey(link)
  local payload = link:match("item:([^|]+)")
  if not payload then return nil end
  local index, last = 0, 13
  for field in (payload .. ":"):gmatch("([^:]*):") do
    index = index + 1
    if index == 13 then
      last = 13 + (tonumber(field) or 0)
    elseif index > 13 then
      if index > last then break end
      local key = CREST[tonumber(field)]
      if key then return key end
    end
  end
  return nil
end

local function CrestHue(link)
  if type(link) ~= "string" then return nil end
  local hit = crestCache[link]
  if hit ~= nil then return hit or nil end
  local key = crestKey(link)
  -- A crest this client has, with no palette to paint it yet, is not a miss: ask again next paint. The
  -- override needs no palette, so that path is already an answer.
  if key and not OVERRIDE[key]
     and not (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[TRACK_QUALITY[key]]) then return nil end
  -- Otherwise the whole answer lives in the link string, so a miss is final for that link and is kept as one.
  return remember(crestCache, link, hueOf(key))
end

-- What the category headings are painted with: the theme's own ink, unless that ink is one of the hues an
-- item level number wears. The numbers under a heading come from the palette above, so a heading that lands
-- on one of those hues reads as another number rather than as a label: Nightbloom's pink sits almost on the
-- hero pink, Reef's and Blood's cranberries on it too, and the class color theme is whatever the player's
-- class is, where a mage's blue is rare blue nearly exactly. The test is measured against the palette, never
-- kept as a list of theme names, so a theme added later is covered the day it is added. A heading that
-- collides is lifted toward the theme's own text ink: the hue stays, the saturation that made it read as an
-- item goes. The gold accents measure 0.38 and further from every one of these hues, which is why the
-- Blizzard and gold themes have always looked right and keep the accent they wear now. Quality 1 to 4 is the
-- ramp that actually fills a bag; heirloom gold and the token stay out of the test, since a bag of them is
-- rare and the warm themes are built on that hue on purpose.
local CLASH, LIFT = 0.34, 0.6

local function nearItemInk(r, g, b)
  local worst = CLASH * CLASH
  local palette = ITEM_QUALITY_COLORS
  if palette then
    for q = 1, 4 do
      local c = palette[q]
      if c then
        local dr, dg, db = r - c.r, g - c.g, b - c.b
        if dr * dr + dg * dg + db * db < worst then return true end
      end
    end
  end
  for _, c in pairs(OVERRIDE) do
    local dr, dg, db = r - c.r, g - c.g, b - c.b
    if dr * dr + dg * dg + db * db < worst then return true end
  end
  return false
end

function ns.HeadingInk(key)
  local Theme = ns.Theme
  local r, g, b = Theme:C(key)
  if not nearItemInk(r, g, b) then return r, g, b end
  local tr, tg, tb = Theme:C("text")
  return r + (tr - r) * LIFT, g + (tg - g) * LIFT, b + (tb - b) * LIFT
end

ns.TrackHue, ns.CrestHue = TrackHue, CrestHue

-- The hue the item level badge wears. The track wins over the crest, both win over the quality color,
-- and the two switches decide which of the three is asked at all: with both off the badge keeps the
-- theme's own ink, which is how the number looked before colors were read from the item.
function ns.IlvlHue(link, quality)
  local bags = ns.Bags
  if bags and bags.trackColorIlvl then
    local hue = TrackHue(link) or CrestHue(link)
    if hue then return hue end
  end
  if bags and bags.qualityColorIlvl and quality and ITEM_QUALITY_COLORS then
    return ITEM_QUALITY_COLORS[quality]
  end
  return nil
end
