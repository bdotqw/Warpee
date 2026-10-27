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
  pocketShow = true, pocketWithBags = false, pocketHandOnly = false, pocketRows = 4, pocketCols = 6,
  pocketSnap = true, pocketRecentTwo = true,
  -- A size of the pocket's own. NONE -- "no number of its own, read the bags' size on every pass" --
  -- would make resizing the bags drag the pocket along, and a profile would never carry the size,
  -- since only keys with a default are copied into one. A save with no number takes the bags' size
  -- once, at login or where the key is first read (ns.PocketIconSize), and from then on it is a
  -- setting like any other.
  pocketIconSize = 37,
  -- NONE, not false: nil here means the pocket has never been given a lock of its own, and
  -- the login block seeds it from the lock that used to cover it. Filling it with a default
  -- would settle that question before the migration ever gets to ask it.
  pocketLock = NONE,
  revFill = false, fillUp = false, questMarks = true, newItemGlow = false,
  newOnTop = false,
  -- The grey-junk coin is a marker toggle of its own now, not a badge in the panel. It ships on, the
  -- way the junk badge always did; ns.MarkJunk reads Bags.junkCoin, and the login path below carries
  -- the old badge/junkIcon state into it.
  junkCoin = true,
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
  -- goldBlizzard: the money line's coin is Warpee's own unless this says otherwise (the client's icons
  -- are the ones the rest of the game writes, kept for anyone who wants the window to match them).
  goldFormat = "short", goldLetters = false, goldOnly = false, goldBlizzard = false,
  -- curStrip: the row of the currencies the client itself tracks, drawn inside the bags under the grid
  -- behind a seam. On by default: it answers "how much of it do I have" without opening the character
  -- panel, and a tick in the panel behind it is the character panel's own pin, both ways.
  -- Features/Currencies.lua reads the flag off Bags.
  curStrip = true,
  -- curOrder: the row's own display order -- watched ids in the player's arrangement. Cells are
  curOrder = {},
  -- curDir: the row grows from the middle out of the box; "ltr" and "rtl" are the player's other picks.
  curDir = "center",
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
  -- The grey-junk coin left the badge panel for its own marker toggle (junkCoin). This runs on login and
  -- on every profile switch, so a profile stored before the move carries its answer across either way. The
  -- signal is the old badge.junk record still being there: badge.junk.on == false means the player had the
  -- coin off, anything else means on. junkIcon was the switch before badge.junk and is folded in for a save
  -- old enough to carry it but no junk badge. The old record is dropped once read, so a captured profile no
  -- longer holds it; on a fresh save it was never created (it left BadgeDefaults with the panel row), so
  -- junkCoin keeps whatever default or choice it already has.
  if type(db.badge) == "table" and db.badge.junk ~= nil then
    local j = db.badge.junk
    db.junkCoin = not (type(j) == "table" and j.on == false)
    db.badge.junk = nil
  elseif db.junkIcon == false then
    db.junkCoin = false
  end
  -- The coin's scale field narrowed to 0.4-0.6: below 0.4 it was only ever a coin small enough that the
  -- art stopped reading, above 0.6 the mark covered the item it sat on. A stored value outside that band is
  -- brought in here, once, rather than clamped in the field's getter -- a getter that answers something
  -- other than what it holds fights the slider and lags the window on every frame. Written only when it
  -- is actually out of band, so nothing is rewritten twice. The junk
  -- coin needs no entry: it is sized by the sale mark's record and has no scale of its own.
  local sellRec = db.badge and db.badge.sell
  if type(sellRec) == "table" then
    local s = tonumber(sellRec.s)
    if s and (s < 0.4 or s > 0.6) then
      sellRec.s = s < 0.4 and 0.4 or 0.6
    end
  end
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
  Bags.goldBlizzard = WarpeeDB.goldBlizzard
  Bags.curStrip = WarpeeDB.curStrip ~= false
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
  Bags.junkCoin         = WarpeeDB.junkCoin
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

