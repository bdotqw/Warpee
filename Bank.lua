local addonName, ns = ...
local Theme = ns.Theme
local Bags = ns.Bags

local function idList(names)
  local t = {}
  for _, n in ipairs(names) do
    local id = Enum and Enum.BagIndex and Enum.BagIndex[n]
    if id ~= nil then t[#t + 1] = id end
  end
  return t
end
local CHAR_TABS = idList({ "CharacterBankTab_1", "CharacterBankTab_2", "CharacterBankTab_3",
                           "CharacterBankTab_4", "CharacterBankTab_5", "CharacterBankTab_6" })
local LEGACY_BANK = idList({ "Bank", "BankBag_1", "BankBag_2", "BankBag_3", "BankBag_4",
                             "BankBag_5", "BankBag_6", "BankBag_7" })
local BANK_TABS_MODE = #CHAR_TABS > 0
local BANK_MAIN = BANK_TABS_MODE and CHAR_TABS or LEGACY_BANK
local WARBAND   = idList({ "AccountBankTab_1", "AccountBankTab_2", "AccountBankTab_3",
                           "AccountBankTab_4", "AccountBankTab_5" })

local PAD, DIV = 10, 22
local HBTN = 26
local ROW1_Y = 4
local SEARCH_MIN = 80
local function headerH(base) return math.max(34, base + 16) end
local function footerH(base) return math.max(28, base + 10) end

function ns.WarbandActive()
  return C_Bank ~= nil and C_Bank.FetchPurchasedBankTabData ~= nil and #WARBAND > 0
end

local function bankTypeFor(mode)
  if not (Enum and Enum.BankType) then return nil end
  return (mode == "warband") and Enum.BankType.Account or Enum.BankType.Character
end

local function bankLive(self, bankType)
  if not (self.bankerOpen and bankType) then return false end
  if self.snap then return false end
  if C_Bank and C_Bank.CanViewBank then
    local ok, can = pcall(C_Bank.CanViewBank, bankType)
    if ok and can == false then return false end
  end
  return true
end

local function purchasableCost(bankType)
  if not (bankType and C_Bank and C_Bank.CanPurchaseBankTab
          and C_Bank.FetchNextPurchasableBankTabData) then return nil end
  local ok, can = pcall(C_Bank.CanPurchaseBankTab, bankType)
  if not ok or not can then return nil end
  if C_Bank.HasMaxBankTabs then
    local okMax, maxed = pcall(C_Bank.HasMaxBankTabs, bankType)
    if okMax and maxed then return nil end
  end
  local okData, data = pcall(C_Bank.FetchNextPurchasableBankTabData, bankType)
  return (okData and data and data.tabCost) or nil
end

local function moneyTransfer(bankType)
  if not bankType then return false end
  if C_Bank and C_Bank.DoesBankTypeSupportMoneyTransfer then
    local ok, yes = pcall(C_Bank.DoesBankTypeSupportMoneyTransfer, bankType)
    if ok then return yes and true or false end
  end
  return bankType == (Enum and Enum.BankType and Enum.BankType.Account)
end

-- Never touch BankFrame.BankPanel from here or anywhere else. The game reads
-- BankFrame on every right click of a bag slot, so writing the panel's fields or
-- showing it from addon code kills using items everywhere for the rest of the
-- session. Deposits follow whatever bank type the game itself has active.
function ns.DepositBlocked(b)
  local bt = ns.Bank.depositType
  local m = bt and b and b.meta
  if not (m and m.loc and C_Bank and C_Bank.IsItemAllowedInBankType) then return false end
  local ok, allowed = pcall(C_Bank.IsItemAllowedInBankType, bt, m.loc)
  return ok and allowed == false
end

function ns.RefreshBagDim()
  if not (Bags.frame and Bags.frame:IsShown()) then return end
  if Bags.ApplySearch then Bags:ApplySearch() end
  if Bags.BrowseState then Bags:BrowseState() end
end

local function addTip(btn, title, extra, side)
  ns.AddTip(btn, title, side or "right", extra)
end

local MEMBER, OWNER = {}, {}
for _, id in ipairs(BANK_MAIN) do MEMBER[id] = true; OWNER[id] = "bank" end
for _, id in ipairs(WARBAND) do MEMBER[id] = true; OWNER[id] = "warband" end
if ns.reagentBank then MEMBER[ns.reagentBank] = true; OWNER[ns.reagentBank] = "bank" end
function ns.IsBankContainer(id) return MEMBER[id] == true end

local function stepFor(size, gap) return size + gap end
local function gridWidth(size, cols, gap) return (cols - 1) * (size + gap) + size end

local View = {}
View.__index = View
ns.Bank = setmetatable({ state = {}, mode = "bank", query = "" }, View)

function View:State(mode)
  local st = self.state[mode]
  if not st then
    st = { mode = mode, pool = {}, vpool = {}, plan = {}, byKey = {}, dirty = {}, gen = {}, labels = {},
           planCount = 0, shown = 0, used = 0, total = 0, contentH = 0 }
    self.state[mode] = st
  end
  if not st.content and self.frame then
    local c = CreateFrame("Frame", nil, self.frame)
    c:SetSize(100, 100)
    c:Hide()
    st.content = c
  end
  return st
end

function View:Label(st, i, color)
  local l = st.labels[i]
  if not l then
    l = Theme:Label(st.content, 11, color or "faint")
    st.labels[i] = l
  end
  if self.fontPath then l:SetFont(self.fontPath, math.max(7, (self.fontBase or 13) - 2), "") end
  l:SetTextColor(Theme:C(color or "faint"))
  return l
end

function View:CellSize()
  return (WarpeeDB and WarpeeDB.bankIconSize) or 40
end

function View:Cols(mode)
  if not WarpeeDB then return 24 end
  if (mode or self.mode) == "warband" then return WarpeeDB.warbandCols or 24 end
  return WarpeeDB.bankCols or 24
end
function View:FontSize() return 13 end
function View:HeaderH() return math.max(58, headerH(self:FontSize()) + 24) + Theme:TopInset() end
function View:FooterH() return footerH(self:FontSize()) end

function View:Sections(mode)
  if mode == "warband" then return { { ids = WARBAND } } end
  if not BANK_TABS_MODE and ns.reagentBank then
    if Bags.mergeReagents then
      local ids = { }
      for _, id in ipairs(BANK_MAIN) do ids[#ids + 1] = id end
      ids[#ids + 1] = ns.reagentBank
      return { { ids = ids } }
    end
    local main = { ids = BANK_MAIN }
    local reag = { ids = { ns.reagentBank }, label = "REAGENTS", color = "reagent" }
    if Bags.reagentTop then return { reag, main } end
    return { main, reag }
  end
  return { { ids = BANK_MAIN } }
end

function View:Build()
  if self.frame then return self.frame end
  local f = CreateFrame("Frame", "WarpeeBankFrame", UIParent, "BackdropTemplate")
  f:Hide()
  Theme:Panel(f, "bg", "stroke")
  f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(s) ns.DragStart(s) end)
  f:SetScript("OnDragStop", function(s)
    if not s.wpeMoving then return end
    s.wpeMoving = nil
    s:StopMovingOrSizing()
    ns.Rebase(s, "bankPos")
  end)
  Theme:Window(f, "WarpeeBankFrame")
  Theme:HeaderBand(f)
  f:SetScript("OnHide", function()
    ns.ClearSearch(self.search)
    self.depositType = nil
    if ns.CharPicker then ns.CharPicker:Close() end
    if ns.Vault:SetView("bank", nil) then self:UpdateCharBtn() end
    ns.RefreshBagDim()
    if self.bankerOpen and not self.closing then
      self.closing = true
      -- An OnHide can run inside the game's own protected close chain, and closing
      -- the bank from there leaves taint that blocks using items from every
      -- container. The timer puts the call back in plain addon context.
      C_Timer.After(0, function()
        if C_Bank and C_Bank.CloseBankFrame then
          pcall(C_Bank.CloseBankFrame)
        elseif CloseBankFrame then
          pcall(CloseBankFrame)
        end
        self.closing = nil
      end)
    end
  end)
  self.frame = f
  ns.CreateMoveBar(f, "bankPos")

  local close = ns.CreateGlyphButton(f, "×", 26)
  close:SetPoint("TOPRIGHT", -PAD, -ROW1_Y)
  close:SetScript("OnClick", function() f:Hide() end)
  self.closeBtn = close

  local gear = ns.CreateGlyphButton(f, "|TInterface\\Buttons\\UI-OptionsButton:13:13:0:0|t", 26)
  gear:SetPoint("TOPRIGHT", close, "TOPLEFT", -4, 0)
  gear:SetScript("OnClick", function() if ns.Options then ns.Options:Toggle() end end)
  addTip(gear, "Settings", nil, "top")
  self.gearBtn = gear

  local sort = ns.CreateGlyphButton(f, "", 26)
  sort:SetPoint("TOPRIGHT", gear, "TOPLEFT", -4, 0)
  sort:SetScript("OnClick", function() self:Sort() end)
  addTip(sort, "Clean up", nil, "top")
  local sortIcon = sort:CreateTexture(nil, "ARTWORK")
  sortIcon:SetAtlas("auctionhouse-ui-sortarrow")
  sortIcon:SetSize(13, 15)
  sortIcon:SetPoint("CENTER")
  sortIcon:SetVertexColor(Theme:C("text"))
  Theme:Track(sortIcon, function(x) x:SetVertexColor(Theme:C("text")) end)
  sort.icon = sortIcon
  self.sortBtn = sort

  local bankTab = ns.CreateButton(f, ns.L["Bank"], 52, HBTN)
  ns.LocalText(bankTab, "Bank")
  bankTab:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -ROW1_Y)
  bankTab:SetScript("OnClick", function() self:SetMode("bank") end)
  bankTab:HookScript("OnLeave", function() self:UpdateTabs() end)
  self.bankTab = bankTab
  local wbTab = ns.CreateButton(f, ns.L["Warband"], 68, HBTN)
  ns.LocalText(wbTab, "Warband")
  wbTab:SetPoint("LEFT", bankTab, "RIGHT", 4, 0)
  wbTab:SetScript("OnClick", function() self:SetMode("warband") end)
  wbTab:HookScript("OnLeave", function() self:UpdateTabs() end)
  self.wbTab = wbTab

  local freeText = Theme:Label(f, 12, "dim")
  freeText:SetPoint("LEFT", wbTab, "RIGHT", 12, 0)
  self.freeText = freeText

  local search = ns.CreateSearchBox(f, function(text)
    self.query = (text or ""):lower()
    self.filters = ns.ParseSearch(self.query)
    self:ApplySearch()
    ns.MirrorSearch("bank", text)
  end)
  search:SetPoint("LEFT", wbTab, "RIGHT", 12, 0)
  search:SetPoint("RIGHT", freeText, "LEFT", -10, 0)
  search:SetPoint("TOP", f, "TOP", 0, -5)
  search:SetHeight(22)
  self.search = search

  self:BuildCharPicker()
  self:AnchorSearch()

  local money = Theme:Label(f, 16, "text")
  money:SetPoint("BOTTOMRIGHT", -PAD, 6)
  self.money = money
  ns.AttachGoldTooltip(money, f)

  local caption = Theme:Label(f, 10, "faint")
  caption:SetPoint("RIGHT", money, "LEFT", -6, 1)
  self.moneyCaption = caption

  local function moneyPopup(which, other)
    StaticPopup_Hide(other)
    if StaticPopup_Visible(which) then StaticPopup_Hide(which); return end
    StaticPopup_Show(which, nil, nil, { bankType = bankTypeFor(self.mode) })
  end

  local dep = ns.CreateButton(f, _G.BANK_DEPOSIT_MONEY_BUTTON_LABEL or "Deposit", 70, 20)
  dep:SetPoint("BOTTOMLEFT", PAD, 5)
  dep:SetScript("OnClick", function() moneyPopup("BANK_MONEY_DEPOSIT", "BANK_MONEY_WITHDRAW") end)
  addTip(dep, "Put your gold into the Warband bank")
  self.depositBtn = dep

  local wdr = ns.CreateButton(f, _G.BANK_WITHDRAW_MONEY_BUTTON_LABEL or "Withdraw", 76, 20)
  wdr:SetPoint("LEFT", dep, "RIGHT", 4, 0)
  wdr:SetScript("OnClick", function() moneyPopup("BANK_MONEY_WITHDRAW", "BANK_MONEY_DEPOSIT") end)
  addTip(wdr, "Take gold out of the Warband bank")
  self.withdrawBtn = wdr

  self:BuildBuyButtons()

  local gridBg = Theme:Rect(f, "panel", "BACKGROUND")
  gridBg:SetDrawLayer("BACKGROUND", 1)
  self.gridBg = gridBg
  gridBg:SetAlpha(Theme:GridAlpha())

  local hint = Theme:Label(f, 13, "dim")
  hint:SetPoint("BOTTOMLEFT", PAD, 8)
  ns.LocalText(hint, "Visit a banker to record this bank")
  hint:Hide()
  self.hint = hint

  f:Hide()
  return f
end

function View:BuildCharPicker()
  if self.charBtn then return self.charBtn end
  local b = ns.CreateCharTag(self.frame, 22, "right")
  b:SetScript("OnClick", function(s)
    ns.CharPicker:Toggle(s, "right", function(k) self:SelectChar(k) end,
      ns.Vault:ViewKey("bank"), "bank")
  end)
  addTip(b, "Browse another character's bank", function(s)
    if s:IsEnabled() then return nil end
    return { { text = "Nothing saved for other characters yet", color = "dim" } }
  end)
  b:Hide()
  self.charBtn = b
  return b
end

function View:WantSnap()
  if not self.bankerOpen then return true end
  if self.mode ~= "bank" then return false end
  return ns.Vault:ViewKey("bank") ~= ns.Vault:Owner()
end

function View:ApplySnap()
  local want = self:WantSnap() and true or nil
  if self.snap == want then return false end
  self.snap = want
  self:HideSlots()
  return true
end

function View:SelectChar(key)
  if not ns.Vault:SetView("bank", key) then return end
  self:UpdateCharBtn()
  if self:ApplySnap() then self:Activate(self.mode) else self:Repaint() end
end

function View:AnchorHeader()
  if not self.frame then return end
  local top = Theme:TopInset()
  local row1 = ROW1_Y + top + Theme:HeadDrop()
  if self.closeBtn then
    self.closeBtn:ClearAllPoints()
    ns.SnapPoint(self.closeBtn, "TOPRIGHT", self.frame, "TOPRIGHT", -PAD, -row1)
  end
  if self.bankTab then
    self.bankTab:ClearAllPoints()
    ns.SnapPoint(self.bankTab, "TOPLEFT", self.frame, "TOPLEFT", PAD, -row1)
  end
  Theme:HeaderBand(self.frame)
  self:UpdateTabs()
  self:AnchorSearch()
end

function View:AnchorSearch()
  if not self.search then return end
  local b = self.charBtn
  local row = 34 + Theme:TopInset()
  self.search:ClearAllPoints()
  self.search:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PAD, -row)
  if b and b:IsShown() then
    b:ClearAllPoints()
    b:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -PAD, -row)
    self.search:SetPoint("TOPRIGHT", b, "TOPLEFT", -6, 0)
  else
    self.search:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -PAD, -row)
  end
