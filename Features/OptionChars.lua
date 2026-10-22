local addonName, ns = ...
local Options = ns.Options
local factories = Options.factories
local Theme = ns.Theme
local Bags = ns.Bags
local L = ns.L

-- The character rows on the profile page: the group heading, the cell that draws one saved character in
-- its class color, the two confirms that drop a character's stored bags and the account-wide gold store,
-- and the grid that lays them out. It all travels together because the cells, the headings and the
-- delete mode share one pool of frames.
-- The shared values come from Options.lua through ns.OptionControlsEnv; the row is asked for while a page
-- is built, after every file has loaded.
local env = ns.OptionControlsEnv
local BASE_FONT = env.baseFont
local CONTENT_W = env.contentW
local track = env.track
local dropdownFont = env.dropdownFont

local CHAR_COLS = 3
local CHAR_CELL_H, CHAR_HEAD_H, CHAR_DEL_H = 24, 22, 26

local function charHead(row, i)
  local h = row.heads[i]
  if h then return h end
  h = CreateFrame("Frame", nil, row)
  h:SetHeight(CHAR_HEAD_H)
  local line = Theme:Rect(h, "strokeSoft", "ARTWORK")
  ns.PixelLine(line, 1)
  line:SetPoint("BOTTOMLEFT", 0, 0)
  line:SetPoint("BOTTOMRIGHT", 0, 0)
  local fs = track(Theme:Label(h, BASE_FONT - 3, "azure"), -3)
  fs:SetPoint("BOTTOMLEFT", 0, 5)
  h.Text = fs
  row.heads[i] = h
  return h
end

local function dropChar(key)
  if not (key and ns.Vault:Delete(key)) then return end
  if ns.Bank and ns.Bank.frame then
    ns.Bank:UpdateCharBtn()
    if ns.Bank.frame:IsShown() then ns.Bank:Repaint() end
  end
  if Bags and Bags.snap and ns.Vault:ViewKey("bags") == ns.Vault:Owner() then
    Bags.snap = nil
    Bags:UpdateCharTag()
    if Bags.frame and Bags.frame:IsShown() then Bags:Layout() end
  end
  if Bags and Bags.BrowseState then Bags:BrowseState() end
  if ns.CharPicker then ns.CharPicker:Close() end
  if ns.Options and ns.Options.ReflowPages then ns.Options:ReflowPages() end
end

-- The gold store is wiped whole: it is one account-wide pool, so there is no per-character row to clear.
-- The current character is stamped straight back in (inside WipeGold), so the list is never left empty and
-- the logged-in character reads as the only remembered purse, which is what a wipe-while-online means.
local function wipeGold()
  if not ns.Vault:WipeGold() then return end
  if Bags and Bags.frame and Bags.frame:IsShown() then Bags:UpdateMeta() end
  if ns.Bank and ns.Bank.frame and ns.Bank.frame:IsShown() then ns.Bank:UpdateFooter() end
  if ns.Options and ns.Options.ReflowPages then ns.Options:ReflowPages() end
end

StaticPopupDialogs["WARPEE_DROP_CHAR"] = {
  text = "Delete saved bags and bank of %s?",
  button1 = _G.DELETE or "Delete",
  button2 = _G.CANCEL or "Cancel",
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  showAlert = true,
  OnAccept = function(_, key) dropChar(key) end,
}

local function dropWarband()
  if not ns.Vault:DropWarband() then return end
  if ns.Bank and ns.Bank.frame and ns.Bank.frame:IsShown() then ns.Bank:Repaint() end
  if Bags and Bags.BrowseState then Bags:BrowseState() end
  if ns.Options and ns.Options.ReflowPages then ns.Options:ReflowPages() end
end

StaticPopupDialogs["WARPEE_DROP_WARBAND"] = {
  text = "Delete the saved Warband bank?",
  button1 = _G.DELETE or "Delete",
  button2 = _G.CANCEL or "Cancel",
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  showAlert = true,
  OnAccept = function() dropWarband() end,
}

StaticPopupDialogs["WARPEE_WIPE_GOLD"] = {
  text = "Forget the remembered gold of every character?",
  button1 = _G.DELETE or "Delete",
  button2 = _G.CANCEL or "Cancel",
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  showAlert = true,
  -- The popup carries Text, not text, so the old self.text write threw on open.
  OnAccept = function() wipeGold() end,
}

-- Reset throws away every rule the player built, so it sits behind a confirm like the saved-data
-- deletes rather than firing on the click. Accept goes back through the editor's own reset hook, the
-- same path the other structural actions take, so the list is rebuilt and then scrolled to its first
-- row: the whole list was just replaced, and it should be read from the top.
StaticPopupDialogs["WARPEE_RESET_CATEGORIES"] = {
  text = "Reset the category list to the shipped one?",
  button1 = _G.ACCEPT or "Accept",
  button2 = _G.CANCEL or "Cancel",
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  showAlert = true,
  OnAccept = function()
    if Options.catReset then Options.catReset() end
  end,
}

