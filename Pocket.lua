local addonName, ns = ...
local Theme = ns.Theme

local Pocket = {}
ns.Pocket = Pocket
Pocket.slots, Pocket.ghosts, Pocket.catchers = {}, {}, {}
Pocket.recSlots, Pocket.recGhosts = {}, {}

local PAD, BAND = 12, 26
local NUDGE_BAND = 24
local LABEL_H, LABEL_GAP, SPLIT = 13, 4, 10
local BOX_H, BOX_GAP = 22, 8
local MAX_COLS, MAX_ROWS = 8, 6
local PICK_MAX, PICK_COLS = 64, 8
local PICK_SIZE, PICK_GAP, PICK_PAD = 36, 8, 12

local POCKET_PICKS = {
  272195, -- Vantus Rune: Tides
  243734, -- Thalassian Phoenix Oil
  259085, -- Void-Touched Augment Rune
  132514, -- auto-hammer
  269586, -- Emergency Soul Link
  248486, -- Emergency Soul Link
  242747, -- Hearty Royal Roast
  242275, -- Royal Roast
  271884, -- Concentrated Silvermoon Health Potion
  271883, -- Concentrated Silvermoon Health Potion
  241300, -- Lightfused Mana Potion
  241301, -- Lightfused Mana Potion
  245916, -- Fleeting Lightfused Mana Potion
  241308, -- Light's Potential
  241309, -- Light's Potential
  245898, -- Fleeting Light's Potential
  241292, -- Draught of Rampant Abandon
  241293, -- Draught of Rampant Abandon
  245910, -- Fleeting Draught of Rampant Abandon
  241288, -- Potion of Recklessness
  241289, -- Potion of Recklessness
  245902, -- Fleeting Potion of Recklessness
  271887, -- Liquid Luster
  271886, -- Liquid Luster
  274764, -- Fleeting Liquid Luster
  241324, -- Flask of the Blood Knights
  241325, -- Flask of the Blood Knights
  245931, -- Fleeting Flask of the Blood Knights
  241326, -- Flask of the Shattered Sun
  241327, -- Flask of the Shattered Sun
  245929, -- Fleeting Flask of the Shattered Sun
  241322, -- Flask of the Magisters
  241323, -- Flask of the Magisters
  245933, -- Fleeting Flask of the Magisters
  241320, -- Flask of Thalassian Resistance
  241321, -- Flask of Thalassian Resistance
  245926, -- Fleeting Flask of Thalassian Resistance
}

local function charKey()
  local n = UnitName("player") or "?"
  local r = (GetNormalizedRealmName and GetNormalizedRealmName())
            or (GetRealmName and GetRealmName()) or "?"
  return n .. "-" .. r
end

function Pocket:Enabled()
  return not (WarpeeDB and WarpeeDB.pocketShow == false)
end

-- Its own lock, not the one the bags and the bank share. The pocket is dragged far more often
-- than the two big windows, and freezing all three together meant the only way to nudge it was
-- to unfreeze everything. The login block seeds this from the old lock once, so a save written
-- before the split keeps the pocket where it was left.
function Pocket:Locked()
  return (WarpeeDB and WarpeeDB.pocketLock) and true or false
end

function Pocket:ToggleLock()
  if WarpeeDB then WarpeeDB.pocketLock = not self:Locked() end
  self:Layout()
end

function Pocket:Cols()
  local n = math.floor(tonumber(WarpeeDB and WarpeeDB.pocketCols) or 6)
  return math.max(4, math.min(MAX_COLS, n))
end

function Pocket:Rows()
  local n = math.floor(tonumber(WarpeeDB and WarpeeDB.pocketRows) or 5)
  return math.max(1, math.min(MAX_ROWS, n))
end

function Pocket:Count()
  return self:Cols() * self:Rows()
end

local function paintTitle()
  local t = Pocket.title
  if not t then return end
  local k = Pocket:Cols() >= 8 and "FANNY PACK" or "POCKET"
  if Pocket.titleKey ~= k then
    Pocket.titleKey = k
    ns.LocalText(t, k)
  end
end

function Pocket:List()
  WarpeeDB.pocket = WarpeeDB.pocket or {}
  local k = charKey()
  WarpeeDB.pocket[k] = WarpeeDB.pocket[k] or {}
  return WarpeeDB.pocket[k]
end

-- Pinned cells are shared with the favorites row in the bag window. Read the block above
-- ns.PinArg in ItemButton.lua before touching anything a cell knows or shows, and make the
-- change there so both rows get it: this file owns only the window, the layout, the tooltip
-- and the click overlay. The lists themselves stay apart, this one is its own.
local pins = {}
local keyDirty = true

local function scan()
  if not keyDirty then return end
  keyDirty = false
  ns.PinScan(Pocket:List(), Pocket:Count(), pins)
end

local function locate(pin)
  scan()
  return ns.PinLocate(pin, pins)
