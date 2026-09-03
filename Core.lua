local addonName, ns = ...
local Bags = ns.Bags
local L = ns.L

local PICKS = {
  slotStyle      = { def = "flat", ok = { flat = true, plate = true, deep = true } },
  goldFormat     = { def = "short",
                     ok = { commas = true, dots = true, spaces = true, short = true } },
  vendorRepairBy = { def = "player", ok = { player = true, guild = true, both = true } },
}

function ns.Toggle(show)
  local f = Bags:Build()
  if show == nil then show = not f:IsShown() end
  if show then
    Bags:RestorePos()
    f:Show()
    ns.Theme:Raise(f)
    Bags:Layout()
  else
    f:Hide()
  end
end

function ns.ToggleBank()
  local B = ns.Bank
  if not B then return end
  if B.frame and B.frame:IsShown() then
    B:OnBankClosed()
  elseif B.bankerOpen then
    B:OnBankOpened()
  else
    B:OpenSnapshot(B.mode or "bank")
  end
end

local blizzHidden

local function hideBlizzBags()
  if InCombatLockdown() then return end
  if not blizzHidden then
    blizzHidden = CreateFrame("Frame")
    blizzHidden:Hide()
  end
  for i = 1, 13 do
    local f = _G["ContainerFrame" .. i]
    if f and f:GetParent() ~= blizzHidden then f:SetParent(blizzHidden) end
  end
  local c = ContainerFrameCombinedBags
  if c and c:GetParent() ~= blizzHidden then c:SetParent(blizzHidden) end
end

local function blizzBagsOpen()
  local c = ContainerFrameCombinedBags
  if c and c:IsShown() then return true end
  return (ContainerFrame1 and ContainerFrame1:IsShown()) and true or false
end

local BAG_FN = {
  open  = { "OpenAllBags", "OpenBackpack", "OpenBag" },
  close = { "CloseAllBags", "CloseBackpack" },
  sync  = { "ToggleBackpack", "ToggleBag", "ToggleAllBags" },
}

local function hookList(names, fn)
  for _, n in ipairs(names) do
    if type(_G[n]) == "function" then hooksecurefunc(n, fn) end
  end
end

local function HookBagToggles()
  hideBlizzBags()
  hookList(BAG_FN.open, function() ns.Toggle(true); hideBlizzBags() end)
  hookList(BAG_FN.close, function() ns.Toggle(false) end)
  hookList(BAG_FN.sync, function() ns.Toggle(blizzBagsOpen()) end)
end

local function autoOpenBags(key)
  if not (WarpeeDB and WarpeeDB.autoOpen and WarpeeDB.autoOpen[key]) then return end
  local f = Bags.frame
  if f and not f:IsShown() then
    ns.autoOpened = key
    ns.Toggle(true)
  end
end

local function autoCloseBags(key)
  if ns.autoOpened and (not key or ns.autoOpened == key) then
    ns.autoOpened = nil
    ns.Toggle(false)
  end
end

local INTERACT_KEY
local function interactKey(t)
  if not (Enum and Enum.PlayerInteractionType) then return nil end
  if not INTERACT_KEY then
    local IT = Enum.PlayerInteractionType
    INTERACT_KEY = {
      [IT.GuildBanker] = "guildbank",
      [IT.Auctioneer]  = "auction",
      [IT.MailInfo]    = "mail",
      [IT.Merchant]    = "vendor",
      [IT.TradePartner] = "trade",
    }
  end
  return INTERACT_KEY[t]
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("BAG_UPDATE")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:RegisterEvent("BAG_UPDATE_COOLDOWN")
ev:RegisterEvent("PLAYER_MONEY")
ev:RegisterEvent("ITEM_LOCK_CHANGED")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:RegisterEvent("SKILL_LINES_CHANGED")
ev:RegisterEvent("BAG_NEW_ITEMS_UPDATED")
ev:RegisterEvent("QUEST_ACCEPTED")
ev:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
for _, e in ipairs({ "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED",
                     "PLAYERBANKBAGSLOTS_CHANGED", "PLAYERREAGENTBANKSLOTS_CHANGED",
                     "REAGENTBANK_UPDATE", "BANK_TABS_CHANGED", "BANK_TAB_SETTINGS_UPDATED",
                     "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED", "ACCOUNT_MONEY",
                     "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE",
                     "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "CVAR_UPDATE",
                     "PLAYER_REGEN_ENABLED",
                     "EQUIPMENT_SETS_CHANGED", "EQUIPMENT_SWAP_FINISHED",
                     "PLAYER_EQUIPMENT_CHANGED",
                     "PLAYER_INTERACTION_MANAGER_FRAME_SHOW",
                     "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" }) do
  pcall(ev.RegisterEvent, ev, e)