end

function View:UpdateCharBtn()
  local b = self.charBtn
  if not b then return end
  b:SetShown(self.mode == "bank")
  if self.mode ~= "bank" then
    if ns.CharPicker then ns.CharPicker:Close() end
    self:AnchorSearch()
    return
  end
  local all = ns.Vault:Chars(true, "bank")
  local key = ns.Vault:ViewKey("bank")
  local on = ns.Vault:Others("bank") > 0 or key ~= ns.Vault:Owner()
  b:SetEnabled(on)
  b:SetAlpha(on and 1 or 0.6)
  if b.caret then b.caret:SetTint(on and "dim" or "faint") end
  if not on and ns.CharPicker then ns.CharPicker:Close() end
  local class, label
  for _, e in ipairs(all) do
    if e.key == key then class = e.class; label = e.name; break end
  end
  if not label and key == ns.Vault:Owner() then
    label = UnitName("player")
    local _, cls = UnitClass("player")
    class = cls
  end
  if not label and on and #ns.Vault:Chars(false, "bank") == 0 then label = ns.L["Hidden"] end
  ns.PaintCharTag(b, label or (key and key:match("^(.-)%-")) or "?", class)
  self:AnchorSearch()
end

function View:BuildBuyButtons()
  self.buyBtn = self.buyBtn or {}
  for _, mode in ipairs({ "bank", "warband" }) do
    local bt = not self.buyBtn[mode] and bankTypeFor(mode)
    local b = bt and ns.CreateButton(self.frame, ns.L["Buy tab"], 96, 20, "BankPanelPurchaseButtonScriptTemplate")
    if b then
      b:SetAttribute("overrideBankType", bt)
      b:Hide()
      addTip(b, mode == "warband" and "Buy another Warband bank tab" or "Buy another bank tab",
        function(btn)
          if not btn.cost then return nil end
          local poor = btn.cost > GetMoney()
          return { { text = (ns.L["Cost: %s"]):format(ns.FormatMoney(btn.cost)),
                     color = poor and "gaugeHi" or "text" } }
        end)
      self.buyBtn[mode] = b
    end
  end
