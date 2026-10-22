local addonName, ns = ...
local Options = ns.Options
local factories = Options.factories
local Theme = ns.Theme

-- The dropdown: one menu frame for the whole options window, its pooled rows, its scrollbar, and the
-- second-press toggle. It is built on the first section that opens rather than at load, because a section
-- nobody has reached never needs it — and a menu that is never shown costs nothing.
-- `ensureDropdown` creates the frame once and keeps it; every later open rebinds the rows in place.
function factories.optiondropdown(env)
  local BASE_FONT = env.baseFont
  local SCROLL_W = env.scrollW
  local track = env.track
  local dropdownFont = env.dropdownFont

  local dropdown
  local openDropdown

  local function closeDropdown()
    if dropdown then dropdown:Hide() end
  end

  -- Whether `frame` is the control the menu is hanging from. A control asks this on hover to keep its
  -- own tip quiet while the menu's description is up.
  local function isDropdownOpen(frame)
    return dropdown and dropdown:IsShown() and dropdown.owner == frame and true or false
  end

  local function makeMenuRow(parent, index, rowH)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(rowH)
    r:SetPoint("TOPLEFT", 0, -(index - 1) * rowH)
    r:SetPoint("TOPRIGHT", 0, -(index - 1) * rowH)

    local bg = Theme:Rect(r, "panelHi", "BACKGROUND")
    bg:SetAllPoints(r)
    bg:Hide()
    r.bg = bg

    local dot = Theme:Rect(r, "accent", "ARTWORK")
    dot:SetSize(3, rowH - 8)
    dot:SetPoint("LEFT", 2, 0)
    dot:Hide()
    r.dot = dot

    -- A multi row is a set, so it reads as a tick box.
    local box = ns.CreateCheckBox(r, 12)
    box:SetPoint("LEFT", 3, 0)
    box:Hide()
    r.box = box

    local fs = track(Theme:Label(r, BASE_FONT - 1, "text"), -1)
    fs:SetFont(dropdownFont(), BASE_FONT - 1, ns.OutlineFlags())
    fs:SetPoint("LEFT", 10, 0)
    fs:SetPoint("RIGHT", -8, 0)
    fs:SetJustifyH("LEFT")
    -- One line per entry, always: a row is one row tall, so a two-word label that wrapped would be drawn
    -- out of its own row and the menu would read as broken. The menu is widened to the longest entry where
    -- it opens (openDropdown), so nothing is cut off either.
    fs:SetWordWrap(false)
    r.Text = fs

    r:SetScript("OnEnter", function(s)
      s.bg:Show()
      if dropdown and dropdown.desc then
        ns.ShowTip(s, { { text = dropdown.desc } }, "top")
      end
    end)
    r:SetScript("OnLeave", function(s) s.bg:Hide(); ns.HideTip() end)
    return r
  end

  local function ensureDropdown()
    if dropdown then return dropdown end

    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("DIALOG")
    catcher:RegisterForClicks("AnyUp")
    catcher:Hide()

    local m = CreateFrame("Frame", "WarpeeDropdown", UIParent, "BackdropTemplate")
    m:Hide()
    Theme:Panel(m, "panel", "accent")
    m:SetFrameStrata("DIALOG")
    m:SetToplevel(true)
    m:SetFrameLevel(catcher:GetFrameLevel() + 10)
    m:EnableMouse(true)
    m:SetClampedToScreen(true)

    local sf = CreateFrame("ScrollFrame", nil, m)
    sf:SetPoint("TOPLEFT", 4, -4)
    sf:SetPoint("BOTTOMRIGHT", -4, 4)
    local child = CreateFrame("Frame", nil, sf)
    child:SetPoint("TOPLEFT")
    sf:SetScrollChild(child)

    -- A scrollbar so a menu longer than its 9-row cap shows it continues: without it a long list (fonts,
    -- token groups) looked like it simply ended at the last visible row. Same look as the page scrollbar
    -- - panel track, faint thumb that lights on hover and drag - and it hides itself when everything fits.
    local bar = CreateFrame("Frame", nil, m)
    bar:SetWidth(SCROLL_W)
    bar:SetPoint("TOPRIGHT", -3, -4)
    bar:SetPoint("BOTTOMRIGHT", -3, 4)
    Theme:Rect(bar, "panel", "BACKGROUND"):SetAllPoints(bar)
    local thumb = CreateFrame("Frame", nil, bar)
    thumb:SetWidth(SCROLL_W)
    local thumbTex = Theme:Rect(thumb, "faint", "ARTWORK")
    thumbTex:SetAllPoints(thumb)
    m.bar, m.thumb = bar, thumb

    local function menuSpan() return math.max(0, child:GetHeight() - sf:GetHeight()) end
    local function paintBar()
      local span, view = menuSpan(), sf:GetHeight()
      if span <= 0 or not m:IsShown() then bar:Hide(); return end
      bar:Show()
      local ch = child:GetHeight()
      local h = math.max(20, view * view / (ch > 0 and ch or view))
      thumb:SetHeight(h)
      local frac = sf:GetVerticalScroll() / span
      thumb:ClearAllPoints()
      thumb:SetPoint("TOP", bar, "TOP", 0, -frac * (view - h))
    end
    m.PaintBar = paintBar
    local function menuScroll(v)
      local span = menuSpan()
      v = math.min(span, math.max(0, v))
      sf:SetVerticalScroll(math.min(span, ns.SnapScroll(sf, v)))
      paintBar()
    end
    m.MenuScroll = menuScroll

    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(s, d) menuScroll(s:GetVerticalScroll() - d * 40) end)

    ns.ScrollThumb(thumb, thumbTex, sf, menuScroll, menuSpan)

    m.rows, m.sf, m.child, m.catcher = {}, sf, child, catcher
    m:SetScript("OnHide", function() catcher:Hide(); ns.HideTip() end)
    catcher:SetScript("OnClick", function()
      local owner = dropdown and dropdown.owner
      closeDropdown()
      local f
      if GetMouseFoci then
        local foci = GetMouseFoci()
        f = (type(foci) == "table") and foci[1] or nil
      end
      if f and f ~= owner and f.wpeDrop and (not f.IsEnabled or f:IsEnabled()) then
        openDropdown(f, f.wpeDrop.spec, f.wpeDrop.onPick)
      end
    end)
    ns.EscClose(m)
    dropdown = m
    return m
  end

  -- Opening and painting only; the second-press toggle lives in openDropdown.
  local function showDropdown(anchor, spec, onPick)
    local m = ensureDropdown()
    local keys = spec.keys()
    local rowH = BASE_FONT + 11
    -- Not `spec.multi and nil or spec.get()`: with the middle nil the `or` falls through and calls get()
    -- anyway, which a multi spec has not got.
    local cur
    if not spec.multi then cur = spec.get() end
    local curIndex = 1
    for i, key in ipairs(keys) do
      local r = m.rows[i]
      if not r then r = makeMenuRow(m.child, i, rowH); m.rows[i] = r end
      r:SetHeight(rowH)
      r.dot:SetSize(3, rowH - 8)
      r.Text:SetFont(dropdownFont(), BASE_FONT - 1, ns.OutlineFlags())
      r.Text:SetText(T(spec.label(key)))
      -- A "#" key is a section header: no dot, drawn faint. It still takes a click, because the token
      -- menu uses one as a way into that section, and the tip carries the hint that it opens.
      local head = type(key) == "string" and key:sub(1, 1) == "#"
      -- multi ticks per key and stays open; single marks one and closes.
      local on
      if spec.multi then on = (not head and spec.isOn and spec.isOn(key))
      else on = (not head and key == cur) end
      if spec.multi then
        -- The tick is the whole state here: one box per entry.
        local tick = on and not head
        r.dot:Hide()
        r.box:SetKeys("slot", tick and "bg" or "stroke", "accent")
        r.box.mark:SetShown(tick and true or false)
        r.box:Show()
      else
        if r.box then r.box:Hide() end
        r.dot:SetShown(on)
      end
      -- A tick box is wider, so a set's text steps past the gutter.
      r.Text:SetPoint("LEFT", spec.multi and 20 or 10, 0)
      -- The pick is shown by its dot and the row plate, not by painting the word accent: the current entry
      -- keeps the text ink and the gutter dot marks it. A header stays faint.
      local tkey = head and "faint" or "text"
      r.Text:SetTextColor(Theme:C(tkey))
      r.bg:Hide()
      if head and not spec.nav then
        r:SetScript("OnClick", nil)
      elseif spec.multi then
        r:SetScript("OnClick", function()
          spec.toggle(key)
          if onPick then onPick() end
          showDropdown(anchor, spec, onPick) -- repaint the ticks + summary, menu stays open
        end)
      else
        r:SetScript("OnClick", function()
          closeDropdown()
          spec.set(key)
          if ns.Profiles and ns.Profiles.SyncActive then ns.Profiles:SyncActive() end
          if onPick then onPick() end
        end)
      end
      r:Show()
      if on then curIndex = i end
    end
    for i = #keys + 1, #m.rows do m.rows[i]:Hide() end

    -- As wide as the longest entry, not as wide as the control it hangs from: with the rows on one line
    -- each, the menu has to hold the words it shows, and a translation longer than the English one (or a
    -- font's own name) must not be cut at the edge. The control's width stays a floor, so a short list does
    -- not shrink to a stub, and the menu is clamped to the screen like every window here.
    local widest = 0
    for i = 1, #keys do
      local r = m.rows[i]
      local wtext = (r and r.Text and r.Text:GetStringWidth()) or 0
      if wtext > widest then widest = wtext end
    end
    local w = math.max(anchor:GetWidth(), 120, math.ceil(widest) + 26)
    local visible = math.min(#keys, 9)
    ns.SnapSize(m, w, visible * rowH + 8)
    -- When the list overflows its 9-row cap the scrollbar shows on the right, so the rows give it room
    -- (its width plus a little air); a list that fits keeps the full width.
    local overflow = #keys > visible
    m.child:SetSize(w - 8 - (overflow and (SCROLL_W + 4) or 0), #keys * rowH)

    local span = math.max(0, #keys * rowH - visible * rowH)
    m.sf:SetVerticalScroll(math.min(span, ns.SnapScroll(m.sf, (curIndex - 1) * rowH - rowH * 3)))

    m.owner = anchor
    m.desc = spec.desc
    ns.HideTip()
    m:ClearAllPoints()
    local below = anchor:GetBottom() or 0
    if below - m:GetHeight() < 20 then
      m:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 2)
    else
      m:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    end
    m.catcher:SetFrameLevel(anchor:GetFrameLevel() + 1)
    m.catcher:Show()
    m:Show()
    m:Raise()
    -- Size and scroll are set now, so paint the bar: it shows only when the list overflows and sits at
    -- the scroll position the current pick was brought to.
    if m.PaintBar then m:PaintBar() end
  end

  -- The ordinary way in: a second press on the control closes it.
  function openDropdown(anchor, spec, onPick)
    if isDropdownOpen(anchor) then closeDropdown(); return end
    showDropdown(anchor, spec, onPick)
  end

  return openDropdown, closeDropdown, isDropdownOpen
end
