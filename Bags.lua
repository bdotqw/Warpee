local addonName, ns = ...
local Theme = ns.Theme

-- The bags a character item may be set down in, the reagent bag deliberately absent: it is the one
-- container that refuses anything but its own kind, so a piece off the body can never land there and
-- StowFromCursor walks this list alone.
ns.playerBags = { 0, 1, 2, 3, 4 }
ns.reagentBag = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5

local OWN_BAGS = { [ns.reagentBag] = true }
for _, b in ipairs(ns.playerBags) do OWN_BAGS[b] = true end

function ns.IsPlayerBag(id)
  return OWN_BAGS[id] == true
end

local SIZE_DEFAULT, PAD = 37, 10
local COLS_DEFAULT, GAP_DEFAULT = 14, 4
local HEADER, FOOTER = 66, 28
local DIV = 22
local HB = 26
local ROW1_Y = 4
local SEARCH = 22
local GAUGE_Y = ROW1_Y + HB + 6
local ROW2_Y = GAUGE_Y + 6
local FONT = 15
local BAGPAD, BAGGAP = 12, 6
local HBAND = 32

local function applyDensity(size)
  local d = ns.Density(size)
  PAD, HEADER, FOOTER, DIV, HB = d.pad, d.header, d.footer, d.div, d.hb
  ROW1_Y, SEARCH = d.row1y, d.searchH
  GAUGE_Y = ROW1_Y + HB + 6
  ROW2_Y = GAUGE_Y + 6
  FONT = d.font
  BAGPAD, BAGGAP = d.bagPad, d.bagGap
  HBAND = d.headerBand
end

-- The face goes on with SetFont, never with a font object. A string that rides an object keeps
-- drawing the face that object held when its text was last written, and a glyph is written
-- once and never again, so a font picked in the settings reached these buttons only after a
-- reload: GetFont answered with the new file while the mark on screen stayed in the old one.
-- Every other window of the addon re-applies its fonts the same way, with the file itself.
local function sizeGlyph(btn, size)
  if not btn then return end
  local fp = ns.Fonts:Current()
  if btn.wpeBoxW == size and btn.wpeBoxH == size and btn.wpeFont == fp then return end
  btn.wpeFont = fp
  ns.SnapBox(btn, size, size)
  if btn.Text then btn.Text:SetFont(fp, math.max(16, math.floor(size * 0.74)), ns.OutlineFlags()) end
  if btn.icon and btn.iconPct then
    local h = btn.iconPctY or btn.iconPct
    btn.icon:SetSize(math.floor(size * btn.iconPct / 100 + 0.5), math.floor(size * h / 100 + 0.5))
  end
  btn:Repaint()
end

local Bags = { pool = {}, vpool = {}, cols = COLS_DEFAULT, gap = GAP_DEFAULT, iconSize = SIZE_DEFAULT,
               slotStyle = "tile", showGauge = true, goldLetters = false, goldOnly = false,
               font = ns.Fonts.DEFAULT, query = "", dirty = {},
               badge = ns.BadgeDefaults(),
               qualityColorIlvl = false, qualityBorder = false, iconZoom = 1, borderWidth = 2, mergeReagents = false, questMarks = false, newItemGlow = false, reagentTint = true, unusableBorder = true,
               revFill = false, fillUp = false, reagentTop = false, hideReagents = false,
               bagView = "grid",
               styleGen = 1 }
ns.Bags = Bags

-- Grid geometry and the caption ellipsis/fit now live in Theme.lua (ns.GridWidth / ns.FitLabel /
-- ns.CharStops), shared with the bank so the two windows never drift. Kept as file locals here so the
-- many call sites read unchanged.
local gridWidth = ns.GridWidth
local fitLabel = ns.FitLabel

function Bags:HeadShift()
  return self.showGauge and 0 or (ROW2_Y - GAUGE_Y + 2)
end

function Bags:BaseTop() return HEADER + 4 + Theme:TopInset() - self:HeadShift() end

-- Whether the reagent block is drawn as its own row above the main grid. The test is the one
-- Layout makes for the same question: the bag has slots to draw, it is neither merged into
-- the grid nor left out of the window, and it is set to sit on top.
function Bags:ReagentsUp()
  if self.hideReagents or self.mergeReagents or not self.reagentTop then return false end
  return (self:Slots(ns.reagentBag) or 0) > 0
end

function Bags:TopOffset()
  local rows = (self.recentH or 0) + (self.favH or 0)
  -- The rows overhead keep a gap to the grid so the two do not read as one block. A reagent
  -- block standing between them brings its own separator in the caption the block is labelled
  -- with, and the two together would leave a hole between the caption and the cells above it.
  -- Only that case drops the gap: merged reagents carry no caption, and hidden ones leave
  -- nothing behind at all. Category view drops it too: its first band already opens with a group
  -- caption that separates it from the rows above, so the extra 18 only doubled the gap.
  local sep = (rows > 0 and not self:ReagentsUp() and not self:CatMode()) and 18 or 0
  return self:BaseTop() + rows + sep
end

function Bags:FlowHeader()
  if not self.frame then return end
  local row1 = ROW1_Y + Theme:TopInset() + Theme:HeadDrop()
  self.headEdge = ns.FlowRow(self.frame, -PAD, -row1, 4,
    { self.closeBtn, self.gearBtn, self.bagsToggle, self.bankBtn,
      self.pocketBtn, self.sellBtn, self.sortBtn })
end

function Bags:AnchorHeader()
  local top = Theme:TopInset()
  local row1 = ROW1_Y + top + Theme:HeadDrop()
  sizeGlyph(self.closeBtn, HB)
  sizeGlyph(self.sortBtn, HB)
  sizeGlyph(self.gearBtn, HB)
  sizeGlyph(self.bagsToggle, HB)
  sizeGlyph(self.reagentBtn, HB)
  sizeGlyph(self.bankBtn, HB)
  sizeGlyph(self.pocketBtn, HB)
  sizeGlyph(self.sellBtn, HB)
  if self.charTag then ns.SnapBox(self.charTag, nil, HB) end
  if self.search then ns.SnapBox(self.search, nil, SEARCH) end
  self:FlowHeader()
  if self.title then
    self.title:ClearAllPoints()
    self.title:SetPoint("BOTTOMLEFT", PAD, 6)
  end
  if self.money then
    self.money:ClearAllPoints()
    self.money:SetPoint("BOTTOMRIGHT", -PAD, 6)
  end
  if self.charTag then
    self.charTag:ClearAllPoints()
    ns.SnapPoint(self.charTag, "TOPLEFT", self.frame, "TOPLEFT", PAD, -row1)
  end
  if self.gaugeBg then
    self.gaugeBg:ClearAllPoints()
    self.gaugeBg:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PAD, -(GAUGE_Y + top))
    self.gaugeBg:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -PAD, -(GAUGE_Y + top))
  end
  if self.search then
    local row2 = ROW2_Y + top - self:HeadShift()
    self.search:ClearAllPoints()
    self.search:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PAD, -row2)
    self.search:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -PAD, -row2)
  end
  Theme:HeaderBand(self.frame, HBAND)
end

function Bags:Build()
  applyDensity(self.iconSize)
  if self.frame then
    local f = self.frame
    if not self.content then self.content = CreateFrame("Frame", nil, f) end
    if not self.gaugeBg then
      local gaugeBg = Theme:Rect(f, "panel", "BACKGROUND")
      -- Above the plate: without a skin the plate spans the whole window, and a line laid on the
      -- same sublayer as it would disappear into it at any opacity above zero.
      gaugeBg:SetDrawLayer("BACKGROUND", 2)
      gaugeBg:SetHeight(2)
      self.gaugeBg = gaugeBg
    end
    if not self.gaugeFill then
      local gaugeFill = Theme:Rect(f, "accent", "ARTWORK")
      gaugeFill:SetHeight(2)
      gaugeFill:SetPoint("TOPLEFT", self.gaugeBg, "TOPLEFT")
      self.gaugeFill = gaugeFill
    end
    if not self.gridBg then
      local gridBg = Theme:Rect(f, "panel", "BACKGROUND")
      gridBg:SetDrawLayer("BACKGROUND", 1)
      self.gridBg = gridBg
    end
    if not self.money then
      local money = Theme:Label(f, FONT + 1, "text")
      Theme:Money(money)
      money:SetPoint("BOTTOMRIGHT", -PAD, 6)
      self.money = money
      ns.AttachGoldTooltip(money, f, function() return self.iconSize end)
    end
    if not self.reagentLabel then
      local rlabel = Theme:Label(self.content, FONT - 4, "reagent")
      ns.LocalText(rlabel, "REAGENTS")
      rlabel:Hide()
      self.reagentLabel = rlabel
    end
    return f
  end

  local f = CreateFrame("Frame", "WarpeeFrame", UIParent, "BackdropTemplate")
  Theme:Panel(f, "bg", "stroke")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(s) ns.DragStart(s) end)
  f:SetScript("OnDragStop", function(s)
    if not s.wpeMoving then return end
    s.wpeMoving = nil
    s:StopMovingOrSizing()
    ns.Rebase(s, "pos")
    ns.SeamDrop(s)
  end)
  -- Drop an item anywhere on the window, not only on a slot: releasing it over the background sets it
  -- down into the bags, and from there the grid puts it in the next free cell and the grouped view
  -- files it under its own category by the rules. No pin, no aim at a section — the same "just put it
  -- back" a drop on the body means. The cells sit above this and take their own drops first; this only
  -- ever fires for a release that missed them. OnReceiveDrag is the drag release, OnMouseUp the
  -- click-carry release; both read the cursor and clear it, no protected call.
  f:SetScript("OnReceiveDrag", function() Bags:DropToBackground() end)
  f:HookScript("OnMouseUp", function() Bags:DropToBackground() end)
  Theme:Window(f, "WarpeeFrame")
  Theme:HeaderBand(f, HBAND)
  f:HookScript("OnMouseDown", function()
    local P = ns.CharPicker
    if P and P.frame and P.frame:IsShown() then ns.Theme:Raise(P.frame) end
  end)
  f:SetScript("OnHide", function()
    -- However the window went away, the auto open is over: the cross, Esc, the bag key
    -- and the game's own sync all land here. Leaving the mark up made the next hand
    -- opened window read as an auto open, so it did not pull the pocket with it, and a
    -- merchant closing later shut a window the player had opened himself.
    ns.autoOpened = nil
    ns.ClearSearch(Bags.search)
    if ns.CharPicker then ns.CharPicker:Close() end
    if Bags.bagWindow then Bags.bagWindow:Hide() end
    if ns.Pocket and not ns.Pocket.solo then ns.Pocket:Close(true) end
    if ns.Vault:SetView("bags", nil) then
      Bags.snap = nil
      Bags:UpdateCharTag()
    end
  end)
  self.frame = f
  self.content = CreateFrame("Frame", nil, f)
  ns.CreateMoveBar(f, "pos")

  local title = Theme:Title(f, FONT, "accent")
  title:SetPoint("BOTTOMLEFT", PAD, 6)
  title:SetText("WARPEE")
  self.title = title

  local function addTip(btn, txt)
    ns.AddTip(btn, txt, "top")
  end

  -- The left cluster is built first, because the two things that follow it hang off the tag:
  -- the reagent switch and the slot count. AnchorHeader moves the tag on every layout and
  -- both follow, so neither needs a point written a second time.
  local charTag = ns.CreateCharTag(f, HB, "left")
  charTag:SetPoint("TOPLEFT", PAD, -ROW1_Y)
  charTag:SetScript("OnClick", function(s) Bags:ToggleCharPicker(s) end)
  ns.AddTip(charTag, "Bags of another character", "top", function(s)
    if s:IsEnabled() then return nil end
    return { { text = "Nothing saved for other characters yet", color = "dim" } }
  end)
  self.charTag = charTag

  local slots = Theme:Label(f, FONT - 3, "dim")
  slots:SetJustifyH("LEFT")
  self.slotText = slots

  local close = ns.CreateGlyphButton(f, "×", HB, "icon")
  close:SetPoint("TOPRIGHT", -PAD, -ROW1_Y)
  close:SetScript("OnClick", function() ns.Toggle(false) end)
  self.closeBtn = close

  local sort = ns.CreateGlyphButton(f, "", HB, "icon")
  sort:SetScript("OnClick", function() Bags:SortBags() end)
  addTip(sort, "Clean up bags")
  local sortIcon = sort:CreateTexture(nil, "ARTWORK")
  sortIcon:SetAtlas("auctionhouse-ui-sortarrow")
  sortIcon:SetSize(13, 15)
  sortIcon:SetPoint("CENTER")
  sortIcon:SetVertexColor(Theme:C("overlay"))
  Theme:Track(sortIcon, function(x) x:SetVertexColor(Theme:C("overlay")) end)
  sort.icon = sortIcon
  sort.iconPct, sort.iconPctY = 50, 58
  sort.wpeIconPaint = function(s)
    if s.icon then s.icon:SetVertexColor(Theme:C("overlay")) end
  end
  self.sortBtn = sort

  local gear = ns.CreateGlyphButton(f, "|TInterface\\Buttons\\UI-OptionsButton:13:13:0:0|t", HB, "icon")
  gear:SetPoint("TOPRIGHT", close, "TOPLEFT", -4, 0)
  gear:SetScript("OnClick", function() if ns.Options then ns.Options:Toggle() end end)
  addTip(gear, "Settings")
  self.gearBtn = gear

  local bagsToggle = ns.CreateGlyphButton(f, "", HB, "icon")
  bagsToggle:SetPoint("TOPRIGHT", gear, "TOPLEFT", -4, 0)
  bagsToggle:SetScript("OnClick", function() Bags:ToggleBagWindow() end)
  addTip(bagsToggle, "Bags")
  local bagIcon = bagsToggle:CreateTexture(nil, "ARTWORK")
  bagIcon:SetAtlas("bag-main")
  bagIcon:SetSize(22, 22)
  bagIcon:SetPoint("CENTER")
  bagIcon:SetVertexColor(Theme:IconTint())
  Theme:Track(bagIcon, function(x) x:SetVertexColor(Theme:IconTint()) end)
  bagsToggle.icon = bagIcon
  bagsToggle.iconPct = 85
  bagsToggle.wpeIconPaint = function(s)
    if s.icon then s.icon:SetVertexColor(Theme:IconTint()) end
  end
  self.bagsToggle = bagsToggle

  -- Reagents, on the switch the settings already had. It stands with the tag and the count
  -- rather than in the button row: the count still includes the reagent slots while they are
  -- hidden, so the control that hides the block belongs beside the number that keeps counting
  -- it. The row is also the wrong place for an eighth button, since it is already wider than
  -- the narrowest the window can be.
  local reags = ns.CreateGlyphButton(f, "", HB, "icon")
  reags:SetPoint("LEFT", charTag, "RIGHT", 4, 0)
  reags:SetScript("OnClick", function() Bags:ToggleReagents() end)
  addTip(reags, "Hide reagents")
  local reagsIcon = reags:CreateTexture(nil, "ARTWORK")
  local reagsAtlas = C_Texture and C_Texture.GetAtlasInfo
                     and C_Texture.GetAtlasInfo("bags-icon-reagents")
  if reagsAtlas then
    reagsIcon:SetAtlas("bags-icon-reagents")
  else
    reagsIcon:SetTexture("Interface\\Icons\\INV_Misc_Bag_EnchantedMageweave")
  end
  reagsIcon:SetSize(20, 20)
  reagsIcon:SetPoint("CENTER")
  reags.icon = reagsIcon
  reags.iconPct = 77
  reags.wpeIconPaint = function(s) Bags:PaintReagents(s) end
  self.reagentBtn = reags
  Bags:PaintReagents(reags)

  slots:SetPoint("LEFT", reags, "RIGHT", 10, 0)

  local bank = ns.CreateGlyphButton(f, "", HB, "icon")
  bank:SetPoint("TOPRIGHT", bagsToggle, "TOPLEFT", -4, 0)
  bank:SetScript("OnClick", function() if ns.ToggleBank then ns.ToggleBank() end end)
  ns.AddTip(bank, "Bank / Warband", "top", function(s)
    if s:IsEnabled() then return nil end
    return { { text = "Visit a banker to record this bank", color = "dim" } }
  end)
  local bankIcon = bank:CreateTexture(nil, "ARTWORK")
  local atlasOK = C_Texture and C_Texture.GetAtlasInfo
                  and C_Texture.GetAtlasInfo("Minimap_tracking_banker")
  if atlasOK then
    bankIcon:SetAtlas("Minimap_tracking_banker")
  else
    bankIcon:SetTexture("Interface\\Minimap\\Tracking\\Banker")
  end
  bankIcon:SetSize(20, 20)
  bankIcon:SetPoint("CENTER")
  bankIcon:SetVertexColor(Theme:IconTint())
  Theme:Track(bankIcon, function(x) x:SetVertexColor(Theme:IconTint()) end)
  bank.icon = bankIcon
  bank.iconPct = 77
  bank.wpeIconPaint = function(s)
    if s.icon then s.icon:SetVertexColor(Theme:IconTint()) end
  end
  self.bankBtn = bank

  sort:SetPoint("TOPRIGHT", bank, "TOPLEFT", -4, 0)

  local sell = ns.CreateGlyphButton(f, "", HB, "icon")
  sell:SetPoint("TOPRIGHT", sort, "TOPLEFT", -4, 0)
  sell:SetScript("OnClick", function() if ns.Vendor then ns.Vendor:Sell() end end)
  ns.AddTip(sell, "Sell now", "top", function()
    return ns.Vendor and ns.Vendor:TipLines() or nil
  end)
  local sellIcon = sell:CreateTexture(nil, "ARTWORK")
  sellIcon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
  sellIcon:SetSize(16, 16)
  sellIcon:SetPoint("CENTER")
  sellIcon:SetDesaturated(true)
  sellIcon:SetAlpha(0.45)
  sellIcon:SetVertexColor(Theme:IconTint())
  Theme:Track(sellIcon, function(x) x:SetVertexColor(Theme:IconTint()) end)
  sell.icon = sellIcon
  sell.iconPct = 61
  sell.wpeIconPaint = function(s)
    if s.icon then s.icon:SetVertexColor(Theme:IconTint()) end
  end
  ns.SetButtonEnabled(sell, false)
  self.sellBtn = sell

  local pocket = ns.CreateGlyphButton(f, "", HB, "icon")
  pocket:SetPoint("TOPRIGHT", sell, "TOPLEFT", -4, 0)
  pocket:SetScript("OnClick", function() if ns.Pocket then ns.Pocket:Toggle() end end)
  addTip(pocket, "Pocket")
  local dots = {}
  for k = 1, 6 do dots[k] = Theme:Rect(pocket, "overlay", "ARTWORK") end
  ns.PixelJob(pocket, function(s)
    local d, sp = ns.PX(s, 4), ns.PX(s, 2)
    local gw, gh = 3 * d + 2 * sp, 2 * d + sp
    for k = 1, 6 do
      local col, row = (k - 1) % 3, math.floor((k - 1) / 3)
      dots[k]:SetSize(d, d)
      dots[k]:ClearAllPoints()
      dots[k]:SetPoint("TOPLEFT", s, "CENTER",
                       -gw / 2 + col * (d + sp), gh / 2 - row * (d + sp))
    end
  end, "pocket")
  self.pocketBtn = pocket

  local search = ns.CreateSearchBox(f, function(text)
    self.query = (text or ""):lower()
    self.filters = ns.ParseSearch(self.query)
    -- The dim on a miss is instant either way, it only repaints cells in place. Category view also
    -- narrows the pass to the sections the query hits, but doing that on every keystroke made them
    -- jump in and out mid-word. So the narrowing is deferred to a short pause after the last key:
    -- you type freely, the layout settles once. Grid never narrows, so it only ever repaints.
    self:ApplySearch()
    if self:CatMode() then self:ScheduleCatFold() end
    ns.MirrorSearch("bags", text)
  end)
  search:SetPoint("TOPLEFT", PAD, -ROW2_Y)
  search:SetPoint("TOPRIGHT", -PAD, -ROW2_Y)
  search:SetHeight(SEARCH)
  self.search = search

  local gaugeBg = Theme:Rect(f, "panel", "BACKGROUND")
  gaugeBg:SetDrawLayer("BACKGROUND", 2)
  gaugeBg:SetHeight(2)
  gaugeBg:SetPoint("TOPLEFT", PAD, -GAUGE_Y)
  gaugeBg:SetPoint("TOPRIGHT", -PAD, -GAUGE_Y)
  local gaugeFill = Theme:Rect(f, "accent", "ARTWORK")
  gaugeFill:SetHeight(2)
  gaugeFill:SetPoint("TOPLEFT", gaugeBg, "TOPLEFT")
  self.gaugeBg, self.gaugeFill = gaugeBg, gaugeFill

  local content = self.content

  local gridBg = Theme:Rect(f, "panel", "BACKGROUND")
  gridBg:SetDrawLayer("BACKGROUND", 1)
  self.gridBg = gridBg

  local money = Theme:Label(f, FONT + 1, "text")
  Theme:Money(money)
  money:SetPoint("BOTTOMRIGHT", -PAD, 6)
  self.money = money
  ns.AttachGoldTooltip(money, f, function() return self.iconSize end)

  local rlabel = Theme:Label(content, FONT - 4, "reagent")
  ns.LocalText(rlabel, "REAGENTS")
  rlabel:Hide()
  self.reagentLabel = rlabel

  f:Hide()
  return f
