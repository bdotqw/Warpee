local addonName, ns = ...
local Options = ns.Options
local H = Options and Options.helpers
if not H then return end

-- The page tables only. The window, the row factories and the flow helpers live in Options.lua, which
-- is listed right before this file, so everything they hand over is on the module table by the time
-- the aliases below run. Two files keep each main chunk clear of the compiler's 200 local limit.
local ANCHORS, ANCHOR_LABELS, ANGLE_KEYS, Bags = H.ANCHORS, H.ANCHOR_LABELS, H.ANGLE_KEYS, H.Bags
local L, STYLES, STYLE_LABELS, T = H.L, H.STYLES, H.STYLE_LABELS, H.T
local THEME_KEYS, Theme, angleGet, angleSet = H.THEME_KEYS, H.Theme, H.angleGet, H.angleSet
local autoField, bg, colsGet, colsSet = H.autoField, H.bg, H.colsGet, H.colsSet
local dbField, edgeGet, edgeSet, field = H.dbField, H.edgeGet, H.edgeSet, H.field
local flow, fontGet, fontKeys, fontSet = H.flow, H.fontGet, H.fontKeys, H.fontSet
local gapGet, gapSet, hideFieldsGet, hideFieldsSet = H.gapGet, H.gapSet, H.hideFieldsGet, H.hideFieldsSet
local localeGet, localeKeys, localeLabel, localeSet = H.localeGet, H.localeKeys, H.localeLabel, H.localeSet
local lockGet, lockSet, mergeGet, mergeSet = H.lockGet, H.lockSet, H.mergeGet, H.mergeSet
local mmHideGet, mmHideSet, onOf, pinHint = H.mmHideGet, H.mmHideSet, H.onOf, H.pinHint
local relayout, sClearGet, sClearSet, sLinkGet = H.relayout, H.sClearGet, H.sClearSet, H.sLinkGet
local sLinkSet, sizeGet, sizeSet, styleField = H.sLinkSet, H.sizeGet, H.sizeSet, H.styleField
local styleGet, styleSet, themeGet, themeLabel = H.styleGet, H.styleSet, H.themeGet, H.themeLabel
local themeSet, zoomGet, zoomSet = H.themeSet, H.zoomGet, H.zoomSet

local questGet, questSet     = styleField("questMarks")
local newGet, newSet         = styleField("newItemGlow")
local unusableGet, unusableSet = styleField("unusableBorder")
local function gridAlphaGet() return tonumber(WarpeeDB and WarpeeDB.gridAlpha) or 0 end
local function gridAlphaSet(v) WarpeeDB.gridAlpha = v; Theme:ApplyGridAlpha() end
local gaugeGet, gaugeSet     = field("showGauge")
local fav = {}
fav.showGet = function() return ns.Fav:Enabled() end
fav.showSet = function(v)
  WarpeeDB.favShow = v and true or false
  relayout()
end
fav.recentBagsGet = function() return ns.Recent and ns.Recent:BagsOn() end
fav.recentBagsSet = function(v)
  WarpeeDB.recentBags = v and true or false
  relayout()
end
fav.recentPocketGet = function() return ns.Recent and ns.Recent:PocketOn() end
fav.recentPocketSet = function(v)
  WarpeeDB.recentPocket = v and true or false
  relayout()
end
fav.pkGet = function() return ns.Pocket and ns.Pocket:Enabled() end
fav.pkSet = function(v)
  WarpeeDB.pocketShow = v and true or false
  if ns.Pocket then
    if v and WarpeeDB.pocketOpen then ns.Pocket:Open()
    else ns.Pocket:Apply() end
  end
  relayout()
end
fav.pkWithGet = function() return WarpeeDB.pocketWithBags ~= false end
fav.snapGet = function() return WarpeeDB.pocketSnap ~= false end
fav.snapSet = function(v) WarpeeDB.pocketSnap = v and true or false end
fav.pkWithSet = function(v)
  WarpeeDB.pocketWithBags = v and true or false
  if v and ns.Pocket and ns.Bags and ns.Bags.frame and ns.Bags.frame:IsShown()
     and not (ns.Pocket.frame and ns.Pocket.frame:IsShown()) then
    ns.Pocket:Open()
  end
  relayout()
end
fav.pkLockGet = function() return ns.Pocket and ns.Pocket:Locked() end
fav.pkLockSet = function(v)
  WarpeeDB.pocketLock = v and true or false
  if ns.Pocket then ns.Pocket:Apply() end
end
fav.pkRowsGet = function() return ns.Pocket and ns.Pocket:Rows() or 5 end
fav.pkRowsSet = function(v)
  WarpeeDB.pocketRows = tonumber(v) or 5
  if ns.Pocket then ns.Pocket:Refresh() end
end
fav.pkColsGet = function() return ns.Pocket and ns.Pocket:Cols() or 6 end
fav.pkColsSet = function(v)
  WarpeeDB.pocketCols = tonumber(v) or 6
  if ns.Pocket then ns.Pocket:Refresh() end
end
fav.pkSizeGet = function()
  return tonumber(WarpeeDB.pocketIconSize) or (Bags.iconSize or 40)
end
fav.pkSizeSet = function(v)
  WarpeeDB.pocketIconSize = tonumber(v) or 40
  ns.BumpCellSize()
  if ns.Pocket then ns.Pocket:Refresh() end
end
local lettersGet, lettersSet = field("goldLetters")
local onlyGet, onlySet       = field("goldOnly")

