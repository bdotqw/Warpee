local addonName, ns = ...
local Theme = ns.Theme

local Pocket = {}
ns.Pocket = Pocket
Pocket.slots, Pocket.ghosts, Pocket.catchers = {}, {}, {}
Pocket.recSlots, Pocket.recGhosts = {}, {}

local PAD, BAND = 12, 26
local LABEL_H, LABEL_GAP, SPLIT = 13, 4, 10
local BOX_H, BOX_GAP = 22, 8
local MAX_COLS, MAX_ROWS = 8, 6

local function charKey()
  local n = UnitName("player") or "?"
  local r = (GetNormalizedRealmName and GetNormalizedRealmName())
            or (GetRealmName and GetRealmName()) or "?"
  return n .. "-" .. r
end

function Pocket:Enabled()
  return not (WarpeeDB and WarpeeDB.pocketShow == false)
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

function Pocket:List()
  WarpeeDB.pocket = WarpeeDB.pocket or {}
  local k = charKey()
  WarpeeDB.pocket[k] = WarpeeDB.pocket[k] or {}
  return WarpeeDB.pocket[k]
end

local keyBag, keySlot, wornKey = {}, {}, {}
local keyDirty = true

local function keyScan()
  wipe(keyBag); wipe(keySlot); wipe(wornKey)
  local want, any = {}, false
  local list = Pocket:List()
  for i = 1, Pocket:Count() do
    local pin = list[i]
    if type(pin) == "string" then
      local id = ns.ItemStubID(pin)
      if id then want[id] = true; any = true end
    end
  end
  if not any then return end
  local function sweep(bag)
    for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
      local id = C_Container.GetContainerItemID(bag, slot)
      if id and want[id] then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        local k = info and ns.ItemKey(info.hyperlink)
        if k and not keyBag[k] then keyBag[k], keySlot[k] = bag, slot end
      end
    end
  end
  for _, bag in ipairs(ns.playerBags) do sweep(bag) end
  if ns.reagentBag then sweep(ns.reagentBag) end
  local get = C_Item and C_Item.GetItemLink
  if not (get and ItemLocation) then return end
  for slot = 1, 19 do
    local loc = ItemLocation:CreateFromEquipmentSlot(slot)
    if loc and C_Item.DoesItemExist(loc) then
      local k = ns.ItemKey(get(loc))
      if k then wornKey[k] = true end
    end
  end
end

local function locate(pin)
  if type(pin) == "number" then
    local F = ns.Fav
    if not (F and F.Locate) then return nil end
    return F:Locate(pin)
  end
  if type(pin) ~= "string" then return nil end
  if keyDirty then keyScan(); keyDirty = false end
  local k = ns.ItemKey(pin)
  if not k then return nil end
  return keyBag[k], keySlot[k]
end

local function worn(pin)
  if type(pin) == "string" then
    if keyDirty then keyScan(); keyDirty = false end
    local k = ns.ItemKey(pin)
    return (k and wornKey[k]) and true or false
  end
  local f = (C_Item and C_Item.IsEquippedItem) or IsEquippedItem
  return (pin and f and f(pin)) and true or false
end

local function itemIcon(id)
  if C_Item and C_Item.GetItemIconByID then
    local ok, tex = pcall(C_Item.GetItemIconByID, id)
    if ok and tex then return tex end
  end
  return (GetItemIcon and GetItemIcon(id)) or 134400
end

local function elsewhere(pin)
  local id = ns.ItemStubID(pin)
  local f = (C_Item and C_Item.GetItemCount) or GetItemCount
  if not (id and f) then return 0 end
  local ok, n = pcall(f, id, true, false, true, true)
  return (ok and tonumber(n)) or 0
end

local function pinFor(id, link)
  local stub = ns.ItemStub(link)
  if not (id and stub) then return id end
  local loc = select(4, C_Item.GetItemInfoInstant(id))
  local max = C_Item.GetItemMaxStackSizeByID and C_Item.GetItemMaxStackSizeByID(id)
  if loc and loc ~= "" and (tonumber(max) or 1) <= 1 then return stub end
  return id