local function charCell(row, i)
  local c = row.cells[i]
  if c then return c end
  c = CreateFrame("Button", nil, row)
  c:SetHeight(CHAR_CELL_H)
  local box = ns.CreateCheckBox(c, 16)
  ns.SnapPoint(box, "TOPLEFT", c, "TOPLEFT", 1, -4)
  local mark = box.mark
  local minus = Theme:Rect(box, "gaugeHi", "OVERLAY")
  ns.PixelLine(minus, 2)
  minus:SetPoint("LEFT", box, "LEFT", ns.PixelFloor(box, 3), 0)
  minus:SetPoint("RIGHT", box, "RIGHT", -ns.PixelFloor(box, 3), 0)
  minus:Hide()
  c.box, c.mark, c.minus = box, mark, minus
  local fs = track(Theme:Label(c, BASE_FONT - 2, "text"), -2)
  fs:SetPoint("LEFT", box, "RIGHT", 5, 0)
  fs:SetPoint("RIGHT", -2, 0)
  fs:SetJustifyH("LEFT")
  c.Text = fs

  c:SetScript("OnEnter", function(s)
    if row.delMode then
      s.box:SetKeys(nil, "gaugeHi", nil)
      s.Text:SetTextColor(Theme:C("gaugeHi"))
      return
    end
    if s.warband or s.gold then return end
    if not ns.Vault:Hidden(s.key or "") then
      s.box:SetKeys(nil, "bg", "accentInk")
    else
      s.box:SetKeys(nil, "accent", nil)
    end
  end)
  c:SetScript("OnLeave", function(s)
    s:Paint()
  end)
  c:SetScript("OnClick", function(s)
    if s.gold then
      if not row.delMode then return end
      StaticPopupDialogs["WARPEE_WIPE_GOLD"].text = L["Forget the remembered gold of every character?"]
      StaticPopup_Show("WARPEE_WIPE_GOLD")
      return
    end
    if s.warband then
      if not row.delMode then return end
      StaticPopupDialogs["WARPEE_DROP_WARBAND"].text = L["Delete the saved Warband bank?"]
      StaticPopup_Show("WARPEE_DROP_WARBAND")
      return
    end
    if not s.key then return end
    if row.delMode then
      StaticPopupDialogs["WARPEE_DROP_CHAR"].text = L["Delete saved bags and bank of %s?"]
      StaticPopup_Show("WARPEE_DROP_CHAR", s.Text:GetText() or s.key, nil, s.key)
      return
    end
    ns.Vault:SetHidden(s.key, not ns.Vault:Hidden(s.key))
    s:Paint()
    if s:IsMouseOver() then s:GetScript("OnEnter")(s) end
  end)
  c.Paint = function(s)
    if s.warband or s.gold then
      s.mark:SetShown(not row.delMode)
      s.minus:SetShown(row.delMode and true or false)
      s.box:SetKeys("slot", row.delMode and "gaugeHi" or "strokeSoft",
        row.delMode and "accent" or "dim")
      s.Text:SetTextColor(Theme:C(row.delMode and "text" or "dim"))
      return
    end
    local on = not ns.Vault:Hidden(s.key or "")
    if row.delMode then
      s.mark:Hide()
      s.minus:Show()
      s.box:SetKeys("slot", "gaugeHi", "accent")
      s.Text:SetTextColor(Theme:C(on and "text" or "dim"))
    else
      s.minus:Hide()
      s.mark:SetShown(on)
      s.box:SetKeys("slot", on and "bg" or "stroke", "accent")
      local cc = on and s.wpeClassColor or nil
      if cc then s.Text:SetTextColor(cc.r, cc.g, cc.b)
      else s.Text:SetTextColor(Theme:C(on and "text" or "dim")) end
    end
  end
  row.cells[i] = c
  return c
end


