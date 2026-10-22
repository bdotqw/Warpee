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
      baseFont = BASE_FONT, scrollW = SCROLL_W, track = track, dropdownFont = dropdownFont,
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
  baseFont = BASE_FONT,
  contentW = CONTENT_W,
  track = track,
  tip = tip,
  offDuty = offDuty,
  sectionOpen = sectionOpen,
  sectionToggle = sectionToggle,
}

-- The key binding row — its capture listener, the mouse catcher and the unbind rules — is built in
-- Features/OptionKeybind.lua, which registers the factory at load.

function factories.input(parent, spec)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(28)

  local fs = track(Theme:Label(row, BASE_FONT, "text"), 0)
  fs:SetPoint("LEFT", 1, 0)
  fs:SetText(T(spec.name))

  local box = CreateFrame("EditBox", nil, row, "BackdropTemplate")
  ns.SnapBox(box, 66, 24, true)
  ns.SnapPoint(box, "TOPRIGHT", row, "TOPRIGHT", -1, -2)
  ns.PixelBackdrop(box)
  ns.SetBg(box, Theme:C("bg"))
  ns.SetEdge(box, Theme:C("stroke"))
  Theme:Track(box, function(s)
    ns.SetBg(s, Theme:C("bg"))
    s:SetTextColor(Theme:C("text"))
    if not s:HasFocus() then ns.SetEdge(s, Theme:C("stroke")) end
  end)
  box:SetFont(dropdownFont(), BASE_FONT - 1, ns.OutlineFlags())
  track(box, -1)
  box:SetTextColor(Theme:C("text"))
  box:SetJustifyH("CENTER")
  box:SetAutoFocus(false)
  box:SetNumeric(true)
  box:SetMaxLetters(4)

  row.Refresh = function()
    local on = not (spec.disabled and spec.disabled())
    box:EnableMouse(on)
    offDuty(row, not on)
    fs:SetText(T(spec.name))
    fs:SetTextColor(Theme:C(on and "text" or "faint"))
    box:SetTextColor(Theme:C(on and "text" or "faint"))
    if not box:HasFocus() then box:SetText(tostring(spec.get() or 0)) end
  end

  local function apply()
    if spec.disabled and spec.disabled() then return end
    local v = tonumber(box:GetText()) or spec.get() or 0
    if spec.min and v < spec.min then v = spec.min end
    if spec.max and v > spec.max then v = spec.max end
    spec.set(v)
    row.Refresh()
    Options:Refresh()
  end

  box:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
  -- Escape cancels the edit. ClearFocus fires OnEditFocusLost synchronously, which commits through
  -- apply(), so the typed text is reverted to the stored value first: apply then reads the current value
  -- back and the edit is a no-op. Refresh after, to redraw the reverted number.
  box:SetScript("OnEscapePressed", function(s)
    s:SetText(tostring(spec.get() or 0))
    s:ClearFocus()
    row.Refresh()
  end)
  box:SetScript("OnEditFocusGained", function(s) ns.SetEdge(s, Theme:C("accent")) end)
  box:SetScript("OnEditFocusLost", function(s)
    ns.SetEdge(s, Theme:C("stroke"))
    apply()
  end)

  row.Refresh()
  tip(row, spec.desc)
  return row
end

function factories.range(parent, spec)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(46)

  local fs = track(Theme:Label(row, BASE_FONT, "text"), 0)
  fs:SetPoint("TOPLEFT", 1, -1)
  fs:SetText(T(spec.name))

  local val = track(Theme:Label(row, BASE_FONT, "accentInk"), 0)
  val:SetPoint("TOPRIGHT", -1, -1)

  local s = CreateFrame("Slider", nil, row)
  s:SetOrientation("HORIZONTAL")
  s:SetHeight(18)
  s:SetPoint("BOTTOMLEFT", 1, 2)
  s:SetPoint("BOTTOMRIGHT", -1, 2)
  s:SetValueStep(spec.step or 1)
  s:SetObeyStepOnDrag(true)

  local track_ = Theme:Rect(s, "panelHi", "BACKGROUND")
  track_:SetHeight(6)
  track_:SetPoint("LEFT", 0, 0)
  track_:SetPoint("RIGHT", 0, 0)

  local fill = Theme:Rect(s, "accent", "ARTWORK")
  fill:SetHeight(6)
  fill:SetPoint("LEFT", track_, "LEFT", 0, 0)

  local thumb = s:CreateTexture(nil, "OVERLAY")
  thumb:SetTexture(Theme.WHITE)
  thumb:SetVertexColor(Theme:C("accentInk"))
  thumb:SetSize(9, 18)
  s:SetThumbTexture(thumb)

  -- The floor moves: gaps start at caption room while names are on.
  local function minOf()
    local m = spec.min
    if type(m) == "function" then m = m() end
    return m or 0
  end
  -- Read back through the floor, so the thumb and the label never disagree.
  local function atLeastFloor()
    local v = tonumber(spec.get()) or 0
    local floor = minOf()
    return v < floor and floor or v
  end
  s:SetMinMaxValues(minOf(), spec.max)

  local function snap(v)
    local step = spec.step or 1
    local mn = minOf()
    local n = math.floor((v - mn) / step + 0.5)
    local out = mn + n * step
    if out > spec.max then out = spec.max elseif out < mn then out = mn end
    return out
  end

  local function label(v)
    if spec.format then return spec.format(v) end
    if (spec.step or 1) < 1 then return string.format("%.2f", v) end
    return tostring(v)
  end

  local function paint(v)
    val:SetText(label(v))
    local mn = minOf()
    local span = spec.max - mn
    local w = s:GetWidth() or 0
    fill:SetWidth(span > 0 and math.max(0.001, w * (v - mn) / span) or 0.001)
  end

  s:SetScript("OnValueChanged", function(sl, v)
    v = snap(v)
    paint(v)
    if sl.quiet then return end
    if math.abs((spec.get() or 0) - v) > 1e-4 then
      spec.set(v)
      local now = spec.get()
      if now and math.abs(now - v) > 1e-4 then
        sl.quiet = true
        sl:SetValue(now)
        sl.quiet = nil
        paint(now)
      end
      -- The value and the layout stay live, the row pass is coalesced. A drag is one step
      -- per pixel and every one of them refreshed all six pages: about a hundred rows and a
      -- profile capture each. One deferred pass does the same work once the slider is still.
      -- OnMouseUp would be the wrong hook, since a programmatic SetValue never raises it.
      Options:RefreshSoon()
    end
  end)
  s:SetScript("OnSizeChanged", function() paint(snap(s:GetValue())) end)
  s:SetScript("OnEnter", function(sl)
    if not sl.offDuty then thumb:SetVertexColor(Theme:C("text")) end
  end)
  s:SetScript("OnLeave", function(sl)
    if sl.offDuty then thumb:SetVertexColor(Theme:C("faint"))
    else thumb:SetVertexColor(Theme:Thumb()) end
  end)

  row.Refresh = function()
    local on = not (spec.disabled and spec.disabled())
    s.offDuty = not on
    offDuty(row, not on)
    s:EnableMouse(on)
    fs:SetText(T(spec.name))
    fs:SetTextColor(Theme:C(on and "text" or "faint"))
    val:SetTextColor(Theme:C(on and "accentInk" or "faint"))
    if on then thumb:SetVertexColor(Theme:Thumb())
    else thumb:SetVertexColor(Theme:C("faint")) end
    fill:SetVertexColor(Theme:C(on and "accent" or "strokeSoft"))
    s.quiet = true
    s:SetMinMaxValues(minOf(), spec.max)
    s:SetValue(atLeastFloor())
    s.quiet = nil
    paint(atLeastFloor())
  end
  row.Refresh()
  tip(row, spec.desc)
  row.slider = s
  return row
end

local function cycle(spec, dir)
  local keys = spec.keys()
  local cur, idx = spec.get(), 1
  for i, k in ipairs(keys) do if k == cur then idx = i; break end end
  idx = idx + dir
  if idx < 1 then idx = #keys elseif idx > #keys then idx = 1 end
  spec.set(keys[idx])
  if ns.Profiles and ns.Profiles.SyncActive then ns.Profiles:SyncActive() end
end

-- The set a multi row holds, read back into the control's width.
local function fitList(fs, text, maxW)
  fs:SetText(text)
  if maxW <= 0 or fs:GetStringWidth() <= maxW then return end
  local stops = ns.CharStops(text)
  local lo, hi, best = 1, #stops - 1, 0
  while lo <= hi do
    local mid = math.floor((lo + hi) / 2)
    fs:SetText(text:sub(1, stops[mid + 1]) .. "…")
    if fs:GetStringWidth() <= maxW then best = mid; lo = mid + 1 else hi = mid - 1 end
  end
  fs:SetText(best == 0 and "…" or (text:sub(1, stops[best + 1]) .. "…"))
end

function factories.select(parent, spec)
  local bare = (spec.name == nil or spec.name == "")
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(bare and 26 or 46)

  local nameFS
  if not bare then
    nameFS = track(Theme:Label(row, BASE_FONT, "text"), 0)
    nameFS:SetPoint("TOPLEFT", 1, -1)
    nameFS:SetText(T(spec.name))
  end

  local btn = CreateFrame("Button", nil, row, "BackdropTemplate")
  ns.SnapBox(btn, nil, 24)
  btn:SetPoint("BOTTOMLEFT", 1, bare and 1 or 0)
  btn:SetPoint("BOTTOMRIGHT", -1, bare and 1 or 0)
  ns.PixelBackdrop(btn)
  ns.SetBg(btn, Theme:C("panel"))
  ns.SetEdge(btn, Theme:C("stroke"))

  local cur = track(Theme:Label(btn, BASE_FONT - 1, "text"), -1)
  cur:SetPoint("LEFT", 7, 0)
  cur:SetPoint("RIGHT", -18, 0)
  cur:SetJustifyH("LEFT")

  local arrowBox = ns.ArrowGlyph(btn, "down", 9)
  arrowBox:SetPoint("RIGHT", -7, 0)
  local function arrowColor(key) arrowBox:SetTint(key) end

  row.Refresh = function()
    local off = (spec.disabled and spec.disabled()) and true or false
    row.off = off
    offDuty(row, off)
    if nameFS then nameFS:SetText(T(spec.name)) end
    -- A set has no single value, so it reads its set back, trimmed.
    if spec.summary then
      local w = (btn:GetWidth() > 0 and btn:GetWidth() or CONTENT_W) - 25
      fitList(cur, spec.summary(), w)
    else
      cur:SetText(T(spec.label(spec.get())) or "")
    end
    cur:SetTextColor(Theme:C(off and "faint" or "text"))
    ns.SetBg(btn, Theme:C("panel"))
    ns.SetEdge(btn, Theme:C(off and "strokeSoft" or "stroke"))
    arrowColor(off and "faint" or "dim")
    btn:SetEnabled(not off)
  end
  btn.wpeDrop = { spec = spec, onPick = row.Refresh }
  row.Refresh()

  btn:SetScript("OnEnter", function(s)
    local open = isDropdownOpen(s)
    if spec.desc and not open then ns.ShowTip(row, { { text = spec.desc } }, "top") end
    if row.off then return end
    ns.SetBg(s, Theme:C("panelHi"))
    ns.SetEdge(s, Theme:C("accent"))
    arrowColor("accent")
  end)
  btn:SetScript("OnLeave", function(s)
    ns.HideTip()
    if row.off then return end
    ns.SetBg(s, Theme:C("panel"))
    ns.SetEdge(s, Theme:C("stroke"))
    arrowColor("dim")
  end)
  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  btn:SetScript("OnClick", function(s, button)
    if row.off then return end
    -- A set has no next value, so right click stays with single picks.
    if button == "RightButton" then
      if spec.summary then return end
      cycle(spec, -1)
      row.Refresh()
      return
    end
    openDropdown(s, spec, row.Refresh)
  end)
  tip(row, spec.desc)
  return row
end

local CHAR_COLS = 3
local CHAR_CELL_H, CHAR_HEAD_H, CHAR_DEL_H = 24, 22, 26

local function charHead(row, i)
  local h = row.heads[i]
  if h then return h end
  h = CreateFrame("Frame", nil, row)
  h:SetHeight(CHAR_HEAD_H)
  local line = Theme:Rect(h, "strokeSoft", "ARTWORK")
  ns.PixelLine(line, 1)
  line:SetPoint("BOTTOMLEFT", 0, 0)
  line:SetPoint("BOTTOMRIGHT", 0, 0)
  local fs = track(Theme:Label(h, BASE_FONT - 3, "azure"), -3)
  fs:SetPoint("BOTTOMLEFT", 0, 5)
  h.Text = fs
  row.heads[i] = h
  return h
end

local function dropChar(key)
  if not (key and ns.Vault:Delete(key)) then return end
  if ns.Bank and ns.Bank.frame then
    ns.Bank:UpdateCharBtn()
    if ns.Bank.frame:IsShown() then ns.Bank:Repaint() end
  end
  if Bags and Bags.snap and ns.Vault:ViewKey("bags") == ns.Vault:Owner() then
    Bags.snap = nil
    Bags:UpdateCharTag()
    if Bags.frame and Bags.frame:IsShown() then Bags:Layout() end
  end
  if Bags and Bags.BrowseState then Bags:BrowseState() end
  if ns.CharPicker then ns.CharPicker:Close() end
  if ns.Options and ns.Options.ReflowPages then ns.Options:ReflowPages() end
end

-- The gold store is wiped whole: it is one account-wide pool, so there is no per-character row to clear.
-- The current character is stamped straight back in (inside WipeGold), so the list is never left empty and
-- the logged-in character reads as the only remembered purse, which is what a wipe-while-online means.
local function wipeGold()
  if not ns.Vault:WipeGold() then return end
  if Bags and Bags.frame and Bags.frame:IsShown() then Bags:UpdateMeta() end
  if ns.Bank and ns.Bank.frame and ns.Bank.frame:IsShown() then ns.Bank:UpdateFooter() end
  if ns.Options and ns.Options.ReflowPages then ns.Options:ReflowPages() end
end

StaticPopupDialogs["WARPEE_DROP_CHAR"] = {
  text = "Delete saved bags and bank of %s?",
  button1 = _G.DELETE or "Delete",
  button2 = _G.CANCEL or "Cancel",
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  showAlert = true,
  OnAccept = function(_, key) dropChar(key) end,
}

local function dropWarband()
  if not ns.Vault:DropWarband() then return end
  if ns.Bank and ns.Bank.frame and ns.Bank.frame:IsShown() then ns.Bank:Repaint() end
  if Bags and Bags.BrowseState then Bags:BrowseState() end
  if ns.Options and ns.Options.ReflowPages then ns.Options:ReflowPages() end
end

StaticPopupDialogs["WARPEE_DROP_WARBAND"] = {
  text = "Delete the saved Warband bank?",
  button1 = _G.DELETE or "Delete",
  button2 = _G.CANCEL or "Cancel",
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  showAlert = true,
  OnAccept = function() dropWarband() end,
}

StaticPopupDialogs["WARPEE_WIPE_GOLD"] = {
  text = "Forget the remembered gold of every character?",
  button1 = _G.DELETE or "Delete",
  button2 = _G.CANCEL or "Cancel",
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  showAlert = true,
  -- The popup carries Text, not text, so the old self.text write threw on open.
  OnAccept = function() wipeGold() end,
}

-- Reset throws away every rule the player built, so it sits behind a confirm like the saved-data
-- deletes rather than firing on the click. Accept goes back through the editor's own reset hook, the
-- same path the other structural actions take, so the list is rebuilt and then scrolled to its first
-- row: the whole list was just replaced, and it should be read from the top.
StaticPopupDialogs["WARPEE_RESET_CATEGORIES"] = {
  text = "Reset the category list to the shipped one?",
  button1 = _G.ACCEPT or "Accept",
  button2 = _G.CANCEL or "Cancel",
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  showAlert = true,
  OnAccept = function()
    if Options.catReset then Options.catReset() end
  end,
}

local function charCell(row, i)
  local c = row.cells[i]
  if c then return c end
  c = CreateFrame("Button", nil, row)
  c:SetHeight(CHAR_CELL_H)
  local box = ns.CreateCheckBox(c, 16)
  ns.SnapPoint(box, "TOPLEFT", c, "TOPLEFT", 1, -4)
  local mark = box.mark
  local minus = Theme:Rect(box, "gaugeHi", "OVERLAY")
  ns.PixelLine(minus, 2)
  minus:SetPoint("LEFT", box, "LEFT", ns.PixelFloor(box, 3), 0)
  minus:SetPoint("RIGHT", box, "RIGHT", -ns.PixelFloor(box, 3), 0)
  minus:Hide()
  c.box, c.mark, c.minus = box, mark, minus
  local fs = track(Theme:Label(c, BASE_FONT - 2, "text"), -2)
  fs:SetPoint("LEFT", box, "RIGHT", 5, 0)
  fs:SetPoint("RIGHT", -2, 0)
  fs:SetJustifyH("LEFT")
  c.Text = fs

  c:SetScript("OnEnter", function(s)
    if row.delMode then
      s.box:SetKeys(nil, "gaugeHi", nil)
      s.Text:SetTextColor(Theme:C("gaugeHi"))
      return
    end
    if s.warband or s.gold then return end
    if not ns.Vault:Hidden(s.key or "") then
      s.box:SetKeys(nil, "bg", "accentInk")
    else
      s.box:SetKeys(nil, "accent", nil)
    end
  end)
  c:SetScript("OnLeave", function(s)
    s:Paint()
  end)
  c:SetScript("OnClick", function(s)
    if s.gold then
      if not row.delMode then return end
      StaticPopupDialogs["WARPEE_WIPE_GOLD"].text = L["Forget the remembered gold of every character?"]
      StaticPopup_Show("WARPEE_WIPE_GOLD")
      return
    end
    if s.warband then
      if not row.delMode then return end
      StaticPopupDialogs["WARPEE_DROP_WARBAND"].text = L["Delete the saved Warband bank?"]
      StaticPopup_Show("WARPEE_DROP_WARBAND")
      return
    end
    if not s.key then return end
    if row.delMode then
      StaticPopupDialogs["WARPEE_DROP_CHAR"].text = L["Delete saved bags and bank of %s?"]
      StaticPopup_Show("WARPEE_DROP_CHAR", s.Text:GetText() or s.key, nil, s.key)
      return
    end
    ns.Vault:SetHidden(s.key, not ns.Vault:Hidden(s.key))
    s:Paint()
    if s:IsMouseOver() then s:GetScript("OnEnter")(s) end
  end)
  c.Paint = function(s)
    if s.warband or s.gold then
      s.mark:SetShown(not row.delMode)
      s.minus:SetShown(row.delMode and true or false)
      s.box:SetKeys("slot", row.delMode and "gaugeHi" or "strokeSoft",
        row.delMode and "accent" or "dim")
      s.Text:SetTextColor(Theme:C(row.delMode and "text" or "dim"))
      return
    end
    local on = not ns.Vault:Hidden(s.key or "")
    if row.delMode then
      s.mark:Hide()
      s.minus:Show()
      s.box:SetKeys("slot", "gaugeHi", "accent")
      s.Text:SetTextColor(Theme:C(on and "text" or "dim"))
    else
      s.minus:Hide()
      s.mark:SetShown(on)
      s.box:SetKeys("slot", on and "bg" or "stroke", "accent")
      local cc = on and s.wpeClassColor or nil
      if cc then s.Text:SetTextColor(cc.r, cc.g, cc.b)
      else s.Text:SetTextColor(Theme:C(on and "text" or "dim")) end
    end
  end
  row.cells[i] = c
  return c
