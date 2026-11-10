local addonName, ns = ...

local reqPrefixes
local function requirementPrefixes()
  if reqPrefixes then return reqPrefixes end
  reqPrefixes = {}
  for _, key in ipairs({ "ITEM_MIN_LEVEL", "ITEM_REQ_SKILL", "ITEM_REQ_LEVEL", "ITEM_MIN_SKILL",
                         "ITEM_CLASSES_ALLOWED", "ITEM_REQ_REPUTATION", "ITEM_REQ_ARENA_RATING",
                         "ITEM_REQ_SPECIALIZATION" }) do
    local g = _G[key]
    if type(g) == "string" then
      local p = (g:match("^(.-)%%") or g):gsub("%s+$", ""):lower()
      if #p >= 3 then reqPrefixes[#reqPrefixes + 1] = p end
    end
  end
  return reqPrefixes
end

local function lineRed(col)
  return col and col.r and col.r > 0.9 and col.g < 0.2 and col.b < 0.2
end

local function typeMatch(a, b)
  if not (a and b) or #a < 3 or #b < 3 then return false end
  a, b = a:lower(), b:lower()
  return a:find(b, 1, true) ~= nil or b:find(a, 1, true) ~= nil
end

-- A requirement the character already meets is written in the item's data all the same, and it stays red:
-- the data is the item's own and knows nothing about who is reading it. The default tooltip hides such a
-- line, the raw C_TooltipInfo data keeps it -- which is why ordinary food whose only red line was a
-- requirement already met was ringed as unwearable. So a level line is read for its number and compared
-- with the character's own level: that tells a piece this character cannot wear yet from food it can eat,
-- using nothing but the item and the player, and without asking a client question that answered wrongly
-- (see the note in IsItemUnusable about the usable-yes that closed the question too early).
local levelPrefixes
local function requirementLevels()
  if levelPrefixes then return levelPrefixes end
  levelPrefixes = {}
  for _, key in ipairs({ "ITEM_MIN_LEVEL", "ITEM_REQ_LEVEL" }) do
    local g = _G[key]
    if type(g) == "string" then
      local p = (g:match("^(.-)%%") or g):gsub("%s+$", ""):lower()
      if #p >= 3 then levelPrefixes[#levelPrefixes + 1] = p end
    end
  end
  return levelPrefixes
end

local function levelMet(txt)
  if not txt then return false end
  local low = txt:lower()
  for _, pref in ipairs(requirementLevels()) do
    if low:find(pref, 1, true) == 1 then
      local n = tonumber(txt:match("(%d+)"))
      local lvl = UnitLevel and UnitLevel("player")
      return (n and lvl and lvl >= n) and true or false
    end
  end
  return false
end

-- Armour a class can put on, as a rank rather than a list of types: a class wears its own type and every
-- lighter one, in every era the addon runs on -- a warrior's cloth, a hunter's leather before the mail
-- levels -- so one number per class answers it everywhere. This is the one "cannot wear this" a snapshot can
-- still work out for a character who has not logged in since its record was written: the item says its
-- armour type, the save says the class, and neither depends on a level. Shields are left out on purpose
-- (which classes may carry one moved between eras) and so is everything that is not armour, where the
-- answer would be a guess rather than a fact.
-- Declared here because the reader below it needs it: the client's own yes/no, defined with the rest of
-- the client readers once the tooltip helpers are in place (a forward local, so the call resolves).
local clientCanUse

local ARMOUR_RANK = { [1] = 1, [2] = 2, [3] = 3, [4] = 4 } -- cloth, leather, mail, plate
local CLASS_RANK = { WARRIOR = 4, PALADIN = 4, DEATHKNIGHT = 4, HUNTER = 3, SHAMAN = 3, EVOKER = 3,
                     DRUID = 2, MONK = 2, ROGUE = 2, DEMONHUNTER = 2 }
local snapCan = {}
-- Links a saved box asked the client to describe. A record's link has no container behind it, so nothing else
-- ever asks for its item data: without this the box waits for a piece the client never loads, and the ring it is
-- owed never appears. Asked once per link, wiped with the verdicts.
local snapAsked = {}

-- A real equipment slot. "Non-equip" is a slot value too -- every consumable, gem and reagent carries
-- INVTYPE_NON_EQUIP_IGNORE -- and reading any non-empty equip location as "can be worn" turned the engine's
-- no on a piece of food or a gem into a red ring on it.
local function equippable(equipLoc)
  return type(equipLoc) == "string" and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE"
     and equipLoc ~= "INVTYPE_NON_EQUIP"
end

-- Whether the link names something worn or wielded at all. A record written before the non-equip slot was
-- understood can carry a refusal for a gem or a stack of food, so a reader asks this before believing one.
function ns.GearLink(link)
  if not link then return false end
  local _, _, _, equipLoc, _, classID = C_Item.GetItemInfoInstant(link)
  -- A quest object is not worn, even when it happens to carry an equip location: it belongs to a quest, and
  -- its red lines are about the quest, not about whether this character can wear it.
  if classID == Enum.ItemClass.Questitem then return false end
  if classID == Enum.ItemClass.Armor or classID == Enum.ItemClass.Weapon then return true end
  return equippable(equipLoc)
end

