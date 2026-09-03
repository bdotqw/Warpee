local addonName, ns = ...
local Theme = ns.Theme

local SLOT_STYLES = {
  flat  = function() return 0, 0, 0, 0 end,
  plate = function() return Theme:C("panelHi") end,
  tile  = function() return Theme:C("slot") end,
  deep  = function()
    local r, g, b = Theme:C("slot")
    local k = Theme:IsLight() and 0.88 or 0.45
    return r * k, g * k, b * k, 1
  end,
}

local SLOT_TEXTURE = [[Interface\Buttons\UI-Slot-Background]]

function ns.PaintSlotBg(b)
  if not (b and b.bg) then return end
  local style = ns.Bags.slotStyle or "tile"
  b.bg:SetTexCoord(0, 1, 0, 1)
  b.bg:SetVertexColor(1, 1, 1, 1)
  if style ~= "flat" and Theme.Skinned and Theme:Skinned() then
    local atlas = Theme.SlotAtlas and Theme:SlotAtlas()
    if atlas and b.bg.SetAtlas and pcall(b.bg.SetAtlas, b.bg, atlas) then
      if style == "deep" then
        local k = Theme:IsLight() and 0.82 or 0.52
        b.bg:SetVertexColor(k, k, k, 1)
      end
      return
    end
    if pcall(b.bg.SetTexture, b.bg, SLOT_TEXTURE) then
      b.bg:SetTexCoord(0, 0.578125, 0, 0.578125)
      return
    end
  end
  local fn = SLOT_STYLES[style] or SLOT_STYLES.tile
  b.bg:SetColorTexture(fn())
end

local RING_INSET = 0
local RING_WIDTH = 2
local function borderLine(bf, sub, layer)
  local t = bf:CreateTexture(nil, layer or "OVERLAY", nil, sub)
  t:SetColorTexture(1, 1, 1, 1)
  return t
end
local ringWidth
local function ringTextures(b)
  if b.iT then return end
  local bf, I, W = b.ringFrame, RING_INSET, RING_WIDTH
  b.iT = borderLine(bf, 4, "ARTWORK"); b.iT:SetPoint("TOPLEFT",I,-I);   b.iT:SetPoint("TOPRIGHT",-I,-I);   b.iT:SetHeight(ns.PX(bf, W))
  b.iB = borderLine(bf, 4, "ARTWORK"); b.iB:SetPoint("BOTTOMLEFT",I,I); b.iB:SetPoint("BOTTOMRIGHT",-I,I); b.iB:SetHeight(ns.PX(bf, W))
  b.iL = borderLine(bf, 4, "ARTWORK"); b.iL:SetPoint("TOPLEFT",I,-I);   b.iL:SetPoint("BOTTOMLEFT",I,I);   b.iL:SetWidth(ns.PX(bf, W))
  b.iR = borderLine(bf, 4, "ARTWORK"); b.iR:SetPoint("TOPRIGHT",-I,-I); b.iR:SetPoint("BOTTOMRIGHT",-I,I); b.iR:SetWidth(ns.PX(bf, W))
  b.ringW = W
  ns.PixelJob(b.ringFrame, function() b.ringW = nil; ringWidth(b) end)
end
function ringWidth(b)
  local w = ns.Bags.borderWidth or RING_WIDTH
  if b.ringW == w then return end
  b.ringW = w
  local px = ns.PX(b.ringFrame or b, w)
  b.iT:SetHeight(px); b.iB:SetHeight(px)
  b.iL:SetWidth(px);  b.iR:SetWidth(px)
end
local function attachBorder(b)
  local bf = CreateFrame("Frame", nil, b)
  bf:SetAllPoints(b)
  bf:SetFrameLevel(b:GetFrameLevel() + 20)
  b.borderFrame = bf
  local rf = CreateFrame("Frame", nil, b)
  rf:SetAllPoints(b)
  rf:SetFrameLevel(b:GetFrameLevel())
  b.ringFrame = rf
  b.bT = borderLine(rf, 2, "ARTWORK"); b.bT:SetPoint("TOPLEFT");    b.bT:SetPoint("TOPRIGHT");    ns.PixelLine(b.bT, 1)
  b.bB = borderLine(rf, 2, "ARTWORK"); b.bB:SetPoint("BOTTOMLEFT"); b.bB:SetPoint("BOTTOMRIGHT"); ns.PixelLine(b.bB, 1)
  b.bL = borderLine(rf, 2, "ARTWORK"); b.bL:SetPoint("TOPLEFT");    b.bL:SetPoint("BOTTOMLEFT");  ns.PixelLine(b.bL, 1, "w")
  b.bR = borderLine(rf, 2, "ARTWORK"); b.bR:SetPoint("TOPRIGHT");   b.bR:SetPoint("BOTTOMRIGHT"); ns.PixelLine(b.bR, 1, "w")
  b.ilvl = bf:CreateFontString(nil, "OVERLAY")
  b.ilvl:SetDrawLayer("OVERLAY", 6)
  b.ilvl:SetFontObject(ns.Fonts:Object(12, "OUTLINE"))
  b.ilvl:SetPoint("TOPLEFT", 3, -3)
  b.ilvl:SetTextColor(Theme:C("overlay"))
  b.bind = bf:CreateFontString(nil, "OVERLAY")
  b.bind:SetDrawLayer("OVERLAY", 6)
  b.bind:SetFontObject(ns.Fonts:Object(12, "OUTLINE"))
  b.bind:SetPoint("TOPLEFT", 2, -2)
  b.bind:SetTextColor(ns.WARBOUND[1], ns.WARBOUND[2], ns.WARBOUND[3])
  b.outfit = bf:CreateFontString(nil, "OVERLAY")
  b.outfit:SetDrawLayer("OVERLAY", 6)
  b.outfit:SetFontObject(ns.Fonts:Object(11, "OUTLINE"))
  b.outfit:SetPoint("BOTTOMLEFT", 2, 2)
  b.outfit:SetTextColor(Theme:C("overlay"))