end

function View:AccountOnly()
  if not self.bankerOpen then return false end
  if self.acctBanker ~= nil then return self.acctBanker end
  local E = Enum and Enum.BankType
  if E and C_Bank and C_Bank.CanViewBank then
    local ok, yes = pcall(C_Bank.CanViewBank, E.Character)
    if ok and yes == false then return true end
  end
  return false
end

function View:ModeAvailable(mode)
  if mode == "warband" and not ns.WarbandActive() then return false end
  if mode == "bank" and self:AccountOnly() then return false end
  if not self.bankerOpen and not ns.Vault:Saved(mode) then return false end
  return true
end

function View:EnforceMode()
  if not self:ModeAvailable(self.mode) then
    self:SetMode(self.mode == "bank" and "warband" or "bank")
  end
end

local BLIZZ_TAB = {}

-- The bank the game deposits into on a right click is BankFrame own tab type, and only the
-- game may set it: writing BankPanel type from here would hand a tainted value to that
-- protected deposit, and then every right click in every bag would be refused. So the game
-- own tab button is parked over ours with its art switched off and takes the click, the
-- game flips its own type from a real hardware press, and our view is walked over to match.
-- Nothing here writes a field or a script on a game frame: only SetParent, points, alpha,
-- hit rect, strata, level and EnableMouse, plus HookScript and hooksecurefunc. Our own tab
-- hands its mouse over while a game button is pinned to it, so a click can never land on
-- ours instead, and takes it back for a snapshot viewed with no banker open. The game lays
-- its own tab strip out again by itself, so both calls that do that are hooked and the
-- button is pinned back after each. Both entry points sit out combat lockdown.
function View:BlizzMode()
  local F = BankFrame
  if not (F and F.GetActiveBankType) then return nil end
  local ok, bt = pcall(F.GetActiveBankType, F)
  if not (ok and bt) then return nil end
  local acct = Enum and Enum.BankType and Enum.BankType.Account
  return (acct and bt == acct) and "warband" or "bank"