end

local function pocketGhost(parent)
  local g = ns.SlotGhost(parent)
  g.plus:Hide()
  local dot = Theme:Rect(g, "accent", "OVERLAY")
  dot:Hide()
  g.dot = dot
  ns.PixelJob(g, function(s)
    local d = ns.PX(s, 5)
    s.dot:SetSize(d, d)
    s.dot:ClearAllPoints()
    s.dot:SetPoint("TOPRIGHT", -d, -d)
  end, "dot")
  local cnt = Theme:Label(g, 11, "dim")
  cnt:SetPoint("BOTTOMRIGHT", -2, 2)
  cnt:Hide()
  g.cnt = cnt
  return g
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
      local n = elsewhere(pin)
      if n > 0 then
        GameTooltip:AddLine((ns.L["%d outside your bags"]):format(n), 0.6, 0.6, 0.6, true)
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
-- or a gem lands only on a slot whose click the game owns, the recent row or a bag.
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
  f.icon:SetTexture(itemIcon(ns.ItemStubID(pin)))
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
  local pin = pinFor(id, link)
  if ns.ItemSound then ns.ItemSound("drop", locate(pin)) end
  self:Set(index, pin)
end

function Pocket:AddByText(text)
  local s = tostring(text or "")
  local id = tonumber(s:match("item:(%d+)")) or tonumber(s:match("%d+"))
  if not id then return end
  local get = C_Item and C_Item.GetItemInfoInstant
  if get and not get(id) then return end
  local list = self:List()
  local n = self:Count()
  for i = 1, n do
    if ns.ItemStubID(list[i]) == id then return end
  end
  for i = 1, n do
    if not list[i] then
      if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
      self:Set(i, id)
      C_Timer.After(0.4, function() Pocket:Refresh() end)
      return
    end
  end
end

