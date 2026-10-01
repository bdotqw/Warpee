local addonName, ns = ...

local Vault = {}
ns.Vault = Vault

local ownerKey
local boxCache = {}
local countCache = {}
local gearByLink = {}
local idByLink = {}
local lastMode, lastBag, lastSlots
local migrated

local FIELD = { bank = "bank", bags = "inv" }
local KEEP = { bags = "keepBags", bank = "keepBank", warband = "keepWarband" }

-- Gold keeps its own store, apart from the snapshots: a toggle switched off, a snapshot never taken
-- or a deleted one must not cost a number. The old copy sat in the character record, so the first
-- read moves it across once and clears the field.
local GOLD_VERSION = 1

local function goldStore()
  if not WarpeeDB then return nil end
  local g = WarpeeDB.gold
  if not g then g = {}; WarpeeDB.gold = g end
  g.chars = g.chars or {}
  if (g.v or 0) < GOLD_VERSION then
    local v = WarpeeDB.vault
    if v then
      for key, c in pairs(v.chars or {}) do
        if type(c) == "table" and c.money then
          if not g.chars[key] then g.chars[key] = { m = c.money, class = c.class } end
          c.money = nil
        end
      end
      if type(v.warband) == "table" and v.warband.money then
        if g.warband == nil then g.warband = v.warband.money end
        v.warband.money = nil
      end
    end
    g.v = GOLD_VERSION
  end
  return g
end

local function hasBags(box)
  return (box and box.bags and next(box.bags)) and true or false
end

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
    if ns.IsPlayerBag then
      for _, c in pairs(v.chars) do
        if type(c) == "table" and type(c.inv) == "table" and type(c.inv.bags) == "table" then
          for bag in pairs(c.inv.bags) do
            if not ns.IsPlayerBag(bag) then c.inv.bags[bag] = nil end
          end
        end
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
  wipe(gearByLink)
  wipe(idByLink)
  lastMode, lastBag, lastSlots = nil, nil, nil
end

-- The item counts alone, for the case that moves them without moving anything else: a bag
-- update on our own character. Rebuilding the box or the anchor memos with it would throw
-- away answers that do not come from live container state.
function Vault:Stale()
  wipe(countCache)
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

function Vault:DropWarband()
  local v = store()
  if not (v and hasBags(v.warband)) then return false end
  v.warband = {}
  invalidate()
  return true
end

function Vault:Keeps(mode)
  local key = KEEP[mode]
  if not (key and WarpeeDB) then return true end
  return WarpeeDB[key] ~= false
end

function Vault:Saved(mode)
  local v = store()
  if not v then return false end
  if mode == "warband" then return hasBags(v.warband) end
  local f = FIELD[mode] or "bank"
  for _, c in pairs(v.chars) do
    if type(c) == "table" and hasBags(c[f]) then return true end
  end
  return false
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

function Vault:SetTabs(mode, tabs)
  if not tabs then return end
  local box = self:OwnerBox(mode, true)
  if not box then return end
  box.tabs = box.tabs or {}
  for bag, m in pairs(tabs) do
    if m and (m.name or m.icon) then box.tabs[bag] = { name = m.name, icon = m.icon } end
  end
end

function Vault:TabMeta(mode, bag)
  local box = self:Box(mode)
  return box and box.tabs and box.tabs[bag] or nil
end

function Vault:OwnerBox(mode, create)
  local v = store()
  if not v then return nil end
  if mode == "warband" then return v.warband end
  local key = self:Owner()
  if not key then return nil end
  return (charSub(v, key, mode, create))
end

local function byRealmName(a, b)
  local ra, rb = (a.realm or ""):lower(), (b.realm or ""):lower()
  if ra ~= rb then return ra < rb end
  return a.name:lower() < b.name:lower()
end