end

function View:PinBlizzTabs()
  if InCombatLockdown() then return end
  local live = self.bankerOpen and not self.snap
  for mode, btn in pairs(BLIZZ_TAB) do
    local own = (mode == "bank") and self.bankTab or self.wbTab
    if own then
      local on = (live and own:IsShown()) and true or false
      if btn:GetParent() ~= own then btn:SetParent(own) end
      btn:ClearAllPoints()
      btn:SetAllPoints(own)
      btn:SetAlpha(0)
      btn:SetHitRectInsets(0, 0, 0, 0)
      btn:SetFrameStrata(own:GetFrameStrata())
      btn:SetFrameLevel(own:GetFrameLevel() + 5)
      btn:EnableMouse(on)
      own:EnableMouse(not on)
    end
  end
end

function View:AttachBlizzTabs()
  if InCombatLockdown() then return end
  local F = BankFrame
  if not (F and F.GetTabButton and F.characterBankTabID and F.accountBankTabID) then return end
  for _, e in ipairs({ { "bank", F.characterBankTabID }, { "warband", F.accountBankTabID } }) do
    local mode, own = e[1], (e[1] == "bank") and self.bankTab or self.wbTab
    local ok, btn = pcall(F.GetTabButton, F, e[2])
    btn = (ok and btn) or nil
    if own and btn and BLIZZ_TAB[mode] ~= btn then
      BLIZZ_TAB[mode] = btn
      btn:HookScript("OnEnter", function()
        if not own:IsShown() then return end
        own:SetBackdropColor(Theme:C("panelHi"))
        own:SetBackdropBorderColor(Theme:C("accent"))
        own.Text:SetTextColor(Theme:C("accent"))
      end)
      btn:HookScript("OnLeave", function()
        own:SetBackdropColor(Theme:C("panel"))
        self:UpdateTabs()
      end)
      btn:HookScript("OnClick", function()
        if self.frame and self.frame:IsShown() then self:SetMode(mode) end
      end)
    end
  end
  if not self.tabHooked and F.SetTab then
    self.tabHooked = true
    hooksecurefunc(F, "SetTab", function() self:PinBlizzTabs() end)
    if F.RefreshTabVisibility then
      hooksecurefunc(F, "RefreshTabVisibility", function() self:PinBlizzTabs() end)
    end
  end
  if not self.typeHooked and F.BankPanel and F.BankPanel.SetBankType then
    self.typeHooked = true
    hooksecurefunc(F.BankPanel, "SetBankType", function(_, bt)
      local acct = Enum and Enum.BankType and Enum.BankType.Account
      local want = (acct and bt == acct) and "warband" or "bank"
      if self.frame and self.frame:IsShown() then self:SetMode(want) end
    end)
  end
  self:PinBlizzTabs()
