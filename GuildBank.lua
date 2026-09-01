local addonName, ns = ...
local Theme = ns.Theme

local Skin = { tabs = {}, panelTabs = {} }
ns.GuildBankSkin = Skin

local COLUMNS, SLOTS, PANEL_TABS = 7, 14, 4

local function ready()
  return Theme.colors and Theme.colors.slot ~= nil
end

local function mute(region)
  if not region then return end
  if region.SetAlpha then region:SetAlpha(0) end
  if region.Hide then region:Hide() end
end

local function muteArt(frame, keepA, keepB)
  if not (frame and frame.GetRegions) then return end
  for _, r in ipairs({ frame:GetRegions() }) do
    if r ~= keepA and r ~= keepB and r.IsObjectType and r:IsObjectType("Texture") then
      mute(r)
    end
  end
end

local function muteStates(b)
  if not (b and b.GetNormalTexture) then return end
  local parts = { b:GetNormalTexture(), b:GetPushedTexture(), b:GetDisabledTexture() }
  for _, t in ipairs(parts) do if t then t:SetAlpha(0) end end
end

local function accentHighlight(b)
  local hl = b.GetHighlightTexture and b:GetHighlightTexture()
  if not hl then return nil end
  hl:SetColorTexture(Theme:C("accent"))
  hl:SetAlpha(0.22)
  hl:SetAllPoints(b)
  return hl
end

local function label(fs, size, key, flags)
  if not (fs and fs.SetFont) then return end
  local k = key or "text"
  fs:SetFont(ns.Fonts:Current(), size or 12, flags or "")
  fs:SetTextColor(Theme:C(k))
  Theme:Track(fs, function(x)
    x:SetFont(ns.Fonts:Current(), size or 12, flags or "")
    x:SetTextColor(Theme:C(k))
  end)
end

local function box(f, bgKey, strokeKey)
  ns.PixelBackdrop(f)
  if not f.SetBackdrop then return nil end
  local bg, st = bgKey or "panel", strokeKey or "stroke"
  f:SetBackdropColor(Theme:C(bg))
  f:SetBackdropBorderColor(Theme:C(st))
  Theme:Track(f, function(s)
    s:SetBackdropColor(Theme:C(s.wpeLit and "panelHi" or bg))
    s:SetBackdropBorderColor(Theme:C(s.wpeLit and "accent" or st))
    if s.wpeHl then
      s.wpeHl:SetColorTexture(Theme:C("accent"))
      s.wpeHl:SetAlpha(0.22)
    end
  end)
  return f
end

local function textOf(b)
  if b.Text and b.Text.SetFont then return b.Text end
  if b.GetFontString then return b:GetFontString() end
  return nil
end

local function steady(b)
  if b.SetPushedTextOffset then b:SetPushedTextOffset(0, 0) end
end

local function skinButton(b, size)
  if not b or b.wpeSkin then return end
  b.wpeSkin = true
  local hl = b.GetHighlightTexture and b:GetHighlightTexture()
  muteArt(b, hl)
  muteStates(b)
  steady(b)
  if hl then
    hl:SetColorTexture(Theme:C("accent"))
    hl:SetAlpha(0.22)
    hl:SetAllPoints(b)
    b.wpeHl = hl
  end
  if not box(b, "panel", "stroke") then return end
  local fs = textOf(b)
  label(fs, size or 12)
  b:HookScript("OnEnter", function(s)
    s:SetBackdropColor(Theme:C("panelHi"))
    s:SetBackdropBorderColor(Theme:C("accent"))
    if fs then fs:SetTextColor(Theme:C("accent")) end
  end)
  b:HookScript("OnLeave", function(s)
    s:SetBackdropColor(Theme:C("panel"))
    s:SetBackdropBorderColor(Theme:C("stroke"))
    if fs then fs:SetTextColor(Theme:C("text")) end
  end)
end