end

function factories.chars(parent, spec)
  local row = CreateFrame("Frame", nil, parent)
  row.heads, row.cells = {}, {}
  row.dynamic = true

  local del = ns.CreateButton(row, L["Delete mode"], 104, CHAR_DEL_H)
  ns.LocalText(del, "Delete mode")
  local function paintDel(hover)
    local key = row.delMode and "gaugeHi" or (hover and "accent" or "dim")
    ns.SetBg(del, Theme:C(hover and "panelHi" or "panel"))
    ns.SetEdge(del, Theme:C(key))
    del.Text:SetTextColor(Theme:C(key))
  end
  del:SetScript("OnEnter", function() paintDel(true) end)
  del:SetScript("OnLeave", function() paintDel(false) end)
  del:SetScript("OnClick", function()
    row.delMode = (not row.delMode) or nil
    row.Rebuild()
    paintDel(del:IsMouseOver())
  end)
  row.delBtn, row.paintDel = del, paintDel

  row.Rebuild = function()
    local list = (ns.Vault and ns.Vault:Chars(true)) or {}
    local wbSaved = (ns.Vault and ns.Vault:Saved("warband")) and true or false
    local anyGold = (ns.Vault and ns.Vault:HasGold()) and true or false
    if #list == 0 and not wbSaved and not anyGold then row.delMode = nil end
    local path = ns.Fonts:Current()
    local colW = math.floor((CONTENT_W - (CHAR_COLS - 1) * 8) / CHAR_COLS)
    del.Text:SetFont(path, math.max(7, BASE_FONT - 1), ns.OutlineFlags())
    del:SetWidth(math.max(104, math.ceil(del.Text:GetStringWidth()) + 26))
    del:SetShown(#list > 0 or wbSaved or anyGold)
    paintDel(false)
    local y, hi, ci, col, realm = 0, 0, 0, 0, nil
    for _, e in ipairs(list) do
      if e.realm ~= realm then
        realm = e.realm
        if col > 0 then y = y + CHAR_CELL_H; col = 0 end
        if y > 0 then y = y + 6 end
        hi = hi + 1
        local h = charHead(row, hi)
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", 0, -y)
        h:SetPoint("TOPRIGHT", 0, -y)
        h.Text:SetText(ns.Upper(realm or "?"))
        h.Text:SetFont(path, math.max(7, BASE_FONT - 3), ns.OutlineFlags())
        h:Show()
        y = y + CHAR_HEAD_H + 2
      end
      ci = ci + 1
      local c = charCell(row, ci)
      c.key, c.warband, c.gold = e.key, nil, nil
      c:SetWidth(colW)
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", col * (colW + 8), -y)
      local cc = e.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.class]
      c.wpeClassColor = cc
      c.Text:SetText(e.name)
      c.Text:SetFont(path, math.max(7, BASE_FONT - 2), ns.OutlineFlags())
      c:Paint()
      c:Show()
      col = col + 1
      if col >= CHAR_COLS then col = 0; y = y + CHAR_CELL_H end
    end
    if col > 0 then y = y + CHAR_CELL_H end
    local goldSaved = (ns.Vault and ns.Vault:HasGold()) and true or false
    if wbSaved or goldSaved then
      if y > 0 then y = y + 6 end
      hi = hi + 1
      local h = charHead(row, hi)
      h:ClearAllPoints()
      h:SetPoint("TOPLEFT", 0, -y)
      h:SetPoint("TOPRIGHT", 0, -y)
      h.Text:SetText(ns.Upper(L["Account"]))
      h.Text:SetFont(path, math.max(7, BASE_FONT - 3), ns.OutlineFlags())
      h:Show()
      y = y + CHAR_HEAD_H + 2
      local acol = 0
      if wbSaved then
        ci = ci + 1
        local c = charCell(row, ci)
        c.key, c.warband, c.gold = nil, true, nil
        c:SetWidth(colW)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", 0, -y)
        c.wpeClassColor = nil
        c.Text:SetText(L["Warband bank"])
        c.Text:SetFont(path, math.max(7, BASE_FONT - 2), ns.OutlineFlags())
        c:Paint()
        c:Show()
        acol = 1
      end
      if goldSaved then
        ci = ci + 1
        local c = charCell(row, ci)
        c.key, c.warband, c.gold = nil, nil, true
        c:SetWidth(colW)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", acol * (colW + 8), -y)
        c.wpeClassColor = nil
        -- Just the word: one account-wide line that the delete mode clears. No live total beside it, so the
        -- row never has to be rebuilt as the purse changes.
        c.Text:SetText(L["Gold"])
        c.Text:SetFont(path, math.max(7, BASE_FONT - 2), ns.OutlineFlags())
        c:Paint()
        c:Show()
        acol = acol + 1
      end
      y = y + CHAR_CELL_H
    end
    for i = hi + 1, #row.heads do row.heads[i]:Hide() end
    for i = ci + 1, #row.cells do row.cells[i]:Hide() end
    if #list > 0 or wbSaved or goldSaved then
      del:ClearAllPoints()
      del:SetPoint("TOP", row, "TOP", 0, -(y + 8))
      y = y + 8 + CHAR_DEL_H
    end
    row:SetHeight(math.max(CHAR_CELL_H, y))
  end
  row.Refresh = row.Rebuild
  Options.charsRow = row
  return row
end

local SL_ROW_H = 22

local function sellRow(row, i)
  local c = row.items[i]
  if c then return c end
  c = CreateFrame("Frame", nil, row)
  c:SetHeight(SL_ROW_H)
  local ic = c:CreateTexture(nil, "ARTWORK")
  ic:SetSize(16, 16)
  ic:SetPoint("LEFT", 1, 0)
  c.icon = ic
  local x = ns.CreateGlyphButton(c, "×", 18)
  x:SetPoint("RIGHT", -1, 0)
  x:SetScript("OnClick", function()
    if c.key and ns.Vendor then ns.Vendor:Unmark(c.key) end
  end)
  c.del = x
  local fs = track(Theme:Label(c, BASE_FONT - 2, "text"), -2)
  fs:SetFont(dropdownFont(), BASE_FONT - 2, ns.OutlineFlags())
  fs:SetPoint("LEFT", ic, "RIGHT", 6, 0)
  fs:SetPoint("RIGHT", x, "LEFT", -6, 0)
  fs:SetJustifyH("LEFT")
  c.Text = fs
  row.items[i] = c
  return c
end