end

local function iconOf(b)
  return b.icon or _G[(b:GetName() or "") .. "IconTexture"]
end

local function fitToIcon(t, ic)
  if not (t and ic) then return end
  t:ClearAllPoints()
  t:SetAllPoints(ic)
end

local function questTex(b)
  return b.IconQuestTexture or _G[(b:GetName() or "") .. "IconQuestTexture"]
end

function ns.QuestMarked(b)
  local t = questTex(b)
  return (t and t:IsShown()) and true or false
end

function ns.MarkQuestItem(b, isQuestItem, questID, isActive)
  local t = questTex(b)
  if not t then return end
  if not ns.Bags.questMarks then t:Hide(); return end
  if questID and not isActive then
    t:SetTexture(TEXTURE_ITEM_QUEST_BANG)
    fitToIcon(t, iconOf(b))
    t:Show()
  elseif questID or isQuestItem then
    t:SetTexture(TEXTURE_ITEM_QUEST_BORDER)
    fitToIcon(t, iconOf(b))
    t:Show()
  else
    t:Hide()
  end
end

function ns.SyncQuestMark(b)
  if not b.wpeBagID then return false end
  local was = ns.QuestMarked(b)
  if ns.Bags.questMarks and C_Container.GetContainerItemQuestInfo then
    local qi = C_Container.GetContainerItemQuestInfo(b.wpeBagID, b:GetID())
    ns.MarkQuestItem(b, qi and qi.isQuestItem, qi and qi.questID, qi and qi.isActive)
  else
    ns.MarkQuestItem(b)
  end
  return ns.QuestMarked(b) ~= was
end

function ns.MarkNewItem(b, bagID, slot, quality)
  local nt, bp = b.NewItemTexture, b.BattlepayItemTexture
  if not (nt or bp) then return end
  local isNew = C_NewItems and C_NewItems.IsNewItem and C_NewItems.IsNewItem(bagID, slot)
  if not isNew then
    if nt then nt:Hide() end
    if bp then bp:Hide() end
    return
  end
  local store = C_Container.IsBattlePayItem and C_Container.IsBattlePayItem(bagID, slot)
  if store then
    if nt then nt:Hide() end
    if bp then fitToIcon(bp, iconOf(b)); bp:SetAlpha(1); bp:Show() end
    return
  end
  if bp then bp:Hide() end
  if not (nt and ns.Bags.newItemGlow) then
    if nt then nt:Hide() end
    return
  end
  local atlas = ColorManager and ColorManager.GetAtlasDataForNewItemQuality
                and ColorManager.GetAtlasDataForNewItemQuality(quality)
             or (NEW_ITEM_ATLAS_BY_QUALITY and quality and NEW_ITEM_ATLAS_BY_QUALITY[quality])
  nt:SetAtlas(atlas or "bags-glow-white")
  fitToIcon(nt, iconOf(b))
  nt:SetAlpha(1)
  nt:Show()
end

function ns.SyncNewItem(b)
  if not b.wpeBagID then return end
  local slot = b:GetID()
  local info = C_Container.GetContainerItemInfo(b.wpeBagID, slot)
  ns.MarkNewItem(b, b.wpeBagID, slot, info and info.quality)
end

local function tierAtlas(t)
  local a = t and t.GetAtlas and t:GetAtlas()
  return (a and a:find("Quality%-Tier")) and true or false
end

local function clearOverlays(b)
  if b.IconOverlay then b.IconOverlay:Hide() end
  if b.IconOverlay2 then b.IconOverlay2:Hide() end
  if b.ProfessionQualityOverlay then b.ProfessionQualityOverlay:Hide() end
  if b.bind then b.bind:SetText("") end
  if b.outfit then b.outfit:SetText("") end
  if b.junk then b.junk:Hide() end
  if b.blocked then b.blocked:Hide() end
end
local muted = setmetatable({}, { __mode = "k" })

local function suppress(t)
  if not t or muted[t] then return end
  muted[t] = true
  t:SetAlpha(0)
  t:Hide()
  hooksecurefunc(t, "Show", function(s) s:SetAlpha(0); s:Hide() end)
  hooksecurefunc(t, "SetAlpha", function(s, a) if a and a ~= 0 then s:SetAlpha(0) end end)
  if t.SetShown then
    hooksecurefunc(t, "SetShown", function(s, on) if on then s:SetAlpha(0); s:Hide() end end)
  end
end

local function clearAnim(ag)
  if not ag.GetAnimations then return end
  for _, a in ipairs({ ag:GetAnimations() }) do
    local t = a.GetTarget and a:GetTarget()
    if t and t.SetAlpha then t:SetAlpha(0) end
  end
end

local function muteAnim(ag)
  if not ag or muted[ag] then return end
  muted[ag] = true
  if ag.IsPlaying and ag:IsPlaying() then ag:Stop() end
  hooksecurefunc(ag, "Play", function(s)
    s:Stop()
    pcall(clearAnim, s)
  end)
end

