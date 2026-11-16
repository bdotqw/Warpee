local addonName, ns = ...

-- The pieces no sweep may take: a merchant never sees them, and the cheap window never offers them for
-- deletion. Each door asks one predicate, so a piece the sale refuses cannot be destroyed by the other.
--
-- An id names an item on one client, and Forever names its pieces its own way, so every set below exists twice:
-- once for retail and once for Forever. Only the running client's set is read; the other is inert. The sets are
-- split by the door -- sale for what a merchant must not take, delete for what a destroy must not take -- and a
-- delete asks the sale's set as well, because a piece kept from a merchant is not one to throw away instead.
--
-- The sets are for the pieces a name cannot cover: the exception behind a kind. The kinds themselves (a potion,
-- a recipe, a collectible) and the bags are asked by the client's own class, which needs no list and covers the
-- next expansion's additions on the day they arrive.

local RETAIL = {
  sale = {
    -- Alchemist stones: the profession's own trinket and the piece a player rebuilds every expansion. A stone
    -- is a tool, not a sale: its value is the craft it opens, not the copper a merchant pays for it.
    [9149] = true, -- Philosopher's Stone
    [13503] = true, -- Alchemist Stone
    [35748] = true, -- Guardian's Alchemist Stone
    [35749] = true, -- Sorcerer's Alchemist Stone
    [35750] = true, -- Redeemer's Alchemist Stone
    [35751] = true, -- Assassin's Alchemist Stone
    [44322] = true, -- Mercurial Alchemist Stone
    [44323] = true, -- Indestructible Alchemist Stone
    [44324] = true, -- Mighty Alchemist Stone
    [58483] = true, -- Lifebound Alchemist Stone
    [68775] = true, -- Volatile Alchemist Stone
    [68776] = true, -- Quicksilver Alchemist Stone
    [68777] = true, -- Vibrant Alchemist Stone
    [75274] = true, -- Zen Alchemist Stone
    [109262] = true, -- Draenic Philosopher's Stone
    [122601] = true, -- Stone of Wind
    [122602] = true, -- Stone of the Earth
    [122603] = true, -- Stone of the Waters
    [122604] = true, -- Stone of Fire
    [128023] = true, -- Stone of the Wilds
    [128024] = true, -- Stone of the Elements
    [127842] = true, -- Infernal Alchemist Stone
    [165926] = true, -- Tidal Alchemist Stone
    [165927] = true, -- Spirited Alchemist Stone
    [165928] = true, -- Eternal Alchemist Stone
    [166974] = true, -- Sanguinated Alchemist Stone
    [166975] = true, -- Imbued Alchemist Stone
    [166976] = true, -- Emblazoned Alchemist Stone
    [171085] = true, -- Peerless Alchemist Stone
    [171087] = true, -- Awakened Alchemist Stone
    [171088] = true, -- Unbound Alchemist Stone
    [171323] = true, -- Spiritual Alchemy Stone
    [175941] = true, -- Spiritual Alchemy Stone
    [175942] = true, -- Spiritual Alchemy Stone
    [175943] = true, -- Spiritual Alchemy Stone
    [191491] = true, -- Sustaining Alchemist Stone
    [191492] = true, -- Alacritous Alchemist Stone
    [210816] = true, -- Algari Alchemist Stone
    [241291] = true, -- Primal Philosopher's Stone
    [241340] = true, -- Magister's Alchemist Stone
    [151607] = true, -- Astral Alchemist Stone
    [152637] = true, -- Siren's Alchemist Stone
    [152632] = true, -- Surging Alchemist Stone
    [168674] = true, -- Abyssal Alchemist Stone
    [168676] = true, -- Ascended Alchemist Stone
    [168675] = true, -- Crushing Alchemist Stone

    -- Fun pieces: toys and novelties a merchant would take for a few copper and the player would miss.
    [7734] = true, [10716] = true, [11905] = true, [1404] = true,
    [2820] = true, [14022] = true, [10727] = true, [10577] = true,
    [18634] = true, [18638] = true, [18639] = true, [19024] = true,
    [19979] = true, [7506] = true, [18706] = true,

    -- Old consumables: out of the expansion's window, still a keepsake or a reagent for an older recipe.
    [133576] = true, [13452] = true, [13512] = true, [6657] = true,
    [8529] = true, [127844] = true, [127843] = true, [142117] = true,
    [127846] = true, [33447] = true,

    -- Augment runes: spent on a piece of gear, never a vendor's stock.
    [118630] = true, [118631] = true, [118632] = true,
    [128482] = true, [128475] = true, [140587] = true, [153023] = true,
    [160053] = true, [174906] = true, [181468] = true, [190384] = true,
    [201325] = true, [211495] = true, [224572] = true, [246492] = true,
    [243191] = true, [259085] = true,

    -- Profession tools and the gear that carries a trade's bonus: the trade is the point, not the price.
    [9452] = true, [12709] = true, [19901] = true,
    [19972] = true, [19969] = true,
    [155459] = true, [155484] = true, [155468] = true, [155476] = true,
    [7349] = true, [10542] = true,
    [85663] = true, [19971] = true, [34109] = true,
    [68796] = true, [34836] = true, [116117] = true, [153203] = true,
    [46006] = true, [18258] = true,

    -- Every Mythic+ keystone is this one id, the level riding in the link, and no merchant buys one. It is
    -- here rather than on the price because a pin has no container record to ask and the client never caches
    -- a keystone's price at all, so the price fallback answers "unknown" and stays open to the mark forever.
    [180653] = true, -- Keystone
  },
  -- Kept from a destroy but not from a merchant: nothing, and the door is here so the two rules stay apart. The
  -- locked boxes are named on Forever's own side alone (FOREVER_LOCKBOX below): the box is a piece of that
  -- client's item list, and a retail id written here would name nothing there.
  delete = {},
}

