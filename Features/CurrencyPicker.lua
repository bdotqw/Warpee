local addonName, ns = ...
local Theme = ns.Theme

-- The currency panel: the one editor of the client's tracking flags. It shows every currency the
-- client knows, in the client's own order and under the client's own section names, with a tick on the
-- ones the character panel tracks -- a tick tracks, a second tick untracks, and the list itself is the
-- feedback. Search narrows it, and a coin in the header walks to the game's own currency tab --
-- the filter lives there, and so do the transfers.
--
-- The panel is also the only place in the addon that walks the client's whole currency list, and that walk
-- is the reason this file exists apart from Features/Currencies.lua:
--
--   * GetCurrencyListInfo answers with the currencies of the headers that are OPEN, so a full list means
--     expanding every collapsed header first (and putting them back afterwards, in reverse order).
--   * Each of those calls fires CURRENCY_DISPLAY_UPDATE, which is the very event a tracker listens to.
--     A scan that ran on that event would answer itself for as long as the client kept talking, so the
--     scan holds a flag for the time it runs and folds anything that arrives meanwhile into one pass
--     after it.
--   * So it runs when the window opens and when the window is open and a currency changes -- never in
--     the background, where nothing needs it: a chip in the row costs one lookup for its own slot.

local Pick = {}
ns.CurPicker = Pick

-- Every number below is a density step's, not this file's (Core/Density.lua, the `cur*` family): the
-- panel is a side panel of the bags, so it grows with the same setting the grid does, and an open panel
-- re-reads it on every paint -- a size change in the settings reaches it without a rebuild.
local W        = 330   -- the narrowest the panel stands for its density step
local ROW_H    = 22
local HEAD_H   = 20    -- a section name's row
local PAD      = 10
local TITLE_H  = 26
local SEARCH_H = 24
local MAX_LIST = 418   -- taller than this and the list scrolls
local BAR_W    = 6     -- the scrollbar's track, standing in the panel's own margin beside the list
local FONT     = 14
local HDR_FONT = 11    -- a section name: under a currency's and quiet, so the currencies carry the eye
local ICON     = 20    -- a currency's icon in a row (nearly the row's own height; the old 15 read as a smudge)
local BOX      = 14    -- its tick box
local BTN      = 22    -- a header button: the coin, the filter and the cross
local HEAD_UP  = 4     -- on Blizzard Flat the header pair stands this far above its plain line

-- Blizzard Flat alone lifts the header pair (the two buttons and the title) off its line; every other skin
-- leaves the pair where it stands.
local function headerUp()
  return Theme.skin == "blizzardflat" and HEAD_UP or 0
end

local function applyDensity()
  -- No size is handed in: the panel belongs to the bags and reads the bags' own icon size, the way every
  -- other number in that window does.
  local d = ns.Density()
  PAD      = d.curPad
  ROW_H    = d.curRow
  HEAD_H   = d.curHdr
  TITLE_H  = d.curTitle
  SEARCH_H = d.curSearch
  W        = d.curW
  FONT     = d.curFont
  HDR_FONT = math.max(9, FONT - 3)
  MAX_LIST = ((d.curRows or 19) + 4) * ROW_H
  -- The icon takes almost the whole row: a 15px mark on a 22px row was read as a smudge, and the
  -- row itself grew a step so the bigger mark still has air around it.
  ICON     = math.max(16, ROW_H - 4)
  BOX      = math.max(12, ROW_H - 8)
end

-- The row's own numbers are the step's too, and a pooled row is dressed again when the step moves: the
-- frame is built once, so nothing here may be baked in at birth.
local function dressRow(r)
  local key = ICON .. ":" .. BOX .. ":" .. ROW_H
  if r.wpeDress == key then return end
  r.wpeDress = key
  r.icon:ClearAllPoints()
  r.icon:SetPoint("RIGHT", r.box, "LEFT", -6, 0)
  r.icon:SetSize(ICON, ICON)
  r.count:ClearAllPoints()
  r.count:SetPoint("RIGHT", r.icon, "LEFT", -6, 0)
  r.name:ClearAllPoints()
  r.name:SetPoint("LEFT", r.xfer, "RIGHT", 4, 0)
  r.name:SetPoint("RIGHT", r.count, "LEFT", -6, 0)
  r.box:SetSize(BOX, BOX)
  r.xfer:SetSize(ROW_H, ROW_H)
  ns.MarkArrow(r.xfer, true)
end

local list      = {}   -- the walk's rows, kept between paints so a tick costs no scan
local scanning  -- the guard: the walk is running and fired the event it answers
local refire    -- something arrived during the walk: one more pass when it is done
local pending

-- The one switch of the panel, shared by the tick box and the row's Shift-click: the client's pin
-- flips at once (the character panel agrees), the row's own record follows without a second walk, and
-- the repaint re-reads the client's track list in its own order. `wpeOn` is the state the last paint
-- drew, so the flip always goes the other way from what the player sees.
local function toggleWatched(r)
  if not (r.wpeID and r.wpeFound) then return false end
  if not ns.Cur:SetWatched(r.wpeID, not r.wpeOn) then return false end
  r.wpeOn = not r.wpeOn
  for i = 1, #list do
    if list[i].id == r.wpeID then list[i].watched = r.wpeOn and true or nil end
  end
  Pick:Paint(true)
  return true