-- Two clocks, because there are two kinds of work and they cost very different things.
--
-- The read: a cell nobody has seen before pays a tooltip call, and a full bank is hundreds of them.
-- That is the work the client stops a pass for, so it keeps a slice of one frame's worth of work (time
-- and not a count: what a cell costs is whatever the moment makes it, so a count that fits one machine
-- starves another). It was a tenth of a second before this -- a slice that big ran 100 ms of read per
-- frame and the opening bank read as one ~130 ms hitch followed by two more -- and 8 ms is the
-- single-digit number the passes that chunk this way aim for.
--
-- The drawing: a texture set, a count, a ring, a string. Ours, cheap, and never sliced anywhere else in
-- the addon -- the bags paint their whole grid in one call, in and out of combat, and always have. So a
-- pass that draws runs its whole plan in one call and the window arrives drawn, which is the shape a
-- window should have: a bank that filled itself in cell by cell read as a stutter, not as an opening.
-- The ceiling below is not a slice but the way out of a plan too big for one frame at all (a snapshot of
-- a thousand slots); past it the pass yields and the next frame carries on.
local BUDGET = 0.008
local FILL_CEILING = 0.5
local lastEntry = GetTimePreciseSec()
function ns.ReportEntry()
  lastEntry = GetTimePreciseSec()
end
function ns.OutOfTime()
  return (GetTimePreciseSec() - lastEntry) > BUDGET
end
function ns.FillOutOfTime()
  -- In combat the client's own watchdog is far stricter than the peace-time ceiling: a fill that ran to
  -- half a second there was logged as "script ran too long" inside a texture write, and the same was
  -- reported for a tab switch in the snapshot. The ceiling drops to the read slice while the player is in
  -- combat, so every frame of a fill stays tiny; out of combat the window still arrives whole.
  local cap = InCombatLockdown() and BUDGET or FILL_CEILING
  return (GetTimePreciseSec() - lastEntry) > cap
end

local function repaintItems()
  ns.ClearItemPaint()
  -- A verdict or an item-cache change that lands while the window is shut has no cells to walk: the links
  -- are dropped here anyway, and the open repaints them (Bags:Resume) instead of waiting for a change in
  -- the bags that will never come.
  if Bags.frame and Bags.frame:IsShown() then Bags:Layout() else Bags.openPaint = true end
  if ns.Bank then ns.Bank:Repaint() end
  -- The guild bank paints the same rings off the same verdicts, and it is the one window the two
  -- passes above cannot reach: an item whose scan had to wait got its border only the next time
  -- the slots happened to be painted, which in practice meant once it was moved.
  local gb, f = ns.GuildBankSkin, _G.GuildBankFrame
  if gb and gb.PaintSlots and f and f:IsShown() then ns.Guard("guild bank paint", gb.PaintSlots, gb) end
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

-- A late verdict is the one thing that arrives after the pass that asked for it, and what it changes is
-- one thing on the cells that hold the link: the red ring the unusable read draws. Those cells are painted
-- and nothing else is. The windows walk their own pools (Bags:RepaintLinks, View:RepaintLinks) and answer
-- with how many cells they really repainted; a cell whose picture the verdict leaves alone keeps it, since
-- the guard inside ns.UpdateItemButton compares everything the ring is a function of.
function ns.PaintVerdicts(links)
  if not links then return 0 end
  local painted = 0
  local bags = Bags
  if bags and bags.frame then
    if bags.frame:IsShown() and bags.RepaintLinks then
      painted = painted + (bags:RepaintLinks(links) or 0)
    else
      -- The cells are not there to repaint, and the link this verdict belongs to is still on them: the
      -- open drops the links and repaints them (Bags:Resume).
      bags.openPaint = true
    end
  end
  local bank = ns.Bank
  if bank and bank.frame and bank.frame:IsShown() and bank.RepaintLinks then
    painted = painted + (bank:RepaintLinks(links) or 0)
  end
  -- The guild bank draws the same rings off the same verdicts: it has no pool of cells to hand a link
  -- to, so it repaints the slots it shows.
  local gb, f = ns.GuildBankSkin, _G.GuildBankFrame
  if gb and gb.PaintSlots and f and f:IsShown() then ns.Guard("guild bank paint", gb.PaintSlots, gb) end
  return painted
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