-- Whether this piece can carry the ring at all. Gear can, and so can a recipe or a plan: "you cannot use
-- this" there means a profession or a level the character has not reached, which is the same kind of answer
-- the ring makes everywhere else. Food, a gem and a reagent cannot -- their red lines are about a single use
-- ("already known", "unique"), not about the character -- and they keep their quality colour.
-- Whether the link names a toy. C_ToyBox knows, and a toy is used by learning it, like a recipe: the
-- profession it asks for is a requirement about this character, not about a single use.
local function isToyLink(link)
  if not (C_ToyBox and C_ToyBox.IsToyItem) then return false end
  local id = tonumber(tostring(link or ""):match("item:(%d+)"))
  if not id then return false end
  local ok, toy = pcall(C_ToyBox.IsToyItem, id)
  return ok and toy and true or false
end

function ns.RedLink(link)
  if not link then return false end
  local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(link)
  if classID == Enum.ItemClass.Recipe then return true end
  if isToyLink(link) then return true end
  -- "Miscellaneous" and "Permanent" are where the things that are used by studying them live: a profession
  -- treatise, a toy, a manual. They are not gear, but "you cannot use this" there is a profession or a level
  -- about this character, which is exactly what the ring says. These are judged by the client alone -- no
  -- tooltip scan -- so a red "unique" or "already known" line cannot ring them.
  if classID == Enum.ItemClass.Miscellaneous or classID == Enum.ItemClass.Permanent
     or classID == Enum.ItemClass.Glyph then return true end
  return ns.GearLink(link)
end

-- Whether the tooltip's own red lines may decide the ring. Gear and recipes only: a plate chest says "Plate"
-- in red, a stack of food says "requires level" in red, and only the first of those means "cannot wear". A
-- piece of armour whose slot is not an armour type -- a shirt, a tabard, a trinket, a ring, a neck, a cloak --
-- is left out of the broad colour read: those carry cosmetic and hidden lines of their own ("already known",
-- a profession the character has met), and taken at their colour they ring a piece the character can use. Their
-- own required level is not lost: the requirement scan runs ahead of this, and the snapshot rule weighs the
-- level number directly.
function ns.ScanLink(link)
  if not link then return false end
  local _, _, _, _, _, classID, subID = C_Item.GetItemInfoInstant(link)
  if classID == Enum.ItemClass.Recipe then return true end
  if classID == Enum.ItemClass.Glyph then return true end
  if classID == Enum.ItemClass.Weapon then return true end
  return (classID == Enum.ItemClass.Armor and ARMOUR_RANK[subID] ~= nil) and true or false
end