function ns.SetSlotBorder(b, r, g, bl, a)
  a = a or 1
  if b.edgeR == r and b.edgeG == g and b.edgeB == bl and b.edgeA == a then return end
  b.edgeR, b.edgeG, b.edgeB, b.edgeA = r, g, bl, a
  b.bT:SetColorTexture(r, g, bl, a); b.bB:SetColorTexture(r, g, bl, a)
  b.bL:SetColorTexture(r, g, bl, a); b.bR:SetColorTexture(r, g, bl, a)
end

function ns.SetRarityRing(b, r, g, bl, a)
  if not r then
    if b.ringOn == false or not b.iT then b.ringOn = false; return end
    b.ringOn = false
    b.iT:Hide(); b.iB:Hide(); b.iL:Hide(); b.iR:Hide()
    return
  end
  a = a or 1
  ringTextures(b)
  ringWidth(b)
  if b.ringOn and b.ringR == r and b.ringG == g and b.ringB == bl and b.ringA == a then return end
  b.ringOn, b.ringR, b.ringG, b.ringB, b.ringA = true, r, g, bl, a
  b.iT:SetColorTexture(r, g, bl, a); b.iB:SetColorTexture(r, g, bl, a)
  b.iL:SetColorTexture(r, g, bl, a); b.iR:SetColorTexture(r, g, bl, a)
  b.iT:Show(); b.iB:Show(); b.iL:Show(); b.iR:Show()
end

function ns.IsWarbound(bagID, slot, loc)
  if loc and C_Item.DoesItemExist(loc) and C_Item.IsBoundToAccountUntilEquip
     and C_Item.IsBoundToAccountUntilEquip(loc) then
    return true
  end
  if C_TooltipInfo and C_TooltipInfo.GetBagItem then
    return ns.WarboundTooltip(C_TooltipInfo.GetBagItem(bagID, slot))
  end
  return false
end

function ns.SetSlotHighlight(b, on)
  if not on then
    if b.hl then b.hl:Hide() end
    return
  end
  if not b.hl then
    if not b.borderFrame then return end
    b.hl = b.borderFrame:CreateTexture(nil, "ARTWORK")
    b.hl:SetAllPoints(b)
  end
  local a = Theme.colors.accent
  b.hl:SetColorTexture(a[1], a[2], a[3], 0.30); b.hl:Show()
end

local btnCount = 0
function ns.CreateItemButton(parent, bagID, slotIndex)
  btnCount = btnCount + 1
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetID(bagID)
  holder:SetSize(37, 37)
  local b = CreateFrame("ItemButton", "WarpeeItem"..btnCount, holder,
    "ContainerFrameItemButtonTemplate")
  b:SetID(slotIndex)
  b:SetAllPoints(holder)
  b.holder = holder
  b.wpeBagID = bagID
  b.bg = b:CreateTexture(nil, "BACKGROUND", nil, -1)
  b.bg:SetAllPoints(b)
  b.bg:SetColorTexture(Theme:C("slot"))
  local nt = b:GetNormalTexture()
  if nt then nt:SetAlpha(0) end
  b.emptyBackgroundAtlas = nil
  local ic = b.icon or _G[(b:GetName() or "").."IconTexture"]
  if ic then ic:ClearAllPoints(); ic:SetAllPoints(b) end
  attachBorder(b)
  local nm = b:GetName() or ""
  suppress(b.IconBorder);   suppress(_G[nm.."IconBorder"])
  muteAnim(b.flashAnim)
  muteAnim(b.newitemglowAnim)
  local cd = b.Cooldown or _G[nm .. "Cooldown"]
  if cd then
    b.cd = cd
    cd.wpeOwner = b
    cd:SetHideCountdownNumbers(true)
    cd:SetDrawEdge(true)
    cd:Clear()
    b.cdText = b.borderFrame:CreateFontString(nil, "OVERLAY")
    b.cdText:SetDrawLayer("OVERLAY", 7)
    b.cdText:SetFontObject(ns.Fonts:Object(14, "OUTLINE"))
    b.cdText:SetPoint("CENTER")
    b.cdText:SetTextColor(Theme:C("text"))
  end
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  return b
end

local vaultCount = 0
function ns.CreateVaultButton(parent)
  vaultCount = vaultCount + 1
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(37, 37)
  local b = CreateFrame("ItemButton", "WarpeeVault" .. vaultCount, holder)
  b:SetAllPoints(holder)
  b.holder = holder
  b.vault = true
  b.bg = b:CreateTexture(nil, "BACKGROUND", nil, -1)
  b.bg:SetAllPoints(b)
  b.bg:SetColorTexture(Theme:C("slot"))
  local nt = b:GetNormalTexture()
  if nt then nt:SetAlpha(0) end
  local ic = b.icon or _G[(b:GetName() or "") .. "IconTexture"]
  if ic then ic:ClearAllPoints(); ic:SetAllPoints(b) end
  attachBorder(b)
  local nm = b:GetName() or ""
  suppress(b.IconBorder);   suppress(_G[nm .. "IconBorder"])
  b:RegisterForClicks("AnyUp")
  b:SetScript("OnClick", function(s)
    if s.vaultLink then HandleModifiedItemClick(s.vaultLink) end
  end)
  b:SetScript("OnEnter", function(s)
    ns.SetSlotHighlight(s, true)
    if not s.vaultLink then return end
    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
    if s.vaultLink:find("battlepet:", 1, true) and BattlePetToolTip_ShowLink then
      BattlePetToolTip_ShowLink(s.vaultLink)
    else
      GameTooltip:SetHyperlink(s.vaultLink)
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function(s)
    ns.SetSlotHighlight(s, false)
    GameTooltip:Hide()
    if BattlePetTooltip then BattlePetTooltip:Hide() end
  end)
  return b
end
local function cellOf(b)
  return (b.view and b.view.iconSize) or ns.Bags.iconSize or 37