-- One place for both kinds of open, a hand press and a window opening the bags for the player. Open with
-- bags is the master switch; Ignore bag auto-open narrows it to the hand press, so an interaction
-- that brings the bags brings no pocket and, just as important, does not take a pocket it did not bring
-- when it closes. A pocket that is up when the bags come up belongs to them and leaves with them
-- (Bags.OnHide) -- including one the player opened on its own a moment earlier.
local function openPocketWithBags(automatic)
  local pocket = ns.Pocket
  if not (pocket and (not WarpeeDB or WarpeeDB.pocketWithBags ~= false)) then return end
  if automatic and WarpeeDB and WarpeeDB.pocketHandOnly then return end
  pocket.solo = nil
  if not (pocket.frame and pocket.frame:IsShown()) then pocket:Open() end
end
-- The pages switch Open with bags on while the bags are already up, and the pocket has to follow the
-- same rule then as on an open.
ns.OpenPocketWithBags = openPocketWithBags

function ns.Toggle(show, automatic)
  local f = Bags:Build()
  if show == nil then show = not f:IsShown() end
  if show then
    if not automatic then ns.autoOpened = nil end
    Bags:RestorePos()
    -- Raised while still hidden. A strata change re-sorts the client's render list, and doing it with the
    -- grid already on screen re-sorts every cell for nothing; raising first is free either way.
    ns.Theme:Raise(f)
    f:Show()
    -- A warm open shows what the last pass drew and repaints only the bags that moved while the window
    -- was shut (Bags:Resume, fed by the dirty set UpdateDirty keeps while hidden). The full pass is for
    -- the first open and for a change it could not carry: style, face, geometry, view, a slot count, a
    -- snapshot. Its capture is the full one; the warm path captures only the bags that moved.
    if Bags:NeedsLayout() then
      Bags:Layout(true)
      Bags.dirty = {}
    else
      Bags:Resume()
    end
    openPocketWithBags(automatic)
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
  close = { "CloseAllBags" },
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
  -- Frame-driven closes belong to the interaction events, which know which window still owns the bags.
  local function closeFromGame(frame, nested)
    if frame ~= nil then return end
    local st = debugstack and debugstack()
    -- CloseBackpack can run inside CloseAllBags without its frame argument; only the outer hook decides.
    if nested and st and st:find("CloseAllBags", 1, true) then return end
    -- Escape must reach UISpecialFrames or the same press opens the game menu after hiding the bags.
    if st and (st:find("CloseAllWindows", 1, true) or st:find("ToggleGameMenu", 1, true)) then return end
    ns.Toggle(false)
  end
  hookList(BAG_FN.close, function(frame) closeFromGame(frame, false) end)
  hookList({ "CloseBackpack" }, function(frame) closeFromGame(frame, true) end)
  -- OpenAllBags and CloseAllBags walk through ToggleBackpack and ToggleBag themselves, and the game's
  -- containers are only reparented, so the inner toggle still reads as the game's own open. Syncing on it
  -- opened our bags beside every window that calls OpenAllBags, checkbox or no checkbox: the sync hook is
  -- for a hand that toggles the game's bags, and a call already inside an open/close-all is not a hand.
  hookList(BAG_FN.sync, function()
    local st = debugstack and debugstack()
    if st and (st:find("OpenAllBags", 1, true) or st:find("CloseAllBags", 1, true)) then return end
    ns.Toggle(blizzBagsOpen())
  end)
end