end
local SCALE_CVARS = { uiscale = true, useuiscale = true }
ev:SetScript("OnEvent", function(_, event, a1, a2)
  if event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
    ns.ScaleChanged()
    return
  end
  if event == "CVAR_UPDATE" then
    if type(a1) == "string" and SCALE_CVARS[a1:lower()] then ns.ScaleChanged() end
    return
  end
  if event == "PLAYER_REGEN_ENABLED" then
    if Bags.cold then Bags:Warm(); Bags:Refresh() end
    local B = ns.Bank
    if B and B.cold then B.cold = nil; B:Refresh() end
    Bags:VendorState()
    ns.EscRestore()
    return
  end
  if event == "PLAYER_LOGIN" then
    WarpeeDB = WarpeeDB or {}
    WarpeeDB.cols = WarpeeDB.cols or 16
    WarpeeDB.gap = WarpeeDB.gap or 2
    WarpeeDB.iconSize = WarpeeDB.iconSize or 40
    WarpeeDB.slotStyle = WarpeeDB.slotStyle or "flat"
    WarpeeDB.theme = WarpeeDB.theme or "midnight"
    if not ns.Theme.THEMES[WarpeeDB.theme] then WarpeeDB.theme = "midnight" end
    ns.Theme:Apply(WarpeeDB.theme)
    WarpeeDB.iconZoom = tonumber(WarpeeDB.iconZoom) or 1
    WarpeeDB.borderWidth = tonumber(WarpeeDB.borderWidth) or 1
    WarpeeDB.gridAlpha = tonumber(WarpeeDB.gridAlpha) or 0
    WarpeeDB.bgAlpha = nil
    if WarpeeDB.slotStyle == "quality" then WarpeeDB.slotStyle = "tile" end
    if WarpeeDB.slotStyle == "frost" then WarpeeDB.slotStyle = "tile" end
    if WarpeeDB.slotStyle == "ridged" or WarpeeDB.slotStyle == "marble"
       or WarpeeDB.slotStyle == "parchment" or WarpeeDB.slotStyle == "stone" then
      WarpeeDB.slotStyle = "deep"
    end
    if WarpeeDB.slotStyle == "tile" then WarpeeDB.slotStyle = "deep" end
    if WarpeeDB.showGauge == nil then WarpeeDB.showGauge = false end
    if WarpeeDB.favShow == nil then WarpeeDB.favShow = true end
    WarpeeDB.favCount = tonumber(WarpeeDB.favCount) or 0
    WarpeeDB.favorites = WarpeeDB.favorites or {}
    if WarpeeDB.goldLetters == nil then
      WarpeeDB.goldLetters = WarpeeDB.goldMode == nil or WarpeeDB.goldMode == "letters"
    end
    if WarpeeDB.goldOnly == nil then
      WarpeeDB.goldOnly = WarpeeDB.goldMode == nil or WarpeeDB.goldMode == "gold"
    end
    WarpeeDB.goldMode = nil
    if not WarpeeDB.fontMigrated then
      WarpeeDB.fontMigrated = true
      if ns.Fonts:Usable(ns.Fonts.DEFAULT) then WarpeeDB.font = ns.Fonts.DEFAULT end
    end
    ns.Fonts:Settle()
    WarpeeDB.badge = WarpeeDB.badge or {}
    ns.BadgeMigrate(WarpeeDB, WarpeeDB.badge)
    if WarpeeDB.junkIcon == false then WarpeeDB.badge.junk.on = false end
    WarpeeDB.junkIcon = nil
    WarpeeDB.ilvlSize, WarpeeDB.ilvlAnchor = nil, nil
    WarpeeDB.ilvlX, WarpeeDB.ilvlY = nil, nil
    WarpeeDB.countSize, WarpeeDB.countAnchor = nil, nil
    WarpeeDB.countX, WarpeeDB.countY = nil, nil
    if WarpeeDB.qualityColorIlvl == nil then WarpeeDB.qualityColorIlvl = false end
    if WarpeeDB.qualityBorder == nil then WarpeeDB.qualityBorder = true end
    if WarpeeDB.mergeReagents == nil then WarpeeDB.mergeReagents = false end
    if WarpeeDB.reagentTop == nil then WarpeeDB.reagentTop = false end
    if WarpeeDB.revFill == nil then WarpeeDB.revFill = false end
    if WarpeeDB.fillUp == nil then WarpeeDB.fillUp = false end
    if WarpeeDB.questMarks == nil then WarpeeDB.questMarks = true end
    if WarpeeDB.newItemGlow == nil then WarpeeDB.newItemGlow = false end
    if WarpeeDB.reagentTint == nil then WarpeeDB.reagentTint = true end
    WarpeeDB.goldFormat = WarpeeDB.goldFormat or "short"
    WarpeeDB.vendorIlvl = tonumber(WarpeeDB.vendorIlvl) or 100
    WarpeeDB.vendorIlvlMin = tonumber(WarpeeDB.vendorIlvlMin) or 10
    WarpeeDB.vendorBlack = WarpeeDB.vendorBlack or {}
    if WarpeeDB.vendorConsum == nil then WarpeeDB.vendorConsum = false end
    if WarpeeDB.vendorAuto == nil then WarpeeDB.vendorAuto = false end
    if WarpeeDB.vendorTokens == nil then WarpeeDB.vendorTokens = false end
    local curExp = LE_EXPANSION_LEVEL_CURRENT
                   or (GetExpansionLevel and GetExpansionLevel()) or 0
    WarpeeDB.vendorTokenExp = WarpeeDB.vendorTokenExp or {}
    for i = 0, curExp do
      if WarpeeDB.vendorTokenExp[i] == nil then
        WarpeeDB.vendorTokenExp[i] = (i <= 6)
      end
    end
    if WarpeeDB.vendorKeepBoE == nil then WarpeeDB.vendorKeepBoE = true end
    if WarpeeDB.vendorKeepWarbound == nil then WarpeeDB.vendorKeepWarbound = true end
    if WarpeeDB.vendorKeepGems == nil then WarpeeDB.vendorKeepGems = true end
    if WarpeeDB.vendorGrey == nil then WarpeeDB.vendorGrey = false end
    if WarpeeDB.vendorRelics == nil then WarpeeDB.vendorRelics = true end
    if WarpeeDB.vendorRepair == nil then WarpeeDB.vendorRepair = false end
    WarpeeDB.vendorRepairBy = WarpeeDB.vendorRepairBy or "player"
    WarpeeDB.vendorKeepMog, WarpeeDB.vendorKeepFresh = nil, nil
    WarpeeDB.optSections = WarpeeDB.optSections or {}
    if WarpeeDB.hideMinimapIcon == nil then WarpeeDB.hideMinimapIcon = false end
    if WarpeeDB.tipCounts == nil then WarpeeDB.tipCounts = true end
    if WarpeeDB.tipBank == nil then WarpeeDB.tipBank = true end
    if WarpeeDB.tipWarband == nil then WarpeeDB.tipWarband = true end
    if WarpeeDB.keepBags == nil then WarpeeDB.keepBags = true end
    if WarpeeDB.keepBank == nil then WarpeeDB.keepBank = true end
    if WarpeeDB.keepWarband == nil then WarpeeDB.keepWarband = true end
    if WarpeeDB.locale == "auto" then WarpeeDB.locale = nil end
    WarpeeDB.unusable = nil
    if WarpeeDB.searchClear == nil then WarpeeDB.searchClear = true end
    if WarpeeDB.searchLink == nil then WarpeeDB.searchLink = true end
    WarpeeDB.minimapAngle = tonumber(WarpeeDB.minimapAngle) or 2.2
    if WarpeeDB.autoOpen == nil then
      WarpeeDB.autoOpen = { auction = false, bank = true, mail = true, trade = true,
                            vendor = true, guildbank = true, professions = false }
    end
    for key, pick in pairs(PICKS) do
      if WarpeeDB[key] ~= nil and not pick.ok[WarpeeDB[key]] then
        WarpeeDB[key] = pick.def
      end
    end
    Bags.cols = WarpeeDB.cols
    Bags.gap = WarpeeDB.gap
    Bags.iconSize = WarpeeDB.iconSize
    Bags.slotStyle = WarpeeDB.slotStyle
    Bags.iconZoom = WarpeeDB.iconZoom
    Bags.borderWidth = WarpeeDB.borderWidth
    Bags.goldLetters = WarpeeDB.goldLetters
    Bags.goldOnly = WarpeeDB.goldOnly
    Bags.font = WarpeeDB.font
    Bags.showGauge = WarpeeDB.showGauge
    Bags.badge = WarpeeDB.badge
    Bags.qualityColorIlvl = WarpeeDB.qualityColorIlvl
    Bags.qualityBorder    = WarpeeDB.qualityBorder
    Bags.mergeReagents    = WarpeeDB.mergeReagents
    Bags.reagentTop       = WarpeeDB.reagentTop
    Bags.revFill          = WarpeeDB.revFill
    Bags.fillUp           = WarpeeDB.fillUp
    Bags.questMarks       = WarpeeDB.questMarks
    Bags.newItemGlow      = WarpeeDB.newItemGlow
    Bags.reagentTint      = WarpeeDB.reagentTint
    Bags:Build()
    Bags:RestorePos()
    Bags:Warm()
    if ns.Fav then ns.Fav:Warm() end
    ns.Theme:ApplyGridAlpha()
    HookBagToggles()
    WarpeeDB.bankCols = WarpeeDB.bankCols or 28
    WarpeeDB.warbandCols = WarpeeDB.warbandCols or 26
    WarpeeDB.bankIconSize = WarpeeDB.bankIconSize or 36
    WarpeeDB.bankSlotStyle = nil
    WarpeeDB.bankFontSize, WarpeeDB.bankCustomSize, WarpeeDB.hideBlizzBank = nil, nil, nil
    WarpeeDB.warbandCustomSize, WarpeeDB.warbandIconSize = nil, nil
    WarpeeDB.bankPool = nil
    if ns.Bank then ns.Bank:HideBlizzard() end
    if ns.ApplyMinimapIcon then ns.ApplyMinimapIcon() end
  elseif event == "BAG_UPDATE" then
    if not Bags.warmed then Bags:Warm() end
    if ns.IsPlayerBag(a1) then Bags.dirty[a1] = true end
    if ns.Bank and ns.IsBankContainer and ns.IsBankContainer(a1) then ns.Bank:QueueRefresh(a1) end
  elseif event == "BAG_UPDATE_DELAYED" then
    if Bags.sorting then Bags:SortSettle() else Bags:UpdateDirty() end
  elseif event == "BAG_UPDATE_COOLDOWN" then
    Bags:RefreshCooldowns()
  elseif event == "PLAYER_MONEY" or event == "ACCOUNT_MONEY" then
    if event == "PLAYER_MONEY" and Bags.frame and Bags.frame:IsShown() then Bags:UpdateMeta() end
    if ns.Bank and ns.Bank.frame and ns.Bank.frame:IsShown() then ns.Bank:UpdateFooter() end
  elseif event == "ITEM_LOCK_CHANGED" then
    if not Bags.sorting and not Bags.snap and Bags.frame and Bags.frame:IsShown()
       and a2 and Bags.byKey then
      local b = Bags.byKey[a1 .. ":" .. a2]
      if b then ns.UpdateItemLock(b) end
    end
  elseif event == "BAG_NEW_ITEMS_UPDATED" then
    Bags:RefreshNewItems()
    if ns.Bank then ns.Bank:RefreshNewItems() end
  elseif event == "QUEST_ACCEPTED" or event == "UNIT_QUEST_LOG_CHANGED" then
    if event == "QUEST_ACCEPTED" or a1 == "player" then
      Bags:RefreshQuests()
      if ns.Bank then ns.Bank:RefreshQuests() end
    end
  elseif event == "PLAYER_LEVEL_UP" or event == "SKILL_LINES_CHANGED" then
    ns.ClearUnusableCache()
    if Bags.pool then for _, b in ipairs(Bags.pool) do b.link = nil end end
    if Bags.frame and Bags.frame:IsShown() then Bags:Layout() end
    if ns.Bank then ns.Bank:Repaint() end
  elseif event == "EQUIPMENT_SETS_CHANGED" or event == "EQUIPMENT_SWAP_FINISHED"
      or event == "PLAYER_EQUIPMENT_CHANGED" then
    ns.Sets:Dirty()
    if Bags.pool then for _, b in ipairs(Bags.pool) do b.link = nil end end
    if Bags.frame and Bags.frame:IsShown() then Bags:Layout() end
  elseif event == "BANKFRAME_OPENED" then
    if ns.Bank then ns.Bank.bankerOpen = true; ns.Bank:OnBankOpened() end
    autoOpenBags("bank")
  elseif event == "BANKFRAME_CLOSED" then
    if ns.Bank then ns.Bank.bankerOpen = false; ns.Bank:OnBankClosed() end
    autoCloseBags("bank")
  elseif event == "TRADE_SKILL_SHOW" then
    autoOpenBags("professions")
  elseif event == "TRADE_SKILL_CLOSE" then
    autoCloseBags("professions")
  elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
    local IT = Enum and Enum.PlayerInteractionType
    if ns.Bank and IT then
      if a1 == IT.AccountBanker then
        ns.Bank.acctBanker = true
      elseif a1 == IT.Banker or a1 == IT.CharacterBanker then
        ns.Bank.acctBanker = false
      end
      if ns.Bank.frame and ns.Bank.frame:IsShown() then
        ns.Bank:UpdateTabs()
        ns.Bank:EnforceMode()
      end
    end
    local k = interactKey(a1)
    if k then autoOpenBags(k) end
  elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
    local IT = Enum and Enum.PlayerInteractionType
    if ns.Bank and IT and (a1 == IT.AccountBanker or a1 == IT.Banker
       or a1 == IT.CharacterBanker) then
      ns.Bank.acctBanker = nil
    end
    local k = interactKey(a1)
    if k then autoCloseBags(k) end
  elseif event == "PLAYERBANKSLOTS_CHANGED" or event == "PLAYERBANKBAGSLOTS_CHANGED"
      or event == "PLAYERREAGENTBANKSLOTS_CHANGED" or event == "REAGENTBANK_UPDATE"
      or event == "BANK_TABS_CHANGED" or event == "BANK_TAB_SETTINGS_UPDATED"
      or event == "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED" then
    if ns.Bank then ns.Bank:QueueRefresh() end
  end
end)