-- Forever names its pieces with its own ids, so its sets are its own: the same two doors, filled from this
-- client's item list rather than from retail's. Retail ids that happen to mean something else here must not
-- be copied in -- an id is a name only on the client that wrote it.
--
-- The owner's keep list: the tools a profession lives by and the stations it deploys, none of which is stock
-- to sell or rubbish to destroy. It fills both doors, because the same piece must be refused by the merchant's
-- alt-click and by the cheap window's bin. One table stands in both doors rather than two copies that could
-- drift apart; when a door ever needs a piece of its own, it gets its own table beside this one.
local FOREVER_KEEP = {
  -- Fishing poles.
  [6256] = true,  -- Fishing Pole
  [6365] = true,  -- Strong Fishing Pole
  [6367] = true,  -- Big Iron Fishing Pole
  [12225] = true, -- Blump Family Fishing Pole
  [19022] = true, -- Nat Pagle's Extreme Angler FC-5000
  [19970] = true, -- Arcanite Fishing Pole
  [285094] = true, -- Ravaged Fishing Pole

  -- Skinning knives.
  [7005] = true,   -- Skinning Knife
  [269716] = true, -- Keen Skinning Knife

  -- Mining and blacksmithing tools.
  [5956] = true,   -- Blacksmith Hammer
  [756] = true,    -- Tunnel Pick
  [2901] = true,   -- Mining Pick
  [4616] = true,   -- Ryedol's Lucky Pick
  [278423] = true, -- Monster - Mining Pick

  -- The other trades' tools.
  [6219] = true,   -- Arclight Spanner
  [2808] = true,   -- Torch of Flame
  [271965] = true, -- Jewelcrafting Chisel

  -- Enchanting rods.
  [6218] = true,  -- Runed Copper Rod
  [6339] = true,  -- Runed Silver Rod
  [11130] = true, -- Runed Golden Rod
  [11145] = true, -- Runed Truesilver Rod
  [16207] = true, -- Runed Arcanite Rod

  -- The wear that carries a trade's bonus.
  [10919] = true,  -- Apothecary Gloves
  [7349] = true,   -- Herbalist's Gloves
  [282655] = true, -- Bog Pickers
  [19972] = true,  -- Lucky Fishing Hat
  [19969] = true,  -- Nat Pagle's Extreme Anglin' Boots
  [19971] = true,  -- High Test Eternium Fishing Line
  [5444] = true,   -- Miner's Cape
  [10542] = true,  -- Goblin Mining Helmet
  [5199] = true,   -- Smelting Pants
  [872] = true,    -- Rockslicer

  -- The stations a profession deploys, and the camp that stands beside them.
  [279944] = true, -- Sharpening Wheel
  [279988] = true, -- Anvil
  [279955] = true, -- Master Forge
  [279950] = true, -- Reagent Bot
  [279949] = true, -- Repair Bot
  [279989] = true, -- Anarchist's Workbench
  [279978] = true, -- Camp Tent
  [279941] = true, -- Tanning Rack
  [279945] = true, -- Sewing Machine
  [279972] = true, -- Faction Banner, first variant
  [279973] = true, -- Faction Banner, second variant
  [279943] = true, -- Spinning Wheel
  [279959] = true, -- Loom
  [279948] = true, -- Rock Garden
  [279952] = true, -- Molten Foundry
  [279961] = true, -- Journeyman Campfire Kit
  [279957] = true, -- Cookie's Feast
  [279974] = true, -- Expert Campfire Kit
  [279982] = true, -- Iron Oven
  [279967] = true, -- Fish Bowl
  [279965] = true, -- Fishing Rack
  [279966] = true, -- Fishing Hut
}

