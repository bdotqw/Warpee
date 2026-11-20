local addonName, ns = ...
local Options = ns.Options
local factories = Options.factories
local Theme = ns.Theme
local L = ns.L

-- The list of items the cheap window was told to leave alone: one row per item with its picture, its name and
-- the minus that puts it back in the list. Built the way the marked-for-sale list is, because it is the same
-- kind of thing -- a saved set of item ids the player edits by hand -- and it keeps its own small pool for the
-- same reason that one does.
local env = ns.OptionControlsEnv
local offDuty = env.offDuty
local BASE_FONT = env.baseFont
local CONTENT_W = env.contentW
local track = env.track
local dropdownFont = env.dropdownFont

local CL_ROW_H = 22

local function ignoredRow(row, i)
  local c = row.items[i]
  if c then return c end
  c = CreateFrame("Frame", nil, row)
  c:SetHeight(CL_ROW_H)
  local ic = c:CreateTexture(nil, "ARTWORK")
  ic:SetSize(16, 16)
  ic:SetPoint("LEFT", 1, 0)
  c.icon = ic
  -- A minus, as on every other delete in these lists: one straight bar, which reads the same on every row
  -- however the list happens to sit on the pixel grid.
  local x = ns.CreateGlyphButton(c, "-", 18)
  x:SetPoint("RIGHT", -1, 0)
  -- The minus only flips the id: ToggleIgnore repaints this list itself when the editor is open, the way
  -- Vendor's unmark repaints the sell list. Asking for a second refresh here rebuilt these rows twice per click.
  x:SetScript("OnClick", function()
    if not c.itemID then return end
    ns.Cheap:ToggleIgnore(c.itemID)
  end)
  c.del = x
  local fs = track(Theme:Label(c, BASE_FONT - 2, "text"), -2)
  fs:SetFont(dropdownFont(), BASE_FONT - 2, ns.OutlineFlags())
  fs:SetPoint("LEFT", ic, "RIGHT", 6, 0)
  fs:SetPoint("RIGHT", x, "LEFT", -6, 0)
  fs:SetJustifyH("LEFT")
  c.Text = fs
  row.items[i] = c
  return c
end

function factories.cheaplist(parent, spec)
  local row = CreateFrame("Frame", nil, parent)
  row.items = {}
  row.dynamic = true
  local empty = track(Theme:Label(row, BASE_FONT - 2, "faint"), -2)
  empty:SetFont(dropdownFont(), BASE_FONT - 2, ns.OutlineFlags())
  empty:SetPoint("TOPLEFT")
  empty:SetWidth(CONTENT_W)
  empty:SetJustifyH("LEFT")
  ns.LocalText(empty, "Nothing is ignored: click the - on an item's icon in the list to leave it out.")
  row.empty = empty
  row.Rebuild = function()
    local list = (ns.Cheap and ns.Cheap.IgnoredList and ns.Cheap:IgnoredList()) or {}
    -- The window switched off greys the whole page behind its master row, this list included: the rows stay
    -- where they are and the minus stops taking a click, the same face a rule row wears when gated.
    local off = (spec.disabled and spec.disabled()) and true or nil
    local y = 0
    row.empty:SetShown(#list == 0)
    if #list == 0 then
      y = math.ceil(row.empty:GetStringHeight()) + 4
    else
      for i, e in ipairs(list) do
        local c = ignoredRow(row, i)
        c.itemID = e.itemID
        c.Text:SetText(e.name or tostring(e.itemID))
        c.icon:SetTexture(e.icon)
        offDuty(c, off)
        c.del:EnableMouse(not off)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", 0, -y)
        c:SetPoint("TOPRIGHT", 0, -y)
        c:Show()
        y = y + CL_ROW_H + 2
      end
    end
    for i = #list + 1, #row.items do row.items[i]:Hide() end
    row:SetHeight(math.max(CL_ROW_H, y))
  end
  row.Refresh = row.Rebuild
  row.Rebuild()
  Options.cheapRow = row
  return row
end