end

local BADGES = {
  { key = "ilvl",   n = "Item level",  p = "447",  c = "BOTTOMRIGHT", x = 0, y = 2, s = 14 },
  { key = "count",  n = "Stack count", p = "20",   c = "BOTTOMRIGHT", x = 0, y = 2, s = 14 },
  { key = "bind",   n = "Binding",     p = "BoE",  c = "TOPLEFT",    x = 2, y = -2, s = 12 },
  { key = "outfit", n = "Gear set",    p = "Myth", c = "BOTTOMLEFT", x = 2, y =  2, s = 11,
    k = 4 },
  { key = "junk",    n = "Junk coin",   tex = true,
    c = "TOPLEFT",  x =  1, y = -1, s = 0.42, m = 8 },
  { key = "blocked", n = "Vendor lock", tex = true,
    c = "TOPRIGHT", x = -1, y = -1, s = 0.60, m = 12 },
}
local BADGE = {}
for _, d in ipairs(BADGES) do BADGE[d.key] = d end
ns.BADGES, ns.BADGE = BADGES, BADGE
ns.BADGE_CORNERS = { TOPLEFT = true, TOPRIGHT = true,
                     BOTTOMLEFT = true, BOTTOMRIGHT = true }

local BADGE_FIELDS = { "c", "x", "y", "s" }
local BADGE_LEGACY = {
  ilvl  = { c = "ilvlAnchor",  x = "ilvlX",  y = "ilvlY",  s = "ilvlSize"  },
  count = { c = "countAnchor", x = "countX", y = "countY", s = "countSize" },
}

function ns.BadgeDefaults()
  local t = {}
  for _, d in ipairs(BADGES) do
    t[d.key] = { c = d.c, x = d.x, y = d.y, s = d.s, k = d.k, on = true }
  end
  return t
end

function ns.BadgeMigrate(db, t)
  for _, d in ipairs(BADGES) do
    local g = t[d.key]
    if type(g) ~= "table" then g = {}; t[d.key] = g end
    local old = BADGE_LEGACY[d.key]
    for _, f in ipairs(BADGE_FIELDS) do
      if g[f] == nil and old then g[f] = db[old[f]] end
      if g[f] == nil then g[f] = d[f] end
    end
    if not ns.BADGE_CORNERS[g.c] then g.c = d.c end
    g.x, g.y = tonumber(g.x) or d.x, tonumber(g.y) or d.y
    g.s = tonumber(g.s) or d.s
    if d.k then g.k = tonumber(g.k) or d.k end
    g.on = g.on ~= false
  end
end

function ns.Badge(key)
  local t = ns.Bags and ns.Bags.badge
  return (t and t[key]) or BADGE[key]
end

local function badgeObj(b, key)
  if key == "count" then return b.Count or _G[(b:GetName() or "") .. "Count"] end
  return b[key]
end

function ns.ApplyBadge(b, key)
  local o = badgeObj(b, key)
  if not o then return end
  local d, g = BADGE[key], ns.Badge(key)
  if d.tex then
    local sz = math.max(d.m or 8, math.floor(cellOf(b) * (g.s or d.s) + 0.5))
    o:SetSize(sz, sz)
  else
    ns.SetOutlined(o, g.s or d.s)
  end
  local ref = iconOf(b) or b
  o:ClearAllPoints()
  o:SetPoint(g.c, ref, g.c, g.x, g.y)
  o:SetAlpha(g.on and 1 or 0)
end

local function decorated(t)
  if not (t and t:IsShown()) then return false end
  return not tierAtlas(t)
end

function ns.ApplyIconZoom(b)
  local ic = b.icon or _G[(b:GetName() or "") .. "IconTexture"]
  if not ic then return end
  local z = ns.Bags.iconZoom or 1
  if decorated(b.IconOverlay) or decorated(b.IconOverlay2) then z = z - 0.1 end
  local sz = cellOf(b)
  if b.zoomFor == z and b.zoomSize == sz then return end
  b.zoomFor, b.zoomSize = z, sz
  ic:ClearAllPoints()
  if z > 1 then
    local t = (1 - 1 / z) / 2
    ic:SetTexCoord(t, 1 - t, t, 1 - t)
    ic:SetAllPoints(b)
  elseif z < 1 then
    local inset = math.max(ns.PX(b, 1), ns.SnapValue(b, (1 - z) * sz / 2))
    ic:SetTexCoord(0, 1, 0, 1)
    ic:SetPoint("TOPLEFT", b, "TOPLEFT", inset, -inset)
    ic:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -inset, inset)
  else
    ic:SetTexCoord(0, 1, 0, 1)
    ic:SetAllPoints(b)
  end
end

function ns.FitOverlays(b)
  local ic = iconOf(b)
  if not ic then return end
  local nm = b:GetName() or ""
  b.IconOverlay = b.IconOverlay or _G[nm .. "IconOverlay"]
  b.IconOverlay2 = b.IconOverlay2 or _G[nm .. "IconOverlay2"]
  fitToIcon(b.IconOverlay or _G[nm .. "IconOverlay"], ic)
  fitToIcon(b.IconOverlay2 or _G[nm .. "IconOverlay2"], ic)
  fitToIcon(questTex(b), ic)
  fitToIcon(b.NewItemTexture or _G[nm .. "NewItemTexture"], ic)
  fitToIcon(b.BattlepayItemTexture or _G[nm .. "BattlepayItemTexture"], ic)
  if b.cd then fitToIcon(b.cd, ic) end
end