end


-- The word the track list carries at the top. The client's own "Tracked" (the objective tracker's own, so
-- it reads in the client's language, if it is there) and, failing that, the addon's key -- which falls to
-- "Tracked".
local function trackedLabel()
  local g = _G.TRACKED
  if type(g) == "string" and g ~= "" then return g end
  return ns.L["Tracked"]
end

------------------------------------------------------------------------------
-- Painting the rows
------------------------------------------------------------------------------
function Pick:Row(i)
  local r = self.rows[i]
  if r then return r end
  -- The row is an insecure action button, the way a cell of the quick row is: a Ctrl-click asks the client
  -- to run its own transfer chain -- the currency's row in the character panel, then its transfer toggle --
  -- so the transfer stays on the client's untainted path and the addon only names frames (see
  -- Cur:ArmTransfer). A client that answers no such template keeps a plain row, whose Ctrl-click walks to
  -- the currency tab instead.
  local made
  made, r = pcall(CreateFrame, "Button", nil, self.child, "InsecureActionButtonTemplate")
  if not made or not r then
    r = CreateFrame("Button", nil, self.child)
    r:RegisterForClicks("LeftButtonUp")
  else
    r:RegisterForClicks("AnyUp", "AnyDown")
    r:SetAttribute("type", "click")
    r:SetAttribute("downbutton", "startup")
    r:SetAttribute("typerelease", "click")
  end
  -- The light takes no colour key on purpose: a keyed Rect carries a recolour hook of its own, and on a
  -- switch that hook re-runs SetVertexColor at full alpha behind the row's pass, leaving rows and headings
  -- lit as if hovered (the same trap the options wash names: SetAlpha is not re-run on a theme change, but
  -- the recolour hook is). The row's own pass writes the colour and the state together, so no second
  -- writer exists to re-light it.
  local hl = Theme:Rect(r, nil, "BACKGROUND")
  hl:SetAllPoints(r)
  hl:SetAlpha(0)
  r.hl = hl
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(ICON, ICON)
  r.name = r:CreateFontString(nil, "OVERLAY")
  r.name:SetJustifyH("LEFT")
  r.name:SetWordWrap(false)
  r.count = r:CreateFontString(nil, "OVERLAY")
  r.count:SetJustifyH("RIGHT")
  r.box = ns.CreateCheckBox(r, BOX)
  r.box:SetPoint("RIGHT", -2, 0)
  -- A currency another character can send over wears a down arrow left of its name -- the drawn mark the
  -- header's own filter carries, an indicator only: it answers no click and names no door. The slot is held
  -- for every row alike (the name anchors to it whether the arrow shows or not), so a currency that cannot
  -- be sent over still starts on the very same column, from empty space.
  r.xfer = CreateFrame("Frame", nil, r)
  r.xfer:SetSize(ROW_H, ROW_H)
  r.xfer:SetPoint("LEFT", 2, 0)
  ns.MarkArrow(r.xfer, true)
  r.xfer:Hide()
  -- The mark sits left of the tick and the count left of the mark, so the row reads name, number, icon,
  -- switch. The name is held against the count's left edge, so a long localized name is clipped there
  -- instead of running under the count.
  r.icon:SetPoint("RIGHT", r.box, "LEFT", -6, 0)
  r.count:SetPoint("RIGHT", r.icon, "LEFT", -6, 0)
  r.name:SetPoint("LEFT", 2, 0)
  r.name:SetPoint("RIGHT", r.count, "LEFT", -6, 0)
  -- The box is a plain Frame, and a Frame is click-through until it asks for the mouse: the tick is a
  -- Button laid over it, so the click really lands. The hit shares the row's own hover and tooltip, so
  -- pointing at the tick reads exactly like pointing at the rest of the row.
  local hit = CreateFrame("Button", nil, r)
  hit:SetAllPoints(r.box)
  hit:RegisterForClicks("LeftButtonUp")
  hit:SetScript("OnClick", function() toggleWatched(r) end)
  local function rowScript(ev)
    local fn = r.GetScript and r:GetScript(ev)
    if fn then fn(r) end
  end
  hit:SetScript("OnEnter", function() rowScript("OnEnter") end)
  hit:SetScript("OnLeave", function() rowScript("OnLeave") end)
  r.boxHit = hit
  -- The light is the pointer's live state, not the last enter: a row hidden under the cursor never sees
  -- its leave, and a theme switch repaints the list from outside the pointer's own events. So the light
  -- carries a pass of its own -- it reads IsMouseOver when it is called -- and every way in (the pointer,
  -- a paint, the theme pass) goes through it. A switch then cannot leave the list standing lit, which is
  -- what a light that trusted its own enter and leave did.
  -- IsMouseOver answers about the row's own rectangle, not about what stands on top of it: with the
  -- options dropdown over an open picker it answered yes for rows behind the menu, and a switch then
  -- lit them as if hovered. The pointer's real owner is GetMouseFocus; the tick's hit frame is the
  -- row's child, so it is accepted as the row itself.
  r.wpeLight = function(s)
    -- The colour rides the state's own pass: the light takes no colour key, so no theme hook may repaint it
    -- to full alpha on its own behind this pass. Colour first: SetVertexColor ends at full alpha by itself,
    -- and the state's alpha is set after it.
    local cr, cg, cb = Theme:C("panelHi")
    s.hl:SetVertexColor(cr, cg, cb)
    local lit = s.wpeLive and s:IsMouseOver()
    if lit and GetMouseFocus then
      local f = GetMouseFocus()
      if not (f == s or (f and f.GetParent and f:GetParent() == s)) then lit = nil end
    end
    s.hl:SetAlpha(lit and 1 or 0)
  end
  Theme:Track(r, r.wpeLight)
  r:SetScript("OnEnter", function(s)
    s:wpeLight()
    -- The arm has to stand before the press, and the Ctrl-hover that always comes first is where it is
    -- made: laying the client's currency list out is the expensive half, and a Ctrl-hover pays it once.
    if s.wpeID and ns.Cur.Transferable(s.wpeID) then ns.Cur:WantTransfer(s, s.wpeID) end
    -- The row's tooltip is the game's own currency tooltip: it already names this very currency, its
    -- standing and its description, so the row re-states nothing of what the client knows.
    if not s.wpeID then return end
    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
    if GameTooltip.SetCurrencyByID then
      GameTooltip:SetCurrencyByID(s.wpeID)
    else
      GameTooltip:SetText(s.wpeName or "")
    end
    if ns.Cur.Transferable(s.wpeID) and not (InCombatLockdown and InCombatLockdown()) then
      GameTooltip:AddLine(ns.TipInk(ns.L["Ctrl + LMB to transfer currency from another character"], 0.9, 0.9, 0.9), 0.9, 0.9, 0.9, true)
    end
    -- The row's own click is a switch too, and the tooltip says which way it goes in the state the
    -- player is looking at: a tracked row offers to stop, an untracked one to start. A currency the
    -- client has never met has no tick and no switch, so it gets no promise either.
    if s.wpeFound then
      local hint = s.wpeOn and ns.L["Shift + LMB to stop tracking"]
                             or ns.L["Shift + LMB to start tracking"]
      GameTooltip:AddLine(ns.TipInk(hint, 0.9, 0.9, 0.9), 0.9, 0.9, 0.9, true)
    end
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function(s)
    s:wpeLight()
    ns.Cur:DisarmTransfer(s, true)
    GameTooltip:Hide()
  end)
  -- The row carries two modified presses: Ctrl is the client's own transfer where the currency is
  -- transferable, and Shift is the same track switch as the tick box. A plain press still does nothing,
  -- so the row can never flip a pin by accident. Ctrl wins when both modifiers are held, and on a
  -- currency the client cannot transfer the Ctrl-press falls through to the Shift switch.
  r:SetScript("OnMouseDown", function(s, button)
    if button == "LeftButton" then s.pressed = true end
  end)
  r:SetScript("OnMouseUp", function(s, button)
    if button ~= "LeftButton" or not s.pressed then return end
    s.pressed = nil
    if not s.wpeID then return end
    if IsControlKeyDown and IsControlKeyDown() then
      -- Combat owns no Ctrl-click on a currency: the press is left unanswered, so nothing here may arm
      -- the client's chain or walk to its protected tab.
      if InCombatLockdown and InCombatLockdown() then return end
      if ns.Cur.Transferable(s.wpeID) then
        -- An armed row has already had the client run its chain on the press; all that is left is to
        -- stand the menu beside the character panel, the way the panel itself would have. An unarmed
        -- one (a client without those frames) walks to the currency tab, where the transfer waits.
        if s.wpeArmed then ns.Cur:PlaceTransfer() else ns.Cur:OpenTransfer(s.wpeID) end
        return
      end
    end
    if IsShiftKeyDown and IsShiftKeyDown() then
      -- The row moves under the pointer when the track list regroups, so the tooltip that named the old
      -- state is put away rather than left standing over another currency.
      if toggleWatched(s) then GameTooltip:Hide() end
    end
  end)
  -- The tick is the row's other switch, and both hand the flip to toggleWatched: the client's pin flips
  -- at once, the held row is repainted from the flip without a second walk, and the burst the client
  -- answers with re-reads the list anyway.
  r.box:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" then toggleWatched(r) end
  end)
  self.rows[i] = r
  return r
