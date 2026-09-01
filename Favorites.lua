local addonName, ns = ...
local Theme = ns.Theme

local Fav = {}
ns.Fav = Fav
Fav.slots, Fav.ghosts, Fav.catchers = {}, {}, {}

local LABEL_H, LABEL_GAP = 13, 4

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

local locBag, locSlot, locsDirty = {}, {}, true

local function scanBag(bag)
  for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
    local id = C_Container.GetContainerItemID(bag, slot)
    if id and not locBag[id] then locBag[id], locSlot[id] = bag, slot end
  end
end

local function locate(id)
  if not id then return nil end
  if locsDirty then
    wipe(locBag); wipe(locSlot)
    for _, bag in ipairs(ns.playerBags) do scanBag(bag) end
    if ns.reagentBag then scanBag(ns.reagentBag) end
    locsDirty = false
  end
  return locBag[id], locSlot[id]
end

local function itemIcon(id)
  if C_Item and C_Item.GetItemIconByID then
    local ok, tex = pcall(C_Item.GetItemIconByID, id)
    if ok and tex then return tex end
  end
  return (GetItemIcon and GetItemIcon(id)) or 134400
end

local function ilvlOf(link)
  if not link then return nil end
  local kl = link:match("keystone:[^:]*:[^:]*:(%d+)")
  if kl then return tonumber(kl) end
  local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(link)
  if classID ~= Enum.ItemClass.Armor and classID ~= Enum.ItemClass.Weapon then return nil end
  local get = C_Item.GetDetailedItemLevelInfo or GetDetailedItemLevelInfo
  return get and get(link) or nil
end

local waiting = false

local function bindSlot(b, bag, slot)
  local want = bag .. " " .. slot
  if b.favBind == want then return end
  if InCombatLockdown() then
    b.favPend = want
    waiting = true
    return
  end
  b.favBind, b.favPend = want, nil
  if not b.secure then return end
  b:SetAttribute("type2", "item")
  b:SetAttribute("item2", want)
  b:SetAttribute("ctrl-type2", "")
end

local function paintSlot(b, bag, slot)
  if b.favBag ~= bag or b.favSlot ~= slot then
    b.favBag, b.favSlot, b.bagID = bag, slot, bag
    b:SetID(slot)
    b.link = nil
  end
  local info = C_Container.GetContainerItemInfo(bag, slot)
  local d
  if info then
    d = b.favData or {}
    b.favData = d
    d.l, d.c, d.q, d.b = info.hyperlink, info.stackCount, info.quality, info.isBound
    d.v = ilvlOf(info.hyperlink)
  end
  ns.PaintVaultButton(b, d, bag)
  ns.UpdateCooldown(b)
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

local function tipFor(f, id)
  GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
  if id then
    GameTooltip:SetItemByID(id)
    GameTooltip:AddLine(ns.L["Ctrl + right click clears the slot"], 0.6, 0.6, 0.6)
  else
    GameTooltip:SetText(ns.L["Favourites"])
    GameTooltip:AddLine(ns.L["Drag an item here to keep it one click away"], 0.6, 0.6, 0.6, true)
  end
  GameTooltip:Show()
end

local function makeCatcher(parent, index)
  local c = CreateFrame("Button", nil, parent)
  c.favIndex = index
  c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  c:SetScript("OnReceiveDrag", function(s) Fav:PinFromCursor(s.favIndex) end)
  c:SetScript("OnClick", function(s, button)
    if GetCursorInfo() then
      Fav:PinFromCursor(s.favIndex)
      return
    end
    if button == "RightButton" and IsControlKeyDown() then
      Fav:Set(s.favIndex, nil)
      tipFor(s, nil)
    end
  end)
  c:SetScript("OnEnter", function(s) tipFor(s, Fav:List()[s.favIndex]) end)
  c:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return c
end

function Fav:Set(index, id)
  self:List()[index] = id or nil
  self:Refresh()
end

function Fav:PinFromCursor(index)
  local kind, a, link = GetCursorInfo()
  if kind ~= "item" then return end
  local id = tonumber(a)
  if not id and link then id = tonumber(link:match("item:(%d+)")) end
  if not id then return end
  ClearCursor()
  self:Set(index, id)
end

