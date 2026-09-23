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
local BASE_FONT = 15
local ROW_GAP = 10
local SCROLL_W = 8
local CONTENT_W = WIN_W - PAD * 2 - SCROLL_W - 6

local function relayout()
  Bags:Refont()
  if Bags.frame and Bags.frame:IsShown() then Bags:Layout() end
  if ns.Bank and ns.Bank.Refresh then ns.Bank:Refresh() end
  if ns.Pocket and ns.Pocket.Apply then ns.Pocket:Apply() end
  if ns.GuildBankSkin and ns.GuildBankSkin.Restyle then ns.GuildBankSkin:Restyle() end
  local P = ns.CharPicker
  if P and P.frame and P.frame:IsShown() and P.Paint then P:Paint(true) end
  C_Timer.After(0, function()
    if Bags.frame and Bags.frame:IsShown() then Bags:FitHeader() end
  end)
end

local function field(name)
  local get = function() return Bags[name] end
  local set = function(v) Bags[name] = v; WarpeeDB[name] = v; relayout() end
  return get, set
end

local function styleField(name)
  local get = function() return Bags[name] end
  local set = function(v)
    Bags[name] = v; WarpeeDB[name] = v
    Bags.styleGen = (Bags.styleGen or 0) + 1
    relayout()
  end
  return get, set
end

-- Options.lua loads before Core.lua, so the factory table cannot be captured here: it is
-- looked up when the getter runs. The literal left in each call is only a last resort, and
-- the numbers the panel shows are the numbers DEFAULTS ships.
local function dbField(name, default)
  local get = function()
    return WarpeeDB[name] or (ns.DEFAULTS and ns.DEFAULTS[name]) or default
  end
  local set = function(v)
    WarpeeDB[name] = v
    if ns.Bank then ns.Bank:Refresh() end
  end
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
  relayout()
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
  return (WarpeeDB and tonumber(WarpeeDB.pocketIconSize))
         or (Bags and Bags.iconSize) or ns.DEFAULT_CELL
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
        g.x = math.floor((g.x or 0) * k + 0.5)
        g.y = math.floor((g.y or 0) * k + 0.5)
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
    if key == "locked" then
      for _ in pairs(WarpeeDB and WarpeeDB.vendorBlack or {}) do return true end
      return false
    end
    -- DEFAULTS.optSections carries every section key and the login path writes them all, so
    -- this is only reached by a key it does not know, and a section nobody has an opinion
    -- about starts open. The table that used to answer here said the opposite of DEFAULTS for
    -- four of the seven keys and was never read.
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

local dropdown

local function closeDropdown()
  if dropdown then dropdown:Hide() end
end
ns.CloseDropdown = closeDropdown

local function dropdownFont()
  return ns.Fonts:Current()
end

local function makeMenuRow(parent, index, rowH)
  local r = CreateFrame("Button", nil, parent)
  r:SetHeight(rowH)
  r:SetPoint("TOPLEFT", 0, -(index - 1) * rowH)
  r:SetPoint("TOPRIGHT", 0, -(index - 1) * rowH)

  local bg = Theme:Rect(r, "panelHi", "BACKGROUND")
  bg:SetAllPoints(r)
  bg:Hide()
  r.bg = bg

  local dot = Theme:Rect(r, "accent", "ARTWORK")
  dot:SetSize(3, rowH - 8)
  dot:SetPoint("LEFT", 2, 0)
  dot:Hide()
  r.dot = dot

  local fs = track(Theme:Label(r, BASE_FONT - 1, "text"), -1)
  fs:SetFont(dropdownFont(), BASE_FONT - 1, ns.OutlineFlags())
  fs:SetPoint("LEFT", 10, 0)
  fs:SetPoint("RIGHT", -8, 0)
  fs:SetJustifyH("LEFT")
  -- One line per entry, always: a row is one row tall, so a two-word label that wrapped would be drawn
  -- out of its own row and the menu would read as broken. The menu is widened to the longest entry where
  -- it opens (openDropdown), so nothing is cut off either.
  fs:SetWordWrap(false)
  r.Text = fs

  r:SetScript("OnEnter", function(s)
    s.bg:Show()
    if dropdown and dropdown.desc then
      ns.ShowTip(s, { { text = dropdown.desc } }, "top")
    end
  end)
  r:SetScript("OnLeave", function(s) s.bg:Hide(); ns.HideTip() end)
  return r
end

local function ensureDropdown()
  if dropdown then return dropdown end

  local catcher = CreateFrame("Button", nil, UIParent)
  catcher:SetAllPoints(UIParent)
  catcher:SetFrameStrata("DIALOG")
  catcher:RegisterForClicks("AnyUp")
  catcher:Hide()

  local m = CreateFrame("Frame", "WarpeeDropdown", UIParent, "BackdropTemplate")
  m:Hide()
  Theme:Panel(m, "panel", "accent")
  m:SetFrameStrata("DIALOG")
  m:SetToplevel(true)
  m:SetFrameLevel(catcher:GetFrameLevel() + 10)
  m:EnableMouse(true)
  m:SetClampedToScreen(true)

  local sf = CreateFrame("ScrollFrame", nil, m)
  sf:SetPoint("TOPLEFT", 4, -4)
  sf:SetPoint("BOTTOMRIGHT", -4, 4)
  local child = CreateFrame("Frame", nil, sf)
  child:SetPoint("TOPLEFT")
  sf:SetScrollChild(child)

  -- A scrollbar so a menu longer than its 9-row cap shows it continues: without it a long list (fonts,
  -- token groups) looked like it simply ended at the last visible row. Same look as the page scrollbar
  -- - panel track, faint thumb that lights on hover and drag - and it hides itself when everything fits.
  local bar = CreateFrame("Frame", nil, m)
  bar:SetWidth(SCROLL_W)
  bar:SetPoint("TOPRIGHT", -3, -4)
  bar:SetPoint("BOTTOMRIGHT", -3, 4)
  Theme:Rect(bar, "panel", "BACKGROUND"):SetAllPoints(bar)
  local thumb = CreateFrame("Frame", nil, bar)
  thumb:SetWidth(SCROLL_W)
  local thumbTex = Theme:Rect(thumb, "faint", "ARTWORK")
  thumbTex:SetAllPoints(thumb)
  m.bar, m.thumb = bar, thumb

  local function menuSpan() return math.max(0, child:GetHeight() - sf:GetHeight()) end
  local function paintBar()
    local span, view = menuSpan(), sf:GetHeight()
    if span <= 0 or not m:IsShown() then bar:Hide(); return end
    bar:Show()
    local ch = child:GetHeight()
    local h = math.max(20, view * view / (ch > 0 and ch or view))
    thumb:SetHeight(h)
    local frac = sf:GetVerticalScroll() / span
    thumb:ClearAllPoints()
    thumb:SetPoint("TOP", bar, "TOP", 0, -frac * (view - h))
  end
  m.PaintBar = paintBar
  local function menuScroll(v)
    local span = menuSpan()
    v = math.min(span, math.max(0, v))
    sf:SetVerticalScroll(math.min(span, ns.SnapScroll(sf, v)))
    paintBar()
  end
  m.MenuScroll = menuScroll

  sf:EnableMouseWheel(true)
  sf:SetScript("OnMouseWheel", function(s, d) menuScroll(s:GetVerticalScroll() - d * 40) end)

  thumb:EnableMouse(true)
  thumb:SetScript("OnMouseDown", function(s)
    s.grabY = select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
    s.grabScroll = sf:GetVerticalScroll()
    s:SetScript("OnUpdate", function(t)
      local y = select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
      local travel = sf:GetHeight() - t:GetHeight()
      if travel <= 0 then return end
      menuScroll(t.grabScroll + (t.grabY - y) * menuSpan() / travel)
    end)
    thumbTex:SetVertexColor(Theme:C("accent"))
  end)
  thumb:SetScript("OnMouseUp", function(s)
    s:SetScript("OnUpdate", nil)
    thumbTex:SetVertexColor(Theme:C("faint"))
  end)
  thumb:SetScript("OnEnter", function() thumbTex:SetVertexColor(Theme:C("dim")) end)
  thumb:SetScript("OnLeave", function(s)
    if not s:GetScript("OnUpdate") then thumbTex:SetVertexColor(Theme:C("faint")) end
  end)

  m.rows, m.sf, m.child, m.catcher = {}, sf, child, catcher
  m:SetScript("OnHide", function() catcher:Hide(); ns.HideTip() end)
  catcher:SetScript("OnClick", function()
    local owner = dropdown and dropdown.owner
    closeDropdown()
    local f
    if GetMouseFoci then
      local foci = GetMouseFoci()
      f = (type(foci) == "table") and foci[1] or nil
    end
    if f and f ~= owner and f.wpeDrop and (not f.IsEnabled or f:IsEnabled()) then
      ns.OpenDropdown(f, f.wpeDrop.spec, f.wpeDrop.onPick)
    end
  end)
  ns.EscClose(m)
  dropdown = m
  return m
end

