local addonName, ns = ...

local Vault = {}
ns.Vault = Vault

local ownerKey
local boxCache = {}
local countCache = {}
local lastMode, lastBag, lastSlots
local migrated

local FIELD = { bank = "bank", bags = "inv" }

local function store()
  if not WarpeeDB then return nil end
  local v = WarpeeDB.vault
  if not v then v = {}; WarpeeDB.vault = v end
  v.chars = v.chars or {}
  v.warband = v.warband or {}
  v.hidden = v.hidden or {}
  if not migrated then
    for _, c in pairs(v.chars) do
      if type(c) == "table" and c.bags and not c.bank then
        c.bank = { bags = c.bags, at = c.at }
        c.bags, c.at = nil, nil
      end
    end
    migrated = true
  end
  return v
end

function Vault:Owner()
  if ownerKey then return ownerKey end
  local name = UnitName("player")
  if not name then return nil end
  local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or GetRealmName()
  ownerKey = name .. "-" .. (realm or "?")
  return ownerKey
end

local function invalidate()
  wipe(boxCache)
  wipe(countCache)
  lastMode, lastBag, lastSlots = nil, nil, nil
end

Vault.view = { bank = nil, bags = nil }

function Vault:ViewKey(mode)
  return self.view[mode] or self:Owner()
end

function Vault:SetView(mode, key)
  if key == "" then key = nil end
  if key == self:Owner() then key = nil end
  if self.view[mode] == key then return false end
  self.view[mode] = key
  invalidate()
  return true
end

function Vault:Hidden(key)
  local v = store()
  return (v and v.hidden[key]) and true or false
end

function Vault:SetHidden(key, on)
  local v = store()
  if not v then return end
  v.hidden[key] = on and true or nil
end

function Vault:Delete(key)
  local v = store()
  if not (v and key and v.chars[key]) then return false end
  v.chars[key] = nil
  v.hidden[key] = nil
  for mode, k in pairs(self.view) do
    if k == key then self.view[mode] = nil end
  end
  invalidate()
  return true
end

local function charSub(v, key, mode, create)
  local c = v.chars[key]
  if not c and create then c = {}; v.chars[key] = c end
  if not c then return nil, nil end
  local f = FIELD[mode] or "bank"
  local sub = c[f]
  if not sub and create then sub = {}; c[f] = sub end
  return sub, c
end

function Vault:Box(mode)
  local hit = boxCache[mode]
  if hit then return hit end
  local v = store()
  if not v then return nil end
  local box
  if mode == "warband" then
    box = v.warband
  else
    local key = self:ViewKey(mode)
    if key then box = (charSub(v, key, mode)) end
  end
  if box then boxCache[mode] = box end
  return box
end

function Vault:OwnerBox(mode, create)
  local v = store()
  if not v then return nil end
  if mode == "warband" then return v.warband end
  local key = self:Owner()
  if not key then return nil end
  return (charSub(v, key, mode, create))
end

function Vault:Chars(includeHidden)
  local v = store()
  if not v then return {} end
  local out = {}
  for key, c in pairs(v.chars) do
    if type(c) == "table" and (c.bank or c.inv) then
      local hidden = v.hidden[key] and true or false
      if includeHidden or not hidden then
        local name, realm = key:match("^(.-)%-(.*)$")
        out[#out + 1] = { key = key, name = name or key, realm = realm, class = c.class,
                          at = (c.bank and c.bank.at) or (c.inv and c.inv.at), hidden = hidden }
      end
    end
  end
  table.sort(out, function(a, b)
    local ra, rb = (a.realm or ""):lower(), (b.realm or ""):lower()
    if ra ~= rb then return ra < rb end
    return a.name:lower() < b.name:lower()
  end)
  return out
end

local function bankTypeFor(mode)
  if not (Enum and Enum.BankType) then return nil end
  return (mode == "warband") and Enum.BankType.Account or Enum.BankType.Character
end

local function readable(mode)
  if mode == "bags" then return true end
  local bt = bankTypeFor(mode)
  if not bt then return false end
  if C_Bank and C_Bank.CanViewBank then
    local ok, can = pcall(C_Bank.CanViewBank, bt)
    if ok and can == false then return false end
  end
  return true
end

local scanLoc
local function gearLevel(bag, slot)
  if not scanLoc then
    scanLoc = ItemLocation:CreateFromBagAndSlot(bag, slot)
  else
    scanLoc:SetBagAndSlot(bag, slot)
  end
  if not C_Item.DoesItemExist(scanLoc) then return nil end
  return C_Item.GetCurrentItemLevel(scanLoc)
end

local gearByLink = {}
local function isGear(link)
  local hit = gearByLink[link]
  if hit ~= nil then return hit end
  local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(link)
  hit = (classID == Enum.ItemClass.Armor or classID == Enum.ItemClass.Weapon)
  gearByLink[link] = hit
  return hit
end

local function packSlot(bag, slot, info)
  local d = { c = info.stackCount, q = info.quality, l = info.hyperlink }
  if info.isBound then d.b = true end
  if d.l and isGear(d.l) then d.v = gearLevel(bag, slot) end
  return d
end

local function scanBag(bag)
  local num = C_Container.GetContainerNumSlots(bag) or 0
  if num <= 0 then return nil end
  local slots, used = {}, 0
  for slot = 1, num do
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if info then
      slots[slot] = packSlot(bag, slot, info)
      used = used + 1
    end
  end
  return { n = num, used = used, slots = slots }
end

