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
local FONT = 15
local HBAND = 32

-- Caption ellipsis and fit are shared with the bags in Theme.lua now (ns.FitLabel / ns.CharStops);
-- the bank had a byte-for-byte copy. Kept as a file local so the call sites read unchanged.
local fitBankLabel = ns.FitLabel

local function applyDensity(size)
  local d = ns.Density(size)
  PAD, DIV, HBTN = d.pad, d.div, d.hb
  FONT = d.font
  HBAND = d.headerBand
end

local function sizeGlyph(btn, size)
  if not btn then return end
  local fp = ns.Fonts:Current()
  if btn.wpeBoxW == size and btn.wpeBoxH == size and btn.wpeFont == fp then return end
  btn.wpeFont = fp
  ns.SnapBox(btn, size, size)
  if btn.Text then btn.Text:SetFont(fp, math.max(16, math.floor(size * 0.74)), ns.OutlineFlags()) end
  if btn.icon and btn.iconPct then
    local h = btn.iconPctY or btn.iconPct
    btn.icon:SetSize(math.floor(size * btn.iconPct / 100 + 0.5), math.floor(size * h / 100 + 0.5))
  end
  btn:Repaint()
end
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

-- A bank type can be switched off at the realm, and the game reports that through a reason
-- of its own rather than a failed call: the bank panel asks for it and turns the answer into
-- the prompt it draws over its own grid. The sentence is a plain global, so it arrives in the
-- player's own language and is not ours to translate. Zero is "None", the bank is fine, and the
-- panel's own table skips it the same way.
local BANK_LOCKED = {}
if Enum and Enum.BankLockedReason then
  BANK_LOCKED[Enum.BankLockedReason.NoAccountInventoryLock] = "BANK_LOCKED_REASON_NO_ACCOUNT_INVENTORY_LOCK"
  BANK_LOCKED[Enum.BankLockedReason.BankDisabled] = "BANK_LOCKED_REASON_BANK_DISABLED"
  BANK_LOCKED[Enum.BankLockedReason.BankConversionFailed] = "BANK_LOCKED_REASON_BANK_CONVERSION_FAILED"
end

local function bankLockMessage(bankType)
  if not (bankType and C_Bank and C_Bank.FetchBankLockedReason) then return nil end
  local ok, reason = pcall(C_Bank.FetchBankLockedReason, bankType)
  local name = ok and BANK_LOCKED[reason]
  return name and _G[name] or nil
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

local function tabBags(mode)
  local bt = bankTypeFor(mode)
  if bt and C_Bank and C_Bank.FetchPurchasedBankTabIDs then
    local ok, ids = pcall(C_Bank.FetchPurchasedBankTabIDs, bt)
    if ok and type(ids) == "table" and #ids > 0 then return ids end
  end
  if mode == "warband" then return WARBAND end
  return BANK_MAIN
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

-- Deposit one bag slot into the active bank as a plain slot move, not a right-click "use". `alloc` is the
-- caller's per-transfer set of bank slots already claimed by moves still in flight (keyed bag*1000+slot),
-- so a burst of moves does not all target the same empty slot before any has landed. Returns the target
-- {tab, slot} when a move was issued (so the pump can watch that slot fill), false when it was skipped
-- (bank full, or the account bank refuses the piece). A full bank returning false ends the run rather than
-- looping: the pump marks a declined slot done and stops when nothing is left, so a category that does not
-- fit stops trying instead of hammering the same slots.
--
-- Why not UseContainerItem(bag, slot, nil, bt, false): that hands an equippable item to the "use" verb,
-- which EQUIPS it rather than banking it (and swaps the worn piece back into the bag), so a BoE piece was
-- worn instead of deposited and the grouped view saw the section change and drew no hole. A source-then-
-- empty-target PickupContainerItem is a pure relocation: it cannot equip, and it frees the source slot
-- cleanly so the hole is drawn.
local function bankDepositMove(bag, slot, alloc)
  local bt = ns.Bank.depositType
  if not bt then return false end
  local acct = Enum and Enum.BankType and Enum.BankType.Account
  -- The account bank refuses what is bound to the character; ask before sending rather than let the game
  -- bounce it back. The character bank takes anything, so it is not asked.
  if bt == acct and ItemLocation and C_Bank and C_Bank.IsItemAllowedInBankType then
    local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
    if loc and loc:IsValid() then
      local ok, allowed = pcall(C_Bank.IsItemAllowedInBankType, bt, loc)
      if ok and allowed == false then return false end
    end
  end
  local bags = tabBags((bt == acct) and "warband" or "bank")
  if not bags then return false end
  for _, tab in ipairs(bags) do
    local num = C_Container.GetContainerNumSlots(tab) or 0
    for s = 1, num do
      local key = tab * 1000 + s
      if not (alloc and alloc[key]) then
        local info = C_Container.GetContainerItemInfo(tab, s)
        -- Free and not mid-rewrite: an empty slot that is locked has a move already in flight into it (the
        -- server has not confirmed), and firing a second move at it locks it harder and drops one. Skip it
        -- and take the next free slot, the way the reference addon skips a locked target.
        if not (info and (info.hyperlink or info.itemID)) and not (info and info.isLocked) then
          C_Container.PickupContainerItem(bag, slot)
          C_Container.PickupContainerItem(tab, s)
          if CursorHasItem() then ClearCursor() end
          if alloc then alloc[key] = true end
          -- The target slot the piece is bound for, so the account-bank pacing waits for it to fill
          -- (the round-trip) instead of reading the source bag, which empties the instant it is lifted.
          return { tab, s }
        end
      end
    end
  end
  -- No free bank slot: leave the piece in the bag rather than firing a move that cannot land.
  return false
end
ns.BankDepositMove = bankDepositMove

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
function ns.IsBankContainer(id) return MEMBER[id] == true end

local function stepFor(size, gap) return size + gap end
local gridWidth = ns.GridWidth  -- shared with the bags (Theme.lua); alias keeps call sites unchanged

local View = {}
View.__index = View
ns.Bank = setmetatable({ state = {}, mode = "bank", query = "" }, View)

function View:State(mode)
  local st = self.state[mode]
  if not st then
    st = { mode = mode, pool = {}, vpool = {}, plan = {}, byKey = {}, dirty = {}, labels = {},
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

-- The crossed-out gaps say what a mode's slots held a moment ago, so they belong to one unbroken look at
-- one set of slots. Anything that changes which slots are on screen — a mode or tab pick, the plain grid,
-- a fresh open, a close — starts the grouped view over, or a piece that left while the other mode (or the
-- grid, or a shut window) was up reopens as a crosshair nothing will ever take. The bags drop theirs on
-- hide for exactly this reason.
function View:DropCatMemory()
  for _, st in pairs(self.state or {}) do st.catMemory = nil end
end

function View:Label(st, i, color)
  local l = st.labels[i]
  if not l then
    l = Theme:Label(st.content, 11, color or "faint")
    st.labels[i] = l
  end
  if self.fontPath then l:SetFont(self.fontPath, math.max(7, (self.fontBase or 13) - 2), ns.OutlineFlags()) end
  l:SetTextColor(Theme:C(color or "faint"))
  return l
end

-- The three grid numbers come from DEFAULTS like everything else the panel shows. The
-- literals are only there for the moment before Core.lua has loaded, and for a save that
-- somehow lost a key. They used to disagree with DEFAULTS, so the panel said 40 where the
-- grid read 36.
function View:CellSize()
  return (WarpeeDB and WarpeeDB.bankIconSize) or (ns.DEFAULTS and ns.DEFAULTS.bankIconSize) or 36
end

function View:Cols(mode)
  local d = ns.DEFAULTS
  local wb = (mode or self.mode) == "warband"
  local n = WarpeeDB and (wb and WarpeeDB.warbandCols or WarpeeDB.bankCols)
  return n or (d and (wb and d.warbandCols or d.bankCols)) or (wb and 26 or 28)
end
function View:FontSize() return FONT - 2 end
function View:HeaderH() return math.max(58, headerH(self:FontSize()) + 24) + Theme:TopInset() end
function View:FooterH() return footerH(self:FontSize()) end

function View:Sections(mode)
  -- The separate reagent section is gone with ns.reagentBank: it was drawn on the client
  -- that had no bank tabs, and no client that can load this addon is that one.
  if mode == "warband" then return { { ids = WARBAND } } end
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
    ns.SeamDrop(s)
  end)
  -- Drop an item on the bank body, not only on a slot: it is set down into the open bank tab of the
  -- current mode, and from there the grid takes the next free cell and the grouped view files it by
  -- category. Same "just put it here" a background drop means in the bags. Cells sit above and take
  -- their own drops first; this only fires on a release that missed them.
  f:SetScript("OnReceiveDrag", function() self:DropToBackground() end)
  f:HookScript("OnMouseUp", function() self:DropToBackground() end)
  Theme:Window(f, "WarpeeBankFrame")
  Theme:HeaderBand(f, HBAND)
  f:HookScript("OnMouseDown", function()
    local P = ns.CharPicker
    if P and P.frame and P.frame:IsShown() then ns.Theme:Raise(P.frame) end
  end)
  f:SetScript("OnHide", function()
    ns.ClearSearch(self.search)
    self.depositType = nil
    self:DropCatMemory()
    self:HideTabSettings()
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
  self.tabSel = {}
  if WarpeeDB and WarpeeDB.bankTabSel then
    self.tabSel.bank = WarpeeDB.bankTabSel.bank
    self.tabSel.warband = WarpeeDB.bankTabSel.warband
  end

  local close = ns.CreateGlyphButton(f, "×", HBTN, "icon")
  close:SetPoint("TOPRIGHT", -PAD, -ROW1_Y)
  close:SetScript("OnClick", function() f:Hide() end)
  self.closeBtn = close

  local gear = ns.CreateGlyphButton(f, "|TInterface\\Buttons\\UI-OptionsButton:13:13:0:0|t", HBTN, "icon")
  gear:SetPoint("TOPRIGHT", close, "TOPLEFT", -4, 0)
  gear:SetScript("OnClick", function() if ns.Options then ns.Options:Toggle() end end)
  addTip(gear, "Settings", nil, "top")
  self.gearBtn = gear

  local sort = ns.CreateGlyphButton(f, "", HBTN, "icon")
  sort:SetPoint("TOPRIGHT", gear, "TOPLEFT", -4, 0)
  sort:SetScript("OnClick", function() self:Sort() end)
  -- The game's own name for this action, keyed to Warpee's language so it follows the addon's language
  -- dropdown and not the game client's fixed locale (see the note on the bags' Clean Up button). The
  -- account bank and the personal bank have their own wording, picked by the mode on screen. A function,
  -- so a language switch is picked up on the next hover.
  addTip(sort, function()
    if self.mode == "warband" then return ns.L["Clean Up Warband Bank"] end
    return ns.L["Clean Up Bank"]
  end, nil, "top")
  local sortIcon = sort:CreateTexture(nil, "ARTWORK")
  sortIcon:SetAtlas("auctionhouse-ui-sortarrow")
  sortIcon:SetSize(13, 15)
  sortIcon:SetPoint("CENTER")
  sortIcon:SetVertexColor(Theme:C("overlay"))
  Theme:Track(sortIcon, function(x) x:SetVertexColor(Theme:C("overlay")) end)
  sort.icon = sortIcon
  sort.iconPct, sort.iconPctY = 50, 58
  sort.wpeIconPaint = function(s)
    if s.icon then s.icon:SetVertexColor(Theme:C("overlay")) end
  end
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
    -- In grouped mode a query decides which sections fold, and that is a re-Plan, not just a per-button
    -- dim. Debounced like the bags (Bags:ScheduleCatFold): a full re-Plan per keystroke re-buckets the
    -- whole bank and jumps the layout as prefixes match then drop, so it waits out a short quiet after
    -- the last key. The per-button dim above stays instant.
    if self:CatMode() then self:ScheduleCatFold() end
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
  Theme:Money(money)
  money:SetPoint("BOTTOMRIGHT", -PAD, 6)
  self.money = money
  ns.AttachGoldTooltip(money, f, function() return self:CellSize() end)

  local caption = Theme:Label(f, 10, "faint")
  caption:SetPoint("RIGHT", money, "LEFT", -6, 1)
  self.moneyCaption = caption

  local function moneyPopup(which, other)
    StaticPopup_Hide(other)
    if StaticPopup_Visible(which) then StaticPopup_Hide(which); return end
    StaticPopup_Show(which, nil, nil, { bankType = bankTypeFor(self.mode) })
  end

  local dep = ns.CreateButton(f, ns.L["Deposit"], 70, 20)
  ns.LocalText(dep, "Deposit")
  dep:SetPoint("BOTTOMLEFT", PAD, 5)
  dep:SetScript("OnClick", function() moneyPopup("BANK_MONEY_DEPOSIT", "BANK_MONEY_WITHDRAW") end)
  addTip(dep, "Put your gold into the Warband bank", nil, "top")
  self.depositBtn = dep

  local wdr = ns.CreateButton(f, ns.L["Withdraw"], 76, 20)
  ns.LocalText(wdr, "Withdraw")
  wdr:SetPoint("LEFT", dep, "RIGHT", 4, 0)
  wdr:SetScript("OnClick", function() moneyPopup("BANK_MONEY_WITHDRAW", "BANK_MONEY_DEPOSIT") end)
  addTip(wdr, "Take gold out of the Warband bank", nil, "top")
  self.withdrawBtn = wdr

  -- Deposit items: the game's own auto-deposit, which files the bags into the open bank by whatever tab
  -- rules are set. One button, not two: you are only ever on one tab (Bank or Warband), so the label
  -- follows the type. It rides the top-right header row, left of the gear, so the footer keeps gold and
  -- the running total to itself; FlowHeader places it and UpdateFooter sets its text, width and shown
  -- state. It runs C_Bank.AutoDepositItemsIntoBank on a real click; no protected slot is touched.
  local depIt = ns.CreateButton(f, "", 130, 20)
  depIt:SetScript("OnClick", function()
    local bt = bankTypeFor(self.mode)
    if bt and C_Bank and C_Bank.AutoDepositItemsIntoBank then
      pcall(C_Bank.AutoDepositItemsIntoBank, bt)
    end
  end)
  addTip(depIt, nil, function()
    return { { text = ns.L["Deposit your bags into this bank"], color = "dim" } }
  end, "top")
  depIt:Hide()
  self.depItemsBtn = depIt

  -- Include reagents: a single game CVar the auto-deposit reads, so the checkbox only mirrors it and the
  -- game does the work. It rides the header beside the deposit button; FlowHeader anchors both.
  local reagBox = ns.CreateCheckBox(f, 16)
  local reagHit = CreateFrame("Button", nil, f)
  reagHit:SetPoint("CENTER", reagBox, "CENTER", 0, 0)
  reagHit:SetSize(16, 20)
  reagHit:RegisterForClicks("LeftButtonUp")
  reagHit:SetScript("OnEnter", function() reagBox:SetKeys(nil, "accent", nil) end)
  reagHit:SetScript("OnLeave", function() reagBox:SetKeys(nil, "stroke", nil) end)
  reagHit:SetScript("OnClick", function()
    local on = not GetCVarBool("bankAutoDepositReagents")
    SetCVar("bankAutoDepositReagents", on)
    reagBox.mark:SetShown(on)
  end)
  local reagLabel = Theme:Label(f, 12, "dim")
  ns.LocalText(reagLabel, "Include reagents")
  reagBox:Hide(); reagHit:Hide(); reagLabel:Hide()
  self.reagBox, self.reagHit, self.reagLabel = reagBox, reagHit, reagLabel

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

  -- The game's own sentence for a bank the realm has switched off, over the empty grid.
  local lock = Theme:Label(f, 13, "text")
  lock:SetWidth(ns.SnapValue(f, 300))
  lock:SetJustifyH("CENTER")
  lock:Hide()
  self.lockHint = lock

  f:Hide()
  return f
