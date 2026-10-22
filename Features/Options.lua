local addonName, ns = ...
local Theme = ns.Theme
local Bags = ns.Bags
local L = ns.L
local function T(s)
  if type(s) ~= "string" or s == "" then return s end
  return L[s]
end

local Options = {}
ns.Options = Options

local WIN_W, WIN_H = 780, 700
local PAD = 18
local HEADER_H = 42
local TAB_H = 30
local SUB_H = 22
local SUB_GAP = 14
-- The list breathes under the strip what the strip breathes under the tabs.
local SUB_DROP = 14
local BASE_FONT = 15
local ROW_GAP = 10
-- Off-duty row fade: ink alone left the box and the slider track bright.
local OFF_ALPHA = 0.55
local SCROLL_W = 8
local CONTENT_W = WIN_W - PAD * 2 - SCROLL_W - 6

local function relayout()
  Bags:Refont()
  if Bags.frame and Bags.frame:IsShown() then Bags:Layout() end
  if ns.Bank and ns.Bank.Refresh then ns.Bank:Refresh() end
  if ns.Cur and ns.Cur.Apply then ns.Cur:Apply() end
  if ns.Pocket and ns.Pocket.Apply then ns.Pocket:Apply() end
  if ns.GuildBankSkin and ns.GuildBankSkin.Restyle then ns.GuildBankSkin:Restyle() end
  local P = ns.CharPicker
  if P and P.frame and P.frame:IsShown() and P.Paint then P:Paint(true) end
  C_Timer.After(0, function()
    if Bags.frame and Bags.frame:IsShown() then Bags:FitHeader() end
  end)
end

-- Paced: first change draws, the rest fold into one trailing pass.
local function throttled(fn)
  local busy, last = false, 0
  return function()
    local now = GetTime()
    if not busy and (now - last) > 0.2 then
      last = now
      fn()
      return
    end
    if busy then return end
    busy = true
    C_Timer.After(0.2, function()
      busy = false
      last = GetTime()
      fn()
    end)
  end
end
-- Two-tier live layout: light passes move positions, a trailing full pass repaints.
-- Scopes live in a set, so neither window's trailing pass is cancelled.
local liteTimer, liteDirty = nil, {}
local function trailBags()
  if Bags.frame and Bags.frame:IsShown() then Bags:Layout() end
  if ns.Pocket then ns.Pocket:Refresh() end
end
local function trailBank()
  if ns.Bank then ns.Bank:Refresh() end
end
function ns.LayoutLite(scope)
  if scope ~= "bank" then
    if Bags.frame and Bags.frame:IsShown() then
      liteDirty.bags = true
      Bags:Layout(nil, true)
    end
  end
  if scope ~= "bags" then
    local B = ns.Bank
    if B and B.frame and B.frame:IsShown() then
      liteDirty.bank = true
      B:Layout(true)
    end
  end
  if liteTimer then liteTimer:Cancel() end
  liteTimer = C_Timer.NewTimer(0.25, function()
    liteTimer = nil
    local bags, bank = liteDirty.bags, liteDirty.bank
    liteDirty.bags, liteDirty.bank = nil, nil
    if bank then trailBank() end
    if bags then trailBags() end
    -- Neither picker is a bag or bank cell, but both are sized from the same knobs the lite rows move
    -- (icon size above all), so the trailing pass has to re-read them or an open panel keeps the old
    -- density until something else repaints it.
    if bags or bank then
      if ns.CurPicker then ns.CurPicker:Refresh() end
      local P = ns.CharPicker
      if P and P.frame and P.frame:IsShown() and P.Paint then P:Paint(true) end
    end
  end)
end

-- The live layout every slider row goes through; discrete clicks feel nothing.
local relayoutLive = throttled(relayout)

-- Every row that stores a value goes through ns.Setting: the store, the module copy the layouts read
-- (Bags here) and one redraw. The four factories below differ only in which copy and which redraw.
local function field(name)
  return function() return Bags[name] end, ns.Setting(name, relayoutLive, Bags)
end

-- Store-only rows: the lite path lays out, so the setter fires no full pass.
local function liteField(name, scope)
  local set = ns.Setting(name, function() ns.LayoutLite(scope) end, Bags)
  return function() return Bags[name] end, set
end

local function styleField(name)
  local set = ns.Setting(name, function()
    Bags.styleGen = (Bags.styleGen or 0) + 1
    relayoutLive()
  end, Bags)
  return function() return Bags[name] end, set
end

-- Options.lua loads before Core.lua, so the defaults table cannot be captured here: it is looked up when
-- the getter runs. The literal left in each call is only a last resort, and the numbers the panel shows
-- are the numbers DEFAULTS ships.
local function dbField(name, default)
  local get = function()
    return WarpeeDB[name] or (ns.DEFAULTS and ns.DEFAULTS[name]) or default
  end
  -- Bank-only rows (widths, icon sizes), paced and scoped to the bank.
  local set = ns.Setting(name, function() ns.LayoutLite("bank") end)
  return get, set
