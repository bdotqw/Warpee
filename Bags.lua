local addonName, ns = ...
local Theme = ns.Theme

ns.playerBags = { 0, 1, 2, 3, 4 }
ns.reagentBag = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5

local OWN_BAGS = { [ns.reagentBag] = true }
for _, b in ipairs(ns.playerBags) do OWN_BAGS[b] = true end

function ns.IsPlayerBag(id)
  return OWN_BAGS[id] == true
end
ns.reagentBank = (Enum and Enum.BagIndex and Enum.BagIndex.Reagentbank) or -3

local SIZE_DEFAULT, PAD = 37, 10
local COLS_DEFAULT, GAP_DEFAULT = 14, 4
local HEADER, FOOTER = 66, 28
local DIV = 22
local HB = 26
local ROW1_Y = 4
local GAUGE_Y = ROW1_Y + HB + 6
local ROW2_Y = GAUGE_Y + 6

local Bags = { pool = {}, vpool = {}, cols = COLS_DEFAULT, gap = GAP_DEFAULT, iconSize = SIZE_DEFAULT,
               slotStyle = "tile", showGauge = true, goldLetters = false, goldOnly = false,
               font = ns.Fonts.DEFAULT, query = "", dirty = {},
               badge = ns.BadgeDefaults(),
               qualityColorIlvl = false, qualityBorder = false, iconZoom = 1, borderWidth = 2, mergeReagents = false, questMarks = false, newItemGlow = false, reagentTint = true,
               revFill = false, fillUp = false, reagentTop = false, hideReagents = false,
               styleGen = 1 }
ns.Bags = Bags

local function stepFor(size, gap) return size + gap end
local function gridWidth(size, cols, gap) return (cols - 1) * (size + gap) + size end
function Bags:HeadShift()
  return self.showGauge and 0 or (ROW2_Y - GAUGE_Y + 2)
end

function Bags:BaseTop() return HEADER + 4 + Theme:TopInset() - self:HeadShift() end

function Bags:TopOffset() return self:BaseTop() + (self.recentH or 0) + (self.favH or 0) end

function Bags:AnchorHeader()
  local top = Theme:TopInset()
  local row1 = ROW1_Y + top + Theme:HeadDrop()
  if self.closeBtn then
    self.closeBtn:ClearAllPoints()
    ns.SnapPoint(self.closeBtn, "TOPRIGHT", self.frame, "TOPRIGHT", -PAD, -row1)
  end
  if self.charTag then
    self.charTag:ClearAllPoints()
    ns.SnapPoint(self.charTag, "TOPLEFT", self.frame, "TOPLEFT", PAD, -row1)
  end
  if self.gaugeBg then
    self.gaugeBg:ClearAllPoints()
    self.gaugeBg:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PAD, -(GAUGE_Y + top))
    self.gaugeBg:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -PAD, -(GAUGE_Y + top))
  end
  if self.search then
    local row2 = ROW2_Y + top - self:HeadShift()
    self.search:ClearAllPoints()
    self.search:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PAD, -row2)
    self.search:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -PAD, -row2)
  end
  Theme:HeaderBand(self.frame)
