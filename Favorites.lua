local addonName, ns = ...
local Theme = ns.Theme

local Fav = {}
ns.Fav = Fav
Fav.slots, Fav.ghosts, Fav.catchers = {}, {}, {}

local LABEL_H, LABEL_GAP = 13, 4
local MAX_SLOTS = 24

local function charKey()
  local n = UnitName("player") or "?"
  local r = (GetNormalizedRealmName and GetNormalizedRealmName())
            or (GetRealmName and GetRealmName()) or "?"
  return n .. "-" .. r
end

function Fav:Enabled()
  return not (WarpeeDB and WarpeeDB.favShow == false)
end

function Fav:Count()
  local n = math.floor(tonumber(WarpeeDB and WarpeeDB.favCount) or 6)
  return math.max(0, math.min(14, n))
end

function Fav:List()
  WarpeeDB.favorites = WarpeeDB.favorites or {}
  local k = charKey()
  WarpeeDB.favorites[k] = WarpeeDB.favorites[k] or {}
  return WarpeeDB.favorites[k]
end

-- Pinned cells are shared with the pocket window. Read the block above ns.PinArg in
-- ItemButton.lua before touching anything a cell knows or shows, and make the change there
-- so both rows get it: this file owns only the row, its geometry, the tooltip and the click
-- overlay. The lists themselves stay apart, this one is its own.
local pins = {}
local locsDirty = true

local function scan()
  if not locsDirty then return end
  locsDirty = false
  ns.PinScan(Fav:List(), MAX_SLOTS, pins)
end

local function locate(pin)
  scan()
  return ns.PinLocate(pin, pins)
end

local function worn(pin)
  scan()
  return ns.PinWorn(pin, pins)
end

local function favSound(kind, bag, slot)
  local pickup = kind == "pickup"
  local play = C_Sound and C_Sound.PlayItemSound
  local kinds = Enum and Enum.ItemSoundType
  if play and kinds and bag and slot and ItemLocation then
    local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
    if loc and C_Item.DoesItemExist(loc) then
      play(pickup and (kinds.Pickup or 0) or (kinds.Drop or 1), loc)
      return
    end
  end
  if not (PlaySound and SOUNDKIT) then return end
  local id = SOUNDKIT[pickup and "UI_CURSOR_PICKUP_OBJECT" or "UI_CURSOR_DROP_OBJECT"]
  if id then PlaySound(id) end
end
ns.ItemSound = favSound

local deferred = false

local function later()
  if deferred then return end
  deferred = true
  C_Timer.After(0, function()
    deferred = false
    Fav:Refresh()
  end)
end

local function makeGhost(parent)
  local g = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  ns.PixelBackdrop(g)
  g:SetBackdropColor(Theme:C("slot"))
  g:SetBackdropBorderColor(Theme:C("emptyLine"))
  Theme:Track(g, function(s)
    s:SetBackdropColor(Theme:C("slot"))
    s:SetBackdropBorderColor(Theme:C("emptyLine"))
  end)
  local ic = g:CreateTexture(nil, "ARTWORK")
  ic:SetPoint("TOPLEFT", 1, -1)
  ic:SetPoint("BOTTOMRIGHT", -1, 1)
  ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  ic:SetDesaturated(true)
  g.icon = ic
  local plus = Theme:Label(g, 13, "faint")
  plus:SetPoint("CENTER")
  plus:SetText("+")
  g.plus = plus
  return g
end
ns.SlotGhost = makeGhost

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
    if not IsMouseButtonDown("LeftButton") then Fav:Drop(); return end
    local x, y = GetCursorPosition()
    local k = UIParent:GetEffectiveScale()
    s:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / k, y / k)
  end)
  dragIcon = f
  return f
end

local function tipFor(c, index)
  local pin = Fav:List()[index]
  GameTooltip:SetOwner(c, "ANCHOR_RIGHT")
  if pin then
    local b = Fav.slots[index]
    if b and b.favBag and b.holder:IsShown() then
      GameTooltip:SetBagItem(b.favBag, b.favSlot)
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
    GameTooltip:SetText(ns.L["Favorites"])
    GameTooltip:AddLine(ns.L["Drag an item here to keep it one click away"], 0.6, 0.6, 0.6, true)
  end
  GameTooltip:Show()
