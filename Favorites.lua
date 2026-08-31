local addonName, ns = ...
local Theme = ns.Theme

local Fav = {}
ns.Fav = Fav
Fav.buttons = {}
Fav.pending = {}

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
  local n = tonumber(WarpeeDB and WarpeeDB.favCount) or 6
  return math.max(1, math.min(14, math.floor(n)))
end

function Fav:List()
  WarpeeDB.favorites = WarpeeDB.favorites or {}
  local k = charKey()
  WarpeeDB.favorites[k] = WarpeeDB.favorites[k] or {}
  return WarpeeDB.favorites[k]
end

local function itemIcon(id)
  if C_Item and C_Item.GetItemIconByID then
    local ok, tex = pcall(C_Item.GetItemIconByID, id)
    if ok and tex then return tex end
  end
  return (GetItemIcon and GetItemIcon(id)) or 134400
end

local function itemCount(id)
  if C_Item and C_Item.GetItemCount then
    local ok, n = pcall(C_Item.GetItemCount, id)
    if ok and n then return n end
  end
  return (GetItemCount and GetItemCount(id)) or 0
end

local function itemCooldown(id)
  if C_Item and C_Item.GetItemCooldown then
    local ok, s, d = pcall(C_Item.GetItemCooldown, id)
    if ok then return s, d end
  end
  if GetItemCooldown then return GetItemCooldown(id) end
end

local function applyAttr(b, id)
  if InCombatLockdown and InCombatLockdown() then
    Fav.pending[b] = id or false
    return
  end
  Fav.pending[b] = nil
  if id then
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", "/use item:" .. id)
  else
    b:SetAttribute("type", nil)
    b:SetAttribute("macrotext", nil)
  end
end

function Fav:Paint(b)
  if not b then return end
  local id = self:List()[b.favIndex]
  b.itemID = id
  applyAttr(b, id)
  local cf = math.max(9, math.floor((b:GetHeight() or 30) * 0.34))
  b.count:SetFont(ns.Fonts:Current(), cf, "OUTLINE")
  if id then
    b.icon:SetTexture(itemIcon(id))
    b.icon:Show()
    b.plus:Hide()
    local n = itemCount(id)
    b.count:SetText((n and n > 1) and n or "")
    b.icon:SetDesaturated((n or 0) == 0)
    local start, dur = itemCooldown(id)
    b.cd:SetCooldown(start or 0, dur or 0)
  else
    b.icon:Hide()
    b.count:SetText("")
    b.plus:Show()
    b.cd:SetCooldown(0, 0)
  end
end

function Fav:Set(index, id)
  local list = self:List()
  list[index] = id or nil
  self:Paint(self.buttons[index])
end

function Fav:PinFromCursor(index)
  local kind, a, link = GetCursorInfo()
  if kind ~= "item" then return end
  local id = tonumber(a)
  if not id and link then id = tonumber(link:match("item:(%d+)")) end
  if not id then return end
  self:Set(index, id)
  ClearCursor()
end

function Fav:RefreshAll()
  for _, b in ipairs(self.buttons) do
    if b:IsShown() then self:Paint(b) end
  end
end

local function tipFor(b)
  GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
  if b.itemID then
    GameTooltip:SetItemByID(b.itemID)
    GameTooltip:AddLine(ns.L["Ctrl + right click clears the slot"], 0.6, 0.6, 0.6)
  else
    GameTooltip:SetText(ns.L["Favourites"])
    GameTooltip:AddLine(ns.L["Drag an item here to keep it one click away"], 0.6, 0.6, 0.6, true)
  end
  GameTooltip:Show()
end

local function makeButton(parent, index)
  local b = CreateFrame("Button", "WarpeeFavButton" .. index, parent,
    "SecureActionButtonTemplate,BackdropTemplate")
  b.favIndex = index
  b:RegisterForClicks("AnyUp")
  ns.PixelBackdrop(b)
  b:SetBackdropColor(Theme:C("slot"))
  b:SetBackdropBorderColor(Theme:C("stroke"))
  Theme:Track(b, function(s)
    s:SetBackdropColor(Theme:C("slot"))
    s:SetBackdropBorderColor(Theme:C(s.wpeHover and "accent" or "stroke"))
  end)

  local ic = b:CreateTexture(nil, "ARTWORK")
  ic:SetPoint("TOPLEFT", 1, -1)
  ic:SetPoint("BOTTOMRIGHT", -1, 1)
  ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.icon = ic

  local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
  cd:SetAllPoints(ic)
  cd:SetDrawEdge(false)
  cd:EnableMouse(false)
  b.cd = cd

  local cnt = Theme:Label(b, 12, "text", "OUTLINE")
  cnt:SetPoint("BOTTOMRIGHT", -2, 2)
  b.count = cnt

  local plus = Theme:Label(b, 13, "faint")
  plus:SetPoint("CENTER")
  plus:SetText("+")
  b.plus = plus

  b:SetScript("OnEnter", function(s)
    s.wpeHover = true
    s:SetBackdropBorderColor(Theme:C("accent"))
    tipFor(s)
  end)
  b:SetScript("OnLeave", function(s)
    s.wpeHover = nil
    s:SetBackdropBorderColor(Theme:C("stroke"))
    GameTooltip:Hide()
  end)
  b:SetScript("OnReceiveDrag", function(s) Fav:PinFromCursor(s.favIndex) end)
  b:SetScript("PreClick", function(s, button)
    if GetCursorInfo() then
      Fav:PinFromCursor(s.favIndex)
      return
    end
    if IsControlKeyDown() and button == "RightButton" then
      Fav:Set(s.favIndex, nil)
      tipFor(s)
    end
  end)
  return b
end

function Fav:Apply(bags, x, top, size, gap)
  if not (bags and bags.frame) then return 0 end
  local frame = bags.frame
  if not self:Enabled() then
    if self.label then self.label:Hide() end
    for _, b in ipairs(self.buttons) do b:Hide() end
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

  local n = math.min(self:Count(), bags.cols or 14)
  local rowY = top + LABEL_H + LABEL_GAP
  for i = 1, n do
    local b = self.buttons[i]
    if not b then b = makeButton(frame, i); self.buttons[i] = b end
    ns.SnapBox(b, size, size)
    b:ClearAllPoints()
    ns.SnapPoint(b, "TOPLEFT", frame, "TOPLEFT", x + (i - 1) * (size + gap), -rowY)
    b:Show()
    self:Paint(b)
  end
  for i = n + 1, #self.buttons do self.buttons[i]:Hide() end
  return LABEL_H + LABEL_GAP + size + 6
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:RegisterEvent("BAG_UPDATE_COOLDOWN")
ev:RegisterEvent("SPELL_UPDATE_COOLDOWN")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_ENABLED" then
    for b, id in pairs(Fav.pending) do applyAttr(b, id or nil) end
  end
  Fav:RefreshAll()
end)
