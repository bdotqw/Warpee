local addonName, ns = ...

local Theme = {}
ns.Theme = Theme

local SHARED = {
  emptyLine  = { 0.271, 0.310, 0.380, 1.00 },
  overlay    = { 0.949, 0.957, 0.973, 1.00 },
  text       = { 0.914, 0.925, 0.945, 1.00 },
  dim        = { 0.604, 0.639, 0.690, 1.00 },
  faint      = { 0.392, 0.427, 0.482, 1.00 },
  azure      = { 0.435, 0.706, 0.831, 1.00 },
  reagent    = { 0.353, 0.804, 0.616, 1.00 },
  silver     = { 0.663, 0.706, 0.765, 1.00 },
  copper     = { 0.780, 0.541, 0.400, 1.00 },
  gaugeLo    = { 0.498, 0.690, 0.639, 1.00 },
  gaugeHi    = { 0.878, 0.451, 0.420, 1.00 },
}

Theme.THEMES = {
  midnight = { label = "Midnight",
    bg = { 0.047, 0.059, 0.078, 0.96 }, panel = { 0.086, 0.106, 0.145, 1 },
    panelHi = { 0.129, 0.157, 0.212, 1 }, slot = { 0.055, 0.067, 0.094, 1 },
    stroke = { 0.184, 0.216, 0.278, 1 }, strokeSoft = { 0.141, 0.169, 0.216, 1 },
    accent = { 0.851, 0.659, 0.373, 1 }, accentInk = { 0.910, 0.773, 0.549, 1 },
    reagent = { 0.353, 0.804, 0.616, 1 } },
  void = { label = "Void",
    bg = { 0.020, 0.020, 0.024, 0.97 }, panel = { 0.047, 0.051, 0.059, 1 },
    panelHi = { 0.086, 0.094, 0.110, 1 }, slot = { 0.024, 0.027, 0.031, 1 },
    stroke = { 0.110, 0.122, 0.137, 1 }, strokeSoft = { 0.082, 0.090, 0.102, 1 },
    accent = { 0.353, 0.851, 0.878, 1 }, accentInk = { 0.588, 0.925, 0.941, 1 },
    text = { 0.902, 0.918, 0.933, 1 }, dim = { 0.588, 0.616, 0.647, 1 },
    faint = { 0.376, 0.400, 0.427, 1 }, emptyLine = { 0.224, 0.243, 0.267, 1 },
    azure = { 0.376, 0.596, 0.910, 1 }, reagent = { 0.416, 0.855, 0.573, 1 } },
  blood = { label = "Blood",
    bg = { 0.086, 0.035, 0.043, 0.96 }, panel = { 0.153, 0.055, 0.067, 1 },
    panelHi = { 0.220, 0.086, 0.098, 1 }, slot = { 0.106, 0.043, 0.051, 1 },
    stroke = { 0.294, 0.110, 0.125, 1 }, strokeSoft = { 0.227, 0.086, 0.098, 1 },
    accent = { 0.878, 0.239, 0.243, 1 }, accentInk = { 0.949, 0.494, 0.478, 1 },
    text = { 0.949, 0.910, 0.910, 1 }, dim = { 0.706, 0.627, 0.627, 1 },
    faint = { 0.494, 0.427, 0.427, 1 }, emptyLine = { 0.337, 0.239, 0.243, 1 },
    azure = { 0.847, 0.588, 0.353, 1 }, reagent = { 0.400, 0.827, 0.612, 1 } },
  nord = { label = "Nord",
    bg = { 0.086, 0.098, 0.129, 0.96 }, panel = { 0.149, 0.169, 0.216, 1 },
    panelHi = { 0.204, 0.231, 0.290, 1 }, slot = { 0.114, 0.129, 0.165, 1 },
    stroke = { 0.271, 0.306, 0.380, 1 }, strokeSoft = { 0.208, 0.235, 0.294, 1 },
    accent = { 0.478, 0.780, 0.871, 1 }, accentInk = { 0.667, 0.878, 0.929, 1 },
    text = { 0.882, 0.902, 0.937, 1 }, dim = { 0.639, 0.678, 0.745, 1 },
    faint = { 0.451, 0.490, 0.561, 1 }, emptyLine = { 0.310, 0.349, 0.427, 1 },
    azure = { 0.400, 0.549, 0.729, 1 }, reagent = { 0.545, 0.831, 0.729, 1 } },
  forest = { label = "Forest",
    bg = { 0.043, 0.086, 0.063, 0.96 }, panel = { 0.086, 0.157, 0.118, 1 },
    panelHi = { 0.114, 0.208, 0.153, 1 }, slot = { 0.059, 0.114, 0.082, 1 },
    stroke = { 0.165, 0.290, 0.212, 1 }, strokeSoft = { 0.125, 0.227, 0.165, 1 },
    accent = { 0.878, 0.702, 0.416, 1 }, accentInk = { 0.937, 0.827, 0.627, 1 },
    text = { 0.906, 0.929, 0.914, 1 }, dim = { 0.635, 0.686, 0.651, 1 },
    faint = { 0.443, 0.494, 0.459, 1 }, emptyLine = { 0.243, 0.337, 0.278, 1 },
    azure = { 0.478, 0.784, 0.729, 1 }, reagent = { 0.451, 0.878, 0.812, 1 } },
  nightbloom = { label = "Nightbloom",
    bg = { 0.075, 0.043, 0.106, 0.96 }, panel = { 0.137, 0.086, 0.192, 1 },
    panelHi = { 0.196, 0.125, 0.271, 1 }, slot = { 0.094, 0.055, 0.133, 1 },
    stroke = { 0.267, 0.165, 0.353, 1 }, strokeSoft = { 0.208, 0.129, 0.278, 1 },
    accent = { 0.949, 0.325, 0.639, 1 }, accentInk = { 0.976, 0.588, 0.788, 1 },
    text = { 0.925, 0.886, 0.957, 1 }, dim = { 0.686, 0.627, 0.757, 1 },
    faint = { 0.478, 0.427, 0.553, 1 }, emptyLine = { 0.337, 0.259, 0.427, 1 },
    azure = { 0.435, 0.706, 0.941, 1 }, reagent = { 0.376, 0.855, 0.686, 1 } },
  blizzard = { label = "Blizzard", skin = "blizzard",
    bg = { 0.114, 0.110, 0.106, 0.95 }, panel = { 0.169, 0.165, 0.157, 1 },
    panelHi = { 0.298, 0.286, 0.267, 1 }, slot = { 0.129, 0.125, 0.118, 1 },
    stroke = { 0.451, 0.404, 0.325, 1 }, strokeSoft = { 0.361, 0.325, 0.267, 1 },
    accent = { 0.804, 0.678, 0.451, 1 }, accentInk = { 0.910, 0.847, 0.706, 1 },
    text = { 0.965, 0.949, 0.906, 1 }, dim = { 0.741, 0.718, 0.663, 1 },
    faint = { 0.545, 0.522, 0.475, 1 },
    emptyLine = { 0.078, 0.075, 0.071, 0.90 },
    azure = { 0.478, 0.729, 0.906, 1 }, reagent = { 0.353, 0.804, 0.616, 1 } },
  blizzardflat = { label = "Blizzard Flat", skin = "blizzardflat",
    bg = { 0.055, 0.053, 0.050, 0.95 }, panel = { 0.141, 0.137, 0.129, 1 },
    panelHi = { 0.243, 0.235, 0.220, 1 }, slot = { 0.110, 0.106, 0.100, 1 },
    stroke = { 0.302, 0.290, 0.263, 1 }, strokeSoft = { 0.278, 0.267, 0.243, 1 },
    accent = { 0.918, 0.741, 0.404, 1 }, accentInk = { 0.961, 0.867, 0.647, 1 },
    text = { 0.949, 0.945, 0.937, 1 }, dim = { 0.741, 0.733, 0.714, 1 },
    faint = { 0.525, 0.518, 0.498, 1 }, emptyLine = { 0.278, 0.271, 0.255, 1 },
    azure = { 0.478, 0.729, 0.906, 1 }, reagent = { 0.353, 0.804, 0.616, 1 } },
  graphite = { label = "Graphite",
    bg = { 0.071, 0.071, 0.071, 0.96 }, panel = { 0.129, 0.129, 0.129, 1 },
    panelHi = { 0.196, 0.196, 0.196, 1 }, slot = { 0.094, 0.094, 0.094, 1 },
    stroke = { 0.251, 0.251, 0.251, 1 }, strokeSoft = { 0.192, 0.192, 0.192, 1 },
    accent = { 0.949, 0.949, 0.949, 1 }, accentInk = { 1, 1, 1, 1 },
    overlay = { 0.949, 0.949, 0.949, 1 }, gaugeHi = { 0.824, 0.686, 0.678, 1 },
    text = { 0.878, 0.878, 0.878, 1 }, dim = { 0.604, 0.604, 0.604, 1 },
    faint = { 0.404, 0.404, 0.404, 1 }, emptyLine = { 0.290, 0.290, 0.290, 1 },
    azure = { 0.729, 0.729, 0.729, 1 }, reagent = { 0.686, 0.686, 0.686, 1 } },
  class = { label = "Class", classAccent = true,
    bg = { 0.055, 0.059, 0.067, 0.96 }, panel = { 0.106, 0.114, 0.129, 1 },
    panelHi = { 0.153, 0.165, 0.184, 1 }, slot = { 0.075, 0.082, 0.094, 1 },
    stroke = { 0.204, 0.216, 0.239, 1 }, strokeSoft = { 0.157, 0.169, 0.188, 1 },
    accent = { 0.851, 0.659, 0.373, 1 }, accentInk = { 0.910, 0.773, 0.549, 1 },
    text = { 0.906, 0.918, 0.937, 1 }, dim = { 0.596, 0.620, 0.663, 1 },
    faint = { 0.392, 0.412, 0.451, 1 }, emptyLine = { 0.235, 0.251, 0.282, 1 },
    azure = { 0.478, 0.706, 0.847, 1 }, reagent = { 0.353, 0.804, 0.616, 1 } },
  abyss = { label = "Abyss",
    bg = { 0.012, 0.055, 0.071, 0.96 }, panel = { 0.024, 0.098, 0.129, 1 },
    panelHi = { 0.039, 0.141, 0.180, 1 }, slot = { 0.016, 0.071, 0.094, 1 },
    stroke = { 0.051, 0.192, 0.243, 1 }, strokeSoft = { 0.039, 0.145, 0.188, 1 },
    accent = { 0.949, 0.573, 0.243, 1 }, accentInk = { 0.973, 0.741, 0.514, 1 },
    text = { 0.878, 0.910, 0.925, 1 }, dim = { 0.576, 0.643, 0.678, 1 },
    faint = { 0.376, 0.443, 0.478, 1 }, emptyLine = { 0.110, 0.271, 0.322, 1 },
    azure = { 0.400, 0.706, 0.816, 1 }, reagent = { 0.353, 0.804, 0.667, 1 } },
}
Theme.THEME_ORDER = { "midnight", "blizzard", "blizzardflat", "class",
                      "nightbloom", "void", "nord",
                      "abyss", "blood", "forest", "graphite" }