-- The locked boxes of the Forever client: nine lockboxes, four chests a fishing cast pulls up and four
-- junkboxes, all with the classic ids the server never changed (checked one by one against its own database,
-- build 1.60.1.70938, where every one of them is filed as Miscellaneous / Junk). Nothing here is a retail id that
-- happens to mean something else: only what the client answered for. A box on this client is worth 50 copper to
-- 5 silver, which is exactly the price band the cheap window watches, so without these lines a junkbox is the
-- one piece the list would offer to throw away.
--
-- Two kinds of box are left out on purpose. A quest box (Lucius's Lockbox, Silver Dawning's, the thaumaturgy
-- vessel) is kept by the quest flag already, so an id here would be a second answer to a question that is
-- answered -- and Lucius's is a quest item whose tooltip carries no lock at all. Mysterious Lockbox is filed as
-- a consumable, so the potion switch already holds it.
local FOREVER_LOCKBOX = {
  [4632] = true, -- Ornate Bronze Lockbox
  [4633] = true, -- Heavy Bronze Lockbox
  [4634] = true, -- Iron Lockbox
  [4636] = true, -- Strong Iron Lockbox
  [4637] = true, -- Steel Lockbox
  [4638] = true, -- Reinforced Steel Lockbox
  [5758] = true, -- Mithril Lockbox
  [5759] = true, -- Thorium Lockbox
  [5760] = true, -- Eternium Lockbox
  [6354] = true, -- Small Locked Chest
  [6355] = true, -- Sturdy Locked Chest
  [13875] = true, -- Ironbound Locked Chest
  [13918] = true, -- Reinforced Locked Chest
  [16882] = true, -- Battered Junkbox
  [16883] = true, -- Worn Junkbox
  [16884] = true, -- Sturdy Junkbox
  [16885] = true, -- Heavy Junkbox
}

-- The reagents a class will not cast without, on Forever: the pieces a spell takes with it, which the cheap
-- window would otherwise offer at a few silver a stack because that is exactly what a vendor pays for them. No
-- kind covers them -- half are plain trade goods, sold beside copper ore, and the trade good class is what a
-- sweep is allowed to take -- so the ids are written out, grouped by the class they belong to.
--
-- Both doors, not just the bin: an alt-click in the bags marks a stack for the merchant, and the row beside the
-- one meant is one row away, so a vial or a seed must not depend on that hand either. A piece the merchant door
-- refuses keeps its way out only through an explicit sale of something the player chose to part with.
--
-- The poisons themselves are not here: they are consumables, and the potion switch already holds them. These are
-- what a poison, a prayer or a teleport is made of.
local FOREVER_REAGENT = {
  -- Rogue: the reagents a poison is crafted from, sold by the poison vendors, plus the one herb a Vanish costs.
  [2928] = true, -- Dust of Decay
  [2930] = true, -- Essence of Pain
  [3371] = true, -- Empty Vial
  [3372] = true, -- Leaded Vial
  [5173] = true, -- Deathweed
  [3818] = true, -- Fadeleaf (Blinding Powder)

  -- Mage: Teleport, Portal and Arcane Brilliance.
  [17031] = true, -- Rune of Teleportation
  [17032] = true, -- Rune of Portals
  [17020] = true, -- Arcane Powder

  -- Warlock: the Inferno and the Ritual of Doom.
  [5565] = true,  -- Infernal Stone
  [16583] = true, -- Demonic Figurine

  -- Druid: Rebirth, one seed per rank, and the two Gift of the Wild reagents.
  [17034] = true, -- Maple Seed (Rebirth I)
  [17035] = true, -- Stranglethorn Seed (Rebirth II)
  [17036] = true, -- Ashwood Seed (Rebirth III)
  [17037] = true, -- Hornbeam Seed (Rebirth IV)
  [17038] = true, -- Ironwood Seed (Rebirth V)
  [17021] = true, -- Wild Berries (Gift of the Wild I)
  [17026] = true, -- Wild Thornroot (Gift of the Wild II)

  -- Priest: the three prayers.
  [17028] = true, -- Holy Candle (Prayer of Fortitude I)
  [17029] = true, -- Sacred Candle (Prayer of Fortitude II, of Spirit, of Shadow Protection)

  -- Shaman: Reincarnation.
  [17030] = true, -- Ankh

  -- Paladin: the greater blessings and Divine Intervention.
  [21177] = true, -- Symbol of Kings
  [17033] = true, -- Symbol of Divinity
}