end

function Bags:BuildBagWindow()
  if self.bagWindow then return self.bagWindow end
  local BPAD = BAGPAD
  local w = CreateFrame("Frame", "WarpeeBagsWindow", UIParent, "BackdropTemplate")
  Theme:Panel(w, "bg", "stroke")
  Theme:WindowArt(w)
  w:SetFrameStrata("MEDIUM")
  w:SetToplevel(true)
  w:SetClampedToScreen(true)
  w:SetMovable(true); w:EnableMouse(true)
  w:RegisterForDrag("LeftButton")
  w:SetScript("OnDragStart", function(s) ns.DragStart(s) end)
  w:SetScript("OnDragStop", function(s)
    if not s.wpeMoving then return end
    s.wpeMoving = nil
    s:StopMovingOrSizing()
    local pp, rp, x, y = ns.SnapFrame(s)
    if pp then WarpeeDB.bagWinPos = { p = pp, rp = rp, x = x, y = y } end
    if ns.Profiles and ns.Profiles.SyncActive then ns.Profiles:SyncActive() end
  end)
  ns.EscClose(w)

  local title = Theme:Title(w, FONT - 1, "accent")
  title:SetPoint("TOPLEFT", BPAD, -8)
  ns.LocalText(title, "BAGS")
  self.bagTitle = title

  local wclose = ns.CreateGlyphButton(w, "×")
  wclose:SetPoint("TOPRIGHT", -6, -6)
  wclose:SetScript("OnClick", function() w:Hide() end)
  self.bagWinClose = wclose

  local bagList = { 0, 1, 2, 3, 4, ns.reagentBag }
  self.bagButtons = {}
  for _, bagID in ipairs(bagList) do
    self.bagButtons[#self.bagButtons + 1] = ns.CreateBagButton(w, bagID, self:BagWinButtonSize())
  end
  w:Hide()
  self.bagWindow = w
  self:LayoutBagWindow()
  return w
end

function Bags:BagWinButtonSize()
  return self.iconSize or 37
end

function Bags:LayoutBagWindow()
  local w = self.bagWindow
  if not w or not self.bagButtons then return end
  sizeGlyph(self.bagWinClose, HB - 4)
  local BGAP, BPAD = BAGGAP, BAGPAD
  local BBAND = 26
  local size = self:BagWinButtonSize()
  local cf = ns.Badge("count").s
  local band = Theme:HeaderBand(w, BBAND)
  local BHEAD = band and (band + 6) or (30 + Theme:TopInset())
  local mid = (band or BHEAD) / 2 + Theme:TitleDrop()
  if self.bagTitle then
    self.bagTitle:ClearAllPoints()
    self.bagTitle:SetPoint("LEFT", w, "TOPLEFT", BPAD, -mid)
  end
  if self.bagWinClose then
    self.bagWinClose:ClearAllPoints()
    ns.SnapPoint(self.bagWinClose, "RIGHT", w, "TOPRIGHT", -6, -mid)
  end
  local prev
  for _, b in ipairs(self.bagButtons) do
    b:SetSize(size, size)
    b:ClearAllPoints()
    if prev then b:SetPoint("LEFT", prev, "RIGHT", BGAP, 0)
    else b:SetPoint("TOPLEFT", BPAD, -BHEAD) end
    b.cntFontSize = cf
    if b.count then
      b.count:ClearAllPoints()
      b.count:SetPoint("BOTTOMRIGHT", -3, 3)
    end
    prev = b
  end
  local n = #self.bagButtons
  w:SetSize(BPAD * 2 + n * size + (n - 1) * BGAP, BHEAD + size + BPAD)
  self:UpdateBagBar()
end

function Bags:ToggleBagWindow()
  local w = self:BuildBagWindow()
  if w:IsShown() then w:Hide(); return end
  w:ClearAllPoints()
  local pp = WarpeeDB and WarpeeDB.bagWinPos
  if pp then
    ns.SnapPoint(w, pp.p, UIParent, pp.rp, pp.x, pp.y)
  elseif self.frame then
    ns.SnapPoint(w, "BOTTOMLEFT", self.frame, "TOPLEFT", 0, 6)
  else
    w:SetPoint("CENTER")
  end
  self:LayoutBagWindow()
  w:Show()
  ns.Theme:Raise(w)
  self:UpdateBagBar()
end

function Bags:ReagentsHidden() return self.hideReagents and true or false end

-- The icon carries the state: full colour while the reagent bag is in the grid, dull once it
-- is left out. Called from the button's own Repaint as well, so a theme or a profile change
-- arrives here without the header having to know about it.
function Bags:PaintReagents(b)
  b = b or self.reagentBtn
  if not (b and b.icon) then return end
  local off = self:ReagentsHidden()
  b.icon:SetVertexColor(Theme:IconTint())
  b.icon:SetDesaturated(off)
  b.icon:SetAlpha(off and 0.45 or 1)
end

-- The same key the settings row writes, from the other end of the window. Layout is the whole
-- of it: nothing outside the bag grid reads this, and the pocket and the bank keep their own.
function Bags:ToggleReagents()
  local v = not self:ReagentsHidden()
  self.hideReagents = v
  if WarpeeDB then WarpeeDB.hideReagents = v end
  if self.frame and self.frame:IsShown() then self:Layout() else self:PaintReagents() end
  if ns.Options and ns.Options.Refresh then ns.Options:Refresh() end
end

function Bags:Acquire(i)
  if self.snap then
    local b = self.vpool[i]
    if not b then
      b = ns.CreateVaultButton(self.content)
      self.vpool[i] = b
    end
    return b
  end
  local b = self.pool[i]
  if not b then
    if InCombatLockdown() then self.cold = true; return nil end
    b = ns.CreateItemButton(self.content, 0, 1)
    self.pool[i] = b
  end
  return b
end

function Bags:Warm()
  if InCombatLockdown() or not self.content then return end
  local n = 0
  for _, bag in ipairs(ns.playerBags) do
    n = n + (C_Container.GetContainerNumSlots(bag) or 0)
  end
  n = n + (C_Container.GetContainerNumSlots(ns.reagentBag) or 0)
  if n == 0 then return end
  for i = 1, n do
    if not self.pool[i] then
      self.pool[i] = ns.CreateItemButton(self.content, 0, 1)
    end
  end
  self.warmed, self.cold = true, nil
end

function Bags:Pool()
  return self.snap and self.vpool or self.pool
end

function Bags:Slots(bag)
  if self.snap then return ns.Vault:Count("bags", bag) end
  return C_Container.GetContainerNumSlots(bag) or 0
end

function Bags:Taken(bag)
  if self.snap then return ns.Vault:Used("bags", bag) end
  local num = C_Container.GetContainerNumSlots(bag) or 0
  return num - (select(1, C_Container.GetContainerNumFreeSlots(bag)) or 0)
end

function Bags:Restyle()
  self.styleGen = (self.styleGen or 0) + 1
  if self.frame and self.frame:IsShown() then self:Layout() end
end

function Bags:Layout(capture)
  applyDensity(self.iconSize)
  ns.ReportEntry()
  self:Build()
  if not (self.frame and self.content and self.gaugeBg and self.gaugeFill
          and self.gridBg and self.money and self.reagentLabel) then return end
  local cols = self.cols
  self:AnchorHeader()
  local size, gap, step = ns.GridMetrics(self.frame, self.iconSize, self.gap)
  self.pxSize, self.pxGap = size, gap
  local i, used, total = 0, 0, 0
  self.byKey = {}
  self.bagSlots = self.bagSlots or {}
  self.fontPath = ns.Fonts:Current()
  if self.title then self.title:SetFont(self.fontPath, FONT, ns.OutlineFlags()) end
  if self.money then
    self.money:SetFont(self.fontPath, FONT + 1, ns.OutlineFlags())
    Theme:Money(self.money)
  end
  if self.reagentLabel then self.reagentLabel:SetFont(self.fontPath, FONT - 4, ns.OutlineFlags()) end
  if self.slotText then self.slotText:SetFont(self.fontPath, FONT - 3, ns.OutlineFlags()) end
  if self.search then
    self.search:SetFont(self.fontPath, FONT - 2, ns.OutlineFlags())
    if self.search.Hint then self.search.Hint:SetFont(self.fontPath, FONT - 2, ns.OutlineFlags()) end
  end
  if self.charTag then self.charTag.Text:SetFont(self.fontPath, FONT - 3, ns.OutlineFlags()); self:UpdateCharTag() end
  if self.frame and self.frame.wpeBar then
    self.frame.wpeBar:Fonts(self.fontPath, FONT - 4)
    self.frame.wpeBar:Size(ns.Density(self.iconSize).moveH)
  end

  -- Recent and Favorites are this character's own live lists, not part of a snapshot: showing them
  -- over another character's cached bags read as if that character had recently touched your items.
  -- So while a foreign snapshot is up they are hidden outright and reserve no height; the window is
  -- purely the cached grid. They come back the moment the view returns to the owner.
  if self.snap then
    if ns.Recent and ns.Recent.Hide then ns.Recent:Hide() end
    if ns.Fav and ns.Fav.Hide then ns.Fav:Hide() end
    self.recentH, self.favH = 0, 0
  else
    self.recentH = ns.Recent and ns.Recent:Apply(self, PAD, self:BaseTop(), size, gap) or 0
    self.favH = ns.Fav and ns.Fav:Apply(self, PAD, self:BaseTop() + self.recentH, size, gap) or 0
  end

  self.content:ClearAllPoints()
  ns.SnapPoint(self.content, "TOPLEFT", self.frame, "TOPLEFT", PAD, -self:TopOffset())

  local function place(bag, slot, x, y)
    i = i + 1
    local b = self:Acquire(i)
    if not b then return end
    local h = b.holder
    -- Same memo the bank window keeps: the anchor parent is made once and never
    -- recreated, so a cell that has not moved does not need its id, its size or its
    -- point written again. Only the content is repainted either way.
    if b.wpeBag ~= bag or b.wpeSlot ~= slot then
      if not self.snap then
        h:SetID(bag)
        b:SetID(slot)
        b.wpeBagID = bag
      end
      b.wpeBag, b.wpeSlot = bag, slot
    end
    if b.wpeSize ~= size then ns.SnapSize(h, size, size); b.wpeSize = size end
    if b.wpeX ~= x or b.wpeY ~= y then
      h:ClearAllPoints()
      ns.SnapPoint(h, "TOPLEFT", self.content, "TOPLEFT", x, y)
      b.wpeX, b.wpeY = x, y
    end
    b.link = nil
    h:Show(); b:Show()
    if self.snap then
      ns.PaintVaultButton(b, ns.Vault:Slot("bags", bag, slot), bag)
    else
      ns.UpdateItemButton(b)
    end
    self.byKey[bag * 1000 + slot] = b
  end

  local contentH
  if self:CatMode() then
    self.reagentLabel:Hide()
    contentH, used, total = self:LayoutCats(place, size, gap, step, cols)
  else
    -- Every section widget, not just the captions: the headers, drop zones and the Empty section's
    -- sample tiles are all pooled and only hidden from the tail inside LayoutCats, which the grid
    -- branch never runs. Left alone they linger over the grid as stray captions and two empty cells
    -- after a switch back from grouped view.
    self:HideCatLabels(0)
    self:HideCatCounts(0)
    self:HideCatHeaders(0)
    self:HideCatZones(0)
    self:HideCatGroups(0)
    self:HideEmptyTiles(0)
    if self.catFree then self.catFree:Hide() end
    local n = 0
    local hide = self.hideReagents and true or false
    local merge = (not hide) and self.mergeReagents and true or false
    local rnum = self:Slots(ns.reagentBag)
    self.bagSlots[ns.reagentBag] = rnum
    local split = (not hide) and (not merge) and rnum > 0
    local mainCount = merge and rnum or 0
    for _, bag in ipairs(ns.playerBags) do mainCount = mainCount + self:Slots(bag) end
    local mainRows = math.max(1, math.ceil(mainCount / cols))
    local rRows = split and math.max(1, math.ceil(rnum / cols)) or 0
    local rBlock = split and ((rRows - 1) * step + size) or 0
    local onTop = split and self.reagentTop and true or false
    local mainTop = onTop and (rBlock + DIV * 2) or 0
    local mainBottom = mainTop + (mainRows - 1) * step + size
    local rTop = onTop and DIV or (mainBottom + DIV)

    local function cellXY(k, count, rows, top)
      local j = self.revFill and (count - k + 1) or k
      local col, row = (j - 1) % cols, math.floor((j - 1) / cols)
      if self.fillUp then row = rows - 1 - row end
      return col * step, -(top + row * step)
    end

    for _, bag in ipairs(ns.playerBags) do
      local num = self:Slots(bag)
      self.bagSlots[bag] = num
      for slot = 1, num do
        n = n + 1
        place(bag, slot, cellXY(n, mainCount, mainRows, mainTop))
      end
      total = total + num
      used = used + self:Taken(bag)
    end
    if rnum > 0 then
      total = total + rnum
      used = used + self:Taken(ns.reagentBag)
      if merge then
        for slot = 1, rnum do
          n = n + 1
          place(ns.reagentBag, slot, cellXY(n, mainCount, mainRows, mainTop))
        end
      end
    end

    contentH = mainBottom
    if split then
      self.reagentLabel:ClearAllPoints()
      self.reagentLabel:SetPoint("TOPLEFT", self.content, "TOPLEFT", 2, -(rTop - DIV + 6))
      self.reagentLabel:Show()
      for slot = 1, rnum do
        place(ns.reagentBag, slot, cellXY(slot, rnum, rRows, rTop))
      end
      if not onTop then contentH = rTop + rBlock end
    else
      self.reagentLabel:Hide()
    end
  end

  local active, idle = self:Pool(), (self.snap and self.pool or self.vpool)
  for j = i + 1, #active do active[j].holder:Hide() end
  for _, b in ipairs(idle) do if b.holder:IsShown() then b.holder:Hide() end end
  -- Sorting is a grid idea: it reorders the live bag slots. Category view groups by rule and draws
  -- each section in its own order, so the button has nothing to act on there and is hidden.
  if self.sortBtn then self.sortBtn:SetShown(not self.snap and not self:CatMode()) end
  if self.reagentBtn then self:PaintReagents() end
  if self.pocketBtn then
    self.pocketBtn:SetShown((ns.Pocket and ns.Pocket:Enabled()) and true or false)
  end
  self:VendorState()
  -- The snapshot is the one thing here that costs a scan of every bag, and a plain
  -- repaint cannot change it: same cells, same contents, same picture. Only the points
  -- that open the window or move what is in it ask for the capture.
  if capture and not self.snap then ns.Vault:Capture("bags") end
  self:BrowseState()
  self.shown, self.used, self.total = i, used, total
  self:Resize(contentH)
  if self.bagWindow and self.bagWindow:IsShown() then self:LayoutBagWindow() end
  self:UpdateMeta()
  self:ApplySearch()
  if ns.Pocket then ns.Pocket:Refresh() end
end

-- Taint: the category view makes no cell of its own. It reuses the same pooled buttons the grid
-- places, re-bound to their slot by the shared placer, so the live window's secure right click and
-- drag stay intact and no new taint surface appears. A snapshot groups too: it draws the same
-- display-only vault cells the grid draws for a cached character, bucketed from the Vault record
-- instead of a live container, so there is still nothing secure to taint.
function Bags:CatMode()
  return self.bagView == "cat"
end

-- One pooled caption per section, kept on the content frame so it moves with the cells.
function Bags:CatLabel(i)
  self.catLabels = self.catLabels or {}
  local fs = self.catLabels[i]
  if not fs then
    fs = Theme:Label(self.content, FONT - 4, "dim")
    fs:SetJustifyH("LEFT")
    self.catLabels[i] = fs
  end
  return fs
end

function Bags:HideCatLabels(from)
  if not self.catLabels then return end
  for i = (from or 0) + 1, #self.catLabels do
    if self.catLabels[i] then self.catLabels[i]:Hide() end
  end
end

-- The count that rides opposite each caption, one pooled fontstring per section like the label,
-- right justified so it lands on the grid's own edge.
function Bags:CatCount(i)
  self.catCounts = self.catCounts or {}
  local fs = self.catCounts[i]
  if not fs then
    fs = Theme:Label(self.content, FONT - 4, "dim")
    fs:SetJustifyH("RIGHT")
    self.catCounts[i] = fs
  end
  return fs
end

function Bags:HideCatCounts(from)
  if not self.catCounts then return end
  for i = (from or 0) + 1, #self.catCounts do
    if self.catCounts[i] then self.catCounts[i]:Hide() end
  end
end

-- A band carries no bag and no slot, so it is display only and adds no taint surface.
function Bags:CatGroupLine(i)
  self.catGLines = self.catGLines or {}
  local t = self.catGLines[i]
  if not t then
    t = Theme:Rect(self.content, "strokeSoft", "ARTWORK")
    ns.PixelLine(t, 1)
    self.catGLines[i] = t
  end
  return t
end

function Bags:CatGroupLabel(i)
  self.catGLabels = self.catGLabels or {}
  local fs = self.catGLabels[i]
  if not fs then
    fs = Theme:Label(self.content, FONT - 2, "azure")
    fs:SetJustifyH("LEFT")
    self.catGLabels[i] = fs
  end
  return fs
end

function Bags:CatGroupCaret(i)
  self.catGCarets = self.catGCarets or {}
  local t = self.catGCarets[i]
  if not t then
    t = ns.Triangle(self.content, "down", 9, 9, "dim")
    self.catGCarets[i] = t
  end
  return t
end

function Bags:CatGroupCount(i)
  self.catGCounts = self.catGCounts or {}
  local fs = self.catGCounts[i]
  if not fs then
    fs = Theme:Label(self.content, FONT - 4, "dim")
    fs:SetJustifyH("LEFT")
    self.catGCounts[i] = fs
  end
  return fs
end

function Bags:CatGroupHead(i)
  self.catGHeads = self.catGHeads or {}
  local b = self.catGHeads[i]
  if not b then
    b = CreateFrame("Button", nil, self.content)
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnClick", function(s)
      if not s.wpeEntry then return end
      if (self.query or "") ~= "" then return end
      if IsShiftKeyDown() then
        ns.Categories:SetAllFolded(not ns.Categories:Folded(s.wpeEntry))
      else
        ns.Categories:ToggleFold(s.wpeEntry)
      end
      self:Layout()
    end)
    b:SetScript("OnEnter", function(s)
      if s.wpeCaret then s.wpeCaret:SetTint("accent") end
      if s.wpeLabel then s.wpeLabel:SetTextColor(Theme:C("accentInk")) end
    end)
    b:SetScript("OnLeave", function(s)
      if s.wpeCaret then s.wpeCaret:SetTint("dim") end
      if s.wpeLabel then s.wpeLabel:SetTextColor(Theme:C("azure")) end
    end)
    self.catGHeads[i] = b
  end
  return b