function Theme:IsLight()
  local c = self.colors.bg
  return (c and (c[1] + c[2] + c[3]) > 1.5) and true or false
end

local function classAccent()
  local _, cls = UnitClass("player")
  local col = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
  if not (col and col.r) then return nil end
  local function lift(v) return v + (1 - v) * 0.45 end
  return { col.r, col.g, col.b, 1 },
         { lift(col.r), lift(col.g), lift(col.b), 1 }
end

Theme.colors = {}
function Theme:Apply(name)
  local t = self.THEMES[name] or self.THEMES.midnight
  local c = {}
  for k, v in pairs(SHARED) do c[k] = v end
  for k, v in pairs(t) do
    if k ~= "label" and k ~= "skin" and k ~= "classAccent" then c[k] = v end
  end
  if t.classAccent then
    local a, ink = classAccent()
    if a then c.accent, c.accentInk = a, ink end
  end
  c.brass = c.accent
  c.gaugeMid = c.accent
  self.colors = c
  self.skin = t.skin or "flat"
  self.active = self.THEMES[name] and name or "midnight"
end
Theme:Apply("midnight")

local WHITE = [[Interface\Buttons\WHITE8x8]]
Theme.WHITE = WHITE

local physH = 768
local function refreshPhys()
  local _, h = GetPhysicalScreenSize()
  if h and h > 0 then physH = h end
end
refreshPhys()

function ns.PixelUnit(region)
  local s = (region or UIParent):GetEffectiveScale()
  if not s or s <= 0 then s = 1 end
  return (768 / physH) / s
