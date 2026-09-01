local addonName, ns = ...
local Theme = ns.Theme

local tipFrame
local TIP_MAXW, TIP_PADT, TIP_TEXT = 340, 9, 13

local function tipLine(t, i)
  local fs = t.lines[i]
  if fs then return fs end
  fs = Theme:Label(t, TIP_TEXT, "text")
  fs:SetJustifyH("LEFT")
  fs:SetWordWrap(true)
  t.lines[i] = fs
  return fs
end

local function tipBox()
  if tipFrame then return tipFrame end
  local t = CreateFrame("Frame", "WarpeeTip", UIParent, "BackdropTemplate")
  Theme:Panel(t, "bg", "accent")
  t:SetFrameStrata("TOOLTIP")
  t:SetClampedToScreen(true)
  t:Hide()
  t.lines = {}
  tipFrame = t
  return t
end

function ns.HideTip()
  if tipFrame then tipFrame:Hide() end
end

function ns.ShowTip(owner, entries, side)
  if not owner or not entries or #entries == 0 then ns.HideTip(); return end
  local t = tipBox()
  local path = ns.Fonts:Path((ns.Bags and ns.Bags.font) or ns.Fonts.DEFAULT)
  local cap = TIP_MAXW - TIP_PADT * 2
  local n, widest = 0, 1
  for _, e in ipairs(entries) do
    if type(e.text) == "string" and e.text ~= "" then
      n = n + 1
      local fs = tipLine(t, n)
      fs:SetFont(path, e.size or TIP_TEXT, "")
      fs:SetWidth(cap)
      fs:SetText(ns.L[e.text])
      fs:SetTextColor(Theme:C(e.color or "text"))
      widest = math.max(widest, math.ceil(fs:GetStringWidth()))
    end
  end
  if n == 0 then t:Hide(); return end
  local w = math.min(cap, widest)
  local y = TIP_PADT
  for i = 1, n do
    local fs = t.lines[i]
    fs:SetWidth(w)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", TIP_PADT, -y)
    fs:Show()
    y = y + math.ceil(fs:GetStringHeight()) + 3
  end
  for i = n + 1, #t.lines do t.lines[i]:Hide() end
  t:SetSize(ns.SnapEven(t, w + TIP_PADT * 2), ns.SnapValue(t, y + TIP_PADT - 3))
  t:ClearAllPoints()
  if side == "bottom" then
    ns.SnapPoint(t, "TOP", owner, "BOTTOM", 0, -6)
  elseif side == "top" then
    ns.SnapPoint(t, "BOTTOM", owner, "TOP", 0, 6)
  elseif side == "left" then
    ns.SnapPoint(t, "TOPRIGHT", owner, "TOPLEFT", -6, 0)
  else
    ns.SnapPoint(t, "TOPLEFT", owner, "TOPRIGHT", 6, 0)
  end
  t:Show()
end