function ns.ApplyItemFont(b)
  if b.styleGen == ns.Bags.styleGen then return end
  b.styleGen = ns.Bags.styleGen
  for _, d in ipairs(BADGES) do ns.ApplyBadge(b, d.key) end
end

function ns.SetOutlined(fs, size)
  if not fs then return end
  fs:SetFont(ns.Fonts:Current(), size, "OUTLINE")
end

function ns.FitCount(b, count)
  local c = b.Count or _G[(b:GetName() or "") .. "Count"]
  if not c then return end
  ns.SetOutlined(c, ns.Badge("count").s)
end

function ns.FitIlvl(b, lvl)
  if not b.ilvl then return end
  ns.SetOutlined(b.ilvl, ns.Badge("ilvl").s)
end

local function fmtCooldown(s)
  if s >= 3600 then return math.floor(s / 3600 + 0.5) .. "h"
  elseif s >= 60 then return math.floor(s / 60 + 0.5) .. "m"
  else return tostring(math.floor(s + 0.5)) end
end

local function cdFont(b)
  if not b.cdText then return end
  ns.SetOutlined(b.cdText, ns.Badge("count").s)
end

local function cdOnUpdate(self, elapsed)
  local b = self.wpeOwner
  if not (b and b.cdEnd) then self:SetScript("OnUpdate", nil); return end
  b.cdAcc = (b.cdAcc or 0) + elapsed
  if b.cdAcc < 0.1 then return end
  b.cdAcc = 0
  local remain = b.cdEnd - GetTime()
  if remain <= 0 then
    if b.cdText then b.cdText:SetText("") end
    b.cdEnd = nil
    self:SetScript("OnUpdate", nil)
    return
  end
  cdFont(b)
  if b.cdText then b.cdText:SetText(fmtCooldown(remain)) end
end

function ns.UpdateCooldown(b)
  local cd = b.cd
  if not cd then return end
  local start, duration, enable = C_Container.GetContainerItemCooldown(b.wpeBagID, b:GetID())
  if start and start > 0 and duration and duration > 2 and enable and enable ~= 0 then
    cd:SetCooldown(start, duration)
    b.cdEnd = start + duration
    b.cdAcc = 0.1
    cdFont(b)
    if b.cdText then b.cdText:SetText(fmtCooldown(b.cdEnd - GetTime())) end
    cd:SetScript("OnUpdate", cdOnUpdate)
  else
    cd:Clear()
    b.cdEnd = nil
    if b.cdText then b.cdText:SetText("") end
    cd:SetScript("OnUpdate", nil)
  end
end

local LOCK_ATLAS = { "bags-icon-lock", "Garr_LockedBuilding" }

function ns.BadgeArt(t, key)
  if not t then return end
  if key == "junk" then
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("bags-junkcoin") then
      t:SetAtlas("bags-junkcoin")
    else
      t:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    end
  elseif key == "blocked" then
    if C_Texture and C_Texture.GetAtlasInfo then
      for _, a in ipairs(LOCK_ATLAS) do
        if C_Texture.GetAtlasInfo(a) then t:SetAtlas(a); return end
      end
    end
    t:SetTexture("Interface\\PetBattles\\PetBattle-LockIcon")
  end
end

local BIND_CACHE = {}
local ACCOUNT_BIND

local function accountBind(bt)
  if not ACCOUNT_BIND then
    ACCOUNT_BIND = {}
    local E = Enum and Enum.ItemBind
    if E then
      if E.ToWoWAccount then ACCOUNT_BIND[E.ToWoWAccount] = true end
      if E.ToBnetAccount then ACCOUNT_BIND[E.ToBnetAccount] = true end
    end
  end
  return bt ~= nil and ACCOUNT_BIND[bt] == true
end

local function bindType(link, itemID)
  if not link then return nil end
  local id = itemID or C_Item.GetItemInfoInstant(link)
  if not id then return nil end
  local v = BIND_CACHE[id]
  if v ~= nil then return v end
  local bt = select(14, C_Item.GetItemInfo(link))
  if bt == nil then return nil end
  BIND_CACHE[id] = bt
  return bt
end

function ns.BindLabel(link, itemID, bound, wue)
  if not ns.Badge("bind").on then return nil end
  if wue then return "WuE" end
  local bt = bindType(link, itemID)
  if accountBind(bt) then return "BoA" end
  local E = Enum and Enum.ItemBind
  if not bound and E and E.OnEquip and bt == E.OnEquip then return "BoE" end
  return nil
end

function ns.MarkBind(b, label, quality)
  local fs = b.bind
  if not fs then return end
  if not label then fs:SetText(""); return end
  fs:SetText(label)
  if label == "BoE" and quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
    local c = ITEM_QUALITY_COLORS[quality]
    fs:SetTextColor(c.r, c.g, c.b)
  else
    local W = ns.WARBOUND
    fs:SetTextColor(W[1], W[2], W[3])
  end
end

local CUT, CUT_N = {}, nil

local function utf8cut(s, n)
  local i, out, len = 1, 0, #s
  while i <= len and out < n do
    local c = s:byte(i)
    local step = 1
    if c >= 240 then step = 4 elseif c >= 224 then step = 3 elseif c >= 192 then step = 2 end
    i = i + step
    out = out + 1
  end
  return s:sub(1, i - 1)
end

local function abbrev(name, n)
  if CUT_N ~= n then CUT, CUT_N = {}, n end
  local v = CUT[name]
  if not v then v = utf8cut(name, n); CUT[name] = v end
  return v
end

local Sets = { map = {}, dirty = true }
ns.Sets = Sets

function Sets:Dirty() self.dirty = true end

