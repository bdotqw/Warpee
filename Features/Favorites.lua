local addonName, ns = ...
local Theme = ns.Theme

local Fav = {}
ns.Fav = Fav
Fav.slots, Fav.ghosts, Fav.catchers = {}, {}, {}

local MAX_SLOTS = 24

local function charKey()
  local n = UnitName("player") or "?"
  local r = (GetNormalizedRealmName and GetNormalizedRealmName())
            or (GetRealmName and GetRealmName()) or "?"
  return n .. "-" .. r
end

function Fav:Enabled()
  return not (WarpeeDB and WarpeeDB.favShow == false)
end

function Fav:List()
  WarpeeDB.favorites = WarpeeDB.favorites or {}
  local k = charKey()
  WarpeeDB.favorites[k] = WarpeeDB.favorites[k] or {}
  return WarpeeDB.favorites[k]
end

-- Pinned cells are shared with the pocket window. Read the block above ns.PinArg in
-- ItemButton.lua before touching anything a cell knows or shows, and make the change there
-- so both rows get it: this file owns only the row, its geometry, the tooltip and the click
-- overlay. The lists themselves stay apart, this one is its own.
local pins = {}
local locsDirty = true

local function scan()
  if not locsDirty then return end
  locsDirty = false
  ns.PinScan(Fav:List(), MAX_SLOTS, pins)
end

local function locate(pin)
  scan()
  return ns.PinLocate(pin, pins)
end

local function worn(pin)
  scan()
  return ns.PinWorn(pin, pins)
end

local function favSound(kind, bag, slot)
  local pickup = kind == "pickup"
  local play = C_Sound and C_Sound.PlayItemSound
  local kinds = Enum and Enum.ItemSoundType
  if play and kinds and bag and slot and ItemLocation then
    local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
    if loc and C_Item.DoesItemExist(loc) then
      play(pickup and (kinds.Pickup or 0) or (kinds.Drop or 1), loc)
      return
    end
  end
  if not (PlaySound and SOUNDKIT) then return end
  local id = SOUNDKIT[pickup and "UI_CURSOR_PICKUP_OBJECT" or "UI_CURSOR_DROP_OBJECT"]
  if id then PlaySound(id) end
end
ns.ItemSound = favSound

local deferred, tipDirty = false, false

-- The tooltip is rebuilt only when a pin changed, never on a plain refresh: this runs on
-- every list write, and a tooltip set under the cursor on each of them would blink. The
-- placement is a frame late, so the rebuild waits for it: by then the cursor has let go of
-- the item and IsMouseOver answers about the cell instead of about a drag still in flight.
local function later(tip)
  if tip then tipDirty = true end
  if deferred then return end
  deferred = true
  C_Timer.After(0, function()
    deferred = false
    Fav:Refresh()
    if tipDirty then tipDirty = false; Fav:Tip() end
  end)
end

local function makeGhost(parent)
  local g = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  ns.PixelBackdrop(g)
  -- The backdrop carries the edge alone, because that is what the pin states repaint through
  -- ns.SetEdge. The fill is a texture of its own, so an empty cell of a row wears the same
  -- slot art a cell of the grid wears instead of a flat plate of its own colour.
  ns.SetBg(g, 0, 0, 0, 0)
  ns.SetEdge(g, Theme:C("emptyLine"))
  local bg = g:CreateTexture(nil, "BACKGROUND", nil, -1)
  bg:SetAllPoints(g)
  g.bg = bg
  local base = g:CreateTexture(nil, "BACKGROUND", nil, -2)
  base:SetAllPoints(g)
  g.bgBase = base
  ns.PaintGhostBg(g)
  ns.MarkPlus(g)
  ns.TintMarkX(g, "faint")
  -- One tracker per frame: Theme:Track keeps a single painter, so background,
  -- edge and mark tint ride together or the later call eats the earlier one.
  Theme:Track(g, function(s)
    ns.PaintGhostBg(s)
    ns.SetEdge(s, Theme:C("emptyLine"))
    ns.TintMarkX(s, "faint")
  end)
  local ic = g:CreateTexture(nil, "ARTWORK")
  ic:SetPoint("TOPLEFT", 1, -1)
  ic:SetPoint("BOTTOMRIGHT", -1, 1)
  ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  ic:SetDesaturated(true)
  g.icon = ic
  -- The drawn plus is the mark an empty cell invites a drop with, and it is fitted to the box the
  -- ghost turns out to have, not to the size it was asked for: the row sizes a cell to whole
  -- pixels, and the mark reads that size back so its bars land on the grid (see FitMarkPlus).
  ns.ShowMark(g, ns.GhostPlus())
  g.plus = true
  return g