end

local function worn(pin)
  scan()
  return ns.PinWorn(pin, pins)
end

local deferred = false

local function later()
  if deferred then return end
  deferred = true
  C_Timer.After(0, function()
    deferred = false
    Pocket:Refresh()
  end)
end

local dragIcon

local function dragArt()
  if dragIcon then return dragIcon end
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetFrameStrata("TOOLTIP")
  f:SetSize(32, 32)
  f:SetAlpha(0.85)
  f:Hide()
  local t = f:CreateTexture(nil, "OVERLAY")
  t:SetAllPoints()
  t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  f.icon = t
  f:SetScript("OnUpdate", function(s)
    if not IsMouseButtonDown("LeftButton") then Pocket:Drop(); return end
    local x, y = GetCursorPosition()
    local k = UIParent:GetEffectiveScale()
    s:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / k, y / k)
  end)
  dragIcon = f
  return f
end

local function tipFor(c, index)
  local pin = Pocket:List()[index]
  GameTooltip:SetOwner(c, "ANCHOR_RIGHT")
  if pin then
    local b = Pocket.slots[index]
    if b and b.pkBag and b.holder:IsShown() then
      GameTooltip:SetBagItem(b.pkBag, b.pkSlot)
    else
      if type(pin) == "string" then
        GameTooltip:SetHyperlink(pin)
      else
        GameTooltip:SetItemByID(pin)
      end
      if worn(pin) then
        GameTooltip:AddLine(ns.L["Equipped"], 0.6, 0.6, 0.6, true)
      end
    end
  else
    GameTooltip:SetText(ns.L["Pocket"])
    GameTooltip:AddLine(ns.L["Drag an item here to keep it one click away"], 0.6, 0.6, 0.6, true)
  end
  GameTooltip:Show()
end

-- The overlay owns the left button for good and passes the right button down to the
-- slot, so a right click reaches the game's handler with no addon code in the path.
-- SetPassThroughButtons is refused during combat lockdown, so it is set here, once,
-- and never touched again. That is why clearing a cell lives on Ctrl + left click.
-- The overlay must never finish a pending item spell itself: C_Container.UseContainerItem
-- from addon code is refused as ADDON_ACTION_FORBIDDEN, traceback 2026-09-05. An enchant
-- or a gem lands only in the bag grid: the game runs that from the left button of its
-- own slot handler, and every row here keeps the right button alone.
local function makeCatcher(parent, index)
  local c = CreateFrame("Button", nil, parent)
  c.pkIndex = index
  c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  c:RegisterForDrag("LeftButton")
  c:SetFrameLevel(parent:GetFrameLevel() + 30)
  c:EnableMouse(true)
  if c.SetPassThroughButtons then c:SetPassThroughButtons("RightButton") end
  c:SetScript("OnDragStart", function(s) Pocket:Lift(s.pkIndex) end)
  c:SetScript("OnDragStop", function() Pocket:Drop() end)
  c:SetScript("OnReceiveDrag", function(s) Pocket:PinFromCursor(s.pkIndex) end)
  c:SetScript("OnClick", function(s, button)
    if button ~= "LeftButton" then return end
    if GetCursorInfo() then
      Pocket:PinFromCursor(s.pkIndex)
      return
    end
    if IsShiftKeyDown() and not (IsControlKeyDown() or IsAltKeyDown()) then
      Pocket:Link(s.pkIndex)
      return
    end
    if IsAltKeyDown() and not (IsShiftKeyDown() or IsControlKeyDown()) then
      Pocket:Lock(s.pkIndex)
      return
    end
    if IsControlKeyDown() and not (IsShiftKeyDown() or IsAltKeyDown()) then
      Pocket:Set(s.pkIndex, nil)
      tipFor(s, s.pkIndex)
    end
  end)
  c:SetScript("OnEnter", function(s)
    local b = Pocket.slots[s.pkIndex]
    if b and b.holder:IsShown() then ns.SetSlotHighlight(b, true) end
    tipFor(s, s.pkIndex)
  end)
  c:SetScript("OnLeave", function(s)
    local b = Pocket.slots[s.pkIndex]
    if b then ns.SetSlotHighlight(b, false) end
    GameTooltip:Hide()
  end)
  return c
end

function Pocket:Link(index)
  local pin = self:List()[index]
  if not (pin and ChatEdit_InsertLink) then return end
  local b = self.slots[index]
  local link
  if b and b.pkBag and b.holder:IsShown() then
    link = C_Container.GetContainerItemLink(b.pkBag, b.pkSlot)
  end
  if not link then link = select(2, C_Item.GetItemInfo(pin)) end
  if link then ChatEdit_InsertLink(link) end
end

function Pocket:Set(index, pin)
  local list = self:List()
  if pin then
    local k = ns.ItemKey(pin)
    for i, own in pairs(list) do
      if i ~= index and k and ns.ItemKey(own) == k then list[i] = nil end
    end
  end
  list[index] = pin or nil
  keyDirty = true
  later()