function Sets:Map()
  if not self.dirty then return self.map end
  self.dirty = false
  local m = self.map
  for k in pairs(m) do m[k] = nil end
  local E = C_EquipmentSet
  if not (E and E.GetEquipmentSetIDs and E.GetItemIDs) then return m end
  for _, id in ipairs(E.GetEquipmentSetIDs()) do
    local name = E.GetEquipmentSetInfo(id)
    local ids = name and E.GetItemIDs(id)
    if ids then
      for _, itemID in pairs(ids) do
        if type(itemID) == "number" and itemID > 1 and not m[itemID] then m[itemID] = name end
      end
    end
  end
  return m
end

function ns.OutfitLabel(itemID)
  local g = ns.Badge("outfit")
  if not (g.on and itemID) then return nil end
  local name = Sets:Map()[itemID]
  if not name then return nil end
  return abbrev(name, g.k or 4)
end

function ns.MarkOutfit(b, label)
  if b.outfit then b.outfit:SetText(label or "") end
end

function ns.MarkJunk(b, quality)
  if not (ns.Badge("junk").on and quality == 0) then
    if b.junk then b.junk:Hide() end
    return
  end
  if not b.junk then
    if not b.borderFrame then return end
    b.junk = b.borderFrame:CreateTexture(nil, "OVERLAY", nil, 5)
    ns.BadgeArt(b.junk, "junk")
  end
  ns.ApplyBadge(b, "junk")
  b.junk:Show()
end

function ns.MarkBlocked(b, itemID)
  local on = (itemID and ns.Vendor and ns.Vendor:Blocked(itemID)) and true or false
  if not (on and ns.Badge("blocked").on) then
    if b.blocked then b.blocked:Hide() end
    return
  end
  if not b.blocked then
    if not b.borderFrame then return end
    b.blocked = b.borderFrame:CreateTexture(nil, "OVERLAY", nil, 6)
    ns.BadgeArt(b.blocked, "blocked")
  end
  ns.ApplyBadge(b, "blocked")
  b.blocked:Show()
end

local function slotLoc(b, bag, slot)
  local loc = b.loc
  if loc and loc.SetBagAndSlot then loc:SetBagAndSlot(bag, slot); return loc end
  loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
  b.loc = loc
  return loc
end