local function paintToggle(b)
  if not b.SetBackdrop then return end
  local hot = b.wpeLit or b.wpeHot or b:IsMouseOver()
  b:SetBackdropColor(Theme:C(hot and "panelHi" or "panel"))
  b:SetBackdropBorderColor(Theme:C(hot and "accent" or "stroke"))
  if b.wpeHl then
    b.wpeHl:SetColorTexture(Theme:C("accent"))
    b.wpeHl:SetAlpha(0.22)
  end
  local fs = textOf(b)
  if fs then fs:SetTextColor(Theme:C(hot and "accent" or "text")) end
end

local function hotOn(s) s.wpeHot = true; paintToggle(s) end
local function hotOff(s) s.wpeHot = nil; paintToggle(s) end

local function slotBg(b)
  if not b.bg then return end
  b.bg:Show()
  ns.PaintSlotBg(b)
end

local function skinSlot(b)
  if not b or b.wpeSkin then return end
  b.wpeSkin = true
  local ic = b.icon or _G[(b:GetName() or "") .. "IconTexture"]
  local hl = b.GetHighlightTexture and b:GetHighlightTexture()
  muteArt(b, ic, hl)
  muteStates(b)
  local so = b.searchOverlay or b.SearchOverlay
  if so then so:SetAlpha(1) end
  if hl then
    hl:SetColorTexture(Theme:C("accent"))
    hl:SetAlpha(0.22)
    hl:SetAllPoints(b)
    b.wpeHl = hl
  end
  if ic then
    ns.SetInside(ic, b, 1)
    ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
  if not box(b, "slot", "emptyLine") then return end
  b:SetBackdropColor(0, 0, 0, 0)
  b.bg = b:CreateTexture(nil, "BORDER", nil, -1)
  ns.SetInside(b.bg, b, 1)
  slotBg(b)
  local ib = b.IconBorder
  if ib then ib:SetAlpha(0) end
  Theme:Track(b, function(s)
    s:SetBackdropColor(0, 0, 0, 0)
    slotBg(s)
    local q = s.wpeQ
    if q then
      s:SetBackdropBorderColor(q[1], q[2], q[3], 1)
    else
      s:SetBackdropBorderColor(Theme:C("emptyLine"))
    end
    if s.wpeHl then
      s.wpeHl:SetColorTexture(Theme:C("accent"))
      s.wpeHl:SetAlpha(0.22)
    end
  end)
  label(b.Count or _G[(b:GetName() or "") .. "Count"], 12, "text", "OUTLINE")
end

