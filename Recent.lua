local addonName, ns = ...
local Theme = ns.Theme

local Rec = {}
ns.Recent = Rec
Rec.slots, Rec.ghosts, Rec.catchers = {}, {}, {}

local LABEL_H, LABEL_GAP = 13, 4
local MAX_SLOTS = 24
local SETTLE = 5

local cells, seq, known, got = {}, {}, {}, {}
local missed, guidMiss, cellMiss = {}, {}, {}
local locBag, locSlot = {}, {}
local poor = {}
local counter = 0
local primed = nil
local guidNow, guidHad, everWorn = {}, {}, {}
local wornN = 0
local ILOC

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
-- switch, which meant the same thing for both windows. This file used to carry one Enabled
-- for the pair, and that one value was doing two jobs: it hid the rows and it stopped the
-- collection. The two are separated here on purpose, because hiding the row in one window
-- must not stop the list the other window is still showing.
local function flag(key)
  local db = WarpeeDB
  if not db then return true end
  if db[key] == nil then return db.recentShow ~= false end
  return db[key] ~= false
end

function Rec:BagsOn() return flag("recentBags") end
function Rec:PocketOn() return flag("recentPocket") end

-- What the collection itself watches. With both switches off this is the old "off": the list
-- keeps its cells but takes nothing new, exactly as it did before the split.
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
  local f = (C_Item and C_Item.IsEquippedItem) or IsEquippedItem
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
    if id then
      local g = ns.GearItem(id) and itemGuid(bag, slot) or nil
      if g then
        guidNow[g] = true
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
  wipe(guidNow)
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

local function mark(id, delta)
  got[id] = (got[id] or 0) + delta
end

local function add(key, n, delta)
  if seq[key] then return end
  counter = counter + 1
  for i = 1, n do
    if not cells[i] then
      cells[i], seq[key] = key, counter
      if delta then mark(key, delta) end
      return
    end
  end
  local worn, age
  for i = 1, n do
    local c = cells[i]
    if c and (not age or (seq[c] or 0) < age) then worn, age = i, seq[c] or 0 end
  end
  if not worn then return end
  local out = cells[worn]
  seq[out], got[out] = nil, nil
  cells[worn], seq[key] = key, counter
  if delta then mark(key, delta) end