function autoOpenBags(key)
  if not (WarpeeDB and WarpeeDB.autoOpen and WarpeeDB.autoOpen[key]) then return end
  -- With Open with bags the pocket is part of the bags: the option opens it beside a window that opened the
  -- bags itself, so this is no place to hide it. With the option off an automatic window still pushes a
  -- standing pocket aside, the way it always did; either way the pocket leaves with the bags when the
  -- window closes (Bags.OnHide).
  if ns.Pocket and WarpeeDB.pocketWithBags == false then
    ns.Pocket:Close(true)
  end
  local f = Bags.frame
  if not f or not f:IsShown() then
    -- Each interaction owns only bags opened automatically; a hand open keeps ownership.
    local set = ns.autoOpened
    if not set then set = {}; ns.autoOpened = set end
    set[key] = true
    ns.Toggle(true, true)
  else
    if ns.autoOpened then ns.autoOpened[key] = true end
    openPocketWithBags(true)
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

-- The event handler is one function per group of events plus a table that says which event goes where.
-- A table cannot hold two answers for one key, so where an event goes is a lookup, and every new event
-- is a row in it rather than another branch threaded through a chain. A body whose events answer
-- differently -- money, whose two events answer differently, and the quest log, which reacts only to
-- the player's own -- reads the event it was handed.
local on = {}

local function onScale()
  ns.ScaleChanged()
end

local function onCvar(_, a1)
  if type(a1) == "string" and SCALE_CVARS[a1:lower()] then ns.ScaleChanged() end
end

local function onRegen()
  if Bags.cold then Bags:Warm(); Bags:Refresh() end
  local B = ns.Bank
  if B and B.cold then B.cold = nil; B:Refresh() end
  Bags:VendorState()
end

local function onLogin()
  -- The view chooser is for first installs only. A save that already carries any key predates
  -- this release: that player set their bags up the way they like long before categories, so
  -- mark it prompted here and the chooser never appears for them. Only a genuinely empty save
  -- (a fresh install, nothing written yet) is left unmarked, so MaybeShow can offer the choice.
  local freshInstall = (WarpeeDB == nil) or (next(WarpeeDB) == nil)
  WarpeeDB = WarpeeDB or {}
  if not freshInstall and WarpeeDB.startPrompted == nil then WarpeeDB.startPrompted = 1 end
  if WarpeeDB.goldLetters == nil then
    WarpeeDB.goldLetters = WarpeeDB.goldMode == "letters"
  end
  if WarpeeDB.goldOnly == nil then
    WarpeeDB.goldOnly = WarpeeDB.goldMode == "gold"
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
  -- Before fillDefaults, or the saved number is thrown away for the default. All three split gaps came
  -- in together, so the one old splitGap seeds all three alike -- the warband one was missing here, so a
  -- save carrying legacy splitGap kept it for bags and bank but lost it to the default for warband.
  if WarpeeDB.splitGapBags == nil then WarpeeDB.splitGapBags = WarpeeDB.splitGap or 12 end
  if WarpeeDB.splitGapBank == nil then WarpeeDB.splitGapBank = WarpeeDB.splitGap or 12 end
  if WarpeeDB.splitGapWb == nil then WarpeeDB.splitGapWb = WarpeeDB.splitGap or 12 end
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
  -- The bank's own pool is warmed a few seconds after login rather than here: a live cell cannot be built
  -- in combat, so the pool has to be waiting before the fight, but its frames are the same a normal open
  -- builds and must not be paid for on the login path or in front of the player. See View:Warm in Bank.lua.
  if ns.Bank and ns.Bank.Warm then C_Timer.After(3, function() ns.Bank:Warm() end) end
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
end

local function onBagChanged(_, a1)
  if not Bags.warmed then Bags:Warm() end
  -- The reagent bag is its own container (bag id 5, outside ns.playerBags), and its cells are drawn in the
  -- same grid: a piece moved in or out of it is a dirty bag like any other, so the pass re-reads it
  -- instead of waiting for the next open.
  if ns.IsPlayerBag(a1) or a1 == ns.reagentBag then
    Bags.dirty[a1] = true
    -- The counts in the tooltip read our own bags live but are cached per character, and
    -- with the window shut nothing captures, so the own row kept the number it was filled
    -- with. A buy, a loot or a deposit moves the item and not one of our windows.
    ns.Vault:Stale()
  end
  if ns.Bank and ns.IsBankContainer and ns.IsBankContainer(a1) then ns.Bank:QueueRefresh(a1) end
