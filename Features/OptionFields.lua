local addonName, ns = ...
local Options = ns.Options
local factories = Options.factories
local Theme = ns.Theme

-- The typed fields and the two pickers: a plain input with its placeholder, the range slider with its
-- track and thumb, and the select row that opens the dropdown. They share the same label row, the same
-- off-duty fade and the same menu entry points, so they travel together.
-- The shared values come from Options.lua through ns.OptionControlsEnv; the rows are asked for while a
-- page is built, after every file has loaded.
local env = ns.OptionControlsEnv
local T = env.T
local BASE_FONT = env.baseFont
local CONTENT_W = env.contentW
local track = env.track
local tip = env.tip
local offDuty = env.offDuty
local dropdownFont = env.dropdownFont
local openDropdown = env.openDropdown
local isDropdownOpen = env.isDropdownOpen

function factories.input(parent, spec)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(28)

  local fs = track(Theme:Label(row, BASE_FONT, "text"), 0)
  fs:SetPoint("LEFT", 1, 0)
  fs:SetText(T(spec.name))

  local box = CreateFrame("EditBox", nil, row, "BackdropTemplate")
  ns.SnapBox(box, 66, 24, true)
  ns.SnapPoint(box, "TOPRIGHT", row, "TOPRIGHT", -1, -2)
  ns.PixelBackdrop(box)
  ns.SetBg(box, Theme:C("bg"))
  ns.SetEdge(box, Theme:C("stroke"))
  Theme:Track(box, function(s)
    ns.SetBg(s, Theme:C("bg"))
    s:SetTextColor(Theme:C("text"))
    if not s:HasFocus() then ns.SetEdge(s, Theme:C("stroke")) end
  end)
  box:SetFont(dropdownFont(), BASE_FONT - 1, ns.OutlineFlags())
  track(box, -1)
  box:SetTextColor(Theme:C("text"))
  box:SetJustifyH("CENTER")
  box:SetAutoFocus(false)
  box:SetNumeric(true)
  box:SetMaxLetters(4)

  row.Refresh = function()
    local on = not (spec.disabled and spec.disabled())
    box:EnableMouse(on)
    offDuty(row, not on)
    fs:SetText(T(spec.name))
    fs:SetTextColor(Theme:C(on and "text" or "faint"))
    box:SetTextColor(Theme:C(on and "text" or "faint"))
    if not box:HasFocus() then box:SetText(tostring(spec.get() or 0)) end
  end

  local function apply()
    if spec.disabled and spec.disabled() then return end
    local v = tonumber(box:GetText()) or spec.get() or 0
    if spec.min and v < spec.min then v = spec.min end
    if spec.max and v > spec.max then v = spec.max end
    spec.set(v)
    row.Refresh()
    Options:Refresh()
  end

  box:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
  -- Escape cancels the edit. ClearFocus fires OnEditFocusLost synchronously, which commits through
  -- apply(), so the typed text is reverted to the stored value first: apply then reads the current value
  -- back and the edit is a no-op. Refresh after, to redraw the reverted number.
  box:SetScript("OnEscapePressed", function(s)
    s:SetText(tostring(spec.get() or 0))
    s:ClearFocus()
    row.Refresh()
  end)
  box:SetScript("OnEditFocusGained", function(s) ns.SetEdge(s, Theme:C("accent")) end)
  box:SetScript("OnEditFocusLost", function(s)
    ns.SetEdge(s, Theme:C("stroke"))
    apply()
  end)

  row.Refresh()
  tip(row, spec.desc)
  return row
end

-- A coin amount typed in gold: the separators are drawn while typing, and once the field loses focus it
-- shows the same form as the rest of the addon (grouped or short, per Gold format). Stored in copper, so
-- a client whose money is small needs no second scale: the same number is 1g there and 1k here.
local function goldDigits(text)
  local digits = (text or ""):gsub("%D", "")
  if #digits > 12 then digits = digits:sub(1, 12) end
  local n = tonumber(digits) or 0
  if n > 999999999 then n = 999999999 end
  return n
end