function factories.selllist(parent, spec)
  local row = CreateFrame("Frame", nil, parent)
  row.items = {}
  row.dynamic = true
  local empty = track(Theme:Label(row, BASE_FONT - 2, "faint"), -2)
  empty:SetFont(dropdownFont(), BASE_FONT - 2, ns.OutlineFlags())
  empty:SetPoint("TOPLEFT")
  empty:SetWidth(CONTENT_W)
  empty:SetJustifyH("LEFT")
  empty:SetText(L["Alt + LMB on an item in your bags to mark it for sale."])
  ns.LocalText(empty, "Alt + LMB on an item in your bags to mark it for sale.")
  row.empty = empty
  row.Rebuild = function()
    local list = ns.Vendor and ns.Vendor:SellList() or {}
    local y = 0
    row.empty:SetShown(#list == 0)
    if #list == 0 then
      y = math.ceil(row.empty:GetStringHeight()) + 4
    else
      for i, e in ipairs(list) do
        local c = sellRow(row, i)
        c.key = e.key
        c.Text:SetText(e.name or tostring(e.id))
        c.icon:SetTexture(e.icon or ns.PinIcon(e.id))
        -- A locked entry is the one the carousel will not sell; the row says so in red, since the
        -- lock is the state a sale would silently skip.
        if e.locked then
          c.Text:SetTextColor(1, 0.4, 0.4)
        else
          c.Text:SetTextColor(Theme:C("text"))
        end
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", 0, -y)
        c:SetPoint("TOPRIGHT", 0, -y)
        c:Show()
        y = y + SL_ROW_H + 2
      end
    end
    for i = #list + 1, #row.items do row.items[i]:Hide() end
    row:SetHeight(math.max(SL_ROW_H, y))
  end
  row.Refresh = row.Rebuild
  row.Rebuild()
  Options.sellRow = row
  return row
end

function factories.badges(parent, spec)
  local PREV = bg.prev
  local row = CreateFrame("Frame", nil, parent)
  row.dynamic = true

  local cell = CreateFrame("Frame", nil, row, "BackdropTemplate")
  ns.SnapBox(cell, PREV, PREV)
  ns.PixelBackdrop(cell)
  cell:EnableMouse(true)

  local mark = CreateFrame("Frame", nil, cell, "BackdropTemplate")
  ns.PixelBackdrop(mark)
  -- Above every badge frame in the preview, including the lifted one being edited: the ring has to be
  -- seen around it.
  mark:SetFrameLevel(cell:GetFrameLevel() + 20)
  mark:Hide()

  local readout = track(Theme:Label(row, BASE_FONT - 1, "accentInk"), -1)
  readout:SetJustifyH("LEFT")

  local hint = track(Theme:Label(row, BASE_FONT - 3, "dim"), -3)
  hint:SetJustifyH("LEFT")

  -- The preview keeps its badges in the same per-badge frames the cells use, so the order the list sets
  -- is what the player sees here too.
  local art, chips = {}, {}
  for _, d in ipairs(ns.BADGES) do
    local holder = ns.BadgeFrame(cell, d.key)
    if d.tex then
      local t = holder:CreateTexture(nil, "OVERLAY")
      ns.BadgeArt(t, d.key)
      art[d.key] = t
    else
      art[d.key] = Theme:Label(holder, BASE_FONT, "overlay")
    end
  end

  local function factor() return PREV / bg.cell() end

  local function measure(key)
    local d = ns.BADGE[key] or ns.BADGES[1]
    -- Read everything off the resolved def's key, not the raw argument: the fallback above is only real
    -- if an unknown key then draws from BADGES[1] too, otherwise art[key] is nil and GetStringWidth throws.
    key = d.key or key
    if d.tex then
      local sz = math.max(6, PREV * (ns.Badge(key).s or d.s))
      return sz, sz
    end
    local o = art[key]
    return o:GetStringWidth() or 0, o:GetStringHeight() or 0
  end

  local function span(key)
    local f = factor()
    if f <= 0 then f = 1 end
    local w, h = measure(key or bg.sel)
    return w / f, h / f,
           (cell:GetWidth() or 0) / f, (cell:GetHeight() or 0) / f
  end

  bg.spanW = function(key) local w = span(key); return w end

  bg.fit = function(field, v, key)
    local w, h, W, H = span(key)
    local g = (key and ns.Badge(key)) or bg.cur()
    local c = g.c or ""
    local horiz = field == "x"
    local size, box = horiz and w or h, horiz and W or H
    v = math.floor((tonumber(v) or 0) + 0.5)
    if size <= 0 or box <= 0 then return v end
    local lo, hi
    if horiz then
      local base = c:find("LEFT") and 0 or box
      local shift = (0.5 - bg.alignOff[bg.alignOf(g)]) * size
      lo, hi = -base - shift, box - base - shift
    elseif c:find("BOTTOM") then lo, hi = -size / 2, box - size / 2
    else lo, hi = size / 2 - box, size / 2 end
    if v < lo then return math.ceil(lo) end
    if v > hi then return math.floor(hi) end
    return v
  end

  local function paintChip(c)
    local sel, on = c.wpeKey == bg.sel, ns.Badge(c.wpeKey).on
    local hover = c:IsMouseOver()
    ns.SetBg(c, Theme:C(hover and "panelHi" or "panel"))
    ns.SetEdge(c, Theme:C(sel and "accent" or (hover and "accentInk" or "stroke")))
    -- Selection and hover show in the edge; the label keeps its ink (faint only when the badge is off),
    -- so the word is never painted over.
    c.Text:SetTextColor(Theme:C((not on) and "faint" or "text"))
  end

  local function paint()
    bg.normalize()
    local f, solo = factor(), bg.soloGet()
    ns.SetBg(cell, Theme:C("panel"))
    ns.SetEdge(cell, Theme:C("stroke"))
    ns.SetBg(mark, 0, 0, 0, 0)
    ns.SetEdge(mark, Theme:C("accent"))
    for _, d in ipairs(ns.BADGES) do
      local g, o, sel = ns.Badge(d.key), art[d.key], d.key == bg.sel
      local vis = (g.on and (sel or not solo)) and true or false
      local dim = sel and 1 or 0.35
      if d.tex then
        local sz = measure(d.key)
        o:SetSize(sz, sz)
        o:SetVertexColor(1, 1, 1, dim)
      else
        local cr, cg, cb = Theme:C("overlay")
        -- Through the same helper the grid draws with, so the preview shows the floor where
        -- the floor is what decides the size. It is magnified by f, not drawn at f.
        ns.SetOutlined(o, math.floor(ns.BadgeSize(d.key, bg.cell(), g) * f + 0.5))
        o:SetText(ns.BadgeSample(d.key) or d.key)
        o:SetTextColor(cr, cg, cb, dim)
      end
      -- Through the per-badge frame the cells also use, so the order from the list is the order the
      -- preview shows. The one being edited is lifted over the rest: a badge you cannot see is a badge
      -- you cannot drag. The stack count keeps the lowest place it has on a cell.
      local at, n = ns.BadgeOrderAt(d.key)
      local holder = ns.BadgeFrame(cell, d.key)
      holder:SetFrameLevel(ns.BadgeLevel(cell, d.key, at, n, sel))
      o:ClearAllPoints()
      -- The offsets go through the same call the grid places with, so the preview cannot show a
      -- placement the cell would not make -- the panel is magnified, and the rule holds at any
      -- magnification: an inset never rounds away to nothing.
      o:SetPoint(ns.BadgePoint(g), cell, g.c, ns.BadgeOffset(g.x, f), ns.BadgeOffset(g.y, f))
      o:SetShown(vis)
      if sel then
        local cl, ct = cell:GetLeft(), cell:GetTop()
        local ol, ot = o:GetLeft(), o:GetTop()
        mark:ClearAllPoints()
        if cl and ct and ol and ot then
          ns.SnapSize(mark, (o:GetWidth() or 0) + 6, (o:GetHeight() or 0) + 6)
          ns.SnapPoint(mark, "TOPLEFT", cell, "TOPLEFT", ol - cl - 3, ot - ct + 3)
        else
          mark:SetPoint("TOPLEFT", o, "TOPLEFT", -3, 3)
          mark:SetPoint("BOTTOMRIGHT", o, "BOTTOMRIGHT", 3, -3)
        end
        mark:SetShown(vis)
      end
    end
    local g = bg.cur()
    readout:SetText(("%s\nx %d\ny %d")
      :format(T(ANCHOR_LABELS[g.c] or g.c), g.x or 0, g.y or 0))
    readout:SetTextColor(Theme:C("accentInk"))
    hint:SetText(bg.hintText())
    for _, c in ipairs(chips) do paintChip(c) end
  end

  local function layoutChips()
    local path, gap, cols = ns.Fonts:Current(), 6, 3
    local w = math.floor((CONTENT_W - gap * (cols - 1)) / cols)
    for i, c in ipairs(chips) do
      c.Text:SetFont(path, BASE_FONT - 2, ns.OutlineFlags())
      c:SetWidth(w)
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", row, "TOPLEFT",
        ((i - 1) % cols) * (w + gap), -math.floor((i - 1) / cols) * 26)
    end
    return math.ceil(#chips / cols) * 26
  end

  for _, d in ipairs(ns.BADGES) do
    local c = ns.CreateButton(row, T(d.n or d.key), 62, 22)
    c.wpeKey = d.key
    ns.LocalText(c, d.n or d.key)
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    c:SetScript("OnEnter", paintChip)
    c:SetScript("OnLeave", paintChip)
    c:SetScript("OnClick", function(s, button)
      local g = ns.Badge(s.wpeKey)
      -- fixed: the right click that hides the other badges does nothing on the one that cannot go.
      if button == "RightButton" then
        if g.on and not d.fixed then g.on = false; bg.bump() end
      else
        if not g.on then g.on = true; bg.bump() end
        bg.sel = s.wpeKey
      end
      Options:ReflowPages()
    end)
    tip(c, d.t)
    chips[#chips + 1] = c
  end

  local function cursorXY()
    local s = cell:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    return cx / s - (cell:GetLeft() or 0), cy / s - (cell:GetBottom() or 0)
  end

  local function corner(o)
    local g = bg.cur()
    local c = g.c or "TOPLEFT"
    local cl, cb = cell:GetLeft() or 0, cell:GetBottom() or 0
    local a = bg.alignOf(g)
    local l, r = o:GetLeft() or 0, o:GetRight() or 0
    local x = (a == "left" and l or (a == "right" and r or (l + r) / 2)) - cl
    local y = (c:find("BOTTOM") and (o:GetBottom() or 0) or (o:GetTop() or 0)) - cb
    return x, y
  end

  local function place(px, py)
    local g, f = bg.cur(), factor()
    local c = g.c or "TOPLEFT"
    local W, H = cell:GetWidth() or 0, cell:GetHeight() or 0
    g.x = bg.pin("x", (c:find("LEFT") and px or (px - W)) / f)
    g.y = bg.pin("y", (c:find("BOTTOM") and py or (py - H)) / f)
  end

  local function center(px, py)
    local g, f = bg.cur(), factor()
    local c = g.c or "TOPLEFT"
    local w, h = measure(bg.sel)
    local W, H = cell:GetWidth() or 0, cell:GetHeight() or 0
    local l = math.min(W, math.max(0, px)) - w / 2
    local d = math.min(H, math.max(0, py)) - h / 2
    local ref = l + bg.alignOff[bg.alignOf(g)] * w
    g.x = bg.pin("x", (ref - (c:find("LEFT") and 0 or W)) / f)
    g.y = bg.pin("y", (c:find("BOTTOM") and d or (d + h - H)) / f)
  end

  local grab
  local function stop()
    grab = nil
    cell:SetScript("OnUpdate", nil)
    bg.bump()
    Options:ReflowPages()
  end

  local function hit(px, py)
    local first
    -- Walked backwards, so of several badges under the cursor the click takes the one drawn over the
    -- others -- among the unselected ones that is the last one built. The current selection still wins
    -- outright, so a click on the badge already chosen never moves the choice.
    for i = #ns.BADGES, 1, -1 do
      local d = ns.BADGES[i]
      local o = art[d.key]
      if ns.Badge(d.key).on and o:IsShown() then
        local l = (o:GetLeft() or 0) - (cell:GetLeft() or 0)
        local b = (o:GetBottom() or 0) - (cell:GetBottom() or 0)
        if px >= l - 3 and px <= l + (o:GetWidth() or 0) + 3
           and py >= b - 3 and py <= b + (o:GetHeight() or 0) + 3 then
          if d.key == bg.sel then return d.key end
          first = first or d.key
        end
      end
    end
    return first
  end

  cell:SetScript("OnMouseDown", function(s, button)
    if button ~= "LeftButton" then return end
    local px, py = cursorXY()
    local under = hit(px, py)
    if under and under ~= bg.sel then
      bg.sel = under
      Options:ReflowPages()
    end
    local g, o = bg.cur(), art[bg.sel]
    local w, h = o:GetWidth() or 0, o:GetHeight() or 0
    local ox = (o:GetLeft() or 0) + w / 2 - (cell:GetLeft() or 0)
    local oy = (o:GetBottom() or 0) + h / 2 - (cell:GetBottom() or 0)
    local held = g.on and math.abs(px - ox) <= w / 2 + 4
                      and math.abs(py - oy) <= h / 2 + 4
    if not held then g.on = true; center(px, py); paint() end
    local cx, cy = corner(o)
    grab = { dx = cx - px, dy = cy - py }
    s:SetScript("OnUpdate", function()
      if not (grab and IsMouseButtonDown("LeftButton")) then stop(); return end
      local x, y = cursorXY()
      place(x + grab.dx, y + grab.dy)
      paint()
    end)
  end)

  row.Refresh = function()
    local h = layoutChips()
    cell:ClearAllPoints()
    ns.SnapPoint(cell, "TOPLEFT", row, "TOPLEFT",
      math.floor((CONTENT_W - PREV) / 2), -(h + 16))
    readout:ClearAllPoints()
    readout:SetPoint("LEFT", row, "TOPLEFT", 2, -(h + 16 + PREV / 2))
    hint:ClearAllPoints()
    hint:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -(h + 16 + PREV + 3))
    hint:SetWidth(CONTENT_W)
    paint()
    local hh = 0
    if (hint:GetText() or "") ~= "" then
      hh = math.max(14, math.ceil(hint:GetStringHeight() or 14))
    end
    local moved = false
    for _, d in ipairs(ns.BADGES) do
      local g = ns.Badge(d.key)
      local x, y = bg.fit("x", g.x, d.key), bg.fit("y", g.y, d.key)
      if x ~= g.x or y ~= g.y then g.x, g.y = x, y; moved = true end
    end
    if moved then
      -- Paced like every slider: a size drag re-fits badges every frame.
      relayoutLive()
    end
    row:SetHeight(h + PREV + 18 + hh)
  end
  row.Rebuild = row.Refresh
  bg.repaint = paint
  row.Refresh()
  tip(cell, spec.desc)
  return row
end

-- The badge order: one line per badge, the top line drawn over the ones below it, moved the same way the
-- category list moves a row — grab the dots and drag, one accent line marking the slot the drop lands in.
-- The stack count gets a line of its own at the bottom with no grip: it is the game's own number on the
-- button, under every frame of ours, so nothing here can lift it over the others.
function factories.badgeorder(parent, spec)
  local row = CreateFrame("Frame", nil, parent)
  row.items = {}
  row.dynamic = true
  local LINE_H = 22
  local dragFrom, grabOff, dragLvl, dropTo

  -- The cursor's height down the list, in the list's own coordinates. nil while the scale is not ready, so
  -- every caller can bail instead of guessing.
  local function cursorOff()
    local scale = row:GetEffectiveScale()
    if not scale or scale == 0 then return nil end
    local _, cy = GetCursorPosition()
    return (row:GetTop() or 0) - (cy / scale)
  end

  -- The line the held row would be inserted before, read off the float's own middle rather than the bare
  -- cursor: the float rides at cursor - grabOff, so keying the slot off the cursor aimed half a line away
  -- from what the eye sees. Past the last movable line the answer is that line plus one, which is the top
  -- of the fixed count.
  local function dropSlot()
    local off = cursorOff()
    if not off then return nil end
    local n = #ns.BadgeOrder()
    local cy = off - (grabOff or 0) + LINE_H / 2
    for i = 1, n do
      if cy < (i - 1) * LINE_H + LINE_H / 2 then return i end
    end
    return n + 1
  end

  -- The line marking the slot, on its own thin frame lifted above the lines: they are child frames, so a
  -- texture on the parent would draw under them and vanish on a line's own edge.
  local function dropMark()
    local m = row.dropMark
    if m then return m end
    local f = CreateFrame("Frame", nil, row)
    f:SetHeight(2)
    f:SetFrameLevel(row:GetFrameLevel() + 30)
    local line = Theme:Rect(f, "accent", "OVERLAY")
    line:SetAllPoints(f)
    f:Hide()
    row.dropMark = f
    return f
  end

  local function onDragUpdate()
    local off = cursorOff()
    if not off then return end
    local fr = dragFrom and row.items[dragFrom]
    if fr then
      local fy = off - (grabOff or 0)
      local maxY = math.max(0, #ns.BadgeOrder() * LINE_H - LINE_H)
      if fy < 0 then fy = 0 elseif fy > maxY then fy = maxY end
      fr:ClearAllPoints()
      fr:SetPoint("TOPLEFT", 0, -fy)
      fr:SetPoint("TOPRIGHT", 0, -fy)
    end
    dropTo = dropSlot()
    -- A line's own place takes no marker: a drop there moves nothing, and both edges of that place are the
    -- same non-move, so the line would read as two different targets on a line already where it would land.
    if dragFrom and (dropTo == dragFrom or dropTo == dragFrom + 1) then dropTo = nil end
    local m = dropMark()
    if dropTo then
      local y = -(dropTo - 1) * LINE_H
      m:ClearAllPoints()
      m:SetPoint("TOPLEFT", 0, y)
      m:SetPoint("TOPRIGHT", 0, y)
      m:Show()
    else
      m:Hide()
    end
  end

  local function startDrag(i)
    dragFrom = i
    row.dragging = i
    local off = cursorOff()
    grabOff = off and (off - (i - 1) * LINE_H) or (LINE_H / 2)
    -- Lifted so the held line reads as picked up and is not drawn under the lines it passes. Put back on
    -- drop, since the rebuild does not touch a line's level.
    local fr = row.items[i]
    if fr then
      dragLvl = fr:GetFrameLevel()
      fr:SetFrameLevel(row:GetFrameLevel() + 20)
    end
    row:SetScript("OnUpdate", onDragUpdate)
  end

  local function stopDrag()
    row:SetScript("OnUpdate", nil)
    row.dragging = nil
    if row.dropMark then row.dropMark:Hide() end
    local from = dragFrom
    local fr = from and row.items[from]
    if fr and dragLvl then fr:SetFrameLevel(dragLvl) end
    dragFrom, dragLvl, dropTo = nil, nil, nil
    if not from then return end
    local slot = dropSlot()
    -- Back on its own place is not a move: rebuild to put the float back and leave the order alone, rather
    -- than writing the same list and re-dressing every cell for a drag that changed nothing.
    if not slot or slot == from or slot == from + 1 then row.Rebuild(); return end
    -- One move of one line, to the slot the marker showed. The count is not in this list, so it stays.
    local order = ns.BadgeOrder()
    local v = table.remove(order, from)
    if v then table.insert(order, slot > from and slot - 1 or slot, v) end
    WarpeeDB.badgeOrder = order
    -- The cells keep their frames; only the level each one draws at moves, so this is the same re-dress a
    -- font or theme change takes, and the preview beside it follows the new order.
    ns.BadgeOrderBump()
    bg.bump()
    row.Rebuild()
  end

  -- The grip: six dots in two columns, the glyph the category list uses for this same gesture, which a
  -- player already reads as "grab and drag this". One gesture for one action: no arrows beside it.
  local function makeGrip(c)
    local b = CreateFrame("Button", nil, c)
    ns.SnapBox(b, 12, LINE_H, true)
    b.dots = {}
    for k = 1, 6 do
      local d = b:CreateTexture(nil, "ARTWORK")
      d:SetColorTexture(Theme:C("dim"))
      ns.SnapSize(d, 2, 2)
      local col = (k - 1) % 2
      local rowk = math.floor((k - 1) / 2)
      d:SetPoint("CENTER", b, "CENTER", col == 0 and -2 or 2, (rowk - 1) * 4 + 2)
      b.dots[k] = d
    end
    local function paint(key)
      for _, d in ipairs(b.dots) do d:SetColorTexture(Theme:C(key)) end
    end
    Theme:Track(b, function() paint("dim") end)
    b:SetScript("OnEnter", function()
      paint("accent")
      GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
      GameTooltip:SetText(ns.L["Drag to reorder"], 1, 1, 1)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() paint("dim"); GameTooltip:Hide() end)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function() startDrag(c.wpeAt) end)
    b:SetScript("OnDragStop", stopDrag)
    return b
  end

  local function line(i, key, fixed)
    local r = row.items[i]
    if not r then
      r = CreateFrame("Frame", nil, row)
      r:SetHeight(LINE_H)
      -- The colour key is fixed when the line is built, because the theme tracker owns it from then on:
      -- a line is either one of the ordered badges or the fixed count, never both.
      r.name = track(Theme:Label(r, BASE_FONT - 1, fixed and "faint" or "text"), -1)
      r.name:SetJustifyH("LEFT")
      r.grip = makeGrip(r)
      ns.SnapPoint(r.grip, "LEFT", r, "LEFT", 1, 0)
      ns.SnapPoint(r.name, "LEFT", r.grip, "RIGHT", 8, 0)
      row.items[i] = r
    end
    local d = ns.BADGE[key] or {}
    r.wpeKey = key
    -- What the drag reads: nil on the count, which is not in the list at all.
    r.wpeAt = fixed and nil or i
    r.name:SetText(T(d.n or key))
    ns.LocalText(r.name, d.n or key)
    r.grip:SetShown(not fixed)
    return r
  end

  row.Rebuild = function()
    local order = ns.BadgeOrder()
    local n = #order
    for i = 1, n do
      local r = line(i, order[i], false)
      -- The held line is placed by the drag pass while it is in the air; the next rebuild puts it back.
      if row.dragging ~= i then
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, -((i - 1) * LINE_H))
        r:SetPoint("TOPRIGHT", 0, -((i - 1) * LINE_H))
      end
      r:Show()
    end
    -- The count is the one badge nobody orders: the game's own string on the button, under every frame of
    -- ours, so its line stands last and carries no grip.
    local c = line(n + 1, "count", true)
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", 0, -(n * LINE_H))
    c:SetPoint("TOPRIGHT", 0, -(n * LINE_H))
    c:Show()
    for i = n + 2, #row.items do row.items[i]:Hide() end
    row:SetHeight((n + 1) * LINE_H)
  end
  row.Refresh = row.Rebuild
  row.Rebuild()
  return row
