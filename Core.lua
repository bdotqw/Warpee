local addonName, ns = ...
local Bags = ns.Bags
local L = ns.L

-- The slot styles the addon used to ship are folded into the ones it ships now, in one
-- place, so the login migration, a config sanitize and a profile that arrives with an old
-- value all land on the same style.
local SLOT_RENAMES = { quality = "deep", frost = "deep", ridged = "deep", marble = "deep",
                       parchment = "deep", stone = "deep", tile = "deep" }

local PICKS = {
  slotStyle      = { def = "plate", ok = { flat = true, plate = true, deep = true },
                     map = SLOT_RENAMES },
  goldFormat     = { def = "short",
                     ok = { commas = true, dots = true, spaces = true, short = true } },
  vendorRepairBy = { def = "player", ok = { player = true, guild = true, both = true } },
}

local NONE = {}
local DEFAULTS = {
  cols = 16, gap = 4, iconSize = 36, slotStyle = "plate", theme = "blizzard",
  font = "Rubik Bold",
  iconZoom = 1, borderWidth = 1, gridAlpha = 0, showGauge = false,
  favShow = true, recentShow = true,
  qualityColorIlvl = true, qualityBorder = true, mergeReagents = false,
  reagentTop = false, hideReagents = false,
  pocketShow = true, pocketWithBags = false, pocketRows = 4, pocketCols = 6,
  pocketIconSize = NONE,
  revFill = false, fillUp = false, questMarks = true, newItemGlow = false,
  reagentTint = true, unusableBorder = true,
  goldFormat = "short", goldLetters = true, goldOnly = true,
  vendorIlvl = 100, vendorIlvlMin = 10, vendorConsum = false, vendorAuto = false,
  vendorTokens = false, vendorTokenExp = {},
  vendorKeepBoE = true, vendorKeepWarbound = true, vendorKeepGems = true,
  vendorGrey = true, vendorRelics = true,
  vendorRepair = true, vendorRepairBy = "player",
  hideMinimapIcon = false, tipCounts = true, tipBank = true, tipWarband = true,
  keepBags = true, keepBank = true, keepWarband = true,
  searchClear = true, searchLink = true, minimapAngle = 2.2,
  bankCols = 28, warbandCols = 26, bankIconSize = 36,
  hideMoveFields = false, badgeSolo = false, lockWindows = false,
  -- Straight out of the badge table in ItemButton.lua, which draws them and feeds the
  -- panel preview from the same numbers. A second copy here is how the two drifted.
  badge = ns.BadgeDefaults(),
  optSections = { interface = false, bankgrid = false, badges = true, autoopen = false,
                  tokenexp = false, arrange = true, pocketsize = true },
  autoOpen = { auction = true, bank = true, mail = true, trade = true,
               vendor = true, guildbank = true, professions = false },
  bagWinPos = NONE,
  pos = { p = "BOTTOMRIGHT", rp = "BOTTOMRIGHT", x = -8, y = 20 },
  bankPos = { p = "BOTTOMLEFT", rp = "BOTTOMLEFT", x = 5, y = 20 },
  pocketPos = { p = "CENTER", rp = "CENTER", x = 163, y = 80.5 },
}