function ns.UpdateItemButton(b)
  local bagID, slot = b.wpeBagID, b:GetID()
  local info = C_Container.GetContainerItemInfo(bagID, slot)
  local link = info and (info.hyperlink or info.iconFileID) or false
  local count = info and info.stackCount or 0
  if b.link == link and b.count == count then return b.itemName end
  b.link, b.count = link, count
  if not info then
    SetItemButtonTexture(b, nil)
    SetItemButtonCount(b, 0)
    SetItemButtonDesaturated(b, false)
    if b.ilvl then b.ilvl:SetText("") end
    clearOverlays(b)
    SetItemButtonQuality(b, nil)
    if b.cd then b.cd:Clear(); b.cdEnd = nil; if b.cdText then b.cdText:SetText("") end; b.cd:SetScript("OnUpdate", nil) end
    ns.MarkQuestItem(b)
    ns.MarkNewItem(b, bagID, slot)
    local nt = b:GetNormalTexture()
    if nt then nt:SetAlpha(0) end
    ns.SetSlotBorder(b, Theme:C("emptyLine"))
    if ns.Bags.reagentTint and (bagID == ns.reagentBag or bagID == ns.reagentBank) then
      local r = Theme.colors.reagent
      ns.SetRarityRing(b, r[1], r[2], r[3], 0.95)
    else
      ns.SetRarityRing(b)
    end
    ns.PaintSlotBg(b)
    b.itemName, b.meta = nil, nil
    return nil, true
  end
  local hl = info and info.hyperlink
  local iItemID, iType, iSub, iEquipLoc, iIcon, iClassID, iSubID
  if hl then
    iItemID, iType, iSub, iEquipLoc, iIcon, iClassID, iSubID = C_Item.GetItemInfoInstant(hl)
  end
  local isGear = iClassID == Enum.ItemClass.Armor or iClassID == Enum.ItemClass.Weapon
  local texture = info and info.iconFileID
  SetItemButtonTexture(b, texture)
  SetItemButtonCount(b, count)
  ns.ApplyItemFont(b)
  ns.FitCount(b, count)
  local gearIlvl
  if b.ilvl then
    local lvl, isKey
    if hl then
      local kl = hl:match("keystone:[^:]*:[^:]*:(%d+)")
      if kl then
        lvl, isKey = tonumber(kl), true
      else
        if iItemID == 180653 then
          lvl, isKey = (C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLevel and C_MythicPlus.GetOwnedKeystoneLevel()), true
        elseif isGear then
          local loc = slotLoc(b, bagID, slot)
          if C_Item.DoesItemExist(loc) then lvl = C_Item.GetCurrentItemLevel(loc) end
          gearIlvl = lvl
        end
      end
    end
    local shown = (lvl and lvl > 1) and ns.Badge("ilvl").on and lvl or nil
    b.ilvl:SetText(shown or "")
    ns.FitIlvl(b, shown)
    local kc
    if isKey and shown then
      local rarity = C_ChallengeMode and C_ChallengeMode.GetKeystoneLevelRarityColor
      if rarity then
        local ok, c = pcall(rarity, shown)
        if ok and type(c) == "table" and c.r then kc = c end
      end
      kc = kc or (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[4])
    end
    local iq = info and info.quality
    if kc then
      b.ilvl:SetTextColor(kc.r, kc.g, kc.b)
    elseif ns.Bags.qualityColorIlvl and iq and ITEM_QUALITY_COLORS[iq] then
      local c = ITEM_QUALITY_COLORS[iq]
      b.ilvl:SetTextColor(c.r, c.g, c.b)
    else
      b.ilvl:SetTextColor(Theme:C("overlay"))
    end
  end
  SetItemButtonQuality(b, info and info.quality, hl, false, info and info.isBound)
  ns.FitOverlays(b)
  ns.ApplyIconZoom(b)
  if ns.Bags.questMarks and C_Container.GetContainerItemQuestInfo then
    local qi = C_Container.GetContainerItemQuestInfo(bagID, slot)
    ns.MarkQuestItem(b, qi and qi.isQuestItem, qi and qi.questID, qi and qi.isActive)
  else
    ns.MarkQuestItem(b)
  end
  ns.MarkNewItem(b, bagID, slot, info and info.quality)
  ns.MarkJunk(b, info and info.quality)
  ns.MarkBlocked(b, info and info.itemID)
  SetItemButtonDesaturated(b, info and info.isLocked)
  local icon = b.icon or _G[(b:GetName() or "").."IconTexture"]
  if icon then icon:SetVertexColor(1, 1, 1, 1) end
  local nt = b:GetNormalTexture()
  if nt then nt:SetAlpha(0) end
  local q = info and info.quality
  ns.SetSlotBorder(b, Theme:C("emptyLine"))
  if ns.QuestMarked(b) then
    ns.SetRarityRing(b)
  elseif ns.Bags.reagentTint and (b.wpeBagID == ns.reagentBag or b.wpeBagID == ns.reagentBank) then
    local r = Theme.colors.reagent
    ns.SetRarityRing(b, r[1], r[2], r[3], 0.95)
  elseif hl and ns.IsItemUnusable(bagID, slot, hl) then
    local R = RED_FONT_COLOR
    ns.SetRarityRing(b, R.r, R.g, R.b, 1)
  elseif ns.Bags.qualityBorder and q and q >= 0 and ITEM_QUALITY_COLORS[q] then
    local c = ITEM_QUALITY_COLORS[q]
    ns.SetRarityRing(b, c.r, c.g, c.b, 1)
  else
    ns.SetRarityRing(b)
  end
  ns.PaintSlotBg(b)
  local nm = hl and hl:match("%[(.-)%]") or nil
  b.itemName = nm
  if nm then
    local loc = slotLoc(b, bagID, slot)
    local wue = ns.Badge("bind").on and C_Item.IsBoundToAccountUntilEquip
                and C_Item.DoesItemExist(loc)
                and C_Item.IsBoundToAccountUntilEquip(loc) or false
    ns.MarkBind(b, ns.BindLabel(hl, iItemID, info.isBound, wue), info.quality)
    ns.MarkOutfit(b, ns.OutfitLabel(iItemID))
    local il = isGear and gearIlvl or nil
    if isGear and not il then
      il = C_Item.DoesItemExist(loc) and C_Item.GetCurrentItemLevel(loc) or nil
      local getIL = C_Item.GetDetailedItemLevelInfo or GetDetailedItemLevelInfo
      if not il and getIL then il = getIL(hl) end
    end
    local m = b.meta or {}
    m.text = (nm .. " " .. (iType or "") .. " " .. (iSub or "")):lower()
    m.q = info.quality
    m.ilvl = il
    m.classID = iClassID
    m.subID = iSubID
    m.id = iItemID
    m.equipLoc = iEquipLoc
    m.bag, m.slot, m.loc, m.isGear = bagID, slot, loc, isGear
    m.bound = info.isBound and true or false
    m.wb = nil
    m.exp = nil
    m.reagent = (bagID == ns.reagentBag) or iClassID == Enum.ItemClass.Tradegoods
                or iClassID == Enum.ItemClass.Reagent
    m.keystone = hl:find("keystone:", 1, true) ~= nil
    b.meta = m
  else
    b.meta = nil
    if b.bind then b.bind:SetText("") end
  end
  ns.UpdateCooldown(b)
  return b.itemName, true
end