end
ns.SlotGhost = makeGhost

local function tipFor(c, index)
  local pin = Fav:List()[index]
  GameTooltip:SetOwner(c, "ANCHOR_RIGHT")
  if pin then
    local b = Fav.slots[index]
    if b and b.favBag and b.holder:IsShown() then
      GameTooltip:SetBagItem(b.favBag, b.favSlot)
    else
      if type(pin) == "string" then
        GameTooltip:SetHyperlink(pin)
      else
        GameTooltip:SetItemByID(pin)
      end
      if worn(pin) then
        GameTooltip:AddLine(ns.TipInk(ns.L["Equipped"], 0.9, 0.9, 0.9), 0.9, 0.9, 0.9, true)
      end
    end
  else
    GameTooltip:SetText(ns.L["Favorites"])
    GameTooltip:AddLine(ns.TipInk(ns.L["Drag an item here for quick access"], 0.9, 0.9, 0.9),
      0.9, 0.9, 0.9, true)
  end
  GameTooltip:Show()
end

-- A pin that lands or moves changes what the cell under the pointer is showing, and the
-- placement itself is a frame late, so the tooltip is rebuilt after the refresh and not at
-- the moment of the change: by then the cursor has let go of the item, and IsMouseOver
-- answers about the cell instead of about a drag still in flight.
function Fav:Tip()
  for i = 1, (self.max or 0) do
    local c = self.catchers[i]
    if c and c:IsShown() and c:IsMouseOver() then tipFor(c, i) end
  end
end

-- The overlay owns the left button for good and passes the right button down to the
-- slot, so a right click reaches the game's handler with no addon code in the path.
-- SetPassThroughButtons is refused during combat lockdown, so it is set here, once,
-- and never touched again. Emptying a slot is on a key rather than on a fourth modifier,
-- because Ctrl is the game's own dress-up and this cell can have it back: the overlay hands
-- the modified click to HandleModifiedItemClick, which is the same branch the grid reaches.
-- The overlay must never finish a pending item spell itself: C_Container.UseContainerItem
-- from addon code is refused as ADDON_ACTION_FORBIDDEN, traceback 2026-09-05. An enchant
-- or a gem lands only in the bag grid: the game runs that from the left button of its
-- own slot handler, and every row here keeps the right button alone.
local function makeCatcher(parent, index)
  local c = CreateFrame("Button", nil, parent)
  c.favIndex = index
  c:RegisterForClicks("LeftButtonUp", "MiddleButtonUp", "RightButtonUp")
  c:RegisterForDrag("LeftButton")
  c:SetFrameLevel(parent:GetFrameLevel() + 30)
  c:EnableMouse(true)
  if c.SetPassThroughButtons then c:SetPassThroughButtons("RightButton") end
  c:SetScript("OnDragStart", function(s) Fav:Lift(s.favIndex) end)
  c:SetScript("OnDragStop", function() Fav:Drop() end)
  c:SetScript("OnReceiveDrag", function(s) Fav:PinFromCursor(s.favIndex) end)
  c:SetScript("OnClick", function(s, button)
    if button == "MiddleButton" then
      -- Direct click, not a binding, and the cell keeps the click either way. The addon's own default
      -- sits on this very button -- a mouse chord over a cell never reaches the game's key settings, so
      -- the addon is the only thing that can bind it -- and that owner is Warpee's own action, which is
      -- no reason to refuse the click. A middle button somebody else has spoken for is left alone.
      local act = (GetBindingAction and GetBindingAction("BUTTON3")) or ""
      if act == "" or act == "WARPEE_UNPIN" then Fav:Unpin(s.favIndex) end
      return
    end
    if button ~= "LeftButton" then return end
    if GetCursorInfo() then
      Fav:PinFromCursor(s.favIndex)
      return
    end
    if IsShiftKeyDown() and not (IsControlKeyDown() or IsAltKeyDown()) then
      Fav:Link(s.favIndex)
      return
    end
    if IsAltKeyDown() and not (IsShiftKeyDown() or IsControlKeyDown()) then
      Fav:Lock(s.favIndex)
      return
    end
    -- The cell wears a live slot when the item is with you and a ghost when it is not, and
    -- the location comes off the cell either way: a ghost carries none and the shared call
    -- falls back to the link.
    if IsModifiedClick("DRESSUP") then
      local b = Fav.slots[s.favIndex]
      ns.PinDressUp(b and b.favBag, b and b.favSlot, Fav:List()[s.favIndex])
    end
  end)
  c:SetScript("OnEnter", function(s)
    local b = Fav.slots[s.favIndex]
    if b and b.holder:IsShown() then ns.SetSlotHighlight(b, true) end
    tipFor(s, s.favIndex)
  end)
  c:SetScript("OnLeave", function(s)
    local b = Fav.slots[s.favIndex]
    if b then ns.SetSlotHighlight(b, false) end
    GameTooltip:Hide()
  end)
  ns.PinWatch(c, function() Fav:Unpin(index) end)
  return c