local cleared = {}
local function markCleared(tt)
  if cleared[tt] then return end
  cleared[tt] = true
  tt:HookScript("OnTooltipCleared", function(s) s.wpeCounted = nil end)
end

local function tipFont()
  local fs = _G.GameTooltipTextLeft1
  if fs and fs.GetFont then
    local p = fs:GetFont()
    if p then return p end
  end
  return nil
end

local function TT(s)
  local need = ns.Fonts:Need()
  if need then
    local p = tipFont()
    if p and not ns.Fonts:Covers(need, p) then return s end
  end
  return L[s]
end

local function countLine(e, withBank)
  local bank = withBank and e.bank or 0
  local total = e.bags + bank
  if e.bags > 0 and bank > 0 then
    return (TT("%d  (%d bags, %d bank)")):format(total, e.bags, bank)
  elseif bank > 0 then
    return (TT("%d  (bank)")):format(bank)
  end
  return (TT("%d  (bags)")):format(e.bags)
end

local function countRows(tt, id)
  local withBank = not (WarpeeDB and WarpeeDB.tipBank == false)
  local withWb = not (WarpeeDB and WarpeeDB.tipWarband == false)
  local list, wb = ns.Vault:ItemCounts(id)
  local rows, total = {}, 0
  for _, e in ipairs(list) do
    local sum = e.bags + (withBank and e.bank or 0)
    if sum > 0 then
      rows[#rows + 1] = e
      total = total + sum
    end
  end
  if not withWb then wb = 0 end
  total = total + wb
  if total <= 0 then return false end
  tt:AddLine(" ")
  tt:AddLine(TT("Inventory"), 1, 0.82, 0)
  for _, e in ipairs(rows) do
    local col = e.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.class]
    tt:AddDoubleLine(e.name, countLine(e, withBank),
      col and col.r or 1, col and col.g or 1, col and col.b or 1, 1, 1, 1)
  end
  if wb > 0 then
    local W = ns.WARBOUND
    tt:AddDoubleLine(TT("Warband bank"), tostring(wb), W[1], W[2], W[3], 1, 1, 1)
  end
  tt:AddDoubleLine(TT("Total"), tostring(total), 1, 0.82, 0, 1, 1, 1)
  return true
