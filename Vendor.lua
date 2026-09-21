local addonName, ns = ...

local L = ns.L
local Vendor = { batch = 12 }
ns.Vendor = Vendor

local SKIP_LOC = {
  INVTYPE_TABARD = true,
  INVTYPE_BODY = true,
  INVTYPE_BAG = true,
  INVTYPE_AMMO = true,
  INVTYPE_QUIVER = true,
  INVTYPE_RELIC = true,
}

local STONE = {
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
}

local FUN = {
  [7734] = true, [10716] = true, [11905] = true, [1404] = true,
  [2820] = true, [14022] = true, [10727] = true, [10577] = true,
  [18634] = true, [18638] = true, [18639] = true, [19024] = true,
  [19979] = true, [7506] = true, [18706] = true,
}

local OLDCONSUM = {
  [133576] = true, [13452] = true, [13512] = true, [6657] = true,
  [8529] = true, [127844] = true, [127843] = true, [142117] = true,
  [127846] = true, [33447] = true,
}

local RUNE = {
  [118630] = true, [118631] = true, [118632] = true,
  [128482] = true, [128475] = true, [140587] = true, [153023] = true,
  [160053] = true, [174906] = true, [181468] = true, [190384] = true,
  [201325] = true, [211495] = true, [224572] = true, [246492] = true,
  [243191] = true, [259085] = true,
}

local PROF = {
  [9452] = true, [12709] = true, [19901] = true,
  [19972] = true, [19969] = true,
  [155459] = true, [155484] = true, [155468] = true, [155476] = true,
  [7349] = true, [10542] = true,
  [85663] = true, [19971] = true, [34109] = true,
  [68796] = true, [34836] = true, [116117] = true, [153203] = true,
  [46006] = true, [18258] = true,
}

local function cosmeticArmor(classID, subID)
  local E = Enum.ItemArmorSubclass
  if not (E and E.Cosmetic) then return false end
  return classID == Enum.ItemClass.Armor and subID == E.Cosmetic
end

local function fishingPole(classID, subID)
  local E = Enum.ItemWeaponSubclass
  if not E then return false end
  local id = E.Fishingpole or E.FishingPole
  return classID == Enum.ItemClass.Weapon and id ~= nil and subID == id
end

local RELIC_CLASS, RELIC_SUB = 3, 11
local CONSUM_SUB = { [1] = true, [2] = true, [3] = true, [5] = true, [7] = true }

local function tokenExpAllowed(link)
  local t = WarpeeDB and WarpeeDB.vendorTokenExp
  if not t then return true end
  local exp = (select(15, C_Item.GetItemInfo(link)))
  if exp == nil then return false end
  return t[exp] and true or false
end

local function tierToken(link, id)
  if not (id and ns.TIER_TOKENS and ns.TIER_TOKENS[id]) then return false end
  return tokenExpAllowed(link)
end

local function oldConsumable(link, classID, subID)
  if classID ~= Enum.ItemClass.Consumable or not CONSUM_SUB[subID] then return false end
  local exp = (select(15, C_Item.GetItemInfo(link)))
  local cur = LE_EXPANSION_LEVEL_CURRENT
              or (GetExpansionLevel and GetExpansionLevel()) or nil
  if not (exp and cur) then return false end
  return exp <= cur - 2
end

local function questItem(bag, slot)
  local get = C_Container.GetContainerItemQuestInfo
  if not get then return false end
  local qi = get(bag, slot)
  return (qi and (qi.isQuestItem or qi.questID)) and true or false
end

function Vendor:Blocked(id)
  local t = WarpeeDB and WarpeeDB.vendorBlack
  return (id and t and t[id]) and true or false
end

function Vendor:Block(id, name)
  if not id then return end
  WarpeeDB.vendorBlack = WarpeeDB.vendorBlack or {}
  WarpeeDB.vendorBlack[id] = name or tostring(id)
end

function Vendor:Unblock(id)
  if id and WarpeeDB.vendorBlack then WarpeeDB.vendorBlack[id] = nil end
end

local function blackRepaint()
  ns.ClearItemPaint()
  local B = ns.Bags
  if B and B.frame and B.frame:IsShown() then B:Layout() end
  if ns.Bank then ns.Bank:Repaint() end
  if ns.Pocket then ns.Pocket:Soon() end
  local O = ns.Options
  if O and O.ReflowPages and O.frame and O.frame:IsShown() then O:ReflowPages() end
end

function Vendor:Toggle(id, name)
  if not id then return end
  if self:Blocked(id) then self:Unblock(id) else self:Block(id, name) end
  blackRepaint()
end