end

local function onBagsSettled()
  if Bags.sorting then Bags:SortSettle() else Bags:UpdateDirty() end
end

local function onCooldowns()
  Bags:RefreshCooldowns()
end

local function onMoney(event)
  if event == "PLAYER_MONEY" and Bags.frame and Bags.frame:IsShown() then Bags:UpdateMeta() end
  if ns.Bank and ns.Bank.frame and ns.Bank.frame:IsShown() then ns.Bank:UpdateFooter() end
  -- The warband read has to happen while the bank is open, so this event waits less.
  ns.Vault:QueueGold(event == "ACCOUNT_MONEY" and 0.5 or 2)
end

local function onSlotLocked(_, a1, a2)
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
    -- A lock that started or ended while the window was shut has nothing to grey: the slot waits for the
    -- open (Bags:Resume), which asks the client again instead of trusting the last desaturation.
    if not (Bags.frame and Bags.frame:IsShown()) then
      Bags.openLocks = Bags.openLocks or {}
      Bags.openLocks[a1 * 1000 + a2] = true
    end
    if ns.Bank and ns.Bank.RefreshLock then ns.Bank:RefreshLock(a1, a2) end
    if ns.Recent and ns.Recent.RefreshLock then ns.Recent:RefreshLock(a1, a2) end
    if ns.Fav and ns.Fav.RefreshLock then ns.Fav:RefreshLock(a1, a2) end
    if ns.Pocket and ns.Pocket.RefreshLock then ns.Pocket:RefreshLock(a1, a2) end
  end
end

local function onNewItems()
  -- A fresh new-item flag is the pump's trigger: an item just acquired (loot, buy, quest) is flagged
  -- here. Run whether or not the window is open, so a piece taken while it was shut is already at the far
  -- end by the time it opens: the move is done unseen instead of jumping the moment the bag appears.
  if Bags.newOnTop and not Bags.snap and Bags.ArrangeNew then Bags:ArrangeNew() end
  Bags:RefreshNewItems()
  if ns.Bank then ns.Bank:RefreshNewItems() end
end

local function onQuests(event, a1)
  if event == "QUEST_ACCEPTED" or a1 == "player" then
    Bags:RefreshQuests()
    if ns.Bank then ns.Bank:RefreshQuests() end
    refreshQuestRows()
  end
end

local function onRequirements()
  -- All four move the same verdicts: a level opens gear, a reputation or an arena rating
  -- closes it, and a spec change swaps which of it an item is built for. The red edge
  -- would otherwise keep saying no after the requirement has been met.
  ns.ClearUnusableCache()
  repaintSoon()
end

local function onWorldEntered()
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
end

local function onCastBegan()
  -- The moment a right-click puts an item-targeting spell on the cursor (a lockbox key, mill,
  -- prospect, disenchant), note the time. UNIT_SPELLCAST_SUCCEEDED below uses it to know the cast
  -- that just finished was one of ours worth refreshing after, without watching every cast.
  if ns.ItemTargeting() then lastItemSpell = GetTime() end
end

local function onCastEnded(_, a1)
  -- A lockbox opened by right-click, or a mill/prospect/disenchant, targets an item and the bag
  -- change lands a beat later than the cast. If our own click just put an item-targeting spell on
  -- the cursor, refresh once the cast reports done so #locked and counts do not sit stale until the
  -- delayed BAG_UPDATE. Only after a recent targeting cast, so ordinary casts cost nothing here.
  if a1 == "player" and (GetTime() - lastItemSpell) < 2 then
    lastItemSpell = 0
    repaintLater()
  end
end

