local addonName, ns = ...
local Theme = ns.Theme

local Rec = {}
ns.Recent = Rec
Rec.slots, Rec.ghosts = {}, {}

local MAX_SLOTS = 24
local SETTLE = 5

local cells, seq, known, got, base = {}, {}, {}, {}, {}
local missed, guidMiss, cellMiss = {}, {}, {}
local locBag, locSlot = {}, {}
local poor = {}
-- Items a scan saw in a slot but could not read yet: GetContainerItemInfo answers nil for an item whose
-- data has not reached the client (a gem just taken from the mail is the common case). The id is kept here
-- and its load requested, so the ITEM_DATA_LOAD_RESULT handler can run one more detect the moment it caches
-- -- the pass the arrival would otherwise never get, since taking the last item out of the mail is usually
-- the final bag event for a while.
local pending = {}
local counter = 0
local primed = nil
local guidNow, guidHad, everWorn, guidItem = {}, {}, {}, {}
local wornN = 0
local ILOC

-- The id the cursor is carrying, and when it last put one down. A split is C_Container.SplitContainerItem:
-- it lifts part of a stack onto the cursor and the piece only lands when a click drops it, so the cursor is
-- always the go-between. The plain "freeze while GetCursorInfo is set" guard is not enough: at pickup the
-- source slot shrinks and fires BAG_UPDATE a frame before the cursor reads as holding the item, so a pass
-- can slip in, read the shrunk total, and write it as the new baseline; then the piece landing reads as an
-- arrival of that difference and lists the player's own split. Stamping the id the moment the cursor shows
-- it (a CURSOR_CHANGED pass) and swallowing that id's next increase closes the window the freeze leaves open.
local carriedId, carriedAt, carrying = nil, 0, false
local CARRY_HOLD = 1.5
local function noteCursor()
  local t, id = GetCursorInfo()
  if t == "item" and id then
    carriedId, carrying = id, true
  elseif carrying then
    carrying, carriedAt = false, GetTime()
  end
end
local function fromCursor(id)
  return carriedId == id and (carrying or (GetTime() - carriedAt) < CARRY_HOLD)
end
-- Shared with the bags' new-on-top: the same "did this come off the cursor" test, one tracker, so a
-- hand-placed item or a split is told apart from an arrival in both places off one CURSOR_CHANGED feed.
ns.CursorHeldItem = fromCursor

local function itemGuid(bag, slot)
  local G = C_Item and C_Item.GetItemGUID
  if not (G and ItemLocation) then return nil end
  if not ILOC then
    if not ItemLocation.CreateEmpty then return nil end
    ILOC = ItemLocation:CreateEmpty()
    if not (ILOC and ILOC.SetBagAndSlot and ILOC.SetEquipmentSlot) then ILOC = nil; return nil end
  end
  if bag then ILOC:SetBagAndSlot(bag, slot) else ILOC:SetEquipmentSlot(slot) end
  if not C_Item.DoesItemExist(ILOC) then return nil end
  local ok, g = pcall(G, ILOC)
  return (ok and g) or nil
end

-- The row is drawn in two windows out of the one list, and each window has its own switch.
-- The key is written at login; a read that happens before that falls back to the old single
-- switch, which meant the same thing for both windows. Hiding a row and collecting an item are
-- separate on purpose: hiding the row in one window must not stop the list the other window is
-- still showing.
local function flag(key)
  local db = WarpeeDB
  if not db then return true end
  if db[key] == nil then return db.recentShow ~= false end
  return db[key] ~= false
end

function Rec:BagsOn() return flag("recentBags") end
function Rec:PocketOn() return flag("recentPocket") end

-- What the collection itself watches. With both switches off the list keeps its cells but takes
-- nothing new.
function Rec:Live() return self:BagsOn() or self:PocketOn() end

