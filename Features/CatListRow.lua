local addonName, ns = ...
local Options = ns.Options
local factories = Options.factories
local Theme = ns.Theme

-- One pooled row of the category list: enable box, grip, name field, the "+" that opens the rule panel,
-- and delete. The panel itself is built by the list, not here. The pool is keyed by list index and rebound
-- on every rebuild, so a row carries no state across a reorder.
function factories.catlistrow(list, env)
  local Cats = env.Cats
  local CAT_ROW_H = env.rowH
  local BASE_FONT = env.baseFont
  local act = env.act
  local makeBox = env.makeBox
  local makeGrip = env.makeGrip
  local commitName = env.commitName
  local cancelPending = env.cancelPending
  local debounce = env.debounce
  local startDrag = env.startDrag
  local stopDrag = env.stopDrag
  local relayout = env.relayout
  local track = env.track

  return function(i)
    local c = list.items[i]
    if c then return c end
    c = CreateFrame("Frame", nil, list)
    c:SetHeight(CAT_ROW_H)

    local box = ns.CreateCheckBox(c, 16)
    ns.SnapPoint(box, "TOPLEFT", c, "TOPLEFT", 1, -5)
    -- The checkbox art is mouse transparent, so a full-height button beside it carries the click (a pooled
    -- sibling at the row's level would not reliably take it).
    local hit = CreateFrame("Button", nil, c)
    hit:SetSize(16, CAT_ROW_H)
    ns.SnapPoint(hit, "TOPLEFT", c, "TOPLEFT", 1, 0)
    hit:SetFrameLevel(c:GetFrameLevel() + 5)
    hit:RegisterForClicks("LeftButtonUp")
    hit:SetScript("OnEnter", function() box:SetKeys(nil, "accent", nil) end)
    hit:SetScript("OnLeave", function() box:SetKeys(nil, "stroke", nil) end)
    hit:SetScript("OnClick", function() act(function() Cats:Toggle(c.idx) end) end)
    c.chk = box
    c.chkHit = hit

    -- Grip is the reorder handle (one gesture, no click/drag ambiguity the old carets had).
    local grip = makeGrip(c)
    ns.SnapPoint(grip, "LEFT", box, "RIGHT", 4, 0)
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart", function() startDrag(c.idx) end)
    grip:SetScript("OnDragStop", stopDrag)
    c.grip = grip

    -- Default right anchor for a marker row; a category row re-anchors del next to its name each pass.
    local del = ns.CreateGlyphButton(c, "\195\151", 18)
    -- The delete cross reads "removes" by colour, not by having a border the way the plus does: the plus
    -- wears an accent border when its panel is open (active), so a cross that showed its own state in a
    -- border would be the same language saying a different thing. Instead the whole mark and its frame
    -- carry the kit's one red (Theme danger), dangerHi on hover -- a red cross is delete, an accent border
    -- is active, two colours for two meanings. A red-filled cross still beats a red-framed white one here:
    -- the glyph is what the eye lands on. Faded rows (Empty/Other hide this) keep the base paint.
    -- One pooled row deletes a category and a marker (divider/group head) alike, so this covers dividers.
    local baseDel = del.Repaint
    local function delPaint(s)
      baseDel(s)
      if not s.offDuty then
        ns.SetEdge(s, Theme:C(s.wpeHot and "dangerHi" or "danger"))
        ns.TintMarkX(s, s.wpeHot and "dangerHi" or "danger")
      end
    end
    del.Repaint = delPaint
    Theme:Track(del, delPaint)
    delPaint(del)
    ns.SnapPoint(del, "TOPRIGHT", c, "TOPRIGHT", -1, -4)
    del:SetScript("OnClick", function()
      -- Drop the open-panel flag with the row, so re-adding a shipped category later (its id is reused)
      -- comes back collapsed instead of inheriting the open state this one had.
      if c.catId then list.openPins[c.catId] = nil end
      act(function()
        if c.entry then Cats:RemoveMarker(c.entry) else Cats:Remove(c.idx) end
      end)
    end)
    c.del = del

    -- "+" opens this row's rule/pin panel. The open state shows in the plate edge, not by filling the
    -- mark: the glyph keeps the window ink and the accent border marks it active, the same way the rest of
    -- the window shows selection. The open state must outlast the hover, so wpeOpen is a sticky flag the
    -- wrapped Repaint reads on top of the base paint.
    local addPin = ns.CreateGlyphButton(c, "+", 18)
    -- Thinner arms than the id-commit plus: this one only unfolds the row, so it reads lighter.
    addPin.wpeMarkW = 2
    ns.FitMarkPlus(addPin)
    ns.SnapPoint(addPin, "RIGHT", del, "LEFT", -4, 0)
    local basePaint = addPin.Repaint
    addPin.Repaint = function(s)
      basePaint(s)
      if s.wpeOpen then ns.SetEdge(s, Theme:C("accent")) end
    end
    addPin:SetScript("OnClick", function()
      local id = c.catId
      if not id then return end
      -- Toggle off the panel's shown state, not the flag: a pinned category opens by default, so a bare
      -- flag toggle could never close it. Stored as an explicit force (true opens pinless, false collapses).
      list.openPins[id] = not c.wpePanelOpen
      act(function() end)
    end)
    c.addPin = addPin

    -- Count survives only for the Other catch-all (unmatched total); hidden on real rows in Rebuild.
    local count = track(Theme:Label(c, BASE_FONT - 2, "dim"), -2)
    count:SetJustifyH("RIGHT")
    count:SetPoint("RIGHT", addPin, "LEFT", -6, 0)
    count:SetWidth(30)
    c.count = count

    local name = makeBox(c, "Name", 24)
    ns.SnapPoint(name, "LEFT", grip, "RIGHT", 8, 0)
    name:SetScript("OnEditFocusLost", function(s)
      ns.SetEdge(s, Theme:C("stroke")); s.ph:SetShown(s:GetText() == "")
      cancelPending(); commitName(c, s:GetText()); relayout()
    end)
    name:SetScript("OnTextChanged", function(s)
      s.ph:SetShown(s:GetText() == "")
      if not s:HasFocus() then return end
      debounce(function() commitName(c, s:GetText()); relayout() end)
    end)
    c.nameBox = name
    -- Rule + pins live in the panel the "+" opens; the row is just name / enable / grip / + / delete.

    list.items[i] = c
    return c
  end
end