end

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
function factories.catlist(parent, spec)
  local Cats = ns.Categories
  local CAT_ROW_H = 26
  -- The category name field's width. Fixed, so the "+"/"×" pair lines up in one column down the list
  -- rather than jostling to each name's length, and the same regardless of how long a name is — the row
  -- carries only the name now, so it can be generous.
  local NAME_W = math.floor((CONTENT_W - 60) * 0.72)
  local row = CreateFrame("Frame", nil, parent)
  row.items = {}
  -- The one panel pool, keyed by row index: each row's rule + pins panel lives here.
  row.build = {}
  -- Which categories have their pin panel forced open, keyed by category id. A category with pins
  -- shows the panel anyway; this is what opens it for one with none yet, so the id box is reachable
  -- without first dragging an item in. Session state, not saved: it is only which panels are unfolded.
  row.openPins = {}
  -- The chosen All/Any per category id. A rule of 0-1 conditions writes no join into its string (there is
  -- no separator to carry it), so a reflow would always read back "all" and snap the toggle. This remembers
  -- the pick so it holds; a rule of 2+ conditions carries its own join and updates this to match.
  row.matchMode = {}
  row.dynamic = true
  local function pageOpen() return Options.frame and Options.frame:IsShown() end

  -- Debounce: a text field runs a full bag scan for its count and a bag relayout, so a per
  -- keystroke run would lag the typing. Each change bumps the token and schedules the commit
  -- 0.3s out; only the last one, and only while the page is still open, actually fires.
  local token = 0
  local function debounce(fn)
    token = token + 1
    local mine = token
    C_Timer.After(0.3, function()
      if mine == token and pageOpen() then fn() end
    end)
  end
  local function cancelPending() token = token + 1 end

  local function blur()
    for _, c in ipairs(row.items) do
      if c.nameBox:HasFocus() then c.nameBox:ClearFocus() end
    end
    -- The rule lives in the panel now, not the row: blur its raw text box too, so a code paste or a reset
    -- does not land while a rule field still holds the caret. The id box closes on its own focus loss.
    for _, p in pairs(row.build) do
      if p.rawBox and p.rawBox:HasFocus() then p.rawBox:ClearFocus() end
    end
  end

  -- Forward-declared: act() reveals what a mutator made, and the reveal reads the offsets the rebuild
  -- lays down, so it is defined with the list body further down this factory.
  local reveal, flashSeq
  -- Forward-declared too: the word picker is defined further down (it needs the axis labels and the shared
  -- popup), but buildPanel's "+ condition" button, defined above it, opens it.
  local openCatPicker
  -- The word list the rule band's "?" opens. Forward-declared with the picker: the button is built in the
  -- panel, the window further down beside the picker it belongs with.
  local showCatHelp

  -- What the share line says back. A code cannot answer in the field it was typed into, so the result of
  -- reading one — how much was written, or why nothing was — goes to the chat frame, the way the profile
  -- panel's own messages do.
  local function say(msg)
    print("|cffd9a85fWarpee|r |cffffffff" .. tostring(msg) .. "|r")
  end

  -- The structural actions do not debounce: one click, one immediate rebuild and relayout. Blur
  -- first so a field mid-edit commits and drops focus before the pool is rebound underneath it.
  -- A mutator hands back the index of the row it created, and that row is then scrolled into view and
  -- flashed: a row added at the bottom of a long list is invisible from the top of it, and the click
  -- would read as if nothing had happened at all.
  local function act(fn)
    blur()
    cancelPending()
    closeDropdown()
    local at = fn()
    Options:ReflowPages()
    relayout()
    if type(at) == "number" then reveal(at) end
  end

  -- The edit box itself (Features/CatListBox.lua), shared by the row's name field, the codes field below and
  -- the panel's own fields.
  local makeBox = factories.catlistbox({ baseFont = BASE_FONT, dropdownFont = dropdownFont })

  -- The drag handle: six dots in two columns, the grip glyph a player already reads as "grab and
  -- drag this row" without a hint, which the paired carets did not. It fills the row height for an
  -- easy target and lights accent on hover. The dots track the theme through Theme:Track like every
  -- other painted piece. The drag wiring itself is hung on it in catRow, next to the row it moves.
  local function makeGrip(c)
    local b = CreateFrame("Button", nil, c)
    ns.SnapBox(b, 12, CAT_ROW_H, true)
    b.dots = {}
    for k = 1, 6 do
      local d = b:CreateTexture(nil, "ARTWORK")
      d:SetColorTexture(Theme:C("dim"))
      ns.SnapSize(d, 2, 2)
      local col = (k - 1) % 2
      local rowk = math.floor((k - 1) / 2)
      d:SetPoint("CENTER", b, "CENTER", col == 0 and -2 or 2, (rowk - 1) * 4 + 2)
      b.dots[k] = d
    end
    local function paint(key)
      for _, d in ipairs(b.dots) do d:SetColorTexture(Theme:C(key)) end
    end
    Theme:Track(b, function() paint("dim") end)
    b:SetScript("OnEnter", function()
      paint("accent")
      GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
      GameTooltip:SetText(ns.L["Drag to reorder"], 1, 1, 1)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() paint("dim"); GameTooltip:Hide() end)
    return b
  end

  -- The marker widgets a pooled row switches on when it is a group header or a divider: the hairline and
  -- the faint caption a divider carries in place of a name. They are made on the row when it first plays
  -- that part, so one pool holds every kind of row and a reorder that turns a category row into a marker
  -- row needs no second pool. The row's own name box serves as the header's name field.
  --
  -- A marker carries no move arrows of its own: it has the same grip on its left that every category row
  -- has, and one gesture for one action is the point — a band that could be stepped with a button read as
  -- though only markers were movable, and the pair of carets spent the room the group's own name wants.
  local function headPart(r)
    if r.headLine then return r end
    local line = r:CreateTexture(nil, "ARTWORK")
    ns.PixelLine(line, 1)
    r.headLine = line

    local cap = Theme:Label(r, BASE_FONT - 2, "faint")
    ns.LocalText(cap, "Divider")
    r.divCap = cap
    return r
  end

  local function headPaint(r, hot)
    r.wpeHot = hot
    if not r.nameBox:HasFocus() then ns.SetEdge(r.nameBox, Theme:C(hot and "accent" or "stroke")) end
    if r.headLine then r.headLine:SetColorTexture(Theme:C(hot and "accent" or "stroke")) end
  end

  -- Commit a row's title: a marker's own name goes to the marker, a category's override to the record.
  -- Both are read back off the list at the row's index, so a commit carries no state across a rebuild.
  local function commitName(r, text)
    local e = Cats:List()[r.idx]
    if Cats.IsMarker(e) then Cats:SetGroupName(e, text) else Cats:SetName(r.idx, text) end
  end

  -- The pinned ids of a list row, in id order so the chips keep a stable place across rebuilds.
  -- Read straight off the saved record like the editor reads name and search; nil pins means none.
  local function pinIds(c)
    local out = {}
    if type(c) == "table" and type(c.pins) == "table" then
      for id in pairs(c.pins) do out[#out + 1] = id end
      -- Compared as text, not by raw key: a pin can be the plain id a drop or a typed number handed over,
      -- or the item string the cursor gave, and sorting a number against a string would abort the whole
      -- row's layout and leave the panel looking like it ignored the click that caused it.
      table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
    end
    return out
  end

  local CHIP, CHIP_GAP = 24, 4
  local ICON_PAD = 2
  local ICON = CHIP - ICON_PAD * 2
  local SPINE_X = 4 -- the panel's left bracket, under the row's own grip column
  -- The accent rail sits just right of where a category name begins, and the panel's content is indented
  -- past it (PANEL_PAD), so the open editor never reaches into the left column of names.
  local RAIL_X = 20
  local PANEL_PAD = 40

  -- The pin rack: the pinned item's icon and the faint empty slots under it, in their own factory.
  local makeChip, makeGhost = factories.catlistchips({
    Cats = Cats,
    act = act,
    chip = CHIP,
    iconPad = ICON_PAD,
    icon = ICON,
  })

  local GHOSTS = 4

  -- The rule band's pieces — the chips for the words, the id field, and the placement controls — are a
  -- factory of their own (Features/CatListRule.lua). Named here, so the panel below reads as it always did.
  local condItem, itemName, paintPlus, makePlusSlot, makePinEntry,
        makeCond, makeDropBtn, makeSortBtn, makePrioPick, makeShowBoxes, COND_H, ADD_COND_W,
        pinFromCursor =
    factories.catlistrule({
      Cats = Cats,
      act = act,
      relayout = relayout,
      openDropdown = openDropdown,
      baseFont = BASE_FONT,
      chip = CHIP,
      T = T,
      sortKeys = CAT_SORT_KEYS,
      sortLabels = SORT_LABELS,
    })

  -- The panel under a category row is a factory of its own (Features/CatListPanel.lua): it holds the rule
  -- band, the placement controls and the pin rack, and the layout that places them. Its two late friends —
  -- the word picker and the word sheet — are filled into the same table further down, once they exist.
  local panelEnv = {
    Cats = Cats,
    row = row,
    relayout = relayout,
    debounce = debounce,
    T = T,
    baseFont = BASE_FONT,
    chip = CHIP,
    chipGap = CHIP_GAP,
    rowH = CAT_ROW_H,
    panelPad = PANEL_PAD,
    railX = RAIL_X,
    condH = COND_H,
    addCondW = ADD_COND_W,
    makeBox = makeBox,
    makeChip = makeChip,
    makePlusSlot = makePlusSlot,
    makePinEntry = makePinEntry,
    makeCond = makeCond,
    makeDropBtn = makeDropBtn,
    makeSortBtn = makeSortBtn,
    makePrioPick = makePrioPick,
    makeShowBoxes = makeShowBoxes,
    condItem = condItem,
    itemName = itemName,
    pinFromCursor = pinFromCursor,
  }
  local buildPanel, layoutBuild = factories.catlistpanel(panelEnv)

  -- One watcher flips every open panel's pin band the moment the cursor picks up or sets down an item, so
  -- the drop target tracks the drag with no per-frame polling. Same idiom as the bag window's section
  -- zones, and safe before the list is built: it no-ops until a panel asks to be synced.
  local dropWatch = CreateFrame("Frame")
  dropWatch:RegisterEvent("CURSOR_CHANGED")
  dropWatch:SetScript("OnEvent", function()
    if not (row and row.build) then return end
    for _, p in pairs(row.build) do if p.SyncDrop then p:SyncDrop() end end
  end)

  -- Drag a row to reorder it, and to carry a category into another band, so a long list is not walked
  -- one arrow-click at a time. The grip is the handle: on grab the held row detaches and rides the
  -- cursor, the rest stay where the rebuild put them, and one accent line marks the slot the drop would
  -- land in. Pin panels are closed for the duration so every row keeps a steady height and the slot
  -- maths is a plain walk of the offsets the rebuild measured. The whole gesture only ever edits the
  -- saved list: nothing here touches a bag slot, a secure frame or the cursor, so it stays taint free.
  -- One row's height in the list, the fallback for any row the rebuild has not measured.
  local ROWH = CAT_ROW_H + 2
  local dragFrom, grabOff, dragLvl, dropTo, dragSF
  -- The cursor's position as a top-down offset from the top of the list, in the list's own coords.
  -- Every drag calculation works in this one space: the slot the drop lands in and where the floating
  -- row draws. Returns nil if the scale is not ready, so a caller can bail.
  local function cursorOff()
    local scale = row:GetEffectiveScale()
    if not scale or scale == 0 then return nil end
    local _, cy = GetCursorPosition()
    return (row:GetTop() or 0) - (cy / scale) - (row.listTop or 0)
  end
  -- The list index the held row would be inserted before, from the float's own middle rather than the
  -- bare cursor: the float is drawn at cursor - grabOff, so keying the slot off the cursor aimed up to
  -- half a row away from what the eye sees. Read off the geometry the rebuild laid down, which stays
  -- put for the whole drag, so the marker does not chase the rows as they are measured again.
  local function dropSlot()
    local off = cursorOff()
    if not off then return nil end
    local cy = off - (grabOff or 0) + ROWH / 2
    local list = Cats:List()
    for i = 1, #list do
      local mid = (row.off[i] or 0) + (row.h[i] or ROWH) / 2
      if cy < mid then return i end
    end
    return #list + 1
  end
  -- Live preview while a row is held: the held row rides the cursor and the rest stay exactly where the
  -- rebuild put them, with one accent line marking the slot the drop would land in. The line lives on
  -- its own thin frame lifted above the row pool, since the rows are child frames and a texture on the
  -- parent would draw under them and vanish on a row's own edge.
  local function dropMark()
    local m = row.dropMark
    if m then return m end
    local f = CreateFrame("Frame", nil, row)
    f:SetHeight(2)
    f:SetFrameLevel(row:GetFrameLevel() + 30)
    local line = Theme:Rect(f, "accent", "OVERLAY")
    line:SetAllPoints(f)
    m = f
    m:Hide()
    row.dropMark = m
    return m
  end
  -- Where the marker line sits for a slot: the top of the row now in it, or the bottom of the list.
  local function markY(slot)
    if not slot then return nil end
    if slot <= #Cats:List() then return row.off[slot] or 0 end
    return row.listH or 0
  end
  -- A held drag near an edge of the visible window scrolls the list. A row made at the tail has to be
  -- walked up the list to reach the band it should head, and without this a list taller than the window
  -- simply cannot be crossed: the cursor leaves the frame and the gesture has nowhere to go. Both edges
  -- use the same margin and the same gentle step, and the row's own offsets are read off the frames, so
  -- the float and the drop line follow the scrolled picture with nothing kept in step by hand.
  local function dragScroll()
    local sf = dragSF
    if not sf or not sf.ScrollTo then return end
    local scale = row:GetEffectiveScale()
    if not scale or scale == 0 then return end
    local view = sf:GetHeight() or 0
    if view <= 0 then return end
    local cy = select(2, GetCursorPosition()) / scale
    local top, bottom = sf:GetTop(), sf:GetBottom()
    if not (top and bottom) then return end
    local EDGE = 26
    local over = 0
    if cy > top - EDGE then over = math.min(EDGE, cy - (top - EDGE))
    elseif cy < bottom + EDGE then over = -math.min(EDGE, (bottom + EDGE) - cy) end
    if over == 0 then return end
    sf:ScrollTo((sf:GetVerticalScroll() or 0) - over * 0.35)
  end
  local function onDragUpdate()
    dragScroll()
    dropTo = dropSlot()
    -- The held row's own place takes no line: a drop there moves nothing, and both of its edges are that
    -- one non-move, so the marker would read as two targets on a row already where it would land.
    if dragFrom and (dropTo == dragFrom or dropTo == dragFrom + 1) then dropTo = nil end
    local m = dropMark()
    local my = markY(dropTo)
    if my then
      local y = -((my - 1) + (row.listTop or 0))
      m:ClearAllPoints()
      m:SetPoint("TOPLEFT", 0, y)
      m:SetPoint("TOPRIGHT", 0, y)
      m:Show()
    else
      m:Hide()
    end
    local fr = dragFrom and row.items[dragFrom]
    local off = cursorOff()
    if fr and off then
      local fy = off - (grabOff or 0)
      local maxY = math.max(0, (row.listH or 0) - ((dragFrom and row.h[dragFrom]) or ROWH))
      if fy < 0 then fy = 0 elseif fy > maxY then fy = maxY end
      fy = fy + (row.listTop or 0)
      fr:ClearAllPoints()
      fr:SetPoint("TOPLEFT", 0, -fy)
      fr:SetPoint("TOPRIGHT", 0, -fy)
    end
  end
  local function startDrag(idx)
    blur()
    cancelPending()
    -- Suppress the pin lines for the duration of the drag so every row is one uniform height and the
    -- slot maths stays a plain walk of the measured offsets. Restored on drop.
    row.dragging = true
    dragFrom = idx
    dragSF = row:GetParent() and row:GetParent():GetParent()
    Options:ReflowPages()
    -- Where inside the grabbed row the cursor took hold, so the row rides under that same point rather
    -- than snapping its top to the cursor. Falls back to the row's middle if the scale is not ready.
    local off = cursorOff()
    grabOff = off and (off - (row.off[idx] or 0)) or (ROWH / 2)
    -- Lift the floating row above its neighbours so it reads as picked up and is not drawn under the
    -- rows it passes; the level is put back on drop, since the rebuild does not touch it.
    local fr = row.items[idx]
    if fr then
      dragLvl = fr:GetFrameLevel()
      fr:SetFrameLevel(row:GetFrameLevel() + 20)
    end
    row:SetScript("OnUpdate", onDragUpdate)
  end
  local function stopDrag()
    row:SetScript("OnUpdate", nil)
    row.dragging = nil
    if row.dropMark then row.dropMark:Hide() end
    local from = dragFrom
    local fr = from and row.items[from]
    if fr and dragLvl then fr:SetFrameLevel(dragLvl) end
    dragFrom, dragLvl, dropTo, dragSF = nil, nil, nil, nil
    if not from then return end
    -- The slot under the float is the drop, and one list move is the whole of it: the row lands where
    -- the line showed, a category that passes another takes its priority, and a marker that passes
    -- anything only reshapes which run of categories is a band. Nothing needs re-sorting afterwards.
    local slot = dropSlot()
    -- Own place again: reflow to put the float back and leave the list alone, instead of taking the same
    -- act to write an order that did not change.
    if slot and slot ~= from and slot ~= from + 1 then
      act(function() Cats:Reorder(from, slot) end)
    else
      Options:ReflowPages()
    end
  end

  -- The axis names the readout prints, as keys so a language change reaches them with the rest of the
  -- window. "text" is the one that matters: it is what a token no dictionary answers to is filed under.
  local AXIS_LABEL = {
    kind = "Kind", slot = "Slot", quality = "Quality", level = "Item level",
    expansion = "Expansion", item = "Item", flag = "Property", text = "In the name",
    -- The picker groups tokens by what a person thinks, not how the parser stores them, so its axes are
    -- these named bands rather than the internal "kind"/"flag". Armor/Weapons/Consumables reuse the
    -- category names already translated everywhere; the rest are the picker's own.
    armor = "Armor type", weapon = "Weapons", consumable = "Consumables", collectible = "Collectible",
    crafting = "Crafting", class = "Item class", binding = "Binding", property = "Property",
    stat = "Attributes",
  }

  -- Word picker for the "+ condition" button: axes left, words right, click a word to add it as a chip.
  -- No operators — the panel's All/Any toggle and each chip's not-state carry the logic. Axis order tracks
  -- PICK_TOKENS; an axis with no word in this build is dropped when the column builds.
  local PICK_AXES = {
    "armor", "weapon", "consumable", "collectible", "crafting", "class",
    "slot", "stat", "quality", "level", "expansion", "binding", "property",
  }

  -- Shared popup, built once and re-anchored per open. Left column axes (fixed), right column the chosen
  -- axis's words, rebuilt each open so a language switch or new token shows without a reload; it scrolls
  -- past PMAX rows so the popup never grows unbounded.
  local catPicker
  -- AXW/WORDW are only fallbacks: each open measures the real rendered labels and words in the live font
  -- (so a bold or wide font, and any locale, fit) and sizes the two columns between these caps. WORDW's
  -- worst case is a full expansion name in the right column ("Wrath of the Lich King" and its translations),
  -- since the popup does not resize when the axis switches. PMAX caps visible rows.
  local AXW, WORDW, PROWH, PMAX = 168, 210, BASE_FONT + 10, 11
  -- WMIN also has to clear the Item level builder's fixed operator row (5 cells * (OPW+2) = 150 wide),
  -- so the number box and op cells never overrun the word column on the narrowest axis.
  local AXMIN, AXMAX, WMIN, WMAX = 120, 280, 150, 340
  local function ensureCatPicker()
    if catPicker then return catPicker end
    local m = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    m:Hide()
    Theme:Panel(m, "panel", "accent")
    m:SetFrameStrata("FULLSCREEN_DIALOG")
    m:SetToplevel(true)
    m:EnableMouse(true)
    m:SetClampedToScreen(true)

    -- Close on an outside click WITHOUT eating it: GLOBAL_MOUSE_DOWN fires for every press while the click
    -- still lands on its target. A press off the popup and off its anchor (so the anchor can toggle) hides.
    local watch = CreateFrame("Frame", nil, m)
    watch:Hide()
    watch:SetScript("OnEvent", function()
      if m:IsMouseOver() then return end
      local a = m.wpeAnchor
      if a and a:IsMouseOver() then return end
      m:Hide()
    end)
    m:SetScript("OnShow", function() watch:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
    m:SetScript("OnHide", function() watch:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)

    local divide = Theme:Rect(m, "strokeSoft", "ARTWORK")
    ns.PixelLine(divide, 1, "w")
    divide:SetPoint("TOPLEFT", AXW + 4, -4)
    divide:SetPoint("BOTTOMLEFT", AXW + 4, 4)
    m.divide = divide

    m.axisRows, m.wordRows = {}, {}
    -- Right column scrolls past PMAX rows; a faint thumb (lit on hover/drag) shows more, hidden when all fit.
    local WBAR = SCROLL_W
    local sf = CreateFrame("ScrollFrame", nil, m)
    sf:SetPoint("TOPLEFT", AXW + 10, -4)
    sf:SetPoint("BOTTOMRIGHT", -4 - WBAR - 2, 4)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(WORDW, PROWH)
    sf:SetScrollChild(child)

    local wbar = CreateFrame("Frame", nil, m)
    wbar:SetWidth(WBAR)
    wbar:SetPoint("TOPRIGHT", -3, -4)
    wbar:SetPoint("BOTTOMRIGHT", -3, 4)
    Theme:Rect(wbar, "panel", "BACKGROUND"):SetAllPoints(wbar)
    local wthumb = CreateFrame("Frame", nil, wbar)
    wthumb:SetWidth(WBAR)
    local wthumbTex = Theme:Rect(wthumb, "faint", "ARTWORK")
    wthumbTex:SetAllPoints(wthumb)
    m.wbar, m.wthumb = wbar, wthumb

    local function wspan() return math.max(0, child:GetHeight() - sf:GetHeight()) end
    local function paintWBar()
      local span, view = wspan(), sf:GetHeight()
      if span <= 0 or not m:IsShown() then wbar:Hide(); return end
      wbar:Show()
      local ch = child:GetHeight()
      local h = math.max(20, view * view / (ch > 0 and ch or view))
      wthumb:SetHeight(h)
      local frac = (sf:GetVerticalScroll() or 0) / span
      wthumb:ClearAllPoints()
      wthumb:SetPoint("TOP", wbar, "TOP", 0, -frac * (view - h))
    end
    m.PaintWBar = paintWBar
    local function wscroll(v)
      local span = wspan()
      sf:SetVerticalScroll(math.min(span, math.max(0, v)))
      paintWBar()
    end
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(s, d) wscroll((s:GetVerticalScroll() or 0) - d * PROWH * 2) end)
    ns.ScrollThumb(wthumb, wthumbTex, sf, wscroll, wspan)
    m.sf, m.wordChild = sf, child
    m.idPool = {}
    -- Off-screen scratch string in the row font, so each open can measure real rendered label/word widths
    -- (bold or wide fonts, any locale) and size the two columns to fit rather than trusting a fixed number.
    local measure = m:CreateFontString(nil, "ARTWORK")
    measure:SetFont(dropdownFont(), BASE_FONT - 1, ns.OutlineFlags())
    measure:Hide()
    m.measure = measure

    -- The Item level axis has no vocabulary: a threshold is a number, not one of a fixed list. So its
    -- right column is this small builder instead of the word scroll — an operator picked from a row of
    -- cells and a number typed in — and committing hands the same kind of token a word row does
    -- (ilvl>=180, ilvl<200, ilvl400). Raised above the panel's own backdrop, which draws over a plain child
    -- frame otherwise, so the cells stayed invisible until this level was set.
    local lp = CreateFrame("Frame", nil, m)
    lp:SetPoint("TOPLEFT", AXW + 10, -8)
    lp:SetSize(WORDW + SCROLL_W, PROWH * 3)
    lp:SetFrameLevel(m:GetFrameLevel() + 5)
    lp:Hide()
    local LP_OPS = { ">=", ">", "=", "<", "<=" }
    lp.op = ">="
    local opCells = {}
    local OPW = 28
    for i, op in ipairs(LP_OPS) do
      local b = CreateFrame("Button", nil, lp, "BackdropTemplate")
      ns.PixelBackdrop(b)
      ns.SnapSize(b, OPW, 22)
      ns.SnapPoint(b, "TOPLEFT", lp, "TOPLEFT", (i - 1) * (OPW + 2), 0)
      local fs = Theme:Label(b, BASE_FONT - 1, "dim")
      fs:SetPoint("CENTER")
      fs:SetText(op)
      b.Text, b.wpeOp = fs, op
      local function paint(s)
        local on = s.wpeOp == lp.op
        ns.SetBg(s, Theme:C(on and "panelHi" or "bg"))
        local er, eg, eb = Theme:C(on and "accent" or (s.wpeHot and "accent" or "strokeSoft"))
        ns.SetEdge(s, er, eg, eb, 1)
        s.Text:SetTextColor(Theme:C((on or s.wpeHot) and "text" or "dim"))
      end
      b.Repaint = paint
      paint(b)
      Theme:Track(b, paint)
      b:RegisterForClicks("LeftButtonUp")
      b:SetScript("OnEnter", function(s) s.wpeHot = true; paint(s) end)
      b:SetScript("OnLeave", function(s) s.wpeHot = nil; paint(s) end)
      b:SetScript("OnClick", function(s)
        lp.op = s.wpeOp
        for _, c in ipairs(opCells) do c:Repaint() end
      end)
      opCells[i] = b
    end
    -- The number box, digits only, with a "+" commit plate to its right. Enter commits too. It spans the
    -- pane width (WORDW + SCROLL_W) less the plate, not the narrower operator-cell row, so a long localized
    -- placeholder ("Gegenstandsstufe", "Уровень предмета") reads in full instead of clipping.
    local numBox = CreateFrame("EditBox", nil, lp, "BackdropTemplate")
    ns.PixelBackdrop(numBox)
    ns.SetBg(numBox, Theme:C("bg"))
    ns.SetEdge(numBox, Theme:C("stroke"))
    ns.SnapSize(numBox, WORDW + SCROLL_W - 30, 22)
    ns.SnapPoint(numBox, "TOPLEFT", lp, "TOPLEFT", 0, -28)
    numBox:SetFont(dropdownFont(), BASE_FONT - 1, ns.OutlineFlags())
    numBox:SetTextColor(Theme:C("text"))
    numBox:SetTextInsets(6, 6, 0, 0)
    numBox:SetAutoFocus(false)
    numBox:SetNumeric(true)
    numBox:SetMaxLetters(4)
    local nph = Theme:Label(numBox, BASE_FONT - 2, "faint")
    nph:SetPoint("LEFT", 6, 0)
    nph:SetPoint("RIGHT", -6, 0)
    nph:SetJustifyH("LEFT")
    nph:SetWordWrap(false)
    ns.LocalText(nph, "Item level")
    numBox:SetScript("OnTextChanged", function(s) nph:SetShown(s:GetText() == "") end)
    Theme:Track(numBox, function(s)
      ns.SetBg(s, Theme:C("bg")); s:SetTextColor(Theme:C("text"))
      if not s:HasFocus() then ns.SetEdge(s, Theme:C("stroke")) end
    end)
    lp.box = numBox
    m.levelBox = numBox
    local function levelToken()
      local n = tonumber(numBox:GetText())
      if not n or n <= 0 then return nil end
      if lp.op == "=" then return "ilvl" .. n end
      return "ilvl" .. lp.op .. n
    end
    local addLvl = CreateFrame("Button", nil, lp, "BackdropTemplate")
    ns.SnapSize(addLvl, 26, 22)
    ns.PixelBackdrop(addLvl)
    ns.SnapPoint(addLvl, "LEFT", numBox, "RIGHT", 4, 0)
    addLvl:RegisterForClicks("LeftButtonUp")
    ns.MarkPlus(addLvl)
    ns.TintMarkX(addLvl, "faint")
    addLvl.Repaint = paintPlus
    paintPlus(addLvl)
    Theme:Track(addLvl, paintPlus)
    addLvl:SetScript("OnEnter", function(s) s.wpeHot = true; paintPlus(s) end)
    addLvl:SetScript("OnLeave", function(s) s.wpeHot = nil; paintPlus(s) end)
    local function commitLevel()
      local tok = levelToken()
      if tok and m.wpeOnPick then m.wpeOnPick(tok) end
      numBox:SetText("")
      m:Hide()
    end
    addLvl:SetScript("OnClick", commitLevel)
    numBox:SetScript("OnEnterPressed", commitLevel)
    numBox:SetScript("OnEscapePressed", function(s) s:SetText(""); s:ClearFocus() end)
    m.levelPane = lp

    catPicker = m
    return m
  end

  -- One pooled row for either column: a button with a left-aligned label that lights on hover. The left
  -- column marks the chosen axis with the accent, the right column is plain words.
  local function pickerRow(pool, parent, i)
    local r = pool[i]
    if r then return r end
    r = CreateFrame("Button", nil, parent)
    r:SetHeight(PROWH)
    local bg = Theme:Rect(r, "panelHi", "BACKGROUND")
    bg:SetAllPoints(r)
    bg:Hide()
    r.bg = bg
    local fs = track(Theme:Label(r, BASE_FONT - 1, "text"), -1)
    fs:SetFont(dropdownFont(), BASE_FONT - 1, ns.OutlineFlags())
    fs:SetPoint("LEFT", 8, 0)
    fs:SetPoint("RIGHT", -6, 0)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    r.Text = fs
    r:SetScript("OnEnter", function(s) s.bg:Show() end)
    r:SetScript("OnLeave", function(s) if not s.wpeSel then s.bg:Hide() end end)
    pool[i] = r
    return r
  end

  -- Fill the right column with one axis's words and size the popup. A word click hands its token to
  -- m.wpeOnPick and closes the popup: one pick is one condition. Words carry the canonical English token
  -- but show the localized display, and keep PICK_TOKENS source order (slots read top-down by body). The
  -- Item level axis is the exception: it has no word list, so its column is the threshold builder instead.
  local function showWords(m, axis)
    for _, r in ipairs(m.axisRows) do
      local sel = r.wpeAxis == axis
      r.wpeSel = sel or nil
      -- The chosen axis is shown by its plate (r.bg), not by accent ink: the label keeps the text colour.
      r.Text:SetTextColor(Theme:C("text"))
      r.bg:SetShown(sel)
    end
    m.axis = axis
    if axis == "level" then
      -- The builder stands in for the scroll: hide the word rows and the bar, show the operator+number pane.
      -- Re-assert its level above m here (not just at creation): open raises m, so a level chosen after the
      -- open would otherwise sit under m's own backdrop and read as an empty right column.
      for i = 1, #m.wordRows do if m.wordRows[i] then m.wordRows[i]:Hide() end end
      if m.wbar then m.wbar:Hide() end
      m.sf:Hide()
      m.levelPane:SetFrameLevel(m:GetFrameLevel() + 5)
      m.levelPane:Show()
      m.levelBuild = true
      m.wordCount = 0
      return
    end
    m.levelPane:Hide()
    m.sf:Show()
    m.levelBuild = nil
    local entries = {}
    for _, e in ipairs(ns.SearchTokenList and ns.SearchTokenList() or {}) do
      if e.axis == axis then entries[#entries + 1] = { ins = e.token, text = e.display } end
    end
    local y = 0
    for i, e in ipairs(entries) do
      local r = pickerRow(m.wordRows, m.wordChild, i)
      r.wpeSel = nil
      r.bg:Hide()
      r.Text:SetText(e.text)
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", 0, -y)
      r:SetWidth(m.wordW or WORDW)
      r:SetScript("OnClick", function()
        if m.wpeOnPick then m.wpeOnPick(e.ins) end
        m:Hide()
      end)
      r:Show()
      y = y + PROWH
    end
    for i = #entries + 1, #m.wordRows do m.wordRows[i]:Hide() end
    m.wordChild:SetHeight(math.max(PROWH, y))
    m.sf:SetVerticalScroll(0)
    if m.PaintWBar then m:PaintWBar() end
    m.wordCount = #entries
  end

  -- Open the word picker anchored to a chip/button, calling onPick(token) when a word is chosen. Left
  -- column is the axes that have any word in this build; the right column swaps to the clicked axis.
  function openCatPicker(anchor, onPick)
    local m = ensureCatPicker()
    if m:IsShown() and m.wpeAnchor == anchor then m:Hide(); return end
    m.wpeAnchor = anchor
    m.wpeOnPick = onPick
    -- Left column: each axis that has any word. Built fresh so a language change reaches the axis labels.
    local axes = {}
    local present = {}
    for _, e in ipairs(ns.SearchTokenList and ns.SearchTokenList() or {}) do present[e.axis] = true end
    -- Item level carries no vocabulary word, so it is not in the token list; add it by hand, since its
    -- column is the threshold builder, not a word scroll.
    present.level = true
    for _, ax in ipairs(PICK_AXES) do
      if present[ax] then axes[#axes + 1] = { key = ax, label = AXIS_LABEL[ax] or ax } end
    end

    -- Measure the real rendered text in the live font (bold/wide faces and every locale included) and fit
    -- the two columns to it, between the min/max caps. The right column's worst case is the widest word of
    -- ANY axis plus the Item level placeholder, since the popup keeps one width across axis switches.
    local mm = m.measure
    mm:SetFont(dropdownFont(), BASE_FONT - 1, ns.OutlineFlags())
    local axWide = 0
    for _, a in ipairs(axes) do
      mm:SetText(T(a.label))
      axWide = math.max(axWide, mm:GetStringWidth() or 0)
    end
    local wWide = 0
    for _, e in ipairs(ns.SearchTokenList and ns.SearchTokenList() or {}) do
      mm:SetText(e.display or "")
      wWide = math.max(wWide, mm:GetStringWidth() or 0)
    end
    mm:SetText(T("Item level"))
    local phWide = mm:GetStringWidth() or 0
    -- Row text sits inside 8+6 insets and the axis row is axisW-4; the word/number box carries 6+6 insets
    -- and the number box is (wordW+SCROLL_W-30) wide, so the placeholder needs wordW >= phWide + 34.
    local axisW = math.max(AXMIN, math.min(AXMAX, math.ceil(axWide) + 18))
    local wordW = math.max(WMIN, math.min(WMAX,
      math.max(math.ceil(wWide) + 14, math.ceil(phWide) + 34)))
    m.wordW = wordW

    -- Re-anchor the pieces whose left edge tracks the axis column, and resize the level builder to the word
    -- column, so both grow with the measured widths instead of the fixed AXW/WORDW.
    m.divide:ClearAllPoints()
    m.divide:SetPoint("TOPLEFT", axisW + 4, -4)
    m.divide:SetPoint("BOTTOMLEFT", axisW + 4, 4)
    m.sf:ClearAllPoints()
    m.sf:SetPoint("TOPLEFT", axisW + 10, -4)
    m.sf:SetPoint("BOTTOMRIGHT", -4 - SCROLL_W - 2, 4)
    m.levelPane:ClearAllPoints()
    m.levelPane:SetPoint("TOPLEFT", axisW + 10, -8)
    m.levelPane:SetSize(wordW + SCROLL_W, PROWH * 3)
    if m.levelBox then ns.SnapSize(m.levelBox, wordW + SCROLL_W - 30, 22) end
    m.wordChild:SetWidth(wordW)

    local y = 0
    for i, a in ipairs(axes) do
      local r = pickerRow(m.axisRows, m, i)
      r.wpeAxis = a.key
      r.Text:SetText(T(a.label))
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", 4, -(4 + y))
      r:SetWidth(axisW - 4)
      r:SetScript("OnClick", function() showWords(m, a.key) end)
      r:Show()
      y = y + PROWH
    end
    for i = #axes + 1, #m.axisRows do m.axisRows[i]:Hide() end
    local axisH = y
    -- No id row here: an id is added by pinning the item (the pin rack's "+"), not as a search condition,
    -- so the picker offers only the vocabulary words. The id-as-chip still renders when a hand-written rule
    -- carries one; it is just not built from this menu.
    if m.footLine then m.footLine:Hide() end
    if m.idPool and m.idPool[1] then m.idPool[1]:Hide() end
    -- Open on the first axis so the common case — pick a type — is one click in.
    showWords(m, axes[1] and axes[1].key or "armor")
    -- The level builder is two rows tall (operator cells over the number box), so its column needs that
    -- much even though it lists no words; every other axis sizes off its word count.
    local rightH = m.levelBuild and (PROWH * 4) or (math.min(m.wordCount, PMAX) * PROWH)
    local h = math.max(axisH, rightH) + 8
    -- Width holds both columns plus the word column's scrollbar track (SCROLL_W + a little air), so a
    -- scrolling axis does not draw its bar over the last letters of its words.
    ns.SnapSize(m, axisW + 10 + wordW + 2 + SCROLL_W + 4, h)

    m:ClearAllPoints()
    -- Opens to the right of the button and downward, like a context menu: TOPLEFT of the popup at the
    -- button's TOPRIGHT. If that would run off the bottom of the screen it flips to grow upward, and
    -- SetClampedToScreen keeps the right edge on screen, so the anchor's own right-side position never
    -- pushes it out of view.
    local top = anchor:GetTop() or 0
    if top - h < 20 then
      m:SetPoint("BOTTOMLEFT", anchor, "TOPRIGHT", 4, 0)
    else
      m:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 0)
    end
    m:Show()
    m:Raise()
  end

  -- The words the search takes, as a list to read rather than a menu to pick from: the band's "+" picks a
  -- word for a chip, this one answers which words exist at all. The sheet is a factory of its own
  -- (Features/CatListHelp.lua), built once and filled from the live locale on every open.
  showCatHelp = factories.catlisthelp({
    baseFont = BASE_FONT,
    scrollW = SCROLL_W,
    dropdownFont = dropdownFont,
    T = T,
    axes = PICK_AXES,
    axisLabel = AXIS_LABEL,
  })

  -- The panel's two late friends, both built after it: the word picker and the word sheet.
  panelEnv.openCatPicker, panelEnv.showCatHelp = openCatPicker, showCatHelp

  local catRow = factories.catlistrow(row, {
    Cats = Cats,
    rowH = CAT_ROW_H,
    baseFont = BASE_FONT,
    act = act,
    makeBox = makeBox,
    makeGrip = makeGrip,
    commitName = commitName,
    cancelPending = cancelPending,
    debounce = debounce,
    startDrag = startDrag,
    stopDrag = stopDrag,
    relayout = relayout,
    track = track,
  })

  -- Put a just-made row in front of the player: scroll it into view and pulse an accent wash over it
  -- for a beat. Every mutator returns the index of the row it made, every created row lands at the tail
  -- of the list, and this is what closes the loop — otherwise the player is left hunting for what just
  -- happened while the list under the cursor moves. The row's own offset comes from the measurement the
  -- rebuild just took; where that sits inside the scroll child is read off the two frames, so the scroll
  -- target is right even though the list body starts below the preset strip.
  reveal = function(i)
    local y = row.off and row.off[i]
    if not y then return end
    local h = row.h[i] or CAT_ROW_H
    local inRow = (row.listTop or 0) + y
    local page = row:GetParent()
    local sf = page and page:GetParent()
    if sf and sf.ScrollTo then
      local off = ((page:GetTop() or 0) - (row:GetTop() or 0)) + inRow
      local view = sf:GetHeight() or 0
      local cur = sf:GetVerticalScroll() or 0
      if off - 8 < cur then
        sf:ScrollTo(math.max(0, off - 8))
      elseif off + h + 8 > cur + view then
        sf:ScrollTo(off + h + 8 - view)
      end
    end
    local f = row.flash
    if not f then
      f = CreateFrame("Frame", nil, row)
      f:SetFrameLevel(row:GetFrameLevel() + 40)
      -- The wash's low alpha is baked into the colour and re-applied through the theme hook, not set
      -- once with SetAlpha: SetAlpha is not re-run on a theme change, but the accent recolour hook is,
      -- and a colorKey Rect's hook re-runs SetVertexColor to full alpha, flaring the wash to a bright
      -- band the moment the theme changed (the same trap the Empty tile plate had). So the texture takes
      -- no colorKey — SetColorTexture writes the accent at 0.22 in one call, and one tracked painter
      -- keeps it faint across every theme change.
      local wash = f:CreateTexture(nil, "OVERLAY")
      wash:SetAllPoints(f)
      local function paintWash(x) local r, g, b = Theme:C("accent"); x:SetColorTexture(r, g, b, 0.22) end
      paintWash(wash)
      Theme:Track(wash, paintWash)
      f.wash = wash
      f:Hide()
      row.flash = f
    end
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", 0, -inRow)
    f:SetPoint("TOPRIGHT", 0, -inRow)
    f:SetHeight(h)
    f:Show()
    -- One timer per pulse and a counter to arbitrate: a quick second create bumps the sequence, and the
    -- older timer then leaves the newer row's wash alone instead of clearing it early.
    flashSeq = (flashSeq or 0) + 1
    local mine = flashSeq
    C_Timer.After(1.1, function()
      if mine == flashSeq and row.flash then row.flash:Hide() end
    end)
  end

  local header = factories.catlistheader(row, {
    Cats = Cats,
    baseFont = BASE_FONT,
    contentW = CONTENT_W,
    sortKeys = GLOBAL_SORT_KEYS,
    sortLabels = SORT_LABELS,
    act = act,
    tip = tip,
    openDropdown = openDropdown,
    relayout = relayout,
  })

  row.gadd = ns.CreateButton(row, ns.L["New group"], 120, 22)
  ns.LocalText(row.gadd, "New group")
  row.gadd:SetScript("OnClick", function() act(function() return Cats:AddGroup() end) end)
  tip(row.gadd, "Adds an empty group at the bottom, then drag it up to head the rows it should name")

  row.dadd = ns.CreateButton(row, ns.L["New divider"], 120, 22)
  ns.LocalText(row.dadd, "New divider")
  row.dadd:SetScript("OnClick", function() act(function() return Cats:AddDivider() end) end)
  tip(row.dadd, "Adds a divider at the bottom, then drag it up to seam the rows where you want")

  local add = ns.CreateButton(row, ns.L["New category"], 120, 22)
  ns.LocalText(add, "New category")
  add:SetScript("OnClick", function() act(function() return Cats:Add() end) end)
  tip(add, "Adds a category at the bottom of the list, ready to drag into place")
  row.add = add
  -- Resetting throws away every rule the player built, so it asks first, the way dropping a saved
  -- character does, and it sits apart from the buttons that make things rather than between them.
  local reset = ns.CreateButton(row, ns.L["Reset categories"], 120, 22)
  ns.LocalText(reset, "Reset categories")
  reset:SetScript("OnClick", function()
    StaticPopupDialogs["WARPEE_RESET_CATEGORIES"].text = T("Reset the category list to the shipped one?")
    StaticPopup_Show("WARPEE_RESET_CATEGORIES")
  end)
  tip(reset, "Asks first, then puts every shipped category back")
  row.reset = reset

  -- The four actions carry their locale key so the rebuild can read the current language and measure the
  -- string that will actually land on the button. The label is repainted on a language change as well, but
  -- the page is reflowed before that paint lands, so measuring whatever is on screen would size the row for
  -- the language being left. `maker` marks the three that create a row: those pack from the left.
  local actions = {
    { btn = add,      key = "New category",     maker = true },
    { btn = row.gadd, key = "New group",        maker = true },
    { btn = row.dadd, key = "New divider",      maker = true },
    { btn = reset,    key = "Reset categories" },
  }

  -- The share line — the Export and Import buttons and the field that carries the code — is a factory of
  -- its own (Features/CatListShare.lua). It also lays itself out, because the line is the last thing on
  -- the page and its height is what the page ends at.
  local share = factories.catlistshare({ makeBox = makeBox, tip = tip, say = say })(row)

  row.Rebuild = function()
    row.builtAt = GetTime()
    local list = Cats:List()
    -- `other` is the unmatched total the Other catch-all shows; the per-row counts live in each open panel.
    local _, other = Cats:Counts()
    local names = Cats:Names()
    -- The gutter holds the pin caret and the count; the search field gets the rest.
    local half = math.floor((CONTENT_W - 96) / 2)
    for _, p in pairs(row.build) do p:Hide() end
    local y = 0

    y = header.layout(y)

    -- One pass over the flat list, in order, and the markers lay out as rows of their own: a group
    -- header with its name field, a divider as a line with a caption. This is the
    -- whole editor — the list is the structure, so there is no second block of groups above it and
    -- nothing to keep in step with it.
    row.listTop = y
    row.off, row.h = {}, {}
    local y0 = y
    for i, e in ipairs(list) do
      local r = catRow(i)
      r.idx = i
      -- Each row is measured as it is laid out, so the slot under the cursor follows the real picture: a
      -- divider is shorter than a category row, and a row with its pin panel open is taller than both.
      row.off[i] = y - y0
      if Cats.IsMarker(e) then
        local head = Cats.IsHead(e)
        local hh = head and CAT_ROW_H or (CAT_ROW_H - 6)
        r.entry, r.catId = e, nil
        r:SetHeight(hh)
        -- Only the grip and the X of the category row are reused: a marker owns no rule, so the
        -- checkbox (and the button that carries its click), the pin toggle and the count have nothing to
        -- say on it.
        r.chk:Hide()
        r.chkHit:Hide()
        r.grip:Show()
        r.del:Show()
        -- A category row re-anchors delete to sit just after its name; a marker wants it back at the far
        -- right, where its head line and caption run up to it.
        r.del:ClearAllPoints()
        ns.SnapPoint(r.del, "TOPRIGHT", r, "TOPRIGHT", -1, -4)
        r.addPin:Hide()
        r.count:Hide()
        local part = headPart(r)
        if head then
          -- A group header is its name field: the placeholder is the resolved name, so an unnamed group
          -- still reads as the shipped one it is. The field is then sized from that placeholder, so a
          -- shipped name longer than the English one is not cut off ("Профессии", "Berufliches"): a marker
          -- row has no search field, and with the band arrows gone its X is the only thing to its right,
          -- so the room a category row spends there is free here.
          r.nameBox:Show()
          r.nameBox.ph:SetText(Cats:GroupName(e))
          -- The cap is the field's own left edge (the grip's right plus 8) plus the X and a gap, so a long
          -- name stops beside the X instead of running under it.
          r.nameBox:SetWidth(math.max(160, math.min(CONTENT_W - 66,
            math.ceil(r.nameBox.ph:GetStringWidth() or 0) + 24)))
          if not r.nameBox:HasFocus() then
            r.nameBox:SetText(e.name or "")
            r.nameBox.ph:SetShown((e.name or "") == "")
          end
          part.divCap:Hide()
          part.headLine:ClearAllPoints()
          part.headLine:SetPoint("BOTTOMLEFT", 0, 4)
          part.headLine:SetPoint("BOTTOMRIGHT", 0, 4)
        else
          -- A divider carries no name: its caption sits on the line instead, so the row still reads as
          -- what it is, and the line runs from the grip to the X behind the words.
          r.nameBox:Hide()
          part.divCap:ClearAllPoints()
          ns.SnapPoint(part.divCap, "LEFT", r.grip, "RIGHT", 8, 0)
          part.divCap:Show()
          part.headLine:ClearAllPoints()
          part.headLine:SetPoint("LEFT", r.grip, "RIGHT", 8, 0)
          part.headLine:SetPoint("RIGHT", r.del, "LEFT", -6, 0)
        end
        part.headLine:Show()
        headPaint(r, false)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, -y)
        r:SetPoint("TOPRIGHT", 0, -y)
        r:Show()
        row.h[i] = hh
        y = y + hh + 2
      else
        r.entry = nil
        if r.headLine then
          -- This row was a marker in an earlier build and is a category now (a drag swapped the two), so
          -- its marker widgets go away and its name field edge drops back to the resting colour.
          headPaint(r, false)
          r.headLine:Hide()
        end
        if r.divCap then r.divCap:Hide() end
        local on = e.enabled ~= false
        -- Empty and Other are real, reorderable rows, but neither owns a rule: no pin caret, no delete.
        -- Empty shows no count (it owns no items) and keeps its enable checkbox; Other shows its count
        -- (the coverage the rules leave behind) and carries no checkbox at all, since the catch-all is
        -- never switched off.
        local isEmpty = e.empty == true
        local isOther = e.other == true
        r.catId = e.id
        -- The row is one clean line now: name, enable box, grip, the "+" that opens the rule/pin panel,
        -- and delete. The rule itself is edited as chips in that panel, so there is no inline field to
        -- read back and no readout line — the row never grows.
        r:SetHeight(CAT_ROW_H)
        if isOther then r.chk:Hide() else r.chk:Show(); r.chk.mark:SetShown(on) end
        r.chkHit:Show()
        r.grip:Show()
        -- The name field carries only a custom override; its placeholder is the resolved caption
        -- (a default's shipped label, a new row's fallback), so an unnamed row still reads as itself.
        r.nameBox:Show()
        r.nameBox.ph:SetText(names[i] or ns.L["Name"])
        if not r.nameBox:HasFocus() then
          r.nameBox:SetText(e.name or "")
          r.nameBox.ph:SetShown((e.name or "") == "")
        end
        local ids = pinIds(e)
        -- Empty and Other own no pins and no rule, so neither shows the "+"; every real row does, lit
        -- while its panel is open. openPins is a tri-state per id: nil is the default (open when the row
        -- holds pins, closed when it does not), true forces open so the rule/id can be edited, and false
        -- collapses a row the player chose to close.
        local canPin = (not isEmpty) and (not isOther)
        local forced = row.openPins[e.id]
        -- Default closed even with pins: the collapsed row shows a pin dot, so the rack does not need
        -- the panel forced open to be known. Only an explicit open (the "+") shows the editor.
        local wantOpen = (forced == true)
        local panelOpen = canPin and wantOpen and not row.dragging
        r.wpePanelOpen = panelOpen
        if isEmpty or isOther then
          -- The "+" and delete these rows do not own are hidden, not merely dimmed, so nothing reads as
          -- editable. Neither is deletable, so both always stay in the list. Other keeps its count on the
          -- right (the unmatched total); Empty owns no items, so it shows none. The name takes the whole
          -- row, since there is nothing to its right to make room for.
          r.nameBox:SetWidth(half * 2 - 18)
          r.del:Hide()
          r.addPin:Hide()
          if isOther then
            -- Count anchored to the row's own right edge, not off addPin (which is hidden here and, on a
            -- pooled row last used as a category, sits re-anchored next to the name).
            r.count:ClearAllPoints()
            ns.SnapPoint(r.count, "TOPRIGHT", r, "TOPRIGHT", -6, -6)
            r.count:SetText(tostring(other or 0))
            r.count:SetAlpha(1)
            r.count:Show()
          else
            r.count:Hide()
          end
        else
          -- Collapsed row: the name owns the left edge; the "+" (and delete, while the panel is open) sit
          -- in one aligned column at the right, off a fixed name width so they read as a tidy column, not a
          -- ragged one chasing each name.
          r.nameBox:SetWidth(NAME_W)
          r.addPin:Show()
          r.addPin:ClearAllPoints()
          ns.SnapPoint(r.addPin, "TOPRIGHT", r, "TOPRIGHT", -1, -4)
          -- The sticky open flag, read by the wrapped Repaint so the + stays accent while its panel is open.
          r.addPin.wpeOpen = panelOpen or nil
          r.addPin:Repaint()
          -- Delete rides beside the "+" only while the panel is open: it is rare and destructive, so a
          -- collapsed list of twenty rows carries none, but the row being edited shows its "×" so the
          -- category can be removed without a second trip.
          if panelOpen then
            r.del:Show()
            r.del:ClearAllPoints()
            ns.SnapPoint(r.del, "RIGHT", r.addPin, "LEFT", -6, 0)
          else
            r.del:Hide()
          end
          -- No catch count on the row: the open panel says how many a rule catches, and repeating it on
          -- every collapsed row was the same number twice.
          r.count:Hide()
        end
        -- The name field dims with the row's on state whether or not the rest of the row is present.
        r.nameBox:SetAlpha(on and 1 or 0.4)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, -y)
        r:SetPoint("TOPRIGHT", 0, -y)
        r:Show()
        local extra = 0
        local panelH = 0
        -- The pin panel shows under a category when it holds pins, or when the row's "+" forced it open
        -- (openPins) so an id can be typed into a pinless one. A pinless, unopened row (the norm) stays
        -- one clean line. Suppressed for the whole drag so every row keeps a steady height mid-gesture.
        if panelOpen then
          local p = buildPanel(i)
          p.wpeId = e.id
          local h = layoutBuild(p, ids, CONTENT_W, e)
          p:ClearAllPoints()
          p:SetPoint("TOPLEFT", 0, -(y + CAT_ROW_H + extra + 2))
          p:SetPoint("TOPRIGHT", 0, -(y + CAT_ROW_H + extra + 2))
          p:SetHeight(h)
          p:Show()
          panelH = h + 2
        end
        row.h[i] = CAT_ROW_H + extra + 2 + panelH
        y = y + CAT_ROW_H + extra + 2 + panelH
      end
    end
    row.listH = y - y0
    for i = #list + 1, #row.items do row.items[i]:Hide() end
    -- The actions sit in one row right under the list: the three that make a row pack from the left, in
    -- the order you are likely to reach for them, and the one that discards the whole list holds the far
    -- right, away from the others. A row made by any of them appears directly above this strip, so the
    -- click and its result are never more than a row apart.
    -- Each is sized from its own label rather than from a fixed box: the English words fit 120, and every
    -- longer translation ran out of it, Russian "Новый разделитель" first. When the makers and the reset
    -- do not fit side by side, the reset drops to a line of its own, still on the right, rather than
    -- overlapping them or being clipped.
    y = y + 12
    local GAPW, SIDEPAD = 8, 22
    local x, span, resetW = 0, 0, 0
    local packed = {}
    for _, e in ipairs(actions) do
      e.btn.Text:SetText(T(e.key))
      local w = math.ceil(e.btn.Text:GetStringWidth()) + SIDEPAD
      if e.maker then
        packed[#packed + 1] = { btn = e.btn, w = w, x = x }
        x = x + w + GAPW
        span = x - GAPW
      else
        resetW = w
      end
    end
    local stacked = (span + GAPW + resetW) > CONTENT_W
    for _, p in ipairs(packed) do
      p.btn:ClearAllPoints()
      p.btn:SetPoint("TOPLEFT", p.x, -y)
      ns.SnapBox(p.btn, p.w, 22)
      p.btn:Show()
    end
    reset:ClearAllPoints()
    reset:SetPoint("TOPRIGHT", 0, stacked and -(y + 26) or -y)
    ns.SnapBox(reset, resetW, 22)
    -- The share line closes the page: it comes after the actions because the list above is the thing
    -- being shared and this is how it leaves and comes back. Its own layout takes the row the actions
    -- took when they wrapped, and hands back the height the page ends at.
    row:SetHeight(share.Layout(y, stacked and 26 or 0, SIDEPAD, GAPW))
  end
  -- Refresh arrives every frame of a drag; the full rebuild is capped.
  row.Refresh = function()
    local now = GetTime()
    if row.builtAt and (now - row.builtAt) < 0.5 then return end
    row.Rebuild()
  end
  row.Rebuild()
  -- The editor's reset hook, called by the confirm dialog's accept: the same wrapper every other action
  -- uses, so a confirmed reset blurs the fields, rebuilds the list and lands the view on its first row.
  Options.catReset = function()
    act(function()
      Cats:Reset()
      return 1
    end)
  end

  -- The editor's refresh hook for a list that was replaced from outside it: an imported code, or one
  -- handed over by another addon's installer. Nothing is mutated here — that has already happened — so
  -- this is the rebuild-and-reveal half of the reset path, and the view lands on the first row because
  -- the whole list just changed under the reader.
  Options.catChanged = function()
    act(function() return 1 end)
  end

  -- One door for a code that arrived in the field, whoever asked for it: the kind is read off the code
  -- itself, so a profile code pasted here is applied the way the profile panel applies one, and the
  -- result is said in chat because the field cannot. The list is rebuilt by the reader in Profiles.lua,
  -- which is the one that knows whether anything was written at all.
  Options.catImport = function(text, mode)
    if ns.Profiles:CodeKind(text) == "profile" then
      local ok, res = ns.Profiles:Import(text)
      if not ok then say(T(res)) return end
      say(T("Imported %s"):format(res))
      return
    end
    local ok, res = ns.Profiles:ImportCategories(text, mode)
    if not ok then say(T(res)) return end
    say(T("Imported sections: %d"):format(res))
  end
  return row
end

-- The page tables live in OptionsPages.lua and borrow the helpers above.
Options.helpers = {
  ANCHORS = ANCHORS,
  ANCHOR_LABELS = ANCHOR_LABELS,
  ANGLE_KEYS = ANGLE_KEYS,
  Bags = Bags,
  L = L,
  STYLES = STYLES,
  STYLE_LABELS = STYLE_LABELS,
  T = T,
  THEME_KEYS = THEME_KEYS,
  Theme = Theme,
  angleGet = angleGet,
  angleSet = angleSet,
  autoField = autoField,
  bg = bg,
  colsGet = colsGet,
  colsSet = colsSet,
  dbField = dbField,
  edgeGet = edgeGet,
  edgeSet = edgeSet,
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
  onOf = onOf,
  pinHint = pinHint,
  relayout = relayout,
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
  zoomGet = zoomGet,
  zoomSet = zoomSet,
}

local function paintTab(b)
  if b.sel then
    local def = Theme.SkinDef and Theme:SkinDef()
    ns.SetBg(b, Theme:C((def and def.quietTabs) and "panel" or "panelHi"))
    ns.SetEdge(b, Theme:C("accent"))
    b.Text:SetTextColor(Theme:C("text"))
  else
    ns.SetBg(b, Theme:C("panel"))
    ns.SetEdge(b, Theme:C("stroke"))
    b.Text:SetTextColor(Theme:C("dim"))
  end
end

-- The strip's paint, held per button, since its own repaint drops the accent.
local function paintSub(b)
  ns.SetBg(b, Theme:C(b.sel and "panelHi" or "panel"))
  ns.SetEdge(b, Theme:C(b.sel and "accent" or "stroke"))
  b.Text:SetTextColor(Theme:C(b.sel and "text" or "dim"))
end

local function paintSubs(entry)
  for _, b in ipairs(entry.btns) do paintSub(b) end
end

-- Measure and chain one page's strip buttons, from reflow and build alike.
local function layoutStrip(entry, defs)
  local prev
  for k, b in ipairs(entry.btns) do
    if defs and defs[k] then b.Text:SetText(T(defs[k].name)) end
    b:SetWidth(math.max(56, b.Text:GetStringWidth() + 18))
    b:ClearAllPoints()
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0)
    else b:SetPoint("LEFT", entry.strip, "LEFT", 0, 0) end
    prev = b
  end
  paintSubs(entry)