end

function Bags:HideCatGroups(from)
  local from = (from or 0) + 1
  if self.catGLines then
    for i = from, #self.catGLines do if self.catGLines[i] then self.catGLines[i]:Hide() end end
  end
  if self.catGLabels then
    for i = from, #self.catGLabels do if self.catGLabels[i] then self.catGLabels[i]:Hide() end end
  end
  if self.catGCarets then
    for i = from, #self.catGCarets do if self.catGCarets[i] then self.catGCarets[i]:Hide() end end
  end
  if self.catGCounts then
    for i = from, #self.catGCounts do if self.catGCounts[i] then self.catGCounts[i]:Hide() end end
  end
  if self.catGHeads then
    for i = from, #self.catGHeads do if self.catGHeads[i] then self.catGHeads[i]:Hide() end end
  end
end

-- The click target over a caption strip: a transparent pooled button covering the caption row, so a
-- piece on the cursor can be dropped anywhere along the strip to be filed by hand. It carries the
-- section id, set fresh each layout. Hover tints the caption so the whole strip reads as one target.
function Bags:CatHeader(i)
  self.catHeaders = self.catHeaders or {}
  local btn = self.catHeaders[i]
  if not btn then
    btn = CreateFrame("Button", nil, self.content)
    btn:RegisterForClicks("LeftButtonUp")
    -- A drop on a caption sets the piece down like a drop anywhere else on the body: it joins the bags
    -- and files under its own category by the rules, no forced pin to this section. DropToBackground
    -- handles the worn-piece unequip and clears the cursor.
    local function drop() self:DropToBackground() end
    btn:SetScript("OnReceiveDrag", drop)
    btn:SetScript("OnClick", drop)
    btn:SetScript("OnEnter", function(s)
      if s.wpeLabel then s.wpeLabel:SetTextColor(Theme:C("accentInk")) end
      -- A caption cut to fit its section shows the whole name on hover, so nothing is lost to the
      -- ellipsis. Only a truncated one gets the tooltip; a name that fit reads for itself.
      if s.wpeFull and s.wpeCut then
        GameTooltip:SetOwner(s, "ANCHOR_TOPLEFT")
        GameTooltip:SetText(s.wpeFull)
        GameTooltip:Show()
      end
    end)
    btn:SetScript("OnLeave", function(s)
      -- Back to the caption's resting tone, which the layout paints accent; a lesser tone here would
      -- leave any header the cursor crossed stuck dim while its untouched neighbours kept the accent.
      if s.wpeLabel then s.wpeLabel:SetTextColor(Theme:C("accent")) end
      GameTooltip:Hide()
    end)
    self.catHeaders[i] = btn
  end
  return btn
end

function Bags:HideCatHeaders(from)
  if not self.catHeaders then return end
  for i = (from or 0) + 1, #self.catHeaders do
    if self.catHeaders[i] then self.catHeaders[i]:Hide() end
  end
end

