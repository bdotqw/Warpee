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
    bg = { 0.055, 0.067, 0.082, 0.96 }, panel = { 0.094, 0.114, 0.149, 1 },
    panelHi = { 0.122, 0.145, 0.188, 1 }, slot = { 0.059, 0.071, 0.098, 1 },
    stroke = { 0.149, 0.176, 0.220, 1 }, strokeSoft = { 0.125, 0.149, 0.184, 1 },
    accent = { 0.851, 0.659, 0.373, 1 }, accentInk = { 0.910, 0.773, 0.549, 1 },
    reagent = { 0.353, 0.804, 0.616, 1 } },
  ember = { label = "Ember",
    bg = { 0.075, 0.063, 0.055, 0.96 }, panel = { 0.130, 0.108, 0.090, 1 },
    panelHi = { 0.166, 0.138, 0.112, 1 }, slot = { 0.088, 0.073, 0.061, 1 },
    stroke = { 0.200, 0.165, 0.130, 1 }, strokeSoft = { 0.160, 0.134, 0.108, 1 },
    accent = { 0.870, 0.660, 0.360, 1 }, accentInk = { 0.925, 0.775, 0.540, 1 },
    reagent = { 0.318, 0.784, 0.729, 1 } },
  obsidian = { label = "Obsidian",
    bg = { 0.040, 0.045, 0.052, 0.96 }, panel = { 0.078, 0.088, 0.100, 1 },
    panelHi = { 0.104, 0.118, 0.135, 1 }, slot = { 0.052, 0.060, 0.070, 1 },
    stroke = { 0.130, 0.150, 0.175, 1 }, strokeSoft = { 0.108, 0.124, 0.145, 1 },
    accent = { 0.435, 0.706, 0.831, 1 }, accentInk = { 0.620, 0.810, 0.900, 1 },
    reagent = { 0.412, 0.847, 0.549, 1 } },
  void = { label = "Void",
    bg = { 0.020, 0.020, 0.024, 0.97 }, panel = { 0.047, 0.051, 0.059, 1 },
    panelHi = { 0.071, 0.078, 0.090, 1 }, slot = { 0.031, 0.035, 0.039, 1 },
    stroke = { 0.110, 0.122, 0.137, 1 }, strokeSoft = { 0.082, 0.090, 0.102, 1 },
    accent = { 0.353, 0.851, 0.878, 1 }, accentInk = { 0.588, 0.925, 0.941, 1 },
    text = { 0.902, 0.918, 0.933, 1 }, dim = { 0.588, 0.616, 0.647, 1 },
    faint = { 0.376, 0.400, 0.427, 1 }, emptyLine = { 0.224, 0.243, 0.267, 1 },
    azure = { 0.435, 0.729, 0.847, 1 }, reagent = { 0.416, 0.855, 0.573, 1 } },
  blood = { label = "Blood",
    bg = { 0.086, 0.035, 0.043, 0.96 }, panel = { 0.153, 0.055, 0.067, 1 },
    panelHi = { 0.200, 0.075, 0.086, 1 }, slot = { 0.106, 0.043, 0.051, 1 },
    stroke = { 0.294, 0.110, 0.125, 1 }, strokeSoft = { 0.227, 0.086, 0.098, 1 },
    accent = { 0.878, 0.239, 0.243, 1 }, accentInk = { 0.949, 0.494, 0.478, 1 },
    text = { 0.949, 0.910, 0.910, 1 }, dim = { 0.706, 0.627, 0.627, 1 },
    faint = { 0.494, 0.427, 0.427, 1 }, emptyLine = { 0.337, 0.239, 0.243, 1 },
    azure = { 0.847, 0.588, 0.353, 1 }, reagent = { 0.400, 0.827, 0.612, 1 } },
  nord = { label = "Nord",
    bg = { 0.110, 0.125, 0.157, 0.96 }, panel = { 0.180, 0.204, 0.251, 1 },
    panelHi = { 0.231, 0.259, 0.322, 1 }, slot = { 0.141, 0.161, 0.200, 1 },
    stroke = { 0.298, 0.337, 0.416, 1 }, strokeSoft = { 0.235, 0.267, 0.329, 1 },
    accent = { 0.533, 0.753, 0.816, 1 }, accentInk = { 0.671, 0.847, 0.890, 1 },
    text = { 0.847, 0.871, 0.914, 1 }, dim = { 0.639, 0.678, 0.745, 1 },
    faint = { 0.451, 0.490, 0.561, 1 }, emptyLine = { 0.310, 0.349, 0.427, 1 },
    azure = { 0.506, 0.631, 0.757, 1 }, reagent = { 0.639, 0.847, 0.784, 1 } },
  forest = { label = "Forest",
    bg = { 0.043, 0.086, 0.063, 0.96 }, panel = { 0.086, 0.157, 0.118, 1 },
    panelHi = { 0.114, 0.208, 0.153, 1 }, slot = { 0.059, 0.114, 0.082, 1 },
    stroke = { 0.165, 0.290, 0.212, 1 }, strokeSoft = { 0.125, 0.227, 0.165, 1 },
    accent = { 0.878, 0.702, 0.416, 1 }, accentInk = { 0.937, 0.827, 0.627, 1 },
    text = { 0.906, 0.929, 0.914, 1 }, dim = { 0.635, 0.686, 0.651, 1 },
    faint = { 0.443, 0.494, 0.459, 1 }, emptyLine = { 0.243, 0.337, 0.278, 1 },
    azure = { 0.478, 0.784, 0.729, 1 }, reagent = { 0.451, 0.878, 0.812, 1 } },
  nightbloom = { label = "Nightbloom",
    bg = { 0.071, 0.055, 0.098, 0.96 }, panel = { 0.129, 0.100, 0.180, 1 },
    panelHi = { 0.176, 0.137, 0.243, 1 }, slot = { 0.086, 0.067, 0.122, 1 },
    stroke = { 0.243, 0.180, 0.322, 1 }, strokeSoft = { 0.192, 0.145, 0.259, 1 },
    accent = { 0.933, 0.353, 0.616, 1 }, accentInk = { 0.973, 0.588, 0.769, 1 },
    text = { 0.914, 0.886, 0.949, 1 }, dim = { 0.678, 0.635, 0.749, 1 },
    faint = { 0.475, 0.435, 0.545, 1 }, emptyLine = { 0.322, 0.278, 0.404, 1 },
    azure = { 0.643, 0.510, 0.902, 1 }, reagent = { 0.400, 0.816, 0.643, 1 } },
  blizzard = { label = "Blizzard", skin = "blizzard",
    bg = { 0.114, 0.110, 0.106, 0.95 }, panel = { 0.169, 0.165, 0.157, 1 },
    panelHi = { 0.298, 0.286, 0.267, 1 }, slot = { 0.129, 0.125, 0.118, 1 },
    stroke = { 0.451, 0.404, 0.325, 1 }, strokeSoft = { 0.361, 0.325, 0.267, 1 },
    accent = { 0.804, 0.678, 0.451, 1 }, accentInk = { 0.910, 0.847, 0.706, 1 },
    text = { 0.965, 0.949, 0.906, 1 }, dim = { 0.741, 0.718, 0.663, 1 },
    faint = { 0.545, 0.522, 0.475, 1 },
    emptyLine = { 0.078, 0.075, 0.071, 0.90 },
    azure = { 0.478, 0.729, 0.906, 1 }, reagent = { 0.353, 0.804, 0.616, 1 } },
  graphite = { label = "Graphite",
    bg = { 0.071, 0.071, 0.071, 0.96 }, panel = { 0.129, 0.129, 0.129, 1 },
    panelHi = { 0.184, 0.184, 0.184, 1 }, slot = { 0.094, 0.094, 0.094, 1 },
    stroke = { 0.251, 0.251, 0.251, 1 }, strokeSoft = { 0.192, 0.192, 0.192, 1 },
    accent = { 0.878, 0.878, 0.886, 1 }, accentInk = { 0.961, 0.961, 0.969, 1 },
    text = { 0.902, 0.902, 0.902, 1 }, dim = { 0.612, 0.612, 0.612, 1 },
    faint = { 0.408, 0.408, 0.408, 1 }, emptyLine = { 0.290, 0.290, 0.290, 1 },
    azure = { 0.588, 0.647, 0.706, 1 }, reagent = { 0.549, 0.686, 0.588, 1 } },
  class = { label = "Class", classAccent = true,
    bg = { 0.055, 0.059, 0.067, 0.96 }, panel = { 0.106, 0.114, 0.129, 1 },
    panelHi = { 0.153, 0.165, 0.184, 1 }, slot = { 0.075, 0.082, 0.094, 1 },
    stroke = { 0.204, 0.216, 0.239, 1 }, strokeSoft = { 0.157, 0.169, 0.188, 1 },
    accent = { 0.851, 0.659, 0.373, 1 }, accentInk = { 0.910, 0.773, 0.549, 1 },
    text = { 0.906, 0.918, 0.937, 1 }, dim = { 0.596, 0.620, 0.663, 1 },
    faint = { 0.392, 0.412, 0.451, 1 }, emptyLine = { 0.235, 0.251, 0.282, 1 },
    azure = { 0.478, 0.706, 0.847, 1 }, reagent = { 0.353, 0.804, 0.616, 1 } },
  abyss = { label = "Abyss",
    bg = { 0.031, 0.063, 0.078, 0.96 }, panel = { 0.055, 0.106, 0.129, 1 },
    panelHi = { 0.078, 0.145, 0.176, 1 }, slot = { 0.039, 0.078, 0.094, 1 },
    stroke = { 0.106, 0.196, 0.235, 1 }, strokeSoft = { 0.082, 0.153, 0.184, 1 },
    accent = { 0.902, 0.639, 0.298, 1 }, accentInk = { 0.949, 0.784, 0.545, 1 },
    text = { 0.878, 0.910, 0.925, 1 }, dim = { 0.576, 0.643, 0.678, 1 },
    faint = { 0.376, 0.443, 0.478, 1 }, emptyLine = { 0.176, 0.278, 0.322, 1 },
    azure = { 0.400, 0.706, 0.816, 1 }, reagent = { 0.353, 0.804, 0.667, 1 } },
  gunmetal = { label = "Gunmetal",
    bg = { 0.078, 0.086, 0.094, 0.96 }, panel = { 0.129, 0.141, 0.153, 1 },
    panelHi = { 0.180, 0.196, 0.212, 1 }, slot = { 0.098, 0.106, 0.118, 1 },
    stroke = { 0.235, 0.251, 0.271, 1 }, strokeSoft = { 0.180, 0.196, 0.212, 1 },
    accent = { 0.902, 0.494, 0.208, 1 }, accentInk = { 0.953, 0.667, 0.451, 1 },
    text = { 0.898, 0.910, 0.922, 1 }, dim = { 0.596, 0.612, 0.635, 1 },
    faint = { 0.400, 0.416, 0.439, 1 }, emptyLine = { 0.239, 0.255, 0.275, 1 },
    azure = { 0.494, 0.667, 0.796, 1 }, reagent = { 0.400, 0.769, 0.588, 1 } },
  moss = { label = "Moss",
    bg = { 0.067, 0.071, 0.043, 0.96 }, panel = { 0.122, 0.129, 0.078, 1 },
    panelHi = { 0.169, 0.180, 0.106, 1 }, slot = { 0.086, 0.090, 0.055, 1 },
    stroke = { 0.239, 0.251, 0.149, 1 }, strokeSoft = { 0.184, 0.196, 0.118, 1 },
    accent = { 0.796, 0.831, 0.475, 1 }, accentInk = { 0.886, 0.906, 0.678, 1 },
    text = { 0.914, 0.918, 0.878, 1 }, dim = { 0.639, 0.651, 0.573, 1 },
    faint = { 0.439, 0.451, 0.384, 1 }, emptyLine = { 0.278, 0.290, 0.184, 1 },
    azure = { 0.588, 0.784, 0.706, 1 }, reagent = { 0.478, 0.847, 0.588, 1 } },
}
Theme.THEME_ORDER = { "midnight", "blizzard", "class", "nightbloom", "void", "nord",
                      "abyss", "blood", "obsidian", "graphite", "gunmetal",
                      "forest", "moss", "ember" }

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

