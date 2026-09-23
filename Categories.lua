local addonName, ns = ...

local Cats = {}
ns.Categories = Cats

-- Forward-declared here, above Cats:PinItem, so its `filterStamp = nil` (the cache invalidation on a
-- pin change) writes this upvalue and not a stray global. The classify cache below (FILTERS/PINS/
-- ACTIVE) is assigned into these same names once they are in scope; without this line PinItem sat
-- textually before the local and its assignment silently missed the cache.
local FILTERS, PINS, ACTIVE, filterStamp

-- The Empty section's own id. It owns no items, so it never collides with a real category id
-- (shipped ids are words, custom ids start with "u").
Cats.EMPTY_ID = "empty"
-- The catch-all's id. Like EMPTY_ID it is no real category, only the tag the bag reads to know a drop
-- here should do nothing: Empty is the one unfile target now, Other is inert.
Cats.OTHER_ID = "other"

-- What a list entry is. A category is a real record (id, search, pins); a marker only shapes the view
-- around it — a group header ({ head = gid }, plus an optional name the player typed and its fold) or a
-- divider ({ div = true }). A run of categories follows each marker and that run is one band, so a group
-- and a divider can sit anywhere and a list can hold any number of either. A row written before markers
-- existed carries neither field and so reads as a category, which is what lets an old save load unrewritten.
local function isHead(e) return type(e) == "table" and type(e.head) == "string" end
local function isDiv(e) return type(e) == "table" and e.div == true end
local function isMarker(e) return isHead(e) or isDiv(e) end
local function isCat(e) return type(e) == "table" and not isMarker(e) end
Cats.IsCat, Cats.IsMarker, Cats.IsHead = isCat, isMarker, isHead

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
-- "!junk" from a gear row and its greys stay in it.
-- Those four gear rows also carry an item-level floor, `ilvl>180`. It is strictly above, so a piece at
-- exactly 180 is out, and a piece whose level cannot be read yet — a bank snapshot row with no level, an
-- item the client has not cached — does not match the floor at all and falls past it. The floor narrows
-- what the band keeps rather than holding a row back from the bag: levelling gear, an heirloom and a
-- current-expansion green all drop out of the type rows, an old-expansion piece lands on the Legacy row
-- below, and anything the rows under it do not claim ends up in Other as always.
-- Markers shape the view, the category rows between them are the rules. A head opens a named band, a
-- div opens a headingless one, and the rows before the first marker are a band of their own with no
-- heading at all. So the three shipped groups are groups only because the list says so, and the tail is
-- a divider band rather than a group with a false gid. "consumables !legacy"
-- ORs with the two item ids so a couple of specific pieces (a codex, a tome) join the block; the
-- specific consumable rows above it (flasks/food/potions) claim their own subclasses first. "misc"
-- is the Miscellaneous item class, not the text word: collectibles sits above it so mounts, pets and
-- toys are pulled out before the class catch-all. Every token here is one classify() understands.
local DEFAULTS = {
  { head = "essentials" },
  { id = "hearthstone",   search = "id6948" },
  { id = "keystone",      search = "keystone" },
  { id = "flasks",        search = "flask" },
  { id = "food",          search = "food" },
  { id = "potions",       search = "potion" },
  { id = "consumables",   search = "consumables !legacy !junk | id132514 id109076" },
  { id = "gem",           search = "gem" },
  { id = "enhancement",   search = "enhancement" },
  { id = "quest",         search = "quest" },
  { head = "gear" },
  { id = "weapons",       search = "weapon shield held !junk ilvl>180" },
  { id = "jewelry",       search = "ring neck !junk ilvl>180" },
  { id = "armor",         search = "cloth leather mail plate !junk ilvl>180" },
  { id = "trinkets",      search = "trinket !junk ilvl>180" },
  { head = "crafting" },
  { id = "reagents",      search = "reagent !legacy !junk" },
  { id = "profgear",      search = "profgear tool" },
  { id = "recipe",        search = "recipe" },
  { id = "bag",           search = "container" },
  { id = "housing",       search = "housing" },
  { head = "hoard" },
  { id = "wardrobe",      search = "cosmetic | glyph | tabard shirt" },
  { id = "collectibles",  search = "toy | mount | battlepet" },
  -- Legacy gathers gear from every past expansion, so it ships pre-set to draw by expansion (newest
  -- first): the one shipped section where that order reads better than quality. The player can change it
  -- from the row's + panel like any other, and every other section still follows the global sort.
  { id = "legacy",        search = "legacy", sort = "expac" },
  { id = "miscellaneous", search = "misc !junk" },
  -- The catch-all: every item no rule claimed lands here. Never switched off or deleted, since items
  -- must always have somewhere to land. Its list position sets where it draws, not what it claims.
  { id = "other",         other = true },
  { id = "junk",          search = "junk" },
  -- Free space, not a rule: owns no search, matches nothing. The grouped view's stand-in for the
  -- grid's trailing blank cells; kept last, movable from the editor.
  { id = "empty",         empty = true },
}