end

function View:UpdateTabs()
  local function paint(btn, on)
    if not btn then return end
    btn.Text:SetTextColor(Theme:C(on and "accent" or "text"))
    btn:SetBackdropBorderColor(Theme:C(on and "accent" or "stroke"))
  end
  paint(self.bankTab, self.mode == "bank")
  paint(self.wbTab, self.mode == "warband")
  local row1 = ROW1_Y + Theme:TopInset() + Theme:HeadDrop()
  local bankOn = self:ModeAvailable("bank")
  if self.bankTab then self.bankTab:SetShown(bankOn) end
  local last = bankOn and self.bankTab or nil
  if self.wbTab then
    local wbOn = self:ModeAvailable("warband")
    self.wbTab:SetShown(wbOn)
    self.wbTab:ClearAllPoints()
    if bankOn then
      self.wbTab:SetPoint("LEFT", self.bankTab, "RIGHT", 4, 0)
    else
      ns.SnapPoint(self.wbTab, "TOPLEFT", self.frame, "TOPLEFT", PAD, -row1)
    end
    if wbOn then last = self.wbTab end
  end
  if self.freeText and last then
    self.freeText:ClearAllPoints()
    self.freeText:SetPoint("LEFT", last, "RIGHT", 12, 0)
  end
  self:AttachBlizzTabs()
end

function View:SetMode(mode)
  if not self:ModeAvailable(mode) then return end
  if mode == self.mode and self.cur then return end
  self.mode = mode
  self:ApplySnap()
  self:UpdateTabs()
  self:Activate(mode)
end

function View:Activate(mode)
  local st = self:State(mode)
  local prev = self.cur
  if prev and prev ~= st then
    self:Cancel(prev, "fill")
    prev.filling = nil
    if prev.content then prev.content:Hide() end
  end
  self.cur = st
  self.depositType = self.bankerOpen and bankTypeFor(mode) or nil
  ns.RefreshBagDim()
  st.content:Show()
  self.gridBg:ClearAllPoints()
  self.gridBg:SetPoint("TOPLEFT", st.content, "TOPLEFT", -3, 3)
  self.gridBg:SetPoint("BOTTOMRIGHT", st.content, "BOTTOMRIGHT", 3, -3)
  self.gridBg:SetAlpha(Theme:GridAlpha())
  self:Layout()
end

function View:Acquire(st, i)
  if self.snap then
    local b = st.vpool[i]
    if not b then
      b = ns.CreateVaultButton(st.content)
      b.view = st
      st.vpool[i] = b
    end
    return b
  end
  local b = st.pool[i]
  if not b then
    if InCombatLockdown() then self.cold = true; return nil end
    b = ns.CreateItemButton(st.content, 0, 1)
    b.view = st
    st.pool[i] = b
  end
  return b
end

function View:HideSlots()
  for _, st in pairs(self.state) do
    for _, b in ipairs(st.pool) do
      if b.holder and b.holder:IsShown() then b.holder:Hide() end
    end
    for _, b in ipairs(st.vpool or {}) do
      if b.holder and b.holder:IsShown() then b.holder:Hide() end
    end
    st.shown, st.paintKey = 0, nil
    wipe(st.byKey)
  end
end

function View:PaintKey(size)
  return table.concat({ size, Bags.slotStyle or "tile", Bags.styleGen or 0,
                        Bags.qualityBorder and 1 or 0, Bags.qualityColorIlvl and 1 or 0,
                        ns.Badge("junk").on and 1 or 0, Bags.reagentTint and 1 or 0 }, ":")
end

function View:Plan(st, size, cols, gap)
  local step = stepFor(size, gap)
  local plan = st.plan
  local n, used, total, bottom, li = 0, 0, 0, 0, 0

  for _, sec in ipairs(self:Sections(st.mode)) do
    local first, count = n, 0
    for _, bag in ipairs(sec.ids) do
      local num, taken
      if self.snap then
        num = ns.Vault:Count(st.mode, bag)
        taken = ns.Vault:Used(st.mode, bag)
      else
        num = C_Container.GetContainerNumSlots(bag) or 0
        taken = num - (select(1, C_Container.GetContainerNumFreeSlots(bag)) or 0)
      end
      total = total + num
      used = used + taken
      for slot = 1, num do
        count = count + 1
        local c = plan[first + count] or {}
        c.bag, c.slot = bag, slot
        plan[first + count] = c
      end
    end
    if count > 0 then
      local secTop = bottom
      if sec.label then
        secTop = bottom + DIV
        li = li + 1
        local lbl = self:Label(st, li, sec.color)
        lbl:ClearAllPoints()
        lbl:SetText(sec.label)
        lbl:SetPoint("TOPLEFT", st.content, "TOPLEFT", 2, -(bottom + 6))
        lbl:Show()
      elseif bottom > 0 then
        secTop = bottom + DIV
      end
      local rows = math.ceil(count / cols)
      for k = 1, count do
        local c = plan[first + k]
        local j = Bags.revFill and (count - k + 1) or k
        local col, row = (j - 1) % cols, math.floor((j - 1) / cols)
        if Bags.fillUp then row = rows - 1 - row end
        c.x, c.y = col * step, -(secTop + row * step)
      end
      bottom = secTop + (rows - 1) * step + size
      n = first + count
    end
  end
  for j = li + 1, #st.labels do st.labels[j]:Hide() end

  st.blank = nil
  if n == 0 and self.snap then
    local rows = 4
    for k = 1, cols * rows do
      local c = plan[k] or {}
      c.bag, c.slot = 0, k
      local col, row = (k - 1) % cols, math.floor((k - 1) / cols)
      c.x, c.y = col * step, -(row * step)
      plan[k] = c
    end
    n = cols * rows
    bottom = (rows - 1) * step + size
    st.blank = true
  end

  st.planCount = n
  return n, bottom, used, total
