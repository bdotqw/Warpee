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
  if cap <= 0 or not ns.playerBags then return out, 0, 0 end
  local keepBoE = not (WarpeeDB.vendorKeepBoE == false)
  for _, bag in ipairs(ns.playerBags) do
    for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      local link = info and info.hyperlink
      if link and not info.isLocked and not info.hasNoValue and (info.quality or 9) <= 4 then
        local _, _, _, equipLoc, _, classID, subID = C_Item.GetItemInfoInstant(link)
        if (classID == Enum.ItemClass.Armor or classID == Enum.ItemClass.Weapon)
           and not SKIP_LOC[equipLoc or ""]
           and not cosmeticArmor(classID, subID)
           and not fishingPole(classID, subID) then
          local lvl = slotIlvl(bag, slot, link)
          local ok = (lvl and lvl > 1 and lvl < cap) and true or false
          if ok and keepBoE and not info.isBound and not ns.IsLinkWarbound(link) then
            ok = false
            kept = kept + 1
          end
          if ok and refundable(bag, slot) then ok = false end
          if ok then
            local value = sellPrice(link) * (info.stackCount or 1)
            out[#out + 1] = { bag = bag, slot = slot, id = info.itemID, ilvl = lvl,
                              value = value, name = info.itemName or link:match("%[(.-)%]") }
            total = total + value
          end
        end
      end
    end
  end
  return out, total, kept
end

function Vendor:TipLines()
  local cap = self:Ilvl()
  local out = {}
  if cap <= 0 then
    out[1] = { text = "Set the item level in Settings, Vendor tab", color = "dim" }
    return out
  end
  out[1] = { text = "Armour and weapons under ilvl " .. cap, color = "dim", size = 10 }
  local list, total, kept = self:Scan()
  if #list == 0 then
    out[2] = { text = "Nothing to sell", color = "faint" }
  else
    out[2] = { text = ("%d items for %s"):format(#list, ns.FormatMoney(total, false)),
               color = "accentInk" }
    local shown = math.min(#list, 10)
    for i = 1, shown do
      out[#out + 1] = { text = ("%d   %s"):format(list[i].ilvl, list[i].name or "?"),
                        color = "text", size = 10 }
    end
    if #list > shown then
      out[#out + 1] = { text = ("and %d more"):format(#list - shown), color = "faint", size = 10 }
    end
  end
  if kept > 0 then
    out[#out + 1] = { text = ("%d BoE kept"):format(kept), color = "dim", size = 10 }
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