end

function Pocket:Lock(index)
  local id = ns.ItemStubID(self:List()[index])
  local V = ns.Vendor
  if not (id and V and V.Toggle) then return end
  V:Toggle(id, (C_Item.GetItemInfo(id)) or tostring(id))
  local c = self.catchers[index]
  if c and c:IsShown() and c:IsMouseOver() then tipFor(c, index) end
end

function Pocket:Lift(index)
  local pin = self:List()[index]
  if not pin then return end
  self.moving = index
  local b = self.slots[index]
  if b then ns.SetSlotHighlight(b, true) end
  if ns.ItemSound then ns.ItemSound("pickup", b and b.pkBag, b and b.pkSlot) end
  local f = dragArt()
  local sz = math.max(16, (b and b:GetWidth()) or 0)
  f:SetSize(sz, sz)
  f.icon:SetTexture(ns.PinIcon(ns.ItemStubID(pin)))
  f:Show()
end

function Pocket:Drop()
  local from = self.moving
  self.moving = nil
  if dragIcon then dragIcon:Hide() end
  if not from then return end
  local b = self.slots[from]
  if b then ns.SetSlotHighlight(b, false) end
  if ns.ItemSound then ns.ItemSound("drop", b and b.pkBag, b and b.pkSlot) end
  local list = self:List()
  for i = 1, (self.max or 0) do
    local c = self.catchers[i]
    if i ~= from and c and c:IsShown() and c:IsMouseOver() then
      list[from], list[i] = list[i], list[from]
      later()
      return
    end
  end
end

function Pocket:PinFromCursor(index)
  local kind, a, link = GetCursorInfo()
  if kind ~= "item" then return end
  local id = tonumber(a)
  if not id and link then id = tonumber(link:match("item:(%d+)")) end
  if not id then return end
  ClearCursor()
  local pin = ns.PinFor(id, link)
  if ns.ItemSound then ns.ItemSound("drop", locate(pin)) end
  self:Set(index, pin)
end

function Pocket:DropID(id)
  id = tonumber(id)
  if not id then return false end
  local list = self:List()
  for i = 1, self:Count() do
    if ns.ItemStubID(list[i]) == id then
      self:Set(i, nil)
      if self.picksFrame and self.picksFrame:IsShown() then self:PickPaint() end
      return true
    end
  end
  return false
end

function Pocket:AddID(id, pin)
  id = tonumber(id)
  if not id then return false end
  if not pin and ns.GearID(id) then
    print("|cffd9a85fWarpee|r |cffffffff"
      .. (ns.L["Gear is pinned by dragging it or pasting its link, a bare id cannot tell one copy from another."] or "") .. "|r")
    return false
  end
  local list = self:List()
  local n = self:Count()
  for i = 1, n do
    if ns.ItemStubID(list[i]) == id then return false end
  end
  for i = 1, n do
    if not list[i] then
      if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
      self:Set(i, pin or id)
      if self.picksFrame and self.picksFrame:IsShown() then self:PickPaint() end
      C_Timer.After(0.4, function() Pocket:Refresh() end)
      return true
    end
  end
  return false
end

function Pocket:AddByText(text)
  local s = tostring(text or "")
  local link = s:match("|H(item:[^|]+)|h") or s:match("^(item:[^|%s]+)")
  local id = tonumber(s:match("item:(%d+)")) or tonumber(s:match("%d+"))
  if not id then return end
  local get = C_Item and C_Item.GetItemInfoInstant
  if get and not get(id) then return end
  self:AddID(id, link and ns.PinFor(id, link) or nil)
end

function Pocket:Cooldowns()
  if not (self.frame and self.frame:IsShown()) then return end
  for i = 1, (self.max or 0) do
    local b = self.slots[i]
    if b and b.link and b.holder:IsVisible() then ns.UpdateCooldown(b) end
  end
  for i = 1, (self.recMax or 0) do
    local b = self.recSlots[i]
    if b and b.link and b.holder:IsVisible() then ns.UpdateCooldown(b) end
  end
end

