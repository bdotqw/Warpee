local addonName, ns = ...
local Theme = ns.Theme

ns.playerBags = { 0, 1, 2, 3, 4 }
ns.reagentBag = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5
ns.reagentBank = (Enum and Enum.BagIndex and Enum.BagIndex.Reagentbank) or -3

local SIZE_DEFAULT, PAD = 37, 10
local COLS_DEFAULT, GAP_DEFAULT = 14, 4
local HEADER, FOOTER = 66, 28
local DIV = 22
local HB, HGAP, HBTNS, SEARCH_MIN = 26, 4, 5, 80
local ROW1_Y = 6
local GAUGE_Y = ROW1_Y + HB + 4
local ROW2_Y = GAUGE_Y + 6

local Bags = { pool = {}, vpool = {}, cols = COLS_DEFAULT, gap = GAP_DEFAULT, iconSize = SIZE_DEFAULT,
               slotStyle = "tile", showGauge = true, goldLetters = false, goldOnly = false,
               font = "Arial Narrow", query = "", dirty = {},
               ilvlSize = 12, ilvlAnchor = "TOPLEFT", ilvlX = 3, ilvlY = -3,
               countSize = 14, countAnchor = "BOTTOMRIGHT", countX = -2, countY = 2,
               qualityColorIlvl = false, qualityBorder = false, iconZoom = 1, borderWidth = 2, mergeReagents = false, questMarks = false, newItemGlow = false, junkIcon = false,
               styleGen = 1 }
ns.Bags = Bags

local function stepFor(size, gap) return size + gap end
local function gridWidth(size, cols, gap) return (cols - 1) * (size + gap) + size end
function Bags:TopOffset() return HEADER + 4 end