end

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
  Theme:HeaderBand(f)
  f:SetScript("OnHide", function()
    ns.ClearSearch(Bags.search)
    if ns.CharPicker then ns.CharPicker:Close() end
    if Bags.bagWindow then Bags.bagWindow:Hide() end
    if ns.Pocket then ns.Pocket:Close(true) end
    if ns.Vault:SetView("bags", nil) then
      Bags.snap = nil
      Bags:UpdateCharTag()
    end
  end)
  self.frame = f
  ns.CreateMoveBar(f, "pos")

  local title = Theme:Title(f, 15, "accent")
  title:SetPoint("BOTTOMLEFT", PAD, 6)
  title:SetText("WARPEE")
  self.title = title

  local function addTip(btn, txt)
    ns.AddTip(btn, txt, "top")
  end

  local close = ns.CreateGlyphButton(f, "×", HB)
  close:SetPoint("TOPRIGHT", -PAD, -ROW1_Y)
  close:SetScript("OnClick", function() ns.Toggle(false) end)
  self.closeBtn = close

  local sort = ns.CreateGlyphButton(f, "", HB)
  sort:SetScript("OnClick", function() Bags:SortBags() end)
  addTip(sort, "Clean up bags")
  local sortIcon = sort:CreateTexture(nil, "ARTWORK")
  sortIcon:SetAtlas("auctionhouse-ui-sortarrow")
  sortIcon:SetSize(13, 15)
  sortIcon:SetPoint("CENTER")
  sortIcon:SetVertexColor(Theme:C("text"))
  Theme:Track(sortIcon, function(x) x:SetVertexColor(Theme:C("text")) end)
  sort.icon = sortIcon
  self.sortBtn = sort

  local gear = ns.CreateGlyphButton(f, "|TInterface\\Buttons\\UI-OptionsButton:13:13:0:0|t", HB)
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
  Theme:Track(bagIcon, function(x) x:SetVertexColor(Theme:C("text")) end)
  bagsToggle.icon = bagIcon
  self.bagsToggle = bagsToggle

  local bank = ns.CreateGlyphButton(f, "", HB)
  bank:SetPoint("TOPRIGHT", bagsToggle, "TOPLEFT", -4, 0)
  bank:SetScript("OnClick", function() if ns.ToggleBank then ns.ToggleBank() end end)
  ns.AddTip(bank, "Bank / Warband", "top", function(s)
    if s:IsEnabled() then return nil end
    return { { text = "Visit a banker to record this bank", color = "dim" } }
  end)
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
  Theme:Track(bankIcon, function(x) x:SetVertexColor(Theme:C("text")) end)
  bank.icon = bankIcon
  self.bankBtn = bank

  sort:SetPoint("TOPRIGHT", bank, "TOPLEFT", -4, 0)

  local sell = ns.CreateGlyphButton(f, "", HB)
  sell:SetPoint("TOPRIGHT", sort, "TOPLEFT", -4, 0)
  sell:SetScript("OnClick", function() if ns.Vendor then ns.Vendor:Sell() end end)
  ns.AddTip(sell, "Sell now", "top", function()
    return ns.Vendor and ns.Vendor:TipLines() or nil
  end)
  local sellIcon = sell:CreateTexture(nil, "ARTWORK")
  sellIcon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
  sellIcon:SetSize(16, 16)
  sellIcon:SetPoint("CENTER")
  sellIcon:SetDesaturated(true)
  sellIcon:SetAlpha(0.45)
  sell.icon = sellIcon
  ns.SetButtonEnabled(sell, false)
  self.sellBtn = sell

  local pocket = ns.CreateGlyphButton(f, "", HB)
  pocket:SetPoint("TOPRIGHT", sell, "TOPLEFT", -4, 0)
  pocket:SetScript("OnClick", function() if ns.Pocket then ns.Pocket:Toggle() end end)
  addTip(pocket, "Pocket")
  local dots = {}
  for k = 1, 6 do dots[k] = Theme:Rect(pocket, "text", "ARTWORK") end
  ns.PixelJob(pocket, function(s)
    local d, sp = ns.PX(s, 4), ns.PX(s, 2)
    local gw, gh = 3 * d + 2 * sp, 2 * d + sp
    for k = 1, 6 do
      local col, row = (k - 1) % 3, math.floor((k - 1) / 3)
      dots[k]:SetSize(d, d)
      dots[k]:ClearAllPoints()
      dots[k]:SetPoint("TOPLEFT", s, "CENTER",
                       -gw / 2 + col * (d + sp), gh / 2 - row * (d + sp))
    end
  end, "pocket")
  self.pocketBtn = pocket

  local charTag = ns.CreateCharTag(f, HB, "left")
  charTag:SetPoint("TOPLEFT", PAD, -ROW1_Y)
  charTag:SetScript("OnClick", function(s) Bags:ToggleCharPicker(s) end)
  ns.AddTip(charTag, "Bags of another character", "top", function(s)
    if s:IsEnabled() then return nil end
    return { { text = "Nothing saved for other characters yet", color = "dim" } }
  end)
  self.charTag = charTag

  local slots = Theme:Label(f, 12, "dim")
  slots:SetPoint("LEFT", charTag, "RIGHT", 10, 0)
  slots:SetJustifyH("LEFT")
  self.slotText = slots

  local search = ns.CreateSearchBox(f, function(text)
    self.query = (text or ""):lower()
    self.filters = ns.ParseSearch(self.query)
    self:ApplySearch()
    ns.MirrorSearch("bags", text)
  end)
  search:SetPoint("TOPLEFT", PAD, -ROW2_Y)
  search:SetPoint("TOPRIGHT", -PAD, -ROW2_Y)
  search:SetHeight(22)
  self.search = search

  local gaugeBg = Theme:Rect(f, "panel", "BACKGROUND")
  gaugeBg:SetHeight(2)
  gaugeBg:SetPoint("TOPLEFT", PAD, -GAUGE_Y)
  gaugeBg:SetPoint("TOPRIGHT", -PAD, -GAUGE_Y)
  local gaugeFill = Theme:Rect(f, "accent", "ARTWORK")
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
  ns.LocalText(rlabel, "REAGENTS")
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
  Theme:WindowArt(w)
  w:SetFrameStrata("DIALOG")
  w:SetClampedToScreen(true)
  w:SetMovable(true); w:EnableMouse(true)
  w:RegisterForDrag("LeftButton")
  w:SetScript("OnDragStart", function(s) ns.DragStart(s) end)
  w:SetScript("OnDragStop", function(s)
    if not s.wpeMoving then return end
    s.wpeMoving = nil
    s:StopMovingOrSizing()
    local pp, rp, x, y = ns.SnapFrame(s)
    if pp then WarpeeDB.bagWinPos = { p = pp, rp = rp, x = x, y = y } end
  end)
  ns.EscClose(w)

  local title = Theme:Title(w, 14, "accent")
  title:SetPoint("TOPLEFT", BPAD, -8)
  ns.LocalText(title, "BAGS")
  self.bagTitle = title

  local wclose = ns.CreateGlyphButton(w, "×")
  wclose:SetPoint("TOPRIGHT", -6, -6)
  wclose:SetScript("OnClick", function() w:Hide() end)
  self.bagWinClose = wclose

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
  local BGAP, BPAD = 6, 12
  local BBAND = 26
  local size = self:BagWinButtonSize()
  local cf = ns.Badge("count").s
  local band = Theme:HeaderBand(w, BBAND)
  local BHEAD = band and (band + 6) or (30 + Theme:TopInset())
  local mid = (band or BHEAD) / 2
  if self.bagTitle then
    self.bagTitle:ClearAllPoints()
    self.bagTitle:SetPoint("LEFT", w, "TOPLEFT", BPAD, -mid)
  end
  if self.bagWinClose then
    self.bagWinClose:ClearAllPoints()
    ns.SnapPoint(self.bagWinClose, "RIGHT", w, "TOPRIGHT", -6, -mid)
  end
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
    ns.SnapPoint(w, pp.p, UIParent, pp.rp, pp.x, pp.y)
  elseif self.frame then
    ns.SnapPoint(w, "BOTTOMLEFT", self.frame, "TOPLEFT", 0, 6)
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
    if InCombatLockdown() then self.cold = true; return nil end
    b = ns.CreateItemButton(self.content, 0, 1)
    self.pool[i] = b
  end
  return b