function Pocket:Build()
  if self.frame then return self.frame end
  local w = CreateFrame("Frame", "WarpeePocket", UIParent, "BackdropTemplate")
  Theme:Panel(w, "bg", "stroke")
  Theme:Window(w, "WarpeePocket")
  w:SetClampedToScreen(true)
  w:SetMovable(true)
  w:EnableMouse(true)
  w:RegisterForDrag("LeftButton")
  w:SetScript("OnDragStart", function(s)
    if Pocket:Locked() then return end
    ns.DragMove(s)
  end)
  w:SetScript("OnDragStop", function(s)
    if not s.wpeMoving then return end
    s.wpeMoving = nil
    s:StopMovingOrSizing()
    local pp, rp, x, y = ns.SnapFrame(s)
    if pp then WarpeeDB.pocketPos = { p = pp, rp = rp, x = x, y = y } end
    if ns.Profiles and ns.Profiles.SyncActive then ns.Profiles:SyncActive() end
  end)
  ns.EscClose(w)
  ns.PixelJob(w, function(s) ns.AlignToScreen(s) end, "align")

  local title = Theme:Title(w, 14, "accent")
  self.title = title
  paintTitle()

  local close = ns.CreateGlyphButton(w, "×")
  close:SetScript("OnClick", function() Pocket:Close() end)
  self.closeBtn = close

  local gear = ns.CreateGlyphButton(w, "|TInterface\\Buttons\\UI-OptionsButton:13:13:0:0|t")
  gear:SetScript("OnClick", function() if ns.Options then ns.Options:Toggle() end end)
  ns.AddTip(gear, ns.L["Settings"], "top")
  self.gearBtn = gear

  local plus = ns.CreateGlyphButton(w, "+")
  plus:SetScript("OnClick", function() Pocket:TogglePicks() end)
  ns.AddTip(plus, ns.L["Popular"], "top")
  self.plusBtn = plus

  local lock = ns.CreateGlyphButton(w, "")
  lock:SetScript("OnClick", function() Pocket:ToggleLock() end)
  local lockIcon = lock:CreateTexture(nil, "ARTWORK")
  lockIcon:SetSize(15, 15)
  lockIcon:SetPoint("CENTER")
  ns.BadgeArt(lockIcon, "blocked")
  lock.icon = lockIcon
  ns.AddTip(lock, function() return ns.L["Lock the pocket"] end, "top")
  self.lockBtn = lock

  self.nudge = ns.CreateNudgeRow(w, "pocketPos")

  local rec = Theme:Label(w, 11, "dim")
  rec:SetJustifyH("LEFT")
  ns.LocalText(rec, "Recent")
  rec:Hide()
  self.recLabel = rec

  local clr = ns.CreateTextButton(w, 10)
  ns.LocalText(clr.Text, "Clear")
  clr:SetScript("OnClick", function(s)
    if s.wpeOn and ns.Recent then ns.Recent:Wipe() end
  end)
  clr:Hide()
  self.recWipe = clr

  local picks = CreateFrame("Frame", "WarpeePocketPicks", UIParent, "BackdropTemplate")
  Theme:Panel(picks, "bg", "stroke")
  Theme:Window(picks)
  picks:SetClampedToScreen(true)
  picks:EnableMouse(true)
  picks:Hide()
  ns.EscClose(picks)
  self.picksFrame = picks

  local ptitle = Theme:Title(picks, 14, "accent")
  ns.LocalText(ptitle, "Popular")
  self.picksTitle = ptitle

  local pclose = ns.CreateGlyphButton(picks, "×", 22)
  pclose:SetScript("OnClick", function() Pocket:TogglePicks() end)
  self.picksClose = pclose

  self.pickBtns = {}
  for i = 1, PICK_MAX do
    local b = CreateFrame("Button", nil, picks, "BackdropTemplate")
    ns.PixelBackdrop(b)
    ns.SetBg(b, Theme:C("slot"))
    ns.SetEdge(b, Theme:C("emptyLine"))
    local function pickBorder(s)
      ns.SetEdge(s, Theme:C(s.wpePinned and "accent" or "emptyLine"))
    end
    Theme:Track(b, function(s)
      ns.SetBg(s, Theme:C("slot"))
      pickBorder(s)
    end)
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnEnter", function(s)
      ns.SetBg(s, Theme:C("panelHi"))
      ns.SetEdge(s, Theme:C("accent"))
      GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
      if s.wpeID then
        GameTooltip:SetItemByID(s.wpeID)
        if s.wpePinned then
          GameTooltip:AddLine(ns.L["Already in the pocket"], 0.6, 0.6, 0.6, true)
        end
      end
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(s)
      ns.SetBg(s, Theme:C("slot"))
      pickBorder(s)
      GameTooltip:Hide()
    end)
    b:SetScript("OnClick", function(s)
      if not s.wpeID then return end
      if s.wpePinned then
        Pocket:DropID(s.wpeID)
      elseif Pocket:AddID(s.wpeID) then
        if ns.ItemSound then ns.ItemSound("pickup") end
      end
    end)
    local ic = b:CreateTexture(nil, "ARTWORK")
    ic:SetPoint("TOPLEFT", 1, -1)
    ic:SetPoint("BOTTOMRIGHT", -1, 1)
    ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.icon = ic
    local tier = b:CreateTexture(nil, "OVERLAY")
    tier:SetPoint("TOPLEFT", b, "TOPLEFT", -3, 2)
    tier:Hide()
    b.tier = tier
    b:Hide()
    self.pickBtns[i] = b
  end

  local box = ns.CreateSearchBox(picks, nil, "Add ID")
  box.wpeLinkID = true
  box:SetHeight(22)
  box:SetScript("OnEnterPressed", function(s)
    Pocket:AddByText(s:GetText())
    s:SetText("")
    s:ClearFocus()
  end)
  box:SetScript("OnEscapePressed", function(s)
    s:SetText("")
    s:ClearFocus()
  end)
  box:SetScript("OnEditFocusLost", function(s) s:SetText("") end)
  self.idBox = box

  w:Hide()
  self.frame = w
  return w
