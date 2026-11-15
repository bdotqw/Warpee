local addonName, ns = ...

-- Forever only, decided at load by the client's own build (Core/Forever.lua reads it once, before the theme).
-- The two clients load the same files from one folder -- there is no second copy to keep apart -- so a file
-- that runs everywhere would open a list built for a bag system the other client does not have. Where it does
-- not run, nothing is left behind: no ns.Cheap, and Core asks before it touches it.
if not ns.IsForever then return end

local Theme = ns.Theme

-- What the window answers: "my bags are full, what can I throw away?" A list of the stacks a vendor would
-- pay the least for, cheapest first. The order is the whole stack's value (price times count) -- a stack of
-- twenty junk pieces is worth more than one charm, and the question the player asks is about the stack.
--
-- What earns a row: the client has to know the stack's sell price, and that price has to be above zero.
-- Locked slots, the hearthstone and quest items never earn one: the first two cannot be thrown away, the
-- last must not. Bound gear is the player's own decision and stays -- the window orders by value, it never
-- claims that something is safe to destroy.

-- The row is one line, and every column has a place: icon, name, count, side, money. The name takes what is
-- left of the fixed columns and is cut with an ellipsis -- a wrapped name used to paint over the row below it,
-- which read as the list being broken rather than as a name being long. The window is wide enough for the
-- widest money a row can carry plus a name worth reading.
local PAD, ROW_H, BAR_W, BAND = 10, 26, 6, 26
-- Three rows, not ten. The list exists for one move -- throw the cheapest thing away and get back to playing --
-- and the rows that matter are always the top ones, because the list is sorted by what the stack is worth. A
-- taller window bought nothing but a bigger frame standing over the bags; anything past the third row is a
-- wheel turn away, on the scrollbar the window already carries.
local WIDTH, MAX_ROWS, FONT = 372, 3, 15
local ICON, NAME_GAP = 24, 8
-- The money block: the side, then gold, silver and copper, each right-aligned in a column of its own. One label
-- could not line anything up -- it was the whole line that was right-aligned, so a row of 7 copper and a row of
-- 2g 92c put their digits wherever the total length left them. Three columns put gold over gold and copper over
-- copper down the list; a coin a row does not carry leaves its column empty, and the column still holds the
-- place, which is what makes a row of pure gold line up with the rest.
-- The numbers below are the least a column may be. A column is as wide as the widest coin the list carries
-- (Paint measures it), so a number grows its column instead of being cut into "3...": a coin cut in half is
-- worse than no coin at all, and every row wears the same three widths, so the digits stay over each other.
-- The gaps are the width of a space, which is what the gold tooltip puts between its coins: a column is its
-- own coin and nothing more, so nothing is padded out to a fixed slot and no pair of coins stands apart.
local SIDE_W = 24
local COL_G, COL_S, COL_C = 26, 24, 24
local COL_GAP = 4

-- MoneyParts fills the smaller coins with a zero once a larger one is written ("2g 0s 0c") so that a single line
-- keeps its copper at the end. In a column that zero is not alignment but noise: the column holds the place by
-- itself, so a piece that is a zero is written as nothing. The zero is read past its colour escape, and past
-- exactly that escape -- an open-ended %x+ eats the leading digit of a ten, and 10 silver would read as empty.
local function moneyPart(piece)
  if not piece then return nil end
  local n = piece:match("^|c%x%x%x%x%x%x%x%x(%d+)") or piece:match("^(%d+)")
  if n == "0" then return nil end
  return piece
end
-- The count rides on the picture, the way a bag cell's own does: sized off the icon so it grows with it, and
-- outlined, because it stands on the item's art rather than on the window's flat ground.
local COUNT_FONT = math.max(8, math.floor(ICON * 0.46))
local HEARTHSTONE = 6948
-- Quality, as the settings page names it: poor is 0 and legendary 5. Both switches are stored by name, so a
-- reader of the saved variables can tell what was chosen.
local QUALITY = { poor = 0, common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5 }

local function qualitySetting(key, fallback)
  local v = WarpeeDB and WarpeeDB[key]
  if type(v) == "string" then
    if v == "never" then return nil end
    v = QUALITY[v]
  end
  if v == nil then return fallback end
  return tonumber(v)
end

-- The best quality that earns a row: everything above it is not a stack to throw away.
local function maxShown()
  return qualitySetting("cheapMaxQuality", 2) or 2
end

-- The quality a delete asks about first, or nil for never.
local function confirmFrom()
  return qualitySetting("cheapConfirm", 2)
end

local function auctionCut()
  return not (WarpeeDB and WarpeeDB.cheapCut == false)
end

-- Items the player told the list to leave alone, by item id: a stack that is worth nothing is worth nothing
-- every time the bags open, and the mark on a row's icon is what writes this. The way back is the list of them
-- on the settings page, which is where a hand goes to change a rule rather than to throw something away.
local function isIgnored(id)
  local t = WarpeeDB and WarpeeDB.cheapIgnored
  return (t and id and t[id]) and true or false
end

local function lockedForSale(id, link)
  local V = ns.Vendor
  return (V and V.Locked and id and V:Locked(id, link)) and true or false
end

-- The list of ignored stacks as it stands, made on first use so a profile that never ignored anything carries
-- no table at all.
local function ignoredList()
  if not WarpeeDB then return nil end
  local t = WarpeeDB.cheapIgnored
  if not t then t = {}; WarpeeDB.cheapIgnored = t end
  return t
end

local Cheap = { rows = {} }
ns.Cheap = Cheap

local function itemGet()
  return (C_Item and C_Item.GetItemInfo) or GetItemInfo
end

local function containerInfo(bag, slot)
  local get = C_Container and C_Container.GetContainerItemInfo
  return get and get(bag, slot) or nil
end

local function questInfo(bag, slot)
  local get = C_Container and C_Container.GetContainerItemQuestInfo
  return get and get(bag, slot) or nil
end