end

function Fav:Link(index)
  local pin = self:List()[index]
  if not (pin and ChatEdit_InsertLink) then return end
  local b = self.slots[index]
  local link
  if b and b.favBag and b.holder:IsShown() then
    link = C_Container.GetContainerItemLink(b.favBag, b.favSlot)
  end
  if not link then link = select(2, C_Item.GetItemInfo(ns.PinArg(pin))) end
  if link then ChatEdit_InsertLink(link) end
end

function Fav:Set(index, pin)
  local list = self:List()
  if pin then
    local k = ns.ItemKey(pin)
    for i, own in pairs(list) do
      if i ~= index and k and ns.ItemKey(own) == k then list[i] = nil end
    end
  end
  list[index] = pin or nil
  locsDirty = true
  later(true)
end

function Fav:Unpin(index)
  if not self:List()[index] then return end
  self:Set(index, nil)
end

-- The "+" at the right end of the section head fills this row from the same Popular list the pocket offers.
-- The popup is the pocket's own frame, opened in its favorites face (see Pocket:TogglePicks), and a cell in
-- that face is a mark: it is either in the section or not, so one click puts it in or takes it out.
-- The popup's id box, in its favorites face: the same parse the pocket's box does, but the result lands in
-- this row. A pasted link is kept as the pin itself, so a piece of gear arrives named by its own string; a
-- bare id goes through ToggleID and takes the gear rule the section already has -- an id cannot tell one
-- copy of gear from another, so a bare one is refused with the line the pocket prints for the same reason.
function Fav:AddByText(text)
  local s = tostring(text or "")
  local link = s:match("|H(item:[^|]+)|h") or s:match("^(item:[^|%s]+)")
  local id = tonumber(s:match("item:(%d+)")) or tonumber(s:match("%d+"))
  if not id then return end
  local get = C_Item and C_Item.GetItemInfoInstant
  if get and not get(id) then return end
  if not link then
    if ns.GearItem(id) then
      print("|cffd9a85fWarpee|r |cffffffff"
        .. ns.L["Gear is pinned by dragging it or pasting its link, a bare id cannot tell one copy from another."]
        .. "|r")
      return
    end
    self:ToggleID(id)
    return
  end
  local cap, list = self:Capacity(), self:List()
  for i = 1, cap do
    if not list[i] then
      self:Set(i, ns.PinFor(id, link) or link)
      if ns.Pocket then ns.Pocket:RepaintPicks() end
      return
    end
  end
  -- Full is silent here as in ToggleID: a link never goes through that path, and a full row simply
  -- keeps what it has.
end

-- How many pins the row can show: as many as it has visible cells. The row makes one cell per column the
-- bags are set to, so with the bags at 14 columns a fifteenth pin would be stored and never drawn -- it
-- would sit in the row's data, count against nothing and be invisible and unclickable. The cap is read off
-- the bags each time rather than kept here, so changing the column count moves it with the row.
function Fav:Capacity()
  local bags = ns.Bags
  local cols = (bags and bags.cols) or 14
  if cols < 1 then cols = 1 elseif cols > MAX_SLOTS then cols = MAX_SLOTS end
  return cols
