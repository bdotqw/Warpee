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
  cols = 16, gap = 4, iconSize = 37, slotStyle = "plate", theme = "blizzard",
  font = "Rubik Bold",
  iconZoom = 1, borderWidth = 1, gridAlpha = 0, transparency = 0, showGauge = false,
  favShow = true, recentBags = true, recentPocket = true,
  qualityColorIlvl = true, qualityBorder = true, mergeReagents = false,
  reagentTop = false, hideReagents = false,
  -- One block per container in the plain grid, per window, off by default.
  splitBags = false, splitBank = false, splitWb = false, splitGapBags = 12, splitGapBank = 12,
  splitGapWb = 12,
  -- Whether a block carries its bag's or tab's name over its cells.
  nameBags = true, nameBank = true, nameWb = true,
  pocketShow = true, pocketWithBags = false, pocketRows = 4, pocketCols = 6,
  pocketSnap = true,
  -- A size of the pocket's own. It used to be NONE -- "no number of its own, read the bags' size on
  -- every pass" -- which is how a save that predated the setting kept working. Left that way it
  -- never stopped: resizing the bags dragged the pocket along, a settings reset cleared the key and
  -- put it back to following, and a profile never carried the size at all, since only keys with a
  -- default are copied into one. A save with no number takes the bags' size once, at login or where
  -- the key is first read (ns.PocketIconSize), and from then on it is a setting like any other.
  pocketIconSize = 37,
  -- NONE, not false: nil here means the pocket has never been given a lock of its own, and
  -- the login block seeds it from the lock that used to cover it. Filling it with a default
  -- would settle that question before the migration ever gets to ask it.
  pocketLock = NONE,
  revFill = false, fillUp = false, questMarks = true, newItemGlow = false,
  newOnTop = false,
  reagentTint = true, unusableBorder = true,
  bagView = "grid", bankView = "grid", categories = {},
  catSort = "ilvl",
  -- Flat pixel values, not NONE: the grouped view ships with the sections packed tight rather than
  -- following the density scale, which read too airy. Two gaps, kept apart on purpose: X is the space
  -- between sections side by side on a shelf (8), Y the drop between shelf rows, set a touch tighter (6)
  -- so the rows read as a block. A player overrides either from its own slider, and a save that already
  -- carried the old single gap seeds both.
  catGapX = 8, catGapY = 6,
  catCombine = true,
  -- Drag a piece onto a section in the grouped view to pin it there. "off" keeps a bag drag meaning only
  -- "put it down" (the editor is the sole way to pin); "alt" pins only while Alt is held, so an ordinary
  -- drag never leaves a surprise pin; "on" pins on every section drop. Alt is the default: it keeps the
  -- plain drag safe and makes pinning a deliberate gesture.
  catPinDrag = "alt",
  goldFormat = "short", goldLetters = true, goldOnly = true,
  vendorIlvl = 100, vendorIlvlMin = 10, vendorConsum = false, vendorAuto = false,
  vendorTokens = false, vendorTokenExp = {},
  vendorKeepBoE = true, vendorKeepWarbound = true, vendorKeepGems = true,
  vendorGrey = true, vendorRelics = true,
  vendorRepair = true, vendorRepairBy = "player",
  hideMinimapIcon = false, tipCounts = true, tipBank = true, tipWarband = true, tipGold = true,
  keepBags = true, keepBank = true, keepWarband = true,
  searchClear = true, searchLink = true, minimapAngle = 2.2,
  bankCols = 28, warbandCols = 26, bankIconSize = 37, warbandIconSize = 37,
  hideMoveFields = false, badgeSolo = false, lockWindows = false,
  -- Straight out of the badge table in ItemButton.lua, which draws them and feeds the
  -- panel preview from the same numbers. A second copy here is how the two drifted.
  badge = ns.BadgeDefaults(),
  -- Only the keys the pages still fold with; retired ones are cleared at login.
  optSections = { badges = true, tokenexp = false, pocketsize = true, categories = true,
                  badgeorder = false },
  autoOpen = { auction = true, bank = true, mail = true, trade = true,
               vendor = true, guildbank = true, professions = false,
               itemupgrade = true, catalyst = true },
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