end

function ns.PX(region, n)
  n = n or 1
  local s = (region or UIParent):GetEffectiveScale()
  if not s or s <= 0 then s = 1 end
  if PixelUtil and PixelUtil.GetNearestPixelSize then
    local ok, v = pcall(PixelUtil.GetNearestPixelSize, n, s, 1)
    if ok and v and v > 0 then return v end
  end
  local unit = (768 / physH) / s
  return math.max(1, math.floor(n / unit + 0.5)) * unit
end

function ns.SnapValue(region, v)
  local unit = ns.PixelUnit(region)
  return math.floor((tonumber(v) or 0) / unit + 0.5 + 0.001) * unit
end

function ns.SnapSize(frame, w, h)
  w = tonumber(w) or 0
  h = tonumber(h) or w
  if PixelUtil and PixelUtil.SetSize then
    if pcall(PixelUtil.SetSize, frame, w, h, 1, 1) then return end
  end
  frame:SetSize(ns.SnapValue(frame, w), ns.SnapValue(frame, h))
end

function ns.SnapPoint(frame, point, rel, relPoint, x, y)
  x, y = tonumber(x) or 0, tonumber(y) or 0
  if PixelUtil and PixelUtil.SetPoint then
    if pcall(PixelUtil.SetPoint, frame, point, rel, relPoint, x, y) then return end
  end
  frame:SetPoint(point, rel, relPoint, ns.SnapValue(frame, x), ns.SnapValue(frame, y))
end

function ns.GridMetrics(region, size, gap)
  local px = ns.PixelUnit(region)
  local s = math.max(px, math.floor((tonumber(size) or 0) / px + 0.5) * px)
  local g = math.max(0, math.floor((tonumber(gap) or 0) / px + 0.5) * px)
  return s, g, s + g, px
end

function ns.SnapEven(region, v)
  local px = ns.PixelUnit(region)
  local n = math.max(2, math.floor((tonumber(v) or 0) / px + 0.5))
  if n % 2 == 1 then n = n + 1 end
  return n * px
end

function ns.SnapOdd(region, v)
  local px = ns.PixelUnit(region)
  local n = math.max(3, math.floor((tonumber(v) or 0) / px + 0.5))
  if n % 2 == 0 then n = n + 1 end
  return n * px
end

function ns.PixelFloor(region, v)
  v = tonumber(v) or 0
  if v == 0 then return 0 end
  local px = ns.PixelUnit(region)
  local n = v / px
  n = (v > 0) and math.floor(n + 0.001) or math.ceil(n - 0.001)
  return n * px
end

function ns.NoPixelSnap(obj)
  if not obj then return obj end
  if obj.SetSnapToPixelGrid then pcall(obj.SetSnapToPixelGrid, obj, false) end
  if obj.SetTexelSnappingBias then pcall(obj.SetTexelSnappingBias, obj, 0) end
  return obj
end

function ns.SetInside(obj, anchor, inset, insetY)
  anchor = anchor or obj:GetParent()
  local x = ns.PixelFloor(anchor, inset or 1)
  local y = ns.PixelFloor(anchor, insetY or inset or 1)
  obj:ClearAllPoints()
  ns.NoPixelSnap(obj)
  obj:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, -y)
  obj:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -x, y)
  return obj
end

local pixelJobs = setmetatable({}, { __mode = "k" })
function ns.PixelJob(obj, fn, key)
  local list = pixelJobs[obj]
  if not list then list = {}; pixelJobs[obj] = list end
  list[key or "job"] = fn
  fn(obj)
  return obj
end

function ns.SnapBox(frame, w, h, even)
  frame.wpeBoxW, frame.wpeBoxH = w, h
  frame.wpeBoxEven = even and true or nil
  return ns.PixelJob(frame, function(x)
    local fit = x.wpeBoxEven and ns.SnapEven or ns.SnapValue
    if x.wpeBoxW then
      local cur = x:GetWidth() or 0
      if x.wpeSetW and cur > 0 and math.abs(cur - x.wpeSetW) > 0.5 then x.wpeBoxW = cur end
      x.wpeSetW = fit(x, x.wpeBoxW)
      x:SetWidth(x.wpeSetW)
    end
    if x.wpeBoxH then
      local cur = x:GetHeight() or 0
      if x.wpeSetH and cur > 0 and math.abs(cur - x.wpeSetH) > 0.5 then x.wpeBoxH = cur end
      x.wpeSetH = fit(x, x.wpeBoxH)
      x:SetHeight(x.wpeSetH)
    end
    ns.AlignToScreen(x)
  end, "size")
end

function ns.PixelLine(t, n, axis)
  return ns.PixelJob(t, function(x)
    local v = ns.PX(x:GetParent(), n or 1)
    if axis == "w" then x:SetWidth(v) else x:SetHeight(v) end
  end, "line")
end

function ns.PixelBackdrop(frame, painter)
  if not frame.SetBackdrop then Mixin(frame, BackdropTemplateMixin) end
  if not frame.SetBackdrop then return frame end
  if not frame.wpeBdWrapped then
    frame.wpeBdWrapped = true
    local setBg, setEdge = frame.SetBackdropColor, frame.SetBackdropBorderColor
    frame.wpeSetBg, frame.wpeSetEdge = setBg, setEdge
    frame.SetBackdropColor = function(x, r, g, b, a)
      x.wpeBg = { r, g, b, a }; setBg(x, r, g, b, a)
    end
    frame.SetBackdropBorderColor = function(x, r, g, b, a)
      x.wpeEdge = { r, g, b, a }; setEdge(x, r, g, b, a)
    end
  end
  return ns.PixelJob(frame, function(x)
    if painter then painter(x); return end
    x:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = ns.PX(x) })
    local bgc = x.wpeBg or { Theme:C("panel") }
    local edc = x.wpeEdge or { Theme:C("stroke") }
    x.wpeSetBg(x, bgc[1], bgc[2], bgc[3], bgc[4])
    x.wpeSetEdge(x, edc[1], edc[2], edc[3], edc[4])
  end, "backdrop")
end

function ns.SnapFrame(frame)
  local p, rel, rp, x, y = frame:GetPoint()
  if not p then return end
  frame:ClearAllPoints()
  frame:SetPoint(p, rel or UIParent, rp or p, ns.SnapValue(frame, x or 0), ns.SnapValue(frame, y or 0))
  ns.AlignToScreen(frame)
  local fp, _, frp, fx, fy = frame:GetPoint()
  return fp or p, frp or rp or p, fx or 0, fy or 0