end

-- The overlay owns the left button for good and passes the right button down to the
-- slot, so a right click reaches the game's handler with no addon code in the path.
-- SetPassThroughButtons is refused during combat lockdown, so it is set here, once,
-- and never touched again. That is why clearing a slot lives on Ctrl + left click:
-- taking the right button back would mean calling it again mid fight.
-- The overlay must never finish a pending item spell itself: C_Container.UseContainerItem
-- from addon code is refused as ADDON_ACTION_FORBIDDEN, traceback 2026-09-05. An enchant
-- or a gem lands only in the bag grid: the game runs that from the left button of its
-- own slot handler, and every row here keeps the right button alone.
local function makeCatcher(parent, index)
  local c = CreateFrame("Button", nil, parent)
  c.favIndex = index
  c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  c:RegisterForDrag("LeftButton")
  c:SetFrameLevel(parent:GetFrameLevel() + 30)
  c:EnableMouse(true)
  if c.SetPassThroughButtons then c:SetPassThroughButtons("RightButton") end
  c:SetScript("OnDragStart", function(s) Fav:Lift(s.favIndex) end)
  c:SetScript("OnDragStop", function() Fav:Drop() end)
  c:SetScript("OnReceiveDrag", function(s) Fav:PinFromCursor(s.favIndex) end)
  c:SetScript("OnClick", function(s, button)
    if button ~= "LeftButton" then return end
    if GetCursorInfo() then
      Fav:PinFromCursor(s.favIndex)
      return
    end
    if IsShiftKeyDown() and not (IsControlKeyDown() or IsAltKeyDown()) then
      Fav:Link(s.favIndex)
      return
    end
    if IsAltKeyDown() and not (IsShiftKeyDown() or IsControlKeyDown()) then
      Fav:Lock(s.favIndex)
      return
    end
    if IsControlKeyDown() and not (IsShiftKeyDown() or IsAltKeyDown()) then
      Fav:Set(s.favIndex, nil)
      tipFor(s, s.favIndex)
    end
  end)
  c:SetScript("OnEnter", function(s)
    local b = Fav.slots[s.favIndex]
    if b and b.holder:IsShown() then ns.SetSlotHighlight(b, true) end
    tipFor(s, s.favIndex)
  end)
  c:SetScript("OnLeave", function(s)
    local b = Fav.slots[s.favIndex]
    if b then ns.SetSlotHighlight(b, false) end
    GameTooltip:Hide()
  end)
  return c
end

function Fav:Link(index)
  local pin = self:List()[index]
  if not (pin and ChatEdit_InsertLink) then return end
  local b = self.slots[index]
  local link
  if b and b.favBag and b.holder:IsShown() then
    link = C_Container.GetContainerItemLink(b.favBag, b.favSlot)
  end
  if not link then link = select(2, C_Item.GetItemInfo(ns.PinArg(pin))) end
  if link then ChatEdit_InsertLink(link) end
end

function Fav:Set(index, pin)
  local list = self:List()
  if pin then
    local k = ns.ItemKey(pin)
    for i, own in pairs(list) do
      if i ~= index and k and ns.ItemKey(own) == k then list[i] = nil end
    end
  end
  list[index] = pin or nil
  locsDirty = true
  later()
end

function Fav:Lock(index)
  local id = ns.ItemStubID(self:List()[index])
  local V = ns.Vendor
  if not (id and V and V.Toggle) then return end
  V:Toggle(id, (C_Item.GetItemInfo(id)) or tostring(id))
  local c = self.catchers[index]
  if c and c:IsShown() and c:IsMouseOver() then tipFor(c, index) end
end