local FREEZE
local function frozen()
  local M = C_PlayerInteractionManager
  if not (M and M.IsInteractingWithNpcOfType and Enum and Enum.PlayerInteractionType) then
    return false
  end
  if not FREEZE then
    local IT = Enum.PlayerInteractionType
    FREEZE = {}
    for _, k in ipairs({ "Banker", "CharacterBanker", "AccountBanker", "GuildBanker",
                         "VoidStorageBanker" }) do
      if IT[k] then FREEZE[#FREEZE + 1] = IT[k] end
    end
  end
  for _, t in ipairs(FREEZE) do
    if M.IsInteractingWithNpcOfType(t) then return true end
  end
  return false
end

local function mailing()
  local M = C_PlayerInteractionManager
  local IT = Enum and Enum.PlayerInteractionType
  if not (M and M.IsInteractingWithNpcOfType and IT and IT.MailInfo) then return false end
  return M.IsInteractingWithNpcOfType(IT.MailInfo) and true or false
end

local function equipped(id)
  -- 12.1.5 removed the shim behind the bare IsEquippedItem, so the namespace is the only reader.
  local f = C_Item.IsEquippedItem
  return (f and f(id)) and true or false
end

local function capacity()
  local c = math.floor(tonumber(ns.Bags and ns.Bags.cols) or 14)
  return math.max(1, math.min(c, MAX_SLOTS))
end
local function scanBag(bag, counts)
  for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
    local info = C_Container.GetContainerItemInfo(bag, slot)
    local id = info and info.itemID
    -- A slot can hold an item the client has not read yet: GetContainerItemInfo answers nil for an item
    -- whose data has not arrived -- a gem just taken from the mail is the usual case. The slot would be
    -- skipped and the arrival lost, and the bag event that took it out of the mail is often the last one
    -- for a while, so the pass that would have caught it never comes. GetContainerItemID still gives the
    -- id (it needs no full data), so the load is asked for and the id noted; ITEM_DATA_LOAD_RESULT re-runs
    -- the pass once it caches, and that pass reads the slot in full and counts it the normal way.
    if not id then
      local pid = C_Container.GetContainerItemID and C_Container.GetContainerItemID(bag, slot)
      if pid then
        pending[pid] = true
        if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(pid) end
      end
    end
    if id then
      pending[id] = nil
      local g = ns.GearItem(id) and itemGuid(bag, slot) or nil
      if g then
        guidNow[g] = true
        -- The id the guid stands for this pass, so an arrival can be matched against the ids that just left
        -- an equipment slot even when the slot itself gives no guid to remember (see bodyDiff).
        guidItem[g] = id
        locBag[g], locSlot[g] = bag, slot
        if info.quality == 0 then poor[g] = true end
      else
        counts[id] = (counts[id] or 0) + (info.stackCount or 1)
        if info.quality == 0 then poor[id] = true end
        if not locBag[id] then locBag[id], locSlot[id] = bag, slot end
      end
    end
  end
end

local function tally()
  local counts = {}
  wipe(locBag); wipe(locSlot); wipe(poor)
  wipe(guidNow); wipe(guidItem)
  for _, bag in ipairs(ns.playerBags) do scanBag(bag, counts) end
  if ns.reagentBag then scanBag(ns.reagentBag, counts) end
  return counts
end

local function used()
  for i = 1, MAX_SLOTS do
    if cells[i] then return true end
  end
  return false
end

-- Seat a newly listed id. base is what the id held before this pass's increase, so the number the cell
-- wears is "how much it has grown since it appeared", read straight off the live total every pass. Nothing
-- is accumulated and nothing is clamped down, which is the whole point: an accumulated counter was clipped
-- by any pass that read short and could only be restored by an increase it did not swallow, so one bad
-- read left the row a piece behind the bags for the rest of the session.
local function mark(id, delta, total)
  base[id] = (total or 0) - (delta or 0)
  got[id] = delta
end

-- A cell that lost its item is held empty for HOLD seconds before the row closes up. The bags row is
-- clicked as a strip: a piece used, sold or handed to a banker vanishes under the hand, and a row that
-- closes in that same frame puts the next piece under the cursor. The grouped view holds its holes for
-- the same reason and on a much longer clock, because a piece there can come back from the bank; in
-- Recent nothing comes back, so this is only about the hand, and two seconds is long enough for the
-- second click of a pair and short enough not to hold a cell the row could be using. Both windows read
-- one list, so the hold is set here once and the pocket inherits it: its Feed sees the hole in the list
-- and leaves the cell standing until the same compaction closes both.
local HOLD = 2

-- A hole is a table in the cell: the piece is gone, its key is freed exactly as a plain removal freed
-- it (so the same item coming back is listed afresh), and the empty cell carries the order it had and
-- the moment it emptied. `seq` is read by Feed, `at` by compact.
local function ord(c)
  if type(c) == "table" then return c.seq or 0 end
  return seq[c] or 0
end

local closeAt
-- `at` is the moment the row should close, not a delay: a rebuild can leave a younger hole behind, and
-- its own deadline is what has to be armed next, or that cell would never close at all.
local function closeSoon(at)
  if closeAt and closeAt <= at then return end
  closeAt = at
  -- The hold has to end by itself: nothing else arrives to close the row in a quiet moment, and an empty
  -- cell standing past its hold reads as a slot that is really there. The layout is idempotent, so a pass
  -- that finds the row already closed costs nothing.
  C_Timer.After(math.max(0, at - GetTime()) + 0.05, function()
    closeAt = nil
    Rec:Refresh()
  end)
end

local function hole(i, key)
  local s, t = seq[key] or 0, GetTime()
  cells[i] = { hole = true, id = key, seq = s, at = t }
  seq[key], got[key], base[key] = nil, nil, nil
  cellMiss[key], missed[key] = nil, nil
  closeSoon(t + HOLD)
end

local function add(key, n, delta, total)
  if seq[key] then return end
  counter = counter + 1
  -- A piece that comes back into the bags takes its own hole back instead of gaining a second cell: the
  -- hole is the place it left, and the pocket reads the list by order, not by index, so restoring it
  -- there is the same move in both windows.
  for i = 1, n do
    local c = cells[i]
    if type(c) == "table" and c.id == key then
      cells[i], seq[key] = key, counter
      if delta then mark(key, delta, total) end
      return
    end
  end
  for i = 1, n do
    if not cells[i] then
      cells[i], seq[key] = key, counter
      if delta then mark(key, delta, total) end
      return
    end
  end
  local worn, age
  for i = 1, n do
    local c = cells[i]
    local s = ord(c)
    if c and (not age or s < age) then worn, age = i, s end
  end
  if not worn then return end
  local out = cells[worn]
  if type(out) ~= "table" then seq[out], got[out], base[out] = nil, nil, nil end
  cells[worn], seq[key] = key, counter
  if delta then mark(key, delta, total) end
end

local function compact(n)
  local ids, over, stale, soonest, now = {}, false, false, nil, GetTime()
  for i = 1, MAX_SLOTS do
    local c = cells[i]
    if c then
      -- An expired hole is what makes the row close up; a young one takes its place in the rebuild like
      -- any other cell, so the pieces after it do not move while it is held.
      if type(c) == "table" and (now - (c.at or 0)) >= HOLD then stale = true
      else
        ids[#ids + 1] = c
        if i > n then over = true end
        if type(c) == "table" then
          local at = (c.at or 0) + HOLD
          if not soonest or at < soonest then soonest = at end
        end
      end
    end
  end
  -- A rebuild can drop one hole and leave a younger one standing; that one still has to close on its own
  -- clock, so the next deadline is armed from what survived rather than from the call that made it.
  if soonest then closeSoon(soonest) end
  if not (over or stale or #ids > n) then return end
  table.sort(ids, function(a, b) return ord(a) < ord(b) end)
  for i = 1, MAX_SLOTS do cells[i] = nil end
  local cut = math.max(0, #ids - n)
  for k = 1, #ids do
    local c = ids[k]
    if k <= cut then
      -- A hole dropped by the cut was already freed when it was made; only a live key has anything to
      -- forget, and it is the one the row pushed out.
      if type(c) ~= "table" then seq[c], got[c], base[c] = nil, nil, nil end
    else
      cells[k - cut] = c
    end
  end
end

local function remove(id)
  for i = 1, MAX_SLOTS do
    if cells[i] == id then hole(i, id) end
  end
  seq[id], got[id], base[id] = nil, nil, nil
end

local function prune(counts)
  -- Nothing is counted or dropped while the cursor carries an item. A picked-up item is in
  -- no bag at all until it lands, so every key reads as gone for the pass, and the row would
  -- spend the forgiveness on the very items it is showing.
  if GetCursorInfo() then return false end
  local fence = false
  for i = 1, MAX_SLOTS do
    -- A hole is already decided: its piece left, and compact closes it once the hold runs out. Read as a
    -- key it would miss every pass and keep re-making its own hole, pushing the hold out forever.
    local c = cells[i]
    local key = (type(c) ~= "table") and c or nil
    local here = key and (type(key) == "string" and guidNow[key] or counts[key])
    if key and (not here or poor[key]) then
      -- Its own counter, not the one the known-item pass keeps: the two run over the same
      -- cell keys, so sharing it spent the forgiveness twice as fast on exactly the items
      -- the row is showing.
      local m = (cellMiss[key] or 0) + 1
      if m >= 3 or poor[key] then
        hole(i, key)
        cellMiss[key] = nil
      else
        cellMiss[key] = m
        fence = true
      end
    elseif key then
      cellMiss[key] = nil
    end
  end
  return fence
end

local shed, shedAt, body = {}, {}, {}
local SHED = 3

-- The character's own equipment is slots 1-19. Profession equipment sits past them: a tool and two
-- accessory slots for each of the two professions (20-25), then cooking and fishing (26-30). The paperdoll
-- never shows them, but the game swaps them like any other equipped piece -- the old one lands in the bag
-- slot the new one came from -- and GetInventoryItemID reads them like any other slot. Without them an old
-- tool coming back from the profession window read as recent loot: its id was never in shed and its guid
-- never in everWorn, since only the paperdoll was watched.
local BODY_LAST = 30

-- Returns whether any body slot answered at all, which is what tells a real empty inventory
-- apart from the client not being ready to answer.
local function bodyDiff()
  local f = GetInventoryItemID
  if not f then return true end
  local cut = GetTime() - SHED
  for id, t in pairs(shedAt) do
    if t < cut then shed[id], shedAt[id] = nil, nil end
  end
  local seen = false
  for s = 1, BODY_LAST do
    local now = f("player", s)
    -- The ready check stays on the paperdoll's own slots: a profession slot answering on its own must not
    -- talk the pass out of treating an empty read as the client between worlds.
    if now and s <= 19 then seen = true end
    local was = body[s]
    body[s] = now
    if was and was ~= now then
      shed[was] = (shed[was] or 0) + 1
      shedAt[was] = GetTime()
    end
    local g = itemGuid(nil, s)
    if g and not everWorn[g] then
      -- One entry per item ever seen equipped, and it has to last the whole session: an
      -- equipped item is not in the bags, so its guid leaves guidNow and this table is the
      -- only thing that stops it being offered as recent loot when it is swapped back. The
      -- cap is set high enough that a session of set swaps never reaches it.
      if wornN >= 4096 then wipe(everWorn); wornN = 0 end
      everWorn[g] = true
      wornN = wornN + 1
    end
  end
  return seen
end

local function pardon(id, delta)
  local n = shed[id]
  if not n then return delta end
  if GetTime() - (shedAt[id] or 0) > SHED then
    shed[id], shedAt[id] = nil, nil
    return delta
  end
  local eat = math.min(n, delta)
  if n > eat then shed[id] = n - eat else shed[id], shedAt[id] = nil, nil end
  return delta - eat
end

-- The guid path's version of pardon: a gear piece is keyed by guid, so the count delta it would pardon
-- never exists. The id the piece just held in the slot is the same evidence, and one piece coming back is
-- one arrival -- no counter to spend, only the age of the mark.
local function fromShed(id)
  if not id or not shed[id] then return false end
  if GetTime() - (shedAt[id] or 0) > SHED then
    shed[id], shedAt[id] = nil, nil
    return false
  end
  return true
end

-- Declared here because detect needs it: see the note on the miss counter in prune.
local soon

local function detect()
  local counts = tally()
  local seen = bodyDiff()
  -- Nothing is decided while the cursor carries an item, the same guard prune keeps. A split lifts part of
  -- a stack onto the cursor, so this pass would read the source slot as shrunk, write the smaller number as
  -- the new baseline, and then read the piece landing back down as an arrival, listing your own split as
  -- recent loot. Freezing the whole pass keeps known/got untouched until the piece lands, so the count on
  -- release matches the baseline and nothing is added. bodyDiff above still runs so equipment tracking
  -- stays live; guidHad/known persist across the skipped passes.
  if GetCursorInfo() then return end
  -- A pass that reads no item and no equipment at once is the client between worlds, not an
  -- emptied inventory: around a loading screen the container calls and the equipment calls
  -- go away together, and the pass is over before either answers again. Judged on its own it
  -- would drop everything the row knows, and the lot walks back in as arrivals the moment the
  -- read returns, which is the whole inventory arriving as new. Such a pass decides nothing,
  -- and it is not worth asking for another look on either.
  if not (next(counts) or next(guidNow) or seen) then return end
  local hold = not primed or frozen() or not Rec:Live()
     or (GetTime() - primed) < SETTLE
  if not primed and (C_Container.GetContainerNumSlots(0) or 0) > 0 then
    primed = GetTime()
  end
  local n = capacity()
  for g in pairs(guidNow) do
    if not (guidHad[g] or everWorn[g] or hold or poor[g] or fromShed(guidItem[g])) then add(g, n, nil) end
  end
  for id, c in pairs(counts) do
    local was = known[id] or 0
    if c > was then
      local d = pardon(id, c - was)
      -- An increase in an id the cursor is carrying (or just put down) is a split or a move landing, not
      -- loot: swallow it so the player's own stack surgery never lists as recent. known still moves to the
      -- new count below, so the piece is accounted for, just not announced.
      if d > 0 and not hold and not poor[id] and not fromCursor(id) then
        -- An id already in the row needs nothing here: the number below is derived from the base it
        -- entered with, so a second arrival is counted by the same read that reports the bags.
        if not seq[id] then add(id, n, d, c) end
      end
    end
    -- The row's number, read off the live total rather than carried: what the id holds now against what it
    -- held when it appeared. A pass that reads short for a frame (a stack on the cursor, a slot the read
    -- missed) costs that frame and no more, because nothing is subtracted here and nothing is clipped.
    if base[id] then
      local live = c - base[id]
      if live > 0 then got[id] = live else remove(id) end
    end
    known[id] = c
  end
  if mailing() then
    for g in pairs(guidNow) do guidHad[g] = true end
    return
  end
  for id in pairs(known) do
    if not counts[id] and not equipped(id) then
      local m = (missed[id] or 0) + 1
      if m >= 3 then known[id] = nil; missed[id] = nil
      else missed[id] = m end
    else
      missed[id] = nil
    end
  end
  -- A cell that just missed is not decided: it takes three passes, and the passes are only
  -- ever the bag events that happen to arrive. The event that takes an item out of the bags
  -- is usually the last one for a while, so the third pass never comes on its own, and the
  -- cell outlives the item it was showing. The count is asked for another look instead.
  if prune(counts) then soon() end
  for g in pairs(guidHad) do
    if guidNow[g] then guidMiss[g] = nil
    else
      local m = (guidMiss[g] or 0) + 1
      if m >= 3 then guidHad[g] = nil; guidMiss[g] = nil
      else guidMiss[g] = m end
    end
  end
  for g in pairs(guidNow) do guidHad[g] = true end
end

-- The row hands the whole cell to the game. Its cells are live container buttons off the same
-- template the grid draws with, registered for the same two buttons and the same drag, so a
-- left click lifts the item, a drag lifts it too, a right click uses it, and shift, ctrl and
-- alt reach the container handler's own modified-click branch with no line of ours in the way.
-- An overlay above the cell would only re-implement the two gestures it takes away from the
-- template, so there is none, and no link check either: a cell whose item moved on stays on
-- the row for a few updates by design, and acting on the new occupant of that slot is what a
-- right click on the row has always done anyway.
--
-- The list is drawn in two windows and each keeps its own pool of cells, so the two field
-- names that answer for a cell come in from the row that owns it. Everything above is the
-- same for both, which is why the cells are built the same way in both.

-- The cells are container slot buttons, so they are built here, out of combat, and a
-- redraw only moves and re-ids them after that. A button made during a fight is
-- tainted for good. There is no overlay above a cell any more: the cell answers every
-- button itself, which is the whole point of the row behaving like the grid.
function Rec:Warm()
  local bags = ns.Bags
  local frame = bags and bags.frame
  if not frame then return end
  if InCombatLockdown() then self.cold = true; return end
  for i = 1, MAX_SLOTS do
    if not self.slots[i] then
      -- The registration and the drag come from the factory: the row wants exactly what the
      -- grid wants. wpeClicks has to say so, because the vendor lock re-registers from it.
      local b = ns.CreateItemButton(frame, 0, 1)
      b.wpeClicks, b.wpeLockable, b.wpeTotal = ns.CLICKS_SLOT, nil, nil
      b.wpeNoNew, b.wpeNoReagent = true, true
      b.holder:Hide()
      self.slots[i] = b
    end
    if not self.ghosts[i] then
      local g = ns.SlotGhost(frame)
      ns.ShowMark(g, false)
      g.icon:Hide()
      ns.RecMark(g)
      g:Hide()
      self.ghosts[i] = g
    end
  end
  if not self.clear then
    local c = ns.CreateTextButton(frame, 10)
    ns.LocalText(c.Text, "Clear")
    c:SetScript("OnClick", function(s) if s.wpeOn then Rec:Wipe() end end)
    c:Hide()
    self.clear = c
  end
  self.cold, self.warmed = nil, true
end

function Rec:Flush()
  if not self.cold or InCombatLockdown() then return end
  self:Warm()
  self:Refresh()
end

function Rec:Wipe()
  for i = 1, MAX_SLOTS do
    local c = cells[i]
    if type(c) == "table" then cells[i] = nil
    elseif c then seq[c], got[c], base[c] = nil, nil, nil; cells[i] = nil end
  end
  self:Refresh()
end

function Rec:Hide()
  if self.label then self.label:Hide() end
  if self.clear then self.clear:Hide() end
  for i = 1, MAX_SLOTS do
    local b, g = self.slots[i], self.ghosts[i]
    if b then b.holder:Hide(); b.recBag = nil end
    if g then g:Hide() end
  end
end

function Rec:Height(size)
  if not self:BagsOn() then return 0 end
  local d = ns.Density(size)
  return d.labelH + d.labelGap + (tonumber(size) or 0) + 6
end

function Rec:Feed(n)
  local out = {}
  if not self:PocketOn() then return out end
  -- The pocket can be the only window on screen, and compaction otherwise only runs from the bags' own
  -- Apply: a held cell would stand there for the rest of the session. Cheap and idempotent, since it
  -- returns immediately while nothing is over capacity and no hold has run out.
  compact(capacity())
  local ids = {}
  for i = 1, MAX_SLOTS do
    if cells[i] then ids[#ids + 1] = cells[i] end
  end
  -- Oldest first, the newest at the right, which is how the row reads in the bags: the two
  -- windows show one list in one order, and only the window under it is different. Reading
  -- this backwards is what put the newest at the left of the pocket while the bags put it
  -- at the right.
  table.sort(ids, function(a, b) return ord(a) < ord(b) end)
  local cut = #ids - (tonumber(n) or 0)
  if cut < 0 then cut = 0 end
  for k = cut + 1, #ids do out[#out + 1] = ids[k] end
  return out
end

function Rec:Where(id)
  if not id then return nil end
  return locBag[id], locSlot[id]
end

function Rec:Got(id)
  return id and got[id] or nil
end

function Rec:Cooldowns()
  for i = 1, MAX_SLOTS do
    local b = self.slots[i]
    if b and b.link and b.holder:IsVisible() then ns.UpdateCooldown(b) end
  end
end

-- Grey the row cell mirroring a bag slot that just locked or unlocked, so a recent item picked up or
-- mid-move desaturates like it does in the grid. The cell binds a real (recBag, recSlot); match on those.
function Rec:RefreshLock(bag, slot)
  for i = 1, MAX_SLOTS do
    local b = self.slots[i]
    if b and b.recBag == bag and b.recSlot == slot and b.holder and b.holder:IsVisible() then
      ns.UpdateItemLock(b)
      return
    end
  end
end
function Rec:Apply(bags, x, top, size, gap)
  if not (bags and bags.frame) then return 0 end
  local frame = bags.frame
  local d = ns.Density(size)
  self.args = { bags = bags, x = x, top = top, size = size, gap = gap }
  local n = capacity()
  compact(n)
  if not self:BagsOn() then
    self:Hide()
    return 0
  end
  if not self.warmed then self:Warm() end
  if not self.label then
    local fs = Theme:Label(frame, 11, "dim")
    fs:SetJustifyH("LEFT")
    ns.LocalText(fs, "Recent")
    self.label = fs
  end
  self.label:SetFont(bags.fontPath or ns.Fonts:Current(), d.font - 4, ns.OutlineFlags())
  self.label:ClearAllPoints()
  ns.SnapPoint(self.label, "TOPLEFT", frame, "TOPLEFT", x, -top)
  self.label:Show()
  local rowY = top + d.labelH + d.labelGap
  if self.clear then
    self.clear.Text:SetFont(bags.fontPath or ns.Fonts:Current(), d.font - 5, ns.OutlineFlags())
    self.clear:SetSize(math.ceil(self.clear.Text:GetStringWidth()) + 8, d.labelH)
    self.clear:ClearAllPoints()
    ns.SnapPoint(self.clear, "TOPLEFT", frame, "TOPLEFT",
                 x + math.ceil(self.label:GetStringWidth()) + 10, -top)
    self.clear:SetOn(used())
    self.clear:Show()
  end
  local gen = (bags.styleGen or 0) .. ":" .. tostring(bags.fontPath) .. ":" .. size
  local repaint = self.paintKey ~= gen
  self.paintKey = gen
  for i = 1, MAX_SLOTS do
    local id = (i <= n) and cells[i] or nil
    local bag, slot = id and locBag[id], id and locSlot[id]
    local b, g = self.slots[i], self.ghosts[i]
    local px = x + (i - 1) * (size + gap)
    if id and bag and not b then self.cold = true end
    local live = (id and bag and b) and true or false
    if live then
      if b.recBag ~= bag or b.recSlot ~= slot then
        b.recBag, b.recSlot, b.wpeBagID = bag, slot, bag
        b.holder:SetID(bag)
        b:SetID(slot)
        b.link = nil
      end
      local h = b.holder
      ns.SnapSize(h, size, size)
      h:ClearAllPoints()
      ns.SnapPoint(h, "TOPLEFT", frame, "TOPLEFT", px, -rowY)
      h:Show(); b:Show()
      b.wpeForce = got[id]
      if repaint then b.link = nil end
      ns.UpdateItemButton(b)
      if bags.ApplyToButton then bags:ApplyToButton(b) end
      if g then g:Hide() end
    else
      if b then b.holder:Hide(); b.recBag, b.wpeForce = nil, nil end
      if g and i <= n then
        ns.SnapBox(g, size, size)
        g:ClearAllPoints()
        ns.SnapPoint(g, "TOPLEFT", frame, "TOPLEFT", px, -rowY)
        ns.PaintGhostBg(g)
        -- A ghost is never a search hit, so it wears the row's dim while a query runs; set here too so
        -- one freshly placed mid-search starts dimmed instead of flashing full until the next pass.
        g:SetAlpha((bags.filters and not bags.filters.empty) and 0.20 or 1)
        g:Show()
      elseif g then
        g:Hide()
      end
    end
  end
  self:Cooldowns()
  return d.labelH + d.labelGap + size + 6
end
function Rec:Refresh()
  local a = self.args
  local live = (a and a.bags and a.bags.frame and a.bags.frame:IsShown()) and true or false
  if live and self:Height(a.size) ~= (a.bags.recentH or 0) then
    a.bags:Layout()
    return
  end
  if live then self:Apply(a.bags, a.x, a.top, a.size, a.gap) end
  if ns.Pocket then ns.Pocket:Soon() end
end

local queued = false

soon = function()
  if queued then return end
  queued = true
  C_Timer.After(0.05, function()
    queued = false
    detect()
    Rec:Refresh()
  end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("BAG_UPDATE")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:RegisterEvent("BAG_UPDATE_COOLDOWN")
ev:RegisterEvent("SPELL_UPDATE_COOLDOWN")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
-- An item whose data was not cached when a scan read its slot (pending). The scan asked for the load; the
-- game answers here, once per id, and the pass is run again -- now the slot reads in full and the arrival
-- is counted. Without this an item taken from the mail whose BAG_UPDATE was its last event never lists.
ev:RegisterEvent("ITEM_DATA_LOAD_RESULT")
-- The cursor picking an item up or putting it down. Stamped before any bag pass so a split in flight is
-- already on record when the source-shrunk BAG_UPDATE arrives; without this the pass beats the cursor read.
ev:RegisterEvent("CURSOR_CHANGED")
ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "CURSOR_CHANGED" then
    noteCursor()
    return
  end
  if event == "ITEM_DATA_LOAD_RESULT" then
    -- Only a load we are waiting on, so an unrelated item resolving elsewhere does not drive a pass.
    if arg1 and pending[arg1] then soon() end
    return
  end
  if event == "PLAYER_EQUIPMENT_CHANGED" then
    bodyDiff()
    return
  end
  if event == "PLAYER_REGEN_ENABLED" then
    Rec:Flush()
    return
  end
  if event == "BAG_UPDATE" then
    soon()
    return
  end
  if event == "BAG_UPDATE_DELAYED" or event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
    detect()
    Rec:Refresh()
    return
  end
  Rec:Cooldowns()
end)
