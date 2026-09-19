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

-- A fresh independent copy of the shipped list, so the save never shares a table with the
-- constant and editing one profile cannot bleed into another or into the defaults.
local function seed()
  local db = {}
  for i, c in ipairs(DEFAULTS) do
    db[i] = { id = c.id, search = c.search, name = c.name, enabled = c.enabled }
  end
  return db
end

-- Seed: List() hands back the shared DEFAULTS until a custom list exists, and mutating that
-- would corrupt the constant for every profile. So every mutator calls this first: it copies
-- DEFAULTS into the save the once, and after that returns the save to edit in place.
function Cats:EnsureCustom()
  if not WarpeeDB then return DEFAULTS end
  local db = WarpeeDB.categories
  if type(db) == "table" and #db > 0 then return db end
  db = seed()
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

-- enabled is nil for on, so a fresh category and a shipped default both read as on. A plain
-- branch, not `x and false or nil`: that idiom yields nil for both cases, since its true-value is
-- itself false and the or falls through, so on could never flip to off.
function Cats:Toggle(i)
  local list = self:EnsureCustom()
  local c = list[i]
  if not c then return end
  if c.enabled == false then c.enabled = nil else c.enabled = false end
end

-- Restore the shipped list in full, not a blank save: Reset means "give me the defaults back",
-- so the save holds the seven named categories again and the editor and dump both read clean.
function Cats:Reset()
  if WarpeeDB then WarpeeDB.categories = seed() end
end

-- A section's fold state lives by category id, so it survives a reorder and rides the profile.
-- The save is kept sparse: only a collapsed id is written, an open one is cleared out, so the
-- dump lists exactly what the player folded and nothing for the default open state. "other" is a
-- real id here, so the catch-all folds like any section.
function Cats:Collapsed(id)
  local t = WarpeeDB and WarpeeDB.catCollapsed
  return (type(t) == "table" and id ~= nil and t[id]) and true or false
end

function Cats:ToggleCollapse(id)
  if not (WarpeeDB and id ~= nil) then return end
  local t = WarpeeDB.catCollapsed
  if type(t) ~= "table" then t = {}; WarpeeDB.catCollapsed = t end
  t[id] = (not t[id]) or nil
end

-- Fold or open every section at once, for the shift click on a caption. Covers every category id
-- in the list plus the "other" catch-all, so a section that is currently empty and unshown still
-- takes the state and honours it the moment it fills. Kept sparse like the single toggle.
function Cats:SetAllCollapsed(state)
  if not WarpeeDB then return end
  local t = WarpeeDB.catCollapsed
  if type(t) ~= "table" then t = {}; WarpeeDB.catCollapsed = t end
  for _, c in ipairs(self:List()) do
    if type(c) == "table" and c.id then t[c.id] = state and true or nil end
  end
  t.other = state and true or nil
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

-- A row classifies items only when it is a real record, switched on, and carries a search. A
-- blank search parses to the match-everything filter, so an empty row would silently become a
-- second catch-all and starve Other; until it is given a rule it is inert, not a category yet.
local function isActive(c)
  return type(c) == "table" and c.enabled ~= false and (c.search or ""):find("%S") ~= nil
end

local function ensureFilters()
  local list = Cats:List()
  local parts = {}
  for i, c in ipairs(list) do
    if type(c) == "table" then
      parts[i] = (c.id or "") .. "\1" .. (c.search or "") .. "\1" .. tostring(c.enabled)
    else
      parts[i] = "\1\1"
    end
  end
  local stamp = table.concat(parts, "\2")
  if stamp == filterStamp then return end
  filterStamp = stamp
  wipe(FILTERS)
  wipe(ACTIVE)
  for _, c in ipairs(list) do
    if isActive(c) then
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
  m.name = nm
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

-- Within a section the draw order is the player's to pick. Every comparator ends on name then bag
-- then slot, and bag and slot are unique per item, so each is a strict total order and table.sort
-- can never see a tie it cannot break. Only the draw moves; the cell still binds its real bag and
-- slot, so the secure right-click is untouched whatever the order.
local function byName(a, z)
  if a.name ~= z.name then return a.name < z.name end
  if a.bag ~= z.bag then return a.bag < z.bag end
  return a.slot < z.slot
end
local function byQuality(a, z)
  if a.q ~= z.q then return a.q > z.q end
  if a.ilvl ~= z.ilvl then return a.ilvl > z.ilvl end
  return byName(a, z)
end
local function byIlvl(a, z)
  if a.ilvl ~= z.ilvl then return a.ilvl > z.ilvl end
  if a.q ~= z.q then return a.q > z.q end
  return byName(a, z)