end

function Bags:Warm()
  if InCombatLockdown() or not self.content then return end
  local n = 0
  for _, bag in ipairs(ns.playerBags) do
    n = n + (C_Container.GetContainerNumSlots(bag) or 0)
  end
  n = n + (C_Container.GetContainerNumSlots(ns.reagentBag) or 0)
  if n == 0 then return end
  for i = 1, n do
    if not self.pool[i] then
      self.pool[i] = ns.CreateItemButton(self.content, 0, 1)
    end
  end
  self.warmed, self.cold = true, nil
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
  self:AnchorHeader()
  local size, gap, step = ns.GridMetrics(self.frame, self.iconSize, self.gap)
  self.pxSize, self.pxGap = size, gap
  local i, used, total = 0, 0, 0
  self.byKey = {}
  self.fontPath = ns.Fonts:Current()
  if self.title then self.title:SetFont(self.fontPath, 15, "") end
  if self.money then self.money:SetFont(self.fontPath, 16, "") end
  if self.reagentLabel then self.reagentLabel:SetFont(self.fontPath, 11, "") end
  if self.slotText then self.slotText:SetFont(self.fontPath, 12, "") end
  if self.search then
    self.search:SetFont(self.fontPath, 13, "")
    if self.search.Hint then self.search.Hint:SetFont(self.fontPath, 13, "") end
  end
  if self.charTag then self.charTag.Text:SetFont(self.fontPath, 12, ""); self:UpdateCharTag() end
  if self.frame and self.frame.wpeBar then self.frame.wpeBar:Fonts(self.fontPath, 11) end

  self.recentH = ns.Recent and ns.Recent:Apply(self, PAD, self:BaseTop(), size, gap) or 0
  self.favH = ns.Fav and ns.Fav:Apply(self, PAD, self:BaseTop() + self.recentH, size, gap) or 0

  self.content:ClearAllPoints()
  ns.SnapPoint(self.content, "TOPLEFT", self.frame, "TOPLEFT", PAD, -self:TopOffset())

  local function place(bag, slot, x, y)
    i = i + 1
    local b = self:Acquire(i)
    if not b then return end
    local h = b.holder
    if not self.snap then
      h:SetID(bag)
      b:SetID(slot)
      b.wpeBagID = bag
    end
    ns.SnapSize(h, size, size)
    b.link = nil
    h:ClearAllPoints()
    ns.SnapPoint(h, "TOPLEFT", self.content, "TOPLEFT", x, y)
    h:Show(); b:Show()
    if self.snap then
      ns.PaintVaultButton(b, ns.Vault:Slot("bags", bag, slot), bag)
    else
      ns.UpdateItemButton(b)
    end
    self.byKey[bag .. ":" .. slot] = b
  end

  local n = 0
  local hide = self.hideReagents and true or false
  local merge = (not hide) and self.mergeReagents and true or false
  local rnum = self:Slots(ns.reagentBag)
  local split = (not hide) and (not merge) and rnum > 0
  local mainCount = merge and rnum or 0
  for _, bag in ipairs(ns.playerBags) do mainCount = mainCount + self:Slots(bag) end
  local mainRows = math.max(1, math.ceil(mainCount / cols))
  local rRows = split and math.max(1, math.ceil(rnum / cols)) or 0
  local rBlock = split and ((rRows - 1) * step + size) or 0
  local onTop = split and self.reagentTop and true or false
  local mainTop = onTop and (rBlock + DIV * 2) or 0
  local mainBottom = mainTop + (mainRows - 1) * step + size
  local rTop = onTop and DIV or (mainBottom + DIV)

  local function cellXY(k, count, rows, top)
    local j = self.revFill and (count - k + 1) or k
    local col, row = (j - 1) % cols, math.floor((j - 1) / cols)
    if self.fillUp then row = rows - 1 - row end
    return col * step, -(top + row * step)
  end

  for _, bag in ipairs(ns.playerBags) do
    local num = self:Slots(bag)
    for slot = 1, num do
      n = n + 1
      place(bag, slot, cellXY(n, mainCount, mainRows, mainTop))
    end
    total = total + num
    used = used + self:Taken(bag)
  end
  if rnum > 0 then
    total = total + rnum
    used = used + self:Taken(ns.reagentBag)
    if merge then
      for slot = 1, rnum do
        n = n + 1
        place(ns.reagentBag, slot, cellXY(n, mainCount, mainRows, mainTop))
      end
    end
  end

  local contentH = mainBottom
  if split then
    self.reagentLabel:ClearAllPoints()
    self.reagentLabel:SetPoint("TOPLEFT", self.content, "TOPLEFT", 2, -(rTop - DIV + 6))
    self.reagentLabel:Show()
    for slot = 1, rnum do
      place(ns.reagentBag, slot, cellXY(slot, rnum, rRows, rTop))
    end
    if not onTop then contentH = rTop + rBlock end
  else
    self.reagentLabel:Hide()
  end

  local active, idle = self:Pool(), (self.snap and self.pool or self.vpool)
  for j = i + 1, #active do active[j].holder:Hide() end
  for _, b in ipairs(idle) do if b.holder:IsShown() then b.holder:Hide() end end
  if self.sortBtn then self.sortBtn:SetShown(not self.snap) end
  if self.pocketBtn then
    self.pocketBtn:SetShown((ns.Pocket and ns.Pocket:Enabled()) and true or false)
  end
  self:VendorState()
  if not self.snap then ns.Vault:Capture("bags") end
  self:BrowseState()
  self.shown, self.used, self.total = i, used, total
  self:Resize(contentH)
  if self.bagWindow and self.bagWindow:IsShown() then self:LayoutBagWindow() end
  self:UpdateMeta()
  self:ApplySearch()
  if ns.Pocket then ns.Pocket:Refresh() end
