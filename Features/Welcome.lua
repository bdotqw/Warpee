local addonName, ns = ...
local Theme = ns.Theme
local Bags = ns.Bags

-- The first-run view chooser. Categories shipped without a word to the players already on the grid, so
-- this announces them once and lets the player pick a starting layout with a live preview drawn on their
-- own items: the bag window redraws in the hovered view while this window sits on its own in the middle
-- of the screen, so the preview changes but the chooser never moves. The choice is per profile (the
-- profile is account-wide, so a pick on any character silences it everywhere), and dismissing by any path
-- counts as shown. All frames here are our own; nothing touches a container template, so no taint surface.
local Welcome = {}
ns.Welcome = Welcome

local PAD = 16
-- The re-announce marker. A player already prompted once (startPrompted) who is still on the plain grid
-- is shown the chooser one more time, so the category view is not missed by everyone who was upgraded
-- silently into it. It is a strict one-time event: the flag is a plain presence, written the instant the
-- window appears (Welcome:Show), and MaybeShow gates on whether it is set at all, never on its value. A
-- future release bumping anything can therefore never re-show it to a grid user who has already seen it
-- once. The number itself is only there to record which release did the announce.
local WELCOME_REANNOUNCE = 2
-- The window grows from WMIN to fit the widest localized line at the face the labels draw in (a bold
-- font, a long German or Russian word), capped at WMAX so it never runs off a small screen. Height is
-- measured against the chosen width so a wrapped line in any locale is never clipped.
local WMIN, WMAX = 340, 520
local TITLE_SZ, SUB_SZ, HEAD_SZ, DESC_SZ = 17, 13, 16, 12

-- Preview a view without committing: only relayout when it actually changes, so moving between the two
-- tiles does not relayout twice for the same target. Read at hover, driven by the player's own motion.
local function preview(mode)
  if Bags.bagView == mode then return end
  Bags.bagView = mode
  if Bags.frame and Bags.frame:IsShown() then Bags:Layout(true) end
end

function Welcome:Restore()
  preview(self.committed or "grid")
end

-- The choice is made: set both the bags and the bank to the picked view (one press decides both, as the
-- reference does), relayout an open bank, and finish. WarpeeDB carries the view so it survives a reload.
function Welcome:Commit(mode)
  Bags.bagView = mode
  WarpeeDB.bagView = mode
  WarpeeDB.bankView = mode
  self.committed = mode
  if Bags.frame and Bags.frame:IsShown() then Bags:Layout(true) end
  if ns.Bank and ns.Bank.Refresh then ns.Bank:Refresh() end
  self:Finish()
end

-- Shown, whatever the player did with it: a tile click, the ×, or the bag window closing under it. The
-- flag is set here on dismiss, not on show, so a window closed unread (or in combat, never shown) returns
-- next time instead of being spent. A preview may be in flight (the pointer left a tile as it closed), so
-- the committed view is put back here rather than left on the hover state.
function Welcome:Finish()
  if WarpeeDB then WarpeeDB.startPrompted = 1; WarpeeDB.welcomeSeen = WELCOME_REANNOUNCE end
  self:Restore()
  if self.frame then self.frame:Hide() end
  if ns.Options and ns.Options.RefreshOpen then ns.Options:RefreshOpen() end
end

-- One tile: a plate with a bold heading and a wrapped description. Hover previews its view on the bag
-- window, leaving without a click restores the committed one, and a click commits. The whole tile is the
-- button so the reference's separate "Choose" caption is unneeded; the heading names the view. Head and
-- desc are kept on the tile so FitLayout can measure and place them once the width is known.
function Welcome:Tile(parent, mode, headKey, descKey)
  local t = CreateFrame("Button", nil, parent, "BackdropTemplate")
  ns.PixelBackdrop(t)
  local function paint(s)
    local on = (s.wpeHot or s.wpeSel)
    ns.SetBg(s, Theme:C(on and "panelHi" or "panel"))
    ns.SetEdge(s, Theme:C(on and "accent" or "stroke"))
  end
  t.Repaint = paint
  paint(t)
  Theme:Track(t, paint)
  local head = Theme:Title(t, HEAD_SZ, "accent")
  ns.SnapPoint(head, "TOPLEFT", t, "TOPLEFT", PAD, -PAD)
  head:SetPoint("RIGHT", t, "RIGHT", -PAD, 0)
  head:SetJustifyH("LEFT")
  ns.LocalText(head, headKey)
  local desc = Theme:Label(t, DESC_SZ, "dim")
  ns.SnapPoint(desc, "TOPLEFT", t, "TOPLEFT", PAD, -(PAD + HEAD_SZ + 6))
  desc:SetPoint("RIGHT", t, "RIGHT", -PAD, 0)
  desc:SetJustifyH("LEFT")
  desc:SetWordWrap(true)
  ns.LocalText(desc, descKey)
  t:SetScript("OnEnter", function(s) s.wpeHot = true; paint(s); preview(mode) end)
  t:SetScript("OnLeave", function(s) s.wpeHot = nil; paint(s); Welcome:Restore() end)
  t:SetScript("OnClick", function() Welcome:Commit(mode) end)
  t.wpeMode, t.wpeHead, t.wpeDesc = mode, head, desc
  return t
