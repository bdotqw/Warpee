local addonName, ns = ...
local Theme = ns.Theme

ns.CLICKS_SLOT = { "LeftButtonUp", "RightButtonUp" }
ns.CLICKS_USE = { "RightButtonUp" }

function ns.ItemTargeting()
  local f, g = SpellCanTargetItem, SpellCanTargetItemID
  return ((f and f()) or (g and g())) and true or false
end

function ns.ItemStub(link)
  if type(link) ~= "string" then return nil end
  return link:match("|H(item:[^|]+)|h") or link:match("^(item:[^|]+)")
end

function ns.ItemStubID(pin)
  if type(pin) == "number" then return pin end
  if type(pin) ~= "string" then return nil end
  return tonumber(pin:match("item:(%d+)"))
end

-- Two copies of one item share an itemID, so a cell that keys on the id alone binds to
-- the wrong ring, the unenchanted one or the lower track. The durable part of the item
-- string is the id, the enchant, the gems, the suffix and the bonus ids; the level, the
-- spec and the unique field drift on their own and are left out.
function ns.ItemKey(pin)
  if type(pin) == "number" then return tostring(pin) end
  local s = ns.ItemStub(pin)
  if not s then return nil end
  local f = {}
  for v in (s .. ":"):gmatch("([^:]*):") do f[#f + 1] = v end
  local bon = {}
  for i = 1, (tonumber(f[14]) or 0) do bon[i] = f[14 + i] or "" end
  table.sort(bon)
  return table.concat({ f[2] or "", f[3] or "", f[4] or "", f[5] or "", f[6] or "",
                        f[7] or "", f[8] or "", table.concat(bon, ",") }, ":")
end

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
  b.bind:SetTextColor(Theme:C("azure"))
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
  if b.wpeNoNew then
    if nt then nt:Hide() end
    if bp then bp:Hide() end
    return
  end
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
  b.wpeLocked = nil
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

function ns.IsWarbound(bagID, slot, loc, bound)
  if not bound and loc and C_Item.DoesItemExist(loc) and C_Item.IsBoundToAccountUntilEquip
     and C_Item.IsBoundToAccountUntilEquip(loc) then
    return true
  end
  if C_TooltipInfo and C_TooltipInfo.GetBagItem then
    return ns.WarboundTooltip(C_TooltipInfo.GetBagItem(bagID, slot))
  end
  return false
end

-- Empty cells of the recent rows look exactly like the grid, and the row label alone
-- was not enough to tell them apart. Only the empty ones carry the mark: an accent
-- line along the top edge of the ghost. A cell that holds an item shows nothing but
-- the item, its rarity border keeps its own color and nothing draws over it.
function ns.RecMark(b)
  if b.wpeRecMark then return end
  local t = b:CreateTexture(nil, "ARTWORK", nil, 5)
  t:SetColorTexture(Theme:C("accent"))
  Theme:Track(t, function(x) x:SetColorTexture(Theme:C("accent")) end)
  t:SetPoint("TOPLEFT")
  t:SetPoint("TOPRIGHT")
  ns.PixelLine(t, 1)
  b.wpeRecMark = t
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

-- The right click that uses an item runs in the game's own secure handler on
-- ContainerFrameItemButtonTemplate. That handler reads state off the button and
-- calls a protected function at the end, so one tainted read anywhere on its path
-- turns every later use into ADDON_ACTION_FORBIDDEN until the ui is reloaded, for
-- every container, not just the slot that was clicked. Never do any of this to a
-- button made from that template:
--   create it while InCombatLockdown() is true. Warm a pool out of combat instead.
--   SetScript any handler on it, or on its Cooldown child. HookScript only.
--   write a field the game's own item button owns: bagID, slotID, count, icon,
--     IconOverlay, IconOverlay2, SplitStack, or a mixin method. Use wpe* names.
--     emptyBackgroundAtlas is the one sanctioned exception: it is the template's own
--     knob for the empty-slot watermark, only insecure paint code reads it, and there
--     is no other way to switch that watermark off.
--   call SetBagID. The holder's SetID carries the bag id, GetBagID falls back to it.
-- Safe in and out of combat: SetID on the button and on the holder, RegisterForClicks,
-- RegisterForDrag, hooksecurefunc on child regions and animations, new wpe* fields.
-- Frames the game owns are the same story one level up, and the bank tab block in Bank.lua
-- holds those rules: no SetScript on them either, and never reparent one whose own code
-- finds its way about with GetParent.
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
    cd:SetHideCountdownNumbers(true)
    cd:SetDrawEdge(true)
    cd:Clear()
    b.cdText = b.borderFrame:CreateFontString(nil, "OVERLAY")
    b.cdText:SetDrawLayer("OVERLAY", 7)
    b.cdText:SetFontObject(ns.Fonts:Object(14, "OUTLINE"))
    b.cdText:SetPoint("CENTER")
    b.cdText:SetTextColor(Theme:C("text"))
  end
  b:RegisterForClicks(unpack(ns.CLICKS_SLOT))
  b.wpeClicks = ns.CLICKS_SLOT
  b.wpeNoSell = false
  b.wpeLockable = true
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
  { key = "ilvl",   n = "Item level",  p = "447",  c = "BOTTOMRIGHT", x = 1, y = 5, s = 14,
    a = "right",
    t = "Item level on gear, and a keystone's level." },
  { key = "count",  n = "Stack count", p = "1000", c = "BOTTOMRIGHT", x = 1, y = 5, s = 14,
    a = "right",
    t = "How many items the stack holds." },
  { key = "bind",   n = "Binding",     p = "BoE",  c = "TOPLEFT",    x = 2, y = -2, s = 12,
    a = "left",
    t = "BoE while unbound, WuE for warbound until equipped, BoA for account bound." },
  { key = "outfit", n = "Gear set",    p = "Myth", c = "BOTTOMLEFT", x = 10, y = -4, s = 10,
    k = 4, a = "left",
    t = "The equipment set the item belongs to, cut to a few letters." },
  { key = "junk",    n = "Junk coin",   tex = true,
    c = "TOPLEFT",  x =  1, y = -1, s = 0.42, m = 8,
    t = "A coin on gray junk items." },
  { key = "blocked", n = "Vendor lock", tex = true,
    c = "TOPRIGHT", x = -1, y = -1, s = 0.60, m = 12,
    t = "A padlock on the items you locked." },
}
local BADGE = {}
for _, d in ipairs(BADGES) do BADGE[d.key] = d end
ns.BADGES, ns.BADGE = BADGES, BADGE
ns.BADGE_CORNERS = { TOPLEFT = true, TOPRIGHT = true,
                     BOTTOMLEFT = true, BOTTOMRIGHT = true }