function Bags:Build()
  if self.frame then return self.frame end

  local f = CreateFrame("Frame", "WarpeeFrame", UIParent, "BackdropTemplate")
  Theme:Panel(f, "bg", "stroke")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(s) ns.DragStart(s) end)
  f:SetScript("OnDragStop", function(s)
    if not s.wpeMoving then return end
    s.wpeMoving = nil
    s:StopMovingOrSizing()
    ns.Rebase(s, "pos")
  end)
  Theme:Window(f, "WarpeeFrame")
  f:SetScript("OnHide", function()
    if ns.CharPicker then ns.CharPicker:Close() end
    if ns.Vault:SetView("bags", nil) then
      Bags.snap = nil
      Bags:UpdateCharTag()
    end
  end)
  self.frame = f
  ns.CreateMoveBar(f, "pos")

  local title = Theme:Title(f, 15)
  title:SetPoint("BOTTOMLEFT", PAD, 6)
  title:SetText("WARPEE")
  title:SetTextColor(Theme:C("accent"))
  self.title = title

  local function addTip(btn, txt)
    ns.AddTip(btn, txt, "top")
  end

  local close = ns.CreateGlyphButton(f, "×", HB)
  close:SetPoint("TOPRIGHT", -PAD, -6)
  close:SetScript("OnClick", function() ns.Toggle(false) end)

  local sort = ns.CreateGlyphButton(f, "", HB)
  sort:SetScript("OnClick", function() Bags:SortBags() end)
  addTip(sort, "Sort / clean up bags")
  local sortIcon = sort:CreateTexture(nil, "ARTWORK")
  sortIcon:SetAtlas("auctionhouse-ui-sortarrow")
  sortIcon:SetSize(13, 15)
  sortIcon:SetPoint("CENTER")
  sortIcon:SetVertexColor(Theme:C("text"))
  sort.icon = sortIcon
  self.sortBtn = sort

  local gear = ns.CreateGlyphButton(f, "|TInterface\\Buttons\\UI-OptionsButton:15:15:0:0|t", HB)
  gear:SetPoint("TOPRIGHT", close, "TOPLEFT", -4, 0)
  gear:SetScript("OnClick", function() if ns.Options then ns.Options:Toggle() end end)
  addTip(gear, "Settings")

  local bagsToggle = ns.CreateGlyphButton(f, "", HB)
  bagsToggle:SetPoint("TOPRIGHT", gear, "TOPLEFT", -4, 0)
  bagsToggle:SetScript("OnClick", function() Bags:ToggleBagWindow() end)
  addTip(bagsToggle, "Bags")
  local bagIcon = bagsToggle:CreateTexture(nil, "ARTWORK")
  bagIcon:SetAtlas("bag-main")
  bagIcon:SetSize(22, 22)
  bagIcon:SetPoint("CENTER")
  bagIcon:SetVertexColor(Theme:C("text"))
  bagsToggle.icon = bagIcon
  self.bagsToggle = bagsToggle

  local bank = ns.CreateGlyphButton(f, "", HB)
  bank:SetPoint("TOPRIGHT", bagsToggle, "TOPLEFT", -4, 0)
  bank:SetScript("OnClick", function() if ns.ToggleBank then ns.ToggleBank() end end)
  addTip(bank, "Bank / Warband")
  local bankIcon = bank:CreateTexture(nil, "ARTWORK")
  local atlasOK = C_Texture and C_Texture.GetAtlasInfo
                  and C_Texture.GetAtlasInfo("Minimap_tracking_banker")
  if atlasOK then
    bankIcon:SetAtlas("Minimap_tracking_banker")
  else
    bankIcon:SetTexture("Interface\\Minimap\\Tracking\\Banker")
  end
  bankIcon:SetSize(20, 20)
  bankIcon:SetPoint("CENTER")
  bankIcon:SetVertexColor(Theme:C("text"))
  bank.icon = bankIcon
  self.bankBtn = bank

  sort:SetPoint("TOPRIGHT", bank, "TOPLEFT", -4, 0)

  local sell = ns.CreateGlyphButton(f, "", HB)
  sell:SetPoint("TOPRIGHT", sort, "TOPLEFT", -4, 0)
  sell:SetScript("OnClick", function() if ns.Vendor then ns.Vendor:Sell() end end)
  ns.AddTip(sell, "Sell low gear", "top", function()
    return ns.Vendor and ns.Vendor:TipLines() or nil
  end)
  local sellIcon = sell:CreateTexture(nil, "ARTWORK")
  sellIcon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
  sellIcon:SetSize(16, 16)
  sellIcon:SetPoint("CENTER")
  sell.icon = sellIcon
  sell:Hide()
  self.sellBtn = sell

  local freeText = Theme:Label(f, 12, "dim")
  self.freeText = freeText

  local charTag = ns.CreateCharTag(f, HB, "left")
  charTag:SetPoint("TOPLEFT", PAD, -ROW1_Y)
  charTag:SetScript("OnClick", function(s) Bags:ToggleCharPicker(s) end)
  addTip(charTag, "Snapshot of another character")
  self.charTag = charTag
  freeText:SetPoint("LEFT", charTag, "RIGHT", 8, 0)

  local search = ns.CreateSearchBox(f, function(text)
    self.query = (text or ""):lower()
    self.filters = ns.ParseSearch(self.query)
    self:ApplySearch()
  end)
  search:SetPoint("TOPLEFT", PAD, -ROW2_Y)
  search:SetPoint("TOPRIGHT", -PAD, -ROW2_Y)
  search:SetHeight(22)
  self.search = search

  local gaugeBg = Theme:Rect(f, "panel", "BACKGROUND")
  gaugeBg:SetHeight(2)
  gaugeBg:SetPoint("TOPLEFT", PAD, -GAUGE_Y)
  gaugeBg:SetPoint("TOPRIGHT", -PAD, -GAUGE_Y)
  local gaugeFill = Theme:Rect(f, "azure", "ARTWORK")
  gaugeFill:SetHeight(2)
  gaugeFill:SetPoint("TOPLEFT", gaugeBg, "TOPLEFT")
  self.gaugeBg, self.gaugeFill = gaugeBg, gaugeFill

  local content = CreateFrame("Frame", nil, f)
  self.content = content

  local gridBg = Theme:Rect(f, "panel", "BACKGROUND")
  gridBg:SetDrawLayer("BACKGROUND", 1)
  self.gridBg = gridBg

  local money = Theme:Label(f, 16, "text")
  money:SetPoint("BOTTOMRIGHT", -PAD, 6)
  self.money = money
  ns.AttachGoldTooltip(money, f)

  local rlabel = Theme:Label(content, 11, "reagent")
  rlabel:SetText("REAGENTS")
  rlabel:Hide()
  self.reagentLabel = rlabel

  f:Hide()
  return f