end

-- Every cell is a container slot button, so all of them are built here, out of combat,
-- and a redraw only moves and re-ids them after that. A button made during a fight is
-- tainted for good, and the overlay above it cannot be configured then either.
function Pocket:Warm()
  if not self:Enabled() then return end
  local w = self:Build()
  if InCombatLockdown() then self.cold = true; return end
  local n = self:Count()
  for i = 1, n do
    if not self.slots[i] then
      local b = ns.CreateItemButton(w, 0, 1)
      b:RegisterForClicks(unpack(ns.CLICKS_USE))
      b:RegisterForDrag()
      b.wpeClicks, b.wpeLockable, b.wpeTotal = ns.CLICKS_USE, nil, true
      b.holder:Hide()
      self.slots[i] = b
    end
    if not self.ghosts[i] then
      local g = ns.PinGhost(w)
      g.plus:Hide()
      g:Hide()
      self.ghosts[i] = g
    end
    if not self.catchers[i] then
      local c = makeCatcher(w, i)
      c:Hide()
      self.catchers[i] = c
    end
  end
  local m = self:Cols()
  for i = 1, m do
    if not self.recSlots[i] then
      local b = ns.CreateItemButton(w, 0, 1)
      b:RegisterForClicks(unpack(ns.CLICKS_USE))
      b.wpeClicks, b.wpeLockable, b.wpeTotal = ns.CLICKS_USE, nil, nil
      b.wpeNoNew, b.wpeNoReagent = true, true
      b.holder:Hide()
      self.recSlots[i] = b
    end
    if not self.recGhosts[i] then
      local g = ns.SlotGhost(w)
      g.plus:Hide()
      g.icon:Hide()
      ns.RecMark(g)
      g:Hide()
      self.recGhosts[i] = g
    end
  end
  self.cold = nil
  self.warmed = math.max(self.warmed or 0, n)
  self.recWarmed = math.max(self.recWarmed or 0, m)
end

function Pocket:Flush()
  if not self.cold or InCombatLockdown() then return end
  self:Warm()
  self:Refresh()
end

