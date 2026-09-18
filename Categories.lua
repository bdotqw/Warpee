local addonName, ns = ...

local Cats = {}
ns.Categories = Cats

-- Ordered list, first match wins, so a piece lands in one section and the order is its priority.
local DEFAULTS = {
  { id = "equipment",   search = "gear" },
  { id = "consumables", search = "consumable" },
  { id = "reagents",    search = "reagent" },
  { id = "quest",       search = "quest" },
  { id = "recipes",     search = "recipe" },
  { id = "gems",        search = "gem" },
  { id = "bags",        search = "bag" },
}

local NAMEKEY = {
  equipment   = "Equipment",
  consumables = "Consumables",
  reagents    = "Reagents",
  quest       = "Quest Items",
  recipes     = "Recipes",
  gems        = "Gems",
  bags        = "Bags",
}

-- Read only. The shipped DEFAULTS are a shared constant, so a caller that means to change the
-- list must go through EnsureCustom first, never mutate what this returns.
function Cats:List()
  local db = WarpeeDB and WarpeeDB.categories
  if type(db) == "table" and #db > 0 then return db end
  return DEFAULTS
end

-- Seed: List() hands back the shared DEFAULTS until a custom list exists, and mutating that
-- would corrupt the constant for every profile. So every mutator calls this first: it deep
-- copies DEFAULTS into the save the once, and after that returns the save to edit in place.
function Cats:EnsureCustom()
  if not WarpeeDB then return DEFAULTS end
  local db = WarpeeDB.categories
  if type(db) == "table" and #db > 0 then return db end
  db = {}
  for i, c in ipairs(DEFAULTS) do
    db[i] = { id = c.id, search = c.search, name = c.name, enabled = c.enabled }
  end
  WarpeeDB.categories = db
  return db
end

local function newId()
  local t = (GetTimePreciseSec and GetTimePreciseSec()) or time()
  return "u" .. tostring(math.floor(t * 1000))
end

