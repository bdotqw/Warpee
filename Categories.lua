local addonName, ns = ...

local Cats = {}
ns.Categories = Cats

-- Forward-declared here, above Cats:PinItem, so its `filterStamp = nil` (the cache invalidation on a
-- pin change) writes this upvalue and not a stray global. The classify cache below (FILTERS/PINS/
-- ACTIVE) is assigned into these same names once they are in scope; without this line PinItem sat
-- textually before the local and its assignment silently missed the cache.
local FILTERS, PINS, ACTIVE, filterStamp

-- The Empty section's own fold id. It owns no items, so it never collides with a real category id
-- (shipped ids are words, custom ids start with "u"): it exists only so the free-space section folds
-- through the same catCollapsed map every real section rides.
Cats.EMPTY_ID = "empty"
-- The catch-all's id. Like EMPTY_ID it is no real category, only the folding key and the tag the bag
-- reads to know a drop here should do nothing: Empty is the one unfile target now, Other is inert.
Cats.OTHER_ID = "other"

-- Ordered list, first match wins, so a piece lands in one section and the order is its priority.
-- Sharp edges to keep in mind before reordering: Weapon is by slot (`weapon shield` — shield is a
-- slot and ORs into the weapon slot-set; it must not be mixed with an armor kind-row, since slot and
-- kind are different axes and AND to nothing). Jewelry is `ring neck` only, with Trinkets split into
-- its own row below; leave trinket in Jewelry and the Trinkets row goes empty, since Jewelry sits
-- higher and claims them first. Collectibles unites three things on different axes — Toy is a flag,
-- Mount and Battlepet are kinds — so it needs the top-level "|": `toy | mount battlepet` = toy OR
-- (mount OR battlepet). Junk sits just above Other so it reads low like the bag it replaces: there is
-- no Misc row here, so grey vendor trash (classID Miscellaneous) falls past everything into Junk, and
-- the gear rows above Junk carry "!junk" so a grey piece drops past its type into Junk too. Delete the
-- "!junk" from a gear row and its greys stay in it. Everything no row claims lands in Other.
local DEFAULTS = {
  -- Free space, not a rule: owns no search, matches nothing. It is the grouped view's stand-in for the
  -- grid's trailing blank cells; seeded first here by the owner's order, movable from the editor.
  { id = "empty",        empty = true, g = "essentials" },
  { id = "hearthstone",  search = "id6948", g = "essentials" },
  { id = "keystone",     search = "keystone", g = "essentials" },
  { id = "flasks",       search = "flask", g = "consumables" },
  { id = "food",         search = "food", g = "consumables" },
  { id = "potions",      search = "potion", g = "consumables" },
  { id = "weapons",      search = "weapon shield !junk", g = "gear" },
  { id = "jewelry",      search = "ring neck !junk", g = "gear" },
  { id = "armor",        search = "cloth leather mail plate !junk", g = "gear" },
  { id = "trinkets",     search = "trinket !junk", g = "gear" },
  { id = "quest",        search = "quest", g = "collections" },
  { id = "collectibles", search = "toy | mount battlepet", g = "collections" },
  { id = "housing",      search = "housing", g = "collections" },
  { id = "reagents",     search = "reagent", g = "rest" },
  { id = "junk",         search = "junk", g = "rest" },
  -- The catch-all: every item no rule claimed lands here. Never switched off or deleted, since items
  -- must always have somewhere to land. Seeded last so it stays the floor of the list.
  { id = "other",        other = true, g = "rest" },
}

local GROUP_NAMEKEY = {
  essentials   = "Essentials",
  consumables  = "Consumables",
  gear         = "Gear",
  collections  = "Collections",
  rest         = "Rest",
}