end

function Bags:BuildBagWindow()
  if self.bagWindow then return self.bagWindow end
  local BPAD = 12
  local w = CreateFrame("Frame", "WarpeeBagsWindow", UIParent, "BackdropTemplate")
  Theme:Panel(w, "bg", "stroke")
  w:SetFrameStrata("DIALOG")
  w:SetClampedToScreen(true)
  w:SetMovable(true); w:EnableMouse(true)
  w:RegisterForDrag("LeftButton")
  w:SetScript("OnDragStart", function(s) ns.DragStart(s) end)
  w:SetScript("OnDragStop", function(s)
    if not s.wpeMoving then return end
    s.wpeMoving = nil
    s:StopMovingOrSizing()
    local pp, _, rp, x, y = s:GetPoint()
    WarpeeDB.bagWinPos = { p = pp, rp = rp, x = x, y = y }
  end)
  tinsert(UISpecialFrames, "WarpeeBagsWindow")

  local title = Theme:Title(w, 14)
  title:SetPoint("TOPLEFT", BPAD, -8)
  title:SetText("BAGS")
  title:SetTextColor(Theme:C("accent"))
  self.bagTitle = title

  local wclose = ns.CreateGlyphButton(w, "×")
  wclose:SetPoint("TOPRIGHT", -6, -6)
  wclose:SetScript("OnClick", function() w:Hide() end)

  local bagList = { 0, 1, 2, 3, 4, ns.reagentBag }
  self.bagButtons = {}
  for _, bagID in ipairs(bagList) do
    self.bagButtons[#self.bagButtons + 1] = ns.CreateBagButton(w, bagID, self:BagWinButtonSize())
  end
  w:Hide()
  self.bagWindow = w
  self:LayoutBagWindow()
  return w
end

function Bags:BagWinButtonSize()
  return self.iconSize or 37
end

function Bags:LayoutBagWindow()
  local w = self.bagWindow
  if not w or not self.bagButtons then return end
  local BGAP, BPAD, BHEAD = 6, 12, 30
  local size = self:BagWinButtonSize()
  local cf = self.countSize or 14
  local prev
  for _, b in ipairs(self.bagButtons) do
    b:SetSize(size, size)
    b:ClearAllPoints()
    if prev then b:SetPoint("LEFT", prev, "RIGHT", BGAP, 0)
    else b:SetPoint("TOPLEFT", BPAD, -BHEAD) end
    b.cntFontSize = cf
    if b.count then
      b.count:ClearAllPoints()
      b.count:SetPoint("BOTTOMRIGHT", -3, 3)
    end
    prev = b
  end
  local n = #self.bagButtons
  w:SetSize(BPAD * 2 + n * size + (n - 1) * BGAP, BHEAD + size + BPAD)
  self:UpdateBagBar()
end

function Bags:ToggleBagWindow()
  local w = self:BuildBagWindow()
  if w:IsShown() then w:Hide(); return end
  w:ClearAllPoints()
  local pp = WarpeeDB and WarpeeDB.bagWinPos
  if pp then
    w:SetPoint(pp.p, UIParent, pp.rp, pp.x, pp.y)
  elseif self.frame then
    w:SetPoint("BOTTOMLEFT", self.frame, "TOPLEFT", 0, 6)
  else
    w:SetPoint("CENTER")
  end
  self:LayoutBagWindow()
  w:Show()
  self:UpdateBagBar()
end

function Bags:Acquire(i)
  if self.snap then
    local b = self.vpool[i]
    if not b then
      b = ns.CreateVaultButton(self.content)
      self.vpool[i] = b
    end
    return b
  end
  local b = self.pool[i]
  if not b then
    b = ns.CreateItemButton(self.content, 0, 1)
    self.pool[i] = b
  end
  return b
end

function Bags:Pool()
  return self.snap and self.vpool or self.pool
end

function Bags:Slots(bag)
  if self.snap then return ns.Vault:Count("bags", bag) end
  return C_Container.GetContainerNumSlots(bag) or 0
end

function Bags:Taken(bag)
  if self.snap then return ns.Vault:Used("bags", bag) end
  local num = C_Container.GetContainerNumSlots(bag) or 0
  return num - (select(1, C_Container.GetContainerNumFreeSlots(bag)) or 0)
end

function Bags:Restyle()
  self.styleGen = (self.styleGen or 0) + 1
  if self.frame and self.frame:IsShown() then self:Layout() end
end

function Bags:Layout()
  local cols = self.cols
  local gap = self.gap
  local size = self.iconSize
  local step = stepFor(size, gap)
  local i, used, total = 0, 0, 0
  self.byKey = {}
  self.fontPath = ns.Fonts:Path(self.font or "Arial Narrow")
  if self.title then self.title:SetFont(self.fontPath, 15, "") end
  if self.money then self.money:SetFont(self.fontPath, 16, "") end
  if self.reagentLabel then self.reagentLabel:SetFont(self.fontPath, 11, "") end
  if self.search then
    self.search:SetFont(self.fontPath, 13, "")
    if self.search.Hint then self.search.Hint:SetFont(self.fontPath, 13, "") end
  end
  if self.freeText then self.freeText:SetFont(self.fontPath, 12, "") end
  if self.charTag then self.charTag.Text:SetFont(self.fontPath, 12, ""); self:UpdateCharTag() end
  if self.frame and self.frame.wpeBar then self.frame.wpeBar:Fonts(self.fontPath, 11) end

  self.content:ClearAllPoints()
  self.content:SetPoint("TOPLEFT", PAD, -self:TopOffset())

  local function place(bag, slot, x, y)
    i = i + 1
    local b = self:Acquire(i)
    local h = b.holder
    if not self.snap then
      h:SetID(bag)
      b:SetID(slot)
      b:SetAttribute("bagid", bag)
    end
    h:SetSize(size, size)
    b.link = nil
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, y)
    h:Show(); b:Show()
    if self.snap then
      ns.PaintVaultButton(b, ns.Vault:Slot("bags", bag, slot), bag)
    else
      ns.UpdateItemButton(b)
    end
    self.byKey[bag .. ":" .. slot] = b
  end

  local n = 0
  local merge = self.mergeReagents and true or false
  for _, bag in ipairs(ns.playerBags) do
    local num = self:Slots(bag)
    for slot = 1, num do
      local col, row = n % cols, math.floor(n / cols)
      place(bag, slot, col * step, -row * step)
      n = n + 1
    end
    total = total + num
    used = used + self:Taken(bag)
  end
  local rnum = self:Slots(ns.reagentBag)
  if merge and rnum > 0 then
    for slot = 1, rnum do
      local col, row = n % cols, math.floor(n / cols)
      place(ns.reagentBag, slot, col * step, -row * step)
      n = n + 1
    end
    total = total + rnum
    used = used + self:Taken(ns.reagentBag)
  end
  local normalRows = math.max(1, math.ceil(n / cols))
  local normalBottom = (normalRows - 1) * step + size
  local contentH = normalBottom

  if not merge and rnum > 0 then
    local top = normalBottom + DIV
    self.reagentLabel:ClearAllPoints()
    self.reagentLabel:SetPoint("TOPLEFT", self.content, "TOPLEFT", 2, -(normalBottom + 6))
    self.reagentLabel:Show()
    for slot = 1, rnum do
      local col, row = (slot - 1) % cols, math.floor((slot - 1) / cols)
      place(ns.reagentBag, slot, col * step, -(top + row * step))
    end
    local rRows = math.ceil(rnum / cols)
    contentH = top + ((rRows - 1) * step + size)
    total = total + rnum
    used = used + self:Taken(ns.reagentBag)
  else
    self.reagentLabel:Hide()
  end

  local active, idle = self:Pool(), (self.snap and self.pool or self.vpool)
  for j = i + 1, #active do active[j].holder:Hide() end
  for _, b in ipairs(idle) do if b.holder:IsShown() then b.holder:Hide() end end
  if self.sortBtn then self.sortBtn:SetShown(not self.snap) end
  self:VendorState()
  if not self.snap then ns.Vault:Capture("bags") end
  self.shown, self.used, self.total = i, used, total
  self:Resize(contentH)
  if self.bagWindow and self.bagWindow:IsShown() then self:LayoutBagWindow() end
  self:UpdateMeta()
  self:ApplySearch()