function ns.EscClose(frame)
  if not (frame and frame.EnableKeyboard) or frame.wpeEsc then return frame end
  frame.wpeEsc = true
  frame:EnableKeyboard(true)
  frame:SetPropagateKeyboardInput(true)
  frame:HookScript("OnKeyDown", function(s, key)
    if key ~= "ESCAPE" then
      s:SetPropagateKeyboardInput(true)
      return
    end
    s:SetPropagateKeyboardInput(false)
    s:Hide()
  end)
  frame:HookScript("OnHide", function(s) s:SetPropagateKeyboardInput(true) end)
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
  fs:SetFont(ns.Fonts:Current(), size or 12, flags or "")
  local key = colorKey or "text"
  fs:SetTextColor(self:C(key))
  track(fs, function(x) x:SetTextColor(Theme:C(key)) end)
  return fs
end

function Theme:Title(parent, size, colorKey)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(ns.Fonts:Current(), size or 15, "")
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

function Theme:Skinned()
  return self.skin == "blizzard"
end

function Theme:SlotAtlas()
  if not self:Skinned() then return nil end
  if self.slotAtlasOK == nil then
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(SLOT_ATLAS)
    self.slotAtlasOK = (info ~= nil)
  end
  return self.slotAtlasOK and SLOT_ATLAS or nil