local function copyDeep(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, x in pairs(v) do out[k] = copyDeep(x) end
  return out
end

local NUMERIC = { "iconZoom", "borderWidth", "gridAlpha", "pocketRows", "pocketCols",
                  "vendorIlvl", "vendorIlvlMin", "minimapAngle" }

local function fillDefaults(db)
  for k, v in pairs(DEFAULTS) do
    if db[k] == nil and v ~= NONE then db[k] = copyDeep(v) end
  end
end

local function wipeConfig(db)
  for k, v in pairs(DEFAULTS) do
    if v == NONE then db[k] = nil else db[k] = copyDeep(v) end
  end
end

ns.DEFAULTS = DEFAULTS
ns.CopyDeep = copyDeep
ns.WipeConfig = wipeConfig

-- Every value is checked against the shape DEFAULTS declares for its key, and anything that
-- does not match is put back to the factory value. A profile code written outside the addon
-- can carry a number under a key whose default is a table, and the login path died on it
-- inside fillComputed, before the bags grid was built: no bags, no bank, and the broken value
-- saved for good, since nothing else in the pipeline reads it back.
function ns.NormalizeConfig(db)
  if not db then return end
  for k, v in pairs(DEFAULTS) do
    if v ~= NONE and db[k] ~= nil and type(db[k]) ~= type(v) then
      db[k] = copyDeep(v)
    end
  end
end

local function fillComputed(db)
  local curExp = LE_EXPANSION_LEVEL_CURRENT
                 or (GetExpansionLevel and GetExpansionLevel()) or 0
  ns.NormalizeConfig(db)
  if db.vendorTokenExp then
    for i = 0, curExp do
      if db.vendorTokenExp[i] == nil then
        db.vendorTokenExp[i] = (i <= 6)
      end
    end
  end
  ns.BadgeMigrate(db, db.badge)
end

ns.FillComputed = fillComputed

local function sanitizeConfig(db)
  if not ns.Theme.THEMES[db.theme] then db.theme = "blizzard" end
  for key, pick in pairs(PICKS) do
    local v = db[key]
    if v ~= nil then
      local to = pick.map and pick.map[v]
      if to then v, db[key] = to, to end
      if not pick.ok[v] then db[key] = pick.def end
    end
  end
end

ns.SanitizeConfig = sanitizeConfig

function ns.PushConfig()
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
  Bags.hideReagents     = WarpeeDB.hideReagents
  Bags.revFill          = WarpeeDB.revFill
  Bags.fillUp           = WarpeeDB.fillUp
  Bags.questMarks       = WarpeeDB.questMarks
  Bags.newItemGlow      = WarpeeDB.newItemGlow
  Bags.reagentTint      = WarpeeDB.reagentTint
  Bags.unusableBorder   = WarpeeDB.unusableBorder
end

function ns.ApplyAll()
  ns.PushConfig()
  ns.Fonts:Settle()
  ns.Fonts:Refresh()
  ns.Theme:Restyle(WarpeeDB.theme)
  Bags:Build()
  -- Placed unconditionally: a profile that carries no position for a window has to land
  -- it on that window's own default, not leave it where the previous profile put it.
  Bags:RestorePos()
  if ns.Bank and ns.Bank.frame then
    ns.PlaceWindow(ns.Bank.frame, "bankPos", { p = "CENTER", rp = "CENTER", x = 220, y = 40 })
  end
  if WarpeeDB.bagWinPos and Bags.bagWindow then ns.PlaceWindow(Bags.bagWindow, "bagWinPos") end
  if WarpeeDB.pocketPos and ns.Pocket and ns.Pocket.frame then ns.PlaceWindow(ns.Pocket.frame, "pocketPos") end
  Bags:Warm()
  if ns.Fav then ns.Fav:Warm() end
  if ns.Recent then ns.Recent:Warm() end
  if ns.Pocket then
    ns.Pocket:Warm()
    if ns.Pocket.Apply then ns.Pocket:Apply() end
  end
  if ns.Bank and ns.Bank.Refresh then ns.Bank:Refresh() end
  if ns.GuildBankSkin and ns.GuildBankSkin.Restyle then ns.GuildBankSkin:Restyle() end
  local picker = ns.CharPicker
  if picker and picker.frame and picker.frame:IsShown() and picker.Paint then
    picker:Paint(true)
  end
  if ns.Options then
    if ns.Options.ReflowPages then ns.Options:ReflowPages() end
    if ns.Options.ApplyFont then ns.Options:ApplyFont() end
  end
  if ns.ApplyLocaleText then ns.ApplyLocaleText() end
  if ns.ApplyMinimapIcon then ns.ApplyMinimapIcon() end
  if Bags.frame and Bags.frame:IsShown() then Bags:Layout() end
end

local function repaintItems()
  ns.ClearItemPaint()
  if Bags.frame and Bags.frame:IsShown() then Bags:Layout() end
  if ns.Bank then ns.Bank:Repaint() end
end

local repaintQ
local function repaintSoon()
  if repaintQ then return end
  repaintQ = true
  C_Timer.After(0.05, function()
    repaintQ = nil
    repaintItems()
  end)
end

local repaintLate
local function repaintLater()
  if repaintLate then return end
  repaintLate = true
  C_Timer.After(0.5, function()
    repaintLate = nil
    repaintItems()
  end)
end

function ns.Toggle(show)
  local f = Bags:Build()
  if show == nil then show = not f:IsShown() end
  if show then
    Bags:RestorePos()
    f:Show()
    ns.Theme:Raise(f)
    Bags:Layout(true)
    -- The pocket follows the bags on a hand press only. An auto open from the auction
    -- house, the mail or a merchant has just pushed the pocket aside, and opening the
    -- bags on top would undo that; ns.autoOpened is set before this runs, so it marks
    -- which kind of open this is. With the option off nothing touches the pocket here:
    -- only its own key and the header button open it.
    if ns.Pocket and not ns.autoOpened
       and (not WarpeeDB or WarpeeDB.pocketWithBags ~= false) then
      ns.Pocket:Open()
    end
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
  close = { "CloseAllBags", "CloseBackpack" },
  sync  = { "ToggleBackpack", "ToggleBag" },
}

