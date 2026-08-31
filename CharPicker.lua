local addonName, ns = ...
local Theme = ns.Theme

local CLASS_RING = "Interface\\TargetingFrame\\UI-Classes-Circles"
local ROW_H, HDR_H, HEAD_H, PAD = 27, 22, 32, 8
local MAX_ROWS = 18
local MIN_W = 265

local Picker = { rows = {} }
ns.CharPicker = Picker

local function classLook(class)
  local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
  local col = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  return coords, col
end

local function fontPath()
  return ns.Fonts:Path((ns.Bags and ns.Bags.font) or ns.Fonts.DEFAULT)
end

function Picker:Build()
  if self.frame then return self.frame end

  local m = CreateFrame("Frame", "WarpeeCharPicker", UIParent, "BackdropTemplate")
  m:Hide()
  Theme:Panel(m, "bg", "accent")
  m:SetFrameStrata("FULLSCREEN_DIALOG")
  m:EnableMouse(true)
  m:SetClampedToScreen(true)
  tinsert(UISpecialFrames, "WarpeeCharPicker")
  self.frame = m

  local hide = ns.CreateButton(m, ns.L["Hidden"], 68, 23)
  ns.LocalText(hide, "Hidden")
  hide:SetPoint("TOPLEFT", PAD, -PAD)
  hide:SetScript("OnEnter", function() self:UpdateHiddenBorder() end)
  hide:SetScript("OnLeave", function() self:UpdateHiddenBorder() end)
  hide:SetScript("OnClick", function()
    self.showHidden = not self.showHidden
    self:UpdateHiddenBorder()
    self:Paint()
  end)
  self.hideBtn = hide
  ns.AddTip(hide, "Show characters you hid", "bottom")

  local close = ns.CreateGlyphButton(m, "×", 23)
  close:SetPoint("TOPRIGHT", -PAD, -PAD)
  close:SetScript("OnClick", function() m:Hide() end)
  self.close = close
  ns.AddTip(close, "Close", "bottom")

  local filter = ns.CreateSearchBox(m, function(text)
    self.query = (text or ""):lower()
    self:Paint()
  end)
  filter:SetPoint("LEFT", hide, "RIGHT", 4, 0)
  filter:SetPoint("RIGHT", close, "LEFT", -4, 0)
  filter:SetHeight(23)
  if filter.Hint then ns.LocalText(filter.Hint, "Search") end
  self.filter = filter

  local sf = CreateFrame("ScrollFrame", nil, m)
  sf:SetPoint("TOPLEFT", PAD, -(PAD + HEAD_H))
  sf:SetPoint("BOTTOMRIGHT", -PAD, PAD)
  local child = CreateFrame("Frame", nil, sf)
  child:SetPoint("TOPLEFT")
  sf:SetScrollChild(child)
  sf:EnableMouseWheel(true)
  sf:SetScript("OnMouseWheel", function(s, d)
    local span = math.max(0, child:GetHeight() - s:GetHeight())
    s:SetVerticalScroll(math.min(span, math.max(0, s:GetVerticalScroll() - d * ROW_H * 2)))
  end)
  self.sf, self.child = sf, child

  return m
end

function Picker:Row(i)
  local r = self.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, self.child)
  r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local bg = Theme:Rect(r, "panelHi", "BACKGROUND")
  bg:SetAllPoints(r)
  bg:Hide()
  r.bg = bg
  local dot = Theme:Rect(r, "accent", "ARTWORK")
  dot:SetSize(3, ROW_H - 8)
  dot:SetPoint("LEFT", 1, 0)
  dot:Hide()
  r.dot = dot
  local ic = r:CreateTexture(nil, "ARTWORK")
  ic:SetSize(20, 20)
  ic:SetPoint("LEFT", 8, 0)
  ic:SetTexture(CLASS_RING)
  r.icon = ic
  local fs = Theme:Label(r, 14, "text")
  fs:SetJustifyH("LEFT")
  r.Text = fs
  local line = Theme:Rect(r, "strokeSoft", "ARTWORK")
  ns.PixelLine(line, 1)
  line:SetPoint("BOTTOMLEFT", 0, 0)
  line:SetPoint("BOTTOMRIGHT", 0, 0)
  line:Hide()
  r.line = line
  r:SetScript("OnEnter", function(s) if s.kind == "char" then s.bg:Show() end end)
  r:SetScript("OnLeave", function(s) s.bg:Hide() end)
  r:SetScript("OnClick", function(s, button)
    if s.kind ~= "char" or not s.key then return end
    if button == "RightButton" then
      ns.Vault:SetHidden(s.key, not ns.Vault:Hidden(s.key))
      self:Paint(true)
      return
    end
    self.currentKey = s.key
    if self.onSelect then self.onSelect(s.key) end
    self:Paint(true)
  end)
  self.rows[i] = r
  ns.AddTip(r, function(s)
    if s.kind ~= "char" or not s.key then return nil end
    return ns.L["Left-click: show this character"]
  end, "left", function(s)
    if s.kind ~= "char" or not s.key then return nil end
    return { { text = ns.Vault:Hidden(s.key) and ns.L["Right-click: unhide"] or ns.L["Right-click: hide"],
               color = "dim" } }
  end)
  return r