end

function ns.AlignToScreen(frame)
  if not (frame and frame.GetLeft and frame.GetNumPoints) then return end
  local s = frame:GetEffectiveScale()
  if not s or s <= 0 then return end
  local l, b = frame:GetLeft(), frame:GetBottom()
  if not (l and b) then return end
  local per = s * (physH / 768)
  if per <= 0 then return end
  local px, py = l * per, b * per
  local dx = (math.floor(px + 0.5) - px) / per
  local dy = (math.floor(py + 0.5) - py) / per
  if math.abs(dx) < 0.0005 and math.abs(dy) < 0.0005 then return end
  local n = frame:GetNumPoints()
  if n == 0 then return end
  local pts = {}
  for i = 1, n do
    local p, rel, rp, x, y = frame:GetPoint(i)
    if not p then return end
    pts[i] = { p, rel, rp, (x or 0) + dx, (y or 0) + dy }
  end
  frame:ClearAllPoints()
  for i = 1, n do
    local t = pts[i]
    frame:SetPoint(t[1], t[2] or frame:GetParent(), t[3] or t[1], t[4], t[5])
  end
end

function ns.SnapScroll(sf, v)
  v = math.max(0, tonumber(v) or 0)
  local unit = ns.PixelUnit(sf)
  v = math.floor(v / unit + 0.5) * unit
  local child = sf.GetScrollChild and sf:GetScrollChild()
  if child then
    local top = child:GetTop()
    local s = child:GetEffectiveScale()
    if top and s and s > 0 then
      local per = s * (physH / 768)
      local py = top * per
      v = v + (py - math.floor(py + 0.5)) / per
    end
  end
  return math.max(0, v)
end

local function restoreFont(fs)
  if not (fs.GetFont and fs.SetFont) then return end
  local ok, path, size, flags = pcall(fs.GetFont, fs)
  if not ok or not path or not size or size <= 0 then return end
  pcall(fs.SetFont, fs, path, size, flags or "")
end

local function restoreRegions(frame, depth)
  if not frame or depth > 8 then return end
  if frame.GetRegions then
    for _, r in ipairs({ frame:GetRegions() }) do
      if r.GetObjectType and r:GetObjectType() == "FontString" then restoreFont(r) end
    end
  end
  if frame.GetChildren then
    for _, c in ipairs({ frame:GetChildren() }) do restoreRegions(c, depth + 1) end
  end
end

function ns.RestoreArt(frame)
  if frame then pcall(restoreRegions, frame, 0) end
end

local function restoreAll()
  if ns.Bags then
    ns.RestoreArt(ns.Bags.frame)
    ns.RestoreArt(ns.Bags.bagWindow)
  end
  if ns.Bank then ns.RestoreArt(ns.Bank.frame) end
  if ns.Options then ns.RestoreArt(ns.Options.frame) end
  if ns.CharPicker then ns.RestoreArt(ns.CharPicker.frame) end
  ns.RestoreArt(_G.WarpeeDropdown)
  ns.RestoreArt(_G.WarpeeMinimapButton)
  ns.RestoreArt(_G.WarpeeTip)
  ns.RestoreArt(_G.WarpeeGoldTip)
  if InCombatLockdown and InCombatLockdown() then return end
  if Theme.Restyle then pcall(Theme.Restyle, Theme, Theme.active) end
end

function ns.RefreshPixels()
  refreshPhys()
  for obj, list in pairs(pixelJobs) do
    for _, fn in pairs(list) do pcall(fn, obj) end
  end
  if ns.CloseDropdown then pcall(ns.CloseDropdown) end
  local quiet = not (InCombatLockdown and InCombatLockdown())
  if ns.Bags then
    if ns.Bags.frame then ns.SnapFrame(ns.Bags.frame) end
    if ns.Bags.bagWindow then ns.SnapFrame(ns.Bags.bagWindow) end
    if quiet and ns.Bags.frame and ns.Bags.frame:IsShown() and ns.Bags.Layout then ns.Bags:Layout() end
  end
  if ns.Bank then
    if ns.Bank.frame then ns.SnapFrame(ns.Bank.frame) end
    if quiet and ns.Bank.frame and ns.Bank.frame:IsShown() and ns.Bank.Refresh then ns.Bank:Refresh() end
  end
  if ns.Options then
    if ns.Options.frame then ns.SnapFrame(ns.Options.frame) end
    if ns.Options.ReflowPages then ns.Options:ReflowPages() end
  end
  restoreAll()
end

local watcher = CreateFrame("Frame")
local lastScale = UIParent:GetEffectiveScale() or 1
local lastPhys = physH
local since = 0
local pending = false
local passes = 3
local lastRun = 0

local function runRefresh()
  pending = false
  lastRun = (GetTime and GetTime()) or 0
  passes = 0
  lastScale = UIParent:GetEffectiveScale() or lastScale
  local _, h = GetPhysicalScreenSize()
  if h and h > 0 then lastPhys = h end
  pcall(ns.RefreshPixels)
end

function ns.ScaleChanged()
  if pending then return end
  pending = true
  if C_Timer and C_Timer.After then
    local now = (GetTime and GetTime()) or 0
    C_Timer.After(math.max(0, lastRun + 0.2 - now), runRefresh)
  else
    runRefresh()
  end
end

watcher:SetScript("OnUpdate", function(self, dt)
  if passes < 3 then
    passes = passes + 1
    if passes == 3 then restoreAll() end
  end
  since = since + (dt or 0)
  if since < 0.2 then return end
  since = 0
  local s = UIParent:GetEffectiveScale() or 1
  local _, h = GetPhysicalScreenSize()
  h = (h and h > 0) and h or lastPhys
  if math.abs(s - lastScale) > 0.0005 or h ~= lastPhys then
    ns.ScaleChanged()
  end
end)

hooksecurefunc(UIParent, "SetScale", function() ns.ScaleChanged() end)
if UIParent.SetIgnoreParentScale then
  hooksecurefunc(UIParent, "SetIgnoreParentScale", function() ns.ScaleChanged() end)
end

function Theme:C(name) local c = self.colors[name]; return c[1], c[2], c[3], c[4] end