function factories.chars(parent, spec)
  local row = CreateFrame("Frame", nil, parent)
  row.heads, row.cells = {}, {}
  row.dynamic = true

  local del = ns.CreateButton(row, L["Delete mode"], 104, CHAR_DEL_H)
  ns.LocalText(del, "Delete mode")
  local function paintDel(hover)
    local key = row.delMode and "gaugeHi" or (hover and "accent" or "dim")
    ns.SetBg(del, Theme:C(hover and "panelHi" or "panel"))
    ns.SetEdge(del, Theme:C(key))
    del.Text:SetTextColor(Theme:C(key))
  end
  del:SetScript("OnEnter", function() paintDel(true) end)
  del:SetScript("OnLeave", function() paintDel(false) end)
  del:SetScript("OnClick", function()
    row.delMode = (not row.delMode) or nil
    row.Rebuild()
    paintDel(del:IsMouseOver())
  end)
  row.delBtn, row.paintDel = del, paintDel

  row.Rebuild = function()
    local list = (ns.Vault and ns.Vault:Chars(true)) or {}
    local wbSaved = (ns.Vault and ns.Vault:Saved("warband")) and true or false
    local anyGold = (ns.Vault and ns.Vault:HasGold()) and true or false
    if #list == 0 and not wbSaved and not anyGold then row.delMode = nil end
    local path = ns.Fonts:Current()
    local colW = math.floor((CONTENT_W - (CHAR_COLS - 1) * 8) / CHAR_COLS)
    del.Text:SetFont(path, math.max(7, BASE_FONT - 1), ns.OutlineFlags())
    del:SetWidth(math.max(104, math.ceil(del.Text:GetStringWidth()) + 26))
    del:SetShown(#list > 0 or wbSaved or anyGold)
    paintDel(false)
    local y, hi, ci, col, realm = 0, 0, 0, 0, nil
    for _, e in ipairs(list) do
      if e.realm ~= realm then
        realm = e.realm
        if col > 0 then y = y + CHAR_CELL_H; col = 0 end
        if y > 0 then y = y + 6 end
        hi = hi + 1
        local h = charHead(row, hi)
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", 0, -y)
        h:SetPoint("TOPRIGHT", 0, -y)
        h.Text:SetText(ns.Upper(realm or "?"))
        h.Text:SetFont(path, math.max(7, BASE_FONT - 3), ns.OutlineFlags())
        h:Show()
        y = y + CHAR_HEAD_H + 2
      end
      ci = ci + 1
      local c = charCell(row, ci)
      c.key, c.warband, c.gold = e.key, nil, nil
      c:SetWidth(colW)
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", col * (colW + 8), -y)
      local cc = e.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.class]
      c.wpeClassColor = cc
      c.Text:SetText(e.name)
      c.Text:SetFont(path, math.max(7, BASE_FONT - 2), ns.OutlineFlags())
      c:Paint()
      c:Show()
      col = col + 1
      if col >= CHAR_COLS then col = 0; y = y + CHAR_CELL_H end
    end
    if col > 0 then y = y + CHAR_CELL_H end
    local goldSaved = (ns.Vault and ns.Vault:HasGold()) and true or false
    if wbSaved or goldSaved then
      if y > 0 then y = y + 6 end
      hi = hi + 1
      local h = charHead(row, hi)
      h:ClearAllPoints()
      h:SetPoint("TOPLEFT", 0, -y)
      h:SetPoint("TOPRIGHT", 0, -y)
      h.Text:SetText(ns.Upper(L["Account"]))
      h.Text:SetFont(path, math.max(7, BASE_FONT - 3), ns.OutlineFlags())
      h:Show()
      y = y + CHAR_HEAD_H + 2
      local acol = 0
      if wbSaved then
        ci = ci + 1
        local c = charCell(row, ci)
        c.key, c.warband, c.gold = nil, true, nil
        c:SetWidth(colW)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", 0, -y)
        c.wpeClassColor = nil
        c.Text:SetText(L["Warband bank"])
        c.Text:SetFont(path, math.max(7, BASE_FONT - 2), ns.OutlineFlags())
        c:Paint()
        c:Show()
        acol = 1
      end
      if goldSaved then
        ci = ci + 1
        local c = charCell(row, ci)
        c.key, c.warband, c.gold = nil, nil, true
        c:SetWidth(colW)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", acol * (colW + 8), -y)
        c.wpeClassColor = nil
        -- Just the word: one account-wide line that the delete mode clears. No live total beside it, so the
        -- row never has to be rebuilt as the purse changes.
        c.Text:SetText(L["Gold"])
        c.Text:SetFont(path, math.max(7, BASE_FONT - 2), ns.OutlineFlags())
        c:Paint()
        c:Show()
        acol = acol + 1
      end
      y = y + CHAR_CELL_H
    end
    for i = hi + 1, #row.heads do row.heads[i]:Hide() end
    for i = ci + 1, #row.cells do row.cells[i]:Hide() end
    if #list > 0 or wbSaved or goldSaved then
      del:ClearAllPoints()
      del:SetPoint("TOP", row, "TOP", 0, -(y + 8))
      y = y + 8 + CHAR_DEL_H
    end
    row:SetHeight(math.max(CHAR_CELL_H, y))
  end
  row.Refresh = row.Rebuild
  Options.charsRow = row
  return row
end
