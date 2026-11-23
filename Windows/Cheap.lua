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
local WIDTH, MAX_ROWS, FONT = 460, 3, 15
local ICON, NAME_GAP = 24, 8
-- The two actions at the right of every row, after the price: the row itself is only a hover and a tooltip, so
-- the destructive act is a plate that names itself. Only one plate stands in a row -- the act is what the window
-- is for, and two equal boxes read as a settings dialog rather than as a list. Ignore is a word beside it: still
-- a named control with its own tooltip, but a secondary one, so it does not argue with the price.
local PLATE_MIN_W, PLATE_H, PLATE_GAP, PLATE_PAD = 34, 18, 6, 12
-- The plate's air: the row's right edge, and the gap the coins keep from the word in front of it.
local PLATE_EDGE, PLATE_COIN_GAP = 6, 8
-- Every word the act plate can wear. It is sized for the longer of them so its width does not twitch when a
-- merchant opens. Ignore is measured too: its word is a click target of its own, with the plate's padding.
local ACT_WORDS, IGNORE_WORD = { "Sell", "Delete" }, "Ignore"
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

-- The coins are the gold tooltip's own: a piece MoneyParts hands back is written as it stands, zeros included,
-- so a stack worth 2 gold reads "2g 0s 0c" here exactly as it does in the gold list. A unit above the highest one
-- the price carries is nil and stays empty -- 30 copper is copper, not "0g 0s 30c" -- which is also the
-- tooltip's rule. The columns already hold the place, so a zero no longer has to be dropped to keep the digits
-- of a ten from sitting under a "0".
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
  return qualitySetting("cheapConfirm", 1)
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
  return C_Item and C_Item.GetItemInfo
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

-- One row per slot. Two stacks of one item are two stacks, not one: the player may throw away one of them and
-- keep the other, and a list that showed a single row for a pair would be lying about what the bags hold -- the
-- two rows carry the same name and the same price because the two pieces do, and each row keeps the bag and the
-- slot it was read from, so a click acts on exactly the piece it was pointed at.
function Cheap:Scan()
  local list = {}
  local qmax = maxShown()
  for _, bag in ipairs(self:BagList()) do
    local slots = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, slots do
      local info = containerInfo(bag, slot)
      local id = info and info.itemID
      -- The protection lists in Items/Protected.lua answer both doors: a piece kept from a merchant is kept
      -- from a destroy as well, so a rule list cannot tell a player one thing and the window another.
      if id and not info.isLocked and id ~= HEARTHSTONE and not isIgnored(id)
         and not lockedForSale(id, info.hyperlink) and not ns.ProtectedItem(id, "delete")
         and (info.quality or 1) <= qmax then
        local q = questInfo(bag, slot)
        local isQuest = (q and (q.isQuestItem or q.questID)) and true or false
        local m = (not isQuest) and itemMeta(info.hyperlink) or nil
        if m and m.price > 0 then
          local count = info.stackCount or 1
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
  if ns.ProtectedItem(e.itemID, "delete") then return false end
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