end

local function ownSlot(tt)
  local o = tt.GetOwner and tt:GetOwner()
  return (o and o.wpeLockable) and true or false
end

local function itemTooltip(tt, data)
  if not (tt and data) then return end
  if tt.IsForbidden and tt:IsForbidden() then return end
  local id = data.id
  if not id then return end
  markCleared(tt)
  if tt.wpeCounted then return end
  local drew = false
  if not (WarpeeDB and WarpeeDB.tipCounts == false) then drew = countRows(tt, id) end
  if ownSlot(tt) then
    local V = ns.Vendor
    local locked = (V and V.Blocked and V:Blocked(id)) and true or false
    local r, g, b = 0.5, 0.5, 0.5
    if locked and V and V.IsOpen and V:IsOpen() then r, g, b = 1, 0.4, 0.4 end
    if not drew then tt:AddLine(" ") end
    tt:AddLine(TT(locked and "Locked from the vendor. Alt-click to unlock"
                          or "Alt-click to lock it from the vendor"), r, g, b)
    drew = true
  end
  tt.wpeCounted = drew or nil
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
   and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, itemTooltip)
end

SLASH_WARPEE1 = "/warpee"
SLASH_WARPEE2 = "/wpe"
SlashCmdList["WARPEE"] = function()
  if ns.Options then ns.Options:Toggle() end
end