ns.BADGE_ALIGNS = { left = true, center = true, right = true }

local ALIGN_POINT = {
  TOP    = { left = "TOPLEFT",    center = "TOP",    right = "TOPRIGHT" },
  BOTTOM = { left = "BOTTOMLEFT", center = "BOTTOM", right = "BOTTOMRIGHT" },
}

function ns.BadgePoint(g)
  local c = g.c or "TOPLEFT"
  local row = ALIGN_POINT[c:find("TOP") and "TOP" or "BOTTOM"]
  return row[g.a or ""] or c
end

local BADGE_FIELDS = { "c", "x", "y", "s" }
local BADGE_LEGACY = {
  ilvl  = { c = "ilvlAnchor",  x = "ilvlX",  y = "ilvlY",  s = "ilvlSize"  },
  count = { c = "countAnchor", x = "countX", y = "countY", s = "countSize" },
}

function ns.BadgeDefaults()
  local t = {}
  for _, d in ipairs(BADGES) do
    t[d.key] = { c = d.c, x = d.x, y = d.y, s = d.s, k = d.k, a = d.a, on = true }
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
    if d.a then
      if g.a == nil then
        g.a = (g.c):find("LEFT") and "left" or "right"
      elseif not ns.BADGE_ALIGNS[g.a] then
        g.a = d.a
      end
    end
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

function ns.BadgeSample(key)
  local d = BADGE[key]
  if not (d and d.p) then return nil end
  if d.k then
    local k = ns.Badge(key).k or d.k
    return utf8cut(ns.L["Mythical"], math.max(2, k))
  end
  return d.p
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
  o:ClearAllPoints()
  o:SetPoint(ns.BadgePoint(g), b, g.c, g.x, g.y)
  o:SetAlpha(g.on and 1 or 0)
end

local function decorated(t)
  if not (t and t:IsShown()) then return false end
  return not tierAtlas(t)
end

-- The zoom unit was re-scaled once: one now draws the icon 8% over each side, which is
-- what the old 1.19 drew, and a decoration zooms exactly like everything else.
local ZOOM_UNIT = 1.19

function ns.ApplyIconZoom(b)
  local ic = b.icon or _G[(b:GetName() or "") .. "IconTexture"]
  if not ic then return end
  local z = (ns.Bags.iconZoom or 1) * ZOOM_UNIT
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

