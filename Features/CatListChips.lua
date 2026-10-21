local addonName, ns = ...
local Options = ns.Options
local factories = Options.factories
local Theme = ns.Theme

-- The pin rack's two pieces: a pinned item's icon and the faint empty slots under it. Both are pooled on
-- the panel, so a reflow rebinds the same frames instead of making a rack each pass.
function factories.catlistchips(env)
  local Cats = env.Cats
  local CHIP, ICON_PAD, ICON = env.chip, env.iconPad, env.icon
  local act = env.act

  -- One pinned item: the art alone. A pin is a picture of something the player filed by hand, and a strip
  -- read by eye — a row of icons puts twice the pins where a row of named chips put them, and the name is
  -- in the tooltip, which is where a name is read anyway. The hover is the whole target: the art dims, the
  -- × stands over it, and a click anywhere on the icon takes the pin out. One frame, so nothing has to be
  -- summoned before it can be hit — a target that appears under the cursor is a target a fast click misses.
  -- The unpin only edits a saved table and relayouts, no protected call, so it is taint free like the drag
  -- that made the pin.
  local function makeChip(panel, k)
    local b = panel.chips[k]
    if b then return b end
    b = CreateFrame("Button", nil, panel, "BackdropTemplate")
    ns.SnapBox(b, CHIP, CHIP)
    ns.PixelBackdrop(b)
    ns.SetBg(b, Theme:C("bg"))
    ns.SetEdge(b, Theme:C("stroke"))
    local ic = b:CreateTexture(nil, "ARTWORK")
    ic:SetPoint("LEFT", ICON_PAD, 0)
    ns.SnapSize(ic, ICON, ICON)
    ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.ic = ic
    local x = CreateFrame("Frame", nil, b)
    x:SetPoint("CENTER")
    x:SetSize(ICON * 0.6, ICON * 0.6)
    ns.MarkX(x)
    ns.TintMarkX(x, "accent")
    Theme:Track(x, function() ns.TintMarkX(x, "accent") end)
    x:Hide()
    b.x = x
    b:SetScript("OnEnter", function(s)
      ns.SetEdge(s, Theme:C("accent"))
      s.ic:SetAlpha(0.35)
      s.x:Show()
      if s.wpeId then
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(s.wpeId)
        GameTooltip:AddLine(ns.TipInk(ns.L["Click the × to remove"], 0.9, 0.9, 0.9), 0.9, 0.9, 0.9)
        GameTooltip:Show()
      end
    end)
    b:SetScript("OnLeave", function(s)
      ns.SetEdge(s, Theme:C("stroke"))
      s.ic:SetAlpha(1)
      s.x:Hide()
      GameTooltip:Hide()
    end)
    b:SetScript("OnClick", function(s)
      GameTooltip:Hide()
      if s.wpeId then act(function() Cats:PinItem(s.wpeId, nil) end) end
    end)
    panel.chips[k] = b
    return b
  end

  -- The empty rack: what a category with no pins shows in place of its strip. Faint slots of the chip
  -- size say both that things go here and how they sit, and they keep the panel's height steady for the
  -- first pin that arrives.
  local function makeGhost(panel, k)
    local g = panel.ghosts[k]
    if g then return g end
    g = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    ns.SnapBox(g, CHIP, CHIP)
    ns.PixelBackdrop(g)
    local function paint(f)
      -- Hot while a piece rides the cursor: the rack is the drop target then, so the empty slots light with
      -- it and the whole band reads as one place to let the item go.
      local br, bg2, bb = Theme:C("bg")
      ns.SetBg(f, br, bg2, bb, 0.35)
      local er, eg, eb = Theme:C(f.wpeHot and "accent" or "emptyLine")
      ns.SetEdge(f, er, eg, eb, f.wpeHot and 1 or 0.35)
    end
    g.Repaint = paint
    paint(g)
    Theme:Track(g, paint)
    panel.ghosts[k] = g
    return g
  end

  return makeChip, makeGhost
end
