local addonName, ns = ...

local ICON = 7549289
local DEFAULT_ANGLE = 2.2

local btn = CreateFrame("Button", "WarpeeMinimapButton", Minimap)
btn:SetSize(31, 31)
btn:SetFrameStrata("MEDIUM")
btn:SetMovable(true)
btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
btn:RegisterForDrag("LeftButton")
btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
btn:Hide()

local bg = btn:CreateTexture(nil, "BACKGROUND")
bg:SetSize(24, 24)
bg:SetPoint("CENTER")
bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

local icon = btn:CreateTexture(nil, "ARTWORK")
icon:SetSize(22, 22)
icon:SetPoint("CENTER")
icon:SetTexture(ICON)

local mask = btn:CreateMaskTexture()
mask:SetTexture("Interface\\Common\\CommonMaskCircle")
mask:SetAllPoints(icon)
icon:AddMaskTexture(mask)

local border = btn:CreateTexture(nil, "OVERLAY")
border:SetSize(50, 50)
border:SetPoint("TOPLEFT")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local function angle()
  return tonumber(WarpeeDB and WarpeeDB.minimapAngle) or DEFAULT_ANGLE
end

local function place(a)
  local radius = Minimap:GetWidth() / 2 + 5
  btn:ClearAllPoints()
  btn:SetPoint("CENTER", Minimap, "CENTER",
    math.cos(a) * radius, math.sin(a) * radius)
end

local function dragUpdate(self)
  if self:GetParent() ~= Minimap then return end
  local cx, cy = Minimap:GetCenter()
  local mx, my = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  place(math.atan2(my / scale - cy, mx / scale - cx))
end

btn:SetScript("OnDragStart", function(self)
  if self:GetParent() ~= Minimap then return end
  self:LockHighlight()
  self:SetScript("OnUpdate", dragUpdate)
end)

btn:SetScript("OnDragStop", function(self)
  self:SetScript("OnUpdate", nil)
  self:UnlockHighlight()
  if self:GetParent() ~= Minimap then return end
  local cx, cy = Minimap:GetCenter()
  local px, py = self:GetCenter()
  local a = math.atan2(py - cy, px - cx)
  place(a)
  if WarpeeDB then WarpeeDB.minimapAngle = a end
end)

btn:SetScript("OnClick", function(_, button)
  if button == "RightButton" then
    if ns.Options then ns.Options:Toggle() end
  else
    ns.Toggle()
  end
end)

ns.AddTip(btn, "Warpee", "left", function()
  return {
    { text = "Left click opens the bags", color = "dim", size = 12 },
    { text = "Right click opens the settings", color = "dim", size = 12 },
    { text = "Drag to move around the minimap", color = "faint", size = 12 },
  }
end)

function ns.ApplyMinimapIcon()
  if WarpeeDB and WarpeeDB.hideMinimapIcon then
    btn:Hide()
    return
  end
  place(angle())
  btn:Show()
end