end

function Fav:HasID(id)
  id = tonumber(id)
  if not id then return false end
  local list = self:List()
  for i = 1, MAX_SLOTS do
    if ns.ItemStubID(list[i]) == id then return true end
  end
  return false
end

function Fav:ToggleID(id)
  id = tonumber(id)
  if not id then return false end
  local list = self:List()
  for i = 1, MAX_SLOTS do
    if ns.ItemStubID(list[i]) == id then
      self:Set(i, nil)
      if ns.Pocket then ns.Pocket:RepaintPicks() end
      return false
    end
  end
  -- Only the visible cells are candidates: a pin put in a free slot past the last column would be stored
  -- where the row never draws. Full means no free cell inside the row, and that stays silent -- the row
  -- keeps what it has and the caller sees false.
  local cap = self:Capacity()
  for i = 1, cap do
    if not list[i] then
      if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
      self:Set(i, id)
      if ns.Pocket then ns.Pocket:RepaintPicks() end
      return true
    end
  end
  return false
end

-- Grey the row cell mirroring a bag slot that just locked or unlocked, so a pinned item picked up or
-- mid-move desaturates like the grid cell it tracks. The cell binds a real (favBag, favSlot); match those.
function Fav:RefreshLock(bag, slot)
  for i = 1, MAX_SLOTS do
    local b = self.slots[i]
    if b and b.favBag == bag and b.favSlot == slot and b.holder and b.holder:IsVisible() then
      ns.UpdateItemLock(b)
      return
    end
  end
end

function Fav:Lock(index)
  local pin = self:List()[index]
  local id = ns.ItemStubID(pin)
  local V = ns.Vendor
  if not (id and V and V.CycleSell) then return end
  -- The copy's own link, so a piece of gear is named by its exact string and not by its id: the live
  -- cell first, then the pin itself when it was kept as one.
  local b = self.slots[index]
  local live = b and b.favBag and b.holder:IsShown()
  local link
  if live then
    link = C_Container.GetContainerItemLink(b.favBag, b.favSlot)
  end
  if not link and type(pin) == "string" then link = pin end
  -- The same gate the cell's own alt-click obeys, so this row cannot mark what the bags refuse.
  if not V:Markable(live and b.favBag, live and b.favSlot, id, link) then return end
  V:CycleSell(id, link, (link and link:match("%[(.-)%]")) or (C_Item.GetItemInfo(id)) or tostring(id))
  local c = self.catchers[index]
  if c and c:IsShown() and c:IsMouseOver() then tipFor(c, index) end
end

function Fav:Lift(index)
  -- A drag always starts clean: OnDragStop is what clears these, and a drag that ended without one
  -- would otherwise leave the next drop, an item dragged in from the bags, looking like our own move.
  self.lifted, self.liftFrom = nil, nil
  local pin = self:List()[index]
  if not pin then return end
  self.moving = index
  local b = self.slots[index]
  local live = (b and b.favBag) and true or false
  if b then ns.SetSlotHighlight(b, true) end
  favSound("pickup", b and b.favBag, b and b.favSlot)
  -- The cell is an overlay over a slot it only mirrors, so the game picks nothing up by itself: the
  -- item behind the pin goes on the cursor by hand, and from there the drag is the game's own -- the
  -- bar's drop handler writes the item action, a bag slot moves the piece -- with the cursor art the
  -- game draws, so there is no art of this row's to follow the pointer. A live cell names the exact
  -- bag slot, and the container reader takes that copy. A ghost has no slot, so the client resolves
  -- its link on its own -- that is the drag worth keeping: the bar takes it and the pointer gets the
  -- game's art -- and the drag is taken as ours whatever the client answers, because rebuilding the
  -- pin from the cursor's link is exactly what loses the enchant. The answer can also come a
  -- beat late, so an empty cursor here is no failure: the pickup is left as it is, the game's drag
  -- shows when it shows, and the pin still moves by our own bookkeeping.
  self.liftFrom = nil
  if live then
    if not GetCursorInfo() and ns.PinPickup(pin, b.favBag, b.favSlot) then
      -- The seat it came from, kept past Drop: OnDragStop may run before the receiver that answers
      -- the drop, so the move cannot look the source up in self.moving -- that one is gone by then.
      self.lifted, self.liftFrom = true, index
    end
  elseif not GetCursorInfo() then
    ns.PinPickup(pin)
    self.lifted, self.liftFrom = true, index
  end
  GameTooltip:Hide()