-- Does the piece riding the cursor come off the character rather than out of a bag? A worn piece is
-- dropped onto the bag area, not filed, so it has to be set down first: clearing the cursor would
-- only snap it back onto the body. C_Cursor.GetCursorItem is the only reader that answers this.
-- GetCursorInfo returns "item", id and link but never says where the piece was lifted from, while
-- the location it returns keeps the slot it came from and stays readable for the whole drag (the
-- game's own container handlers read it mid-drag the same way). Read-only, and nil-safe for a
-- spell or money on the cursor, which have no location at all.
function Bags:CursorIsEquipped()
  if not (C_Cursor and C_Cursor.GetCursorItem) then return false end
  local loc = C_Cursor.GetCursorItem()
  return (loc and loc.IsEquipmentSlot and loc:IsEquipmentSlot()) and true or false
end

-- Does the piece on the cursor already live in one of these bags? A drop on the window body of an item
-- that came out of the same bags is a "missed the cell" and should go back to its own slot untouched,
-- not relocate; a piece held from anywhere else (a worn slot, the bank, the warband bank) is placed
-- into a free slot instead. Read-only, nil-safe for a spell or money on the cursor.
function Bags:CursorInBags()
  if not (C_Cursor and C_Cursor.GetCursorItem) then return false end
  local loc = C_Cursor.GetCursorItem()
  if not (loc and loc.IsBagAndSlot and loc:IsBagAndSlot()) then return false end
  local bag = loc:GetBagAndSlot()
  for _, b in ipairs(ns.playerBags) do if b == bag then return true end end
  return false
end

-- Set a worn piece down into the first bag with room, which is the unequip. PutItemInBag wants the
-- bag's inventory slot, not its container id, so the worn bag is translated first; the backpack has
-- no inventory slot and goes through PutItemInBackpack. Neither is protected, and both are driven by
-- the player's own hardware click, so this runs from our drop handler exactly as it would from the
-- game's own bag-slot buttons. True once the piece left the cursor.
function Bags:StowFromCursor()
  for _, bag in ipairs(ns.playerBags) do
    if CursorHasItem() then
      if (select(1, C_Container.GetContainerNumFreeSlots(bag)) or 0) > 0 then
        if bag == 0 then PutItemInBackpack() else PutItemInBag(C_Container.ContainerIDToInventoryID(bag)) end
      end
    end
  end
  return not CursorHasItem()
end

-- Set the held item down when a drop lands on the window body instead of a cell. Where it goes depends
-- on where it was lifted from: a piece already out of these bags (a missed cell) goes back to its own
-- slot on ClearCursor, untouched; anything from elsewhere — a worn slot, the bank, the warband bank,
-- any window that hands the cursor an item — is placed into the first free bag slot, which is the
-- "drag it into the bags" the player means. StowFromCursor does that placement through the same
-- PutItemInBag/PutItemInBackpack the game's own bag buttons use, so it is taint free and works from
-- the bank the same as from the character. The grouped view then files it under its category by the
-- rules; there is no pin and no section to aim at. No-op on an empty cursor (every ordinary click).
function Bags:DropToBackground()
  local ctype = GetCursorInfo()
  if ctype ~= "item" then return end
  if not self:CursorInBags() then
    -- A piece from these same bags is only being set back down; the game returns it to its slot when
    -- the cursor clears. Anything from outside (worn, bank, warband) is stowed into a free slot.
    -- StowFromCursor no-ops if the bags are full, leaving the piece to place by hand.
    self:StowFromCursor()
  end
  ClearCursor()
  self:Layout()
  if ns.Options and ns.Options.RefreshOpen then ns.Options:RefreshOpen() end
end

-- The drop target for filing an item by hand. Dropping on the thin caption alone was the "where do
-- I even aim" complaint, so while an item rides the cursor the whole section lights up as one zone:
-- release anywhere on it to file the held item under that section. The zone sits above the cells
-- and shows only mid drag (SyncDropZones on CURSOR_CHANGED), so with no item held a click still
-- reaches the cell beneath. The item was lifted by the cell's own secure drag, the player's
-- hardware click; here we only read the cursor and clear it, no protected call. Other takes no drop,
-- so its zone never lights; Empty is the unfile target.
function Bags:CatZone(i)
  self.catZones = self.catZones or {}
  local z = self.catZones[i]
  if not z then
    z = CreateFrame("Button", nil, self.content, "BackdropTemplate")
    z:SetFrameLevel(self.content:GetFrameLevel() + 60)
    z:RegisterForClicks("LeftButtonUp")
    -- Fully transparent: no fill, no edge. The section a drop lands in is named by the floating pill
    -- that tracks the cursor, not by an outline drawn on the section, so a hovered zone shows no border
    -- and hides nothing. The box only has to catch the release over the whole section extent.
    ns.PixelBackdrop(z)
    ns.SetBg(z, 0, 0, 0, 0)
    ns.SetEdge(z, 0, 0, 0, 0)
    -- A drop on a section files the held item into it by hand: it moves the piece from whatever
    -- category held it into this one. A worn piece is set down into the bags first (the unequip), then
    -- filed; a piece already in the bags is only re-filed, it does not move slot. The lift was the
    -- cell's own secure drag (the player's hardware click); here we read the cursor and clear it, no
    -- protected call. Other takes no drop (its slots are the catch-all), Empty is the unfile target.
    local function drop(s)
      if s.wpeId == ns.Categories.OTHER_ID then return end
      local ctype, id = GetCursorInfo()
      if ctype == "item" and id then
        if self:CursorIsEquipped() then self:StowFromCursor() end
        ns.Categories:PinItem(id, s.wpeId)
        ClearCursor()
      end
      self:HideDropPill()
      self:Layout()
      if ns.Options and ns.Options.RefreshOpen then ns.Options:RefreshOpen() end
    end
    z:SetScript("OnReceiveDrag", drop)
    z:SetScript("OnClick", drop)
    -- The floating pill names the section under the cursor while a piece is held, so the target reads
    -- at a glance without a name printed across every section at once. Only the hovered zone shows it.
    z:SetScript("OnEnter", function(s) self:ShowDropPill(s.wpeName, s.wpeId) end)
    z:SetScript("OnLeave", function() self:HideDropPill() end)
    self.catZones[i] = z
  end
  return z
end

-- The floating name pill that names the section the cursor is over during a drag: a small bordered
-- label ("Armor +", or the unpin word over Empty) that tracks the cursor, so the target reads at a
-- glance without a name printed across every section. One pill, re-anchored per hover.
function Bags:ShowDropPill(name, id)
  local p = self.dropPill
  if not p then
    p = CreateFrame("Frame", nil, self.frame or UIParent, "BackdropTemplate")
    p:SetFrameStrata("TOOLTIP")
    ns.PixelBackdrop(p)
    ns.SetBg(p, Theme:C("panel"))
    ns.SetEdge(p, Theme:C("accent"))
    local fs = Theme:Label(p, FONT, "accent")
    fs:SetFont(self.fontPath or ns.Fonts:Current(), FONT, ns.OutlineFlags())
    fs:SetPoint("CENTER")
    p.fs = fs
    self.dropPill = p
  end
  local isEmpty = (id == ns.Categories.EMPTY_ID)
  -- The plus sits after the name ("ARMOR +"), reading as "add to this one"; the Empty section is the
  -- unfile target, so it names the action instead of a category.
  p.fs:SetText(isEmpty and ns.Upper(ns.L["Unpin"]) or (ns.Upper(name or "") .. " +"))
  local w = math.ceil(p.fs:GetStringWidth()) + 20
  ns.SnapSize(p, w, FONT + 12)
  p:ClearAllPoints()
  -- Just up and to the right of the cursor, in the window's scale so it lands where the mouse is.
  local scale = (self.frame and self.frame:GetEffectiveScale()) or UIParent:GetEffectiveScale()
  local mx, my = GetCursorPosition()
  p:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", mx / scale + 14, my / scale + 14)
  p:Show()
end

function Bags:HideDropPill()
  if self.dropPill then self.dropPill:Hide() end
end

function Bags:HideCatZones(from)
  if not self.catZones then return end
  for i = (from or 0) + 1, #self.catZones do
    local z = self.catZones[i]
    if z then z.wpeActive = false; z:Hide() end
  end
end