function Pocket:Layout()
  local w = self.frame
  if not w then return end
  local Bags = ns.Bags
  local size, gap, step = ns.GridMetrics(w,
    (WarpeeDB and tonumber(WarpeeDB.pocketIconSize)) or (Bags and Bags.iconSize) or 37,
    Bags and Bags.gap or 4)
  local cols, rows = self:Cols(), self:Rows()
  local n = cols * rows
  if (self.warmed or 0) < n or (self.recWarmed or 0) < cols then self:Warm() end
  local band = Theme:HeaderBand(w, BAND)
  local head = band and (band + 6) or (30 + Theme:TopInset())
  local mid = (band or head) / 2 + Theme:TitleDrop()
  local path = ns.Fonts:Current()
  self.title:SetFont(path, 14, "")
  paintTitle()
  self.title:ClearAllPoints()
  ns.SnapPoint(self.title, "LEFT", w, "TOPLEFT", PAD, -mid)
  self.closeBtn:ClearAllPoints()
  ns.SnapPoint(self.closeBtn, "RIGHT", w, "TOPRIGHT", -6, -mid)
  local rightBtn = self.closeBtn
  if self.gearBtn then
    self.gearBtn:ClearAllPoints()
    ns.SnapPoint(self.gearBtn, "RIGHT", rightBtn, "LEFT", -4, 0)
    rightBtn = self.gearBtn
  end
  -- The lock sits between the gear and the plus, so the plus keeps the outermost slot it has
  -- always had and the new button is the one that moves in.
  if self.lockBtn then
    self.lockBtn:ClearAllPoints()
    ns.SnapPoint(self.lockBtn, "RIGHT", rightBtn, "LEFT", -4, 0)
    rightBtn = self.lockBtn
    self.lockBtn.icon:SetVertexColor(Theme:C(self:Locked() and "accent" or "dim"))
    self.lockBtn:Show()
  end
  if self.plusBtn then
    self.plusBtn:ClearAllPoints()
    ns.SnapPoint(self.plusBtn, "RIGHT", rightBtn, "LEFT", -4, 0)
    rightBtn = self.plusBtn
  end

  local gen = ((Bags and Bags.styleGen) or 0) .. ":" .. tostring(path) .. ":" .. size
  local repaint = self.paintKey ~= gen
  self.paintKey = gen

  local R = ns.Recent
  local recOn = (R and R:PocketOn()) and true or false
  local y = head
  if recOn then
    self.recLabel:SetFont(path, 11, "")
    self.recLabel:ClearAllPoints()
    ns.SnapPoint(self.recLabel, "TOPLEFT", w, "TOPLEFT", PAD, -y)
    self.recLabel:Show()
    local capY = y
    y = y + LABEL_H + LABEL_GAP
    local feed = R:Feed(cols)
    self.recWipe.Text:SetFont(path, 10, "")
    self.recWipe:SetSize(math.ceil(self.recWipe.Text:GetStringWidth()) + 8, LABEL_H)
    self.recWipe:ClearAllPoints()
    ns.SnapPoint(self.recWipe, "TOPLEFT", w, "TOPLEFT",
                 PAD + math.ceil(self.recLabel:GetStringWidth()) + 10, -capY)
    self.recWipe:SetOn(feed[1] and true or false)
    self.recWipe:Show()
    for i = 1, math.max(cols, self.recMax or 0) do
      local b, g = self.recSlots[i], self.recGhosts[i]
      local id = (i <= cols) and feed[i] or nil
      local bag, slot = R:Where(id)
      if id and bag and not b then self.cold = true end
      local live = (id and bag and b) and true or false
      if live then
        if b.pkBag ~= bag or b.pkSlot ~= slot then
          b.pkBag, b.pkSlot, b.wpeBagID = bag, slot, bag
          b.holder:SetID(bag)
          b:SetID(slot)
          b.link = nil
        end
        local h = b.holder
        ns.SnapSize(h, size, size)
        h:ClearAllPoints()
        ns.SnapPoint(h, "TOPLEFT", w, "TOPLEFT", PAD + (i - 1) * step, -y)
        h:Show(); b:Show()
        b.wpeForce = R:Got(id)
        if repaint then b.link = nil end
        ns.UpdateItemButton(b)
        if g then g:Hide() end
      else
        if b then b.holder:Hide(); b.pkBag, b.wpeForce = nil, nil end
        if g and i <= cols then
          ns.SnapBox(g, size, size)
          g:ClearAllPoints()
          ns.SnapPoint(g, "TOPLEFT", w, "TOPLEFT", PAD + (i - 1) * step, -y)
          g:Show()
        elseif g then
          g:Hide()
        end
      end
    end
    self.recMax = cols
    y = y + size + SPLIT
  else
    self.recLabel:Hide()
    self.recWipe:Hide()
    for i = 1, (self.recMax or 0) do
      local b, g = self.recSlots[i], self.recGhosts[i]
      if b then b.holder:Hide(); b.pkBag, b.wpeForce = nil, nil end
      if g then g:Hide() end
    end
  end

  -- The scan runs before the loop reads the list, not inside the first locate: an
  -- adoption rewrites a stale pin in place, and the entry read before the scan would
  -- paint the old item string for a cycle.
  scan()
  local list = self:List()
  local gridTop = y
  local seen = {}
  for i = 1, math.max(n, self.max or 0) do
    local b, g, c = self.slots[i], self.ghosts[i], self.catchers[i]
    if i > n then
      if b then b.holder:Hide() end
      if g then g:Hide() end
      if c then c:Hide() end
    else
      local pin = list[i]
      local key = pin and ns.ItemKey(pin)
      if key and seen[key] then list[i], pin, key = nil, nil, nil end
      if key then seen[key] = true end
      local px = PAD + ((i - 1) % cols) * step
      local py = gridTop + math.floor((i - 1) / cols) * step
      local bag, slot = locate(pin)
      if bag and not b then self.cold = true end
      local live = (bag and b) and true or false
      if live and (b.pkBag ~= bag or b.pkSlot ~= slot) then
        b.pkBag, b.pkSlot, b.wpeBagID = bag, slot, bag
        b.holder:SetID(bag)
        b:SetID(slot)
        b.link = nil
      end
      if live then
        local h = b.holder
        ns.SnapSize(h, size, size)
        h:ClearAllPoints()
        ns.SnapPoint(h, "TOPLEFT", w, "TOPLEFT", px, -py)
        h:Show(); b:Show()
        if repaint then b.link = nil end
        ns.UpdateItemButton(b)
        if g then g:Hide() end
      else
        if b then b.holder:Hide(); b.pkBag = nil end
        if g then
          ns.SnapBox(g, size, size)
          g:ClearAllPoints()
          ns.SnapPoint(g, "TOPLEFT", w, "TOPLEFT", px, -py)
          ns.PaintPin(g, pin, pins)
          g:Show()
        end
      end
      if c then
        ns.SnapBox(c, size, size)
        c:ClearAllPoints()
        ns.SnapPoint(c, "TOPLEFT", w, "TOPLEFT", px, -py)
        c.wpeLockable = live or nil
        c:Show()
      end
    end
  end
  self.max = n
  self:Cooldowns()
  -- The band under the arrows is reserved whether they are up or not. Locking a window is not
  -- a resize: the pocket used to shrink by the band the moment it was pinned, so pinning it
  -- moved everything in it. Only the arrows themselves come and go.
  local editable = not self:Locked()
  if self.nudge then self.nudge:SetShown(editable) end
  local foot = gridTop + (rows - 1) * step + size + BOX_GAP
  ns.SnapSize(w, PAD * 2 + cols * step - gap, foot + NUDGE_BAND)
  ns.AlignToScreen(w)