end
local function compact(n)
  local ids, over = {}, false
  for i = 1, MAX_SLOTS do
    local id = cells[i]
    if id then
      ids[#ids + 1] = id
      if i > n then over = true end
    end
  end
  if not over and #ids <= n then return end
  table.sort(ids, function(a, b) return (seq[a] or 0) < (seq[b] or 0) end)
  for i = 1, MAX_SLOTS do cells[i] = nil end
  local cut = math.max(0, #ids - n)
  for k = 1, #ids do
    local id = ids[k]
    if k <= cut then seq[id], got[id] = nil, nil else cells[k - cut] = id end
  end
end

local function remove(id)
  for i = 1, MAX_SLOTS do
    if cells[i] == id then cells[i] = nil end
  end
  seq[id], got[id] = nil, nil
end

local function prune(counts)
  for i = 1, MAX_SLOTS do
    local key = cells[i]
    local here = key and (type(key) == "string" and guidNow[key] or counts[key])
    if key and (not here or poor[key]) then
      -- Its own counter, not the one the known-item pass keeps: the two run over the same
      -- cell keys, so sharing it spent the forgiveness twice as fast on exactly the items
      -- the row is showing.
      local m = (cellMiss[key] or 0) + 1
      if m >= 3 or poor[key] then
        seq[key], got[key] = nil, nil
        cellMiss[key] = nil
        cells[i] = nil
      else
        cellMiss[key] = m
      end
    elseif key then
      cellMiss[key] = nil
    end
  end
end

local shed, shedAt, body = {}, {}, {}
local SHED = 3

local function bodyDiff()
  local f = GetInventoryItemID
  local cut = GetTime() - SHED
  for id, t in pairs(shedAt) do
    if t < cut then shed[id], shedAt[id] = nil, nil end
  end
  for s = 1, 19 do
    local now = f and f("player", s) or nil
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

local function detect()
  local counts = tally()
  bodyDiff()
  local hold = not primed or frozen() or not Rec:Live()
     or (GetTime() - primed) < SETTLE
  if not primed and (C_Container.GetContainerNumSlots(0) or 0) > 0 then
    primed = GetTime()
  end
  local n = capacity()
  for g in pairs(guidNow) do
    if not (guidHad[g] or everWorn[g] or hold or poor[g]) then add(g, n, nil) end
  end
  for id, c in pairs(counts) do
    local was = known[id] or 0
    if c > was then
      local d = pardon(id, c - was)
      if d > 0 and not hold and not poor[id] then
        if seq[id] then mark(id, d) else add(id, n, d) end
      end
    elseif c < was and got[id] then
      got[id] = got[id] - (was - c)
    end
    if got[id] then
      if got[id] > c then got[id] = c end
      if got[id] <= 0 then remove(id) end
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
  prune(counts)
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

-- The row is a stack of live container buttons and it keeps the right button alone, so a
-- left click cannot lift an item off it. That also costs the two left-click gestures a slot
-- normally answers, and this overlay buys those two back without buying back the rest.
--
-- The overlay owns the left button and passes the right one down to the cell, so a right
-- click still reaches the game's own handler with no addon code in its path.
-- SetPassThroughButtons is refused during combat lockdown, so it is set once, here, when the
-- overlay is built, and never touched again: a pool that was not ready before the fight
-- cannot be made ready during it, and the whole pool is built beside the cells in Warm.
--
-- What it adds is a modified left click, and only the two kinds the row wants: dress up and
-- insert into chat. Everything else is swallowed deliberately. An ordinary left click does
-- nothing, so no item is picked up; nothing is registered for drag, so the overlay cannot be
-- dragged; there is no receive handler, so an item dragged in from the grid is not dropped
-- onto the row and stays on the cursor; middle and extra buttons die here as well.
--
-- The link is read from the live slot at the moment of the click rather than from anything
-- the row remembered, and it has to be the link the cell is showing. A cell whose item moved
-- on stays on the row for a few updates by design, and acting on the new occupant of that
-- slot would be acting on the wrong item. An emptied slot reads no link and does nothing.
--
-- The list is drawn in two windows and each keeps its own cells, so the pool and the two
-- field names that answer for a cell come in from the row that owns it. Everything above is
-- the same for both, which is the point of building them here rather than twice.
local function makeCatcher(parent, index, pool, bagKey, slotKey)
  local c = CreateFrame("Button", nil, parent)
  c.recIndex = index
  c.recPool, c.recBagKey, c.recSlotKey = pool, bagKey, slotKey
  c:RegisterForClicks("LeftButtonUp")
  c:SetFrameLevel(parent:GetFrameLevel() + 30)
  c:EnableMouse(true)
  c:EnableKeyboard(false)
  if c.SetPassThroughButtons then c:SetPassThroughButtons("RightButton") end
  -- Hover is not the overlay's to take: the cell's own OnEnter owns the tooltip, and this
  -- lets the motion through to it instead of stopping here.
  if c.SetPropagateMouseMotion then c:SetPropagateMouseMotion(true) end
  c:SetScript("OnClick", function(s, button)
    if button ~= "LeftButton" or GetCursorInfo() then return end
    if not (IsModifiedClick("DRESSUP") or IsModifiedClick("CHATLINK")) then return end
    local b = s.recPool and s.recPool[s.recIndex]
    local bag, slot = b and b[s.recBagKey], b and b[s.recSlotKey]
    if not (bag and slot) then return end
    local link = C_Container.GetContainerItemLink(bag, slot)
    if not (link and link == b.link) then return end
    -- The location goes with the link because that is how the game calls it, and its
    -- dress-up branch reaches for the location before it falls back to parsing the link.
    local loc
    if ItemLocation and ItemLocation.CreateFromBagAndSlot then
      loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
    end
    HandleModifiedItemClick(link, loc)
  end)
  return c
end

-- The pocket draws the same list in cells of its own, and takes the overlay from here so
-- there is one copy of the click rules and one place that sets the pass-through.
function Rec:NewCatcher(parent, index, pool, bagKey, slotKey)
  return makeCatcher(parent, index, pool, bagKey, slotKey)
end

-- The cells are container slot buttons, so they are built here, out of combat, and a
-- redraw only moves and re-ids them after that. A button made during a fight is
-- tainted for good. The row keeps the right button for using the item and leaves the
-- template's own drag alone, and the left button lives on the overlay above each cell,
-- which is the only place in this file that calls SetPassThroughButtons.
function Rec:Warm()
  local bags = ns.Bags
  local frame = bags and bags.frame
  if not frame then return end
  if InCombatLockdown() then self.cold = true; return end
  for i = 1, MAX_SLOTS do
    if not self.slots[i] then
      local b = ns.CreateItemButton(frame, 0, 1)
      b:RegisterForClicks(unpack(ns.CLICKS_USE))
      b.wpeClicks, b.wpeLockable, b.wpeTotal = ns.CLICKS_USE, nil, nil
      b.wpeNoNew, b.wpeNoReagent = true, true
      b.holder:Hide()
      self.slots[i] = b
    end
    if not self.ghosts[i] then
      local g = ns.SlotGhost(frame)
      g.plus:Hide()
      g.icon:Hide()
      ns.RecMark(g)
      g:Hide()
      self.ghosts[i] = g
    end
    if not self.catchers[i] then
      local c = makeCatcher(frame, i, self.slots, "recBag", "recSlot")
      c:Hide()
      self.catchers[i] = c
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
    local id = cells[i]
    if id then seq[id], got[id] = nil, nil; cells[i] = nil end
  end
  self:Refresh()
end

function Rec:Hide()
  if self.label then self.label:Hide() end
  if self.clear then self.clear:Hide() end
  for i = 1, MAX_SLOTS do
    local b, g, c = self.slots[i], self.ghosts[i], self.catchers[i]
    if b then b.holder:Hide(); b.recBag = nil end
    if g then g:Hide() end
    if c then c:Hide() end
  end
end

function Rec:Height(size)
  if not self:BagsOn() then return 0 end
  return LABEL_H + LABEL_GAP + (tonumber(size) or 0) + 6
end

function Rec:Feed(n)
  local out = {}
  if not self:PocketOn() then return out end
  for i = 1, MAX_SLOTS do
    if cells[i] then out[#out + 1] = cells[i] end
  end
  table.sort(out, function(a, b) return (seq[a] or 0) > (seq[b] or 0) end)
  for i = #out, (tonumber(n) or 0) + 1, -1 do out[i] = nil end
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
function Rec:Apply(bags, x, top, size, gap)
  if not (bags and bags.frame) then return 0 end
  local frame = bags.frame
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
  self.label:SetFont(bags.fontPath or ns.Fonts:Current(), 11, "")
  self.label:ClearAllPoints()
  ns.SnapPoint(self.label, "TOPLEFT", frame, "TOPLEFT", x, -top)
  self.label:Show()
  local rowY = top + LABEL_H + LABEL_GAP
  if self.clear then
    self.clear.Text:SetFont(bags.fontPath or ns.Fonts:Current(), 10, "")
    self.clear:SetSize(math.ceil(self.clear.Text:GetStringWidth()) + 8, LABEL_H)
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
    local b, g, c = self.slots[i], self.ghosts[i], self.catchers[i]
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
        g:Show()
      elseif g then
        g:Hide()
      end
    end
    -- The overlay exists only where a live cell does. An empty cell of the row is a ghost
    -- rather than a drop target, so it gets no overlay and answers no click.
    if c then
      if live then
        ns.SnapBox(c, size, size)
        c:ClearAllPoints()
        ns.SnapPoint(c, "TOPLEFT", frame, "TOPLEFT", px, -rowY)
        c:Show()
      else
        c:Hide()
      end
    end
  end
  self:Cooldowns()
  return LABEL_H + LABEL_GAP + size + 6
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

local function soon()
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
ev:SetScript("OnEvent", function(_, event)
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