function Pocket:Cooldowns()
  for i = 1, (self.max or 0) do
    local b = self.slots[i]
    if b and b.holder:IsShown() and b.link then ns.UpdateCooldown(b) end
  end
  for i = 1, (self.recMax or 0) do
    local b = self.recSlots[i]
    if b and b.holder:IsShown() and b.link then ns.UpdateCooldown(b) end
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
  w:SetScript("OnDragStart", function(s) ns.DragStart(s) end)
  w:SetScript("OnDragStop", function(s)
    if not s.wpeMoving then return end
    s.wpeMoving = nil
    s:StopMovingOrSizing()
    local pp, rp, x, y = ns.SnapFrame(s)
    if pp then WarpeeDB.pocketPos = { p = pp, rp = rp, x = x, y = y } end
  end)
  ns.EscClose(w)
  ns.EscClose(w)
  ns.PixelJob(w, function(s) ns.AlignToScreen(s) end, "align")

  local title = Theme:Title(w, 14, "accent")
  ns.LocalText(title, "POCKET")
  self.title = title

  local close = ns.CreateGlyphButton(w, "×")
  close:SetScript("OnClick", function() Pocket:Close() end)
  self.closeBtn = close

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

  local box = ns.CreateSearchBox(w, nil, "Add ID")
  box.wpeLinkID = true
  box:SetScript("OnEnterPressed", function(s)
    Pocket:AddByText(s:GetText())
    s:SetText("")
    s:ClearFocus()
  end)
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
      local g = pocketGhost(w)
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
      b.wpeNoNew = true
      b.holder:Hide()
      self.recSlots[i] = b
    end
    if not self.recGhosts[i] then
      local g = ns.SlotGhost(w)
      g.plus:Hide()
      g.icon:Hide()
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
  local size, gap, step = ns.GridMetrics(w, Bags and Bags.iconSize or 37,
                                         Bags and Bags.gap or 4)
  local cols, rows = self:Cols(), self:Rows()
  local n = cols * rows
  if (self.warmed or 0) < n or (self.recWarmed or 0) < cols then self:Warm() end
  local band = Theme:HeaderBand(w, BAND)
  local head = band and (band + 6) or (30 + Theme:TopInset())
  local mid = (band or head) / 2
  local path = ns.Fonts:Current()
  self.title:SetFont(path, 14, "")
  self.title:ClearAllPoints()
  ns.SnapPoint(self.title, "LEFT", w, "TOPLEFT", PAD, -mid)
  self.closeBtn:ClearAllPoints()
  ns.SnapPoint(self.closeBtn, "RIGHT", w, "TOPRIGHT", -6, -mid)

  local gen = ((Bags and Bags.styleGen) or 0) .. ":" .. tostring(path) .. ":" .. size
  local repaint = self.paintKey ~= gen
  self.paintKey = gen

  local R = ns.Recent
  local recOn = (R and R:Enabled()) and true or false
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
          if pin then
            g.icon:SetTexture(itemIcon(ns.ItemStubID(pin))); g.icon:Show()
            g.dot:SetShown(worn(pin))
            local away = ns.GearItem(ns.ItemStubID(pin)) and 0 or elsewhere(pin)
            if away > 0 then
              g.cnt:SetFont(path, math.max(9, math.floor(size * 0.3)), "")
              g.cnt:SetText(away)
              g.cnt:Show()
            else
              g.cnt:Hide()
            end
          else
            g.icon:Hide()
            g.dot:Hide()
            g.cnt:Hide()
          end
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
  local foot = gridTop + (rows - 1) * step + size + BOX_GAP
  self.idBox:SetFont(path, 13, "")
  if self.idBox.Hint then self.idBox.Hint:SetFont(path, 13, "") end
  self.idBox:ClearAllPoints()
  ns.SnapPoint(self.idBox, "TOPLEFT", w, "TOPLEFT", PAD, -foot)
  ns.SnapPoint(self.idBox, "TOPRIGHT", w, "TOPRIGHT", -PAD, -foot)
  self.idBox:SetHeight(BOX_H)
  ns.SnapSize(w, PAD * 2 + cols * step - gap, foot + BOX_H + PAD)
  ns.AlignToScreen(w)
end

function Pocket:Soon()
  later()
end

function Pocket:Refresh()
  keyDirty = true
  if not (self.frame and self.frame:IsShown()) then return end
  self:Layout()
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
end

function Pocket:Close(keep)
  if self.idBox then self.idBox:SetText(""); self.idBox:ClearFocus() end
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

function Pocket:Restore()
  if self.frame and self.frame:IsShown() then return end
  if not (self:Enabled() and WarpeeDB and WarpeeDB.pocketOpen) then return end
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

local function defaultKey()
  if not WarpeeDB or WarpeeDB.pocketBind then return end
  if InCombatLockdown() then return end
  if not (GetBindingKey and GetBindingAction and SetBinding and SaveBindings) then return end
  if GetBindingKey("WARPEE_POCKET") then WarpeeDB.pocketBind = true; return end
  if (GetBindingAction("F7") or "") ~= "" then WarpeeDB.pocketBind = true; return end
  if SetBinding("F7", "WARPEE_POCKET") then
    SaveBindings((GetCurrentBindingSet and GetCurrentBindingSet()) or 1)
    WarpeeDB.pocketBind = true
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:RegisterEvent("BAG_UPDATE_COOLDOWN")
ev:RegisterEvent("SPELL_UPDATE_COOLDOWN")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    C_Timer.After(1, defaultKey)
    return
  end
  if event == "PLAYER_REGEN_ENABLED" then
    Pocket:Flush()
    return
  end
  if event == "BAG_UPDATE_DELAYED" or event == "PLAYER_EQUIPMENT_CHANGED" then
    later()
    return
  end
  Pocket:Cooldowns()
end)