local GROUP_NAMEKEY = {
  essentials   = "Essentials",
  gear         = "Gear",
  crafting     = "Crafting",
  hoard        = "Hoard",
}

local NAMEKEY = {
  hearthstone   = "Hearthstone",
  keystone      = "Keystones",
  flasks        = "Flasks",
  food          = "Food",
  potions       = "Potions",
  consumables   = "Consumables",
  gem           = "Gems",
  enhancement   = "Enhancements",
  quest         = "Quest Items",
  weapons       = "Weapons",
  jewelry       = "Jewelry",
  armor         = "Armor",
  trinkets      = "Trinkets",
  recipe        = "Recipes",
  profgear      = "Profession Gear",
  reagents      = "Reagents",
  bag           = "Bags",
  wardrobe      = "Wardrobe",
  collectibles  = "Collectibles",
  housing       = "Housing",
  legacy        = "Legacy",
  miscellaneous = "Miscellaneous",
  junk          = "Junk",
  empty         = "Slots",
  other         = "Other",
}

-- Read only. The shipped DEFAULTS are a shared constant, so a caller that means to change the
-- list must go through EnsureCustom first, never mutate what this returns.
function Cats:List()
  local db = WarpeeDB and WarpeeDB.categories
  if type(db) == "table" and #db > 0 then return db end
  return DEFAULTS
end

-- One fresh independent entry, so the save never shares a table with the constant and editing one
-- profile cannot bleed into another or into the defaults. A marker copies its name and fold, since
-- those are the player's; pins are not copied, because a reset hands back the rules, not the manual
-- homes.
local function seedEntry(c)
  if isHead(c) then return { head = c.head, name = c.name, folded = c.folded } end
  if isDiv(c) then return { div = true, folded = c.folded } end
  return { id = c.id, search = c.search, name = c.name, enabled = c.enabled,
           empty = c.empty, other = c.other, sort = c.sort }
end

local function seed()
  local db = {}
  for i, c in ipairs(DEFAULTS) do db[i] = seedEntry(c) end
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
  -- A new custom row goes above the structural tail (Empty, Other), never after it: those two are
  -- the floor of the list and a rule added below Other would never be reached. Same insover point
  -- the presets use, so hand-add and preset-add drop a row in the same place.
  local at = self:InsertAt(list)
  table.insert(list, at, { id = newId(), search = "" })
  -- The index comes back so the editor can put the eye on the row it just made.
  return at
end

-- The shipped named categories, offered in the editor as one-click "add this whole category" presets.
-- This is the DEFAULTS list minus the markers and the two structural rows (Empty, Other are always
-- present and are not things you add), in the same order, so the preset strip reads like the default
-- layout. id keys into NAMEKEY for the caption and is what a duplicate check compares, search is
-- copied verbatim.
local PRESET_IDS = {
  "hearthstone", "keystone", "flasks", "food", "potions", "consumables", "gem",
  "enhancement", "quest", "weapons", "jewelry", "armor", "trinkets", "recipe",
  "profgear", "reagents", "bag", "wardrobe", "collectibles", "housing", "legacy",
  "miscellaneous", "junk",
}
local PRESET_SEARCH = {}
local PRESET_SORT = {}
-- The shipped band each preset sits in, taken off the same walk: the shelf a ready-made category stands on
-- in the editor's strip is the band it ships under, so the strip and the default list cannot disagree
-- about where a category belongs. A marker opens the band that follows it.
local PRESET_BAND = {}
local band = nil
for _, c in ipairs(DEFAULTS) do
  -- The guard on c.id is what skips the markers. Without it a head or a div row indexes this table
  -- with nil and the client refuses to load the file at all ("table index is nil"), taking every
  -- method in it down with it — which is how a nil Categories:Migrate in Core's login block happens.
  if c.head then
    band = c.head
  elseif c.id and not (c.empty or c.other) then
    PRESET_SEARCH[c.id] = c.search
    PRESET_SORT[c.id] = c.sort
    PRESET_BAND[c.id] = band
  end