function Fav:SetCatch()
  local on = (GetCursorInfo() and true) or IsControlKeyDown()
  local list = self:List()
  for i = 1, (self.max or 0) do
    local c = self.catchers[i]
    if c and c:IsShown() then c:EnableMouse(on or not locate(list[i])) end
  end
end

function Fav:Cooldowns()
  for i = 1, (self.max or 0) do
    local b = self.slots[i]
    if b and b.holder:IsShown() and b.link then ns.UpdateCooldown(b) end
  end
end

function Fav:Flush()
  if not waiting or InCombatLockdown() then return end
  waiting = false
  for i = 1, (self.max or 0) do
    local b = self.slots[i]
    if b and b.favPend then
      local want = b.favPend
      b.favBind, b.favPend = want, nil
      if b.secure then
        b:SetAttribute("type2", "item")
        b:SetAttribute("item2", want)
        b:SetAttribute("ctrl-type2", "")
      end
    end
  end
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
    ns.LocalText(fs, "Favourites")
    self.label = fs
  end
  self.label:SetFont(bags.fontPath or ns.Fonts:Current(), 11, "")
  self.label:ClearAllPoints()
  ns.SnapPoint(self.label, "TOPLEFT", frame, "TOPLEFT", x, -top)
  self.label:Show()

  local cols = bags.cols or 14
  local want = self:Count()
  local n = (want <= 0) and cols or math.min(want, cols)
  local rowY = top + LABEL_H + LABEL_GAP
  local list = self:List()
  local catch = (GetCursorInfo() and true) or IsControlKeyDown()
  local last = math.max(self.max or 0, n)
  self.max = last
  local plusSize = math.max(14, math.floor(size * 0.5))
  for i = 1, n do
    local id = list[i]
    local bag, slot = locate(id)
    local px = x + (i - 1) * (size + gap)
    local b, g = self.slots[i], self.ghosts[i]
    if bag then
      if not b then b = ns.CreateFavButton(frame); self.slots[i] = b end
      local h = b.holder
      ns.SnapSize(h, size, size)
      h:ClearAllPoints()
      ns.SnapPoint(h, "TOPLEFT", frame, "TOPLEFT", px, -rowY)
      h:Show(); b:Show()
      bindSlot(b, bag, slot)
      paintSlot(b, bag, slot)
      if g then g:Hide() end
    else
      if not g then g = makeGhost(frame); self.ghosts[i] = g end
      ns.SnapBox(g, size, size)
      g:ClearAllPoints()
      ns.SnapPoint(g, "TOPLEFT", frame, "TOPLEFT", px, -rowY)
      if id then
        g.icon:SetTexture(itemIcon(id)); g.icon:Show(); g.plus:Hide()
      else
        g.icon:Hide()
        g.plus:SetFont(bags.fontPath or ns.Fonts:Current(), plusSize, "")
        g.plus:Show()
      end
      g:Show()
      if b then b.holder:Hide(); b.favBag = nil end
    end
    local c = self.catchers[i]
    if not c then c = makeCatcher(frame, i); self.catchers[i] = c end
    ns.SnapBox(c, size, size)
    c:ClearAllPoints()
    ns.SnapPoint(c, "TOPLEFT", frame, "TOPLEFT", px, -rowY)
    c:SetFrameLevel(frame:GetFrameLevel() + 30)
    c:EnableMouse(catch or not bag)
    c:Show()
  end
  for i = n + 1, last do
    local b, g, c = self.slots[i], self.ghosts[i], self.catchers[i]
    if b then b.holder:Hide() end
    if g then g:Hide() end
    if c then c:Hide() end
  end
  return LABEL_H + LABEL_GAP + size + 6
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:RegisterEvent("BAG_UPDATE_COOLDOWN")
ev:RegisterEvent("SPELL_UPDATE_COOLDOWN")
ev:RegisterEvent("CURSOR_CHANGED")
ev:RegisterEvent("MODIFIER_STATE_CHANGED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "PLAYER_REGEN_ENABLED" then
    Fav:Flush()
    return
  end
  if event == "MODIFIER_STATE_CHANGED" then
    if arg1 and arg1:find("CTRL", 1, true) then Fav:SetCatch() end
    return
  end
  if event == "CURSOR_CHANGED" then
    Fav:SetCatch()
    return
  end
  if event == "BAG_UPDATE_DELAYED" then
    locsDirty = true
    Fav:Refresh()
    return
  end
  Fav:Cooldowns()
end)