end

function View:BuildCharPicker()
  if self.charBtn then return self.charBtn end
  local b = ns.CreateCharTag(self.frame, 22, "right")
  b:SetScript("OnClick", function(s)
    ns.CharPicker:Toggle(s, "right", function(k) self:SelectChar(k) end,
      ns.Vault:ViewKey("bank"), "bank", function() return self:CellSize() end)
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

function View:FlowHeader()
  if not self.frame then return end
  local row1 = ROW1_Y + Theme:TopInset() + Theme:HeadDrop()
  sizeGlyph(self.closeBtn, HBTN)
  sizeGlyph(self.gearBtn, HBTN)
  sizeGlyph(self.sortBtn, HBTN)
  -- The three glyphs sit at the right edge. Sort is only dropped when the bank has no live container, so
  -- the flow skips it there and the gear closes up to the X. Left of the glyphs comes the deposit button,
  -- and left of that the checkbox with its label to the checkbox's left, so the row
  -- reads "Include reagents [checkbox]  [Deposit ...]  glyphs" left to right. The tabs occupy the left
  -- of this same row, so each control is shown only while it still clears the tabs' right edge: the
  -- deposit button and the reagents check are tested on their own, so a narrow window drops whichever
  -- does not fit rather than both. UpdateFooter sets depWant/reagWant (the bank type wants them); the
  -- fit test here has the final say on shown state.
  local edge = ns.FlowRow(self.frame, -PAD, -row1, 4,
    { self.closeBtn, self.gearBtn, self.sortBtn })
  local bound = 0
  local tabEdge = self.wbTab and self.wbTab:IsShown() and self.wbTab:GetRight()
  if tabEdge then bound = tabEdge + 8 end
  local prev = edge
  if self.depItemsBtn then
    local anchorL = self.depWant and prev and prev:GetLeft()
    if anchorL and (anchorL - 8 - self.depItemsBtn:GetWidth()) >= bound then
      self.depItemsBtn:ClearAllPoints()
      ns.SnapPoint(self.depItemsBtn, "RIGHT", prev, "LEFT", -8, 0)
      self.depItemsBtn:Show()
      prev = self.depItemsBtn
    else
      self.depItemsBtn:Hide()
    end
  end
  if self.reagLabel then
    local anchorL = self.reagWant and prev and prev:GetLeft()
    local w = 16 + 4 + math.ceil(self.reagLabel:GetStringWidth())
    if anchorL and (anchorL - 8 - w) >= bound then
      self.reagBox:ClearAllPoints()
      ns.SnapPoint(self.reagBox, "RIGHT", prev, "LEFT", -8, 0)
      self.reagLabel:ClearAllPoints()
      ns.SnapPoint(self.reagLabel, "RIGHT", self.reagBox, "LEFT", -4, 0)
      self.reagBox:Show(); self.reagHit:Show(); self.reagLabel:Show()
      prev = self.reagLabel
    else
      self.reagBox:Hide(); self.reagHit:Hide(); self.reagLabel:Hide()
    end
  end
  self.headEdge = prev
end

function View:AnchorHeader()
  if not self.frame then return end
  local top = Theme:TopInset()
  local row1 = ROW1_Y + top + Theme:HeadDrop()
  self:FlowHeader()
  if self.bankTab then
    self.bankTab:ClearAllPoints()
    ns.SnapPoint(self.bankTab, "TOPLEFT", self.frame, "TOPLEFT", PAD, -row1)
  end
  Theme:HeaderBand(self.frame, HBAND)
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
          local poor = (tonumber(btn.cost) or 0) > GetMoney()
          return { { text = (ns.L["Cost: %s"]):format(ns.FormatMoney(btn.cost)),
                     color = poor and "gaugeHi" or "text" } }
        end, "top")
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

-- Only a live bank can be locked: a snapshot is browsable whatever the realm is doing with
-- the bank it was taken from.
function View:Locked()
  if not (self.bankerOpen and not self.snap) then return nil end
  return bankLockMessage(bankTypeFor(self.mode))
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

function View:LiveTabMeta(mode)
  local bt = bankTypeFor(mode)
  if not (bt and C_Bank and C_Bank.FetchPurchasedBankTabData) then return nil end
  local ok, data = pcall(C_Bank.FetchPurchasedBankTabData, bt)
  if not (ok and type(data) == "table") then return nil end
  local bags = tabBags(mode)
  local out = nil
  for i, td in ipairs(data) do
    local bag = bags[i]
    if bag ~= nil and type(td) == "table" and (td.name or td.icon) then
      out = out or {}
      out[bag] = { name = td.name, icon = td.icon, depositFlags = td.depositFlags }
    end
  end
  return out
end

function View:TabSel(mode)
  mode = mode or self.mode
  local sel = self.tabSel and self.tabSel[mode]
  if sel == nil then return nil end
  local known = false
  for _, sec in ipairs(self:Sections(mode)) do
    for _, bag in ipairs(sec.ids) do
      if bag == sel then known = true; break end
    end
    if known then break end
  end
  if not known then return nil end
  if self.snap then
    if ns.Vault:Count(mode, sel) <= 0 then return nil end
  elseif (C_Container.GetContainerNumSlots(sel) or 0) <= 0 then
    return nil
  end
  return sel
end

function View:SelectTab(bag)
  local mode = self.mode
  self.tabSel = self.tabSel or {}
  if self.tabSel[mode] == bag then return end
  self.tabSel[mode] = bag or nil
  if WarpeeDB then
    WarpeeDB.bankTabSel = WarpeeDB.bankTabSel or {}
    WarpeeDB.bankTabSel[mode] = bag or nil
  end
  self:HideTabSettings()
  -- A tab scopes the grouped view to its own bag, so the slots the gaps were standing for are not the ones
  -- on screen any more.
  self:DropCatMemory()
  if self.frame and self.frame:IsShown() then self:Layout() end
end

-- Bank tab plumbing. Read all of this before changing any of it.
--
-- The bank that a right click in a bag deposits into is BankFrame own tab type and nothing
-- else. The game reads BankFrame:GetActiveBankType() inside its own container click handler
-- and hands the answer straight to a protected call. So that type has to be set by the game
-- itself, off a real hardware press on the game own tab button. Set it from here and the
-- value carries our taint, the secure handler picks the taint up the moment it reads it, and
-- from then on every right click in every bag is refused, not only the ones aimed at a bank.
--
-- Never do any of these, here or anywhere else:
--   * write the bank panel type, or call BankFrame:SetTab, SelectDefaultTab, or any other
--     setter on that tab system. Every one of them lands in that same protected deposit.
--   * SetScript on BankFrame or on anything inside it. It taints the frame, and the taint
--     reaches the secure bank work: the tab purchase button stops answering, and item use
--     goes with it, since the game reads BankFrame on every bag right click. HookScript and
--     hooksecurefunc are fine, they add a handler and never replace one.
--   * reparent a tab button. Its OnClick reaches its tab system through GetParent, so a
--     button hung on one of our frames dies on a nil call inside the game own template.
--     Move the whole tab system instead and only anchor the button, since SetPoint may
--     cross the frame hierarchy freely while parenting may not.
--     PinBlizzTabs is the one call that writes SetParent on a tab button and it is not
--     this: it puts the button back on the tab system it came from, and the pool parents
--     every button there already, so the branch never fires. It exists for the client
--     that parents one somewhere else, and putting it back is the repair, not the fault.
--   * call BankFrame:Hide(). That fires BANKFRAME_CLOSED and ends the banker session.
--   * press a tab button for the user with Click(). A press we make is our own execution, so
--     the type it sets is just as tainted as if we had written it by hand.
--
-- Safe on frames the game owns, and the whole of what this code uses: SetParent, points,
-- SetAlpha, SetHitRectInsets, SetFrameStrata, SetFrameLevel, Show, EnableMouse, HookScript,
-- hooksecurefunc, and reading anything at all. Both entry points sit out combat lockdown:
-- frames the game owns can refuse a move in there, and none of this is worth finding that
-- out mid fight.

local BLIZZ_TAB = {}

-- Reading the type is always safe, and this is the only direction that runs from the game to
-- us. The open path needs it because the game selects its own first available tab every time
-- the bank opens, so a tab we remembered from last time would sit there claiming a bank that
-- a right click does not go to.
function View:BlizzMode()
  local F = BankFrame
  if not (F and F.GetActiveBankType) then return nil end
  local ok, bt = pcall(F.GetActiveBankType, F)
  if not (ok and bt) then return nil end
  local acct = Enum and Enum.BankType and Enum.BankType.Account
  return (acct and bt == acct) and "warband" or "bank"
end