local GOLD_FORMATS = { "commas", "dots", "spaces", "short" }
local GOLD_FORMAT_LABELS = {
  commas = "Commas (5,000,000)",
  dots   = "Dots (5.000.000)",
  spaces = "Spaces (5 000 000)",
  short  = "Short (5M, 284.4K)",
}
local function goldFmtGet() return WarpeeDB.goldFormat or "commas" end
local function goldFmtSet(v) WarpeeDB.goldFormat = v; relayout() end
-- Drag-to-pin mode for the grouped view: whether dropping a piece on a section pins it there. Off keeps
-- the editor the only way to pin; Alt (the default) pins only while Alt is held, so a plain drag never
-- leaves a surprise pin; Always pins on every section drop.
local PIN_DRAG_MODES = { "off", "alt", "on" }
local PIN_DRAG_LABELS = {
  off = "Off",
  alt = "Hold Alt",
  on  = "Always",
}
local function pinDragGet() return WarpeeDB.catPinDrag or "alt" end
local function pinDragSet(v) WarpeeDB.catPinDrag = v end
local qColorGet, qColorSet   = styleField("qualityColorIlvl")
local qBorderGet, qBorderSet = styleField("qualityBorder")
local bankColsGet, bankColsSet = dbField("bankCols")
local wbColsGet, wbColsSet     = dbField("warbandCols")
local bankSizeGet, bankIconSizeSet = dbField("bankIconSize")
local function bankSizeSet(v) ns.BumpCellSize(); bankIconSizeSet(v) end
local wbSizeGet, wbIconSizeSet = dbField("warbandIconSize")
local function wbSizeSet(v) ns.BumpCellSize(); wbIconSizeSet(v) end

local function anchorKeys() return ANCHORS end
local function anchorLabel(k) return ANCHOR_LABELS[k] or k end

local aucGet, aucSet   = autoField("auction")
local bankGet, bankSet = autoField("bank")
local gbGet, gbSet     = autoField("guildbank")
local mailGet, mailSet = autoField("mail")
local profGet, profSet = autoField("professions")
local tradeGet, tradeSet = autoField("trade")
local vendGet, vendSet = autoField("vendor")
local upgGet, upgSet   = autoField("itemupgrade")
local cataGet, cataSet = autoField("catalyst")

-- One list, no subs: appearance first, then the addon's own switches, then money last under its heading.
-- Ten rows read as one screenful, so the strip would buy nothing here; the window behaviour moved out to
-- the Grid tab, where the bags it opens live.
local GENERAL_PAGE = {
  list = {
      { type = "select", name = "Theme", get = themeGet, set = themeSet,
        keys = function() return THEME_KEYS end, label = themeLabel,
        desc = "Color scheme for the whole addon." },
      { type = "select", name = "Slot background",
        get = styleGet, set = styleSet,
        keys = function() return STYLES end, label = function(k) return STYLE_LABELS[k] or k end,
        desc = "What sits behind every icon. Transparent shows the plate through the slot, Highlight lifts it out, Solid closes it off." },
      { type = "range", name = "Plate opacity", min = 0, max = 1, step = 0.01,
        get = gridAlphaGet, set = gridAlphaSet,
        desc = "The plate the items stand on, an extra surface over the window's own background. At 0 it is invisible and the window keeps its own background; raised, it covers the window from top to bottom, except the header a skin draws for itself." },
      { type = "select", name = "Language", get = localeGet, set = localeSet,
        keys = localeKeys, label = localeLabel,
        desc = "Language for the addon's own text. Item names always come from the game." },
      { type = "select", name = "Font", get = fontGet,
        set = function(v) fontSet(v); Options:ApplyFont() end,
        keys = fontKeys, label = function(k) return k end,
        desc = "Used for every label Warpee draws. Other addons can add to this list." },
      -- The bag windows' own search boxes, ahead of the lock that hangs the windows they search.
      { type = "toggle", name = "Clear search on close", col = 1, get = sClearGet, set = sClearSet,
        desc = "Empty the search box when the window closes, so it opens unfiltered next time." },
      { type = "toggle", name = "Search bags and bank together", col = 2, get = sLinkGet, set = sLinkSet,
        desc = "While both windows are open, typing in either box searches both at once." },
      { type = "toggle", name = "Hide minimap icon", get = mmHideGet, set = mmHideSet,
        desc = "Takes the Warpee button off the minimap." },
      { type = "header", name = "Money" },
      { type = "select", name = "Gold format", get = goldFmtGet, set = goldFmtSet,
        keys = function() return GOLD_FORMATS end, label = function(k) return GOLD_FORMAT_LABELS[k] or k end,
        desc = "Grouping for printed amounts. Short abbreviates to K and M." },
      { type = "toggle", name = "Gold only", col = 1, get = onlyGet, set = onlySet,
        desc = "Show gold only, hide silver and copper." },
      { type = "toggle", name = "Coin letters", col = 2, get = lettersGet, set = lettersSet,
        desc = "On = g/s/c letters. Off = coin icons." },
  },
}

local POCKET_PAGE = {
  { type = "toggle", name = "Pocket window", col = 1, get = fav.pkGet, set = fav.pkSet,
    desc = pinHint(
      "A small window of bookmark cells beside the bags, opened by the grid button in the header. Drag an item into a cell and the cell keeps it, wherever the item moves in your bags. Drag a cell onto another to swap them, and hovering a cell and pressing %s empties it.",
      "A small window of bookmark cells beside the bags, opened by the grid button in the header. Drag an item into a cell and the cell keeps it, wherever the item moves in your bags. Drag a cell onto another to swap them, and a cell under the pointer can be emptied with a key of its own." ) },
  { type = "toggle", name = "Open with bags", col = 2, get = fav.pkWithGet, set = fav.pkWithSet,
    disabled = function() return not fav.pkGet() end,
    desc = "The pocket opens together with the bags. A window that opens the bags on its own, the auction house or the mail, pushes the pocket aside until you open it yourself." },
  { type = "toggle", name = "Lock the pocket", col = 1,
    get = fav.pkLockGet, set = fav.pkLockSet,
    disabled = function() return not fav.pkGet() end,
    desc = "Keep the pocket where it is. Unlocked, the arrows along its bottom edge nudge it around." },
  { type = "toggle", name = "Snap to windows", col = 2,
    get = fav.snapGet, set = fav.snapSet,
    disabled = function() return not fav.pkGet() end,
    desc = "Dropped close to the bags or the bank, the pocket lines up against it and holds that seam when the other window changes size. Dragging the bags never carries the pocket along." },
  { type = "toggle", name = "Recent in the pocket",
    get = fav.recentPocketGet, set = fav.recentPocketSet,
    disabled = function() return not fav.pkGet() end,
    desc = "A row above the pocket cells holding what came into your bags this session, apart from gray items. It is the same list the bag window shows, so clearing it in one window clears it in the other." },
  { type = "select", name = "Pocket growth corner",
    get = function() return angleGet("pocketPos") end,
    set = function(v) angleSet("pocketPos", v) end,
    keys = function() return ANGLE_KEYS end, label = anchorLabel,
    disabled = function() return not fav.pkGet() end,
    desc = "The corner the pocket hangs from. Snapping it against another window sets this by itself." },
  { type = "keybind", name = "Pocket key", binding = "WARPEE_POCKET",
    disabled = function() return not fav.pkGet() end,
    desc = "The key that opens and closes the pocket. Click, then press a key, a mouse button or the wheel, with Shift, Ctrl or Alt if you like; a right click clears it, Escape cancels." },
  { type = "header", name = "Pocket size", key = "pocketsize" },
  { type = "range", name = "Pocket rows", min = 1, max = 6, step = 1, half = "left",
    section = "pocketsize",
    get = fav.pkRowsGet, set = fav.pkRowsSet,
    disabled = function() return not fav.pkGet() end,
    desc = "How many rows of cells the pocket window holds." },
  { type = "range", name = "Pocket slots per row", min = 4, max = 8, step = 1, half = "right",
    section = "pocketsize",
    get = fav.pkColsGet, set = fav.pkColsSet,
    disabled = function() return not fav.pkGet() end,
    desc = "How wide the pocket window grows." },
  { type = "range", name = "Pocket slot size", min = 24, max = 56, step = 1,
    section = "pocketsize",
    get = fav.pkSizeGet, set = fav.pkSizeSet,
    disabled = function() return not fav.pkGet() end,
    desc = "Size of one cell in the pocket. It follows the bag slot size until you move this." },
}