local function skinSideTab(tab, index)
  if not tab then return end
  muteArt(tab)
  local b = tab.Button
  if not b or b.wpeSkin then return end
  b.wpeSkin = true
  local ic = b.IconTexture or _G[(b:GetName() or "") .. "IconTexture"]
  local tex = ic and ic.GetTexture and ic:GetTexture()
  local hl = b.GetHighlightTexture and b:GetHighlightTexture()
  muteArt(b, ic, hl)
  muteStates(b)
  if ic then
    if tex then ic:SetTexture(tex) end
    ns.SetInside(ic, b, 1)
    ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ic:SetAlpha(1)
    ic:Show()
  end
  if hl then
    hl:SetColorTexture(Theme:C("accent"))
    hl:SetAlpha(0.22)
    hl:SetAllPoints(b)
    b.wpeHl = hl
  end
  if not box(b, "panel", "stroke") then return end
  b.wpeIndex = index
  Theme:Track(b, paintToggle)
  b:HookScript("OnEnter", hotOn)
  b:HookScript("OnLeave", hotOff)
  b:HookScript("OnClick", function() Skin:Refresh() end)
  Skin.tabs[#Skin.tabs + 1] = b
end

local TAB_PARTS = { "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive",
                    "LeftHighlight", "MiddleHighlight", "RightHighlight",
                    "LeftDisabled", "MiddleDisabled", "RightDisabled",
                    "Glow", "ActiveGlow", "Background", "SelectedTexture" }

local hushed = setmetatable({}, { __mode = "k" })

local function hush(t)
  if not t or hushed[t] then return end
  hushed[t] = true
  t:SetAlpha(0)
  t:Hide()
  hooksecurefunc(t, "Show", function(s) s:SetAlpha(0); s:Hide() end)
  hooksecurefunc(t, "SetAlpha", function(s, a) if a and a ~= 0 then s:SetAlpha(0) end end)
  if t.SetShown then
    hooksecurefunc(t, "SetShown", function(s, on) if on then s:SetAlpha(0); s:Hide() end end)
  end
end

local function stillTab(t)
  if not t.GetAnimationGroups then return end
  for _, ag in ipairs({ t:GetAnimationGroups() }) do
    if hushed[ag] == nil then
      hushed[ag] = true
      if ag.Stop then ag:Stop() end
      hooksecurefunc(ag, "Play", function(s) s:Stop() end)
    end
  end
end

local function lockTab(t)
  local a = t.wpeAnchor
  if a then
    t:ClearAllPoints()
    t:SetPoint(a.point, a.rel or t:GetParent(), a.relPoint or a.point, a.x or 0, a.y or 0)
    if a.h and a.h > 0 then t:SetHeight(a.h) end
  end
  local fs = textOf(t)
  if fs then
    fs:ClearAllPoints()
    fs:SetPoint("CENTER", t, "CENTER", 0, 0)
  end
end

local function skinPanelTab(t, index)
  if not t or t.wpeSkin then return end
  t.wpeSkin = true
  local hl = t.GetHighlightTexture and t:GetHighlightTexture()
  muteArt(t, hl)
  muteStates(t)
  steady(t)
  stillTab(t)
  for _, key in ipairs(TAB_PARTS) do hush(t[key]) end
  local point, rel, relPoint, x, y = t:GetPoint()
  if point then
    t.wpeAnchor = { point = point, rel = rel, relPoint = relPoint,
                    x = x, y = y, h = t:GetHeight() }
  end
  lockTab(t)
  if hl then
    hl:SetColorTexture(Theme:C("accent"))
    hl:SetAlpha(0.22)
    hl:SetAllPoints(t)
    t.wpeHl = hl
  end
  if not box(t, "panel", "stroke") then return end
  label(textOf(t), 12)
  t.wpeIndex = index
  Theme:Track(t, function(s) paintToggle(s); lockTab(s) end)
  t:HookScript("OnEnter", hotOn)
  t:HookScript("OnLeave", hotOff)
  t:HookScript("OnClick", function() Skin:Refresh() end)
  Skin.panelTabs[#Skin.panelTabs + 1] = t
end

local function skinScroll(sb)
  if not sb or sb.wpeSkin then return end
  sb.wpeSkin = true
  muteArt(sb)
  for _, key in ipairs({ "Back", "Forward" }) do
    local step = sb[key]
    if step then
      muteArt(step)
      muteStates(step)
      local g = ns.ArrowGlyph(step, key == "Back" and "up" or "down", 8)
      g:SetPoint("CENTER")
    end
  end
  local track = sb.Track
  if track then
    muteArt(track)
    box(track, "slot", "strokeSoft")
    local thumb = track.Thumb
    if thumb then
      muteArt(thumb)
      box(thumb, "panelHi", "stroke")
    end
  end
end


local SKIN_LIFT = 1.30

local function dressFrame(frame)
  if not Theme:Skinned() then return end
  ns.PixelBackdrop(frame)
  if not frame.SetBackdrop then return end
  local r, g, b = Theme:C("bg")
  frame:SetBackdropColor(math.min(1, r * SKIN_LIFT), math.min(1, g * SKIN_LIFT),
                         math.min(1, b * SKIN_LIFT), 1)
  frame:SetBackdropBorderColor(Theme:C("stroke"))
end

local function gridBack(frame)
  local first = frame.Column1 or _G.GuildBankColumn1
  local last = frame["Column" .. COLUMNS] or _G["GuildBankColumn" .. COLUMNS]
  first = first and first.Button1
  last = last and last["Button" .. SLOTS]
  if not (first and last) then return end
  local g = Skin.gridBg
  if not g then
    g = Theme:Rect(frame, "panel", "BACKGROUND")
    g:SetDrawLayer("BACKGROUND", 1)
    Skin.gridBg = g
  end
  g:ClearAllPoints()
  g:SetPoint("TOPLEFT", first, "TOPLEFT", -3, 3)
  g:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT", 3, -3)
  g:SetAlpha(Theme:GridAlpha())
  g:SetShown(first:IsShown() and last:IsShown())
end

local function placeClose(close)
  local host = close.wpeHost
  if not host then return end
  close:ClearAllPoints()
  ns.SnapPoint(close, "TOPRIGHT", host, "TOPRIGHT", -6, -5)
end

local function skinClose(close, host)
  if not close or close.wpeSkin then return end
  close.wpeSkin = true
  close.wpeHost = host
  muteArt(close)
  muteStates(close)
  local hl = close.GetHighlightTexture and close:GetHighlightTexture()
  if hl then hl:SetAlpha(0) end
  ns.SnapBox(close, 22, 22)
  if not box(close, "panel", "stroke") then return end
  local glyph = Theme:Label(close, 16, "dim")
  glyph:SetPoint("CENTER")
  glyph:SetText("×")
  close.Text = glyph
  Theme:Track(close, function(s) paintToggle(s); placeClose(s) end)
  close:HookScript("OnEnter", hotOn)
  close:HookScript("OnLeave", hotOff)
  paintToggle(close)
  placeClose(close)
end

local function skinSearch(sb)
  if not sb or sb.wpeSkin then return end
  sb.wpeSkin = true
  mute(sb.Left); mute(sb.Middle); mute(sb.Right); mute(sb.searchIcon)
  muteArt(sb)
  if not box(sb, "bg", "stroke") then return end
  sb:SetFont(ns.Fonts:Current(), 13, "")
  sb:SetTextColor(Theme:C("text"))
  sb:SetTextInsets(8, 8, 0, 0)
  label(sb.Instructions, 13, "dim")
  sb:HookScript("OnEditFocusGained", function(s) s:SetBackdropBorderColor(Theme:C("accent")) end)
  sb:HookScript("OnEditFocusLost", function(s) s:SetBackdropBorderColor(Theme:C("stroke")) end)
end

local function skinPopup(pop)
  if not pop or pop.wpeSkin then return end
  pop.wpeSkin = true
  muteArt(pop)
  if pop.NineSlice then pop.NineSlice:SetAlpha(0) end
  if pop.Border then muteArt(pop.Border) end
  Theme:Panel(pop, "bg", "stroke")
  local bb = pop.BorderBox
  skinButton((bb and bb.OkayButton) or pop.OkayButton or _G.GuildBankPopupOkayButton)
  skinButton((bb and bb.CancelButton) or pop.CancelButton or _G.GuildBankPopupCancelButton)
  label((bb and bb.IconSelectorEditBox) or _G.GuildBankPopupEditBox, 13)
  skinClose(pop.CloseButton, pop)
end

local function try(fn, ...)
  if fn then pcall(fn, ...) end
end

function Skin:Apply()
  local frame = _G.GuildBankFrame
  if self.applied or not frame or not ready() then return end
  self.applied = true

  try(muteArt, frame)
  if frame.NineSlice then frame.NineSlice:SetAlpha(0) end
  mute(frame.Emblem)
  if frame.PortraitContainer then frame.PortraitContainer:Hide() end
  Theme:Panel(frame, "bg", "stroke")
  dressFrame(frame)
  if frame.SetToplevel then frame:SetToplevel(true) end
  frame:HookScript("OnMouseDown", function(s) Theme:Raise(s) end)

  try(label, (frame.TitleContainer and frame.TitleContainer.TitleText)
             or _G.GuildBankFrameTitleText, 15)
  try(skinClose, frame.CloseButton, frame)

  try(skinButton, frame.DepositButton or _G.GuildBankFrameDepositButton)
  try(skinButton, frame.WithdrawButton or _G.GuildBankFrameWithdrawButton)
  try(skinButton, _G.GuildBankInfoSaveButton)
  try(skinButton, (frame.BuyInfo and frame.BuyInfo.PurchaseButton)
                  or _G.GuildBankFramePurchaseButton)

  local money = frame.MoneyFrameBG or _G.GuildBankMoneyFrameBG
  if money then try(muteArt, money) end

  local black = frame.BlackBG
  if black and black.IsObjectType and black:IsObjectType("Frame") then
    try(muteArt, black)
    try(box, black, "slot", "strokeSoft")
  else
    mute(black)
  end

  for i = 1, (_G.MAX_GUILDBANK_TABS or 8) do
    try(skinSideTab, _G["GuildBankTab" .. i], i)
  end

  for i = 1, COLUMNS do
    local col = frame["Column" .. i] or _G["GuildBankColumn" .. i]
    if col then
      try(muteArt, col)
      for s = 1, SLOTS do try(skinSlot, col["Button" .. s]) end
    end
  end

  for i = 1, PANEL_TABS do
    try(skinPanelTab, _G["GuildBankFrameTab" .. i], i)
  end

  try(gridBack, frame)

  try(skinSearch, _G.GuildItemSearchBox)
  try(skinScroll, frame.Log and frame.Log.ScrollBar)

  local info = _G.GuildBankInfoScrollFrame
  if info then
    try(muteArt, info)
    try(skinScroll, info.ScrollBar)
  end
  label(_G.GuildBankInfoEditBox, 13)
  skinPopup(_G.GuildBankPopupFrame)
end

local function slotQuality(tab, index)
  if GetGuildBankItemInfo then
    local ok, _, _, _, _, q = pcall(GetGuildBankItemInfo, tab, index)
    if ok and q then return q end
  end
  local link = GetGuildBankItemLink and GetGuildBankItemLink(tab, index)
  if not link then return nil end
  return select(3, C_Item.GetItemInfo(link))
end

function Skin:PaintSlots()
  local frame = _G.GuildBankFrame
  if not frame then return end
  local tab = (GetCurrentGuildBankTab and GetCurrentGuildBankTab()) or 0
  for i = 1, COLUMNS do
    local col = frame["Column" .. i] or _G["GuildBankColumn" .. i]
    if col then
      for s = 1, SLOTS do
        local b = col["Button" .. s]
        if b and b.wpeSkin and b.SetBackdropBorderColor then
          local q = slotQuality(tab, (i - 1) * SLOTS + s)
          local c = (q and q >= 2 and ITEM_QUALITY_COLORS) and ITEM_QUALITY_COLORS[q] or nil
          if c then
            b.wpeQ = { c.r, c.g, c.b }
            b:SetBackdropBorderColor(c.r, c.g, c.b, 1)
          else
            b.wpeQ = nil
            b:SetBackdropBorderColor(Theme:C("emptyLine"))
          end
        end
      end
    end
  end
end

function Skin:Restyle()
  local frame = _G.GuildBankFrame
  if not (self.applied and frame) then return end
  C_Timer.After(0, function() pcall(dressFrame, frame) end)
  for i = 1, COLUMNS do
    local col = frame["Column" .. i] or _G["GuildBankColumn" .. i]
    if col then
      for s = 1, SLOTS do
        local b = col["Button" .. s]
        if b and b.bg then slotBg(b) end
      end
    end
  end
end

function Skin:Refresh()
  if not (self.applied and ready()) then return end
  local frame = _G.GuildBankFrame
  local cur = (GetCurrentGuildBankTab and GetCurrentGuildBankTab()) or 0
  for _, b in ipairs(self.tabs) do
    b.wpeLit = (b.wpeIndex == cur) or nil
    paintToggle(b)
  end
  local sel = frame and frame.selectedTab
  for _, t in ipairs(self.panelTabs) do
    t.wpeLit = (t.wpeIndex == sel) or nil
    lockTab(t)
    paintToggle(t)
  end
  gridBack(frame)
  self:PaintSlots()
end

local themeHook = CreateFrame("Frame")
Theme:Track(themeHook, function() pcall(Skin.Restyle, Skin) end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("GUILDBANKFRAME_OPENED")
ev:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 ~= "Blizzard_GuildBankUI" then return end
  pcall(Skin.Apply, Skin)
  pcall(Skin.Refresh, Skin)
end)