-- Every line in here is load bearing, so keep the lot:
--   the tab system moves into our window because a button only takes mouse input while its
--     whole parent chain is shown, and BankFrame itself stays in the hidden holder so its
--     slot grid can never catch a click of ours;
--   alpha 0 is how the strip disappears without being hidden, since a hidden frame takes no
--     clicks at all;
--   the hit rect is zeroed because the game insets it to suit its own wide button, and those
--     insets ate most of a 52 pixel tab;
--   the strata is copied because frame level only orders frames within one strata, and our
--     windows sit in a higher strata than BankFrame does;
--   our own tab gives its mouse up whenever the game's button is pinned over it and can take
--     the click, and takes it back where that button is not shown, where no banker is open, or
--     where the click would only walk our own view (see the loop);
--   everything else in that strip loses its mouse, because it is invisible inside our window
--     and must not catch anything.
function View:PinBlizzTabs()
  if InCombatLockdown() then return end
  local TS = BankFrame and BankFrame.TabSystem
  local host = self.frame
  if not (TS and host) then return end
  local blizzMode = self.bankerOpen and self:BlizzMode() or nil
  if TS:GetParent() ~= host then TS:SetParent(host) end
  TS:Show()
  TS:SetAlpha(0)
  TS:EnableMouse(false)
  TS:SetFrameStrata(host:GetFrameStrata())
  TS:SetFrameLevel(host:GetFrameLevel() + 20)
  for _, c in ipairs({ TS:GetChildren() }) do
    if c.EnableMouse then c:EnableMouse(false) end
  end
  for mode, btn in pairs(BLIZZ_TAB) do
    local own = (mode == "bank") and self.bankTab or self.wbTab
    if own then
      -- A click that switches the bank belongs to the game: only its own tab may set the bank
      -- type the deposit follows, so the invisible game button takes that click and our view is
      -- walked over to match (Activate follows the same type from the other side). Two cases
      -- stay ours: the game's button is not shown when this realm cannot view that bank, and
      -- with no banker open the strip is dead and a click only moves our own snapshot. While
      -- another character's bank is on screen the same rule keeps one tab each, the game's
      -- button holding the bank our view is not on, ours holding the tab of the bank the panel
      -- already has, which is the way back to the live bank (SetMode on the mode already shown).
      local on = (self.bankerOpen and btn:IsShown() and own:IsShown()
                  and not (self.snap and mode == blizzMode)) and true or false
      if btn:GetParent() ~= TS then btn:SetParent(TS) end
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