-- The keep list and the class reagents fill both doors, the boxes fill the bin's alone. A reagent is as easy to
-- lose at a merchant as in the bin: the mark for sale is one alt-click in the bags, and an alt-click lands on the
-- row beside the one meant often enough that a stack of seeds or a poison vial should not depend on it. The boxes
-- stay open to a sale, because a box is worth something to a merchant and the player may want the coin.
--
-- Built from the tables rather than written out by hand, so an id added to one cannot be forgotten in the other --
-- two copies of a rule are how the doors start to disagree about a piece.
local FOREVER_SALE = {}
for id in pairs(FOREVER_KEEP) do FOREVER_SALE[id] = true end
for id in pairs(FOREVER_REAGENT) do FOREVER_SALE[id] = true end

local FOREVER_DELETE = {}
for id in pairs(FOREVER_SALE) do FOREVER_DELETE[id] = true end
for id in pairs(FOREVER_LOCKBOX) do FOREVER_DELETE[id] = true end

local FOREVER = {
  sale = FOREVER_SALE,
  delete = FOREVER_DELETE,
}

local live = ns.IsForever and FOREVER or RETAIL

-- Which kinds a delete leaves alone, by the client's own class rather than by id: a health potion exists in
-- hundreds of forms and every expansion writes new ones, while the class that says "this is a use-item" never
-- changes. Each kind has a switch on the Cheap page and is on out of the box; the id sets above stay for the
-- exceptions a kind cannot name.
--
-- Kinds are the delete door's alone. Selling is a deliberate gesture -- the player marked the piece and pressed
-- the coin -- and a merchant still takes a potion that was marked; a destroy is one click and has no such
-- second thought behind it.
local function keptKind(key)
  return not (WarpeeDB and WarpeeDB[key] == false)
end

-- C_ToyBox and C_MountJournal throw on an id they do not know on some builds, so every answer is asked in a
-- pcall and a false is a false either way.
local function asks(fn, arg)
  if not fn then return false end
  local ok, answer = pcall(fn, arg)
  return ok and answer and true or false
end

local function collectible(id, classID)
  if classID == (Enum.ItemClass.Battlepet) then return true end
  if asks(C_ToyBox and C_ToyBox.IsToyItem, id) then return true end
  if asks(C_MountJournal and C_MountJournal.GetMountFromItem, id) then return true end
  return false
end

local function itemClass(id)
  if not (C_Item and C_Item.GetItemInfoInstant) then return nil end
  local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(id)
  return classID
end

-- A bag is furniture, not stock: it holds what the player owns, and a destroy takes the bag together with
-- everything standing in it. No switch, because no bag is a thing to throw in the bin, and no list, because
-- the client files every bag -- and every ammo pouch -- the same way. The merchant door is left alone: a bag
-- the player marked for sale is one they decided to part with.
local function isContainer(classID)
  local C = Enum and Enum.ItemClass
  if not (C and classID) then return false end
  return classID == C.Container or (C.Quiver ~= nil and classID == C.Quiver) or false
end

-- Ammunition is a piece the shot takes with it: a stack of arrows is worth a few copper, which is the price band
-- the sweep watches, and a hunter whose quiver is empty cannot shoot at all. Every arrow and every bullet is
-- class 6, so the class answers here and no id has to be listed -- the next expansion's ammo is covered the day
-- it drops, and nothing else in the game shares the class.
local function isAmmo(classID)
  local C = Enum and Enum.ItemClass
  if not (C and classID) then return false end
  return C.Projectile ~= nil and classID == C.Projectile or false
end

local function deletedKind(id, classID)
  local C = Enum and Enum.ItemClass
  if not (C and classID) then return false end
  -- No early return between the kinds: the client files some toys as plain consumables, so a toy must still be
  -- kept when the consumable switch is off and the collectible one is on.
  if classID == C.Consumable and keptKind("cheapKeepConsumable") then return true end
  if classID == C.Recipe and keptKind("cheapKeepRecipe") then return true end
  if keptKind("cheapKeepCollectible") and collectible(id, classID) then return true end
  return false
end

-- Whether a piece is kept from a door: "sale" for a merchant, "delete" for the cheap window's destroy. A
-- delete asks the sale's set too, so the two doors can never disagree about a piece both would take.
-- Read as a question, never as a write: the sets are constants and no path may edit them.
function ns.ProtectedItem(id, door)
  if not id then return false end
  if live.sale[id] then return true end
  if door ~= "delete" then return false end
  if live.delete[id] then return true end
  local classID = itemClass(id)
  if isContainer(classID) or isAmmo(classID) then return true end
  return deletedKind(id, classID)
end
