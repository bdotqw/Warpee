local addonName, ns = ...
local Theme = ns.Theme

-- The colour of every line we append to the game's tooltip rides in the text itself. On the ru/zh/ko
-- clients a colour handed to AddLine does not survive: the first show is right, and every later one
-- leaves our line white, while the game's own lines keep theirs. An inline code is part of the string,
-- so no later show can wash it out. The call sites still pass their colour, to dress the first show
-- exactly as before.
function ns.TipInk(text, r, g, b)
  local function hex(v) return math.floor(v * 255 + 0.5) end
  return ("|cff%02x%02x%02x%s|r"):format(hex(r), hex(g), hex(b), text)
end

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

-- The frame whose tip is on screen. The tip is drawn once, when the pointer arrives, so a click that
-- changes the words it shows would leave the old ones standing until the pointer left -- which is exactly
-- what a button offering the opposite action on its own label runs into the moment it is pressed. A
-- frame that knows its words changed asks for RefreshTip below; a tip standing over another frame is not
-- ours to touch.
local tipOwner

function ns.HideTip()
  tipOwner = nil
  if tipFrame then tipFrame:Hide() end
end

local function fitWidth(fs, cap)
  local full = math.ceil(fs:GetStringWidth())
  if full <= cap then return full end
  fs:SetWidth(cap)
  local tall = fs:GetStringHeight() or 0
  local rows = math.max(2, math.ceil(full / cap))
  local lo, hi = math.floor(full / rows), cap
  while hi - lo > 3 do
    local mid = math.floor((lo + hi) / 2)
    fs:SetWidth(mid)
    if (fs:GetStringHeight() or 0) <= tall + 0.5 then hi = mid else lo = mid end
  end
  fs:SetWidth(hi)
  return hi
end

function ns.ShowTip(owner, entries, side)
  if not owner or not entries or #entries == 0 then ns.HideTip(); return end
  tipOwner = owner
  local t = tipBox()
  local path = ns.Fonts:Current()
  local cap = TIP_MAXW - TIP_PADT * 2
  local n, widest = 0, 1
  for _, e in ipairs(entries) do
    if type(e.text) == "string" and e.text ~= "" then
      n = n + 1
      local fs = tipLine(t, n)
      fs:SetFont(path, e.size or TIP_TEXT, ns.OutlineFlags())
      fs:SetWidth(cap)
      fs:SetText(ns.L[e.text])
      fs:SetTextColor(Theme:C(e.color or "text"))
      widest = math.max(widest, fitWidth(fs, cap))
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
  local off = math.floor(((owner:GetWidth() or 0) - (t:GetWidth() or 0)) / 2 + 0.5)
  if side == "bottom" then
    ns.SnapPoint(t, "TOPLEFT", owner, "BOTTOMLEFT", off, -6)
  elseif side == "top" then
    ns.SnapPoint(t, "BOTTOMLEFT", owner, "TOPLEFT", off, 6)
  elseif side == "left" then
    ns.SnapPoint(t, "TOPRIGHT", owner, "TOPLEFT", -6, 0)
  else
    ns.SnapPoint(t, "TOPLEFT", owner, "TOPRIGHT", 6, 0)
  end
  t:Show()
end