function Vault:Sections(mode)
  if mode == "bags" then
    local ids = {}
    for _, b in ipairs(ns.playerBags) do ids[#ids + 1] = b end
    if ns.reagentBag then ids[#ids + 1] = ns.reagentBag end
    return { { ids = ids } }
  end
  if ns.Bank and ns.Bank.Sections then return ns.Bank:Sections(mode) end
  return {}
end

local function stampClass(mode)
  local v = store()
  local key = v and ns.Vault:Owner()
  local c = key and v.chars[key]
  if not c then return end
  c.money = GetMoney()
  if mode == "warband" then return end
  local _, class = UnitClass("player")
  if class then c.class = class end
end

local function stampMoney(box, mode)
  if mode ~= "warband" or not box then return end
  if not (C_Bank and C_Bank.FetchDepositedMoney and Enum and Enum.BankType) then return end
  local ok, v = pcall(C_Bank.FetchDepositedMoney, Enum.BankType.Account)
  if ok and v then box.money = v end
end

function Vault:WarbandMoney()
  local v = store()
  return v and v.warband and v.warband.money or nil
end

local function linkID(link)
  if not link then return nil end
  return tonumber(link:match("item:(%d+)"))
end

local function countIn(sub, itemID)
  if not (sub and sub.bags) then return 0 end
  local n = 0
  for _, entry in pairs(sub.bags) do
    local slots = entry and entry.slots
    if slots then
      for _, d in pairs(slots) do
        if d.l and linkID(d.l) == itemID then n = n + (d.c or 1) end
      end
    end
  end
  return n
end

function Vault:ItemCounts(itemID)
  itemID = tonumber(itemID)
  if not itemID then return {}, 0, 0 end
  local hit = countCache[itemID]
  if hit then return hit.list, hit.warband, hit.total end
  local v = store()
  local list, total, wb = {}, 0, 0
  if v then
    local ownKey = self:Owner()
    local live = GetItemCount and GetItemCount(itemID) or nil
    local seen = false
    for key, c in pairs(v.chars) do
      if type(c) == "table" then
        local bags = countIn(c.inv, itemID)
        local bank = countIn(c.bank, itemID)
        if key == ownKey then
          seen = true
          if live then bags = live end
        end
        local sum = bags + bank
        if sum > 0 then
          list[#list + 1] = { key = key, name = key:match("^(.-)%-") or key, class = c.class,
                              bags = bags, bank = bank, total = sum }
          total = total + sum
        end
      end
    end
    if not seen and ownKey and live and live > 0 then
      local _, class = UnitClass("player")
      list[#list + 1] = { key = ownKey, name = ownKey:match("^(.-)%-") or ownKey, class = class,
                          bags = live, bank = 0, total = live }
      total = total + live
    end
    wb = countIn(v.warband, itemID)
    total = total + wb
  end
  table.sort(list, function(a, b)
    if a.total ~= b.total then return a.total > b.total end
    return a.name:lower() < b.name:lower()
  end)
  countCache[itemID] = { list = list, warband = wb, total = total }
  return list, wb, total
end

function Vault:MoneyList()
  local v = store()
  local out, total = {}, 0
  local ownKey = self:Owner()
  local seen = false
  if v then
    for key, c in pairs(v.chars) do
      if type(c) == "table" then
        local own = (key == ownKey)
        local m = own and GetMoney() or c.money
        if own then seen = true end
        if m and m > 0 then
          out[#out + 1] = { key = key, name = key:match("^(.-)%-") or key,
                            class = c.class, money = m, own = own }
          total = total + m
        end
      end
    end
  end
  if not seen and ownKey then
    local m = GetMoney()
    if m and m > 0 then
      local _, class = UnitClass("player")
      out[#out + 1] = { key = ownKey, name = ownKey:match("^(.-)%-") or ownKey,
                        class = class, money = m, own = true }
      total = total + m
    end
  end
  table.sort(out, function(a, b)
    if a.money ~= b.money then return a.money > b.money end
    return a.name:lower() < b.name:lower()
  end)
  return out, total
end

function Vault:Capture(mode, only)
  if not (WarpeeDB and readable(mode)) then return false end
  local box = only and self:OwnerBox(mode) or nil
  if only and not (box and box.bags) then only = nil end

  if only then
    local touched = false
    for bag in pairs(only) do
      local entry = scanBag(bag)
      if entry then box.bags[bag] = entry; touched = true end
    end
    if not touched then return false end
    box.at = time()
    stampClass(mode)
    stampMoney(box, mode)
    invalidate()
    return true
  end

  local bags, any = {}, false
  for _, sec in ipairs(self:Sections(mode)) do
    for _, bag in ipairs(sec.ids) do
      local entry = scanBag(bag)
      if entry then bags[bag] = entry; any = true end
    end
  end
  if not any then return false end
  box = self:OwnerBox(mode, true)
  if not box then return false end
  box.at = time()
  box.bags = bags
  stampClass(mode)
  stampMoney(box, mode)
  invalidate()
  return true
end

function Vault:Bag(mode, bag)
  local box = self:Box(mode)
  return box and box.bags and box.bags[bag] or nil
end

function Vault:Count(mode, bag)
  local entry = self:Bag(mode, bag)
  return entry and entry.n or 0
end

function Vault:Used(mode, bag)
  local entry = self:Bag(mode, bag)
  return entry and entry.used or 0
end

function Vault:Slot(mode, bag, slot)
  if lastMode ~= mode or lastBag ~= bag then
    local entry = self:Bag(mode, bag)
    lastMode, lastBag, lastSlots = mode, bag, entry and entry.slots or nil
  end
  return lastSlots and lastSlots[slot] or nil
end