end

function View:Cancel(st, tag)
  st.gen[tag] = (st.gen[tag] or 0) + 1
end
function View:Drip(st, tag, list, count, each, done)
  self:Cancel(st, tag)
  for i = 1, count do each(list[i], i) end
  if done then done() end
end

function View:Run(st, repaint, tag)
  local size = st.iconSize
  local snap = self.snap
  st.filling = true
  self:Drip(st, tag or "fill", st.plan, st.planCount, function(c, i)
    local b = self:Acquire(st, i)
    if not b then return end
    local h = b.holder
    if b.wpeBag ~= c.bag or b.wpeSlot ~= c.slot then
      if not snap then
        h:SetID(c.bag); b:SetID(c.slot); b.wpeBagID = c.bag
      end
      b.wpeBag, b.wpeSlot, b.link = c.bag, c.slot, nil
    end
    if b.wpeSize ~= size then ns.SnapSize(h, size, size); b.wpeSize = size end
    if b.wpeX ~= c.x or b.wpeY ~= c.y then
      h:ClearAllPoints(); ns.SnapPoint(h, "TOPLEFT", st.content, "TOPLEFT", c.x, c.y)
      b.wpeX, b.wpeY = c.x, c.y
    end
    if repaint then b.link = nil end
    if not h:IsShown() then h:Show() end
    if not b:IsShown() then b:Show() end
    if snap then
      ns.PaintVaultButton(b, ns.Vault:Slot(st.mode, c.bag, c.slot), c.bag)
    else
      ns.UpdateItemButton(b)
    end
    ns.ApplySearchToButton(b, self.filters)
    st.byKey[c.bag * 1000 + c.slot] = b
  end, function()
    st.filling = nil
  end)
end

function View:Fonts()
  local path = ns.Fonts:Current()
  local base = self:FontSize()
  self.fontPath, self.fontBase = path, base
  local function put(fs, delta)
    if fs then fs:SetFont(path, math.max(7, base + (delta or 0)), "") end
  end
  local bh = math.max(20, base + 6)
  local function fit(btn, minW, pad, h)
    if not (btn and btn.Text) then return end
    btn:SetHeight(h or bh)
    btn:SetWidth(math.max(minW, math.ceil(btn.Text:GetStringWidth()) + (pad or 16)))
  end
  put(self.freeText, -1)
  put(self.hint, 0)
  put(self.money, 3)
  put(self.moneyCaption, -3)
  local sh = math.max(22, base + 8)
  if self.search then put(self.search, 0); put(self.search.Hint, 0); self.search:SetHeight(sh) end
  if self.bankTab then put(self.bankTab.Text, -1); fit(self.bankTab, 52, nil, HBTN) end
  if self.wbTab then put(self.wbTab.Text, -1); fit(self.wbTab, 68, nil, HBTN) end
  if self.charBtn then
    put(self.charBtn.Text, -1)
    self.charBtn:SetHeight(sh)
  end
  if self.depositBtn then put(self.depositBtn.Text, -1); fit(self.depositBtn, 70, 18) end
  if self.withdrawBtn then put(self.withdrawBtn.Text, -1); fit(self.withdrawBtn, 76, 18) end
  for _, b in pairs(self.buyBtn or {}) do put(b.Text, -1); b:SetHeight(bh) end
  if self.frame and self.frame.wpeBar then self.frame.wpeBar:Fonts(path, math.max(8, base - 2)) end
  for _, st in pairs(self.state) do
    for _, l in ipairs(st.labels) do put(l, -2) end
  end
end

function View:LayoutMode(st, tag)
  local cols = self:Cols(st.mode)
  local size, gap = ns.GridMetrics(self.frame, self:CellSize(), Bags.gap or 4)
  st.iconSize = size
  st.pxGap = gap
  local key = self:PaintKey(size)
  local repaint = (st.paintKey ~= key)
  st.paintKey = key
  wipe(st.byKey)
  wipe(st.dirty)
  st.needLayout = nil
  local n, contentH, used, total = self:Plan(st, size, cols, gap)
  st.shown, st.used, st.total = n, used, total
  st.contentH = math.max(size, contentH)
  local pool = self.snap and st.vpool or st.pool
  for j = n + 1, #pool do
    local h = pool[j].holder
    if h:IsShown() then h:Hide() end
  end
  if st == self.cur then
    self:Resize(st)
    self:UpdateMeta()
    self:UpdateFooter()
    if self.hint then self.hint:SetShown(st.blank and true or false) end
  end
  self:Run(st, repaint, tag)
end

function View:Layout()
  if not (self.frame and self.cur) then return end
  self:Fonts()
  self:AnchorHeader()
  self:LayoutMode(self.cur, "fill")
end