-- SetFont re-resolves the face and re-lays out the string every call, and the badges ask
-- for it far more often than they change: the cooldown digits alone would do it ten times
-- a second per slot. The last font that landed is remembered, so an unchanged one costs a
-- string compare. A new font path or size makes a new key on its own, so nothing has to be
-- told when the font changes.
function ns.SetOutlined(fs, size)
  if not fs then return end
  local path = ns.Fonts:Current()
  local key = path .. ":" .. tostring(size)
  if fs.wpeFontKey == key then return end
  fs.wpeFontKey = key
  fs:SetFont(path, size, "OUTLINE")
end

function ns.FitCount(b, count)
  local c = b.Count or _G[(b:GetName() or "") .. "Count"]
  if not c then return end
  ns.SetOutlined(c, ns.Badge("count").s)
  if not ns.Badge("count").on then c:SetText("") end
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

local function cdSay(b, text)
  local fs = b.cdText
  if not fs or b.wpeCdText == text then return end
  b.wpeCdText = text
  fs:SetText(text)
end

-- One ticker for every slot, because a script on the game's Cooldown frame would
-- put addon code on an object the secure click path also touches.
local ticking = setmetatable({}, { __mode = "k" })
local ticker = CreateFrame("Frame")
ticker:Hide()
ticker:SetScript("OnUpdate", function(self, elapsed)
  self.acc = (self.acc or 0) + elapsed
  if self.acc < 0.1 then return end
  self.acc = 0
  local live = false
  for b in pairs(ticking) do
    local left = (b.cdEnd or 0) - GetTime()
    if left > 0 then
      -- A cell whose window is closed keeps its place in the list, since the swirl runs off
      -- the time it was given and the digits are read again the moment it comes back, but
      -- nobody is looking at it, so it is not worth a font and a string every tick.
      if b:IsVisible() then
        cdFont(b)
        cdSay(b, fmtCooldown(left))
      end
      live = true
    else
      ticking[b] = nil
      b.cdEnd = nil
      cdSay(b, "")
    end
  end
  if not live then self:Hide() end
end)

local function tick(b, on)
  if not on then ticking[b] = nil; return end
  ticking[b] = true
  ticker:Show()
end

-- Using one item puts every item that shares its cooldown category on cooldown too, so a
-- single potion brings one of these calls for each of them, and the row keeps calling on
-- every SPELL_UPDATE_COOLDOWN after that. Restarting a swirl that is already running the
-- same countdown costs the same as starting it, so an unchanged pair is left alone.
-- Every cooldown gets the swirl, the global one included: that sweep is the only thing that
-- says the press landed. What the short ones do not get is a digit: a counting number is
-- one SetText every second for as long as it runs, and that shows up as a frame spike on
-- its own. Under ten seconds the swirl alone says everything, so those stay out of the
-- ticker entirely.
local DIGITS_ABOVE = 10

function ns.UpdateCooldown(b)
  local cd = b.cd
  if not cd then return end
  local start, duration, enable = C_Container.GetContainerItemCooldown(b.wpeBagID, b:GetID())
  if start and start > 0 and duration and duration > 0 and enable and enable ~= 0 then
    if b.wpeCdStart ~= start or b.wpeCdDur ~= duration then
      b.wpeCdStart, b.wpeCdDur = start, duration
      cd:SetCooldown(start, duration)
    end
    if duration > DIGITS_ABOVE then
      b.cdEnd = start + duration
      if b:IsVisible() then
        cdFont(b)
        cdSay(b, fmtCooldown(b.cdEnd - GetTime()))
      end
      tick(b, true)
    else
      b.cdEnd = nil
      cdSay(b, "")
      tick(b, false)
    end
  elseif b.cdEnd or b.wpeCdStart then
    cd:Clear()
    b.cdEnd, b.wpeCdStart, b.wpeCdDur = nil, nil, nil
    cdSay(b, "")
    tick(b, false)
  end
end

function ns.StopCooldown(b)
  if not b.cd then return end
  b.cd:Clear()
  b.cdEnd, b.wpeCdStart, b.wpeCdDur = nil, nil, nil
  cdSay(b, "")
  tick(b, false)
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
  if wue and not bound then return "WuE" end
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
  ns.SetOutlined(fs, ns.Badge("bind").s)
  fs:SetText(label)
  if label == "BoE" and quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
    local c = ITEM_QUALITY_COLORS[quality]
    fs:SetTextColor(c.r, c.g, c.b)
  else
    fs:SetTextColor(Theme:C("azure"))
  end
end

local CUT, CUT_N = {}, nil

local function abbrev(name, n)
  if CUT_N ~= n then CUT, CUT_N = {}, n end
  local v = CUT[name]
  if not v then v = utf8cut(name, n); CUT[name] = v end
  return v