end
function Bags:Resize(contentH)
  local gw = gridWidth(self.iconSize, self.cols, self.gap)
  self.content:SetSize(gw, contentH)
  self.frame:SetSize(PAD * 2 + gw, self:TopOffset() + contentH + FOOTER)
  self.gridBg:ClearAllPoints()
  self.gridBg:SetPoint("TOPLEFT", self.content, "TOPLEFT", -3, 3)
  self.gridBg:SetPoint("BOTTOMRIGHT", self.content, "BOTTOMRIGHT", 3, -3)
  ns.Rebase(self.frame, "pos")
end

local function groupNumber(n, sep)
  local out = tostring(math.floor(n))
  local k
  repeat out, k = out:gsub("^(%d+)(%d%d%d)", "%1" .. sep .. "%2") until k == 0
  return out
end

local SHORT_UNITS = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
local function shortNumber(n)
  n = math.floor((n or 0) + 0.5)
  if n < 1000 then return tostring(n) end
  for i, u in ipairs(SHORT_UNITS) do
    local scale, suf = u[1], u[2]
    if n >= scale then
      local r = math.floor(n / scale * 10 + 0.5) / 10
      if r >= 1000 and i > 1 then
        scale, suf = SHORT_UNITS[i - 1][1], SHORT_UNITS[i - 1][2]
        r = math.floor(n / scale * 10 + 0.5) / 10
      end
      if r == math.floor(r) then return string.format("%d%s", r, suf) end
      return string.format("%.1f%s", r, suf)
    end
  end