function ns.AddTip(frame, title, side, extra)
  if not frame then return end
  frame:HookScript("OnEnter", function(s)
    local entries = {}
    local head = title
    if type(title) == "function" then head = title(s) end
    if type(head) == "string" and head ~= "" then entries[#entries + 1] = { text = head } end
    if extra then
      local more = extra(s)
      if type(more) == "table" then
        for _, e in ipairs(more) do entries[#entries + 1] = e end
      end
    end
    ns.ShowTip(s, entries, side)
  end)
  frame:HookScript("OnLeave", ns.HideTip)
end

local goldTip
local TIP_PAD, TIP_GAP = 8, 16
local TIP_FONT_MAX, TIP_FONT_MIN = 14, 8

local function tipRow(t, i)
  local r = t.rows[i]
  if r then return r end
  r = CreateFrame("Frame", nil, t)
  local l = Theme:Label(r, TIP_FONT_MAX, "text")
  l:SetPoint("LEFT", 0, 0)
  l:SetJustifyH("LEFT")
  local v = Theme:Label(r, TIP_FONT_MAX, "text")
  v:SetPoint("RIGHT", 0, 0)
  v:SetJustifyH("RIGHT")
  r.Left, r.Right = l, v
  t.rows[i] = r
  return r
end

local function goldTipFrame()
  if goldTip then return goldTip end
  local t = CreateFrame("Frame", "WarpeeGoldTip", UIParent, "BackdropTemplate")
  Theme:Panel(t, "bg", "accent")
  t:SetFrameStrata("TOOLTIP")
  t:SetClampedToScreen(true)
  t:Hide()
  t.rows = {}
  local line = Theme:Rect(t, "strokeSoft", "ARTWORK")
  ns.PixelLine(line, 1)
  line:Hide()
  t.sep = line
  goldTip = t
  return t
end

local function showGoldTip(anchor)
  local t = goldTipFrame()
  local path = ns.Fonts:Path((ns.Bags and ns.Bags.font) or ns.Fonts.DEFAULT)
  local list, total = ns.Vault:MoneyList()
  local wb = ns.Vault:WarbandMoney()

  local count = math.max(1, #list) + 1 + ((wb and wb > 0) and 1 or 0)
  local top = (anchor and anchor:GetTop()) or 0
  local avail = math.max(120, (UIParent:GetHeight() or 768) - top - 24)
  local fs = TIP_FONT_MAX
  while fs > TIP_FONT_MIN and (count * (fs + 3) + TIP_PAD * 2 + 7) > avail do
    fs = fs - 1
  end
  local rowH = fs + 3

  local n, y, widest = 0, TIP_PAD, 90

  local function row(name, amount, colorKey, col)
    n = n + 1
    local r = tipRow(t, n)
    r:SetHeight(rowH)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", TIP_PAD, -y)
    r:SetPoint("TOPRIGHT", -TIP_PAD, -y)
    r.Left:SetFont(path, fs, "")
    r.Right:SetFont(path, fs, "")
    r.Left:SetText(name)
    r.Right:SetText(amount or "")
    if col then
      r.Left:SetTextColor(col.r, col.g, col.b)
    else
      r.Left:SetTextColor(Theme:C(colorKey or "text"))
    end
    r.Right:SetTextColor(Theme:C("text"))
    r:Show()
    widest = math.max(widest,
      math.ceil(r.Left:GetStringWidth() + r.Right:GetStringWidth()) + TIP_GAP)
    y = y + rowH
  end

  for _, e in ipairs(list) do
    local col = e.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.class]
    row(e.name, ns.FormatMoney(e.money, true), "text", col)
  end
  if n == 0 then row(ns.L["No gold recorded yet"], "", "dim") end

  local sum = total
  y = y + 3
  t.sep:ClearAllPoints()
  t.sep:SetPoint("TOPLEFT", TIP_PAD, -y)
  t.sep:SetPoint("TOPRIGHT", -TIP_PAD, -y)
  t.sep:Show()
  y = y + 4
  if wb and wb > 0 then
    row(ns.L["Warband bank"], ns.FormatMoney(wb, true), "azure")
    sum = sum + wb
  end
  row(ns.L["Total"], ns.FormatMoney(sum, true), "accent")

  for i = n + 1, #t.rows do t.rows[i]:Hide() end
  t:SetSize(widest + TIP_PAD * 2, y + TIP_PAD)
  t:ClearAllPoints()
  t:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, 6)
  t:Show()
end

function ns.AttachGoldTooltip(region, parent)
  if not region or region.wpeGoldHit then return region.wpeGoldHit end
  local hit = CreateFrame("Frame", nil, parent or region:GetParent())
  hit:SetAllPoints(region)
  hit:EnableMouse(true)
  hit:SetScript("OnEnter", function(s) showGoldTip(s) end)
  hit:SetScript("OnLeave", function() if goldTip then goldTip:Hide() end end)
  region.wpeGoldHit = hit
  return hit
end