end

-- The rows the panel shows, out of the rows the walk brought back: the client's sections as headings,
-- every currency under the section it came in -- the client's own "Unused" one included, so it reads
-- like any other section -- and everything a query does not match left out with them. A currency never
-- met stays out: with no tick it would take and no door to open, it is a line nothing can be done with.
-- Pure on purpose -- the walk needs the game, the filtering needs only the rows, so the harness drives
-- this directly.
function Pick.Filter(rows, query, onlyTransfer)
  local out = {}
  local q = query and query:lower()
  if q and q == "" then q = nil end
  -- The one cut the header's filter makes: only what another character can send over. It applies to the
  -- client's sections, the player's own track list and a search alike, so the panel never disagrees
  -- with itself.
  local function keeps(e)
    return e.found ~= false and (not onlyTransfer or e.transfer)
  end
  -- A query flattens the list: the sections step aside and every match stands on its own, so a search is a
  -- plain run of the currencies it found.
  if q then
    for i = 1, #rows do
      local e = rows[i]
      if not e.header and keeps(e) and (e.name or ""):lower():find(q, 1, true) then
        out[#out + 1] = e
      end
    end
    return out
  end
  -- No query: the client's own list, its sections as headings and each currency under the section it came
  -- in. A heading is a plain label -- it folds nothing and answers no click.
  --
  -- The player's own track list opens the panel first, as one more heading: a tick anywhere -- here, the
  -- character panel, the bags' own row -- is the client's "show in backpack" flag, so a tracked currency
  -- is lifted out of its section and lives up here, in the client's own order. That keeps it to one row per
  -- currency (no double with the same tick below) and makes "what I watch" the first thing the panel shows.
  -- An empty track list adds no heading at all.
  local watched = {}
  for i = 1, #rows do
    local e = rows[i]
    if not e.header and e.watched and keeps(e) then
      watched[#watched + 1] = e
    end
  end
  if #watched > 0 then
    out[#out + 1] = { header = true, name = trackedLabel(), level = 1, tracked = true }
    for i = 1, #watched do out[#out + 1] = watched[i] end
  end
  for i = 1, #rows do
    local e = rows[i]
    if e.header then
      out[#out + 1] = e
    elseif keeps(e) and not e.watched then
      out[#out + 1] = e
    end
  end
  -- A heading with nothing under it is noise: the client keeps sections whose currencies are gone, and a
  -- panel that shows "Midnight" over an empty line reads as a loading bug. A heading of any level is empty
  -- when the row after it is a heading at its own level or above: nothing sits between the two.
  for i = #out, 1, -1 do
    local e, nxt = out[i], out[i + 1]
    if e.header then
      local lvl = e.level or 1
      if not nxt or (nxt.header and (nxt.level or 1) <= lvl) then table.remove(out, i) end
    end
  end
  return out
end

function Pick:Visible(query)
  return Pick.Filter(list, query, self.onlyTransfer)
end

function Pick:Paint(keepScroll)
  local w = self.frame
  if not (w and w:IsShown()) then return end
  applyDensity()
  local rows = self:Visible(self.query)
  local path = ns.Fonts:Current()
  local y, widest = 0, 0
  for i = 1, #rows do
    local e = rows[i]
    local r = self:Row(i)
    dressRow(r)
    -- A section name is a plain label: it answers no click and takes no light, the way a section name
    -- always did; only a currency row is live.
    r.wpeID   = e.header and nil or e.id
    r.wpeName = e.header and nil or e.name
    r.wpeLive = (not e.header) and true or nil
    -- A pooled row that comes back as a heading must lose the arm it carried as a currency: the attributes
    -- name the client's frames and survive a repaint, so a heading clicked with Ctrl would still transfer.
    if e.header then ns.Cur:DisarmTransfer(r) end
    if e.header then
      r.icon:Hide()
      r.box:Hide()
      if r.boxHit then r.boxHit:Hide() end
      r.xfer:Hide()
      -- The count's own face before the empty string goes in: the client refuses SetText on a FontString
      -- that has no font, and a heading is the only row that clears the count without ever giving it one --
      -- a row reused from a currency row below it either way. The game logged one line per heading for this.
      r.count:SetFont(path, FONT - 1, ns.OutlineFlags())
      -- A quiet line: faint and small, flush to the row's left, no caret and no counted rows, so it reads
      -- as a label and not another currency. The track list alone wears its own colour, so the top heading
      -- is told apart from the client's own sections.
      local cr, cg, cb = Theme:C(e.tracked and "coin" or "faint")
      r.name:ClearAllPoints()
      r.name:SetPoint("LEFT", r.xfer, "RIGHT", 4, 0)
      r.name:SetPoint("RIGHT", r.count, "LEFT", -6, 0)
      r.name:SetFont(path, HDR_FONT, ns.OutlineFlags())
      r.name:SetTextColor(cr, cg, cb)
      r.name:SetText(ns.Upper(e.name or ""))
      r:SetHeight(HEAD_H)
      r.count:SetText("")
    else
      -- Every name shares one left offset: the arrow's slot stands whether the arrow is drawn or not, so a
      -- currency another character can send over starts on the mark and one that cannot starts on empty
      -- space at the very same column.
      r.name:ClearAllPoints()
      r.name:SetPoint("LEFT", r.xfer, "RIGHT", 4, 0)
      r.name:SetPoint("RIGHT", r.count, "LEFT", -6, 0)
      if e.transfer then
        -- A quiet ink, a step under the row's own white: the mark reads as a secondary note, not a second
        -- name. The palette key (not a raw alpha) keeps it right on every skin and lets the 1px silhouette
        -- under it stay a clean outline.
        ns.TintMarkX(r.xfer, "dim")
        r.xfer:Show()
      else
        r.xfer:Hide()
      end
      local on = e.watched and true or false
      r.wpeOn = on
      r.wpeFound = e.found
      r.icon:SetTexture(e.icon)
      r.icon:Show()
      -- No tick for a currency never met: the client refuses the pin, so the box stands down the way
      -- Blizzard's own list stands it down.
      r.box:SetShown(e.found)
      if r.boxHit then r.boxHit:SetShown(e.found) end
      r.box.mark:SetShown(on)
      r.box:SetKeys(on and "panelHi" or "slot", "stroke", "accent")
      r.name:SetFont(path, FONT, ns.OutlineFlags())
      r.name:SetText(e.name or "")
      local tr, tg, tb = Theme:C("text")
      r.name:SetTextColor(tr, tg, tb)
      -- Measured after the face is on, so the width is the width of the row the player reads.
      local nw = r.name:GetStringWidth()
      if nw > widest then widest = nw end
      r.count:SetFont(path, FONT - 1, ns.OutlineFlags())
      r.count:SetText(ns.Cur.CountText(e.q))
      -- The count reads in the row's own white ink at every value: a currency at its ceiling is no
      -- different from one below it here, so the number never turns into a red warning of its own.
      local dr, dg, db = Theme:C("text")
      r.count:SetTextColor(dr, dg, db)
      r:SetHeight(ROW_H)
    end
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, -y)
    r:SetPoint("TOPRIGHT", self.child, "TOPRIGHT", 0, -y)
    r:Show()
    -- The light is re-derived rather than trusted from the last enter: the row's own pass reads the
    -- pointer (see Pick:Row), so a paint and a theme pass can never disagree about it.
    r:wpeLight()
    y = y + r:GetHeight()
  end
  for i = #rows + 1, #self.rows do self.rows[i]:Hide() end
  self.child:SetHeight(math.max(1, y))
  self.listH = math.min(MAX_LIST, math.max(ROW_H * 6, y))
  -- The panel's own width: the step's minimum, or wide enough for the longest name the walk has shown,
  -- with ninety points of slack as the ceiling -- one enormous localized name must not push the panel off
  -- the screen. The widest name is remembered, so narrowing the list with a search cannot make the panel
  -- breathe under the cursor.
  if widest > (self.widest or 0) then self.widest = widest end
  local need = 2 + ICON + 6 + (self.widest or 0) + 6 + 44 + BOX + 2 + ROW_H + 4 + PAD * 2 + BAR_W + 2
  local w0 = math.min(W + 90, math.max(W, need))
  -- The search box stands its own height under the title and the list begins under the box: they are two
  -- lines, not one. Anchoring both at `head` drew the list's first row up under the search box. A skin also
  -- draws its own title band across the top and keeps a strip for it (Theme:TopInset): the title, the coin
  -- and the cross move below that strip, and the frame grows by it, so on the Blizzard art the three no
  -- longer sit on the ornate band.
  local top = Theme:TopInset()
  local searchTop = TITLE_H + PAD + top
  local head = searchTop + SEARCH_H + 8
  local h = head + self.listH + 8
  -- The face follows the numbers: the frame is built once and painted many times, so the chrome is
  -- re-anchored here rather than written down at birth -- a density change reaches an open panel.
  -- The header pair shares one line: the two buttons stand on the right and the title is centered on their
  -- middle. The title is anchored by its own LEFT point onto the frame's TOPLEFT -- a bare "LEFT" with no
  -- frame named answers the parent's own left-centre and drops the name into the middle of the window. On
  -- Blizzard Flat the pair rides HEAD_UP above its plain line; that is only a move of the two, no height
  -- changes, so the frame keeps its size.
  local btnTop = -(PAD - 5 + top) + headerUp()
  if self.title then
    self.title:SetFontObject(ns.Fonts:Object(FONT, ns.OutlineFlags()))
    self.title:ClearAllPoints()
    self.title:SetPoint("LEFT", w, "TOPLEFT", PAD, btnTop - BTN / 2)
  end
  if self.close then
    self.close:ClearAllPoints()
    self.close:SetPoint("TOPRIGHT", -(PAD - 2), btnTop)
  end
  if self.filter then
    self.filter:ClearAllPoints()
    self.filter:SetPoint("TOPLEFT", PAD, -searchTop)
    self.filter:SetPoint("TOPRIGHT", -PAD, -searchTop)
    self.filter:SetHeight(SEARCH_H)
    self.filter:SetFont(path, FONT, ns.OutlineFlags())
    if self.filter.Hint then
      self.filter.Hint:SetFontObject(ns.Fonts:Object(FONT, ns.OutlineFlags()))
    end
  end
  self.sf:ClearAllPoints()
  self.sf:SetPoint("TOPLEFT", PAD, -head)
  self.sf:SetPoint("TOPRIGHT", -(PAD + BAR_W + 2), -head)
  self.sf:SetHeight(self.listH)
  self.child:SetWidth(w0 - PAD - (PAD + BAR_W + 2))
  ns.SnapSize(w, w0, h)
  if not keepScroll then self.sf:SetVerticalScroll(0) end
  Pick:PaintBar()
  -- The panel takes its side of the window, level with the bags' own head where the currency switch that
  -- summoned it stands. The character picker takes the same top line, and the two panels never stand
  -- together (Toggle takes the other down), so the line is free. A window low enough that the panel would
  -- run off the screen falls back to the foot: the list must stay visible even when it cannot open by its
  -- switch. The two side panels are mutually exclusive, so no sibling frame is handed to the helper:
  -- anchoring one panel to the other is exactly what built the anchor cycle the client refused. The
  -- helper still guards the wanted side off the edge.
  local align = "top"
  if self.win and self.win.GetTop and self.win.GetBottom and UIParent and UIParent.GetHeight then
    local top, bottom = self.win:GetTop(), self.win:GetBottom()
    local sh = UIParent:GetHeight() or 0
    if top and bottom and sh > 0 then
      local topRoom, bottomRoom = top, sh - bottom
      if topRoom < h and bottomRoom > topRoom then align = "bottom" end
    end
  end
  if self.win then
    ns.SidePlace(w, self.win, self.side or "left", align)
  end
  ns.AlignToScreen(w)
end

------------------------------------------------------------------------------
-- The walk
------------------------------------------------------------------------------
function Pick:Scan(keep)
  if not (self.frame and self.frame:IsShown()) then return end
  if scanning then refire = true; return end
  scanning = true
  -- Reads only, never switches: the client's filter (character or warband) answers to the game's own
  -- hands alone, so the walk takes whatever list the tab currently shows and the label above names it.
  local CI = C_CurrencyInfo
  -- The warband roster arrives late: ask for it while open, and the event above rescans when it lands.
  if CI.RequestCurrencyDataForAccountCharacters
     and CI.IsAccountCharacterCurrencyDataReady and not CI.IsAccountCharacterCurrencyDataReady() then
    CI.RequestCurrencyDataForAccountCharacters()
  end
  local expanded = {}
  local rows, headers = ns.Cur.WalkList(CI, {}, expanded)
  list = rows
  ns.Cur.RestoreList(CI, expanded)
  scanning = false
  -- A deferred pass re-reads rather than repainting stale rows.
  if refire then
    refire = nil
    self:Scan(keep)
    return
  end
  self:Paint(keep)
end

-- A currency changed while the panel is open: one debounced pass, and the burst that a scan itself
-- produces folds into it rather than starting another. The scroll stays where the player left it: a
-- rescan that jumped to the top on every coin spent would read as the list running away.
function Pick:Request()
  if pending then return end
  pending = true
  C_Timer.After(0.25, function()
    pending = nil
    Pick:Scan(true)
  end)
end

-- The header's one filter: the whole list, or only the currencies another character can send over. It is
-- a cut of the rows this panel already holds -- the client's own account-transferable flag -- so it costs
-- no walk of the client's list and never changes what the game itself shows. Kept between sessions (the
-- bags already remember their other shape choices), because a player who works with the warband's coins
-- wants the panel to open on them.
function Pick:SetOnlyTransfer(on)
  on = on and true or false
  self.onlyTransfer = on or nil
  if WarpeeDB then WarpeeDB.curOnlyTransfer = on or nil end
  local b = self.onlyBtn
  if b then
    b.wpeOn = on or nil
    b:Repaint()
  end
  -- The cut is a new list, so the scroll goes back to its head: a filter toggled while the player stood
  -- deep in the full list would otherwise keep that offset over a shorter one and leave the panel blank
  -- until the wheel walked it back up.
  if self.frame and self.frame:IsShown() then self:Paint() end
end

-- Called by Features/Currencies.lua when the tracking changes: the ticks are repainted, the client is
-- not asked again.
function Pick:Refresh()
  -- Called by Features/Currencies.lua right after it asks the client to flip the track flag -- and the
  -- client has not always answered by the time this returns. So the read waits one frame and folds into a
  -- single pass: a tick then paints once, with the flag in hand, rather than twice -- once stale and once
  -- right -- which drew a tracked currency in one order and then another, as if it were thrown to the tail
  -- of the mirror and pulled back to its place. The coalescing keeps a burst of flips to the one paint.
  if self.refreshPending then return end
  self.refreshPending = true
  C_Timer.After(0, function()
    self.refreshPending = nil
    if ns.Cur and ns.Cur.ReadWatched and C_CurrencyInfo then
      local ids, on = {}, {}
      ns.Cur.ReadWatched(C_CurrencyInfo, ids)
      for i = 1, #ids do on[ids[i].id] = true end
      for i = 1, #list do
        local e = list[i]
        if not e.header and e.id then e.watched = on[e.id] and true or nil end
      end
    end
    if self.frame and self.frame:IsShown() then self:Paint(true) end
  end)
end

------------------------------------------------------------------------------
-- The window
------------------------------------------------------------------------------
-- The scrollbar's own arithmetic, pure so the harness drives it: how tall the thumb stands and how far down
-- it sits for a list `childH` tall in a window `view` tall, scrolled to `scroll` of a `span` that is left to
-- travel. The thumb never falls under sixteen points -- a smaller one is a mark nobody can grab -- and never
-- outstays the track. Nil means "no bar at all": the list fits.
function Pick.BarFit(span, view, childH, scroll)
  if not (span and span > 0 and view and view > 0 and childH and childH > 0) then return nil end
  local h = math.max(16, view * view / childH)
  if h > view then h = view end
  local frac = math.max(0, math.min(1, (scroll or 0) / span))
  return h, frac * (view - h)
end

-- Draws it, or takes it away. The bar hangs just outside the list's own right edge -- the panel is wider than
-- the rows on purpose, so the track is never over a row's tick box -- and the thumb is placed and sized on
-- every pass: a bar that only showed itself and left the thumb at nothing would be a mark the height of the
-- list with no answer for where in it the player stands.
function Pick:PaintBar()
  local sf, bar, thumb = self.sf, self.bar, self.thumb
  if not (sf and bar and thumb and self.child) then return end
  local view = sf:GetHeight() or 0
  local h, drop = Pick.BarFit(math.max(0, (self.child:GetHeight() or 0) - view), view,
                              self.child:GetHeight() or 0, sf:GetVerticalScroll() or 0)
  if not h then bar:Hide(); return end
  bar:Show()
  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", sf, "TOPRIGHT", 2, 0)
  bar:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 2, 0)
  thumb:SetHeight(h)
  thumb:ClearAllPoints()
  thumb:SetPoint("TOP", bar, "TOP", 0, -drop)
end

-- The theme-switch pass for the panel: repaint the shell through Panel (which retakes the theme's
-- single slot), take the slot back, and repaint the list -- fonts and the hover light included.
local function restylePicker(s)
  Theme:Panel(s, Theme:IsLight() and "bg" or "deep", "stroke")
  Theme:Track(s, restylePicker)
  Pick:Paint(true)
end

function Pick:Build()
  if self.frame then return self.frame end
  local w = CreateFrame("Frame", "WarpeeCurrencyPicker", UIParent, "BackdropTemplate")
  w:Hide()
  local bgKey = Theme:IsLight() and "bg" or "deep"
  Theme:Panel(w, bgKey, "stroke")
  w:SetFrameStrata("MEDIUM")
  w:SetToplevel(true)
  Theme:WindowArt(w)
  w:EnableMouse(true)
  w:SetClampedToScreen(true)
  ns.EscClose(w)
  ns.PixelJob(w, function(s) ns.AlignToScreen(s) end, "align")
  -- One tracked function repaints and lays out together (see the strip): Panel retakes the theme's
  -- single slot, so the wrapper repaints through it, takes the slot back, and repaints the list -- fonts
  -- and the hover light included.
  Theme:Track(w, restylePicker)
  self.frame = w
  self.rows = {}

  -- The skin's title strip (Theme:TopInset) is honoured here too: the points set at build are replaced on
  -- the first paint, but the panel must not flash its title on the band for the frame between the two. The
  -- title takes the buttons' middle from the start (its LEFT onto the frame's TOPLEFT, never the bare LEFT).
  local top = Theme:TopInset()
  local btnTop = -(PAD - 5 + top) + headerUp()
  local title = Theme:Title(w, FONT, "accent")
  title:SetPoint("LEFT", w, "TOPLEFT", PAD, btnTop - BTN / 2)
  ns.LocalText(title, "Currencies")
  self.title = title

  local close = ns.CreateGlyphButton(w, "×", BTN)
  close:SetPoint("TOPRIGHT", -(PAD - 2), btnTop)
  close:SetScript("OnClick", function() w:Hide() end)
  -- Quiet at rest, up to the white text ink under the pointer, the way the bags' header marks read.
  close.wpeIconPaint = function(s)
    ns.TintMarkX(s, (s.wpeHot and not s.offDuty) and "text" or "dim")
  end
  close.wpeIconPaint(close)
  ns.AddTip(close, "Close", "top")
  self.close = close

  -- The door to the game's own list, left of the cross: a coin that opens the character tab, where
  -- the filter lives and the transfers happen.
  local open = ns.CreateButton(w, "", BTN, BTN)
  open:SetPoint("TOPRIGHT", close, "TOPLEFT", -6, 0)
  local coin = open:CreateTexture(nil, "ARTWORK")
  coin:SetTexture([[Interface\AddOns\Warpee\Media\Icons\coin.tga]])
  coin:SetSize(14, 14)
  coin:SetPoint("CENTER", 0, 0)
  open:SetScript("OnClick", function()
    if ToggleCharacter then ToggleCharacter("TokenFrame") end
  end)
  -- The coin wears the same dim-at-rest, white-under-the-pointer ink as the header's other marks.
  open.wpeIconPaint = function(s)
    coin:SetVertexColor(Theme:C((s.wpeHot and not s.offDuty) and "text" or "dim"))
  end
  open.wpeIconPaint(open)
  ns.AddTip(open, "Opens your currencies", "top")
  self.open = open

  -- The filter, left of the coin: the whole list, or only what another character can send over -- the
  -- same cut the game's own currency tab keeps. Its face is a single down arrow with a 1px dark outline,
  -- drawn in code the way the cross and the lock are -- the kit is square textures, and no atlas of the
  -- client's reads as a transfer at this size.
  local only = ns.CreateButton(w, "", BTN, BTN)
  only:SetPoint("TOPRIGHT", open, "TOPLEFT", -6, 0)
  ns.MarkArrow(only, true)
  -- The arrow takes the header's own white ink -- lit while the filter is on or under the pointer, the
  -- row's dim grey at rest -- so the mark sits in the family of the coin and the cross beside it.
  only.wpeIconPaint = function(s)
    local lit = s.wpeOn or (s.wpeHot and not s.offDuty)
    ns.TintMarkX(s, lit and "text" or "dim")
    if s.wpeOn then
      ns.SetBg(s, Theme:C("panelHi"))
      ns.SetEdge(s, Theme:C("accent"))
    end
  end
  only.wpeOn = (WarpeeDB and WarpeeDB.curOnlyTransfer) or nil
  Pick.onlyTransfer = only.wpeOn
  only:SetScript("OnClick", function() Pick:SetOnlyTransfer(not Pick.onlyTransfer) end)
  ns.AddTip(only, "Transferable currencies only", "top")
  only:Repaint()
  self.onlyBtn = only

  local filter = ns.CreateSearchBox(w, function(text)
    self.query = text
    self:Paint()
  end)
  local searchTop = TITLE_H + PAD + top
  local head = searchTop + SEARCH_H + 8
  filter:SetPoint("TOPLEFT", PAD, -searchTop)
  filter:SetPoint("TOPRIGHT", -PAD, -searchTop)
  filter:SetHeight(SEARCH_H)
  if filter.Hint then ns.LocalText(filter.Hint, "Search") end
  self.filter = filter

  local sf = CreateFrame("ScrollFrame", nil, w)
  sf:SetPoint("TOPLEFT", PAD, -head)
  sf:SetPoint("TOPRIGHT", -(PAD + BAR_W + 2), -head)
  sf:EnableMouseWheel(true)
  local child = CreateFrame("Frame", nil, sf)
  -- The scroll frame owns this frame's corners: it clears and moves them whenever the list scrolls,
  -- so an anchored width would be wiped and the rows would collapse to nothing. The width is a
  -- number instead -- the panel's own width less its two margins and the scrollbar's track.
  child:SetPoint("TOPLEFT")
  child:SetWidth(W - PAD - (PAD + BAR_W + 2))
  sf:SetScrollChild(child)
  local function listSpan() return math.max(0, child:GetHeight() - sf:GetHeight()) end
  local function listScroll(v)
    sf:SetVerticalScroll(math.min(listSpan(), math.max(0, v or 0)))
    -- The thumb follows its own scroll, whether the wheel turned it or the hand dragged it.
    if Pick.PaintBar then Pick:PaintBar() end
  end
  sf:SetScript("OnMouseWheel", function(s, d) listScroll((s:GetVerticalScroll() or 0) - d * ROW_H * 3) end)
  self.sf, self.child = sf, child

  -- The track itself. The list leaves it the room above -- the scroll frame's own TOPRIGHT is pulled in by
  -- the bar's width and two points of air, so no row's tick box can end up under it -- and PaintBar is what
  -- anchors it, shows it, and sizes and places the thumb.
  local bar = CreateFrame("Frame", nil, w)
  bar:SetWidth(BAR_W)
  local trackTex = Theme:Rect(bar, "panel", "BACKGROUND")
  trackTex:SetAllPoints(bar)
  local thumb = CreateFrame("Frame", nil, bar)
  thumb:SetWidth(BAR_W)
  local thumbTex = Theme:Rect(thumb, "faint", "ARTWORK")
  thumbTex:SetAllPoints(thumb)
  bar:Hide()
  self.bar, self.thumb = bar, thumb
  ns.ScrollThumb(thumb, thumbTex, sf, listScroll, listSpan)

  -- The list is read when the panel opens and while it is open, never behind it.
  w:SetScript("OnShow", function() Pick:Scan() end)
  w:SetScript("OnHide", function()
    if self.filter then self.filter:ClearFocus() end
  end)
  local ev = CreateFrame("Frame", nil, w)
  ev:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
  ev:RegisterEvent("ACCOUNT_CHARACTER_CURRENCY_DATA_RECEIVED")
  ev:SetScript("OnEvent", function(_, event)
    -- The warband roster arrives late: a rescan when it lands fills the transferable rows.
    if w:IsShown() then Pick:Request() end
  end)
  self.ev = ev
  return w
end

-- Opens beside the window that asked: the panel hangs off the roomy side -- the half of the screen
-- the window's middle stands away from -- and stands level with the bags' own head, near the currency
-- switch that summoned it. The character picker uses the same top line, and the two never stand
-- together. Only a window too low for the panel's height falls back to the foot, so the list stays on
-- the screen instead of hanging below it.
function Pick:Toggle(anchor)
  applyDensity()
  local w = self:Build()
  if w:IsShown() and self.anchor == anchor then w:Hide(); return end
  -- The two side panels never stand together: this one takes the character picker down, so the pair can
  -- never crowd one flank or stack a second panel past the screen's own edge.
  if ns.CharPicker then ns.CharPicker:Close() end
  self.anchor = anchor
  self.query = nil
  if self.filter then self.filter:SetText("") end
  -- The window, not the bar: the bar hangs a full strip-height under the bags, and feet pinned to it
  -- land the panel lower than the bags' own bottom.
  local win = (anchor and anchor.frame) or anchor
  self.win = win
  -- The side the room is on: the half of the screen the window's middle stands away from. Taken as the
  -- first choice only -- the placement in Paint flips it when the character picker already stands there.
  local cx = win and win.GetCenter and win:GetCenter()
  local sw = UIParent and UIParent:GetWidth() or 0
  self.side = (cx and sw > 0 and cx < sw / 2) and "right" or "left"
  if not win then
    w:ClearAllPoints()
    w:SetPoint("CENTER")
  end
  self:Paint()
  w:Show()
end

function Pick:Close()
  if self.frame then self.frame:Hide() end
end