local function groupGold(n)
  local mode = WarpeeDB and WarpeeDB.goldFormat or "commas"
  local sep = (mode == "dots" and ".") or (mode == "spaces" and " ") or ","
  local out = tostring(math.floor(n))
  local k
  repeat out, k = out:gsub("^(%d+)(%d%d%d)", "%1" .. sep .. "%2") until k == 0
  return out
end

function factories.money(parent, spec)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(28)

  local fs = track(Theme:Label(row, BASE_FONT, "text"), 0)
  fs:SetPoint("LEFT", 1, 0)
  fs:SetText(T(spec.name))

  -- spec.max is the row's ceiling in gold. The client's purse stops at 9,999,999, and a filter above that
  -- could only hide every character. It lives on the row so the Forever port can give it its own scale.
  local cap = spec.max
  -- The ceiling is also the most digits the field takes: 9,999,999 is seven, so the eighth is refused.
  local capDigits = cap and #tostring(math.floor(cap)) or nil

  local box = CreateFrame("EditBox", nil, row, "BackdropTemplate")
  ns.SnapBox(box, 92, 24, true)
  ns.SnapPoint(box, "TOPRIGHT", row, "TOPRIGHT", -1, -2)
  ns.PixelBackdrop(box)
  ns.SetBg(box, Theme:C("bg"))
  ns.SetEdge(box, Theme:C("stroke"))
  Theme:Track(box, function(s)
    ns.SetBg(s, Theme:C("bg"))
    s:SetTextColor(Theme:C("accentInk"))
    if not s:HasFocus() then ns.SetEdge(s, Theme:C("stroke")) end
  end)
  box:SetFont(dropdownFont(), BASE_FONT - 1, ns.OutlineFlags())
  track(box, -1)
  -- The number wears the colour the slider values wear, not the plain label colour: it is a gold figure,
  -- and the coin beside it is the file the money line draws, so the row reads as money at a glance.
  box:SetTextColor(Theme:C("accentInk"))
  box:SetJustifyH("CENTER")
  box:SetAutoFocus(false)
  -- Not numeric: the client's numeric box refuses the grouping separators this field draws.
  box:SetNumeric(false)
  -- The client's own letter limit is the ceiling, not a Lua check: seven digits plus the two separators
  -- grouping adds is the longest a valid entry can be, so a held key is refused by the EditBox itself and
  -- never reaches the handler -- no rewrite per repeat, nothing to flicker.
  box:SetMaxLetters(capDigits and capDigits + 2 or 14)
  local coin = row:CreateTexture(nil, "ARTWORK")
  coin:SetTexture("Interface\\AddOns\\Warpee\\Media\\Icons\\coin-gold")
  coin:SetSize(12, 12)
  coin:SetPoint("RIGHT", box, "LEFT", -6, 0)
  -- The resting zero is a placeholder, not text: an EditBox holding "0" puts a caret beside it on
  -- focus, and the stale text event puts it back, so the first typed digit shoved the zero aside.
  local ph = box:CreateFontString(nil, "OVERLAY")
  ph:SetFont(dropdownFont(), BASE_FONT - 1, ns.OutlineFlags())
  ph:SetPoint("CENTER")
  ph:SetText("0")
  ph:SetTextColor(Theme:C("faint"))
  Theme:Track(ph, function(s) s:SetTextColor(Theme:C("faint")) end)
  ph:Hide()
  box.wpePlaceholder = ph

  local function stored() return math.max(0, tonumber(spec.get()) or 0) end
  local function gold()
    local g = math.floor(stored() / 10000)
    if cap and g > cap then g = cap end
    return g
  end

  row.Refresh = function()
    local on = not (spec.disabled and spec.disabled())
    box:EnableMouse(on)
    offDuty(row, not on)
    fs:SetText(T(spec.name))
    fs:SetTextColor(Theme:C(on and "text" or "faint"))
    if box:HasFocus() then return end
    local g = gold()
    -- A saved value over the ceiling is cut back here, not only on the next edit: a 17 million left in the
    -- store would hide every purse until the player happened to touch the field again.
    if g * 10000 ~= stored() then spec.set(g * 10000) end
    -- Digits and separators at rest, never the short form: a box that can hold "9.9m" is a box whose text
    -- the field has to be able to read back, and one letter in it would be parsed as one gold. The same
    -- grouped text the edit shows also means focus does not change the number under the player's eyes.
    box.wpeBusy = true
    box:SetText(g > 0 and groupGold(g) or "")
    box.wpeBusy = nil
    ph:SetShown(g <= 0 and on)
    box:SetTextColor(Theme:C(on and "accentInk" or "faint"))
    coin:SetAlpha(on and 1 or 0.35)
  end

  local function apply()
    if spec.disabled and spec.disabled() then return end
    local raw = box:GetText() or ""
    -- A display form is not an edit: a letter left in the field (an old save, a text set from outside)
    -- must not be parsed as its digits, which would commit 500 for "500 к". Revert instead of guessing.
    if raw:find("[^%d%s%.,]") then row.Refresh(); return end
    local g = goldDigits(raw)
    if cap and g > cap then g = cap end
    spec.set(g * 10000)
    row.Refresh()
    Options:Refresh()
  end

  -- The text is rewritten on every keystroke so the grouping appears as it is typed. The guard stops
  -- SetText from re-entering this handler. A "short" format would turn 1000 into "1k" mid-edit and make
  -- the next digit invisible, so editing always shows digits with the user's own separator.
  box:SetScript("OnTextChanged", function(s)
    -- Only the player's own editing is regrouped. A programmatic SetText (Refresh's short form, the
    -- rebuild after a commit) can deliver OnTextChanged after wpeBusy is gone; regrouping "500 к" then
    -- reads 500 and writes it back, which is how a typed 500,000 collapsed to 500.
    if s.wpeBusy or not s:HasFocus() then return end
    -- Anything that is not a digit is dropped here: an empty entry is empty, not a zero, so a letter
    -- leaves the field blank instead of putting a zero in it. Past the ceiling's own digit count the
    -- extra stays out, so the field never holds a number that would have to be cut back later.
    local digits = goldDigits(s:GetText())
    if capDigits and #tostring(digits) > capDigits then
      digits = tonumber(tostring(digits):sub(1, capDigits)) or 0
    end
    local want = digits > 0 and groupGold(digits) or ""
    if want ~= s:GetText() then
      s.wpeBusy = true
      s:SetText(want)
      s:SetCursorPosition(#want)
      s.wpeBusy = nil
    end
  end)
  box:SetScript("OnEditFocusGained", function(s)
    ns.SetEdge(s, Theme:C("accent"))
    s:SetTextColor(Theme:C("accentInk"))
    ph:Hide()
    -- The resting text is already digits and separators, so this rewrite normally changes nothing; it
    -- stays for a field painted before a save landed.
    local g = gold()
    s.wpeBusy = true
    s:SetText(g > 0 and groupGold(g) or "")
    s:SetCursorPosition(#s:GetText())
    s.wpeBusy = nil
  end)
  box:SetScript("OnEditFocusLost", function(s)
    ns.SetEdge(s, Theme:C("stroke"))
    apply()
  end)
  box:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
  -- Escape reverts through the grouped digits, never through the short form: "1k" would parse as 1 gold
  -- when the focus loss commits it.
  box:SetScript("OnEscapePressed", function(s)
    local g = gold()
    s.wpeBusy = true
    s:SetText(g > 0 and groupGold(g) or "")
    s.wpeBusy = nil
    s:ClearFocus()
    row.Refresh()
  end)

  row.Refresh()
  tip(row, spec.desc)
  return row
end

function factories.range(parent, spec)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(46)

  local fs = track(Theme:Label(row, BASE_FONT, "text"), 0)
  fs:SetPoint("TOPLEFT", 1, -1)
  fs:SetText(T(spec.name))

  local val = track(Theme:Label(row, BASE_FONT, "accentInk"), 0)
  val:SetPoint("TOPRIGHT", -1, -1)

  local s = CreateFrame("Slider", nil, row)
  s:SetOrientation("HORIZONTAL")
  s:SetHeight(18)
  s:SetPoint("BOTTOMLEFT", 1, 2)
  s:SetPoint("BOTTOMRIGHT", -1, 2)
  s:SetValueStep(spec.step or 1)
  s:SetObeyStepOnDrag(true)

  local track_ = Theme:Rect(s, "panelHi", "BACKGROUND")
  track_:SetHeight(6)
  track_:SetPoint("LEFT", 0, 0)
  track_:SetPoint("RIGHT", 0, 0)

  local fill = Theme:Rect(s, "accent", "ARTWORK")
  fill:SetHeight(6)
  fill:SetPoint("LEFT", track_, "LEFT", 0, 0)

  local thumb = s:CreateTexture(nil, "OVERLAY")
  thumb:SetTexture(Theme.WHITE)
  thumb:SetVertexColor(Theme:C("accentInk"))
  thumb:SetSize(9, 18)
  s:SetThumbTexture(thumb)

  -- The floor moves: gaps start at caption room while names are on.
  local function minOf()
    local m = spec.min
    if type(m) == "function" then m = m() end
    return m or 0
  end
  -- Read back through the floor, so the thumb and the label never disagree.
  local function atLeastFloor()
    local v = tonumber(spec.get()) or 0
    local floor = minOf()
    return v < floor and floor or v
  end
  s:SetMinMaxValues(minOf(), spec.max)

  local function snap(v)
    local step = spec.step or 1
    local mn = minOf()
    local n = math.floor((v - mn) / step + 0.5)
    local out = mn + n * step
    if out > spec.max then out = spec.max elseif out < mn then out = mn end
    return out
  end

  local function label(v)
    if spec.format then return spec.format(v) end
    if (spec.step or 1) < 1 then return string.format("%.2f", v) end
    return tostring(v)
  end

  local function paint(v)
    val:SetText(label(v))
    local mn = minOf()
    local span = spec.max - mn
    local w = s:GetWidth() or 0
    fill:SetWidth(span > 0 and math.max(0.001, w * (v - mn) / span) or 0.001)
  end

  s:SetScript("OnValueChanged", function(sl, v)
    v = snap(v)
    paint(v)
    if sl.quiet then return end
    if math.abs((spec.get() or 0) - v) > 1e-4 then
      spec.set(v)
      local now = spec.get()
      if now and math.abs(now - v) > 1e-4 then
        sl.quiet = true
        sl:SetValue(now)
        sl.quiet = nil
        paint(now)
      end
      -- The value and the layout stay live, the row pass is coalesced. A drag is one step
      -- per pixel and every one of them refreshed all six pages: about a hundred rows and a
      -- profile capture each. One deferred pass does the same work once the slider is still.
      -- OnMouseUp would be the wrong hook, since a programmatic SetValue never raises it.
      Options:RefreshSoon()
    end
  end)
  s:SetScript("OnSizeChanged", function() paint(snap(s:GetValue())) end)
  s:SetScript("OnEnter", function(sl)
    if not sl.offDuty then thumb:SetVertexColor(Theme:C("text")) end
  end)
  s:SetScript("OnLeave", function(sl)
    if sl.offDuty then thumb:SetVertexColor(Theme:C("faint"))
    else thumb:SetVertexColor(Theme:Thumb()) end
  end)

  row.Refresh = function()
    local on = not (spec.disabled and spec.disabled())
    s.offDuty = not on
    offDuty(row, not on)
    s:EnableMouse(on)
    fs:SetText(T(spec.name))
    fs:SetTextColor(Theme:C(on and "text" or "faint"))
    val:SetTextColor(Theme:C(on and "accentInk" or "faint"))
    if on then thumb:SetVertexColor(Theme:Thumb())
    else thumb:SetVertexColor(Theme:C("faint")) end
    fill:SetVertexColor(Theme:C(on and "accent" or "strokeSoft"))
    s.quiet = true
    s:SetMinMaxValues(minOf(), spec.max)
    s:SetValue(atLeastFloor())
    s.quiet = nil
    paint(atLeastFloor())
  end
  row.Refresh()
  tip(row, spec.desc)
  row.slider = s
  return row
end

local function cycle(spec, dir)
  local keys = spec.keys()
  local cur, idx = spec.get(), 1
  for i, k in ipairs(keys) do if k == cur then idx = i; break end end
  idx = idx + dir
  if idx < 1 then idx = #keys elseif idx > #keys then idx = 1 end
  spec.set(keys[idx])
  if ns.Profiles and ns.Profiles.SyncActive then ns.Profiles:SyncActive() end
end

-- The set a multi row holds, read back into the control's width.
local function fitList(fs, text, maxW)
  fs:SetText(text)
  if maxW <= 0 or fs:GetStringWidth() <= maxW then return end
  local stops = ns.CharStops(text)
  local lo, hi, best = 1, #stops - 1, 0
  while lo <= hi do
    local mid = math.floor((lo + hi) / 2)
    fs:SetText(text:sub(1, stops[mid + 1]) .. "…")
    if fs:GetStringWidth() <= maxW then best = mid; lo = mid + 1 else hi = mid - 1 end
  end
  fs:SetText(best == 0 and "…" or (text:sub(1, stops[best + 1]) .. "…"))
end

function factories.select(parent, spec)
  local bare = (spec.name == nil or spec.name == "")
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(bare and 26 or 46)

  local nameFS
  if not bare then
    nameFS = track(Theme:Label(row, BASE_FONT, "text"), 0)
    nameFS:SetPoint("TOPLEFT", 1, -1)
    nameFS:SetText(T(spec.name))
  end

  local btn = CreateFrame("Button", nil, row, "BackdropTemplate")
  ns.SnapBox(btn, nil, 24)
  btn:SetPoint("BOTTOMLEFT", 1, bare and 1 or 0)
  btn:SetPoint("BOTTOMRIGHT", -1, bare and 1 or 0)
  ns.PixelBackdrop(btn)
  ns.SetBg(btn, Theme:C("panel"))
  ns.SetEdge(btn, Theme:C("stroke"))

  local cur = track(Theme:Label(btn, BASE_FONT - 1, "text"), -1)
  cur:SetPoint("LEFT", 7, 0)
  cur:SetPoint("RIGHT", -18, 0)
  cur:SetJustifyH("LEFT")

  local arrowBox = ns.ArrowGlyph(btn, "down", 9)
  arrowBox:SetPoint("RIGHT", -7, 0)
  local function arrowColor(key) arrowBox:SetTint(key) end

  row.Refresh = function()
    local off = (spec.disabled and spec.disabled()) and true or false
    row.off = off
    offDuty(row, off)
    if nameFS then nameFS:SetText(T(spec.name)) end
    -- A set has no single value, so it reads its set back, trimmed.
    if spec.summary then
      local w = (btn:GetWidth() > 0 and btn:GetWidth() or CONTENT_W) - 25
      fitList(cur, spec.summary(), w)
    else
      cur:SetText(T(spec.label(spec.get())) or "")
    end
    cur:SetTextColor(Theme:C(off and "faint" or "text"))
    ns.SetBg(btn, Theme:C("panel"))
    ns.SetEdge(btn, Theme:C(off and "strokeSoft" or "stroke"))
    arrowColor(off and "faint" or "dim")
    btn:SetEnabled(not off)
  end
  btn.wpeDrop = { spec = spec, onPick = row.Refresh }
  row.Refresh()

  btn:SetScript("OnEnter", function(s)
    local open = isDropdownOpen(s)
    if spec.desc and not open then ns.ShowTip(row, { { text = spec.desc } }, "top") end
    if row.off then return end
    ns.SetBg(s, Theme:C("panelHi"))
    ns.SetEdge(s, Theme:C("accent"))
    arrowColor("accent")
  end)
  btn:SetScript("OnLeave", function(s)
    ns.HideTip()
    if row.off then return end
    ns.SetBg(s, Theme:C("panel"))
    ns.SetEdge(s, Theme:C("stroke"))
    arrowColor("dim")
  end)
  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  btn:SetScript("OnClick", function(s, button)
    if row.off then return end
    -- A set has no next value, so right click stays with single picks.
    if button == "RightButton" then
      if spec.summary then return end
      cycle(spec, -1)
      row.Refresh()
      return
    end
    openDropdown(s, spec, row.Refresh)
  end)
  tip(row, spec.desc)
  return row
end