function Vault:Chars(includeHidden, mode)
  local v = store()
  if not v then return {} end
  local f = mode and (FIELD[mode] or "bank") or nil
  local out = {}
  for key, c in pairs(v.chars) do
    local keep = type(c) == "table"
      and (f and hasBags(c[f]) or (not f and (c.bank or c.inv)))
    if keep then
      local hidden = v.hidden[key] and true or false
      if includeHidden or not hidden then
        local name, realm = key:match("^(.-)%-(.*)$")
        out[#out + 1] = { key = key, name = name or key, realm = realm, class = c.class,
                          at = (c.bank and c.bank.at) or (c.inv and c.inv.at), hidden = hidden }
      end
    end
  end
  table.sort(out, byRealmName)
  return out
end

function Vault:Others(mode)
  local own = self:Owner()
  local n = 0
  for _, e in ipairs(self:Chars(true, mode)) do
    if e.key ~= own then n = n + 1 end
  end
  return n
end

function Vault:WithOwner(list)
  local key = self:Owner()
  if not key then return list end
  local found = false
  for _, e in ipairs(list) do
    if e.key == key then found = true; break end
  end
  if not found then
    local name, realm = key:match("^(.-)%-(.*)$")
    local _, class = UnitClass("player")
    list[#list + 1] = { key = key, name = name or key, realm = realm, class = class }
  end
  table.sort(list, function(a, b)
    if (a.key == key) ~= (b.key == key) then return a.key == key end
    return byRealmName(a, b)
  end)
  return list
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
local function gearFacts(bag, slot, bound)
  if not scanLoc then
    scanLoc = ItemLocation:CreateFromBagAndSlot(bag, slot)
  else
    scanLoc:SetBagAndSlot(bag, slot)
  end
  if not C_Item.DoesItemExist(scanLoc) then return nil end
  local wue = not bound and C_Item.IsBoundToAccountUntilEquip
              and C_Item.IsBoundToAccountUntilEquip(scanLoc) or nil
  return C_Item.GetCurrentItemLevel(scanLoc), wue
end

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
  -- The warbound flag is written for every piece of gear, false included. "No w at all" has
  -- to keep meaning "written before the flag existed", and a reader can only tell those two
  -- apart while a fresh record always carries the key.
  if d.l and isGear(d.l) then
    local lvl, wue = gearFacts(bag, slot, info.isBound)
    d.v, d.w = lvl, wue and true or false
  end
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
  if mode == "warband" then return end
  local v = store()
  local key = v and ns.Vault:Owner()
  local c = key and v.chars[key]
  if not c then return end
  local _, class = UnitClass("player")
  if class then c.class = class end
end

-- The warband coins are readable only while the account bank is in reach. A missed read must never
-- wipe a kept number, so a zero lands only with the bank open.
local function accountBankOpen()
  if not (C_Bank and C_Bank.CanViewBank and Enum and Enum.BankType) then return false end
  local ok, can = pcall(C_Bank.CanViewBank, Enum.BankType.Account)
  return (ok and can) and true or false
end

-- The one place gold is written: a snapshot asks for the coins, this store keeps them. It is called
-- from the middle of a session only, never from login or logout: at both ends of it the money reads as
-- 0 while the client is loading the character or already tearing it down, and one such read was enough
-- to write a zero over every character's remembered gold.
function Vault:StampGold()
  local g = goldStore()
  if not g then return end
  self:StampGoldChar(g)
  if C_Bank and C_Bank.FetchDepositedMoney and Enum and Enum.BankType then
    local ok, v = pcall(C_Bank.FetchDepositedMoney, Enum.BankType.Account)
    if ok and type(v) == "number" and (v > 0 or accountBankOpen()) then
      g.warband = v
      g.warbandAt = time()
    end
  end
end

-- The character half of a stamp, split out so a wipe can re-seed the list with this character's purse
-- without pulling the warband number back in from FetchDepositedMoney's cache.
function Vault:StampGoldChar(g)
  g = g or goldStore()
  if not g then return end
  local key = self:Owner()
  if not key then return end
  local row = g.chars[key]
  if not row then row = {}; g.chars[key] = row end
  local m = GetMoney()
  if m then row.m = m end
  local _, class = UnitClass("player")
  if class then row.class = class end
  row.at = time()
end

-- A sale, a loot and a repair each fire PLAYER_MONEY, so only the last timer writes.
local goldGen = 0
function Vault:QueueGold(delay)
  goldGen = goldGen + 1
  local gen = goldGen
  C_Timer.After(delay or 2, function()
    if goldGen ~= gen then return end
    Vault:StampGold()
  end)
end

function Vault:WarbandMoney()
  local g = goldStore()
  return g and g.warband or nil
end

-- The gold a given character has, for the money corner when a snapshot is open: the own character reads
-- live, another character reads the remembered number. nil means nothing is kept for them -- the purse was
-- wiped or never recorded -- which the window draws as a dash rather than falling back to the viewer's own
-- gold, so a snapshot never shows the wrong character's money.
function Vault:CharGold(key)
  if not key or key == self:Owner() then return GetMoney() end
  local g = goldStore()
  local c = g and g.chars[key]
  return (type(c) == "table" and c.m) or nil
end

-- Whether anything is kept in the gold store at all: a character with a number, or the warband purse.
-- The settings page shows the gold row only when there is something to show or clear.
function Vault:HasGold()
  local g = goldStore()
  if not g then return false end
  if g.warband then return true end
  for _, c in pairs(g.chars) do
    if type(c) == "table" and c.m then return true end
  end
  return false
end

-- Throw away every remembered purse at once, then re-seed only this character so the list is not left
-- empty: the gold is kept apart from the snapshots, so this clears only gold and leaves bags and bank
-- saves alone. Only the character's own purse is written back, never the warband -- a plain StampGold
-- would pull the warband number straight back out of FetchDepositedMoney's cache and the wipe would not
-- clear it. The current character reads back in as the single entry, the natural result of a wipe online.
function Vault:WipeGold()
  if not WarpeeDB then return false end
  WarpeeDB.gold = nil
  self:StampGoldChar()
  return true
end


-- A pattern match and a short string per stored slot, over every character's bags and bank
-- plus the warband: one hover that misses the count cache walked thousands of records and
-- matched every hyperlink on the way. The answer for a link never changes, and the table is
-- emptied with the count cache it belongs to.
local function linkID(link)
  if not link then return nil end
  local id = idByLink[link]
  if id ~= nil then return id or nil end
  id = tonumber(link:match("item:(%d+)"))
  idByLink[link] = id or false
  return id
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
        -- The live count stands in for our own bags, so their stored copy is not read: the
        -- walk over it was thrown away every time this ran with GetItemCount available.
        local own = (key == ownKey)
        local bags = (own and live ~= nil) and live or countIn(c.inv, itemID)
        local bank = countIn(c.bank, itemID)
        if own then seen = true end
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
  local g = goldStore()
  local out, total = {}, 0
  local ownKey = self:Owner()
  local seen = false
  if g then
    for key, c in pairs(g.chars) do
      if type(c) == "table" then
        local own = (key == ownKey)
        local m = own and GetMoney() or c.m
        if own then seen = true end
        -- A character whose purse is empty is listed as an empty purse. The number being 0 is a fact
        -- the player asked to have remembered; dropping the row read as the character never having been
        -- recorded at all, which is how a visited alt went missing from the list.
        if m then
          out[#out + 1] = { key = key, name = key:match("^(.-)%-") or key,
                            class = c.class, money = m, own = own }
          total = total + m
        end
      end
    end
  end
  if not seen and ownKey then
    local m = GetMoney()
    if m then
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
  if not (WarpeeDB and readable(mode) and self:Keeps(mode)) then return false end
  local box = only and self:OwnerBox(mode) or nil
  if only and not (box and box.bags) then only = nil end

  if only then
    local allow = {}
    for _, sec in ipairs(self:Sections(mode)) do
      for _, bag in ipairs(sec.ids) do allow[bag] = true end
    end
    local touched = false
    for bag in pairs(only) do
      if allow[bag] then
        local entry = scanBag(bag)
        if entry then box.bags[bag] = entry; touched = true end
      end
    end
    if not touched then return false end
    box.at = time()
    stampClass(mode)
    self:StampGold()
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
  self:StampGold()
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