end

local function setLoc(packed)
  if type(packed) ~= "number" or packed <= 1 or not ItemLocation then return nil end
  local player, bank, bags, void, slot, bag
  if EquipmentManager_GetLocationData then
    local d = EquipmentManager_GetLocationData(packed)
    if not d then return nil end
    player, bank, bags, void = d.isPlayer, d.isBank, d.isBags, d.isVoidStorage
    slot, bag = d.slot, d.bag
  elseif EquipmentManager_UnpackLocation then
    player, bank, bags, void, slot, bag = EquipmentManager_UnpackLocation(packed)
  else
    return nil
  end
  if void or not slot then return nil end
  if bags and bag then return ItemLocation:CreateFromBagAndSlot(bag, slot) end
  if bank then
    local base = BankButtonIDToInvSlotID and BankButtonIDToInvSlotID(0)
    if not base then return nil end
    return ItemLocation:CreateFromBagAndSlot(-1, slot - base)
  end
  if player then return ItemLocation:CreateFromEquipmentSlot(slot) end
  return nil
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
  local G = C_Item and C_Item.GetItemGUID
  if not (E and G and E.GetEquipmentSetIDs and E.GetItemLocations) then return m end
  for _, id in ipairs(E.GetEquipmentSetIDs()) do
    local name = E.GetEquipmentSetInfo(id)
    local locs = name and E.GetItemLocations(id)
    if locs then
      for _, packed in pairs(locs) do
        local loc = setLoc(packed)
        if loc and C_Item.DoesItemExist(loc) then
          local ok, guid = pcall(G, loc)
          if ok and guid and not m[guid] then m[guid] = name end
        end
      end
    end
  end
  return m
end

function ns.OutfitLabel(loc, itemID)
  local g = ns.Badge("outfit")
  if not (g.on and loc and itemID and ns.GearItem(itemID)) then return nil end
  local m = Sets:Map()
  if not next(m) then return nil end
  local G = C_Item and C_Item.GetItemGUID
  if not G then return nil end
  local ok, guid = pcall(G, loc)
  local name = (ok and guid) and m[guid] or nil
  if not name then return nil end
  return abbrev(name, g.k or 4)
end

function ns.MarkOutfit(b, label)
  if not b.outfit then return end
  if label then ns.SetOutlined(b.outfit, ns.Badge("outfit").s) end
  b.outfit:SetText(label or "")
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

local function lockClicks(b, locked)
  if not ns.IsPlayerBag(b.wpeBagID) then return end
  local V = ns.Vendor
  local block = (locked and V and V:IsOpen()) and true or false
  if b.wpeNoSell == block or InCombatLockdown() then return end
  b.wpeNoSell = block
  local list = b.wpeClicks or ns.CLICKS_SLOT
  if not block then b:RegisterForClicks(unpack(list)); return end
  local keep, n = {}, 0
  for _, c in ipairs(list) do
    if c:find("Left", 1, true) then n = n + 1; keep[n] = c end
  end
  b:RegisterForClicks(unpack(keep, 1, n))
end

function ns.LockClicks(b)
  if b then lockClicks(b, b.wpeLocked) end
end

function ns.MarkBlocked(b, itemID)
  local on = (itemID and ns.Vendor and ns.Vendor:Blocked(itemID)) and true or false
  b.wpeLocked = on or nil
  lockClicks(b, on)
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

local KEYSTONE_LINK = "item:180653"

local function keystoneMark(link)
  if type(link) ~= "string" or not link:find(KEYSTONE_LINK, 1, true) then return nil end
  local get = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLevel
  return get and get() or nil
end

function ns.ClearItemPaint()
  local B = ns.Bags
  if B and B.pool then for _, b in ipairs(B.pool) do b.link = nil end end
  local F = ns.Fav
  if F and F.slots then for _, b in pairs(F.slots) do b.link = nil end end
  local R = ns.Recent
  if R and R.slots then for _, b in pairs(R.slots) do b.link = nil end end
  local P = ns.Pocket
  if P and P.slots then for _, b in pairs(P.slots) do b.link = nil end end
  if P and P.recSlots then for _, b in pairs(P.recSlots) do b.link = nil end end
end

local gearMemo = {}
local GEAR_CLASS = {}
do
  local C = Enum and Enum.ItemClass
  for _, k in ipairs({ "Armor", "Weapon", "Profession" }) do
    if C and C[k] then GEAR_CLASS[C[k]] = true end
  end
end

