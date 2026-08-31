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
  -- Borrows the game's own frame art instead of a flat plate: the panel border
  -- is Blizzard's tooltip edge, the slots are the bag atlas, and emptyLine is
  -- transparent because that atlas draws its own rim.
  blizzard = { label = "Blizzard", skin = "blizzard",
    bg = { 0.114, 0.110, 0.106, 0.95 }, panel = { 0.169, 0.165, 0.157, 1 },
    panelHi = { 0.216, 0.208, 0.196, 1 }, slot = { 0.129, 0.125, 0.118, 1 },
    stroke = { 0.325, 0.290, 0.235, 1 }, strokeSoft = { 0.235, 0.212, 0.176, 1 },
    accent = { 1.000, 0.820, 0.000, 1 }, accentInk = { 1.000, 0.914, 0.510, 1 },
    text = { 0.965, 0.949, 0.906, 1 }, dim = { 0.741, 0.718, 0.663, 1 },
    faint = { 0.545, 0.522, 0.475, 1 },
    emptyLine = { 0.078, 0.075, 0.071, 0.90 },
    azure = { 0.478, 0.729, 0.906, 1 }, reagent = { 0.353, 0.804, 0.616, 1 } },
}
Theme.THEME_ORDER = { "midnight", "blizzard", "nightbloom", "void", "nord", "blood",
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
  for k, v in pairs(t) do
    if k ~= "label" and k ~= "skin" then c[k] = v end
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

-- pixel grid ----------------------------------------------------------------
-- One interface unit is not one screen pixel: the virtual screen is always
-- 768 units tall, so a unit covers physH/768 * effectiveScale pixels. On 1440p
-- with the default UI scale that is 1.33 px, which makes hairlines land between
-- pixels: some render one pixel wide, some two, some vanish. Every border and
-- every slot offset therefore goes through these helpers.
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

-- Size in units that renders as exactly n whole screen pixels (never below 1).
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
  return math.floor((tonumber(v) or 0) / unit + 0.5) * unit
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

-- Jobs re-run whenever the scale or the resolution changes.
local pixelJobs = setmetatable({}, { __mode = "k" })
function ns.PixelJob(obj, fn)
  pixelJobs[obj] = fn
  fn(obj)
  return obj
end

function ns.PixelLine(t, n, axis)
  return ns.PixelJob(t, function(x)
    local v = ns.PX(x:GetParent(), n or 1)
    if axis == "w" then x:SetWidth(v) else x:SetHeight(v) end
  end)
end

-- SetBackdrop wipes the colors, so remember them and put them back. A caller
-- with its own painter (the themed window frames) sets its colors inside it.
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
    if x.wpeBg then x.wpeSetBg(x, x.wpeBg[1], x.wpeBg[2], x.wpeBg[3], x.wpeBg[4]) end
    if x.wpeEdge then x.wpeSetEdge(x, x.wpeEdge[1], x.wpeEdge[2], x.wpeEdge[3], x.wpeEdge[4]) end
  end)
end

function ns.SnapFrame(frame)
  local p, rel, rp, x, y = frame:GetPoint()
  if not p then return end
  frame:ClearAllPoints()
  frame:SetPoint(p, rel or UIParent, rp or p, ns.SnapValue(frame, x or 0), ns.SnapValue(frame, y or 0))
  return p, rp, ns.SnapValue(frame, x or 0), ns.SnapValue(frame, y or 0)
end

function ns.RefreshPixels()
  refreshPhys()
  -- One bad job must not take the rest of the pass down with it.
  for obj, fn in pairs(pixelJobs) do pcall(fn, obj) end
  -- Relayout touches secure item buttons, so leave it alone in combat: the next
  -- bag update lays the grid out again anyway.
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

-- Game art the Blizzard skin borrows. Nothing is shipped with the addon: these
-- are the client's own files, and a missing one falls back to the flat plate.
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

-- The real thing: a Blizzard panel frame parked behind the window's content, so
-- the grey nine-slice border, the title strip and the dark tile are the game's
-- own art. Its portrait and close button are hidden — Warpee draws those.
local function buildArt(frame)
  if frame.wpeArt ~= nil then return frame.wpeArt end
  local ok, art = pcall(CreateFrame, "Frame", nil, frame, ART_TEMPLATE)
  if not ok or not art then
    ok, art = pcall(CreateFrame, "Frame", nil, frame, ART_FALLBACK)
  end
  if not ok or not art then frame.wpeArt = false; return false end
  art:SetAllPoints(frame)
  art:EnableMouse(false)
  art:SetFrameLevel(frame:GetFrameLevel())
  -- Whatever ornament the template ships with, Warpee draws its own: the border,
  -- the strip and the tile are all we keep.
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
    if art then art:Show() end
    return art
  end
  if frame.wpeArt then frame.wpeArt:Hide() end
  return false
end

function Theme:WindowArt(frame)
  ART_FRAMES[frame] = true
  local fn = tracked[frame]
  if fn then fn(frame) else self:RefreshArt(frame) end
  return frame
end

function Theme:Panel(frame, bgKey, strokeKey)
  local bg, st = bgKey or "bg", strokeKey or "stroke"
  local function paint(x)
    if Theme:Skinned() then
      local art = ART_FRAMES[x] and Theme:RefreshArt(x)
      if art then
        -- Keep the template's own tile when it has one; fill the inside
        -- ourselves when it does not, or the window would be see-through.
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
  { name = "Expressway",           file = "Expressway.ttf" },
  { name = "Manrope",              file = "Manrope.ttf" },
  { name = "Archivo",              file = "Archivo.ttf" },
  { name = "Fira Sans Condensed",  file = "FiraSansCondensed.ttf" },
}
local BUILTIN = {
  { name = "Arial Narrow",  path = [[Fonts\ARIALN.TTF]] },
  { name = "Friz Quadrata", path = [[Fonts\FRIZQT__.TTF]] },
  { name = "Skurri",        path = [[Fonts\SKURRI.TTF]] },
  { name = "Morpheus",      path = [[Fonts\MORPHEUS.TTF]] },
}
for i = #SHIPPED, 1, -1 do
  table.insert(BUILTIN, 1, { name = SHIPPED[i].name, path = MEDIA .. SHIPPED[i].file })
end
local function LSM() return _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true) or nil end
do
  local m = LSM()
  if m and m.Register then
    for _, f in ipairs(SHIPPED) do m:Register("font", f.name, MEDIA .. f.file) end
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

-- The font every label starts with: whatever the player picked, Expressway
-- otherwise. Call sites that re-apply fonts later still override this.
function ns.Fonts:Current()
  local name = (ns.Bags and ns.Bags.font) or (WarpeeDB and WarpeeDB.font) or self.DEFAULT
  return self:Path(name)
end