function View:Resize(st)
  local gw = gridWidth(st.iconSize, self:Cols(st.mode), st.pxGap or Bags.gap or 4)
  st.content:ClearAllPoints()
  ns.SnapPoint(st.content, "TOPLEFT", self.frame, "TOPLEFT", PAD, -(self:HeaderH() + 4))
  st.content:SetSize(gw, st.contentH)
  self.frame:SetSize(PAD * 2 + gw, self:HeaderH() + 4 + st.contentH + self:FooterH())
  ns.Rebase(self.frame, "bankPos")
end

function View:FitHeader()
  if self.search then self.search:Show() end
  if self.freeText then
    local edge = self.sortBtn and self.sortBtn:IsShown() and self.sortBtn:GetLeft()
    local from = self.freeText:GetLeft()
    local show = true
    if edge and from then
      show = (edge - from - 10) >= math.ceil(self.freeText:GetStringWidth())
    end
    self.freeText:SetShown(show)
  end
end

function View:UpdateMeta()
  local st = self.cur
  self:UpdateCharBtn()
  if self.freeText and st then
    self.freeText:SetText((ns.L["Slots %d/%d"]):format(st.used or 0, st.total or 0))
  end
  self:FitHeader()
end

function View:Sort()
  local bt = bankTypeFor(self.mode)
  if not bankLive(self, bt) then return end
  if C_Bank and C_Bank.FetchNumPurchasedBankTabs then
    local ok, tabs = pcall(C_Bank.FetchNumPurchasedBankTabs, bt)
    if ok and (tonumber(tabs) or 0) <= 0 then return end
  end
  if PlaySound and SOUNDKIT and SOUNDKIT.UI_BAG_SORTING_01 then
    PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
  end
  if C_Container.SortBank then
    C_Container.SortBank(bt)
  elseif self.mode == "warband" then
    if C_Container.SortAccountBankBags then C_Container.SortAccountBankBags() end
  elseif C_Container.SortBankBags then
    C_Container.SortBankBags()
  end
end

function View:UpdateFooter()
  if not self.frame then return end
  local bt = bankTypeFor(self.mode)
  local live = bankLive(self, bt)
  local transfer = live and moneyTransfer(bt)
  if self.sortBtn then self.sortBtn:SetShown(live) end

  local function gate(btn, canName)
    if not btn then return end
    btn:SetShown(transfer)
    if not transfer then return end
    local can, fn = false, C_Bank and C_Bank[canName]
    if fn then local ok, v = pcall(fn, bt); can = ok and v end
    ns.SetButtonEnabled(btn, can)
  end
  gate(self.depositBtn, "CanDepositMoney")
  gate(self.withdrawBtn, "CanWithdrawMoney")

  for mode, b in pairs(self.buyBtn or {}) do if mode ~= self.mode then b:Hide() end end
  local buy = self.buyBtn and self.buyBtn[self.mode]
  if buy then
    local cost = live and purchasableCost(bt) or nil
    buy.cost = cost
    if cost then
      buy.Text:SetText((ns.L["Buy tab · %s"]):format(ns.FormatGold(cost)))
      buy.Text:SetTextColor(Theme:C(cost > GetMoney() and "gaugeHi" or "text"))
      buy:SetWidth(math.max(90, math.ceil(buy.Text:GetStringWidth()) + 22))
      buy:ClearAllPoints()
      if transfer and self.withdrawBtn then
        buy:SetPoint("LEFT", self.withdrawBtn, "RIGHT", 8, 0)
      else
        buy:SetPoint("BOTTOMLEFT", PAD, 5)
      end
      buy:Show()
    else
      buy:Hide()
    end
  end

  if self.money then
    local abt = Enum and Enum.BankType and Enum.BankType.Account
    local sum
    if self.bankerOpen and abt and C_Bank and C_Bank.FetchDepositedMoney then
      local ok, v = pcall(C_Bank.FetchDepositedMoney, abt)
      if ok then sum = v end
    end
    if sum == nil then sum = ns.Vault:WarbandMoney() end
    self.money:SetText(sum and ns.FormatMoney(sum) or "—")
    self.moneyCaption:SetText(ns.L["WARBAND BANK"])
  end

  local need = PAD * 2 + 12
  if transfer then
    if self.depositBtn then need = need + self.depositBtn:GetWidth() + 4 end
    if self.withdrawBtn then need = need + self.withdrawBtn:GetWidth() + 8 end
  end
  if buy and buy:IsShown() then need = need + buy:GetWidth() + 8 end
  if self.hint and self.hint:IsShown() then need = need + math.ceil(self.hint:GetStringWidth()) + 8 end
  if self.money then need = need + math.ceil(self.money:GetStringWidth()) end
  local w = self.frame:GetWidth()
  if self.moneyCaption then
    local capW = math.ceil(self.moneyCaption:GetStringWidth()) + 6
    self.moneyCaption:SetShown(need + capW <= w)
  end
  if need > w then self.frame:SetWidth(need) end
end

function View:ApplySearch()
  local st = self.cur
  if not st then return end
  local pool = self.snap and st.vpool or st.pool
  for j = 1, (st.shown or 0) do ns.ApplySearchToButton(pool[j], self.filters) end
end

function View:CountSlots(mode)
  local total, used = 0, 0
  for _, sec in ipairs(self:Sections(mode)) do
    for _, bag in ipairs(sec.ids) do
      if self.snap then
        total = total + ns.Vault:Count(mode, bag)
        used = used + ns.Vault:Used(mode, bag)
      else
        local num = C_Container.GetContainerNumSlots(bag) or 0
        total = total + num
        used = used + (num - (select(1, C_Container.GetContainerNumFreeSlots(bag)) or 0))
      end
    end
  end
  return total, used
