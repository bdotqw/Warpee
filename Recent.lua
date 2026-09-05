local addonName, ns = ...
local Theme = ns.Theme

local Rec = {}
ns.Recent = Rec
Rec.slots, Rec.ghosts = {}, {}

local LABEL_H, LABEL_GAP = 13, 4
local MAX_SLOTS = 24
local SETTLE = 5

local cells, seq, known, got = {}, {}, {}, {}
local locBag, locSlot = {}, {}
local poor = {}
local counter = 0
local primed = nil

function Rec:Enabled()
  return not (WarpeeDB and WarpeeDB.recentShow == false)
end

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
      counts[id] = (counts[id] or 0) + (info.stackCount or 1)
      if info.quality == 0 then poor[id] = true end
      if not locBag[id] then locBag[id], locSlot[id] = bag, slot end
    end
  end
end

local function tally()
  local counts = {}
  wipe(locBag); wipe(locSlot); wipe(poor)
  for _, bag in ipairs(ns.playerBags) do scanBag(bag, counts) end
  if ns.reagentBag then scanBag(ns.reagentBag, counts) end
  return counts
end

local function pinned(id)
  local F = ns.Fav
  if not (F and F.List) then return false end
  for _, own in pairs(F:List()) do
    if own == id then return true end
  end
  return false
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

local function add(id, n, delta)
  if seq[id] or pinned(id) then return end
  counter = counter + 1
  for i = 1, n do
    if not cells[i] then
      cells[i], seq[id] = id, counter
      mark(id, delta)
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
  cells[worn], seq[id] = id, counter
  mark(id, delta)
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
    local id = cells[i]
    if id and (not counts[id] or pinned(id) or poor[id]) then
      seq[id], got[id] = nil, nil
      cells[i] = nil
    end
  end
end

local shed, shedAt, body = {}, {}, {}
local SHED = 3

local function bodyDiff()
  local f = GetInventoryItemID
  if not f then return end
  for s = 1, 19 do
    local now = f("player", s)
    local was = body[s]
    body[s] = now
    if was and was ~= now then
      shed[was] = (shed[was] or 0) + 1
      shedAt[was] = GetTime()
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
  local hold = not primed or frozen() or not Rec:Enabled()
     or (GetTime() - primed) < SETTLE
  if not primed and (C_Container.GetContainerNumSlots(0) or 0) > 0 then
    primed = GetTime()
  end
  local n = capacity()
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
  if mailing() then return end
  for id in pairs(known) do
    if not counts[id] and not equipped(id) then known[id] = nil end
  end
  prune(counts)
end

local function makeGhost(parent)
  local g = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  ns.PixelBackdrop(g)
  g:SetBackdropColor(Theme:C("slot"))
  g:SetBackdropBorderColor(Theme:C("emptyLine"))
  Theme:Track(g, function(s)
    s:SetBackdropColor(Theme:C("slot"))
    s:SetBackdropBorderColor(Theme:C("emptyLine"))
  end)
  return g
end

-- The cells are container slot buttons, so they are built here, out of combat, and a
-- redraw only moves and re-ids them after that. A button made during a fight is
-- tainted for good. The row keeps the right button for using the item and leaves the
-- template's own drag alone, and it owns no click handler and no overlay, which is why
-- SetPassThroughButtons, the call that is refused in combat, never appears in this file.
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
      b.wpeNoNew = true
      b.holder:Hide()
      self.slots[i] = b
    end
    if not self.ghosts[i] then
      local g = makeGhost(frame)
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
    local id = cells[i]
    if id then seq[id], got[id] = nil, nil; cells[i] = nil end
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
  if not self:Enabled() then return 0 end
  return LABEL_H + LABEL_GAP + (tonumber(size) or 0) + 6
end

function Rec:Feed(n)
  local out = {}
  if not self:Enabled() then return out end
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
    if b and b.holder:IsShown() and b.link then ns.UpdateCooldown(b) end
  end
end
function Rec:Apply(bags, x, top, size, gap)
  if not (bags and bags.frame) then return 0 end
  local frame = bags.frame
  self.args = { bags = bags, x = x, top = top, size = size, gap = gap }
  local n = capacity()
  compact(n)
  if not self:Enabled() then
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
    local b, g = self.slots[i], self.ghosts[i]
    local px = x + (i - 1) * (size + gap)
    if id and bag and not b then self.cold = true end
    if id and bag and b then
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
  end
  return LABEL_H + LABEL_GAP + size + 6
end
function Rec:Refresh()
  local a = self.args
  if not (a and a.bags and a.bags.frame and a.bags.frame:IsShown()) then return end
  if self:Height(a.size) ~= (a.bags.recentH or 0) then
    a.bags:Layout()
    return
  end
  self:Apply(a.bags, a.x, a.top, a.size, a.gap)
  if ns.Pocket then ns.Pocket:Refresh() end
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