end

local function autoField(key)
  local get = function() return WarpeeDB.autoOpen and WarpeeDB.autoOpen[key] end
  local set = function(v)
    WarpeeDB.autoOpen = WarpeeDB.autoOpen or {}
    WarpeeDB.autoOpen[key] = v and true or false
  end
  return get, set
end

local function lockGet() return WarpeeDB.lockWindows and true or false end
local function mmHideGet() return WarpeeDB.hideMinimapIcon and true or false end
local function mmHideSet(v)
  WarpeeDB.hideMinimapIcon = v and true or false
  if ns.ApplyMinimapIcon then ns.ApplyMinimapIcon() end
end
local function localeGet() return ns.LocalePick() end
local function localeSet(v)
  WarpeeDB.locale = v
  -- A language move drops the search index; the next query rebuilds it.
  Options.searchIdx = nil
  ns.Fonts:Settle()
  ns.Fonts:Refresh()
  if Options.ReflowPages then Options:ReflowPages() end
  if ns.ApplyLocaleText then ns.ApplyLocaleText() end
  relayout()
  if Options.ApplyFont then Options:ApplyFont() end
end
local function localeKeys() return ns.LocaleOrder() end
local function localeLabel(k) return ns.L[ns.LOCALE_LABELS[k] or k] end

local function sClearGet() return WarpeeDB.searchClear ~= false end
local function sClearSet(v) WarpeeDB.searchClear = v and true or false end
local function sLinkGet() return WarpeeDB.searchLink ~= false end
local function sLinkSet(v) WarpeeDB.searchLink = v and true or false end
local function lockSet(v)
  WarpeeDB.lockWindows = v and true or nil
  ns.ApplyWindowLock()
end
local function hideFieldsGet() return WarpeeDB.hideMoveFields and true or false end
local function hideFieldsSet(v)
  WarpeeDB.hideMoveFields = v and true or nil
  ns.ApplyWindowLock()
end

local ANCHORS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
local ANCHOR_LABELS = { TOPLEFT = "Top left", TOPRIGHT = "Top right",
                        BOTTOMLEFT = "Bottom left", BOTTOMRIGHT = "Bottom right",
                        CENTER = "Center" }
local ANGLE_KEYS = { "CENTER", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }

local function angleGet(dbKey)
  local rec = WarpeeDB and WarpeeDB[dbKey]
  local stored = rec and ns.CornerOk(rec.p)
  if stored then return stored end
  local def = ns.DEFAULTS and ns.DEFAULTS[dbKey]
  return (def and ns.CornerOk(def.p)) or "CENTER"
end

-- A window that is closed has no rectangle to keep, so the corner is only recorded and the
-- next open places the window from it. One that is standing is re-anchored on the rectangle
-- it holds, which is why picking a corner never moves a window.
local function angleSet(dbKey, v)
  local f = dbKey == "pos" and ns.Bags and ns.Bags.frame
    or dbKey == "bankPos" and ns.Bank and ns.Bank.frame
    or dbKey == "pocketPos" and ns.Pocket and ns.Pocket.frame
  if f then
    ns.SetAngle(f, dbKey, v)
    return
  end
  local rec = WarpeeDB and WarpeeDB[dbKey]
  if rec then rec.p, rec.rp = v, v end
end

local STYLES = { "flat", "plate", "deep" }
local STYLE_LABELS = { flat = "Transparent", plate = "Highlight", deep = "Solid" }
local THEME_LABELS = {}
for i = #Theme.THEME_ORDER, 1, -1 do
  local k = Theme.THEME_ORDER[i]
  local t = Theme.THEMES[k]
  if t then THEME_LABELS[k] = t.label or k else table.remove(Theme.THEME_ORDER, i) end
end
local function themeGet() return WarpeeDB.theme or "blizzard" end
local function themeSet(v)
  WarpeeDB.theme = v
  Theme:Restyle(v)