end

-- The presets, each { id, name, search, band, bandKey }, name and band label resolved live so neither
-- freezes a language. bandKey is the locale key of the band, for a caller that shows the band's name.
function Cats:Presets()
  local out = {}
  for _, id in ipairs(PRESET_IDS) do
    local gid = PRESET_BAND[id]
    out[#out + 1] = { id = id, name = (NAMEKEY[id] and ns.L[NAMEKEY[id]]) or id,
                      search = PRESET_SEARCH[id] or "",
                      band = gid, bandKey = (gid and GROUP_NAMEKEY[gid]) or "New group" }
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

-- The index a new category is inserted at: the tail of the list, but never after the free-space row,
-- which is the last thing in a list by design. It used to be "before whichever of Empty and Other
-- comes first", and in a save where one of those had drifted up the list that put a brand-new row
-- near the top: the list shifted under the player and the row turned up far from the button that made
-- it. Reading the tail this way lands on the same spot in a shipped list and a sane one in any other,
-- so an added row always appears at the bottom, right above the buttons that made it.
function Cats:InsertAt(list)
  list = list or self:List()
  local last = list[#list]
  if #list > 0 and type(last) == "table" and last.empty then return #list end
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
  table.insert(list, at, { id = id, search = search, sort = PRESET_SORT[id] })
  return at
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

function Cats:SetName(i, text)
  local list = self:EnsureCustom()
  if list[i] then list[i].name = text ~= "" and text or nil end
end

function Cats:SetSearch(i, text)
  local list = self:EnsureCustom()
  if list[i] then list[i].search = text or "" end
end

-- The per-category sort override, set from the pin panel. Keyed by category id, not list index: the
-- panel knows the row by its id and a drag can slide indices under an open dropdown. nil (or the
-- sentinel "default") clears it, so the section falls back to the global WarpeeDB.catSort; any other
-- mode pins that order on this section alone. Only the draw order is stored — no rule, no pin, nothing
-- secure — so a change is a plain relayout. The stamp is untouched: sort is read straight off the entry
-- in bucketsCore and never folded into the FILTERS cache.
function Cats:SetSortById(id, mode)
  if not id then return end
  local list = self:EnsureCustom()
  for _, c in ipairs(list) do
    if type(c) == "table" and c.id == id then
      c.sort = (mode and mode ~= "default") and mode or nil
      return
    end
  end
end

-- The stored sort of the category with this id, or "default" when it inherits the global order. Read
-- side for the editor's per-category selector.
function Cats:SortOf(id)
  if not id then return "default" end
  for _, c in ipairs(self:List()) do
    if type(c) == "table" and c.id == id then return c.sort or "default" end
  end
  return "default"
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
    WarpeeDB.catGroups = nil
    WarpeeDB.catGroupFold = nil
    -- Swapping the whole list out from under the classify cache: nil the stamp so the next pass
    -- rebuilds ACTIVE from the fresh save instead of comparing content and possibly matching a stale
    -- one. This is the "wipe" path the stamp comment promises nils the cache.
    filterStamp = nil
  end
end

-- The draw-order keys a section may carry, mirrored from the editor's own dropdown: a code written by
-- a version that knows more of them reads back only what this one can draw.
local SORT_KEYS = { quality = true, ilvl = true, name = true, match = true, expac = true }

-- What one shared code may carry. Generous enough for any list a player builds by hand, hard enough
-- that a hand-written code cannot turn into a denial of service on the client that reads it.
local SHARE_MAX, SHARE_PINS_MAX, SHARE_TEXT_MAX = 400, 200, 400

-- One list entry as a code carries it: a head keeps its name, a divider is only itself, a category
-- keeps its rule, its caption, whether it is on, its manual homes and its own draw order. Fold state
-- does not travel — a folded band is how the sender's view stood, not part of the list, and a code
-- that carried it would hand over the sender's clutter — and neither does any field a later version
-- may add, since one this build does not know is not read back.
-- The same function cleans an incoming entry, so a code from outside is cut to this shape before it is
-- ever stored: a number where a table belongs, a rule several pages long, and a run of pins with no
-- end all stop here rather than in the classify pass.
local function shareEntry(e)
  if type(e) ~= "table" then return nil end
  if isHead(e) then
    local name = (type(e.name) == "string" and e.name ~= "") and e.name:sub(1, 40) or nil
    return { head = e.head:sub(1, 40), name = name }
  end
  if isDiv(e) then return { div = true } end
  if type(e.id) ~= "string" or e.id == "" then return nil end
  local out = { id = e.id:sub(1, 60) }
  if type(e.search) == "string" then out.search = e.search:sub(1, SHARE_TEXT_MAX) end
  if type(e.name) == "string" and e.name ~= "" then out.name = e.name:sub(1, 40) end
  if e.enabled == false then out.enabled = false end
  if e.empty == true then out.empty = true end
  if e.other == true then out.other = true end
  if type(e.sort) == "string" and SORT_KEYS[e.sort] then out.sort = e.sort end
  if type(e.pins) == "table" then
    local pins, n = nil, 0
    for k in pairs(e.pins) do
      if type(k) == "number" then
        if n >= SHARE_PINS_MAX then break end
        pins = pins or {}
        pins[k] = true
        n = n + 1
      end
    end
    if pins then out.pins = pins end
  end
  return out
end

-- The list as a code carries it: always fresh tables, so the packer never holds a reference into the
-- save and the save can never be edited through a code. Read only.
function Cats:ShareList()
  local out = {}
  for _, e in ipairs(self:List()) do
    if #out >= SHARE_MAX then break end
    local s = shareEntry(e)
    if s then out[#out + 1] = s end
  end
  return out
end

-- Take a code's list. "replace" puts it in place of the whole one; "merge" — the default, and what a
-- caller that cannot ask should use — appends the sections the player does not have yet in the order
-- they were written, and leaves every row already here exactly where it is, index and pin alike.
-- Either way a marker is written only once something stands under it, so a code whose last band is
-- empty, or a merge that dropped a duplicate, cannot land a header over nothing; one id is taken once
-- however many times a code names it.
-- The structural rows are repaired, not trusted: Empty and Other are the floor of every list, so they
-- exist after any code and exist once, carrying the one id the bag reads to recognise them. A code
-- that used those ids for ordinary rules has those rules dropped rather than the floor broken.
-- Returns the number of category rows written, or nil and the reason it refused.
function Cats:TakeList(list, mode, catSort)
  if not WarpeeDB then return nil, "Not ready" end
  if type(list) ~= "table" then return nil, "Nothing to import" end
  local replace = (mode == "replace")
  local here = {}
  if not replace then
    for _, e in ipairs(self:List()) do
      if isCat(e) and type(e.id) == "string" then here[e.id] = true end
    end
  end
  local clean, taken, structural = {}, {}, {}
  for _, e in ipairs(list) do
    local c = shareEntry(e)
    if c then
      -- A marker carries no id, so it never dedupes: it passes straight through, and the pending/kept
      -- pass below drops any that end up heading nothing. Only categories are keyed by id — reaching the
      -- else with a marker wrote taken[nil] and crashed the import ("table index is nil").
      if isMarker(c) then
        -- nothing to dedupe; fall through to the append
      elseif c.empty or c.other then
        local key = c.empty and "empty" or "other"
        if structural[key] then
          c = nil
        else
          structural[key] = true
          c = { id = (key == "empty") and self.EMPTY_ID or self.OTHER_ID }
          c[key] = true
        end
      elseif taken[c.id] or here[c.id]
          or c.id == self.EMPTY_ID or c.id == self.OTHER_ID then
        c = nil
      else
        taken[c.id] = true
      end
      if c then
        clean[#clean + 1] = c
        if #clean >= SHARE_MAX then break end
      end
    end
  end
  -- A marker is held back until a category follows it, and a second marker in the same run replaces
  -- the one before it: the first headed nothing, and a header standing over an empty run is exactly
  -- what the editor's own drag rules out.
  local kept, pending, count = {}, nil, 0
  for _, c in ipairs(clean) do
    if isMarker(c) then
      pending = c
    else
      if pending then kept[#kept + 1] = pending; pending = nil end
      kept[#kept + 1] = c
      count = count + 1
    end
  end
  if count == 0 then return nil, "Nothing to import" end
  if replace then
    WarpeeDB.categories = kept
  else
    local target = self:EnsureCustom()
    local at = self:InsertAt(target)
    for _, c in ipairs(kept) do
      table.insert(target, at, c)
      at = at + 1
    end
  end
  if type(catSort) == "string" and SORT_KEYS[catSort] then WarpeeDB.catSort = catSort end
  self:EnsureEmpty()
  self:EnsureOther()
  -- The list was swapped out from under the classify cache, so the stamp goes: the next pass rebuilds
  -- ACTIVE from the new save instead of comparing content and possibly matching a stale one.
  filterStamp = nil
  return count
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
  db[#db + 1] = { id = Cats.EMPTY_ID, empty = true }
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
  db[#db + 1] = { id = Cats.OTHER_ID, other = true }
end


-- The index of a list entry by identity. The renderers hold entries rather than ids — a band carries
-- the marker that heads it — so this is how a click on a heading reaches the row it names.
function Cats:IndexOf(entry)
  for i, e in ipairs(self:List()) do if e == entry then return i end end
end

-- Resolve a caller's entry against the save. The shipped list is a shared constant and must never be
-- mutated, so the index is read off whatever List() returns now, the save is materialised through
-- EnsureCustom (which copies the constant index for index), and the same index is handed back in it.
function Cats:Resolve(entry)
  local idx = self:IndexOf(entry)
  if not idx then return nil end
  local list = self:EnsureCustom()
  return list, idx
end

-- Folding belongs to a group header: it names a run of rows and can close over it. A divider seams a
-- band off without naming it, so it has nothing to close, and the flag is never set on one. A divider
-- that carries one anyway — a save written back when dividers folded — reads as open, so its band draws
-- whole instead of vanishing behind a control no longer on screen; the stale flag is inert until the
-- next Shift-click on a heading sweeps the list.
function Cats:Folded(entry)
  return isHead(entry) and entry.folded == true
end

function Cats:ToggleFold(entry)
  local list, idx = self:Resolve(entry)
  if not list then return end
  local e = list[idx]
  if isHead(e) then e.folded = (not e.folded) or nil end
end

function Cats:SetAllFolded(state)
  if not WarpeeDB then return end
  for _, e in ipairs(self:EnsureCustom()) do
    if isHead(e) then e.folded = state and true or nil
    elseif isDiv(e) then e.folded = nil end
  end
end

-- The caption of a group header: the player's own name if they typed one, else the shipped label for a
-- shipped gid, else the generic. Resolved live rather than stored, so a language change reaches it.
function Cats:GroupName(entry)
  if isHead(entry) and entry.name and entry.name ~= "" then return entry.name end
  return self:BandLabel(isHead(entry) and entry.head)
end

-- The shipped label of a band, by its gid. Shared by a group header's placeholder and the editor's preset
-- shelves, so the word on a shelf is the word a header takes once its category is added, and neither has a
-- second table of band names to drift from the other.
function Cats:BandLabel(gid)
  local key = gid and GROUP_NAMEKEY[gid]
  return (key and ns.L[key]) or ns.L["New group"]
end

-- A new group or divider lands where a new category lands: at the tail of the rule region, just above
-- the structural floor, right next to the buttons that made it. Not at the very end of the list — the
-- floor is last on purpose, so a marker appended after it opens a band nothing ever draws: the row is
-- there, no section follows it, and the button reads as having done nothing. Not at the head either,
-- since a marker there would take over whatever run happened to open the list, silently re-labelling a
-- band nobody asked it to touch. Both return their index, like the category mutators, so the editor can
-- reveal the row.
function Cats:AddGroup()
  local list = self:EnsureCustom()
  local at = self:InsertAt(list)
  table.insert(list, at, { head = newId() })
  return at
end

function Cats:AddDivider()
  local list = self:EnsureCustom()
  local at = self:InsertAt(list)
  table.insert(list, at, { div = true })
  return at
end

function Cats:SetGroupName(entry, text)
  local list, idx = self:Resolve(entry)
  if not list then return end
  local e = list[idx]
  if isHead(e) then e.name = (text ~= nil and text ~= "") and text or nil end
end

-- Remove a marker and leave its categories where they are: they join the band above (or become the
-- headingless run at the top), which is what "delete this group" means when the rules stay put.
function Cats:RemoveMarker(entry)
  local list, idx = self:Resolve(entry)
  if list then table.remove(list, idx) end
end

-- Move a contiguous block so it sits at index `dest`, every index read before the move.
local function moveBlock(list, from, to, dest)
  local n = to - from + 1
  local block = {}
  for k = 1, n do block[k] = list[from + k - 1] end
  for _ = 1, n do table.remove(list, from) end
  local at = dest
  if dest > to then at = dest - n end
  for k = n, 1, -1 do table.insert(list, at, block[k]) end
end

-- Trade a whole band with the neighbouring one: the marker and the run it heads move together, so the
-- rows inside keep their order and the rules keep their priority. Only the bands swap places.
function Cats:MoveGroup(entry, dir)
  local list, idx = self:Resolve(entry)
  if not (list and isMarker(list[idx])) then return end
  local last = idx
  while isCat(list[last + 1]) do last = last + 1 end
  if dir < 0 then
    if idx <= 1 then return end
    local a = idx - 1
    while a > 1 and isCat(list[a - 1]) do a = a - 1 end
    moveBlock(list, idx, last, a)
  else
    local n = last + 1
    if not list[n] then return end
    local z = n
    while isCat(list[z + 1]) do z = z + 1 end
    moveBlock(list, idx, last, z + 1)
  end
end

-- A drop in the editor: lift the entry at `from` and put it back before the entry now at `to`, nil for
-- the end of the list. A plain list move is the whole of it, because the list is the structure: a
-- category that passes another takes its priority, a marker that passes anything only reshapes which
-- run is a band. Nothing needs to be kept in step afterwards, which is what the old band arithmetic
-- and its heal pass were for.
function Cats:Reorder(from, to)
  local list = self:EnsureCustom()
  local row = list[from]
  if type(row) ~= "table" then return end
  table.remove(list, from)
  local at = to or (#list + 1)
  if from < at then at = at - 1 end
  if at < 1 then at = 1 elseif at > #list + 1 then at = #list + 1 end
  table.insert(list, at, row)
end

-- The ungrouped band's fold key in the old two-table model was `false`, a legal Lua table key but not
-- one SavedVariables writes cleanly, so it was stored under this sentinel. It survives only as what
-- the one-time migration below reads.
local UNGROUP_FOLD = "\1ungrouped"

-- The four shipped gear rows gained an item-level floor after a save may already exist, so a save written
-- before it holds their searches without one. Only a row still holding the shipped string exactly is
-- touched: a rule the player has typed over is left as it is, and a row that has already been upgraded no
-- longer matches the old string, so the pass is safe to run again. The flag keeps it to the one time, so a
-- row deliberately put back to the old string stays put.
local FLOOR_FROM = {
  weapons  = "weapon shield !junk",
  jewelry  = "ring neck !junk",
  armor    = "cloth leather mail plate !junk",
  trinkets = "trinket !junk",
}
function Cats:UpgradeFloor()
  if not WarpeeDB or WarpeeDB.catIlvl180 then return end
  WarpeeDB.catIlvl180 = true
  -- Read the save, never the shipped table: with no save of its own the list below is DEFAULTS itself and
  -- carries the floor already.
  local db = WarpeeDB.categories
  if type(db) ~= "table" then return end
  for _, c in ipairs(db) do
    if isCat(c) and type(c.id) == "string" and c.search == FLOOR_FROM[c.id] then
      c.search = PRESET_SEARCH[c.id] or c.search
    end
  end
  filterStamp = nil
end

-- The save used to be two structures: a plain category list carrying a .g on every row, plus a separate
-- catGroups table it had to be kept in step with. This rebuilds that pair into the flat list once — a
-- group header wherever a run of rows changes group, a divider where that run is the ungrouped one, the
-- old fold states carried onto the markers — and drops the old tables. A save already in the flat shape
-- has no catGroups and no .g, so this is a no-op for it.
function Cats:Migrate()
  if not WarpeeDB then return end
  local db = WarpeeDB.categories
  -- Only a .g on a row makes a save the old shape. The mere presence of catGroups is not enough: the
  -- key lived in DEFAULTS, so a save can carry an empty or shipped one with no row to migrate, and
  -- converting on that would put every category into one headingless band.
  local legacy = false
  if type(db) == "table" then
    for _, c in ipairs(db) do
      if type(c) == "table" and c.g ~= nil then legacy = true; break end
    end
  end
  if not legacy then
    WarpeeDB.catGroups, WarpeeDB.catGroupFold = nil, nil
    return
  end
  local known, names = {}, {}
  local groups = WarpeeDB.catGroups
  if type(groups) == "table" then
    for _, g in ipairs(groups) do
      if type(g) == "table" and g.id then known[g.id] = true; names[g.id] = g.name end
    end
  end
  local fold = WarpeeDB.catGroupFold
  local oldFold = type(fold) == "table" and fold or nil
  local out, prev = {}, nil
  for _, c in ipairs(db) do
    if type(c) == "table" then
      local gid = c.g
      -- A gid no group answers to (a deleted group, an imported save) reads as ungrouped rather than as
      -- a header whose name nothing can resolve.
      if gid == nil or gid == false or not known[gid] then gid = false end
      if gid ~= prev then
        if gid == false then
          out[#out + 1] = { div = true, folded = oldFold and oldFold[UNGROUP_FOLD] or nil }
        else
          local name = names[gid]
          out[#out + 1] = { head = gid, name = (name and name ~= "") and name or nil,
                            folded = oldFold and oldFold[gid] or nil }
        end
        prev = gid
      end
      c.g = nil
      out[#out + 1] = c
    end
  end
  WarpeeDB.categories = out
  WarpeeDB.catGroups, WarpeeDB.catGroupFold = nil, nil
  filterStamp = nil
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
      -- The stamp is the run of rows in list order with what each one matches, which is the whole of
      -- what a reclassify depends on. A marker lands in it as an empty part, so moving one rebuilds the
      -- cache too; that is only a wasted pass, since the bands themselves are read off the list at draw
      -- time and never cached, so a marker move shows up in the view whether or not the stamp moved.
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
  -- Cosmetic from the game's own flag, not the armor subclass: Blizzard tags many cosmetic appearances
  -- outside the Cosmetic subclass, so a subclass test caught almost nothing. See ItemButton.lua. Nil-safe.
  m.cosmetic = (hl and C_Item and C_Item.IsCosmeticItem and C_Item.IsCosmeticItem(hl)) and true or false
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
  m.cosmetic = (hl and C_Item and C_Item.IsCosmeticItem and C_Item.IsCosmeticItem(hl)) and true or false
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
  -- Every Mythic keystone is item 180653, so an id-only meta can flag it without a link (buildMeta
  -- reads the keystone: hyperlink instead). Left false here, RuleHome could not see a dropped keystone
  -- land in the keystone category, so PinItem pinned it there instead of reading the drop as unfile.
  m.keystone = (itemID == 180653) or false
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
-- "By rule": the section's search is an OR of branches (toy | mount | battlepet), and a piece draws by
-- which branch first claimed it, so the view reads in the order the rule is written — all the toys, then
-- the mounts, then the pets. rank rides on the slot, set at file() time off the live meta (the branch
-- index, or one past the last for a hand-pinned piece no branch matches, so those sit below the ruled
-- bands). A search with no top-level "|" gives every piece rank 0, so this falls straight through to
-- quality, and two pieces on one branch keep quality order within it.
local function byRank(a, z)
  local ar, zr = a.rank or 0, z.rank or 0
  if ar ~= zr then return ar < zr end
  return byQuality(a, z)
end
-- "By expansion": the piece's expansion, newest first, so a Legacy section that gathers gear from every
-- past expansion reads in bands rather than scattered. exp rides on the slot, set at file() time; an
-- item the client has not cached the expansion for sorts last, and within one expansion the order is
-- name. Offered both globally, on the Categories page, and per category from a row's + panel, though
-- only a mixed-expansion section (Legacy) reads better for it.
local function byExp(a, z)
  local ae, ze = a.exp or -1, z.exp or -1
  if ae ~= ze then return ae > ze end
  return byName(a, z)
end
local SORTS = { quality = byQuality, ilvl = byIlvl, name = byName, match = byRank, expac = byExp }
local function sorter(mode)
  return SORTS[mode] or byQuality
end

-- The branch a piece matched, for the "by rule" sort. Only an OR search has branches to rank by, so a
-- flat filter (or a pin-only section, FILTERS[idx] nil) ranks every piece 0 and the sort falls through
-- to quality. A pinned piece that no branch matches ranks after them all. idx is the classify result,
-- so FILTERS[idx] is exactly the destination section's parsed search, read while the meta is still live.
local function branchRank(idx, m)
  local f = idx and FILTERS[idx]
  if not (f and f.ors) then return 0 end
  for i = 1, #f.ors do
    if ns.MatchSearch(m, f.ors[i]) then return i end
  end
  return #f.ors + 1
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
  -- Band membership, read fresh off the list on every pass so a marker the player just moved shows up
  -- at once: each category maps to the marker it sits under, as the entry itself (nil for the run before
  -- the first marker, which draws with no heading). The bucket carries it through to the layout.
  local bandOf = {}
  do
    local cur
    for _, e in ipairs(Cats:List()) do
      if isMarker(e) then cur = e
      elseif e.id then bandOf[e.id] = cur end
    end
  end
  -- Each bucket carries its effective sort: the category's own override if it set one, else the global
  -- WarpeeDB.catSort. Resolved here so file() can compute only the sort key its bucket needs (a rank for
  -- "by rule", an expansion for "by expansion") rather than every key for every item on every pass.
  local globalMode = (WarpeeDB and WarpeeDB.catSort) or "ilvl"
  local order = {}
  for i = 1, #ACTIVE do
    order[i] = { id = ACTIVE[i].id, name = catName(ACTIVE[i]), slots = {}, hits = 0,
                 band = bandOf[ACTIVE[i].id], empty = ACTIVE[i].empty, other = ACTIVE[i].other,
                 mode = ACTIVE[i].sort or globalMode }
  end
  -- The catch-all is a row now, so it sits in order at the place the player set rather than pinned
  -- last. classify still returns nil for an item no rule claimed, and that nil files into this bucket.
  -- If a hand-edited save somehow lost the row, one is synthesized at the tail so no item is dropped.
  local otherBucket
  for i = 1, #order do if order[i].other then otherBucket = order[i]; break end end
  if not otherBucket then
    otherBucket = { id = Cats.OTHER_ID, name = ns.L["Other"], slots = {}, hits = 0, other = true,
                    band = bandOf[Cats.OTHER_ID], mode = globalMode }
    order[#order + 1] = otherBucket
  end
  local used, total = 0, 0
  -- One buckets pass files a slot from its meta whatever built it: a live container reads it straight,
  -- a snapshot rebuilds the same meta from the record the Vault kept. The sort keys ride on the slot
  -- entry, read off the scratch meta now, since the meta is reused on the next slot and would be gone
  -- by the time the bucket is sorted. rank and exp are only read when the destination's own sort asks
  -- for them, so a plain quality view never pays for a branch match or an expansion lookup.
  local function file(bag, slot, m)
    local idx = classify(m)
    local dest = (idx and order[idx]) or otherBucket
    local entry = {
      bag = bag, slot = slot, q = m.q or -1, ilvl = m.ilvl or 0, name = m.name or "",
    }
    local mode = dest.mode
    if mode == "match" then
      entry.rank = branchRank(idx, m)
    elseif mode == "expac" then
      entry.exp = ns.MetaExp(m)
    end
    dest.slots[#dest.slots + 1] = entry
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
  -- Each bucket sorts by its own resolved mode: a category's override, or the global fall-through.
  -- The comparator only reads keys file() filled for that mode, so mixing modes across sections in one
  -- pass is free.
  for _, b in ipairs(out) do table.sort(b.slots, sorter(b.mode)) end
  return out, used, total
end

-- Every occupied bag slot into its section, sections that hold anything returned in list order. The
-- window hands its live query so the per-section hit count drives what a search shows;
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
    out[i] = isCat(c) and catName(c) or ""
  end
  return out
end
