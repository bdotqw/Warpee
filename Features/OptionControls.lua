local addonName, ns = ...
local Options = ns.Options
local factories = Options.factories
local Theme = ns.Theme

-- The page chrome and the two simplest rows: a section header, a hairline divider, a paragraph and a tick
-- box. They share the same few pieces — the label font, the fade for an off-duty row and the tip under the
-- pointer — so they travel together. The values come from Options.lua, which sets them for this file at
-- load; nothing here runs until a page asks for a row.
local env = ns.OptionControlsEnv
local BASE_FONT = env.baseFont
local CONTENT_W = env.contentW
local track = env.track
local tip = env.tip
local offDuty = env.offDuty
local sectionOpen = env.sectionOpen
local sectionToggle = env.sectionToggle

local function caretGroup(parent, dir)
  return ns.ArrowGlyph(parent, dir, dir == "down" and 10 or 12)
end

function factories.header(parent, spec)
  local row = CreateFrame(spec.key and "Button" or "Frame", nil, parent)
  row:SetHeight(30)
  local line = Theme:Rect(row, "strokeSoft", "ARTWORK")
  ns.PixelLine(line, 1)
  line:SetPoint("BOTTOMLEFT", 0, 0)
  line:SetPoint("BOTTOMRIGHT", 0, 0)
  local fs = track(Theme:Label(row, BASE_FONT, "azure"), 0)
  fs:SetPoint("BOTTOMLEFT", spec.key and 22 or 0, 6)
  fs:SetText(ns.Upper(T(spec.name)))
  if not spec.key then
    local plain = spec.state and track(Theme:Label(row, BASE_FONT - 3, "faint"), -3)
    if plain then plain:SetPoint("BOTTOMRIGHT", 0, 7) end
    row.Refresh = function()
      fs:SetText(ns.Upper(T(spec.name)))
      if plain then plain:SetText((spec.state and spec.state()) or "") end
    end
    row.Refresh()
    return row
  end

  local down = caretGroup(row, "down")
  down:SetPoint("BOTTOMLEFT", 0, 8)
  local right = caretGroup(row, "right")
  right:SetPoint("BOTTOMLEFT", 3, 5)
  local state = track(Theme:Label(row, BASE_FONT - 3, "faint"), -3)
  state:SetPoint("BOTTOMRIGHT", 0, 7)

  row.Refresh = function()
    fs:SetText(ns.Upper(T(spec.name)))
    local on = sectionOpen(spec.key)
    down:SetShown(on)
    right:SetShown(not on)
    state:SetText((spec.state and spec.state()) or "")
  end
  row:SetScript("OnClick", function()
    sectionToggle(spec.key)
    row.Refresh()
    Options:ReflowPages()
  end)
  -- The header title does not recolor on hover: the caret already shows open/closed and the row is
  -- plainly clickable, so lighting the words would be the text-fill highlight the rest of the window drops.
  row.Refresh()
  return row
end

-- A bare hairline between groups; no name, so the search walks past it.
function factories.divider(parent, spec)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(18)
  local line = Theme:Rect(row, "strokeSoft", "ARTWORK")
  ns.PixelLine(line, 1)
  line:SetPoint("BOTTOMLEFT", 0, 0)
  line:SetPoint("BOTTOMRIGHT", 0, 0)
  -- VisibleRows calls Refresh blindly; a missing one is a nil call on page switch.
  row.Refresh = function() end
  return row
end

function factories.description(parent, spec)
  local row = CreateFrame("Frame", nil, parent)
  local fs = track(Theme:Label(row, BASE_FONT - 2, "dim"), -2)
  fs:SetPoint("TOPLEFT")
  fs:SetWidth(CONTENT_W)
  fs:SetJustifyH("LEFT")
  fs:SetSpacing(2)
  fs:SetText(T(spec.name))
  row:SetHeight(fs:GetStringHeight() + 6)
  row.autoHeight = fs
  row.Refresh = function() fs:SetText(T(spec.name)) end
  return row
end

function factories.toggle(parent, spec)
  local row = CreateFrame("Button", nil, parent)
  row:SetHeight(26)

  local box = ns.CreateCheckBox(row, 18)
  ns.SnapPoint(box, "TOPLEFT", row, "TOPLEFT", 1, -4)
  local mark = box.mark

  local fs = track(Theme:Label(row, BASE_FONT, "text"), 0)
  fs:SetPoint("LEFT", box, "RIGHT", 8, 0)
  fs:SetPoint("RIGHT", -2, 0)
  fs:SetJustifyH("LEFT")
  local function paintBox(hover)
    if row.off then
      box:SetKeys("slot", "strokeSoft", "faint")
    elseif row.on then
      box:SetKeys("slot", "bg", hover and "accentInk" or "accent")
    else
      box:SetKeys("slot", hover and "accent" or "stroke", "accent")
    end
  end
  row.Refresh = function()
    if type(spec.name) == "function" then
      fs:SetText(T(spec.name()) or "")
    else
      fs:SetText(T(spec.name))
    end
    local off = (spec.disabled and spec.disabled()) and true or false
    local on = spec.get() and true or false
    mark:SetShown(on)
    fs:SetTextColor(Theme:C(off and "faint" or (on and "text" or "dim")))
    row:SetEnabled(not off)
    row.off, row.on = off, on
    offDuty(row, off)
    paintBox(not off and row:IsMouseOver())
  end
  row:SetScript("OnClick", function()
    if row.off then return end
    spec.set(not spec.get())
    row.Refresh()
    Options:Refresh()
  end)
  row:SetScript("OnEnter", function()
    if row.off then return end
    paintBox(true)
  end)
  row:SetScript("OnLeave", function()
    paintBox(false)
  end)
  row.Refresh()
  tip(row, spec.desc)
  return row
end
