local addonName, ns = ...

local Cats = {}
ns.Categories = Cats

-- Forward-declared here, above Cats:PinItem, so its `filterStamp = nil` (the cache invalidation on a
-- pin change) writes this upvalue and not a stray global. The classify cache below (FILTERS/PINS/
-- ACTIVE/ORDER) is assigned into these same names once they are in scope; without this line PinItem sat
-- textually before the local and its assignment silently missed the cache.
local FILTERS, PINS, ACTIVE, ORDER, filterStamp

-- The Empty section's own id. It owns no items, so it never collides with a real category id
-- (shipped ids are words, custom ids start with "u").
Cats.EMPTY_ID = "empty"

-- A window is open that takes items one physical stack at a time: trade, mail, a merchant, a banker or
-- guild bank, the scrapper, or the socket UI. While one is up, Combine stacks must not fold: a folded
-- cell binds a single slot and draws the sum, so a stack the player split off to hand over would be
-- hidden behind the fold and could not be picked up on its own. Suppressing the fold here makes every
-- physical stack its own cell again for the duration, then the fold returns when the window closes.
-- Read live each layout; the events that open and close these windows already relayout the grouped view.
local SPLIT_TYPES
local function splitWindowOpen()
  local M = C_PlayerInteractionManager
  local IT = Enum and Enum.PlayerInteractionType
  if not (M and M.IsInteractingWithNpcOfType and IT) then return false end
  if not SPLIT_TYPES then
    SPLIT_TYPES = {}
    for _, k in ipairs({ "TradePartner", "MailInfo", "Merchant", "Banker", "CharacterBanker",
                         "AccountBanker", "GuildBanker", "ScrappingMachine", "ItemInteraction",
                         "VoidStorageBanker" }) do
      if IT[k] then SPLIT_TYPES[#SPLIT_TYPES + 1] = IT[k] end
    end
  end
  for _, t in ipairs(SPLIT_TYPES) do
    if M.IsInteractingWithNpcOfType(t) then return true end
  end
  return false
end
-- Read by the grouped views to freeze their layout while any such window is open: an item leaving the
-- bags (sold, deposited) then keeps its cell in place instead of the whole view reflowing.
ns.SplitWindowOpen = splitWindowOpen
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

-- Ordered list, first match wins within one priority, so a piece lands in one section and its place
-- in the list is the tie-break. Sharp edges to keep in mind before reordering: Weapon is by slot
-- (`weapon shield offhand` — every word is a slot and they OR into one set; it must not be mixed with an
-- armor kind-row, since slot and kind are different axes and AND to nothing). Jewelry is `finger neck`
-- only, with Trinkets split into its own row below; leave trinket in Jewelry and the Trinkets row goes
-- empty, since Jewelry sits higher and claims them first. Collectibles unites three things on different
-- axes — Toy is a flag, Mount and Battlepet are kinds — so it needs the top-level "|": `toy | mount
-- battlepet` = toy OR (mount OR battlepet). Grey vendor trash matches both its type (a grey Miscellaneous
-- piece answers to the `misc` row, a grey weapon to a gear row) and the `poor` quality; the Junk row
-- carries prio 2 so it wins that contest wherever it sits, which is why no other rule needs a "!junk" to
-- push greys past itself. Drop Junk's priority to 0 and a grey would fall to whichever type row sits
-- above it instead.
-- The four gear rows carry an item-level floor, `ilvl>180`. It is strictly above, so a piece at
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
-- toys are pulled out before the class catch-all. Every token here is one classify() understands, and
-- written the way the "+" picker spells it: where the parser also takes a synonym (ring for finger, junk
-- for poor, container for bag, consumables for consumable, held for offhand) the shipped rule uses the
-- word the axes offer. A chip reads through the picker, so the picker's word is the one that comes back
-- translated and pickable; a synonym typed by hand still matches, it only falls back to the token.
--
-- `prio` is a claim priority, kept apart from list position: which section a piece lands in when more
-- than one rule matches it is decided by prio (higher wins), where a section draws is decided by its
-- place in the list. Default 0. Only Junk ships raised (prio 2) so it can sit low in the list — where
-- the player wants to see it — yet still pull grey trash out from under the type rows and the
-- Miscellaneous class row above it. Ties fall back to list order, so the old top-down behaviour holds
-- wherever prio is equal. Legacy ships at the default 0: raising it would drag current-item-level gear
-- that still carries a past-expansion tag down into it, so that trade-off is left to the player.
local DEFAULTS = {
  { head = "essentials" },
  -- A named single item is a pin, not a rule: that is the one consistent home for "this exact piece", the
  -- same place the two consumables gadgets sit, and it renders in the rack with the item's art. Hearthstone
  -- owns no word rule, only the pin.
  { id = "hearthstone",   pins = { [6948] = true } },
  { id = "keystone",      search = "keystone" },
  { id = "flasks",        search = "flask" },
  { id = "food",          search = "food" },
  { id = "potions",       search = "potion" },
  -- Consumables from the current expansion, one "and" the rule editor shows as chips. The two old gadgets
  -- this row used to name by id (Auto-hammer, Goblin Glider Kit) stay with it, but as pins: naming them in
  -- the rule mixed an "or" into an "and", which no chip row can read back, and a rule the editor cannot draw
  -- is a rule the player cannot edit either. Pinned, they are still guaranteed to this row, they show in its
  -- rack like any hand-filed piece, and the rule stays one the chips read and the player can change.
  { id = "consumables",   search = "consumable !legacy", pins = { [132514] = true, [109076] = true } },
  { id = "gem",           search = "gem" },
  { id = "enhancement",   search = "enhancement" },
  { id = "quest",         search = "quest" },
  { head = "gear" },
  -- "offhand" is the slot word the picker carries: it takes the off-hand weapon and the shield as well as
  -- the hold, where "held" (the holdable slot alone) is a word no language but three can spell as one token.
  { id = "weapons",       search = "weapon shield offhand ilvl>180" },
  { id = "jewelry",       search = "finger neck ilvl>180" },
  { id = "armor",         search = "cloth leather mail plate ilvl>180" },
  { id = "trinkets",      search = "trinket ilvl>180" },
  { head = "crafting" },
  { id = "reagents",      search = "reagent !legacy" },
  { id = "profgear",      search = "profgear tool" },
  { id = "recipe",        search = "recipe" },
  { id = "bag",           search = "bag" },
  { id = "housing",       search = "housing" },
  { head = "hoard" },
  -- Every pair written out, rather than two slot words side by side inside an "or": the parser unions
  -- them either way, but only the written-out form is one the chip editor can show.
  { id = "wardrobe",      search = "cosmetic | glyph | tabard | shirt" },
  { id = "collectibles",  search = "toy | mount | battlepet" },
  { id = "legacy",        search = "legacy", sort = "expac" },
  { id = "miscellaneous", search = "misc" },
  { id = "other",         other = true },
  { id = "junk",          search = "poor", prio = 2 },
  { id = "empty",         empty = true },
  -- Free space, not a rule: owns no search, matches nothing. The grouped view's stand-in for the
  -- grid's trailing blank cells; kept last, movable from the editor.
  -- The catch-all: every item no rule claimed lands here. Never switched off or deleted, since items
  -- must always have somewhere to land. Its list position sets where it draws, not what it claims.
  -- Legacy gathers gear from every past expansion, so it ships pre-set to draw by expansion (newest
  -- first): the one shipped section where that order reads better than quality. The player can change it
  -- from the row's + panel like any other, and every other section still follows the global sort.
}

local GROUP_NAMEKEY = {
  essentials   = "Essentials",
  gear         = "Gear",
  crafting     = "Crafting",
  hoard        = "Hoard",
}

local NAMEKEY = {
  hearthstone   = "Hearthstone",
  keystone      = "Keystone",
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
  -- hide and pins are tables, so each is copied fresh rather than shared: a seed must never hand the new save
  -- a reference into the constant (or the source profile), or editing one would bleed into the other.
  local hide, pins
  if type(c.hide) == "table" then hide = {}; for k, v in pairs(c.hide) do hide[k] = v end end
  if type(c.pins) == "table" then pins = {}; for k, v in pairs(c.pins) do pins[k] = v end end
  return { id = c.id, search = c.search, name = c.name, enabled = c.enabled,
           empty = c.empty, other = c.other, sort = c.sort, prio = c.prio, hide = hide, pins = pins }
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
-- The pins a shipped preset carries, so adding one from the shelf brings its hand-filed pieces with it: the
-- rack is part of what the preset is, not something only a fresh save gets.
local PRESET_PINS = {}
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
    if type(c.pins) == "table" then
      local pins = {}
      for k, v in pairs(c.pins) do pins[k] = v end
      PRESET_PINS[c.id] = pins
    end
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
-- search and its own copy of the preset's pins, inserted in the rule region. A second add of the same
-- preset is a no-op, so the strip's one-click add can never make two "Armor" rows; the caller dims an
-- in-list preset to signal that.
function Cats:AddPreset(id)
  if not id or self:Has(id) then return end
  local search = PRESET_SEARCH[id]
  -- A preset can ship pins with no search (Hearthstone is one exact item), so it is addable when it has
  -- either; only a preset with neither is not a real category.
  if search == nil and not PRESET_PINS[id] then return end
  local pins
  if PRESET_PINS[id] then
    pins = {}
    for k, v in pairs(PRESET_PINS[id]) do pins[k] = v end
  end
  local list = self:EnsureCustom()
  local at = self:InsertAt(list)
  table.insert(list, at, { id = id, search = search, sort = PRESET_SORT[id], pins = pins })
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

-- The rule of a category by id, and the setter by id, for the visual chip editor: the panel knows a row
-- by its id (a drag can slide indices under an open panel, so the index is not safe to hold), exactly as
-- the sort and priority controls do. The read returns "" for a row with no rule.
function Cats:SearchById(id)
  if not id then return "" end
  for _, c in ipairs(self:List()) do
    if type(c) == "table" and c.id == id then return c.search or "" end
  end
  return ""
end

function Cats:SetSearchById(id, text)
  if not id then return end
  local list = self:EnsureCustom()
  for _, c in ipairs(list) do
    if type(c) == "table" and c.id == id then c.search = text or ""; return end
  end
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

-- The claim priority of a category, set from the editor. Keyed by id, not index, for the same reason
-- the sort override is: a drag can slide indices under an open control. It decides which section wins
-- an item that several rules match — higher takes it — but never where the section draws, which stays
-- the list position. Stored only when non-zero so a default list carries no prio field; 0 clears it.
-- Only the classify order depends on it, so a change nils the stamp to force a reclassify, exactly as
-- a pin change does. Range is clamped to the editor's own -2..2.
function Cats:SetPrioById(id, n)
  if not id then return end
  n = tonumber(n) or 0
  if n < -2 then n = -2 elseif n > 2 then n = 2 end
  local list = self:EnsureCustom()
  for _, c in ipairs(list) do
    if type(c) == "table" and c.id == id then
      c.prio = (n ~= 0) and n or nil
      filterStamp = nil
      return
    end
  end
end

-- The stored priority of the category with this id, 0 when it carries none. Read side for the editor.
function Cats:PrioOf(id)
  if not id then return 0 end
  for _, c in ipairs(self:List()) do
    if type(c) == "table" and c.id == id then return tonumber(c.prio) or 0 end
  end
  return 0
end

-- "Show in": a category can be hidden in one or more of the three windows (bags, bank, warband) while
-- still classifying everywhere else. Stored as c.hide = { bank = true, ... }; a window absent from the
-- table (or no table) means shown. Hidden is not the same as removed: an item a hidden category would
-- have claimed in that window falls through to the next matching rule (ultimately Other), so nothing
-- ever disappears from a bag — only which section draws it changes. bucketsCore reads c.hide live off
-- the ACTIVE entries, so no cache stamp depends on it; a toggle is a plain relayout.
local WINDOW_KEYS = { bags = true, bank = true, warband = true }

function Cats:HiddenIn(id, window)
  if not (id and WINDOW_KEYS[window]) then return false end
  for _, c in ipairs(self:List()) do
    if type(c) == "table" and c.id == id then
      return (type(c.hide) == "table" and c.hide[window]) and true or false
    end
  end
  return false
end

function Cats:ToggleHidden(id, window)
  if not (id and WINDOW_KEYS[window]) then return end
  local list = self:EnsureCustom()
  for _, c in ipairs(list) do
    if type(c) == "table" and c.id == id then
      -- Empty and Other always show: Empty is the free-space stand-in and Other must always have a place
      -- to land the unclaimed, so neither is hideable however this is called.
      if c.empty or c.other then return end
      local h = c.hide
      if type(h) ~= "table" then h = {}; c.hide = h end
      h[window] = (not h[window]) or nil
      if next(h) == nil then c.hide = nil end
      return
    end
  end
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
-- Is drag-to-pin armed right now? "off" never pins, "on" always, "alt" only while Alt is held. Read at
-- the moment of the drop so the modifier is live, and read by both grouped views, which drop a piece on a
-- section the same way. A missing or unknown saved value falls back to the "alt" default.
function Cats.PinDragActive()
  local mode = (WarpeeDB and WarpeeDB.catPinDrag) or "alt"
  if mode == "off" then return false end
  if mode == "on" then return true end
  return IsAltKeyDown() and true or false
end

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
-- keeps its rule, its caption, whether it is on, its manual homes, its own draw order, its claim
-- priority and which windows it is hidden in. Fold state does not travel — a folded band is how the
-- sender's view stood, not part of the list, and a code that carried it would hand over the sender's
-- clutter — and neither does any field a later version may add, since one this build does not know is
-- not read back.
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
  if type(e.prio) == "number" and e.prio ~= 0 then
    local n = e.prio
    if n < -2 then n = -2 elseif n > 2 then n = 2 end
    out.prio = n
  end
  -- Only the three known window keys travel, so a code cannot smuggle a stray field into c.hide; an
  -- empty table is dropped rather than stored, matching how the toggle clears it.
  if type(e.hide) == "table" then
    local hide
    for _, w in ipairs({ "bags", "bank", "warband" }) do
      if e.hide[w] then hide = hide or {}; hide[w] = true end
    end
    if hide then out.hide = hide end
  end
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
-- Two shipped rules used to be written so that the chip editor could not read them back. Consumables
-- mixed "and" with "or" to name two old gadgets it still wants; Wardrobe left two slot words side by side
-- inside an "or", which the parser unions but the chip view would not flatten. Both are corrected in the
-- shipped table above — Consumables keeps only the general rule, with the two gadgets pinned to that row
-- instead, and Wardrobe writes its "or" between every pair — and this pass carries the correction onto a
-- save that still holds the old text exactly. A rule the player has typed over no longer matches the old
-- string and is left as it is, and a row already corrected does not match either, so the pass is safe to
-- run again; the flag keeps it to the one time.
-- The pins are a second pass with a flag of their own, because a build in between shipped the two gadgets
-- pinned, then moved them into the rule text: a save that took that build holds the flat rule with an empty
-- rack, and its rule flag is already set. A save that took the first shape gets the rule rewritten and the
-- pins written in the same walk; a save that took the second gets only the pins.
local PRESET_RULE_FROM = {
  consumables = { search = "consumables !legacy | id132514 id109076", flat = "consumables !legacy",
                  pin = { 132514, 109076 } },
  wardrobe    = { search = "cosmetic | glyph | tabard shirt" },
  -- Hearthstone shipped as the rule "id6948"; it is a pin now. A save still holding that exact rule gets it
  -- cleared and the item pinned, once.
  hearthstone = { search = "id6948", pin = { 6948 }, clearSearch = true },
}
function Cats:UpgradePresetRules()
  if not WarpeeDB then return end
  local doRules, doPins = not WarpeeDB.catRuleChips, not WarpeeDB.catConsumPins
  -- Hearthstone id-rule -> pin is its own flag, since the two above are already set on any save from the
  -- in-between build and would skip this.
  local doHearth = not WarpeeDB.catHearthPin
  if not (doRules or doPins or doHearth) then return end
  WarpeeDB.catRuleChips, WarpeeDB.catConsumPins, WarpeeDB.catHearthPin = true, true, true
  local db = WarpeeDB.categories
  if type(db) ~= "table" then return end
  for _, c in ipairs(db) do
    local from = isCat(c) and type(c.id) == "string" and PRESET_RULE_FROM[c.id]
    if from then
      -- A row holding the shipped rule string exactly gets pins written in and, when the preset carries no
      -- rule any more (Hearthstone), its search cleared. A rule the player typed over is left alone.
      local held = (c.search == from.search) or (from.flat and c.search == from.flat)
      if from.clearSearch then
        if doHearth and held then
          c.search = nil
          if from.pin then
            for _, id in ipairs(from.pin) do c.pins = c.pins or {}; c.pins[id] = true end
          end
        end
      else
        if doRules and held then
          c.search = PRESET_SEARCH[c.id] or c.search
        end
        if doPins and from.pin and c.search == PRESET_SEARCH[c.id] then
          for _, id in ipairs(from.pin) do
            c.pins = c.pins or {}
            c.pins[id] = true
          end
        end
      end
    end
  end
  filterStamp = nil
end

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

-- Five shipped rules named their concept with a word the parser takes but the picker never shows: "held"
-- for the off-hand, "ring" for the finger slot, "junk" for the poor quality, "container" for the bag
-- class and "consumables" for the general rule, the plural only some languages spell. A chip reads
-- through the picker, so such a word is a chip that falls back to its English token — and "held" has no
-- one-word name in most languages at all, since the client spells that slot as a phrase. The shipped text
-- above now says what the axes say, and this brings a save holding the old spelling over once. A rule the
-- player has typed over matches nothing here and is left as it is; a row already carrying the picker's
-- word does not match either, so the pass is safe to run again.
local RULE_WORD_FROM = {
  consumables = "consumables !legacy",
  weapons     = "weapon shield held ilvl>180",
  jewelry     = "ring neck ilvl>180",
  bag         = "container",
  junk        = "junk",
}
function Cats:UpgradeRuleWords()
  if not WarpeeDB or WarpeeDB.catRuleWords then return end
  WarpeeDB.catRuleWords = true
  local db = WarpeeDB.categories
  if type(db) ~= "table" then return end
  for _, c in ipairs(db) do
    if isCat(c) and type(c.id) == "string" and c.search == RULE_WORD_FROM[c.id] then
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
FILTERS, PINS, ACTIVE, ORDER, filterStamp = {}, {}, {}, {}, nil

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
      -- prio joins the stamp because it reorders which section claims an item, so a change to it must
      -- rebuild the classify order below just as a search or a pin change does.
      parts[i] = (c.id or "") .. "\1" .. (c.search or "") .. "\1" .. tostring(c.enabled)
                 .. "\1" .. pinPrint(c) .. "\1" .. tostring(c.prio or 0)
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
  ORDER = ORDER or {}
  wipe(ORDER)
  for _, c in ipairs(list) do
    if isActive(c) then
      local idx = #ACTIVE + 1
      ACTIVE[idx] = c
      FILTERS[idx] = hasSearch(c) and ns.ParseSearch((c.search or ""):lower()) or nil
      PINS[idx] = hasPins(c) and c.pins or nil
      ORDER[idx] = idx
    end
  end
  -- ORDER is the sequence classify walks its search pass in: highest priority first, list order within
  -- a tie. It is kept apart from ACTIVE (which stays in list order, so order[i] in bucketsCore and the
  -- band lookup still read straight across) — only the claim contest consults ORDER. A stable sort is
  -- faked by breaking ties on the original index, so equal-priority rows keep the top-down order the
  -- view has always had and nothing shifts for a list that sets no priority at all.
  table.sort(ORDER, function(a, b)
    local pa = tonumber(ACTIVE[a].prio) or 0
    local pb = tonumber(ACTIVE[b].prio) or 0
    if pa ~= pb then return pa > pb end
    return a < b
  end)
end

-- The same fields UpdateItemButton writes onto a cell, read straight off the container because
-- a slot is sorted before any cell is bound to it. One scratch table and one location are reused
-- like a live cell reuses b.loc, so a full pass allocates nothing; wb/exp are cleared per slot or
-- the previous slot's memoized answer leaks.
local scratch = {}
local scratchLoc = ItemLocation and ItemLocation.CreateEmpty and ItemLocation:CreateEmpty()
-- Set for the duration of a bucketing pass that needs slot-memory keys (the grouped anti-jump while a
-- take-items window is open). Off otherwise: reading the instance GUID costs a container lookup per slot,
-- and a plain pass has no use for it.
local KEYED = false
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
  m.count = info.stackCount or 1
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
  m.statset = nil
  -- The slot-memory key: a unique instance GUID for a live item, so the grouped anti-jump can tell a
  -- returning piece from a genuinely new one. nil unless a keyed pass, and nil on a snapshot (no live
  -- container) or anything the client will not answer for, where the itemID stands in.
  m.guid = nil
  if isGear and scratchLoc then
    scratchLoc:SetBagAndSlot(bag, slot)
    m.loc = scratchLoc
    if C_Item.DoesItemExist(scratchLoc) then m.ilvl = C_Item.GetCurrentItemLevel(scratchLoc) end
  end
  if KEYED and hl then
    -- The gear branch above already pointed scratchLoc at this slot; reuse it, else set it now.
    if not m.loc then scratchLoc:SetBagAndSlot(bag, slot) end
    if C_Item.DoesItemExist(scratchLoc) then m.guid = C_Item.GetItemGUID(scratchLoc) end
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
  m.count = d.c or 1
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
  m.statset = nil
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
-- every section, then searches in priority-then-list order. Within each pass first match wins. The pin
-- pass loops ACTIVE directly (a pin is unique per item, so order cannot change the outcome); the search
-- pass walks ORDER so a higher-priority rule claims a shared item before a lower one, whatever their
-- list positions. ORDER holds the same indices as ACTIVE, so order[ORDER[k]] still names the section.
-- `skip` (optional) is a set of ACTIVE indices the current window hides: a hidden section neither claims
-- a pin nor matches a search here, so its items fall through to the next rule (ultimately Other), which
-- is what "Show in" means — the item stays in the bag, only which section draws it changes.
local function classify(m, skip)
  local id = m.id
  if id then
    for i = 1, #ACTIVE do
      if not (skip and skip[i]) then
        local pins = PINS[i]
        if pins and pins[id] then return i end
      end
    end
  end
  for k = 1, #ORDER do
    local i = ORDER[k]
    if not (skip and skip[i]) then
      local f = FILTERS[i]
      if f and ns.MatchSearch(m, f) then return i end
    end
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
  m.statset = nil
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
  for k = 1, #ORDER do
    local i = ORDER[k]
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

-- Slot memory for the grouped anti-jump. A category keeps the ordered keys of the slots it last drew;
-- while a window that takes items is open the next pass walks that order and rebuilds the section from
-- it: a remembered piece still present keeps its place, one that left becomes an inert hole carrying its
-- old key, and anything present no remembered entry claimed is new and appends. So a deposit leaves holes
-- in place (no reflow under the cursor) and a piece coming back from the bank drops into its own hole;
-- Does live slot `e` hold the remembered piece `p`? The instance GUID is the exact match, tried first. If
-- it does not match, the itemID is the fallback, and it is allowed even for a unique piece (gear): a piece
-- that goes into the warband bank and comes back is issued a FRESH GUID, so its old GUID never matches
-- again, and only the itemID ties the returning piece to the hole it left. The counted round-one/round-two
-- match below is what keeps this fallback honest: a still-present twin of the same itemID claims its own
-- slot by position in round one, so it is already taken and cannot be handed to a departed piece's entry in
-- round two. (onScreen, separately, stays GUID-only, so that same twin never masks the departure itself.)
local function sameKey(e, p)
  if p.guid and e.guid and e.guid == p.guid then return true end
  return (p.nokey and e.nokey and e.nokey == p.nokey) or false
end

-- `live` holds every identity still on screen anywhere in this pass, so a hole can tell whether the piece
-- it stands for left the bags or merely moved (a merged stack, a piece re-filed into another category).
-- Only a hole whose piece is nowhere is a removal, and that is what the caller times its hold off.
-- The instance GUID is trusted alone whenever the piece has one: a moved piece keeps its GUID (it shifts
-- only in and out of the warband bank, and a piece there was matched by key in its own category already),
-- so a GUID that is nowhere means the piece truly left. The earlier itemID fallback here was the bug behind
-- "not every stack got a hole": depositing one stack of an itemID while another stack of the same itemID
-- stayed read the survivor as the deposited one still being present, and drew no hole. The itemID is used
-- only when the client answered no GUID at all.
local function onScreen(live, p)
  if not live then return false end
  if p.guid then return live.guid[p.guid] == true end
  return (p.nokey and live.nokey[p.nokey]) and true or false
end
local function reconcile(b, prev, live)
  if not (prev and #prev > 0) then return end
  local slots, used, out = b.slots, {}, {}
  -- A pass that brought this category nothing it did not already hold is a pure removal: the pieces that
  -- stood here left and their places are worth holding, since nothing is pushing them out of the way. A
  -- pass that brought something new is a rebuild instead, and a gap held through a rebuild stands over a
  -- piece that is not coming back. Counted by item key, not by identity, because a stack's GUID shifts as
  -- it moves and one arriving of a kind the category already held is still an arrival: only a key the
  -- category has never seen makes the pass a rebuild.
  local held = {}
  for i = 1, #prev do
    local key = prev[i].nokey
    if key then held[key] = (held[key] or 0) + 1 end
  end
  local fresh = false
  for k = 1, #slots do
    local key = slots[k].nokey
    if key and (held[key] or 0) > 0 then held[key] = held[key] - 1
    elseif key then fresh = true; break end
  end
  -- Round one, for every remembered piece at once: the live slot in the very bag and slot it was
  -- remembered in is that piece. It has to be a round of its own rather than a preference inside the
  -- loop below. Two identical stacks carry the same itemID and a stack's GUID shifts when it moves, so
  -- nothing else tells them apart, and an earlier entry left to look for a match by key would take the
  -- later one's cell: picking one of two identical stacks up emptied the other one's cell instead.
  local claim, at = {}, {}
  for k = 1, #slots do at[slots[k].bag * 1000 + slots[k].slot] = k end
  for i = 1, #prev do
    local p = prev[i]
    local k = at[p.bag * 1000 + p.slot]
    if k and not used[k] and sameKey(slots[k], p) then
      used[k], claim[i] = true, k
    end
  end
  -- Round two: what is left, in remembered order, matched by key. Among the live slots still free a
  -- stack of the same size comes first, since its count is the last thing that tells two apart.
  local pick = {}
  for i = 1, #prev do
    local p = prev[i]
    if not claim[i] then
      local byCount, byKey
      for k = 1, #slots do
        local s = slots[k]
        if not used[k] and sameKey(s, p) then
          if not byCount and p.count and s.count == p.count then byCount = k end
          byKey = byKey or k
        end
      end
      pick[i] = byCount or byKey
      if pick[i] then used[pick[i]] = true end
    end
  end
  for i = 1, #prev do
    local p = prev[i]
    local k = claim[i] or pick[i]
    if k then
      out[#out + 1] = slots[k]
    elseif not (fresh or onScreen(live, p)) then
      local d = { dummy = true, guid = p.guid, nokey = p.nokey, count = p.count,
                  bag = p.bag, slot = p.slot }
      -- A hole stands for a piece that left the window's containers: a deposit, a sale, a destroy. The
      -- piece stood here as a live cell last pass and stands nowhere now, so there is nothing left to take
      -- this place and holding it keeps the view from reflowing under the cursor. A hole carried over from
      -- an earlier pass (p.dummy) was already counted on the pass that made it.
      if not p.dummy then b.left = (b.left or 0) + 1 end
      out[#out + 1] = d
    end
    -- The other two ways out leave no hole at all, and neither is a removal: the pass is a rebuild (fresh,
    -- something new arrived in this category), or the piece is still on screen somewhere else in this
    -- window — it changed category, or moved within this one. A gap in that case would be a mark nothing
    -- could take, standing over a piece the player can see two cells away.
  end
  for k = 1, #slots do
    if not used[k] then out[#out + 1] = slots[k] end
  end
  b.slots = out
end

-- The ordered keys of a buckets pass, one list per category id, for the next pass to reconcile against.
-- Dummies carry their remembered keys forward so a hole survives pass after pass until its piece returns.
-- `holes` says whether the pass that produced these buckets is drawing them: a pass that draws the
-- compacted view hands back the compacted order, or the holes it just dropped would come back the moment a
-- window opened over it.
function Cats:CaptureMemory(buckets, holes)
  local mem = {}
  for _, b in ipairs(buckets or {}) do
    if not b.empty then
      local list = {}
      for i = 1, #b.slots do
        local s = b.slots[i]
        if holes or not s.dummy then
          list[#list + 1] = { guid = s.guid, nokey = s.nokey, count = s.count,
                              bag = s.bag, slot = s.slot, dummy = s.dummy }
        end
      end
      if #list > 0 then mem[b.id] = list end
    end
  end
  return mem
end

-- Drop the held holes from a pass's buckets, in place, for a layout that is not holding: the cells after a
-- piece that left move up, which is what an ordinary rebuild does.
function Cats:Compact(buckets)
  for _, b in ipairs(buckets or {}) do
    local slots, n = b.slots, 0
    for i = 1, #slots do
      if not slots[i].dummy then n = n + 1; slots[n] = slots[i] end
    end
    for i = n + 1, #slots do slots[i] = nil end
  end
end

-- Handed in as the memory on the first held pass, before any memory exists: a non-nil empty table, so the
-- pass records keys (a nil memory would read as "not keyed") yet reconciles against nothing.
Cats.EMPTY_MEMORY = {}

-- The category transfer: move a section's slots through the game's own UseContainerItem, a batch at a
-- time. Modelled on the vendor sell pump (Features/Vendor.lua): a slot whose item is gone or locked is
-- never forced, a slot that will not clear after a few tries is left alone, and the run stops the moment
-- the window closes or combat starts. Deposit and withdraw both come through here: `send(bag, slot)` is the
-- one game call that moves a piece (deposit passes the bank type, withdraw does not), and `dummy` entries
-- (held holes) are skipped since their bag/slot is stale.
--
-- Two speeds, and which one a run gets is the `warband` argument. The character bank takes a move and has
-- it done by the time the next line runs, so its runs send batch after batch with nothing but a short gap
-- between them. The account bank answers a server round-trip per move, and a second batch fired into a
-- move still in flight leaves those slots locked and drops the moves behind it: its runs are the smaller
-- batch and do not send the next one until the one before it landed. What "landed" is read from is the
-- run's own list, since either direction empties the slot it sent, so it costs no container reads.
local ctstate = nil
local CT_BATCH, CT_TRIES, CT_WAIT = 6, 4, 0.12
-- A slot that reads locked is a move in flight, so the sweep waits it out rather than firing at it. But a
-- lock that never clears is a server-side stall (the state a reload does not fix, only a relog): waited on
-- forever it would spin the pump on that one slot without end. This is how many consecutive sweeps a slot
-- may sit locked before it is given up on, so the run finishes instead of looping. Generous, since a real
-- warband round-trip can hold a lock for a second or two; at ~0.1s a sweep, this is a few seconds.
local CT_LOCK_WAITS = 40
-- The account bank's batch, kept small: the warband answers a server round-trip per move, and firing more
-- than a handful before they land is what left pieces server-side locked (a state a reload does not clear,
-- only a relog). Three at a time, well within what the server accepts in one breath.
Cats.WARBAND_BATCH = 3
-- A batch sent to the account bank is given this long to land before the run sweeps again. It is not a
-- give-up: the sweep re-reads the container, marks the pieces that did land as done, and re-sends any that
-- did not (the server drops a move now and then), which is how a skipped piece is gone back for rather than
-- abandoned. A piece that truly cannot move is caught by the per-slot try cap in ctSweep, not here. The poll
-- count is generous, since a slow warband round-trip must be waited out rather than raced.
local CT_SETTLE, CT_SETTLE_POLLS = 0.10, 40

-- The client is mid-update: a burst of container changes has fired BAG_UPDATE but not yet the settling
-- BAG_UPDATE_DELAYED, so slots are in motion and a move issued now can land on a slot the server is still
-- rewriting and lock it. The reference addon gates its whole transfer on exactly this (its bag cache marks
-- itself pending on BAG_UPDATE and clears on BAG_UPDATE_DELAYED); WoW exposes no such flag, so it is tracked
-- here off the same two events, plus the bank-slot events that a deposit or withdraw stirs. The pump holds
-- until it clears, which is what makes a whole batch settle before the next goes out. A hard ceiling
-- (bagPendingUntil) drops the flag if the settling event never arrives, so the pump can never wedge on it;
-- it is long, because dropping it early is exactly the race that locked pieces on the warband.
local bagPending, bagPendingUntil = false, 0
do
  local w = CreateFrame("Frame")
  w:RegisterEvent("BAG_UPDATE")
  w:RegisterEvent("BAG_UPDATE_DELAYED")
  w:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
  w:RegisterEvent("PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED")
  w:RegisterEvent("BANK_TABS_CHANGED")
  w:SetScript("OnEvent", function(_, event)
    if event == "BAG_UPDATE_DELAYED" then
      bagPending = false
    else
      -- Any container change opens the pending window; BAG_UPDATE_DELAYED closes it. The ceiling covers a
      -- bank event that the client does not follow with a delayed sweep.
      bagPending, bagPendingUntil = true, GetTime() + 2.0
    end
  end)
end
local function clientSettling()
  if not bagPending then return false end
  if GetTime() >= bagPendingUntil then bagPending = false; return false end
  return true
end

-- Has the batch just sent actually landed? Read per moved entry, and which side is read depends on the
-- move. A deposit records the bank slot it aimed at (destBag/destSlot): the source (a bag) empties the
-- instant the piece is lifted onto the cursor, well before the account bank answers the round-trip, so
-- reading the source would call the batch done too early and the next batch would fire into slots the
-- warband has not finished locking. The destination slot fills only when the server confirms, so a deposit
-- is pending until its target slot holds something. A withdraw has no recorded target (the game picks the
-- bag slot), but its source IS the account bank, which empties only on the round-trip, so the source read
-- is the right signal there. A move with neither still on its side is done.
local function ctPending(moved)
  local n = 0
  for i = 1, #moved do
    local m = moved[i]
    if not m.s.done then
      if m.destBag then
        local info = C_Container.GetContainerItemInfo(m.destBag, m.destSlot)
        if not (info and (info.hyperlink or info.itemID)) then n = n + 1 end
      else
        local info = C_Container.GetContainerItemInfo(m.s.bag, m.s.slot)
        if info and (info.hyperlink or info.itemID) then n = n + 1 end
      end
    end
  end
  return n
end

-- One sweep of the slot list: send up to `batch` pieces that are present and unlocked, mark gone or stuck
-- ones done. `send(bag, slot, info)` returns a truthy value for a move actually issued (a deposit returns
-- its target {bag, slot}; a withdraw returns true, the game choosing the bag slot), false for a move it
-- declined (the bank refuses the piece, or is full). A declined slot is marked done, so a full bank ends
-- the run instead of hammering the same slots: the space check lives in `send`, and the sweep trusts it.
-- Each issued move is recorded in `moved` with the target slot the pacing reads to know it landed.
local function ctSweep(slots, send, tries, batch, moved)
  local cap = batch or CT_BATCH
  local sent = 0
  for i = 1, #slots do
    local s = slots[i]
    if not s.dummy and not s.done and sent < cap then
      local info = C_Container.GetContainerItemInfo(s.bag, s.slot)
      if not (info and (info.hyperlink or info.itemID)) then
        s.done = true
        s.locks = nil
      elseif info.isLocked then
        -- A move is in flight on this slot; wait it out. But a lock that never clears is a server-side
        -- stall (only a relog frees it), and waited on forever it would spin the pump on this one slot with
        -- nothing else left to do. Count the consecutive locked sweeps and give up past the cap, so the run
        -- ends instead of looping. The count resets the moment the slot reads unlocked again below.
        s.locks = (s.locks or 0) + 1
        if s.locks > CT_LOCK_WAITS then s.done = true end
      else
        s.locks = nil
        local k = s.bag * 1000 + s.slot
        tries[k] = (tries[k] or 0) + 1
        if tries[k] > CT_TRIES then
          s.done = true
        else
          local ok = send(s.bag, s.slot, info)
          if ok then
            sent = sent + 1
            if moved then
              local rec = { s = s }
              if type(ok) == "table" then rec.destBag, rec.destSlot = ok[1], ok[2] end
              moved[#moved + 1] = rec
            end
          else
            s.done = true
          end
        end
      end
    end
  end
  return sent
end

-- Start a transfer of `slots`. `send(bag,slot,info)` returns true when a move was actually issued;
-- `alive()` says the window is still open and live (checked every pass); `warband` is true for a run that
-- touches the account bank, either way, and it is what selects the smaller batch and the waiting for each
-- batch to land. Re-entrant: a second call replaces the run, since only one category moves at a time.
function Cats:MoveSlots(slots, send, alive, warband)
  ctstate = { slots = slots, send = send, alive = alive, tries = {},
              batch = warband and Cats.WARBAND_BATCH or CT_BATCH, pace = warband or nil }
  local function step()
    local st = ctstate
    if not (st and st.slots) then return end
    if not st.alive() then ctstate = nil; return end
    if InCombatLockdown() or CursorHasItem() or GetCursorInfo()
       or (ns.ItemTargeting and ns.ItemTargeting()) then
      C_Timer.After(0.25, step)
      return
    end
    -- The client is still settling a burst of container changes (BAG_UPDATE fired, BAG_UPDATE_DELAYED not
    -- yet): hold the whole run. A move issued into that window can land on a slot the server is still
    -- rewriting and lock it, which is what left pieces stuck mid-transfer. This is the global gate the
    -- reference addon puts at the head of every transfer step; the per-slot lock check below is not enough
    -- on its own, since a target slot can be mid-rewrite without the source reading locked.
    if clientSettling() then
      C_Timer.After(CT_SETTLE, step)
      return
    end
    -- An account-bank run sends no new batch until the one before it has landed on the far side: a second
    -- batch fired into moves still in flight locks the target slots and drops the moves behind them. The
    -- wait reads the container (ctPending) on the side that answers the round-trip: a deposit's target bank
    -- slot, which fills only on the server's confirm, so the pause is the real warband round-trip and the
    -- pieces are seen to arrive before the next batch goes (reading the source bag instead would end the
    -- wait the instant the piece is lifted, far too early). On the poll cap it does not abandon anything: it
    -- falls through to the sweep, which marks the landed pieces done and re-sends any straggler the server
    -- dropped. A character-bank run skips all of this; the bank is done with the move by the next line.
    if st.pace and st.moved then
      if ctPending(st.moved) == 0 then
        st.moved, st.polls = nil, nil
      elseif (st.polls or 0) >= CT_SETTLE_POLLS then
        st.moved, st.polls = nil, nil
      else
        st.polls = (st.polls or 0) + 1
        C_Timer.After(CT_SETTLE, step)
        return
      end
    end
    local moved = {}
    local sent = ctSweep(st.slots, st.send, st.tries, st.batch, moved)
    -- The receiving window is driven by the client's own bag events, and during a paced run those can
    -- hold off until the burst is over: the piece then appears only once everything has landed. Each
    -- batch lays both split views out again, so a piece landing shows as the one before it leaves.
    if sent > 0 and st.pace then st.moved, st.polls = moved, 0 end
    if sent > 0 and ns.RelayoutForSplit then ns.RelayoutForSplit() end
    local left = false
    for i = 1, #st.slots do
      local s = st.slots[i]
      if not s.done and not s.dummy then left = true; break end
    end
    if left then
      -- A paced run comes back on the settle poll while it is waiting for its batch, and on the plain gap
      -- once that batch has landed.
      C_Timer.After((st.pace and st.moved) and CT_SETTLE or CT_WAIT, step)
    else
      ctstate = nil
    end
  end
  step()
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
local function bucketsCore(find, snap, snapMode, bagList, reagentBag, memory)
  ensureFilters()
  -- A memory means this pass reconciles against last pass's slot order, so it must also record the
  -- instance GUIDs the reconcile matches on. The grouped view hands one on every pass: a piece can vanish
  -- with no window open at all (a destroy), and by the time the pass sees it gone the order it stood in is
  -- already last pass's, so it has to have been recorded then. This read is what that costs.
  KEYED = memory ~= nil
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
  -- Which sections are hidden in this window, as a set of ACTIVE indices classify() skips. The window is
  -- snapMode ("bags"/"bank"/"warband"); a hidden section is left out of the claim entirely so its items
  -- fall through to the next rule here while still filing normally in the windows it is shown in. Built
  -- once per pass rather than read per slot. A hidden section still gets its bucket below (so a toggle is
  -- a live relayout, not a structural rebuild), it simply never receives a slot and so does not draw.
  local skip
  do
    for i = 1, #ACTIVE do
      local h = ACTIVE[i].hide
      if type(h) == "table" and h[snapMode] then skip = skip or {}; skip[i] = true end
    end
  end
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
  -- Combine stacks: when on, several slots of one stackable item fold into a single cell that shows the
  -- summed count, so a category is as compact as the items allow rather than one tile per bag slot. Gear,
  -- caged pets and keystones are never merged — each of those is its own piece (a distinct ilvl, pet
  -- level or key), so folding them would hide real differences. The cell still binds one real bag slot,
  -- so the secure right-click is untouched; only the drawn count is the sum. Read once per pass.
  -- Suppressed while a stack-splitting window is open (trade, mail, merchant, bank, scrapper, socket):
  -- a folded cell hides the individual physical stacks, so a piece split off to hand over could not be
  -- picked up on its own. Unfolding for the duration puts every physical stack back as its own cell.
  local combine = (WarpeeDB and WarpeeDB.catCombine and not splitWindowOpen()) and true or false
  -- One buckets pass files a slot from its meta whatever built it: a live container reads it straight,
  -- a snapshot rebuilds the same meta from the record the Vault kept. The sort keys ride on the slot
  -- entry, read off the scratch meta now, since the meta is reused on the next slot and would be gone
  -- by the time the bucket is sorted. rank and exp are only read when the destination's own sort asks
  -- for them, so a plain quality view never pays for a branch match or an expansion lookup.
  local function file(bag, slot, m)
    local idx = classify(m, skip)
    local dest = (idx and order[idx]) or otherBucket
    if find and ns.MatchSearch(m, find) then dest.hits = dest.hits + 1 end
    -- Fold into the item's existing cell when combining: same id, and not one of the per-piece kinds.
    local canMerge = combine and m.id and not (m.isGear or m.battlepet or m.keystone)
    if canMerge then
      dest.byId = dest.byId or {}
      local prev = dest.byId[m.id]
      if prev then prev.count = prev.count + (m.count or 1); return end
    end
    local entry = {
      bag = bag, slot = slot, q = m.q or -1, ilvl = m.ilvl or 0, name = m.name or "",
      count = m.count or 1,
      -- The slot-memory keys. guid = a unique instance (from C_Item.GetItemGUID this pass); nokey = the
      -- itemID fallback. Both ride the entry so the reconcile pass can tie a returning piece to the hole it
      -- left without re-reading the container. The GUID matches an unmoved or in-place-moved piece exactly;
      -- the itemID catches a piece that came back through the warband bank, which is issued a fresh GUID on
      -- the way out and so can never match its old GUID again.
      guid = m.guid, nokey = m.id,
    }
    local mode = dest.mode
    if mode == "match" then
      entry.rank = branchRank(idx, m)
    elseif mode == "expac" then
      entry.exp = ns.MetaExp(m)
    end
    dest.slots[#dest.slots + 1] = entry
    if canMerge then dest.byId[m.id] = entry end
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
  -- Each bucket sorts by its own resolved mode: a category's override, or the global fall-through.
  -- The comparator only reads keys file() filled for that mode, so mixing modes across sections in one
  -- pass is free. Sorted before reconcile so the holes insert into the settled order.
  for i = 1, #order do table.sort(order[i].slots, sorter(order[i].mode)) end
  -- Slot-memory reconcile: hold each emptied cell as an inert hole where it was and drop a returning piece
  -- back into its own hole, so the grouped view does not reflow under the cursor mid-transfer. `memory` is
  -- the previous pass's per-category ordered slot keys, handed back by the window on every grouped pass.
  -- Runs over every order bucket, before the show/hide filter below, so a category emptied to its last cell
  -- keeps its holes on screen.
  if memory then
    -- Every identity still on screen anywhere this pass, so the holes the reconcile makes can say which of
    -- their pieces really left the bags; the window times its hold off those. GUIDs and itemIDs kept apart:
    -- onScreen trusts the GUID set alone whenever a piece has a GUID, so a departure is never masked by a
    -- twin of the same itemID that is still present (the itemID set is only its no-GUID fallback).
    local live = { guid = {}, nokey = {} }
    for i = 1, #order do
      local slots = order[i].slots
      for k = 1, #slots do
        local s = slots[k]
        if s.guid then live.guid[s.guid] = true end
        if s.nokey then live.nokey[s.nokey] = true end
      end
    end
    for i = 1, #order do
      if not order[i].empty then reconcile(order[i], memory[order[i].id], live) end
    end
  end
  local out = {}
  for i = 1, #order do
    -- Empty is kept on its list position whether or not it holds anything: it is the free-space
    -- stand-in and owns no slots by design. Other and every real category show only when they hold
    -- something, so an empty catch-all does not clutter the view, but when Other does hold items it
    -- now draws at its own list position rather than pinned last. A bucket carrying only holes (its
    -- items all just left) still draws, so the transfer leaves gaps rather than collapsing the section.
    if order[i].empty or #order[i].slots > 0 then out[#out + 1] = order[i] end
  end
  return out, used, total
end

-- Every occupied bag slot into its section, sections that hold anything returned in list order. The
-- window hands its live query so the per-section hit count drives what a search shows;
-- the reagent bag is always included, since cat-view is a full-inventory grouping.
function Cats:Buckets(bags, memory)
  local q = bags and bags.query or ""
  local find = (q ~= "") and bags.filters or nil
  return bucketsCore(find, bags and bags.snap, "bags", ns.playerBags, ns.reagentBag, memory)
end

-- The bank's grouping: the same rules over the bank or warband containers instead of the bags. mode
-- is "bank" or "warband" (the Vault store and the container set both key on it), snap picks the
-- cached-character store, and find is the parsed live query. No reagent bag is appended: the bank has
-- none. The container id list is handed in by the caller, which owns the BANK_MAIN / WARBAND tables.
function Cats:BankBuckets(mode, snap, find, bagList, memory)
  return bucketsCore(find, snap, mode, bagList or {}, nil, memory)
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
-- actually holds: pins first, then searches in priority-then-list order, exactly like classify, so a
-- slot is tallied once to the section that would really claim it. A disabled or blank row is not a
-- section, so it counts 0, matching isActive and the layout. Per-window "Show in" hiding is NOT applied
-- here: the editor is window-agnostic, so it shows the true rule division a category holds across the
-- bags, not what any one window draws. buildMeta runs once per slot, not once per slot per category.
-- Returns the per index array and, second, how many occupied slots matched nothing and would fall to
-- Other, so the editor can show the coverage the rules leave behind.
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
  -- Searches are tried in priority order, list order within a tie, so the tally matches classify's own
  -- ORDER walk. Built over the full list index (not ACTIVE) since Counts keys everything by list index;
  -- only rows with a filter take part, the rest sort harmlessly among themselves and are skipped below.
  local searchOrder = {}
  for i = 1, #list do if filters[i] then searchOrder[#searchOrder + 1] = i end end
  table.sort(searchOrder, function(a, b)
    local pa = tonumber(list[a].prio) or 0
    local pb = tonumber(list[b].prio) or 0
    if pa ~= pb then return pa > pb end
    return a < b
  end)
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
          for k = 1, #searchOrder do
            local i = searchOrder[k]
            if ns.MatchSearch(m, filters[i]) then out[i] = out[i] + 1; hit = true; break end
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