-- The entries a tip is made of, read fresh every time they are asked for: the title and the extra lines
-- are closures (the bank's tab names, the reagent switch's promise), so a change of state lands in the
-- words without the frame being told twice.
local function tipEntries(s)
  local entries = {}
  local head = s.wpeTipTitle
  if type(head) == "function" then head = head(s) end
  if type(head) == "string" and head ~= "" then entries[#entries + 1] = { text = head } end
  if s.wpeTipExtra then
    local more = s.wpeTipExtra(s)
    if type(more) == "table" then
      for _, e in ipairs(more) do entries[#entries + 1] = e end
    end
  end
  return entries
end

-- Redraw the tip of a frame whose own words just changed, and only that one: the tip already on screen
-- belongs to the frame it was raised over, so another frame calling this changes nothing. Called by the
-- reagent switch, whose tip offers the step the next click will take.
function ns.RefreshTip(frame)
  if not (frame and frame == tipOwner and tipFrame and tipFrame:IsShown()) then return end
  ns.ShowTip(frame, tipEntries(frame), frame.wpeTipSide)
end

function ns.AddTip(frame, title, side, extra)
  if not frame then return end
  -- One hook per frame: HookScript adds rather than replaces, so a persistent frame re-decorated on a
  -- rebuild would stack OnEnter/OnLeave handlers and fire ShowTip several times per hover. The guard
  -- matches AttachGoldTooltip's wpeGoldHit. The title/extra closures still see the latest values because
  -- they are stored on the frame and read live below, not captured once.
  frame.wpeTipTitle, frame.wpeTipSide, frame.wpeTipExtra = title, side, extra
  if frame.wpeTip then return end
  frame.wpeTip = true
  frame:HookScript("OnEnter", function(s)
    ns.ShowTip(s, tipEntries(s), s.wpeTipSide)
  end)
  frame:HookScript("OnLeave", ns.HideTip)
end

local goldTip
local tokenTick = false
local TIP_PAD, TIP_GAP = 8, 16
local TIP_FONT_MIN = 8

local function tipRow(t, i, size)
  local r = t.rows[i]
  if r then return r end
  r = CreateFrame("Frame", nil, t)
  local l = Theme:Label(r, size, "text")
  l:SetPoint("LEFT", 0, 0)
  l:SetJustifyH("LEFT")
  local v = Theme:Label(r, size, "text")
  v:SetPoint("RIGHT", 0, 0)
  v:SetJustifyH("RIGHT")
  r.Left, r.Right = l, v
  t.rows[i] = r
  return r
end

local function goldTipFrame()
  if goldTip then return goldTip end
  local t = CreateFrame("Frame", "WarpeeGoldTip", UIParent, "BackdropTemplate")
  Theme:Panel(t, "deep", "accent")
  t:SetFrameStrata("TOOLTIP")
  t:SetClampedToScreen(true)
  t:Hide()
  t.rows = {}
  local line = Theme:Rect(t, "strokeSoft", "ARTWORK")
  ns.PixelLine(line, 1)
  line:Hide()
  t.sep = line
  local line2 = Theme:Rect(t, "strokeSoft", "ARTWORK")
  ns.PixelLine(line2, 1)
  line2:Hide()
  t.sep2 = line2
  goldTip = t
  return t
end

-- The threshold hides small purses from the table, but the total still counts every character: the
-- number is the account's gold, not the sum of whatever the filter happens to show. Every row is
-- filtered alike, the current character included: the setting is about what the player wants to read.
function ns.GoldRows(list, min)
  if not min or min <= 0 then return list end
  local out = {}
  for _, e in ipairs(list) do
    if (e.money or 0) >= min then out[#out + 1] = e end
  end
  return out
end

-- The client's own purse ceiling: a character holds at most 9,999,999 gold. A threshold above it could
-- only hide every character, and a save written before the list of presets (a hand-typed figure) can
-- still carry one, so the filter reads it through the ceiling rather than trusting it.
local GOLD_CAP = 9999999

local function showGoldTip(anchor)
  if WarpeeDB and WarpeeDB.tipGold == false then
    if goldTip then goldTip:Hide() end
    return
  end
  local t = goldTipFrame()
  local path = ns.Fonts:Current()
  local list, total = ns.Vault:MoneyList()
  local min = tonumber(WarpeeDB and WarpeeDB.goldMin) or 0
  if min > GOLD_CAP * 10000 then min = GOLD_CAP * 10000 end
  local shown = ns.GoldRows(list, min)
  local wb = ns.Vault:WarbandMoney()
  local token = 0
  if C_WowTokenPublic and C_WowTokenPublic.GetCurrentMarketPrice then
    if not tokenTick and C_WowTokenPublic.UpdateMarketPrice and C_Timer and C_Timer.NewTicker then
      tokenTick = true
      C_WowTokenPublic.UpdateMarketPrice()
      C_Timer.NewTicker(60, function() C_WowTokenPublic.UpdateMarketPrice() end)
    end
    token = C_WowTokenPublic.GetCurrentMarketPrice() or 0
  end

  -- One row is reserved for "nothing recorded" only when the store itself is empty; a filter that hides
  -- every purse must not leave a blank row of height behind.
  local listed = #shown
  if listed == 0 and #list == 0 then listed = 1 end
  local count = listed + 1 + ((wb and wb > 0) and 1 or 0) + ((token > 0) and 1 or 0)
  local top = (anchor and anchor:GetTop()) or 0
  local avail = math.max(120, (UIParent:GetHeight() or 768) - top - 24)
  local size = anchor and anchor.wpeGoldSize
  if type(size) == "function" then size = size() end
  local fs = ns.Density(size).font - 1
  while fs > TIP_FONT_MIN and (count * (fs + 3) + TIP_PAD * 2 + 7) > avail do
    fs = fs - 1
  end
  local rowH = fs + 3

  local n, y, widest = 0, TIP_PAD, 90

  local function row(name, amount, colorKey, col)
    n = n + 1
    local r = tipRow(t, n, fs)
    r:SetHeight(rowH)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", TIP_PAD, -y)
    r:SetPoint("TOPRIGHT", -TIP_PAD, -y)
    r.Left:SetFont(path, fs, ns.OutlineFlags())
    r.Right:SetFont(path, fs, ns.OutlineFlags())
    r.Left:SetText(name)
    r.Right:SetText(amount or "")
    if col then r.Left:SetTextColor(col.r, col.g, col.b)
    else r.Left:SetTextColor(Theme:C(colorKey or "text")) end
    r.Right:SetTextColor(Theme:C("overlay"))
    r:Show()
    widest = math.max(widest,
      math.ceil(r.Left:GetStringWidth() + r.Right:GetStringWidth()) + TIP_GAP)
    y = y + rowH
  end

  for _, e in ipairs(shown) do
    -- An empty purse is listed but not dressed up: dim and uncoloured, so a run of zeroes does not read
    -- as gold the way the class colours do.
    local live = (e.money or 0) > 0
    local col = live and e.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.class]
    row(e.name, ns.FormatMoney(e.money, true, true), live and "text" or "dim", col)
  end
  -- "Nothing recorded" is about the store, not about the filter: a threshold that hides every row must
  -- leave the table empty, not claim the purse was never recorded.
  if n == 0 and #list == 0 then row(ns.L["No gold recorded yet"], "", "dim") end

  local sum = total
  -- With every purse hidden by the threshold there is nothing above the total, so the divider has no
  -- row to separate and is left out rather than drawn across the top of the tip.
  if n > 0 then
    y = y + 3
    t.sep:ClearAllPoints()
    t.sep:SetPoint("TOPLEFT", TIP_PAD, -y)
    t.sep:SetPoint("TOPRIGHT", -TIP_PAD, -y)
    t.sep:Show()
    y = y + 4
  else
    t.sep:Hide()
  end
  if wb and wb > 0 then
    row(ns.L["Warband bank"], ns.FormatMoney(wb, true, true), "azure")
    sum = sum + wb
  end
  row(ns.L["Total"], ns.FormatMoney(sum, true, true), "accent")
  if token > 0 then
    y = y + 3
    t.sep2:ClearAllPoints()
    t.sep2:SetPoint("TOPLEFT", TIP_PAD, -y)
    t.sep2:SetPoint("TOPRIGHT", -TIP_PAD, -y)
    t.sep2:Show()
    y = y + 4
    row(ns.L["WoW Token"], ns.FormatMoney(token, true, true), "dim")
  elseif t.sep2 then
    t.sep2:Hide()
  end

  for i = n + 1, #t.rows do t.rows[i]:Hide() end
  t:SetSize(widest + TIP_PAD * 2, y + TIP_PAD)
  t:ClearAllPoints()
  t:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, 6)
  t:Show()
end

function ns.AttachGoldTooltip(region, parent, size)
  if not region then return nil end
  if region.wpeGoldHit then return region.wpeGoldHit end
  local hit = CreateFrame("Frame", nil, parent or region:GetParent())
  hit:SetAllPoints(region)
  hit:EnableMouse(true)
  hit.wpeGoldSize = size
  hit:SetScript("OnEnter", function(s) showGoldTip(s) end)
  hit:SetScript("OnLeave", function() if goldTip then goldTip:Hide() end end)
  region.wpeGoldHit = hit
  return hit
end