end
local SORTS = { quality = byQuality, ilvl = byIlvl, name = byName }
local function sorter()
  local mode = WarpeeDB and WarpeeDB.catSort
  return SORTS[mode] or byQuality
end

-- Every occupied slot into its section, sections that hold anything returned in ACTIVE order with
-- the catch-all last. The reagent bag is always bucketed here: cat-view is a full inventory grouping,
-- the grid's hide-reagents toggle does not gate it.
function Cats:Buckets(bags)
  ensureFilters()
  -- The live search decides which sections open while it runs, so the count of hits per section is
  -- taken here in the one pass that already builds each slot's meta, not a second scan. The window
  -- hands us its parsed filter; a blank query leaves it nil and every section keeps its saved fold.
  local q = bags and bags.query or ""
  local find = (q ~= "") and bags.filters or nil
  local order = {}
  for i = 1, #ACTIVE do
    order[i] = { id = ACTIVE[i].id, name = catName(ACTIVE[i]), slots = {}, hits = 0 }
  end
  local other = { id = "other", name = ns.L["Other"], slots = {}, hits = 0 }
  local used, total = 0, 0
  local function tally(bag)
    local num = C_Container.GetContainerNumSlots(bag) or 0
    total = total + num
    for slot = 1, num do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and (info.hyperlink or info.itemID) then
        used = used + 1
        local m = buildMeta(bag, slot, info)
        local idx = classify(m)
        local dest = (idx and order[idx]) or other
        -- The sort keys ride on the slot entry, read off the scratch meta now, since the meta is
        -- reused on the next slot and would be gone by the time the bucket is sorted.
        dest.slots[#dest.slots + 1] = {
          bag = bag, slot = slot, q = m.q or -1, ilvl = m.ilvl or 0, name = m.name or "",
        }
        if find and ns.MatchSearch(m, find) then dest.hits = dest.hits + 1 end
      end
    end
  end
  for _, bag in ipairs(ns.playerBags) do tally(bag) end
  if ns.reagentBag then tally(ns.reagentBag) end
  local out = {}
  for i = 1, #order do
    if #order[i].slots > 0 then out[#out + 1] = order[i] end
  end
  if #other.slots > 0 then out[#out + 1] = other end
  local cmp = sorter()
  for _, b in ipairs(out) do table.sort(b.slots, cmp) end
  return out, used, total
end

-- The bags the editor's counts read: cat-view always includes the reagent bag, so the count
-- beside a search matches the sections, which classify every occupied slot the same way.
local function countBags()
  local n = #ns.playerBags
  local out = {}
  for i = 1, n do out[i] = ns.playerBags[i] end
  if ns.reagentBag then out[n + 1] = ns.reagentBag end
  return out
end

-- Count for one search as it is typed: how many occupied slots it would claim, on its own. A
-- blank box reads 0, not the whole bag: an empty search is inert in the layout, so the preview
-- says the same instead of flashing the match-everything total.
function Cats:Preview(search)
  if not (search or ""):find("%S") then return 0 end
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

-- The whole editor list in one slot pass, and the number beside each row is what its section
-- actually holds: first match wins in list order, exactly like Buckets, so a slot is tallied once
-- to the first active category that claims it. A disabled or blank row is not a section, so it
-- counts 0, matching isActive and the layout. buildMeta runs once per slot, not once per slot per
-- category. Returns the per index array and, second, how many occupied slots matched nothing and
-- would fall to Other, so the editor can show the coverage the rules leave behind.
function Cats:Counts()
  local list = self:List()
  local filters, out = {}, {}
  for i, c in ipairs(list) do
    if isActive(c) then
      filters[i] = ns.ParseSearch((c.search or ""):lower())
    end
    out[i] = 0
  end
  local other = 0
  for _, bag in ipairs(countBags()) do
    local num = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, num do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and (info.hyperlink or info.itemID) then
        local m = buildMeta(bag, slot, info)
        local hit = false
        for i = 1, #list do
          if filters[i] and ns.MatchSearch(m, filters[i]) then out[i] = out[i] + 1; hit = true; break end
        end
        if not hit then other = other + 1 end
      end
    end
  end
  return out, other
end

-- The resolved caption per list row, by list index: a saved name if set, else the shipped label
-- for a default id, else the New category fallback. The editor shows these as the name field's
-- placeholder so a row without a custom name still reads as what it is instead of a blank "Name".
function Cats:Names()
  local list = self:List()
  local out = {}
  for i, c in ipairs(list) do
    out[i] = (type(c) == "table") and catName(c) or ""
  end
  return out
end