-- One item record per link, read once and kept: the open of this window is the bags' own open, and two
-- client calls per stack (price, then icon) put a second full pass of the item cache on that frame for data
-- that does not change between scans. The name is cut off the link, so only the pair the row needs is kept.
local meta = {}
local function itemMeta(link)
  if not link then return nil end
  local m = meta[link]
  if m then return m end
  local get = itemGet()
  if not get then return nil end
  -- The client answers in one go; a record that is not cached yet answers nothing, and nothing is stored,
  -- so the next scan asks again.
  local _, _, _, _, _, _, _, _, _, icon, price = get(link)
  price = tonumber(price)
  if not price then return nil end
  m = { price = price, icon = icon, name = link:match("|h%[(.-)%]|h") or link }
  meta[link] = m
  return m
end

-- Auction value, from the addons that keep one. A stack worth forty copper to a vendor and ninety gold on the
-- auction house must not be thrown away, and the list has to say which side of that it stands on. Read per item
-- id and kept -- a price does not move between two paints -- and a miss is kept as a miss, because the same
-- stack is asked for again on every repaint. The auction house opening clears the misses, which is when new
-- data can have arrived.
local auction, auctionSource = {}, nil

-- TSM keeps its prices behind a custom price name; the item string is what the price store is keyed on.
local function tsmPrice(link)
  local api = _G.TSM_API
  if not (api and api.GetCustomPriceValue and api.ToItemString) then return nil end
  local ok, itemString = pcall(api.ToItemString, link)
  if not (ok and itemString) then return nil end
  -- Both spellings are in use across TSM versions, and the market value is the fallback when a minimum
  -- buyout is not configured at all.
  for _, name in ipairs({ "dbminbuyout", "Dbminbuyout", "dbmarket" }) do
    local ok2, v = pcall(api.GetCustomPriceValue, name, itemString)
    v = ok2 and tonumber(v) or nil
    if v and v > 0 then return v end
  end
  return nil
end

-- Which addon the prices come from, as the settings page names it: auto takes Auctionator when it is there and
-- TSM after it, either of the two can be asked for by name, and Vendor only turns the auction side off -- every
-- row is then the merchant's price, which is the honest answer for a player who keeps neither one's data.
local SOURCES = { auto = true, auctionator = true, tsm = true, vendor = true }

local function hasAuctionator()
  local A = _G.Auctionator
  return (A and A.API and A.API.v1 and A.API.v1.GetAuctionPriceByItemID) and true or false
end

local function hasTSM()
  return (_G.TSM_API and _G.TSM_API.GetCustomPriceValue) and true or false
end

local function sourcePref()
  local v = WarpeeDB and WarpeeDB.cheapAuctionSource
  if not (type(v) == "string" and SOURCES[v]) then return "auto" end
  -- A choice left over from an addon that has since been turned off is not a choice any more: the list falls
  -- back to auto rather than reading nothing at all, and the settings page shows the same answer.
  if v == "auctionator" and not hasAuctionator() then return "auto" end
  if v == "tsm" and not hasTSM() then return "auto" end
  return v
end

function Cheap:AuctionSource()
  -- Only a found source is kept: "nothing there" is asked again on the next scan, which is what lets an addon
  -- that loads late -- or one the player enables in the middle of a session -- be picked up without a reload.
  if auctionSource then return auctionSource end
  local pref = sourcePref()
  if pref == "vendor" then auctionSource = false
  elseif pref == "auctionator" then auctionSource = hasAuctionator() and "auctionator" or false
  elseif pref == "tsm" then auctionSource = hasTSM() and "tsm" or false
  else auctionSource = hasAuctionator() and "auctionator" or (hasTSM() and "tsm" or false) end
  if auctionSource == "auctionator" then self:WatchAuctionDB() end
  return auctionSource
end