function Fav:Lift(index)
  local pin = self:List()[index]
  if not pin then return end
  self.moving = index
  local b = self.slots[index]
  if b then ns.SetSlotHighlight(b, true) end
  favSound("pickup", b and b.favBag, b and b.favSlot)
  local f = dragArt()
  local sz = math.max(16, (b and b:GetWidth()) or 0)
  f:SetSize(sz, sz)
  f.icon:SetTexture(ns.PinIcon(ns.ItemStubID(pin)))
  f:Show()
end

function Fav:Drop()
  local from = self.moving
  self.moving = nil
  if dragIcon then dragIcon:Hide() end
  if not from then return end
  local b = self.slots[from]
  if b then ns.SetSlotHighlight(b, false) end
  favSound("drop", b and b.favBag, b and b.favSlot)
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

function Fav:PinFromCursor(index)
  local kind, a, link = GetCursorInfo()
  if kind ~= "item" then return end
  local id = tonumber(a)
  if not id and link then id = tonumber(link:match("item:(%d+)")) end
  if not id then return end
  ClearCursor()
  local pin = ns.PinFor(id, link)
  favSound("drop", locate(pin))
  self:Set(index, pin)
end

-- IsShown is only about the cell itself, and a cell in a closed window is still shown, so
-- the sweep has to ask IsVisible or a closed bag window keeps paying for every spell
-- cooldown in the game.
function Fav:Cooldowns()
  for i = 1, (self.max or 0) do
    local b = self.slots[i]
    if b and b.link and b.holder:IsVisible() then ns.UpdateCooldown(b) end
  end
end

function Fav:Flush()
  if not self.cold or InCombatLockdown() then return end
  self:Warm()
  self:Refresh()
end

function Fav:Hide()
  if self.label then self.label:Hide() end
  for i = 1, (self.max or 0) do
    local b, g, c = self.slots[i], self.ghosts[i], self.catchers[i]
    if b then b.holder:Hide() end
    if g then g:Hide() end
    if c then c:Hide() end
  end
end

-- Everything the row needs is built here, out of combat, and a redraw only moves
-- frames after that. A slot button made during a fight is tainted for good, and the
-- overlay cannot be configured then either.
function Fav:Warm()
  local bags = ns.Bags
  local frame = bags and bags.frame
  if not frame then return end
  if InCombatLockdown() then self.cold = true; return end
  for i = 1, MAX_SLOTS do
    if not self.slots[i] then
      local b = ns.CreateItemButton(frame, 0, 1)
      b:RegisterForClicks(unpack(ns.CLICKS_USE))
      b:RegisterForDrag()
      b.wpeClicks, b.wpeLockable, b.wpeTotal = ns.CLICKS_USE, nil, true
      b.holder:Hide()
      self.slots[i] = b
    end
    if not self.ghosts[i] then
      local g = ns.PinGhost(frame)
      g:Hide()
      self.ghosts[i] = g
    end
    if not self.catchers[i] then
      local c = makeCatcher(frame, i)
      c:Hide()
      self.catchers[i] = c
    end
  end
  self.cold, self.warmed = nil, true
end

function Fav:Refresh()
  local a = self.args
  if a and a.bags and a.bags.frame and a.bags.frame:IsShown() then
    self:Apply(a.bags, a.x, a.top, a.size, a.gap)
  end
end