local function onItemChanged(_, a1, a2)
  -- The link from before and after: a marked or locked piece keeps its entry through an upgrade, a
  -- gem or an enchant instead of being left on a key that is no longer there.
  if ns.Vendor and ns.Vendor.RetargetMarks then ns.Vendor:RetargetMarks(a1, a2) end
  repaintSoon()
  repaintLater()
end

local function onGearChanged()
  ns.Sets:Dirty()
  repaintSoon()
end

local function onBankOpened()
  ns.Sets:Dirty()
  -- A banker or the warband portal: the one moment the account bank is readable.
  ns.Vault:StampGold()
  if ns.Bank then ns.Bank.bankerOpen = true; ns.Bank:OnBankOpened() end
  autoOpenBags("bank")
end

local function onBankClosed()
  if ns.Bank then ns.Bank.bankerOpen = false; ns.Bank:OnBankClosed() end
  autoCloseBags("bank")
  -- Settle the grouped anti-jump freeze the bank interactions left: holes held in place while the
  -- banker was open (a deposit from the bags, a withdraw in the bank) relay into the packed order now.
  ns.RelayoutForSplit()
end

local function onProfessionsOpened()
  autoOpenBags("professions")
end

local function onProfessionsClosed()
  autoCloseBags("professions")
end

local function onInteractionOpened(_, a1)
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
end

local function onInteractionClosed(_, a1)
  local IT = Enum and Enum.PlayerInteractionType
  if ns.Bank and IT and (a1 == IT.AccountBanker or a1 == IT.Banker
     or a1 == IT.CharacterBanker) then
    -- Fallback close: BANKFRAME_CLOSED is dropped now and then and strands the window open and
    -- empty. bankerOpen gates this to a no-op once the normal close has run.
    if ns.Bank.bankerOpen then
      ns.Bank.bankerOpen = false
      ns.Bank:OnBankClosed()
      autoCloseBags("bank")
    else
      ns.Bank.acctBanker = nil
    end
  end
  local k = interactKey(a1)
  if k then autoCloseBags(k) end
  -- The window closed: fold the stacks back if Combine stacks is on.
  ns.RelayoutForSplit()
end

local function onBankSlots()
  if ns.Bank then ns.Bank:QueueRefresh() end
end

on.UI_SCALE_CHANGED = onScale
on.DISPLAY_SIZE_CHANGED = onScale
on.CVAR_UPDATE = onCvar
on.PLAYER_REGEN_ENABLED = onRegen
on.PLAYER_LOGIN = onLogin
on.BAG_UPDATE = onBagChanged
on.BAG_UPDATE_DELAYED = onBagsSettled
on.BAG_UPDATE_COOLDOWN = onCooldowns
on.PLAYER_MONEY = onMoney
on.ACCOUNT_MONEY = onMoney
on.ITEM_LOCK_CHANGED = onSlotLocked
on.BAG_NEW_ITEMS_UPDATED = onNewItems
on.QUEST_ACCEPTED = onQuests
on.UNIT_QUEST_LOG_CHANGED = onQuests
on.PLAYER_LEVEL_UP = onRequirements
on.SKILL_LINES_CHANGED = onRequirements
on.UPDATE_FACTION = onRequirements
on.PLAYER_SPECIALIZATION_CHANGED = onRequirements
on.PVP_RATING_UPDATE = onRequirements
on.PLAYER_ENTERING_WORLD = onWorldEntered
on.CURRENT_SPELL_CAST_CHANGED = onCastBegan
on.UNIT_SPELLCAST_SUCCEEDED = onCastEnded
on.ITEM_CHANGED = onItemChanged
on.EQUIPMENT_SETS_CHANGED = onGearChanged
on.EQUIPMENT_SWAP_FINISHED = onGearChanged
on.PLAYER_EQUIPMENT_CHANGED = onGearChanged
on.BANKFRAME_OPENED = onBankOpened
on.BANKFRAME_CLOSED = onBankClosed
on.TRADE_SKILL_SHOW = onProfessionsOpened
on.TRADE_SKILL_CLOSE = onProfessionsClosed
on.PLAYER_INTERACTION_MANAGER_FRAME_SHOW = onInteractionOpened
on.PLAYER_INTERACTION_MANAGER_FRAME_HIDE = onInteractionClosed
on.PLAYERBANKSLOTS_CHANGED = onBankSlots
on.PLAYERBANKBAGSLOTS_CHANGED = onBankSlots
on.PLAYERREAGENTBANKSLOTS_CHANGED = onBankSlots
on.REAGENTBANK_UPDATE = onBankSlots
on.BANK_TABS_CHANGED = onBankSlots
on.BANK_TAB_SETTINGS_UPDATED = onBankSlots
on.PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED = onBankSlots