end

local LOWER_STRATA = { TOOLTIP = "FULLSCREEN_DIALOG", FULLSCREEN_DIALOG = "DIALOG",
                       DIALOG = "HIGH", HIGH = "MEDIUM", MEDIUM = "LOW", LOW = "BACKGROUND" }

local function sinkArt(frame, art)
  local under = LOWER_STRATA[frame:GetFrameStrata() or ""] or "MEDIUM"
  art:SetFrameStrata(under)
  art:SetFrameLevel(1)
end

local function buildArt(frame)
  if frame.wpeArt ~= nil then return frame.wpeArt end
  local ok, art = pcall(CreateFrame, "Frame", nil, frame, ART_TEMPLATE)
  if not ok or not art then
    ok, art = pcall(CreateFrame, "Frame", nil, frame, ART_FALLBACK)
  end
  if not ok or not art then frame.wpeArt = false; return false end
  art:SetAllPoints(frame)
  art:EnableMouse(false)
  sinkArt(frame, art)
  for _, key in ipairs(ART_HIDE) do
    local part = art[key]
    if part then
      if part.EnableMouse then part:EnableMouse(false) end
      if part.Hide then part:Hide() end
    end
  end
  local title = art.TitleContainer
  if title then
    if title.TitleText then title.TitleText:SetText("") end
    if title.SetAlpha then title:SetAlpha(1) end
  end
  frame.wpeArt = art
  return art