end

function Picker:RealmRow(n, y, realm, path)
  local h = self:Row(n)
  h.kind, h.key = "realm", nil
  h:SetHeight(HDR_H)
  h:ClearAllPoints()
  h:SetPoint("TOPLEFT", 0, -y)
  h:SetPoint("TOPRIGHT", 0, -y)
  h:SetAlpha(1)
  h.icon:Hide(); h.dot:Hide(); h.bg:Hide(); h.line:Show()
  h.Text:ClearAllPoints()
  h.Text:SetPoint("LEFT", 2, 0)
  h.Text:SetPoint("RIGHT", -6, 0)
  h.Text:SetFont(path, 12, "")
  h.Text:SetTextColor(Theme:C("faint"))
  h.Text:SetText((realm or "?"):upper())
  h:Show()
end

function Picker:CharRow(n, y, e, path)
  local r = self:Row(n)
  r.kind, r.key = "char", e.key
  r:SetHeight(ROW_H)
  r:ClearAllPoints()
  r:SetPoint("TOPLEFT", 0, -y)
  r:SetPoint("TOPRIGHT", 0, -y)
  r.line:Hide()
  r.Text:ClearAllPoints()
  r.Text:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
  r.Text:SetPoint("RIGHT", -8, 0)
  r.Text:SetFont(path, 14, "")
  local coords, col = classLook(e.class)
  if coords then
    r.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4]); r.icon:Show()
  else
    r.icon:Hide()
  end
  r.Text:SetText(e.name)
  if col then r.Text:SetTextColor(col.r, col.g, col.b)
  else r.Text:SetTextColor(Theme:C("text")) end
  r:SetAlpha(e.hidden and 0.4 or 1)
  r.dot:SetShown(e.key == self.currentKey)
  r.bg:Hide()
  r:Show()
  return math.ceil(r.Text:GetStringWidth()) + 54
end

function Picker:Paint(keepScroll)
  if not self.frame then return end
  local scroll = keepScroll and self.sf:GetVerticalScroll() or 0
  local path = fontPath()
  local list = ns.Vault:Chars(self.showHidden)
  local q = self.query
  local n, y, widest, realm = 0, 0, MIN_W, nil
  for _, e in ipairs(list) do
    local pass = not (q and q ~= "" and not e.name:lower():find(q, 1, true))
    if pass then
      if e.realm ~= realm then
        realm = e.realm
        n = n + 1
        self:RealmRow(n, y, realm, path)
        y = y + HDR_H + 2
      end
      n = n + 1
      widest = math.max(widest, self:CharRow(n, y, e, path))
      y = y + ROW_H
    end
  end
  for i = n + 1, #self.rows do self.rows[i]:Hide() end

  if self.filter then
    self.filter:SetFont(path, 13, "")
    if self.filter.Hint then self.filter.Hint:SetFont(path, 13, "") end
  end
  if self.hideBtn then
    self.hideBtn.Text:SetFont(path, 13, "")
  end
  self:UpdateHiddenBorder()

  local bodyH = math.max(ROW_H, math.min(y, MAX_ROWS * ROW_H))
  self.frame:SetSize(widest + PAD * 2, PAD * 2 + HEAD_H + bodyH)
  self.child:SetSize(widest, math.max(1, y))
  local span = math.max(0, y - bodyH)
  self.sf:SetVerticalScroll(math.min(span, math.max(0, scroll)))
end

function Picker:UpdateHiddenBorder()
  local b = self.hideBtn
  if not b then return end
  if self.showHidden then
    b:SetBackdropColor(Theme:C("panelHi"))
    b:SetBackdropBorderColor(1, 0.82, 0.2, 1)
    b.Text:SetTextColor(1, 0.82, 0.2)
  elseif b:IsMouseOver() then
    b:SetBackdropColor(Theme:C("panelHi"))
    b:SetBackdropBorderColor(Theme:C("accent"))
    b.Text:SetTextColor(Theme:C("accent"))
  else
    b:SetBackdropColor(Theme:C("panel"))
    b:SetBackdropBorderColor(Theme:C("stroke"))
    b.Text:SetTextColor(Theme:C("dim"))
  end
end

function Picker:Toggle(anchor, side, onSelect, currentKey)
  local m = self:Build()
  if m:IsShown() and self.anchor == anchor then m:Hide(); return end
  self.anchor, self.onSelect, self.currentKey = anchor, onSelect, currentKey
  self.query, self.showHidden = nil, false
  if self.filter then self.filter:SetText(""); self.filter:ClearFocus() end
  self:UpdateHiddenBorder()
  self:Paint()
  local win = (anchor and anchor.GetParent and anchor:GetParent()) or anchor
  if not win then return end
  m:ClearAllPoints()
  if side == "right" then
    m:SetPoint("TOPLEFT", win, "TOPRIGHT", 6, 0)
  else
    m:SetPoint("TOPRIGHT", win, "TOPLEFT", -6, 0)
  end
  m:Show()
end

function Picker:Close()
  if self.frame then self.frame:Hide() end
end