end

function Fav:Drop()
  local from = self.moving
  self.moving = nil
  if not from then return end
  local b = self.slots[from]
  if b then ns.SetSlotHighlight(b, false) end
  favSound("drop", b and b.favBag, b and b.favSlot)
  -- A lifted item belongs to the game now: over a cell PinFromCursor takes it, over the bar
  -- PlaceAction writes the action, over a bag slot the container moves it. The pins are references,
  -- so whatever is still held once those handlers have run was dropped on empty UI and goes back
  -- where it came from -- a frame later, because this may run before the receiver.
  if self.lifted then
    -- The flags survive the frame on purpose: PinFromCursor reads the source seat and may be called
    -- after this. By the next frame the receiver has had its say, so anything still on the cursor
    -- was dropped on empty UI, or on a bar that would not take it, and goes back to its slot.
    C_Timer.After(0, function()
      if CursorHasItem() then ClearCursor() end
      Fav.lifted, Fav.liftFrom = nil, nil
      locsDirty = true
      later()
    end)
    return
  end
  local list = self:List()
  for i = 1, (self.max or 0) do
    local c = self.catchers[i]
    if i ~= from and c and c:IsShown() and c:IsMouseOver() then
      list[from], list[i] = list[i], list[from]
      later(true)
      break
    end
  end
end

function Fav:PinFromCursor(index)
  -- A drop of a pin this row itself lifted is a move, not a new pin: the two seats trade the pins
  -- they already hold, untouched. Rebuilding the pin from the cursor's link would normalise it -- a
  -- gear copy loses the enchant, the gems and the upgrade ids it was pinned by, a plain id comes back
  -- as a full stub whose key no longer matches the one stored -- and the rebuilt pin would then stand
  -- beside the stored one on the same id, one of the two with no slot behind it, a ghost.
  local from = self.liftFrom
  if from then
    if GetCursorInfo() then ClearCursor() end
    if from ~= index then
      local list = self:List()
      list[from], list[index] = list[index], list[from]
      locsDirty = true
      later(true)
    end
    return
  end
  local kind, a, link = GetCursorInfo()
  if kind ~= "item" then return end
  local id = tonumber(a)
  if not id and link then id = tonumber(link:match("item:(%d+)")) end
  if not id then return end
  ClearCursor()
  local pin = ns.PinFor(id, link)
  favSound("drop", locate(pin))
  -- A pin lifted out of this row comes back as an item on the cursor, so this is also where a drag
  -- across the row reorders when the lift could not say where it started; the item is matched by
  -- key and the two seats trade places, instead of the drop overwriting the neighbour.
  local list, src, key = self:List(), nil, ns.ItemKey(pin)
  if key then
    for i = 1, (self.max or 0) do
      if i ~= index and list[i] and ns.ItemKey(list[i]) == key then src = i break end
    end
  end
  -- The same copy can come back as a different link: the bonus ids move on an upgrade, and a bound
  -- piece carries its owner's guid in a tail the key never sees. The stem tells that apart from
  -- another enchant, another gem or another suffix, so a drop of the same stem moves the stored pin
  -- instead of standing beside it -- the stored one is the spelling the owner pinned.
  local plainMove = false
  if not src and type(pin) ~= "number" then
    local stem = ns.ItemStem(pin)
    if stem then
      for i = 1, (self.max or 0) do
        local own = list[i]
        if i ~= index and own and ns.ItemStem(own) == stem then
          src, plainMove = i, true
          break
        end
      end
    end
  end
  -- A pin that is a bare id means "any copy of this item", so a drop of that id is that pin and moves
  -- it, whatever the cursor's link spells -- a typed-in id against a full stub, or a stub whose
  -- upgrade ids moved under it. An exact pin is a different matter: it names one copy, and a link
  -- that does not match it is another copy the drop is pinning in its place, so it is left alone --
  -- unless the link names no copy at all. Every enchant, gem and bonus id in it is then zero, which
  -- is what the client hands back for a worn piece it cannot take exactly, and taking that link as
  -- the new pin would flatten an enchanted ring to its bare id. The exact pin is moved instead.
  if not src and type(pin) == "number" then
    for i = 1, (self.max or 0) do
      local own = list[i]
      if i ~= index and own and ns.ItemStubID(own) == pin then src = i break end
    end
  elseif not src and ns.ItemPlain(pin) then
    local want = ns.ItemStubID(pin)
    for i = 1, (self.max or 0) do
      local own = list[i]
      if i ~= index and own and ns.ItemStubID(own) == want and not ns.ItemPlain(own) then
        src, plainMove = i, true
        break
      end
    end
  end
  if src then
    if plainMove then
      list[index], list[src] = list[src], nil
    else
      list[src], list[index] = list[index], list[src]
    end
    locsDirty = true
    later(true)
  elseif not (type(pin) == "number" and ns.GearItem(pin)) then
    -- A bare id is the whole pin for a stackable, but it names no copy of gear -- the same rule
    -- refuses a typed id. A drop that could not carry a link, the client answering a worn copy by
    -- id alone, must not flatten the pin it was lifted from into an id: nothing is pinned at all.
    self:Set(index, pin)
  end