end

function Welcome:Build()
  if self.frame then return self.frame end
  local host = Bags and Bags.frame

  -- Its own window in the middle of the screen, unattached to the bags, so a preview that changes the bag
  -- window's height (a full alt can grow it taller than the grouped view) never moves the chooser or the
  -- pointer off a tile. Parented to UIParent, its own strata, Esc-closable. Sized in FitLayout.
  local m = CreateFrame("Frame", "WarpeeWelcome", UIParent, "BackdropTemplate")
  m:Hide()
  Theme:Panel(m, "panel", "accent")
  m:SetFrameStrata("DIALOG")
  m:SetToplevel(true)
  m:EnableMouse(true)
  m:SetClampedToScreen(true)
  ns.SnapSize(m, WMIN, 300)
  ns.SnapPoint(m, "CENTER", UIParent, "CENTER", 0, 0)
  ns.EscClose(m)
  self.frame = m
  -- A hidden string to measure localized text at the exact face and size each label draws in, so the
  -- window can be sized to whatever the current language and font actually need.
  self.measure = m:CreateFontString(nil, "ARTWORK")

  local title = Theme:Title(m, TITLE_SZ, "accent")
  ns.SnapPoint(title, "TOPLEFT", m, "TOPLEFT", PAD, -PAD)
  title:SetPoint("RIGHT", m, "RIGHT", -(PAD + 26), 0)
  title:SetJustifyH("LEFT")
  title:SetWordWrap(true)
  ns.LocalText(title, "Choose your bag layout")

  local close = ns.CreateGlyphButton(m, "×", 22)
  ns.SnapPoint(close, "TOPRIGHT", m, "TOPRIGHT", -PAD, -PAD)
  close:SetScript("OnClick", function() Welcome:Finish() end)
  ns.AddTip(close, "Decide later", "top")

  local sub = Theme:Label(m, SUB_SZ, "text")
  sub:SetJustifyH("LEFT")
  sub:SetWordWrap(true)
  ns.LocalText(sub, "You can change this any time.")
  self.title, self.sub, self.close = title, sub, close

  local grid = self:Tile(m, "grid", "Grid", "One grid, sorted by bag slot. The classic bag.")
  local cats = self:Tile(m, "cat", "Categories", "Items grouped into labelled sections by type.")
  self.gridTile, self.catTile = grid, cats

  -- Closing the bag window with the chooser still up counts as a dismiss: the flag has to be set so it
  -- does not return next open. Hooked once; a no-op when the chooser is already down.
  if host then
    host:HookScript("OnHide", function()
      if Welcome.frame and Welcome.frame:IsShown() then Welcome:Finish() end
    end)
  end
  return m
end

-- Highlight the tile that matches the committed view, so an untouched dismiss reads as "keep this".
function Welcome:MarkSelected()
  local sel = self.committed or "grid"
  for _, t in ipairs({ self.gridTile, self.catTile }) do
    if t then t.wpeSel = (t.wpeMode == sel); t:Repaint() end
  end
end