end

function Pocket:PickPaint()
  local p = self.picksFrame
  if not (p and self.pickBtns) then return end
  local list = self:List()
  local n = #POCKET_PICKS
  local path = ns.Fonts:Current()
  local band = Theme:HeaderBand(p, BAND)
  local head = band and (band + 6) or (30 + Theme:TopInset())
  local mid = (band or head) / 2 + Theme:TitleDrop()
  if self.picksTitle then
    self.picksTitle:SetFont(path, 14, "")
    self.picksTitle:ClearAllPoints()
    ns.SnapPoint(self.picksTitle, "LEFT", p, "TOPLEFT", PICK_PAD, -mid)
  end
  if self.picksClose then
    self.picksClose:ClearAllPoints()
    ns.SnapPoint(self.picksClose, "RIGHT", p, "TOPRIGHT", -6, -mid)
  end
  if self.idBox then
    self.idBox:SetFont(path, 13, "")
    if self.idBox.Hint then self.idBox.Hint:SetFont(path, 13, "") end
    self.idBox:ClearAllPoints()
    ns.SnapPoint(self.idBox, "TOPLEFT", p, "TOPLEFT", PICK_PAD, -head)
    ns.SnapPoint(self.idBox, "TOPRIGHT", p, "TOPRIGHT", -PICK_PAD, -head)
  end
  local gridTop = head + BOX_H + BOX_GAP
  for i = 1, n do
    local id = POCKET_PICKS[i]
    local b = self.pickBtns[i]
    b.wpeID = id
    b.icon:SetTexture(ns.PinIcon(id))
    local pinned = false
    for j = 1, self:Count() do
      if ns.ItemStubID(list[j]) == id then pinned = true; break end
    end
    b.wpePinned = pinned
    ns.SetBg(b, Theme:C("slot"))
    ns.SetEdge(b, Theme:C(pinned and "accent" or "emptyLine"))
    b.icon:SetDesaturated(false)
    b.icon:SetAlpha(pinned and 0.55 or 1)
    local atlas = ns.PinTier(id)
    if atlas then b.tier:SetAtlas(atlas, true); b.tier:Show() else b.tier:Hide() end
    b:Show()
  end
  for i = n + 1, PICK_MAX do self.pickBtns[i]:Hide() end
  local cols = math.max(1, math.min(PICK_COLS, n))
  local rows = n > 0 and math.ceil(n / cols) or 0
  local gridH = rows > 0 and (rows * PICK_SIZE + (rows - 1) * PICK_GAP) or 0
  local pickW = PICK_PAD * 2 + cols * PICK_SIZE + (cols - 1) * PICK_GAP
  ns.SnapSize(p, math.max(pickW, 176), gridTop + gridH + PICK_PAD)
  for i = 1, n do
    local b = self.pickBtns[i]
    ns.SnapSize(b, PICK_SIZE, PICK_SIZE)
    b:ClearAllPoints()
    local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
    ns.SnapPoint(b, "TOPLEFT", p, "TOPLEFT",
      PICK_PAD + col * (PICK_SIZE + PICK_GAP),
      -(gridTop + row * (PICK_SIZE + PICK_GAP)))
  end
  local w = self.frame
  if w then
    p:ClearAllPoints()
    ns.SnapPoint(p, "TOPRIGHT", w, "TOPLEFT", -6, 0)
  end
end

function Pocket:TogglePicks()
  local p = self.picksFrame
  if not p then return end
  if p:IsShown() then
    p:Hide()
    if self.idBox then self.idBox:ClearFocus() end
    return
  end
  self:PickPaint()
  p:Show()
  for _, id in ipairs(POCKET_PICKS) do
    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
  end
  if self.idBox then self.idBox:SetFocus() end
end

function Pocket:Soon()
  later()
end

function Pocket:Refresh()
  keyDirty = true
  if not (self.frame and self.frame:IsShown()) then return end
  self:Layout()
  if self.picksFrame and self.picksFrame:IsShown() then self:PickPaint() end
end