function Theme:Hex(name)
  local c = self.colors[name]
  return string.format("%02x%02x%02x", c[1] * 255 + 0.5, c[2] * 255 + 0.5, c[3] * 255 + 0.5)
end

local tracked = setmetatable({}, { __mode = "k" })
local function track(obj, fn) tracked[obj] = fn; return obj end
Theme.Track = function(_, obj, fn) return track(obj, fn) end

function Theme:Restyle(name)
  self:Apply(name)
  for obj, fn in pairs(tracked) do pcall(fn, obj) end
  if ns.Bags and ns.Bags.Restyle then ns.Bags:Restyle() end
  if ns.Bank and ns.Bank.Restyle then ns.Bank:Restyle() end
  local P = ns.CharPicker
  if P and P.frame and P.frame:IsShown() and P.Paint then P:Paint(true) end
  self:ApplyGridAlpha()
  if ns.Options and ns.Options.ReflowPages then ns.Options:ReflowPages() end
end

function Theme:GridAlpha()
  local a = WarpeeDB and tonumber(WarpeeDB.gridAlpha)
  if a == nil then return 1 end
  return a
end

function Theme:ApplyGridAlpha()
  local a = self:GridAlpha()
  if ns.Bags and ns.Bags.gridBg then ns.Bags.gridBg:SetAlpha(a) end
  if ns.Bank and ns.Bank.gridBg then ns.Bank.gridBg:SetAlpha(a) end
end

local escFrames = {}

local function escArm(f)
  if not f.wpeEscArm or InCombatLockdown() then return end
  f.wpeEscArm = nil
  f:EnableKeyboard(true)
  f:SetPropagateKeyboardInput(true)
end

local function escFree(f)
  if not f.wpeEscEat or InCombatLockdown() then return end
  f.wpeEscEat = nil
  f:SetPropagateKeyboardInput(true)
end

function ns.EscRestore()
  for i = 1, #escFrames do
    escArm(escFrames[i])
    escFree(escFrames[i])
  end
end

function ns.EscClose(frame)
  if not (frame and frame.EnableKeyboard) or frame.wpeEsc then return frame end
  frame.wpeEsc = true
  frame.wpeEscArm = true
  escFrames[#escFrames + 1] = frame
  escArm(frame)
  frame:HookScript("OnShow", function(s) escArm(s); escFree(s) end)
  frame:HookScript("OnKeyDown", function(s, key)
    if InCombatLockdown() then
      if key == "ESCAPE" then s:Hide() end
      return
    end
    if key ~= "ESCAPE" then escFree(s); return end
    s.wpeEscEat = true
    s:SetPropagateKeyboardInput(false)
    s:Hide()
    C_Timer.After(0, function() escFree(s) end)
  end)
  return frame
end

Theme.WINDOW_STRATA = "HIGH"
function Theme:Window(frame, escName)
  frame:SetFrameStrata(self.WINDOW_STRATA)
  frame:SetToplevel(true)
  if escName then ns.EscClose(frame) end
  self:WindowArt(frame)
  return frame
end

function Theme:Raise(frame)
  if frame and frame.Raise then frame:Raise() end
end

function Theme:Rect(parent, colorKey, layer)
  local t = parent:CreateTexture(nil, layer or "ARTWORK")
  t:SetTexture(WHITE)
  if colorKey then
    t:SetVertexColor(self:C(colorKey))
    track(t, function(x) x:SetVertexColor(Theme:C(colorKey)) end)
  end
  return t
end

function Theme:Label(parent, size, colorKey, flags)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFontObject(ns.Fonts:Object(size or 12, flags or ""))
  local key = colorKey or "text"
  fs:SetTextColor(self:C(key))
  track(fs, function(x) x:SetTextColor(Theme:C(key)) end)
  return fs
end

function Theme:Title(parent, size, colorKey)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFontObject(ns.Fonts:Object(size or 15, ""))
  local key = colorKey or "text"
  fs:SetTextColor(self:C(key))
  track(fs, function(x) x:SetTextColor(Theme:C(key)) end)
  return fs
end

local TIP_BG   = [[Interface\Tooltips\UI-Tooltip-Background]]
local TIP_EDGE = [[Interface\Tooltips\UI-Tooltip-Border]]
local SLOT_ATLAS = "bags-item-slot64"
local ART_TEMPLATE = "DefaultPanelTemplate"
local ART_FALLBACK = "PortraitFrameTemplate"
local ART_HIDE = { "CloseButton", "PortraitContainer", "portrait", "PortraitFrame",
                   "Portrait", "TopTileStreaks", "Inset" }
local ART_FRAMES = setmetatable({}, { __mode = "k" })

local function nineSlice(base)
  local function corner(name)
    return { layer = "OVERLAY", atlas = base .. "-Corner" .. name }
  end
  local function edge(prefix, name)
    return { layer = "OVERLAY", atlas = prefix .. base .. "-Edge" .. name,
             x = 0, y = 0, x1 = 0, y1 = 0 }
  end
  return {
    TopLeftCorner     = corner("TopLeft"),
    TopRightCorner    = corner("TopRight"),
    BottomLeftCorner  = corner("BottomLeft"),
    BottomRightCorner = corner("BottomRight"),
    TopEdge    = edge("_", "Top"),
    BottomEdge = edge("_", "Bottom"),
    LeftEdge   = edge("!", "Left"),
    RightEdge  = edge("!", "Right"),
  }
end

local FLAT_EDGE = nineSlice("OptionsFrame-NineSlice")
local EDGE_PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner",
                      "BottomRightCorner", "TopEdge", "BottomEdge", "LeftEdge", "RightEdge" }
local EDGE_HIDE = { "NineSlice", "TopLeftCorner", "TopRightCorner", "BotLeftCorner",
                    "BotRightCorner", "BottomLeftCorner", "BottomRightCorner",
                    "TopBorder", "BottomBorder", "LeftBorder", "RightBorder", "TitleBg" }

local SKINS = {
  blizzard     = { inset = 20, grain = true },
  blizzardflat = { inset = 4, drop = -5, edge = FLAT_EDGE, out = 14, band = 32,
                   bandAlpha = 0.80,
                   edgeTint = "stroke", plate = true, bodyGrain = 0.10 },
}

function Theme:SkinDef()
  return SKINS[self.skin or ""]
end

function Theme:Skinned()
  return SKINS[self.skin or ""] ~= nil
end

local atlasOK = {}