-- Hook the game's bag functions, never assign over them. A replaced global is a
-- tainted closure the game then calls itself, and if that path goes on to a protected
-- call, the call is refused.
local function hookList(names, fn)
  for _, n in ipairs(names) do
    if type(_G[n]) == "function" then hooksecurefunc(n, fn) end
  end
end

local autoOpenBags, autoCloseBags

local function HookBagToggles()
  -- The one game global the addon replaces. Other names of ours reach _G as well
  -- (WarpeeDB, the slash commands, the font objects CreateFont needs), but this is the
  -- only function of the game's we assign over. ToggleAllBags runs from a keybind, from
  -- the bag button, or from another addon, never inside a path that goes on to a
  -- protected call. Hooking it instead let the game build and update all of its own
  -- container frames on every open, and left its idea of whether bags are open
  -- disagreeing with ours, so a press could close what it should have opened.
  ToggleAllBags = function() ns.Toggle() end
  hideBlizzBags()
  -- The game opens its own bags beside a window on its own: the mail calls this family
  -- with its frame, the merchant and the auction house call it from their own code.
  -- Following those calls made the auto open checkboxes dead letters, the game's call
  -- always opened ours, so the hooks now follow none of them: the auto open
  -- checkboxes are the only thing that opens our bags together with a window, and
  -- these hooks stay only to keep the game's containers tucked away. Two game paths
  -- still open ours: an enchant or a gem waiting for a target opens them so the item
  -- to receive it can be clicked, held back when the pocket is on screen, and a loot
  -- toast click means show what just dropped.
  local OPEN_FRAME_KEY = { MailFrame = "mail" }
  local function frameKey(frame)
    if type(frame) ~= "table" or not frame.GetName then return nil end
    local ok, name = pcall(frame.GetName, frame)
    return (ok and OPEN_FRAME_KEY[name]) or nil
  end
  -- A loot toast click is the only thing that reaches the bags through OpenBag, so the
  -- stack is read on that one name. OpenAllBags and OpenBackpack arrive from the mail, a
  -- merchant, the auction house or a keybind, and building a stack for them was paying
  -- for an answer they cannot give.
  local function fromGameOpen(fromToast)
    if ns.ItemTargeting() then
      if not (ns.Pocket and ns.Pocket.frame and ns.Pocket.frame:IsShown()) then
        ns.Toggle(true)
      end
    elseif fromToast then
      ns.Toggle(true)
    end
    hideBlizzBags()
  end
  hookList({ "OpenAllBags", "OpenBackpack" }, function()
    fromGameOpen(false)
  end)
  hookList({ "OpenBag" }, function()
    fromGameOpen(debugstack():find("AlertFrameSystems", 1, true) ~= nil)
  end)
  -- An item spell waiting for a target, an enchant or a gem, makes the game open the
  -- bags through these same calls. Only our own frame is held back here; the game's
  -- functions still run whole, so nothing of its own is silenced and no protected call
  -- loses its footing. Never turn this into an override of theirs.
  -- BankFrame opens and closes the bags itself, and it hands itself in as the first
  -- argument. Those calls are left to the bank events instead, so the banker still
  -- honours the auto-open settings.
  hookList(BAG_FN.close, function(frame)
    if frame ~= nil and frame == BankFrame then return end
    local key = frameKey(frame)
    if key then
      autoCloseBags(key)
      return
    end
    ns.Toggle(false)
  end)
  hookList(BAG_FN.sync, function() ns.Toggle(blizzBagsOpen()) end)