-- White and better asks first, out of the box. The dialog text and the buttons are the client's own words; the
-- answer carries the entry itself rather than its numbers, and the delete re-reads the slot when it runs.
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
  -- The controls first, and the plate at the outer edge: the destructive one stands furthest from the price, where
  -- the hand is not already working, and the quiet word sits between it and the coins. The act is a plate, not a
  -- bare word -- the destructive one must read as a control, not as a label the eye skips -- while Ignore is a word
  -- of the addon's secondary kind.
  -- One answer to "is a merchant open", read by the plate's word and by its tooltip alike: two spellings of the
  -- same question is how a plate came to promise a sale the click would not make.
  local function selling()
    return (MerchantFrame and MerchantFrame:IsShown()) and true or false
  end
  local act = ns.CreateButton(r, "", PLATE_MIN_W, PLATE_H)
  act:RegisterForClicks("LeftButtonUp")
  ns.SnapPoint(act, "RIGHT", r, "RIGHT", -PLATE_EDGE, 0)
  -- No tooltip on either control. The plate carries the word for what it does, and the word changes with the
  -- merchant, so a tip could only repeat it; a window of six rows that answers the pointer on every plate is
  -- noise over the item tip that is already there. The two controls stand under the pointer long enough to be
  -- read, which is the whole of what a tooltip would have added.
  -- The plate is a control of the window's own ink, and the red arrives only at the moment a hand is on the way
  -- down. A permanent red word on every row — six of them down the list — teaches the eye to stop looking, and a
  -- warning nobody sees is not one. With a merchant open the plate is a sale, and a sale is not a warning: it
  -- brightens under the pointer and wears no red at all.
  act.wpeIconPaint = function(s)
    local hot = s.wpeHot and not s.offDuty
    ns.SetEdge(s, Theme:C("stroke"))
    if not s.Text then return end
    if s.wpeSell then
      s.Text:SetTextColor(Theme:C(hot and "overlay" or "text"))
      return
    end
    s.Text:SetTextColor(Theme:C(hot and "dangerHi" or "text"))
  end
  r.syncAct = function()
    local sell = selling()
    act.wpeSell = sell
    ns.LocalText(act.Text, sell and "Sell" or "Delete")
    act:Repaint()
  end
  r.syncAct()
  act:SetScript("OnClick", function()
    if r.entry then Cheap:Act(r.entry) end
  end)
  -- The word beside the plate is the faintest ink in the window: not the azure a secondary action usually stands
  -- in, and not white either. Beside a plate of the same height a readable word read as a weaker second button,
  -- and the eye kept asking which of the two was the real control -- so it steps back, and only the pointer brings
  -- it forward. That brightening is the whole of its affordance, and its click target is a pad wider than the
  -- letters, so a word is still a comfortable thing to hit.
  local ignore = ns.CreateTextButton(r, FONT - 4)
  ignore:RegisterForClicks("LeftButtonUp")
  ns.SnapPoint(ignore, "RIGHT", act, "LEFT", -PLATE_GAP, 0)
  ns.LocalText(ignore.Text, "Ignore")
  -- The word answers the pointer with its ink and nothing else: it steps from the faintest kind to plain white as
  -- the pointer lands on it, which at this size is the whole of the answer a word needs. No line under it, no box,
  -- no ground of its own -- each of those dressed it as the second button the eye kept mistaking it for.
  ignore.Paint = function(s)
    s.Text:SetTextColor(Theme:C((s.wpeHot and not s.offDuty) and "text" or "faint"))
  end
  ignore:Paint()
  ignore:SetScript("OnClick", function()
    if r.entry then Cheap:ToggleIgnore(r.entry.itemID) end
  end)
  -- Nothing about the two controls follows the pointer: both stand on every row, always, and the item tip is
  -- left alone when the pointer crosses onto them -- a plate that took the tip away would leave the pointer over
  -- a control with nothing to say about the piece it belongs to.
  r.act, r.ignore = act, ignore

  local function column(width, anchor, gap)
    local fs = Theme:Label(r, FONT - 3, "dim")
    fs:SetJustifyH("RIGHT")
    fs:SetWordWrap(false)
    fs:SetWidth(width)
    ns.SnapPoint(fs, "RIGHT", anchor, anchor == r and "RIGHT" or "LEFT", -(gap or 0), 0)
    return fs
  end
  local copper = column(COL_C, ignore, PLATE_COIN_GAP)
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

  -- The left half of the row says what the piece is and carries the item's own tip; the right end carries the two
  -- controls. Nothing on the row itself sells, deletes or ignores: the destructive gesture is the plate that wears
  -- the word for it, and the pointer only lights the ground it stands on.
  local function tip()
    local e = r.entry
    if not e then return end
    -- The client's own item tip and nothing of ours on top of it. The row already says the side and the price,
    -- the plates say what they do, so every line this window added to the tip repeated something the player was
    -- looking at already -- once formatted differently, which read as a second, disagreeing answer.
    -- The tip opens at the pointer rather than off a side of the row: this window stands against the bags, so a
    -- tip pinned to either edge of a full-width row covered something the player was using -- the controls on the
    -- right, the bags on the left. At the cursor it stays next to the piece being read, and the client keeps it on
    -- the screen by itself, whichever edge of the world the window happens to be near.
    GameTooltip:SetOwner(r, "ANCHOR_CURSOR")
    GameTooltip:SetHyperlink(e.link)
    GameTooltip:Show()
  end

  -- Live ground and the item's tip are one thing, and both belong to what the row shows -- picture, name, price --
  -- ending where the coins end. The row's right end carries the two controls: a pointer there is deciding, not
  -- reading, so the ground stays dark under it and the tip stays away. That is also why this region stops short of
  -- the word by PLATE_GAP: walking from the price to the word crosses the gap and loses the light, which is the
  -- answer to "am I still on the piece or already on the button".
  local liveZone = CreateFrame("Frame", nil, r)
  liveZone:EnableMouse(true)
  liveZone:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
  liveZone:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
  liveZone:SetPoint("RIGHT", ignore, "LEFT", -PLATE_GAP, 0)
  liveZone:SetScript("OnEnter", function()
    if not r.entry then return end
    -- The ground lights and nothing else moves: the plates do not need it, they are already there, and a
    -- highlight that pushed them around would be the only thing the hover changed.
    r.bg:SetAlpha(1)
    r.bg:Show()
    tip()
  end)
  liveZone:SetScript("OnLeave", function()
    r.bg:Hide()
    GameTooltip:Hide()
  end)
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

  local function wheel(_, d)
    -- One row a notch: with three rows on screen a two-row step jumped most of the window at once.
    Cheap:ScrollTo((Cheap.scroll or 0) - d * ROW_H)
  end
  sf:SetScript("OnMouseWheel", wheel)
  -- The bar is a strip of the window the pointer can rest on, and a wheel turn there fell through to the
  -- window and moved nothing: the list only answered while the pointer was over the viewport itself.
  bar:EnableMouse(true)
  bar:EnableMouseWheel(true)
  bar:SetScript("OnMouseWheel", wheel)
  -- A press off the thumb pages one view. The track was dead to the click, so the only way to move the list
  -- with the mouse was its wheel; a scrollbar that ignores a press reads as a broken one.
  bar:SetScript("OnMouseDown", function(_, button)
    if button ~= "LeftButton" then return end
    local _, y = GetCursorPosition()
    y = y / (UIParent:GetEffectiveScale() or 1)
    local top, bottom = thumb:GetTop(), thumb:GetBottom()
    if not (top and bottom) then return end
    local page = math.max(ROW_H, (sf:GetHeight() or 0) - (thumb:GetHeight() or 0))
    if y > top then
      Cheap:ScrollTo((Cheap.scroll or 0) - page)
    elseif y < bottom then
      Cheap:ScrollTo((Cheap.scroll or 0) + page)
    end
  end)
  -- The thumb itself drags. The bar only ever reported where the list stood, so holding the thumb and pulling
  -- moved nothing at all; ScrollThumb is the drag every other window here already has.
  ns.ScrollThumb(thumb, thumbTex, sf, function(v) Cheap:ScrollTo(v) end,
    function() return Cheap:Span() end)

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
    local t = { g, s, c }
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
  -- The plate's width is the widest act word it can wear here, so it never twitches when a merchant opens; the
  -- word that stands beside it is measured too, because its click target is as wide as itself. Both are measured
  -- on the one label that is never given a width, before anything is placed, so the digits and the name are
  -- placed against the answer.
  local plateW, igW = PLATE_MIN_W, PLATE_MIN_W
  if meas then
    meas:SetFont(path, FONT - 4, ns.OutlineFlags())
    local function wordW(key)
      meas:SetText(ns.L[key] or key)
      return (meas:GetStringWidth() or 0) + PLATE_PAD
    end
    for i = 1, #ACT_WORDS do
      local w = wordW(ACT_WORDS[i])
      if w > plateW then plateW = w end
    end
    igW = math.max(PLATE_MIN_W, wordW(IGNORE_WORD))
    meas:SetText("")
  end
  local function dressPlate(b)
    if not b then return end
    ns.SnapSize(b, plateW, PLATE_H)
    b.Text:SetFont(path, FONT - 4, ns.OutlineFlags())
  end
  local function dressIgnore(b)
    if not b then return end
    ns.SnapSize(b, igW, PLATE_H)
    b.Text:SetFont(path, FONT - 4, ns.OutlineFlags())
  end
  -- The controls stand at the right edge and the coins anchor to the plate, so the name gives up both widths,
  -- their gap and the air around them as well as the money columns.
  local actions = plateW + PLATE_GAP + igW + PLATE_EDGE + PLATE_COIN_GAP
  local nameMax = math.max(40, innerW - 2 - ICON - NAME_GAP - 4
    - (wG + wS + wC + COL_GAP * 2 + 6 + SIDE_W) - actions)

  local y, n = 0, 0
  for _, e in ipairs(list) do
    n = n + 1
    local r = self.rows[n]
    if not r then r = buildRow(self.child); self.rows[n] = r end
    r.entry = e
    r.syncAct()
    dressPlate(r.act)
    dressIgnore(r.ignore)
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
    -- copper. A unit above the price's highest one is written as nothing, and its column is what keeps the digits
    -- of the units in place; a zero MoneyParts wrote ("2g 0s 0c") is kept, as the gold tooltip keeps it. The
    -- widths are the ones measured over the whole list, so the coin is never cut, and the row keeps the same
    -- three columns as its neighbours.
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
-- The visit's close takes the window with it (see the handler): a plate that promised a sale a moment ago
-- must not answer the same click with a delete.
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
  -- The merchant's counter is the one place the plate offers a sale, and the sale ends with him: a
  -- repaint here turned every Sell into Delete under the hand that was reaching for it, on the same
  -- stack. The list goes with the visit instead, and the next open asks again.
  if event == "MERCHANT_CLOSED" then
    if Cheap.frame and Cheap.frame:IsShown() then Cheap:Close() end
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