end

-- IsShown is only about the cell itself, and a cell in a closed window is still shown, so
-- the sweep has to ask IsVisible or a closed bag window keeps paying for every spell
-- cooldown in the game.
function Fav:Cooldowns()
  for i = 1, (self.max or 0) do
    local b = self.slots[i]
    if b and b.link and b.holder:IsVisible() then ns.UpdateCooldown(b) end
  end
end

function Fav:Flush()
  if not self.cold or InCombatLockdown() then return end
  self:Warm()
  self:Refresh()
end

function Fav:Hide()
  if self.label then self.label:Hide() end
  if self.add then self.add:Hide() end
  local P = ns.Pocket
  if P and P.picksFrame and P.picksFrame:IsShown() and P.PicksMode and P:PicksMode() == "fav" then
    P.picksFrame:Hide()
  end
  for i = 1, (self.max or 0) do
    local b, g, c = self.slots[i], self.ghosts[i], self.catchers[i]
    if b then b.holder:Hide() end
    if g then g:Hide() end
    if c then c:Hide() end
  end
end

-- Everything the row needs is built here, out of combat, and a redraw only moves
-- frames after that. A slot button made during a fight is tainted for good, and the
-- overlay cannot be configured then either.
function Fav:Warm()
  local bags = ns.Bags
  local frame = bags and bags.frame
  if not frame then return end
  if InCombatLockdown() then self.cold = true; return end
  for i = 1, MAX_SLOTS do
    if not self.slots[i] then
      local b = ns.CreateBagItemButton(frame)
      b:RegisterForClicks(unpack(ns.CLICKS_USE))
      b:RegisterForDrag()
      b.wpeClicks, b.wpeLockable, b.wpeTotal = ns.CLICKS_USE, nil, true
      b.holder:Hide()
      self.slots[i] = b
    end
    if not self.ghosts[i] then
      local g = ns.PinGhost(frame)
      g:Hide()
      self.ghosts[i] = g
    end
    if not self.catchers[i] then
      local c = makeCatcher(frame, i)
      c:Hide()
      self.catchers[i] = c
    end
  end
  self.cold, self.warmed = nil, true
end

-- The section's own press: the popup asks the pocket where to stand, so the geometry it needs is the last
-- one this row was laid out with, read back rather than passed through every caller.
function Fav:OpenPicks()
  local P, a = ns.Pocket, self.args
  if not (P and P.TogglePicks and a and a.bags and a.bags.frame) then return end
  -- The two pickers are lists too, and two lists never stand together here: the popup takes their place
  -- instead of stacking over them. Where it stands owes them nothing -- it opens against the bags' own top
  -- left corner, lined up with the first column of the grid, whether or not either of them was up, and
  -- whether or not the pocket is.
  local CP, ChP = ns.CurPicker, ns.CharPicker
  if CP and CP.Close and CP.frame and CP.frame:IsShown() then CP:Close() end
  if ChP and ChP.Close and ChP.frame and ChP.frame:IsShown() then ChP:Close() end
  P:TogglePicks("fav", a.bags.frame, a.x, 0)