function Theme:SlotAtlas()
  local def = self:SkinDef()
  if not def then return nil end
  local name = def.slot or SLOT_ATLAS
  if atlasOK[name] == nil then
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name)
    atlasOK[name] = (info ~= nil)
  end
  return atlasOK[name] and name or nil
end

local LOWER_STRATA = { TOOLTIP = "FULLSCREEN_DIALOG", FULLSCREEN_DIALOG = "DIALOG",
                       DIALOG = "HIGH", HIGH = "MEDIUM", MEDIUM = "LOW", LOW = "BACKGROUND" }

local function sinkArt(frame, art)
  local under = LOWER_STRATA[frame:GetFrameStrata() or ""] or "MEDIUM"
  art:SetFrameStrata(under)
  art:SetFrameLevel(1)
end

local function tintEdge(art, def)
  local edge = art.wpeEdge
  if not (edge and def.edgeTint) then return end
  local r, g, b = Theme:C(def.edgeTint)
  for _, piece in ipairs(EDGE_PIECES) do
    local part = edge[piece]
    if part and part.SetVertexColor then part:SetVertexColor(r, g, b) end
  end
end

local function dressEdge(art, def)
  for _, part in ipairs(EDGE_HIDE) do
    local region = art[part]
    if region and region.Hide then region:Hide() end
  end
  if art.wpeEdge ~= nil then return art.wpeEdge end
  local ok, edge = pcall(CreateFrame, "Frame", nil, art, "NineSliceCodeTemplate")
  if not ok or not edge then ok, edge = pcall(CreateFrame, "Frame", nil, art) end
  if not ok or not edge then art.wpeEdge = false; return false end
  local o = def.out or 0
  edge:SetPoint("TOPLEFT", art, "TOPLEFT", -o, o)
  edge:SetPoint("BOTTOMRIGHT", art, "BOTTOMRIGHT", o, -o)
  edge:EnableMouse(false)
  for _, piece in ipairs(EDGE_PIECES) do
    if not edge[piece] then edge[piece] = edge:CreateTexture(nil, "OVERLAY") end
  end
  if NineSliceUtil and NineSliceUtil.ApplyLayout then
    pcall(NineSliceUtil.ApplyLayout, edge, def.edge)
  end
  art.wpeEdge = edge
  tintEdge(art, def)
  return edge
end

local function buildArt(frame, key, def)
  local cache = frame.wpeArts
  if not cache then cache = {}; frame.wpeArts = cache end
  if cache[key] ~= nil then return cache[key] end
  local ok, art = pcall(CreateFrame, "Frame", nil, frame, def.template or ART_TEMPLATE)
  if not ok or not art then
    ok, art = pcall(CreateFrame, "Frame", nil, frame, ART_FALLBACK)
  end
  if not ok or not art then cache[key] = false; return false end
  art:SetAllPoints(frame)
  art:EnableMouse(false)
  sinkArt(frame, art)
  for _, part in ipairs(ART_HIDE) do
    local region = art[part]
    if region then
      if region.EnableMouse then region:EnableMouse(false) end
      if region.Hide then region:Hide() end
    end
  end
  local title = art.TitleContainer
  if title then
    if title.TitleText then title.TitleText:SetText("") end
    if title.SetAlpha then title:SetAlpha(1) end
  end
  if def.plate then
    local plate = art:CreateTexture(nil, "BACKGROUND", nil, -8)
    plate:SetTexture(WHITE)
    plate:SetAllPoints(art)
    art.wpePlate = plate
    if art.Bg then
      if def.bodyGrain then
        art.Bg:ClearAllPoints()
        art.Bg:SetAllPoints(art)
      else
        art.Bg:Hide()
      end
    end
  end
  if def.edge then dressEdge(art, def) end
  cache[key] = art
  return art
end

function Theme:RefreshArt(frame)
  local def = self:SkinDef()
  if def then
    local art = buildArt(frame, self.skin, def)
    local cache = frame.wpeArts
    if cache then
      for key, other in pairs(cache) do
        if other and key ~= self.skin then other:Hide() end
      end
    end
    if art then
      sinkArt(frame, art)
      local a = (self.colors.bg and self.colors.bg[4]) or 1
      if art.wpePlate then
        local r, g, b = self:C("bg")
        art.wpePlate:SetVertexColor(r, g, b)
        art.wpePlate:SetAlpha(a)
        art.wpePlate:Show()
        if art.Bg and def.bodyGrain then
          art.Bg:SetAlpha(a * def.bodyGrain)
          art.Bg:Show()
        end
      elseif art.Bg then
        art.Bg:SetAlpha(a)
      end
      if art.Center then art.Center:SetAlpha(a) end
      tintEdge(art, def)
      art:Show()
    end
    frame.wpeArt = art
    if frame.wpeBandH or def.band then self:HeaderBand(frame) end
    return art
  end
  local cache = frame.wpeArts
  if cache then
    for _, other in pairs(cache) do
      if other then other:Hide() end
    end
  end
  frame.wpeArt = nil
  if frame.wpeBand then frame.wpeBand:Hide() end
  if frame.wpeBandLine then frame.wpeBandLine:Hide() end
  return false
end

function Theme:WindowArt(frame)
  ART_FRAMES[frame] = true
  local fn = tracked[frame]
  if fn then fn(frame) else self:RefreshArt(frame) end
  return frame
end

function Theme:HeaderBand(frame, height)
  if height then frame.wpeBandH = height end
  local def = self:SkinDef()
  local h = def and def.band and (frame.wpeBandH or def.band)
  local art = frame.wpeArt
  if not (h and h > 0 and art) then
    if frame.wpeBand then frame.wpeBand:Hide() end
    if frame.wpeBandLine then frame.wpeBandLine:Hide() end
    return
  end
  local a = (self.colors.bg and self.colors.bg[4]) or 1
  local band = frame.wpeBand
  if not band or band:GetParent() ~= art then
    band = art:CreateTexture(nil, "BACKGROUND", nil, 3)
    band:SetTexture(WHITE)
    frame.wpeBand = band
  end
  band:ClearAllPoints()
  band:SetPoint("TOPLEFT", frame, "TOPLEFT")
  band:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
  band:SetHeight(h)
  band:SetVertexColor(self:C("panelHi"))
  band:SetAlpha(a * (def.bandAlpha or 1))
  band:Show()
  local line = frame.wpeBandLine
  if not line or line:GetParent() ~= art then
    line = art:CreateTexture(nil, "BACKGROUND", nil, 4)
    line:SetTexture(WHITE)
    frame.wpeBandLine = line
  end
  line:ClearAllPoints()
  line:SetPoint("TOPLEFT", band, "BOTTOMLEFT")
  line:SetPoint("TOPRIGHT", band, "BOTTOMRIGHT")
  line:SetHeight(ns.PX(frame))
  line:SetVertexColor(self:C("stroke"))
  line:SetAlpha(a)
  line:Show()
  return h