-- The window's own settings, declared beside the passes they owe, the way every other window keeps them
-- (Core/Settings.lua): the options page asks for a change and this file writes the key, so no page puts a
-- value in the save on its own and no change lands without the repaint behind it.
local function repaint()
  if Cheap.frame and Cheap.frame:IsShown() then Cheap:Paint() end
end

local setShow = ns.Setting("cheapShow", function(value)
  -- Switched on is a request for the window, not just permission for it: with the bags up the list comes
  -- back now, through the same door that brings it with them; switched off it leaves the screen at once.
  if value then
    if Cheap.MaybeShow then Cheap:MaybeShow() end
  elseif Cheap.Close then
    Cheap:Close()
  end
end)
-- A cut or a source change moves every number on the list, and each cached price was an answer from the rule
-- that stood before the click: the cache goes and the open list is painted from the new rule.
local setCut = ns.Setting("cheapCut", function() Cheap:ClearAuction(); repaint() end)
local setMax = ns.Setting("cheapMaxQuality", repaint)
local setConfirm = ns.Setting("cheapConfirm")
local setSource = ns.Setting("cheapAuctionSource", function() Cheap:ClearAuction(); repaint() end)
local setKeepConsumable = ns.Setting("cheapKeepConsumable", repaint)
local setKeepRecipe = ns.Setting("cheapKeepRecipe", repaint)
local setKeepCollectible = ns.Setting("cheapKeepCollectible", repaint)

function Cheap:SetShown(value) setShow(value and true or false) end
function Cheap:SetCut(value) setCut(value and true or false) end
function Cheap:SetMaxQuality(value) setMax(value) end
function Cheap:SetConfirm(value) setConfirm(value) end
function Cheap:SetAuctionSource(value) setSource(value) end
function Cheap:SetKeep(key, value)
  if key == "cheapKeepConsumable" then setKeepConsumable(value and true or false)
  elseif key == "cheapKeepRecipe" then setKeepRecipe(value and true or false)
  elseif key == "cheapKeepCollectible" then setKeepCollectible(value and true or false)
  end
end