local NUMERIC = { "iconZoom", "borderWidth", "gridAlpha", "transparency", "pocketRows", "pocketCols",
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
  Bags.splitBags        = WarpeeDB.splitBags
  Bags.splitBank        = WarpeeDB.splitBank
  Bags.splitWb          = WarpeeDB.splitWb
  Bags.splitGapBags     = WarpeeDB.splitGapBags
  Bags.splitGapBank     = WarpeeDB.splitGapBank
  Bags.splitGapWb       = WarpeeDB.splitGapWb
  Bags.nameBags         = WarpeeDB.nameBags
  Bags.nameBank         = WarpeeDB.nameBank
  Bags.nameWb           = WarpeeDB.nameWb
  Bags.revFill          = WarpeeDB.revFill
  Bags.fillUp           = WarpeeDB.fillUp
  Bags.newOnTop         = WarpeeDB.newOnTop
  Bags.questMarks       = WarpeeDB.questMarks
  Bags.newItemGlow      = WarpeeDB.newItemGlow
  Bags.reagentTint      = WarpeeDB.reagentTint
  Bags.unusableBorder   = WarpeeDB.unusableBorder
  Bags.bagView          = WarpeeDB.bagView
  Bags.catGapX          = WarpeeDB.catGapX
  Bags.catGapY          = WarpeeDB.catGapY
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

-- A pass that paints a whole bank is not a fixed number of cells, and a cell nobody has seen
-- before costs a tooltip read on top of its paint, so the budget is time and not a count. A
-- pass records the moment it started, and every caller that can afford to stop asks before
-- it takes on more: the cost of a cell is whatever the moment makes it, so a count that
-- fits one machine starves another.
local BUDGET = 0.1
local lastEntry = GetTimePreciseSec()
function ns.ReportEntry()
  lastEntry = GetTimePreciseSec()
end
function ns.OutOfTime()
  return (GetTimePreciseSec() - lastEntry) > BUDGET
end

local function repaintItems()
  ns.ClearItemPaint()
  if Bags.frame and Bags.frame:IsShown() then Bags:Layout() end
  if ns.Bank then ns.Bank:Repaint() end
  -- The guild bank paints the same rings off the same verdicts, and it is the one window the two
  -- passes above cannot reach: an item whose scan had to wait got its border only the next time
  -- the slots happened to be painted, which in practice meant once it was moved.
  local gb, f = ns.GuildBankSkin, _G.GuildBankFrame
  if gb and gb.PaintSlots and f and f:IsShown() then pcall(gb.PaintSlots, gb) end
end

local repaintQ
-- Difficulty at the last world entry, and the time an item-targeting spell was last on the
-- cursor: both let a later branch tell a real transition from an ordinary one. See PLAYER_ENTERING_WORLD
-- (timewalking rescale) and UNIT_SPELLCAST_SUCCEEDED (a lockbox or a mill/prospect cast finishing).
local lastDifficulty
local lastItemSpell = 0
local function repaintSoon()
  if repaintQ then return end
  repaintQ = true
  C_Timer.After(0.05, function()
    repaintQ = nil
    repaintItems()
  end)
end

ns.RepaintSoon = repaintSoon

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
    -- First open on a profile that has never been prompted announces the category view and offers a
    -- starting layout. It gates itself on the per-profile flag and on combat, and sets the flag only when
    -- dismissed, so an open in combat simply tries again next time.
    if ns.Welcome then ns.Welcome:MaybeShow() end
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
    -- The Escape press reaches here through Blizzard's own window pass before that pass walks
    -- UISpecialFrames: hiding here would leave that walk nothing to find, and the client would
    -- open the game menu over the bags it just closed. Seen from the stack the call comes from
    -- CloseAllWindows/ToggleGameMenu, so it is left to that walk, which hides the frame itself
    -- and counts the press. Every other caller hides at once, as before.
    local st = debugstack and debugstack()
    if st and (st:find("CloseAllWindows", 1, true) or st:find("ToggleGameMenu", 1, true)) then return end
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

-- Relayout whichever grouped windows are open when a stack-splitting / take-items window opens or closes.
-- Two things ride on this: the Combine-stacks fold (a folded cell hides physical stacks a split needs), and
-- the anti-jump slot memory (LayoutCats/PlanCats hold emptied cells as holes while such a window is open,
-- and compact them once it closes). Cheap and idempotent, so it no-ops for a plain grid or a closed window.
-- Deferred one frame: the interaction-manager state is only updated after the event, so a layout run inside
-- the handler would still read the window as open and keep the holes the close was meant to settle.
function ns.RelayoutForSplit()
  if ns.Categories and ns.Categories.MoveQuiet and ns.Categories:MoveQuiet() then return end
  C_Timer.After(0, function()
    if Bags.frame and Bags.frame:IsShown() and Bags.CatMode and Bags:CatMode() then Bags:Layout() end
    if ns.Bank and ns.Bank.Refresh then ns.Bank:Refresh() end
  end)
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
      -- Item Upgrade window (53) and the Revival Catalyst (44, an ItemInteraction), both arriving on
      -- the same interaction-manager event as the others.
      [IT.ItemUpgrade]   = "itemupgrade",
      [IT.ItemInteraction] = "catalyst",
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
                     "CURRENT_SPELL_CAST_CHANGED", "UNIT_SPELLCAST_SUCCEEDED",
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
    return
  end
  if event == "PLAYER_LOGIN" then
    -- The view chooser is for first installs only. A save that already carries any key predates
    -- this release: that player set their bags up the way they like long before categories, so
    -- mark it prompted here and the chooser never appears for them. Only a genuinely empty save
    -- (a fresh install, nothing written yet) is left unmarked, so MaybeShow can offer the choice.
    local freshInstall = (WarpeeDB == nil) or (next(WarpeeDB) == nil)
    WarpeeDB = WarpeeDB or {}
    if not freshInstall and WarpeeDB.startPrompted == nil then WarpeeDB.startPrompted = 1 end
    if WarpeeDB.goldLetters == nil then
      WarpeeDB.goldLetters = WarpeeDB.goldMode == nil or WarpeeDB.goldMode == "letters"
    end
    if WarpeeDB.goldOnly == nil then
      WarpeeDB.goldOnly = WarpeeDB.goldMode == nil or WarpeeDB.goldMode == "gold"
    end
    WarpeeDB.goldMode = nil

    -- Recent was one switch for both windows, and it is two now. The split has to happen
    -- before the defaults are filled in, because that is what would otherwise write two
    -- "on" over the only record of the row having been off. A save that already carries
    -- either key was written by this version, so the old value is spent either way.
    if WarpeeDB.recentBags == nil then WarpeeDB.recentBags = WarpeeDB.recentShow ~= false end
    if WarpeeDB.recentPocket == nil then WarpeeDB.recentPocket = WarpeeDB.recentShow ~= false end
    WarpeeDB.recentShow = nil

    -- The pocket used to be frozen by the lock that governs the bags and the bank. It is
    -- independent now, and a save that predates that has no answer of its own: take the old
    -- lock's answer once, so nobody's pocket starts moving on its own after an update. From
    -- here on the two never read each other.
    if WarpeeDB.pocketLock == nil then WarpeeDB.pocketLock = WarpeeDB.lockWindows == true end

    -- The one category gap became two, X across a shelf and Y between rows. A save that carried the
    -- single number seeds both from it, so a window that was packed to the player's taste stays packed
    -- that way; the old key is dropped so it does not linger in the save or ride along in a profile.
    if WarpeeDB.catGap ~= nil then
      local g = tonumber(WarpeeDB.catGap)
      if g then
        if WarpeeDB.catGapX == nil then WarpeeDB.catGapX = g end
        if WarpeeDB.catGapY == nil then WarpeeDB.catGapY = g end
      end
      WarpeeDB.catGap = nil
    end

    -- Before fillDefaults: a saved number must not be seeded over by the default.
    if WarpeeDB.warbandIconSize == nil then WarpeeDB.warbandIconSize = WarpeeDB.bankIconSize end
    -- The same one-time seed for the pocket's own size, and for the same reason: a save written
    -- before the pocket had a size keeps the look it had, the moment it is read. After this it is
    -- a setting of its own and the bags' size is never consulted again -- a save that carries no
    -- bags size either is left to the default above.
    if WarpeeDB.pocketIconSize == nil then WarpeeDB.pocketIconSize = WarpeeDB.iconSize end
    -- Before fillDefaults, or the saved number is thrown away for the default.
    if WarpeeDB.splitGapBags == nil then WarpeeDB.splitGapBags = WarpeeDB.splitGap or 12 end
    if WarpeeDB.splitGapBank == nil then WarpeeDB.splitGapBank = WarpeeDB.splitGap or 12 end
    fillDefaults(WarpeeDB)
    -- autoOpen is a table default, so fillDefaults only seeds it whole on a fresh profile; a profile
    -- that predates these two keys keeps its table and would read them as nil (off). Seed the pair so
    -- the shipped default (on) reaches everyone, the way the rest of the auto-open toggles ship on.
    if WarpeeDB.autoOpen then
      if WarpeeDB.autoOpen.itemupgrade == nil then WarpeeDB.autoOpen.itemupgrade = true end
      if WarpeeDB.autoOpen.catalyst == nil then WarpeeDB.autoOpen.catalyst = true end
    end
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

    -- The save used to keep its groups in a second table beside the categories; Migrate folds that
    -- pair into the one ordered list once, markers and all, and drops the leftovers. Empty and Other
    -- are real, movable category rows but neither is deletable, so both rows must always exist; an
    -- older or short custom list gets them restored at the tail here, on every login.
    -- The upgrades sit between them because they are about the shipped rules rather than the shape of the
    -- list: two shipped rules were rewritten so the rule editor can show them as chips, the four gear rows
    -- gained an item-level floor after saves existed, and five rule words were later spelled the way the
    -- picker spells them, so their chips read as words the player can pick back and a language can
    -- translate. Each carries its change onto those rows alone where they are still exactly as shipped,
    -- leaving written rules alone.
    if ns.Categories then
      ns.Categories:Migrate()
      ns.Categories:UpgradePresetRules()
      ns.Categories:UpgradeFloor()
      ns.Categories:UpgradeRuleWords()
      ns.Categories:EnsureEmpty()
      ns.Categories:EnsureOther()
    end

    WarpeeDB.favorites = WarpeeDB.favorites or {}
    -- The sale carousel's store (Features/Vendor.lua): any older vendor lock is folded into it here,
    -- and the folded ids that are gear are moved onto the copies at hand on PLAYER_ENTERING_WORLD.
    WarpeeDB.sellMark = WarpeeDB.sellMark or {}
    if ns.Vendor and ns.Vendor.FoldLocks then ns.Vendor:FoldLocks() end

    WarpeeDB.highContrast = nil
    WarpeeDB.bgAlpha = nil
    WarpeeDB.catCollapsed = nil
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
    -- Warband icon size is live again: not wiped here, or it is re-seeded every login.
    WarpeeDB.warbandCustomSize = nil
    WarpeeDB.bankPool = nil
    -- Empty was briefly deletable and used this flag to remember a delete; it is not deletable now
    -- and EnsureEmpty always restores the row, so the flag is dead. Cleared so no save keeps it.
    WarpeeDB.emptySeeded = nil
    -- Four fold keys no page carries; cleared with the other retired keys.
    if WarpeeDB.optSections then
      WarpeeDB.optSections.interface, WarpeeDB.optSections.bankgrid = nil, nil
      WarpeeDB.optSections.autoopen, WarpeeDB.optSections.arrange = nil, nil
    end
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
    ns.Theme:ApplyWindowAlpha()
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
    -- The warband read has to happen while the bank is open, so this event waits less.
    ns.Vault:QueueGold(event == "ACCOUNT_MONEY" and 0.5 or 2)
  elseif event == "ITEM_LOCK_CHANGED" then
    -- The game locks a slot the instant a move is issued and unlocks it when the move lands, so this is
    -- what greys a cell mid-transfer, the way Blizzard's own bags desaturate a locked item. a2 nil means an
    -- equipment slot (a1 is the equip slot), which no container cell draws, so those are skipped. The change
    -- is fanned to every surface that draws live cells, not just the bag grid: the bank, and the pinned rows
    -- (Recent, Favorites, Pocket) all mirror bag or bank slots and have to grey the same slot the same way.
    if a2 and not Bags.sorting and not Bags.snap and Bags.frame and Bags.frame:IsShown()
       and Bags.byKey then
      local b = Bags.byKey[a1 * 1000 + a2]
      if b then ns.UpdateItemLock(b) end
    end
    if a2 then
      if ns.Bank and ns.Bank.RefreshLock then ns.Bank:RefreshLock(a1, a2) end
      if ns.Recent and ns.Recent.RefreshLock then ns.Recent:RefreshLock(a1, a2) end
      if ns.Fav and ns.Fav.RefreshLock then ns.Fav:RefreshLock(a1, a2) end
      if ns.Pocket and ns.Pocket.RefreshLock then ns.Pocket:RefreshLock(a1, a2) end
    end
  elseif event == "BAG_NEW_ITEMS_UPDATED" then
    -- A fresh new-item flag is the pump's trigger: an item just acquired (loot, buy, quest) is flagged
    -- here. Run whether or not the window is open, so a piece taken while it was shut is already at the far
    -- end by the time it opens: the move is done unseen instead of jumping the moment the bag appears.
    if Bags.newOnTop and not Bags.snap and Bags.ArrangeNew then Bags:ArrangeNew() end
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
    -- The character's coins are stamped here and never at login or logout: at both ends of a session
    -- the money reads as 0 while the client is still loading the character or already tearing it down,
    -- so a stamp there wrote that zero over the number the store had, and the gold list lost the
    -- character. A couple of beats after the world is up the read is the player's real purse.
    ns.Vault:QueueGold(2)
    -- Timewalking rescales every equippable item to the event's level, and the number changes at the
    -- instance boundary with no BAG_UPDATE behind it. GetCurrentItemLevel is read live per paint, so a
    -- window left open across the zone-in kept the outside ilvl on its cells. Difficulty 33 is
    -- Timewalking; repaint only when that boundary is actually crossed, not on every loading screen.
    local diff = GetDungeonDifficultyID and GetDungeonDifficultyID()
    if diff ~= lastDifficulty then
      local twNow, twWas = (diff == 33), (lastDifficulty == 33)
      lastDifficulty = diff
      if twNow ~= twWas then repaintSoon() end
    end
  elseif event == "CURRENT_SPELL_CAST_CHANGED" then
    -- The moment a right-click puts an item-targeting spell on the cursor (a lockbox key, mill,
    -- prospect, disenchant), note the time. UNIT_SPELLCAST_SUCCEEDED below uses it to know the cast
    -- that just finished was one of ours worth refreshing after, without watching every cast.
    if ns.ItemTargeting() then lastItemSpell = GetTime() end
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    -- A lockbox opened by right-click, or a mill/prospect/disenchant, targets an item and the bag
    -- change lands a beat later than the cast. If our own click just put an item-targeting spell on
    -- the cursor, refresh once the cast reports done so #locked and counts do not sit stale until the
    -- delayed BAG_UPDATE. Only after a recent targeting cast, so ordinary casts cost nothing here.
    if a1 == "player" and (GetTime() - lastItemSpell) < 2 then
      lastItemSpell = 0
      repaintLater()
    end
  elseif event == "ITEM_CHANGED" then
    -- The link from before and after: a marked or locked piece keeps its entry through an upgrade, a
    -- gem or an enchant instead of being left on a key that is no longer there.
    if ns.Vendor and ns.Vendor.RetargetMarks then ns.Vendor:RetargetMarks(a1, a2) end
    repaintSoon()
    repaintLater()
  elseif event == "EQUIPMENT_SETS_CHANGED" or event == "EQUIPMENT_SWAP_FINISHED"
      or event == "PLAYER_EQUIPMENT_CHANGED" then
    ns.Sets:Dirty()
    repaintSoon()
  elseif event == "BANKFRAME_OPENED" then
    ns.Sets:Dirty()
    -- A banker or the warband portal: the one moment the account bank is readable.
    ns.Vault:StampGold()
    if ns.Bank then ns.Bank.bankerOpen = true; ns.Bank:OnBankOpened() end
    autoOpenBags("bank")
  elseif event == "BANKFRAME_CLOSED" then
    if ns.Bank then ns.Bank.bankerOpen = false; ns.Bank:OnBankClosed() end
    autoCloseBags("bank")
    -- Settle the grouped anti-jump freeze the bank interactions left: holes held in place while the
    -- banker was open (a deposit from the bags, a withdraw in the bank) relay into the packed order now.
    ns.RelayoutForSplit()
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
    -- A stack-splitting window just opened: if the grouped view is up with Combine stacks on, relayout so
    -- the fold lifts and every physical stack is its own cell (Categories reads the window live). Harmless
    -- otherwise — a grid or an ungrouped window relayouts to the same picture.
    ns.RelayoutForSplit()
  elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
    local IT = Enum and Enum.PlayerInteractionType
    if ns.Bank and IT and (a1 == IT.AccountBanker or a1 == IT.Banker
       or a1 == IT.CharacterBanker) then
      ns.Bank.acctBanker = nil
    end
    local k = interactKey(a1)
    if k then autoCloseBags(k) end
    -- The window closed: fold the stacks back if Combine stacks is on.
    ns.RelayoutForSplit()
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
  if pinSlot(tt) then
    if not drew then tt:AddLine(" ") end
    -- The key alone when there is one: it is the binding the player chose, and the middle
    -- click keeps working under it whether or not this line names it. With no key bound the
    -- middle click is the whole story, and it steps aside only if the player bound it.
    local name = ns.PinKeyName()
    local msg
    if name then
      msg = TT("%s clears the slot"):format(name)
    elseif (GetBindingAction("BUTTON3") or "") == "" then
      msg = TT("Middle-click to clear the slot")
    else
      msg = TT("Bind a key to clear the slot")
    end
    tt:AddLine(msg, 0.6, 0.6, 0.6)
    drew = true
  end
  if ownSlot(tt) then
    local V = ns.Vendor
    -- The line is a promise, so it is made only where the alt-click would keep it: Vendor:Markable is the
    -- click's own question, the hard vetoes and the player's keep settings included, so the two answer
    -- alike. An item already in the carousel is always offered the way round, or a mark could not come
    -- off whatever its price did.
    local o = tt.GetOwner and tt:GetOwner()
    local bag = o and o.wpeBagID
    local info = bag and C_Container.GetContainerItemInfo(bag, o:GetID())
    if info and info.itemID ~= id then info = nil end
    local link = info and info.hyperlink
    if not link and tt.GetItem then local _, l = tt:GetItem(); link = l end
    local state = (V and V.SellState) and V:SellState(id, link) or nil
    if state or (V and V.Markable and V:Markable(bag, bag and o:GetID(), id, link, info)) then
      local r, g, b = 0.5, 0.5, 0.5
      local msg
      if state == "lock" then
        msg = "Locked from sale. ALT-click to clear it"
        if V.IsOpen and V:IsOpen() then r, g, b = 1, 0.4, 0.4 end
      elseif state == "mark" then
        msg = "Marked for sale. ALT-click to lock it from sale"
        r, g, b = 1, 0.82, 0
      else
        msg = "ALT-click to mark it for sale"
      end
      if not drew then tt:AddLine(" ") end
      tt:AddLine(TT(msg), r, g, b)
      drew = true
    end
  end
  tt.wpeCounted = drew or nil
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
   and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, itemTooltip)
end

SLASH_WARPEE1 = "/warpee"
SLASH_WARPEE2 = "/wpe"
SlashCmdList["WARPEE"] = function(msg)
  local arg = ((msg or ""):match("^%s*(%S*)") or ""):lower()
  if arg == "welcome" and ns.Welcome then
    ns.Welcome:Reopen()
    return
  end
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