end

local TITLE_STRIP = 20

function Theme:TopInset()
  local def = self:SkinDef()
  if not def then return 0 end
  return def.inset or TITLE_STRIP
end

function Theme:HeadDrop()
  local def = self:SkinDef()
  if not def then return 0 end
  return def.drop or 1
end

function Theme:Panel(frame, bgKey, strokeKey)
  local bg, st = bgKey or "bg", strokeKey or "stroke"
  local function paint(x)
    if Theme:Skinned() then
      local art = ART_FRAMES[x] and Theme:RefreshArt(x)
      if art then
        if art.Bg then
          x:SetBackdrop(nil)
        else
          x:SetBackdrop({ bgFile = WHITE,
                          insets = { left = 4, right = 4, top = 4, bottom = 4 } })
          x:SetBackdropColor(Theme:C(bg))
        end
        return
      end
      x:SetBackdrop({ bgFile = TIP_BG, edgeFile = TIP_EDGE, tile = true, tileSize = 16,
                      edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
      x:SetBackdropColor(Theme:C(bg))
      x:SetBackdropBorderColor(1, 1, 1, 1)
      return
    end
    Theme:RefreshArt(x)
    x:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = ns.PX(x) })
    x:SetBackdropColor(Theme:C(bg))
    x:SetBackdropBorderColor(Theme:C(st))
  end
  ns.PixelBackdrop(frame, paint)
  track(frame, paint)
  return frame
end

ns.Fonts = {}
ns.Fonts.DEFAULT = "Friz Quadrata"
local MEDIA = [[Interface\AddOns\Warpee\Media\Fonts\]]
local GAME_FONT = [[Fonts\FRIZQT__.TTF]]

local function clientFont()
  local fo = _G.GameFontNormal
  local p = fo and fo.GetFont and fo:GetFont()
  if type(p) == "string" and p ~= "" then return p end
  return GAME_FONT
end
local SCRIPTS = {
  latin1 = {
    chars = { "ß", "ä", "ö", "ü", "ç", "é", "à", "ñ", "ó", "ã", "ì", "ÿ" },
    fonts = { [[Fonts\FRIZQT__.TTF]], [[Fonts\ARIALN.TTF]], [[Fonts\FRIZQT___CYR.TTF]] },
  },
  cyrillic = {
    chars = { "Ш", "Г", "ш", "г", "Ё", "ъ" },
    fonts = { [[Fonts\FRIZQT___CYR.TTF]], [[Fonts\ARIALN.TTF]], [[Fonts\NIM_____.ttf]] },
  },
  hangul = {
    chars = { "가", "한", "글", "자", "요" },
    fonts = { [[Fonts\2002.TTF]], [[Fonts\2002B.TTF]], [[Fonts\K_Pagetext.TTF]] },
  },
  hanS = {
    chars = { "的", "是", "我", "你", "好" },
    fonts = { [[Fonts\ARHei.TTF]], [[Fonts\ARKai_T.TTF]], [[Fonts\ARKai_C.TTF]] },
  },
  hanT = {
    chars = { "們", "個", "這", "沒", "麼" },
    fonts = { [[Fonts\bHEI00M.ttf]], [[Fonts\bLEI00D.ttf]], [[Fonts\bKAI00M.ttf]], [[Fonts\ARKai_T.TTF]] },
  },
}
local NEEDS = {
  deDE = "latin1", esES = "latin1", esMX = "latin1", frFR = "latin1",
  itIT = "latin1", ptBR = "latin1", ruRU = "cyrillic", koKR = "hangul",
  zhCN = "hanS", zhTW = "hanT",
}

local DECLARED, scriptOK, scriptPick, judging = {}, {}, {}, {}
for k in pairs(SCRIPTS) do
  DECLARED[k], scriptOK[k], judging[k] = {}, {}, {}
end

local SHIPPED = {
  { name = "Manrope Bold",         file = "ManropeBold.ttf",        has = { latin1 = true, cyrillic = true } },
  { name = "Rubik Bold",           file = "RubikBold.ttf",          has = { latin1 = true, cyrillic = true } },
  { name = "Oswald",               file = "Oswald.ttf",             has = { latin1 = true, cyrillic = true } },
  { name = "Russo One",            file = "RussoOne.ttf",           has = { latin1 = true, cyrillic = true } },
  { name = "Archivo",              file = "Archivo.ttf",            has = { latin1 = true } },
  { name = "Fira Sans Condensed",  file = "FiraSansCondensed.ttf",  has = { latin1 = true, cyrillic = true } },
}
local BUILTIN = {
  { name = "Arial Narrow",  path = [[Fonts\ARIALN.TTF]] },
  { name = "Friz Quadrata", live = clientFont },
  { name = "Skurri",        path = [[Fonts\SKURRI.TTF]] },
  { name = "Morpheus",      path = [[Fonts\MORPHEUS.TTF]] },
}
for i = #SHIPPED, 1, -1 do
  local p = MEDIA .. SHIPPED[i].file
  local has = SHIPPED[i].has
  for k in pairs(SCRIPTS) do DECLARED[k][p] = has[k] and true or false end
  table.insert(BUILTIN, 1, { name = SHIPPED[i].name, path = p })
end
local function LSM() return _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true) or nil end
do
  local m = LSM()
  if m and m.Register then
    for _, f in ipairs(SHIPPED) do m:Register("font", f.name, MEDIA .. f.file) end
  end
end

local needFilter