function ns.GearItem(id)
  id = tonumber(id)
  if not id then return false end
  local v = gearMemo[id]
  if v == nil then
    local cls = select(6, C_Item.GetItemInfoInstant(id))
    if cls == nil then return false end
    v = GEAR_CLASS[cls] and true or false
    gearMemo[id] = v
  end
  return v
end

local function bagTotal(info, count)
  local get = C_Item.GetItemCount or GetItemCount
  local id = info and info.itemID
  if not (get and id) then return count end
  local all = get(id) or count
  if all <= count then return count end
  if count > 1 then return all end
  local max = (C_Item.GetItemMaxStackSizeByID and C_Item.GetItemMaxStackSizeByID(id))
              or select(8, C_Item.GetItemInfo(id))
  if (tonumber(max) or 1) <= 1 then return count end
  return all
end

function ns.UpdateItemButton(b)
  local bagID, slot = b.wpeBagID, b:GetID()
  local info = C_Container.GetContainerItemInfo(bagID, slot)
  local link = info and (info.hyperlink or info.iconFileID) or false
  local count = info and info.stackCount or 0
  if b.wpeForce or b.wpeTotal then
    local one = info and ns.GearItem(info.itemID)
    if b.wpeForce and not one then
      count = b.wpeForce
    elseif b.wpeTotal and not one then
      count = bagTotal(info, count)
    end
  end
  local mark = keystoneMark(link)
  if b.link == link and b.wpeCount == count and b.wpeMark == mark then return b.itemName end
  b.link, b.wpeCount, b.wpeMark = link, count, mark
  if not info then
    SetItemButtonTexture(b, nil)
    SetItemButtonCount(b, 0)
    SetItemButtonDesaturated(b, false)
    if b.ilvl then b.ilvl:SetText("") end
    clearOverlays(b)
    SetItemButtonQuality(b, nil)
    if b.cd then ns.StopCooldown(b) end
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
  elseif ns.Bags.reagentTint and not b.wpeNoReagent
         and (b.wpeBagID == ns.reagentBag or b.wpeBagID == ns.reagentBank) then
    local r = Theme.colors.reagent
    ns.SetRarityRing(b, r[1], r[2], r[3], 0.95)
  elseif hl and ns.IsItemUnusable(bagID, slot, hl) then
    local R = RED_FONT_COLOR
    ns.SetRarityRing(b, R.r, R.g, R.b, 1)
  elseif ns.Bags.qualityBorder and q and q >= 0 and ITEM_QUALITY_COLORS[q]
         and not decorated(b.IconOverlay) and not decorated(b.IconOverlay2) then
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
    local wue = ns.Badge("bind").on and not info.isBound
                and iEquipLoc and iEquipLoc ~= ""
                and C_Item.IsBoundToAccountUntilEquip
                and C_Item.DoesItemExist(loc)
                and C_Item.IsBoundToAccountUntilEquip(loc) or false
    ns.MarkBind(b, ns.BindLabel(hl, iItemID, info.isBound, wue), info.quality)
    ns.MarkOutfit(b, ns.OutfitLabel(loc, iItemID))
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
  if b.link == link and b.wpeCount == count then return b.itemName end
  b.link, b.wpeCount = link, count
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
    ns.MarkBind(b, ns.BindLabel(link, itemID, d.b, d.w), q)
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
  elseif ns.Bags.qualityBorder and q and q >= 0 and ITEM_QUALITY_COLORS[q]
         and not decorated(b.IconOverlay) and not decorated(b.IconOverlay2) then
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
  -- Desaturation reaches the icon alone, so the quality ring kept its hue on a dimmed
  -- cell and stayed the one colored thing on it. A color texture greys out under
  -- SetDesaturated the same way, and the flag survives a SetColorTexture repaint.
  if b.iT then
    b.iT:SetDesaturated(miss); b.iB:SetDesaturated(miss)
    b.iL:SetDesaturated(miss); b.iR:SetDesaturated(miss)
  end
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

-- Pinned cells. The favorites row in the bag window and the pocket window both draw them,
-- and neither file owns what a pinned cell knows or shows: that is all here, once. The two
-- lists stay apart, each row keeps its own saved list and its own lookup tables, and a pin
-- in one row never touches the other. What is shared is the behaviour, and it is shared on
-- purpose: the pocket once learned exact item keys, ghost edges, the item level and the craft
-- tier while the favorites row sat on bare item ids and kept binding itself to the wrong
-- copy of a ring. Anything new about a pinned cell, another badge, another edge colour,
-- another state, goes into these functions and both rows have it the same day. Never add it
-- to one of the two files. Nothing here asks the bank anything: a pinned cell answers "with
-- you or not" and nothing else. A row that draws pinned cells has to hear four things for
-- them to stay right: bag updates, equipment changes, gear set changes and ITEM_CHANGED.
function ns.PinArg(pin)
  if type(pin) == "number" then return pin end
  return ns.ItemStub(pin)