-- Size the whole window to the localized text: first the width from the widest single line (title, tile
-- headings) at the face they draw in, capped at WMAX; then, with that width fixed, measure each wrapped
-- description at the tile's inner width and lay the pieces out top to bottom so nothing is ever clipped or
-- overlapped. Called at each Show, so a font or language change is picked up. Measured against the current
-- addon font (Bags.fontPath), the same face the labels use.
function Welcome:FitLayout()
  local m, mm = self.frame, self.measure
  if not (m and mm) then return end
  local face = Bags.fontPath or ns.Fonts:Current()
  local function width(text, size)
    if not text or text == "" then return 0 end
    mm:SetFont(face, size, ns.OutlineFlags())
    mm:SetWidth(0)          -- clear any wrap left from a prior layout so this reads the natural width
    mm:SetWordWrap(false)
    mm:SetText(text)
    return math.ceil(mm:GetStringWidth() or 0)
  end
  -- Width: the widest single-line string, each with its own edge lead. Title clears the close glyph.
  -- SLACK is spare width added on top of the measured need so a bold face on a long locale (Spanish,
  -- German) has room to spare rather than sitting flush against the edge.
  local SLACK = 26
  local need = WMIN
  need = math.max(need, width(ns.L["Choose your bag layout"], TITLE_SZ) + PAD * 2 + 30)
  for _, t in ipairs({ self.gridTile, self.catTile }) do
    need = math.max(need, width(t.wpeHead:GetText(), HEAD_SZ) + PAD * 4)
  end
  local w = math.min(WMAX, need + SLACK)
  ns.SnapSize(m, w, m:GetHeight() or 300)
  w = m:GetWidth() or w

  -- Height: measure the true wrapped height of each block at the width it will actually wrap in. A
  -- FontString given a fixed width and word-wrap reports back the real multi-line height, so a locale
  -- whose words break onto an extra line (Spanish, German) is measured, not guessed at from a width
  -- ratio that ignores where the words actually break.
  local innerW = w - PAD * 2       -- subtitle wraps in the window
  local function wrapped(text, size, wrapW)
    if not text or text == "" then return 0 end
    mm:SetFont(face, size, ns.OutlineFlags())
    mm:SetWidth(wrapW)
    mm:SetWordWrap(true)
    mm:SetText(text)
    return math.ceil(mm:GetStringHeight() or size)
  end
  local subH = wrapped(ns.L["You can change this any time."], SUB_SZ, innerW)
  local y = PAD + TITLE_SZ + 10           -- below the title row
  self.sub:ClearAllPoints()
  ns.SnapPoint(self.sub, "TOPLEFT", m, "TOPLEFT", PAD, -y)
  self.sub:SetPoint("RIGHT", m, "RIGHT", -PAD, 0)
  y = y + subH + 14

  -- Height each tile from its own live FontStrings, not a proxy. The measure string matched the face and
  -- point size but not the engine's line leading, which it adds on top when a description wraps to a second
  -- line, so a two-line locale under-read by that leading and the text sat almost against the bottom edge.
  -- The real head and desc already carry their width (anchored left and right inside the tile), so their
  -- own GetStringHeight is the true rendered height, leading and outline included: the same PAD then closes
  -- the tile top and bottom on every locale, one and two line alike. Anchor the desc first so its width is
  -- fixed before it is measured.
  for _, t in ipairs({ self.gridTile, self.catTile }) do
    t:ClearAllPoints()
    ns.SnapPoint(t, "TOPLEFT", m, "TOPLEFT", PAD, -y)
    t:SetPoint("RIGHT", m, "RIGHT", -PAD, 0)   -- width from the anchors; only the height is snapped
    local headH = math.ceil(t.wpeHead:GetStringHeight() or HEAD_SZ)
    t.wpeDesc:ClearAllPoints()
    ns.SnapPoint(t.wpeDesc, "TOPLEFT", t, "TOPLEFT", PAD, -(PAD + headH + 6))
    t.wpeDesc:SetPoint("RIGHT", t, "RIGHT", -PAD, 0)
    local descH = math.ceil(t.wpeDesc:GetStringHeight() or DESC_SZ)
    local tileH = PAD + headH + 6 + descH + PAD
    t:SetHeight(ns.SnapValue(t, tileH))
    y = y + tileH + 10
  end
  ns.SnapSize(m, w, y - 10 + PAD)
  -- Centred on UIParent, a snapped even size can still land the left/bottom edge on a half pixel, which
  -- blurs the border. AlignToScreen nudges the frame's own offsets so its edges sit on the physical grid,
  -- the same pass every other Warpee window runs after it is sized.
  ns.AlignToScreen(m)
end

-- Show the chooser. committed is the view in force now: hovering previews the other, leaving restores this,
-- and a plain dismiss keeps it. Shown via MaybeShow (gated below) or /wpe welcome.
--
-- welcomeSeen is written HERE, the instant the window is actually on screen, not at dismiss. The
-- re-announce to existing grid users must fire at most once ever: writing it on show spends it even when
-- the window then leaves by a path that runs no dismiss code (a /reload with it up, a disconnect), so no
-- one is prompted twice, and no later release can bring it back for a grid user who already saw it once.
-- startPrompted stays on Finish, so only a brand-new install that closes the window unread is offered the
-- choice again, which is the one repeat we want.
function Welcome:Show()
  local m = self:Build()
  if not m then return end
  if WarpeeDB then WarpeeDB.welcomeSeen = WELCOME_REANNOUNCE end
  self.committed = Bags.bagView or "grid"
  self:MarkSelected()
  self:FitLayout()
  m:Show()
  m:Raise()
end

-- The first out-of-combat bag open where the chooser is still owed. Two ways in: a profile never prompted
-- at all (a fresh install), or one prompted by an older release that is still on the plain grid and has
-- never been shown the re-announce. The second is the one-time nudge toward the category view, offered
-- only to grid users, since a player already in categories has plainly found them. welcomeSeen is a
-- presence flag, not a version compare: once it is set at all the re-announce never returns, so 11.4, 12
-- and every later release leave a grid user who saw it once alone for good.
function Welcome:MaybeShow()
  if not WarpeeDB then return end
  local firstEver = WarpeeDB.startPrompted == nil
  local reannounce = not firstEver and WarpeeDB.welcomeSeen == nil
                     and (Bags.bagView or "grid") ~= "cat"
  if not (firstEver or reannounce) then return end
  if InCombatLockdown() then return end
  self:Show()
end

-- /wpe welcome: re-open the chooser regardless of the flag, for a second look or a locale check. A pick or
-- dismiss re-sets the flag, so this is also the permanent "show it again" path.
function Welcome:Reopen()
  self:Show()
end

