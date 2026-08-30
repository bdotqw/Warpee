local addonName, ns = ...

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
local MISC_CLASS = 15
local MISC_SUB = { [0] = true, [1] = true, [4] = true }
local CONSUM_SUB = { [1] = true, [2] = true, [3] = true, [5] = true, [7] = true }

local classPrefix
local function classesPrefix()
  if classPrefix ~= nil then return classPrefix end
  classPrefix = false
  local g = ITEM_CLASSES_ALLOWED
  if type(g) == "string" and g ~= "" then
    local p = (g:match("^(.-)%%") or g):gsub("%s+$", "")
    if #p >= 3 then classPrefix = p:lower() end
  end
  return classPrefix
end

local classCache = {}
local function classBound(link)
  local pref = classesPrefix()
  if not (pref and C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return false end
  local hit = classCache[link]
  if hit ~= nil then return hit end
  local yes = false
  local data = C_TooltipInfo.GetHyperlink(link)
  if data and data.lines then
    for _, line in ipairs(data.lines) do
      if line.leftText == nil and TooltipUtil and TooltipUtil.SurfaceArgs then
        TooltipUtil.SurfaceArgs(line)
      end
      local txt = line.leftText
      if txt and txt:lower():find(pref, 1, true) == 1 then yes = true; break end
    end
  end
  classCache[link] = yes
  return yes
end

local function tierToken(link, id, classID, subID, q)
  if id and ns.TIER_TOKENS and ns.TIER_TOKENS[id] then return true end
  if classID ~= MISC_CLASS or not MISC_SUB[subID] or q < 3 then return false end
  return classBound(link)
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
  local a, _, c = get(bag, slot, false)
  local secs = (type(a) == "table" and a.refundSeconds) or c
  return (tonumber(secs) or 0) > 0
end
function Vendor:Ilvl()
  return tonumber(WarpeeDB and WarpeeDB.vendorIlvl) or 0
end

function Vendor:Scan()
  local out, total, kept = {}, 0, 0
  local cap = self:Ilvl()
  local low = tonumber(WarpeeDB and WarpeeDB.vendorIlvlMin) or 0
  if not ns.playerBags then return out, 0, 0 end
  local keepBoE = not (WarpeeDB.vendorKeepBoE == false)
  local keepWb = not (WarpeeDB.vendorKeepWarbound == false)
  local keepGems = not (WarpeeDB.vendorKeepGems == false)
  local grey = not (WarpeeDB.vendorGrey == false)
  local relics = not (WarpeeDB.vendorRelics == false)
  local consum = WarpeeDB.vendorConsum and true or false
  local tokens = WarpeeDB.vendorTokens and true or false
  for _, bag in ipairs(ns.playerBags) do
    for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      local link = info and info.hyperlink
      if link and not info.isLocked and not info.hasNoValue then
        local q = info.quality or 9
        local _, _, _, equipLoc, _, classID, subID = C_Item.GetItemInfoInstant(link)
        local take, lvl = false, nil
        if self:Blocked(info.itemID) or questItem(bag, slot) then
          take = false
        elseif grey and q == 0 then
          take = true
        elseif consum and q <= 4 and oldConsumable(link, classID, subID) then
          take = true
        elseif relics and q <= 4 and classID == RELIC_CLASS and subID == RELIC_SUB then
          take = true
        elseif tokens and q <= 4 and tierToken(link, info.itemID, classID, subID, q) then
          take = true
        elseif q <= 4 and cap > 0
           and (classID == Enum.ItemClass.Armor or classID == Enum.ItemClass.Weapon)
           and not SKIP_LOC[equipLoc or ""]
           and not cosmeticArmor(classID, subID)
           and not fishingPole(classID, subID)
           and not hasUse(link) then
          lvl = slotIlvl(bag, slot, link)
          take = (lvl and lvl > 1 and lvl >= low and lvl < cap) and true or false
          local wb = ((keepBoE and not info.isBound) or keepWb)
                     and ns.IsLinkWarbound(link) or false
          if take and keepBoE and not info.isBound and not wb then take = false; kept = kept + 1 end
          if take and keepWb and wb then take = false; kept = kept + 1 end
          if take and keepGems and hasGems(link) then take = false; kept = kept + 1 end
        end
        if take and refundable(bag, slot) then take = false end
        if take then
          local value = sellPrice(link) * (info.stackCount or 1)
          out[#out + 1] = { bag = bag, slot = slot, id = info.itemID, ilvl = lvl,
                            value = value, name = info.itemName or link:match("%[(.-)%]") }
          total = total + value
        end
      end
    end
  end
  return out, total, kept
end

function Vendor:TipLines()
  local cap = self:Ilvl()
  local out = {}
  if not self:IsOpen() then
    out[#out + 1] = { text = "Locked, talk to a merchant first", color = "azure", size = 11 }
  end
  if cap > 0 then
    out[#out + 1] = { text = "Armour and weapons under ilvl " .. cap, color = "dim", size = 10 }
  else
    out[#out + 1] = { text = "Item level is zero, gear is kept", color = "dim", size = 10 }
  end
  local list, total, kept = self:Scan()
  if #list == 0 then
    out[#out + 1] = { text = "Nothing to sell", color = "faint" }
  else
    out[#out + 1] = { text = ("%d items for %s"):format(#list, ns.FormatMoney(total, false)),
                      color = "accentInk" }
  end
  if kept > 0 then
    out[#out + 1] = { text = ("%d kept back"):format(kept), color = "dim", size = 10 }
  end
  if self:Busy() then
    out[#out + 1] = { text = "Selling now", color = "accent", size = 10 }
  end
  return out
end
local ev = CreateFrame("Frame")
local open, run, gen = false, nil, 0

function Vendor:IsOpen() return open end
function Vendor:Busy() return run ~= nil end

local function finish()
  if not run then return end
  local sold = run.base - (run.left or 0)
  local start = run.money or GetMoney()
  run = nil
  ev:UnregisterEvent("BAG_UPDATE_DELAYED")
  if sold <= 0 then return end
  C_Timer.After(0.3, function()
    local earned = GetMoney() - start
    if earned < 0 then earned = 0 end
    print(("|cffd9a85fWarpee|r sold %d items for %s"):format(sold, ns.FormatMoney(earned, false)))
  end)
end

function Vendor:Pass()
  gen = gen + 1
  if not open then finish(); return end
  local list = self:Scan()
  local count = #list
  if run then
    run.left = count
  else
    run = { base = count, left = count, passes = 0, money = GetMoney() }
  end
  if count == 0 then finish(); return end
  run.passes = run.passes + 1
  if run.passes > 60 then finish(); return end
  if CursorHasItem() then ClearCursor() end
  ev:RegisterEvent("BAG_UPDATE_DELAYED")
  for i = 1, math.min(count, self.batch) do
    local it = list[i]
    local now = C_Container.GetContainerItemInfo(it.bag, it.slot)
    if now and not now.isLocked and now.itemID == it.id then
      C_Container.UseContainerItem(it.bag, it.slot)
    end
  end
  local mark = gen
  C_Timer.After(1, function()
    if run and gen == mark then Vendor:Pass() end
  end)
end

function Vendor:Sell()
  if not open or run then return end
  self:Pass()
end
ev:RegisterEvent("MERCHANT_SHOW")
ev:RegisterEvent("MERCHANT_CLOSED")
pcall(ev.RegisterEvent, ev, "MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL")
ev:SetScript("OnEvent", function(_, event)
  if event == "MERCHANT_SHOW" then
    open = true
    if ns.Bags then ns.Bags:VendorState() end
    if WarpeeDB and WarpeeDB.vendorAuto then
      C_Timer.After(0.3, function() if open then Vendor:Sell() end end)
    end
  elseif event == "MERCHANT_CLOSED" then
    open = false
    finish()
    if ns.Bags then ns.Bags:VendorState() end
  elseif event == "BAG_UPDATE_DELAYED" then
    if run then Vendor:Pass() end
  elseif event == "MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL" then
    if run and SellCursorItem then
      SellCursorItem()
      if StaticPopup_Hide then StaticPopup_Hide("CONFIRM_MERCHANT_TRADE_TIMER_REMOVAL") end
    end
  end
end)