end
function Bags:Resize(contentH)
  local gw = gridWidth(self.pxSize or self.iconSize, self.cols, self.pxGap or self.gap)
  self.content:SetSize(gw, contentH)
  self.frame:SetSize(PAD * 2 + gw, self:TopOffset() + contentH + FOOTER)
  self.gridBg:ClearAllPoints()
  self.gridBg:SetPoint("TOPLEFT", self.content, "TOPLEFT", -3, 3)
  self.gridBg:SetPoint("BOTTOMRIGHT", self.content, "BOTTOMRIGHT", 3, -3)
  self.gridBg:SetAlpha(Theme:GridAlpha())
  ns.Rebase(self.frame, "pos")
end

local function groupNumber(n, sep)
  local out = tostring(math.floor(n))
  local k
  repeat out, k = out:gsub("^(%d+)(%d%d%d)", "%1" .. sep .. "%2") until k == 0
  return out
end

local function shortNumber(n)
  n = math.floor((n or 0) + 0.5)
  if n < 1000 then return tostring(n) end
  local form = ns.ShortForm()
  local units = form.units
  for i, u in ipairs(units) do
    local scale, suf = u[1], u[2]
    if n >= scale then
      local r = math.floor(n / scale * 10 + 0.5) / 10
      if r >= 1000 and i > 1 then
        scale, suf = units[i - 1][1], units[i - 1][2]
        r = math.floor(n / scale * 10 + 0.5) / 10
      end
      if r == math.floor(r) then return string.format("%d%s", r, suf) end
      return (string.format("%.1f", r):gsub("%.", form.dec)) .. suf
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
local COIN_HEX = { g = "ffd700", s = "c7c7cf", c = "eda55f" }