function Pocket:Open()
  if not self:Enabled() then return end
  local w = self:Build()
  w:ClearAllPoints()
  local pp = WarpeeDB and WarpeeDB.pocketPos
  local anchor = ns.Bags and ns.Bags.frame
  if pp then
    ns.SnapPoint(w, pp.p, UIParent, pp.rp, pp.x, pp.y)
  elseif anchor then
    ns.SnapPoint(w, "TOPLEFT", anchor, "TOPRIGHT", 8, 0)
  else
    w:SetPoint("CENTER")
  end
  WarpeeDB.pocketOpen = true
  self:Layout()
  w:Show()
  Theme:Raise(w)
  -- Layout runs before the frame is shown, so its cooldown pass sees nothing visible.
  -- One pass after Show picks up a cooldown that started while the window was closed.
  self:Cooldowns()
end

function Pocket:Close(keep)
  if self.idBox then self.idBox:SetText(""); self.idBox:ClearFocus() end
  if self.picksFrame then self.picksFrame:Hide() end
  if self.frame then self.frame:Hide() end
  if not keep then WarpeeDB.pocketOpen, self.solo = nil, nil end
end

function Pocket:Toggle()
  if self.frame and self.frame:IsShown() then
    self:Close()
  else
    self.solo = nil
    self:Open()
  end
end

function Pocket:Hotkey()
  if not self:Enabled() then return end
  if self.frame and self.frame:IsShown() then
    self:Close()
    return
  end
  local f = ns.Bags and ns.Bags.frame
  self.solo = not (f and f:IsShown()) or nil
  self:Open()
end

function Pocket:Apply()
  if not self:Enabled() then self:Close(true); return end
  self:Refresh()
end

-- Bindings.xml is picked up by the client from the addon folder on its own. Listing it
-- in the toc sends it through the frame XML parser instead, which does not know the
-- Binding tag and drops the whole file, so it stays out of the file list.
ns.LocalGlobal("BINDING_NAME_WARPEE_POCKET", "Pocket")

function WarpeePocketToggle()
  if ns.Pocket then ns.Pocket:Hotkey() end
end

-- The pocket used to take F7 outright. It takes the first free key of a short ladder now,
-- and the one line it says on the way is built from the key it actually got.
local function defaultKey()
  if not WarpeeDB or WarpeeDB.pocketBind then return end
  if InCombatLockdown() then return end
  -- A pocket that is switched off gets no key and no line about one. Its header button is
  -- hidden with it, so a binding would sit on the player's keys doing nothing, and the line
  -- would describe a window that never opens. The mark is still set: there is nothing here
  -- to say later.
  if not ns.Pocket:Enabled() then
    WarpeeDB.pocketBind = true
    return
  end
  if not (GetBindingKey and GetBindingAction and SetBinding and SaveBindings) then return end
  local key = GetBindingKey("WARPEE_POCKET")
  if not key then
    if (GetBindingAction("SHIFT-B") or "") == "" then
      key = "SHIFT-B"
    elseif (GetBindingAction("F7") or "") == "" then
      key = "F7"
    end
    if key then
      SetBinding(key, "WARPEE_POCKET")
      SaveBindings((GetCurrentBindingSet and GetCurrentBindingSet()) or 1)
      if GetBindingKey("WARPEE_POCKET") ~= key then key = nil end
    end
  end
  -- The line names the key it just took, so it is built from the localized sentence with
  -- the key spliced in, not from an English string glued to an English tail.
  local line
  if key then
    line = (ns.L["The pocket is a small window of bookmark cells beside the bags. Open it with %s or the grid button in the header."]):format(key)
  else
    line = ns.L["The pocket is a small window of bookmark cells beside the bags. Open it with the grid button in the header, or bind a key in the settings."]
  end
  WarpeeDB.pocketBind = true
  print("|cffd9a85fWarpee|r |cffffffff" .. line .. "|r")
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:RegisterEvent("BAG_UPDATE_COOLDOWN")
ev:RegisterEvent("SPELL_UPDATE_COOLDOWN")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:RegisterEvent("EQUIPMENT_SETS_CHANGED")
ev:RegisterEvent("EQUIPMENT_SWAP_FINISHED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ITEM_CHANGED")
pcall(ev.RegisterEvent, ev, "ITEM_DATA_LOAD_RESULT")
ev:SetScript("OnEvent", function(_, event, a1, a2)
  if event == "ITEM_CHANGED" then
    if ns.PinRetarget(Pocket:List(), Pocket:Count(), a1, a2) then later() end
    return
  end
  if event == "ITEM_DATA_LOAD_RESULT" then
    if Pocket.picksFrame and Pocket.picksFrame:IsShown() then Pocket:PickPaint() end
    return
  end
  if event == "PLAYER_LOGIN" then
    C_Timer.After(1, defaultKey)
    return
  end
  if event == "PLAYER_REGEN_ENABLED" then
    Pocket:Flush()
    return
  end
  if event == "BAG_UPDATE_DELAYED" or event == "PLAYER_EQUIPMENT_CHANGED"
     or event == "EQUIPMENT_SETS_CHANGED" or event == "EQUIPMENT_SWAP_FINISHED" then
    later()
    return
  end
  Pocket:Cooldowns()
end)
