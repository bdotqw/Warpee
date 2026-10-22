local addonName, ns = ...
local Options = ns.Options
local factories = Options.factories
local Theme = ns.Theme
local L = ns.L

-- The list of items marked for sale: one row per mark with its icon, its name and the cross that unmarks
-- it, and the list that lays them out. It is the only row on the sell page that is a plain list, so it
-- keeps its own small pool here. The shared values come from Options.lua through ns.OptionControlsEnv.
local env = ns.OptionControlsEnv
local BASE_FONT = env.baseFont
local CONTENT_W = env.contentW
local track = env.track
local dropdownFont = env.dropdownFont

local SL_ROW_H = 22

local function sellRow(row, i)
  local c = row.items[i]
  if c then return c end
  c = CreateFrame("Frame", nil, row)
  c:SetHeight(SL_ROW_H)
  local ic = c:CreateTexture(nil, "ARTWORK")
  ic:SetSize(16, 16)
  ic:SetPoint("LEFT", 1, 0)
  c.icon = ic
  local x = ns.CreateGlyphButton(c, "×", 18)
  x:SetPoint("RIGHT", -1, 0)
  x:SetScript("OnClick", function()
    if c.key and ns.Vendor then ns.Vendor:Unmark(c.key) end
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

function factories.selllist(parent, spec)
  local row = CreateFrame("Frame", nil, parent)
  row.items = {}
  row.dynamic = true
  local empty = track(Theme:Label(row, BASE_FONT - 2, "faint"), -2)
  empty:SetFont(dropdownFont(), BASE_FONT - 2, ns.OutlineFlags())
  empty:SetPoint("TOPLEFT")
  empty:SetWidth(CONTENT_W)
  empty:SetJustifyH("LEFT")
  empty:SetText(L["Alt + LMB on an item in your bags to mark it for sale."])
  ns.LocalText(empty, "Alt + LMB on an item in your bags to mark it for sale.")
  row.empty = empty
  row.Rebuild = function()
    local list = ns.Vendor and ns.Vendor:SellList() or {}
    local y = 0
    row.empty:SetShown(#list == 0)
    if #list == 0 then
      y = math.ceil(row.empty:GetStringHeight()) + 4
    else
      for i, e in ipairs(list) do
        local c = sellRow(row, i)
        c.key = e.key
        c.Text:SetText(e.name or tostring(e.id))
        c.icon:SetTexture(e.icon or ns.PinIcon(e.id))
        -- A locked entry is the one the carousel will not sell; the row says so in red, since the
        -- lock is the state a sale would silently skip.
        if e.locked then
          c.Text:SetTextColor(1, 0.4, 0.4)
        else
          c.Text:SetTextColor(Theme:C("text"))
        end
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", 0, -y)
        c:SetPoint("TOPRIGHT", 0, -y)
        c:Show()
        y = y + SL_ROW_H + 2
      end
    end
    for i = #list + 1, #row.items do row.items[i]:Hide() end
    row:SetHeight(math.max(SL_ROW_H, y))
  end
  row.Refresh = row.Rebuild
  row.Rebuild()
  Options.sellRow = row
  return row
end