local function whiteNum(str)
  return "|cff" .. Theme:Hex("text") .. str .. "|r"
end

local function coinUnit(letter)
  if not Bags.goldLetters then return COIN_ICON[letter] end
  local sp = (letter == "g" and WarpeeDB and WarpeeDB.goldFormat == "short") and " " or ""
  return sp .. "|cff" .. COIN_HEX[letter] .. ns.CoinLetter(letter) .. "|r"
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
  local path = ns.Fonts:Current()
  if self.bagTitle then self.bagTitle:SetFont(path, 14, "") end
  for _, b in ipairs(self.bagButtons) do
    local bagID = b.wpeBagID
    local tex
    if bagID == 0 then
      tex = "Interface\\Buttons\\Button-Backpack-Up"
    else
      tex = GetInventoryItemTexture("player", C_Container.ContainerIDToInventoryID(bagID))
    end
    b.icon:SetTexture(tex or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
    local free = select(1, C_Container.GetContainerNumFreeSlots(bagID)) or 0
    b.count:SetText(free > 0 and free or "")
    if b.count and b.cntFontSize then ns.SetOutlined(b.count, b.cntFontSize) end
  end
end

function Bags:Refont()
  self.fontPath = ns.Fonts:Refresh()
  if not self.pool then return end
  for _, b in ipairs(self.pool) do
    b.link = nil
  end
end

function Bags:HighlightBag(bagID)
  if self.snap then return end
  self.hlBag = bagID
  for j = 1, (self.shown or 0) do
    local b = self.pool[j]
    if b then
      local on = (b.wpeBagID == bagID)
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
      b.searchMiss = nil
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
    function(key) self:SelectChar(key) end, ns.Vault:ViewKey("bags"), "bags")
end

function Bags:SelectChar(key)
  if not ns.Vault:SetView("bags", key) then return end
  self.snap = (ns.Vault:ViewKey("bags") ~= ns.Vault:Owner()) or nil
  self:UpdateCharTag()
  if self.frame and self.frame:IsShown() then self:Layout() end
end