local function openDropdown(anchor, spec, onPick)
  local m = ensureDropdown()
  if m:IsShown() and m.owner == anchor then closeDropdown(); return end

  local keys = spec.keys()
  local rowH = BASE_FONT + 11
  local cur = spec.get()
  local curIndex = 1
  for i, key in ipairs(keys) do
    local r = m.rows[i]
    if not r then r = makeMenuRow(m.child, i, rowH); m.rows[i] = r end
    r:SetHeight(rowH)
    r.dot:SetSize(3, rowH - 8)
    r.Text:SetFont(dropdownFont(), BASE_FONT - 1, ns.OutlineFlags())
    r.Text:SetText(T(spec.label(key)))
    -- A "#" key is a section header: no dot, drawn faint. It still takes a click, because the token
    -- menu uses one as a way into that section, and the tip carries the hint that it opens.
    local head = type(key) == "string" and key:sub(1, 1) == "#"
    local on = (not head and key == cur)
    r.dot:SetShown(on)
    local tkey = head and "faint" or (on and "accentInk" or "text")
    r.Text:SetTextColor(Theme:C(tkey))
    r.bg:Hide()
    if head and not spec.nav then
      r:SetScript("OnClick", nil)
    else
      r:SetScript("OnClick", function()
        closeDropdown()
        spec.set(key)
        if ns.Profiles and ns.Profiles.SyncActive then ns.Profiles:SyncActive() end
        if onPick then onPick() end
      end)
    end
    r:Show()
    if on then curIndex = i end
  end
  for i = #keys + 1, #m.rows do m.rows[i]:Hide() end

  -- As wide as the longest entry, not as wide as the control it hangs from: with the rows on one line
  -- each, the menu has to hold the words it shows, and a translation longer than the English one (or a
  -- font's own name) must not be cut at the edge. The control's width stays a floor, so a short list does
  -- not shrink to a stub, and the menu is clamped to the screen like every window here.
  local widest = 0
  for i = 1, #keys do
    local r = m.rows[i]
    local wtext = (r and r.Text and r.Text:GetStringWidth()) or 0
    if wtext > widest then widest = wtext end
  end
  local w = math.max(anchor:GetWidth(), 120, math.ceil(widest) + 26)
  local visible = math.min(#keys, 9)
  ns.SnapSize(m, w, visible * rowH + 8)
  -- When the list overflows its 9-row cap the scrollbar shows on the right, so the rows give it room
  -- (its width plus a little air); a list that fits keeps the full width.
  local overflow = #keys > visible
  m.child:SetSize(w - 8 - (overflow and (SCROLL_W + 4) or 0), #keys * rowH)

  local span = math.max(0, #keys * rowH - visible * rowH)
  m.sf:SetVerticalScroll(math.min(span, ns.SnapScroll(m.sf, (curIndex - 1) * rowH - rowH * 3)))

  m.owner = anchor
  m.desc = spec.desc
  ns.HideTip()
  m:ClearAllPoints()
  local below = anchor:GetBottom() or 0
  if below - m:GetHeight() < 20 then
    m:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 2)
  else
    m:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
  end
  m.catcher:SetFrameLevel(anchor:GetFrameLevel() + 1)
  m.catcher:Show()
  m:Show()
  m:Raise()
  -- Size and scroll are set now, so paint the bar: it shows only when the list overflows and sits at
  -- the scroll position the current pick was brought to.
  if m.PaintBar then m:PaintBar() end
end

ns.OpenDropdown = openDropdown

local function caretGroup(parent, dir)
  return ns.ArrowGlyph(parent, dir, dir == "down" and 10 or 12)
end

function factories.header(parent, spec)
  local row = CreateFrame(spec.key and "Button" or "Frame", nil, parent)
  row:SetHeight(30)
  local line = Theme:Rect(row, "strokeSoft", "ARTWORK")
  ns.PixelLine(line, 1)
  line:SetPoint("BOTTOMLEFT", 0, 0)
  line:SetPoint("BOTTOMRIGHT", 0, 0)
  local fs = track(Theme:Label(row, BASE_FONT, "azure"), 0)
  fs:SetPoint("BOTTOMLEFT", spec.key and 22 or 0, 6)
  fs:SetText(ns.Upper(T(spec.name)))
  if not spec.key then
    local plain = spec.state and track(Theme:Label(row, BASE_FONT - 3, "faint"), -3)
    if plain then plain:SetPoint("BOTTOMRIGHT", 0, 7) end
    row.Refresh = function()
      fs:SetText(ns.Upper(T(spec.name)))
      if plain then plain:SetText((spec.state and spec.state()) or "") end
    end
    row.Refresh()
    return row
  end

  local down = caretGroup(row, "down")
  down:SetPoint("BOTTOMLEFT", 0, 8)
  local right = caretGroup(row, "right")
  right:SetPoint("BOTTOMLEFT", 3, 5)
  local state = track(Theme:Label(row, BASE_FONT - 3, "faint"), -3)
  state:SetPoint("BOTTOMRIGHT", 0, 7)

  row.Refresh = function()
    fs:SetText(ns.Upper(T(spec.name)))
    local on = sectionOpen(spec.key)
    down:SetShown(on)
    right:SetShown(not on)
    state:SetText((spec.state and spec.state()) or "")
  end
  row:SetScript("OnClick", function()
    sectionToggle(spec.key)
    row.Refresh()
    Options:ReflowPages()
  end)
  row:SetScript("OnEnter", function() fs:SetTextColor(Theme:C("accentInk")) end)
  row:SetScript("OnLeave", function() fs:SetTextColor(Theme:C("azure")) end)
  row.Refresh()
  return row
end

function factories.description(parent, spec)
  local row = CreateFrame("Frame", nil, parent)
  local fs = track(Theme:Label(row, BASE_FONT - 2, "dim"), -2)
  fs:SetPoint("TOPLEFT")
  fs:SetWidth(CONTENT_W)
  fs:SetJustifyH("LEFT")
  fs:SetSpacing(2)
  fs:SetText(T(spec.name))
  row:SetHeight(fs:GetStringHeight() + 6)
  row.autoHeight = fs
  row.Refresh = function() fs:SetText(T(spec.name)) end
  return row
end

function factories.toggle(parent, spec)
  local row = CreateFrame("Button", nil, parent)
  row:SetHeight(26)

  local box = ns.CreateCheckBox(row, 18)
  ns.SnapPoint(box, "TOPLEFT", row, "TOPLEFT", 1, -4)
  local mark = box.mark

  local fs = track(Theme:Label(row, BASE_FONT, "text"), 0)
  fs:SetPoint("LEFT", box, "RIGHT", 8, 0)
  fs:SetPoint("RIGHT", -2, 0)
  fs:SetJustifyH("LEFT")
  local function paintBox(hover)
    if row.off then
      box:SetKeys("slot", "strokeSoft", "faint")
    elseif row.on then
      box:SetKeys("slot", "bg", hover and "accentInk" or "accent")
    else
      box:SetKeys("slot", hover and "accent" or "stroke", "accent")
    end
  end
  row.Refresh = function()
    if type(spec.name) == "function" then
      fs:SetText(T(spec.name()) or "")
    else
      fs:SetText(T(spec.name))
    end
    local off = (spec.disabled and spec.disabled()) and true or false
    local on = spec.get() and true or false
    mark:SetShown(on)
    fs:SetTextColor(Theme:C(off and "faint" or (on and "text" or "dim")))
    row:SetEnabled(not off)
    row.off, row.on = off, on
    paintBox(not off and row:IsMouseOver())
  end
  row:SetScript("OnClick", function()
    if row.off then return end
    spec.set(not spec.get())
    row.Refresh()
    Options:Refresh()
  end)
  row:SetScript("OnEnter", function()
    if row.off then return end
    paintBox(true)
  end)
  row:SetScript("OnLeave", function()
    paintBox(false)
  end)
  row.Refresh()
  tip(row, spec.desc)
  return row
end

local KEY_MODS = {
  LCTRL = true, RCTRL = true, LSHIFT = true, RSHIFT = true, LALT = true, RALT = true,
}

-- Click the button, press a key, a mouse button, or the wheel, done: the binding is
-- written the way the game stores them, so the client's own key list stays in sync.
-- Escape cancels, a right click outside the capture unbinds. SetBinding is protected
-- in combat, so capture never starts there, and a press that lands mid combat is
-- dropped instead of applied.
-- The capture itself follows the game's own KeybindListener shape: one top level
-- button, no parent, that receives OnKeyDown only while its script is set. A nested
-- button inside the options window never sees a keypress arrive, no matter how it is
-- enabled, which is why the capture does not live on the visible button. The mouse
-- buttons and the wheel arrive through a fullscreen catcher instead: keys have no
-- position, clicks do, and the catcher owns them all while the capture runs, with
-- left and right reserved for cancel.
local keyListener = CreateFrame("Button")
keyListener:SetSize(1, 1)
keyListener:EnableMouse(false)
keyListener:SetFrameStrata("DIALOG")
local keyListen = nil

local function listenerKeyDown(_, key)
  if not keyListen then return end
  local swallow = keyListener.SetPropagateKeyboardInput
  if swallow then pcall(swallow, keyListener, false) end
  keyListen(key)
end

local mouseCatcher
local function catcherClick(_, button)
  if not keyListen then return end
  button = (button or ""):upper()
  if button == "LEFTBUTTON" or button == "RIGHTBUTTON" then keyListen("CANCEL") return end
  keyListen(button)
end

local function catcherWheel(_, delta)
  if not keyListen then return end
  keyListen((delta or 0) > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
end

local function startListen(fn)
  keyListen = fn
  keyListener:SetScript("OnKeyDown", listenerKeyDown)
  keyListener:Show()
  if not mouseCatcher then
    mouseCatcher = CreateFrame("Button", nil, UIParent)
    mouseCatcher:SetAllPoints(UIParent)
    mouseCatcher:SetFrameStrata("FULLSCREEN_DIALOG")
    mouseCatcher:RegisterForClicks("AnyUp")
    mouseCatcher:EnableMouseWheel(true)
    mouseCatcher:Hide()
  end
  mouseCatcher:SetScript("OnClick", catcherClick)
  mouseCatcher:SetScript("OnMouseWheel", catcherWheel)
  mouseCatcher:Show()
end

local function stopListen()
  if not keyListen then return end
  keyListen = nil
  keyListener:SetScript("OnKeyDown", nil)
  keyListener:Hide()
  if mouseCatcher then
    mouseCatcher:SetScript("OnClick", nil)
    mouseCatcher:SetScript("OnMouseWheel", nil)
    mouseCatcher:Hide()
  end
end

function factories.keybind(parent, spec)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(46)

  local nameFS = track(Theme:Label(row, BASE_FONT, "text"), 0)
  nameFS:SetPoint("TOPLEFT", 1, -1)
  nameFS:SetText(T(spec.name))

  local btn = CreateFrame("Button", nil, row, "BackdropTemplate")
  ns.SnapBox(btn, nil, 24)
  btn:SetPoint("BOTTOMLEFT", 1, 0)
  btn:SetPoint("BOTTOMRIGHT", -1, 0)
  ns.PixelBackdrop(btn)
  ns.SetBg(btn, Theme:C("panel"))
  ns.SetEdge(btn, Theme:C("stroke"))
  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  local cur = track(Theme:Label(btn, BASE_FONT - 1, "text"), -1)
  cur:SetPoint("CENTER")
  local capturing = false

  local function keyText()
    -- GetBindingKey returns BOTH slots; take the first non-empty so a key set only in the second
    -- slot still reads as bound instead of "Not bound".
    local k1, k2 = GetBindingKey and GetBindingKey(spec.binding)
    local k = (k1 and k1 ~= "" and k1) or (k2 and k2 ~= "" and k2) or nil
    if k then return k end
    return T("Not bound")
  end

  local function paint()
    local on = not (spec.disabled and spec.disabled())
    if capturing then
      cur:SetText(T("Press a key..."))
      cur:SetTextColor(Theme:C("accent"))
      ns.SetEdge(btn, Theme:C("accent"))
    else
      cur:SetText(keyText())
      cur:SetTextColor(Theme:C(on and "text" or "faint"))
      ns.SetEdge(btn, Theme:C("stroke"))
    end
    nameFS:SetTextColor(Theme:C(on and "text" or "faint"))
    ns.SetBg(btn, Theme:C("panel"))
  end

  local function stop()
    if not capturing then return end
    capturing = false
    stopListen()
    paint()
  end

  local function save()
    SaveBindings((GetCurrentBindingSet and GetCurrentBindingSet()) or 1)
  end

  local function onKey(key)
    if not capturing then stopListen() return end
    if key == "ESCAPE" or key == "CANCEL" then stop() return end
    if KEY_MODS[key] then return end
    stop()
    if InCombatLockdown() then return end
    local combo = (IsControlKeyDown() and "CTRL-" or "")
               .. (IsAltKeyDown() and "ALT-" or "")
               .. (IsShiftKeyDown() and "SHIFT-" or "")
               .. key
    local k1, k2 = GetBindingKey(spec.binding)
    if k1 then SetBinding(k1) end
    if k2 then SetBinding(k2) end
    if SetBinding(combo, spec.binding) then save() end
    paint()
  end

  row.Refresh = function()
    nameFS:SetText(T(spec.name))
    paint()
  end

  btn:SetScript("OnEnter", function(s)
    if capturing then return end
    ns.SetBg(s, Theme:C("panelHi"))
    ns.SetEdge(s, Theme:C("accent"))
  end)
  btn:SetScript("OnLeave", function(s)
    if capturing then return end
    paint()
  end)

  btn:SetScript("OnClick", function(_, button)
    if spec.disabled and spec.disabled() then return end
    if capturing then stop() return end
    if button == "RightButton" then
      if InCombatLockdown() then return end
      local k1, k2 = GetBindingKey and GetBindingKey(spec.binding)
      if k1 then SetBinding(k1) end
      if k2 then SetBinding(k2) end
      if k1 or k2 then save() end
      paint()
      return
    end
    if InCombatLockdown() then return end
    capturing = true
    startListen(onKey)
    paint()
  end)

  btn:SetScript("OnHide", stop)
  row:SetScript("OnHide", stop)
  tip(row, spec.desc)
  tip(btn, "Right-click to unbind")
  paint()
  return row
end

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
  box:SetScript("OnEscapePressed", function(s) s:ClearFocus(); row.Refresh() end)
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
  s:SetMinMaxValues(spec.min, spec.max)
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

  local function snap(v)
    local step = spec.step or 1
    local n = math.floor((v - spec.min) / step + 0.5)
    local out = spec.min + n * step
    if out > spec.max then out = spec.max elseif out < spec.min then out = spec.min end
    return out
  end

  local function label(v)
    if spec.format then return spec.format(v) end
    if (spec.step or 1) < 1 then return string.format("%.2f", v) end
    return tostring(v)
  end

  local function paint(v)
    val:SetText(label(v))
    local span = spec.max - spec.min
    local w = s:GetWidth() or 0
    fill:SetWidth(span > 0 and math.max(0.001, w * (v - spec.min) / span) or 0.001)
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
    s:EnableMouse(on)
    fs:SetText(T(spec.name))
    fs:SetTextColor(Theme:C(on and "text" or "faint"))
    val:SetTextColor(Theme:C(on and "accentInk" or "faint"))
    if on then thumb:SetVertexColor(Theme:Thumb())
    else thumb:SetVertexColor(Theme:C("faint")) end
    fill:SetVertexColor(Theme:C(on and "accent" or "strokeSoft"))
    s.quiet = true
    s:SetValue(spec.get())
    s.quiet = nil
    paint(spec.get())
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
    if nameFS then nameFS:SetText(T(spec.name)) end
    cur:SetText(T(spec.label(spec.get())) or "")
    cur:SetTextColor(Theme:C(off and "faint" or "text"))
    ns.SetBg(btn, Theme:C("panel"))
    ns.SetEdge(btn, Theme:C(off and "strokeSoft" or "stroke"))
    arrowColor(off and "faint" or "dim")
    btn:SetEnabled(not off)
  end
  btn.wpeDrop = { spec = spec, onPick = row.Refresh }
  row.Refresh()

  btn:SetScript("OnEnter", function(s)
    local open = dropdown and dropdown:IsShown() and dropdown.owner == s
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
    if button == "RightButton" then
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
    if s.warband then return end
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
    if s.warband then
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
    if #list == 0 and not wbSaved then row.delMode = nil end
    local path = ns.Fonts:Current()
    local colW = math.floor((CONTENT_W - (CHAR_COLS - 1) * 8) / CHAR_COLS)
    del.Text:SetFont(path, math.max(7, BASE_FONT - 1), ns.OutlineFlags())
    del:SetWidth(math.max(104, math.ceil(del.Text:GetStringWidth()) + 26))
    del:SetShown(#list > 0 or wbSaved)
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
      c.key, c.warband = e.key, nil
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
    if wbSaved then
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
      ci = ci + 1
      local c = charCell(row, ci)
      c.key, c.warband = nil, true
      c:SetWidth(colW)
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", 0, -y)
      c.wpeClassColor = nil
      c.Text:SetText(L["Warband bank"])
      c.Text:SetFont(path, math.max(7, BASE_FONT - 2), ns.OutlineFlags())
      c:Paint()
      c:Show()
      y = y + CHAR_CELL_H
    end
    for i = hi + 1, #row.heads do row.heads[i]:Hide() end
    for i = ci + 1, #row.cells do row.cells[i]:Hide() end
    if #list > 0 or wbSaved then
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

local BL_ROW_H = 22

local function blackRow(row, i)
  local c = row.items[i]
  if c then return c end
  c = CreateFrame("Frame", nil, row)
  c:SetHeight(BL_ROW_H)
  local ic = c:CreateTexture(nil, "ARTWORK")
  ic:SetSize(16, 16)
  ic:SetPoint("LEFT", 1, 0)
  c.icon = ic
  local x = ns.CreateGlyphButton(c, "×", 18)
  x:SetPoint("RIGHT", -1, 0)
  x:SetScript("OnClick", function()
    if c.id and ns.Vendor and ns.Vendor:Blocked(c.id) then ns.Vendor:Toggle(c.id) end
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

function factories.blacklist(parent, spec)
  local row = CreateFrame("Frame", nil, parent)
  row.items = {}
  row.dynamic = true
  local empty = track(Theme:Label(row, BASE_FONT - 2, "faint"), -2)
  empty:SetFont(dropdownFont(), BASE_FONT - 2, ns.OutlineFlags())
  empty:SetPoint("TOPLEFT")
  empty:SetWidth(CONTENT_W)
  empty:SetJustifyH("LEFT")
  empty:SetText(L["Alt-click an item in your bags while this tab is open."])
  ns.LocalText(empty, "Alt-click an item in your bags while this tab is open.")
  row.empty = empty
  row.Rebuild = function()
    local list = ns.Vendor and ns.Vendor:BlackList() or {}
    local y = 0
    row.empty:SetShown(#list == 0)
    if #list == 0 then
      y = math.ceil(row.empty:GetStringHeight()) + 4
    else
      for i, e in ipairs(list) do
        local c = blackRow(row, i)
        c.id = e.id
        c.Text:SetText(e.name or tostring(e.id))
        local tex = (select(10, C_Item.GetItemInfo(e.id)))
        c.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", 0, -y)
        c:SetPoint("TOPRIGHT", 0, -y)
        c:Show()
        y = y + BL_ROW_H + 2
      end
    end
    for i = #list + 1, #row.items do row.items[i]:Hide() end
    row:SetHeight(math.max(BL_ROW_H, y))
  end
  row.Refresh = row.Rebuild
  row.Rebuild()
  Options.blackRow = row
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
  mark:SetFrameLevel(cell:GetFrameLevel() + 1)
  mark:Hide()

  local readout = track(Theme:Label(row, BASE_FONT - 1, "accentInk"), -1)
  readout:SetJustifyH("LEFT")

  local hint = track(Theme:Label(row, BASE_FONT - 3, "dim"), -3)
  hint:SetJustifyH("LEFT")

  local art, chips = {}, {}
  for _, d in ipairs(ns.BADGES) do
    if d.tex then
      local t = cell:CreateTexture(nil, "OVERLAY")
      ns.BadgeArt(t, d.key)
      art[d.key] = t
    else
      art[d.key] = Theme:Label(cell, BASE_FONT, "overlay")
    end
  end

  local function factor() return PREV / bg.cell() end

  local function measure(key)
    local d = ns.BADGE[key] or ns.BADGES[1]
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
    c.Text:SetTextColor(Theme:C((not on) and "faint" or (sel and "accentInk" or "text")))
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
      o:SetDrawLayer("OVERLAY", sel and 7 or 5)
      o:ClearAllPoints()
      o:SetPoint(ns.BadgePoint(g), cell, g.c, (g.x or 0) * f, (g.y or 0) * f)
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
      if button == "RightButton" then
        if g.on then g.on = false; bg.bump() end
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
    for _, d in ipairs(ns.BADGES) do
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
    if moved then bg.bump() end
    row:SetHeight(h + PREV + 18 + hh)
  end
  row.Rebuild = row.Refresh
  bg.repaint = paint
  row.Refresh()
  tip(cell, spec.desc)
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
  sf:SetScript("OnMouseWheel", function(s, d) scrollTo(s:GetVerticalScroll() - d * 34) end)
  sf:SetScript("OnSizeChanged", paintBar)

  thumb:EnableMouse(true)
  thumb:SetScript("OnMouseDown", function(s)
    s.grabY = select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
    s.grabScroll = sf:GetVerticalScroll()
    s:SetScript("OnUpdate", function(t)
      local y = select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
      local view = sf:GetHeight()
      local travel = view - t:GetHeight()
      if travel <= 0 then return end
      scrollTo(t.grabScroll + (t.grabY - y) * range() / travel)
    end)
    thumbTex:SetVertexColor(Theme:C("accent"))
  end)
  thumb:SetScript("OnMouseUp", function(s)
    s:SetScript("OnUpdate", nil)
    thumbTex:SetVertexColor(Theme:C("faint"))
  end)
  thumb:SetScript("OnEnter", function() thumbTex:SetVertexColor(Theme:C("dim")) end)
  thumb:SetScript("OnLeave", function(s)
    if not s:GetScript("OnUpdate") then thumbTex:SetVertexColor(Theme:C("faint")) end
  end)
  return sf
end

local colsGet, colsSet       = field("cols")
local sizeGet, bagSizeSet    = field("iconSize")
-- A window's cell is what its badges are sized against, so a window that lands on a new one
-- has to reach them and not just its own grid. The bump comes first: the restyle that follows
-- is the pass that dresses them, and it reads the counter on its way through.
local function sizeSet(v) ns.BumpCellSize(); bagSizeSet(v) end
local gapGet, gapSet         = field("gap")
local styleGet, styleSet     = styleField("slotStyle")
local fontGet, fontSet       = styleField("font")
local zoomGet, zoomSet       = styleField("iconZoom")
local edgeGet, edgeSet       = styleField("borderWidth")
local mergeGet, mergeSet     = field("mergeReagents")
local flow = {}
flow.topGet, flow.topSet = field("reagentTop")
flow.hideGet, flow.hideSet = field("hideReagents")
flow.offGet = function() return mergeGet() or flow.hideGet() end
flow.revGet, flow.revSet = field("revFill")
flow.upGet, flow.upSet   = field("fillUp")
-- The view is a string on disk, the row a toggle, so the pair maps bool to "grid"/"cat".
flow.catGet = function() return Bags.bagView == "cat" end
-- The inverse gate: rows that only make sense in the grouped view hide themselves in the grid with
-- hidden = flow.gridGet, the mirror of the reagent rows that hide in cat-view with hidden = catGet.
flow.gridGet = function() return Bags.bagView ~= "cat" end
-- The bank's own grouped-view flag, independent of the bags: a player may want sections in one and
-- the plain grid in the other. Stored on WarpeeDB.bankView and read by the bank when it lays out.
flow.bankCatGet = function() return WarpeeDB and WarpeeDB.bankView == "cat" end
-- Fill-upwards and reverse-order are grid settings the bank grid reads too (Bank.lua reads Bags.fillUp
-- and Bags.revFill), so they must stay reachable while any window is still a grid. Hidden only when
-- both the bags and the bank are grouped, i.e. no grid is left anywhere to arrange. The reagent rows
-- above hide on catGet alone because the reagent bag is a bags-only thing the bank never draws.
flow.gridGone = function() return flow.catGet() and flow.bankCatGet() end
-- Category spacing (WarpeeDB.catGapX / catGapY) drives the grouped view of both surfaces, so it is
-- reachable whenever either the bags or the bank is grouped, and hidden only when neither is.
flow.noCat = function() return not (flow.catGet() or flow.bankCatGet()) end
flow.bankCatSet = function(v)
  WarpeeDB.bankView = v and "cat" or "grid"
  if ns.Bank and ns.Bank.Refresh then ns.Bank:Refresh() end
  -- Category spacing and the grid-order rows are gated on the bank view as well as the bags', so the
  -- page has to reflow at this switch too, the same as the bags toggle does. Without it the spacing
  -- slider stays hidden when the bank alone turns grouped, and lingers when the bank alone leaves.
  if Options.ReflowPages then Options:ReflowPages() end
end
flow.catSet = function(v)
  local mode = v and "cat" or "grid"
  Bags.bagView = mode
  WarpeeDB.bagView = mode
  relayout()
  -- The reagent rows are gated on the view, so reflow the page to add or drop them at the switch.
  if Options.ReflowPages then Options:ReflowPages() end
end

-- One editable row per category: a checkbox, the reorder carets, a name and a search field, the
-- live count, and a delete. The list is dynamic so the page rebuilds it on every relayout; the
-- pool of rows is reused and rebound to a list index each pass, exactly like the character grid.
function factories.catlist(parent, spec)
  local Cats = ns.Categories
  local CAT_ROW_H = 26
  local row = CreateFrame("Frame", nil, parent)
  row.items = {}
  -- The one panel pool, keyed by row index: each row's rule + pins panel lives here.
  row.build = {}
  -- Which categories have their pin panel forced open, keyed by category id. A category with pins
  -- shows the panel anyway; this is what opens it for one with none yet, so the id box is reachable
  -- without first dragging an item in. Session state, not saved: it is only which panels are unfolded.
  row.openPins = {}
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
      if c.searchBox:HasFocus() then c.searchBox:ClearFocus() end
    end
  end

  -- Forward-declared: act() reveals what a mutator made, and the reveal reads the offsets the rebuild
  -- lays down, so it is defined with the list body further down this factory.
  local reveal, flashSeq

  -- What the share line says back. A code cannot answer in the field it was typed into, so the result of
  -- reading one — how much was written, or why nothing was — goes to the chat frame, the way the profile
  -- panel's own messages do.
  local function say(msg)
    print("|cffd9a85fWarpee|r |cffffffff" .. tostring(msg) .. "|r")
  end

  -- The structural actions do not debounce: one click, one immediate rebuild and relayout. Blur
  -- first so a field mid-edit commits and drops focus before the pool is rebound underneath it.
  -- A mutator hands back the index of the row it created, and that row is then scrolled into view and
  -- flashed. A row added at the bottom of a long list is invisible from the top of it, and that is why
  -- pressing these buttons used to feel like nothing had happened at all.
  local function act(fn)
    blur()
    cancelPending()
    closeDropdown()
    local at = fn()
    Options:ReflowPages()
    relayout()
    if type(at) == "number" then reveal(at) end
  end


  local function makeBox(c, hint, maxLen)
    local box = CreateFrame("EditBox", nil, c, "BackdropTemplate")
    ns.SnapBox(box, 60, 22, true)
    ns.PixelBackdrop(box)
    ns.SetBg(box, Theme:C("bg"))
    ns.SetEdge(box, Theme:C("stroke"))
    Theme:Track(box, function(s)
      ns.SetBg(s, Theme:C("bg"))
      s:SetTextColor(Theme:C("text"))
      if not s:HasFocus() then ns.SetEdge(s, Theme:C("stroke")) end
    end)
    box:SetFont(dropdownFont(), BASE_FONT - 1, ns.OutlineFlags())
    box:SetTextColor(Theme:C("text"))
    box:SetTextInsets(6, 6, 0, 0)
    box:SetAutoFocus(false)
    box:SetMaxLetters(maxLen)
    local ph = Theme:Label(box, BASE_FONT - 2, "faint")
    ph:SetPoint("LEFT", 6, 0)
    -- Registered with the locale watcher rather than set once, so the background name (the "Categories
    -- code" caption) follows a language change live instead of keeping the old language until a reload.
    ns.LocalText(ph, hint)
    box.ph = ph
    box:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    box:SetScript("OnEditFocusGained", function(s) ns.SetEdge(s, Theme:C("accent")) end)
    return box
  end

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

  -- One pinned item: the art alone. A pin is a picture of something the player filed by hand, and a strip
  -- read by eye — a row of icons puts twice the pins where a row of named chips put them, and the name is
  -- in the tooltip, which is where a name is read anyway. The hover is the whole target: the art dims, the
  -- × stands over it, and a click anywhere on the icon takes the pin out. One frame, so nothing has to be
  -- summoned before it can be hit — a target that appears under the cursor is a target a fast click misses.
  -- The unpin only edits a saved table and relayouts, no protected call, so it is taint free like the drag
  -- that made the pin.
  local function makeChip(panel, k)
    local b = panel.chips[k]
    if b then return b end
    b = CreateFrame("Button", nil, panel, "BackdropTemplate")
    ns.SnapBox(b, CHIP, CHIP)
    ns.PixelBackdrop(b)
    ns.SetBg(b, Theme:C("bg"))
    ns.SetEdge(b, Theme:C("stroke"))
    local ic = b:CreateTexture(nil, "ARTWORK")
    ic:SetPoint("LEFT", ICON_PAD, 0)
    ns.SnapSize(ic, ICON, ICON)
    ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.ic = ic
    local x = Theme:Label(b, BASE_FONT, "accent")
    x:SetPoint("CENTER")
    x:SetText("\195\151") -- ×
    x:Hide()
    b.x = x
    b:SetScript("OnEnter", function(s)
      ns.SetEdge(s, Theme:C("accent"))
      s.ic:SetAlpha(0.12)
      s.x:Show()
      if s.wpeId then
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(s.wpeId)
        GameTooltip:AddLine(ns.L["Click the × to remove"], 0.6, 0.6, 0.6)
        GameTooltip:Show()
      end
    end)
    b:SetScript("OnLeave", function(s)
      ns.SetEdge(s, Theme:C("stroke"))
      s.ic:SetAlpha(1)
      s.x:Hide()
      GameTooltip:Hide()
    end)
    b:SetScript("OnClick", function(s)
      GameTooltip:Hide()
      if s.wpeId then act(function() Cats:PinItem(s.wpeId, nil) end) end
    end)
    panel.chips[k] = b
    return b
  end

  -- The empty rack: what a category with no pins shows in place of its strip. Faint slots of the chip
  -- size say both that things go here and how they sit, and they keep the panel's height steady for
  -- the first pin that arrives.
  local GHOSTS = 4

  local function makeGhost(panel, k)
    local g = panel.ghosts[k]
    if g then return g end
    g = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    ns.SnapBox(g, CHIP, CHIP)
    ns.PixelBackdrop(g)
    local function paint(f)
      local br, bg2, bb = Theme:C("bg")
      ns.SetBg(f, br, bg2, bb, 0.35)
      local er, eg, eb = Theme:C("emptyLine")
      ns.SetEdge(f, er, eg, eb, 0.35)
    end
    paint(g)
    Theme:Track(g, paint)
    panel.ghosts[k] = g
    return g
  end

  -- The per-category sort control that sits on the panel's header line: a small dropdown that overrides
  -- the global "Sort within a section" for this one category. It stores nothing secure — only the draw
  -- order on the saved row — so the pick relayouts the bags and repaints its own label, no page rebuild
  -- and no taint. The panel's wpeId is the category id, set fresh each layout, and the spec reads it live
  -- so the pooled control always speaks for the row it is seated under.
  --
  -- It is drawn as a quiet pair of words, not as a filled button: sort belongs to the row above, not to
  -- the pins, and a 150-pixel plate on this line weighed the same as the whole strip of pinned items
  -- under it. Read from the right, one label and the value it holds, and hover is where it lights up.
  local function makeSortBtn(panel)
    local btn = CreateFrame("Button", nil, panel)
    ns.SnapBox(btn, 150, 22, true)
    local cur = Theme:Label(btn, BASE_FONT - 2, "text")
    cur:SetPoint("RIGHT", -13, 0)
    cur:SetJustifyH("RIGHT")
    local cap = Theme:Label(btn, BASE_FONT - 2, "faint")
    cap:SetPoint("RIGHT", cur, "LEFT", -6, 0)
    cap:SetJustifyH("RIGHT")
    ns.LocalText(cap, "Sort")
    local arrow = ns.ArrowGlyph(btn, "down", 9)
    arrow:SetPoint("RIGHT", -2, 0)
    btn.cap, btn.cur = cap, cur
    local spec = {
      keys = function() return CAT_SORT_KEYS end,
      get = function() return Cats:SortOf(panel.wpeId) end,
      set = function(v)
        if not panel.wpeId then return end
        Cats:SetSortById(panel.wpeId, v)
        relayout()
      end,
      label = function(k) return ns.L[SORT_LABELS[k] or k] end,
      desc = "The order this one section takes, overriding the sort above it. Default follows that sort. By rule draws items in the order a search's | parts are written; By expansion groups by expansion, newest first.",
    }
    local function refresh()
      cur:SetText(T(SORT_LABELS[spec.get()] or "Default"))
      arrow:SetTint("dim")
      -- The width follows the words: the caption, the value and the chevron are measured off the labels
      -- themselves, so a longer translation or a longer sort name is not clipped by a fixed 150.
      btn:SetWidth(13 + 9 + 4 + (cur:GetStringWidth() or 0) + 6 + (cap:GetStringWidth() or 0))
    end
    btn.wpeDrop = { spec = spec, onPick = refresh }
    btn:SetScript("OnClick", function(s) openDropdown(s, spec, refresh) end)
    btn:SetScript("OnEnter", function(s)
      arrow:SetTint("accent")
      cur:SetTextColor(Theme:C("accent"))
      if spec.desc then ns.ShowTip(s, { { text = spec.desc } }, "top") end
    end)
    btn:SetScript("OnLeave", function(s)
      arrow:SetTint("dim")
      cur:SetTextColor(Theme:C("text"))
      ns.HideTip()
    end)
    btn.Refresh = refresh
    return btn
  end

  -- The panel that drops under an open row: the items pinned to this category by hand, as a strip of
  -- chips, and a box to pin one more by shift-click or id. The rule itself is not edited here — it is
  -- the row's own search field, and whole categories are added from the preset strip at the top — so
  -- this panel is only the manual-pin overflow that does not fit on the one-line row, plus the
  -- per-category sort override on its header line.
  --
  -- It is drawn as the row's own inside rather than as a second row: a hairline closes the row off, a
  -- short accent spine under the grip ties the two together, and the whole thing is one column of the
  -- list's own padding, so nothing about it reads as a new level of the page.
  local function buildPanel(i)
    local p = row.build[i]
    if p then return p end
    p = CreateFrame("Frame", nil, row)
    p.chips, p.ghosts = {}, {}

    -- The two hairlines make one bracket: the spine runs down the panel's full height under the grip and
    -- the line across the top starts to its right, so the pair reads as the row's own inside. The line
    -- used to start at the left edge, which put a cross over the spine and read as a divider being cut
    -- through. SPINE_X is the grip column; the gap keeps the corner from closing into a blob.
    local top = Theme:Rect(p, "stroke", "BACKGROUND")
    ns.SnapPoint(top, "TOPLEFT", p, "TOPLEFT", SPINE_X + 8, 0)
    top:SetPoint("TOPRIGHT", p, "TOPRIGHT")
    top:SetHeight(ns.PX(p))
    p.top = top
    local spine = Theme:Rect(p, "accent", "BACKGROUND")
    spine:SetPoint("TOPLEFT", SPINE_X, 0)
    spine:SetPoint("BOTTOMLEFT", SPINE_X, 0)
    spine:SetWidth(ns.PX(p, 2))
    p.spine = spine

    local hcap = Theme:Label(p, BASE_FONT - 2, "faint")
    -- Localized through the watcher, not a bare SetText: this label is built once per pooled panel and
    -- never re-set, so a bare set would freeze it in the language it was made in until a reload, the same
    -- trap the preset caption had.
    ns.LocalText(hcap, "Pinned")
    p.hcap = hcap

    -- The count rides the caption, and it is the honest one: a category holding four pins says so before
    -- you look at the strip, which is what the old panel left you to work out from the icons.
    local hcount = Theme:Label(p, BASE_FONT - 2, "dim")
    p.hcount = hcount

    p.sortBtn = makeSortBtn(p)

    -- The box takes a shift-clicked item as before; its focus handler is the one RegisterLinkBox
    -- installed, wrapped rather than replaced so the drop still runs.
    local pbox = makeBox(p, "Shift-click item or ID", 200)
    pbox:SetWidth(150)
    ns.RegisterLinkBox(pbox, true)
    local prevFocus = pbox:GetScript("OnEditFocusLost")
    local function commit(s)
      local text = s:GetText()
      s:SetText("")
      s:ClearFocus()
      local id = tonumber(text)
      if not id and text ~= "" then id = C_Item.GetItemInfoInstant(text) end
      if id and id > 0 and p.wpeId then act(function() Cats:PinItem(id, p.wpeId) end) end
    end
    pbox:SetScript("OnEnterPressed", commit)
    -- The plus is the slot's mark, not a prefix on the text, and both it and the hint stand only while
    -- the box is empty and the cursor is not in it: a click into the field leaves nothing between the
    -- caret and what is typed — an id read by hand must not be read through "+ Shift-click item or ID" —
    -- and an empty field that loses focus gets its hint back. One question asked in one place, so the
    -- two can never disagree, whether the text was typed, pasted or handed over by a shift-clicked link.
    local function slotMark(s, inField)
      local show = s:GetText() == "" and not inField
      s.ph:SetShown(show)
      if s.plus then s.plus:SetShown(show) end
      return show
    end
    pbox:SetScript("OnTextChanged", function(s)
      slotMark(s, s:HasFocus())
      if s:GetText():find("^item:") then commit(s) end
    end)
    local prevGain = pbox:GetScript("OnEditFocusGained")
    pbox:SetScript("OnEditFocusGained", function(s)
      if prevGain then prevGain(s) end
      slotMark(s, true)
    end)
    pbox:SetScript("OnEditFocusLost", function(s)
      if prevFocus then prevFocus(s) end
      -- The focus is already gone by the time this runs, so the question is not put to the client.
      slotMark(s, false)
    end)
    -- The field reads as the rack's next slot: a plus where the item would sit, the placeholder pushed
    -- past it, and the same height as a chip, so the box says "pin something here" before the words are
    -- read. Its width follows its own hint for the same reason the editor's buttons do: a translation
    -- longer than the English one must not run out of the box it is written in.
    local plus = Theme:Label(pbox, BASE_FONT, "faint")
    plus:SetPoint("LEFT", 7, 0)
    plus:SetText("+")
    pbox.ph:ClearAllPoints()
    pbox.ph:SetPoint("LEFT", 18, 0)
    pbox:SetTextInsets(18, 6, 0, 0)
    pbox:SetHeight(CHIP)
    pbox:SetWidth(math.max(150, math.ceil(pbox.ph:GetStringWidth() or 0) + 34))
    pbox.plus = plus
    slotMark(pbox, false)
    p.pinBox = pbox

    row.build[i] = p
    return p
  end

  -- Seat one row's pin panel under it and return the height it took, so Rebuild advances by exactly
  -- it: a caption with the count, the pinned items as a wrapping strip of chips, and the field that
  -- adds one more below them. Everything pooled on the panel, nothing created per pass.
  local function layoutBuild(p, ids, width)
    local y, pad = 9, 24
    p.hcap:ClearAllPoints()
    p.hcap:SetPoint("TOPLEFT", pad, -y)
    p.hcap:Show()
    p.hcount:ClearAllPoints()
    ns.SnapPoint(p.hcount, "LEFT", p.hcap, "RIGHT", 5, 0)
    p.hcount:SetText("· " .. #ids)
    p.hcount:Show()
    -- The sort override rides the same header line, right-aligned and reading as words: the chevron at
    -- the far right, then the value it holds, then what that value is. It is pooled on the panel and
    -- rebound to this row's id each pass, so its live spec always speaks for the section it is under.
    p.sortBtn:ClearAllPoints()
    p.sortBtn:SetPoint("TOPRIGHT", -pad, -y)
    p.sortBtn:Show()
    p.sortBtn:Refresh()
    y = y + BASE_FONT + 6
    -- The strip. A chip asks for as much width as its name wants and takes the icon alone when even a
    -- short name has nowhere to go on this line, so a line never carries half a word and the strip
    -- never pushes a chip past the panel's right edge.
    local usable = width - pad * 2
    local x, line, lastChip = 0, 0, 0
    for k = 1, #ids do
      local chip = makeChip(p, k)
      chip.wpeId = ids[k]
      chip.ic:SetTexture(ns.PinIcon(ids[k]))
      if x > 0 and usable - x < CHIP then x = 0; line = line + 1 end
      chip:ClearAllPoints()
      chip:SetPoint("TOPLEFT", pad + x, -(y + line * (CHIP + CHIP_GAP)))
      chip:Show()
      x = x + CHIP + CHIP_GAP
      lastChip = k
    end
    for k = lastChip + 1, #p.chips do if p.chips[k] then p.chips[k]:Hide() end end
    local lines = 0
    if lastChip > 0 then
      lines = line + 1
      -- The rack is cleared for a category that has pins: a category that just gained its first one keeps
      -- no faint slot behind it.
      for k = 1, #p.ghosts do if p.ghosts[k] then p.ghosts[k]:Hide() end end
    elseif #ids == 0 then
      -- A category with nothing pinned shows the empty rack instead of a blank line: the same slots the
      -- chips will occupy, faint, so the first pin has somewhere to land and the panel keeps its height.
      for k = 1, GHOSTS do
        local g = makeGhost(p, k)
        g:ClearAllPoints()
        g:SetPoint("TOPLEFT", pad + (k - 1) * (CHIP + CHIP_GAP), -y)
        g:Show()
      end
      lines = 1
    end
    if lines > 0 then y = y + lines * CHIP + (lines - 1) * CHIP_GAP + 7 end
    p.pinBox:ClearAllPoints()
    p.pinBox:SetPoint("TOPLEFT", pad, -y)
    p.pinBox.ph:SetShown(p.pinBox:GetText() == "")
    return y + CHIP + 8
  end

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
    if slot then
      act(function() Cats:Reorder(from, slot) end)
    else
      Options:ReflowPages()
    end
  end

  -- The axis names the readout prints, as keys so a language change reaches them with the rest of the
  -- window. "text" is the one that matters: it is what a token no dictionary answers to is filed under.
  local AXIS_LABEL = {
    kind = "Kind", slot = "Slot", quality = "Quality", level = "Level",
    expansion = "Expansion", item = "Item", flag = "Flag", text = "In the name",
  }

  -- What an empty field shows while it is being written in: six rules that between them use every part of
  -- the language — a quality word, a negation, a level test, an OR of two kinds, an account-bound flag and
  -- the word for the expansions before this one. The words belong to the parser, so they read the same in
  -- every language; only the label in front of them is translated.
  local EXAMPLES = "junk \194\183 !junk \194\183 ilvl>180 \194\183 toy | mount \194\183 boa \194\183 legacy"

  -- One rule as one line of chips. "weapon shield !junk | id6948" reads back as "slot: weapon · in the
  -- name: shield · not quality: junk | item: id6948": the parts of one side are joined by a raised dot
  -- because every one of them has to hold, and the sides of a "|" by the bar itself, the character the
  -- player wrote for exactly that. nil when there is nothing to explain.
  local function explainRule(search)
    if not ns.ExplainSearch then return nil end
    local sides = ns.ExplainSearch(search)
    if not sides then return nil end
    local out = {}
    for _, side in ipairs(sides) do
      local chips = {}
      for _, p in ipairs(side) do
        local part = (p.neg and (T("Not") .. " ") or "") .. T(AXIS_LABEL[p.axis] or p.axis or "?")
                     .. ": " .. p.token
        -- A token no word answers to is the one part that can be wrong and still look right, so it names
        -- the words it might have meant: the vocabulary is one edit or one keystroke away from what was
        -- written, and nothing else in the line distinguishes a typo from a rule that simply catches nothing.
        if p.near then
          part = part .. " (" .. T("did you mean") .. " " .. table.concat(p.near, ", ") .. ")"
        end
        chips[#chips + 1] = part
      end
      out[#out + 1] = table.concat(chips, " \194\183 ")
    end
    return table.concat(out, " | ")
  end

  local function catRow(i)
    local c = row.items[i]
    if c then return c end
    c = CreateFrame("Frame", nil, row)
    c:SetHeight(CAT_ROW_H)

    local box = ns.CreateCheckBox(c, 16)
    -- Top-anchored, not centered: a focused row grows downward to hold the readout, and a centered
    -- control band would sink half that growth, dragging the readout down until its wrapped second
    -- line spills onto the row below. The -5 reproduces the single-line centering ((26-16)/2), so a
    -- one-line row is unchanged; the whole name/grip/search chain roots here and stays put with it.
    ns.SnapPoint(box, "TOPLEFT", c, "TOPLEFT", 1, -5)
    -- The checkbox art is mouse transparent, so a button carries the click. It needs a real rect
    -- and a raised level of its own: sharing the row frame's level, a pooled sibling would not
    -- reliably take the click. Full row height makes an easy target either side of the 16px box.
    local hit = CreateFrame("Button", nil, c)
    hit:SetSize(16, CAT_ROW_H)
    ns.SnapPoint(hit, "TOPLEFT", c, "TOPLEFT", 1, 0)
    hit:SetFrameLevel(c:GetFrameLevel() + 5)
    hit:RegisterForClicks("LeftButtonUp")
    hit:SetScript("OnEnter", function() box:SetKeys(nil, "accent", nil) end)
    hit:SetScript("OnLeave", function() box:SetKeys(nil, "stroke", nil) end)
    hit:SetScript("OnClick", function() act(function() Cats:Toggle(c.idx) end) end)
    c.chk = box
    -- Kept on the row so the rebuild can hide the click target with the box: it sits over the box's
    -- own rect, and a marker row has no enable state to flip.
    c.chkHit = hit

    -- A grip in the old caret slot, dragged to reorder the row. It reads as a handle on sight, where
    -- the two carets read as step-one-place buttons and hid the drag; the drag lives on the grip alone
    -- now, so there is one gesture and no click/drag ambiguity. Same footprint, so the layout is unmoved.
    local grip = makeGrip(c)
    ns.SnapPoint(grip, "LEFT", box, "RIGHT", 4, 0)
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart", function() startDrag(c.idx) end)
    grip:SetScript("OnDragStop", stopDrag)
    c.grip = grip

    local del = ns.CreateGlyphButton(c, "\195\151", 18)
    -- Top-anchored like the checkbox so the control band holds its place when a focused row grows
    -- downward for the readout; -4 is the single-line centering ((26-18)/2). addPin and count chain
    -- off del, so pinning del pins the whole right cluster too.
    ns.SnapPoint(del, "TOPRIGHT", c, "TOPRIGHT", -1, -4)
    del:SetScript("OnClick", function()
      act(function()
        if c.entry then Cats:RemoveMarker(c.entry) else Cats:Remove(c.idx) end
      end)
    end)
    c.del = del

    -- The pin toggle: a "+" that opens the pin panel under this row so an item id can be typed in
    -- without first dragging a piece onto the section. A row that already holds pins shows the panel
    -- regardless; this only forces it for a pinless one. It lights accent while its panel is open.
    -- Toggling only flips a session flag and relayouts the editor, so it stays taint free.
    local addPin = ns.CreateGlyphButton(c, "+", 18)
    ns.SnapPoint(addPin, "RIGHT", del, "LEFT", -4, 0)
    -- The open state has to outlast the hover: CreateButton's OnLeave clears wpeHot, so the accent
    -- would drop the instant the cursor left the button. wpeOpen is the sticky flag the layout sets,
    -- and the wrapped Repaint lights the glyph when either the hover or the open state is on.
    local basePaint = addPin.Repaint
    addPin.Repaint = function(s)
      basePaint(s)
      if s.wpeOpen and s.Text then s.Text:SetTextColor(Theme:C("accent")) end
    end
    addPin:SetScript("OnClick", function()
      local id = c.catId
      if not id then return end
      -- Toggle from the panel's current shown state, not from the flag alone: a category that holds
      -- pins opens by default, so without this a click on its "+" could never close it (the pins kept
      -- it open regardless). The stored value is an explicit force now — true opens a pinless row,
      -- false collapses a pinned one — read back in Rebuild over the has-pins default.
      row.openPins[id] = not c.wpePanelOpen
      act(function() end)
    end)
    c.addPin = addPin

    -- The count widget survives only for the Other catch-all, where it shows how many items no rule
    -- caught. Real rows no longer show a per-item tally next to the "+", so it is hidden for them in
    -- Rebuild; the pool keeps one field regardless of which row borrows it this pass.
    local count = track(Theme:Label(c, BASE_FONT - 2, "dim"), -2)
    count:SetJustifyH("RIGHT")
    count:SetPoint("RIGHT", addPin, "LEFT", -6, 0)
    count:SetWidth(30)
    c.count = count

    local name = makeBox(c, "Name", 24)
    ns.SnapPoint(name, "LEFT", grip, "RIGHT", 8, 0)
    name:SetScript("OnEditFocusLost", function(s)
      ns.SetEdge(s, Theme:C("stroke")); s.ph:SetShown(s:GetText() == "")
      cancelPending(); commitName(c, s:GetText()); relayout()
    end)
    name:SetScript("OnTextChanged", function(s)
      s.ph:SetShown(s:GetText() == "")
      if not s:HasFocus() then return end
      debounce(function() commitName(c, s:GetText()); relayout() end)
    end)
    c.nameBox = name

    local search = makeBox(c, "Search", 60)
    search:SetScript("OnEditFocusLost", function(s)
      ns.SetEdge(s, Theme:C("stroke")); s.ph:SetShown(s:GetText() == "")
      cancelPending()
      Cats:SetSearch(c.idx, s:GetText())
      relayout()
      -- The rule is read back only under a field being written in, so the row gives up its readout here
      -- and the reflow is what puts the list back to one line per rule.
      Options:ReflowPages()
    end)
    search:SetScript("OnEditFocusGained", function(s)
      ns.SetEdge(s, Theme:C("accent"))
      -- The other half of the same idea: the row grows to hold the readout as the field takes focus. Not
      -- through act(), which blurs first — the cursor has to stay in the field the player clicked into.
      Options:ReflowPages()
    end)
    search:SetScript("OnTextChanged", function(s)
      s.ph:SetShown(s:GetText() == "")
      if not s:HasFocus() then return end
      debounce(function()
        Cats:SetSearch(c.idx, s:GetText())
        relayout()
        -- Straight to the reflow rather than waiting for one: the readout and its count are the answer
        -- to what was just typed, and they are worth nothing while the typing is still going on.
        Options:ReflowPages()
      end)
    end)
    c.searchBox = search

    -- The rule read back under the field it was written in: one chip per token, in the order the parser
    -- takes them, each naming the axis it was understood on. This is the manual the field never had — it
    -- is how "!junk" and "toy | mount" explain themselves while they are being typed — and a token no
    -- dictionary knows comes back as text, so the one silent failure, a rule that reads right and catches
    -- nothing, says so on the spot. Width and height are taken in the rebuild: it runs from the field to
    -- the row's right edge, and the row grows to hold it.
    local readout = track(Theme:Label(c, BASE_FONT - 4, "faint"), -4)
    readout:SetJustifyH("LEFT")
    readout:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -2)
    c.readout = readout

    row.items[i] = c
    return c
  end

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

  -- The preset strip: one button per shipped category (Armor, Potions, Mounts…). A click adds that
  -- whole category to the list — the thing a player actually wants, not a filter to assemble — and a
  -- preset already in the list dims and goes inert so the strip doubles as a picture of what is on.
  -- This is the primary way to build the list; the per-row search field is the advanced escape for
  -- anyone who wants to hand-write a rule. Buttons are pooled and re-labelled each Rebuild.
  row.presets = {}
  local presetCap = Theme:Label(row, BASE_FONT - 2, "faint")
  -- Localized through the watcher, not a bare SetText: a language change repaints every watched label
  -- and reflows the page, and this caption is the one preset-strip label that used to miss that pass and
  -- keep its old-language text until a reload. Its siblings (New group/divider/category) already do this.
  ns.LocalText(presetCap, "Add a category")
  row.presetCap = presetCap

  -- One caption per shipped band, made on first use and kept: a band whose presets are all in the list
  -- leaves no button behind and no caption either, so a shelf only ever names what stands under it.
  row.shelfCaps = {}
  local function shelfCap(key)
    local cap = row.shelfCaps[key]
    if not cap then
      cap = Theme:Label(row, BASE_FONT - 3, "faint")
      ns.LocalText(cap, key)
      row.shelfCaps[key] = cap
    end
    return cap
  end

  row.gadd = ns.CreateButton(row, ns.L["New group"], 120, 22)
  ns.LocalText(row.gadd, "New group")
  row.gadd:SetScript("OnClick", function() act(function() return Cats:AddGroup() end) end)
  tip(row.gadd, "Adds an empty group at the bottom, then drag it up to head the rows it should name")

  row.dadd = ns.CreateButton(row, ns.L["New divider"], 120, 22)
  ns.LocalText(row.dadd, "New divider")
  row.dadd:SetScript("OnClick", function() act(function() return Cats:AddDivider() end) end)
  tip(row.dadd, "Adds a divider at the bottom, then drag it up to seam the rows where you want")

  local function presetBtn(k, def)
    local b = row.presets[k]
    if not b then
      b = ns.CreateButton(row, "", 100, 22)
      row.presets[k] = b
    end
    b.Text:SetText(def.name)
    local inList = Cats:Has(def.id)
    ns.SetButtonEnabled(b, not inList)
    b:SetScript("OnClick", function()
      if Cats:Has(def.id) then return end
      act(function() return Cats:AddPreset(def.id) end)
    end)
    local wtext = math.ceil(b.Text:GetStringWidth()) + 20
    ns.SnapBox(b, math.max(64, wtext), 22)
    b:Show()
    return b
  end

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

  -- The share line, under the buttons that make rows: one code, both directions. A code carries this
  -- list and nothing else — no positions, no sizes, no theme — so it can be pasted to another player and
  -- mean the same thing there. The field below serves both ways, the way the profile panel's own field
  -- does: Export fills it, Import reads it. Import replaces the whole list, behind a confirm; the list you
  -- had is kept as the Before import profile, so the one destructive direction has a way back.
  local shareExp = ns.CreateButton(row, ns.L["Export"], 120, 22)
  ns.LocalText(shareExp, "Export")
  local shareImp = ns.CreateButton(row, ns.L["Import"], 120, 22)
  ns.LocalText(shareImp, "Import")
  tip(shareExp, "Fills the field below with a code for this list: copy it and paste it wherever it should be applied")
  tip(shareImp, "Reads the code in the field and asks before replacing your list; the list you had is kept as a profile, so it can be brought back")
  local share = {
    { btn = shareExp, key = "Export" },
    { btn = shareImp, key = "Import" },
  }

  -- A code is long, so the field is the full width of the column and the placeholder is the only thing
  -- naming it. The 60-character default of a row's own field would cut a real code in half and a half
  -- code is one nobody can copy, so this one takes whatever a paste hands it.
  local codeBox = makeBox(row, "Categories code", 8192)
  codeBox:SetScript("OnTextChanged", function(s) s.ph:SetShown(s:GetText() == "") end)
  codeBox:SetScript("OnEditFocusLost", function(s) s.ph:SetShown(s:GetText() == "") end)
  codeBox.ph:Show()
  row.shareCode = codeBox

  -- Empty means empty however it was typed: a field holding a few spaces is one the player means to fill.
  local function noCode(text)
    return type(text) ~= "string" or text:gsub("%s", "") == ""
  end

  shareExp:SetScript("OnClick", function()
    local text = ns.Profiles:ExportCategories()
    if text == "" then say(T("Nothing to export")) return end
    codeBox:SetText(text)
    codeBox:SetFocus()
    codeBox:HighlightText()
    say(T("Exported %s, press Ctrl and C to copy"):format(T("Categories")))
  end)
  shareImp:SetScript("OnClick", function()
    local text = codeBox:GetText()
    if noCode(text) then say(T("Nothing to import")) return end
    -- No confirm: a category import replaces the list, but the list you had is put aside as the
    -- "Before import" profile first (see ImportCategories), so the replace is one click to undo and a
    -- question in front of it only adds a step. A profile code pasted here is applied like the profile
    -- panel does; catImport reads the kind off the code either way.
    Options.catImport(text, "replace")
  end)

  -- The order items take inside every section: the list's own setting, so it lives on the list's header
  -- line instead of among the settings at the top of the tab, where it read as a property of the page and
  -- the thing it orders was a screen away. Words rather than a filled plate, exactly like the per-section
  -- override inside a row's + panel — one control at two scopes — and its label is read live on every
  -- reflow, so a language change reaches it.
  local SORT_SPEC = {
    keys = function() return GLOBAL_SORT_KEYS end,
    get = function() return WarpeeDB.catSort or "ilvl" end,
    set = function(v) WarpeeDB.catSort = v; relayout() end,
    label = function(k) return ns.L[SORT_LABELS[k] or k] end,
    desc = "The order items take inside every section, unless one sets its own from its + panel. Each falls back to name, so it never flickers. By rule follows a search written with |, drawing its parts in written order; By expansion groups by expansion, newest first.",
  }
  local sortRow = CreateFrame("Button", nil, row)
  ns.SnapBox(sortRow, nil, 22, true)
  local sortCap = Theme:Label(sortRow, BASE_FONT - 2, "faint")
  ns.LocalText(sortCap, "Sort within a section")
  sortCap:SetPoint("LEFT", 0, 0)
  local sortArrow = ns.ArrowGlyph(sortRow, "down", 9)
  sortArrow:SetPoint("RIGHT", -2, 0)
  local sortVal = Theme:Label(sortRow, BASE_FONT - 2, "text")
  sortVal:SetJustifyH("RIGHT")
  sortVal:SetPoint("RIGHT", sortArrow, "LEFT", -6, 0)
  local function refreshSort()
    sortVal:SetText(SORT_SPEC.label(SORT_SPEC.get()))
    sortArrow:SetTint("dim")
  end
  sortRow:SetScript("OnClick", function(s) openDropdown(s, SORT_SPEC, refreshSort) end)
  sortRow:SetScript("OnEnter", function()
    sortArrow:SetTint("accent")
    sortVal:SetTextColor(Theme:C("accent"))
  end)
  sortRow:SetScript("OnLeave", function()
    sortArrow:SetTint("dim")
    sortVal:SetTextColor(Theme:C("text"))
  end)
  tip(sortRow, SORT_SPEC.desc)

  row.Rebuild = function()
    local list = Cats:List()
    -- Only Other's coverage tally is shown now (per-row and per-group counts were dropped), so the
    -- first return, the per-row counts, is discarded.
    local _, other = Cats:Counts()
    local names = Cats:Names()
    -- The gutter holds the pin caret and the count; the search field gets the rest.
    local half = math.floor((CONTENT_W - 96) / 2)
    for _, p in pairs(row.build) do p:Hide() end
    local y = 0

    -- The preset strip at the top, in shelves: a caption line per shipped band, the ready-made categories
    -- of that band under it, wrapped to the page width. It leads the editor because adding a ready-made
    -- category is the common act; the list of your own categories follows below.
    --
    -- A preset already in the list is gone from the strip rather than dimmed. The list below is the record
    -- of what is in, so a button whose whole job is to say "you have me" spends a line of the page saying
    -- nothing — and the strip is the one block that grows as the player does less with it. Gone, it shrinks
    -- as the list grows and leaves the page entirely once the shipped set is complete, which is also what
    -- gives the editor back the top half of its screen. Reset is the way back to it.
    for _, b in pairs(row.presets) do b:Hide() end
    local presets = Cats:Presets()
    local shelves, shelvedAt = {}, {}
    for k, def in ipairs(presets) do
      local key = def.bandKey or ""
      local shelf = shelvedAt[key]
      if not shelf then
        shelf = { key = key, add = {} }
        shelvedAt[key] = shelf
        shelves[#shelves + 1] = shelf
      end
      if not Cats:Has(def.id) then shelf.add[#shelf.add + 1] = k end
    end
    local live = 0
    for _, shelf in ipairs(shelves) do if #shelf.add > 0 then live = live + 1 end end
    local usedCaps = {}
    if live > 0 then
      presetCap:ClearAllPoints()
      presetCap:SetPoint("TOPLEFT", 0, -y)
      presetCap:Show()
      y = y + BASE_FONT + 5
      for _, shelf in ipairs(shelves) do
        if #shelf.add > 0 then
          local cap = shelfCap(shelf.key)
          usedCaps[cap] = true
          cap:ClearAllPoints()
          cap:SetPoint("TOPLEFT", 0, -y)
          cap:Show()
          y = y + BASE_FONT + 1
          local px, prow = 0, 0
          for _, k in ipairs(shelf.add) do
            local b = presetBtn(k, presets[k])
            local w = b:GetWidth()
            if px > 0 and px + w > CONTENT_W then px = 0; prow = prow + 1 end
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", px, -(y + prow * 26))
            px = px + w + 6
          end
          y = y + (prow + 1) * 26 + 3
        end
      end
      y = y + 3
    else
      presetCap:Hide()
    end
    for _, cap in pairs(row.shelfCaps) do if not usedCaps[cap] then cap:Hide() end end
    for k = #presets + 1, #row.presets do if row.presets[k] then row.presets[k]:Hide() end end

    -- A faint divider seams the preset strip off from the list of categories below it. A texture, not
    -- a bare frame: PixelLine only sizes what it is given, and a frame has nothing to paint, so the
    -- line was invisible until it was drawn on a real texture like the group-header line above.
    local seam = row.seam
    if not seam then
      seam = Theme:Rect(row, "strokeSoft", "ARTWORK")
      ns.PixelLine(seam, 1)
      row.seam = seam
    end
    seam:ClearAllPoints()
    seam:SetPoint("TOPLEFT", 0, -y)
    seam:SetPoint("TOPRIGHT", 0, -y)
    seam:Show()
    y = y + 8

    -- The list's own header line: what orders the rows under it, directly above them.
    sortRow:ClearAllPoints()
    sortRow:SetPoint("TOPLEFT", 0, -y)
    sortRow:SetPoint("TOPRIGHT", 0, -y)
    sortRow:Show()
    refreshSort()
    y = y + 26

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
        -- checkbox (and the button that carries its click), the search field, the pin toggle and the
        -- count have nothing to say on it.
        r.chk:Hide()
        r.chkHit:Hide()
        r.grip:Show()
        r.del:Show()
        r.addPin:Hide()
        r.count:Hide()
        r.searchBox:Hide()
        r.readout:Hide()
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
        -- Empty and Other are real, reorderable rows, but neither owns a rule: no search box, no pin
        -- caret, no delete. The name field stretches across the freed space so the row still reads clean.
        -- Empty shows no count (it owns no items) and keeps its enable checkbox; Other shows its count
        -- (the coverage the rules leave behind) and carries no checkbox at all, since the catch-all is
        -- never switched off.
        local isEmpty = e.empty == true
        local isOther = e.other == true
        r.catId = e.id
        -- The rule read back, and the count it would catch, and neither unless this field is the one being
        -- written in: the list stays one line per rule the rest of the time, and only one row can hold
        -- focus. The text is taken from the field rather than from the saved row, since the save lags the
        -- typing by the debounce and it is the half-written line that wants explaining. The count is the
        -- same Preview the real pass runs, so it is the honest answer to "does this catch anything"
        -- without opening the bags; skipped in combat, where the walk is not worth the frame.
        local extra = 0
        local chips
        if (not isEmpty) and (not isOther) and r.searchBox:HasFocus() then
          local typed = r.searchBox:GetText()
          chips = explainRule(typed)
          if chips then
            if not (InCombatLockdown and InCombatLockdown()) then
              local n = Cats:Preview(typed) or 0
              -- The count answers "does this catch anything", so a zero is said in the theme's warning
              -- colour instead of the readout's own faint grey. A rule that reads right and catches
              -- nothing is the one failure the chips cannot tell from a working one.
              chips = chips .. "   |cff" .. Theme:Hex(n > 0 and "dim" or "gone")
                             .. T("%d items"):format(n) .. "|r"
            end
          else
            -- An empty field has nothing to read back, so the line goes to the examples instead. The
            -- words of the language are written down nowhere else in the window, and this is the one
            -- place a player looks for them — the field itself, while the cursor is already in it.
            chips = T("Examples") .. ":   " .. EXAMPLES
          end
        end
        if chips then
          -- Runs from the field to the row's right edge, measured off the two frames rather than guessed:
          -- the width the name and search fields take is theirs to set, and this only reads it back.
          local left = (r.searchBox:GetLeft() or 0) - (r:GetLeft() or 0)
          if left <= 0 then left = 300 end
          r.readout:SetWidth(math.max(160, CONTENT_W - left - 8))
          r.readout:SetText(chips)
          r.readout:Show()
          extra = math.max(14, math.ceil(r.readout:GetStringHeight() or 14)) + 4
        else
          r.readout:Hide()
        end
        r:SetHeight(CAT_ROW_H + extra)
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
        -- Empty and Other own no pins, so neither shows the add-pin toggle; every real row does, lit
        -- while its panel is open. openPins is a tri-state per id: nil is the default (open when the row
        -- holds pins, closed when it does not), true forces a pinless row open so an id can be typed in,
        -- and false collapses a pinned row the player chose to close. So the "+" can now hide a category
        -- that has pins, which it could not when the panel was pinned open by the pin count alone.
        local canPin = (not isEmpty) and (not isOther)
        local forced = row.openPins[e.id]
        local wantOpen = (forced == nil) and (#ids > 0) or (forced == true)
        local panelOpen = canPin and wantOpen and not row.dragging
        r.wpePanelOpen = panelOpen
        if isEmpty or isOther then
          -- The fields, add-pin and delete button these rows do not own are hidden, not merely dimmed,
          -- so nothing reads as editable. Neither is deletable, so both always stay in the list; the name
          -- box takes the freed width to avoid a ragged gap. Other keeps its count on the right (the
          -- unmatched total); Empty owns no items, so it shows none.
          r.nameBox:SetWidth(half * 2 - 18)
          r.searchBox:Hide()
          r.del:Hide()
          r.addPin:Hide()
          if isOther then
            r.count:SetText(tostring(other or 0))
            r.count:SetAlpha(1)
            r.count:Show()
          else
            r.count:Hide()
          end
        else
          r.addPin:Show()
          -- The sticky open flag, read by the wrapped Repaint so the + stays accent while its panel is
          -- open even after the cursor leaves the button.
          r.addPin.wpeOpen = panelOpen or nil
          r.addPin:Repaint()
          r.nameBox:SetWidth(half - 24)
          r.del:Show()
          r.searchBox:ClearAllPoints()
          ns.SnapPoint(r.searchBox, "LEFT", r.nameBox, "RIGHT", 6, 0)
          r.searchBox:SetWidth(half + 20)
          r.searchBox:Show()
          if not r.searchBox:HasFocus() then
            r.searchBox:SetText(e.search or "")
            r.searchBox.ph:SetShown((e.search or "") == "")
          end
          -- No per-item tally on a real row: the count sat between the search field and the "+" and only
          -- added noise the owner asked to drop. Only Other keeps its count, set in the branch above.
          r.count:Hide()
          -- A disabled row is not classified into any section, so dim its search to read as off; the
          -- controls stay lit so it can be re-enabled, reordered or removed.
          r.searchBox:SetAlpha(on and 1 or 0.4)
        end
        -- The name field dims with the row's on state whether or not the rest of the row is present.
        r.nameBox:SetAlpha(on and 1 or 0.4)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, -y)
        r:SetPoint("TOPRIGHT", 0, -y)
        r:Show()
        local panelH = 0
        -- The pin panel shows under a category when it holds pins, or when the row's "+" forced it open
        -- (openPins) so an id can be typed into a pinless one. A pinless, unopened row (the norm) stays
        -- one clean line. Suppressed for the whole drag so every row keeps a steady height mid-gesture.
        if panelOpen then
          local p = buildPanel(i)
          p.wpeId = e.id
          local h = layoutBuild(p, ids, CONTENT_W)
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
    -- no longer fit side by side, the reset drops to a line of its own, still on the right, rather than
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
    -- The share line, last on the page: the three buttons pack from the left like the makers and are
    -- The share line, last on the page: the two buttons pack from the left like the makers and are
    -- sized from their own labels, and the code field takes the width under them. It comes after the
    -- actions because the list above is the thing being shared and this is how it leaves and comes back.
    local shareY = y + 22 + (stacked and 26 or 0) + 14
    local sx = 0
    for _, e in ipairs(share) do
      e.btn.Text:SetText(T(e.key))
      local w = math.ceil(e.btn.Text:GetStringWidth()) + SIDEPAD
      e.btn:ClearAllPoints()
      e.btn:SetPoint("TOPLEFT", sx, -shareY)
      ns.SnapBox(e.btn, w, 22)
      e.btn:Show()
      sx = sx + w + GAPW
    end
    codeBox:ClearAllPoints()
    codeBox:SetPoint("TOPLEFT", 0, -(shareY + 28))
    codeBox:SetPoint("TOPRIGHT", 0, -(shareY + 28))
    codeBox:Show()
    row:SetHeight(shareY + 28 + 22)
  end
  row.Refresh = row.Rebuild
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
local qColorGet, qColorSet   = styleField("qualityColorIlvl")
local qBorderGet, qBorderSet = styleField("qualityBorder")
local bankColsGet, bankColsSet = dbField("bankCols")
local wbColsGet, wbColsSet     = dbField("warbandCols")
local bankSizeGet, bankIconSizeSet = dbField("bankIconSize")
local function bankSizeSet(v) ns.BumpCellSize(); bankIconSizeSet(v) end

local function anchorKeys() return ANCHORS end
local function anchorLabel(k) return ANCHOR_LABELS[k] or k end

local aucGet, aucSet   = autoField("auction")
local bankGet, bankSet = autoField("bank")
local gbGet, gbSet     = autoField("guildbank")
local mailGet, mailSet = autoField("mail")
local profGet, profSet = autoField("professions")
local tradeGet, tradeSet = autoField("trade")
local vendGet, vendSet = autoField("vendor")

local GENERAL_PAGE = {
  { type = "header", name = "Look" },
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
  { type = "select", name = "Font", get = fontGet,
    set = function(v) fontSet(v); Options:ApplyFont() end,
    keys = fontKeys, label = function(k) return k end,
    desc = "Used for every label Warpee draws. Other addons can add to this list." },
  { type = "header", name = "Money" },
  { type = "select", name = "Gold format", get = goldFmtGet, set = goldFmtSet,
    keys = function() return GOLD_FORMATS end, label = function(k) return GOLD_FORMAT_LABELS[k] or k end,
    desc = "Grouping for printed amounts. Short abbreviates to K and M." },
  { type = "toggle", name = "Gold only", col = 1, get = onlyGet, set = onlySet,
    desc = "Show gold only, hide silver and copper." },
  { type = "toggle", name = "Coin letters", col = 2, get = lettersGet, set = lettersSet,
    desc = "On = g/s/c letters. Off = coin icons." },
  { type = "header", name = "Interface", key = "interface" },
  { type = "select", name = "Language", section = "interface", get = localeGet, set = localeSet,
    keys = localeKeys, label = localeLabel,
    desc = "Language for the addon's own text. Item names always come from the game." },
  { type = "toggle", name = "Lock bags and bank", col = 1, section = "interface", get = lockGet, set = lockSet,
    desc = "Freeze the bags and the bank in place. Unlocked, they show X/Y fields along their bottom edge. Type a value, or nudge with the arrows (Shift = 10)." },
  { type = "toggle", name = "Hide X/Y fields", col = 2, section = "interface", get = hideFieldsGet, set = hideFieldsSet,
    disabled = function() return lockGet() end,
    desc = "The windows stay movable by dragging, but the X/Y fields are not drawn." },
  { type = "select", name = "Bags growth corner", col = 1, of = 2, section = "interface",
    get = function() return angleGet("pos") end,
    set = function(v) angleSet("pos", v) end,
    keys = anchorKeys, label = anchorLabel,
    desc = "The corner of the screen the bag window hangs from. It grows away from that corner as your bags fill." },
  { type = "select", name = "Bank growth corner", col = 2, of = 2, section = "interface",
    get = function() return angleGet("bankPos") end,
    set = function(v) angleSet("bankPos", v) end,
    keys = anchorKeys, label = anchorLabel,
    desc = "The corner of the screen the bank window hangs from, used the same way." },
  { type = "toggle", name = "Capacity bar", col = 1, section = "interface", get = gaugeGet, set = gaugeSet,
    desc = "Fill bar in the bags header showing how full they are." },
  { type = "toggle", name = "Hide minimap icon", col = 2, section = "interface", get = mmHideGet, set = mmHideSet,
    desc = "Takes the Warpee button off the minimap." },
  { type = "toggle", name = "Clear search on close", col = 1, section = "interface", get = sClearGet, set = sClearSet,
    desc = "Empty the search box when the window closes, so it opens unfiltered next time." },
  { type = "toggle", name = "Search bags and bank together", col = 2, section = "interface", get = sLinkGet, set = sLinkSet,
    desc = "While both windows are open, typing in either box searches both at once." },
  { type = "header", name = "Open bags with", key = "autoopen",
    state = function()
      return onOf({ aucGet, bankGet, gbGet, mailGet, profGet, tradeGet, vendGet })
    end },
  { type = "description", section = "autoopen",
    name = "The bags open together with these windows and close with them again." },
  { type = "toggle", name = "Bank", col = 1, section = "autoopen", get = bankGet, set = bankSet },
  { type = "toggle", name = "Vendor", col = 2, section = "autoopen", get = vendGet, set = vendSet },
  { type = "toggle", name = "Mail", col = 1, section = "autoopen", get = mailGet, set = mailSet },
  { type = "toggle", name = "Auction house", col = 2, section = "autoopen",
    get = aucGet, set = aucSet },
  { type = "toggle", name = "Trade", col = 1, section = "autoopen",
    get = tradeGet, set = tradeSet },
  { type = "toggle", name = "Guild bank", col = 2, section = "autoopen", get = gbGet, set = gbSet },
  { type = "toggle", name = "Professions", col = 1, section = "autoopen",
    get = profGet, set = profSet },
}

local POCKET_PAGE = {
  { type = "header", name = "Pocket" },
  { type = "toggle", name = "Pocket window", col = 1, get = fav.pkGet, set = fav.pkSet,
    desc = pinHint(
      "A small window of bookmark cells beside the bags, opened by the grid button in the header. Drag an item into a cell and the cell keeps it, wherever the item moves in your bags. Drag a cell onto another to swap them, and hovering a cell and pressing %s empties it.",
      "A small window of bookmark cells beside the bags, opened by the grid button in the header. Drag an item into a cell and the cell keeps it, wherever the item moves in your bags. Drag a cell onto another to swap them, and a cell under the pointer can be emptied with a key of its own." ) },
  { type = "toggle", name = "Open with bags", col = 2, get = fav.pkWithGet, set = fav.pkWithSet,
    disabled = function() return not fav.pkGet() end,
    desc = "The pocket opens together with the bags. A window that opens the bags on its own, the auction house or the mail, pushes the pocket aside until you open it yourself." },
  { type = "toggle", name = "Recent in the pocket", col = 1,
    get = fav.recentPocketGet, set = fav.recentPocketSet,
    disabled = function() return not fav.pkGet() end,
    desc = "A row above the pocket cells holding what came into your bags this session, apart from gray items. It is the same list the bag window shows, so clearing it in one window clears it in the other." },
  { type = "toggle", name = "Lock the pocket", col = 2,
    get = fav.pkLockGet, set = fav.pkLockSet,
    disabled = function() return not fav.pkGet() end,
    desc = "Keep the pocket where it is. Unlocked, the arrows along its bottom edge nudge it around." },
  { type = "toggle", name = "Snap to windows", col = 1,
    get = fav.snapGet, set = fav.snapSet,
    disabled = function() return not fav.pkGet() end,
    desc = "Dropped close to the bags or the bank, the pocket lines up against it and holds that seam when the other window changes size. Dragging the bags never carries the pocket along." },
  { type = "select", name = "Pocket growth corner", col = 2,
    get = function() return angleGet("pocketPos") end,
    set = function(v) angleSet("pocketPos", v) end,
    keys = function() return ANGLE_KEYS end, label = anchorLabel,
    disabled = function() return not fav.pkGet() end,
    desc = "The corner the pocket hangs from. Snapping it against another window sets this by itself." },
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
  { type = "range", name = "Pocket slot size", min = 24, max = 56, step = 1, half = "left",
    section = "pocketsize",
    get = fav.pkSizeGet, set = fav.pkSizeSet,
    disabled = function() return not fav.pkGet() end,
    desc = "Size of one cell in the pocket. It follows the bag slot size until you move this." },
  { type = "keybind", name = "Pocket key", binding = "WARPEE_POCKET", half = "right",
    disabled = function() return not fav.pkGet() end,
    desc = "The key that opens and closes the pocket. Click, then press a key, a mouse button or the wheel, with Shift, Ctrl or Alt if you like; a right click clears it, Escape cancels." },
}

local ITEMS_PAGE = {
  { type = "header", name = "Markers" },
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
  { type = "header", name = "Badges", key = "badges",
    state = function()
      return ("%s, %d/%d"):format(T(bg.label(bg.sel)), bg.shown(), #ns.BADGES)
    end },
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
  { type = "header", name = "Locked items", key = "locked",
    state = function()
      local n = 0
      for _ in pairs(WarpeeDB.vendorBlack or {}) do n = n + 1 end
      return (n == 1) and L["1 item"] or (L["%d items"]):format(n)
    end },
  { type = "description", section = "locked",
    name = "Alt-click an item to lock it: a padlock appears, and the item can no longer be sold, neither automatically nor by right-clicking at a merchant. Works in the bags, the bank, the favorites row and the pocket. Alt-click again, or the cross here, to unlock." },
  { type = "blacklist", section = "locked" },
}

local GRID_PAGE = {
  { type = "header", name = "Bags grid" },
  { type = "range", name = "Slot size", min = 24, max = 56, step = 1, get = sizeGet, set = sizeSet,
    half = "left", desc = "Size of one slot in the bags." },
  { type = "range", name = "Slots per row", min = 6, max = 24, step = 1, get = colsGet, set = colsSet,
    half = "right", desc = "How wide the bag window grows." },
  { type = "range", name = "Spacing", min = 0, max = 16, step = 1, get = gapGet, set = gapSet,
    half = "left", desc = "Gap between slots, in every grid." },
  { type = "range", name = "Icon zoom", min = 0.8, max = 1.2, step = 0.01,
    get = zoomGet, set = zoomSet, half = "right",
    desc = "1.00 fills the slot. Less shrinks the icon, more crops it." },
  { type = "header", name = "Bag arrangement", key = "arrange" },
  { type = "toggle", name = "Bags by category", col = 1, of = 2, section = "arrange",
    get = flow.catGet, set = flow.catSet,
    desc = "Lay the bag items out in labelled sections instead of one grid: equipment, consumables, reagents and the rest, with anything left over under Other. The favorites and recent rows stay." },
  { type = "toggle", name = "Bank by category", col = 2, of = 2, section = "arrange",
    get = flow.bankCatGet, set = flow.bankCatSet,
    desc = "Lay the bank and warband bank out in the same labelled sections as the bags." },
  -- Shown whenever either surface is grouped (hidden = noCat), since the gaps drive both. Each reads
  -- the density gap while unset so the slider opens on the value already in use, and writes a flat
  -- pixel gap once moved. X is the space between sections across a shelf, Y the drop between rows.
  { type = "range", name = "Category spacing X", min = 0, max = 40, step = 1, section = "arrange",
    get = function() return Bags.catGapX or ns.Density(Bags.iconSize).div end,
    set = function(v) Bags.catGapX = v; WarpeeDB.catGapX = v; relayout() end,
    hidden = flow.noCat, half = "left",
    desc = "Horizontal gap between categories on a shelf, in the grouped view." },
  { type = "range", name = "Category spacing Y", min = 0, max = 40, step = 1, section = "arrange",
    get = function() return Bags.catGapY or ns.Density(Bags.iconSize).div end,
    set = function(v) Bags.catGapY = v; WarpeeDB.catGapY = v; relayout() end,
    hidden = flow.noCat, half = "right",
    desc = "Vertical gap between category rows, in the grouped view." },
  { type = "toggle", name = "Hide reagents", col = 1, of = 2, section = "arrange",
    get = flow.hideGet, set = flow.hideSet, hidden = flow.catGet,
    desc = "Leave the reagent bag out of the window. Its slots still count in the header, and reagents still go into it." },
  { type = "toggle", name = "Merge reagents", col = 2, of = 2, get = mergeGet, set = mergeSet,
    section = "arrange", disabled = flow.hideGet, hidden = flow.catGet,
    desc = "Lay the reagent bag out with the main bags, without its caption." },
  { type = "toggle", name = "Reagents on top", section = "arrange",
    get = flow.topGet, set = flow.topSet, disabled = flow.offGet, hidden = flow.catGet,
    desc = "Draw the reagent bag above the main bags instead of below them." },
  { type = "toggle", name = "Fill grid upwards", col = 1, of = 2, section = "arrange",
    get = flow.upGet, set = flow.upSet, hidden = flow.gridGone,
    desc = "The rows of cells stack from the bottom edge up, so the part-filled last row sits at the top." },
  { type = "toggle", name = "Reverse slot order", col = 2, of = 2, section = "arrange",
    get = flow.revGet, set = flow.revSet, hidden = flow.gridGone,
    desc = "The bag slots run backwards, so the last slot of the last bag takes the first cell. Nothing moves inside your bags, only the order the slots are drawn in." },
  { type = "header", name = "Quick access" },
  { type = "toggle", name = "Recent in bags", col = 1,
    get = fav.recentBagsGet, set = fav.recentBagsSet,
    desc = "A row above the favorites holding what came into your bags this session, apart from gray items. Each arrival takes the first free cell, the oldest one leaves when the row is full, and the row clears on logout or a reload." },
  { type = "toggle", name = "Favorite slots", col = 2, get = fav.showGet, set = fav.showSet,
    desc = pinHint(
      "A row of slots above the grid, always in sight. Drag an item onto one to keep it a click away; hovering a slot and pressing %s clears it.",
      "A row of slots above the grid, always in sight. Drag an item onto one to keep it a click away; a slot under the pointer can be cleared with a key of its own." ) },
  { type = "keybind", name = "Clear the cell", binding = "WARPEE_UNPIN",
    desc = "The key that empties a favorite or pocket cell under the pointer. Click, then press a key, a mouse button or the wheel; a right click clears it, Escape cancels." },
  { type = "header", name = "Bank and Warband grid", key = "bankgrid",
    state = function() return (L["%d and %d wide"]):format(bankColsGet(), wbColsGet()) end },
  { type = "description", section = "bankgrid",
    name = "The bank keeps its own width and icon size, apart from the bags." },
  { type = "range", name = "Bank slot size", min = 24, max = 56, step = 1, section = "bankgrid",
    get = bankSizeGet, set = bankSizeSet,
    desc = "One icon size for both bank tabs." },
  { type = "range", name = "Bank slots per row", min = 8, max = 40, step = 1, section = "bankgrid",
    get = bankColsGet, set = bankColsSet, half = "left" },
  { type = "range", name = "Warband slots per row", min = 8, max = 40, step = 1,
    section = "bankgrid", get = wbColsGet, set = wbColsSet, half = "right" },
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

local CATS_PAGE = {
  { type = "header", name = "Categories", key = "categories" },
  { type = "description", section = "categories",
    name = "Each row is either a category — a search read top to bottom, where an item joins the first it matches — or a marker: a group header naming the band under it, or a divider seaming one off. Drag a row by its grip to move it, the box on the left turns a category off, and the X takes a row out; a removed group header leaves its categories where they are. The strip above adds a ready-made category, and the buttons under the list add a new row at its bottom — the view scrolls to it and it flashes." },
  -- The order of items inside a section is set on the list's own header line, inside the catlist row
  -- below, rather than as a select here: see factories.catlist.
  { type = "catlist", section = "categories" },
}

local PAGES = {
  { name = "General", list = GENERAL_PAGE },
  { name = "Grid", list = GRID_PAGE },
  { name = "Categories", list = CATS_PAGE },
  { name = "Items", list = ITEMS_PAGE },
  { name = "Pocket", list = POCKET_PAGE },
  { name = "Vendor", list = VENDOR_PAGE },
  { name = "Characters", list = CHARS_PAGE },
}

local function paintTab(b)
  if b.sel then
    local def = Theme.SkinDef and Theme:SkinDef()
    ns.SetBg(b, Theme:C((def and def.quietTabs) and "panel" or "panelHi"))
    ns.SetEdge(b, Theme:C("accent"))
    b.Text:SetTextColor(Theme:C("accent"))
  else
    ns.SetBg(b, Theme:C("panel"))
    ns.SetEdge(b, Theme:C("stroke"))
    b.Text:SetTextColor(Theme:C("dim"))
  end
end

function Options:Select(index)
  closeDropdown()
  self.current = index
  for i, tab in ipairs(self.tabs) do
    tab.sel = (i == index)
    paintTab(tab)
    self.areas[i]:SetShown(i == index)
    self.areas[i].bar:SetShown(i == index)
  end
  local area = self.areas[index]
  area:ScrollTo(0)
  area:PaintBar()
  self:Refresh()
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
      tab.Text:SetText(T(PAGES[i].name))
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
  self:AnchorHeader()
  for _, row in ipairs(rows) do row.Refresh() end
  for _, area in ipairs(self.areas) do
    area.page.Relayout()
    area:ScrollTo(area:GetVerticalScroll())
    area:PaintBar()
  end
end

function Options:Refresh()
  for _, row in ipairs(rows) do row.Refresh() end
  if ns.Profiles and ns.Profiles.SyncActive then ns.Profiles:SyncActive() end
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
  self:ReflowPages()
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
  end)
  self.frame = f

  local title = Theme:Title(f, BASE_FONT + 2, "accent")
  title:SetPoint("TOPLEFT", PAD, -10)
  title:SetText("WARPEE")
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

  local line = Theme:Rect(f, "strokeSoft", "ARTWORK")
  ns.PixelLine(line, 1)
  line:SetPoint("TOPLEFT", PAD, -HEADER_H)
  line:SetPoint("TOPRIGHT", -PAD, -HEADER_H)
  self.headLine = line

  self.tabs, self.areas = {}, {}
  for i, pageDef in ipairs(PAGES) do
    local tab = ns.CreateButton(f, T(pageDef.name), 90, TAB_H)
    track(tab.Text, -1)
    tab:SetWidth(math.max(70, tab.Text:GetStringWidth() + 22))
    -- Placement is done by ReflowPages so a hidden tab leaves no gap; here we only create it.
    tab:HookScript("OnLeave", paintTab)
    tab:SetScript("OnClick", function() self:Select(i) end)
    self.tabs[i] = tab

    local area = makeScrollArea(f, pageDef.list)
    area:SetPoint("TOPLEFT", PAD, -(HEADER_H + TAB_H + 14))
    area:SetPoint("BOTTOMRIGHT", -(PAD + SCROLL_W + 6), PAD)
    area.bar:SetPoint("TOPLEFT", area, "TOPRIGHT", 6, 0)
    area.bar:SetPoint("BOTTOMLEFT", area, "BOTTOMRIGHT", 6, 0)
    self.areas[i] = area
  end

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
  for _, area in ipairs(self.areas or {}) do
    area:ClearAllPoints()
    area:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(HEADER_H + TAB_H + 14 + top))
    area:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(PAD + SCROLL_W + 6), PAD)
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
