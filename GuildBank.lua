local addonName, ns = ...
local Theme = ns.Theme

local Skin = { tabs = {}, panelTabs = {}, texts = {} }
ns.GuildBankSkin = Skin

local COLUMNS, SLOTS, PANEL_TABS = 7, 14, 4

-- The window keeps its own arrays of what it built: BankTabs holds the eight side tabs and
-- Columns holds the seven columns, each with its Buttons. Both are what the game's own update
-- walks, and both exist the moment the window does, so they are read first and the globals
-- only as a fallback. This is the game's window: nothing here should hang on a name.
local function tabAt(frame, i)
  local a = frame and frame.BankTabs
  return (a and a[i]) or _G["GuildBankTab" .. i]
end

local function colAt(frame, i)
  local a = frame and frame.Columns
  return (a and a[i]) or (frame and frame["Column" .. i]) or _G["GuildBankColumn" .. i]
end

local function slotAt(col, s)
  local a = col and col.Buttons
  return (a and a[s]) or (col and col["Button" .. s])
end

local function ready()
  return Theme.colors and Theme.colors.slot ~= nil
end

local function try(fn, ...)
  if fn then pcall(fn, ...) end
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
  local n, p, d = b:GetNormalTexture(), b:GetPushedTexture(), b:GetDisabledTexture()
  if n then n:SetAlpha(0) end
  if p then p:SetAlpha(0) end
  if d then d:SetAlpha(0) end
end