local ITEMS_PAGE = {
  subs = {
    { name = "Markers", list = {
  { type = "toggle", name = "Reagent border", col = 1,
    get = function() return Bags.reagentTint end,
    set = function(v)
      Bags.reagentTint = v
      WarpeeDB.reagentTint = v
      Bags.styleGen = (Bags.styleGen or 0) + 1
      relayout()
    end,
    desc = "Tint the slots of the reagent bag and the reagent bank." },
  { type = "toggle", name = "Quality border", col = 2, get = qBorderGet, set = qBorderSet,
    desc = "A border around each item in its quality color. Items tied to a quest take the quest yellow instead, the color of the exclamation mark. The reagent and unwearable borders come first." },
  { type = "toggle", name = "Quest marker", col = 1, get = questGet, set = questSet,
    desc = "The exclamation mark on items for quests you have not picked up yet. Not shown in the warband bank." },
  { type = "toggle", name = "New item glow", col = 2, get = newGet, set = newSet,
    desc = "Quality-colored glow on items the game still counts as new." },
  { type = "toggle", name = "Item level by quality", col = 1, get = qColorGet, set = qColorSet,
    disabled = function() return not ns.Badge("ilvl").on end,
    desc = "Tint the item level number with the item's quality color." },
  { type = "toggle", name = "Unwearable border", col = 2, get = unusableGet, set = unusableSet,
    desc = "Red border around gear your character cannot wear." },
  { type = "range", name = "Border thickness", min = 1, max = 6, step = 1,
    get = edgeGet, set = edgeSet,
    desc = "Thickness of the slot border." },
    } },
    { name = "Badges", list = {
  { type = "badges", section = "badges",
    desc = "Drag a badge, or click where you want it. Left-click a name to show that badge, right-click the name to hide it." },
  { type = "toggle", name = "Show only the selected badge", col = 1, section = "badges",
    get = bg.soloGet, set = bg.soloSet,
    desc = "In the cell above, hide every badge except the selected one." },
  { type = "select", col = 2, section = "badges", get = bg.aGet, set = bg.aSet,
    keys = bg.alignKeys, label = bg.alignLabel, hidden = bg.isTex,
    desc = "Growth direction: which way the badge grows when the value gets longer." },
  { type = "select", name = "Corner", get = bg.cGet, set = bg.cSet, section = "badges",
    keys = anchorKeys, label = anchorLabel,
    desc = "Which corner of the slot the badge is pinned to." },
  { type = "range", name = "X offset", min = -56, max = 56, step = 1, section = "badges",
    get = bg.xGet, set = bg.xSet, half = "left" },
  { type = "range", name = "Y offset", min = -56, max = 56, step = 1, section = "badges",
    get = bg.yGet, set = bg.ySet, half = "right" },
  { type = "range", name = "Text size", min = 6, max = 24, step = 1, section = "badges",
    get = bg.sGet, set = bg.sSet, hidden = bg.isTex },
  { type = "range", name = "Badge scale", min = 0.2, max = 1, step = 0.02, section = "badges",
    get = bg.sGet, set = bg.sSet, hidden = bg.isText },
  { type = "range", name = "Letters", min = 2, max = 8, step = 1, section = "badges",
    get = bg.kGet, set = bg.kSet, hidden = bg.notFit,
    desc = "How many letters of the set name to show." },
  { type = "header", name = "Badge order", key = "badgeorder" },
  { type = "description", section = "badgeorder",
    name = "The badge at the top of the list draws over the ones below it. The stack count always stays at the bottom." },
  { type = "badgeorder", section = "badgeorder" },
    } },
  },
}

-- The three windows an option on this page can apply to, in the order they stand in the menu. The bags
-- are one entry because the bag window is one grid; the character bank and the Warband bank answer for
-- themselves, since either can be drawn as blocks or named without the other.
local SURFACES = { "bags", "bank", "warband" }
-- The grouped view cannot offer the Warband bank on its own: the bank reads one flag for both of its tab
-- sets, because the window shows either behind its mode picker, and a third tick here would be a switch the
-- game has nothing to answer. So this row asks about the bags and the bank, and the bank's tick covers every
-- tab the bank window can show.
local VIEW_SURFACES = { "bags", "bank" }
local SURFACE_WORDS = { bags = "Bags", bank = "Bank", warband = "Warband" }