-- Two independent paths walk our view over to the tab the game just picked, because a post
-- hook is lost whenever the call it follows errors before returning: the bank panel type
-- setter, which the game runs as the first line of its own SetTab, and the button own
-- OnClick. Either one alone is enough. The two flags are apart on purpose, since the bank
-- panel may not exist the first time through and one shared flag would burn that hook for
-- the session. The game lays its tab strip out again on its own, which is what tore the
-- button off our tab in an earlier attempt, so both calls that do it pin it back. Its OnEnter
-- opens a tooltip whenever it reads the label as truncated, which it is once the button is
-- squeezed onto our tab, so the hook closes it again.
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
        ns.SetBg(own, Theme:C("panelHi"))
        ns.SetEdge(own, Theme:C("accent"))
        own.Text:SetTextColor(Theme:C("accent"))
        if GameTooltip then GameTooltip:Hide() end
      end)
      btn:HookScript("OnLeave", function()
        ns.SetBg(own, Theme:C("panel"))
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
    ns.SetEdge(btn, Theme:C(on and "accent" or "stroke"))
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
  if mode == self.mode and self.cur then
    -- Clicking the tab of the mode already on screen is the way out of another
    -- character's snapshot: with the banker still open it asks for the live view
    -- back. Without a banker there is no live view, so the click stays a no-op.
    if self.snap and self.bankerOpen and ns.Vault:SetView("bank", nil) then
      self:UpdateCharBtn()
      if self:ApplySnap() then self:Activate(self.mode) else self:Repaint() end
    end
    return
  end
  self:HideTabSettings()
  self.mode = mode
  self:ApplySnap()
  self:UpdateTabs()
  self:Activate(mode)
end

local TAB_SIZE, TAB_GAP = 33, 4
local TAB_FALLBACK_ICON = [[Interface\Icons\INV_Misc_QuestionMark]]

-- Three states the eye has to tell apart at a glance: the selected tab, the one under the cursor, and
-- the rest. The selected one alone wears the accent edge and an accent underbar and shows its icon at
-- full strength; hover only lifts the plate and half-brightens the icon, so a tab being pointed at can
-- never be mistaken for the one that is open (the old paint gave hover the same accent edge as select,
-- which is what hid which tab the view was actually scoped to). Idle tabs sit dim so the open one stands
-- out of the row on its own, Everything included.
local function paintStripTab(b)
  local on, hot = b.wpeOn, b.wpeHot
  ns.SetBg(b, Theme:C((on or hot) and "panelHi" or "panel"))
  ns.SetEdge(b, Theme:C(on and "accent" or "stroke"))
  if b.wpeIcon then b.wpeIcon:SetAlpha(on and 1 or (hot and 0.85 or 0.5)) end
  if b.wpeUnder then b.wpeUnder:SetShown(on and true or false) end
end

function View:StripEntries(mode)
  local list = { { bag = nil } }
  for _, sec in ipairs(self:Sections(mode)) do
    for _, bag in ipairs(sec.ids) do
      local n
      if self.snap then n = ns.Vault:Count(mode, bag)
      else n = C_Container.GetContainerNumSlots(bag) or 0 end
      if n > 0 then list[#list + 1] = { bag = bag } end
    end
  end
  return list
end

-- The buy cell follows the last tab, or heads the strip when the character owns no tab at all:
-- that strip is hidden, and the game's own purchase prompt lives in the panel we keep in the
-- hidden holder, so this cell is the only way to a first bank tab.
function View:PlaceBuyCell(x)
  local buy = self.buyBtn and self.buyBtn[self.mode]
  if not buy then return end
  ns.SnapBox(buy, TAB_SIZE, TAB_SIZE)
  buy:ClearAllPoints()
  ns.SnapPoint(buy, "BOTTOMLEFT", self.frame, "TOPLEFT", x, 6)
  if buy.Text then
    buy.Text:SetFont(ns.Fonts:Current(), math.max(16, math.floor(TAB_SIZE * 0.74)), ns.OutlineFlags())
    buy.Text:SetText("+")
    if buy.Repaint then buy:Repaint() end
  end
  local cost = (self.bankerOpen and not self.snap) and purchasableCost(bankTypeFor(self.mode)) or nil
  buy:SetShown(cost ~= nil)
end

function View:RefreshStrip()
  local f = self.frame
  if not f then return end
  self.tabBtns = self.tabBtns or {}
  local entries = self:StripEntries(self.mode)
  local def = Theme.SkinDef and Theme:SkinDef()
  local x = 6 + (def and (tonumber(def.outX or def.out) or 0) or 0)
  if #entries < 2 then
    for _, b in ipairs(self.tabBtns) do b:Hide() end
    self:PlaceBuyCell(x)
    return
  end
  local meta = (not self.snap) and self:LiveTabMeta(self.mode) or nil
  local sel = self:TabSel(self.mode)
  for i, e in ipairs(entries) do
    local b = self.tabBtns[i]
    if not b then
      b = CreateFrame("Button", nil, f, "BackdropTemplate")
      ns.SnapBox(b, TAB_SIZE, TAB_SIZE)
      ns.PixelBackdrop(b)
      ns.SetBg(b, Theme:C("panel"))
      ns.SetEdge(b, Theme:C("stroke"))
      -- The accent bar that ties the open tab to the window it scopes, drawn under the plate's bottom
      -- edge. Shown for the selected tab alone (paintStripTab); it is the loudest of the three cues.
      local under = Theme:Rect(b, "accent", "OVERLAY")
      under:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 1, 3)
      under:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", -1, 3)
      ns.PixelLine(under, 2)
      under:Hide()
      b.wpeUnder = under
      Theme:Track(b, function(s) paintStripTab(s) end)
      b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      b:SetScript("OnEnter", function(s) s.wpeHot = true; paintStripTab(s) end)
      b:SetScript("OnLeave", function(s) s.wpeHot = nil; paintStripTab(s); GameTooltip:Hide() end)
      b:SetScript("OnClick", function(s, button)
        if button == "RightButton" then self:OpenTabSettings(s.wpeBag)
        else self:SelectTab(s.wpeBag) end
      end)
      ns.AddTip(b, function(s) return s.wpeTip end, "top", function()
        if self.bankerOpen and not self.snap then
          return { { text = ns.L["Right-click to edit"], color = "dim" } }
        end
      end)
      self.tabBtns[i] = b
    end
    local ic = b.wpeIcon
    if not ic then
      ic = b:CreateTexture(nil, "ARTWORK")
      ic:SetPoint("TOPLEFT", 3, -3)
      ic:SetPoint("BOTTOMRIGHT", -3, 3)
      ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      b.wpeIcon = ic
    end
    local m = e.bag ~= nil and ((meta and meta[e.bag]) or ns.Vault:TabMeta(self.mode, e.bag)) or nil
    if e.bag == nil then
      ic:SetTexture(nil)
      if ic.SetAtlas then ic:SetAtlas("bag-main") end
      b.wpeTip = ns.L["Everything"]
    else
      if m and m.icon then ic:SetTexture(m.icon) else ic:SetTexture(TAB_FALLBACK_ICON) end
      if m and m.name and m.name ~= "" then b.wpeTip = m.name
      else b.wpeTip = (ns.L["Tab %d"]):format(i - 1) end
    end
    b.wpeBag = e.bag
    b.wpeOn = (e.bag == sel) or nil
    paintStripTab(b)
    b:ClearAllPoints()
    ns.SnapPoint(b, "BOTTOMLEFT", f, "TOPLEFT", x + (i - 1) * (TAB_SIZE + TAB_GAP), 6)
    b:Show()
  end
  for j = #entries + 1, #self.tabBtns do self.tabBtns[j]:Hide() end
  self:PlaceBuyCell(x + #entries * (TAB_SIZE + TAB_GAP))
end

-- The tab editor is the game's own settings menu, the same popup the macro and guild bank
-- windows open, so the icon list and its search, the deposit settings and the write back
-- are all the game's, and none of it has to be kept in step with a patch from here.
--
-- Three things have to happen before it can be opened from our strip. It is a child of
-- BankPanel and BankFrame lives in the hidden holder, so nothing inside that panel is ever
-- drawn; it is parented out to UIParent for that, which costs nothing because the game
-- reads the panel off the BankPanel global rather than down the parent chain. It is given
-- its tab data, because the panel's own answer is a cache that comes back empty on the path
-- we open it by, see TabData below. And it is handed to the guild bank's popup skinner once,
-- so the two popups of one template cannot drift apart.
function View:TabSettings()
  local panel = BankFrame and BankFrame.BankPanel
  local pop = panel and panel.TabSettingsMenu
  if not (pop and pop.OnOpenTabSettingsRequested) then return nil end
  if not pop.wpeMoved then
    pop.wpeMoved = true
    pop:SetParent(UIParent)
    pop:SetFrameStrata("DIALOG")
    pop:SetClampedToScreen(true)
    pop.GetBankPanel = function()
      return { GetTabData = function(_, tabID) return self:TabData(tabID) end }
    end
    if ns.SkinIconPopup then pcall(ns.SkinIconPopup, pop) end
  end
  return pop
end

-- The menu asks the panel for the tab it was opened on and draws itself from the answer, and
-- the panel answers from a cache of purchased tabs. Opened straight from our strip that
-- answer comes back empty, and the menu sits on its blank defaults until a bank type switch
-- resets the panel underneath it. The live read is asked first instead; the panel's own
-- answer stays as the second source, for a bank type the live read refuses.
function View:TabData(tabID)
  local bt = bankTypeFor(self.mode)
  if bt and C_Bank and C_Bank.FetchPurchasedBankTabData then
    local ok, data = pcall(C_Bank.FetchPurchasedBankTabData, bt)
    if ok and type(data) == "table" then
      for _, td in ipairs(data) do
        if td.ID == tabID then return td end
      end
    end
  end
  local panel = BankFrame and BankFrame.BankPanel
  if panel and panel.GetTabData then return panel:GetTabData(tabID) end
  return nil
end

function View:HideTabSettings()
  local pop = self:TabSettings()
  if pop and pop:IsShown() then pop:Hide() end
end

function View:OpenTabSettings(bag)
  if bag == nil or not (self.bankerOpen and not self.snap) then return end
  if InCombatLockdown() then return end
  local pop = self:TabSettings()
  if not pop then return end
  -- The strip of bank tabs hangs off the window's right edge, and the menu opened at that
  -- edge sat on top of the icon the player had just right clicked. It opens past the top tab
  -- instead, and past the window itself when there is no strip to clear.
  local anchor
  for _, b in ipairs(self.tabBtns or {}) do
    if b:IsShown() then anchor = b end
  end
  pop:ClearAllPoints()
  if not (self.frame and self.frame:IsShown()) then
    pop:SetPoint("CENTER")
  elseif anchor then
    ns.SnapPoint(pop, "TOPLEFT", anchor, "TOPRIGHT", 8, 0)
  else
    ns.SnapPoint(pop, "TOPLEFT", self.frame, "TOPRIGHT", 8, 0)
  end
  -- The game's own path, so a second right click on the tab that is already open closes the
  -- popup instead of moving it. A right click on another tab while it is up retargets it:
  -- the menu only ever moves to what the game itself selects, and nothing here does that.
  if pop:IsShown() and pop.GetSelectedTabID and pop:GetSelectedTabID() ~= bag then
    pop:OnNewBankTabSelected(bag)
    return
  end
  pop:OnOpenTabSettingsRequested(bag)
end

function View:Activate(mode)
  if self.bankerOpen and not self.snap then
    local bm = self:BlizzMode()
    if bm and bm ~= mode then
      mode = bm
      self.mode = bm
      self:ApplySnap()
      self:UpdateTabs()
    end
  end
  local st = self:State(mode)
  local prev = self.cur
  if prev and prev ~= st then
    prev.filling = nil
    if prev.content then prev.content:Hide() end
  end
  self.cur = st
  self:DropCatMemory()
  self.depositType = self.bankerOpen and bankTypeFor(mode) or nil
  ns.RefreshBagDim()
  st.content:Show()
  self:Layout()
  self:PinBlizzTabs()
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
  -- The view is part of a cell's paint recipe, so it is part of this key and not only a flag the pass
  -- reads per cell: the ring reads the view (by item class versus by bag), and a switch moves every cell
  -- to a new plan index, so a cell that happens to keep its slot across the switch has nothing else to
  -- tell it the recipe changed. Without it here the switch decided repaint was false and trusted the
  -- per-cell flag alone, which only covers the cells the drip reaches and only for the one thing that
  -- flag names. In the key, the switch rebuilds every cell once, whatever else the view moved.
  return table.concat({ size, Bags.slotStyle or "tile", Bags.styleGen or 0,
                        Bags.qualityBorder and 1 or 0, Bags.qualityColorIlvl and 1 or 0,
                        ns.Badge("junk").on and 1 or 0, Bags.reagentTint and 1 or 0,
                        Bags.unusableBorder and 1 or 0, self:CatMode() and "cat" or "grid",
                        (self.tabSel and self.tabSel[self.mode]) or 0 }, ":")
end

-- Grouped mode is on whenever the player set it, tab pick or not. A tab and a category grouping
-- narrow the same slots on different axes, so they compose: picking a tab scopes the categories to
-- that one tab's slots (see CatBags) rather than switching the whole window back to a flat grid. The
-- per-tab and everything views share one category container and differ only in which slots feed it.
function View:CatMode()
  return WarpeeDB and WarpeeDB.bankView == "cat"
end

-- The bags the category bucketer walks: the whole mode normally, or just the selected tab's bag when
-- one is picked, so the grouping covers exactly the slots on screen. Mirrors the plain grid's
-- `only = TabSel` scoping, kept 1:1 with it so a tab shows the same slots either way.
function View:CatBags(mode)
  local only = self:TabSel(mode)
  if only then return { only } end
  return self:ModeBags(mode)
end

-- The containers of the current mode, flattened from Sections, for the category bucketer to walk.
function View:ModeBags(mode)
  local out = {}
  for _, sec in ipairs(self:Sections(mode)) do
    for _, bag in ipairs(sec.ids) do out[#out + 1] = bag end
  end
  return out
end

-- Set the held item down when a drop lands on the bank body instead of a cell. Where it goes depends
-- on where the piece came from: one already in this mode's own containers (a missed cell) goes back to
-- its slot on ClearCursor, untouched; anything from elsewhere — the character's bags, a worn slot, the
-- other bank mode — is deposited into the first container of the current mode with room, through the
-- same PutItemInBag the game's bank-slot buttons use. So dragging from bags onto the bank body stores
-- it, and dragging from the bank onto its own body just puts it back. Never on a snapshot: another
-- character's bank has no live container to place into, so the piece is left on the cursor. Reads the
-- cursor and places through unprotected calls only, driven by the player's release, so it stays taint
-- free.
function View:DropToBackground()
  if self.snap or not CursorHasItem() then return end
  local ctype = GetCursorInfo()
  if ctype ~= "item" then return end
  if not self:CursorInMode() then
    for _, bag in ipairs(self:ModeBags(self.mode)) do
      if not CursorHasItem() then break end
      if (select(1, C_Container.GetContainerNumFreeSlots(bag)) or 0) > 0 then
        local inv = C_Container.ContainerIDToInventoryID(bag)
        if inv then PutItemInBag(inv) end
      end
    end
  end
  ClearCursor()
  self:Layout()
  if ns.Options and ns.Options.RefreshOpen then ns.Options:RefreshOpen() end
end

-- Does the piece on the cursor already live in one of this mode's containers? Then a body drop is only
-- a missed cell and it goes back to its own slot on ClearCursor rather than being deposited afresh.
function View:CursorInMode()
  if not (C_Cursor and C_Cursor.GetCursorItem) then return false end
  local loc = C_Cursor.GetCursorItem()
  if not (loc and loc.IsBagAndSlot and loc:IsBagAndSlot()) then return false end
  local bag = loc:GetBagAndSlot()
  for _, b in ipairs(self:ModeBags(self.mode)) do if b == bag then return true end end
  return false
end

-- Category grouping for the bank: the same buckets the bags draw, laid as captioned sections that
-- stack down the window. It reuses the plan array and the pooled labels exactly like the tab layout,
-- so Run/Resize downstream are unchanged; only the geometry and the captions differ. Cells carry the
-- real bag and slot, so paint, search and the secure click are untouched. Returns the same tuple Plan
-- does. Only a group band folds, and a search draws its hits alone.
function View:PlanCats(st, size, cols, gap)
  local step = stepFor(size, gap)
  local plan = st.plan
  -- While the banker is open and live, hand the bucketer last pass's slot memory so a deposit (into the
  -- bank) or a withdrawal (out of it) holds the emptied cell as an inert hole instead of reflowing the
  -- grouped view under the cursor, and a returning piece drops back into its own hole. A search compacts,
  -- and a snapshot has no live container, so neither holds. Recaptured from this pass's buckets below.
  local hold = (not self.snap) and self.bankerOpen and (self.query or "") == "" and ns.SplitWindowOpen()
  local buckets, used, total = ns.Categories:BankBuckets(st.mode, self.snap, self.filters,
    self:CatBags(st.mode), hold and (st.catMemory or ns.Categories.EMPTY_MEMORY) or nil)
  if hold then
    -- The holes this pass drew are kept in the memory, or the piece coming back would have nothing to
    -- land in, and the held cell would compact the moment the next pass saw it unclaimed.
    st.catMemory = ns.Categories:CaptureMemory(buckets, true)
  else
    st.catMemory = nil
  end
  local searching = (self.query or "") ~= ""
  local gridW = gridWidth(size, cols, gap)
  local capH = DIV
  -- The group caption sits at labelX with its caret to the left. A section caption sits at capX,
  -- flush with the left edge of its own first cell, so the name heads the items directly beneath it
  -- rather than floating off to their right. Mirrors the bags: the per-section caret is gone and
  -- nothing else stands before the name, so the caption starts exactly on that edge, with no pad the
  -- eye would take for a glyph that is not there.
  local labelX = 14
  local capX = 0
  -- The drop below a group caption before its sections start, so the band header is not crammed
  -- against the first row of names.
  local GHEAD_GAP = 6
  -- Shelves like the bags: each section is only as wide as its cells need (capped at the full bank
  -- width, floored at its own caption), so several sit side by side on one row and the empty space to
  -- the right is used instead of one tall column down the middle. GUTX is the gap between neighbours on
  -- a shelf, GUTY the drop between shelf rows. Each follows its own Category spacing slider
  -- (WarpeeDB.catGapX / catGapY) like the bags' grouped view does, so the one pair moves both surfaces;
  -- the density DIV is the fallback until a slider is touched.
  local GUTX = math.max(0, math.floor(tonumber(WarpeeDB and WarpeeDB.catGapX) or DIV))
  local GUTY = math.max(0, math.floor(tonumber(WarpeeDB and WarpeeDB.catGapY) or DIV))
  local shelfX, shelfY, shelfH = 0, 0, 0
  local n, li, holes = 0, 0, 0
  -- Empty is the free-space stand-in. The bank has no reagent bag, so one sample tile: the free count.
  local free = math.max(0, (total or 0) - (used or 0))
  local shownEmpty = false
  local nb = #buckets
  -- Bands: a run of sections that share the marker heading them. The marker is the entry in the saved
  -- list the whole layout walks — a group header, a divider, or nothing at all for the run before the
  -- first marker — so a band is where it is because the list says so, and the bank and the bags read the
  -- same list. No group table, and no ungrouped special case: the tail is a run under a divider.
  local bands = {}
  for bi = 1, nb do
    local b = buckets[bi]
    local band = bands[#bands]
    if not band or band.key ~= b.band then
      band = { key = b.band, from = bi, to = bi }
      bands[#bands + 1] = band
    end
    band.to = bi
  end
  -- Whether a band shows its sections. A live search answers instead of the fold: the query is the
  -- filter, so a band with a hit draws open and one with nothing to show keeps only its heading. With no
  -- search the fold saved on the band's own marker decides, and the run before the first marker is always
  -- open — it has no heading to click.
  local function bandOpen(band)
    if searching then
      for bi = band.from, band.to do
        if (buckets[bi].hits or 0) > 0 then return true end
      end
      return false
    end
    return not (band.key and ns.Categories:Folded(band.key))
  end
  local gi = 0
  for bk = 1, #bands do
    local band = bands[bk]
    local open = bandOpen(band)
    if bk > 1 then
      shelfY = shelfY + shelfH + GUTY
      shelfX, shelfH = 0, 0
    end
    -- The heading of the band. A group header draws its name with the caret beside it, and that heading
    -- is the fold handle — the only way back into a folded band. A divider seams a band off without
    -- naming it, so there is nothing there to open or close: no caret, no click target, its line is the
    -- whole of the heading and the band starts right below it.
    if band.key then
      gi = gi + 1
      local gcapH = math.max(capH, self:FontSize() + 5)
      local top = shelfY
      local textY = shelfY
      local isHead = ns.Categories.IsHead(band.key)
      local line = self:CatGLine(st, gi)
      -- SnapPoint so the 1px divider lands on the pixel grid: top is a float sum of shelf heights, and a
      -- raw SetPoint at it drew the hairline blurred (the bags already Snap theirs). Placed whether or
      -- not it is shown, so each heading in the pool carries one set of points. A divider always draws
      -- its line, since the line is the whole of its heading; only the first group heading skips it,
      -- having nothing above it to seam itself off from.
      line:ClearAllPoints()
      ns.SnapPoint(line, "TOPLEFT", st.content, "TOPLEFT", 0, -top)
      ns.SnapPoint(line, "TOPRIGHT", st.content, "TOPRIGHT", 0, -top)
      local seamed = (bk > 1) or (not isHead)
      line:SetShown(seamed)
      if seamed then textY = top + 1 + DIV / 4 end
      local glabel = self:CatGLabel(st, gi)
      local gcaret = self:CatGCaret(st, gi)
      -- No tally on a heading: each section under it prints its own (N), so a count of sections beside
      -- the name only repeated what the eye reads down the band. Hidden, matching the bags.
      self:CatGCount(st, gi):Hide()
      local headH
      if isHead then
        fitBankLabel(glabel, ns.Categories:GroupName(band.key), gridW - labelX)
        glabel:ClearAllPoints()
        ns.SnapPoint(glabel, "TOPLEFT", st.content, "TOPLEFT", labelX, -textY)
        glabel:Show()
        gcaret:ClearAllPoints()
        ns.SnapPoint(gcaret, "RIGHT", glabel, "LEFT", -4, 0)
        gcaret:SetDir(open and "down" or "right")
        gcaret:SetTint("dim")
        gcaret:Show()
        shelfY = textY + gcapH + GHEAD_GAP
        headH = (textY - top) + gcapH
      else
        glabel:Hide()
        gcaret:Hide()
        shelfY = textY + DIV / 4
        headH = math.max(9, textY - top)
      end
      local ghead = self:CatGHead(st, gi)
      ghead.wpeEntry, ghead.wpeCaret, ghead.wpeLabel = band.key, gcaret, glabel
      ghead:ClearAllPoints()
      ns.SnapPoint(ghead, "TOPLEFT", st.content, "TOPLEFT", 0, -top)
      ghead:SetSize(math.max(1, gridW), headH)
      ghead:SetShown(isHead)
    end
    -- A folded band keeps its heading but draws no sections: an empty range is the same thing as
    -- skipping the loop, without a second nesting level to keep aligned.
    if not open then band.from, band.to = 0, -1 end
  for bi = band.from, band.to do
    local b = buckets[bi]
    local isEmpty = b.empty
    local count = isEmpty and 1 or #b.slots
    if count > 0 then
      local folded = searching and (isEmpty or (b.hits or 0) == 0)
      li = li + 1
      local label = self:Label(st, li, "accent")
      label:SetJustifyH("LEFT")
      local count2 = self:CatCount(st, li)
      -- The parenthesised tally beside the name, dim so it reads as a count not an ilvl. Empty drops it
      -- (its free number is on the tile below); shown only from three items up on a named section.
      local showCount = (not isEmpty) and count >= 3
      local countW = 0
      if showCount then
        count2:SetText("(" .. count .. ")")
        countW = count2:GetStringWidth()
      else
        count2:Hide()
      end
      -- Width from the cell count, but never so narrow the name is crushed to an initial. The floor is
      -- the whole caption (indent, name up to a cap, gap, count), so a one-item section still reads its
      -- name instead of a lone glyph; past the cap the name truncates. Mirrors the bags.
      label:SetText(ns.Upper(b.name or ""))
      local fullNameW = label:GetStringWidth()
      local nameCap = math.min(gridW, 6 * step)
      local floorNeed = capX + math.min(fullNameW, nameCap) + 6 + countW
      local capCols = math.max(1, math.ceil((floorNeed - size) / step) + 1)
      local w = math.max(math.min(count, cols), capCols)
      if w > cols then w = cols end
      local sw = gridWidth(size, w, gap)
      fitBankLabel(label, b.name, sw - capX - 6 - countW)
      if shelfX > 0 and shelfX + GUTX + sw > gridW + 0.5 then
        shelfY = shelfY + shelfH + GUTY
        shelfX, shelfH = 0, 0
      end
      local sx = (shelfX == 0) and 0 or (shelfX + GUTX)
      local sy = shelfY
      label:ClearAllPoints()
      -- SnapPoint like the bags: sy is a float shelf offset, so a raw SetPoint drew the caption a
      -- fraction off the pixel grid and it read fuzzy against the crisp cells. The count rides the
      -- label, so snapping the label carries it too.
      ns.SnapPoint(label, "TOPLEFT", st.content, "TOPLEFT", sx + capX, -(sy + 4))
      label:Show()
      if showCount then
        count2:ClearAllPoints()
        ns.SnapPoint(count2, "LEFT", label, "RIGHT", 6, 0)
        count2:Show()
      end
      -- The caption's right-click transfer handle: a drawn section (not Empty, not a search-folded one)
      -- carries its own slots so a right click withdraws the lot to the bags. Sized to the caption row.
      if not isEmpty and not folded then
        local hit = self:CatHit(st, li)
        hit.wpeSlots = b.slots
        hit:ClearAllPoints()
        ns.SnapPoint(hit, "TOPLEFT", st.content, "TOPLEFT", sx, -sy)
        hit:SetSize(math.max(1, sw), capH)
        hit:Show()
      elseif st.catHits and st.catHits[li] then
        st.catHits[li]:Hide()
      end
      local secH
      if folded then
        secH = capH
      elseif isEmpty then
        -- One sample free-slot tile under the caption, bound to nothing (no bag/slot), so it carries no
        -- taint and just shows the number. Pooled on st like the slot cells.
        local tile = self:EmptyTile(st, 1)
        ns.SnapSize(tile, size, size)
        tile.count:SetText(tostring(free))
        tile:ClearAllPoints()
        ns.SnapPoint(tile, "TOPLEFT", st.content, "TOPLEFT", sx, -(sy + capH))
        tile:Show()
        shownEmpty = true
        secH = capH + size
      else
        local cellsTop = sy + capH
        for k = 1, count do
          local s = b.slots[k]
          local col, row = (k - 1) % w, math.floor((k - 1) / w)
          local cx, cy = sx + col * step, -(cellsTop + row * step)
          if s.dummy then
            -- Held hole: an item just left this spot while the banker is open. Draw the inert crosshair
            -- instead of a cell (nothing to bind, nothing to click) so the grouped view does not reflow
            -- under the cursor mid-transfer. Placed here rather than in the plan: it paints no item, so
            -- it needs none of the pooled cell machinery.
            holes = holes + 1
            local t = self:CatHole(st, holes)
            ns.SnapSize(t, size, size)
            t:ClearAllPoints()
            ns.SnapPoint(t, "TOPLEFT", st.content, "TOPLEFT", cx, cy)
            t:Show()
          else
            n = n + 1
            local c = plan[n] or {}
            c.bag, c.slot = s.bag, s.slot
            -- Combine-stacks: the cell binds its own slot but draws the folded sum. nil for a single.
            c.force = (s.count and s.count > 1) and s.count or nil
            c.x, c.y = cx, cy
            plan[n] = c
          end
        end
        local rows = math.max(1, math.ceil(count / w))
        secH = capH + (rows - 1) * step + size
      end
      -- The section's own drop target, sized to its drawn extent (caption through last cell row, the gap
      -- between sections left out). Positioned every pass but kept hidden; the cursor watcher shows it
      -- while a piece rides the cursor. A release sets the piece down the way the bank body does, and with
      -- drag-to-pin armed also pins it to this section, so the box carries the section id and its name.
      -- Empty owns no items, so it is not a pin target (wpeId nil) and a drop there is a plain stow; a
      -- section the search folded away keeps no target either.
      local zone = self:CatZone(st, li)
      zone.wpeActive = not folded
      zone.wpeId = (not folded) and (not isEmpty) and b.id or nil
      if zone.hint then zone.hint:SetText(ns.Upper(b.name or "")) end
      zone:ClearAllPoints()
      ns.SnapPoint(zone, "TOPLEFT", st.content, "TOPLEFT", sx, -sy)
      zone:SetSize(math.max(1, sw), math.max(capH, secH))
      zone:Hide()
      shelfX = sx + sw
      shelfH = math.max(shelfH, secH)
    end
  end
  end
  local bottom = shelfY + shelfH
  for j = li + 1, #st.labels do st.labels[j]:Hide() end
  self:HideCatCounts(st, li)
  self:HideCatHits(st, li)
  self:HideCatZones(st, li)
  self:HideCatGroups(st, gi)
  self:HideCatHoles(st, holes)
  if not shownEmpty then self:HideEmptyTiles(st, 0) end
  st.blank = nil
  st.locked = self:Locked()
  st.planCount = n
  if st.locked then
    return self:PlanLocked(st, size, cols, step)
  end
  return n, bottom, used, total
end

-- A band carries no bag and no slot, so it is display only and adds no taint surface.
function View:CatGLine(st, i)
  st.gLines = st.gLines or {}
  local t = st.gLines[i]
  if not t then
    t = Theme:Rect(st.content, "strokeSoft", "ARTWORK")
    ns.PixelLine(t, 1)
    st.gLines[i] = t
  end
  return t
end

function View:CatGLabel(st, i)
  st.gLabels = st.gLabels or {}
  local fs = st.gLabels[i]
  if not fs then
    fs = Theme:Label(st.content, 11, "azure")
    fs:SetJustifyH("LEFT")
    st.gLabels[i] = fs
  end
  if self.fontPath then fs:SetFont(self.fontPath, math.max(8, (self.fontBase or 13) - 1), ns.OutlineFlags()) end
  fs:SetTextColor(Theme:C("azure"))
  return fs
end

function View:CatGCaret(st, i)
  st.gCarets = st.gCarets or {}
  local t = st.gCarets[i]
  if not t then
    t = ns.Triangle(st.content, "down", 9, 9, "dim")
    st.gCarets[i] = t
  end
  return t
end

function View:CatGCount(st, i)
  st.gCounts = st.gCounts or {}
  local fs = st.gCounts[i]
  if not fs then
    fs = Theme:Label(st.content, 11, "dim")
    fs:SetJustifyH("LEFT")
    st.gCounts[i] = fs
  end
  if self.fontPath then fs:SetFont(self.fontPath, math.max(7, (self.fontBase or 13) - 2), ns.OutlineFlags()) end
  fs:SetTextColor(Theme:C("dim"))
  return fs
end

function View:HideCatGroups(st, from)
  if not st then return end
  local pools = { st.gLines, st.gLabels, st.gCarets, st.gCounts, st.gHeads }
  for _, pool in ipairs(pools) do
    if pool then
      for i = (from or 0) + 1, #pool do if pool[i] then pool[i]:Hide() end end
    end
  end
end

function View:CatCount(st, i)
  st.catCounts = st.catCounts or {}
  local fs = st.catCounts[i]
  if not fs then
    fs = Theme:Label(st.content, 11, "dim")
    fs:SetJustifyH("LEFT")
    st.catCounts[i] = fs
  end
  if self.fontPath then fs:SetFont(self.fontPath, math.max(7, (self.fontBase or 13) - 2), ns.OutlineFlags()) end
  fs:SetTextColor(Theme:C("dim"))
  return fs
end

function View:HideCatCounts(st, from)
  if not (st and st.catCounts) then return end
  for i = (from or 0) + 1, #st.catCounts do
    if st.catCounts[i] then st.catCounts[i]:Hide() end
  end
end

-- A transparent click target over a section caption, so a right click on the name withdraws the whole
-- section to the bags while the banker is open. Pooled by section index like the labels. A left click or
-- a drop here behaves like a drop on the bank body (DropToBackground): the caption is not a special drop
-- target, only a right-click transfer handle.
function View:CatHit(st, i)
  st.catHits = st.catHits or {}
  local b = st.catHits[i]
  if not b then
    b = CreateFrame("Button", nil, st.content)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local function drop() self:DropToBackground() end
    b:SetScript("OnReceiveDrag", drop)
    b:SetScript("OnClick", function(s, button)
      if button == "RightButton" then self:TransferSection(s.wpeSlots) else drop() end
    end)
    -- The hint rides the caption while the banker is live: on a snapshot the click does nothing, so no
    -- tip is shown rather than promising a move that will not happen. It is one line on the addon's own
    -- tip, the same face the rest of the window hints in, rather than the game's tooltip built for item
    -- links, which drew a single sentence the size of a paragraph.
    ns.AddTip(b, nil, "top", function(s)
      if not (self.bankerOpen and not self.snap and s.wpeSlots and s.wpeSlots[1]) then return nil end
      return { { text = "Right click to move this category to your bags", color = "dim" } }
    end)
    st.catHits[i] = b
  end
  return b
end

function View:HideCatHits(st, from)
  if not (st and st.catHits) then return end
  for i = (from or 0) + 1, #st.catHits do
    if st.catHits[i] then st.catHits[i]:Hide() end
  end
end

-- The live cell under the cursor, if any. The plan carries the real bag and slot of every drawn cell and
-- the pool answers with the button, so a drop can be handed to the cell's own behaviour (the game's item
-- button merges a stack or swaps two pieces) instead of the section's plain stow. A snapshot draws other
-- people's items and has no live container, so it never answers.
function View:CellUnderCursor()
  local st = self.cur
  if self.snap or not (st and st.plan) then return nil end
  local cx, cy = GetCursorPosition()
  if not cx then return nil end
  for i = 1, (st.planCount or 0) do
    local c = st.plan[i]
    local b = st.pool[i]
    local h = b and b.holder
    if c and c.bag and h and h:IsShown() then
      local s = h:GetEffectiveScale()
      local l, r, t, btm = h:GetLeft(), h:GetRight(), h:GetTop(), h:GetBottom()
      if s and s > 0 and l then
        local px, py = cx / s, cy / s
        if px >= l and px <= r and py >= btm and py <= t then return c.bag, c.slot, b end
      end
    end
  end
  return nil
end

-- The section drop box the cursor is over, if any. The plan cannot answer this one (the boxes are pooled
-- apart from the cells), so the cursor is tested against each box's own rectangle in its own scale, the way
-- CellUnderCursor reads the cells. Only a box that owns a section answers: the Empty section's is a catcher
-- for a plain stow with no category to pin to, and a folded-away section keeps none, so neither can wash.
function View:ZoneUnderCursor()
  local st = self.cur
  if not (st and st.catZones) then return nil end
  local cx, cy = GetCursorPosition()
  if not cx then return nil end
  for _, z in ipairs(st.catZones) do
    if z.wpeId and z:IsShown() then
      local s = z:GetEffectiveScale()
      local l, r, t, b = z:GetLeft(), z:GetRight(), z:GetTop(), z:GetBottom()
      if s and s > 0 and l then
        local px, py = cx / s, cy / s
        if px >= l and px <= r and py >= b and py <= t then return z end
      end
    end
  end
  return nil
end

-- What the drop under the cursor would do, drawn while a piece rides it. The section boxes cover the cells
-- for the whole drag and take their mouseover with them, so both readings are worked out here by hand from
-- the cursor's own position, on the tick the watcher below runs: the cell a plain drop would be forwarded to
-- (grouped view, piece held, pinning not armed, live bank) lights up as "into this cell", and with pinning
-- armed the section under the cursor washes with its name as "into this category". Read per tick rather than
-- on the box's mouseover alone, because everything the answer depends on can change while the cursor stands
-- still: the modifier is pressed or let go, a pass at the tail of a layout lays the sections out under the
-- piece, or the drag starts with the cursor already over a section. One cell and one section at a time, and
-- over a gap nothing lights.
function View:TrackDropHighlight()
  local shown = (self:CatMode() and self.frame and self.frame:IsShown() and CursorHasItem()) and true or false
  -- A peek at another character's bank takes no drop at all (DropToBackground refuses it), so it is never
  -- promised one: same rule the caption's hint follows above.
  local armed = shown and not self.snap and ns.Categories.PinDragActive() and true or false
  local hit
  if shown and not armed and not self.snap then hit = select(3, self:CellUnderCursor()) end
  if self.hlCell and self.hlCell ~= hit then
    ns.SetSlotHighlight(self.hlCell, false)
    self.hlCell = nil
  end
  if hit and self.hlCell ~= hit then
    ns.SetSlotHighlight(hit, true)
    self.hlCell = hit
  end
  local zone
  if armed then zone = self:ZoneUnderCursor() end
  if self.hlZone and self.hlZone ~= zone then self.hlZone.wpeLit(false); self.hlZone = nil end
  if zone and self.hlZone ~= zone then zone.wpeLit(true); self.hlZone = zone end
end

-- Set the held piece down on a section of the grouped view. Where it goes is the bank body's own drop
-- (DropToBackground: a piece from the bags is deposited into this mode, one of this mode's own goes back
-- to its slot), with one exception: a release over a live cell with no pin armed is forwarded to that
-- exact slot, so the game merges a stack or swaps two pieces the way its own grid does — the section box
-- would otherwise eat the drop. With drag-to-pin armed the piece is pinned to this section after the
-- stow, since PinItem writes the category membership and moves nothing. Reads the cursor and places
-- through unprotected calls only, driven by the player's own release, so it stays taint free.
function View:DropToCategory(targetId)
  if self.snap or not CursorHasItem() then return end
  local ctype, cid = GetCursorInfo()
  if ctype ~= "item" then return end
  local pin = targetId and ns.Categories.PinDragActive() and cid or nil
  if not pin then
    local bag, slot = self:CellUnderCursor()
    if bag then
      C_Container.PickupContainerItem(bag, slot)
      ClearCursor()
      self:Layout()
      if ns.Options and ns.Options.RefreshOpen then ns.Options:RefreshOpen() end
      return
    end
  end
  self:DropToBackground()
  -- Pin after the stow: the piece lives here now (or already did), and PinItem only records where it
  -- belongs. A drop on the very section the rules already file it under unfiles inside PinItem.
  if pin then
    ns.Categories:PinItem(pin, targetId)
    -- The pin is the last thing this drop changes, and the only thing it changes is the filing: it touches
    -- no container and no slot. The layout inside the stow above has therefore already run, and it ran on
    -- the filing from before this line, so that pass drew the piece under its former caption — and no bag
    -- event follows a pin to ask for another one. Ask for the pass here, behind the pin, so the piece moves
    -- to the section it was dropped on the moment it is let go, instead of waiting for the next pass that
    -- some other action happens to trigger.
    self:QueueRefresh()
  end
end

-- A section's own drop target in the grouped view: a box over its drawn extent (caption through last cell
-- row), hidden until a piece rides the cursor, so with nothing held a click reaches the cell beneath. While
-- pinning is armed it also lights the hovered section with a faint accent wash and shows its name, so the
-- release reads as "into this category" rather than as a plain stow. Pooled by section index like the
-- captions and the empty tiles. Carries no bag and no slot, so it adds no taint surface.
function View:CatZone(st, i)
  st.catZones = st.catZones or {}
  local z = st.catZones[i]
  if not z then
    z = CreateFrame("Button", nil, st.content, "BackdropTemplate")
    z:SetFrameLevel(st.content:GetFrameLevel() + 60)
    z:RegisterForClicks("LeftButtonUp")
    ns.PixelBackdrop(z)
    ns.SetBg(z, 0, 0, 0, 0)
    ns.SetEdge(z, 0, 0, 0, 0)
    local hint = Theme:Label(z, self:FontSize(), "accent")
    hint:SetPoint("CENTER")
    hint:SetJustifyH("CENTER")
    hint:Hide()
    z.hint = hint
    local function lit(on)
      if on then
        local r, g, b = Theme:C("accent")
        ns.SetBg(z, r, g, b, 0.14)
      else
        ns.SetBg(z, 0, 0, 0, 0)
      end
      z.hint:SetShown(on and true or false)
    end
    -- The wash is painted from outside, by the tick that reads the drop point: see TrackDropHighlight.
    z.wpeLit = lit
    local function drop() lit(false); self:DropToCategory(z.wpeId) end
    z:SetScript("OnReceiveDrag", drop)
    z:SetScript("OnClick", drop)
    st.catZones[i] = z
  end
  return z
end

function View:HideCatZones(st, from)
  if not (st and st.catZones) then return end
  for i = (from or 0) + 1, #st.catZones do
    local z = st.catZones[i]
    if z then z.wpeActive = false; z:Hide() end
  end
end

-- One watcher flips the section targets the moment the cursor picks a piece up or sets it down, so the
-- drag costs nothing per frame beyond the highlight below. Declared before SyncCatZones so that function
-- can reach it as an upvalue.
local bankDropWatch = CreateFrame("Frame")

-- Flip every section target of the current view at once: on while a piece rides the cursor in the grouped
-- view, off the rest of the time so the cells click through as normal. Called on each cursor change and at
-- the tail of a layout, in case the window opened with a piece already on the cursor.
function View:SyncCatZones()
  local st = self.cur
  if not (st and st.catZones) then return end
  local on = self:CatMode() and self.frame and self.frame:IsShown() and CursorHasItem()
  for _, z in ipairs(st.catZones) do
    if on and z.wpeActive then
      -- Start each drag unlit: the wash and the name appear only once the cursor enters a section with
      -- pinning armed, so a box shown by a fresh pickup does not carry the last drag's tint. This runs on
      -- every cursor change and at the tail of every pass, and a pass is what a pickup asks for, so the
      -- wash painted the moment the piece was lifted used to be wiped here a tenth of a second later and
      -- stay off until the cursor crossed a section edge again. The tracked section is let go with the
      -- wash, and the tick below puts both back where the cursor really is.
      ns.SetBg(z, 0, 0, 0, 0)
      if z.hint then z.hint:Hide() end
      z:Show()
    else
      z:Hide()
    end
  end
  if on then self.hlZone = nil end
  bankDropWatch.tracking = on and true or false
  self:TrackDropHighlight()
end

bankDropWatch:RegisterEvent("CURSOR_CHANGED")
bankDropWatch:SetScript("OnEvent", function()
  local b = ns.Bank
  local held = CursorHasItem()
  -- A piece picked up or set down is the player's own move, and the drop is its end: that is the moment
  -- the window should show the new arrangement. Everything else here waits on a bag event for the slot
  -- that changed, and a piece moved between two bank tabs can land without one arriving for the tab it
  -- left — the window then keeps the picture it had until some later event, a click on a cell or a tab
  -- switch, happens to lay it out. The cursor is the signal that always comes, and a refresh it did not
  -- need costs one pass.
  if held or b.wasHeld then b:QueueRefresh() end
  b.wasHeld = held
  b:SyncCatZones()
end)
bankDropWatch:SetScript("OnUpdate", function(s, dt)
  if not s.tracking then return end
  s.acc = (s.acc or 0) + dt
  if s.acc < 0.03 then return end
  s.acc = 0
  ns.Bank:TrackDropHighlight()
end)

-- The inert crosshair the grouped anti-jump leaves where a bank item just left (deposited away or
-- withdrawn). ns.CatHole builds it, so the bags draw the same one. Pooled per state like the empty
-- tiles, drawn only while the banker holds the layout.
function View:CatHole(st, i)
  st.catHoles = st.catHoles or {}
  local t = st.catHoles[i]
  if not t then
    t = ns.CatHole(st.content)
    st.catHoles[i] = t
  end
  return t
end

function View:HideCatHoles(st, from)
  if not (st and st.catHoles) then return end
  for i = (from or 0) + 1, #st.catHoles do
    if st.catHoles[i] then st.catHoles[i]:Hide() end
  end
end

-- Right click on a bank category caption withdraws the whole section to the player's bags: each piece
-- through the game's own UseContainerItem on a bank slot (no bank-type argument), the same withdraw the
-- game's bank button runs, paced by Cats:MoveSlots while the account bank is the one open, since only it
-- answers a round-trip per move. Only while the banker is open and live; a snapshot has no live container.
-- `slots` is the section's own list; nil (Empty) is inert. The send closure checks the player bags have a
-- free slot before firing: with the bags full UseContainerItem cannot land the piece (it stays locked in
-- the bank), so a full-bags run would otherwise retry each slot to its cap for nothing. Returning false on
-- no space ends the run at once, the way the reference addon stops a transfer with nowhere to go.
local function bagsHaveRoom()
  for _, bag in ipairs(ns.playerBags) do
    if (select(1, C_Container.GetContainerNumFreeSlots(bag)) or 0) > 0 then return true end
  end
  if ns.reagentBag and (select(1, C_Container.GetContainerNumFreeSlots(ns.reagentBag)) or 0) > 0 then
    return true
  end
  return false
end
function View:TransferSection(slots)
  if not slots or self.snap or not self.bankerOpen then return end
  if InCombatLockdown() or CursorHasItem() or GetCursorInfo() then return end
  ns.Categories:MoveSlots(slots, function(bag, slot)
    -- No free bag slot: stop rather than fire a withdraw that cannot land and then retry it to the cap.
    -- A reagent going only to the reagent bag is not distinguished here; the game routes it, and a false
    -- from a full ordinary bags set with a free reagent slot is the rare miss the per-slot cap still covers.
    if not bagsHaveRoom() then return false end
    C_Container.UseContainerItem(bag, slot)
    -- No target slot to hand back: the game chooses the bag slot. The pump reads the source (this bank
    -- slot) to know it landed, which for the account bank is the round-trip signal.
    return true
  end, function()
    return self.bankerOpen and self.frame and self.frame:IsShown()
  end, self.mode == "warband")
end

-- A display-only free-slot tile for the Empty section: a faint plate with a count, bound to nothing so
-- it never carries a bag or slot and stays taint-free. Pooled on the state.
function View:EmptyTile(st, i)
  st.emptyTiles = st.emptyTiles or {}
  local t = st.emptyTiles[i]
  if not t then
    t = CreateFrame("Frame", nil, st.content, "BackdropTemplate")
    ns.PixelBackdrop(t)
    ns.SetBg(t, Theme:C("slot"))
    ns.SetEdge(t, Theme:C("stroke"))
    local fs = Theme:Label(t, 12, "dim")
    fs:SetPoint("CENTER")
    fs:SetJustifyH("CENTER")
    t.count = fs
    st.emptyTiles[i] = t
  end
  if self.fontPath then t.count:SetFont(self.fontPath, math.max(7, self.fontBase or 13), ns.OutlineFlags()) end
  return t
end

function View:HideEmptyTiles(st, from)
  if not (st and st.emptyTiles) then return end
  for i = (from or 0) + 1, #st.emptyTiles do
    if st.emptyTiles[i] then st.emptyTiles[i]:Hide() end
  end
end

function View:CatGHead(st, i)
  st.gHeads = st.gHeads or {}
  local b = st.gHeads[i]
  if not b then
    b = CreateFrame("Button", nil, st.content)
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnClick", function(s)
      if not s.wpeEntry then return end
      if (self.query or "") ~= "" then return end
      if IsShiftKeyDown() then
        ns.Categories:SetAllFolded(not ns.Categories:Folded(s.wpeEntry))
      else
        ns.Categories:ToggleFold(s.wpeEntry)
      end
      self:Layout()
    end)
    b:SetScript("OnEnter", function(s)
      if s.wpeCaret then s.wpeCaret:SetTint("accent") end
      if s.wpeLabel then s.wpeLabel:SetTextColor(Theme:C("accentInk")) end
    end)
    b:SetScript("OnLeave", function(s)
      if s.wpeCaret then s.wpeCaret:SetTint("dim") end
      if s.wpeLabel then s.wpeLabel:SetTextColor(Theme:C("azure")) end
    end)
    st.gHeads[i] = b
  end
  return b
