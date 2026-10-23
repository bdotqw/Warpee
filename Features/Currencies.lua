local addonName, ns = ...
local Theme = ns.Theme

-- The currencies the client itself tracks ("show in backpack"), drawn as one row of slot-sized cells
-- inside the window's own content, under the grid, seamed off from it by the same hairline the category
-- sections wear. Icon and count per currency, in the client's own order, wrapped onto as many lines as the
-- grid's width fits -- nothing is counted away behind a "+N": what is tracked is what is drawn. The row
-- grows the way the player chose: left to right, right to left (mirrored, the first at the right edge), or
-- centred a line at a time.
--
-- The window owns the height: Measure answers how tall the row stands for a given cell size and width,
-- the layout adds that to its content and seats the row with Place. It takes a row of the window, unlike
-- the old bar that hung off the foot and spent no pixel of it.
--
-- Why the client's list and not an own one: the track flag lives in the character panel, and a second
-- list beside it means two editors that disagree -- a tick here that the panel there never saw, and five
-- pins there that come back on the next login after being taken off here. So a tick here IS the client's
-- flag (C_CurrencyInfo.SetCurrencyBackpackByID both ways), the row reads the client's own tracking list
-- (GetBackpackCurrencyInfo, the same source the game's own backpack strip reads), and the panel behind
-- it (Features/CurrencyPicker.lua) ticks the same flag per row.
--
-- The transfer door lives in that panel, on the rows the client marks transferable
-- (isAccountTransferable): an arrow that walks to the game's own currency tab, where the transfer click
-- itself stays the player's own.
--
-- What is read when: the row never walks the client's currency list -- one GetBackpackCurrencyInfo per
-- tracked currency, in the client's order. Walking the whole list means expanding collapsed headers, and
-- every one of those calls fires CURRENCY_DISPLAY_UPDATE -- the event the row answers; that walk lives
-- in the picker, runs only while its window is open, and holds a reentrancy flag (CurrencyPicker:Scan).

local Cur = {}
ns.Cur = Cur

local CHIP_GAP  = 12   -- cell to cell, both ways
local MAX_WATCH = 40   -- the read stops at the first empty slot; this is only the ceiling it never climbs

local pending

------------------------------------------------------------------------------
-- Reading (pure: the API table is handed in)
------------------------------------------------------------------------------
-- The client's own tracking list, in its own order: the entry GetBackpackCurrencyInfo answers with.
-- Stops at the first slot the client leaves empty (it returns nothing past its list).
function Cur.ReadWatched(CI, out)
  wipe(out)
  if not (CI and CI.GetBackpackCurrencyInfo) then return out end
  for i = 1, MAX_WATCH do
    local pin = CI.GetBackpackCurrencyInfo(i)
    if not pin then break end
    local id = pin.currencyTypesID
    if id then
      out[#out + 1] = {
        id = id,
        name = pin.name or "",
        icon = pin.iconFileID,
        q = pin.quantity or 0,
      }
    end
  end
  return out
end

-- The client's whole currency list, walked with every collapsed header opened first, because
-- GetCurrencyListInfo only answers for the sections that are open. `expanded` comes back holding the
-- headers this had to open, so the caller can put the player's panel back the way it found it (see
-- Cur.RestoreList). Section names are kept as heading rows -- the panel draws them, the row ignores
-- them. Each row carries the client's own flags: `watched` is the backpack pin the row reads,
-- `transfer` marks a currency another character can send over.
function Cur.WalkList(CI, out, expanded)
  wipe(out)
  if not (CI and CI.GetCurrencyListSize and CI.GetCurrencyListInfo) then return out, expanded end
  -- First pass: open. The list grows as it opens, so the size is re-read on every step, which also walks
  -- the sections a section reveals (nested headers included).
  local i = 1
  while i <= (CI.GetCurrencyListSize() or 0) do
    local e = CI.GetCurrencyListInfo(i)
    if e and e.isHeader and not e.isHeaderExpanded and CI.ExpandCurrencyList then
      CI.ExpandCurrencyList(i, true)
      if expanded then expanded[#expanded + 1] = i end
    end
    i = i + 1
  end
  -- Second pass: read. Everything here is the client's own words and order, so the panel and the game's
  -- own currency tab can never disagree about a name or a count.
  --
  -- Depth rides alongside: the client answers a flat, already-ordered list, and `headerIndex` names the
  -- entry each row sits under -- for a header, its parent section, and for a currency, its section. One
  -- pass holds every parent's own depth before its children are read, so a header whose parent is a header
  -- is a subgroup (level two and deeper). The panel reads a level to tell a group from a subgroup; a client
  -- that answers no `headerIndex` leaves every header at level one, which is the flat list it always was.
  local level = {}
  for idx = 1, (CI.GetCurrencyListSize() or 0) do
    local e = CI.GetCurrencyListInfo(idx)
    if e then
      local lv = 1
      local parent = e.headerIndex
      if parent and parent > 0 and level[parent] then lv = level[parent] + 1 end
      level[idx] = lv
      if e.isHeader then
        if e.name and e.name ~= "" then out[#out + 1] = { header = true, name = e.name, level = lv } end
      elseif e.currencyID then
        out[#out + 1] = {
          id = e.currencyID,
          name = e.name or "",
          icon = e.iconFileID,
          q = e.quantity or 0,
          max = e.maxQuantity or 0,
          watched = e.isShowInBackpack and true or nil,
          transfer = e.isAccountTransferable and true or nil,
          found = e.discovered ~= false,
          level = lv,
        }
      end
    end
  end
  return out, expanded
end

-- Puts the client's sections back the way they stood. Reverse order on purpose: collapsing a later header
-- does not move the ones before it, so the recorded indices still point where they did.
function Cur.RestoreList(CI, expanded)
  if not (CI and CI.ExpandCurrencyList and expanded) then return end
  for k = #expanded, 1, -1 do CI.ExpandCurrencyList(expanded[k], false) end
end

-- The count as the client writes it in its own tracker: thousands separated, and folded once the line
-- would run past its budget. The fold is ns.ShortCount, the cell's own writing: exact to four digits,
-- one letter and never past three from ten thousand. The coin line is written with its own short form
-- (ns.ShortNumber); this badge only has to fit.
function Cur.CountText(q, budget)
  q = tonumber(q) or 0
  budget = tonumber(budget) or 5
  local text = (BreakUpLargeNumbers and BreakUpLargeNumbers(q)) or tostring(math.floor(q))
  if #text > budget then
    text = ns.ShortCount(q)
  end
  return text
end

------------------------------------------------------------------------------
-- The flag (both ways: a tick here is the character panel's own pin)
------------------------------------------------------------------------------
-- The player's own display order, kept by the profile: watched ids in the arrangement the cells were
-- dragged into. Ids the order does not know stand at the tail, in the client's order, so a fresh pin
-- lands right. A seat is forgotten the moment tracking stops, from either side -- a re-track is a new pin
-- and stands at the tail, never back where it stood.
function Cur.Order()
  if not (WarpeeDB and type(WarpeeDB.curOrder) == "table") then
    if WarpeeDB then WarpeeDB.curOrder = {} else return {} end
  end
  return WarpeeDB.curOrder
end

-- The way the row grows, the player's own pick: left to right the plain walk, right to left the mirror
-- (the first currency at the right edge, the row growing left), from the middle the block centred a line
-- at a time. Anything else -- an old profile, a stale value -- reads as the factory choice: from the middle.
function Cur.Dir()
  local d = WarpeeDB and WarpeeDB.curDir
  if d == "ltr" or d == "rtl" or d == "center" then return d end
  return "center"
end

function Cur:Remember(id)
  if not id then return end
  local o = Cur.Order()
  for i = 1, #o do if o[i] == id then return end end
  o[#o + 1] = id           -- a fresh pin takes the tail
end

-- The seat is gone the moment tracking stops: a re-track is a new pin, not a homecoming.
function Cur.Forget(id)
  if not id then return end
  local o = Cur.Order()
  for i = #o, 1, -1 do if o[i] == id then table.remove(o, i) end end
end

-- Move the carried cell ahead of `target`, or to the end when it lands on bare content. A drop on
-- itself changes nothing.
function Cur:MoveOrder(from, target)
  if not from then return end
  local o = Cur.Order()
  for i = #o, 1, -1 do if o[i] == from then table.remove(o, i) end end
  if target and target ~= from then
    local to = #o + 1
    for i = 1, #o do if o[i] == target then to = i; break end end
    table.insert(o, to, from)
  else
    o[#o + 1] = from
  end
  Cur:Apply(true)
end

-- The player's own order over the client's: watched ids the order remembers keep their seats, and every
-- id the order has never met takes the tail after them, in the client's own order, so a fresh pin lands
-- at the right end of the row. Pruned first: an untrack from the character tab never passes this file, so
-- its seat would linger here and hand the re-track its old place, middle or tail included; forgetting it
-- here means a re-track stands fresh at the tail.
function Cur.Sort(rows)
  local order = Cur.Order()
  do
    local live = {}
    for i = 1, #rows do live[rows[i].id] = true end
    local k = 0
    for i = 1, #order do if live[order[i]] then k = k + 1; order[k] = order[i] end end
    for i = #order, k + 1, -1 do order[i] = nil end
  end
  local pos = {}
  for i = 1, #order do if pos[order[i]] == nil then pos[order[i]] = i end end
  local fresh = {}
  for i = 1, #rows do
    if not pos[rows[i].id] then fresh[#fresh + 1] = rows[i].id end
  end
  for i = 1, #fresh do order[#order + 1] = fresh[i] end
  if #fresh > 0 then
    wipe(pos)
    for i = 1, #order do if pos[order[i]] == nil then pos[order[i]] = i end end
  end
  table.sort(rows, function(a, b) return (pos[a.id] or 0) < (pos[b.id] or 0) end)
end

function Cur:SetWatched(id, on)
  if not (id and C_CurrencyInfo and C_CurrencyInfo.SetCurrencyBackpackByID) then return false end
  on = on and true or false
  -- No cap here on purpose: nobody keeps one -- the flag is set blind and the client sorts out what
  -- its own backpack fits.
  if on then Cur:Remember(id) end
  if not on then Cur.Forget(id) end
  C_CurrencyInfo.SetCurrencyBackpackByID(id, on)
  -- The client sends no event for a tracking change (its own frames repaint by hand after the same
  -- call), so the row and the panel repaint here, at once, instead of waiting for a reload.
  Cur:Apply(true)
  return true
end

------------------------------------------------------------------------------
-- The transfer door (a pointer, not a push: the window is protected)
------------------------------------------------------------------------------
-- The transfer itself (RequestCurrencyFromAccountCharacter) is a protected call: it only runs on an
-- untainted path, and opening the game's CurrencyTransferMenu from addon code taints that path -- the
-- game's own confirm button then dies with ADDON_ACTION_FORBIDDEN naming us. So the door only walks the
-- player to the game's own currency tab; the transfer click itself stays the player's own, untainted.
function Cur:OpenTransfer(id)
  if not id then return end
  -- The currency tab is protected, so walking to it is left alone in combat: a Ctrl-click there answers
  -- nothing rather than reaching for a frame the client will refuse.
  if InCombatLockdown and InCombatLockdown() then return end
  if not ToggleCharacter then return end
  -- The door only ever opens: pressing it with the tab already standing would shut the very window the
  -- player asked for, which is what a plain ToggleCharacter does.
  if TokenFrame and CharacterFrame and CharacterFrame:IsShown() and TokenFrame:IsShown() then return end
  ToggleCharacter("TokenFrame")
end

------------------------------------------------------------------------------
-- The quick transfer: Ctrl-click on a cell, done by the client's own buttons
------------------------------------------------------------------------------
-- C_CurrencyInfo.RequestCurrencyFromAccountCharacter is AllowedWhenUntainted: a currency id written by
-- addon Lua, or the transfer menu opened from it, taints the path and the game's own confirm button dies
-- with ADDON_ACTION_FORBIDDEN (Features/CurrencyTransferDoor.lua keeps that note). So nothing here touches
-- the client's state. The cell is an InsecureActionButtonTemplate, and a Ctrl-click asks the *client* to
-- click two of its own frames -- the currency's row in the character panel, which selects it and fills the
-- popup, and the popup's transfer toggle, which opens the menu -- both in the client's own, untainted
-- context. The addon only names frames.
local XFER_SOUNDS = { 567422, 567507, 567433 }   -- character info tab, open, close
local XFER_TOKEN = {}                            -- the layout callback token this file books with
local function xferMute()
  for i = 1, #XFER_SOUNDS do MuteSoundFile(XFER_SOUNDS[i]) end
end
local function xferUnmute()
  C_Timer.After(0, function()
    for i = 1, #XFER_SOUNDS do UnmuteSoundFile(XFER_SOUNDS[i]) end
  end)
end

-- The client's own row for a currency. Its scroll box builds only the rows its own height covers, and the
-- wanted currency may sit far down the list, so the list is laid out whole for the moment it takes to read
-- the row: the two panels are parented where a layout may happen, the box is stretched over every entry,
-- and everything is put back as soon as the row is read -- the row is the only thing that can select a
-- currency without tainting it.
--
-- The answer may come late, and that is the whole of the first Ctrl-click of a session: a client that has
-- never shown the currency tab lays its list out a frame or two after the panels stand, so reading the row
-- here and putting the panels back on the very next frame answered nothing at all -- the cell stayed
-- unarmed, its press fell back to the tab, and only the second press reached the menu. So `onRow` is
-- called with whatever the layout eventually reads (right away when the list is already warm), and the
-- panels are held until then -- bounded, so a client that answers no layout at all still gets them back.
local function clientRow(id, onRow)
  local CI = C_CurrencyInfo
  local TF, popup = _G.TokenFrame, _G.TokenFramePopup
  local sb = TF and TF.ScrollBox
  local toggle = popup and popup.CurrencyTransferToggleButton
  if not (id and CI and sb and toggle and CharacterFrame and sb.GetFrames
          and BaseScrollBoxEvents and sb.RegisterCallback) then return nil end
  local row
  local ok = pcall(function()
    -- The client's own index for this currency, opening the sections on the way: a currency inside a
    -- collapsed section is not in the list at all, and the index moves as the sections open.
    local index
    local i = 0
    while i < (CI.GetCurrencyListSize() or 0) do
      i = i + 1
      local info = CI.GetCurrencyListInfo(i)
      if info then
        if info.isHeader then
          if not info.isHeaderExpanded and CI.ExpandCurrencyList then CI.ExpandCurrencyList(i, true) end
        else
          local link = CI.GetCurrencyListLink and CI.GetCurrencyListLink(i)
          local cid = link and CI.GetCurrencyIDFromLink and CI.GetCurrencyIDFromLink(link)
          if cid == id then index = i; break end
        end
      end
    end
    if not index then return end

    local characterParent, tokenParent = CharacterFrame:GetParent(), TF:GetParent()
    local characterShown, tokenShown = CharacterFrame:IsVisible(), TF:IsVisible()
    local done, waits
    local function putBack()
      if done then return end
      -- The list is still laying out: the panels stand only until the row is read, and never longer than
      -- a score of frames -- a client that answers no layout at all gets its panels back by the count.
      if not row and waits and waits < 20 then
        waits = waits + 1
        C_Timer.After(0, putBack)
        return
      end
      done = true
      sb:ClearAllPoints()
      sb:SetPoint("TOPLEFT", CharacterFrame.Inset, 4, -4)
      sb:SetPoint("BOTTOMRIGHT", CharacterFrame.Inset, -22, 2)
      -- Dot calls on the frames' own SetParent: a UI overhaul can replace the method on these two, and
      -- the C function behind it is what actually moves them.
      CharacterFrame.SetParent(CharacterFrame, characterParent)
      TF.SetParent(TF, tokenParent)
      HideUIPanel(TF)
      HideUIPanel(CharacterFrame)
      if tokenShown then ShowUIPanel(TF) end
      if characterShown then ShowUIPanel(CharacterFrame) end
      xferUnmute()
    end

    xferMute()
    HideUIPanel(CharacterFrame)
    HideUIPanel(TF)
    CharacterFrame.SetParent(CharacterFrame, UIParent)
    TF.SetParent(TF, CharacterFrame)
    sb:ClearAllPoints()
    sb:SetHeight(30 * (CI.GetCurrencyListSize() or 1))   -- 30: taller than any row the client draws
    sb:SetWidth(200)
    sb:SetPoint("TOPLEFT", UIParent)
    sb:RegisterCallback(BaseScrollBoxEvents.OnLayout, function()
      sb:UnregisterCallback(BaseScrollBoxEvents.OnLayout, XFER_TOKEN)
      local frames = sb:GetFrames()
      row = frames and frames[index]
      putBack()
      if onRow then onRow(row) end
    end, XFER_TOKEN)
    ShowUIPanel(CharacterFrame)
    ShowUIPanel(TF)
    waits = 0
    C_Timer.After(0, putBack)
  end)
  if not ok then return nil end
  return row
end

-- The frames this chain names -- TokenFrame, TokenFramePopup, CurrencyTransferMenu -- live in
-- Blizzard_TokenUI, a load-on-demand addon the client only pulls in when the currency tab is first
-- opened. Before that the very first Ctrl-click found no frames to arm, fell back to the tab, and made
-- the player click twice: the first click loading the client's own UI, the second reaching the menu. So
-- the addon is pulled in quietly at login, and again, out of combat, on the hover that finds nothing.
local TOKEN_UI = "Blizzard_TokenUI"
local function tokenUI()
  if _G.TokenFramePopup then return true end
  if InCombatLockdown() then return nil end
  pcall(function()
    if C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn(TOKEN_UI) end
  end)
  return _G.TokenFramePopup and true or nil
end

do
  local boot = CreateFrame("Frame")
  boot:RegisterEvent("ADDON_LOADED")
  local function ask()
    -- Quietly, before the first Ctrl-click ever needs it; never in combat.
    if InCombatLockdown() then return end
    pcall(function()
      if C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn(TOKEN_UI) end
    end)
  end
  boot:SetScript("OnEvent", function(_, name)
    if name == addonName then
      boot:UnregisterEvent("ADDON_LOADED")
      ask()                       -- may be refused while the loading screen stands
    elseif name == "PLAYER_LOGIN" then
      boot:UnregisterEvent("PLAYER_LOGIN")
      if not _G.TokenFramePopup then ask() end   -- the second chance, now that the screen is down
    end
  end)
  boot:RegisterEvent("PLAYER_LOGIN")
end

-- Armed and left holding: the armed cell, so the disarm above can follow the key out.
local watch, armWatch

-- Arms one cell for the client's own click chain. The press and the release are two different targets,
-- and that is the whole chain: the press clicks the currency's own row in the character panel (which
-- selects it), the release clicks the popup's transfer toggle (which opens the transfer menu for it). Both
-- clicks are the client's own, in the client's own context -- the addon only names the frames. It runs on
-- the Ctrl-hover that comes before the press (the arming lays the client's currency list out off screen,
-- the expensive half), and a cell that was never armed carries no attributes at all -- its click can never
-- reach the client's transfer by accident.
--
-- Why the release is the plain clickbutton: a modifier-prefixed release dies the moment the player lets go
-- of Ctrl before the mouse button, and a Ctrl held for the press but gone at the release is most players.
-- That was the difference between the two windows: a Ctrl-only release answered with the popup alone (the
-- row was selected, the toggle was never clicked), so the player saw the options flyout and had to press
-- again. The press target stays the Ctrl one, so a plain press never reaches the chain at all -- and the
-- disarm follows the key out of the press (see armWatch), so a release that fires with Ctrl gone still
-- lands on the toggle that belongs to the currency just armed.
-- One layout at a time: the list is laid out whole to read a row, and a pointer crossing several rows
-- quickly would open as many layouts. The last want wins -- it is the one a press would be aimed at -- and
-- whatever arrives arms the row it names, or asks again for the row the pointer moved on to while the list
-- was laying out (the list is warm by then, so that second ask answers inside the same frame).
local xferBusy
function Cur:ArmTransfer(cell, id)
  if not (cell and id and cell.SetAttribute) then return end
  if InCombatLockdown() or not tokenUI() then return end
  local toggle = _G.TokenFramePopup and _G.TokenFramePopup.CurrencyTransferToggleButton
  if not toggle or xferBusy then return end
  -- A call from outside the hover is a want too: the row it names is the one the press would be aimed at.
  if not (Cur.wantArm and Cur.wantArm.cell == cell) then Cur.wantArm = { cell = cell, id = id } end
  local token = {}
  xferBusy = token
  -- A client that answers no layout at all (or a currency the list does not hold) must not leave the
  -- arming closed for the rest of the session.
  C_Timer.After(0.5, function()
    if xferBusy == token then xferBusy = nil end
  end)
  clientRow(id, function(row)
    if xferBusy == token then xferBusy = nil end
    if not row then return end
    local want = Cur.wantArm
    if not (want and want.cell == cell and want.id == id) then
      -- The pointer moved on to another row while the list was laying out: that row wants the same door,
      -- and the list is warm now, so its own ask is answered inside the same frame it is made.
      if want then Cur:ArmTransfer(want.cell, want.id) end
      return
    end
    if InCombatLockdown() then return end
    cell:SetAttribute("pressAndHoldAction", true)
    cell:SetAttribute("clickbutton", toggle)
    cell:SetAttribute("ctrl-clickbutton-startup", row)
    cell.wpeArmed = true
    Cur.armed = cell
    armWatch()
  end)
end

function Cur:DisarmTransfer(cell, leaving)
  cell = cell or Cur.armed
  if not cell then return end
  if cell.SetAttribute then
    cell:SetAttribute("clickbutton", nil)
    cell:SetAttribute("ctrl-clickbutton-startup", nil)
  end
  cell.wpeArmed = nil
  -- The cell leaving the pointer is the only one whose want is dropped: a Ctrl let go keeps the want, so
  -- the next Ctrl press over the same row arms it again without a second hover.
  local want = Cur.wantArm
  if leaving and want and want.cell == cell then Cur.wantArm = nil end
  if Cur.armed == cell then Cur.armed = nil end
end

-- A hover wants the transfer whether or not Ctrl is down yet. The arm has to stand before the press, so a
-- player who hovers first and presses Ctrl after would otherwise be answered with the fallback -- the
-- currency tab -- for that one click, and would need a second press to reach the menu. So the want is
-- remembered, and the watcher above arms it the moment the key goes down.
function Cur:WantTransfer(cell, id)
  if not (cell and id) then return end
  -- Combat has no transfer door at all: the hover neither remembers a want nor arms the cell, so a
  -- Ctrl-press in combat can never reach the client's protected chain.
  if InCombatLockdown and InCombatLockdown() then return end
  Cur.wantArm = { cell = cell, id = id }
  if IsControlKeyDown and IsControlKeyDown() then Cur:ArmTransfer(cell, id) end
end

-- The release target is the plain clickbutton, so the disarm follows the key rather than the pointer: the
-- moment Ctrl is let go, the armed cell loses its attributes. A plain press on a row whose holder stopped
-- holding Ctrl can then never open the client's menu on its own.
armWatch = function()
  if watch then return end
  watch = CreateFrame("Frame")
  watch:RegisterEvent("MODIFIER_STATE_CHANGED")
  -- An arm made before combat would keep its click attributes through the lockdown, and those would
  -- still ask the client's protected chain for a transfer. Entering combat drops the arm and the want.
  watch:RegisterEvent("PLAYER_REGEN_DISABLED")
  watch:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
      Cur.wantArm = nil
      Cur:DisarmTransfer()
      return
    end
    local down = IsControlKeyDown and IsControlKeyDown()
    if Cur.armed and not down then
      Cur:DisarmTransfer()
      return
    end
    local want = Cur.wantArm
    if down and want and not Cur.armed then Cur:ArmTransfer(want.cell, want.id) end
  end)
end

-- The watcher stands from the load, not from the first arm: the hover that wants the transfer is a hover
-- made with Ctrl still up, so the key-down is the only thing that can arm it -- and a watcher born inside
-- that same key-down would never hear it. Without this the first Ctrl-click of a session reaches the
-- fallback and opens the currency tab, and only the second one lands on the menu.
armWatch()

-- The client's transfer menu is a frame of its own and it stands while the transfer runs and after it;
-- what it cannot do on its own is stay off the currency tab it was born in, because that tab is hidden by
-- the arming. The menu is set beside the character panel and left to the client, so nothing closes it and
-- nothing taints the confirm.
function Cur:PlaceTransfer()
  -- The menu lives on the protected currency tab, so moving it is left alone in combat as well.
  if InCombatLockdown and InCombatLockdown() then return end
  local popup = _G.TokenFramePopup
  if not (popup and CharacterFrame and popup.SetPoint) then return end
  local function place()
    if not popup:IsShown() then return end
    if popup.ClearAllPoints then popup:ClearAllPoints() end
    popup:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", 3, -28)
  end
  -- The menu is filled inside the click's own frame, so the anchor is asked for twice: once now and once
  -- after the client has drawn it.
  place()
  if C_Timer and C_Timer.After then C_Timer.After(0, place) end
end

-- Only the client's own flag decides whether a cell offers the transfer at all.
function Cur.Transferable(id)
  local CI = C_CurrencyInfo
  return (id and CI and CI.IsAccountTransferableCurrency and CI.IsAccountTransferableCurrency(id)) and true or nil
end

------------------------------------------------------------------------------
-- The cell
------------------------------------------------------------------------------
-- The window's own icon zoom, texcoords only: the cell keeps its anchors, only the crop moves --
-- the same unit the slots zoom by (see ApplyIconZoom), so a zoomed bag zooms its purse with it.
local ZOOM_UNIT = 1.19
local function zoomIcon(icon)
  local z = (ns.Bags and ns.Bags.iconZoom or 1) * ZOOM_UNIT
  if z > 1 then
    local t = (1 - 1 / z) / 2
    icon:SetTexCoord(t, 1 - t, t, 1 - t)
  else
    icon:SetTexCoord(0, 1, 0, 1)
  end
end

------------------------------------------------------------------------------
-- Carrying (the addon's own reorder language: lift, float, mark the seat)
------------------------------------------------------------------------------
-- The painters live below this pass, but the pass calls them: Lua does not hoist locals, so a
-- function declared up here would only see empty globals under those names. The seats are booked
-- here, the bodies fill them below.
local chipEdge, paintEdge, chipRing, chipKey, ringJob, paintRing, restEdge, hotEdge

-- The cursor, in the window frame's own coordinates: x from the left edge, y downward from the top.
-- nil while the scale is not ready, so every caller bails instead of guessing.
local function cursorAt(row)
  local frame = row.frame
  if not frame then return nil end
  local s = frame:GetEffectiveScale()
  if not s or s == 0 then return nil end
  local cx, cy = GetCursorPosition()
  local l, t = frame:GetLeft(), frame:GetTop()
  if not (cx and l and t) then return nil end
  return cx / s - l, t - cy / s
end

-- The cell count, wrapped: the tracked chips and the add door. The door always holds the seat past the
-- last coin, so it follows the row's growth like one more cell -- rightmost on a plain walk, leftmost
-- when mirrored, the right end of the block when the row grows from the middle. Without a currency the
-- row is no row at all (Measure answers zero), so the door never stands alone.
local function seats(row)
  return #(row.rows or {}) + (row.plus and 1 or 0)
end

-- How many seats one wrapped line carries: a full `cols` until the last line, which holds the remainder.
local function lineCount(n, cols, line)
  local c = n - line * cols
  if c > cols then c = cols end
  if c < 0 then c = 0 end
  return c
end

-- Where seat `k` (0-based) stands, in the window frame's own coordinates, for the row's growth direction.
-- Left to right is the plain walk; right to left right-aligns every line and reverses it, so the first
-- currency sits at the right edge and the row grows left; from the middle centres each line, so a short
-- last line stands centred rather than flush left.
local function seatAt(row, k)
  local cols = row.cols or 1
  local size, gap = row.size or 30, row.gap or CHIP_GAP
  local step = size + gap
  local n = seats(row)
  local line = math.floor(k / cols)
  local p = k % cols
  local cnt = lineCount(n, cols, line)
  local gw = row.gridW or (cols * step - gap)
  local blockW = cnt * step - gap
  local dir = row.dir or "ltr"
  local off = 0
  if dir == "rtl" then off = gw - blockW; p = cnt - 1 - p
  elseif dir == "center" then off = (gw - blockW) / 2 end
  return (row.x0 or 0) + off + p * step, (row.top or 0) + line * step
end

-- The seat the held cell would land ahead of, read off the cursor over the wrapped grid: the line the
-- cursor's y falls in, then the column its x falls in out of the seats that line actually carries. Past
-- the seats the answer is one past them. The column is read back into the row's own order by the growth
-- direction, so a drop lands where the eye points whichever way the row grows. Shown seats only.
local function dropSlot(row)
  local cx, cy = cursorAt(row)
  if not cx then return nil end
  local size, gap, cols = row.size or 30, row.gap or CHIP_GAP, row.cols or 1
  local step = size + gap
  local n = seats(row)
  local lastLine = math.floor((n - 1) / cols)
  local line = math.floor((cy - (row.top or 0) + gap / 2) / step)
  if line < 0 then line = 0 elseif line > lastLine then line = lastLine end
  local cnt = lineCount(n, cols, line)
  local gw = row.gridW or (cols * step - gap)
  local blockW = cnt * step - gap
  local dir = row.dir or "ltr"
  local off = 0
  if dir == "rtl" then off = gw - blockW
  elseif dir == "center" then off = (gw - blockW) / 2 end
  -- The row starts at the content's left edge, not at the window's own: without taking `x0` out the
  -- whole index sat a fraction of a cell to the right of the hand, so the mark and the drop both landed
  -- one seat past the point the player was pointing at.
  local p = math.floor((cx - (row.x0 or 0) - off + gap / 2) / step)
  if p < 0 then p = 0 elseif p > cnt then p = cnt end
  local slot
  if dir == "rtl" then slot = line * cols + (cnt - p) + 1 else slot = line * cols + p + 1 end
  if slot > n + 1 then slot = n + 1 end
  return slot
end

-- The seat's mark, on its own thin frame lifted above the cells: a texture on the window would draw
-- under them and vanish on a cell's own edge.
local function dropMark(row)
  local m = row.dropMark
  if m then return m end
  m = CreateFrame("Frame", nil, row.frame)
  ns.SnapSize(m, 2, 30)
  m:SetFrameLevel((row.frame:GetFrameLevel() or 1) + 20)
  local line = Theme:Rect(m, "accent", "OVERLAY")
  line:SetAllPoints(m)
  m:Hide()
  row.dropMark = m
  return m
end

local function dragUpdate(row)
  local id = row.dragId
  if not id then return end
  local cx, cy = cursorAt(row)
  if cx then
    local size, gap, cols = row.size or 30, row.gap or CHIP_GAP, row.cols or 1
    local step = size + gap
    local fx = cx - (row.grabOff or 0)
    local fy = cy - (row.grabY or 0)
    -- Half a cell of overhang past the outer seats: the middle must cross the outer line, or the
    -- first and last seats stay unreachable no matter how far the eye pushes.
    local n = seats(row)
    local lastLine = math.floor((n - 1) / cols)
    local gw = row.gridW or (cols * step - gap)
    local lo, hi
    if (row.dir or "ltr") == "ltr" then
      -- The right-hand wall is the last column the row actually fills: a row that does not fill its last
      -- line stops at its own last seat, so the carried cell travels right across the whole line instead
      -- of running off into the empty columns past the end of the row.
      local lastCol = math.min(cols - 1, n - 1)
      lo, hi = (row.x0 or 0) - size / 2, (row.x0 or 0) + lastCol * step + size / 2
    else
      -- A mirrored or centred row is read the other way: its cells span the width, so the wall is the
      -- row's own width, not a left column count.
      lo, hi = (row.x0 or 0) - size / 2, (row.x0 or 0) + gw + size / 2
    end
    local vo, vh = (row.top or 0) - size / 2, (row.top or 0) + lastLine * step + size / 2
    if fx < lo then fx = lo elseif fx > hi then fx = hi end
    if fy < vo then fy = vo elseif fy > vh then fy = vh end
    for i = 1, #row.chips do
      local c = row.chips[i]
      if c and c.wpeID == id then
        c:ClearAllPoints()
        ns.SnapPoint(c, "TOPLEFT", row.frame, "TOPLEFT", fx, -fy)
        break
      end
    end
  end
  local slot = dropSlot(row)
  local idx = row.dragIdx
  -- Its own seat takes no marker: a drop there moves nothing, and both edges of that seat are the same
  -- non-move, so the mark would read as two targets where it would land anyway.
  if idx and (slot == idx or slot == idx + 1) then slot = nil end
  row.dropTo = slot
  local m = dropMark(row)
  if slot then
    local size, gap = row.size or 30, row.gap or CHIP_GAP
    local n = seats(row)
    local bx, by
    if (row.dir or "ltr") == "rtl" then
      -- Mirrored: the boundary before a seat stands to the RIGHT of the cell that precedes it, and the
      -- boundary ahead of the first seat stands at the far right edge.
      local k = math.max(0, math.min(slot - 2, n - 1))
      bx, by = seatAt(row, k)
      if slot <= 1 then bx = bx + size + gap / 2 else bx = bx - gap / 2 end
    else
      local k = math.min(slot - 1, n - 1)
      bx, by = seatAt(row, k)
      if slot > n then bx = bx + size + gap / 2 else bx = bx - gap / 2 end
    end
    m:ClearAllPoints()
    ns.SnapSize(m, 2, size - 8)
    ns.SnapPoint(m, "TOPLEFT", row.frame, "TOPLEFT", bx - 1, -(by + 4))
    m:Show()
  else
    m:Hide()
  end
end

local function beginDrag(row, s)
  local id = s.wpeID
  if not id or row.dragId then return end
  local idx
  for i = 1, #(row.rows or {}) do if row.rows[i].id == id then idx = i; break end end
  if not idx then return end
  row.dragId, row.dragIdx = id, idx
  local cx, cy = cursorAt(row)
  row.grabOff = (cx or 0) - ((row.lefts or {})[idx] or 0)
  row.grabY = (cy or 0) - ((row.tops or {})[idx] or 0)
  -- Lifted so the held cell reads as picked up and is not drawn under the cells it passes.
  s.wpeLevel = s:GetFrameLevel()
  s:SetFrameLevel((row.frame:GetFrameLevel() or 1) + 10)
  s.icon:SetAlpha(0.5)
  hotEdge(s)   -- in the hand: the whole outline takes the accent, not just the edge
  row.frame:SetScript("OnUpdate", function() dragUpdate(row) end)
end

local function endDrag(row, s)
  row.frame:SetScript("OnUpdate", nil)
  if row.dropMark then row.dropMark:Hide() end
  local id, slot = row.dragId, row.dropTo
  row.dragId, row.dragIdx, row.dropTo, row.grabOff, row.grabY = nil, nil, nil, nil, nil
  if s then
    if s.wpeLevel then s:SetFrameLevel(s.wpeLevel); s.wpeLevel = nil end
    s.icon:SetAlpha(s.wpeGhost and 0.55 or 1)
    restEdge(s)
    s.pressed = nil
  end
  row.dragJust = true
  -- Back on its own seat is not a move: the carry floats the cell under the hand and only a move
  -- rebuilds the row, so the float is put home here -- otherwise it is stranded where the hand let it
  -- go, its own seat left bare.
  if not id or not slot then Cur:Home(id); return end
  local target = (slot <= #(row.rows or {})) and row.rows[slot].id or nil
  Cur:MoveOrder(id, target)
end

-- One cell: the icon itself, edged -- a 1px outline over it, no plate under it. The number is the
-- window's own stack badge: its place and face come from the badge settings, so it sits where every
-- other count sits. A Ctrl-click transfers it where the client allows one, a shift-click stops tracking
-- the currency (the client's own pin, so the character panel agrees), and the panel behind the row is the
-- picker's own (Features/CurrencyPicker.lua) -- the tooltip is the game's own currency tooltip where it
-- exists. The cell follows the window's icon size, live: the row is a summary of the grid, not the grid.
local function cellSize()
  return math.max(16, ((ns.Bags and ns.Bags.iconSize) or 30) - 3)
end

-- The cell's own drawn border, in the cell's own language: a 1px outer edge (the window's stroke,
-- the accent under the pointer or in the hand), the currency's quality as a ring on the very edge,
-- and a black keyline one pixel inside the ring, so the colour reads against any icon. A backdrop
-- edge would sit under the full-bleed icon and vanish into it, and the slot furniture would drag a
-- whole cell apparatus (levels, rings, badge strings) onto a cell. The ring and the keyline live and
-- die together -- a ring with no keyline smears into a warm icon.
chipEdge = function(c)
  if c.edge then return c.edge end
  -- A bare texture paints nothing: SetVertexColor only tints, so each line gets a white face first,
  -- the way the checkbox lights its own edges. Without it the border is four invisible nothings.
  local e = {}
  e[1] = c:CreateTexture(nil, "OVERLAY"); e[1]:SetPoint("TOPLEFT");     e[1]:SetPoint("TOPRIGHT");    e[1]:SetColorTexture(1, 1, 1, 1); ns.PixelLine(e[1], 1)
  e[2] = c:CreateTexture(nil, "OVERLAY"); e[2]:SetPoint("BOTTOMLEFT");  e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetColorTexture(1, 1, 1, 1); ns.PixelLine(e[2], 1)
  e[3] = c:CreateTexture(nil, "OVERLAY"); e[3]:SetPoint("TOPLEFT");     e[3]:SetPoint("BOTTOMLEFT");  e[3]:SetColorTexture(1, 1, 1, 1); ns.PixelLine(e[3], 1, "w")
  e[4] = c:CreateTexture(nil, "OVERLAY"); e[4]:SetPoint("TOPRIGHT");    e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetColorTexture(1, 1, 1, 1); ns.PixelLine(e[4], 1, "w")
  c.edge = e
  return e
end

paintEdge = function(c, r, g, b)
  for _, t in ipairs(chipEdge(c)) do t:SetVertexColor(r, g, b) end
end

-- The ring on the very edge, over the outer line the way a cell's ring sits over its edge. Inset
-- zero anchors never move; only the thickness follows the ring-width slider.
chipRing = function(c)
  if c.ring then return c.ring end
  local r = {}
  r[1] = c:CreateTexture(nil, "OVERLAY", nil, 1); r[1]:SetPoint("TOPLEFT");     r[1]:SetPoint("TOPRIGHT");     r[1]:SetColorTexture(1, 1, 1, 1); r[1]:Hide()
  r[2] = c:CreateTexture(nil, "OVERLAY", nil, 1); r[2]:SetPoint("BOTTOMLEFT");  r[2]:SetPoint("BOTTOMRIGHT");  r[2]:SetColorTexture(1, 1, 1, 1); r[2]:Hide()
  r[3] = c:CreateTexture(nil, "OVERLAY", nil, 1); r[3]:SetPoint("TOPLEFT");     r[3]:SetPoint("BOTTOMLEFT");   r[3]:SetColorTexture(1, 1, 1, 1); r[3]:Hide()
  r[4] = c:CreateTexture(nil, "OVERLAY", nil, 1); r[4]:SetPoint("TOPRIGHT");    r[4]:SetPoint("BOTTOMRIGHT");  r[4]:SetColorTexture(1, 1, 1, 1); r[4]:Hide()
  c.ring = r
  return r
end

-- The dark line the ring is read against, one pixel just inside it and one sublevel under it. Black
-- face baked at birth like the cell's own keyline; the painter only shows and hides.
chipKey = function(c)
  if c.key then return c.key end
  local k = {}
  for i = 1, 4 do
    k[i] = c:CreateTexture(nil, "OVERLAY")
    k[i]:SetColorTexture(0, 0, 0, 0.85)
    k[i]:Hide()
  end
  c.key = k
  return k
end

-- The ring's thickness and the keyline's offset from the snapped ring width, so a scale change or a
-- slider move cannot wedge them apart. Guarded on the snapped pixels: a repaint walks every cell.
ringJob = function(x)
  local ring, key = x.ring, x.key
  if not (ring and key) then return end
  local w = ns.PX(x, x.wpeRingW or 2)
  local kp = ns.PX(x, 1)
  if x.ringPx == w and x.keyPx == kp then return end
  x.ringPx, x.keyPx = w, kp
  ring[1]:SetHeight(w); ring[2]:SetHeight(w)
  ring[3]:SetWidth(w);  ring[4]:SetWidth(w)
  key[1]:ClearAllPoints(); key[1]:SetPoint("TOPLEFT", w, -w);     key[1]:SetPoint("TOPRIGHT", -w, -w);    key[1]:SetHeight(kp)
  key[2]:ClearAllPoints(); key[2]:SetPoint("BOTTOMLEFT", w, w);   key[2]:SetPoint("BOTTOMRIGHT", -w, w);  key[2]:SetHeight(kp)
  key[3]:ClearAllPoints(); key[3]:SetPoint("TOPLEFT", w, -w);     key[3]:SetPoint("BOTTOMLEFT", w, w);    key[3]:SetWidth(kp)
  key[4]:ClearAllPoints(); key[4]:SetPoint("TOPRIGHT", -w, -w);   key[4]:SetPoint("BOTTOMRIGHT", -w, w);  key[4]:SetWidth(kp)
end

-- One call is the whole state of the ring: a colour turns the four lines up with their keyline, nil
-- puts them away. The guard is about the colour, not the meaning -- a repaint walks every cell, and
-- the geometry follows through the job every time, slider or no slider.
paintRing = function(c, r, g, b)
  local ring, key = chipRing(c), chipKey(c)
  if not r then
    if c.ringOn == false then return end
    c.ringOn = false
    for i = 1, 4 do ring[i]:Hide(); key[i]:Hide() end
    return
  end
  for i = 1, 4 do ring[i]:Show(); key[i]:Show() end
  if c.ringOn and c.ringR == r and c.ringG == g and c.ringB == b then ringJob(c); return end
  c.ringOn, c.ringR, c.ringG, c.ringB = true, r, g, b
  for i = 1, 4 do ring[i]:SetColorTexture(r, g, b, 1) end
  ringJob(c)
end

-- The rest ink of the whole outline: the accent under the pointer or in the hand, the row's own coin ink
-- under it. One colour for the row -- edge and ring together -- because quality on a currency says little
-- and would put the grid's own language on a row that is not the grid; and the coin ink is the one tone in
-- the kit that is far from every chromatic quality colour and from every accent (see Core/Theme.lua). The
-- ring keeps the slots' width slider and the black keyline, so it still reads on a pale coin icon.
restEdge = function(s)
  local r, g, b
  if s:IsMouseOver() then r, g, b = Theme:C("accent") else r, g, b = Theme:C("coin") end
  paintEdge(s, r, g, b)
  paintRing(s, r, g, b)
end

-- The same outline under the hand or in it: both lines take the accent, since the ring is an accent, not
-- a quality that stays put. A hover runs no layout, so the pointer's own handler has to paint the ring too
-- -- painting only the edge would leave the coin ink standing next to an accent edge.
hotEdge = function(s)
  local r, g, b = Theme:C("accent")
  paintEdge(s, r, g, b)
  paintRing(s, r, g, b)
end

-- The door's one switch. Every hover on the band lands here: a cell, the door itself, or the bare seam
-- between them are one target to the eye, so the plus stands while the pointer is anywhere on the strip.
-- The band's own plate (Windows/Bags.lua) is the rectangle of record -- a few pixels of gap between two
-- cells are still the row, and asking a topmost frame per cell would make the door blink in every gap.
function Cur:LightDoor(on)
  if self.plus then self.plus:SetAlpha(on and 1 or 0) end
  local band = self.hover
  if not band then return end
  if on then
    -- A layout can slide the band out from under a still hand without sending the leave, and a cell that
    -- is hidden or reseated under the pointer sends none either. While the door is lit, ask the band's
    -- own rectangle once a frame: the first answer of no puts it out and stops the watch. It runs only
    -- while lit, so a row at rest costs nothing.
    if not band.wpeWatch then
      band.wpeWatch = true
      band:SetScript("OnUpdate", function(s)
        if not s:IsMouseOver() then
          s.wpeWatch = nil
          s:SetScript("OnUpdate", nil)
          Cur:LightDoor(false)
        end
      end)
    end
  elseif band.wpeWatch then
    band.wpeWatch = nil
    band:SetScript("OnUpdate", nil)
  end
end

-- Whether a frame that just lost the pointer was the band's last bit. A cell's leave is often not the
-- row's: the next thing under the hand can be the gap to the next coin, and the plate under the whole
-- band still answers its own rectangle there. Only a leave that stands outside it puts the door out.
local function unlight(row)
  local band = row.hover
  if not (band and band:IsMouseOver()) then row:LightDoor(false) end
end

-- The tip over one coin: the client's own currency lines where it has them, then the row's two hints.
-- Kept in one place because a shift-untrack rebuilds the row under the pointer: the same physical cell
-- can come back carrying another currency, and the tip has to be re-owned for it without a new enter.
local function coinTip(c)
  if not (c and c.wpeID) then return end
  GameTooltip:SetOwner(c, "ANCHOR_TOP")
  if GameTooltip.SetCurrencyByID then
    GameTooltip:SetCurrencyByID(c.wpeID)
  else
    GameTooltip:SetText(c.wpeName or "")
  end
  GameTooltip:AddLine(ns.TipInk(ns.L["Drag to reorder"], 0.9, 0.9, 0.9), 0.9, 0.9, 0.9, true)
  if Cur.Transferable(c.wpeID) and not (InCombatLockdown and InCombatLockdown()) then
    GameTooltip:AddLine(ns.TipInk(ns.L["Ctrl + LMB to transfer currency from another character"], 0.9, 0.9, 0.9), 0.9, 0.9, 0.9, true)
  end
  GameTooltip:AddLine(ns.TipInk(ns.L["Shift + LMB to stop tracking"], 0.9, 0.9, 0.9), 0.9, 0.9, 0.9, true)
  -- Which coin this seat's tip was last built for: a rebuild that hands the seat another coin is the
  -- only time the hover's transfer want has to move with it.
  c.wpeTipID = c.wpeID
  GameTooltip:Show()
end

-- A shift-untrack rebuilds the row under a still hand: the seat under the pointer is repainted with the
-- next coin -- or hidden, at the tail -- and no enter fires, so the old coin's tip would hang over the new
-- one. After the rebuild, re-own the tip for the coin the seat carries now, or put it away when the seat
-- is gone. A tip owned by any other frame is none of the row's business. The hover's transfer want is
-- re-bound too: a Ctrl press without moving must serve the coin under the hand, not the one just removed.
function Cur:RefreshTip()
  local tip = GameTooltip
  if not (tip and tip.GetOwner and tip.IsShown and tip:IsShown()) then return end
  local owner = tip:GetOwner()
  local c
  for i = 1, #(self.chips or {}) do
    if self.chips[i] == owner then c = owner; break end
  end
  if not c then return end
  if not (c:IsShown() and c:IsMouseOver() and c.wpeID) then tip:Hide(); return end
  if c.wpeTipID ~= c.wpeID then
    Cur:DisarmTransfer(c, true)
    if Cur.Transferable(c.wpeID) then Cur:WantTransfer(c, c.wpeID) end
  end
  coinTip(c)
end

-- One cell: the icon itself, edged in the cell's language -- outer line, one ring, keyline.
local function chip(row, i)
  row.chips = row.chips or {}
  local c = row.chips[i]
  if c then return c end
  -- An insecure action button, not a plain one: a Ctrl-click asks the client to run its own transfer
  -- chain (see Cur:ArmTransfer). A client that answers no such template still gets a plain cell, whose
  -- Ctrl-click only opens the currency tab.
  local made
  made, c = pcall(CreateFrame, "Button", nil, row.frame, "InsecureActionButtonTemplate")
  if not made or not c then
    c = CreateFrame("Button", nil, row.frame)
  else
    c:RegisterForClicks("AnyUp", "AnyDown")
    c:SetAttribute("type", "click")
    c:SetAttribute("downbutton", "startup")
    c:SetAttribute("typerelease", "click")
  end
  -- Above the window's grid plate, the way the old bar stood a level over the foot: the cells hang on
  -- the window frame, so the level has to be asked for rather than inherited from a row frame.
  c:SetFrameLevel((row.frame:GetFrameLevel() or 1) + 2)
  c.icon = c:CreateTexture(nil, "ARTWORK")
  c.icon:SetAllPoints(c)
  c.text = c:CreateFontString(nil, "OVERLAY")
  c.Count = c.text   -- the stack badge's own handle: ApplyBadge dresses it like every other count
  c.text:SetJustifyH("RIGHT")
  c.text:SetWordWrap(false)
  c:RegisterForDrag("LeftButton")
  -- The ring geometry heals on a scale change without a layout, through the pixel pass.
  ns.PixelJob(c, ringJob, "ring")
  c:SetScript("OnDragStart", function(s) beginDrag(row, s) end)
  c:SetScript("OnDragStop", function(s) endDrag(row, s) end)
  -- A press released on its own cell says one thing: a shift takes the currency off the track. A press that
  -- became a carry says nothing -- the drop already landed it. The cell is not a door of its own: the row's
  -- add door past the last coin (and the header's currency switch) opens the panel, so a plain click has
  -- nothing to answer.
  c:SetScript("OnMouseDown", function(s, button)
    if button == "LeftButton" then s.pressed = true end
  end)
  c:SetScript("OnMouseUp", function(s, button)
    if row.dragJust then row.dragJust = nil; s.pressed = nil; return end
    if button ~= "LeftButton" or not s.pressed then s.pressed = nil; return end
    s.pressed = nil
    if not s.wpeID then return end
    -- Combat owns no Ctrl-click on a currency: the press is left unanswered, so nothing here may arm
    -- the client's chain or walk to its protected tab.
    if IsControlKeyDown and IsControlKeyDown() then
      if InCombatLockdown and InCombatLockdown() then return end
      if Cur.Transferable(s.wpeID) then
        -- An armed cell has already had the client run its chain on the press; all that is left is to
        -- stand the menu beside the character panel. An unarmed one (a client without those frames)
        -- walks to the currency tab, where the same transfer waits.
        if s.wpeArmed then Cur:PlaceTransfer() else Cur:OpenTransfer(s.wpeID) end
        return
      end
    end
    if IsShiftKeyDown() then Cur:SetWatched(s.wpeID, false) end
  end)
  c:SetScript("OnEnter", function(s)
    hotEdge(s)
    -- The row is one target: a pointer anywhere on the band lights the add door at its tail.
    row:LightDoor(true)
    -- A ghost lifts toward the eye under the pointer, the way a pocket ghost does.
    if s.wpeGhost and row.dragId ~= s.wpeID then s.icon:SetAlpha(0.85) end
    if not s.wpeID then return end
    -- Ctrl asks for the client's own transfer, and the arm has to be in place before the press: the cell
    -- wants it on every hover, and the key going down (see Cur:WantTransfer) is where the arm is made, so
    -- a player who presses Ctrl after hovering is served the same one-press menu.
    if Cur.Transferable(s.wpeID) then Cur:WantTransfer(s, s.wpeID) end
    coinTip(s)
  end)
  c:SetScript("OnLeave", function(s)
    restEdge(s)
    Cur:DisarmTransfer(s, true)
    if not row.dragId then s.icon:SetAlpha(s.wpeGhost and 0.55 or 1) end
    -- Moving off a coin does not by itself mean the row is left: the next coin, the door or the bare
    -- seam between two cells is still the same band, and the plate knows its own rectangle. Only a leave
    -- that carries the pointer out of it puts the door out.
    unlight(row)
    GameTooltip:Hide()
  end)
  row.chips[i] = c
  return c
end

-- The add door: one empty cell past the last tracked currency, the same size as a cell, carrying a plus.
-- It is the row's own way into the currency panel -- the header's currency switch (Windows/Bags.lua) stays
-- the other, and the only one while nothing is tracked. The door rests at alpha 0: a plus lit all the time
-- read as one more currency, and the row is meant to be a run of the player's own coins. A pointer anywhere
-- on the band -- a cell, the door, or the seam and gaps around them -- lights it; only leaving the band's
-- rectangle puts it out again (see Cur:LightDoor and Cur.hover). It is built on the window frame and
-- seated by Place, the way a cell is.
local function door(row)
  local d = row.plus
  if d then return d end
  d = ns.CreateGlyphButton(row.frame, "+", row.size or 30)
  d:SetFrameLevel((row.frame:GetFrameLevel() or 1) + 2)
  d:SetAlpha(0)
  d:SetScript("OnClick", function()
    local bags = ns.Bags
    -- The foot of the bags window: the panel stands at its lower-left corner, the way the row that holds
    -- this door sits at the window's foot. The header's switch keeps the head (see Pick:Toggle).
    if ns.CurPicker then ns.CurPicker:Toggle((bags and bags.frame) or row.frame, "bottom") end
  end)
  -- The door reveals itself the moment the pointer finds it, even from outside the row: it stands a full
  -- cell past the last coin, and a player who knows it is there must not have to cross a cell to see it.
  d:HookScript("OnEnter", function() row:LightDoor(true) end)
  d:HookScript("OnLeave", function() unlight(row) end)
  ns.AddTip(d, "Open currency list", "top")
  row.plus = d
  return d
end

-- Paints one cell for its tracked currency: icon, the row's one ring, count. Kept apart from seating so
-- a count change repaints in place without moving anything.
local function paintCell(row, c, r, sz)
  c.wpeID, c.wpeName = r.id, r.name
  c.icon:SetTexture(r.icon)
  zoomIcon(c.icon)
  -- A ghost when there is nothing of it, the way the pocket draws a pin that is not with you: no
  -- desaturation, half alpha, and the nought written in the gone ink. The flag rides the cell, so
  -- hover and the drop know the resting alpha without a second lookup. The held cell keeps the
  -- drag's own alpha while it is in the air.
  c.wpeGhost = (r.q or 0) <= 0
  if row.dragId ~= r.id then c.icon:SetAlpha(c.wpeGhost and 0.55 or 1) end
  -- The cell's outline, by its own hand: the accent under the pointer or in the hand, the row's coin ink at
  -- rest. The ring follows the same width slider as the slots, so the row and the grid speak one line.
  local hot = ((c:IsMouseOver() and true or false) or row.dragId == r.id) and true or false
  c.wpeRingW = (ns.Bags and ns.Bags.borderWidth) or 2
  if hot then hotEdge(c) else restEdge(c) end
  -- No direct SetFont on this string, ever: the badge dress remembers faces by key, and a face set
  -- past it desyncs the cache -- every repaint after the first would keep the fallback size instead
  -- of the badge's. The fallback below goes through the same cache, so it stays consistent too.
  if ns.SetOutlined then
    ns.SetOutlined(c.text, sz)
  elseif c.text.SetFont then
    c.text:SetFont(ns.Fonts:Current(), sz, ns.OutlineFlags())
  end
  -- The nought is written, in the gone ink like a ghost's: an empty cell reads as empty, not as one
  -- owned and not as a breakage.
  c.text:SetText(Cur.CountText(r.q, 4))
  c.wpeCell = sz
  -- Dressed by the badge's own hand, with the size forced after it: whatever path the number took,
  -- it lands at the badge's own size -- a half-dressed badge can never leave it big.
  if ns.ApplyBadge then ns.ApplyBadge(c, "count") end
  if ns.BadgeSize and ns.SetOutlined then ns.SetOutlined(c.text, ns.BadgeSize("count", sz)) end
  c.text:SetAlpha(1)   -- the row's numbers always read: the badge toggle rules the slots, not this row
  -- The number has no ceiling warning of its own: at every value it reads in the ordinary ink, and at
  -- zero in the gone ink the way a ghost's nought does.
  local zr, zg, zb = Theme:C((r.q or 0) > 0 and "text" or "gone")
  c.text:SetTextColor(zr, zg, zb)
end

-- How tall the row stands for a given cell size and grid width, in pixels: every tracked currency and the
-- add door at their tail, wrapped onto the grid's columns. 0 when the row is switched off, and 0 when
-- nothing is tracked -- an empty row is no row at all, and the header's currency switch is what brings one
-- back. Reads the client's tracking list and remembers it, so the Place that follows a Measure needs no
-- second read.
function Cur:Measure(size, gap, gridW, cols)
  local B = ns.Bags
  if not self.frame then return 0 end
  self.size, self.gap = size, gap
  self.cols = math.max(1, math.floor(tonumber(cols) or 1))
  self.gridW = gridW
  self.dir = Cur.Dir()
  local rows = Cur.ReadWatched(C_CurrencyInfo, self.rows or {})
  self.rows = rows
  if B and B.curStrip == false then
    self.sig = nil
    return 0
  end
  Cur.Sort(rows)
  self.sig = #rows
  if #rows == 0 then
    self.nRows = 0
    return 0
  end
  local step = size + gap
  -- The door takes the seat after the last coin; when that seat is the first of a new line the row grows
  -- by it, so the empty cell never hangs off the band.
  self.nRows = math.ceil((#rows + 1) / self.cols)
  return self.nRows * step - gap
end

-- Seats every tracked currency inside the window frame, wrapped onto the columns the Measure above was
-- taken for and laid out the way the player chose: `x` is the left edge, `top` the top edge below the
-- frame's top. A light pass seats positions only -- what each cell shows is left for the trailing full
-- pass, as the grid does.
function Cur:Place(frame, x, top, size, gap, light)
  self.frame = frame
  self.x0, self.top = x, top
  self.size, self.gap = size, gap
  self.lefts, self.tops = {}, {}
  local rows = self.rows or {}
  -- Built before the first seat is asked for: the door is one of the row's seats, and the centred and
  -- mirrored walks measure their blocks with it in the count.
  local plus = door(self)
  for i = 1, #rows do
    local c = chip(self, i)
    if not light then paintCell(self, c, rows[i], size) end
    local px, py = seatAt(self, i - 1)
    -- The held cell is placed by the drag pass while it is in the air; the next layout puts it back.
    if self.dragId ~= rows[i].id then
      c:ClearAllPoints()
      ns.SnapPoint(c, "TOPLEFT", frame, "TOPLEFT", px, -py)
    end
    ns.SnapSize(c, size, size)
    c:Show()
    self.lefts[i], self.tops[i] = ns.SnapValue(frame, px), ns.SnapValue(frame, py)
  end
  -- The door holds the seat past the last coin, or goes away with a row that carries none: a lone plus
  -- would be a row of its own, and the header's switch already stands for an empty track list.
  if #rows > 0 then
    local px, py = seatAt(self, #rows)
    plus:ClearAllPoints()
    ns.SnapPoint(plus, "TOPLEFT", frame, "TOPLEFT", px, -py)
    ns.SnapSize(plus, size, size)
    plus:Show()
    -- A row laid out under the pointer keeps the door lit only if the pointer really stands on the band:
    -- a window that closed while the hand was over the door never sees its leave, so the next layout
    -- asks instead of trusting the last enter. The plate knows the whole rectangle; the cells are its
    -- fallback for a layout that ran before the window made one.
    local hot = (self.hover and self.hover:IsMouseOver()) and true or false
    if not hot then
      hot = plus:IsMouseOver()
      for i = 1, #rows do
        if hot then break end
        local c = self.chips[i]
        hot = (c and c:IsMouseOver()) and true or false
      end
    end
    self:LightDoor(hot)
  else
    plus:Hide()
  end
  for i = #rows + 1, #(self.chips or {}) do self.chips[i]:Hide() end
  self.placed = true
end

-- Repaints the seated cells for their counts alone, without moving anything. Called when the set of
-- tracked currencies did not change, so the window needs no resize.
function Cur:Repaint()
  local size = self.size
  if not size or not self.chips then return end
  for i = 1, #(self.rows or {}) do
    local c = self.chips[i]
    if c then paintCell(self, c, self.rows[i], size) end
  end
end

-- Puts a carried cell back on its own recorded seat. The carry floats the cell under the hand and only a
-- move rebuilds the row, so a drop with no move -- the hand let go over its own seat -- would leave the
-- float stranded and the seat bare. This is that return trip, by hand.
function Cur:Home(id)
  if not id or not self.frame then return end
  local idx
  for i = 1, #(self.rows or {}) do if self.rows[i].id == id then idx = i; break end end
  if not idx then return end
  local c = (self.chips or {})[idx]
  local lx, ly = (self.lefts or {})[idx], (self.tops or {})[idx]
  if not (c and lx and ly) then return end
  c:ClearAllPoints()
  ns.SnapPoint(c, "TOPLEFT", self.frame, "TOPLEFT", lx, -ly)
end

-- Hides the whole row: every cell. The window does the same to the seam line.
function Cur:Hide()
  -- No armed cell outlives the row: its attributes name a row of the client's list, and nothing that is
  -- not on screen should still be able to ask for a transfer.
  Cur:DisarmTransfer()
  for i = 1, #(self.chips or {}) do if self.chips[i] then self.chips[i]:Hide() end end
  -- The door goes with the row and comes back at rest: a layout that hid it under the pointer must not
  -- leave a lit plus waiting for the next time the row opens. The switch also stops the lit watch.
  if self.plus then self.plus:Hide(); self:LightDoor(false) end
  if self.dropMark then self.dropMark:Hide() end
  self.placed = nil
end

-- Attach: the window hands the row its frame once (from the bags build), and the row reads the window's
-- icon size and columns each layout through Measure. Nothing is anchored here: the layout seats it.
function Cur:Attach(frame)
  if self.frame then return self end
  self.frame = frame
  self.bags = ns.Bags
  self.chips = self.chips or {}
  self.rows = self.rows or {}
  frame:HookScript("OnShow", function() Cur:Request() end)
  return self
end

------------------------------------------------------------------------------
-- The read
------------------------------------------------------------------------------
-- CURRENCY_DISPLAY_UPDATE arrives in bursts (one per currency on entering the world, several per change),
-- so the read is coalesced behind one timer: the flag means "a pass is already coming".
function Cur:Request()
  if pending then return end
  pending = true
  C_Timer.After(0.2, function()
    pending = nil
    Cur:Apply()
  end)
end

function Cur:Apply(force)
  local B = self.bags
  if B and B.frame and B.frame:IsShown() then
    local fresh = Cur.ReadWatched(C_CurrencyInfo, {})
    -- Only a change in how many are tracked moves the row's height, so only that asks the window to
    -- rebuild. A hidden row (curStrip off) has no height to move: it stays a repaint even though its
    -- count reads as nil, rather than asking for a full layout on every open through the OnShow request.
    local on = B.curStrip ~= false
    if force or (on and (#fresh ~= (self.sig or -1) or not self.placed)) then
      B:Layout()
    else
      self.rows = fresh
      Cur.Sort(self.rows)
      self:Repaint()
    end
    -- A repaint may have handed the seat under a still pointer another coin (a shift-untrack moves the
    -- whole tail down a seat) or a new count: re-own its tip for what it carries now, so the removed
    -- coin's lines cannot hang over the next currency.
    Cur:RefreshTip()
  end
  if ns.CurPicker then ns.CurPicker:Refresh() end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function() Cur:Request() end)

-- The tracking flag has no event: the client tells no one when "show in backpack" flips, anywhere it
-- flips from. So the flip itself is watched instead -- a secure hook on the two setters fires whether
-- the character tab, a shift-click or our own tick moved it, and the repaint folds into the same pass.
if hooksecurefunc and C_CurrencyInfo then
  if C_CurrencyInfo.SetCurrencyBackpackByID then
    hooksecurefunc(C_CurrencyInfo, "SetCurrencyBackpackByID", function() Cur:Request() end)
  end
  if C_CurrencyInfo.SetCurrencyBackpack then
    hooksecurefunc(C_CurrencyInfo, "SetCurrencyBackpack", function() Cur:Request() end)
  end
end

-- The first read waits for the window to build: the row asks for its own pass when it attaches.