end

function View:UpdateDirty()
  local st = self.cur
  if self.snap then return end
  if not (st and self.frame and self.frame:IsShown()) then return end
  local total, used = self:CountSlots(st.mode)
  if total ~= st.total then wipe(st.dirty); self:Layout(); return end
  st.used = used
  local q = self.dripQueue or {}
  self.dripQueue = q
  local n = 0
  for bag in pairs(st.dirty) do
    local num = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, num do
      local b = st.byKey[bag * 1000 + slot]
      if b then n = n + 1; q[n] = b end
    end
  end
  wipe(st.dirty)
  self:UpdateMeta()
  self:Drip(st, "fill", q, n, function(b)
    ns.UpdateItemButton(b)
    ns.ApplySearchToButton(b, self.filters)
  end)
end

function View:QueueRefresh(bagID)
  if not (self.frame and self.frame:IsShown() and self.cur) then return end
  if bagID then
    local owner = OWNER[bagID]
    if owner and owner ~= self.cur.mode then return end
    self.cur.dirty[bagID] = true
  else
    self.cur.needLayout = true
  end
  self.refreshGen = (self.refreshGen or 0) + 1
  local gen = self.refreshGen
  C_Timer.After(0.1, function()
    if self.refreshGen ~= gen then return end
    local st = self.cur
    if self.bankerOpen and not self.snap and st then
      ns.Vault:Capture(st.mode, (not st.needLayout) and next(st.dirty) and st.dirty or nil)
    end
    if not (st and self.frame and self.frame:IsShown()) then return end
    if st.needLayout or st.filling then
      self:Layout()
    else
      self:UpdateDirty()
    end
  end)
end
function View:Refresh()
  if self.frame and self.frame:IsShown() then self:Layout() end
end

function View:RefreshNewItems()
  local st = self.cur
  if self.snap or not (st and self.frame and self.frame:IsShown()) then return end
  for i = 1, (st.shown or 0) do
    local b = st.pool[i]
    if b then ns.SyncNewItem(b) end
  end
end

function View:RefreshQuests()
  local st = self.cur
  if self.snap or not (st and self.frame and self.frame:IsShown()) then return end
  for i = 1, (st.shown or 0) do
    local b = st.pool[i]
    if b and ns.SyncQuestMark(b) then
      b.link = nil
      ns.UpdateItemButton(b)
      ns.ApplySearchToButton(b, self.filters)
    end
  end
end

function View:Repaint()
  for _, st in pairs(self.state) do
    for _, b in ipairs(st.pool) do b.link = nil end
    for _, b in ipairs(st.vpool or {}) do b.link = nil end
    st.paintKey = nil
  end
  self:Refresh()
end

function View:Restyle()
  Bags.styleGen = (Bags.styleGen or 0) + 1
  if self.frame and self.frame:IsShown() then
    self:UpdateTabs()
    self:Repaint()
  end
end

function View:Place()
  ns.PlaceWindow(self.frame, "bankPos", { p = "CENTER", rp = "CENTER", x = 220, y = 40 })
end

function View:OnBankOpened()
  self:Build()
  self:BuildBuyButtons()
  ns.Vault:SetView("bank", nil)
  if self.snap then self.snap = nil; self:HideSlots() end
  if self.mode == "warband" and not ns.WarbandActive() then self.mode = "bank" end
  if self.mode == "bank" and self:AccountOnly() then self.mode = "warband" end
  self:UpdateTabs()
  self:Place()
  self.frame:Show()
  Theme:Raise(self.frame)
  self:Activate(self.mode)
  if not self:AccountOnly() then ns.Vault:Capture("bank") end
  if ns.WarbandActive() then ns.Vault:Capture("warband") end
  ns.RefreshBagDim()
end

function View:OpenSnapshot(mode)
  mode = mode or "bank"
  if not self:ModeAvailable(mode) then
    mode = self:ModeAvailable("warband") and "warband" or "bank"
  end
  self:Build()
  if not self.snap then self.snap = true; self:HideSlots() end
  self.mode = mode
  self:UpdateTabs()
  self:Place()
  self.frame:Show()
  Theme:Raise(self.frame)
  self:Activate(mode)
end

function View:OnBankClosed()
  if self.frame then self.frame:Hide() end
  self.depositType = nil
  self.acctBanker = nil
  ns.RefreshBagDim()
end

-- Reparenting is the whole trick, and it has to stay the whole trick. A SetScript on
-- BankFrame taints the frame, and the taint reaches the secure bank work: the tab
-- purchase button stops answering, and the game reads BankFrame on every right click of
-- a bag slot, so item use goes with it. Its OnShow is also what gives BankFrame.BankPanel
-- a bank type through SelectDefaultTab, and the game passes that type into the deposit,
-- so silencing OnShow sent everything to the character bank. Never call BankFrame:Hide()
-- either: that fires BANKFRAME_CLOSED and ends the banker session.
function View:HideBlizzard()
  if self.blizzHidden then return end
  local hidden = self.hiddenHolder
  if not hidden then hidden = CreateFrame("Frame"); hidden:Hide(); self.hiddenHolder = hidden end
  if BankFrame then BankFrame:SetParent(hidden) end
  for n = 7, 13 do
    local cf = _G["ContainerFrame" .. n]
    if cf then cf:SetParent(hidden) end
  end
  self.blizzHidden = true
end
