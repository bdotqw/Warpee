local addonName, ns = ...
local Bags = ns.Bags
local L = ns.L

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

function ns.ToggleBank(mode)
  local B = ns.Bank
  if not B then return end
  mode = mode or B.mode or "bank"
  if B.frame and B.frame:IsShown() then
    if mode ~= B.mode then B:SetMode(mode) else B:OnBankClosed() end
  elseif B.bankerOpen then
    B:OnBankOpened()
    if mode == "warband" then B:SetMode(mode) end
  else
    B:OpenSnapshot(mode)
  end
end

local function HookBagToggles()
  local open  = function() ns.Toggle(true) end
  local close = function() ns.Toggle(false) end
  local toggle = function() ns.Toggle() end
  ToggleAllBags = toggle
  OpenAllBags   = open
  CloseAllBags  = close
  ToggleBackpack = toggle
  OpenBackpack  = open
  CloseBackpack = close
  ToggleBag     = function() ns.Toggle() end
  OpenBag       = open
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
  if event == "PLAYER_LOGIN" then
    WarpeeDB = WarpeeDB or {}
    WarpeeDB.cols = WarpeeDB.cols or 14
    WarpeeDB.gap = WarpeeDB.gap or 4
    WarpeeDB.iconSize = WarpeeDB.iconSize or 37
    WarpeeDB.slotStyle = WarpeeDB.slotStyle or "deep"
    WarpeeDB.theme = WarpeeDB.theme or "midnight"
    if not ns.Theme.THEMES[WarpeeDB.theme] then WarpeeDB.theme = "midnight" end
    ns.Theme:Apply(WarpeeDB.theme)
    WarpeeDB.iconZoom = tonumber(WarpeeDB.iconZoom) or 1
    WarpeeDB.borderWidth = tonumber(WarpeeDB.borderWidth) or 2
    WarpeeDB.gridAlpha = tonumber(WarpeeDB.gridAlpha) or 1
    WarpeeDB.bgAlpha = nil
    if WarpeeDB.slotStyle == "quality" then WarpeeDB.slotStyle = "tile" end
    if WarpeeDB.slotStyle == "frost" then WarpeeDB.slotStyle = "tile" end
    if WarpeeDB.slotStyle == "ridged" or WarpeeDB.slotStyle == "marble"
       or WarpeeDB.slotStyle == "parchment" or WarpeeDB.slotStyle == "stone" then
      WarpeeDB.slotStyle = "deep"
    end
    if WarpeeDB.slotStyle == "tile" then WarpeeDB.slotStyle = "deep" end
    if WarpeeDB.showGauge == nil then WarpeeDB.showGauge = true end
    if WarpeeDB.goldLetters == nil then WarpeeDB.goldLetters = (WarpeeDB.goldMode == "letters") end
    if WarpeeDB.goldOnly == nil then WarpeeDB.goldOnly = (WarpeeDB.goldMode == "gold") end
    WarpeeDB.goldMode = nil
    if not WarpeeDB.fontMigrated then
      WarpeeDB.fontMigrated = true
      if ns.Fonts:Usable(ns.Fonts.DEFAULT) then WarpeeDB.font = ns.Fonts.DEFAULT end
    end
    WarpeeDB.font = WarpeeDB.font or ns.Fonts.DEFAULT
    if not ns.Fonts:Has(WarpeeDB.font) then WarpeeDB.font = ns.Fonts.DEFAULT end
    if not ns.Fonts:Usable(WarpeeDB.font) then WarpeeDB.font = "Arial Narrow" end
    WarpeeDB.ilvlSize    = WarpeeDB.ilvlSize or 12
    WarpeeDB.ilvlAnchor  = WarpeeDB.ilvlAnchor or "TOPLEFT"
    WarpeeDB.ilvlX       = WarpeeDB.ilvlX or 3
    WarpeeDB.ilvlY       = WarpeeDB.ilvlY or -3
    WarpeeDB.countSize   = WarpeeDB.countSize or 14
    WarpeeDB.countAnchor = WarpeeDB.countAnchor or "BOTTOMRIGHT"
    WarpeeDB.countX      = WarpeeDB.countX or -2
    WarpeeDB.countY      = WarpeeDB.countY or 2
    if WarpeeDB.qualityColorIlvl == nil then WarpeeDB.qualityColorIlvl = false end
    if WarpeeDB.qualityBorder == nil then WarpeeDB.qualityBorder = false end
    if WarpeeDB.mergeReagents == nil then WarpeeDB.mergeReagents = false end
    if WarpeeDB.questMarks == nil then WarpeeDB.questMarks = false end
    if WarpeeDB.newItemGlow == nil then WarpeeDB.newItemGlow = false end
    if WarpeeDB.junkIcon == nil then WarpeeDB.junkIcon = false end
    WarpeeDB.goldFormat = WarpeeDB.goldFormat or "commas"
    WarpeeDB.vendorIlvl = tonumber(WarpeeDB.vendorIlvl) or 300
    WarpeeDB.vendorIlvlMin = tonumber(WarpeeDB.vendorIlvlMin) or 0
    WarpeeDB.vendorBlack = WarpeeDB.vendorBlack or {}
    if WarpeeDB.vendorConsum == nil then WarpeeDB.vendorConsum = false end
    if WarpeeDB.vendorAuto == nil then WarpeeDB.vendorAuto = false end
    if WarpeeDB.vendorTokens == nil then WarpeeDB.vendorTokens = false end
    local curExp = LE_EXPANSION_LEVEL_CURRENT
                   or (GetExpansionLevel and GetExpansionLevel()) or 0
    WarpeeDB.vendorTokenExp = WarpeeDB.vendorTokenExp or {}
    for i = 0, curExp do
      if WarpeeDB.vendorTokenExp[i] == nil then
        WarpeeDB.vendorTokenExp[i] = (i <= curExp - 4)
      end
    end
    if WarpeeDB.vendorKeepBoE == nil then WarpeeDB.vendorKeepBoE = true end
    if WarpeeDB.vendorKeepWarbound == nil then WarpeeDB.vendorKeepWarbound = true end
    if WarpeeDB.vendorKeepGems == nil then WarpeeDB.vendorKeepGems = true end
    if WarpeeDB.vendorGrey == nil then WarpeeDB.vendorGrey = true end
    if WarpeeDB.vendorRelics == nil then WarpeeDB.vendorRelics = true end
    if WarpeeDB.vendorRepair == nil then WarpeeDB.vendorRepair = false end
    WarpeeDB.vendorRepairBy = WarpeeDB.vendorRepairBy or "player"
    WarpeeDB.vendorKeepMog, WarpeeDB.vendorKeepFresh = nil, nil
    WarpeeDB.optSections = WarpeeDB.optSections or {}
    if WarpeeDB.hideMinimapIcon == nil then WarpeeDB.hideMinimapIcon = false end
    if WarpeeDB.locale == "auto" then WarpeeDB.locale = nil end
    if WarpeeDB.searchClear == nil then WarpeeDB.searchClear = true end
    if WarpeeDB.searchLink == nil then WarpeeDB.searchLink = true end
    WarpeeDB.minimapAngle = tonumber(WarpeeDB.minimapAngle) or 2.2
    if WarpeeDB.autoOpen == nil then
      WarpeeDB.autoOpen = { auction = true, bank = true, mail = true, trade = true,
                            vendor = true, guildbank = false, professions = false }
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
    Bags.ilvlSize    = WarpeeDB.ilvlSize
    Bags.ilvlAnchor  = WarpeeDB.ilvlAnchor
    Bags.ilvlX       = WarpeeDB.ilvlX
    Bags.ilvlY       = WarpeeDB.ilvlY
    Bags.countSize   = WarpeeDB.countSize
    Bags.countAnchor = WarpeeDB.countAnchor
    Bags.countX      = WarpeeDB.countX
    Bags.countY      = WarpeeDB.countY
    Bags.qualityColorIlvl = WarpeeDB.qualityColorIlvl
    Bags.qualityBorder    = WarpeeDB.qualityBorder
    Bags.mergeReagents    = WarpeeDB.mergeReagents
    Bags.questMarks       = WarpeeDB.questMarks
    Bags.newItemGlow      = WarpeeDB.newItemGlow
    Bags.junkIcon         = WarpeeDB.junkIcon
    Bags:Build()
    Bags:RestorePos()
    ns.Theme:ApplyGridAlpha()
    HookBagToggles()
    WarpeeDB.bankCols = WarpeeDB.bankCols or 24
    WarpeeDB.warbandCols = WarpeeDB.warbandCols or WarpeeDB.bankCols
    WarpeeDB.bankIconSize = WarpeeDB.bankIconSize or 40
    WarpeeDB.bankSlotStyle = nil
    WarpeeDB.bankFontSize, WarpeeDB.bankCustomSize, WarpeeDB.hideBlizzBank = nil, nil, nil
    WarpeeDB.warbandCustomSize, WarpeeDB.warbandIconSize = nil, nil
    WarpeeDB.bankPool = nil
    if ns.Bank then ns.Bank:HideBlizzard() end
    if ns.ApplyMinimapIcon then ns.ApplyMinimapIcon() end
    print("|cffd9a85fWarpee|r " .. L["loaded"] .. " · v" ..
      (C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"))
  elseif event == "BAG_UPDATE" then
    Bags.dirty[a1] = true
    if ns.Bank and ns.IsBankContainer and ns.IsBankContainer(a1) then ns.Bank:QueueRefresh(a1) end
  elseif event == "BAG_UPDATE_DELAYED" then
    if Bags.sorting then Bags:SortSettle() else Bags:UpdateDirty() end
  elseif event == "BAG_UPDATE_COOLDOWN" then
    Bags:RefreshCooldowns()
  elseif event == "PLAYER_MONEY" or event == "ACCOUNT_MONEY" then
    if event == "PLAYER_MONEY" and Bags.frame and Bags.frame:IsShown() then Bags:UpdateMeta() end
    if ns.Bank and ns.Bank.frame and ns.Bank.frame:IsShown() then ns.Bank:UpdateFooter() end
  elseif event == "ITEM_LOCK_CHANGED" then
    if not Bags.sorting and Bags.frame and Bags.frame:IsShown() and a2 and Bags.byKey then
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
  if ns.Fonts:NeedsCyrillic() then
    local p = tipFont()
    if p and not ns.Fonts:HasCyrillic(p) then return s end
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

local function itemTooltip(tt, data)
  if not (tt and data) then return end
  if tt.IsForbidden and tt:IsForbidden() then return end
  if WarpeeDB and WarpeeDB.tipCounts == false then return end
  local id = data.id
  if not id then return end
  markCleared(tt)
  if tt.wpeCounted then return end
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
  if total <= 0 then return end
  tt.wpeCounted = true
  tt:AddLine(" ")
  tt:AddLine(TT("Inventory"), 1, 0.82, 0)
  for _, e in ipairs(rows) do
    local col = e.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.class]
    tt:AddDoubleLine(e.name, countLine(e, withBank),
      col and col.r or 1, col and col.g or 1, col and col.b or 1, 1, 1, 1)
  end
  if wb > 0 then
    tt:AddDoubleLine(TT("Warband bank"), tostring(wb), 0.44, 0.71, 0.83, 1, 1, 1)
  end
  tt:AddDoubleLine(TT("Total"), tostring(total), 1, 0.82, 0, 1, 1, 1)
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
   and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, itemTooltip)
end

SLASH_WARPEE1 = "/warpee"
SLASH_WARPEE2 = "/wpe"
SlashCmdList["WARPEE"] = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  local cols = tonumber(msg:match("^cols%s+(%d+)$"))
  if msg == "bags" or msg == "bag" or msg == "toggle" then
    ns.Toggle()
  elseif cols and cols >= 6 and cols <= 24 then
    WarpeeDB.cols = cols
    Bags.cols = cols
    if Bags.frame:IsShown() then Bags:Layout() end
    print("|cff6FB4D4Warpee|r: " .. L["columns"] .. " —", cols)
  elseif msg == "bank" or msg == "warband" then
    ns.ToggleBank(msg == "warband" and "warband" or "bank")
  else
    if ns.Options then ns.Options:Toggle() end
  end
end