end

function autoOpenBags(key)
  if not (WarpeeDB and WarpeeDB.autoOpen and WarpeeDB.autoOpen[key]) then return end
  -- The pocket stands in for the bags, so a window that pulls the bags open pushes the
  -- pocket out of the way: too many windows on screen at once, and the pocket answers
  -- "with you or not", which the bags already say. Its own key and button still open it
  -- on top of everything.
  if ns.Pocket then ns.Pocket:Close(true) end
  local f = Bags.frame
  if f and not f:IsShown() then
    -- Every window that asked is remembered, not only the first: the bank and a merchant
    -- can be on screen together, and closing either one must not take the bags away while
    -- the other is still open. Bags the player opened himself are not in the set at all,
    -- so nothing closes those behind his back.
    local set = ns.autoOpened
    if not set then set = {}; ns.autoOpened = set end
    set[key] = true
    ns.Toggle(true)
  elseif ns.autoOpened then
    ns.autoOpened[key] = true
  end
end

function autoCloseBags(key)
  local set = ns.autoOpened
  if not set then return end
  if key then set[key] = nil end
  if next(set) then return end
  ns.autoOpened = nil
  ns.Toggle(false)
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

-- The quest mark is read off the game on every repaint, and a repaint only reaches a cell
-- that thinks its contents changed. The bag and bank grids get a pass of their own, but the
-- three pinned rows keep their link, so a mark that moved while they were on screen would
-- stay as it was. Clearing the link is what makes them look again.
local function refreshQuestRows()
  for _, row in ipairs({ ns.Fav, ns.Recent, ns.Pocket }) do
    if row then
      for _, field in ipairs({ "slots", "recSlots" }) do
        local t = row[field]
        if t then
          for _, b in pairs(t) do
            if b and ns.SyncQuestMark(b) then
              b.link = nil
              ns.UpdateItemButton(b)
              if Bags.ApplyToButton then Bags:ApplyToButton(b) end
            end
          end
        end
      end
    end
  end
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
                     "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
                     "UPDATE_FACTION", "PLAYER_SPECIALIZATION_CHANGED", "PVP_RATING_UPDATE",
                     "EQUIPMENT_SETS_CHANGED", "EQUIPMENT_SWAP_FINISHED",
                     "PLAYER_EQUIPMENT_CHANGED",
                     "PLAYER_INTERACTION_MANAGER_FRAME_SHOW",
                     "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
                     "ITEM_CHANGED" }) do
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
    if WarpeeDB.goldLetters == nil then
      WarpeeDB.goldLetters = WarpeeDB.goldMode == nil or WarpeeDB.goldMode == "letters"
    end
    if WarpeeDB.goldOnly == nil then
      WarpeeDB.goldOnly = WarpeeDB.goldMode == nil or WarpeeDB.goldMode == "gold"
    end
    WarpeeDB.goldMode = nil

    fillDefaults(WarpeeDB)
    for i = 1, #NUMERIC do
      local k = NUMERIC[i]
      if WarpeeDB[k] ~= nil then WarpeeDB[k] = tonumber(WarpeeDB[k]) or DEFAULTS[k] end
    end

    if not ns.Theme.THEMES[WarpeeDB.theme] then WarpeeDB.theme = "blizzard" end
    ns.Theme:Apply(WarpeeDB.theme)

    if WarpeeDB.slotStyle and SLOT_RENAMES[WarpeeDB.slotStyle] then
      WarpeeDB.slotStyle = SLOT_RENAMES[WarpeeDB.slotStyle]
    end

    ns.Fonts:Settle()
    fillComputed(WarpeeDB)
    if WarpeeDB.junkIcon == false then WarpeeDB.badge.junk.on = false end

    WarpeeDB.favorites = WarpeeDB.favorites or {}
    WarpeeDB.vendorBlack = WarpeeDB.vendorBlack or {}

    WarpeeDB.highContrast = nil
    WarpeeDB.bgAlpha = nil
    WarpeeDB.favCount = nil
    WarpeeDB.junkIcon = nil
    WarpeeDB.pocketKeyDone = nil
    WarpeeDB.unusable = nil
    WarpeeDB.ilvlSize, WarpeeDB.ilvlAnchor = nil, nil
    WarpeeDB.ilvlX, WarpeeDB.ilvlY = nil, nil
    WarpeeDB.qualityAnchor, WarpeeDB.qualityScale = nil, nil
    WarpeeDB.countSize, WarpeeDB.countAnchor = nil, nil
    WarpeeDB.countX, WarpeeDB.countY = nil, nil
    WarpeeDB.fontMigrated = nil
    WarpeeDB.vendorKeepWarband = nil
    WarpeeDB.vendorKeepMog, WarpeeDB.vendorKeepFresh = nil, nil
    WarpeeDB.bankSlotStyle = nil
    WarpeeDB.bankFontSize, WarpeeDB.bankCustomSize, WarpeeDB.hideBlizzBank = nil, nil, nil
    WarpeeDB.warbandCustomSize, WarpeeDB.warbandIconSize = nil, nil
    WarpeeDB.bankPool = nil
    if WarpeeDB.locale == "auto" then WarpeeDB.locale = nil end

    sanitizeConfig(WarpeeDB)
    ns.PushConfig()
    Bags:Build()
    Bags:RestorePos()
    Bags:Warm()
    if ns.Fav then ns.Fav:Warm() end
    if ns.Recent then ns.Recent:Warm() end
    if ns.Pocket then ns.Pocket:Warm() end
    ns.Theme:ApplyGridAlpha()
    HookBagToggles()
    WarpeeDB.bankTabSel = WarpeeDB.bankTabSel or {}
    if ns.Bank then ns.Bank:HideBlizzard() end
    if ns.ApplyLocaleText then ns.ApplyLocaleText() end
    if ns.ApplyMinimapIcon then ns.ApplyMinimapIcon() end
    if C_CVar and C_CVar.SetCVarBitfield then
      -- The mount equipment tutorial hooks the container slot template, and the taint
      -- it leaves is reported against whichever bag addon is loaded. Closing both
      -- tutorials keeps that off us, and the reagent bag one points at a ui we replace.
      if LE_FRAME_TUTORIAL_MOUNT_EQUIPMENT_SLOT_FRAME then
        pcall(C_CVar.SetCVarBitfield, "closedInfoFrames", LE_FRAME_TUTORIAL_MOUNT_EQUIPMENT_SLOT_FRAME, true)
      end
      if LE_FRAME_TUTORIAL_EQUIP_REAGENT_BAG then
        pcall(C_CVar.SetCVarBitfield, "closedInfoFrames", LE_FRAME_TUTORIAL_EQUIP_REAGENT_BAG, true)
      end
    end
    ns.Ready = true
    if ns.Profiles and ns.Profiles.Migrate then ns.Profiles:Migrate() end
  elseif event == "BAG_UPDATE" then
    if not Bags.warmed then Bags:Warm() end
    if ns.IsPlayerBag(a1) then
      Bags.dirty[a1] = true
      -- The counts in the tooltip read our own bags live but are cached per character, and
      -- with the window shut nothing captures, so the own row kept the number it was filled
      -- with. A buy, a loot or a deposit moves the item and not one of our windows.
      ns.Vault:Stale()
    end
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
      local b = Bags.byKey[a1 * 1000 + a2]
      if b then ns.UpdateItemLock(b) end
    end
  elseif event == "BAG_NEW_ITEMS_UPDATED" then
    Bags:RefreshNewItems()
    if ns.Bank then ns.Bank:RefreshNewItems() end
  elseif event == "QUEST_ACCEPTED" or event == "UNIT_QUEST_LOG_CHANGED" then
    if event == "QUEST_ACCEPTED" or a1 == "player" then
      Bags:RefreshQuests()
      if ns.Bank then ns.Bank:RefreshQuests() end
      refreshQuestRows()
    end
  elseif event == "PLAYER_LEVEL_UP" or event == "SKILL_LINES_CHANGED"
      or event == "UPDATE_FACTION" or event == "PLAYER_SPECIALIZATION_CHANGED"
      or event == "PVP_RATING_UPDATE" then
    -- All four move the same verdicts: a level opens gear, a reputation or an arena rating
    -- closes it, and a spec change swaps which of it an item is built for. The red edge
    -- would otherwise keep saying no after the requirement has been met.
    ns.ClearUnusableCache()
    repaintSoon()
  elseif event == "PLAYER_ENTERING_WORLD" then
    ns.ClearUnusableCache()
  elseif event == "ITEM_CHANGED" then
    repaintSoon()
    repaintLater()
  elseif event == "EQUIPMENT_SETS_CHANGED" or event == "EQUIPMENT_SWAP_FINISHED"
      or event == "PLAYER_EQUIPMENT_CHANGED" then
    ns.Sets:Dirty()
    repaintSoon()
  elseif event == "BANKFRAME_OPENED" then
    ns.Sets:Dirty()
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
    if IT and a1 == IT.Transmogrifier then
      -- The transmog window covers most of the screen and no bag is needed on it, so
      -- both of ours get out of the way. Hiding the bags takes the pocket with it when
      -- it is open beside them; one on its own needs its own word.
      ns.Toggle(false)
      if ns.Pocket then ns.Pocket:Close(true) end
      return
    end
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
    local r, g, b = ns.Theme:C("azure")
    tt:AddDoubleLine(TT("Warband bank"), tostring(wb), r, g, b, 1, 1, 1)
  end
  tt:AddDoubleLine(TT("Total"), tostring(total), 1, 0.82, 0, 1, 1, 1)
  return true