-- name is left unset, never a translated literal: a string written here would freeze in the
-- language it was made in and outlive any later relocalize. catName resolves the caption live.
function Cats:Add()
  local list = self:EnsureCustom()
  list[#list + 1] = { id = newId(), search = "" }
end

function Cats:Remove(i)
  local list = self:EnsureCustom()
  if list[i] then table.remove(list, i) end
end

function Cats:Move(i, dir)
  local list = self:EnsureCustom()
  local j = i + dir
  if list[i] and list[j] then list[i], list[j] = list[j], list[i] end
end

function Cats:SetName(i, text)
  local list = self:EnsureCustom()
  if list[i] then list[i].name = text ~= "" and text or nil end
end

function Cats:SetSearch(i, text)
  local list = self:EnsureCustom()
  if list[i] then list[i].search = text or "" end
end

-- enabled is nil for on, so a fresh category and a shipped default both read as on.
function Cats:Toggle(i)
  local list = self:EnsureCustom()
  local c = list[i]
  if c then c.enabled = (c.enabled ~= false) and false or nil end
end

function Cats:Reset()
  if WarpeeDB then WarpeeDB.categories = {} end
end

local function catName(c)
  if c.name and c.name ~= "" then return c.name end
  local key = NAMEKEY[c.id]
  return (key and ns.L[key]) or ns.L["New category"]
end

-- ACTIVE and FILTERS are kept 1:1: FILTERS[i] is the parsed search of ACTIVE[i], so the index
-- classify returns reads straight back through order[i] built from ACTIVE. Filtering the
-- disabled out of one array but not the other would slide the indices apart and file items
-- under the wrong section, so both are built in the same pass and the stamp folds enabled in.
local FILTERS, ACTIVE, filterStamp = {}, {}, nil

function Cats:Version() return (WarpeeDB and WarpeeDB.categoryVer) or 0 end

function Cats:Bump()
  if WarpeeDB then WarpeeDB.categoryVer = (WarpeeDB.categoryVer or 0) + 1 end
  filterStamp = nil
end

local function ensureFilters()
  local list = Cats:List()
  local parts = {}
  for i, c in ipairs(list) do
    parts[i] = (c.id or "") .. "\1" .. (c.search or "") .. "\1" .. tostring(c.enabled)
  end
  local stamp = table.concat(parts, "\2")
  if stamp == filterStamp then return end
  filterStamp = stamp
  wipe(FILTERS)
  wipe(ACTIVE)
  for _, c in ipairs(list) do
    if c.enabled ~= false then
      local idx = #ACTIVE + 1
      ACTIVE[idx] = c
      FILTERS[idx] = ns.ParseSearch((c.search or ""):lower())
    end
  end
end

-- The same fields UpdateItemButton writes onto a cell, read straight off the container because
-- a slot is sorted before any cell is bound to it. One scratch table and one location are reused
-- like a live cell reuses b.loc, so a full pass allocates nothing; wb/exp are cleared per slot or
-- the previous slot's memoized answer leaks.
local scratch = {}
local scratchLoc = ItemLocation and ItemLocation.CreateEmpty and ItemLocation:CreateEmpty()
local function buildMeta(bag, slot, info)
  local hl = info.hyperlink
  local m = scratch
  local iItemID, iType, iSub, iEquipLoc, iClassID, iSubID
  if hl then
    iItemID, iType, iSub, iEquipLoc, _, iClassID, iSubID = C_Item.GetItemInfoInstant(hl)
  end
  local isGear = iClassID == Enum.ItemClass.Armor or iClassID == Enum.ItemClass.Weapon
  local nm = (hl and hl:match("%[(.-)%]")) or ""
  m.text = (nm .. " " .. (iType or "") .. " " .. (iSub or "")):lower()
  m.q = info.quality
  m.classID, m.subID, m.id, m.equipLoc = iClassID, iSubID, iItemID, iEquipLoc
  m.isGear = isGear
  m.bag, m.slot = bag, slot
  m.link = hl
  m.bound = info.isBound and true or false
  m.ilvl = nil
  m.loc = nil
  m.wb = nil
  m.exp = nil
  if isGear and scratchLoc then
    scratchLoc:SetBagAndSlot(bag, slot)
    m.loc = scratchLoc
    if C_Item.DoesItemExist(scratchLoc) then m.ilvl = C_Item.GetCurrentItemLevel(scratchLoc) end
  end
  if isGear and not m.ilvl then
    local getIL = C_Item.GetDetailedItemLevelInfo or GetDetailedItemLevelInfo
    if getIL and hl then m.ilvl = getIL(hl) end
  end
  m.reagent = (bag == ns.reagentBag) or iClassID == Enum.ItemClass.Tradegoods
              or iClassID == Enum.ItemClass.Reagent
  m.keystone = (hl and hl:find("keystone:", 1, true) ~= nil) or false
  return m
end

local function classify(m)
  for i = 1, #FILTERS do
    if ns.MatchSearch(m, FILTERS[i]) then return i end
  end
  return nil
end

-- Every occupied slot into its section, sections that hold anything returned in ACTIVE order with
-- the catch-all last. A hidden reagent bag still counts toward used and total so the footer does
-- not jump when it is switched off, but its items are only bucketed while it is shown.
function Cats:Buckets(bags)
  ensureFilters()
  local order = {}
  for i = 1, #ACTIVE do
    order[i] = { id = ACTIVE[i].id, name = catName(ACTIVE[i]), slots = {} }
  end
  local other = { id = "other", name = ns.L["Other"], slots = {} }
  local used, total = 0, 0
  local hide = bags.hideReagents and true or false
  local function tally(bag, bucket)
    local num = C_Container.GetContainerNumSlots(bag) or 0
    total = total + num
    for slot = 1, num do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and (info.hyperlink or info.itemID) then
        used = used + 1
        if bucket then
          local m = buildMeta(bag, slot, info)
          local idx = classify(m)
          local dest = (idx and order[idx]) or other
          dest.slots[#dest.slots + 1] = { bag = bag, slot = slot }
        end
      end
    end
  end
  for _, bag in ipairs(ns.playerBags) do tally(bag, true) end
  if ns.reagentBag then tally(ns.reagentBag, not hide) end
  local out = {}
  for i = 1, #order do
    if #order[i].slots > 0 then out[#out + 1] = order[i] end
  end
  if #other.slots > 0 then out[#out + 1] = other end
  return out, used, total
end

-- The bags the editor's counts read: the reagent bag drops out when it is hidden, so the count
-- beside a search matches what the sections actually show and does not tally slots that are off.
local function countBags()
  local hide = ns.Bags and ns.Bags.hideReagents
  local n = #ns.playerBags
  local out = {}
  for i = 1, n do out[i] = ns.playerBags[i] end
  if ns.reagentBag and not hide then out[n + 1] = ns.reagentBag end
  return out
end

-- Count for one search as it is typed: how many occupied slots it would claim, on its own.
function Cats:Preview(search)
  local filter = ns.ParseSearch((search or ""):lower())
  local n = 0
  for _, bag in ipairs(countBags()) do
    local num = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, num do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and (info.hyperlink or info.itemID) then
        if ns.MatchSearch(buildMeta(bag, slot, info), filter) then n = n + 1 end
      end
    end
  end
  return n
end

-- The whole editor list in one slot pass: buildMeta runs once per slot, not once per slot per
-- category, and each item is tested against every category's filter. Standalone counts, not the
-- first-match the sections use, so the number says what a search catches on its own. Returned by
-- list index, disabled rows included, since the editor draws them too.
function Cats:Counts()
  local list = self:List()
  local filters, out = {}, {}
  for i, c in ipairs(list) do
    filters[i] = ns.ParseSearch((c.search or ""):lower())
    out[i] = 0
  end
  for _, bag in ipairs(countBags()) do
    local num = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, num do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and (info.hyperlink or info.itemID) then
        local m = buildMeta(bag, slot, info)
        for i = 1, #filters do
          if ns.MatchSearch(m, filters[i]) then out[i] = out[i] + 1 end
        end
      end
    end
  end
  return out
end