end
local THEME_KEYS = {}
for i, k in ipairs(Theme.THEME_ORDER) do if Theme.LIGHT[k] then THEME_KEYS[#THEME_KEYS + 1] = k end end
for i, k in ipairs(Theme.THEME_ORDER) do if not Theme.LIGHT[k] then THEME_KEYS[#THEME_KEYS + 1] = k end end
-- Theme names stay in English in every language, the way font families do: they are what players see in
-- guides and screenshots, and the saved key is English too. So the row label is the name itself, with no
-- key behind it. "Class color" is named for what the accent follows; it is still a name, not a label.
local function themeLabel(k)
  return THEME_LABELS[k] or k
end

local function fontKeys()
  return ns.Fonts:List()
end

-- Every tip in the options window opens above its control, and this is the one place that
-- decides it. Rows here are full width or half of it, so a tip hung on the side lands past
-- the window edge with nothing under it, and two rows written months apart end up pointing
-- two different ways. Above reads the same for a checkbox, a slider, a dropdown and a row.
local function tip(frame, text)
  if not text then return end
  if frame.EnableMouse then frame:EnableMouse(true) end
  ns.AddTip(frame, function() return (type(text) == "function") and text() or T(text) end, "top")
end

-- Off-duty rows fade here, so every factory fades by one amount.
local function offDuty(row, off)
  row:SetAlpha(off and OFF_ALPHA or 1)
end

local function pinHint(bound, unbound)
  return function()
    local name = ns.PinKeyName()
    if not name then return T(unbound) end
    return (T(bound)):format(name)
  end
end

local fonts = {}
local function track(fs, delta)
  fonts[#fonts + 1] = { fs = fs, delta = delta or 0 }
  return fs
end

local rows = {}
local factories = {}
Options.factories = factories

-- The sort modes, one label table shared by the global select and the per-category override so the two
-- can never drift. The global "Sort within a section" offers GLOBAL_SORT_KEYS; a category's own override
-- (CAT_SORT_KEYS, in the pin panel) puts "Default" first — inherit the global — ahead of the same modes.
-- "By rule" orders a piece by which branch of an OR search (toy | mount | battlepet) claimed it, so the
-- view reads in the order the rule is written; on a search with no "|" it falls through to quality. "By
-- expansion" groups a section by expansion, newest first — most useful on a mixed pile like Legacy, but
-- offered globally too so it can be the default when the player wants it.
local SORT_LABELS = {
  default = "Default", quality = "Quality", ilvl = "Item level",
  name = "Name", match = "By rule", expac = "By expansion",
}
local GLOBAL_SORT_KEYS = { "quality", "ilvl", "name", "match", "expac" }
local CAT_SORT_KEYS = { "default", "quality", "ilvl", "name", "match", "expac" }


local bg = { sel = "ilvl" }
bg.aligns = { "left", "right", "center" }
bg.alignOff = { left = 0, center = 0.5, right = 1 }
bg.alignLabels = { left = "Grows left to right", right = "Grows right to left",
                   center = "Grows from the center" }
bg.alignKeys = function() return bg.aligns end
bg.alignLabel = function(k) return bg.alignLabels[k] or bg.alignLabels.left end
bg.alignOf = function(g)
  local a = g and g.a
  if a and bg.alignOff[a] then return a end
  return ((g and g.c) or ""):find("LEFT") and "left" or "right"
end
bg.cur = function() return ns.Badge(bg.sel) end
bg.def = function() return ns.BADGE[bg.sel] or ns.BADGES[1] end
bg.bump = function()
  Bags.styleGen = (Bags.styleGen or 0) + 1
  if bg.repaint then bg.repaint() end
  if ns.Profiles and ns.Profiles.SyncActive then ns.Profiles:SyncActive() end
  -- Paced: the badge size and offset sliders drive this per pixel.
  relayoutLive()
end
bg.soloGet = function() return WarpeeDB.badgeSolo and true or false end
bg.soloSet = function(v)
  WarpeeDB.badgeSolo = v and true or false
  if bg.repaint then bg.repaint() end
end
bg.getter = function(f) return function() return bg.cur()[f] end end
bg.setter = function(f) return function(v) bg.cur()[f] = v; bg.bump() end end
bg.pin = function(f, v) return bg.fit and bg.fit(f, v) or bg.clamp(v) end
bg.reseat = function(g)
  g.x, g.y = bg.pin("x", g.x), bg.pin("y", g.y)
end
bg.cGet = bg.getter("c")
bg.cSet = function(v)
  local g = bg.cur()
  g.c = v
  bg.reseat(g)
  bg.bump()
end
bg.aGet = function() return bg.alignOf(bg.cur()) end
bg.aSet = function(v)
  local g = bg.cur()
  local old = bg.alignOf(g)
  if old == v or not bg.alignOff[v] then return end
  local w = bg.spanW and bg.spanW(bg.sel) or 0
  g.a = v
  g.x = bg.pin("x", (g.x or 0) + (bg.alignOff[v] - bg.alignOff[old]) * w)
  bg.bump()
end
bg.xGet, bg.yGet = bg.getter("x"), bg.getter("y")
bg.xSet = function(v) bg.cur().x = bg.pin("x", v); bg.bump() end
bg.ySet = function(v) bg.cur().y = bg.pin("y", v); bg.bump() end
bg.sGet = bg.getter("s")
bg.sSet = function(v)
  local g = bg.cur()
  g.s = v
  -- The number in the field is pixels in the cell this page draws against, so that is the cell
  -- it is written for. Spelling it out here keeps the pair honest even if the field is reached
  -- before the badge has been through a paint.
  if bg.isText() then g.ref = bg.cell() end
  bg.bump()
  local x, y = bg.pin("x", g.x), bg.pin("y", g.y)
  if x ~= g.x or y ~= g.y then g.x, g.y = x, y; bg.bump() end
end
bg.kGet = function() return bg.cur().k or 4 end
bg.kSet = bg.setter("k")
bg.isTex   = function() return bg.def().tex and true or false end
bg.isText  = function() return not bg.def().tex end
bg.notFit  = function() return bg.sel ~= "outfit" end
bg.label   = function(key) return (ns.BADGE[key] or {}).n or key end
bg.prev    = 132
bg.max     = 56
bg.clamp   = function(v)
  v = math.floor(v + 0.5)
  if v > bg.max then return bg.max elseif v < -bg.max then return -bg.max end
  return v
end
-- The cell the editor draws against and the cell the badge numbers are stored for. It is the
-- bags, and it is read the same way the grid reads it, so a badge dragged here is drawn where
-- the grid will draw it: a number written against one cell and drawn in another is how the
-- two come apart.
bg.cell = function()
  return (Bags and Bags.pxSize) or (Bags and Bags.iconSize) or ns.DEFAULT_CELL
end

local function bagsCell() return bg.cell() end
local function bankCell(mode)
  local V = ns.Bank
  local st = V and V.state and V.state[mode]
  if st and (st.iconSize or 0) > 0 then return st.iconSize end
  if V and V.CellSize then return V:CellSize() end
  return ns.DEFAULT_CELL
end
local function pocketCell()
  -- The pocket's own size, through the one call that reads it: falling back to the bags' size here
  -- would scale that window's badges with a size the pocket is not drawn at.
  return (ns.PocketIconSize and ns.PocketIconSize()) or ns.DEFAULT_CELL
end

-- The windows a badge has to read the same way in. The guild bank reads its cell off its own
-- live buttons, which the skin measures as it dresses them; until one is measured there is no
-- number to quote and the window stays out of the line.
local function guildCell()
  local S = ns.GuildBankSkin
  local h = S and S.guildCell
  if h and h > 0 then return h end
end
bg.windows = {
  { n = "Bags",    cell = bagsCell },
  { n = "Bank",    cell = function() return bankCell("bank") end },
  { n = "Warband", cell = function() return bankCell("warband") end },
  { n = "Pocket",  cell = pocketCell },
  { n = "Guild bank", cell = guildCell },
}

-- The editor draws a badge against the bags and stores what it drew, so the cell those numbers
-- are written for is the bags' cell. When the bags have moved since the badge was last touched,
-- say it again in the new cell. This changes no pixels: round(round(s * B / ref) * B / B) is
-- already what the grid was drawing, so nothing has to be repainted and nothing on screen
-- moves. It is done on every paint rather than when the page opens, because the bags can be
-- resized from another page while this one is the page being looked at.
bg.normalize = function()
  local B = bg.cell()
  if not (B and B > 0) then return end
  for _, d in ipairs(ns.BADGES) do
    if not d.tex then
      local g = ns.Badge(d.key)
      local ref = ns.BadgeRef(d, g)
      if ref ~= B then
        local k = B / ref
        -- Through the same call the drawing uses, so the promise above holds: an offset re-based
        -- here and an offset scaled there have to round alike, or a badge the panel normalized
        -- while the cell was small would have lost the inset for good and jumped into its corner.
        g.x = ns.BadgeOffset(g.x, k)
        g.y = ns.BadgeOffset(g.y, k)
        g.s = math.floor((tonumber(g.s) or d.s) * k + 0.5)
        g.ref = B
      end
    end
  end
end

-- What the badge works out to in each window, through the same helper the grid draws with, so
-- the number the panel promises is the number that lands on the cell. The floor is called out
-- where it is what decided the size, since that is the one place the badge stops following the
-- share of the cell the rest of this page is about.
bg.hintText = function()
  if bg.isTex() then return "" end
  local key = bg.sel
  -- The cell is what the line shows and the pixels are what the badge will be, and two windows
  -- whose cells round to the same number can still land on different pixels: each grid snaps to
  -- its own pixel unit, so 36.0 and 35.56 both read as 36 and do not draw alike. The group is
  -- the pair, so a line only ever promises a number that every window under it draws.
  local function at(cell)
    local shown = math.floor(cell + 0.5)
    local px, floored = ns.BadgeSize(key, cell)
    return ("%d:%d"):format(shown, px), shown, px, floored
  end
  local seen, parts = {}, {}
  for _, w in ipairs(bg.windows) do
    local cell = w.cell()
    if cell and cell > 0 then
      local bucket, shown, px, floored = at(cell)
      if not seen[bucket] then
        seen[bucket] = true
        local names = {}
        for _, w2 in ipairs(bg.windows) do
          local c2 = w2.cell()
          if c2 and c2 > 0 and at(c2) == bucket then names[#names + 1] = T(w2.n) end
        end
        parts[#parts + 1] = ("%s (%d): %dpx%s"):format(table.concat(names, ", "), shown, px,
          floored and (" " .. T("(min)")) or "")
      end
    end
  end
  return table.concat(parts, "   ")
end

bg.shown = function()
  local n = 0
  for _, d in ipairs(ns.BADGES) do if ns.Badge(d.key).on then n = n + 1 end end
  return n
end

local function sectionOpen(key)
  if not key then return true end
  local t = WarpeeDB and WarpeeDB.optSections
  local v = t and t[key]
  if v == nil then
    -- Sections that the profile predates: both start closed, since a section nobody has opened yet only
    -- takes room away. The marked-for-sale one opens itself once there is something in it to show.
    if key == "badgeorder" then return false end
    if key == "sellmarks" then
      for _ in pairs(WarpeeDB and WarpeeDB.sellMark or {}) do return true end
      return false
    end
    -- DEFAULTS.optSections carries every section key and the login path writes them all, so
    -- this is only reached by a key it does not know, and a section nobody has an opinion
    -- about starts open.
    return true
  end
  return v and true or false
end

local function sectionToggle(key)
  local on = sectionOpen(key)
  WarpeeDB.optSections = WarpeeDB.optSections or {}
  WarpeeDB.optSections[key] = not on
end

local function onOf(list)
  local n = 0
  for _, fn in ipairs(list) do if fn() then n = n + 1 end end
  return (L["%d of %d"]):format(n, #list)
end

-- The dropdown — the menu frame, its pooled rows, its scrollbar and the second-press toggle — is a
-- factory of its own (Features/OptionDropdown.lua). That file loads after this one, so the menu is built
-- on the first control that opens it; these three names are the entry points the controls always called,
-- and the two module-level ones are in place from load, so another panel can ask for a menu before this
-- window has ever been opened.
-- The font a menu row and every control beside it are measured in; the menu factory takes it as well, so
-- a row's label and the control it hangs from read at the same size.
local function dropdownFont()
  return ns.Fonts:Current()
end

local dd
local function dropdownApi()
  if not dd then
    dd = { factories.optiondropdown({
      T = T, baseFont = BASE_FONT, scrollW = SCROLL_W, track = track, dropdownFont = dropdownFont,
    }) }
  end
  return dd
end
local function openDropdown(anchor, spec, onPick) return dropdownApi()[1](anchor, spec, onPick) end
local function closeDropdown() if dd then dd[2]() end end
local function isDropdownOpen(frame) return dd ~= nil and dd[3](frame) end
ns.OpenDropdown, ns.CloseDropdown = openDropdown, closeDropdown

-- Page chrome and the simplest rows — section header, divider, paragraph, tick box — are built in
-- Features/OptionControls.lua. That file reads the values below when it loads; nothing here calls it,
-- because a page asks for one of those rows only while it is being built, long after every file is in.
ns.OptionControlsEnv = {
  T = T,
  baseFont = BASE_FONT,
  contentW = CONTENT_W,
  track = track,
  tip = tip,
  offDuty = offDuty,
  sectionOpen = sectionOpen,
  sectionToggle = sectionToggle,
  dropdownFont = dropdownFont,
  openDropdown = openDropdown,
  isDropdownOpen = isDropdownOpen,
  field = field,
  relayoutLive = relayoutLive,
  anchorLabels = ANCHOR_LABELS,
}

-- The key binding row — its capture listener, the mouse catcher and the unbind rules — is built in
-- Features/OptionKeybind.lua, which registers the factory at load.

-- The character rows' helpers: the group heading, the two confirms that drop a character's saved bags
-- and the account-wide gold store, and the cell that draws one character.
-- The character rows — the heading, the cell, the delete mode and the two confirms — are built in
-- Features/OptionChars.lua, which registers factories.chars at load.

-- The marked-for-sale list is built in Features/OptionSellList.lua, which registers factories.selllist
-- at load; the badge picker and its order stay here, next to the page scaffold they ride on.

-- The badge picker and the badge order are built in Features/OptionBadges.lua, which registers both
-- factories at load. The page scaffold below stays here, with the rows it lays out.

local function buildPage(parent, list)
  local page = CreateFrame("Frame", nil, parent)
  page:SetPoint("TOPLEFT")
  page:SetWidth(CONTENT_W)
  page.rows = {}
  for _, spec in ipairs(list) do
    local row = factories[spec.type](page, spec)
    page.rows[#page.rows + 1] = { row = row, spec = spec }
    if row.Refresh then rows[#rows + 1] = row end
  end
  page.Relayout = function()
    local y = 0
    local halfW = math.floor((CONTENT_W - 14) / 2)
    local thirdW = math.floor((CONTENT_W - 20) / 3)
    local function gone(spec)
      return (spec.hidden and spec.hidden())
             or (spec.section and not sectionOpen(spec.section)) and true or false
    end
    local function nextSpec(from)
      for j = from + 1, #page.rows do
        local s = page.rows[j].spec
        if not gone(s) then return s end
      end
    end
    for index, entry in ipairs(page.rows) do
      local row, spec = entry.row, entry.spec
      if gone(spec) then
        row:Hide()
      else
        row:Show()
        if row.dynamic and row.Rebuild then row.Rebuild() end
        if row.autoHeight then row:SetHeight(row.autoHeight:GetStringHeight() + 6) end
        row:ClearAllPoints()
        if spec.type == "header" and y > 0 then y = y + 12 end
        local nx = nextSpec(index)
        local function advance(extra)
          y = ns.SnapValue(row, y + row:GetHeight() + extra)
        end
        row:SetHeight(ns.SnapEven(row, row:GetHeight()))
        local sy = ns.SnapValue(row, y)
        if spec.col then
          local total = spec.of or 2
          local colW = total == 3 and thirdW or halfW
          row:SetWidth(colW)
          ns.SnapPoint(row, "TOPLEFT", page, "TOPLEFT",
            (spec.col - 1) * (colW + (total == 3 and 10 or 14)), -sy)
          local nextCol = nx and nx.col
          if spec.col >= total or not nextCol or nextCol <= spec.col then
            advance(ROW_GAP)
          end
        elseif spec.half == "left" then
          ns.SnapPoint(row, "TOPLEFT", page, "TOPLEFT", 0, -sy)
          row:SetWidth(halfW)
          if not (nx and nx.half == "right") then advance(ROW_GAP) end
        elseif spec.half == "right" then
          ns.SnapPoint(row, "TOPRIGHT", page, "TOPRIGHT", 0, -sy)
          row:SetWidth(halfW)
          advance(ROW_GAP)
        else
          ns.SnapPoint(row, "TOPLEFT", page, "TOPLEFT", 0, -sy)
          ns.SnapPoint(row, "TOPRIGHT", page, "TOPRIGHT", 0, -sy)
          advance(spec.type == "header" and 7 or ROW_GAP)
        end
      end
    end
    page:SetHeight(ns.SnapValue(page, y + 4))
  end
  page.Relayout()
  return page
end

local function makeScrollArea(parent, list)
  local sf = CreateFrame("ScrollFrame", nil, parent)
  local page = buildPage(sf, list)
  sf:SetScrollChild(page)

  local bar = CreateFrame("Frame", nil, parent)
  bar:SetWidth(SCROLL_W)
  local trackTex = Theme:Rect(bar, "panel", "BACKGROUND")
  trackTex:SetAllPoints(bar)
  local thumb = CreateFrame("Frame", nil, bar)
  thumb:SetWidth(SCROLL_W)
  local thumbTex = Theme:Rect(thumb, "faint", "ARTWORK")
  thumbTex:SetAllPoints(thumb)
  sf.bar, sf.page = bar, page

  local function range()
    return math.max(0, page:GetHeight() - sf:GetHeight())
  end

  local function paintBar()
    local span, view = range(), sf:GetHeight()
    if span <= 0 or not sf:IsShown() then bar:Hide(); return end
    bar:Show()
    local h = math.max(20, view * view / page:GetHeight())
    thumb:SetHeight(h)
    local frac = sf:GetVerticalScroll() / span
    thumb:ClearAllPoints()
    thumb:SetPoint("TOP", bar, "TOP", 0, -frac * (view - h))
  end
  sf.PaintBar = function() paintBar() end

  local function scrollTo(v)
    -- Any dropdown open on this page is anchored to a row button that rides the scroll child, so a scroll
    -- carries it off across the window (and past its edge, since the menu is parented to UIParent and only
    -- clamped to the screen). Dismiss it on the first scroll rather than let it drift: the pick is a quick
    -- act, and a menu that followed the page would have to be re-aimed anyway. Covers every options
    -- dropdown, not just the per-category sort one.
    closeDropdown()
    local span = range()
    v = math.min(span, math.max(0, v))
    sf:SetVerticalScroll(math.min(span, ns.SnapScroll(sf, v)))
    paintBar()
  end
  sf.ScrollTo = function(_, v) scrollTo(v) end

  sf:EnableMouseWheel(true)
  sf:SetScript("OnMouseWheel", function(s, d)
    -- A wheel aimed at the search-words sheet never turns the page beneath it: the sheet is opened from a row
    -- in this page, so a page that scrolled under the cursor would drag that row out from under the sheet
    -- while the sheet's own list scrolled, and the two together read as the sheet itself moving. The sheet
    -- takes its own wheel; this is the one path that can still reach the page from over it.
    if ns.SearchWordsUnderCursor and ns.SearchWordsUnderCursor() then return end
    scrollTo(s:GetVerticalScroll() - d * 34)
  end)
  sf:SetScript("OnSizeChanged", paintBar)

  ns.ScrollThumb(thumb, thumbTex, sf, scrollTo, range)
  return sf
end

local colsGet, colsSet       = liteField("cols", "bags")
local sizeGet, bagSizeSet    = liteField("iconSize", "bags")
-- A window's cell is what its badges are sized against, so a window that lands on a new one
-- has to reach them and not just its own grid. The bump comes first: the restyle that follows
-- is the pass that dresses them, and it reads the counter on its way through.
local function sizeSet(v) ns.BumpCellSize(); bagSizeSet(v) end
local gapGet, gapSet         = liteField("gap", "both")
local styleGet, styleSet     = styleField("slotStyle")
local fontGet, fontSet       = styleField("font")
local zoomGet, zoomSet       = styleField("iconZoom")
local edgeGet, edgeSet       = styleField("borderWidth")
local mergeGet, mergeSet     = field("mergeReagents")
local flow = {}
flow.topGet, flow.topSet = field("reagentTop")
flow.hideGet = function() return Bags.hideReagents end
-- The header's reagent switch writes the same key, so the store lives on the window (Bags:SetReagentsHidden)
-- and the page adds its own pass on top of it.
flow.hideSet = function(v) Bags:SetReagentsHidden(v); relayoutLive() end
flow.offGet = function() return mergeGet() or flow.hideGet() end
-- One flag for the bags, one for both bank sets behind their mode pick.
-- Split releases a merged reagent bag, so the merge row greys out.
flow.splitGet = function() return Bags.splitBags end
local setSplitBags = ns.Setting("splitBags", function(value)
  if value and Bags.mergeReagents then mergeSet(false) end
  relayout()
end, Bags)
flow.splitSet = function(v) setSplitBags(v and true or false) end
flow.noMerge = function() return flow.hideGet() or flow.splitGet() end
flow.splitBankGet, flow.splitBankSet = field("splitBank")
flow.splitWbGet, flow.splitWbSet     = field("splitWb")
-- A named block needs caption room, so the setter holds the value to it.
local function splitRoom(named) return named() and (ns.CapRoom or 0) or 0 end
local function splitNamedBags() return Bags.splitBags and Bags.nameBags end
local function splitNamedBank() return Bags.splitBank and Bags.nameBank end
local function splitNamedWb() return Bags.splitWb and Bags.nameWb end
local function gapFloor(v, named)
  local room = splitRoom(named)
  v = tonumber(v) or 12
  return v < room and room or v
end
-- Through the settings layer, so the number lands on the table the layouts read.
local setSplitGapBags = ns.Setting("splitGapBags", function() ns.LayoutLite("bags") end, Bags)
local setSplitGapBank = ns.Setting("splitGapBank", function() ns.LayoutLite("bank") end, Bags)
local setSplitGapWb = ns.Setting("splitGapWb", function() ns.LayoutLite("bank") end, Bags)
local function gapBagsSet(v) setSplitGapBags(gapFloor(v, splitNamedBags)) end
local function gapBankSet(v) setSplitGapBank(gapFloor(v, splitNamedBank)) end
local function gapWbSet(v) setSplitGapWb(gapFloor(v, splitNamedWb)) end
flow.splitGapBagsGet = function() return Bags.splitGapBags end
flow.splitGapBagsSet = gapBagsSet
flow.splitGapBankGet = function() return Bags.splitGapBank end
flow.splitGapBankSet = gapBankSet
flow.splitGapWbGet = function() return Bags.splitGapWb end
flow.splitGapWbSet = gapWbSet
-- The slider's floor; the range factory reads min as a function.
flow.splitGapBagsMin = function() return splitRoom(splitNamedBags) end
flow.splitGapBankMin = function() return splitRoom(splitNamedBank) end
flow.splitGapWbMin = function() return splitRoom(splitNamedWb) end
flow.nameBagsGet, flow.nameBagsSet   = field("nameBags")
flow.nameBankGet, flow.nameBankSet   = field("nameBank")
flow.nameWbGet, flow.nameWbSet       = field("nameWb")
flow.revGet, flow.revSet = field("revFill")
flow.upGet, flow.upSet   = field("fillUp")
-- New-on-top is bags-only and means nothing in the grouped view, so it greys there.
flow.newTopGet = function() return Bags.newOnTop end
local setNewOnTop = ns.Setting("newOnTop", function(value)
  -- Turning it on kicks the pump so any items that arrived while it was off move to the far end at once;
  -- turning it off leaves the bags exactly as they are (the new pieces simply stop being kept apart).
  if value and Bags.ArrangeNew then Bags:ArrangeNew() end
  relayout()
end, Bags)
flow.newTopSet = function(v) setNewOnTop(v) end
-- The view is a string on disk, the row a toggle, so the pair maps bool to "grid"/"cat".
flow.catGet = function() return Bags.bagView == "cat" end
-- The inverse gate, the mirror of the reagent rows' catGet: true while the bags are still a plain grid.
flow.gridGet = function() return Bags.bagView ~= "cat" end
-- The bank's own grouped-view flag, independent of the bags: a player may want sections in one and
-- the plain grid in the other. Stored on WarpeeDB.bankView and read by the bank when it lays out.
flow.bankCatGet = function() return WarpeeDB and WarpeeDB.bankView == "cat" end
-- Both grids read these, so they grey only when neither is a grid.
flow.gridGone = function() return flow.catGet() and flow.bankCatGet() end
-- Category spacing drives the grouped view of both, live while either is grouped.
flow.noCat = function() return not (flow.catGet() or flow.bankCatGet()) end
-- Both view keys have a second writer in Features/Welcome.lua, the first-run pick that sets the bags and
-- the bank at once. The stores live here and on Bags (SetView), so the two surfaces write the same pair;
-- the passes stay with each caller, since the first-run path lays the window out before it is shown.
local setBankView = ns.Setting("bankView")
function Options:SetBankView(mode) setBankView(mode) end
flow.bankCatSet = function(v)
  Options:SetBankView(v and "cat" or "grid")
  if ns.Bank and ns.Bank.Refresh then ns.Bank:Refresh() end
  -- A row pass, not a reflow: a reflow would rebuild the page under the open menu.
  if Options.RefreshSoon then Options:RefreshSoon() end
end
flow.catSet = function(v)
  Bags:SetView(v and "cat" or "grid")
  relayout()
  -- The reagent rows answer to the view; one row pass updates their state.
  if Options.RefreshSoon then Options:RefreshSoon() end
end

-- One editable row per category: a checkbox, the reorder carets, a name and a search field, the
-- live count, and a delete. The list is dynamic so the page rebuilds it on every relayout; the
-- pool of rows is reused and rebound to a list index each pass, exactly like the character grid.
-- The category editor itself is in Features/CatListPage.lua, which reads this table at load. Every name
-- a row binds to is listed here once, so the page file does not reach back into this one.
ns.CatListEnv = {
  ANCHORS = ANCHORS,
  ANCHOR_LABELS = ANCHOR_LABELS,
  ANGLE_KEYS = ANGLE_KEYS,
  BASE_FONT = BASE_FONT,
  Bags = Bags,
  CAT_SORT_KEYS = CAT_SORT_KEYS,
  CONTENT_W = CONTENT_W,
  GLOBAL_SORT_KEYS = GLOBAL_SORT_KEYS,
  L = L,
  Options = Options,
  SCROLL_W = SCROLL_W,
  SORT_LABELS = SORT_LABELS,
  STYLES = STYLES,
  STYLE_LABELS = STYLE_LABELS,
  T = T,
  THEME_KEYS = THEME_KEYS,
  Theme = Theme,
  angleGet = angleGet,
  angleSet = angleSet,
  autoField = autoField,
  closeDropdown = closeDropdown,
  colsGet = colsGet,
  colsSet = colsSet,
  dbField = dbField,
  dropdownFont = dropdownFont,
  edgeGet = edgeGet,
  edgeSet = edgeSet,
  factories = factories,
  field = field,
  flow = flow,
  fontGet = fontGet,
  fontKeys = fontKeys,
  fontSet = fontSet,
  gapGet = gapGet,
  gapSet = gapSet,
  hideFieldsGet = hideFieldsGet,
  hideFieldsSet = hideFieldsSet,
  localeGet = localeGet,
  localeKeys = localeKeys,
  localeLabel = localeLabel,
  localeSet = localeSet,
  lockGet = lockGet,
  lockSet = lockSet,
  mergeGet = mergeGet,
  mergeSet = mergeSet,
  mmHideGet = mmHideGet,
  mmHideSet = mmHideSet,
  ns = ns,
  onOf = onOf,
  openDropdown = openDropdown,
  pinHint = pinHint,
  relayout = relayout,
  rows = rows,
  sClearGet = sClearGet,
  sClearSet = sClearSet,
  sLinkGet = sLinkGet,
  sLinkSet = sLinkSet,
  sizeGet = sizeGet,
  sizeSet = sizeSet,
  styleField = styleField,
  styleGet = styleGet,
  styleSet = styleSet,
  themeGet = themeGet,
  themeLabel = themeLabel,
  themeSet = themeSet,
  tip = tip,
  track = track,
  zoomGet = zoomGet,
  zoomSet = zoomSet,
}
-- The window's own methods — tabs, sub strips, the page cache, open/close, refresh, search — are in
-- Features/OptionShell.lua, which reads the scaffold and the numbers below at load.
ns.OptionShellEnv = {
  T = T,
  baseFont = BASE_FONT,
  tabH = TAB_H,
  subH = SUB_H,
  subGap = SUB_GAP,
  subDrop = SUB_DROP,
  headerH = HEADER_H,
  pad = PAD,
  winW = WIN_W,
  winH = WIN_H,
  scrollW = SCROLL_W,
  track = track,
  rows = rows,
  fonts = fonts,
  makeScrollArea = makeScrollArea,
  closeDropdown = closeDropdown,
  dropdownFont = dropdownFont,
  localeGet = localeGet,
  sectionOpen = sectionOpen,
  sectionToggle = sectionToggle,
}