end

function ns.FormatNumber(n)
  local mode = WarpeeDB and WarpeeDB.goldFormat or "commas"
  if mode == "short" then return shortNumber(n) end
  local sep = (mode == "dots" and ".") or (mode == "spaces" and " ") or ","
  return groupNumber(n, sep)
end

local COIN_ICON = {
  g = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t",
  s = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t",
  c = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t",
}
local COIN_COLOR = { g = "brass", s = "silver", c = "copper" }

local function whiteNum(str)
  return "|cff" .. Theme:Hex("text") .. str .. "|r"
end

local function coinUnit(letter)
  if not Bags.goldLetters then return COIN_ICON[letter] end
  local sp = (letter == "g" and WarpeeDB and WarpeeDB.goldFormat == "short") and " " or ""
  return sp .. "|cff" .. Theme:Hex(COIN_COLOR[letter]) .. letter .. "|r"
end

local function coinSeg(num, letter)
  return whiteNum(num) .. coinUnit(letter)
end

function ns.FormatMoney(money, goldOnly)
  money = money or 0
  local g = math.floor(money / 10000)
  if goldOnly == nil then goldOnly = Bags.goldOnly end
  if goldOnly then return coinSeg(ns.FormatNumber(g), "g") end
  local sv = math.floor((money % 10000) / 100)
  local cp = money % 100
  local parts = {}
  if g  > 0 then parts[#parts + 1] = coinSeg(ns.FormatNumber(g), "g") end
  if sv > 0 then parts[#parts + 1] = coinSeg(sv, "s") end
  if cp > 0 or #parts == 0 then parts[#parts + 1] = coinSeg(cp, "c") end
  return table.concat(parts, " ")
end
function Bags:FormatMoney() return ns.FormatMoney(GetMoney()) end

function ns.FormatGold(copper)
  return coinSeg(ns.FormatNumber(math.floor((copper or 0) / 10000)), "g")
end

function Bags:UpdateBagBar()
  if not self.bagButtons then return end
  local path = self.fontPath or ns.Fonts:Path(self.font or "Arial Narrow")
  if self.bagTitle then self.bagTitle:SetFont(path, 14, "") end
  for _, b in ipairs(self.bagButtons) do
    local bagID = b.bagID
    local tex
    if bagID == 0 then
      tex = "Interface\\Buttons\\Button-Backpack-Up"
    else
      tex = GetInventoryItemTexture("player", C_Container.ContainerIDToInventoryID(bagID))
    end
    b.icon:SetTexture(tex or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
    local free = select(1, C_Container.GetContainerNumFreeSlots(bagID)) or 0
    b.count:SetText(free > 0 and free or "")
    if b.count and b.cntFontSize then b.count:SetFont(path, b.cntFontSize, "OUTLINE") end
  end
end

function Bags:HighlightBag(bagID)
  if self.snap then return end
  self.hlBag = bagID
  for j = 1, (self.shown or 0) do
    local b = self.pool[j]
    if b then
      local on = (b.bagID == bagID)
      b:SetAlpha(on and 1 or 0.15)
      ns.SetSlotHighlight(b, on)
    end
  end
end

function Bags:ClearBagHighlight()
  if self.snap then return end
  self.hlBag = nil
  for j = 1, (self.shown or 0) do
    local b = self.pool[j]
    if b then
      ns.SetSlotHighlight(b, false)
      b:SetAlpha(1)
      self:ApplyToButton(b)
    end
  end
end

function Bags:TryEquipBag(bag, slot)
  if InCombatLockdown() then return false end
  local info = C_Container.GetContainerItemInfo(bag, slot)
  if not info or not info.hyperlink then return false end
  if select(6, C_Item.GetItemInfoInstant(info.hyperlink)) ~= Enum.ItemClass.Container then return false end
  local target, targetUsed
  for _, bg in ipairs({ 1, 2, 3, 4 }) do
    local num = C_Container.GetContainerNumSlots(bg)
    if num == 0 then target = bg; break end
    local free = select(1, C_Container.GetContainerNumFreeSlots(bg)) or 0
    local used = num - free
    if not targetUsed or used < targetUsed then targetUsed = used; target = bg end
  end
  if not target or target == bag then return false end
  local inv = C_Container.ContainerIDToInventoryID(target)
  ClearCursor()
  C_Container.PickupContainerItem(bag, slot)
  PutItemInBag(inv)
  if CursorHasItem() then C_Container.PickupContainerItem(bag, slot) end
  ClearCursor()
  return true
end

function Bags:PlaceBagFromCursor(bagID)
  if InCombatLockdown() then ClearCursor(); return end
  if bagID == 0 then ClearCursor(); return end
  local inv = C_Container.ContainerIDToInventoryID(bagID)
  if not inv then ClearCursor(); return end
  PutItemInBag(inv)
end

function Bags:UpdateCharTag()
  if not self.charTag then return end
  local key = ns.Vault:ViewKey("bags")
  local name, class
  if key == ns.Vault:Owner() then
    name = UnitName("player")
    local _, cls = UnitClass("player")
    class = cls
  else
    for _, e in ipairs(ns.Vault:Chars(true)) do
      if e.key == key then name, class = e.name, e.class; break end
    end
  end
  ns.PaintCharTag(self.charTag, name or (key and key:match("^(.-)%-")) or "?", class)
end

function Bags:ToggleCharPicker(anchor)
  if not ns.CharPicker then return end
  ns.CharPicker:Toggle(anchor or self.charTag, "left",
    function(key) self:SelectChar(key) end, ns.Vault:ViewKey("bags"))
end

function Bags:SelectChar(key)
  if not ns.Vault:SetView("bags", key) then return end
  self.snap = (ns.Vault:ViewKey("bags") ~= ns.Vault:Owner()) or nil
  self:UpdateCharTag()
  if self.frame and self.frame:IsShown() then self:Layout() end
end

function Bags:VendorState()
  local b = self.sellBtn
  if not b then return end
  local on = (ns.Vendor and ns.Vendor:IsOpen() and not self.snap)
  b:SetShown(on and true or false)
  self:FitHeader()
end

function Bags:FitHeader()
  if not (self.frame and self.search) then return end
  local w = self.frame:GetWidth()
  self.search:Show()
  local btns = HBTNS
  if self.sellBtn and self.sellBtn:IsShown() then btns = btns + 1 end
  local right = PAD + btns * HB + (btns - 1) * HGAP
  if self.charTag and self.freeText then
    local left = PAD + self.charTag:GetWidth() + 8 + math.ceil(self.freeText:GetStringWidth())
    self.freeText:SetShown(left + 8 <= w - right)
  end
  if self.title and self.money then
    self.title:SetText("WARPEE")
    local room = w - PAD * 2 - math.ceil(self.money:GetStringWidth()) - 12
    local show = room >= math.ceil(self.title:GetStringWidth())
    if not show then self.title:SetText("") end
    self.title:SetShown(show)
  end
end

function Bags:UpdateMeta()
  local used, total = self.used or 0, self.total or 0
  self.freeText:SetText(("%d/%d"):format(used, total))
  self.money:SetText(self:FormatMoney())
  self:UpdateBagBar()

  local frac = total > 0 and used / total or 0
  if self.showGauge then
    self.gaugeBg:Show(); self.gaugeFill:Show()
    self.gaugeFill:SetWidth(math.max(1, frac * gridWidth(self.iconSize, self.cols, self.gap)))
    self.gaugeFill:SetVertexColor(Theme:C("azure"))
  else
    self.gaugeBg:Hide(); self.gaugeFill:Hide()
  end
  self:FitHeader()
end

local QUALITY_WORDS = {
  poor = 0, junk = 0, grey = 0, gray = 0, common = 1, white = 1,
  uncommon = 2, green = 2, rare = 3, blue = 3, epic = 4, purple = 4,
  legendary = 5, orange = 5, artifact = 6, heirloom = 7,
}
local SLOT_WORDS = {
  head = {INVTYPE_HEAD=1}, helm = {INVTYPE_HEAD=1},
  neck = {INVTYPE_NECK=1},
  shoulder = {INVTYPE_SHOULDER=1}, shoulders = {INVTYPE_SHOULDER=1},
  back = {INVTYPE_CLOAK=1}, cloak = {INVTYPE_CLOAK=1},
  chest = {INVTYPE_CHEST=1, INVTYPE_ROBE=1},
  wrist = {INVTYPE_WRIST=1}, bracers = {INVTYPE_WRIST=1},
  hands = {INVTYPE_HAND=1}, gloves = {INVTYPE_HAND=1},
  waist = {INVTYPE_WAIST=1}, belt = {INVTYPE_WAIST=1},
  legs = {INVTYPE_LEGS=1}, pants = {INVTYPE_LEGS=1},
  feet = {INVTYPE_FEET=1}, boots = {INVTYPE_FEET=1},
  finger = {INVTYPE_FINGER=1}, ring = {INVTYPE_FINGER=1}, rings = {INVTYPE_FINGER=1},
  trinket = {INVTYPE_TRINKET=1}, trinkets = {INVTYPE_TRINKET=1},
  shield = {INVTYPE_SHIELD=1}, tabard = {INVTYPE_TABARD=1}, shirt = {INVTYPE_BODY=1},
  weapon = {INVTYPE_WEAPON=1, INVTYPE_2HWEAPON=1, INVTYPE_WEAPONMAINHAND=1,
            INVTYPE_WEAPONOFFHAND=1, INVTYPE_RANGED=1, INVTYPE_RANGEDRIGHT=1},
  mainhand = {INVTYPE_WEAPONMAINHAND=1, INVTYPE_WEAPON=1, INVTYPE_2HWEAPON=1},
  offhand = {INVTYPE_WEAPONOFFHAND=1, INVTYPE_HOLDABLE=1, INVTYPE_SHIELD=1},
}
function ns.ParseSearch(q)
  q = (q or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local f = { text = {} }
  f.empty = q == ""
  for token in q:gmatch("%S+") do
    local num = token:match("^ilvl(%d+)$") or token:match("^(%d+)$")
    if num then
      f.ilvl = tonumber(num)
    elseif QUALITY_WORDS[token] then
      f.quality = QUALITY_WORDS[token]
    elseif SLOT_WORDS[token] then
      f.slots = f.slots or {}
      for k in pairs(SLOT_WORDS[token]) do f.slots[k] = true end
    elseif token == "warbound" or token == "wb" or token == "warband" then
      f.warbound = true
    elseif token == "soulbound" or token == "sb" or token == "bound" or token == "bop" then
      f.soulbound = true
    elseif token == "reagent" or token == "reagents" or token == "mats" then
      f.reagent = true
    elseif token == "keystone" or token == "key" or token == "mythic" then
      f.keystone = true
    elseif token == "quest" then
      f.quest = true
    elseif token == "consumable" or token == "consumables" then
      f.consumable = true
    elseif token == "gear" or token == "equip" or token == "equipment" then
      f.gear = true
    else
      f.text[#f.text + 1] = token
    end
  end
  return f
end
function ns.MetaWarbound(m)
  if m.wb == nil then
    if not m.isGear then
      m.wb = false
    elseif m.bag then
      m.wb = ns.IsWarbound(m.bag, m.slot, m.loc) and true or false
    else
      m.wb = ns.IsLinkWarbound(m.link) and true or false
    end
  end
  return m.wb
end

function ns.MatchSearch(m, f)
  if not f or f.empty then return true end
  if not m then return false end
  for _, t in ipairs(f.text) do
    if not (m.text and m.text:find(t, 1, true)) then return false end
  end
  if f.quality ~= nil and m.q ~= f.quality then return false end
  if f.ilvl and m.ilvl ~= f.ilvl then return false end
  if f.slots and not (m.equipLoc and f.slots[m.equipLoc]) then return false end
  if f.warbound and not ns.MetaWarbound(m) then return false end
  if f.soulbound and not (m.bound and not ns.MetaWarbound(m)) then return false end
  if f.reagent and not m.reagent then return false end
  if f.keystone and not m.keystone then return false end
  if f.quest and m.classID ~= Enum.ItemClass.Questitem then return false end
  if f.consumable and m.classID ~= Enum.ItemClass.Consumable then return false end
  if f.gear and not (m.classID == Enum.ItemClass.Armor
     or m.classID == Enum.ItemClass.Weapon) then return false end
  return true
end

function Bags:ApplySearch()
  local p = self:Pool()
  for j = 1, (self.shown or 0) do self:ApplyToButton(p[j]) end
end

function Bags:RefreshNewItems()
  if self.snap or not (self.frame and self.frame:IsShown() and self.pool) then return end
  for i = 1, (self.shown or 0) do
    local btn = self.pool[i]
    if btn then ns.SyncNewItem(btn) end
  end
end

function Bags:RefreshQuests()
  if self.snap or not (self.frame and self.frame:IsShown() and self.pool) then return end
  for i = 1, (self.shown or 0) do
    local btn = self.pool[i]
    if btn and ns.SyncQuestMark(btn) then
      btn.link = nil
      ns.UpdateItemButton(btn)
      self:ApplyToButton(btn)
    end
  end
end

function Bags:RefreshCooldowns()
  if self.snap or not (self.frame and self.frame:IsShown() and self.pool) then return end
  for i = 1, (self.shown or 0) do
    local b = self.pool[i]
    if b and b.link then ns.UpdateCooldown(b) end
  end
end

function Bags:ApplyToButton(b)
  ns.ApplySearchToButton(b, self.filters, ns.DepositBlocked and ns.DepositBlocked(b))
end

function Bags:UpdateDirty()
  if not (self.frame and self.frame:IsShown()) then self.dirty = {}; return end
  if next(self.dirty) then ns.Vault:Capture("bags", self.dirty) end
  if self.snap then self.dirty = {}; return end
  local total, used = 0, 0
  for _, bag in ipairs(ns.playerBags) do
    local num = C_Container.GetContainerNumSlots(bag)
    total = total + num
    used = used + (num - (select(1, C_Container.GetContainerNumFreeSlots(bag)) or 0))
  end
  local rnum = C_Container.GetContainerNumSlots(ns.reagentBag)
  if rnum and rnum > 0 then
    total = total + rnum
    used = used + (rnum - (select(1, C_Container.GetContainerNumFreeSlots(ns.reagentBag)) or 0))
  end
  if total ~= self.total then self.dirty = {}; self:Layout(); return end
  self.used = used
  for bag in pairs(self.dirty) do
    local num = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, num do
      local b = self.byKey[bag .. ":" .. slot]
      if b then ns.UpdateItemButton(b); self:ApplyToButton(b) end
    end
  end
  self.dirty = {}
  self:UpdateMeta()
end

function Bags:SortBags()
  self.sorting = true
  self:SortSettle()
  C_Container.SortBags()
end

function Bags:SortSettle()
  self.sortGen = (self.sortGen or 0) + 1
  local gen = self.sortGen
  C_Timer.After(0.2, function()
    if self.sortGen ~= gen then return end
    self.sorting = false
    for _, bag in ipairs(ns.playerBags) do self.dirty[bag] = true end
    self.dirty[ns.reagentBag] = true
    if self.frame and self.frame:IsShown() then self:UpdateDirty() end
  end)
end

function Bags:RestorePos()
  ns.PlaceWindow(self.frame, "pos")
end

function Bags:Refresh()
  self:Build()
  if self.frame:IsShown() then self:Layout() end
end