end

function Options:Select(index)
  closeDropdown()
  self.current = index
  -- The tab builds its lists on first visit, one page at a time.
  self:BuildPage(index)
  for i, tab in ipairs(self.tabs) do
    tab.sel = (i == index)
    paintTab(tab)
  end
  for i = 1, #Options.pages do
    local entry = self.subs[i]
    if entry then
      local at = self.subAt[i] or 1
      for k, area in ipairs(entry.areas) do
        local on = (i == index and k == at)
        area:SetShown(on)
        area.bar:SetShown(on)
      end
      if entry.strip then entry.strip:SetShown(i == index) end
      for k, b in ipairs(entry.btns) do b.sel = (i == index and k == at) end
      paintSubs(entry)
    end
  end
  local area = self.subs[index].areas[self.subAt[index] or 1]
  area:ScrollTo(0)
  area:PaintBar()
  self:Refresh()
end

-- The sub buttons switch lists; the pick is remembered per page.
function Options:SubSelect(k)
  self.subAt[self.current] = k
  self:Select(self.current)
end

function Options:ApplyFont()
  -- The same guard ReflowPages opens with, and for the same reason: ns.ApplyAll calls both
  -- of them, and an apply that runs before this window was ever built has no tabs or pages
  -- to measure. Build's own ApplyFont puts the fonts on once there are.
  if not (self.tabs and self.areas) then return end
  local path = ns.Fonts:Current()
  for _, e in ipairs(fonts) do
    e.fs:SetFont(path, math.max(7, BASE_FONT + e.delta), ns.OutlineFlags())
  end
  local function measure()
    for _, tab in ipairs(self.tabs) do
      tab:SetWidth(math.max(70, tab.Text:GetStringWidth() + 22))
    end
    if self.profilesBtn then
      self.profilesBtn:SetWidth(math.max(64, self.profilesBtn.Text:GetStringWidth() + 20))
    end
    if self.searchBox and self.searchPh then
      -- The box fits its placeholder, so a long translation stays inside it.
      local tw = math.ceil(self.searchPh:GetStringWidth() or 0)
      self.searchBox:SetWidth(math.max(180, math.min(340, tw + 42)))
    end
    for i, area in ipairs(self.areas) do
      area.page.Relayout()
      area:PaintBar()
    end
  end
  measure()
  C_Timer.After(0, measure)