function Bags:VendorState()
  if self.pool then
    for _, x in ipairs(self.pool) do ns.LockClicks(x) end
  end
  local F = ns.Fav
  if F then
    for i = 1, (F.max or 0) do ns.LockClicks(F.slots[i]) end
  end
  local P = ns.Pocket
  if P then
    for i = 1, (P.max or 0) do ns.LockClicks(P.slots[i]) end
  end
  local b = self.sellBtn
  if not b then return end
  b:SetShown(not self.snap)
  local on = (ns.Vendor and ns.Vendor:IsOpen()) and true or false
  ns.SetButtonEnabled(b, on)
  if b.icon then
    b.icon:SetDesaturated(not on)
    b.icon:SetAlpha(on and 1 or 0.45)
  end
  self:FitHeader()
end

function Bags:BrowseState()
  local V = ns.Vault
  local b = self.bankBtn
  if b then
    local on = ((ns.Bank and ns.Bank.bankerOpen) or V:Saved("bank") or V:Saved("warband"))
               and true or false
    ns.SetButtonEnabled(b, on)
    if b.icon then
      b.icon:SetDesaturated(not on)
      b.icon:SetAlpha(on and 1 or 0.45)
    end
  end
  local t = self.charTag
  if t then
    local on = V:Others("bags") > 0 or (self.snap and true or false)
    t:SetEnabled(on)
    t:SetAlpha(on and 1 or 0.6)
    if t.caret then t.caret:SetTint(on and "dim" or "faint") end
  end
end

function Bags:FitHeader()
  if not (self.frame and self.search) then return end
  local w = self.frame:GetWidth()
  self.search:Show()
  if self.slotText and self.charTag then
    local edge
    for _, b in ipairs({ self.pocketBtn, self.sellBtn, self.sortBtn, self.bankBtn, self.bagsToggle }) do
      if b and b:IsShown() and b:GetLeft() then edge = b:GetLeft(); break end
    end
    local from = self.charTag:GetRight()
    local show = true
    if edge and from then
      show = (edge - from - 16) >= math.ceil(self.slotText:GetStringWidth())
    end
    self.slotText:SetShown(show)
  end
  if self.title and self.money then
    self.title:SetText("WARPEE")
    local tw = math.ceil(self.title:GetStringWidth())
    local room = w - PAD * 2 - math.ceil(self.money:GetStringWidth()) - 12
    local show = tw <= 0 or room >= tw
    if not show then self.title:SetText("") end
    self.title:SetShown(show)
  end
end

function Bags:UpdateMeta()
  local used, total = self.used or 0, self.total or 0
  self.money:SetText(self:FormatMoney())
  self:UpdateBagBar()
  if self.slotText then
    self.slotText:SetText((ns.L["Slots %d/%d"]):format(used, total))
  end

  local frac = total > 0 and used / total or 0
  if self.showGauge then
    self.gaugeBg:Show(); self.gaugeFill:Show()
    self.gaugeFill:SetWidth(math.max(1, frac * gridWidth(self.pxSize or self.iconSize,
      self.cols, self.pxGap or self.gap)))
    self.gaugeFill:SetVertexColor(Theme:C("accent"))
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
  body = {INVTYPE_BODY=1},
  relic = {INVTYPE_RELIC=1},
  held = {INVTYPE_HOLDABLE=1},
  ranged = {INVTYPE_RANGED=1, INVTYPE_RANGEDRIGHT=1, INVTYPE_THROWN=1},
  thrown = {INVTYPE_THROWN=1},
  ammo = {INVTYPE_AMMO=1},
  quiver = {INVTYPE_QUIVER=1},
  tool = {INVTYPE_PROFESSION_TOOL=1},
  profgear = {INVTYPE_PROFESSION_GEAR=1},
  bagslot = {INVTYPE_BAG=1},
  weapon = {INVTYPE_WEAPON=1, INVTYPE_2HWEAPON=1, INVTYPE_WEAPONMAINHAND=1,
            INVTYPE_WEAPONOFFHAND=1, INVTYPE_RANGED=1, INVTYPE_RANGEDRIGHT=1},
  mainhand = {INVTYPE_WEAPONMAINHAND=1, INVTYPE_WEAPON=1, INVTYPE_2HWEAPON=1},
  offhand = {INVTYPE_WEAPONOFFHAND=1, INVTYPE_HOLDABLE=1, INVTYPE_SHIELD=1},
  ["2h"] = {INVTYPE_2HWEAPON=1, INVTYPE_RANGED=1, INVTYPE_RANGEDRIGHT=1},
  ["1h"] = {INVTYPE_WEAPON=1, INVTYPE_WEAPONMAINHAND=1, INVTYPE_WEAPONOFFHAND=1},
}
local IC  = Enum.ItemClass or {}
local IAS = Enum.ItemArmorSubclass or {}
local IWS = Enum.ItemWeaponSubclass or {}
local IMS = Enum.ItemMiscellaneousSubclass or {}
local function kind(cls, ...)
  if cls == nil then return nil end
  local subs
  for i = 1, select("#", ...) do
    local s = select(i, ...)
    if s ~= nil then subs = subs or {}; subs[s] = true end
  end
  return { class = cls, subs = subs }