-- Whether the character looking at a saved record could wear what it holds, answered when the record is
-- read instead of making that character revisit the bank to have it recorded: the record remembers the
-- item, the question is about the reader. Three answers, strongest evidence first -- the armour rank (a
-- class wears its own type and every lighter one, in every era, and needs no level), the engine's own
-- yes/no for this character, and the item's required level against the reader's. A piece that is not gear
-- with a slot never gets a verdict here, and nil stays nil: nothing is guessed.
function ns.SnapshotCanUse(link, class, lvl, own)
  if not link then return nil end
  local key = link .. "|" .. tostring(class) .. "|" .. tostring(lvl) .. "|" .. tostring(own and 1 or 0)
  local hit = snapCan[key]
  if hit and hit.v ~= nil then return hit.v end
  -- A "no answer" is never remembered: it means the item's own data had not landed, and keeping it is what left
  -- a whole saved box unringed while the very same question, asked a second later, answered "no". A nil costs
  -- one read on the next paint and nothing else.
  local v
  local _, _, _, equipLoc, _, classID, subID = C_Item.GetItemInfoInstant(link)
  -- The instant read is not always the whole story: links the record kept from a crafted or bonus-dressed
  -- piece come back with an id and nothing else, while the full read has the type and the slot. Asking only
  -- the instant one left every such piece with no answer at all, which is a snapshot quietly unringed.
  if not classID or not equipLoc then
    if C_Item.GetItemInfo then
      -- The full read is a list of returns, not a table: the slot is the 9th, the class the 12th and the
      -- subtype the 13th. The name is the only thing that says the client described the item at all.
      local name, _, _, _, _, _, _, _, loc, _, _, cid, sid = C_Item.GetItemInfo(link)
      if name then
        classID = classID or cid
        subID = subID or sid
        equipLoc = equipLoc or loc
      end
    end
  end
  -- An item the client has not described yet cannot be answered or remembered: its type and slot are exactly
  -- what the answer is made of, so a verdict computed from "no type yet" is a guess that would then stick
  -- for the rest of the session -- which is one plate chest ringed and the next not. A slot it does report is
  -- enough to judge it as a worn piece, so only a link with neither is left unanswered, and nothing is cached:
  -- the next paint asks again.
  if not classID and not (equipLoc and equippable(equipLoc)) then return nil end
  local info, minLvl
  if C_Item.GetItemInfo then
    -- The same list again: the name says the data landed, the 5th return is the level the item requires.
    local name, _, _, _, req = C_Item.GetItemInfo(link)
    info, minLvl = name, req
  end
  if not info and not snapAsked[link] and C_Item.RequestLoadItemDataByID then
    snapAsked[link] = true
    local iid = select(1, C_Item.GetItemInfoInstant(link))
    if iid then pcall(C_Item.RequestLoadItemDataByID, iid) end
  end
  local rank = ARMOUR_RANK[subID]
  -- A worn piece whose armour type the rank table knows, or a weapon: the two kinds where the client's own
  -- no can only mean a level, a class or a proficiency. An armour piece with no armour type -- a shirt, a
  -- tabard, a trinket, a ring, a neck -- is not weighed by the engine: its no can be about a cosmetic that is
  -- already known, which is not a reason to ring it.
  local worn = (classID == Enum.ItemClass.Armor and rank ~= nil) or classID == Enum.ItemClass.Weapon
  -- A class missing from the table is a cloth class: the table names the heavier types only, and every
  -- class wears cloth, so the rank is 1 rather than "unknown".
  local viewerRank = class and (CLASS_RANK[class] or 1)
  -- The level to weigh is the character logged in, which is who every snapshot ring answers for; `lvl` is the
  -- caller's own reading of it and is used only when the question is asked about a record owner explicitly.
  -- The client's answer likewise only ever speaks about the logged-in character.
  local who = own and (UnitLevel and UnitLevel("player")) or lvl
  -- What the item's own tooltip says about this character: a profession, a class, a specialization. Those lines
  -- are about whoever reads them, so they hold for another character too -- unlike the engine, which only ever
  -- speaks about the character logged in.
  local function requirementBlocked()
    return (ns.RequirementBlocked and ns.RequirementBlocked(link)) and true or false
  end
  local function engineNo()
    -- The engine's no is evidence only for something worn and wielded in the ordinary sense: real armour or a
    -- weapon. On a quest object, a bag, a toy, a treatise, a shirt or a trinket it can answer about a single
    -- use, an "already known" or a cosmetic, which is not what the ring means; those are decided by the item's
    -- own red requirement line below, never by this answer.
    return own and worn and clientCanUse(link) == false
  end
  -- A consumable -- food, a potion, an elixir -- is ringed for exactly one reason: the level it requires is above
  -- the character who would use it. Food the character can already eat is never ringed, and none of its red
  -- tooltip lines are read for this: they name a single use ("already known", "unique"), not a level.
  local tooLowToUse = classID == Enum.ItemClass.Consumable
                      and minLvl and minLvl > 0 and who and who > 0 and who < minLvl
  -- Worn, or learned and then used: the kinds this ring is for at all. Food, a gem, a reagent, a pet and the
  -- rest are not -- their red lines are about a single use, not about the character.
  local ringable = classID == Enum.ItemClass.Armor or classID == Enum.ItemClass.Weapon
                   or classID == Enum.ItemClass.Recipe or classID == Enum.ItemClass.Miscellaneous
                   or classID == Enum.ItemClass.Permanent or classID == Enum.ItemClass.Glyph
                   or (ns.RedLink and ns.RedLink(link)) or false
  if tooLowToUse then
    -- The one level a stack of food or a potion can ask for, weighed against the character looking at it.
    v = false
  elseif not ringable then
    -- Food, a gem, a reagent, a pet: red lines here are about a single use (a stack, a level on the stack, "already
    -- collected") and never about wearing, so nothing is decided and nothing is ringed. Food above the character's
    -- level was handled above; a toy the client files as a plain consumable is covered further up by ns.RedLink.
  elseif classID == Enum.ItemClass.Armor and rank and viewerRank and rank > viewerRank then
    -- A type this class never wears, in any era: no level and no client answer changes that.
    v = false
  elseif engineNo() then
    v = false
  elseif not worn and requirementBlocked() then
    -- A requirement line on a learned or studied thing -- or on an armour piece that is not a worn type, like a
    -- shirt or a trinket: its profession, class or standing, which the client does not weigh. A real worn piece
    -- is left out on purpose -- its own red lines can name a restriction the character has already met (the raw
    -- tooltip keeps such a line, and keeps it red), and the rank, the engine's answer and the level below are
    -- what decide a worn piece everywhere else in this add-on.
    v = false
  elseif minLvl and minLvl > 0 and who and who > 0 and who < minLvl then
    -- The required level, weighed whoever is asking: the engine's yes is about class and proficiency, and a
    -- piece the character is too low for is still a no.
    v = false
  elseif classID == Enum.ItemClass.Armor and rank and viewerRank then
    -- The type is one this class wears, in every era and without a level: that is evidence of its own, and the
    -- one answer the armour rule gives when the client says nothing about the piece.
    v = true
  elseif minLvl and minLvl > 0 and who and who > 0 then
    -- Nothing blocks and the level was actually weighed: that is a yes.
    v = true
  end
  -- The client's yes is never taken. On this client it answers yes for pieces the character plainly cannot wear,
  -- and a yes believed here is a ring that never appears on a piece whose required level had not streamed in
  -- yet -- which is most of a saved box on the first pass.
  -- No level and no engine answer leaves "nothing is known": v stays nil, and the next paint asks again.
  -- A table, not a bare value: a cached nil and an absent key have to stay tellable apart, or a second paint
  -- pays the read again forever.
  if v ~= nil then snapCan[key] = { v = v } else snapCan[key] = nil end
  return v
end

local unusableCache = {}
local warboundCache = {}
-- Links the client never answered for. Kept apart from the verdicts: a link here has no verdict, and what
-- is remembered is that asking again is pointless. Without it a cell whose slot the client has no item for
-- (a snapshot record, a pinned ghost) paid a tooltip read on every repaint and never got an answer to keep.
local hopeless = {}
-- How many times a link has been asked about without an answer yet. Beside the caches because it is
-- wiped with them: the same level or reputation change that moves a verdict makes the old count stale.
local retries = {}

-- Everything here answers "what does this item look like right now", so it goes together:
-- a level, a reputation, a rating or a spec change can move any of these verdicts and none
-- of the caches can tell on its own which one it was. This is the only path that clears
-- them, so it is also what keeps them from growing for a whole session.
function ns.ClearUnusableCache()
  wipe(unusableCache)
  wipe(warboundCache)
  wipe(retries)
  wipe(hopeless)
  wipe(snapCan)
  wipe(snapAsked)
  ns.ClearWarboundMeta()
end

local function knownVerdict(link)
  return unusableCache[link]
end

local function keepVerdict(link, bad)
  unusableCache[link] = bad
end

-- Asking for a verdict costs a tooltip read, and a layout asks for one per cell: a full bank
-- or a vault is hundreds of them inside one script, which is more than the client sits
-- through before it stops the pass with "script ran too long". So a pass only scans while it
-- has time left, the rest of the links wait their turn, and the answer arrives over the next
-- few frames, when the cells that hold those links are painted (see ns.PaintVerdicts).
local queue, queued, armed = {}, {}, false
-- Links whose old answer was dropped for arriving data: their cells are painted whichever way the new answer
-- lands, since a verdict that turned from red to fine has a ring to take down. Read by the drain below.
local stale = {}

local drain

local function askNextFrame(link, bag, slot)
  local e = queued[link]
  if e then
    if bag and not e.bag then e.bag, e.slot = bag, slot end
    return
  end
  e = { link = link, bag = bag, slot = slot }
  queued[link] = e
  queue[#queue + 1] = e
  if not armed then
    armed = true
    C_Timer.After(0, drain)
  end
end

drain = function()
  armed = false
  ns.ReportEntry()
  local hit, done, hits = false, 0, nil
  while done < #queue and not ns.OutOfTime() do
    done = done + 1
    local e = queue[done]
    local bad
    if e.bag then bad = ns.IsItemUnusable(e.bag, e.slot, e.link)
    else bad = ns.IsLinkUnusable(e.link) end
    -- The links that came back bad are kept, not just the fact that one did: the ring they earn is
    -- drawn on the cells that hold them, and those cells are the whole of what has to paint.
    -- A link whose old answer was dropped for arriving data is painted whatever the new answer is: a verdict that
    -- changed from red to fine has a ring to take down, and one that stayed red is painted where it stands.
    if bad or stale[e.link] then hit = true; hits = hits or {}; hits[e.link] = true end
    stale[e.link] = nil
    queued[e.link] = nil
  end
  if done > 0 then
    local rest = {}
    for i = done + 1, #queue do rest[#rest + 1] = queue[i] end
    queue = rest
  end
  if #queue > 0 then
    armed = true
    C_Timer.After(0, drain)
    return
  end
  if hit then
    -- A verdict that lands after the pass that asked for it changes one thing on one cell: the red ring of
    -- the unusable read. Painting the windows for it -- every cell of the bags and of the bank -- is what a
    -- bank open paid a second time once the queue emptied, a beat after the window was up, and it read as a
    -- second wave of cells arriving. The cells that hold the links are painted instead, and only those.
    if ns.PaintVerdicts then ns.PaintVerdicts(hits)
    elseif ns.RepaintSoon then ns.RepaintSoon() end
  end
end

-- An item the client has not described yet is not a verdict. Right after a login the bags can hold pieces
-- whose data has not streamed in, and GetItemInfoInstant answers nil for them -- and that nil was read as
-- "not equipment", which wrote a "fine" into the cache for the rest of the session. That is why the red
-- ring sometimes did not come at all until the next /reload, by which time the client knew the item: the
-- answer had already been given, and given wrongly, from an ignorance that looked like a fact. So an
-- item with no class is asked for its data and the link comes back a beat later, a few times at most:
-- a link the client never answers for is not a verdict either, and retrying it all session would be a
-- timer that never stops.
local RETRY_DELAY, RETRY_MAX = 1, 5

local function unknownItem(link)
  if select(6, C_Item.GetItemInfoInstant(link)) then return false end
  local id = tonumber((link or ""):match("item:(%d+)"))
  if id and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
  return true
end

local function retryLater(link, bag, slot)
  local n = (retries[link] or 0) + 1
  retries[link] = n
  if n > RETRY_MAX then
    -- Asked as often as it is worth asking: the next paint must not pay another read for it.
    hopeless[link] = true
    return
  end
  C_Timer.After(RETRY_DELAY, function() askNextFrame(link, bag, slot) end)
end

-- The client's own answer, when it has one: whether this character can use the item at all -- its level,
-- class, proficiency, profession and reputation in one call. C_PlayerInfo.CanUseItem is the modern name
-- (10.0.5+, and the 12.1 engine Forever runs has it too); C_Item.IsUsableItem and the bare global are the
-- older ones, and the global went away in 12.1.5. nil means no client API could answer, which is not a
-- verdict either way.
function clientCanUse(link)
  local id = tonumber((link or ""):match("item:(%d+)"))
  if not id then return nil end
  local info = _G.C_PlayerInfo
  local yes
  -- Only a real boolean is an answer. These calls return nil for an item whose data has not landed yet --
  -- which is most of a saved box on the first pass -- and reading that nil as `== true` turned "the client
  -- does not know this id" into "the client says no", ringing shirts and trinkets that were never refused.
  if info and info.CanUseItem then
    local ok, can = pcall(info.CanUseItem, id)
    if ok and type(can) == "boolean" then yes = can end
  elseif C_Item and C_Item.IsUsableItem then
    local ok, can = pcall(C_Item.IsUsableItem, link)
    if ok and type(can) == "boolean" then yes = can end
  elseif _G.IsUsableItem then
    local ok, can = pcall(_G.IsUsableItem, link)
    if ok and type(can) == "boolean" then yes = can end
  end
  return yes
end

-- The same yes/no for the character who is logged in, for the capture to write down: a snapshot is taken
-- while its character is the player, so this is the one moment the client can say what that character can
-- wear. Asked per item, no tooltip scan, and nil stays nil -- an item the client has not described yet is
-- not a verdict and must not be filed as one.
ns.ClientCanUse = clientCanUse

-- Red lines an item says for reasons that are not "you cannot wear this now". Everything else red is a
-- block, in whatever words the client chooses: the sentences a requirement is written in are the part of
-- a tooltip every patch rewrites, and a list of the ones we know is a list that is always one patch
-- behind -- which is how a piece that plainly says "requires" in red keeps its quality colour. So the few
-- red lines that mean something else are named and the rest are taken at their colour.
local notBlocking
local function nonBlocking()
  if notBlocking then return notBlocking end
  notBlocking = {}
  -- Read by name, not by value: a nil in a table constructor ends ipairs at that hole, so one missing
  -- global in one locale would silently drop every name after it.
  for _, key in ipairs({ "ITEM_SCRAPABLE_NOT", "CANNOT_UNEQUIP_COMBAT", "ITEM_DISENCHANT_NOT_DISENCHANTABLE",
                         "ITEM_CANT_BE_DISENCHANTED", "ITEM_UNIQUE", "ITEM_UNIQUE_EQUIPPED",
                         "ITEM_ALREADY_KNOWN", "ITEM_CANT_BE_REFUNDED", "ITEM_WONT_BE_TRADABLE" }) do
    local g = _G[key]
    if type(g) == "string" and g ~= "" then
      notBlocking[g] = true
      notBlocking[(g:gsub("%s+$", ""))] = true
      notBlocking[(g:gsub("^%s+", ""))] = true
    end
  end
  return notBlocking
end

-- The effect lines: "Equip:", "Use:", "Chance on hit:", a set or socket bonus. They are printed in red while
-- the effect does not apply to this character -- a cloak whose attunement is for another specialization, a set
-- bonus that is not active yet -- and none of that is "you cannot wear this". Matched by prefix and in the
-- client's own wording, because the rest of the line is the effect's own text.
local notBlockingPrefix
local function nonBlockingPrefixes()
  if notBlockingPrefix then return notBlockingPrefix end
  notBlockingPrefix = {}
  for _, key in ipairs({ "ITEM_SPELL_TRIGGER_ONEQUIP", "ITEM_SPELL_TRIGGER_ONUSE", "ITEM_SPELL_TRIGGER_ONPROC",
                         "ITEM_SET_BONUS", "ITEM_SET_BONUS_GRAY", "ITEM_SOCKET_BONUS" }) do
    local g = _G[key]
    if type(g) == "string" then
      local p = (g:match("^(.-)%%") or g):gsub("%s+$", ""):lower()
      if #p >= 4 then notBlockingPrefix[#notBlockingPrefix + 1] = p end
    end
  end
  return notBlockingPrefix
end

local function isNonBlocking(txt)
  local skip = nonBlocking()
  if skip[txt] then return true end
  local low = txt:lower()
  for _, p in ipairs(nonBlockingPrefixes()) do
    if low:find(p, 1, true) == 1 then return true end
  end
  return false
end

-- The broad read: any red line that is not one of the named non-blocks. It is deliberately independent of
-- how a requirement is phrased, and it runs on every item rather than only on the classes that usually
-- carry one -- a restriction is the item's own business, not its class's.
local function redBlocked(data)
  for _, line in ipairs(data.lines) do
    if line.leftColor == nil and TooltipUtil and TooltipUtil.SurfaceArgs then
      TooltipUtil.SurfaceArgs(line)
    end
    if not (levelMet(line.leftText) or levelMet(line.rightText)) then
      -- A red line with no words on it blocks nothing: the client draws such a line as a blank separator, and
      -- taken at its colour it rang whatever carried it (see the same guard in scanRequirements).
      local lt, rt = line.leftText or "", line.rightText or ""
      if lt ~= "" and lineRed(line.leftColor) and not isNonBlocking(lt) then return true end
      if rt ~= "" and lineRed(line.rightColor) and not isNonBlocking(rt) then return true end
    end
  end
  return false
end

-- The engine's own answer for the character logged in, used only where it can be trusted to mean "cannot
-- wear": a piece of armour or a weapon. A false there is a requirement this character does not meet -- level,
-- class or proficiency -- and it is language-independent, so it is the one verdict that does not depend on how
-- a tooltip phrases a restriction. It is never used as a yes (a yes on this engine once closed the question
-- for pieces the character plainly could not wear, which is what took the ring off every bag at once); a
-- false is added to what the item's data already said. Everything else is decided by its red requirement line.
local function engineCannotWear(link)
  local _, _, _, _, _, classID, subID = C_Item.GetItemInfoInstant(link)
  -- Only a worn or wielded piece in the ordinary sense: real armour or a weapon. A quest object, a bag, a toy,
  -- a treatise or a recipe can get a no from this engine for reasons that are not "you cannot wear it" -- a
  -- single use, an "already known", a profession the character does not have -- and so can a shirt, a tabard or
  -- a trinket, whose armour type the rank table does not name. Those are read from the item's own requirement
  -- line instead. A weapon or a piece of real armour has no such alternative reading: the no there is a class,
  -- proficiency or level this character does not meet.
  local worn = classID == Enum.ItemClass.Weapon
               or (classID == Enum.ItemClass.Armor and ARMOUR_RANK[subID] ~= nil)
  if not worn then return false end
  return clientCanUse(link) == false
end

-- Profession equipment names the profession it asks for in the type line itself, and the client prints that
-- line red while the character lacks it: "Tailoring Tool" says nothing of the wording the scans below know,
-- and its type is only the last word ("Tool"), so the slot compare and the prefix list both walked past it --
-- a tailoring tool was the one piece of a box that never took the ring, in the bags and in another
-- character's snapshot alike. The slot is the giveaway: on a profession slot a red line has one meaning.
-- The slot, or the class the client files it under when the slot comes back empty: a profession tool is
-- "PROFESSION_TOOL" in one read and class 19 in another, and either one says the same thing.
local function professionGear(equipLoc, classID)
  if classID and Enum.ItemClass.Profession and classID == Enum.ItemClass.Profession then return true end
  return type(equipLoc) == "string" and equipLoc:find("PROFESSION", 1, true) ~= nil
end

local function scanRequirements(link, data)
  local _, _, subType, equipLoc, _, classID = C_Item.GetItemInfoInstant(link)
  -- The slot's own name, and only when it has one. "INVTYPE_NON_EQUIP_IGNORE" -- the slot of everything that is
  -- not equipment -- is labelled by the client with an empty string, and an empty name matched the empty left text
  -- of a red line that carries no words at all: a treasure's tooltip ends with a red line of that shape, and the
  -- compare rang the item as unwearable while its tooltip showed nothing red anywhere (Burbling Blob of Paint).
  local slotName = (equipLoc and equipLoc ~= "" and _G[equipLoc]) or nil
  if slotName == "" then slotName = nil end
  local byProfession = professionGear(equipLoc, classID)
  local prefixes = requirementPrefixes()
  for _, line in ipairs(data.lines) do
    if line.leftColor == nil and TooltipUtil and TooltipUtil.SurfaceArgs then
      TooltipUtil.SurfaceArgs(line)
    end
    local txt = line.leftText or ""
    -- A requirement line whose number the character has already passed is not a block, whatever colour the
    -- data carries. Everything else is read as before.
    if not (levelMet(txt) or levelMet(line.rightText)) then
      if slotName and txt ~= "" and txt == slotName and (lineRed(line.leftColor) or lineRed(line.rightColor)) then
        return true
      end
      if lineRed(line.rightColor) and typeMatch(line.rightText, subType) then return true end
      -- The profession line, before any wording: a red type line on a profession slot is the profession the
      -- slot needs, however the client words it.
      if byProfession and txt ~= "" and (lineRed(line.leftColor) or lineRed(line.rightColor)) then return true end
      if lineRed(line.leftColor) then
        if subType and txt == subType then return true end
        local low = txt:lower()
        for _, pref in ipairs(prefixes) do
          if low:find(pref, 1, true) == 1 then return true end
        end
      end
    end
  end
  return false
end

-- Which red lines decide the ring for this link. Real armour and weapons keep the broad read (a red slot or
-- subtype line is a real block); everything else that can carry the ring -- a shirt, a trinket, a glyph, a toy,
-- a treatise -- is read for a requirement only, because "unique", "already known" and a cosmetic's own red
-- lines are red too and are not a wear requirement. requirementOnly is declared below and reached through this
-- forward local, since the reader here is defined before it.
local requirementOnly
local function ringScan(link, data)
  if scanRequirements(link, data) then return true end
  if ns.ScanLink(link) then return redBlocked(data) and true or false end
  return requirementOnly(link, data) and true or false
end

-- The verdict a capture writes down, for the character whose bags are being read: the same item data, read
-- off the slot the piece stands in, and nil when the answer would be a guess -- out of time, an item the
-- client has not described yet, a slot with no tooltip behind it. A record written with nil is rebuilt on the
-- next capture, which is how an old save fills itself in instead of being read for a verdict it never had.
function ns.CaptureCanUse(bag, slot, link)
  if not link then return nil end
  local hit = knownVerdict(link)
  if hit ~= nil then return hit end
  if hopeless[link] then return nil end
  if unknownItem(link) then return nil end
  -- A no the engine can give without any tooltip is written down as it stands: that is the answer a record
  -- saved on the character's own visit should carry, and waiting for a tooltip only left the field nil.
  if engineCannotWear(link) then keepVerdict(link, true); return true end
  if ns.OutOfTime() then return nil end
  local data = (bag and C_TooltipInfo and C_TooltipInfo.GetBagItem) and C_TooltipInfo.GetBagItem(bag, slot) or nil
  if not (data and data.lines) then return nil end
  local bad = ringScan(link, data)
  keepVerdict(link, bad)
  return bad
end

-- A piece the ring is not meant for can still answer no, but only on a requirement: a red line naming a level,
-- a class or a profession this character has not reached. "Unique", "already known" and an effect line never
-- decide it here, and neither does the engine -- a consumable's no can be about a stack or a use, not about the
-- character. This is what lets a toy the client files as a plain consumable (class 0) get its ring.
local skillPrefixes
local function nonLevelPrefixes()
  if skillPrefixes then return skillPrefixes end
  skillPrefixes = {}
  -- A profession, a class, a specialization, a reputation: the requirements that are about this character in a
  -- way no level answers. A red level line is left out on purpose -- a stack of food says one, and the ring is
  -- not for a single use -- and so is every line that is not a requirement at all.
  for _, key in ipairs({ "ITEM_REQ_SKILL", "ITEM_MIN_SKILL", "ITEM_CLASSES_ALLOWED", "ITEM_REQ_REPUTATION",
                         "ITEM_REQ_SPECIALIZATION", "ITEM_REQ_ARENA_RATING" }) do
    local g = _G[key]
    if type(g) == "string" then
      local p = (g:match("^(.-)%%") or g):gsub("%s+$", ""):lower()
      if #p >= 4 then skillPrefixes[#skillPrefixes + 1] = p end
    end
  end
  return skillPrefixes
end

requirementOnly = function(link, data)
  if not (data and data.lines) then return false end
  local prefixes = nonLevelPrefixes()
  -- The profession line of profession gear is a requirement without the wording of one: see scanRequirements.
  local byProfession = professionGear((select(4, C_Item.GetItemInfoInstant(link))),
                                      (select(6, C_Item.GetItemInfoInstant(link))))
  for _, line in ipairs(data.lines) do
    if line.leftColor == nil and TooltipUtil and TooltipUtil.SurfaceArgs then
      pcall(TooltipUtil.SurfaceArgs, line)
    end
    local txt = line.leftText or ""
    if txt ~= "" and lineRed(line.leftColor) then
      local low = txt:lower()
      for _, pref in ipairs(prefixes) do
        if low:find(pref, 1, true) == 1 then return true end
      end
    end
    if byProfession and txt ~= "" and (lineRed(line.leftColor) or lineRed(line.rightColor)) then return true end
  end
  return false
end

function ns.IsItemUnusable(bag, slot, link)
  if not link then return false end
  -- Only a piece that can carry the ring in the first place. A battle pet, a stack of food or a gem prints red
  -- lines about a single use ("already collected", "unique") and those are not "you cannot wear this" -- and
  -- because the verdict is cached, such a line used to ring the pet on arrival and on every move.
  if not ns.RedLink(link) then
    local other = knownVerdict(link)
    if other ~= nil then return other end
    if hopeless[link] or unknownItem(link) then return false end
    if not (C_TooltipInfo and C_TooltipInfo.GetBagItem) then return false end
    local data = C_TooltipInfo.GetBagItem(bag, slot)
    -- No lines is not "answered": but it is also not worth a read on every repaint, and the event that fills the
    -- item in clears this cache anyway.
    local bad = requirementOnly(link, data)
    keepVerdict(link, bad)
    return bad
  end
  local hit = knownVerdict(link)
  if hit ~= nil then return hit end
  if hopeless[link] then return false end
  if unknownItem(link) then retryLater(link, bag, slot); return false end
  -- The engine's no comes first, before any tooltip exists: it needs only the item id, and the beat after a
  -- login is exactly when the tooltip is empty -- the requirement lines had not streamed in, the scan found
  -- nothing to complain about, and that "fine" was then kept for the session, which is the ring that only
  -- appeared once the player moved the piece. It is read as a no only: a yes on this engine has been wrong
  -- about pieces the character plainly cannot wear, so a yes decides nothing and the item's own data keeps
  -- the last word below.
  if engineCannotWear(link) then
    keepVerdict(link, true)
    return true
  end
  -- Everything past this point is the tooltip, and only gear and recipes may be judged by it. A treatise or a
  -- toy is answered by the client above; its "unique"/"already known" lines are not a wear requirement.
  if not (C_TooltipInfo and C_TooltipInfo.GetBagItem) then return false end
  if ns.OutOfTime() then askNextFrame(link, bag, slot); return false end
  local data = C_TooltipInfo.GetBagItem(bag, slot)
  -- No tooltip is not "usable" either: the read can come back empty while the client is still filling
  -- in the item, and a bare false here left the cell without its ring and nothing to paint it later.
  if not (data and data.lines) then
    retryLater(link, bag, slot); return false
  end
  -- The wording of a requirement is not something to depend on, so the broad read has the last word: the
  -- precise one still runs first for the cases it knows, and anything it does not recognise but the item
  -- prints in red counts as a block.
  local bad = ringScan(link, data)
  keepVerdict(link, bad)
  return bad
end

-- The requirement scan alone, for a record that belongs to another character: those lines speak about
-- whoever reads them, so they answer for its owner too.
function ns.RequirementBlocked(link)
  if not link then return false end
  if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return false end
  return requirementOnly(link, C_TooltipInfo.GetHyperlink(link))
end

function ns.IsLinkUnusable(link)
  if not link then return false end
  if not ns.RedLink(link) then
    local other = knownVerdict(link)
    if other ~= nil then return other end
    if hopeless[link] or unknownItem(link) then return false end
    if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return false end
    local bad = requirementOnly(link, C_TooltipInfo.GetHyperlink(link))
    keepVerdict(link, bad)
    return bad
  end
  local hit = knownVerdict(link)
  if hit ~= nil then return hit end
  if hopeless[link] then return false end
  if unknownItem(link) then retryLater(link); return false end
  -- Same rule as the bag read: see IsItemUnusable, engine's no first and no tooltip needed for it. A link is
  -- asked about for cells with no slot behind them, and the requirement lines live in its tooltip data too.
  if engineCannotWear(link) then keepVerdict(link, true); return true end
  if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return false end
  if ns.OutOfTime() then askNextFrame(link); return false end
  local data = C_TooltipInfo.GetHyperlink(link)
  if not (data and data.lines) then retryLater(link); return false end
  local bad = ringScan(link, data)
  keepVerdict(link, bad)
  return bad
end

local wbLines
local function warboundLines()
  if wbLines then return wbLines end
  wbLines = {}
  for _, name in ipairs({ "ITEM_ACCOUNTBOUND_UNTIL_EQUIP", "ITEM_BIND_TO_ACCOUNT_UNTIL_EQUIP",
                          "ITEM_BNETACCOUNTBOUND_UNTIL_EQUIP", "ITEM_ACCOUNTBOUND",
                          "ITEM_BNETACCOUNTBOUND" }) do
    local g = _G[name]
    if type(g) == "string" and g ~= "" then wbLines[g:lower()] = true end
  end
  return wbLines
end

local function plainText(txt)
  if not txt then return nil end
  txt = txt:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  return txt:gsub("^%s+", ""):gsub("%s+$", ""):lower()
end

function ns.WarboundTooltip(data)
  if not (data and data.lines) then return false end
  local want = warboundLines()
  if not next(want) then return false end
  for _, line in ipairs(data.lines) do
    if line.leftText == nil and TooltipUtil and TooltipUtil.SurfaceArgs then
      TooltipUtil.SurfaceArgs(line)
    end
    local txt = plainText(line.leftText)
    if txt and want[txt] then return true end
  end
  return false
end

local ACCOUNT_BINDS
local function accountBinds()
  if ACCOUNT_BINDS then return ACCOUNT_BINDS end
  ACCOUNT_BINDS = {}
  local E = Enum and Enum.ItemBind
  if E then
    for _, key in ipairs({ "ToWoWAccount", "ToBnetAccount", "ToBnetAccountUntilEquipped",
                           "ToWoWAccountUntilEquipped" }) do
      if E[key] then ACCOUNT_BINDS[E[key]] = true end
    end
  end
  return ACCOUNT_BINDS
end

function ns.IsLinkWarbound(link)
  -- Forever retires the account-bound marker with the rest of the warband UI.
  if ns.IsForever then return false end
  if not link then return false end
  local hit = warboundCache[link]
  if hit ~= nil then return hit end
  local bad = false
  if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
    bad = ns.WarboundTooltip(C_TooltipInfo.GetHyperlink(link))
  end
  local bindType = select(14, C_Item.GetItemInfo(link))
  if not bad and bindType and accountBinds()[bindType] then bad = true end
  if bad or bindType then warboundCache[link] = bad end
  return bad
end
-- Item data arrives after the first paint. A cell drawn before the client has described the piece cannot be
-- answered for -- no type, no slot, no required level -- so it draws without its ring, and nothing used to ask
-- for it again: the ring appeared on a freshly looted item (its data was already there) and vanished after a
-- reload, where the grid was painted first and the data landed behind it. The arrival is what lets that link be
-- answered at last, so its saved answers are dropped and asked again.
--
-- Only that link's, though. A whole-cache wipe here is what a pointer moving across the bags showed as a
-- flicker: a login's worth of arrivals landed one after another, each one dropped every verdict in the addon,
-- and the repaint that followed painted cells whose answers were being computed again -- no ring for a beat, then
-- the answer lands and the ring is back. One item's data says nothing about another item's verdict.

-- Whether a cache key names this item id. Keys are a link, or a link with the question's own tail on it
-- ("|class|level|side"), so the id has to end where the item's does: "item:1901" must not claim "item:19019".
local function namesItem(key, id)
  if type(key) ~= "string" then return false end
  local head = "item:" .. id
  local at = key:find(head, 1, true)
  if not at then return false end
  local tail = key:sub(at + #head, at + #head)
  return tail == "" or tail == ":" or tail == "|" or tail == "]"
end

-- The links whose answers this one item's data can change, with those answers dropped. Nothing else is touched:
-- a cell on the other side of the window keeps the verdict it had.
local function forgetItem(id)
  if not id then return nil end
  local links, seen = {}, {}
  local function note(key)
    if not namesItem(key, id) then return end
    local l = key:match("(item:[^|]+)")
    if not l or seen[l] then return end
    seen[l] = true
    links[#links + 1] = l
  end
  for key in pairs(unusableCache) do note(key) end
  for key in pairs(warboundCache) do note(key) end
  for key in pairs(hopeless) do note(key) end
  for key in pairs(retries) do note(key) end
  for key in pairs(snapCan) do note(key) end
  for key in pairs(snapAsked) do note(key) end
  for _, l in ipairs(links) do
    unusableCache[l], warboundCache[l], hopeless[l] = nil, nil, nil
    retries[l], snapAsked[l] = nil, nil
    for key in pairs(snapCan) do
      if key:match("(item:[^|]+)") == l then snapCan[key] = nil end
    end
  end
  return links
end

local ringRepaint
local ringFrame = CreateFrame("Frame")
ringFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
ringFrame:SetScript("OnEvent", function(_, _, id)
  local links = forgetItem(id)
  if links then
    -- Asked now, painted when the answer is in: the drain repaints the cells that hold these links, so a cell is
    -- never painted while its verdict is being computed, which is what the flicker was.
    for _, l in ipairs(links) do
      stale[l] = true
      askNextFrame(l)
    end
  else
    -- An event with no id names nothing, so nothing can be spared: the whole cache goes, as it always did.
    ns.ClearUnusableCache()
  end
  if ringRepaint then return end
  ringRepaint = true
  local tries = 0
  -- The arrival is not always the last word: one pass can still be too early for the item whose event fired it,
  -- and a saved box keeps no verdict on a cell it could not answer for, so nothing revisits it. The ring's own
  -- pass asks again and repaints the answer; a handful of later ones is what closes the gap.
  local function pass()
    tries = tries + 1
    local B = ns.Bags
    if ns.SnapRingSoon then ns.SnapRingSoon() end
    -- A saved box is not re-laid out for this: that pass redraws every cell and the cells lose the craft tier
    -- the game had drawn on them, which is a box flickering and coming back plainer than it was. Its rings are
    -- painted on their own instead, over the picture that is already there. A live grid is not re-laid out
    -- either when the event named its item: those links are asked, and the drain paints the cells that hold them.
    if not links and B and B.frame and B.frame:IsShown() and not B.snap then
      if ns.RepaintSoon then ns.RepaintSoon() else B:Layout() end
    end
    if tries < 4 then C_Timer.After(0.6 * tries, pass) else ringRepaint = nil end
  end
  C_Timer.After(0.2, pass)
end)