end

function Theme:RefreshArt(frame)
  if self:Skinned() then
    local art = buildArt(frame)
    if art then
      sinkArt(frame, art)
      local a = (self.colors.bg and self.colors.bg[4]) or 1
      if art.Bg then art.Bg:SetAlpha(a) end
      if art.Center then art.Center:SetAlpha(a) end
      art:Show()
    end
    if frame.wpeBandH then self:HeaderBand(frame) end
    return art
  end
  if frame.wpeArt then frame.wpeArt:Hide() end
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
  local line = frame.wpeBandLine
  if line then line:Hide() end
end

local TITLE_STRIP = 20

function Theme:TopInset()
  return self:Skinned() and TITLE_STRIP or 0
end

function Theme:HeadLift()
  return self:Skinned() and 1 or 0
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
ns.Fonts.DEFAULT = "Expressway"
local MEDIA = [[Interface\AddOns\Warpee\Media\]]
local SHIPPED = {
  { name = "Expressway",           file = "Expressway.ttf",         cyr = true },
  { name = "Manrope",              file = "Manrope.ttf",            cyr = true },
  { name = "Onest",                file = "Onest.ttf",              cyr = true },
  { name = "Golos Text",           file = "GolosText.ttf",          cyr = true },
  { name = "Geologica",            file = "Geologica.ttf",          cyr = true },
  { name = "Rubik",                file = "Rubik.ttf",              cyr = true },
  { name = "Archivo",              file = "Archivo.ttf",            cyr = false },
  { name = "Fira Sans Condensed",  file = "FiraSansCondensed.ttf",  cyr = true },
}
local BUILTIN = {
  { name = "Arial Narrow",  path = [[Fonts\ARIALN.TTF]] },
  { name = "Friz Quadrata", path = [[Fonts\FRIZQT__.TTF]] },
  { name = "Skurri",        path = [[Fonts\SKURRI.TTF]] },
  { name = "Morpheus",      path = [[Fonts\MORPHEUS.TTF]] },
}
local DECLARED = {}
for i = #SHIPPED, 1, -1 do
  local p = MEDIA .. SHIPPED[i].file
  DECLARED[p] = SHIPPED[i].cyr and true or false
  table.insert(BUILTIN, 1, { name = SHIPPED[i].name, path = p })