-- What the settings page offers: only the sources that are actually there, so a player without TSM is never
-- asked to pick it. Read on every open of the menu, so an addon loaded later shows up without a reload.
function Cheap:AuctionChoices()
  local list = { "auto" }
  if hasAuctionator() then list[#list + 1] = "auctionator" end
  if hasTSM() then list[#list + 1] = "tsm" end
  list[#list + 1] = "vendor"
  return list
end

function Cheap:AuctionChoiceAvailable(v)
  if v == "auctionator" then return hasAuctionator() end
  if v == "tsm" then return hasTSM() end
  return true
end

function Cheap:AuctionPrice(id, link)
  if not id then return nil end
  local known = auction[id]
  if known ~= nil then return known or nil end
  local src, value = self:AuctionSource(), nil
  if src == "auctionator" then
    local ok, v = pcall(_G.Auctionator.API.v1.GetAuctionPriceByItemID, "Warpee", id)
    value = ok and tonumber(v) or nil
    if not value and link then
      local ok2, v2 = pcall(_G.Auctionator.API.v1.GetAuctionPriceByItemLink, "Warpee", link)
      value = ok2 and tonumber(v2) or nil
    end
  elseif src == "tsm" and link then
    value = tsmPrice(link)
  end
  if value and value <= 0 then value = nil end
  if value and auctionCut() then value = math.floor(value * 0.95) end
  auction[id] = value or false
  return value
end

-- The cache is an answer about one moment. A scan finishing, the auction house opening or closing, or the source
-- being switched makes it an answer about the past -- and a stale "no price" is the one that hurts, because it
-- outlives the data that would have filled it. Dropped whole: a hit is cheap to ask for again.
function Cheap:ClearAuction()
  auction = {}
  auctionSource = nil
end

-- Auctionator says when its price database moves -- the end of a scan, or a search that brought new prices --
-- through its own API, which is the call the addon documents for this. Without it a scan finished while the list
-- was open stayed unseen until a reload: the miss from before the scan was cached as firmly as a price.
local auctionHooked = false

function Cheap:WatchAuctionDB()
  if auctionHooked then return end
  local A = _G.Auctionator
  local api = A and A.API and A.API.v1
  if not (api and api.RegisterForDBUpdate) then return end
  local ok = pcall(api.RegisterForDBUpdate, "Warpee", function()
    Cheap:ClearAuction()
    if Cheap.frame and Cheap.frame:IsShown() then Cheap:Refresh() end
  end)
  auctionHooked = ok and true or false
end

-- Attachment: which side of the bags the list is standing against, and where along that side. Kept instead of a
-- rectangle because the list is one piece with the bags once it is docked: it is placed again whenever they move
-- or change size, and it is placed by the edge that holds the seam -- above them the bottom edge is the anchor,
-- so a row that arrives pushes the window up instead of into the bags.
local ATTACH_REACH = 40

local function bagsRect()
  local bags = ns.Bags and ns.Bags.frame
  if not (bags and bags:IsShown()) then return nil end
  local l, b = bags:GetLeft(), bags:GetBottom()
  local w, h = bags:GetWidth(), bags:GetHeight()
  if not (l and b and w and h) then return nil end
  return bags, l, b, l + w, b + h
end

function Cheap:PlaceAttached()
  local f = self.frame
  local a = WarpeeDB and WarpeeDB.cheapAttach
  local bags, bl, bb, br, bt = bagsRect()
  if not (f and a and bags and bl) then return false end
  local gap = ns.SeamGap(f, a.side)
  f:ClearAllPoints()
  -- The edge that holds the seam is the one anchored: above the bags it is the bottom edge, below them the top,
  -- and beside them the side -- so the other axis is held by the corner the drop recorded. Beside them that
  -- corner is the BOTTOM one, because `a.y` is measured from the bags' bottom: anchoring a top edge on that
  -- number dropped the window by its own height on every drop, which is the list crawling down the bags.
  if a.side == "below" then
    ns.SnapPoint(f, "TOPLEFT", UIParent, "BOTTOMLEFT", bl + (a.x or 0), bb - gap)
  elseif a.side == "right" then
    ns.SnapPoint(f, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", br + gap, bb + (a.y or 0))
  elseif a.side == "left" then
    ns.SnapPoint(f, "BOTTOMRIGHT", UIParent, "BOTTOMLEFT", bl - gap, bb + (a.y or 0))
  else
    ns.SnapPoint(f, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", bl + (a.x or 0), bt + gap)
  end
  return true
end

-- Dropped near an edge of the bags, the list joins them: within reach on the facing axis and overlapping on the
-- other one, it is pulled flush with the seam and the side is remembered. Dropped anywhere else it keeps its own
-- rectangle and stays there.
function Cheap:Attach()
  local f = self.frame
  local bags, bl, bb, br, bt = bagsRect()
  if not (f and bags and bl and f:IsShown()) then return false end
  local fl, fb = f:GetLeft(), f:GetBottom()
  local fr, ft = f:GetRight(), f:GetTop()
  if not (fl and fb and fr and ft) then return false end
  local reach = ns.SnapValue(f, ATTACH_REACH)
  local overlapX = math.min(fr, br) - math.max(fl, bl)
  local overlapY = math.min(ft, bt) - math.max(fb, bb)
  local rec
  if overlapX > 0 then
    if math.abs(fb - bt) <= reach then
      rec = { side = "above", x = ns.SnapValue(f, fl - bl) }
    elseif math.abs(ft - bb) <= reach then
      rec = { side = "below", x = ns.SnapValue(f, fl - bl) }
    end
  end
  if not rec and overlapY > 0 then
    if math.abs(fl - br) <= reach then
      rec = { side = "right", y = ns.SnapValue(f, fb - bb) }
    elseif math.abs(fr - bl) <= reach then
      rec = { side = "left", y = ns.SnapValue(f, fb - bb) }
    end
  end
  if WarpeeDB then
    WarpeeDB.cheapAttach = rec
    -- An attached list is placed from the bags, so the absolute record would be a second, older answer waiting to
    -- take over the next time the window opens.
    if rec then WarpeeDB.cheapPos = nil end
  end
  if rec then self:PlaceAttached() end
  return rec and true or false
end

-- The list travels with the bags: one watcher over their rectangle puts it back on its side whenever they move,
-- grow or shrink -- dragging the bags, a recent row arriving and making them taller, a resolution change. A
-- frame of a few number reads and nothing else while the list is up, and it stops the moment either window goes.
local watch, watchSig
local function watchStep()
  local f = Cheap.frame
  local a = WarpeeDB and WarpeeDB.cheapAttach
  if not (f and f:IsShown() and a) then
    watch:Hide()
    watchSig = nil
    return
  end
  local bags, bl, bb, br, bt = bagsRect()
  if not bags then return end
  -- Four numbers, compared as numbers: this runs every frame the list is up, and a formatted string per frame
  -- is garbage for nothing.
  local s = watchSig
  if not (s and s[1] == bl and s[2] == bb and s[3] == br and s[4] == bt) then
    watchSig = { bl, bb, br, bt }
    Cheap:PlaceAttached()
  end
end
function Cheap:Watch()
  if not (WarpeeDB and WarpeeDB.cheapAttach) then return end
  -- Built on first use: this file is read by the harness, which has no client to hand it a frame.
  if not watch then
    watch = CreateFrame("Frame")
    watch:Hide()
    watch:SetScript("OnUpdate", watchStep)
  end
  watchSig = nil
  watch:Show()
end

function Cheap:BagList()
  local list = {}
  local get = C_Container and C_Container.GetContainerNumSlots
  for bag = 0, (NUM_BAG_SLOTS or 4) do
    local n = get and get(bag) or 0
    if n and n > 0 then list[#list + 1] = bag end
  end
  return list
end

-- One row per stack shape: two stacks of one item with the same count are interchangeable, so the second is
-- not a second row -- the list reads as "what can go", not "where it lies". The first slot of the pair is
-- the one a click acts on.
function Cheap:Scan()
  local list, seen = {}, {}
  local qmax = maxShown()
  for _, bag in ipairs(self:BagList()) do
    local slots = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, slots do
      local info = containerInfo(bag, slot)
      local id = info and info.itemID
      if id and not info.isLocked and id ~= HEARTHSTONE and not isIgnored(id)
         and not lockedForSale(id, info.hyperlink)
         and (info.quality or 1) <= qmax then
        local q = questInfo(bag, slot)
        local isQuest = (q and (q.isQuestItem or q.questID)) and true or false
        local m = (not isQuest) and itemMeta(info.hyperlink) or nil
        if m and m.price > 0 then
          local count = info.stackCount or 1
          local key = id .. ":" .. count
          if not seen[key] then
            seen[key] = true
            -- The row is worth the better of the two sides: the vendor pays its price for the whole stack, the
            -- auction house pays its own per piece, and the side that wins is the one the player should take.
            -- Gray is the exception. A poor stack almost never sells, so whatever number the price addon still
            -- holds for it is usually stale, and the honest answer -- the one the row shows and sorts on -- is
            -- the vendor's: gray is asked at no auction house at all.
            local quality = info.quality or 1
            local aper = quality > 0 and self:AuctionPrice(id, info.hyperlink) or nil
            local kind, per = "vendor", m.price
            if aper and aper > m.price then kind, per = "auction", aper end
            list[#list + 1] = {
              itemID = id, bag = bag, slot = slot, link = info.hyperlink, name = m.name,
              count = count, price = m.price, total = m.price * count,
              vendor = m.price * count, auction = aper and (aper * count) or nil,
              best = per * count, kind = kind,
              quality = quality, icon = m.icon or info.iconFileID,
            }
          end
        end
      end
    end
  end
  table.sort(list, function(a, b)
    if a.best ~= b.best then return a.best < b.best end
    if a.itemID ~= b.itemID then return a.itemID < b.itemID end
    return a.count < b.count
  end)
  self.list = list
  return list
end

local function qualityColor(q)
  local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q or 1]
  c = c and c.color
  if c then return c.r, c.g, c.b end
  return Theme:C("text")
end

-- The stack is re-read before it is touched. Nothing is taken on faith from the row: the bags move under a
-- list painted a frame late (a loot, a sale), and a click on a slot that has changed hands would otherwise
-- throw away the piece that moved in.
local function stillThere(e)
  local info = containerInfo(e.bag, e.slot)
  if not (info and info.itemID == e.itemID and (info.stackCount or 1) == e.count) then return false end
  return not info.isLocked
end

-- What the cursor is holding, if it is the stack this row stands for. The identifier is the client's answer
-- rather than a promise: a build that hands back only the link, or only the type, is still holding the stack,
-- and a check that insisted on the id cleared the cursor and did nothing -- a click that reads as a window
-- which cannot delete.
local function cursorIs(e)
  local kind, id, link = GetCursorInfo and GetCursorInfo()
  if kind ~= "item" then return false end
  if id and id ~= e.itemID and (not link or link ~= e.link) then return false end
  return true
end

local function deleteStack(e, onDone)
  if GetCursorInfo and GetCursorInfo() then return false end
  if lockedForSale(e.itemID, e.link) then return false end
  if not stillThere(e) then return false end
  local pickup = (C_Container and C_Container.PickupContainerItem) or _G.PickupContainerItem
  if not pickup then return false end
  pickup(e.bag, e.slot)
  local function commit()
    if not cursorIs(e) then return false end
    if DeleteCursorItem then DeleteCursorItem() end
    if GetCursorInfo and GetCursorInfo() then
      if ClearCursor then ClearCursor() end
      return false
    end
    if onDone then onDone() end
    return true
  end
  if commit() then return true end
  -- Some builds answer a container pickup on their own beat: the cursor is still empty on the frame the pickup
  -- was asked for. Asking once more on the next frame turns a click that did nothing into the delete it
  -- promised, instead of leaving the stack on the cursor with no word said.
  C_Timer.After(0, function()
    if not cursorIs(e) then
      if GetCursorInfo and GetCursorInfo() and ClearCursor then ClearCursor() end
      return
    end
    commit()
  end)
  return false
end

local function sellStack(e)
  if not (MerchantFrame and MerchantFrame:IsShown()) then return false end
  if not stillThere(e) then return false end
  C_Container.UseContainerItem(e.bag, e.slot)
  return true
end

-- Green and better asks first. The dialog text and the buttons are the client's own words; the answer
-- carries the entry itself rather than its numbers, and the delete re-reads the slot when it runs.
local function askThenDelete(e, onDone)
  local from = confirmFrom()
  if not from or (e.quality or 1) < from then return deleteStack(e, onDone) end
  StaticPopupDialogs["WARPEE_DELETE_CHEAP"] = {
    text = DELETE_ITEM .. "\n\n%s\n\n",
    button1 = YES, button2 = NO,
    OnAccept = function(_, data)
      if data and data.entry then deleteStack(data.entry, onDone) end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3, showAlert = true,
  }
  -- Both arguments are handed to the dialog's SetFormattedText on this client, and a nil there is an error
  -- rather than an empty word: the second one is spelled out as nothing instead of left out.
  StaticPopup_Show("WARPEE_DELETE_CHEAP", e.link, "", { entry = e })
  return false
end

function Cheap:Act(e)
  if not e then return end
  if MerchantFrame and MerchantFrame:IsShown() then
    if sellStack(e) then self:Paint() end
    return
  end
  if askThenDelete(e, function() if Cheap.frame then Cheap:Paint() end end) then self:Paint() end
end

-- Taking a stack off the list, and putting it back: the same switch both ways, so an ignored item is never a
-- thing the window did to the player.
function Cheap:ToggleIgnore(id)
  local t = ignoredList()
  if not (t and id) then return end
  t[id] = (not t[id]) and true or nil
  -- A window that is not on screen is not repainted -- and is not built just to be repainted: the settings list
  -- is the one place this is pressed while the bags are shut.
  if self.frame and self.frame:IsShown() then self:Paint() end
  -- The settings page lists these same ids, and it can be open while the window is too. It was only rebuilt when
  -- the page was left and entered again, so a stack ignored from the list above kept sitting in the editor below
  -- -- or vanished from it -- long after it had gone. The mark-for-sale list announces its changes the same way
  -- (Vendor's sellRepaint), for the same reason: the editor is another view of a set this window already owns.
  local O = ns.Options
  if O and O.ReflowPages and O.frame and O.frame:IsShown() then O:ReflowPages() end
end

-- What the settings page lists: the ids the window was told to skip, with the name and the picture the client
-- has for them. Name and icon both wait for the client -- an id it has never answered for still lists, under its
-- number, which is the same answer an id field gives.
function Cheap:IgnoredCount()
  local n = 0
  for _ in pairs((WarpeeDB and WarpeeDB.cheapIgnored) or {}) do n = n + 1 end
  return n
end

function Cheap:IgnoredList()
  local out = {}
  for id in pairs((WarpeeDB and WarpeeDB.cheapIgnored) or {}) do
    out[#out + 1] = { itemID = id, name = ns.PinName(id) or tostring(id), icon = ns.PinIcon(id) }
  end
  table.sort(out, function(a, b) return tostring(a.name) < tostring(b.name) end)
  return out
end

local function buildRow(parent)
  local r = CreateFrame("Button", nil, parent)
  r:RegisterForClicks("LeftButtonUp")
  local bg = Theme:Rect(r, "panelHi", "BACKGROUND")
  bg:SetAllPoints(r)
  bg:Hide()
  r.bg = bg
  -- Inside the scroll frame the window's own snap pass does not walk, so every piece of a row is placed and
  -- sized on the grid here: a 24 ui-unit icon at this scale is a fraction of a physical pixel and would be
  -- stretched over the cell it sits in.
  local icon = r:CreateTexture(nil, "ARTWORK")
  ns.SnapSize(icon, ICON, ICON)
  ns.SnapPoint(icon, "LEFT", r, "LEFT", 2, 0)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.icon = icon
  -- Fixed slots from the right edge inwards: the money, then the name up to the icon. A label that sized itself
  -- would move the column on every paint, and the names would stop lining up down the list.
  -- The side and the money are one label: "AH 1g 20s" or "V 6c". Two labels meant a column narrow enough to
  -- clip the side out of the picture, which is the one thing it exists to say.
  -- The columns, from the right edge inwards: copper, silver, gold, and the side in front of them. The side has
  -- a colour of its own -- V is the merchant, AH is the auction house -- because beside a coin the letter was
  -- read as part of the number.
  local function column(width, anchor, gap)
    local fs = Theme:Label(r, FONT - 3, "dim")
    fs:SetJustifyH("RIGHT")
    fs:SetWordWrap(false)
    fs:SetWidth(width)
    ns.SnapPoint(fs, "RIGHT", anchor, anchor == r and "RIGHT" or "LEFT", -(gap or 0), 0)
    return fs
  end
  local copper = column(COL_C, r, 6)
  local silver = column(COL_S, copper, COL_GAP)
  local gold = column(COL_G, silver, COL_GAP)
  local side = column(SIDE_W, gold, 6)
  r.copper, r.silver, r.gold, r.side = copper, silver, gold, side

  -- The count on the icon, bottom-right, exactly where a bag cell puts its own: the column it used to have cost
  -- the name 28 points plus its gap and said nothing the picture could not hold.
  local count = Theme:Label(r, COUNT_FONT, "text")
  count:SetJustifyH("RIGHT")
  count:SetWordWrap(false)
  ns.SnapPoint(count, "BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, 0)
  r.count = count
  -- One line, and only one: the width is set from the fixed columns on every paint and the text is cut to it
  -- there, so a long name ends in an ellipsis instead of painting a second row over its neighbour.
  local name = Theme:Label(r, FONT - 2, "text")
  name:SetJustifyH("LEFT")
  name:SetWordWrap(false)
  Theme:Shadow(name, true)
  ns.SnapPoint(name, "LEFT", icon, "RIGHT", NAME_GAP, 0)
  r.Text = name
  local line = Theme:Rect(r, "strokeSoft", "ARTWORK")
  ns.PixelLine(line, 1)
  line:SetPoint("BOTTOMLEFT", 0, 0)
  line:SetPoint("BOTTOMRIGHT", 0, 0)
  r.line = line
  -- The ignore mark lives over the picture and nowhere else, the way a pinned item carries its remove mark, and
  -- it is only there while the pointer is on that picture. On the row it flickered: the mark appeared under the
  -- pointer, took the mouse away from the row, the row said leave, the mark went, the row said enter again, and
  -- that loop ran for as long as the pointer stood still. The plate below is always there -- the pointer never
  -- changes owner -- and what comes and goes is the rim and the mark drawn inside it.
  local hot = CreateFrame("Button", nil, r)
  -- The hotspot is the picture's whole column, gaps included: a row is 26 high and its picture 24, and the two
  -- dead pixels -- plus the gap out to the name -- were a strip where the pointer had already left the picture
  -- while a click still reached the row, so a player aiming at the icon deleted the stack instead of ignoring
  -- it. The ring itself still hugs the picture; only the target around it grew.
  hot:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
  hot:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
  hot:SetPoint("RIGHT", icon, "RIGHT", NAME_GAP, 0)
  hot:SetFrameLevel(r:GetFrameLevel() + 3)
  -- The same click the row registers, spelled out here rather than taken from whatever a bare button defaults
  -- to: a press on the picture must never be the press that throws the stack away.
  hot:RegisterForClicks("LeftButtonUp")
  local rim = CreateFrame("Frame", nil, hot, "BackdropTemplate")
  ns.PixelBackdrop(rim)
  local cr, cg, cb = Theme:C("bg")
  ns.SetBg(rim, cr, cg, cb, 0)
  -- Painted when the row is built as well as filed away for the theme: Theme:Track only keeps the pass for a
  -- restyle, and a row born after the last one kept the backdrop's default stroke -- the hover ring showed a
  -- plain border where the accent belongs.
  local function paintRim(s) ns.SetEdge(s, Theme:C("accent")) end
  Theme:Track(rim, paintRim)
  paintRim(rim)
  ns.SnapPoint(rim, "TOPLEFT", icon, "TOPLEFT", -1, 1)
  ns.SnapPoint(rim, "BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
  rim:Hide()
  local mark = CreateFrame("Frame", nil, hot)
  mark:SetPoint("TOPLEFT", icon, "TOPLEFT")
  mark:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT")
  ns.MarkMinus(mark, true)
  -- The mark takes the same accent, and for the same reason it is painted here and not only on a restyle.
  local function paintMark(s) ns.TintMarkX(s, "accent") end
  Theme:Track(mark, paintMark)
  paintMark(mark)
  mark:Hide()
  r.mark, r.rim, r.hot = mark, rim, hot

  -- Two hovers, two answers. On the strip the row lights and nothing else: the mark and the rim belong to the
  -- picture alone. On the picture the strip's light gives way -- one hover at a time, so the mark never stands
  -- over a row that is also lit -- the art dims under the outline, and a click ignores the stack.
  local function tip()
    local e = r.entry
    if not e then return end
    -- The client's own item tip and nothing of ours on top of it. The row already says the side, the price and
    -- what a click does, so every line this window added to the tip repeated something the player was looking
    -- at already -- once formatted differently, which read as a second, disagreeing answer.
    GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(e.link)
    GameTooltip:Show()
  end

  local function rowHot()
    if not r.entry then return end
    r.bg:SetAlpha(1); r.bg:Show()
    tip()
  end
  local function rowCold()
    r.bg:Hide()
    GameTooltip:Hide()
  end
  local function iconHot()
    if not r.entry then return end
    r.bg:Hide()
    r.rim:Show()
    r.mark:Show()
    r.icon:SetAlpha(0.45)
    tip()
  end
  local function iconCold()
    r.rim:Hide()
    r.mark:Hide()
    r.icon:SetAlpha(1)
    GameTooltip:Hide()
  end

  hot:SetScript("OnEnter", iconHot)
  hot:SetScript("OnLeave", iconCold)
  hot:SetScript("OnClick", function()
    if r.entry then Cheap:ToggleIgnore(r.entry.itemID) end
  end)
  r:SetScript("OnEnter", rowHot)
  r:SetScript("OnLeave", function()
    -- Sliding from the row onto its own picture is not leaving: both are the same hover, and hiding here made the
    -- pair blink as the pointer crossed the edge between them.
    if r.hot:IsMouseOver() then return end
    rowCold()
  end)
  r:SetScript("OnClick", function(s) Cheap:Act(s.entry) end)
  return r
end

function Cheap:Build()
  if self.frame then return self.frame end
  local f = CreateFrame("Frame", "WarpeeCheap", UIParent, "BackdropTemplate")
  f:Hide()
  -- Solid like the character picker: every row is a strip of its own, and a faded body would leave the
  -- strips standing alone over the world. Set before the window is dressed: the theme registers the frame
  -- for its transparency pass there and reads this flag at that moment.
  f.wpeSolid = true
  Theme:Panel(f, Theme:IsLight() and "bg" or "deep", "stroke")
  Theme:Window(f, "WarpeeCheap")
  Theme:Plate(f)
  -- The same stratum the pocket stands on: the two are one HUD over the bags, and the list must not sink under
  -- a window the pocket is already drawn over.
  f:SetFrameStrata("HIGH")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(s) ns.DragMove(s) end)
  f:SetScript("OnDragStop", function(s)
    if not s.wpeMoving then return end
    s.wpeMoving = nil
    s:StopMovingOrSizing()
    ns.Rebase(s, "cheapPos", "TOPLEFT")
    -- Snapping is always on for this window -- there is no switch to turn it off. Dropped near the bags it joins
    -- them and rides with them from then on; dropped away from them it keeps the rectangle it was given.
    Cheap:Attach()
    Cheap:Watch()
  end)
  ns.EscClose(f)
  ns.PixelJob(f, function(s) ns.AlignToScreen(s) end, "align")
  self.frame = f

  -- Placed in Paint, not here: the header rides the theme's own band and insets, and those are read on every
  -- pass, so a restyle moves the title, the cross and the viewport together instead of leaving them on the
  -- padding of the theme the window was built under.
  local title = Theme:Title(f, FONT, "accent")
  ns.LocalText(title, "Cheap")
  self.title = title

  local close = ns.CreateGlyphButton(f, "×", 20)
  close.wpeIconPaint = function(s)
    ns.TintMarkX(s, (s.wpeHot and not s.offDuty) and "text" or "dim")
  end
  close.wpeIconPaint(close)
  close:SetScript("OnClick", function() Cheap:Close() end)
  ns.AddTip(close, "Close", "top")
  self.closeBtn = close

  -- The viewport stays out of the pixel pass for the same reason the character list does: this client drops
  -- a scroll frame's offset when its points move, and that pass moves them.
  local sf = CreateFrame("ScrollFrame", nil, f)
  sf.wpePixelSkip = true
  sf:EnableMouseWheel(true)
  local child = CreateFrame("Frame", nil, sf)
  child:SetPoint("TOPLEFT")
  sf:SetScrollChild(child)
  self.sf, self.child = sf, child

  local bar = CreateFrame("Frame", nil, f)
  bar.wpePixelRect = true
  bar:SetWidth(BAR_W)
  bar:SetPoint("TOPLEFT", sf, "TOPRIGHT", 2, 0)
  bar:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 2, 0)
  local track = Theme:Rect(bar, "panel", "BACKGROUND")
  track:SetAllPoints(bar)
  local thumb = CreateFrame("Frame", nil, bar)
  thumb.wpePixelRect = true
  thumb:SetWidth(BAR_W)
  local thumbTex = Theme:Rect(thumb, "faint", "ARTWORK")
  thumbTex:SetAllPoints(thumb)
  bar:Hide()
  self.bar, self.thumb, self.thumbTex = bar, thumb, thumbTex

  sf:SetScript("OnMouseWheel", function(_, d)
    -- One row a notch: with three rows on screen a two-row step jumped most of the window at once.
    Cheap:ScrollTo((Cheap.scroll or 0) - d * ROW_H)
  end)

  local empty = Theme:Label(child, FONT - 3, "faint")
  empty:SetJustifyH("LEFT")
  empty:SetPoint("TOPLEFT", 0, 0)
  empty:SetPoint("RIGHT", 0, 0)
  ns.LocalText(empty, "Nothing cheap enough to throw away.")
  self.empty = empty

  -- The money columns are measured before they are drawn, and the measuring is done here: a label that is
  -- already placed answers with the width it was allowed to draw, not with the width of its string, so reading
  -- a row's own columns would only ever confirm the width they were given. This one is never shown and is
  -- never given a width, so it answers with the whole string.
  local meas = Theme:Label(child, FONT - 3, "dim")
  meas:SetWordWrap(false)
  meas:Hide()
  self.meas = meas

  return f
end

function Cheap:Span()
  if not (self.sf and self.child) then return 0 end
  return math.max(0, (self.child:GetHeight() or 0) - (self.sf:GetHeight() or 0))
end

function Cheap:ScrollTo(v)
  if not (self.sf and self.child) then return end
  local want = math.min(self:Span(), math.max(0, tonumber(v) or 0))
  self.scroll = want
  self.sf:SetVerticalScroll(want)
  self:PaintBar()
end

function Cheap:PaintBar()
  local sf, bar, thumb = self.sf, self.bar, self.thumb
  if not (sf and bar and thumb) then return end
  local span = self:Span()
  if span <= 0 then bar:Hide(); return end
  bar:Show()
  local view = sf:GetHeight() or 0
  local h = math.max(16, view * view / math.max(1, self.child:GetHeight()))
  ns.FitScrollThumb(thumb, bar, h, (self.scroll or 0) / span * (view - h))
end

function Cheap:Paint()
  local f = self:Build()
  -- The header, in the theme's own numbers: the art's band when a skin carries one, the title drop and the
  -- content insets on top of it. The Blizzard skin's nine-slice is thicker than the flat themes', and the
  -- fixed padding this window used to stand on buried the title under its border.
  local side = Theme:ContentPad("side")
  local padTop = Theme:ContentPad("top")
  local padBottom = PAD + Theme:ContentPad("bottom")
  local band = Theme:HeaderBand(f, BAND)
  local head = band and (band + 6) or (30 + Theme:TopInset())
  local mid = (band or head) / 2 + Theme:TitleDrop() + padTop
  head = head + padTop
  local path = ns.Fonts:Current()
  local innerW = WIDTH - (PAD + side) * 2 - BAR_W - 2

  self.title:ClearAllPoints()
  self.title:SetFont(path, FONT, ns.OutlineFlags())
  ns.SnapPoint(self.title, "LEFT", f, "TOPLEFT", PAD + side, -mid)
  ns.SizeGlyph(self.closeBtn, BAND - 6)
  self.closeBtn:ClearAllPoints()
  ns.SnapPoint(self.closeBtn, "RIGHT", f, "TOPRIGHT", -(6 + side), -mid)
  self.sf:ClearAllPoints()
  ns.SnapPoint(self.sf, "TOPLEFT", f, "TOPLEFT", PAD + side, -head)
  ns.SnapPoint(self.sf, "BOTTOMRIGHT", f, "BOTTOMRIGHT", -(PAD + side + BAR_W + 2), padBottom)

  local list = self:Scan()

  -- Every row's coins, and the widest of each unit across the list: the three widths the whole list will be
  -- written in. Measured, not guessed -- the coin is a texture inside the string and its size is not something
  -- a fixed width could know -- and shared, so one wide number widens the column for every row instead of
  -- cutting that one row's coin to "3...".
  local meas = self.meas
  local parts = {}
  local wG, wS, wC = 0, 0, 0
  for i, e in ipairs(list) do
    local g, s, c = ns.MoneyParts(e.best or e.total, false)
    local t = { moneyPart(g), moneyPart(s), moneyPart(c) }
    parts[i] = t
    if meas then
      meas:SetFont(path, FONT - 3, ns.OutlineFlags())
      for k = 1, 3 do
        meas:SetText(t[k] or "")
        local w = meas:GetStringWidth() or 0
        if k == 1 and w > wG then wG = w
        elseif k == 2 and w > wS then wS = w
        elseif k == 3 and w > wC then wC = w end
      end
      meas:SetText("")
    end
  end
  -- The measured widths start at zero, so a unit no row carries keeps no column at all: a slot standing empty
  -- for nothing would put a hole between the coins of every row on the list. A unit some row does carry keeps
  -- its column for the rows that do not, which is the whole point of lining the digits up. Without the
  -- measuring label the columns fall back to the widths they were built with.
  if not meas then wG, wS, wC = COL_G, COL_S, COL_C end
  local nameMax = math.max(40, innerW - 2 - ICON - NAME_GAP - 4
    - (wG + wS + wC + COL_GAP * 2 + 6 + SIDE_W) - 6)

  local y, n = 0, 0
  for _, e in ipairs(list) do
    n = n + 1
    local r = self.rows[n]
    if not r then r = buildRow(self.child); self.rows[n] = r end
    r.entry = e
    r.icon:SetTexture(e.icon)
    -- The first word only: "Battered Buckler" is a buckler in a list of cheap stacks, and the rest of the name
    -- was cut to an ellipsis anyway -- a word that is cut tells nothing, while the first one is what the player
    -- recognises the item by.
    local nm = e.name or tostring(e.itemID)
    nm = nm:match("^(%S+)") or nm
    r.Text:SetFont(path, FONT - 2, ns.OutlineFlags())
    r.Text:SetTextColor(qualityColor(e.quality))
    -- The count is the picture's own label now: inside the icon's corner, the same fold the bag cells use from a
    -- thousand up, and nothing at all on a single piece.
    r.count:SetFont(path, COUNT_FONT, ns.OutlineFlags())
    r.count:SetText(e.count > 1 and ns.ShortCount(e.count) or "")
    -- The cut is made on the string, then the width holds it: asking the label to fit a box it is already in
    -- would answer with the box, and nothing would ever be cut.
    ns.FitLabel(r.Text, nm, nameMax, true)
    r.Text:SetWidth(nameMax)
    -- Where the money comes from, in a column of its own: AH for the auction house and V for what a vendor pays.
    -- Its own colour as well -- the auction house keeps the accent, the merchant takes the azure -- because a
    -- white letter pressed against a coin read as part of the number rather than as the side of it.
    r.side:SetFont(path, FONT - 4, ns.OutlineFlags())
    r.side:SetText(e.kind == "auction" and "AH" or "V")
    r.side:SetTextColor(Theme:C(e.kind == "auction" and "accent" or "azure"))
    -- The coins, one column each, from the string pieces rather than the whole line: gold over gold, copper over
    -- copper. A unit the stack does not carry is written as nothing, and its column is what keeps the digits of
    -- the units above it in place. The widths are the ones measured over the whole list, so the coin is never
    -- cut, and the row keeps the same three columns as its neighbours.
    local txt = parts[n]
    local cols = { r.gold, r.silver, r.copper }
    local widths = { wG, wS, wC }
    for i = 1, 3 do
      local fs = cols[i]
      fs:SetFont(path, FONT - 3, ns.OutlineFlags())
      fs:SetWidth(widths[i])
      fs:SetText(txt and txt[i] or "")
      fs:SetTextColor(Theme:C("dim"))
    end

    r:SetHeight(ns.SnapValue(r, ROW_H))
    r:ClearAllPoints()
    ns.SnapPoint(r, "TOPLEFT", self.child, "TOPLEFT", 0, -y)
    ns.SnapPoint(r, "TOPRIGHT", self.child, "TOPRIGHT", 0, -y)
    r:Show()
    y = ns.SnapValue(self.child, y + ROW_H)
  end
  for i = n + 1, #self.rows do
    self.rows[i].entry = nil
    self.rows[i]:Hide()
  end

  self.empty:SetFont(path, FONT - 3, ns.OutlineFlags())
  self.empty:SetShown(n == 0)
  ns.SnapSize(self.child, innerW, math.max(1, y))

  local rows = math.max(1, math.min(n, MAX_ROWS))
  ns.SnapSize(f, WIDTH, head + rows * ROW_H + padBottom)
  Theme:FitPlateOf(f)
  self:ScrollTo(self.scroll or 0)
end

function Cheap:Refresh()
  if not (self.frame and self.frame:IsShown()) then return end
  self:Paint()
end

function Cheap:Place()
  local f = self:Build()
  if self:PlaceAttached() then return end
  if WarpeeDB and WarpeeDB.cheapPos then
    ns.PlaceWindow(f, "cheapPos")
    return
  end
  -- Never dragged and never attached: above the bags, as it opens the first time. It starts out attached there,
  -- so the bags carry it from the beginning.
  local bags = ns.Bags and ns.Bags.frame
  if bags and bags:IsShown() then
    if WarpeeDB then WarpeeDB.cheapAttach = { side = "above", x = 0 } end
    self:PlaceAttached()
  else
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
  end
end

-- A restyle moves the header with the theme: the band is read again, and so are the content insets. Without
-- this the window kept the padding of the theme it was built under -- the gap of a textured header stayed
-- behind after the art was gone, and the Blizzard skin did not push the rows inside its thicker border.
function Cheap:Restyle()
  if not (self.frame and self.frame:IsShown()) then return end
  -- Placed again as well as painted: the seam gap belongs to the theme, so the window steps back from the bags
  -- when the new skin's rims ask for more air.
  self:Place()
  self:Paint()
end

function Cheap:Open()
  local f = self:Build()
  -- Every open asks again: the list is a window on this moment's prices, and a miss carried over from the last
  -- session is exactly how a scanned auction failed to show until the addon was reloaded.
  self:ClearAuction()
  self:Place()
  self:Watch()
  self.scroll = 0
  f:Show()
  self:Paint()
  Theme:Raise(f)
end

function Cheap:Close()
  if self.frame then self.frame:Hide() end
  if watch then watch:Hide() end
  watchSig = nil
end

-- The bags bring it and the bags take it: it is one window with them, not a list that can be left standing
-- over a closed bag. A player who closes it by hand gets it back with the next open.
--
-- Opened a frame late, on purpose: this window scans every bag and builds its rows, and that work on the bags'
-- own open was paid by the frame the player is watching. One frame behind is invisible, and the bags' open
-- stays its own.
function Cheap:MaybeShow()
  if self.pending then return end
  if WarpeeDB and WarpeeDB.cheapShow == false then return end
  if self.frame and self.frame:IsShown() then return end
  self.pending = true
  C_Timer.After(0, function()
    self.pending = nil
    if self.frame and self.frame:IsShown() then return end
    if not (ns.Bags and ns.Bags.frame and ns.Bags.frame:IsShown()) then return end
    self:Open()
  end)
end

function Cheap:BagsClosed()
  if self.frame and self.frame:IsShown() then self.frame:Hide() end
end

-- The bags move under the list: a loot, a sale, a delete of its own. Every pass is deferred a frame, so a
-- burst of BAG_UPDATE events paints once.
local ev = CreateFrame("Frame")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:RegisterEvent("PLAYER_MONEY")
pcall(ev.RegisterEvent, ev, "AUCTION_HOUSE_SHOW")
pcall(ev.RegisterEvent, ev, "MERCHANT_SHOW")
pcall(ev.RegisterEvent, ev, "MERCHANT_CLOSED")
-- A listing bought or sold moves the numbers under the list, and a miss from before it is remembered as firmly
-- as a hit, so opening and closing the auction house clears both (Auctionator's own update hook lives beside
-- ClearAuction).
pcall(ev.RegisterEvent, ev, "AUCTION_HOUSE_CLOSED")
ev:SetScript("OnEvent", function(_, event)
  -- A fresh auction house is a fresh chance at a price for the stacks that had none: the misses go, and an open
  -- list repaints on them.
  if event == "AUCTION_HOUSE_SHOW" or event == "AUCTION_HOUSE_CLOSED" then
    Cheap:ClearAuction()
    if Cheap.frame and Cheap.frame:IsShown() then Cheap:Refresh() end
    return
  end
  if not (Cheap.frame and Cheap.frame:IsShown()) then return end
  if Cheap.busy then return end
  Cheap.busy = true
  C_Timer.After(0, function()
    Cheap.busy = nil
    Cheap:Refresh()
  end)
end)
