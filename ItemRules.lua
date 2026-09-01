local addonName, ns = ...

local reqPrefixes
local function requirementPrefixes()
  if reqPrefixes then return reqPrefixes end
  reqPrefixes = {}
  for _, g in ipairs({ ITEM_MIN_LEVEL, ITEM_REQ_SKILL, ITEM_REQ_LEVEL, ITEM_MIN_SKILL,
                       ITEM_CLASSES_ALLOWED, ITEM_REQ_REPUTATION, ITEM_REQ_ARENA_RATING,
                       ITEM_REQ_SPECIALIZATION }) do
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

local unusableCache = {}
local warboundCache = {}

function ns.ClearUnusableCache()
  wipe(unusableCache)
end

local function knownVerdict(link)
  return unusableCache[link]
end

local function keepVerdict(link, bad)
  unusableCache[link] = bad
end

local function scanRequirements(link, data)
  local _, _, subType, equipLoc = C_Item.GetItemInfoInstant(link)
  local slotName = (equipLoc and equipLoc ~= "" and _G[equipLoc]) or nil
  local prefixes = requirementPrefixes()
  for _, line in ipairs(data.lines) do
    if line.leftColor == nil and TooltipUtil and TooltipUtil.SurfaceArgs then
      TooltipUtil.SurfaceArgs(line)
    end
    local txt = line.leftText or ""
    if slotName and txt == slotName and (lineRed(line.leftColor) or lineRed(line.rightColor)) then
      return true
    end
    if lineRed(line.rightColor) and typeMatch(line.rightText, subType) then return true end
    if lineRed(line.leftColor) then
      if subType and txt == subType then return true end
      local low = txt:lower()
      for _, pref in ipairs(prefixes) do
        if low:find(pref, 1, true) == 1 then return true end
      end
    end
  end
  return false
end

local function equippable(link)
  local eq = C_Item.IsEquippableItem or IsEquippableItem
  return eq and eq(link) and true or false
end

local restrictedClasses
local function restrictedClass(link)
  if not (Enum and Enum.ItemClass) then return false end
  if not restrictedClasses then
    restrictedClasses = {}
    for _, key in ipairs({ "Recipe", "Miscellaneous", "Consumable" }) do
      local id = Enum.ItemClass[key]
      if id then restrictedClasses[id] = true end
    end
  end
  local classID = select(6, C_Item.GetItemInfoInstant(link))
  return (classID and restrictedClasses[classID]) and true or false
end

local function checkable(link)
  return equippable(link) or restrictedClass(link)
end

function ns.IsItemUnusable(bag, slot, link)
  if not link then return false end
  local hit = knownVerdict(link)
  if hit ~= nil then return hit end
  if not checkable(link) then keepVerdict(link, false); return false end
  if not (C_TooltipInfo and C_TooltipInfo.GetBagItem) then return false end
  local data = C_TooltipInfo.GetBagItem(bag, slot)
  if not (data and data.lines) then return false end
  local bad = scanRequirements(link, data)
  keepVerdict(link, bad)
  return bad
end

function ns.IsLinkUnusable(link)
  if not link then return false end
  local hit = knownVerdict(link)
  if hit ~= nil then return hit end
  if not checkable(link) then keepVerdict(link, false); return false end
  if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return false end
  local data = C_TooltipInfo.GetHyperlink(link)
  if not (data and data.lines) then return false end
  local bad = scanRequirements(link, data)
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
