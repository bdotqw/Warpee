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
}
Theme.THEME_ORDER = { "midnight", "nightbloom", "void", "nord", "blood",
                      "obsidian", "forest", "ember" }

function Theme:IsLight()
  local c = self.colors.bg
  return (c and (c[1] + c[2] + c[3]) > 1.5) and true or false
end

Theme.colors = {}
function Theme:Apply(name)
  local t = self.THEMES[name] or self.THEMES.midnight
  local c = {}
  for k, v in pairs(SHARED) do c[k] = v end
  for k, v in pairs(t) do if k ~= "label" then c[k] = v end end
  c.brass = c.accent
  c.gaugeMid = c.accent
  self.colors = c
  self.active = self.THEMES[name] and name or "midnight"
end
Theme:Apply("midnight")

local WHITE = [[Interface\Buttons\WHITE8x8]]
Theme.WHITE = WHITE

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
  for obj, fn in pairs(tracked) do fn(obj) end
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

Theme.WINDOW_STRATA = "HIGH"
function Theme:Window(frame, escName)
  frame:SetFrameStrata(self.WINDOW_STRATA)
  frame:SetToplevel(true)
  if escName then tinsert(UISpecialFrames, escName) end
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
  fs:SetFont([[Fonts\ARIALN.TTF]], size or 12, flags or "")
  local key = colorKey or "text"
  fs:SetTextColor(self:C(key))
  track(fs, function(x) x:SetTextColor(Theme:C(key)) end)
  return fs
end

function Theme:Title(parent, size, colorKey)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont([[Fonts\FRIZQT__.TTF]], size or 15, "")
  local key = colorKey or "text"
  fs:SetTextColor(self:C(key))
  track(fs, function(x) x:SetTextColor(Theme:C(key)) end)
  return fs
end

function Theme:Panel(frame, bgKey, strokeKey)
  if not frame.SetBackdrop then Mixin(frame, BackdropTemplateMixin) end
  frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  local bg, st = bgKey or "bg", strokeKey or "stroke"
  frame:SetBackdropColor(self:C(bg))
  frame:SetBackdropBorderColor(self:C(st))
  track(frame, function(x) x:SetBackdropColor(Theme:C(bg)); x:SetBackdropBorderColor(Theme:C(st)) end)
  return frame
end

ns.Fonts = {}
ns.Fonts.DEFAULT = "Expressway"
local BUILTIN = {
  { name = "Expressway",    path = [[Interface\AddOns\Warpee\Media\Expressway.ttf]] },
  { name = "Arial Narrow",  path = [[Fonts\ARIALN.TTF]] },
  { name = "Friz Quadrata", path = [[Fonts\FRIZQT__.TTF]] },
  { name = "Skurri",        path = [[Fonts\SKURRI.TTF]] },
  { name = "Morpheus",      path = [[Fonts\MORPHEUS.TTF]] },
}
local function LSM() return _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true) or nil end
do
  local m = LSM()
  if m and m.Register then
    m:Register("font", "Expressway", [[Interface\AddOns\Warpee\Media\Expressway.ttf]])
  end
end

function ns.Fonts:List()
  local names, seen = {}, {}
  for _, f in ipairs(BUILTIN) do names[#names + 1] = f.name; seen[f.name] = true end
  local lsm = LSM()
  if lsm then
    for _, name in ipairs(lsm:List("font")) do
      if not seen[name] then names[#names + 1] = name; seen[name] = true end
    end
  end
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

local probe, pathOK = nil, {}
function ns.Fonts:Path(name)
  local p = rawPath(name)
  if p == FALLBACK_FONT then return p end
  local ok = pathOK[p]
  if ok == nil then
    probe = probe or UIParent:CreateFontString(nil, "OVERLAY")
    ok = pcall(probe.SetFont, probe, p, 12, "") and true or false
    pathOK[p] = ok
  end
  return ok and p or FALLBACK_FONT
end

function ns.Fonts:Has(name)
  if not name then return false end
  for _, n in ipairs(self:List()) do if n == name then return true end end
  return false
end

function ns.Fonts:Usable(name)
  return self:Path(name) == rawPath(name)
end