end

function Options:ReflowPages()
  if not self.areas then return end
  if self.tabs then
    local prev
    for i, tab in ipairs(self.tabs) do
      tab.Text:SetText(T(Options.pages[i].name))
      tab:SetWidth(math.max(70, tab.Text:GetStringWidth() + 22))
      tab:ClearAllPoints()
      if prev then
        tab:SetPoint("TOPLEFT", prev, "TOPRIGHT", 5, 0)
      else
        ns.SnapPoint(tab, "TOPLEFT", self.frame, "TOPLEFT", PAD,
          -(HEADER_H + 7 + Theme:TopInset()))
      end
      prev = tab
      tab:Show()
      paintTab(tab)
    end
  end
  -- The strip's buttons measure like the tabs, chained left to right.
  for i = 1, #Options.pages do
    local entry = self.subs[i]
    if entry then layoutStrip(entry, Options.pages[i].subs) end
  end
  self:AnchorHeader()
  for _, row in ipairs(rows) do row.Refresh() end
  for _, area in ipairs(self.areas) do
    area.page.Relayout()
    area:ScrollTo(area:GetVerticalScroll())
    area:PaintBar()
  end
end

-- The rows on screen; Select fills it, so hidden lists wait their turn.
function Options:VisibleRows()
  local entry = self.subs and self.subs[self.current]
  if not entry then return rows end
  local area = entry.areas[self.subAt[self.current] or 1]
  local page = area and area.page
  if not (page and page.rows) then return rows end
  -- Hidden rows are left out: a folded section is not on screen.
  local out = {}
  for i = 1, #page.rows do
    local row = page.rows[i].row
    if row:IsShown() then out[#out + 1] = row end
  end
  return out
end

function Options:Refresh()
  local live = self:VisibleRows()
  for i = 1, #live do live[i].Refresh() end
  self:SyncProfilesSoon()
end

-- The capture trails the row passes; closing the window writes it at once.
function Options:SyncProfilesSoon()
  if self.syncQ then return end
  self.syncQ = true
  C_Timer.After(0.3, function()
    self.syncQ = nil
    if ns.Profiles and ns.Profiles.SyncActive then ns.Profiles:SyncActive() end
  end)
end

-- One row pass per frame at most, however many settings moved in it. The flag lives on the
-- table rather than in a local: Options.lua is the file closest to the main-chunk limit, and
-- the deferral costs a C_Timer, not a slot.
function Options:RefreshSoon()
  if self.refreshQ then return end
  self.refreshQ = true
  C_Timer.After(0, function()
    self.refreshQ = nil
    self:Refresh()
  end)
end

-- Re-render the open editor after a change made from outside it — a pin dropped on a section in the
-- bag window files into a category, and the category editor, if it happens to be open, must redraw so
-- the new pin's row and icon appear at once rather than only after the tab is left and re-entered.
-- A no-op when the window is closed, so the bag drop can call it unconditionally.
function Options:RefreshOpen()
  if not (self.frame and self.frame:IsShown()) then return end
  self:Refresh()
  -- Only the list on screen is measured; the pages behind wait their turn.
  local entry = self.subs and self.subs[self.current]
  local area = entry and entry.areas[self.subAt[self.current] or 1]
  if area and area.page and area.page.Relayout then
    area.page.Relayout()
    area:PaintBar()
  end
end

-- Crude inflection stripper: Russian cases and plurals, Latin plurals, German -en.
local RU_TAIL2 = { "ая","яя","ое","ее","ые","ие","ой","ей","ый","ий","ом","ем","ах","ях","ов","ев" }
local RU_TAIL1 = { "а","я","ы","и","у","ю","о","е","ё","й","ь" }
local function stemWord(w)
  local last = w:sub(-1)
  if (last >= "a" and last <= "z") or (last >= "A" and last <= "Z") then
    local tail2 = w:sub(-2)
    if #w > 4 and (tail2 == "en" or tail2 == "es") then return w:sub(1, -3) end
    if #w > 3 and (last == "s" or last == "x" or last == "n") then return w:sub(1, -2) end
    return w
  end
  if last < "\128" then return w end
  for i = 1, #RU_TAIL2 do
    local t = RU_TAIL2[i]
    if #w > #t + 2 and w:sub(-#t) == t then return w:sub(1, -#t - 1) end
  end
  for i = 1, #RU_TAIL1 do
    local t = RU_TAIL1[i]
    if #w > #t + 2 and w:sub(-#t) == t then return w:sub(1, -#t - 1) end
  end
  return w
end
local function stemBlob(s)
  if type(s) ~= "string" then return "" end
  local words = {}
  for w in s:gmatch("[%w\128-\255]+") do words[#words + 1] = stemWord(w) end
  return table.concat(words, " ")
end

-- Plain-language synonyms the labels never spell: slang and translits a player types instead of the
-- written word. Per locale, each maps the typed word to the words the labels and tooltips carry, in the
-- player's spelling first and in English second, so "голда" answers the way "золото" and "gold" do.
-- Compared folded, like the query itself; a query that is already a written word never reaches this table.
local SEARCH_SYN = {
  enUS = {
    ["ah"] = { "auction" },
    ["ilvl"] = { "item level" },
  },
  deDE = {
    ["rucksack"] = { "taschen", "bags" },
    ["skin"] = { "design", "theme" },
  },
  frFR = {
    ["hv"] = { "hôtel des ventes" },
    ["stuff"] = { "objets", "items" },
  },
  itIT = {
    ["asta"] = { "casa d'aste" },
  },
  ptBR = {
    ["leilão"] = { "casa de leilões" },
    ["leilao"] = { "casa de leilões" },
    ["grana"] = { "ouro" },
  },
  koKR = {
    ["인벤"] = { "가방" },
    ["렙"] = { "레벨" },
  },
  zhCN = {
    ["g"] = { "金币" },
  },
  zhTW = {
    ["g"] = { "金幣" },
  },
  ruRU = {
    ["голда"] = { "золото", "gold" },
    ["бабки"] = { "золото", "gold" },
    ["бабло"] = { "золото", "gold" },
    ["голд"] = { "золото", "gold" },
    ["прозрачность"] = { "opacity" },
    ["илвл"] = { "item level" },
    ["зазор"] = { "промежуток", "gap" },
    ["вендор"] = { "торговец", "vendor" },
    ["мейл"] = { "почта", "mail" },
    ["трейд"] = { "обмен", "trade" },
    ["варбанд"] = { "отряд", "warband" },
    ["шмот"] = { "item" },
    ["крафт"] = { "профессии", "professions" },
    ["лут"] = { "sell", "продавать" },
    ["починка"] = { "ремонт", "repair" },
    ["квест"] = { "quest", "задание" },
    ["ах"] = { "аукцион", "auction" },
    ["скин"] = { "тема", "theme" },
    ["табы"] = { "вкладка", "tab" },
  },
}

-- The search index: one entry per row of every page, its name and its tooltip, built once and dropped when
-- the language moves, since a player types the label they read. It walks the page tables rather than the
-- built rows, so a setting on a page nobody has opened this session is found all the same, and no page has to
-- be built to be searched. Every page and every list of it is an entry as well: a place, with no row to walk
-- to, so a query that names a tab answers with the tab: without that a query like "grid" found nothing at
-- all here, which is the one answer a player looking in the wrong tab must never get.
-- The label's spellings in every loaded language, folded: the search answers a word typed in a language
-- the window is not reading, the way the bag search reads every language's words whatever the interface is
-- set to. Only static labels travel: a function name is already the spelling on screen.
local function crossLabels(key)
  if type(key) ~= "string" or key == "" then return nil end
  local codes = ns.LOCALES
  if type(codes) ~= "table" then return nil end
  local out
  for i = 1, #codes do
    local t = ns.LocaleStrings and ns.LocaleStrings(codes[i]) or nil
    local s = (type(t) == "table" and t[key]) or nil
    if type(s) == "string" and s ~= "" then
      local f = ns.SearchFold(s)
      if f ~= "" then out = out or {}; out[#out + 1] = f end
    end
  end
  return out
end

function Options:SearchIndex()
  if self.searchIdx then return self.searchIdx end
  local out = {}
  local function place(i, label, sub, parent)
    if type(label) ~= "string" or label == "" then return end
    local loc = T(label)
    local plab = parent and T(parent) or ""
    -- The breadcrumb is searchable as one more word for the place: a query that names a page lists the lists
    -- under it, so "grid" answers with Grid and with the three lists of it in the same breath. Both spellings
    -- go in, since a player types whichever one is on their screen.
    local fold = ns.SearchFold(label)
    local foldLoc = ns.SearchFold(loc)
    local e = {
      page = i, sub = sub, place = true, loc = loc, where = plab,
      l = fold, ll = foldLoc,
      hay = parent and ns.SearchFold(parent .. " " .. label .. " " .. plab .. " " .. loc) or nil,
      n = (fold:gsub(" ", "")), nl = (foldLoc:gsub(" ", "")),
      lx = crossLabels(label),
    }
    e.st = stemBlob(e.l .. " " .. e.ll .. " " .. (e.hay or "") .. " " .. table.concat(e.lx or {}, " "))
    out[#out + 1] = e
  end
  for i = 1, #Options.pages do
    local page = Options.pages[i]
    local lists = page.subs or { { list = page.list } }
    -- The page first, then each list of it: the page answers to its own name, a list to its name with the
    -- page it belongs to as its breadcrumb.
    place(i, page.name, 1)
    for k = 1, #lists do
      local sub = lists[k]
      place(i, sub.name, k, page.name)
      local where = T(page.name) .. (sub.name and (" / " .. T(sub.name)) or "")
      local list = sub.list or {}
      for j = 1, #list do
        local spec = list[j]
        local label = spec.name
        if type(label) == "function" then label = label() end
        -- A description row is a paragraph, not a setting: its words are not a name to look for.
        if type(label) == "string" and label ~= "" and spec.type ~= "description" then
          local loc = T(label)
          local tip = type(spec.desc) == "string" and spec.desc or ""
          -- SearchFold and not :lower(): the client folds ASCII alone, so a Russian label only answered a
          -- query that copied its capital letters. The bag search has folded this way all along.
          local fold, foldLoc = ns.SearchFold(label), ns.SearchFold(loc)
          local e = {
            page = i, sub = k, spec = spec, loc = loc, where = where,
            hd = spec.type == "header" and true or nil,
            l = fold, ll = foldLoc, ld = ns.SearchFold(tip .. " " .. (T(tip) or "")),
            n = (fold:gsub(" ", "")), nl = (foldLoc:gsub(" ", "")),
            lx = crossLabels(type(spec.name) == "string" and spec.name or nil),
          }
          e.st = stemBlob(e.l .. " " .. e.ll .. " " .. (e.ld or "") .. " " .. table.concat(e.lx or {}, " "))
          out[#out + 1] = e
        end
      end
    end
  end
  self.searchIdx = out
  return out
end

-- One query against the index: the name exactly, then a prefix, then anywhere in the name, then the name with
-- its spaces dropped (so "plateopacity" finds "Plate opacity"), then the breadcrumb a place carries, then
-- anywhere in the tooltip, and last the stemmed words, so an inflection answers its dictionary form. The first
-- three tiers read every language's spelling of the name, so a word typed in a language the window is not
-- reading still answers. A synonym of the query answers with the same tiers through the words it stands for. The name is read in both spellings at every one of those tiers, since the written
-- label and the one on screen are two names for one row and a player may type either. The first tier that
-- answers wins, and the list comes back in tier then alphabetical order, which puts the row the player means at
-- the top without any scoring arithmetic, and never lets a place reached by its page outrank a row that wears
-- the query in its own name. A place and a row are the two kinds here: a row holds a setting, a place is a page
-- or one list of it, so it carries no row of its own to walk to and its name is the whole of what it is.
-- One spelling among the entry's other-language labels answering exactly, by prefix or by part.
local function lxHit(e, qq, mode)
  local lx = e.lx
  if not lx then return false end
  if mode == 1 then
    for i = 1, #lx do if lx[i] == qq then return true end end
  elseif mode == 2 then
    for i = 1, #lx do if lx[i]:sub(1, #qq) == qq then return true end end
  else
    for i = 1, #lx do if lx[i]:find(qq, 1, true) then return true end end
  end
  return false
end

function Options:SearchMatches(query)
  local q = ns.SearchFold(query or ""):match("^%s*(.-)%s*$")
  if q == "" then return {} end
  local tight = q:gsub(" ", "")
  -- The query plus what its synonyms stand for: every spelling answers with the same tiers, and the entry
  -- keeps the best tier any of them reaches. A single latin letter is never a word, only an abbreviation, so it
  -- answers exactly and through its synonyms: without this "g" prefix-matched every English label starting
  -- with g and buried the gold rows it stood for.
  local tiny = (#q == 1 and q:find("%a")) and true or nil
  local queries = { { q = q, tight = tight, sq = stemBlob(q), bare = tiny } }
  local loc = localeGet and localeGet() or nil
  local syn = (loc and SEARCH_SYN[loc]) or nil
  -- esMX carries no strings of its own, only overrides over esES (see the FALLBACK in Core/Locale.lua),
  -- so it reads the Spanish synonyms too.
  if not syn and loc == "esMX" then syn = SEARCH_SYN.esES end
  -- English abbreviations travel: "ilvl" and "ah" are typed whatever the window reads. So does slang:
  -- the tables hold no word twice with two meanings, and every canonical answers in both spellings, so a
  -- Russian "голда" typed into an English window still lands on the gold rows.
  local alt = (syn and syn[q]) or (SEARCH_SYN.enUS and SEARCH_SYN.enUS[q]) or nil
  if not alt then
    for _, t in pairs(SEARCH_SYN) do
      local v = t[q]
      if v then alt = v; break end
    end
  end
  if alt then
    for i = 1, #alt do
      local fq = ns.SearchFold(alt[i]):match("^%s*(.-)%s*$")
      if fq ~= "" and fq ~= q then queries[#queries + 1] = { q = fq, tight = fq:gsub(" ", ""), sq = stemBlob(fq) } end
    end
  end
  local idx = self:SearchIndex()
  local out = {}
  for i = 1, #idx do
    local e = idx[i]
    local tier
    for k = 1, #queries do
      local qq, tt, ss = queries[k].q, queries[k].tight, queries[k].sq
      local t
      if e.l == qq or e.ll == qq or lxHit(e, qq, 1) then t = 1
      elseif e.l:sub(1, #qq) == qq or e.ll:sub(1, #qq) == qq or lxHit(e, qq, 2) then t = 2
      elseif e.l:find(qq, 1, true) or e.ll:find(qq, 1, true) or lxHit(e, qq, 3) then t = 3
      elseif e.n:find(tt, 1, true) or e.nl:find(tt, 1, true) then t = 4
      elseif e.hay and e.hay:find(qq, 1, true) then t = 5
      elseif e.ld and e.ld:find(qq, 1, true) then t = 6
      elseif e.st and ss ~= "" and #ss >= 3 and e.st:find(ss, 1, true) then t = 7
      end
      if t and (not tier or t < tier) then tier = t end
      local sp = queries[k]
      if sp.bare and tier and tier > 1 then tier = nil end
    end
    if tier then out[#out + 1] = { e = e, t = tier } end
  end
  table.sort(out, function(a, b)
    if a.t ~= b.t then return a.t < b.t end
    -- Inside one tier the places come first: a query that names a page or one of its lists reads as "take me
    -- there", and the row that happens to spell the same word stays a line under it.
    if a.e.place ~= b.e.place then return a.e.place end
    -- A heading names a block, it does not set anything: where a row and the heading over it share a name,
    -- the row is the one a player means.
    if (a.e.hd or false) ~= (b.e.hd or false) then return not a.e.hd end
    if a.e.l ~= b.e.l then return a.e.l < b.e.l end
    return (a.e.where or "") < (b.e.where or "")
  end)
  return out
end

-- One keystroke: the count beside the box, and the matches under it. Nothing is built for a query that finds
-- nothing, and the list is the window's own menu, so it brings its scrollbar, its click catcher and its cap of
-- nine visible rows for free. showDropdown and not openDropdown: the ordinary way in closes the menu when the
-- control that opened it is pressed again, which is exactly wrong while the player is still typing.
function Options:SearchRefresh(query)
  if not self.searchBox then return end
  local hits = self:SearchMatches(query)
  self.searchTop = hits[1] and hits[1].e or nil
  if #hits == 0 then
    -- A query that finds nothing says so beside the box; an empty box just says nothing.
    local idle = (query == nil or query == "")
    self.searchCount:SetText(idle and "" or T("Nothing found"))
    closeDropdown()
    return
  end
  self.searchCount:SetText(("%d"):format(#hits))
  local keys = {}
  for i = 1, math.min(#hits, 40) do keys[i] = hits[i].e end
  -- A row reads "its name   the page it lives on", which is the whole answer to "where is this one": the player
  -- came to the box because the page they would have looked on was the wrong one, so the breadcrumb is what
  -- teaches them. A place wears the accent instead and carries no name of its own, so the two never read as
  -- the same kind of hit.
  local ar, ag, ab = Theme:C("accent")
  local accent = ("|cff%02x%02x%02x"):format(math.floor(ar * 255 + 0.5), math.floor(ag * 255 + 0.5), math.floor(ab * 255 + 0.5))
  -- The breadcrumb in dim, so the eye stops at the name: one ink for both made "Gold format General /
  -- Interface" read as a single sentence with the page lost somewhere in the middle of it.
  local dr, dg, db = Theme:C("dim")
  local dim = ("|cff%02x%02x%02x"):format(math.floor(dr * 255 + 0.5), math.floor(dg * 255 + 0.5), math.floor(db * 255 + 0.5))
  showDropdown(self.searchBox, {
    keys = function() return keys end,
    get = function() end,
    label = function(k)
      if k.place then return accent .. (k.where ~= "" and (k.where .. "  /  " .. k.loc) or k.loc) .. "|r" end
      return k.loc .. "   " .. dim .. k.where .. "|r"
    end,
    set = function(k) self:GoToRow(k) end,
  })
end

-- Walk the window to what the search found: its page, its sub-list, its section if the row is folded away,
-- then the list scrolls it into sight and the wash says which one it was. Select does the page, the sub and
-- the row pass; everything after it is the walk itself, and the top of the query is what Enter walks to. A
-- place stops after the page and the sub, since there is no row of its own to reach.
function Options:GoToRow(entry)
  local e = entry
  if not (e and e.page) then return end
  self.subAt[e.page] = e.sub or 1
  self:Select(e.page)
  -- A place is the page and its list, and there is no row after that: the strip button the query named takes
  -- the wash, so a jump onto a list the window was already sitting on still says where it went.
  if not e.spec then
    local entryAt = self.subs[e.page]
    local btn = entryAt and entryAt.btns and entryAt.btns[e.sub or 1]
    if btn then self:WashRow(btn) end
    return
  end
  if e.spec.section and not sectionOpen(e.spec.section) then
    sectionToggle(e.spec.section)
    self:ReflowPages()
  end
  local area = self.subs[e.page] and self.subs[e.page].areas[self.subAt[e.page] or 1]
  local page = area and area.page
  if not (page and page.rows) then return end
  local row
  for i = 1, #page.rows do
    if page.rows[i].spec == e.spec then row = page.rows[i].row; break end
  end
  if not (row and row:IsShown()) then return end
  local off = (page:GetTop() or 0) - (row:GetTop() or 0)
  local cur = area:GetVerticalScroll() or 0
  local view = area:GetHeight() or 0
  if off < cur or off + row:GetHeight() > cur + view then
    area:ScrollTo(math.max(0, off - 12))
  end
  self:WashRow(row)
end

-- The wash over a row or a sub button the search walked to: the same accent a freshly added category wears when its own list
-- scrolls to it, at a low alpha baked into the colour, since a theme change repaints the texture and would
-- flare a SetAlpha wash back to full. It lives on its own field, away from the wash the category list keeps
-- on its own rows, so the two timers never cut each other short.
function Options:WashRow(row)
  local f = row.wpeWash
  if not f then
    f = CreateFrame("Frame", nil, row)
    f:SetFrameLevel(row:GetFrameLevel() + 40)
    local wash = f:CreateTexture(nil, "OVERLAY")
    wash:SetAllPoints(f)
    local function paintWash(x) local r, g, b = Theme:C("accent"); x:SetColorTexture(r, g, b, 0.22) end
    paintWash(wash)
    Theme:Track(wash, paintWash)
    row.wpeWash = f
  end
  f:ClearAllPoints()
  f:SetAllPoints(row)
  f:Show()
  self.washSeq = (self.washSeq or 0) + 1
  local mine = self.washSeq
  C_Timer.After(1.1, function()
    if mine == self.washSeq and row.wpeWash then row.wpeWash:Hide() end
  end)
end

-- One page's lists, built once and hidden until selected: whatever Select did not pick stays down,
-- like every other page it never built. A second call is a no-op returning what the first made.
function Options:BuildPage(i)
  if self.subs[i] then return self.subs[i] end
  local pageDef = Options.pages[i]
  local f = self.frame
  if not (pageDef and f) then return nil end
  local list = pageDef.subs or { { list = pageDef.list } }
  local entry = { areas = {}, btns = {} }
  if #list > 1 then
    local strip = CreateFrame("Frame", nil, f)
    strip:SetHeight(SUB_H)
    strip:Hide()
    entry.strip = strip
  end
  for k, sub in ipairs(list) do
    if entry.strip then
      local b = ns.CreateButton(entry.strip, T(sub.name), 80, SUB_H)
      track(b.Text, -2)
      b:SetScript("OnClick", function() self:SubSelect(k) end)
      b:HookScript("OnLeave", paintSub)
      entry.btns[k] = b
    end
    local area = makeScrollArea(f, sub.list)
    area:SetPoint("TOPLEFT", PAD, -(HEADER_H + TAB_H + 14))
    area:SetPoint("BOTTOMRIGHT", -(PAD + SCROLL_W + 6), PAD)
    area.bar:SetPoint("TOPLEFT", area, "TOPRIGHT", 6, 0)
    area.bar:SetPoint("BOTTOMLEFT", area, "BOTTOMRIGHT", 6, 0)
    area:Hide()
    area.bar:Hide()
    entry.areas[k] = area
    self.areas[#self.areas + 1] = area
  end
  self.subs[i] = entry
  -- Placed here and not at the next reflow: the strip buttons are measured by layoutStrip and the strip
  -- and lists anchored by AnchorHeader, and neither pass runs on a tab switch.
  layoutStrip(entry, pageDef.subs)
  self:AnchorHeader()
  return entry
end

function Options:Build()
  if self.frame then return self.frame end

  local f = CreateFrame("Frame", "WarpeeOptionsFrame", UIParent, "BackdropTemplate")
  f:Hide()
  Theme:Panel(f, "bg", "stroke", true)
  ns.SnapBox(f, WIN_W, math.min(WIN_H, UIParent:GetHeight() - 60), true)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(s) ns.DragMove(s) end)
  f:SetScript("OnDragStop", function(s)
    -- The move flag is cleared with the gesture here as it is on the bags, the bank and the pocket. It was
    -- left standing after the first drag, and it is the flag the move driver reads on every frame this
    -- window stays open.
    if not s.wpeMoving then return end
    s.wpeMoving = nil
    s:StopMovingOrSizing()
    local p, rp, x, y = ns.SnapFrame(s)
    if p then WarpeeDB.optPos = { p = p, rp = rp, x = x, y = y } end
    if ns.Profiles and ns.Profiles.SyncActive then ns.Profiles:SyncActive() end
  end)
  f:SetScript("OnMouseDown", function(s) Theme:Raise(s) end)
  Theme:Window(f, "WarpeeOptionsFrame")
  f:SetFrameStrata("DIALOG")
  Theme:HeaderBand(f, HEADER_H + Theme:TopInset())
  f:SetScript("OnHide", function()
    local row = Options.charsRow
    if row and row.delMode then
      row.delMode = nil
      if row.Rebuild then row.Rebuild() end
    end
    ns.HideTip()
    -- The query is dropped with the window: the box comes back empty and the list unfiltered, rather than
    -- showing a word from last time over a page that has nothing to do with it.
    if Options.searchBox then Options.searchBox:SetText("") end
    -- The profile capture trails the row passes by a moment, so the window closing is where the last one is
    -- written: whatever was moved before walking away stands in the active profile when it is read next.
    if ns.Profiles and ns.Profiles.SyncActive then ns.Profiles:SyncActive() end
  end)
  self.frame = f

  local title = Theme:Title(f, BASE_FONT + 2, "accent")
  title:SetPoint("TOPLEFT", PAD, -10)
  title:SetText(ns.TITLE)
  track(title, 2)
  self.title = title

  local close = ns.CreateGlyphButton(f, "×", 28)
  close:SetPoint("TOPRIGHT", -PAD, -8)
  close:SetScript("OnClick", function() self:Close() end)
  track(close.Text, 2)
  self.closeBtn = close

  local prof = ns.CreateButton(f, "", 76, 28)
  ns.LocalText(prof.Text, "Profiles")
  track(prof.Text, -1)
  prof:SetWidth(math.max(64, prof.Text:GetStringWidth() + 20))
  ns.SnapPoint(prof, "RIGHT", close, "LEFT", -6, 0)
  prof:SetScript("OnClick", function() ns.Profiles:Toggle() end)
  self.profilesBtn = prof

  -- The search field. Seven pages and three sub-lists deep, the player who comes back to change one setting
  -- looks for it by name rather than by the page it lives on, so every row answers to its own words as well:
  -- the matches hang under the box like any other menu, and a pick walks the window to that row and washes
  -- it once. The box rides in the header over no list at all, so it costs the pages none of their room.
  -- The box sits at the right end of the header, just left of the Profiles button, where a search field is
  -- looked for: the two are the window's only header controls, so they line up as one group. Snapped and even
  -- sized like every other control here, so the hairline of its border lands on the pixel grid and stays one
  -- pixel from edge to edge.
  local search = CreateFrame("EditBox", nil, f, "BackdropTemplate")
  ns.SnapBox(search, 214, 22, true)
  ns.SnapPoint(search, "RIGHT", prof, "LEFT", -8, 0)
  ns.PixelBackdrop(search)
  -- The fill the window's own search fields use: a light theme paints the box as a slot, since the panel
  -- colour there would leave the box and its border the same value and the field would read as a hole.
  local function searchBg() return Theme:C(Theme:IsLight() and "slot" or "bg") end
  ns.SetBg(search, searchBg())
  ns.SetEdge(search, Theme:C("stroke"))
  Theme:Track(search, function(s)
    ns.SetBg(s, searchBg())
    s:SetTextColor(Theme:C("text"))
    if not s:HasFocus() then ns.SetEdge(s, Theme:C("stroke")) end
  end)
  search:SetFont(dropdownFont(), BASE_FONT - 1, ns.OutlineFlags())
  search:SetTextColor(Theme:C("text"))
  search:SetJustifyH("LEFT")
  search:SetTextInsets(8, 8, 0, 0)
  search:SetAutoFocus(false)
  search:SetMaxLetters(32)
  track(search, -1)
  self.searchBox = search

  local placeholder = track(Theme:Label(search, BASE_FONT - 1, "faint"), -1)
  placeholder:SetPoint("LEFT", 8, 0)
  -- Through LocalText, so a language switch repaints it with everything else instead of waiting for a reload.
  ns.LocalText(placeholder, "Search settings")
  self.searchPh = placeholder

  -- How many the query found, on the far side of the box: the room to the right of it now belongs to the
  -- Profiles button, so the count grows leftwards from the field instead of pushing into it.
  local hits = track(Theme:Label(f, BASE_FONT - 3, "faint"), -3)
  ns.SnapPoint(hits, "RIGHT", search, "LEFT", -8, 0)
  self.searchCount = hits

  search:SetScript("OnTextChanged", function(s)
    local q = s:GetText() or ""
    placeholder:SetShown(q == "")
    Options:SearchRefresh(q)
  end)
  search:SetScript("OnEscapePressed", function(s)
    s:SetText("")
    s:ClearFocus()
  end)
  search:SetScript("OnEnterPressed", function(s)
    local top = Options.searchTop
    if top then s:ClearFocus(); Options:GoToRow(top) end
  end)
  search:SetScript("OnEditFocusGained", function(s) ns.SetEdge(s, Theme:C("accent")) end)
  search:SetScript("OnEditFocusLost", function(s) ns.SetEdge(s, Theme:C("stroke")) end)

  local line = Theme:Rect(f, "strokeSoft", "ARTWORK")
  ns.PixelLine(line, 1)
  line:SetPoint("TOPLEFT", PAD, -HEADER_H)
  line:SetPoint("TOPRIGHT", -PAD, -HEADER_H)
  self.headLine = line

  -- A page holds one list, or a set of them behind a strip of its own buttons: the long pages reach a
  -- screenful each that way, and a page that already fits keeps the single list it has always had. areas
  -- is every list of every sub, flat, for the font pass that walks them all.
  -- Only the built pages are in either: tabs rise with the window, but a page's lists are built on the
  -- first visit (BuildPage), so the first open pays for one page instead of all seven.
  self.tabs, self.areas = {}, {}
  self.subs, self.subAt = {}, {}
  for i, pageDef in ipairs(Options.pages) do
    local tab = ns.CreateButton(f, T(pageDef.name), 90, TAB_H)
    track(tab.Text, -1)
    tab:SetWidth(math.max(70, tab.Text:GetStringWidth() + 22))
    -- Placement is done by ReflowPages so a hidden tab leaves no gap; here we only create it.
    tab:HookScript("OnLeave", paintTab)
    tab:SetScript("OnClick", function() self:Select(i) end)
    self.tabs[i] = tab
    self.subAt[i] = 1
  end
  self:BuildPage(1)

  self:ApplyFont()
  self:ReflowPages()
  self:AnchorHeader()
  self:Select(1)
  return f
end

function Options:AnchorHeader()
  local f = self.frame
  if not f then return end
  local top = Theme:TopInset()
  if self.title then
    self.title:ClearAllPoints()
    self.title:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(10 + top))
  end
  if self.closeBtn then
    self.closeBtn:ClearAllPoints()
    ns.SnapPoint(self.closeBtn, "TOPRIGHT", f, "TOPRIGHT", -PAD, -(8 + top))
  end
  -- The search field rides on the same band as the rest of the header: its left side hugs the Profiles
  -- button, an 8 pixel gap between them, and the count glows on the box's left, so the number grows toward
  -- the tabs. Both snapped to keywords so the Endless pixel grid keeps the pair sharp, and the skin's own
  -- TopInset only moves the band, because the pair only rides it once at build.
  if self.searchBox then
    self.searchBox:ClearAllPoints()
    ns.SnapPoint(self.searchBox, "RIGHT", self.profilesBtn, "LEFT", -8, 0)
    if self.searchCount then
      self.searchCount:ClearAllPoints()
      ns.SnapPoint(self.searchCount, "RIGHT", self.searchBox, "LEFT", -8, 0)
    end
  end
  if self.headLine then
    self.headLine:ClearAllPoints()
    self.headLine:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(HEADER_H + top))
    self.headLine:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -(HEADER_H + top))
  end
  local first = self.tabs and self.tabs[1]
  if first then
    first:ClearAllPoints()
    ns.SnapPoint(first, "TOPLEFT", f, "TOPLEFT", PAD, -(HEADER_H + 7 + top))
  end
  -- A page with a strip gives it room: the strip sits a gap under the tab row, and the page's list
  -- starts a gap under the strip. A page without one keeps the single list it has always had. Every
  -- offset is measured off the row the tabs sit in, so a translation or a font change never moves
  -- the window's frame.
  local tabsBottom = HEADER_H + 7 + TAB_H + top
  for i = 1, #Options.pages do
    local entry = self.subs[i]
    if entry then
    local areaTop = tabsBottom + 14
    if entry.strip then
      -- Both edges, not just the corner: a strip left at zero width is a degenerate rect, and the
      -- points of anything anchored to it do not resolve. The sub buttons chain off this frame's
      -- LEFT, so without a width they were built, shown and sized and still never drew. The level
      -- puts the row above the scroll areas of every page.
      local stripTop = tabsBottom + SUB_GAP
      entry.strip:ClearAllPoints()
      entry.strip:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -stripTop)
      entry.strip:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -stripTop)
      entry.strip:SetFrameLevel(f:GetFrameLevel() + 4)
      areaTop = stripTop + SUB_H + SUB_DROP
    end
    for _, area in ipairs(entry.areas) do
      area:ClearAllPoints()
      area:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -areaTop)
      area:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(PAD + SCROLL_W + 6), PAD)
    end
    end
  end
  local band = Theme:HeaderBand(f, HEADER_H + top)
  if self.headLine then self.headLine:SetShown(not band) end
end

function Options:Open()
  local f = self:Build()
  local pos = WarpeeDB and WarpeeDB.optPos
  f:ClearAllPoints()
  if pos then
    ns.SnapPoint(f, pos.p, UIParent, pos.rp, pos.x, pos.y)
  else
    ns.SnapPoint(f, "CENTER", UIParent, "CENTER", 260, 0)
  end
  self:Refresh()
  self:ApplyFont()
  f:Show()
  ns.AlignToScreen(f)
  Theme:Raise(f)
end

function Options:Close()
  closeDropdown()
  if ns.Profiles and ns.Profiles.panel then ns.Profiles.panel:Hide() end
  if self.frame then self.frame:Hide() end
end

function Options:Toggle()
  if self.frame and self.frame:IsShown() then self:Close() else self:Open() end
end