function ns.Fonts:List()
  local names, seen = {}, {}
  for _, f in ipairs(BUILTIN) do names[#names + 1] = f.name; seen[f.name] = true end
  local lsm = LSM()
  if lsm then
    for _, name in ipairs(lsm:List("font")) do
      if not seen[name] then names[#names + 1] = name; seen[name] = true end
    end
  end
  if needFilter then names = needFilter(names) end
  table.sort(names)
  return names
end

local function rawPath(name)
  for _, f in ipairs(BUILTIN) do
    if f.name == name then return f.live and f.live() or f.path end
  end
  local lsm = LSM()
  if lsm then local pth = lsm:Fetch("font", name, true); if pth then return pth end end
  return clientFont()
end

local glyphProbe, pathOK = nil, {}

local function freshString()
  return UIParent:CreateFontString(nil, "OVERLAY")
end

local function applied(fs, path, size)
  if not pcall(fs.SetFont, fs, path, size or 12, "") then return false end
  fs:SetText("Mg")
  return (fs:GetStringWidth() or 0) > 0
end

local function judgePath(path, size)
  local fs = freshString()
  if not pcall(fs.SetFont, fs, path, size or 12, "") then return false end
  fs:SetText("Mg")
  if (fs:GetStringWidth() or 0) > 0 then return true end
  return nil
end

local checking = {}

local function pathUsable(path)
  if not path then return false end
  local known = pathOK[path]
  if known ~= nil then return known end
  local now = judgePath(path)
  if now ~= nil then
    pathOK[path] = now
    return now
  end
  if not checking[path] then
    checking[path] = true
    C_Timer.After(0, function()
      checking[path] = nil
      local late = judgePath(path)
      if late ~= nil then
        pathOK[path] = late
        if ns.Fonts.Refresh then ns.Fonts:Refresh() end
      end
    end)
  end
  return true
end

local ABSENT = { "\239\183\144", "\239\183\145", "\226\191\160" }

local function measure(fs, s)
  fs:SetText(s)
  return fs:GetStringWidth() or 0
end

local function judgeScript(script, path)
  local set = SCRIPTS[script]
  if not set then return true end
  glyphProbe = freshString()
  if not applied(glyphProbe, path, 24) then return nil end
  local first, same = nil, true
  for _, ch in ipairs(set.chars) do
    local w = measure(glyphProbe, ch)
    if w <= 0 then return nil end
    if not first then
      first = w
    elseif math.abs(w - first) > 0.5 then
      same = false
    end
  end
  if not same then return true end
  local ref = measure(glyphProbe, ABSENT[1])
  if ref <= 0 then return false end
  for i = 2, #ABSENT do
    if math.abs(measure(glyphProbe, ABSENT[i]) - ref) > 0.5 then return false end
  end
  return math.abs(first - ref) > 0.5
end

local function hasScript(script, path)
  if not path then return false end
  if not SCRIPTS[script] then return true end
  local declared = DECLARED[script][path]
  if declared ~= nil then return declared end
  local known = scriptOK[script][path]
  if known ~= nil then return known end
  local now = judgeScript(script, path)
  if now ~= nil then
    scriptOK[script][path] = now
    return now
  end
  if not judging[script][path] then
    judging[script][path] = true
    C_Timer.After(0, function()
      judging[script][path] = nil
      local late = judgeScript(script, path)
      if late ~= nil then
        scriptOK[script][path] = late
        if ns.Fonts.Refresh then ns.Fonts:Refresh() end
      end
    end)
  end
  return false
end

local function scriptFont(script)
  local pick = scriptPick[script]
  if pick then return pick end
  local own = clientFont()
  local set = SCRIPTS[script]
  if not set then return own end
  if hasScript(script, own) then scriptPick[script] = own; return own end
  for _, path in ipairs(set.fonts) do
    if hasScript(script, path) then scriptPick[script] = path; return path end
  end
  return own
end

function ns.Fonts:Need()
  return NEEDS[(ns.LocalePick and ns.LocalePick()) or "enUS"]
end

function ns.Fonts:Covers(script, path)
  if not script then return true end
  return hasScript(script, path) and true or false
end

needFilter = function(names)
  local need = ns.Fonts:Need()
  if not need then return names end
  local out = {}
  for _, n in ipairs(names) do
    if hasScript(need, rawPath(n)) then out[#out + 1] = n end
  end
  return (#out > 0) and out or names
end

function ns.Fonts:Path(name)
  local p = rawPath(name)
  if not pathUsable(p) then p = clientFont() end
  local need = self:Need()
  if need and not hasScript(need, p) then return scriptFont(need) end
  return p
end

function ns.Fonts:Has(name)
  if not name then return false end
  for _, n in ipairs(self:List()) do if n == name then return true end end
  return false
end

function ns.Fonts:Usable(name)
  local p = rawPath(name)
  if not pathUsable(p) then return false end
  local need = self:Need()
  if need and not hasScript(need, p) then return false end
  return true
end

function ns.Fonts:Fallback()
  if self:Usable(self.DEFAULT) then return self.DEFAULT end
  for _, n in ipairs(self:List()) do
    if self:Usable(n) then return n end
  end
  return self.DEFAULT
end

function ns.Fonts:Settle()
  local db = WarpeeDB
  if not db then return end
  local wish = db.fontWish or db.font or self.DEFAULT
  if self:Has(wish) and self:Usable(wish) then
    db.font, db.fontWish = wish, nil
  else
    db.fontWish = wish
    if not (self:Has(db.font) and self:Usable(db.font)) then
      db.font = self:Fallback()
    end
  end
  if ns.Bags then ns.Bags.font = db.font end
  self.active = nil
  return db.font
end

function ns.Fonts:Refresh()
  local name = (ns.Bags and ns.Bags.font) or (WarpeeDB and WarpeeDB.font) or self.DEFAULT
  local prev = self.active
  self.active = self:Path(name)
  if prev and prev ~= self.active and ns.Bags then
    ns.Bags.styleGen = (ns.Bags.styleGen or 0) + 1
  end
  self:Reapply()
  return self.active
end

function ns.Fonts:Current()
  return self.active or self:Refresh()
end

local objects = {}

local function dressObject(o, path, size, flags)
  o:SetFont(path, size, flags)
end

function ns.Fonts:Object(size, flags)
  size = math.max(6, math.floor(tonumber(size) or 12))
  flags = flags or ""
  local key = size .. ":" .. flags
  local o = objects[key]
  if not o then
    o = CreateFont("WarpeeFont" .. size .. flags)
    o.wpeSize, o.wpeFlags = size, flags
    o:SetTextColor(1, 1, 1)
    objects[key] = o
    dressObject(o, self:Current(), size, flags)
  end
  return o
end

function ns.Fonts:Reapply()
  local p = self:Current()
  for _, o in pairs(objects) do
    dressObject(o, p, o.wpeSize, o.wpeFlags)
  end
end