local NAMEKEY = {
  hearthstone  = "Hearthstone",
  keystone     = "Keystones",
  flasks       = "Flasks",
  food         = "Food",
  potions      = "Potions",
  weapons      = "Weapons",
  jewelry      = "Jewelry",
  armor        = "Armor",
  trinkets     = "Trinkets",
  quest        = "Quest Items",
  collectibles = "Collectibles",
  housing      = "Housing",
  reagents     = "Reagents",
  junk         = "Junk",
  empty        = "Empty",
  other        = "Other",
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
    db[i] = { id = c.id, search = c.search, name = c.name, enabled = c.enabled,
              empty = c.empty, other = c.other, g = c.g }
  end
  return db
end

-- The groups a fresh save starts with, in band order, taken off the shipped rows so the two can
-- never disagree about which group an id names.
local function seedGroups()
  local out, seen = {}, {}
  for _, c in ipairs(DEFAULTS) do
    if c.g and not seen[c.g] then
      seen[c.g] = true
      out[#out + 1] = { id = c.g }
    end
  end
  return out
end

local function shippedGroup(id)
  for _, c in ipairs(DEFAULTS) do
    if c.id == id then return c.g end
  end
end

-- The group a row added at `at` joins: the row above the insert point, else the row below it,
-- else the first group.
local function joinGroup(list, at)
  local above, below = list[at - 1], list[at]
  local g = (type(above) == "table" and above.g) or (type(below) == "table" and below.g)
  if g then return g end
  local groups = WarpeeDB and WarpeeDB.catGroups
  return (type(groups) == "table" and groups[1] and groups[1].id) or nil
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
  -- A new custom row goes above the structural tail (Empty, Other), never after it: those two are
  -- the floor of the list and a rule added below Other would never be reached. Same insover point
  -- the presets use, so hand-add and preset-add drop a row in the same place.
  local at = self:InsertAt(list)
  table.insert(list, at, { id = newId(), search = "", g = joinGroup(list, at) })
end

-- The shipped named categories, offered in the editor as one-click "add this whole category" presets.
-- This is the DEFAULTS list minus the two structural rows (Empty, Other are always present and are
-- not things you add), in the same order, so the preset strip reads like the default layout. id keys
-- into NAMEKEY for the caption and is what a duplicate check compares, search is copied verbatim.
local PRESET_IDS = {
  "hearthstone", "keystone", "flasks", "food", "potions", "weapons", "jewelry",
  "armor", "trinkets", "quest", "collectibles", "housing", "reagents", "junk",
}
local PRESET_SEARCH = {}
for _, c in ipairs(DEFAULTS) do
  if not (c.empty or c.other) then PRESET_SEARCH[c.id] = c.search end
end

-- The presets, each { id, name, search }, name resolved live so it never freezes a language.
function Cats:Presets()
  local out = {}
  for _, id in ipairs(PRESET_IDS) do
    out[#out + 1] = { id = id, name = (NAMEKEY[id] and ns.L[NAMEKEY[id]]) or id,
                      search = PRESET_SEARCH[id] or "" }
  end
  return out
end

-- Whether a category with this id is already in the list, so the strip can dim a preset that is in.
function Cats:Has(id)
  for _, c in ipairs(self:List()) do
    if type(c) == "table" and c.id == id then return true end
  end
  return false
end

-- The index a new row is inserted at: just before the first structural row (Empty or Other), so
-- every added category lands in the rule region and the two catch-alls stay at the floor. Falls back
-- to the end if somehow neither is present (a list mid-heal), which EnsureEmpty/EnsureOther then fix.
function Cats:InsertAt(list)
  list = list or self:List()
  for i, c in ipairs(list) do
    if type(c) == "table" and (c.empty or c.other) then return i end
  end
  return #list + 1
end

-- Add a preset by id: a fresh independent row (never a reference into DEFAULTS) with the preset's
-- search, inserted in the rule region. A second add of the same preset is a no-op, so the strip's
-- one-click add can never make two "Armor" rows; the caller dims an in-list preset to signal that.
function Cats:AddPreset(id)
  if not id or self:Has(id) then return end
  local search = PRESET_SEARCH[id]
  if search == nil then return end
  local list = self:EnsureCustom()
  local at = self:InsertAt(list)
  table.insert(list, at, { id = id, search = search, g = joinGroup(list, at) })
end

function Cats:Remove(i)
  local list = self:EnsureCustom()
  local c = list[i]
  -- Empty and Other are structural, not rules: Empty stands in for free space and Other catches
  -- everything unmatched, so neither may be deleted. The editor hides their delete buttons, and this
  -- guards the path anyway so no other caller can drop them.
  if not c or c.empty or c.other then return end
  table.remove(list, i)
end

function Cats:Move(i, dir)
  local list = self:EnsureCustom()
  local j = i + dir
  if list[i] and list[j] then list[i], list[j] = list[j], list[i] end
end

-- Lift the row at from and drop it before the row at to, the arbitrary-distance move the drag needs
-- where Move only steps one place. to is the slot the row lands in after the lift, so dragging down
-- past the tail clamps to the end. A move onto itself or its own next slot is a no-op.
function Cats:MoveTo(from, to)
  local list = self:EnsureCustom()
  if not list[from] then return end
  local n = #list
  if to < 1 then to = 1 elseif to > n then to = n end
  if to == from then return end
  local c = table.remove(list, from)
  table.insert(list, to, c)
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
  -- The catch-all is never switched off: unmatched items must always have somewhere to land. The
  -- editor shows it no checkbox, and this guards the path so no other caller can disable it either.
  if c.other then return end
  if c.enabled == false then c.enabled = nil else c.enabled = false end
end

-- Pin an item to the category with this id. An item lives in one manual home, so it is lifted from
-- every other section's pin set first, then added here; a drop on a section it already sits in is a
-- no-op after the lift. id is the plain numeric itemID. targetId nil or an id no section owns just
-- clears the pin everywhere, which is how a drop on Other unfiles a piece. The classify cache is
-- keyed on the pin sets, so a change nils the stamp to force a reclassify on the next pass.
function Cats:PinItem(itemID, targetId)
  if not itemID then return end
  local list = self:EnsureCustom()
  for _, c in ipairs(list) do
    if type(c) == "table" and type(c.pins) == "table" then
      c.pins[itemID] = nil
      if next(c.pins) == nil then c.pins = nil end
    end
  end
  -- Dropping a piece on the very section its rules already send it to is not a pin: it is a no-op the
  -- player reads as "put it back". Pinning it there anyway left a redundant pin that stayed in the
  -- editor and blocked moving the piece elsewhere until it was cleared by hand. So a target that
  -- equals the rule-home unfiles instead of pinning; the lift above already cleared any prior pin.
  if targetId and targetId == self:RuleHome(itemID) then targetId = nil end
  if targetId then
    for _, c in ipairs(list) do
      if type(c) == "table" and c.id == targetId then
        -- The Empty section owns no items on purpose, so a drop there is the unfile: the lift above
        -- already cleared the piece's home, and nothing is pinned. It draws only free-slot tiles, so
        -- an item filed here would classify into a section that never renders its slots and vanish.
        -- Other has no list row at all and so never reaches this loop; the lift is its unfile too.
        if not c.empty then
          c.pins = c.pins or {}
          c.pins[itemID] = true
        end
        break
      end
    end
  end
  filterStamp = nil
end

-- The category id an item is pinned to, or nil. Read side for the editor and any caller that wants
-- to show or clear a pin without walking the list itself.
function Cats:PinnedTo(itemID)
  if not itemID then return nil end
  for _, c in ipairs(self:List()) do
    if type(c) == "table" and type(c.pins) == "table" and c.pins[itemID] then return c.id end
  end
  return nil
end

-- Restore the shipped list in full, not a blank save: Reset means "give me the defaults back",
-- so the save holds the seven named categories again and the editor and dump both read clean.
function Cats:Reset()
  if WarpeeDB then
    WarpeeDB.categories = seed()
    WarpeeDB.catGroups = seedGroups()
    WarpeeDB.catGroupFold = {}
  end
end

-- The Empty section is not deletable, so its row must always be present in a custom list. A save from
-- before Empty was a list member carries no row for it, and so does one that predates this rule and
-- had it removed while delete still existed; either way this restores it at the tail. A fresh List()
-- already carries Empty from DEFAULTS, so only a customised save is ever short one. It runs every
-- login, so a row that went missing by any path heals on the next reload.
function Cats:EnsureEmpty()
  if not WarpeeDB then return end
  local db = WarpeeDB.categories
  if type(db) ~= "table" or #db == 0 then return end
  for _, c in ipairs(db) do
    if type(c) == "table" and c.empty then return end
  end
  db[#db + 1] = { id = Cats.EMPTY_ID, empty = true, g = tailGroup(db) }
end

-- The catch-all is not deletable either, and for a stronger reason than Empty: items that match no
-- rule have nowhere else to go, so the row must always exist. A save from before Other was a list
-- member carries no row for it; this restores it at the tail on every login, exactly as EnsureEmpty
-- does for the free-space row. Buckets also synthesizes one as a last resort, but keeping it in the
-- list is what lets the player see and reorder it.
function Cats:EnsureOther()
  if not WarpeeDB then return end
  local db = WarpeeDB.categories
  if type(db) ~= "table" or #db == 0 then return end
  for _, c in ipairs(db) do
    if type(c) == "table" and c.other then return end
  end
  db[#db + 1] = { id = Cats.OTHER_ID, other = true, g = tailGroup(db) }
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
  -- The Empty section folds with the rest under a shift click, so its id takes the state too.
  t[Cats.EMPTY_ID] = state and true or nil
end

-- A group is a run of neighbouring rows, drawn as one band in the grouped view. The list order is
-- what decides which rule claims an item first, so a row joins a group by moving into it: the run
-- is what keeps the picture and the priority saying the same thing. Membership rides on the row as
-- `g` (a group id), the groups themselves live in WarpeeDB.catGroups, and the fold of a band rides
-- in WarpeeDB.catGroupFold like a section's fold rides in catCollapsed.
local function groupIndex(groups, gid)
  if not gid then return nil end
  for i, g in ipairs(groups) do
    if type(g) == "table" and g.id == gid then return i end
  end
end

function Cats:Groups()
  if not WarpeeDB then return {} end
  local t = WarpeeDB.catGroups
  if type(t) ~= "table" then t = seedGroups(); WarpeeDB.catGroups = t end
  return t
end

function Cats:HasGroup(gid)
  return groupIndex(self:Groups(), gid) ~= nil
end

-- gid -> position in the band order. Read on every relayout of the grouped view, and small enough
-- that building it fresh beats caching a table the save can move under.
function Cats:GroupRank()
  local rank, n = {}, 0
  for i, g in ipairs(self:Groups()) do
    if type(g) == "table" and g.id then rank[g.id] = i; n = i end
  end
  return rank, n
end

function Cats:GroupName(gid)
  local groups = self:Groups()
  local g = groups[groupIndex(groups, gid)]
  if g and g.name and g.name ~= "" then return g.name end
  local key = GROUP_NAMEKEY[gid]
  return (key and ns.L[key]) or ns.L["New group"]
end

function Cats:GroupCounts()
  local out = {}
  for _, c in ipairs(self:List()) do
    if type(c) == "table" and c.g then out[c.g] = (out[c.g] or 0) + 1 end
  end
  return out
end

function Cats:AddGroup()
  local groups = self:Groups()
  local id = newId()
  groups[#groups + 1] = { id = id }
  return id
end

function Cats:SetGroupName(gid, text)
  local groups = self:Groups()
  local g = groups[groupIndex(groups, gid)]
  if not g then return end
  g.name = (text ~= nil and text ~= "") and text or nil
end

-- Deleting a group never deletes a category: its rows move into the group before it, or the one
-- after it when it was the first, and the empty band is dropped.
function Cats:RemoveGroup(gid)
  local groups = self:Groups()
  if #groups <= 1 then return end
  local at = groupIndex(groups, gid)
  if not at then return end
  local to = groups[at - 1] or groups[at + 1]
  table.remove(groups, at)
  for _, c in ipairs(self:EnsureCustom()) do
    if type(c) == "table" and c.g == gid then c.g = to.id end
  end
  self:NormalizeGroups()
end

function Cats:MoveGroup(gid, dir)
  local groups = self:Groups()
  local at = groupIndex(groups, gid)
  local j = at and (at + dir)
  if not (j and groups[j]) then return end
  groups[at], groups[j] = groups[j], groups[at]
  self:NormalizeGroups()
end

-- Stable re-sort by band order: rows already in band order keep their places, a group that ended up
-- sitting after another one is brought back into the band order the editor shows.
function Cats:NormalizeGroups()
  local list = self:EnsureCustom()
  local rank, top = self:GroupRank()
  local wrap = top + 1
  local at = {}
  for i, c in ipairs(list) do if type(c) == "table" then at[c] = i end end
  table.sort(list, function(a, z)
    local ra = (type(a) == "table" and rank[a.g]) or wrap
    local rz = (type(z) == "table" and rank[z.g]) or wrap
    if ra ~= rz then return ra < rz end
    return (at[a] or 1e9) < (at[z] or 1e9)
  end)
end

function Cats:SetRowGroup(i, gid)
  local list = self:EnsureCustom()
  local row = list[i]
  if not (type(row) == "table" and self:HasGroup(gid)) then return end
  if row.g == gid then return end
  local rank = self:GroupRank()
  local mine = rank[gid] or 1e9
  table.remove(list, i)
  row.g = gid
  local at = #list + 1
  for k = #list, 1, -1 do
    local r = list[k]
    local g = type(r) == "table" and r.g
    if g and (rank[g] or 1e9) <= mine then at = k + 1; break end
  end
  table.insert(list, at, row)
end

-- A drag drops a row into the run it landed in, so the grip alone moves a category between groups.
function Cats:FileRow(i)
  local list = self:EnsureCustom()
  local row = list[i]
  if type(row) ~= "table" then return end
  local above, below = list[i - 1], list[i + 1]
  local g = (type(above) == "table" and above.g) or (type(below) == "table" and below.g)
  if g then row.g = g end
  self:NormalizeGroups()
end

function Cats:GroupFolded(gid)
  local t = WarpeeDB and WarpeeDB.catGroupFold
  return (type(t) == "table" and gid ~= nil and t[gid]) and true or false
end

function Cats:ToggleGroupFold(gid)
  if not (WarpeeDB and gid ~= nil) then return end
  local t = WarpeeDB.catGroupFold
  if type(t) ~= "table" then t = {}; WarpeeDB.catGroupFold = t end
  t[gid] = (not t[gid]) or nil
end

function Cats:SetAllGroupsFolded(state)
  if not WarpeeDB then return end
  local t = WarpeeDB.catGroupFold
  if type(t) ~= "table" then t = {}; WarpeeDB.catGroupFold = t end
  for _, g in ipairs(self:Groups()) do
    if g.id then t[g.id] = state and true or nil end
  end
end

local function tailGroup(list)
  for i = #list, 1, -1 do
    local c = list[i]
    if type(c) == "table" and c.g then return c.g end
  end
  local groups = Cats:Groups()
  return groups[1] and groups[1].id
end

-- Heals a save written before groups existed: a row with no group, or one naming a group that is
-- gone, takes the group the shipped row with its id sits in, else the one above it, else the first.
-- A save already carrying a group on every row is left exactly as it is.
function Cats:EnsureGroups()
  if not WarpeeDB then return end
  local groups = self:Groups()
  local known = {}
  for _, g in ipairs(groups) do
    if type(g) == "table" and g.id then known[g.id] = true end
  end
  local list = WarpeeDB.categories
  if type(list) ~= "table" or #list == 0 then return end
  local prev, heal = nil, false
  local first = groups[1] and groups[1].id
  for _, c in ipairs(list) do
    if type(c) == "table" then
      local g = c.g
      if not (type(g) == "string" and known[g]) then
        c.g = shippedGroup(c.id) or prev or first
        heal = true
      end
      prev = c.g
    end
  end
  if heal then self:NormalizeGroups() end
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
-- PINS[i] is the manual pin set of ACTIVE[i], carried 1:1 like FILTERS. A pinned item is filed by
-- id before any search runs, so a piece the player dropped on a section stays there whatever the
-- rules say. FILTERS[i] is nil for a section that has pins but no search, so it never search-matches.
-- Assigned into the forward-declared upvalues at the top of the file (not re-declared) so PinItem's
-- earlier `filterStamp = nil` and this table both bind the same locals.
FILTERS, PINS, ACTIVE, filterStamp = {}, {}, {}, nil

local function hasSearch(c) return (c.search or ""):find("%S") ~= nil end
local function hasPins(c) return type(c.pins) == "table" and next(c.pins) ~= nil end

-- A pin fingerprint for the cache stamp: the ids a section holds, in id order so the same set reads
-- the same string whatever order they were added. A pin change through the mutator also nils the
-- stamp outright, this covers the paths that swap the whole list at once (profile, import, wipe).
local function pinPrint(c)
  if not hasPins(c) then return "" end
  local ids = {}
  for id in pairs(c.pins) do ids[#ids + 1] = id end
  table.sort(ids)
  return table.concat(ids, ",")
end

-- A row classifies items when it is a real record, switched on, and carries either a search or at
-- least one pin. A blank search parses to the match-everything filter, so a row with neither would
-- silently become a second catch-all and starve Other; until given a rule or a pin it is inert.
-- The Empty row is the one exception: it owns no rule on purpose and classifies nothing, yet it is
-- active so it keeps a place among the sections. Its filter and pin set stay nil, so classify skips
-- it and no item ever lands there.
local function isActive(c)
  if type(c) ~= "table" then return false end
  -- The catch-all is never switched off: items must always have somewhere to land, so it stays active
  -- whatever its enabled flag says. Everything else obeys enable and needs a rule, a pin, or to be the
  -- free-space row.
  if c.other then return true end
  return c.enabled ~= false and (c.empty or hasSearch(c) or hasPins(c))
end

local function ensureFilters()
  local list = Cats:List()
  local parts = {}
  for i, c in ipairs(list) do
    if type(c) == "table" then
      parts[i] = (c.id or "") .. "\1" .. (c.search or "") .. "\1" .. tostring(c.enabled)
                 .. "\1" .. pinPrint(c)
    else
      parts[i] = "\1\1"
    end
  end
  local stamp = table.concat(parts, "\2")
  if stamp == filterStamp then return end
  filterStamp = stamp
  wipe(FILTERS)
  wipe(PINS)
  wipe(ACTIVE)
  for _, c in ipairs(list) do
    if isActive(c) then
      local idx = #ACTIVE + 1
      ACTIVE[idx] = c
      FILTERS[idx] = hasSearch(c) and ns.ParseSearch((c.search or ""):lower()) or nil
      PINS[idx] = hasPins(c) and c.pins or nil
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
  m.boa = nil
  m.toy = nil
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
  -- Battle pets in bags carry a battlepet: link, not an item: link, so GetItemInfoInstant returns no
  -- classID and a Battlepet kind-row never matched them (the same reason toys and keystones are read
  -- off the link, not the class). Cover the item forms too: a classID Battlepet item, or a
  -- Miscellaneous companion-pet teaching item.
  m.battlepet = (hl and hl:find("battlepet:", 1, true) ~= nil)
    or iClassID == Enum.ItemClass.Battlepet
    or (iClassID == Enum.ItemClass.Miscellaneous and Enum.ItemMiscellaneousSubclass
        and iSubID == Enum.ItemMiscellaneousSubclass.CompanionPet) or false
  -- A keystone's link is a keystone: hyperlink, not an item:, so GetItemInfoInstant hands back no id
  -- and m.id above is nil. classify keys pins by id, so a keystone could be neither filed by hand nor
  -- lifted out of its section, alone among items. The itemID is the first field of the link, so read
  -- it out here; the cursor hands PinItem the same 180653, and now the two match.
  if m.keystone and not m.id then m.id = tonumber(hl:match("keystone:(%d+)")) end
  return m
end

-- The snapshot has no live container to read, so the meta is built from the packed slot the Vault
-- kept: the hyperlink, the quality and bound flag, and for gear the item level and warbound flag
-- captured at scan time. GetItemInfoInstant, GetItemInfo, the toybox and the expansion lookup all
-- key on the link or the id, so they answer the same for a cached character as for a live one. Two
-- deliberate differences from the live builder keep classify off any live-container call: m.loc is
-- left nil so no gear ilvl is fetched from a slot that is not this character's, and m.bag is left nil
-- so a gear piece with no stored warbound flag (an old record) falls to MetaWarbound's link branch
-- rather than reading this character's bag. A fresh record carries m.wb outright.
local scratchSnap = {}
local function buildMetaSnap(bag, d)
  local hl = d.l
  local m = scratchSnap
  local iItemID, iType, iSub, iEquipLoc, iClassID, iSubID
  if hl then
    iItemID, iType, iSub, iEquipLoc, _, iClassID, iSubID = C_Item.GetItemInfoInstant(hl)
  end
  local isGear = iClassID == Enum.ItemClass.Armor or iClassID == Enum.ItemClass.Weapon
  local nm = (hl and hl:match("%[(.-)%]")) or ""
  m.name = nm
  m.text = (nm .. " " .. (iType or "") .. " " .. (iSub or "")):lower()
  m.q = d.q
  m.classID, m.subID, m.id, m.equipLoc = iClassID, iSubID, iItemID, iEquipLoc
  m.isGear = isGear
  m.bag, m.slot = nil, nil
  m.link = hl
  m.bound = d.b and true or false
  m.loc = nil
  m.ilvl = d.v
  if isGear and not m.ilvl then
    local getIL = C_Item.GetDetailedItemLevelInfo or GetDetailedItemLevelInfo
    if getIL and hl then m.ilvl = getIL(hl) end
  end
  m.wb = d.w
  m.exp = nil
  m.boa = nil
  m.toy = nil
  m.reagent = (bag == ns.reagentBag) or iClassID == Enum.ItemClass.Tradegoods
              or iClassID == Enum.ItemClass.Reagent
  m.keystone = (hl and hl:find("keystone:", 1, true) ~= nil) or false
  if m.keystone and not m.id then m.id = tonumber(hl:match("keystone:(%d+)")) end
  m.battlepet = (hl and hl:find("battlepet:", 1, true) ~= nil)
    or iClassID == Enum.ItemClass.Battlepet
    or (iClassID == Enum.ItemClass.Miscellaneous and Enum.ItemMiscellaneousSubclass
        and iSubID == Enum.ItemMiscellaneousSubclass.CompanionPet) or false
  return m
end

-- A pin beats every search, so the piece the player dropped on a section lands there even when an
-- earlier section's rule would also take it. That means two passes, not one: all pins first across
-- every section, then searches in list order. Within each pass first match wins. Looped over ACTIVE
-- because a pin-only section leaves FILTERS[i] nil and a single #FILTERS walk would miss it.
local function classify(m)
  local id = m.id
  if id then
    for i = 1, #ACTIVE do
      local pins = PINS[i]
      if pins and pins[id] then return i end
    end
  end
  for i = 1, #ACTIVE do
    local f = FILTERS[i]
    if f and ns.MatchSearch(m, f) then return i end
  end
  return nil
end

-- A meta built from an itemID alone, enough for the rule filters to classify it: no bag slot, so no
-- ilvl or bound flag, but the class/subclass/slot/name/quality the search tokens read all come from
-- the item cache. Used to answer "where would this piece land by rule" without a live cell.
local idMeta = {}
local function metaFromID(itemID)
  -- classID/subID/equipLoc come from GetItemInfoInstant, which is synchronous and answers off the
  -- static item data: GetItemInfo is async and returns nil for a cold cache, and a nil classID here
  -- would send a fresh-looted or cross-character piece to Other and defeat RuleHome (the drop-on-home
  -- unfile). Name and quality still come from GetItemInfo (only it has them); a nil name just leaves
  -- the text/quality tokens unmatched, which the class/slot rules do not need.
  local name, _, quality = C_Item.GetItemInfo(itemID)
  local iID, iType, iSub, equipLoc, _, classID, subID = C_Item.GetItemInfoInstant(itemID)
  local m = idMeta
  local nm = name or ""
  m.name = nm
  m.text = (nm .. " " .. (iType or "") .. " " .. (iSub or "")):lower()
  m.q = quality
  m.classID, m.subID, m.id, m.equipLoc = classID, subID, iID or itemID, equipLoc
  m.isGear = classID == Enum.ItemClass.Armor or classID == Enum.ItemClass.Weapon
  m.link = nil
  m.bound, m.ilvl, m.loc, m.wb, m.exp, m.boa, m.toy = false, nil, nil, nil, nil, nil, nil
  m.reagent = classID == Enum.ItemClass.Tradegoods or classID == Enum.ItemClass.Reagent
  m.keystone = false
  m.battlepet = classID == Enum.ItemClass.Battlepet
    or (classID == Enum.ItemClass.Miscellaneous and Enum.ItemMiscellaneousSubclass
        and subID == Enum.ItemMiscellaneousSubclass.CompanionPet) or false
  return m
end

-- The category id an item would land in by its rules alone, pins ignored. Dropping a piece on this
-- same section is not a pin (it is already there for free), so PinItem treats such a drop as unfile:
-- otherwise "drag it back where it belongs" left a redundant pin that lingered and blocked the next
-- move. Returns nil if no rule claims it (it would fall to Other).
function Cats:RuleHome(itemID)
  if not itemID then return nil end
  ensureFilters()
  local m = metaFromID(itemID)
  for i = 1, #ACTIVE do
    local f = FILTERS[i]
    if f and ns.MatchSearch(m, f) then return ACTIVE[i].id end
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

-- Every occupied slot into its section, sections that hold anything returned in list order. The
-- catch-all is a row like the rest now, so it draws where the player put it, not forced last. The
-- reagent bag is always bucketed here: cat-view is a full inventory grouping, the grid's
-- hide-reagents toggle does not gate it.
-- The shared bucketing core, so the bags and the bank group by the exact same rules. It is told its
-- world through opts rather than reading ns.playerBags directly: `bagList` is the containers to walk,
-- `snap`/`snapMode` pick the Vault store when a cached character is shown, `reagentBag` is the one
-- extra container the bags append (nil for the bank), and `find` is the parsed live query for the
-- per-section hit count. Returns the same {out, used, total} the bags always did.
local function bucketsCore(find, snap, snapMode, bagList, reagentBag)
  ensureFilters()
  local order = {}
  for i = 1, #ACTIVE do
    order[i] = { id = ACTIVE[i].id, name = catName(ACTIVE[i]), slots = {}, hits = 0,
                 g = ACTIVE[i].g, empty = ACTIVE[i].empty, other = ACTIVE[i].other }
  end
  -- The catch-all is a row now, so it sits in order at the place the player set rather than pinned
  -- last. classify still returns nil for an item no rule claimed, and that nil files into this bucket.
  -- If a hand-edited save somehow lost the row, one is synthesized at the tail so no item is dropped.
  local otherBucket
  for i = 1, #order do if order[i].other then otherBucket = order[i]; break end end
  if not otherBucket then
    otherBucket = { id = Cats.OTHER_ID, name = ns.L["Other"], slots = {}, hits = 0, other = true,
                    g = ACTIVE[#ACTIVE] and ACTIVE[#ACTIVE].g }
    order[#order + 1] = otherBucket
  end
  local used, total = 0, 0
  -- One buckets pass files a slot from its meta whatever built it: a live container reads it straight,
  -- a snapshot rebuilds the same meta from the record the Vault kept. The sort keys ride on the slot
  -- entry, read off the scratch meta now, since the meta is reused on the next slot and would be gone
  -- by the time the bucket is sorted.
  local function file(bag, slot, m)
    local idx = classify(m)
    local dest = (idx and order[idx]) or otherBucket
    dest.slots[#dest.slots + 1] = {
      bag = bag, slot = slot, q = m.q or -1, ilvl = m.ilvl or 0, name = m.name or "",
    }
    if find and ns.MatchSearch(m, find) then dest.hits = dest.hits + 1 end
  end
  -- A snapshot has no live container, so its slots and their contents come from the Vault instead:
  -- the same bag ids the grid walks, each packed slot turned back into a classify meta. used and total
  -- are taken from the Vault's own tallies, not counted here, so the Empty section's free-space count
  -- matches the grid's for a cached character exactly. snapMode names the Vault store ("bags", "bank",
  -- "warband"), so the bank groups its own snapshot rather than the bags'.
  local function tally(bag)
    if snap then
      local num = ns.Vault:Count(snapMode, bag) or 0
      total = total + num
      used = used + (ns.Vault:Used(snapMode, bag) or 0)
      for slot = 1, num do
        local d = ns.Vault:Slot(snapMode, bag, slot)
        if d and d.l then file(bag, slot, buildMetaSnap(bag, d)) end
      end
    else
      local num = C_Container.GetContainerNumSlots(bag) or 0
      total = total + num
      for slot = 1, num do
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info and (info.hyperlink or info.itemID) then
          used = used + 1
          file(bag, slot, buildMeta(bag, slot, info))
        end
      end
    end
  end
  for _, bag in ipairs(bagList) do tally(bag) end
  if reagentBag then tally(reagentBag) end
  local out = {}
  for i = 1, #order do
    -- Empty is kept on its list position whether or not it holds anything: it is the free-space
    -- stand-in and owns no slots by design. Other and every real category show only when they hold
    -- something, so an empty catch-all does not clutter the view, but when Other does hold items it
    -- now draws at its own list position rather than pinned last.
    if order[i].empty or #order[i].slots > 0 then out[#out + 1] = order[i] end
  end
  local cmp = sorter()
  for _, b in ipairs(out) do table.sort(b.slots, cmp) end
  return out, used, total
end

-- Every occupied bag slot into its section, sections that hold anything returned in list order. The
-- window hands its live query so the per-section hit count drives which fold open during a search;
-- the reagent bag is always included, since cat-view is a full-inventory grouping.
function Cats:Buckets(bags)
  local q = bags and bags.query or ""
  local find = (q ~= "") and bags.filters or nil
  return bucketsCore(find, bags and bags.snap, "bags", ns.playerBags, ns.reagentBag)
end

-- The bank's grouping: the same rules over the bank or warband containers instead of the bags. mode
-- is "bank" or "warband" (the Vault store and the container set both key on it), snap picks the
-- cached-character store, and find is the parsed live query. No reagent bag is appended: the bank has
-- none. The container id list is handed in by the caller, which owns the BANK_MAIN / WARBAND tables.
function Cats:BankBuckets(mode, snap, find, bagList)
  return bucketsCore(find, snap, mode, bagList or {}, nil)
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
  local filters, pins, out = {}, {}, {}
  for i, c in ipairs(list) do
    if isActive(c) then
      -- A filter only for a row that actually carries a search: a blank search parses to match
      -- everything, so a pin-only row would otherwise swallow the whole bag instead of only its pins.
      if hasSearch(c) then filters[i] = ns.ParseSearch((c.search or ""):lower()) end
      if hasPins(c) then pins[i] = c.pins end
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
        local id = m.id
        local hit = false
        -- Pins win over any search, so tally them in a first pass, exactly like classify.
        if id then
          for i = 1, #list do
            if pins[i] and pins[i][id] then out[i] = out[i] + 1; hit = true; break end
          end
        end
        if not hit then
          for i = 1, #list do
            if filters[i] and ns.MatchSearch(m, filters[i]) then out[i] = out[i] + 1; hit = true; break end
          end
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