-- A window drawing sections has nothing to split into blocks or to name, so the block rows drop its box
-- while it is grouped. The Warband tab answers to the bank's flag, since the bank window shows either of
-- its tab sets behind one mode picker.
local function grouped(k)
  if k == "bags" then return flow.catGet() end
  return flow.bankCatGet()
end

-- One row that asks which windows an option covers instead of carrying a checkbox for each: the menu keeps
-- its own set of ticks and stays open while they are picked, and the row reads the set back on its face.
-- `disable` greys the row where the option has nothing to act on, taken per row rather than per surface,
-- since one row now answers for every window at once; the row keeps its place so the group keeps its shape.
-- The grouped-view row carries no gate, so the way back out of a grouped pair of windows never sits behind
-- the very state it set.
local function surfaceRow(name, surfaces, desc, getters, setters, disable, off)
  -- The windows this row can still act on. A window that draws sections has no blocks to split and no names
  -- to put over them, so its box is not offered: a tick that does nothing is worse than no tick at all.
  -- With every window out of play the list is left whole, because the row is greyed by then and an empty
  -- menu reads as broken rather than as inapplicable.
  local function offered()
    if not off then return surfaces end
    local out = {}
    for i = 1, #surfaces do
      local k = surfaces[i]
      if not off(k) then out[#out + 1] = k end
    end
    return #out > 0 and out or surfaces
  end
  return {
    type = "select", name = name, multi = true, desc = desc,
    disabled = disable,
    keys = offered,
    label = function(k) return SURFACE_WORDS[k] end,
    isOn = function(k) return getters[k]() end,
    toggle = function(k)
      setters[k](not getters[k]())
      -- The rest of the page answers to these sets, the gap slider and the order pair among them, so one
      -- more row pass lets them follow the tick. A row pass and not a reflow: the list stays open for the
      -- next tick and the page keeps the scroll it had.
      Options:RefreshSoon()
    end,
    summary = function()
      -- A greyed row acts on nothing, so its face says Off rather than the saved ticks: those stay stored
      -- and come back when the windows ungroup, but while grouped they are not what the row does.
      if disable and disable() then return T("Off") end
      local out = {}
      local list = offered()
      for i = 1, #list do
        local k = list[i]
        if getters[k]() then out[#out + 1] = T(SURFACE_WORDS[k]) end
      end
      return #out > 0 and table.concat(out, ", ") or T("Off")
    end,
  }
end

local SPLIT_ON  = { bags = flow.splitGet, bank = flow.splitBankGet, warband = flow.splitWbGet }
local SPLIT_SET = { bags = flow.splitSet, bank = flow.splitBankSet, warband = flow.splitWbSet }
local NAME_ON   = { bags = flow.nameBagsGet, bank = flow.nameBankGet, warband = flow.nameWbGet }
local NAME_SET  = { bags = flow.nameBagsSet, bank = flow.nameBankSet, warband = flow.nameWbSet }
local VIEW_ON   = { bags = flow.catGet, bank = flow.bankCatGet }
local VIEW_SET  = { bags = flow.catSet, bank = flow.bankCatSet }

-- A window without split has no blocks to name, so the names row drops its box the way the block rows
-- drop grouped windows; with split off everywhere the row greys out whole. Ticks stay stored throughout
-- and come back with the split, the same as with grouping.
local function unsplit(k)
  if grouped(k) then return true end
  local f = SPLIT_ON[k]
  return not (f and f())
end
local function namesGone()
  if flow.gridGone() then return true end
  return not ((SPLIT_ON.bags and SPLIT_ON.bags())
    or (SPLIT_ON.bank and SPLIT_ON.bank())
    or (SPLIT_ON.warband and SPLIT_ON.warband()))
end

local GRID_PAGE = {
  subs = {
    { name = "Layout", list = {
      -- No heading over the block: every other sub opens on its rows, and a heading naming the whole page
      -- would only repeat the tab. "Grid order" below keeps its own, since it names a group, not the page.
      surfaceRow("Category view", VIEW_SURFACES,
        "Lay the containers out in labelled sections instead of one grid: equipment, consumables, reagents and the rest, with anything left over under Other. Tick each window you want it in.",
        VIEW_ON, VIEW_SET),
      surfaceRow("Separate bags and tabs", SURFACES,
        "Draw every bag and every bank tab on its own, with a gap between them, in the windows you tick. The reagent bag stands apart already and joins the row of blocks with the bags; one merged into them is separated again the moment the banks go on.",
        SPLIT_ON, SPLIT_SET, flow.gridGone, grouped),
      surfaceRow("Name bags and tabs", SURFACES,
        "Name each one over its cells with the bag or tab it holds, in the windows you tick. A name needs them drawn apart: a window left as one grid has nothing to name, and its gap does the separating alone.",
        NAME_ON, NAME_SET, namesGone, unsplit),
      { type = "divider" },
      { type = "range", name = "Bags gap", min = flow.splitGapBagsMin, max = 40, step = 1,
        get = flow.splitGapBagsGet, set = flow.splitGapBagsSet,
        disabled = function() return (not Bags.splitBags) or flow.catGet() end, col = 1, of = 3,
        desc = "The space between one bag and the next. A bag that shows its name needs room for it, so the slider starts at that room rather than moving through values no block can stand at." },
      { type = "range", name = "Bank gap", min = flow.splitGapBankMin, max = 40, step = 1,
        get = flow.splitGapBankGet, set = flow.splitGapBankSet,
        disabled = function() return (not Bags.splitBank) or flow.bankCatGet() end,
        col = 2, of = 3,
        desc = "The space between one bank tab and the next in the character bank. It starts at the room a name takes while that window draws its names." },
      { type = "range", name = "Warband gap", min = flow.splitGapWbMin, max = 40, step = 1,
        get = flow.splitGapWbGet, set = flow.splitGapWbSet,
        disabled = function() return (not Bags.splitWb) or flow.bankCatGet() end,
        col = 3, of = 3,
        desc = "The space between one tab and the next in the Warband bank. It starts at the room a name takes while that window draws its names." },
      -- Cell rendering for every grid, beside the block gaps above: the spacing between slots and the
      -- zoom inside them. One taste for all windows, so a single pair on the cross-window list rather
      -- than one per window; sizes stay per window because tab counts dictate them.
      { type = "range", name = "Slot spacing", min = 0, max = 16, step = 1, get = gapGet, set = gapSet,
        half = "left", desc = "Gap between slots, in every grid." },
      { type = "range", name = "Icon zoom", min = 0.8, max = 1.2, step = 0.01,
        get = zoomGet, set = zoomSet, half = "right",
        desc = "1.00 fills the slot. Less shrinks the icon, more crops it." },
      { type = "divider" },
      -- The windows' place on the screen: the lock holds both windows at once, so it stands on the
      -- cross-window list beside the corners that hang each of them, not on a window's own list.
      { type = "toggle", name = "Lock bags and bank", col = 1, get = lockGet, set = lockSet,
        desc = "Freeze the bags and the bank in place. Unlocked, they show X/Y fields along their bottom edge. Type a value, or nudge with the arrows (Shift = 10)." },
      { type = "toggle", name = "Hide X/Y fields", col = 2, get = hideFieldsGet, set = hideFieldsSet,
        disabled = function() return lockGet() end,
        desc = "The windows stay movable by dragging, but the X/Y fields are not drawn." },
      -- The order the plain grid draws in, with no window of its own to belong to: both grids read it, so the
      -- rows grey out only when neither is left to arrange. With the split on, each block turns over on its own.
      -- Everything under it re-sorts cells: the lock pair above hangs the windows, it does not arrange them.
      { type = "header", name = "Grid order",
        state = function()
          -- One pair of switches read by both plain grids, so the row says which grids those still are:
          -- a grouped window draws sections, and nothing here reaches it.
          local out = {}
          if not flow.catGet() then out[#out + 1] = T("Bags") end
          if not flow.bankCatGet() then out[#out + 1] = T("Bank") end
          return #out > 0 and table.concat(out, ", ") or nil
        end },
      { type = "toggle", name = "Fill grid upwards", col = 1, of = 2,
        get = flow.upGet, set = flow.upSet, disabled = flow.gridGone,
        desc = "The rows of cells stack from the bottom edge up, so the part-filled last row sits at the top." },
      { type = "toggle", name = "Reverse slot order", col = 2, of = 2,
        get = flow.revGet, set = flow.revSet, disabled = flow.gridGone,
        desc = "The bag slots run backwards, so the last slot of the last bag takes the first cell. Nothing moves inside your bags, only the order the slots are drawn in." },
    } },
    { name = "Bags", list = {
      { type = "range", name = "Slot size", min = 24, max = 56, step = 1, get = sizeGet, set = sizeSet,
        half = "left", desc = "Size of one slot in the bags." },
      { type = "range", name = "Slots per row", min = 6, max = 24, step = 1, get = colsGet, set = colsSet,
        half = "right", desc = "How wide the bag window grows." },
      { type = "header", name = "Window" },
      -- The window's own furniture, ahead of the reagent block that follows it: the bar in the header, the
      -- two rows over the grid, the key that clears a cell in one of them, and the corner it hangs from. The
      -- corner moved here from the General page, where it stood among the addon's own switches, away from the
      -- window it moves; the pocket has always kept its corner on its own page, and these follow it.
      -- New arrivals open the group: alone between the slider pairs and the heading it broke the rhythm, and
      -- the heading collects it.
      { type = "toggle", name = "Keep new items apart", col = 1,
        get = flow.newTopGet, set = flow.newTopSet, disabled = flow.catGet,
        desc = "Items that just arrived are kept apart from the rest of your bags, so you can see what is new at a glance. Using an item or pressing sort returns everything to the ordinary order. Only the drawing order changes, nothing moves inside your bags." },
      { type = "toggle", name = "Capacity bar", col = 2, get = gaugeGet, set = gaugeSet,
        desc = "Fill bar in the bags header showing how full they are." },
      { type = "toggle", name = "Recent in bags", col = 1,
        get = fav.recentBagsGet, set = fav.recentBagsSet,
        desc = "A row above the favorites holding what came into your bags this session, apart from gray items. Each arrival takes the first free cell, the oldest one leaves when the row is full, and the row clears on logout or a reload." },
      { type = "toggle", name = "Favorite slots", col = 2, get = fav.showGet, set = fav.showSet,
        desc = pinHint(
          "A row of slots above the grid, always in sight. Drag an item onto one to keep it a click away; hovering a slot and pressing %s clears it.",
          "A row of slots above the grid, always in sight. Drag an item onto one to keep it a click away; a slot under the pointer can be cleared with a key of its own." ) },
      { type = "keybind", name = "Clear the cell", binding = "WARPEE_UNPIN",
        desc = "The key that empties a favorite or pocket cell under the pointer. Click, then press a key, a mouse button or the wheel; a right click clears it, Escape cancels." },
      { type = "select", name = "Bags growth corner",
        get = function() return angleGet("pos") end,
        set = function(v) angleSet("pos", v) end,
        keys = anchorKeys, label = anchorLabel,
        desc = "The corner of the screen the bag window hangs from. It grows away from that corner as your bags fill." },
      -- Where the reagent bag sits, under the window it belongs to. Every row here greys out in the grouped
      -- view, which files the reagent slots by category instead, so the subhead stays and still names them.
      { type = "header", name = "Reagents" },
      { type = "toggle", name = "Hide reagents", col = 1, of = 2,
        get = flow.hideGet, set = flow.hideSet, disabled = flow.catGet,
        desc = "Leave the reagent bag out of the window. Its slots still count in the header, and reagents still go into it." },
      { type = "toggle", name = "Merge reagents", col = 2, of = 2, get = mergeGet, set = mergeSet,
        disabled = function() return flow.noMerge() or flow.catGet() end,
        desc = "Lay the reagent bag out with the main bags, without its caption." },
      { type = "toggle", name = "Reagents on top",
        get = flow.topGet, set = flow.topSet, disabled = function() return flow.offGet() or flow.catGet() end,
        desc = "Draw the reagent bag above the main bags instead of below them." },
    } },
    -- The bank's own numbers, apart from the bags: each of its two tab sets keeps its own width and its own
    -- icon size, since the character bank and the Warband bank hold different counts and are looked at at
    -- different times. One group, so no heading and no paragraph: the tab above names the page, the paired rows
    -- say which of the two banks each belongs to, and the corner row says where the window hangs.
    { name = "Bank", list = {
      { type = "range", name = "Bank slot size", min = 24, max = 56, step = 1,        get = bankSizeGet, set = bankSizeSet,
        half = "left" },
      { type = "range", name = "Warband slot size", min = 24, max = 56, step = 1,
        get = wbSizeGet, set = wbSizeSet, half = "right" },
      -- The window's place on the screen, ahead of the shape: a corner belongs to one window and answers to the tab above,
      -- not to the shape below it. The lock holding both windows stands on the Layout list.
      { type = "select", name = "Bank growth corner",
        get = function() return angleGet("bankPos") end,
        set = function(v) angleSet("bankPos", v) end,
        keys = anchorKeys, label = anchorLabel,
        desc = "The corner of the screen the bank window hangs from. It grows away from that corner as the tabs fill." },
      { type = "header", name = "Grid shape" },
      { type = "range", name = "Bank slots per row", min = 8, max = 40, step = 1,
        get = bankColsGet, set = bankColsSet, half = "left" },
      { type = "range", name = "Warband slots per row", min = 8, max = 40, step = 1,
        get = wbColsGet, set = wbColsSet, half = "right" },
    } },
    -- When the bags open on their own: beside the lock and the search pair that answer for the windows,
    -- and away from the addon's own switches.
    { name = "Auto-open bags", list = {
      { type = "description",
        name = "The bags open together with these windows and close with them again." },
      -- Paired by kind down each row: the two banks, then mail and the auction house, then the two
      -- face-to-face windows, then the two item stations. Professions trails alone.
      { type = "toggle", name = "Bank", col = 1, get = bankGet, set = bankSet },
      { type = "toggle", name = "Guild bank", col = 2, get = gbGet, set = gbSet },
      { type = "toggle", name = "Mail", col = 1, get = mailGet, set = mailSet },
      { type = "toggle", name = "Auction house", col = 2,
        get = aucGet, set = aucSet },
      { type = "toggle", name = "Vendor", col = 1, get = vendGet, set = vendSet },
      { type = "toggle", name = "Trade", col = 2,
        get = tradeGet, set = tradeSet },
      -- The Revival Catalyst window has no stable global string, so "Catalyst" is a Warpee key; the Item
      -- Upgrade window keeps one too, translated from the upgrader's own title, so the row reads the same in
      -- every client and the search index sees a plain label.
      { type = "toggle", name = "Item Upgrade", col = 1,
        get = upgGet, set = upgSet },
      { type = "toggle", name = "Catalyst", col = 2, get = cataGet, set = cataSet },
      { type = "toggle", name = "Professions", col = 1,
        get = profGet, set = profSet },
    } },
  },
}

local function tipOnGet() return WarpeeDB.tipCounts ~= false end
local function tipOnSet(v) WarpeeDB.tipCounts = v and true or false end
local function tipBankGet() return WarpeeDB.tipBank ~= false end
local function tipBankSet(v) WarpeeDB.tipBank = v and true or false end
local function tipWbGet() return WarpeeDB.tipWarband ~= false end
local function tipWbSet(v) WarpeeDB.tipWarband = v and true or false end
local function tipGoldGet() return WarpeeDB.tipGold ~= false end
local function tipGoldSet(v) WarpeeDB.tipGold = v and true or false end
local function tipOff() return not tipOnGet() end

local snap = {}
snap.bagsGet = function() return WarpeeDB.keepBags ~= false end
snap.bagsSet = function(v) WarpeeDB.keepBags = v and true or false; relayout() end
snap.bankGet = function() return WarpeeDB.keepBank ~= false end
snap.bankSet = function(v) WarpeeDB.keepBank = v and true or false; relayout() end
snap.wbGet = function() return WarpeeDB.keepWarband ~= false end
snap.wbSet = function(v) WarpeeDB.keepWarband = v and true or false; relayout() end

local CHARS_PAGE = {
  { type = "header", name = "Tooltips",
    state = function() return onOf({ tipOnGet, tipBankGet, tipWbGet, tipGoldGet }) end },
  { type = "toggle", name = "Count across characters", col = 1, get = tipOnGet, set = tipOnSet,
    desc = "Adds an Inventory block to item tooltips: how many each character carries." },
  { type = "toggle", name = "Include bank", col = 2, get = tipBankGet, set = tipBankSet,
    disabled = tipOff,
    desc = "Count each character's bank too. Off = bags only." },
  { type = "toggle", name = "Include Warband", col = 1, get = tipWbGet, set = tipWbSet,
    disabled = tipOff,
    desc = "Count the shared Warband bank on its own line." },
  { type = "toggle", name = "Gold tooltip", col = 2, get = tipGoldGet, set = tipGoldSet,
    desc = "Gold tooltip over the money in the window corner: every character's gold, the Warband bank, the total and the WoW Token price." },
  { type = "header", name = "Snapshots",
    state = function() return onOf({ snap.bagsGet, snap.bankGet, snap.wbGet }) end },
  { type = "description",
    name = "Copies of what you carry, so another character's bags and bank open from your own window." },
  { type = "toggle", name = "Remember bags", col = 1, get = snap.bagsGet, set = snap.bagsSet,
    desc = "Save this character's bags and gold whenever the bag window opens. Off = the saved copy stops updating, and stays visible until you delete the character below." },
  { type = "toggle", name = "Remember bank", col = 2, get = snap.bankGet, set = snap.bankSet,
    desc = "Save the character bank while you stand at a banker." },
  { type = "toggle", name = "Remember Warband bank", col = 1, get = snap.wbGet, set = snap.wbSet,
    desc = "Save the shared Warband bank while you stand at a banker." },
  { type = "header", name = "Characters" },
  { type = "description",
    name = "Unchecked characters stay saved but are hidden from the character list." },
  { type = "chars" },
}

local function vIlvlGet() return tonumber(WarpeeDB.vendorIlvl) or 0 end
local function vIlvlSet(v)
  WarpeeDB.vendorIlvl = tonumber(v) or 0
  if Bags and Bags.VendorState then Bags:VendorState() end
end
local V = {}
function V.boeGet() return WarpeeDB.vendorKeepBoE ~= false end
function V.boeSet(v) WarpeeDB.vendorKeepBoE = v and true or false end
function V.wbGet() return WarpeeDB.vendorKeepWarbound ~= false end
function V.wbSet(v) WarpeeDB.vendorKeepWarbound = v and true or false end
function V.gemGet() return WarpeeDB.vendorKeepGems ~= false end
function V.gemSet(v) WarpeeDB.vendorKeepGems = v and true or false end
function V.greyGet() return WarpeeDB.vendorGrey ~= false end
function V.greySet(v) WarpeeDB.vendorGrey = v and true or false end
function V.repGet() return WarpeeDB.vendorRepair and true or false end
function V.repSet(v) WarpeeDB.vendorRepair = v and true or false end
V.REPAIR_BY = { "player", "guild", "both" }
V.REPAIR_LABELS = { player = "Your gold", guild = "Guild bank",
                    both = "Guild / Yours" }
function V.repByGet() return WarpeeDB.vendorRepairBy or "player" end
function V.repBySet(v) WarpeeDB.vendorRepairBy = v or "player" end
function V.relicGet() return WarpeeDB.vendorRelics ~= false end
function V.relicSet(v) WarpeeDB.vendorRelics = v and true or false end

function V.minGet() return tonumber(WarpeeDB.vendorIlvlMin) or 0 end
function V.minSet(v) WarpeeDB.vendorIlvlMin = tonumber(v) or 0 end
function V.consumGet() return WarpeeDB.vendorConsum and true or false end
function V.consumSet(v) WarpeeDB.vendorConsum = v and true or false end
function V.autoGet() return WarpeeDB.vendorAuto and true or false end
function V.autoSet(v) WarpeeDB.vendorAuto = v and true or false end
function V.tokenGet() return WarpeeDB.vendorTokens and true or false end
function V.tokenSet(v) WarpeeDB.vendorTokens = v and true or false end
function V.tokensOff() return not (WarpeeDB.vendorTokens and true or false) end
function V.expGet(i)
  local t = WarpeeDB.vendorTokenExp
  return (t and t[i]) and true or false
end
function V.expSet(i, v)
  WarpeeDB.vendorTokenExp = WarpeeDB.vendorTokenExp or {}
  WarpeeDB.vendorTokenExp[i] = v and true or false
end
function V.expName(i)
  local n = _G["EXPANSION_NAME" .. i]
  if type(n) == "string" and n ~= "" then return n end
  return "Expansion " .. i
end

local VENDOR_PAGE = {
  { type = "header", name = "Runs on its own" },
  { type = "description",
    name = "These start when a merchant window opens, with no click from you." },
  { type = "toggle", name = "Sell junk", col = 1, of = 3, get = V.greyGet, set = V.greySet,
    desc = "Sell every gray item, whatever its item level." },
  { type = "toggle", name = "Repair", col = 2, of = 3, get = V.repGet, set = V.repSet,
    desc = "Repair at merchants who offer it. Others are left alone, with no message." },
  { type = "select", name = "Pay with", col = 3, of = 3, get = V.repByGet, set = V.repBySet,
    keys = function() return V.REPAIR_BY end,
    label = function(k) return T(V.REPAIR_LABELS[k] or k) end,
    disabled = function() return not V.repGet() end,
    desc = "Where the repair money comes from. The guild bank is used only if your withdraw limit covers the whole bill." },
  { type = "header", name = "The coin button",
    state = function()
      local min, max = V.minGet(), vIlvlGet()
      if max > 0 and min >= max then return L["Invalid range"] end
      if not V.autoGet() then return nil end
      local parts = {}
      -- Through L, like the line below, or the range reads in English inside a translated
      -- header and the three keys have nowhere to be translated to.
      if min > 0 and max > 0 then parts[#parts + 1] = (L["ilvl %d-%d"]):format(min, max)
      elseif min > 0 then parts[#parts + 1] = (L["ilvl %d+"]):format(min)
      elseif max > 0 then parts[#parts + 1] = (L["ilvl <%d"]):format(max) end
      if V.greyGet() then parts[#parts + 1] = T("Sell junk") end
      if V.relicGet() then parts[#parts + 1] = T("Legion relics") end
      if V.consumGet() then parts[#parts + 1] = T("Old consumables") end
      if V.tokenGet() then parts[#parts + 1] = T("Tier tokens") end
      if #parts == 0 then return nil end
      if #parts > 4 then
        local short = { parts[1], parts[2], parts[3], "..." }
        return table.concat(short, ", ")
      end
      return table.concat(parts, ", ")
    end },
  { type = "description",
    name = "Everything below is sold by the coin in the bags header, unless you switch on automatic selling." },
  { type = "input", name = "Item level from", col = 1, min = 0, max = 9999,
    get = V.minGet, set = V.minSet,
    desc = "Gear at or above this item level is sold." },
  { type = "input", name = "Item level under", col = 2, min = 0, max = 9999,
    get = vIlvlGet, set = vIlvlSet,
    desc = "Gear under this item level is sold. Zero keeps every piece." },
  { type = "toggle", name = "Legion relics", col = 1, get = V.relicGet, set = V.relicSet,
    desc = "Sell Legion artifact relics. Item level ignored." },
  { type = "toggle", name = "Old consumables", col = 2, get = V.consumGet, set = V.consumSet,
    desc = "Sell potions, flasks, food and bandages older than the previous expansion." },
  { type = "toggle", name = "Tier tokens", col = 1, get = V.tokenGet, set = V.tokenSet,
    desc = "Sell raid armor tokens, item level ignored. Only from the expansions ticked below." },
  { type = "toggle", name = "Sell all of this automatically",
    get = V.autoGet, set = V.autoSet,
    desc = "Sell the list above at every merchant, without pressing the coin." },
  { type = "header", name = "Token expansions", key = "tokenexp",
    state = function()
      if V.tokensOff() then return L["Off"] end
      local t = WarpeeDB.vendorTokenExp or {}
      local none = ns.TOKEN_EXP_NONE or {}
      local cur = LE_EXPANSION_LEVEL_CURRENT
                  or (GetExpansionLevel and GetExpansionLevel()) or 0
      local n, all = 0, 0
      for i = 0, cur do
        if not none[i] then
          all = all + 1
          if t[i] then n = n + 1 end
        end
      end
      return (L["%d of %d"]):format(n, all)
    end },
  { type = "description", section = "tokenexp",
    name = "Which expansions tokens may be sold from. The four newest are kept by default. Expansions that never had tokens are not listed." },
  { type = "header", name = "Never sell",
    state = function() return onOf({ V.boeGet, V.wbGet, V.gemGet }) end },
  { type = "toggle", name = "Keep BoE", col = 1, get = V.boeGet, set = V.boeSet,
    desc = "Skip gear that is not bound yet, so it can go to the auction house." },
  { type = "toggle", name = "Keep warbound", col = 2, get = V.wbGet, set = V.wbSet,
    desc = "Skip warbound gear, since an alt can still use it." },
  { type = "toggle", name = "Keep socketed or enchanted", col = 1, get = V.gemGet, set = V.gemSet,
    desc = "Skip any piece with a gem socketed or an enchant applied." },
  { type = "header", name = "Marked for sale", key = "sellmarks",
    state = function() return ns.LN("%d items", (ns.Vendor and ns.Vendor:SellCount()) or 0) end },
  { type = "description", section = "sellmarks",
    name = "ALT-click an item to mark it for sale: a coin appears, and it is sold at the next merchant who buys wares. A second click locks it from sale, a third clears it. Works in the bags, the bank, the favorites row and the pocket." },
  { type = "selllist", section = "sellmarks" },
}

do
  local cur = LE_EXPANSION_LEVEL_CURRENT
              or (GetExpansionLevel and GetExpansionLevel()) or 0
  local at
  for i, row in ipairs(VENDOR_PAGE) do
    if row.type == "description" and row.section == "tokenexp" then at = i + 1; break end
  end
  local rows = {}
  local none = ns.TOKEN_EXP_NONE or {}
  local slot = 0
  for i = 0, cur do
    if not none[i] then
      rows[#rows + 1] = {
        type = "toggle", name = V.expName(i), col = (slot % 2 == 0) and 1 or 2,
        section = "tokenexp",
        get = function() return V.expGet(i) end,
        set = function(v) V.expSet(i, v) end,
        disabled = V.tokensOff,
        desc = "Sell tier tokens from this expansion.",
      }
      slot = slot + 1
    end
  end
  if at then
    for k = #rows, 1, -1 do table.insert(VENDOR_PAGE, at, rows[k]) end
  end
end

-- What the grouped view does and how tight it stands, ahead of the editor: the switch that turns the view
-- on stays in Grid > Layout with the rest of how a window is drawn, and everything the view then does is
-- settled here, beside the categories it acts on.
local CATS_PAGE = {
  -- The same name the switch carries over in Grid, where the row that turns the view on stands, so the
  -- player who met the feature there meets the same words here.
  { type = "header", name = "Category view" },
  { type = "toggle", name = "Combine stacks",
    get = function() return WarpeeDB and WarpeeDB.catCombine end,
    set = function(v)
      WarpeeDB.catCombine = v
      if ns.Bank and ns.Bank.Refresh then ns.Bank:Refresh() end
      relayout()
    end,
    disabled = flow.noCat,
    desc = "Show several stacks of one item as a single cell with the total. This only changes how they look; the items stay in their own bag slots. Gear, pets and keystones stay one cell each." },
  { type = "select", name = "Drag to pin",
    get = pinDragGet, set = pinDragSet,
    keys = function() return PIN_DRAG_MODES end, label = function(k) return PIN_DRAG_LABELS[k] or k end,
    disabled = flow.noCat,
    desc = "Drag an item onto a category in the category view to pin it there. Hold Alt pins only while Alt is held, so an ordinary drag never leaves a surprise pin. Off leaves pinning to the editor. A drop on the category the rules already choose unpins instead." },
  -- Each spacing reads the density gap while unset, so the slider opens on the value already in use.
  { type = "range", name = "Category spacing X", min = 0, max = 40, step = 1,
    get = function() return Bags.catGapX or ns.Density(Bags.iconSize).div end,
    set = function(v) Bags.catGapX = v; WarpeeDB.catGapX = v; ns.LayoutLite("both") end,
    disabled = flow.noCat, half = "left",
    desc = "Horizontal gap between categories on a shelf, in the category view." },
  { type = "range", name = "Category spacing Y", min = 0, max = 40, step = 1,
    get = function() return Bags.catGapY or ns.Density(Bags.iconSize).div end,
    set = function(v) Bags.catGapY = v; WarpeeDB.catGapY = v; ns.LayoutLite("both") end,
    disabled = flow.noCat, half = "right",
    desc = "Vertical gap between category rows, in the category view." },
  { type = "header", name = "Categories", key = "categories" },
  { type = "description", section = "categories",
    name = "Each row is either a category — a search read top to bottom, where an item joins the first it matches — or a marker: a group header naming the band under it, or a divider seaming one off. Drag a row by its grip to move it, the box on the left turns a category off, and the X takes a row out; a removed group header leaves its categories where they are. The strip above adds a ready-made category, and the buttons under the list add a new row at its bottom — the view scrolls to it and it flashes." },
  -- The order of items inside a section is set on the list's own header line, inside the catlist row
  -- below, rather than as a select here: see factories.catlist.
  { type = "catlist", section = "categories" },
}

local PAGES = {
  { name = "General", list = GENERAL_PAGE.list },
  { name = "Grid", subs = GRID_PAGE.subs },
  { name = "Categories", list = CATS_PAGE },
  { name = "Items", subs = ITEMS_PAGE.subs },
  { name = "Pocket", list = POCKET_PAGE },
  { name = "Vendor", list = VENDOR_PAGE },
  { name = "Characters", list = CHARS_PAGE },
}


-- The window reads the page list back through the module table.
Options.pages = PAGES