-- A display-only cell for the Empty section: a quiet icon and a free-slot count, sized like a bag
-- cell but bound to nothing, so it never carries a bag or slot id and stays wholly taint-free. Pooled
-- by index like the other section widgets.
function Bags:EmptyTile(i)
  self.emptyTiles = self.emptyTiles or {}
  local t = self.emptyTiles[i]
  if not t then
    t = CreateFrame("Frame", nil, self.content)
    -- A sample empty cell, cell-sized so it sits in the grid like any slot: a faint plate, its free
    -- count centred, and a border. Two are drawn, the plain-bag one and the reagent one, so the two
    -- pools each show their own free number without folding into one. The count in the section caption
    -- is the total; these name where that room is. The section drop zone lies over them and a release
    -- is the unfile.
    -- The faint plate. Its low alpha is baked into the vertex colour and re-applied through the theme
    -- hook, not set once with SetAlpha: a plain SetAlpha is not re-run on a theme change, while the
    -- Rect's own recolour hook re-runs SetVertexColor to full alpha, so the plate used to flare to full
    -- brightness the moment the theme changed and only a reload cleared it. Painting colour and alpha
    -- together in one tracked call keeps it faint across every theme change.
    local bg = t:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(t)
    local function paintBg(x) local r, g, b = Theme:C("faint"); x:SetColorTexture(r, g, b, 0.12) end
    paintBg(bg)
    Theme:Track(bg, paintBg)
    t.bg = bg
    local count = Theme:Label(t, FONT, "text")
    count:SetJustifyH("CENTER")
    t.count = count
    -- One border, four 1px edges, built once with no colour key so Theme:Rect hangs no auto-recolour
    -- hook on them. EmptyTileBorder paints them by hand each layout instead, the soft frame tone for
    -- the plain cell and the reagent tint for the reagent one. The earlier build stacked two tracked
    -- sets on the same edges and toggled only their visibility; a theme change recoloured both before
    -- the layout re-ran, and the reagent set could surface as a stuck highlight. One hand-painted set
    -- cannot: its colour is written fresh on every layout, and a layout follows every theme change.
    t.edges = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
      local e = Theme:Rect(t, nil, "OVERLAY")
      if side == "TOP" then
        e:SetPoint("TOPLEFT", t, "TOPLEFT", 0, 0); e:SetPoint("TOPRIGHT", t, "TOPRIGHT", 0, 0)
        ns.PixelLine(e, 1)
      elseif side == "BOTTOM" then
        e:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 0, 0); e:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", 0, 0)
        ns.PixelLine(e, 1)
      elseif side == "LEFT" then
        e:SetPoint("TOPLEFT", t, "TOPLEFT", 0, 0); e:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 0, 0)
        ns.PixelLine(e, 1, "w")
      else
        e:SetPoint("TOPRIGHT", t, "TOPRIGHT", 0, 0); e:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", 0, 0)
        ns.PixelLine(e, 1, "w")
      end
      t.edges[#t.edges + 1] = e
    end
    self.emptyTiles[i] = t
  end
  return t
end

-- Paint the border for this layout: reagent tint on the reagent sample cell, a neutral mid tone on the
-- plain one, close in weight to the reagent border so the two read as a pair. Written fresh every
-- layout, so a theme change (which re-lays the grid) repaints it and nothing can stick lit.
function Bags:EmptyTileBorder(t, on)
  if not t.edges then return end
  local r, g, b = Theme:C(on and "reagent" or "faint")
  for _, e in ipairs(t.edges) do
    e:SetVertexColor(r, g, b)
    e:Show()
  end
end

-- Centre the free number in the cell and size it off the cell like a real slot's stack count, so it
-- grows and shrinks with the player's cell setting.
function Bags:FitEmptyCount(t, cell)
  local c = t.count
  if not c then return end
  ns.SetOutlined(c, ns.BadgeSize("count", cell, ns.Badge("count")))
  c:ClearAllPoints()
  c:SetPoint("CENTER", t, "CENTER", 0, 0)
end

function Bags:HideEmptyTiles(from)
  if not self.emptyTiles then return end
  for i = (from or 0) + 1, #self.emptyTiles do
    if self.emptyTiles[i] then self.emptyTiles[i]:Hide() end
  end
end

-- Flip every section drop zone at once: on while an item rides the cursor and the grouped view is
-- up, off the rest of the time so the cells click through as normal. Called on each cursor change
-- and at the tail of a grouped layout, in case the window opened with an item already on the cursor.
function Bags:SyncDropZones()
  if not self.catZones then return end
  local on = self:CatMode() and self.frame and self.frame:IsShown() and CursorHasItem()
  for _, z in ipairs(self.catZones) do
    -- An active zone is an invisible droppable box over the section's extent for the whole drag, so a
    -- release on the gaps between cells still files the piece. The pill names the section under the
    -- cursor; the zone itself stays invisible.
    if on and z.wpeActive then z:Show() else z:Hide() end
  end
  -- No item held, no target to name: drop the pill so it never lingers after a drag ends.
  if not on then self:HideDropPill() end
end

-- One watcher flips the zones the moment the cursor picks up or sets down an item, so the highlight
-- tracks the drag with no per-frame polling. Safe before the window exists: SyncDropZones no-ops
-- until the zones are built.
local dropWatch = CreateFrame("Frame")
dropWatch:RegisterEvent("CURSOR_CHANGED")
dropWatch:SetScript("OnEvent", function() Bags:SyncDropZones() end)

-- Sections packed into shelves: each is as wide as its cells need (capped at the grid, floored by
-- its caption) so several share a row and the list reads left to right in priority order. A section
-- is always drawn whole: only a group band folds, and it does so from the caption row above its own
-- sections. A live search narrows the pass to the hits, so a match is never hidden behind a band.
function Bags:LayoutCats(place, size, gap, step, cols)
  local buckets, used, total = ns.Categories:Buckets(self)
  local Cats = ns.Categories
  local d = ns.Density(size)
  local capH = d.labelH + d.labelGap
  local gridW = gridWidth(size, cols, gap)
  local searching = (self.query or "") ~= ""
  -- The group caption sits at labelX with its caret in the gap to its left. A section caption sits at
  -- capX, flush with the left edge of its own first cell, so the name reads as the heading of the
  -- items directly beneath it rather than floating off to their right. The per-section caret is gone
  -- and nothing else stands before the name, so the caption starts exactly on that edge: a px of pad
  -- here reads as a stray gap the eye takes for a glyph that is not there.
  local labelX = 14
  local capX = 0
  -- The drop below the group caption before its sections begin, so the band header is not crammed
  -- against the first row of names. Added on top of the caption's own height.
  local GHEAD_GAP = 6
  -- Shelves, not a single column: each section is only as wide as it needs, so several sit side by
  -- side on one row and the list still reads left to right, which is the priority order. A section's
  -- width is its cell count capped at the grid columns, but never narrower than its own caption, so
  -- a long name is not clipped by a two-item block. When the next section will not fit the row's
  -- remaining width the shelf wraps: y drops by the tallest section on the shelf plus one gap, and
  -- packing starts again at the left. GUT is the gap between neighbours on a shelf.
  -- The gap between categories, split in two: GUTX is the neighbour gap across a shelf, GUTY the drop
  -- between shelf rows. Each follows the density scale (DIV) until the player sets a flat value on its
  -- own slider, and both are the grouped view's alone, so the reagent block's own DIV spacing in the
  -- grid is untouched.
  local GUTX = math.max(0, math.floor(tonumber(self.catGapX) or DIV))
  local GUTY = math.max(0, math.floor(tonumber(self.catGapY) or DIV))
  local shelfX, shelfY, shelfH = 0, 0, 0
  local nb = #buckets
  -- The Empty section is a real list member now (Categories seeds it), so it arrives as one of the
  -- buckets on its own list position and lays out in this same pass as the rest: it packs onto a
  -- shelf and repacks like any section, and the player can move or delete it from the editor. It
  -- stands in for the free space the grid shows as trailing blank cells: grouped view has none to
  -- eyeball, so this names it. Its bucket carries b.empty and owns no slots; it draws two display
  -- tiles instead, bound to nothing so they carry no bag or slot and stay taint-free: the normal bags'
  -- free count, and the reagent bag's under its green border (dropped when no reagent bag is worn). It
  -- doubles as the unfile target: EMPTY_ID owns no items, so a drop here clears the piece's manual
  -- home, which is exactly the unpin.
  local free = math.max(0, (total or 0) - (used or 0))
  -- Reagent free and slot counts through the same snap-aware readers the grid uses, so the Empty
  -- section's reagent tile is right for a cached character too: live reads the container, a snapshot
  -- reads the Vault, and regSlots minus Taken is the free room either way.
  local freeReg, regSlots = 0, 0
  if ns.reagentBag then
    regSlots = self:Slots(ns.reagentBag)
    if regSlots > 0 then freeReg = regSlots - self:Taken(ns.reagentBag) end
  end
  local freeMain = math.max(0, free - freeReg)
  local emptyTiles = (regSlots > 0) and 2 or 1
  local shownTiles = 0
  -- Bands: a run of sections that share the marker heading them. The marker is the entry in the saved
  -- list the whole layout walks — a group header, a divider, or nothing at all for the run before the
  -- first marker — so a band is where it is because the list says so. Nothing to keep in step, no group
  -- table to consult, and no ungrouped special case: the trailing rows are simply a run under a divider.
  local bands = {}
  for bi = 1, nb do
    local b = buckets[bi]
    local band = bands[#bands]
    if not band or band.key ~= b.band then
      band = { key = b.band, from = bi, to = bi, n = 0 }
      bands[#bands + 1] = band
    end
    band.to = bi
    if (not searching) or (b.hits or 0) > 0 then band.n = band.n + 1 end
  end
  -- Whether a band shows its sections. A live search answers instead of the fold: the query is the
  -- filter, so a band with a hit draws open and one with nothing to show keeps only its heading. With no
  -- search the fold saved on the band's own marker decides, and the run before the first marker is always
  -- open — it has no heading to click.
  local function bandOpen(band)
    if searching then return band.n > 0 end
    return not (band.key and Cats:Folded(band.key))
  end
  local drawn = {}
  for k = 1, #bands do
    local band = bands[k]
    -- A folded band still draws: its heading is the handle that unfolds it. A search is different — a
    -- band with no hit is left out whole, heading and all.
    if (not searching) or band.n > 0 then drawn[#drawn + 1] = band end
  end
  local gi, si = 0, 0
  for k = 1, #drawn do
    local band = drawn[k]
    local open = bandOpen(band)
    if k > 1 then
      shelfY = shelfY + shelfH + GUTY
      shelfX, shelfH = 0, 0
    end
    -- The heading of the band. A group header draws its name with the caret beside it, and that heading
    -- is the fold handle — the only way back into a folded band. A divider seams a band off without
    -- naming it, so there is nothing there to open or close: no caret, no click target, its line is the
    -- whole of the heading and the band starts right below it.
    if band.key then
      gi = gi + 1
      local gcapH = math.max(capH, d.font + 4)
      local top = shelfY
      local textY = shelfY
      local isHead = Cats.IsHead(band.key)
      local line = self:CatGroupLine(gi)
      -- Placed whether or not it is shown, so each heading in the pool carries one set of points. A divider
      -- always draws its line, since the line is the whole of its heading; only the first group heading
      -- skips it, having nothing above it to seam itself off from.
      line:ClearAllPoints()
      ns.SnapPoint(line, "TOPLEFT", self.content, "TOPLEFT", 0, -top)
      ns.SnapPoint(line, "TOPRIGHT", self.content, "TOPRIGHT", 0, -top)
      local seamed = (k > 1) or (not isHead)
      line:SetShown(seamed)
      if seamed then textY = top + 1 + d.labelGap end
      local glabel = self:CatGroupLabel(gi)
      local gcaret = self:CatGroupCaret(gi)
      -- No tally on a heading: every section under it already prints its own (N), so a count of sections
      -- beside the name only repeated what the eye reads down the band. Kept pooled but hidden so a build
      -- that carried it before this change clears it.
      self:CatGroupCount(gi):Hide()
      local headH
      if isHead then
        glabel:SetFont(self.fontPath or ns.Fonts:Current(), FONT - 2, ns.OutlineFlags())
        glabel:SetTextColor(Theme:C("azure"))
        fitLabel(glabel, Cats:GroupName(band.key), gridW - labelX)
        glabel:ClearAllPoints()
        ns.SnapPoint(glabel, "TOPLEFT", self.content, "TOPLEFT", labelX, -textY)
        glabel:Show()
        gcaret:ClearAllPoints()
        ns.SnapPoint(gcaret, "RIGHT", glabel, "LEFT", -4, 0)
        gcaret:SetDir(open and "down" or "right")
        gcaret:SetTint("dim")
        gcaret:Show()
        shelfY = textY + gcapH + GHEAD_GAP
        headH = (textY - top) + gcapH
      else
        glabel:Hide()
        gcaret:Hide()
        shelfY = textY + d.labelGap
        headH = math.max(9, textY - top)
      end
      local ghead = self:CatGroupHead(gi)
      ghead.wpeEntry, ghead.wpeCaret, ghead.wpeLabel = band.key, gcaret, glabel
      ghead:ClearAllPoints()
      ns.SnapPoint(ghead, "TOPLEFT", self.content, "TOPLEFT", 0, -top)
      ghead:SetSize(math.max(1, gridW), headH)
      ghead:SetShown(isHead)
    end
    -- A folded band keeps its heading but draws no sections: an empty range is the same thing as
    -- skipping the loop, without a second nesting level to keep aligned.
    if not open then band.from, band.to = 0, -1 end
  for bi = band.from, band.to do
    local b = buckets[bi]
    -- A search draws the hits alone: a section with no match is left out of the pass whole, so the
    -- query reveals exactly where the item lives. The Empty section never scores a hit.
    if (not searching) or (b.hits or 0) > 0 then
    si = si + 1
    local isEmpty = b.empty
    local id = b.id
    local name = b.name
    local n = isEmpty and emptyTiles or #b.slots
    local label = self:CatLabel(si)
    -- Set as a file every layout so a font change reaches the caption.
    label:SetFont(self.fontPath or ns.Fonts:Current(), FONT - 4, ns.OutlineFlags())
    label:SetTextColor(Theme:C("accent"))
    local count = self:CatCount(si)
    -- Parenthesised so the dim tally beside the accent name reads as a count, not a stray number or an
    -- item level tacked onto the caption. The Empty section drops the tally outright: its free numbers
    -- are already printed on the sample tiles below, so a count here only repeats them, and in a one or
    -- two cell wide section it steals the very width the word EMPTY needs. Zeroing countW gives that
    -- room back to both the width floor and the truncation, so the label reads at a small cell size
    -- instead of collapsing to an ellipsis.
    -- The tally is only worth the room once it beats a glance: at one or two items the eye already
    -- counts them, so the (N) there only steals width from a narrow section's caption. It shows from
    -- three up. Empty never shows one (its free numbers ride the sample tiles below). showCount gates
    -- both the text and the width floor, so a hidden count reserves no space and the name gets it back.
    local showCount = (not isEmpty) and n >= 3
    local countW = 0
    if showCount then
      count:SetFont(self.fontPath or ns.Fonts:Current(), FONT - 4, ns.OutlineFlags())
      count:SetText("(" .. n .. ")")
      countW = count:GetStringWidth()
    else
      count:Hide()
    end
    -- Width from the cell count, but never so narrow the name is crushed to an initial. The floor is
    -- the whole caption (indent, name, gap, count), capped so a long name cannot blow one section across
    -- the grid: up to catNameCap px of name is granted room, past that the name truncates and the header
    -- offers the whole of it in a tooltip. This is why a one-item section still reads its name instead of
    -- a lone glyph, while the shelf packing stays sane. Measured with the real name in the label.
    label:SetText(ns.Upper(name or ""))
    local fullNameW = label:GetStringWidth()
    local nameCap = math.min(gridW, 6 * step)
    local floorNeed = capX + math.min(fullNameW, nameCap) + 6 + countW
    local capCols = math.max(1, math.ceil((floorNeed - size) / step) + 1)
    local w = math.max(math.min(n, cols), capCols)
    if w > cols then w = cols end
    local sw = gridWidth(size, w, gap)
    -- Cut the name to whatever the section leaves once the indent, gap and count are reserved, so the
    -- caption is never wider than its own section. The count keeps its place at the name's right, so a
    -- shorter name only pulls the tally inward; the caption indent never moves. A cut name (only the
    -- longest, past the cap) shows in full on hover, so nothing is lost to the ellipsis.
    local truncated = fitLabel(label, name, sw - capX - 6 - countW)
    -- Wrap to a new shelf when this section would run past the grid's right edge. The 0.5 absorbs the
    -- rounding in the density-scaled widths so an exact fit is not bumped to the next row.
    if shelfX > 0 and shelfX + GUTX + sw > gridW + 0.5 then
      shelfY = shelfY + shelfH + GUTY
      shelfX, shelfH = 0, 0
    end
    local sx = (shelfX == 0) and 0 or (shelfX + GUTX)
    local sy = shelfY
    label:ClearAllPoints()
    ns.SnapPoint(label, "TOPLEFT", self.content, "TOPLEFT", sx + capX, -sy)
    label:Show()
    if showCount then
      count:ClearAllPoints()
      -- Left edge to the name's right, so the tally rides beside the caption as one unit and shares its
      -- vertical centre. On the ragged shelf edges a far-right count would line up with nothing.
      ns.SnapPoint(count, "LEFT", label, "RIGHT", 6, 0)
      count:Show()
    end
    local head = self:CatHeader(si)
    head.wpeId, head.wpeLabel = id, label
    head.wpeFull, head.wpeCut = ns.Upper(name or ""), truncated
    head:ClearAllPoints()
    ns.SnapPoint(head, "TOPLEFT", self.content, "TOPLEFT", sx, -sy)
    head:SetSize(math.max(1, sw), capH)
    head:Show()
    local secH
    if isEmpty then
      -- Sample empty cells on the shelf like a section's slots: the plain-bag one with its free count,
      -- and when a reagent bag exists a reagent-bordered one beside it with the reagent free count. The
      -- caption already totals the free room; these two say where it is, in the grid's own cell shape.
      -- They live inside secH so the Empty drop zone covers them, and a release here is the unfile.
      local cellsTop = sy + capH
      local t1 = self:EmptyTile(1)
      ns.SnapSize(t1, size, size)
      t1.count:SetText(tostring(freeMain))
      self:EmptyTileBorder(t1, false)
      self:FitEmptyCount(t1, size)
      t1:ClearAllPoints()
      ns.SnapPoint(t1, "TOPLEFT", self.content, "TOPLEFT", sx, -cellsTop)
      t1:Show()
      if emptyTiles > 1 then
        local t2 = self:EmptyTile(2)
        ns.SnapSize(t2, size, size)
        t2.count:SetText(tostring(freeReg))
        self:EmptyTileBorder(t2, true)
        self:FitEmptyCount(t2, size)
        t2:ClearAllPoints()
        ns.SnapPoint(t2, "TOPLEFT", self.content, "TOPLEFT", sx + step, -cellsTop)
        t2:Show()
      end
      shownTiles = emptyTiles
      secH = capH + size
    else
      local cellsTop = sy + capH
      for k, s in ipairs(b.slots) do
        local col = (k - 1) % w
        local row = math.floor((k - 1) / w)
        place(s.bag, s.slot, sx + col * step, -(cellsTop + row * step))
      end
      local rows = math.max(1, math.ceil(n / w))
      secH = capH + (rows - 1) * step + size
    end
    -- The section's own drop zone, sized to its drawn extent (caption through last cell row, the
    -- between-section gap left out). Positioned every layout but kept hidden; the watcher shows it mid drag.
    -- The Empty zone rides EMPTY_ID like its header, so a release on it unfiles, and its tag names the
    -- action, not a section: dropping here is the unpin, and the word says so.
    local zone = self:CatZone(si)
    zone.wpeId = id
    -- Other still takes no drop (its slots are the catch-all already), so its zone stays inert; every
    -- other section, Empty included, takes a hand-file drop.
    zone.wpeActive = (id ~= ns.Categories.OTHER_ID)
    -- The name the floating pill shows for this section; the pill adds the "+" and the outline font.
    zone.wpeName = name
    zone:ClearAllPoints()
    ns.SnapPoint(zone, "TOPLEFT", self.content, "TOPLEFT", sx, -sy)
    zone:SetSize(math.max(1, sw), math.max(capH, secH))
    zone:Hide()
    shelfX = sx + sw
    shelfH = math.max(shelfH, secH)
    end
  end
  end
  -- The bottom of the last shelf, plus the trailing gap. The Empty section now sits on that shelf, so
  -- the footer that used to be measured on its own is folded into this one number.
  local contentH = shelfY + shelfH + d.labelGap
  if self.catFree then self.catFree:Hide() end
  self:HideCatLabels(si)
  self:HideCatCounts(si)
  self:HideCatHeaders(si)
  self:HideCatZones(si)
  self:HideCatGroups(gi)
  self:HideEmptyTiles(shownTiles)
  -- Opened with an item already on the cursor? Light the zones now; otherwise this hides them.
  self:SyncDropZones()
  return contentH, used, total
end

function Bags:Resize(contentH)
  local seam = ns.SeamWatch(self.frame)
  local gw = gridWidth(self.pxSize or self.iconSize, self.cols, self.pxGap or self.gap)
  self.content:SetSize(gw, contentH)
  self.frame:SetSize(PAD * 2 + gw, self:TopOffset() + contentH + FOOTER)
  -- The plate is the extra surface the items stand on, over the window's own background, and it runs
  -- the whole window: header, grid and footer are covered alike, and only a skin's own header band is
  -- left alone (Theme:FitPlate). It used to be the one band the grid sat in, which left the window's
  -- background showing around it as a second tone.
  Theme:FitPlate(self.gridBg, self.frame)
  ns.Rebase(self.frame, "pos")
  ns.SeamHeal(seam)
end

local function groupNumber(n, sep)
  local out = tostring(math.floor(n))
  local k
  repeat out, k = out:gsub("^(%d+)(%d%d%d)", "%1" .. sep .. "%2") until k == 0
  return out
end

local function shortNumber(n)
  n = math.floor(n or 0)
  if n < 1000 then return tostring(n) end
  local form = ns.ShortForm()
  local units = form.units
  for i, u in ipairs(units) do
    local scale, suf = u[1], u[2]
    if n >= scale then
      local r = math.floor(n / scale * 10 + 1e-9) / 10
      if r >= 1000 and i > 1 then
        scale, suf = units[i - 1][1], units[i - 1][2]
        r = math.floor(n / scale * 10 + 1e-9) / 10
      end
      if r == math.floor(r) then return string.format("%d%s", r, suf) end
      return (string.format("%.1f", r):gsub("%.", form.dec)) .. suf
    end
  end
  return tostring(n)
end

function ns.FormatNumber(n)
  local mode = WarpeeDB and WarpeeDB.goldFormat or "commas"
  if mode == "short" then return shortNumber(n) end
  local sep = (mode == "dots" and ".") or (mode == "spaces" and " ") or ","
  return groupNumber(n, sep)
end

local COIN_ICON = {
  g = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t",
  s = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t",
  c = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t",
}
local COIN_HEX = { g = "ffd700", s = "c7c7cf", c = "eda55f" }
-- The colour of a coin's letter is the one thing another window can borrow from here: the guild
-- bank writes its money a coin at a time, so it cannot go through FormatMoney, and the letters of
-- a coin are the same colour wherever they are written.
ns.COIN_HEX = COIN_HEX

local function whiteNum(str, deep, plain)
  if plain then return "|cffffffff" .. str .. "|r" end
  return "|cff" .. Theme:Hex(deep and "overlay" or "text") .. str .. "|r"
end

local function coinUnit(letter)
  if not Bags.goldLetters then return COIN_ICON[letter] end
  local sp = (letter == "g" and WarpeeDB and WarpeeDB.goldFormat == "short") and " " or ""
  return sp .. "|cff" .. COIN_HEX[letter] .. ns.CoinLetter(letter) .. "|r"
end

local function coinSeg(num, letter, deep, plain)
  return whiteNum(num, deep, plain) .. coinUnit(letter)
end

function ns.FormatMoney(money, goldOnly, deep, plain)
  money = money or 0
  local g = math.floor(money / 10000)
  if goldOnly == nil then goldOnly = Bags.goldOnly end
  if goldOnly then return coinSeg(ns.FormatNumber(g), "g", deep, plain) end
  local sv = math.floor((money % 10000) / 100)
  local cp = money % 100
  local parts = {}
  if g  > 0 then parts[#parts + 1] = coinSeg(ns.FormatNumber(g), "g", deep, plain) end
  if sv > 0 then parts[#parts + 1] = coinSeg(sv, "s", deep, plain) end
  if cp > 0 or #parts == 0 then parts[#parts + 1] = coinSeg(cp, "c", deep, plain) end
  return table.concat(parts, " ")
end
function Bags:FormatMoney() return ns.FormatMoney(GetMoney(), nil, Theme:IsLight()) end

function ns.FormatGold(copper, deep, plain)
  return coinSeg(ns.FormatNumber(math.floor((copper or 0) / 10000)), "g", deep, plain)
end

function Bags:UpdateBagBar()
  if not self.bagButtons then return end
  local path = ns.Fonts:Current()
  if self.bagTitle then self.bagTitle:SetFont(path, FONT - 1, ns.OutlineFlags()) end
  for _, b in ipairs(self.bagButtons) do
    local bagID = b.wpeBagID
    local tex
    if bagID == 0 then
      tex = "Interface\\Buttons\\Button-Backpack-Up"
    else
      tex = GetInventoryItemTexture("player", C_Container.ContainerIDToInventoryID(bagID))
    end
    b.icon:SetTexture(tex or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
    local free = select(1, C_Container.GetContainerNumFreeSlots(bagID)) or 0
    b.count:SetText(free > 0 and free or "")
    if b.count and b.cntFontSize then ns.SetOutlined(b.count, b.cntFontSize) end
  end
end

function Bags:Refont()
  self.fontPath = ns.Fonts:Refresh()
  if not self.pool then return end
  for _, b in ipairs(self.pool) do
    b.link = nil
  end
end

function Bags:HighlightBag(bagID)
  if self.snap then return end
  -- A bag the grid is not showing has no cell to light up, and fading the rest with
  -- nothing highlighted only blanks the window: a reagent bag with reagents hidden, or a
  -- bag slot with nothing in it. Nothing is dimmed unless something is lit.
  local hit = false
  for j = 1, (self.shown or 0) do
    local b = self.pool[j]
    if b and b.wpeBagID == bagID then hit = true; break end
  end
  if not hit then return end
  self.hlBag = bagID
  for j = 1, (self.shown or 0) do
    local b = self.pool[j]
    if b then
      local on = (b.wpeBagID == bagID)
      b:SetAlpha(on and 1 or 0.15)
      ns.SetSlotHighlight(b, on)
    end
  end
end

function Bags:ClearBagHighlight()
  if self.snap then return end
  self.hlBag = nil
  for j = 1, (self.shown or 0) do
    local b = self.pool[j]
    if b then
      ns.SetSlotHighlight(b, false)
      b:SetAlpha(1)
      b.searchMiss = nil
      self:ApplyToButton(b)
    end
  end
end

function Bags:PlaceBagFromCursor(bagID)
  if InCombatLockdown() then ClearCursor(); return end
  if bagID == 0 then ClearCursor(); return end
  local inv = C_Container.ContainerIDToInventoryID(bagID)
  if not inv then ClearCursor(); return end
  PutItemInBag(inv)
end

function Bags:UpdateCharTag()
  if not self.charTag then return end
  local key = ns.Vault:ViewKey("bags")
  local name, class
  if key == ns.Vault:Owner() then
    name = UnitName("player")
    local _, cls = UnitClass("player")
    class = cls
  else
    for _, e in ipairs(ns.Vault:Chars(true)) do
      if e.key == key then name, class = e.name, e.class; break end
    end
  end
  ns.PaintCharTag(self.charTag, name or (key and key:match("^(.-)%-")) or "?", class)
end

function Bags:ToggleCharPicker(anchor)
  if not ns.CharPicker then return end
  ns.CharPicker:Toggle(anchor or self.charTag, "left",
    function(key) self:SelectChar(key) end, ns.Vault:ViewKey("bags"), "bags",
    function() return self.iconSize end)
end

function Bags:SelectChar(key)
  if not ns.Vault:SetView("bags", key) then return end
  self.snap = (ns.Vault:ViewKey("bags") ~= ns.Vault:Owner()) or nil
  self:UpdateCharTag()
  if self.frame and self.frame:IsShown() then self:Layout(true) end
end

function Bags:VendorState()
  if self.pool then
    for _, x in ipairs(self.pool) do ns.LockClicks(x) end
  end
  local F = ns.Fav
  if F then
    for i = 1, (F.max or 0) do ns.LockClicks(F.slots[i]) end
  end
  local P = ns.Pocket
  if P then
    for i = 1, (P.max or 0) do ns.LockClicks(P.slots[i]) end
    for _, x in pairs(P.recSlots) do ns.LockClicks(x) end
  end
  local R = ns.Recent
  if R then
    for _, x in pairs(R.slots) do ns.LockClicks(x) end
  end
  local b = self.sellBtn
  if not b then return end
  b:SetShown(not self.snap)
  -- The coin follows CanBuy, not IsOpen: a repair-only NPC opens a merchant that takes nothing, so
  -- the button stays dim there rather than lighting up over a sale that would silently do nothing.
  local on = (ns.Vendor and ns.Vendor:CanBuy()) and true or false
  ns.SetButtonEnabled(b, on)
  if b.icon then
    b.icon:SetDesaturated(not on)
    b.icon:SetAlpha(on and 1 or 0.45)
  end
  self:FitHeader()
end

function Bags:BrowseState()
  local V = ns.Vault
  local b = self.bankBtn
  if b then
    local on = ((ns.Bank and ns.Bank.bankerOpen) or V:Saved("bank") or V:Saved("warband"))
               and true or false
    ns.SetButtonEnabled(b, on)
    if b.icon then
      b.icon:SetDesaturated(not on)
      b.icon:SetAlpha(on and 1 or 0.45)
    end
  end
  local t = self.charTag
  if t then
    local on = V:Others("bags") > 0 or (self.snap and true or false)
    t:SetEnabled(on)
    t:SetAlpha(on and 1 or 0.6)
    if t.caret then t.caret:SetTint(on and "dim" or "faint") end
  end
end

-- While the auction house is open, an item that cannot be listed reads as unavailable, the same grey
-- the search gives a miss: a soulbound piece, a quest item, or anything with no sale value can never
-- go on the block, so dimming it points the eye straight at what can. The test is deliberately cheap
-- and per-slot — the bound flag and hasNoValue off the container info, plus the quest class — so it
-- costs a layout no tooltip scan, in keeping with the addon's no-scan-per-slot rule. An item bound to
-- the player is the common uncase; a BoE stays lit until it binds.
local auctionOpen = false
function ns.AuctionBlocked(b)
  if not auctionOpen then return false end
  if not (b and b.wpeBagID and b.GetID) then return false end
  local info = C_Container.GetContainerItemInfo(b.wpeBagID, b:GetID())
  if not info then return false end
  if info.hasNoValue then return true end
  if info.isBound then return true end
  local m = b.meta
  if m and m.classID == Enum.ItemClass.Questitem then return true end
  return false
end

-- Flip the auction dim on and off with the house, and re-dim the open bags at each edge so the grey
-- appears the moment the window is up and clears when it closes. Mirrors the merchant path.
do
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("AUCTION_HOUSE_SHOW")
  ev:RegisterEvent("AUCTION_HOUSE_CLOSED")
  ev:SetScript("OnEvent", function(_, event)
    auctionOpen = (event == "AUCTION_HOUSE_SHOW")
    if ns.RefreshBagDim then ns.RefreshBagDim() end
  end)
end

-- The game already knows which bag slots do not belong in whatever interaction window is open: the item
-- upgrade frame, the scrapper, a gem socket, the runeforge, void storage, a bank type that refuses the
-- item. It greys those cells in its own bags. ItemButtonUtil answers the same question for a slot across
-- every context at once, so one match test says which cells to dim without the addon having to name the
-- window or know its rules. DoesNotApply means nothing is open; only a real Mismatch dims. The house and
-- the merchant keep their own reasons above; this is everything the client itself fades.
local ctxMismatch = ItemButtonUtil and ItemButtonUtil.ItemContextMatchResult
  and ItemButtonUtil.ItemContextMatchResult.Mismatch
function ns.ContextBlocked(b)
  if not (ctxMismatch and ItemButtonUtil.GetItemContextMatchResultForItem) then return false end
  if not (b and b.wpeBagID and b.GetID and ItemLocation) then return false end
  local loc = ItemLocation:CreateFromBagAndSlot(b.wpeBagID, b:GetID())
  if not (loc and loc:IsValid()) then return false end
  local ok, res = pcall(ItemButtonUtil.GetItemContextMatchResultForItem, loc)
  return ok and res == ctxMismatch
end

-- The client fires this the moment an interaction window opens, closes, or switches (a new bank type,
-- the next socket). Re-dim the open bags on it so the grey tracks the window with no polling.
do
  if ItemButtonUtil and ItemButtonUtil.RegisterCallback and ItemButtonUtil.Event then
    local owner = {}
    ItemButtonUtil.RegisterCallback(ItemButtonUtil.Event.ItemContextChanged, function()
      if ns.RefreshBagDim then ns.RefreshBagDim() end
    end, owner)
  end
end

-- The guild bank is not one of the contexts ItemButtonUtil answers for, so the client never fades a bag
-- slot for it and ContextBlocked stays blind here. The rule the guild bank enforces is its own: a slot
-- takes anything except an item bound to the player and an account-bound-until-equipped item, so those
-- two are what read as unavailable while the guild vault is open. Both flags come off the container info
-- and the item location, no tooltip scan, in keeping with the no-scan-per-slot rule.
local guildOpen = false
local mailOpen = false
function ns.GuildDepositBlocked(b)
  if not guildOpen then return false end
  if not (b and b.wpeBagID and b.GetID) then return false end
  local info = C_Container.GetContainerItemInfo(b.wpeBagID, b:GetID())
  if not info then return false end
  if info.isBound then return true end
  if ItemLocation and C_Item and C_Item.IsBoundToAccountUntilEquip then
    local loc = ItemLocation:CreateFromBagAndSlot(b.wpeBagID, b:GetID())
    if loc and loc:IsValid() then
      local ok, boa = pcall(C_Item.IsBoundToAccountUntilEquip, loc)
      if ok and boa then return true end
    end
  end
  return false
end

-- Flip the guild dim with the guild bank window and re-dim the open bags at each edge, the same shape as
-- the auction and merchant paths. The interaction manager names the frame, so GuildBanker is the one to
-- watch and nothing else on this frame concerns the bags.
do
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
  ev:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
  local GUILD = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.GuildBanker
  local MAIL = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.MailInfo
  ev:SetScript("OnEvent", function(_, event, kind)
    local show = (event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    if kind == GUILD then
      guildOpen = show
    elseif kind == MAIL then
      mailOpen = show
    else
      return
    end
    if ns.RefreshBagDim then ns.RefreshBagDim() end
  end)
end

-- Mail takes two signals, not one: the mail window has to be up and the Send tab, not the inbox, has to
-- be the one showing. The interaction manager gives the first; SetSendMailShowing gives the second and
-- fires on every tab switch. The rule for what cannot be sent is its own too — a bound item cannot go in
-- the post, except one bound to the account, which can still reach your own alts, so that one stays lit.
local mailSend = false
do
  if type(SetSendMailShowing) == "function" then
    hooksecurefunc("SetSendMailShowing", function(state)
      mailSend = state and true or false
      if ns.RefreshBagDim then ns.RefreshBagDim() end
    end)
  end
end

function ns.MailBlocked(b)
  if not (mailOpen and mailSend) then return false end
  if not (b and b.wpeBagID and b.GetID) then return false end
  local info = C_Container.GetContainerItemInfo(b.wpeBagID, b:GetID())
  if not info or not info.isBound then return false end
  -- Bound, so the post refuses it unless the account bank would take it: an account-bound piece can be
  -- mailed to your own characters, so it is the one bound item that stays available.
  if ItemLocation and C_Bank and C_Bank.IsItemAllowedInBankType and Enum and Enum.BankType then
    local loc = ItemLocation:CreateFromBagAndSlot(b.wpeBagID, b:GetID())
    if loc and loc:IsValid() then
      local ok, allowed = pcall(C_Bank.IsItemAllowedInBankType, Enum.BankType.Account, loc)
      if ok and allowed then return false end
    end
  end
  return true
end

function Bags:FitHeader()
  if not (self.frame and self.search) then return end
  self:FlowHeader()
  local w = self.frame:GetWidth()
  self.search:Show()
  -- The reagent switch hides the reagent block, which is a grid-only idea: cat-view always groups
  -- the full inventory, so the button has nothing to gate there. It comes off the header in
  -- cat-view and the count slides back onto the tag where the button used to sit.
  if self.reagentBtn and self.slotText and self.charTag then
    local catMode = self:CatMode()
    self.reagentBtn:SetShown(not catMode)
    self.slotText:ClearAllPoints()
    self.slotText:SetPoint("LEFT", catMode and self.charTag or self.reagentBtn, "RIGHT", 10, 0)
  end
  if self.slotText and self.charTag then
    local edge = self.headEdge and self.headEdge:GetLeft()
    -- The count reads after the reagent switch now, so that is the edge it has to clear. The tag
    -- is the fallback for a frame built before that button existed, and for cat-view where the
    -- switch is hidden.
    local anchor = (self.reagentBtn and self.reagentBtn:IsShown()) and self.reagentBtn or self.charTag
    local from = anchor:GetRight()
    local show = true
    if edge and from then
      show = (edge - from - 16) >= math.ceil(self.slotText:GetStringWidth())
    end
    self.slotText:SetShown(show)
  end
  if self.title and self.money then
    self.title:SetText("WARPEE")
    local tw = math.ceil(self.title:GetStringWidth())
    local room = w - PAD * 2 - math.ceil(self.money:GetStringWidth()) - 12
    local show = tw <= 0 or room >= tw
    if not show then self.title:SetText("") end
    self.title:SetShown(show)
  end
end

function Bags:UpdateMeta()
  local used, total = self.used or 0, self.total or 0
  self.money:SetText(self:FormatMoney())
  self:UpdateBagBar()
  if self.slotText then
    self.slotText:SetText((ns.L["Slots %d/%d"]):format(used, total))
  end

  local frac = total > 0 and used / total or 0
  if self.showGauge then
    self.gaugeBg:Show(); self.gaugeFill:Show()
    self.gaugeFill:SetWidth(math.max(1, frac * gridWidth(self.pxSize or self.iconSize,
      self.cols, self.pxGap or self.gap)))
    self.gaugeFill:SetVertexColor(Theme:C("accent"))
  else
    self.gaugeBg:Hide(); self.gaugeFill:Hide()
  end
  self:FitHeader()
end

local QUALITY_WORDS = {
  poor = 0, junk = 0, grey = 0, gray = 0, common = 1, white = 1,
  uncommon = 2, green = 2, rare = 3, blue = 3, epic = 4, purple = 4,
  legendary = 5, orange = 5, artifact = 6, heirloom = 7,
}
local SLOT_WORDS = {
  head = {INVTYPE_HEAD=1}, helm = {INVTYPE_HEAD=1},
  neck = {INVTYPE_NECK=1},
  shoulder = {INVTYPE_SHOULDER=1}, shoulders = {INVTYPE_SHOULDER=1},
  back = {INVTYPE_CLOAK=1}, cloak = {INVTYPE_CLOAK=1},
  chest = {INVTYPE_CHEST=1, INVTYPE_ROBE=1},
  wrist = {INVTYPE_WRIST=1}, bracers = {INVTYPE_WRIST=1},
  hands = {INVTYPE_HAND=1}, gloves = {INVTYPE_HAND=1},
  waist = {INVTYPE_WAIST=1}, belt = {INVTYPE_WAIST=1},
  legs = {INVTYPE_LEGS=1}, pants = {INVTYPE_LEGS=1},
  feet = {INVTYPE_FEET=1}, boots = {INVTYPE_FEET=1},
  finger = {INVTYPE_FINGER=1}, ring = {INVTYPE_FINGER=1}, rings = {INVTYPE_FINGER=1},
  trinket = {INVTYPE_TRINKET=1}, trinkets = {INVTYPE_TRINKET=1},
  shield = {INVTYPE_SHIELD=1}, tabard = {INVTYPE_TABARD=1}, shirt = {INVTYPE_BODY=1},
  body = {INVTYPE_BODY=1},
  relic = {INVTYPE_RELIC=1},
  held = {INVTYPE_HOLDABLE=1},
  ranged = {INVTYPE_RANGED=1, INVTYPE_RANGEDRIGHT=1, INVTYPE_THROWN=1},
  thrown = {INVTYPE_THROWN=1},
  ammo = {INVTYPE_AMMO=1},
  quiver = {INVTYPE_QUIVER=1},
  tool = {INVTYPE_PROFESSION_TOOL=1},
  profgear = {INVTYPE_PROFESSION_GEAR=1},
  bagslot = {INVTYPE_BAG=1},
  weapon = {INVTYPE_WEAPON=1, INVTYPE_2HWEAPON=1, INVTYPE_WEAPONMAINHAND=1,
            INVTYPE_WEAPONOFFHAND=1, INVTYPE_RANGED=1, INVTYPE_RANGEDRIGHT=1},
  mainhand = {INVTYPE_WEAPONMAINHAND=1, INVTYPE_WEAPON=1, INVTYPE_2HWEAPON=1},
  offhand = {INVTYPE_WEAPONOFFHAND=1, INVTYPE_HOLDABLE=1, INVTYPE_SHIELD=1},
  ["2h"] = {INVTYPE_2HWEAPON=1, INVTYPE_RANGED=1, INVTYPE_RANGEDRIGHT=1},
  ["1h"] = {INVTYPE_WEAPON=1, INVTYPE_WEAPONMAINHAND=1, INVTYPE_WEAPONOFFHAND=1},
}
local IC  = Enum.ItemClass or {}
local IAS = Enum.ItemArmorSubclass or {}
local IWS = Enum.ItemWeaponSubclass or {}
local IMS = Enum.ItemMiscellaneousSubclass or {}
local function kind(cls, ...)
  if cls == nil then return nil end
  local subs
  for i = 1, select("#", ...) do
    local s = select(i, ...)
    if s ~= nil then subs = subs or {}; subs[s] = true end
  end
  return { class = cls, subs = subs }
end
local KIND_WORDS = {
  cloth    = kind(IC.Armor, IAS.Cloth),
  leather  = kind(IC.Armor, IAS.Leather),
  mail     = kind(IC.Armor, IAS.Mail),
  plate    = kind(IC.Armor, IAS.Plate),
  -- cosmetic is a flag, not a kind: see m.cosmetic (C_Item.IsCosmeticItem) and the classify branch,
  -- because Blizzard does not keep cosmetic appearances in the Cosmetic armor subclass.
  dagger   = kind(IC.Weapon, IWS.Dagger),
  sword    = kind(IC.Weapon, IWS.Sword1H, IWS.Sword2H),
  axe      = kind(IC.Weapon, IWS.Axe1H, IWS.Axe2H),
  mace     = kind(IC.Weapon, IWS.Mace1H, IWS.Mace2H),
  polearm  = kind(IC.Weapon, IWS.Polearm),
  staff    = kind(IC.Weapon, IWS.Staff),
  bow      = kind(IC.Weapon, IWS.Bows),
  gun      = kind(IC.Weapon, IWS.Guns),
  crossbow = kind(IC.Weapon, IWS.Crossbow),
  wand     = kind(IC.Weapon, IWS.Wand),
  fist     = kind(IC.Weapon, IWS.Unarmed),
  warglaive = kind(IC.Weapon, IWS.Warglaive),
  fishing  = kind(IC.Weapon, IWS.Fishingpole),
  mount    = kind(IC.Miscellaneous, IMS.Mount),
  gem      = kind(IC.Gem),
  recipe   = kind(IC.Recipe),
  glyph    = kind(IC.Glyph),
  bag      = kind(IC.Container),
  container = kind(IC.Container),
  -- pet / battlepet are NOT kinds: a caged pet's bag link is a battlepet: link, so GetItemInfoInstant
  -- gives no classID and a kind row never sees it. They are flags below, read off the link in buildMeta.
  projectile = kind(IC.Projectile),
  tradegoods = kind(IC.Tradegoods),
  misc     = kind(IC.Miscellaneous),
  enhancement = kind(IC.ItemEnhancement),
  -- Consumable subclasses by number, the way Vendor.lua already keys them (1 potion, 3 flask/phial,
  -- 5 food/drink). A number can never be a wrong-name nil the way Enum.ItemConsumableSubclass.X
  -- would, and a nil sub would widen kind() to every consumable.
  potion   = kind(IC.Consumable, 1),
  flask    = kind(IC.Consumable, 3),
  food     = kind(IC.Consumable, 5),
}
local EXP_WORDS = {
  classic = 0, vanilla = 0,
  tbc = 1, bc = 1, burningcrusade = 1,
  wotlk = 2, wrath = 2, lich = 2,
  cata = 3, cataclysm = 3,
  mop = 4, pandaria = 4,
  wod = 5, draenor = 5,
  legion = 6,
  bfa = 7, azeroth = 7,
  sl = 8, shadowlands = 8,
  df = 9, dragonflight = 9,
  tww = 10, warwithin = 10,
  midnight = 11,
}
local CUR_EXP = LE_EXPANSION_LEVEL_CURRENT
                or (GetExpansionLevel and GetExpansionLevel()) or 0
do
  for i = 0, CUR_EXP do
    local n = _G["EXPANSION_NAME" .. i]
    if type(n) == "string" and n ~= "" and not n:find("%s") then
      local k = ns.SearchFold(n)
      if EXP_WORDS[k] == nil then EXP_WORDS[k] = i end
    end
  end
end
local function classify(f, token)
  local bare = token:match("^[!%-](.+)$")
  local lo, hi = token:match("^ilvl(%d+)%-(%d+)$")
  local gt = token:match("^ilvl>=?(%d+)$")
  local lt = token:match("^ilvl<=?(%d+)$")
  local num = token:match("^ilvl(%d+)$") or token:match("^(%d+)$")
  if bare then
    f.nots = f.nots or {}
    f.nots[#f.nots + 1] = ns.ParseSearch(bare)
  elseif lo then
    f.ilvlMin, f.ilvlMax = tonumber(lo), tonumber(hi)
  elseif gt then
    f.ilvlMin = tonumber(gt) + (token:find(">=", 1, true) and 0 or 1)
  elseif lt then
    f.ilvlMax = tonumber(lt) - (token:find("<=", 1, true) and 0 or 1)
  elseif token:match("^id(%d+)$") then
    -- Match one exact itemID. A bare number is already ilvl, so the id is prefixed; several ids in
    -- one string OR together like kinds do, so a rule can name a small set (a Hearthstone category).
    f.ids = f.ids or {}
    f.ids[tonumber(token:match("^id(%d+)$"))] = true
  elseif num then
    f.ilvl = tonumber(num)
  elseif QUALITY_WORDS[token] then
    f.quality = QUALITY_WORDS[token]
  elseif SLOT_WORDS[token] then
    f.slots = f.slots or {}
    for k in pairs(SLOT_WORDS[token]) do f.slots[k] = true end
  elseif KIND_WORDS[token] then
    f.kinds = f.kinds or {}
    f.kinds[#f.kinds + 1] = KIND_WORDS[token]
  elseif EXP_WORDS[token] then
    f.exps = f.exps or {}
    f.exps[EXP_WORDS[token]] = true
  elseif token == "current" then
    f.exps = f.exps or {}
    f.exps[CUR_EXP] = true
  elseif token == "legacy" or token == "old" then
    f.expMax = CUR_EXP - 1
  elseif token == "warbound" or token == "wb" or token == "warband" then
    f.warbound = true
  elseif token == "soulbound" or token == "sb" or token == "bound" or token == "bop" then
    f.soulbound = true
  elseif token == "boe" or token == "unbound" then
    f.boe = true
  elseif token == "boa" or token == "accountbound" then
    f.boa = true
  elseif token == "token" or token == "tier" then
    f.token = true
  elseif token == "locked" or token == "blocked" then
    f.locked = true
  elseif token == "reagent" or token == "reagents" or token == "mats" then
    f.reagent = true
  elseif token == "keystone" or token == "key" or token == "mythic" then
    f.keystone = true
  elseif token == "battlepet" or token == "pet" then
    f.battlepet = true
  elseif token == "quest" then
    f.quest = true
  elseif token == "consumable" or token == "consumables" then
    f.consumable = true
  elseif token == "gear" or token == "equip" or token == "equipment" then
    f.gear = true
  elseif token == "toy" then
    f.toy = true
  elseif token == "cosmetic" then
    f.cosmetic = true
  elseif token == "housing" or token == "decor" then
    f.housing = true
  else
    return false
  end
  return true
end

function ns.ParseSearch(q)
  q = (q or ""):gsub("^%s+", ""):gsub("%s+$", "")
  -- A top-level "|" is OR across the whole rule, so a section can gather two things that sit on
  -- different axes and would otherwise AND to nothing (keystone | id6948, toy | mount). Each side is
  -- parsed on its own and MatchSearch keeps the item if any side matches. A bare or trailing "|" adds
  -- no side; a single surviving side collapses back to a plain filter so nothing downstream ever sees
  -- the wrapper, and only two-plus sides produce an ors node.
  if q:find("|", 1, true) then
    local ors = {}
    for raw in (q .. "|"):gmatch("([^|]*)|") do
      -- A local, not a write back into the loop variable: the trim belongs to this side alone.
      local part = raw:gsub("^%s+", ""):gsub("%s+$", "")
      if part ~= "" then ors[#ors + 1] = ns.ParseSearch(part) end
    end
    if #ors == 0 then return { text = {}, empty = true } end
    if #ors == 1 then return ors[1] end
    return { ors = ors }
  end
  local f = { text = {} }
  f.empty = q == ""
  for token in q:gmatch("%S+") do
    if not classify(f, token) then
      local alias = ns.SearchAlias(ns.SearchFold(token))
      if not (alias and classify(f, alias)) then
        f.text[#f.text + 1] = token
      end
    end
  end
  return f
end
-- The fields classify() can fill, in the order it checks them, each with the axis the editor names it by.
-- Reading the axis off a scratch filter rather than re-walking the string keeps the two honest: this
-- shares one classify() with the parser, so a token the parser learns to understand answers here too,
-- with no second place to edit. The booleans at the end are the flags the filter carries as facts.
local EXPLAIN_ROWS = {
  { "ids", "item" }, { "quality", "quality" },
  { "ilvl", "level" }, { "ilvlMin", "level" }, { "ilvlMax", "level" },
  { "slots", "slot" }, { "kinds", "kind" }, { "exps", "expansion" }, { "expMax", "expansion" },
  { "reagent", "kind" }, { "keystone", "kind" }, { "battlepet", "kind" }, { "quest", "kind" },
  { "consumable", "kind" }, { "gear", "kind" }, { "toy", "kind" }, { "housing", "kind" },
  { "token", "kind" },
  { "warbound", "flag" }, { "soulbound", "flag" }, { "boe", "flag" }, { "boa", "flag" },
  { "locked", "flag" },
}

-- The words classify answers to by name, as spelled. The four tables above cover the rest; every word
-- here is handed to classify before it is kept, so this list can never offer a word the parser refuses.
local FLAG_SPELLINGS = {
  "current", "legacy", "old", "warbound", "wb", "warband", "soulbound", "sb", "bound", "bop",
  "boe", "unbound", "boa", "accountbound", "token", "tier", "locked", "blocked",
  "reagent", "reagents", "mats", "keystone", "key", "mythic", "battlepet", "pet", "quest",
  "consumable", "consumables", "gear", "equip", "equipment", "toy", "housing", "decor",
}

-- The whole vocabulary the parser takes, each word with the axis it is read on, gathered from the tables
-- classify reads instead of being listed a second time. A language's own words are in there too, resolved
-- to the English token they stand for, so a Russian player is offered "латы" and "шлем" as readily as
-- "plate" and "helm". Built once, on the first keystroke that needs it.
local TOKEN_LIST, TOKEN_LOCALE
local function tokenWords()
  -- Keyed by language: the words a locale adds are part of the list, and the editor can switch language
  -- without a reload.
  local code = ns.LocalePick and ns.LocalePick() or nil
  if TOKEN_LIST and TOKEN_LOCALE == code then return TOKEN_LIST end
  local seen, out = {}, {}
  local function keep(word, token)
    if seen[word] then return end
    local probe = {}
    if classify(probe, token or word) then
      local axis = "flag"
      for _, row in ipairs(EXPLAIN_ROWS) do
        if probe[row[1]] ~= nil then axis = row[2]; break end
      end
      seen[word] = true
      out[#out + 1] = { word = word, axis = axis }
    end
  end
  for _, t in ipairs({ QUALITY_WORDS, SLOT_WORDS, KIND_WORDS, EXP_WORDS }) do
    for word in pairs(t) do keep(word) end
  end
  for _, word in ipairs(FLAG_SPELLINGS) do keep(word) end
  if ns.SearchWords then
    for _, pair in ipairs(ns.SearchWords()) do keep(pair[1], pair[2]) end
  end
  TOKEN_LOCALE, TOKEN_LIST = code, out
  return out
end

-- The next character of a string and where it ends: the game's text is utf-8, so a letter of a language
-- that writes it in two bytes is one letter to a comparison that has to count letters and not bytes.
local function charStep(s, i)
  local b = s:byte(i)
  if b == nil then return nil end
  local len = 1
  if b >= 240 then len = 4 elseif b >= 224 then len = 3 elseif b >= 192 then len = 2 end
  return i + len, s:sub(i, i + len - 1)
end

local function charCount(s)
  local n, i = 0, 1
  while true do
    local next1 = charStep(s, i)
    if not next1 then return n end
    n, i = n + 1, next1
  end
end

-- What a word might have been: the words it could still be growing into, and the words a single letter
-- away. Counted in letters, so a typo in a language that writes its letters in two bytes is still one
-- letter and still found. A suggestion that is merely missing costs nothing; a wrong one costs trust, so
-- the edit cases stay to what counting can tell apart.
local function nearWords(word, limit)
  limit = limit or 3
  local out, taken = {}, {}
  local function add(w)
    if taken[w] then return end
    taken[w] = true
    out[#out + 1] = w
  end
  local list = tokenWords()
  -- Every word is compared in its folded form, which is the form the parser reads a typed one in, while
  -- the word offered back is the one the language wrote.
  for _, entry in ipairs(list) do
    if #out >= limit then return out end
    local w = entry.word
    local fw = ns.SearchFold(w)
    if #fw > #word and fw:sub(1, #word) == word then add(w) end
  end
  if #out >= limit then return out end
  local lw = charCount(word)
  for _, entry in ipairs(list) do
    if #out >= limit then break end
    local w = entry.word
    local fw = ns.SearchFold(w)
    local n = charCount(fw)
    if n == lw and n > 1 then
      -- Same length: one letter may differ, and no more.
      local i, j, diff = 1, 1, 0
      while i <= #fw and j <= #word do
        local ni, ci = charStep(fw, i)
        local nj, cj = charStep(word, j)
        if ci ~= cj then
          diff = diff + 1
          if diff > 1 then break end
        end
        i, j = ni, nj
      end
      if diff == 1 and i > #fw and j > #word then add(w) end
    elseif n == lw + 1 or n == lw - 1 then
      -- One letter too many or too few: the shorter word has to be a run of the longer one, which a single
      -- walk answers — a match moves both on, a miss moves the longer one alone.
      local short, long = word, fw
      if n < lw then short, long = fw, word end
      local i, j = 1, 1
      while i <= #short and j <= #long do
        local ni, ci = charStep(short, i)
        local nj, cj = charStep(long, j)
        if ci == cj then i = ni end
        j = nj
      end
      if i > #short then add(w) end
    end
  end
  return out
end

-- One token as the parser took it: the axis it was understood on, the text as it was written (a word of the
-- player's own language is reported as written, since that is what they see), and whether a leading "!" or
-- "-" turned it into a NOT. A token no dictionary answers to — and that no alias resolves — comes back as
-- text, which is the one way a rule can look right and match nothing, so it carries the words it might have
-- meant: the field's own vocabulary is the only place a typo can be caught, since nothing else about the
-- line looks different.
local function explainPart(token)
  local bare = token:match("^[!%-](.+)$")
  local neg = bare ~= nil
  if bare then token = bare end
  local probe = {}
  local alias = ns.SearchAlias(ns.SearchFold(token))
  if classify(probe, token) or (alias and classify(probe, alias)) then
    for _, row in ipairs(EXPLAIN_ROWS) do
      if probe[row[1]] ~= nil then return { axis = row[2], token = token, neg = neg or nil } end
    end
    -- A field the parser filled that this table has no name for yet: still a word the parser knows, so it
    -- is reported as a flag rather than as text. Text is kept for the one case that means it — which is
    -- what makes the label worth reading.
    return { axis = "flag", token = token, neg = neg or nil }
  end
  local near = #token > 1 and nearWords(ns.SearchFold(token), 3) or nil
  return { axis = "text", token = token, neg = neg or nil,
           near = (near and #near > 0) and near or nil }
end

-- A rule read back as its sides: the shape `|` builds, one list per side, one part per token. The editor
-- turns that into chips; the parser is untouched, this only asks it what it saw. nil for an empty rule,
-- which matches everything and has nothing to explain.
function ns.ExplainSearch(q)
  q = (q or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if q == "" then return nil end
  local sides = {}
  for side in (q .. "|"):gmatch("([^|]*)") do
    local parts = {}
    for token in side:gmatch("%S+") do parts[#parts + 1] = explainPart(token) end
    if #parts > 0 then sides[#sides + 1] = parts end
  end
  return (#sides > 0) and sides or nil
end

function ns.MetaWarbound(m)
  if m.wb == nil then
    if not m.isGear then
      m.wb = false
    elseif m.bag then
      m.wb = ns.IsWarbound(m.bag, m.slot, m.loc, m.bound, m.link) and true or false
    elseif m.link and ns.IsLinkWarbound then
      -- No live bag slot (a snapshot or an id-only meta): fall back to the link reader when there is
      -- one. A meta with no link at all (RuleHome builds these) cannot answer warbound, so it is not
      -- warbound rather than a nil call on a link that is not there.
      m.wb = ns.IsLinkWarbound(m.link) and true or false
    else
      m.wb = false
    end
  end
  return m.wb
end

function ns.MetaExp(m)
  if m.exp == nil then
    local e = m.id and (select(15, C_Item.GetItemInfo(m.id)))
    if e == nil then return nil end
    m.exp = e
  end
  return m.exp
end

-- Lazy like MetaExp: the account-bind lookup and its cache live in ItemButton.lua, so this is only
-- read when a BoA rule is present. IsAccountBound loads late, so the call is guarded.
function ns.MetaBoA(m)
  if m.boa == nil then
    m.boa = (m.link and ns.IsAccountBound and ns.IsAccountBound(m.link, m.id)) and true or false
  end
  return m.boa
end

-- A toy is not a class of its own, so it is asked of the toybox. GetToyInfo answers for a toy the
-- player has never collected too, which is what a bag rule needs. The client caches the call, so a
-- per-slot ask on relayout is cheap; the boolean is still parked on the scratch meta for the pass.
function ns.MetaToy(m)
  if m.toy == nil then
    local info = m.id and C_ToyBox and C_ToyBox.GetToyInfo and C_ToyBox.GetToyInfo(m.id)
    m.toy = (info ~= nil) and true or false
  end
  return m.toy
end

-- Housing decor lives in its own item class (20, confirmed in game via GetItemClassInfo).
local HOUSING_CLASS = 20
function ns.MetaHousing(m)
  return m.classID == HOUSING_CLASS
end

function ns.MatchSearch(m, f)
  if not f or f.empty then return true end
  if not m then return false end
  -- An ors node carries no fields of its own, only its sides, so it returns here before the flat
  -- checks below (which are all nil-guarded and would otherwise pass an empty wrapper as match-all).
  if f.ors then
    for _, sub in ipairs(f.ors) do
      if ns.MatchSearch(m, sub) then return true end
    end
    return false
  end
  if f.nots then
    for _, n in ipairs(f.nots) do
      if ns.MatchSearch(m, n) then return false end
    end
  end
  for _, t in ipairs(f.text) do
    if not (m.text and m.text:find(t, 1, true)) then return false end
  end
  if f.ids and not (m.id and f.ids[m.id]) then return false end
  if f.quality ~= nil and m.q ~= f.quality then return false end
  if f.ilvl and m.ilvl ~= f.ilvl then return false end
  if f.ilvlMin and not (m.ilvl and m.ilvl >= f.ilvlMin) then return false end
  if f.ilvlMax and not (m.ilvl and m.ilvl <= f.ilvlMax) then return false end
  if f.slots and not (m.equipLoc and f.slots[m.equipLoc]) then return false end
  if f.kinds then
    local ok = false
    for _, k in ipairs(f.kinds) do
      if m.classID == k.class and (not k.subs or (m.subID and k.subs[m.subID])) then
        ok = true
        break
      end
    end
    if not ok then return false end
  end
  if f.exps then
    local e = ns.MetaExp(m)
    if not (e and f.exps[e]) then return false end
  end
  if f.expMax then
    local e = ns.MetaExp(m)
    if not (e and e <= f.expMax) then return false end
  end
  if f.warbound and not ns.MetaWarbound(m) then return false end
  if f.soulbound and not (m.bound and not ns.MetaWarbound(m)) then return false end
  if f.boe and not (m.isGear and not m.bound) then return false end
  if f.boa and not ns.MetaBoA(m) then return false end
  if f.token and not (m.id and ns.TIER_TOKENS and ns.TIER_TOKENS[m.id]) then return false end
  if f.locked and not (m.id and ns.Vendor and ns.Vendor:Blocked(m.id)) then return false end
  if f.reagent and not m.reagent then return false end
  if f.keystone and not m.keystone then return false end
  if f.battlepet and not m.battlepet then return false end
  if f.cosmetic and not m.cosmetic then return false end
  if f.quest and m.classID ~= Enum.ItemClass.Questitem then return false end
  if f.consumable and m.classID ~= Enum.ItemClass.Consumable then return false end
  if f.gear and not (m.classID == Enum.ItemClass.Armor
     or m.classID == Enum.ItemClass.Weapon) then return false end
  if f.toy and not ns.MetaToy(m) then return false end
  if f.housing and not ns.MetaHousing(m) then return false end
  return true
end

-- A search in category view re-folds sections by hit, but a fold per keystroke jumps the layout as
-- similar prefixes match and drop. So the relayout waits out a short quiet after the last key: each
-- keystroke re-arms the timer and only the final one fires, folding once against the settled query.
-- A token guards it so a stale timer that outlived the window or another relayout does nothing.
function Bags:ScheduleCatFold()
  self.catFoldToken = (self.catFoldToken or 0) + 1
  local mine = self.catFoldToken
  C_Timer.After(0.25, function()
    if self.catFoldToken ~= mine then return end
    if self.frame and self.frame:IsShown() and self:CatMode() then self:Layout() end
  end)
end

function Bags:ApplySearch()
  local p = self:Pool()
  for j = 1, (self.shown or 0) do self:ApplyToButton(p[j]) end
  -- A ghost stands for a pinned item that is not in the bags, so it can never be a search hit and is
  -- dimmed with the row's misses instead of staying lit while everything around it fades. It is a
  -- frame parented to the window, not a child of its slot button, so the button's own dim never
  -- reaches it: the alpha is set here by hand, and cleared back to full the moment the query is empty.
  local ghostA = (self.filters and not self.filters.empty) and 0.20 or 1
  for _, row in ipairs({ ns.Fav, ns.Recent }) do
    if row and row.ghosts then
      for _, g in ipairs(row.ghosts) do g:SetAlpha(ghostA) end
    end
  end
  if ns.Fav and ns.Fav.slots then
    for _, b in ipairs(ns.Fav.slots) do if b:IsShown() then self:ApplyToButton(b) end end
  end
  if ns.Recent and ns.Recent.slots then
    for _, b in ipairs(ns.Recent.slots) do if b:IsShown() then self:ApplyToButton(b) end end
  end
end

function Bags:RefreshNewItems()
  if self.snap or not (self.frame and self.frame:IsShown() and self.pool) then return end
  for i = 1, (self.shown or 0) do
    local btn = self.pool[i]
    if btn then ns.SyncNewItem(btn) end
  end
end

function Bags:RefreshQuests()
  if self.snap or not (self.frame and self.frame:IsShown() and self.pool) then return end
  for i = 1, (self.shown or 0) do
    local btn = self.pool[i]
    if btn and ns.SyncQuestMark(btn) then
      btn.link = nil
      ns.UpdateItemButton(btn)
      self:ApplyToButton(btn)
    end
  end
end

function Bags:RefreshCooldowns()
  if self.snap or not (self.frame and self.frame:IsShown() and self.pool) then return end
  for i = 1, (self.shown or 0) do
    local b = self.pool[i]
    if b and b.link then ns.UpdateCooldown(b) end
  end
end

function Bags:ApplyToButton(b)
  local blocked = (ns.DepositBlocked and ns.DepositBlocked(b))
    or (ns.AuctionBlocked and ns.AuctionBlocked(b))
    or (ns.ContextBlocked and ns.ContextBlocked(b))
    or (ns.GuildDepositBlocked and ns.GuildDepositBlocked(b))
    or (ns.MailBlocked and ns.MailBlocked(b))
  ns.ApplySearchToButton(b, self.filters, blocked)
end

function Bags:UpdateDirty()
  if not (self.frame and self.frame:IsShown()) then self.dirty = {}; return end
  self:Build()
  if not (self.content and self.gaugeBg and self.gaugeFill and self.gridBg
          and self.money and self.reagentLabel) then
    self.dirty = {}
    return
  end
  if not self.byKey then
    self.dirty = {}
    self:Layout(true)
    return
  end
  -- Cat mode rebuilds the whole pass because a changed slot can leave its section, and
  -- Layout(true) captures the bags itself, so the incremental capture here would be thrown
  -- away a line later. Skip it and let the full pass do the one capture.
  if self:CatMode() then
    if next(self.dirty) then self.dirty = {}; self:Layout(true) end
    return
  end
  if next(self.dirty) then ns.Vault:Capture("bags", self.dirty) end
  if self.snap then self.dirty = {}; return end
  -- A cell that moved needs the grid rebuilt, and the swap that caused it is usually two
  -- bags of the same size: the total alone says nothing, so every bag is compared. The
  -- counts are read in the loop that was already running.
  local total, used, moved = 0, 0, false
  local have = self.bagSlots or {}
  for _, bag in ipairs(ns.playerBags) do
    local num = C_Container.GetContainerNumSlots(bag) or 0
    total = total + num
    used = used + (num - (select(1, C_Container.GetContainerNumFreeSlots(bag)) or 0))
    if have[bag] ~= num then moved = true end
  end
  local rnum = C_Container.GetContainerNumSlots(ns.reagentBag) or 0
  if have[ns.reagentBag] ~= rnum then moved = true end
  if rnum > 0 then
    total = total + rnum
    used = used + (rnum - (select(1, C_Container.GetContainerNumFreeSlots(ns.reagentBag)) or 0))
  end
  if moved or total ~= self.total then self.dirty = {}; self:Layout(true); return end
  self.used = used
  for bag in pairs(self.dirty) do
    local num = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, num do
      local b = self.byKey[bag * 1000 + slot]
      if b then ns.UpdateItemButton(b); self:ApplyToButton(b) end
    end
  end
  self.dirty = {}
  self:UpdateMeta()
end

function Bags:SortBags()
  self.sorting = true
  self:SortSettle()
  C_Container.SortBags()
end

function Bags:SortSettle()
  self.sortGen = (self.sortGen or 0) + 1
  local gen = self.sortGen
  C_Timer.After(0.2, function()
    if self.sortGen ~= gen then return end
    self.sorting = false
    for _, bag in ipairs(ns.playerBags) do self.dirty[bag] = true end
    self.dirty[ns.reagentBag] = true
    if self.frame and self.frame:IsShown() then self:UpdateDirty() end
  end)
end

function Bags:RestorePos()
  ns.PlaceWindow(self.frame, "pos")
end

function Bags:Refresh()
  self:Build()
  if self.frame:IsShown() then self:Layout(true) end
end