ev:SetScript("OnEvent", function(_, event, a1, a2)
  local h = on[event]
  if h then h(event, a1, a2) end
end)

local cleared = {}
local function markCleared(tt)
  if cleared[tt] then return end
  cleared[tt] = true
  tt:HookScript("OnTooltipCleared", function(s) s.wpeCounted = nil end)
end

local function countLine(e, withBank)
  local bank = withBank and e.bank or 0
  local total = e.bags + bank
  if e.bags > 0 and bank > 0 then
    return (L["%d  (%d bags, %d bank)"]):format(total, e.bags, bank)
  elseif bank > 0 then
    return (L["%d  (bank)"]):format(bank)
  end
  return (L["%d  (bags)"]):format(e.bags)
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
  tt:AddLine(ns.TipInk(L["Inventory"], 1, 0.82, 0), 1, 0.82, 0)
  for _, e in ipairs(rows) do
    local col = e.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.class]
    local r, g, b = col and col.r or 1, col and col.g or 1, col and col.b or 1
    tt:AddDoubleLine(ns.TipInk(e.name, r, g, b), countLine(e, withBank), r, g, b, 1, 1, 1)
  end
  if wb > 0 then
    local r, g, b = ns.Theme:C("azure")
    tt:AddDoubleLine(ns.TipInk(L["Warband bank"], r, g, b), tostring(wb), r, g, b, 1, 1, 1)
  end
  tt:AddDoubleLine(ns.TipInk(L["Total"], 1, 0.82, 0), tostring(total), 1, 0.82, 0, 1, 1, 1)
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
    -- A pin is moved by dragging it to another cell, and that line stands above the clear line:
    -- the two actions a pinned cell offers are moving it and emptying it. The sale hint is left to
    -- the bag and bank cells, so the pin's own tooltip spends its lines on those two alone (an
    -- Alt-click on a pin still cycles the sale mark, it is just not promised here).
    tt:AddLine(ns.TipInk(L["Drag to reorder"], 0.9, 0.9, 0.9), 0.9, 0.9, 0.9)
    -- The key alone when there is one: it is the binding the player chose, and the middle
    -- click keeps working under it whether or not this line names it. With no key bound the
    -- middle click is the whole story, and it steps aside only if the player bound it.
    local name = ns.PinKeyName()
    local msg
    if name then
      msg = L["%s clears the slot"]:format(name)
    elseif (GetBindingAction("BUTTON3") or "") == "" then
      msg = L["Middle-click to clear the slot"]
    else
      msg = L["Bind a key to clear the slot"]
    end
      tt:AddLine(ns.TipInk(msg, 0.9, 0.9, 0.9), 0.9, 0.9, 0.9)
    drew = true
  end
  if ownSlot(tt) and not pinSlot(tt) then
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
      local msg
      if state == "lock" then
        msg = "Locked from sale. Alt + LMB to clear it"
      elseif state == "mark" then
        msg = "Marked for sale. Alt + LMB to lock it from sale"
      else
        msg = "Alt + LMB to mark it for sale"
      end
      if not drew then tt:AddLine(" ") end
      tt:AddLine(ns.TipInk(L[msg], 0.9, 0.9, 0.9), 0.9, 0.9, 0.9)
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