end

-- The locked-bank placeholder, lifted out of Plan so both the tab and the category layouts reach the
-- same 4-row dummy grid when the bank cannot be read.
function View:PlanLocked(st, size, cols, step)
  local plan = st.plan
  local rows = 4
  for k = 1, cols * rows do
    local c = plan[k] or {}
    c.bag, c.slot, c.force = 0, k, nil
    local col, row = (k - 1) % cols, math.floor((k - 1) / cols)
    c.x, c.y = col * step, -(row * step)
    plan[k] = c
  end
  st.blank = true
  st.planCount = cols * rows
  return cols * rows, (rows - 1) * step + size, 0, 0
end

function View:Plan(st, size, cols, gap)
  if self:CatMode() then return self:PlanCats(st, size, cols, gap) end
  local step = stepFor(size, gap)
  local plan = st.plan
  local n, used, total, bottom, li = 0, 0, 0, 0, 0
  local only = self:TabSel(st.mode)

  for _, sec in ipairs(self:Sections(st.mode)) do
    local first, count = n, 0
    for _, bag in ipairs(sec.ids) do
      if not only or bag == only then
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
        -- The plan is shared with the grouped view and its entries are reused index by index, so a
        -- count override left on one by a folded cell is read back by whatever the grid puts at that
        -- index: the merged total of a category then stays drawn on a slot that holds one stack of its
        -- own. Cleared wherever the grid writes a slot, so the grid never draws a number it did not
        -- count itself.
        c.force = nil
        plan[first + count] = c
      end
      end
    end
    if count > 0 then
      local secTop = bottom
      if sec.label and not only then
        secTop = bottom + DIV
        li = li + 1
        local lbl = self:Label(st, li, sec.color)
        lbl:ClearAllPoints()
        lbl:SetText(ns.L[sec.label])
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
  -- Grouped mode leaves counts and the free tile parked on the content; hide them all when the plain
  -- tab layout runs.
  self:HideCatCounts(st, 0)
  self:HideCatGroups(st, 0)
  self:HideCatHoles(st, 0)
  self:HideCatHits(st, 0)
  self:HideEmptyTiles(st, 0)
  -- The grouped anti-jump memory belongs to the grouped view, so the grid drops it: a switch back into
  -- groups would otherwise reconcile against the order it saw before the grid, and every piece that left
  -- while the grid was up would stand as a crossed-out hole the bank no longer needs.
  self:DropCatMemory()

  st.blank = nil
  -- A locked bank has no grid to draw whatever the client still reports for its tabs, so it
  -- takes the placeholder the empty snapshot takes and the message sits in the middle of it.
  local lock = self:Locked()
  if lock or (n == 0 and self.snap) then
    local rows = 4
    for k = 1, cols * rows do
      local c = plan[k] or {}
      c.bag, c.slot, c.force = 0, k, nil
      local col, row = (k - 1) % cols, math.floor((k - 1) / cols)
      c.x, c.y = col * step, -(row * step)
      plan[k] = c
    end
    n = cols * rows
    bottom = (rows - 1) * step + size
    st.blank = true
  end

  st.locked = lock
  st.planCount = n
  return n, bottom, used, total