end

function Fav:Refresh()
  local a = self.args
  if a and a.bags and a.bags.frame and a.bags.frame:IsShown() then
    self:Apply(a.bags, a.x, a.top, a.size, a.gap)
  end
end

function Fav:Apply(bags, x, top, size, gap)
  if not (bags and bags.frame) then return 0 end
  local frame = bags.frame
  local d = ns.Density(size)
  self.args = { bags = bags, x = x, top = top, size = size, gap = gap }
  -- Our own drag holds the item itself, and pickup fires BAG_UPDATE_DELAYED at once: a scan taken
  -- then reads the bags without it and paints the pin's cell as a ghost for the rest of the drag.
  -- The item is not gone, it is on the cursor. The drop clears the cursor and asks again -- the
  -- frame-late pass in Drop, and PinFromCursor for a drop on a cell -- so waiting loses nothing.
  if self.lifted and CursorHasItem() then
    return d.labelH + d.labelGap + size + 6
  end
  if not self:Enabled() then
    self:Hide()
    return 0
  end
  if not self.label then
    -- The section names in the grid are accent (see the layout's SetTextColor), and these two are
    -- typographic peers of them: same face, same FONT - 4, same one word above a run of cells. Left at
    -- dim they were the only grey heads in a window painted in accent and azure, which read as a
    -- switched-off control rather than a caption. The ink is the sections' own, softened by alpha --
    -- the standing rule here is the same colour quieter, never a second colour -- so the four section
    -- heads still lead the two list heads above them.
    local fs = Theme:Label(frame, 11, "accent")
    fs:SetAlpha(0.85)
    fs:SetJustifyH("LEFT")
    ns.LocalText(fs, "Favorites")
    self.label = fs
  end
  self.label:SetFont(bags.fontPath or ns.Fonts:Current(), d.font - 4, ns.OutlineFlags())
  self.label:ClearAllPoints()
  ns.SnapPoint(self.label, "TOPLEFT", frame, "TOPLEFT", x, -top)
  self.label:Show()

  if not self.add then
    -- A word beside the head, the way Clear stands beside Recent: the way into the popular popup for a row
    -- that is empty or does not hold the item yet. A glyph square was a losing fight with the band the head
    -- lives in -- the box has to clear the cells below and the search field above, and the band is only as
    -- tall as a line of text plus its gap, so every size of it either touched the cells or hung over the
    -- search. A word sits on the head's own line, in the head's own font, and nothing has to be fitted.
    local c = ns.CreateTextButton(frame, 10)
    ns.LocalText(c.Text, "Add")
    -- The head's own faintness: a section head is a label drawn at 0.85 alpha, and a verb beside it at full
    -- strength reads as the brighter of the two -- a button shouting over its own caption. Same value here,
    -- so the pair sits on one ink; hover and the disabled state still move the colour, which the alpha does
    -- not touch.
    c:SetAlpha(0.85)
    c:SetScript("OnClick", function() Fav:OpenPicks() end)
    c:SetOn(true)
    ns.AddTip(c, "Popular", "top")
    self.add = c
  end
  self.add:ClearAllPoints()
  -- Hung off the head itself, centre on centre, so the two share a baseline at every density. Measured from
  -- the frame's top instead it sat a pixel low: a button's height and a font box are not the same number, and
  -- the difference lands under the smaller text. A step smaller than the head, as Clear is beside Recent.
  self.add.Text:SetFont(bags.fontPath or ns.Fonts:Current(), d.font - 5, ns.OutlineFlags())
  self.add:SetSize(math.ceil(self.add.Text:GetStringWidth()) + 8, d.labelH)
  ns.SnapPoint(self.add, "LEFT", self.label, "RIGHT", 8, 0)
  -- Read-only view of another character's vault: this section is that character's, and a list this window
  -- only shows is not something to write into from here.
  self.add:SetShown(not bags.snap)

  local cols = bags.cols or 14
  local n = math.min(cols, MAX_SLOTS)
  if not self.warmed then self:Warm() end
  local rowY = top + d.labelH + d.labelGap
  local list = self:List()
  local last = math.max(self.max or 0, n)
  self.max = last
  local gen = (bags.styleGen or 0) .. ":" .. tostring(bags.fontPath) .. ":" .. size
  local repaint = self.paintKey ~= gen
  self.paintKey = gen
  -- The scan runs before the loop reads the list, not inside the first locate: an
  -- adoption rewrites a stale pin in place, and the entry read before the scan would
  -- paint the old item string for a cycle.
  scan()
  local seen = {}
  for i = 1, n do
    local pin = list[i]
    local key = pin and ns.ItemKey(pin)
    if key and seen[key] then list[i], pin, key = nil, nil, nil end
    if key then seen[key] = true end
    local bag, slot = locate(pin)
    local px = x + (i - 1) * (size + gap)
    local b, g = self.slots[i], self.ghosts[i]
    if bag and not b then self.cold = true end
    local live = (bag and b) and true or false
    if live and (b.favBag ~= bag or b.favSlot ~= slot) then
      b.favBag, b.favSlot, b.wpeBagID = bag, slot, bag
      b.holder:SetID(bag)
      b:SetID(slot)
      b.link = nil
    end
    if live then
      local h = b.holder
      ns.SnapSize(h, size, size)
      h:ClearAllPoints()
      ns.SnapPoint(h, "TOPLEFT", frame, "TOPLEFT", px, -rowY)
      h:Show(); b:Show()
      if repaint then b.link = nil end
      ns.UpdateItemButton(b)
      if bags.ApplyToButton then bags:ApplyToButton(b) end
      if g then g:Hide() end
    else
      if g then
        ns.SnapBox(g, size, size)
        g:ClearAllPoints()
        ns.SnapPoint(g, "TOPLEFT", frame, "TOPLEFT", px, -rowY)
        ns.PaintPin(g, pin, pins)
        ns.ShowMark(g, false)
        -- A ghost is never a search hit, so it wears the row's dim while a query runs; set here too so
        -- one freshly placed mid-search starts dimmed instead of flashing full until the next pass.
        g:SetAlpha((bags.filters and not bags.filters.empty) and 0.20 or 1)
        g:Show()
      end
      if b then b.holder:Hide(); b.favBag = nil end
    end
    local c = self.catchers[i]
    if c then
      ns.SnapBox(c, size, size)
      c:ClearAllPoints()
      ns.SnapPoint(c, "TOPLEFT", frame, "TOPLEFT", px, -rowY)
      c.wpeLockable = live or nil
      c:Show()
    end
  end
  for i = n + 1, last do
    local b, g, c = self.slots[i], self.ghosts[i], self.catchers[i]
    if b then b.holder:Hide() end
    if g then g:Hide() end
    if c then c:Hide() end
  end
  -- An unchanged item takes the early return in UpdateItemButton, which also skips its
  -- cooldown, so a cooldown that started while this row was closed is never seen here
  -- until the next cooldown event. One pass after placing the cells closes that gap,
  -- and the cached start and duration keep an unchanged one nearly free.
  self:Cooldowns()
  return d.labelH + d.labelGap + size + 6
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:RegisterEvent("BAG_UPDATE_COOLDOWN")
ev:RegisterEvent("SPELL_UPDATE_COOLDOWN")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:RegisterEvent("EQUIPMENT_SETS_CHANGED")
ev:RegisterEvent("EQUIPMENT_SWAP_FINISHED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("ITEM_CHANGED")
ev:SetScript("OnEvent", function(_, event, a1, a2)
  if event == "PLAYER_REGEN_ENABLED" then
    Fav:Flush()
    return
  end
  if event == "ITEM_CHANGED" then
    if ns.PinRetarget(Fav:List(), MAX_SLOTS, a1, a2) then
      locsDirty = true
      Fav:Refresh()
    end
    return
  end
  if event == "BAG_UPDATE_DELAYED" or event == "PLAYER_EQUIPMENT_CHANGED"
     or event == "EQUIPMENT_SETS_CHANGED" or event == "EQUIPMENT_SWAP_FINISHED" then
    locsDirty = true
    Fav:Refresh()
    return
  end
  Fav:Cooldowns()
end)