end

-- An equippable that does not stack is kept as its own item string, so the cell finds that
-- copy and not the twin with different bonus ids. Everything else is kept as a plain id.
function ns.PinFor(id, link)
  local stub = ns.ItemStub(link)
  if not (id and stub) then return id end
  local loc = select(4, C_Item.GetItemInfoInstant(id))
  local max = C_Item.GetItemMaxStackSizeByID and C_Item.GetItemMaxStackSizeByID(id)
  if loc and loc ~= "" and (tonumber(max) or 1) <= 1 then return stub end
  return id
end

function ns.PinIcon(id)
  if C_Item and C_Item.GetItemIconByID then
    local ok, tex = pcall(C_Item.GetItemIconByID, id)
    if ok and tex then return tex end
  end
  return (GetItemIcon and GetItemIcon(id)) or 134400
end

-- Two keys have the same stem when they differ in bonus ids alone. Bonus ids are where an
-- upgrade lands, so a same stem candidate is the same item changed; a different stem means
-- something the owner chose by hand is different, the enchant, a gem or the suffix, and that
-- is a different copy that must never be adopted.
local function pinStem(k)
  return (type(k) == "string" and k:match("^(.*):")) or nil
end

-- One pass over the bags per row, filling that row's own tables: every item id, so a
-- stackable pin finds any copy; the exact key of the copies this row actually pins, so a
-- gear pin finds its own; and what is worn, with the item level and gear set of each piece.
function ns.PinScan(list, n, t)
  local function tab(k)
    t[k] = t[k] or {}
    wipe(t[k])
    return t[k]
  end
  local idBag, idSlot = tab("idBag"), tab("idSlot")
  local keyBag, keySlot = tab("keyBag"), tab("keySlot")
  local wornKey, wornIlvl, wornSet = tab("wornKey"), tab("wornIlvl"), tab("wornSet")
  local want, byKey, gear = {}, false, false
  for i = 1, (n or 0) do
    local pin = list and list[i]
    local id = ns.ItemStubID(pin)
    if id and type(pin) == "string" then want[id] = true; byKey = true end
    if id and ns.GearItem(id) then gear = true end
  end
  local bagKeys, wornKeys, stubFor = {}, {}, {}
  local function note(where, id, k)
    local a = where[id]
    if not a then a = {}; where[id] = a end
    a[#a + 1] = k
  end
  local function sweep(bag)
    for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
      local id = C_Container.GetContainerItemID(bag, slot)
      if id then
        if not idBag[id] then idBag[id], idSlot[id] = bag, slot end
        if want[id] then
          local info = C_Container.GetContainerItemInfo(bag, slot)
          local k = info and ns.ItemKey(info.hyperlink)
          if k then
            if not keyBag[k] then keyBag[k], keySlot[k] = bag, slot end
            if not stubFor[k] then stubFor[k] = ns.ItemStub(info.hyperlink) end
            note(bagKeys, id, k)
          end
        end
      end
    end
  end
  for _, bag in ipairs(ns.playerBags) do sweep(bag) end
  if ns.reagentBag then sweep(ns.reagentBag) end
  if not (byKey or gear) then return end
  local get = C_Item and C_Item.GetItemLink
  if get and ItemLocation then
    for slot = 1, 19 do
      local loc = ItemLocation:CreateFromEquipmentSlot(slot)
      if loc and C_Item.DoesItemExist(loc) then
        local link = get(loc)
        local lvl = C_Item.GetCurrentItemLevel and C_Item.GetCurrentItemLevel(loc)
        local id = C_Item.GetItemID and C_Item.GetItemID(loc)
        local set = id and ns.OutfitLabel(loc, id)
        local k = link and ns.ItemKey(link)
        if k then
          wornKey[k] = true
          if lvl then wornIlvl[k] = lvl end
          if set then wornSet[k] = set end
          if not stubFor[k] then stubFor[k] = ns.ItemStub(link) end
          if id then note(wornKeys, id, k) end
        end
        if id then
          wornKey[tostring(id)] = true
          if lvl then wornIlvl[tostring(id)] = lvl end
          if set then wornSet[tostring(id)] = set end
        end
      end
    end
  end
  if not byKey then return end
  -- Second chance for a pin whose exact copy is nowhere: an upgrade, a gem or an enchant
  -- rewrites the bonus ids, and ITEM_CHANGED is not proven to arrive for every one of them.
  -- So a stale pin looks at what copies of that item exist and adopts one only when there is
  -- no choice to make: a single worn copy first, since a pin on gear is nearly always the
  -- piece being worn, otherwise a single copy in the bags. Two copies and it stays a ghost
  -- rather than guess, which is the whole reason the exact key exists. The candidate also has
  -- to share the stem, so a pinned copy resting in the bank cannot be replaced by the plain
  -- twin lying in the bags: that twin differs by its enchant, not by an upgrade.
  for i = 1, (n or 0) do
    local pin = list and list[i]
    if type(pin) == "string" then
      local k = ns.ItemKey(pin)
      if k and not keyBag[k] and not wornKey[k] then
        local id = ns.ItemStubID(pin)
        local w, b = wornKeys[id], bagKeys[id]
        local pick
        if w and #w == 1 then
          pick = w[1]
        elseif (not w or #w == 0) and b and #b == 1 then
          pick = b[1]
        end
        if pick and pinStem(pick) ~= pinStem(k) then pick = nil end
        local stub = pick and stubFor[pick]
        if stub then list[i] = stub end
      end
    end
  end
end

function ns.PinLocate(pin, t)
  if pin == nil or not t then return nil end
  if type(pin) == "number" then return t.idBag and t.idBag[pin], t.idSlot and t.idSlot[pin] end
  if type(pin) ~= "string" then return nil end
  local k = ns.ItemKey(pin)
  if not (k and t.keyBag) then return nil end
  return t.keyBag[k], t.keySlot[k]
end

function ns.PinWorn(pin, t)
  if pin == nil then return false end
  local k = ns.ItemKey(pin)
  if k and t and t.wornKey and t.wornKey[k] then return true end
  if type(pin) == "number" then
    local f = (C_Item and C_Item.IsEquippedItem) or IsEquippedItem
    return (pin and f and f(pin)) and true or false
  end
  return false
end

function ns.PinIlvl(pin, t)
  local k = ns.ItemKey(pin)
  local lvl = k and t and t.wornIlvl and t.wornIlvl[k]
  if lvl then return lvl end
  local f = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
  local arg = ns.PinArg(pin)
  if not (f and arg) then return nil end
  local ok, v = pcall(f, arg)
  return (ok and tonumber(v)) or nil
end

function ns.PinSet(pin, t)
  local k = ns.ItemKey(pin)
  return (k and t and t.wornSet and t.wornSet[k]) or nil
end

-- An upgrade, a gem, an enchant or a recraft rewrites the bonus ids of the item, so the exact
-- key of a pinned copy stops matching: the cell would sit on a ghost for good and print the
-- item level the piece had before. The game announces the change itself, and ITEM_CHANGED
-- carries the link from before and after, so the pin is moved onto the new link and stays
-- exact. Only a pin kept as an item string can go stale; a plain id never does.
function ns.PinRetarget(list, n, prev, new)
  local from, to = ns.ItemKey(prev), ns.ItemStub(new)
  if not (list and from and to) then return false end
  local hit = false
  for i = 1, (n or 0) do
    local pin = list[i]
    if type(pin) == "string" and ns.ItemKey(pin) == from then
      list[i] = to
      hit = true
    end
  end
  return hit
end

local function pinQuality(pin)
  local f = C_Item and C_Item.GetItemQualityByID
  local arg = ns.PinArg(pin)
  if not (f and arg) then return nil end
  local ok, q = pcall(f, arg)
  return (ok and tonumber(q)) or nil
end

-- Midnight dropped the two lowest crafting ranks, so building an atlas name out of the
-- quality number points at the wrong metal. Patch 12.0.0 added the pair of quality info
-- calls that hand back the atlas of the item itself, and asking the game is the only mapping
-- that stays right when the ranks are renamed or renumbered again. Reagent quality is asked
-- first and crafted second, the order the game uses on its own item buttons.
function ns.PinTier(pin)
  local T = C_TradeSkillUI
  local arg = ns.PinArg(pin)
  if not (T and arg) then return nil end
  for _, name in ipairs({ "GetItemReagentQualityInfo", "GetItemCraftedQualityInfo" }) do
    local f = T[name]
    if f then
      local ok, info = pcall(f, arg)
      if ok and type(info) == "table" then
        local art = info.iconInventory or info.icon or info.iconSmall
        if art then return art end
      end
    end
  end
  return nil
end

function ns.PinGhost(parent)
  local g = ns.SlotGhost(parent)
  local tier = g:CreateTexture(nil, "OVERLAY")
  tier:Hide()
  g.tier = tier
  local cnt = Theme:Label(g, 11, "gone")
  cnt:SetPoint("BOTTOMRIGHT", -2, 2)
  cnt:Hide()
  g.cnt = cnt
  local ilvl = g:CreateFontString(nil, "OVERLAY")
  ilvl:SetDrawLayer("OVERLAY", 6)
  ilvl:SetTextColor(Theme:C("overlay"))
  ilvl:Hide()
  g.ilvl = ilvl
  local outfit = g:CreateFontString(nil, "OVERLAY")
  outfit:SetDrawLayer("OVERLAY", 6)
  outfit:SetTextColor(Theme:C("overlay"))
  outfit:Hide()
  g.outfit = outfit
  return g
end

-- The item button is an intrinsic widget, so its quality overlay lives in no source file to
-- copy numbers out of. The anchor is read off a real button of the row instead, which is by
-- definition the corner and the offsets the game itself uses.
function ns.PinTierFit(g, btn)
  if g.tierFit then return end
  local src = btn and (btn.ProfessionQualityOverlay or btn.IconOverlay)
  g.tier:ClearAllPoints()
  if not (src and src.GetNumPoints and src:GetNumPoints() > 0) then
    g.tier:SetPoint("TOPLEFT", g.icon, "TOPLEFT")
    g.tier:SetPoint("BOTTOMRIGHT", g.icon, "BOTTOMRIGHT")
    return
  end
  local n = src:GetNumPoints()
  for i = 1, n do
    local p, _, rp, x, y = src:GetPoint(i)
    if p then g.tier:SetPoint(p, g, rp or p, x or 0, y or 0) end
  end
  if n < 3 then
    local w, h = src:GetSize()
    if (w or 0) > 0 and (h or 0) > 0 then
      g.tier:SetSize(w, h)
    else
      g.tierArt = true
    end
  end
  g.tierFit = true
end

-- Blue edge means the item is on you, gold means it is not with you at all, and the gold
-- zero says the same for something that stacks. Gear carries its item level and its gear set
-- instead of a count, and the craft tier is drawn only on what is not gear, since an item
-- level already says how good a piece is.
function ns.PaintPin(g, pin, t, btn)
  if not g then return end
  if not pin then
    if g.icon then g.icon:Hide() end
    if g.tier then g.tier:Hide() end
    if g.cnt then g.cnt:Hide() end
    if g.ilvl then g.ilvl:Hide() end
    if g.outfit then g.outfit:Hide() end
    g:SetBackdropBorderColor(Theme:C("emptyLine"))
    return
  end
  local id = ns.ItemStubID(pin)
  local gear = ns.GearItem(id)
  g.icon:SetTexture(ns.PinIcon(id)); g.icon:Show()
  if g.plus then g.plus:Hide() end
  g:SetBackdropBorderColor(Theme:C(ns.PinWorn(pin, t) and "worn" or "gone"))
  local art = (not gear) and ns.PinTier(pin) or nil
  if g.tier then
    if art then
      ns.PinTierFit(g, btn)
      g.tier:SetAtlas(art, g.tierArt and true or false)
      g.tier:Show()
    else
      g.tier:Hide()
    end
  end
  if gear then
    if g.cnt then g.cnt:Hide() end
    local lvl = ns.Badge("ilvl").on and ns.PinIlvl(pin, t) or nil
    if g.ilvl then
      if lvl and lvl > 1 then
        ns.ApplyBadge(g, "ilvl")
        local q = (ns.Bags and ns.Bags.qualityColorIlvl) and pinQuality(pin)
        local qc = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
        if qc then
          g.ilvl:SetTextColor(qc.r, qc.g, qc.b)
        else
          g.ilvl:SetTextColor(Theme:C("overlay"))
        end
        g.ilvl:SetText(lvl)
        g.ilvl:Show()
      else
        g.ilvl:Hide()
      end
    end
    local set = ns.PinSet(pin, t)
    if g.outfit then
      if set then
        ns.ApplyBadge(g, "outfit")
        g.outfit:SetText(set)
        g.outfit:Show()
      else
        g.outfit:Hide()
      end
    end
  else
    if g.ilvl then g.ilvl:Hide() end
    if g.outfit then g.outfit:Hide() end
    if g.cnt then
      local cb = ns.Badge("count")
      ns.SetOutlined(g.cnt, cb.s)
      g.cnt:ClearAllPoints()
      g.cnt:SetPoint(ns.BadgePoint(cb), g, cb.c, cb.x, cb.y)
      g.cnt:SetText("0")
      g.cnt:Show()
    end
  end
end