-- Every string this skin writes is remembered here, because a font picked in the settings has
-- to reach a frame the game built: the theme walks its own list, and the guild bank skin is
-- outside it. The same record is what the theme repaints, so both roads end in one dress.
local function label(fs, size, key, flags)
  if not (fs and fs.SetFont) then return end
  local rec = fs.wpeLabel
  if not rec then
    rec = {}
    fs.wpeLabel = rec
    Skin.texts[#Skin.texts + 1] = rec
  end
  rec.fs, rec.size, rec.key, rec.flags = fs, size or 12, key or "text", flags or ""
  if not rec.dress then
    rec.dress = function()
      rec.fs:SetFont(ns.Fonts:Current(), rec.size, rec.flags)
      rec.fs:SetTextColor(Theme:C(rec.key))
    end
    Theme:Track(fs, rec.dress)
  end
  rec.dress()
end

local function box(f, bgKey, strokeKey)
  ns.PixelBackdrop(f)
  if not f.SetBackdrop then return nil end
  local bg, st = bgKey or "panel", strokeKey or "stroke"
  ns.SetBg(f, Theme:C(bg))
  ns.SetEdge(f, Theme:C(st))
  Theme:Track(f, function(s)
    ns.SetBg(s, Theme:C(s.wpeLit and "panelHi" or bg))
    ns.SetEdge(s, Theme:C(s.wpeLit and "accent" or st))
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
    ns.SetBg(s, Theme:C("panelHi"))
    ns.SetEdge(s, Theme:C("accent"))
    if fs then fs:SetTextColor(Theme:C("accent")) end
  end)
  b:HookScript("OnLeave", function(s)
    ns.SetBg(s, Theme:C("panel"))
    ns.SetEdge(s, Theme:C("stroke"))
    if fs then fs:SetTextColor(Theme:C("text")) end
  end)
end

local function paintToggle(b)
  if not b.SetBackdrop then return end
  local hot = b.wpeLit or b.wpeHot
  ns.SetBg(b, Theme:C(hot and "panelHi" or "panel"))
  ns.SetEdge(b, Theme:C(hot and "accent" or "stroke"))
  if b.wpeHl then
    b.wpeHl:SetColorTexture(Theme:C("accent"))
    b.wpeHl:SetAlpha(0.22)
  end
  local fs = textOf(b)
  if fs then fs:SetTextColor(Theme:C(hot and "accent" or (b.wpeTextKey or "text"))) end
end

local function hotOn(s) s.wpeHot = true; paintToggle(s) end
local function hotOff(s) s.wpeHot = nil; paintToggle(s) end

-- The game hangs its own tooltip off the side of a tab. Ours opens above it instead, in the
-- addon's own skin, which is where every other cell of the window says what it is for. The
-- wording is the game's: the tab's name, or the line it puts on the buy cell.
local function showTabTip(s)
  if GameTooltip then GameTooltip:Hide() end
  local name = s.tooltip
  if name and name ~= "" then ns.ShowTip(s, { { text = name } }, "top") end
end

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
  ns.SetBg(b, 0, 0, 0, 0)
  b.bg = b:CreateTexture(nil, "BORDER", nil, -1)
  ns.SetInside(b.bg, b, 1)
  slotBg(b)
  local ib = b.IconBorder
  if ib then ib:SetAlpha(0) end
  Theme:Track(b, function(s)
    ns.SetBg(s, 0, 0, 0, 0)
    slotBg(s)
    local q = s.wpeQ
    if q then
      ns.SetEdge(s, q[1], q[2], q[3], 1)
    else
      ns.SetEdge(s, Theme:C("emptyLine"))
    end
    if s.wpeHl then
      s.wpeHl:SetColorTexture(Theme:C("accent"))
      s.wpeHl:SetAlpha(0.22)
    end
  end)
  -- The stack count is the game's own string, and it is dressed with the rest of the badges
  -- when the slots are painted, so that one setting moves it here as it moves it in the bags.
end

-- Dressing a tab is cut into three steps, and each of them is asked for on every refresh with
-- its own latch. This is the one window of the addon that is not ours: the game builds and
-- rebuilds these cells on its own schedule, and a step that was cut short once must not leave
-- the cell bare for the whole session. A step that already landed costs one boolean, and a step
-- that falls over is a step on its own, standing between the player and nothing else.
local function dressTab(tab, b, index)
  if b.wpeSkin then return end
  -- The two things the rest of this file asks about a tab are known before anything is drawn,
  -- so they are written first: a plate that did not come up is still a cell that knows which
  -- tab it is, and the plus and the tip do not wait on the plate.
  b.wpeIndex = index
  local ic = b.IconTexture or _G[(b:GetName() or "") .. "IconTexture"]
  b.wpeIcon = ic
  muteArt(tab)
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
  b.wpeSkin = true
end

local function putPlus(b)
  if b.wpePlus then return end
  -- The cell that buys the next tab wears the same plus the bank's own strip wears. The game
  -- draws that one cell with its NewTab art, which is a texture: it cannot follow the theme or
  -- the addon font, so the icon is faded out and a glyph is drawn in its place, in the same way
  -- and with the same size as the buy cell of the bank window.
  --
  -- The glyph rides a frame of ours, the way the bank window's own cell is built, and not a
  -- string hung on the game's button: it takes no mouse, so the click still lands on the tab
  -- under it, and it sits one level up, where nothing the button draws can cover it.
  local plus = CreateFrame("Frame", nil, b)
  plus:SetAllPoints(b)
  plus:EnableMouse(false)
  plus:Hide()
  local glyph = plus:CreateFontString(nil, "OVERLAY")
  glyph:SetPoint("CENTER")
  glyph:SetText("+")
  -- Written once here and once through the record below: the record is what follows a font
  -- change, and this is what the glyph has even if the record cannot be made.
  glyph:SetFont(ns.Fonts:Current(), 18, "")
  glyph:SetTextColor(Theme:C("dim"))
  label(glyph, 18, "dim")
  plus.Text = glyph
  b.wpePlus = plus
  b.Text = glyph
  b.wpeTextKey = "dim"
  -- The buy mark was read before the glyph existed, so the cell is read again: a plus that
  -- arrives late still arrives on the right cell.
  b.wpeBuy = nil
end

local function hookTab(b)
  if b.wpeHooked then return end
  b.wpeHooked = true
  Theme:Track(b, paintToggle)
  b:HookScript("OnEnter", function(s) hotOn(s); showTabTip(s) end)
  b:HookScript("OnLeave", function(s) hotOff(s); ns.HideTip() end)
  b:HookScript("OnClick", function() Skin:Refresh() end)
  Skin.tabs[#Skin.tabs + 1] = b
end

local function skinSideTab(tab, index)
  if not tab then return end
  local b = tab.Button
  if not b then return end
  try(dressTab, tab, b, index)
  try(putPlus, b)
  try(hookTab, b)
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
  t:HookScript("OnEnter", function(s) hotOn(s); showTabTip(s) end)
  t:HookScript("OnLeave", function(s) hotOff(s); ns.HideTip() end)
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
local GRAIN = [[Interface\FrameGeneral\UI-Background-Rock]]
local GRAIN_ALPHA = 0.10

local function grainTex(frame)
  local t = Skin.grain
  if t ~= nil then return t or nil end
  t = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
  if not pcall(t.SetTexture, t, GRAIN, "REPEAT", "REPEAT") then
    t:Hide()
    Skin.grain = false
    return nil
  end
  t:SetHorizTile(true)
  t:SetVertTile(true)
  t:SetBlendMode("BLEND")
  t:SetAlpha(GRAIN_ALPHA)
  ns.SetInside(t, frame, 1)
  Skin.grain = t
  return t
end

local function dressFrame(frame)
  local grain = grainTex(frame)
  local def = Theme.SkinDef and Theme:SkinDef()
  if not (def and def.grain) then
    if grain then grain:Hide() end
    return
  end
  ns.PixelBackdrop(frame)
  if frame.SetBackdrop then
    local r, g, b = Theme:C("bg")
    ns.SetBg(frame, math.min(1, r * SKIN_LIFT), math.min(1, g * SKIN_LIFT),
                           math.min(1, b * SKIN_LIFT), 1)
    ns.SetEdge(frame, Theme:C("stroke"))
  end
  if grain then
    grain:SetAlpha(GRAIN_ALPHA)
    grain:Show()
  end
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
  close.wpeTextKey = "dim"
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
  sb:HookScript("OnEditFocusGained", function(s) ns.SetEdge(s, Theme:C("accent")) end)
  sb:HookScript("OnEditFocusLost", function(s) ns.SetEdge(s, Theme:C("stroke")) end)
  -- The game's own handler answers this too: it asks the server and dims what comes back
  -- filtered. Ours runs beside it, in the words the bags know.
  sb:HookScript("OnTextChanged", function() Skin:Search() end)
end

local function skinPopup(pop)
  if not pop or pop.wpeSkin then return end
  pop.wpeSkin = true
  -- The template wears two frames, an outer one and a BorderBox inside it. Both are muted, so
  -- the panel below is the only surface: with the inner one left up, Blizzard's metal frame sat
  -- on top of our fill with a margin of the fill showing all the way around it.
  muteArt(pop)
  if pop.NineSlice then pop.NineSlice:SetAlpha(0) end
  if pop.Border then muteArt(pop.Border) end
  local bb = pop.BorderBox
  if bb then
    muteArt(bb)
    if bb.NineSlice then bb.NineSlice:SetAlpha(0) end
  end
  Theme:Panel(pop, "bg", "stroke")
  skinButton((bb and bb.OkayButton) or pop.OkayButton or _G.GuildBankPopupOkayButton)
  skinButton((bb and bb.CancelButton) or pop.CancelButton or _G.GuildBankPopupCancelButton)
  label((bb and bb.IconSelectorEditBox) or _G.GuildBankPopupEditBox, 13)
  skinClose(pop.CloseButton, pop)
end

-- The bank tab settings popup is the same game template as this one, so both are skinned
-- here and the two cannot drift apart.
ns.SkinIconPopup = skinPopup

-- The eight cells are the game's, and every refresh asks for them by name again. A pass that
-- could not reach one the first time, because the window had not built it yet or the game
-- rebuilt it under us, is not a reason to leave that cell bare for the session; a cell that
-- already wears the skin costs one boolean.
function Skin:EnsureTabs()
  local frame = _G.GuildBankFrame
  if not frame then return end
  for i = 1, (_G.MAX_GUILDBANK_TABS or 8) do
    try(skinSideTab, tabAt(frame, i), i)
  end
end

-- The money lines are the game's own frames and the coins are its own buttons, so what can be
-- taken from them is the way the numbers are written: the grouping is a setting of the addon,
-- and the face is ours. The game's own update is the only place that sees every amount it puts
-- there, including the ones it writes back after a withdrawal and the ones it writes on a
-- money event, so that is what is hooked. Only these three frames are touched, and the hook
-- leaves everything that is not one of them alone.
local MONEY_FRAMES = {
  GuildBankMoneyFrame = true,          -- what the guild bank holds, bottom right
  GuildBankWithdrawMoneyFrame = true,  -- what this player may take out, bottom left
  GuildBankFrameTabCostMoneyFrame = true,
}

-- The coin art is what the game made the button wider than the digits in it, and it is read
-- before the face moves so that it stays the coin's own width. The width goes back the way the
-- game sets it, digits plus coin, because the three buttons are chained to each other by their
-- widths and the gold one is two anchors away from the frame's own edge.
local function coinText(btn, value)
  local fs = btn and btn.Text
  if not fs then return end
  local icon = (btn:GetWidth() or 0) - (fs:GetStringWidth() or 0)
  ns.SetOutlined(fs, 12)
  fs:SetText(ns.FormatNumber(value))
  btn:SetWidth((fs:GetStringWidth() or 0) + math.max(0, icon))
end

local function dressMoney(target, amount)
  local frame = (type(target) == "string" and _G[target]) or target
  -- The game calls its own update with a name in some places and with the frame itself in
  -- others, which is why the answer is looked up either way before anything is touched. This
  -- runs on every money update in the whole interface, so the first thing it does is leave.
  if not (frame and frame.GetName and MONEY_FRAMES[frame:GetName()]) then return end
  local money = amount or 0
  coinText(frame.GoldButton, math.floor(money / 10000))
  coinText(frame.SilverButton, math.floor((money % 10000) / 100))
  coinText(frame.CopperButton, money % 100)
end

-- The hook only fires when the game puts a new amount there, so the faces are put back on the
-- amounts already on screen by the same pass that re-dresses the rest of the window.
local function dressMoneys()
  for name in pairs(MONEY_FRAMES) do
    local frame = _G[name]
    if frame then dressMoney(frame, frame.staticMoney) end
  end
end

function Skin:Apply()
  local frame = _G.GuildBankFrame
  if self.applied or not frame or not ready() then return end
  self.applied = true

  try(muteArt, frame)
  if frame.NineSlice then try(frame.NineSlice.SetAlpha, frame.NineSlice, 0) end
  mute(frame.Emblem)
  if frame.PortraitContainer then try(frame.PortraitContainer.Hide, frame.PortraitContainer) end
  frame.wpeGuest = true
  try(Theme.Panel, Theme, frame, "bg", "stroke")
  try(dressFrame, frame)
  if frame.SetToplevel then try(frame.SetToplevel, frame, true) end
  try(frame.HookScript, frame, "OnMouseDown", function(s) Theme:Raise(s) end)

  try(label, (frame.TitleContainer and frame.TitleContainer.TitleText)
             or _G.GuildBankFrameTitleText, 15)
  -- Three lines of the window are written by the game and were never dressed: the tab's own name
  -- over the window, which carries the access the player has to that tab, the line under the
  -- grid that counts what is left of the day's withdrawals, and the words next to the money.
  try(label, frame.TabTitle, 15)
  try(label, frame.LimitLabel, 12)
  try(skinClose, frame.CloseButton, frame)

  local dep = frame.DepositButton or _G.GuildBankFrameDepositButton
  local wdr = frame.WithdrawButton or _G.GuildBankFrameWithdrawButton
  try(skinButton, dep)
  try(skinButton, wdr)
  -- The game puts three pixels between them, and the border of one skinned plate eats into the
  -- border of the other at that distance. They are pulled apart to a gap that fits both.
  if dep and wdr then
    pcall(wdr.ClearAllPoints, wdr)
    pcall(wdr.SetPoint, wdr, "RIGHT", dep, "LEFT", -8, 0)
  end
  try(skinButton, _G.GuildBankInfoSaveButton)
  try(skinButton, (frame.BuyInfo and frame.BuyInfo.PurchaseButton)
                  or _G.GuildBankFramePurchaseButton)

  local money = frame.MoneyFrameBG or _G.GuildBankMoneyFrameBG
  if money then
    try(muteArt, money)
    -- The two words on that plate sit with the money they describe, so they are dressed with it.
    try(label, money.LimitLabel, 12)
    try(label, money.UnlimitedLabel, 12)
  end
  -- A global function, so hooking it is the sanctioned way in and nothing of the game's own is
  -- replaced. It is installed once, with the rest of the skin.
  if type(MoneyFrame_Update) == "function" then
    hooksecurefunc("MoneyFrame_Update", dressMoney)
  end

  local black = frame.BlackBG
  if black and black.IsObjectType and black:IsObjectType("Frame") then
    try(muteArt, black)
    try(box, black, "slot", "strokeSoft")
  else
    mute(black)
  end

  self:EnsureTabs()

  for i = 1, COLUMNS do
    local col = colAt(frame, i)
    if col then
      try(muteArt, col)
      for s = 1, SLOTS do try(skinSlot, slotAt(col, s)) end
    end
  end

  for i = 1, PANEL_TABS do
    try(skinPanelTab, _G["GuildBankFrameTab" .. i], i)
  end


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

-- The game's own guild bank search asks the server and dims whatever comes back filtered; ours
-- runs here and knows the words the bags know, which is the search the player already uses in
-- the other windows. The box is the game's, so the text is read off it, and a cell is dimmed the
-- way a bag cell is: the button goes translucent and its icon desaturates. Nothing is cached
-- from a miss, since an item that is not in the cache yet becomes one a moment later.
local metaCache = {}

local function itemMeta(link)
  if not link then return nil end
  local hit = metaCache[link]
  if hit then return hit end
  local nm, _, q, ilvl = C_Item.GetItemInfo(link)
  if not nm then return nil end
  local id, iType, iSub, iEquipLoc, _, classID, subID = C_Item.GetItemInfoInstant(link)
  local m = {
    text = (nm .. " " .. (iType or "") .. " " .. (iSub or "")):lower(),
    q = q, ilvl = ilvl, classID = classID, subID = subID,
    equipLoc = iEquipLoc, id = id, link = link,
    reagent = classID == Enum.ItemClass.Tradegoods or classID == Enum.ItemClass.Reagent,
    keystone = link:find("keystone:", 1, true) ~= nil,
  }
  metaCache[link] = m
  return m
end

function Skin:Search()
  local frame = _G.GuildBankFrame
  local box = _G.GuildItemSearchBox
  if not (self.applied and frame and box) then return end
  local f = ns.ParseSearch(box:GetText())
  local tab = (GetCurrentGuildBankTab and GetCurrentGuildBankTab()) or 0
  for i = 1, COLUMNS do
    local col = colAt(frame, i)
    if col then
      for s = 1, SLOTS do
        local b = slotAt(col, s)
        if b and b.wpeSkin then
          local miss = false
          if not f.empty then
            local link = GetGuildBankItemLink and GetGuildBankItemLink(tab, (i - 1) * SLOTS + s)
            miss = not ns.MatchSearch(itemMeta(link), f)
          end
          if b.wpeMiss ~= miss then
            b.wpeMiss = miss
            b:SetAlpha(miss and 0.2 or 1)
            if SetItemButtonDesaturated then SetItemButtonDesaturated(b, miss) end
          end
        end
      end
    end
  end
end

-- One read of a cell, off the two calls the game's own tooltip reads. The quality falls back to
-- the item itself for a cell the server has not answered for yet, and the count is the stack the
-- window shows.
local function slotInfo(tab, index)
  local link = GetGuildBankItemLink and GetGuildBankItemLink(tab, index)
  local count, q
  if GetGuildBankItemInfo then
    local ok, _, c, _, _, quality = pcall(GetGuildBankItemInfo, tab, index)
    if ok then count, q = c, quality end
  end
  if not q and link then q = select(3, C_Item.GetItemInfo(link)) end
  return link, count, q
end

-- The slots are the game's own item buttons, and the badges are the addon's: the same strings in
-- the same places, dressed by the same settings, so a piece of gear reads the same here as it
-- does in the bags. What a cell shows is read off the two calls the game's own tooltip reads,
-- and nothing is kept: a tab that has just been switched hands back other items, and a link the
-- client has not cached yet answers nothing and answers properly a moment later.
local function badgeSlots(b)
  if b.wpeBadge then return end
  b.wpeBadge = true
  ns.BadgeFurniture(b)
  local h = b:GetHeight() or 37
  if h > 0 then b.view = b.view or { iconSize = h } end
end

local function paintBadges(b, link, count, q)
  ns.ApplyItemFont(b)
  ns.FitCount(b, count)
  ns.MarkJunk(b, q)
  if not link then
    if b.ilvl then b.ilvl:SetText("") end
    ns.MarkBind(b)
    return
  end
  local m = itemMeta(link)
  -- An item level belongs to a piece of gear and to nothing else. A stack of cloth and a
  -- profession reagent both carry one, and printing it on them says nothing about what they are
  -- worth; the bags read the same rule off the item class and show it only for armor and
  -- weapons. The keystone is the other case the bags know, and it is left out here: its level
  -- comes from the player's own keystone, which is not the one sitting in the guild bank.
  local gear = m and (m.classID == Enum.ItemClass.Armor or m.classID == Enum.ItemClass.Weapon)
  local lvl = gear and m.ilvl or nil
  local shown = (lvl and lvl > 1) and ns.Badge("ilvl").on and lvl or nil
  if b.ilvl then
    ns.FitIlvl(b, shown)
    b.ilvl:SetText(shown or "")
    local c = (shown and ns.Bags.qualityColorIlvl and q) and ITEM_QUALITY_COLORS[q] or nil
    if c then b.ilvl:SetTextColor(c.r, c.g, c.b) else b.ilvl:SetTextColor(Theme:C("overlay")) end
  end
  -- The binds that read off the item itself: account binding, and BoE on a piece that is not
  -- bound. The warbound question is left out on purpose, because it is the one that is answered
  -- by building a tooltip, and a window that holds ninety-eight items at once is not the place
  -- to build one per item. BoE and BoA come from the item id, which is already cached.
  ns.MarkBind(b, ns.BindLabel(link, m and m.id or nil, false), q)
end

-- A badge face is not a string this file wrote, it is one the badges wrote, and the pass that
-- re-dresses the skin on a font change has to reach them too: without this the badges kept the
-- face they were built with until something asked for a slot again, which only happened when
-- the player switched tabs.
local function badgeFace(b)
  for _, d in ipairs(ns.BADGES) do try(ns.ApplyBadge, b, d.key) end
end

function Skin:PaintSlots()
  local frame = _G.GuildBankFrame
  if not frame then return end
  local tab = (GetCurrentGuildBankTab and GetCurrentGuildBankTab()) or 0
  for i = 1, COLUMNS do
    local col = colAt(frame, i)
    if col then
      for s = 1, SLOTS do
        local b = slotAt(col, s)
        if b and b.wpeSkin and b.SetBackdropBorderColor then
          local index = (i - 1) * SLOTS + s
          local link, count, q = slotInfo(tab, index)
          local c = (q and q >= 2 and ITEM_QUALITY_COLORS) and ITEM_QUALITY_COLORS[q] or nil
          -- Slots of a tab just switched to carry different items, so the search has to judge
          -- them again rather than trust what it decided for the tab before.
          b.wpeMiss = nil
          if c then
            b.wpeQ = { c.r, c.g, c.b }
            ns.SetEdge(b, c.r, c.g, c.b, 1)
          else
            b.wpeQ = nil
            ns.SetEdge(b, Theme:C("emptyLine"))
          end
          try(badgeSlots, b)
          try(paintBadges, b, link, count, q)
        end
      end
    end
  end
end

function Skin:Restyle()
  local frame = _G.GuildBankFrame
  if not (self.applied and frame) then return end
  C_Timer.After(0, function() pcall(dressFrame, frame) end)
  for _, rec in ipairs(self.texts) do try(rec.dress) end
  for i = 1, COLUMNS do
    local col = colAt(frame, i)
    if col then
      for s = 1, SLOTS do
        local b = slotAt(col, s)
        if b and b.bg then slotBg(b) end
        if b and b.wpeBadge then badgeFace(b) end
      end
    end
  end
  dressMoneys()
end

local function markBuy(b, numTabs)
  local buy = (b.wpeIndex == numTabs + 1) and true or nil
  if b.wpeBuy == buy then return end
  b.wpeBuy = buy
  -- The game keeps one cell past the last bought tab as the buy cell, and that is the only one
  -- that should wear the plus: every other tab carries an icon of its own, and a tab that has
  -- just been bought has to get its icon back. Whether the cell is up is the game's business
  -- and not ours: a hidden cell hides its glyph along with itself.
  if b.wpePlus then b.wpePlus:SetShown(buy and true or false) end
  if b.wpeIcon then b.wpeIcon:SetAlpha(buy and 0 or 1) end
end

function Skin:Refresh()
  if not ready() then return end
  self:EnsureTabs()
  if not self.applied then return end
  local frame = _G.GuildBankFrame
  local cur = (GetCurrentGuildBankTab and GetCurrentGuildBankTab()) or 0
  local numTabs = (GetNumGuildBankTabs and GetNumGuildBankTabs()) or 0
  for _, b in ipairs(self.tabs) do
    b.wpeLit = (b.wpeIndex == cur) or nil
    markBuy(b, numTabs)
    paintToggle(b)
  end
  local sel = frame and frame.selectedTab
  for _, t in ipairs(self.panelTabs) do
    t.wpeLit = (t.wpeIndex == sel) or nil
    lockTab(t)
    paintToggle(t)
  end
  self:PaintSlots()
  self:Search()
end

-- A cell whose link the client has not cached yet answers nothing, and answers a moment later:
-- the tab's items and the item data itself are two different messages. Without this the badges
-- of such a cell stayed bare until something else painted the slots, which in practice meant
-- switching tabs. The flag keeps a burst of these messages, one per item, down to one pass.
local infoPending = false

local function infoLanded()
  if infoPending then return end
  infoPending = true
  C_Timer.After(0, function()
    infoPending = false
    local frame = _G.GuildBankFrame
    if frame and frame:IsShown() then pcall(Skin.PaintSlots, Skin) end
  end)
end

local themeHook = CreateFrame("Frame")
Theme:Track(themeHook, function() pcall(Skin.Restyle, Skin) end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("GUILDBANKFRAME_OPENED")
ev:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
-- The tabs move on their own schedule: buying one makes the game hand the plus to the next cell
-- and put the old tab's icon back, and that arrives as this event and no other.
ev:RegisterEvent("GUILDBANK_UPDATE_TABS")
-- Item data arrives after the tab it belongs to does, and a badge cannot be read off a link the
-- client does not have yet.
ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 ~= "Blizzard_GuildBankUI" then return end
  if event == "GET_ITEM_INFO_RECEIVED" then
    local frame = _G.GuildBankFrame
    if frame and frame:IsShown() then infoLanded() end
    return
  end
  pcall(Skin.Apply, Skin)
  pcall(Skin.Refresh, Skin)
end)