end

function View:Drip(st, tag, list, count, each, done, token)
  -- A slice per frame, measured in time rather than counted in cells, and for a reason: what a
  -- cell costs is whatever its paint happens to need, and a vault nobody has seen yet pays for
  -- a tooltip read on top of that. The whole plan in one call is more than the client sits
  -- through, and it stops the pass with "script ran too long" and leaves the window half
  -- drawn. The token drops a pass that a newer layout has already replaced, and a pass that takes
  -- over may hand its own token in: the full fill owns the state's fill flag, so it has to stamp the
  -- flag before its first slice is painted rather than after the drip comes back.
  token = token or ((st.dripToken or 0) + 1)
  st.dripToken = token
  local i = 0
  local function step()
    if st.dripToken ~= token then
      -- A newer pass took the state over, so this one stops where it is and never reaches its finish
      -- callback. Anything it was holding has to be released here: a full fill that kept its flag set
      -- would leave every later layout waiting for a fill that is not happening — the pass it was
      -- waiting for is the very one that just stopped — and the window would show what it had until
      -- some unrelated trigger came along seconds later.
      if st.filling == token then st.filling = nil end
      return
    end
    ns.ReportEntry()
    while i < count and not ns.OutOfTime() do
      i = i + 1
      each(list[i], i)
    end
    if i < count then
      C_Timer.After(0, step)
      return
    end
    if done then done() end
  end
  step()
