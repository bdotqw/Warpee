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

local unusableCache = {}
local warboundCache = {}
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
    if bad then hit = true; hits = hits or {}; hits[e.link] = true end
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
  if n > RETRY_MAX then return end
  C_Timer.After(RETRY_DELAY, function() askNextFrame(link, bag, slot) end)
end

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
                         "ITEM_CANT_BE_DISENCHANTED", "ITEM_UNIQUE_EQUIPPED", "ITEM_ALREADY_KNOWN",
                         "ITEM_CANT_BE_REFUNDED", "ITEM_WONT_BE_TRADABLE" }) do
    local g = _G[key]
    if type(g) == "string" and g ~= "" then
      notBlocking[g] = true
      notBlocking[(g:gsub("%s+$", ""))] = true
      notBlocking[(g:gsub("^%s+", ""))] = true
    end
  end
  return notBlocking
end

-- The broad read: any red line that is not one of the named non-blocks. It is deliberately independent of
-- how a requirement is phrased, and it runs on every item rather than only on the classes that usually
-- carry one -- a restriction is the item's own business, not its class's.
local function redBlocked(data)
  local skip = nonBlocking()
  for _, line in ipairs(data.lines) do
    if line.leftColor == nil and TooltipUtil and TooltipUtil.SurfaceArgs then
      TooltipUtil.SurfaceArgs(line)
    end
    if lineRed(line.leftColor) and not skip[line.leftText or ""] then return true end
    if lineRed(line.rightColor) and not skip[line.rightText or ""] then return true end
  end
  return false
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

function ns.IsItemUnusable(bag, slot, link)
  if not link then return false end
  local hit = knownVerdict(link)
  if hit ~= nil then return hit end
  if unknownItem(link) then retryLater(link, bag, slot); return false end
  if not (C_TooltipInfo and C_TooltipInfo.GetBagItem) then return false end
  if ns.OutOfTime() then askNextFrame(link, bag, slot); return false end
  local data = C_TooltipInfo.GetBagItem(bag, slot)
  -- No tooltip is not "usable" either: the read can come back empty while the client is still filling
  -- in the item, and a bare false here left the cell without its ring and nothing to paint it later.
  if not (data and data.lines) then retryLater(link, bag, slot); return false end
  -- The wording of a requirement is not something to depend on, so the broad read has the last word: the
  -- precise one still runs first for the cases it knows, and anything it does not recognise but the item
  -- prints in red counts as a block.
  local bad = scanRequirements(link, data) or redBlocked(data)
  keepVerdict(link, bad)
  return bad
end

function ns.IsLinkUnusable(link)
  if not link then return false end
  local hit = knownVerdict(link)
  if hit ~= nil then return hit end
  if unknownItem(link) then retryLater(link); return false end
  if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return false end
  if ns.OutOfTime() then askNextFrame(link); return false end
  local data = C_TooltipInfo.GetHyperlink(link)
  if not (data and data.lines) then retryLater(link); return false end
  local bad = scanRequirements(link, data) or redBlocked(data)
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
