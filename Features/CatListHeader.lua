local addonName, ns = ...
local Options = ns.Options
local factories = Options.factories
local Theme = ns.Theme

-- The preset strip and the list's own sort line. They are built here because the strip changes with the
-- list and the sort line is the list's header, not a page setting. The caller owns the rows below them.
function factories.catlistheader(parent, env)
  local Cats = env.Cats
  local BASE_FONT, CONTENT_W = env.baseFont, env.contentW

  local header = {}
  -- The preset strip: one button per shipped category (Armor, Potions, Mounts…). A click adds that
  -- whole category to the list — the thing a player actually wants, not a filter to assemble — and a
  -- preset already in the list dims and goes inert so the strip doubles as a picture of what is on.
  -- This is the primary way to build the list; the per-row search field is the advanced escape for
  -- anyone who wants to hand-write a rule. Buttons are pooled and re-labelled each Rebuild.
  header.presets = {}
  local presetCap = Theme:Label(parent, BASE_FONT - 2, "faint")
  -- Localized through the watcher, not a bare SetText: a language change repaints every watched label
  -- and reflows the page, so this caption follows it like its siblings (New group/divider/category).
  ns.LocalText(presetCap, "Add a category")
  header.presetCap = presetCap

  -- One caption per shipped band, made on first use and kept: a band whose presets are all in the list
  -- leaves no button behind and no caption either, so a shelf only ever names what stands under it.
  header.shelfCaps = {}
  local function shelfCap(key)
    local cap = header.shelfCaps[key]
    if not cap then
      cap = Theme:Label(parent, BASE_FONT - 3, "faint")
      ns.LocalText(cap, key)
      header.shelfCaps[key] = cap
    end
    return cap
  end

  local function presetBtn(k, def)
    local b = header.presets[k]
    if not b then
      b = ns.CreateButton(parent, "", 100, 22)
      header.presets[k] = b
    end
    b.Text:SetText(def.name)
    local inList = Cats:Has(def.id)
    ns.SetButtonEnabled(b, not inList)
    b:SetScript("OnClick", function()
      if Cats:Has(def.id) then return end
      env.act(function() return Cats:AddPreset(def.id) end)
    end)
    local wtext = math.ceil(b.Text:GetStringWidth()) + 20
    ns.SnapBox(b, math.max(64, wtext), 22)
    b:Show()
    return b
  end

  -- The order items take inside every section: the list's own setting, so it lives on the list's header
  -- line instead of among the settings at the top of the tab, where it read as a property of the page and
  -- the thing it orders was a screen away. Words rather than a filled plate, exactly like the per-section
  -- override inside a row's + panel — one control at two scopes — and its label is read live on every
  -- reflow, so a language change reaches it.
  local SORT_SPEC = {
    keys = function() return env.sortKeys end,
    get = function() return WarpeeDB.catSort or "ilvl" end,
    set = function(v) WarpeeDB.catSort = v; env.relayout() end,
    label = function(k) return ns.L[env.sortLabels[k] or k] end,
    desc = "The order items take inside every section, unless one sets its own from its + panel. Each falls back to name, so it never flickers. By rule follows a search written with |, drawing its parts in written order; By expansion groups by expansion, newest first.",
  }
  local sortRow, refreshSort
  local function buildSort()
    if sortRow then return end
    sortRow = CreateFrame("Button", nil, parent)
    ns.SnapBox(sortRow, nil, 22, true)
    local sortCap = Theme:Label(sortRow, BASE_FONT - 2, "faint")
    ns.LocalText(sortCap, "Sort within a section")
    sortCap:SetPoint("LEFT", 0, 0)
    local sortArrow = ns.ArrowGlyph(sortRow, "down", 9)
    sortArrow:SetPoint("RIGHT", -2, 0)
    local sortVal = Theme:Label(sortRow, BASE_FONT - 2, "text")
    sortVal:SetJustifyH("RIGHT")
    sortVal:SetPoint("RIGHT", sortArrow, "LEFT", -6, 0)
    refreshSort = function()
      sortVal:SetText(SORT_SPEC.label(SORT_SPEC.get()))
      sortArrow:SetTint("dim")
    end
    sortRow:SetScript("OnClick", function(s) env.openDropdown(s, SORT_SPEC, refreshSort) end)
    sortRow:SetScript("OnEnter", function()
      sortArrow:SetTint("accent")
    end)
    sortRow:SetScript("OnLeave", function()
      sortArrow:SetTint("dim")
    end)
    env.tip(sortRow, SORT_SPEC.desc)
  end

  function header.layout(y)
    -- The preset strip at the top, in shelves: a caption line per shipped band, the ready-made categories
    -- of that band under it, wrapped to the page width. It leads the editor because adding a ready-made
    -- category is the common act; the list of your own categories follows below.
    --
    -- A preset already in the list is gone from the strip rather than dimmed. The list below is the record
    -- of what is in, so a button whose whole job is to say "you have me" spends a line of the page saying
    -- nothing — and the strip is the one block that grows as the player does less with it. Gone, it shrinks
    -- as the list grows and leaves the page entirely once the shipped set is complete, which is also what
    -- gives the editor back the top half of its screen. Reset is the way back to it.
    for _, b in pairs(header.presets) do b:Hide() end
    local presets = Cats:Presets()
    local shelves, shelvedAt = {}, {}
    for k, def in ipairs(presets) do
      local key = def.bandKey or ""
      local shelf = shelvedAt[key]
      if not shelf then
        shelf = { key = key, add = {} }
        shelvedAt[key] = shelf
        shelves[#shelves + 1] = shelf
      end
      if not Cats:Has(def.id) then shelf.add[#shelf.add + 1] = k end
    end
    local live = 0
    for _, shelf in ipairs(shelves) do if #shelf.add > 0 then live = live + 1 end end
    local usedCaps = {}
    if live > 0 then
      presetCap:ClearAllPoints()
      presetCap:SetPoint("TOPLEFT", 0, -y)
      presetCap:Show()
      y = y + BASE_FONT + 5
      for _, shelf in ipairs(shelves) do
        if #shelf.add > 0 then
          local cap = shelfCap(shelf.key)
          usedCaps[cap] = true
          cap:ClearAllPoints()
          cap:SetPoint("TOPLEFT", 0, -y)
          cap:Show()
          y = y + BASE_FONT + 1
          local px, prow = 0, 0
          for _, k in ipairs(shelf.add) do
            local b = presetBtn(k, presets[k])
            local w = b:GetWidth()
            if px > 0 and px + w > CONTENT_W then px = 0; prow = prow + 1 end
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", px, -(y + prow * 26))
            px = px + w + 6
          end
          y = y + (prow + 1) * 26 + 3
        end
      end
      y = y + 3
    else
      presetCap:Hide()
    end
    for _, cap in pairs(header.shelfCaps) do if not usedCaps[cap] then cap:Hide() end end
    for k = #presets + 1, #header.presets do if header.presets[k] then header.presets[k]:Hide() end end

    -- A faint divider seams the preset strip off from the list of categories below it. A texture, not
    -- a bare frame: PixelLine only sizes what it is given, and a frame has nothing to paint, so the
    -- line was invisible until it was drawn on a real texture like the group-header line above.
    local seam = header.seam
    if not seam then
      seam = Theme:Rect(parent, "strokeSoft", "ARTWORK")
      ns.PixelLine(seam, 1)
      header.seam = seam
    end
    seam:ClearAllPoints()
    seam:SetPoint("TOPLEFT", 0, -y)
    seam:SetPoint("TOPRIGHT", 0, -y)
    seam:Show()
    y = y + 8

    -- The list's own header line: what orders the rows under it, directly above them.
    buildSort()
    sortRow:ClearAllPoints()
    sortRow:SetPoint("TOPLEFT", 0, -y)
    sortRow:SetPoint("TOPRIGHT", 0, -y)
    sortRow:Show()
    refreshSort()
    return y + 26
  end

  return header
end