function Fav:Apply(bags, x, top, size, gap)
  if not (bags and bags.frame) then return 0 end
  local frame = bags.frame
  self.args = { bags = bags, x = x, top = top, size = size, gap = gap }
  if not self:Enabled() then
    self:Hide()
    return 0
  end
  if not self.label then
    local fs = Theme:Label(frame, 11, "dim")
    fs:SetJustifyH("LEFT")
    ns.LocalText(fs, "Favorites")
    self.label = fs
  end
  self.label:SetFont(bags.fontPath or ns.Fonts:Current(), 11, "")
  self.label:ClearAllPoints()
  ns.SnapPoint(self.label, "TOPLEFT", frame, "TOPLEFT", x, -top)
  self.label:Show()

  local cols = bags.cols or 14
  local want = self:Count()
  local n = math.min((want <= 0) and cols or math.min(want, cols), MAX_SLOTS)
  if not self.warmed then self:Warm() end
  local rowY = top + LABEL_H + LABEL_GAP
  local list = self:List()
  local last = math.max(self.max or 0, n)
  self.max = last
  local plusSize = math.max(14, math.floor(size * 0.5))
  local gen = (bags.styleGen or 0) .. ":" .. tostring(bags.fontPath) .. ":" .. size
  local repaint = self.paintKey ~= gen
  self.paintKey = gen
  -- The scan runs before the loop reads the list, not inside the first locate: an
  -- adoption rewrites a stale pin in place, and the entry read before the scan would
  -- paint the old item string for a cycle.
  scan()
  local seen = {}
  for i = 1, n do
    local pin = list[i]
    local key = pin and ns.ItemKey(pin)
    if key and seen[key] then list[i], pin, key = nil, nil, nil end
    if key then seen[key] = true end
    local bag, slot = locate(pin)
    local px = x + (i - 1) * (size + gap)
    local b, g = self.slots[i], self.ghosts[i]
    if bag and not b then self.cold = true end
    local live = (bag and b) and true or false
    if live and (b.favBag ~= bag or b.favSlot ~= slot) then
      b.favBag, b.favSlot, b.wpeBagID = bag, slot, bag
      b.holder:SetID(bag)
      b:SetID(slot)
      b.link = nil
    end
    if live then
      local h = b.holder
      ns.SnapSize(h, size, size)
      h:ClearAllPoints()
      ns.SnapPoint(h, "TOPLEFT", frame, "TOPLEFT", px, -rowY)
      h:Show(); b:Show()
      if repaint then b.link = nil end
      ns.UpdateItemButton(b)
      if g then g:Hide() end
    else
      if g then
        ns.SnapBox(g, size, size)
        g:ClearAllPoints()
        ns.SnapPoint(g, "TOPLEFT", frame, "TOPLEFT", px, -rowY)
        ns.PaintPin(g, pin, pins, self.slots[1])
        if not pin then
          g.plus:SetFont(bags.fontPath or ns.Fonts:Current(), plusSize, "")
          g.plus:Show()
        end
        g:Show()
      end
      if b then b.holder:Hide(); b.favBag = nil end
    end
    local c = self.catchers[i]
    if c then
      ns.SnapBox(c, size, size)
      c:ClearAllPoints()
      ns.SnapPoint(c, "TOPLEFT", frame, "TOPLEFT", px, -rowY)
      c.wpeLockable = live or nil
      c:Show()
    end
  end
  for i = n + 1, last do
    local b, g, c = self.slots[i], self.ghosts[i], self.catchers[i]
    if b then b.holder:Hide() end
    if g then g:Hide() end
    if c then c:Hide() end
  end
  -- An unchanged item takes the early return in UpdateItemButton, which also skips its
  -- cooldown, so a cooldown that started while this row was closed is never seen here
  -- until the next cooldown event. One pass after placing the cells closes that gap,
  -- and the cached start and duration keep an unchanged one nearly free.
  self:Cooldowns()
  return LABEL_H + LABEL_GAP + size + 6
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:RegisterEvent("BAG_UPDATE_COOLDOWN")
ev:RegisterEvent("SPELL_UPDATE_COOLDOWN")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:RegisterEvent("EQUIPMENT_SETS_CHANGED")
ev:RegisterEvent("EQUIPMENT_SWAP_FINISHED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("ITEM_CHANGED")
ev:SetScript("OnEvent", function(_, event, a1, a2)
  if event == "PLAYER_REGEN_ENABLED" then
    Fav:Flush()
    return
  end
  if event == "ITEM_CHANGED" then
    if ns.PinRetarget(Fav:List(), MAX_SLOTS, a1, a2) then
      locsDirty = true
      Fav:Refresh()
    end
    return
  end
  if event == "BAG_UPDATE_DELAYED" or event == "PLAYER_EQUIPMENT_CHANGED"
     or event == "EQUIPMENT_SETS_CHANGED" or event == "EQUIPMENT_SWAP_FINISHED" then
    locsDirty = true
    Fav:Refresh()
    return
  end
  Fav:Cooldowns()
end)