function ns.PaintVaultButton(b, d, bagID)
  local link = (d and d.l) or false
  local count = (d and d.c) or 0
  if b.link == link and b.count == count then return b.itemName end
  b.link, b.count = link, count
  b.vaultLink = d and d.l or nil
  local q = d and d.q
  local iconID, classID, gear, subID, itemID, equipLoc, iType, iSub
  if link then
    local iid, ity, isub, iloc, ic, cid, sid = C_Item.GetItemInfoInstant(link)
    iconID, classID, subID, itemID = ic, cid, sid, iid
    iType, iSub, equipLoc = ity, isub, iloc
    gear = (cid == Enum.ItemClass.Armor or cid == Enum.ItemClass.Weapon)
  end
  SetItemButtonTexture(b, iconID)
  SetItemButtonCount(b, count)
  SetItemButtonDesaturated(b, false)
  if link then
    SetItemButtonQuality(b, q, link, false, d.b)
    ns.FitOverlays(b)
    ns.MarkQuestItem(b, classID == Enum.ItemClass.Questitem)
    ns.MarkJunk(b, q)
    ns.MarkBlocked(b, (C_Item.GetItemInfoInstant(link)))
    ns.MarkBind(b, ns.BindLabel(link, itemID, d.b, false), q)
    ns.MarkOutfit(b, nil)
  else
    clearOverlays(b)
    SetItemButtonQuality(b, nil)
    ns.MarkQuestItem(b)
  end
  ns.ApplyIconZoom(b)
  ns.ApplyItemFont(b)
  ns.FitCount(b, count)
  local icon = b.icon or _G[(b:GetName() or "") .. "IconTexture"]
  if icon then icon:SetVertexColor(1, 1, 1, 1) end
  local nt = b:GetNormalTexture()
  if nt then nt:SetAlpha(0) end
  if b.ilvl then
    local lvl = d and d.v
    local shown = (lvl and lvl > 1) and ns.Badge("ilvl").on and lvl or nil
    b.ilvl:SetText(shown or "")
    ns.FitIlvl(b, shown)
    if ns.Bags.qualityColorIlvl and q and ITEM_QUALITY_COLORS[q] then
      local c = ITEM_QUALITY_COLORS[q]
      b.ilvl:SetTextColor(c.r, c.g, c.b)
    else
      b.ilvl:SetTextColor(Theme:C("overlay"))
    end
  end
  ns.SetSlotBorder(b, Theme:C("emptyLine"))
  if ns.QuestMarked(b) then
    ns.SetRarityRing(b)
  elseif ns.Bags.reagentTint and bagID and (bagID == ns.reagentBank or bagID == ns.reagentBag) then
    local r = Theme.colors.reagent
    ns.SetRarityRing(b, r[1], r[2], r[3], 0.95)
  elseif link and ns.IsLinkUnusable(link) then
    local R = RED_FONT_COLOR
    ns.SetRarityRing(b, R.r, R.g, R.b, 1)
  elseif ns.Bags.qualityBorder and q and q >= 0 and ITEM_QUALITY_COLORS[q] then
    local c = ITEM_QUALITY_COLORS[q]
    ns.SetRarityRing(b, c.r, c.g, c.b, 1)
  else
    ns.SetRarityRing(b)
  end
  ns.PaintSlotBg(b)
  if link then
    local name = link:match("%[(.-)%]")
    local m = b.meta or {}
    m.text = ((name or "") .. " " .. (iType or "") .. " " .. (iSub or "")):lower()
    m.q, m.ilvl, m.classID = q, d.v, classID
    m.subID, m.id = subID, itemID
    m.equipLoc, m.isGear = equipLoc, gear and true or false
    m.bag, m.slot, m.loc = nil, nil, nil
    m.link = link
    m.bound = d.b and true or false
    m.wb = nil
    m.exp = nil
    m.reagent = (bagID == ns.reagentBank) or classID == Enum.ItemClass.Tradegoods
                or classID == Enum.ItemClass.Reagent
    m.keystone = link:find("keystone:", 1, true) ~= nil
    b.meta = m
    b.itemName = name
  else
    b.meta, b.itemName = nil, nil
  end
  return b.itemName
end

function ns.ApplySearchToButton(b, filters, blocked)
  if not b then return end
  local miss = (blocked or (filters and not ns.MatchSearch(b.meta, filters))) and true or false
  if b.searchMiss == miss then return end
  b.searchMiss = miss
  b:SetAlpha(miss and 0.20 or 1)
  SetItemButtonDesaturated(b, miss)
end

function ns.UpdateItemLock(b)
  if not (b and b.wpeBagID) then return end
  local info = C_Container.GetContainerItemInfo(b.wpeBagID, b:GetID())
  SetItemButtonDesaturated(b, ((info and info.isLocked) or b.searchMiss) and true or false)
end

function ns.CreateBagButton(parent, bagID, size)
  size = size or 22
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  ns.SnapBox(b, size, size)
  ns.PixelBackdrop(b)
  b:SetBackdropColor(Theme:C("slot"))
  b:SetBackdropBorderColor(Theme:C("stroke"))
  Theme:Track(b, function(s)
    s:SetBackdropColor(Theme:C("slot"))
    s:SetBackdropBorderColor(Theme:C(s.wpeHover and "accent" or "stroke"))
  end)
  b.wpeBagID = bagID
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", 1, -1); icon:SetPoint("BOTTOMRIGHT", -1, 1)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.icon = icon
  local cf = math.max(10, math.floor(size * 0.30))
  local cnt = Theme:Label(b, cf, "text")
  cnt:SetPoint("BOTTOMRIGHT", -1, 1)
  b.count = cnt
  b.cntFontSize = cf
  b:SetScript("OnEnter", function(s)
    s.wpeHover = true
    s:SetBackdropBorderColor(Theme:C("accent"))
    if ns.Bags.HighlightBag then ns.Bags:HighlightBag(bagID) end
    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
    if bagID == 0 then
      GameTooltip:SetText(BACKPACK_TOOLTIP or "Backpack")
    else
      GameTooltip:SetInventoryItem("player", C_Container.ContainerIDToInventoryID(bagID))
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function(s)
    s.wpeHover = nil
    s:SetBackdropBorderColor(Theme:C("stroke"))
    if ns.Bags.ClearBagHighlight then ns.Bags:ClearBagHighlight() end
    GameTooltip:Hide()
  end)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetScript("OnDragStart", function(s)
    if s.wpeBagID ~= 0 then PickupBagFromSlot(C_Container.ContainerIDToInventoryID(s.wpeBagID)) end
  end)
  b:SetScript("OnReceiveDrag", function(s) ns.Bags:PlaceBagFromCursor(s.wpeBagID) end)
  b:SetScript("OnClick", function(s, button)
    if CursorHasItem() then
      ns.Bags:PlaceBagFromCursor(s.wpeBagID)
    elseif button == "LeftButton" and IsModifiedClick("PICKUPITEM") and s.wpeBagID ~= 0 then
      PickupBagFromSlot(C_Container.ContainerIDToInventoryID(s.wpeBagID))
    end
  end)
  return b
end