end
local KIND_WORDS = {
  cloth    = kind(IC.Armor, IAS.Cloth),
  leather  = kind(IC.Armor, IAS.Leather),
  mail     = kind(IC.Armor, IAS.Mail),
  plate    = kind(IC.Armor, IAS.Plate),
  cosmetic = kind(IC.Armor, IAS.Cosmetic),
  dagger   = kind(IC.Weapon, IWS.Dagger),
  sword    = kind(IC.Weapon, IWS.Sword1H, IWS.Sword2H),
  axe      = kind(IC.Weapon, IWS.Axe1H, IWS.Axe2H),
  mace     = kind(IC.Weapon, IWS.Mace1H, IWS.Mace2H),
  polearm  = kind(IC.Weapon, IWS.Polearm),
  staff    = kind(IC.Weapon, IWS.Staff),
  bow      = kind(IC.Weapon, IWS.Bows),
  gun      = kind(IC.Weapon, IWS.Guns),
  crossbow = kind(IC.Weapon, IWS.Crossbow),
  wand     = kind(IC.Weapon, IWS.Wand),
  fist     = kind(IC.Weapon, IWS.Unarmed),
  warglaive = kind(IC.Weapon, IWS.Warglaive),
  fishing  = kind(IC.Weapon, IWS.Fishingpole),
  mount    = kind(IC.Miscellaneous, IMS.Mount),
  gem      = kind(IC.Gem),
  recipe   = kind(IC.Recipe),
  glyph    = kind(IC.Glyph),
  bag      = kind(IC.Container),
  container = kind(IC.Container),
  pet      = kind(IC.Battlepet),
  battlepet = kind(IC.Battlepet),
  projectile = kind(IC.Projectile),
  tradegoods = kind(IC.Tradegoods),
  misc     = kind(IC.Miscellaneous),
  enhancement = kind(IC.ItemEnhancement),
}
local EXP_WORDS = {
  classic = 0, vanilla = 0,
  tbc = 1, bc = 1, burningcrusade = 1,
  wotlk = 2, wrath = 2, lich = 2,
  cata = 3, cataclysm = 3,
  mop = 4, pandaria = 4,
  wod = 5, draenor = 5,
  legion = 6,
  bfa = 7, azeroth = 7,
  sl = 8, shadowlands = 8,
  df = 9, dragonflight = 9,
  tww = 10, warwithin = 10,
  midnight = 11,
}
local CUR_EXP = LE_EXPANSION_LEVEL_CURRENT
                or (GetExpansionLevel and GetExpansionLevel()) or 0
do
  for i = 0, CUR_EXP do
    local n = _G["EXPANSION_NAME" .. i]
    if type(n) == "string" and n ~= "" and not n:find("%s") then
      local k = ns.SearchFold(n)
      if EXP_WORDS[k] == nil then EXP_WORDS[k] = i end
    end
  end