end

function View:Run(st, repaint, tag)
  local size = st.iconSize
  local snap = self.snap
  -- The fill flag carries the pass's own token, not a bare true: the wait in Layout is what keeps a
  -- half-drawn plan from being replaced mid-fill, and a pass that is replaced has to be able to see
  -- whether the flag is still its own before it lets go of it.
  local token = (st.dripToken or 0) + 1
  st.filling, st.fillAt = token, GetTime()
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
    -- The view is part of a cell's paint recipe: the grouped view rings reagents by item class, not by
    -- which bag holds them (see Bags.lua). A cell that keeps its slot through a view switch has nothing
    -- else to tell it the recipe changed, and the guarded repaint below would leave the ring of the view
    -- it was drawn in, so the link is dropped when the flag itself flips and not only on a full repaint.
    local cat = self:CatMode()
    if repaint or b.wpeCat ~= cat then b.link = nil end
    if not h:IsShown() then h:Show() end
    if not b:IsShown() then b:Show() end
    -- Combine-stacks sum for a folded cell (grouped view only; nil everywhere else), overriding just the
    -- drawn count. Kept off b so a plan entry reused as a single clears it.
    b.wpeForce = c.force
    b.wpeCat = cat
    if snap then
      ns.PaintVaultButton(b, ns.Vault:Slot(st.mode, c.bag, c.slot), c.bag, c.force)
    else
      ns.UpdateItemButton(b)
    end
    ns.ApplySearchToButton(b, self.filters)
    st.byKey[c.bag * 1000 + c.slot] = b
  end, function()
    if st.filling == token then st.filling = nil end
    -- A layout asked for while this pass was filling waited for it; it runs now, on the finished plan.
    if st.relayout then st.relayout = nil; self:Layout() end
  end, token)
end

function View:Fonts()
  applyDensity(self:CellSize())
  local path = ns.Fonts:Current()
  local base = self:FontSize()
  self.fontPath, self.fontBase = path, base
  local function put(fs, delta)
    if fs then fs:SetFont(path, math.max(7, base + (delta or 0)), ns.OutlineFlags()) end
  end
  local bh = math.max(20, base + 6)
  local function fit(btn, minW, pad, h)
    if not (btn and btn.Text) then return end
    btn:SetHeight(h or bh)
    btn:SetWidth(math.max(minW, math.ceil(btn.Text:GetStringWidth()) + (pad or 16)))
  end
  put(self.freeText, -1)
  put(self.hint, 0)
  put(self.lockHint, 0)
  if self.money then
    put(self.money, 3)
    Theme:Money(self.money)
  end
  put(self.moneyCaption, -3)
  local sh = math.max(22, base + 8)
  if self.search then put(self.search, 0); put(self.search.Hint, 0); self.search:SetHeight(sh) end
  if self.bankTab then put(self.bankTab.Text, -1); fit(self.bankTab, 52, nil, HBTN) end
  if self.wbTab then put(self.wbTab.Text, -1); fit(self.wbTab, 68, nil, HBTN) end
  if self.charBtn then
    put(self.charBtn.Text, -1)
    self.charBtn.Text:SetFont(path, math.max(7, base - 1), ns.OutlineFlags())
    self.charBtn:SetHeight(sh)
  end
  if self.depositBtn then put(self.depositBtn.Text, -1); fit(self.depositBtn, 70, 18) end
  if self.withdrawBtn then put(self.withdrawBtn.Text, -1); fit(self.withdrawBtn, 76, 18) end
  -- The deposit-items label is the game's own and can be long ("Deposit All Reagents"), so the button
  -- is not a fixed width: the font goes on here and UpdateFooter sizes it to whatever text the bank type
  -- put on it. The reagents label rides the same face as the rest of the footer.
  if self.depItemsBtn then put(self.depItemsBtn.Text, -1) end
  if self.reagLabel then put(self.reagLabel, -1) end
  if self.frame and self.frame.wpeBar then
    self.frame.wpeBar:Fonts(path, math.max(8, base - 2))
    self.frame.wpeBar:Size(ns.Density(self:CellSize()).moveH)
  end
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
  -- The section drop targets follow the pass that placed them: shown while a piece rides the cursor in
  -- the grouped view, hidden the rest of the time and always in the grid.
  self:SyncCatZones()
  local pool = self.snap and st.vpool or st.pool
  for j = n + 1, #pool do
    local h = pool[j].holder
    if h:IsShown() then h:Hide() end
  end
  if st == self.cur then
    self:Resize(st)
    self:UpdateMeta()
    self:UpdateFooter()
    local lock = st.locked
    if st.content then st.content:SetShown(not lock) end
    if self.hint then self.hint:SetShown((st.blank and not lock) and true or false) end
    if self.lockHint then
      self.lockHint:ClearAllPoints()
      if lock then
        self.lockHint:SetText(lock)
        ns.SnapPoint(self.lockHint, "CENTER", st.content, "CENTER", 0, 0)
      end
      self.lockHint:SetShown(lock and true or false)
    end
  end
  self:Run(st, repaint, tag)
end

-- A search in grouped mode re-folds sections by hit, but a fold per keystroke re-buckets the whole
-- bank and jumps the layout as prefixes match then drop. So the relayout waits out a short quiet after
-- the last key: each keystroke re-arms the token and only the final one fires. Mirrors Bags:ScheduleCatFold.
function View:ScheduleCatFold()
  self.catFoldToken = (self.catFoldToken or 0) + 1
  local mine = self.catFoldToken
  C_Timer.After(0.25, function()
    if self.catFoldToken ~= mine then return end
    if self.frame and self.frame:IsShown() and self:CatMode() then self:Layout() end
  end)
end