local function ownSlotFocus()
  local f
  if GetMouseFoci then
    local list = GetMouseFoci()
    f = type(list) == "table" and list[1] or nil
  end
  for _ = 1, 4 do
    if not f or f == UIParent then return false end
    if f.wpeBagID ~= nil then return true end
    f = f.GetParent and f:GetParent() or nil
  end
  return false
end

if type(HandleModifiedItemClick) == "function" then
  hooksecurefunc("HandleModifiedItemClick", function(link)
    if not (link and IsAltKeyDown() and not IsShiftKeyDown() and not IsControlKeyDown()) then
      return
    end
    if not ownSlotFocus() then return end
    local id = (C_Item.GetItemInfoInstant(link))
    if not id then return end
    Vendor:Toggle(id, link:match("%[(.-)%]") or (C_Item.GetItemInfo(link)))
  end)
end

function Vendor:BlackList()
  local out = {}
  for id, name in pairs(WarpeeDB.vendorBlack or {}) do
    out[#out + 1] = { id = id, name = name }
  end
  table.sort(out, function(a, b) return tostring(a.name) < tostring(b.name) end)
  return out
end

local function hasUse(link)
  local get = C_Item.GetItemSpell or GetItemSpell
  if not get then return false end
  return get(link) ~= nil
end

local function hasGems(link)
  local str = link:match("Hitem:([%-%d:]*)") or link:match("^item:([%-%d:]*)")
  if not str then return false end
  local i, hit = 0, false
  for v in (str .. ":"):gmatch("([^:]*):") do
    i = i + 1
    if i >= 2 and i <= 6 then
      local n = tonumber(v)
      if n and n ~= 0 then hit = true end
    end
    if i > 6 then break end
  end
  return hit
end

local function slotIlvl(bag, slot, link)
  local loc = ItemLocation and ItemLocation:CreateFromBagAndSlot(bag, slot)
  if loc and C_Item.DoesItemExist(loc) then
    local lvl = C_Item.GetCurrentItemLevel(loc)
    if lvl and lvl > 0 then return lvl end
  end
  local get = C_Item.GetDetailedItemLevelInfo or GetDetailedItemLevelInfo
  local lvl = get and get(link)
  if lvl and lvl > 0 then return lvl end
  return nil
end

local function sellPrice(link)
  local p = (select(11, C_Item.GetItemInfo(link)))
  return tonumber(p) or 0
end

local function refundable(bag, slot)
  local get = C_Container.GetContainerItemPurchaseInfo
  if not get then return false end
  local info = get(bag, slot, false)
  return (type(info) == "table" and (tonumber(info.refundSeconds) or 0) > 0) and true or false
end
function Vendor:Ilvl()
  return tonumber(WarpeeDB and WarpeeDB.vendorIlvl) or 0
end

function Vendor:Scan(junkOnly)
  local out, total, kept, locked = {}, 0, 0, 0
  local cap = self:Ilvl()
  local low = tonumber(WarpeeDB and WarpeeDB.vendorIlvlMin) or 0
  if not ns.playerBags then return out, 0, 0, 0 end
  local keepBoE = not (WarpeeDB.vendorKeepBoE == false)
  local keepWb = not (WarpeeDB.vendorKeepWarbound == false)
  local keepGems = not (WarpeeDB.vendorKeepGems == false)
  local grey = not (WarpeeDB.vendorGrey == false)
  local relics = not (WarpeeDB.vendorRelics == false)
  local consum = WarpeeDB.vendorConsum and true or false
  local tokens = WarpeeDB.vendorTokens and true or false
  if junkOnly then
    relics, consum, tokens, cap = false, false, false, 0
  end
  for _, bag in ipairs(ns.playerBags) do
    for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      local link = info and info.hyperlink
      if link and not info.isLocked and not info.hasNoValue then
        local q = info.quality or 9
        local _, _, _, equipLoc, _, classID, subID = C_Item.GetItemInfoInstant(link)
        local take, lvl = false, nil
        if grey and q == 0 then
          take = true
        elseif consum and q <= 4 and oldConsumable(link, classID, subID) then
          take = true
        elseif relics and q <= 4 and classID == RELIC_CLASS and subID == RELIC_SUB then
          take = true
        elseif tokens and q <= 4 and tierToken(link, info.itemID) then
          take = true
        elseif q <= 4 and cap > 0
           and (classID == Enum.ItemClass.Armor or classID == Enum.ItemClass.Weapon)
           and not SKIP_LOC[equipLoc or ""]
           and not cosmeticArmor(classID, subID)
           and not fishingPole(classID, subID)
           and not (hasUse(link) and equipLoc ~= "INVTYPE_TRINKET") then
          lvl = slotIlvl(bag, slot, link)
          take = (lvl and lvl > 1 and lvl >= low and lvl < cap) and true or false
          local wb = ((keepBoE and not info.isBound) or keepWb)
                     and ns.IsLinkWarbound(link) or false
          if take and keepBoE and not info.isBound and not wb then take = false; kept = kept + 1 end
          if take and keepWb and wb then take = false; kept = kept + 1 end
          if take and keepGems and hasGems(link) then take = false; kept = kept + 1 end
        end
        if take and refundable(bag, slot) then take = false end
        if take and questItem(bag, slot) then take = false end
        if STONE[info.itemID] or FUN[info.itemID] or OLDCONSUM[info.itemID] or PROF[info.itemID] or RUNE[info.itemID] then take = false end
        if classID == Enum.ItemClass.Battlepet then take = false end
        if take and self:Blocked(info.itemID) then take = false; locked = locked + 1 end
        if take then
          local value = sellPrice(link) * (info.stackCount or 1)
          out[#out + 1] = { bag = bag, slot = slot, id = info.itemID, ilvl = lvl,
                            value = value, name = info.itemName or link:match("%[(.-)%]") }
          total = total + value
        end
      end
    end
  end
  return out, total, kept, locked
end

function Vendor:TipLines()
  local out = {}
  local list, total = self:Scan()
  if #list == 0 then
    out[#out + 1] = { text = "Nothing to sell", color = "dim", size = 12 }
  else
    out[#out + 1] = { text = (L["%d items for %s"]):format(#list, ns.FormatMoney(total, false)),
                      color = "accentInk" }
  end
  if self:Busy() then
    out[#out + 1] = { text = "Selling now", color = "dim", size = 12 }
  elseif not self:IsOpen() then
    out[#out + 1] = { text = "Talk to a merchant first", color = "dim", size = 12 }
  elseif not self:CanBuy() then
    -- Open, but a repair-only NPC that buys nothing: say why the coin is dim instead of leaving it
    -- looking broken beside a bag full of sellable items.
    out[#out + 1] = { text = "This merchant only repairs", color = "dim", size = 12 }
  end
  return out
end
local ev = CreateFrame("Frame")
local pump = CreateFrame("Frame")
pump:Hide()
local open, run, gen = false, nil, 0
local MAX_TRIES = 6

function Vendor:IsOpen() return open end
function Vendor:Busy() return run ~= nil end

-- A repair-only NPC -- the summoned Auto-Hammer, Blingtron, Reaves and the like -- still fires
-- MERCHANT_SHOW, so open alone does not mean the merchant buys. There is no direct "can buy" flag,
-- but such a bot carries no wares: a stall with nothing for sale never buys, while any merchant that
-- takes items always stocks some. So an empty shelf under an open merchant is the repair-only tell,
-- and a sale is only attempted when the shelf holds something. Guarded so a nil API never throws.
function Vendor:CanBuy()
  if not open then return false end
  local n = GetMerchantNumItems and GetMerchantNumItems() or 0
  return (tonumber(n) or 0) > 0
end

local function finish()
  if not run then return end
  local stuck = 0
  for _ in pairs(run.dead or {}) do stuck = stuck + 1 end
  run = nil
  pump:Hide()
  ev:UnregisterEvent("BAG_UPDATE_DELAYED")
  if stuck > 0 then
    print("|cffd9a85fWarpee|r |cffffffff" .. (L["%d items could not be sold and stayed in the bags"]):format(stuck) .. "|r")
  end
  if open then Vendor:Repair() end
end

local function sendOne(it)
  -- UseContainerItem sells while a merchant is open and uses the item when one is
  -- not. Using is protected, so without this guard a run that outlives the window
  -- would report the addon for calling a forbidden function.
  if not (open and MerchantFrame and MerchantFrame:IsShown()) then return false end
  -- The same call from inside combat, or with the cursor carrying anything, is refused
  -- the same way and poisons every container until a reload. A pull while shopping, an
  -- item held on the cursor or an enchant waiting for its target all land here, so any
  -- of them stops the pass and the next one picks the item up again. An item on the
  -- cursor is what CursorHasItem reports; a spell or an enchant that has not picked its
  -- target yet leaves the cursor empty, and only GetCursorInfo and ItemTargeting see it.
  -- The second return says the call was never made, which is not the same as an item the
  -- merchant refused: the pump counts a pass of refusals, but not a pass of these.
  if InCombatLockdown() or CursorHasItem() or GetCursorInfo() or ns.ItemTargeting() then
    return false, true
  end
  local key = ("%d:%d:%d"):format(it.id or 0, it.bag, it.slot)
  local n = run.tries[key] or 0
  if n >= MAX_TRIES then
    run.dead[key] = true
    return false
  end
  local now = C_Container.GetContainerItemInfo(it.bag, it.slot)
  if not (now and not now.isLocked and now.itemID == it.id) then return false end
  run.tries[key] = n + 1
  C_Container.UseContainerItem(it.bag, it.slot)
  return true
end

pump:SetScript("OnUpdate", function(self)
  if not (run and run.queue) then self:Hide(); return end
  local held = false
  while run.qi <= #run.queue and run.qsent < Vendor.batch do
    local it = run.queue[run.qi]
    run.qi = run.qi + 1
    local ok, blocked = sendOne(it)
    if ok then run.qsent = run.qsent + 1
    elseif blocked then held = true end
  end
  local sent = run.qsent
  run.queue, run.qi, run.qsent = nil, nil, nil
  self:Hide()
  if sent == 0 and not held then
    -- Four passes that reached the merchant and sold nothing end the run. A pass that never
    -- reached it is not one of them, and counting it ended the whole run on a raid pull.
    run.idle = (run.idle or 0) + 1
    if run.idle >= 4 then finish(); return end
  elseif sent > 0 then
    run.idle = 0
  end
  local mark = gen
  C_Timer.After(1, function()
    if run and gen == mark then Vendor:Pass() end
  end)
end)

function Vendor:Pass()
  gen = gen + 1
  local mark = gen
  if not open then finish(); return end
  -- Nothing is queued while the call would be refused. A pull that starts mid-sale, an item
  -- held on the cursor or a spell waiting for its target is not this run failing, so the pass
  -- is not counted against the sixty it is allowed and the timer simply comes back. Counting
  -- them ended the run after a minute of combat with the junk still unsold and no word about it.
  if InCombatLockdown() or CursorHasItem() or GetCursorInfo() or ns.ItemTargeting() then
    C_Timer.After(1, function()
      if run and gen == mark then Vendor:Pass() end
    end)
    return
  end
  local list = self:Scan(run and run.junk)
  local count = #list
  if not run then
    run = { passes = 0, tries = {}, dead = {} }
  end
  if count == 0 then finish(); return end
  run.passes = run.passes + 1
  if run.passes > 60 then finish(); return end
  ev:RegisterEvent("BAG_UPDATE_DELAYED")
  run.queue, run.qi, run.qsent = list, 1, 0
  pump:Show()
end

function Vendor:Sell(junkOnly)
  if not open or run or not self:CanBuy() then return end
  run = { passes = 0, tries = {}, dead = {}, junk = junkOnly and true or false }
  self:Pass()
end

local function repairCost()
  if not (CanMerchantRepair and CanMerchantRepair()) then return 0 end
  if not GetRepairAllCost then return 0 end
  local cost, can = GetRepairAllCost()
  if not can then return 0 end
  return tonumber(cost) or 0
end

function Vendor:Repair()
  if not (WarpeeDB and WarpeeDB.vendorRepair) then return end
  if not RepairAllItems then return end
  if self.repaired then return end
  local cost = repairCost()
  if cost <= 0 then return end
  local mode = WarpeeDB.vendorRepairBy or "player"
  local guild = false
  if mode ~= "player" and CanGuildBankRepair and CanGuildBankRepair() then
    local limit = GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney() or 0
    guild = (limit == -1 or (tonumber(limit) or 0) >= cost)
  end
  local by
  if guild then
    by = L["guild funds"]
  elseif mode ~= "guild" and GetMoney() >= cost then
    by = L["your gold"]
  end
  if not by then return end
  RepairAllItems(guild)
  self.repaired = true
  print("|cffd9a85fWarpee|r |cffffffff" .. (L["repaired for %s from %s"])
        :format(ns.FormatGold(cost, nil, true), by) .. "|r")
end
ev:RegisterEvent("MERCHANT_SHOW")
ev:RegisterEvent("MERCHANT_CLOSED")
pcall(ev.RegisterEvent, ev, "MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL")
ev:SetScript("OnEvent", function(_, event)
  if event == "MERCHANT_SHOW" then
    open = true
    Vendor.repaired = nil
    if ns.Bags then ns.Bags:VendorState() end
    C_Timer.After(0.3, function()
      if not open then return end
      Vendor:Repair()
      if WarpeeDB and WarpeeDB.vendorAuto then
        Vendor:Sell()
      elseif WarpeeDB and WarpeeDB.vendorGrey ~= false then
        Vendor:Sell(true)
      end
    end)
  elseif event == "MERCHANT_CLOSED" then
    open = false
    Vendor.repaired = nil
    finish()
    if ns.Bags then ns.Bags:VendorState() end
  elseif event == "BAG_UPDATE_DELAYED" then
    if run and not run.queue then Vendor:Pass() end
  elseif event == "MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL" then
    if run then
      if StaticPopup_Hide then StaticPopup_Hide("CONFIRM_MERCHANT_TRADE_TIMER_REMOVAL") end
      if CursorHasItem and CursorHasItem() then ClearCursor() end
    end
  end
end)