end
local function classify(f, token)
  local bare = token:match("^[!%-](.+)$")
  local lo, hi = token:match("^ilvl(%d+)%-(%d+)$")
  local gt = token:match("^ilvl>=?(%d+)$")
  local lt = token:match("^ilvl<=?(%d+)$")
  local num = token:match("^ilvl(%d+)$") or token:match("^(%d+)$")
  if bare then
    f.nots = f.nots or {}
    f.nots[#f.nots + 1] = ns.ParseSearch(bare)
  elseif lo then
    f.ilvlMin, f.ilvlMax = tonumber(lo), tonumber(hi)
  elseif gt then
    f.ilvlMin = tonumber(gt) + (token:find(">=", 1, true) and 0 or 1)
  elseif lt then
    f.ilvlMax = tonumber(lt) - (token:find("<=", 1, true) and 0 or 1)
  elseif num then
    f.ilvl = tonumber(num)
  elseif QUALITY_WORDS[token] then
    f.quality = QUALITY_WORDS[token]
  elseif SLOT_WORDS[token] then
    f.slots = f.slots or {}
    for k in pairs(SLOT_WORDS[token]) do f.slots[k] = true end
  elseif KIND_WORDS[token] then
    f.kinds = f.kinds or {}
    f.kinds[#f.kinds + 1] = KIND_WORDS[token]
  elseif EXP_WORDS[token] then
    f.exps = f.exps or {}
    f.exps[EXP_WORDS[token]] = true
  elseif token == "current" then
    f.exps = f.exps or {}
    f.exps[CUR_EXP] = true
  elseif token == "legacy" or token == "old" then
    f.expMax = CUR_EXP - 1
  elseif token == "warbound" or token == "wb" or token == "warband" then
    f.warbound = true
  elseif token == "soulbound" or token == "sb" or token == "bound" or token == "bop" then
    f.soulbound = true
  elseif token == "boe" or token == "unbound" then
    f.boe = true
  elseif token == "token" or token == "tier" then
    f.token = true
  elseif token == "locked" or token == "blocked" then
    f.locked = true
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
    return false
  end
  return true
end

function ns.ParseSearch(q)
  q = (q or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local f = { text = {} }
  f.empty = q == ""
  for token in q:gmatch("%S+") do
    if not classify(f, token) then
      local alias = ns.SearchAlias(ns.SearchFold(token))
      if not (alias and classify(f, alias)) then
        f.text[#f.text + 1] = token
      end
    end
  end
  return f
end
function ns.MetaWarbound(m)
  if m.wb == nil then
    if not m.isGear then
      m.wb = false
    elseif m.bag then
      m.wb = ns.IsWarbound(m.bag, m.slot, m.loc, m.bound) and true or false
    else
      m.wb = ns.IsLinkWarbound(m.link) and true or false
    end
  end
  return m.wb
end

function ns.MetaExp(m)
  if m.exp == nil then
    local e = m.id and (select(15, C_Item.GetItemInfo(m.id)))
    if e == nil then return nil end
    m.exp = e
  end
  return m.exp
end

function ns.MatchSearch(m, f)
  if not f or f.empty then return true end
  if not m then return false end
  if f.nots then
    for _, n in ipairs(f.nots) do
      if ns.MatchSearch(m, n) then return false end
    end
  end
  for _, t in ipairs(f.text) do
    if not (m.text and m.text:find(t, 1, true)) then return false end
  end
  if f.quality ~= nil and m.q ~= f.quality then return false end
  if f.ilvl and m.ilvl ~= f.ilvl then return false end
  if f.ilvlMin and not (m.ilvl and m.ilvl >= f.ilvlMin) then return false end
  if f.ilvlMax and not (m.ilvl and m.ilvl <= f.ilvlMax) then return false end
  if f.slots and not (m.equipLoc and f.slots[m.equipLoc]) then return false end
  if f.kinds then
    local ok = false
    for _, k in ipairs(f.kinds) do
      if m.classID == k.class and (not k.subs or (m.subID and k.subs[m.subID])) then
        ok = true
        break
      end
    end
    if not ok then return false end
  end
  if f.exps then
    local e = ns.MetaExp(m)
    if not (e and f.exps[e]) then return false end
  end
  if f.expMax then
    local e = ns.MetaExp(m)
    if not (e and e <= f.expMax) then return false end
  end
  if f.warbound and not ns.MetaWarbound(m) then return false end
  if f.soulbound and not (m.bound and not ns.MetaWarbound(m)) then return false end
  if f.boe and not (m.isGear and not m.bound) then return false end
  if f.token and not (m.id and ns.TIER_TOKENS and ns.TIER_TOKENS[m.id]) then return false end
  if f.locked and not (m.id and ns.Vendor and ns.Vendor:Blocked(m.id)) then return false end
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