function View:Layout()
  if not (self.frame and self.cur) then return end
  -- A pass is painted a slice at a time, and a pass that starts while one is still filling drops it
  -- mid-way: a fresh pass begins at the first cell, so a run of changes faster than a pass leaves the far
  -- end of the plan drawing what used to be there and only catches up once the run stops. The transfer
  -- re-lays the view out as it goes, which is exactly that run. Wait for the fill instead; it runs the
  -- layout it was asked for when it ends. The age check is the way out if a fill ever dies holding the
  -- flag, so a bad pass cannot leave the window unable to lay out at all.
  local st = self.cur
  if st.filling then
    if (GetTime() - (st.fillAt or 0)) < 2 then st.relayout = true; return end
    st.filling = nil
  end
  st.relayout = nil
  applyDensity(self:CellSize())
  -- A font, theme or slot-style change bumps Bags.styleGen. The bags nil every cell's link on that
  -- (Bags:Refont) so the next paint redraws its text at the new face; the bank pools live here and were
  -- never cleared, so a badge like the bind tag kept the old font. The paint is drip-sliced with a
  -- cancel token, and repaint is decided once by a PaintKey change: a second Layout in the same batch
  -- (the FitHeader/ApplyFont timers relayout fires) sees the key already stored, decides repaint is
  -- false, and cancels the first drip mid-pass, leaving every cell it had not reached on the old face
  -- until a drag changed the link. Clearing the links across both states whenever the generation moved
  -- makes the guard in UpdateItemButton miss on every cell regardless of the drip race, as the bags do.
  if self.styleGenSeen ~= Bags.styleGen then
    self.styleGenSeen = Bags.styleGen
    for _, st in pairs(self.state) do
      for _, b in ipairs(st.pool) do b.link = nil end
      for _, b in ipairs(st.vpool) do b.link = nil end
    end
  end
  self:Fonts()
  self:AnchorHeader()
  self:LayoutMode(self.cur, "fill")
  self:RefreshStrip()
  -- A cell that takes the early return keeps whatever cooldown it last drew, and a bank
  -- that reopens on the same size and the same tab repaints nothing. The rows outside the
  -- bank each re-arm themselves on show for the same reason.
  self:Cooldowns()
end

function View:Resize(st)
  local seam = ns.SeamWatch(self.frame)
  local gw = gridWidth(st.iconSize, self:Cols(st.mode), st.pxGap or Bags.gap or 4)
  st.content:ClearAllPoints()
  ns.SnapPoint(st.content, "TOPLEFT", self.frame, "TOPLEFT", PAD, -(self:HeaderH() + 4))
  ns.SnapSize(st.content, gw, st.contentH)
  -- SnapSize the frame, not SetSize: the window is anchored by a bottom corner and Rebase squares that
  -- corner to the pixel grid, so a whole-pixel height lands the top edge on the grid too. content
  -- anchors TOPLEFT to that top, so once the top is grid-aligned every caption and hairline SnapPointed
  -- relative to content comes out crisp. A raw fractional height left the top (and so all of cat view)
  -- half a pixel off; warband's height happened to sum near a pixel, bank's did not, which is why only
  -- the bank read fuzzy.
  ns.SnapSize(self.frame, PAD * 2 + gw, self:HeaderH() + 4 + st.contentH + self:FooterH())
  -- The plate runs the whole window (Theme:FitPlate). Fitted on every layout rather than where the tab
  -- is picked, so a restyle or a tab switch both leave it where the theme says it belongs.
  Theme:FitPlate(self.gridBg, self.frame)
  ns.Rebase(self.frame, "bankPos")
  ns.SeamHeal(seam)
end

function View:FitHeader()
  self:FlowHeader()
  if self.search then self.search:Show() end
  if self.freeText then
    local edge = self.headEdge and self.headEdge:GetLeft()
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
  local bt = bankTypeFor(self:BlizzMode() or self.mode)
  if not bankLive(self, bt) then return end
  -- A bank with no tabs bought has nothing to tidy, so the count is read before the sort is spent. Only a
  -- real zero stops it. The count is asked per bank type and the account bank is not what the call was
  -- written for: it answers nil in some builds, and reading that as "no tabs" killed the sort outright on
  -- the very bank that has them, with no error to show for it.
  if C_Bank and C_Bank.FetchNumPurchasedBankTabs then
    local ok, tabs = pcall(C_Bank.FetchNumPurchasedBankTabs, bt)
    tabs = ok and tonumber(tabs) or nil
    if tabs and tabs <= 0 then return end
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
  -- Sort works on the live bank slots whatever view is shown, exactly as the bags' clean-up button does.
  -- In the category view the grouped picture barely tells, but the bank underneath is tidied for the next
  -- switch back to tabs. Only a bank with no live container has nothing to sort, so that alone hides it.
  if self.sortBtn then self.sortBtn:SetShown(live) end
  self:FlowHeader()

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

  -- Deposit items and its reagents box live with a banker only, like the money buttons, and only for a
  -- bank type the game will auto-deposit into. The label is the game's own, so it reads "Deposit" in the
  -- character bank and the warbound wording in the warband, matching the default bank on every client.
  do
    local autoDep = live and C_Bank and C_Bank.DoesBankTypeSupportAutoDeposit
    local canDep = false
    if autoDep then local ok, v = pcall(C_Bank.DoesBankTypeSupportAutoDeposit, bt); canDep = ok and v end
    local account = bt == (Enum and Enum.BankType and Enum.BankType.Account)
    -- "Want" is the bank type's answer: whether the control belongs here at all. FlowHeader has the
    -- final say on shown state, dropping either one on its own when the row runs out of room, so it must
    -- know the width of both before deciding. Set the label and width here, flag want, then flow.
    self.depWant = canDep and true or false
    if self.depItemsBtn and canDep then
      -- Our own button, our own words in every locale: the character bank files reagents, the warband
      -- files warbound items, so the label follows the type. Read live from ns.L so a language change
      -- (which calls Refresh -> Layout -> here) re-evaluates it, the same as every other label.
      self.depItemsBtn.Text:SetText(ns.L[account and "Deposit warbound items" or "Deposit reagents"])
      -- Width follows the label: the words differ by bank type and locale, so a fixed box clipped the
      -- longer ones. Pad each side so the text is never flush to the edge, and keep the header height.
      local w = math.ceil(self.depItemsBtn.Text:GetStringWidth()) + 24
      self.depItemsBtn:SetWidth(math.max(70, w))
      self.depItemsBtn:SetHeight(HBTN)
    end
    -- The reagents box is a warband idea: only the account bank sorts reagents into a reagent tab, so the
    -- character bank offers the deposit button without it, exactly as the default frame gates it.
    self.reagWant = canDep and account
    if self.reagBox and self.reagWant then
      self.reagBox.mark:SetShown(GetCVarBool("bankAutoDepositReagents"))
    end
    -- Both live on the top row now, so re-flow the header once want/width are set: FlowHeader fits each
    -- against the tabs' edge and shows or hides it on its own.
    self:FlowHeader()
  end

  for mode, b in pairs(self.buyBtn or {}) do if mode ~= self.mode then b:Hide() end end
  local buy = self.buyBtn and self.buyBtn[self.mode]
  if buy then
    local cost = live and purchasableCost(bt) or nil
    cost = tonumber(cost) or nil
    buy.cost = cost
  end

  if self.money then
    -- The character bank holds no money of its own, so its footer reads the purse the player
    -- carries, while the warband footer reads what the warband holds. The caption is the only
    -- thing that tells the two apart, so it follows the number and not the window.
    local warband = bt == (Enum and Enum.BankType and Enum.BankType.Account)
    local sum
    if warband then
      local abt = Enum and Enum.BankType and Enum.BankType.Account
      if self.bankerOpen and abt and C_Bank and C_Bank.FetchDepositedMoney then
        local ok, v = pcall(C_Bank.FetchDepositedMoney, abt)
        if ok then sum = v end
      end
      if sum == nil then sum = ns.Vault:WarbandMoney() end
    else
      -- The viewed character's purse: own reads live, another character reads its remembered gold, and a
      -- wiped purse reads nil so the footer draws a dash rather than the viewer's own money.
      sum = ns.Vault:CharGold(ns.Vault:ViewKey("bank"))
    end
    self.money:SetText(sum and ns.FormatMoney(sum, nil, Theme:IsLight()) or "—")
    self.moneyCaption:SetText(ns.L[warband and "WARBAND BANK" or "ON HAND"])
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
  local only = self:TabSel(mode)
  for _, sec in ipairs(self:Sections(mode)) do
    for _, bag in ipairs(sec.ids) do
      if not only or bag == only then
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
  end
  return total, used
end

-- Grey (or un-grey) the one cell that just changed lock state, the way Blizzard's bags desaturate a locked
-- item mid-move. Only the live view keeps a bag*1000+slot map (byKey); the grouped and grid layouts share
-- it, so one lookup covers both. A snapshot has no live locks. Cheaper than a full dirty pass for a state
-- that flips many times a second during a category transfer.
function View:RefreshLock(bag, slot)
  if self.snap or not (self.frame and self.frame:IsShown()) then return end
  local st = self.cur
  if not (st and st.byKey) then return end
  local b = st.byKey[bag * 1000 + slot]
  if b then ns.UpdateItemLock(b) end
end

function View:UpdateDirty()
  local st = self.cur
  if self.snap then return end
  if not (st and self.frame and self.frame:IsShown()) then return end
  -- Grouped mode files each slot by its contents, so a changed slot can leave its section: an in-place
  -- repaint would leave it drawn under the wrong caption. Rebuild the whole pass, as the bags do. The
  -- anti-jump while a banker is open lives in PlanCats (slot memory + holes), not here.
  if self:CatMode() then
    if next(st.dirty) then wipe(st.dirty); self:Layout() end
    return
  end
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
  -- One refresh covers everything that lands while it waits, and a refresh already waiting is not pushed
  -- back. Re-arming the timer on every event instead made this a trailing debounce: a run of changes
  -- faster than the wait (a whole category moving into the bank) held the view still until the run
  -- stopped, so the pieces all appeared at once at the end instead of as they arrived.
  if self.refreshPending then return end
  self.refreshPending = true
  C_Timer.After(0.1, function()
    self.refreshPending = nil
    local st = self.cur
    if self.bankerOpen and not self.snap and st then
      ns.Vault:Capture(st.mode, (not st.needLayout) and next(st.dirty) and st.dirty or nil)
      ns.Vault:SetTabs(st.mode, self:LiveTabMeta(st.mode))
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

function View:Cooldowns()
  if self.snap then return end
  local st = self.cur
  if not (st and self.frame and self.frame:IsShown()) then return end
  for i = 1, (st.shown or 0) do
    local b = st.pool[i]
    if b and b.link and b.holder:IsVisible() then ns.UpdateCooldown(b) end
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
  if (WarpeeDB and WarpeeDB.bankPos) or not self.placed then
    ns.PlaceWindow(self.frame, "bankPos", { p = "CENTER", rp = "CENTER", x = 220, y = 40 })
  end
  self.placed = true
end

function View:OnBankOpened()
  self:Build()
  self:BuildBuyButtons()
  ns.Vault:SetView("bank", nil)
  if self.snap then self.snap = nil; self:HideSlots() end
  local bm = self:BlizzMode()
  if bm then self.mode = bm end
  if self.mode == "warband" and not ns.WarbandActive() then self.mode = "bank" end
  if self.mode == "bank" and self:AccountOnly() then self.mode = "warband" end
  self:UpdateTabs()
  self:Place()
  self.frame:Show()
  Theme:Raise(self.frame)
  self:Activate(self.mode)
  if not self:AccountOnly() then ns.Vault:Capture("bank") end
  if ns.WarbandActive() then ns.Vault:Capture("warband") end
  if not self:AccountOnly() then ns.Vault:SetTabs("bank", self:LiveTabMeta("bank")) end
  if ns.WarbandActive() then ns.Vault:SetTabs("warband", self:LiveTabMeta("warband")) end
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
  self:HideTabSettings()
  -- A snapshot is local and browsable without a banker, so losing the banker while
  -- looking at someone else's bank keeps the window and only drops the live parts.
  self.depositType = nil
  self.acctBanker = nil
  if self.snap then
    self:UpdateFooter()
    ns.RefreshBagDim()
    return
  end
  if self.frame then self.frame:Hide() end
  ns.RefreshBagDim()
end

-- Reparenting is the whole trick, and it has to stay the whole trick. A SetScript on
-- BankFrame taints the frame, and the taint reaches the secure bank work: the tab
-- purchase button stops answering, and the game reads BankFrame on every right click of
-- a bag slot, so item use goes with it. Its OnShow is also what gives BankFrame.BankPanel
-- a bank type through SelectDefaultTab, and the game passes that type into the deposit,
-- so silencing OnShow sent everything to the character bank. Never call BankFrame:Hide()
-- either: that fires BANKFRAME_CLOSED and ends the banker session.
-- The holder stays hidden, and must never become a shown frame parked off screen: shown means
-- every slot button in the bank panel is live and catches clicks wherever the panel ends up,
-- and the game puts its own panels back on screen by itself anyway. The tab strip is the one
-- piece that has to stay reachable by the mouse, and the tab code lifts it out of here.
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