end

local function ownSlot(tt)
  local o = tt.GetOwner and tt:GetOwner()
  return (o and o.wpeLockable) and true or false
end

local function pinSlot(tt)
  local o = tt.GetOwner and tt:GetOwner()
  return (o and (o.favIndex or o.pkIndex)) and true or false
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
  if pinSlot(tt) then
    if not drew then tt:AddLine(" ") end
    tt:AddLine(TT("Ctrl + left click clears the slot"), 0.6, 0.6, 0.6)
    tt:AddLine(TT("Drag moves it to another slot"), 0.6, 0.6, 0.6)
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

local slugOK
local SLUG_OFF = { ruRU = true, zhCN = true, zhTW = true, koKR = true }
function ns.OutlineFlags()
  if slugOK == nil then
    slugOK = false
    if not SLUG_OFF[GetLocale and GetLocale() or ""] then
      local probe = UIParent and UIParent:CreateFontString()
      if probe then
        pcall(probe.SetFont, probe, ns.Fonts:Current(), 12, "OUTLINE, SLUG")
        slugOK = probe:GetFont() ~= nil
      end
    end
  end
  return slugOK and "OUTLINE, SLUG" or "OUTLINE"
end

do
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:SetScript("OnEvent", function()
    if ns.Fonts and ns.Fonts.Settle then ns.Fonts:Settle() end
    if ns.Fonts then ns.Fonts:Refresh() end
  end)
end