end
local function LSM() return _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true) or nil end
do
  local m = LSM()
  if m and m.Register then
    for _, f in ipairs(SHIPPED) do m:Register("font", f.name, MEDIA .. f.file) end
  end
end

local cyrFilter

function ns.Fonts:List()
  local names, seen = {}, {}
  for _, f in ipairs(BUILTIN) do names[#names + 1] = f.name; seen[f.name] = true end
  local lsm = LSM()
  if lsm then
    for _, name in ipairs(lsm:List("font")) do
      if not seen[name] then names[#names + 1] = name; seen[name] = true end
    end
  end
  if cyrFilter then names = cyrFilter(names) end
  table.sort(names)
  return names
end

local FALLBACK_FONT = [[Fonts\ARIALN.TTF]]

local function rawPath(name)
  for _, f in ipairs(BUILTIN) do if f.name == name then return f.path end end
  local lsm = LSM()
  if lsm then local pth = lsm:Fetch("font", name, true); if pth then return pth end end
  return FALLBACK_FONT
end

local probe, cyrProbe, pathOK = nil, nil, {}

local CYR_FONTS = { [[Fonts\FRIZQT___CYR.TTF]], [[Fonts\ARIALN.TTF]], [[Fonts\FRIZQT__.TTF]] }
local cyrOK, cyrPick = {}, nil

local function freshString()
  return UIParent:CreateFontString(nil, "OVERLAY")
end

local function applied(fs, path, size)
  if not pcall(fs.SetFont, fs, path, size or 12, "") then return false end
  fs:SetText("Mg")
  return (fs:GetStringWidth() or 0) > 0
end

local function probeFont(path, size)
  probe = freshString()
  if not applied(probe, path, size) then return nil end
  return probe
end

local function hasCyrillic(path)
  if not path then return false end
  local declared = DECLARED[path]
  if declared ~= nil then return declared end
  local known = cyrOK[path]
  if known ~= nil then return known end
  cyrProbe = freshString()
  if not applied(cyrProbe, path, 24) then cyrOK[path] = false; return false end
  cyrProbe:SetText("Ш")
  local wide = cyrProbe:GetStringWidth() or 0
  cyrProbe:SetText("Г")
  local narrow = cyrProbe:GetStringWidth() or 0
  local ok = (wide > 0 and narrow > 0 and math.abs(wide - narrow) > 0.5) and true or false
  cyrOK[path] = ok
  return ok
end

local function cyrillicFont()
  if cyrPick then return cyrPick end
  for _, path in ipairs(CYR_FONTS) do
    if hasCyrillic(path) then cyrPick = path; return path end
  end
  cyrPick = FALLBACK_FONT
  return cyrPick
end

function ns.Fonts:CyrillicPath()
  return cyrillicFont()
end

function ns.Fonts:HasCyrillic(path)
  return path and hasCyrillic(path) or false
end

function ns.Fonts:NeedsCyrillic()
  return (ns.LocalePick and ns.LocalePick() == "ruRU") and true or false
end

cyrFilter = function(names)
  if not ns.Fonts:NeedsCyrillic() then return names end
  local out = {}
  for _, n in ipairs(names) do
    if hasCyrillic(rawPath(n)) then out[#out + 1] = n end
  end
  return (#out > 0) and out or names
end

function ns.Fonts:Path(name)
  local p = rawPath(name)
  local ok = pathOK[p]
  if ok == nil then
    ok = probeFont(p) and true or false
    pathOK[p] = ok
  end
  if not ok then p = FALLBACK_FONT end
  if self:NeedsCyrillic() and not hasCyrillic(p) then return cyrillicFont() end
  return p
end

function ns.Fonts:Has(name)
  if not name then return false end
  for _, n in ipairs(self:List()) do if n == name then return true end end
  return false
end

function ns.Fonts:Usable(name)
  local p = rawPath(name)
  local ok = pathOK[p]
  if ok == nil then
    ok = probeFont(p) and true or false
    pathOK[p] = ok
  end
  return ok
end

function ns.Fonts:Current()
  local name = (ns.Bags and ns.Bags.font) or (WarpeeDB and WarpeeDB.font) or self.DEFAULT
  return self:Path(name)
end
