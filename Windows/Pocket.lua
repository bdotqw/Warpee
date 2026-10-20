local addonName, ns = ...
local Theme = ns.Theme

local Pocket = {}
ns.Pocket = Pocket
Pocket.slots, Pocket.ghosts, Pocket.catchers = {}, {}, {}
Pocket.recSlots, Pocket.recGhosts = {}, {}

local PAD, BAND = 12, 26
local NUDGE_BAND = 24
local LABEL_H, LABEL_GAP, SPLIT = 13, 4, 10
local BOX_H, BOX_GAP = 22, 8
local MAX_COLS, MAX_ROWS = 8, 6
local PICK_MAX, PICK_COLS = 64, 8
local PICK_SIZE, PICK_GAP, PICK_PAD = 36, 8, 12
local FONT, PICK_MINW = 15, 176

-- The pocket's cell size, and the one place it is read: the layout, the picks list and the
-- settings page all come through here. A pocket that has no number of its own takes the bags' size
-- once, where it is first asked -- the one-time move the key was added for -- and keeps it. Reading
-- the bags' size on every pass instead is what the key shipped as, and it is why resizing the bags
-- carried the pocket along and why a settings reset put it back to following them.
function ns.PocketIconSize()
  local n = WarpeeDB and tonumber(WarpeeDB.pocketIconSize)
  if n then return n end
  n = (WarpeeDB and tonumber(WarpeeDB.iconSize)) or 37
  if WarpeeDB then WarpeeDB.pocketIconSize = n end
  return n
end
-- The short name this file calls it by.
local pocketSize = ns.PocketIconSize

local function applyDensity()
  local d = ns.Density(pocketSize())
  PAD, BAND, NUDGE_BAND = d.pocketPad, d.pocketBand, d.pocketNudge
  LABEL_H, LABEL_GAP = d.labelH, d.labelGap
  BOX_H, BOX_GAP = d.searchH, d.pocketGap
  PICK_SIZE, PICK_GAP, PICK_PAD = d.pickSize, d.pickGap, d.pickPad
  FONT, PICK_MINW = d.font, d.pickMinW
end

-- Header buttons follow the pocket slot size the same way the bags follow theirs.
-- Dressing a cell is ns.SizeGlyph in Theme.lua now: the pocket, the bags and the bank each carried a copy.
-- A file local, so the call sites read as they always did.
local sizeGlyph = ns.SizeGlyph

local POCKET_PICKS = {
  259085, -- Void-Touched Augment Rune
  132514, -- Auto-hammer
  248409, -- W-47CH D0G
  244639, -- Void-Touched Drums
  248137, -- M3DDY
  269586, -- Emergency Soul Link
  248486, -- Emergency Soul Link
  109076, -- Goblin Glider Kit
  272195, -- Vantus Rune: Tides
  243734, -- Thalassian Phoenix Oil
  113509, -- Conjured Mana Bun
  242747, -- Hearty Royal Roast
  271884, -- Concentrated Silvermoon Health Potion
  271883, -- Concentrated Silvermoon Health Potion
  241300, -- Lightfused Mana Potion
  241301, -- Lightfused Mana Potion
  245916, -- Fleeting Lightfused Mana Potion
  241308, -- Light's Potential
  241309, -- Light's Potential
  245898, -- Fleeting Light's Potential
  241292, -- Draught of Rampant Abandon
  241293, -- Draught of Rampant Abandon
  245910, -- Fleeting Draught of Rampant Abandon
  241288, -- Potion of Recklessness
  241289, -- Potion of Recklessness
  245902, -- Fleeting Potion of Recklessness
  271887, -- Liquid Luster
  271886, -- Liquid Luster
  274764, -- Fleeting Liquid Luster
  241324, -- Flask of the Blood Knights
  241325, -- Flask of the Blood Knights
  245931, -- Fleeting Flask of the Blood Knights
  241326, -- Flask of the Shattered Sun
  241327, -- Flask of the Shattered Sun
  245929, -- Fleeting Flask of the Shattered Sun
  241322, -- Flask of the Magisters
  241323, -- Flask of the Magisters
  245933, -- Fleeting Flask of the Magisters
  241320, -- Flask of Thalassian Resistance
  241321, -- Flask of Thalassian Resistance
  245926, -- Fleeting Flask of Thalassian Resistance
  241302, -- Void-Shrouded Tincture
  241303, -- Void-Shrouded Tincture
  241334, -- Vicious Thalassian Flask of Honor
}

local function charKey()
  local n = UnitName("player") or "?"
  local r = (GetNormalizedRealmName and GetNormalizedRealmName())
            or (GetRealmName and GetRealmName()) or "?"
  return n .. "-" .. r
end

function Pocket:Enabled()
  return not (WarpeeDB and WarpeeDB.pocketShow == false)
end

-- Its own lock, not the one the bags and the bank share. The pocket is dragged far more often
-- than the two big windows, and freezing all three together meant the only way to nudge it was
-- to unfreeze everything. The login block seeds this from the old lock once, so a save written
-- before the split keeps the pocket where it was left.
function Pocket:Locked()
  return (WarpeeDB and WarpeeDB.pocketLock) and true or false
end

function Pocket:ToggleLock()
  if WarpeeDB then WarpeeDB.pocketLock = not self:Locked() end
  self:Layout()
end

function Pocket:Cols()
  local n = math.floor(tonumber(WarpeeDB and WarpeeDB.pocketCols) or 6)
  return math.max(4, math.min(MAX_COLS, n))
end

function Pocket:Rows()
  local n = math.floor(tonumber(WarpeeDB and WarpeeDB.pocketRows) or 5)
  return math.max(1, math.min(MAX_ROWS, n))
end

function Pocket:Count()
  return self:Cols() * self:Rows()
end

local function paintTitle()
  local t = Pocket.title
  if not t then return end
  local k = Pocket:Cols() >= 8 and "FANNY PACK" or "POCKET"
  if Pocket.titleKey ~= k then
    Pocket.titleKey = k
    ns.LocalText(t, k)
  end
end

function Pocket:List()
  WarpeeDB.pocket = WarpeeDB.pocket or {}
  local k = charKey()
  WarpeeDB.pocket[k] = WarpeeDB.pocket[k] or {}
  return WarpeeDB.pocket[k]
end

-- Pinned cells are shared with the favorites row in the bag window. Read the block above
-- ns.PinArg in ItemButton.lua before touching anything a cell knows or shows, and make the
-- change there so both rows get it: this file owns only the window, the layout, the tooltip
-- and the click overlay. The lists themselves stay apart, this one is its own.
local pins = {}
local keyDirty = true

local function scan()
  if not keyDirty then return end
  keyDirty = false
  ns.PinScan(Pocket:List(), Pocket:Count(), pins)
end

local function locate(pin)
  scan()
  return ns.PinLocate(pin, pins)
end

local function worn(pin)
  scan()
  return ns.PinWorn(pin, pins)
end

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
    Pocket:Refresh()
    if tipDirty then tipDirty = false; Pocket:Tip() end
  end)
end

local function tipFor(c, index)
  local pin = Pocket:List()[index]
  GameTooltip:SetOwner(c, "ANCHOR_RIGHT")
  if pin then
    local b = Pocket.slots[index]
    if b and b.pkBag and b.holder:IsShown() then
      GameTooltip:SetBagItem(b.pkBag, b.pkSlot)
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
    GameTooltip:SetText(ns.L["Pocket"])
    GameTooltip:AddLine(ns.TipInk(ns.L["Drag an item here for quick access"], 0.9, 0.9, 0.9),
      0.9, 0.9, 0.9, true)
  end
  GameTooltip:Show()
end

-- A pin that lands or moves changes what the cell under the pointer is showing, and the
-- placement itself is a frame late, so the tooltip is rebuilt after the refresh and not at
-- the moment of the change: by then the cursor has let go of the item, and IsMouseOver
-- answers about the cell instead of about a drag still in flight.
function Pocket:Tip()
  for i = 1, (self.max or 0) do
    local c = self.catchers[i]
    if c and c:IsShown() and c:IsMouseOver() then tipFor(c, i) end
  end
end

-- The overlay owns the left button for good and passes the right button down to the
-- slot, so a right click reaches the game's handler with no addon code in the path.
-- SetPassThroughButtons is refused during combat lockdown, so it is set here, once,
-- and never touched again. Emptying a cell is on a key rather than on a fourth modifier,
-- because Ctrl is the game's own dress-up and this cell can have it back: the overlay hands
-- the modified click to HandleModifiedItemClick, which is the same branch the grid reaches.
-- The overlay must never finish a pending item spell itself: C_Container.UseContainerItem
-- from addon code is refused as ADDON_ACTION_FORBIDDEN, traceback 2026-09-05. An enchant
-- or a gem lands only in the bag grid: the game runs that from the left button of its
-- own slot handler, and every row here keeps the right button alone.
local function makeCatcher(parent, index)
  local c = CreateFrame("Button", nil, parent)
  c.pkIndex = index
  c:RegisterForClicks("LeftButtonUp", "MiddleButtonUp", "RightButtonUp")
  c:RegisterForDrag("LeftButton")
  c:SetFrameLevel(parent:GetFrameLevel() + 30)
  c:EnableMouse(true)
  if c.SetPassThroughButtons then c:SetPassThroughButtons("RightButton") end
  c:SetScript("OnDragStart", function(s) Pocket:Lift(s.pkIndex) end)
  c:SetScript("OnDragStop", function() Pocket:Drop() end)
  c:SetScript("OnReceiveDrag", function(s) Pocket:PinFromCursor(s.pkIndex) end)
  c:SetScript("OnClick", function(s, button)
    if button == "MiddleButton" then
      -- Direct click, not a binding: mouse chords never reach us, and a
      -- key-bound middle keeps its owner.
      if (GetBindingAction("BUTTON3") or "") == "" then Pocket:Unpin(s.pkIndex) end
      return
    end
    if button ~= "LeftButton" then return end
    if GetCursorInfo() then
      Pocket:PinFromCursor(s.pkIndex)
      return
    end
    if IsShiftKeyDown() and not (IsControlKeyDown() or IsAltKeyDown()) then
      Pocket:Link(s.pkIndex)
      return
    end
    if IsAltKeyDown() and not (IsShiftKeyDown() or IsControlKeyDown()) then
      Pocket:Lock(s.pkIndex)
      return
    end
    -- The cell wears a live slot when the item is with you and a ghost when it is not, and
    -- the location comes off the cell either way: a ghost carries none and the shared call
    -- falls back to the link.
    if IsModifiedClick("DRESSUP") then
      local b = Pocket.slots[s.pkIndex]
      ns.PinDressUp(b and b.pkBag, b and b.pkSlot, Pocket:List()[s.pkIndex])
    end
  end)
  c:SetScript("OnEnter", function(s)
    local b = Pocket.slots[s.pkIndex]
    if b and b.holder:IsShown() then ns.SetSlotHighlight(b, true) end
    tipFor(s, s.pkIndex)
  end)
  c:SetScript("OnLeave", function(s)
    local b = Pocket.slots[s.pkIndex]
    if b then ns.SetSlotHighlight(b, false) end
    GameTooltip:Hide()
  end)
  ns.PinWatch(c, function() Pocket:Unpin(index) end)
  return c
end

function Pocket:Link(index)
  local pin = self:List()[index]
  if not (pin and ChatEdit_InsertLink) then return end
  local b = self.slots[index]
  local link
  if b and b.pkBag and b.holder:IsShown() then
    link = C_Container.GetContainerItemLink(b.pkBag, b.pkSlot)
  end
  if not link then link = select(2, C_Item.GetItemInfo(pin)) end
  if link then ChatEdit_InsertLink(link) end
end

function Pocket:Set(index, pin)
  local list = self:List()
  if pin then
    local k = ns.ItemKey(pin)
    for i, own in pairs(list) do
      if i ~= index and k and ns.ItemKey(own) == k then list[i] = nil end
    end
  end
  list[index] = pin or nil
  keyDirty = true
  later(true)
end

function Pocket:Unpin(index)
  if not self:List()[index] then return end
  self:Set(index, nil)
end

-- Grey the pocket cell mirroring a bag slot that just locked or unlocked, so a pinned or recent-in-pocket
-- item picked up or mid-move desaturates like the grid cell it tracks. Both cell pools (pinned and the
-- recent row) bind a real (pkBag, pkSlot); scan both and grey the one that matches.
function Pocket:RefreshLock(bag, slot)
  for _, pool in ipairs({ self.slots, self.recSlots }) do
    for _, b in pairs(pool) do
      if b and b.pkBag == bag and b.pkSlot == slot and b.holder and b.holder:IsVisible() then
        ns.UpdateItemLock(b)
        return
      end
    end
  end
end

function Pocket:Lock(index)
  local pin = self:List()[index]
  local id = ns.ItemStubID(pin)
  local V = ns.Vendor
  if not (id and V and V.CycleSell) then return end
  -- The copy's own link, so a piece of gear is named by its exact string and not by its id: the live
  -- cell first, then the pin itself when it was kept as one.
  local b = self.slots[index]
  local live = b and b.pkBag and b.holder:IsShown()
  local link
  if live then
    link = C_Container.GetContainerItemLink(b.pkBag, b.pkSlot)
  end
  if not link and type(pin) == "string" then link = pin end
  -- The same gate the cell's own alt-click obeys, so this row cannot mark what the bags refuse.
  if not V:Markable(live and b.pkBag, live and b.pkSlot, id, link) then return end
  V:CycleSell(id, link, (link and link:match("%[(.-)%]")) or (C_Item.GetItemInfo(id)) or tostring(id))
  local c = self.catchers[index]
  if c and c:IsShown() and c:IsMouseOver() then tipFor(c, index) end
end

function Pocket:Lift(index)
  -- A drag always starts clean: OnDragStop is what clears these, and a drag that ended without one
  -- would otherwise leave the next drop, an item dragged in from the bags, looking like our own move.
  self.lifted, self.liftFrom = nil, nil
  local pin = self:List()[index]
  if not pin then return end
  self.moving = index
  local b = self.slots[index]
  local live = (b and b.pkBag) and true or false
  if b then ns.SetSlotHighlight(b, true) end
  if ns.ItemSound then ns.ItemSound("pickup", b and b.pkBag, b and b.pkSlot) end
  -- The cell is an overlay over a slot it only mirrors, so the game picks nothing up by itself: the
  -- item behind the pin goes on the cursor by hand, and from there the drag is the game's own -- the
  -- bar's drop handler writes the item action, a bag slot moves the piece -- with the cursor art the
  -- game draws, so there is no art of this window's to follow the pointer. A live cell names the
  -- exact bag slot, and the container reader takes that copy. A ghost has no slot, so the client
  -- resolves its link on its own -- that is the drag worth keeping: the bar takes it and the pointer
  -- gets the game's art -- and the drag is taken as ours whatever the client answers, because
  -- rebuilding the pin from the cursor's link is exactly what used to lose the enchant. The answer
  -- can also come a beat late, so an empty cursor here is no failure: the pickup is left as it is,
  -- the game's drag shows when it shows, and the pin still moves by our own bookkeeping.
  self.liftFrom = nil
  if live then
    if not GetCursorInfo() and ns.PinPickup(pin, b.pkBag, b.pkSlot) then
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

function Pocket:Drop()
  local from = self.moving
  self.moving = nil
  if not from then return end
  local b = self.slots[from]
  if b then ns.SetSlotHighlight(b, false) end
  if ns.ItemSound then ns.ItemSound("drop", b and b.pkBag, b and b.pkSlot) end
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
      Pocket.lifted, Pocket.liftFrom = nil, nil
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

function Pocket:PinFromCursor(index)
  -- A drop of a pin this strip itself lifted is a move, not a new pin: the two seats trade the pins
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
      keyDirty = true
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
  if ns.ItemSound then ns.ItemSound("drop", locate(pin)) end
  -- A pin lifted out of this strip comes back as an item on the cursor, so this is also where a drag
  -- across the strip reorders when the lift could not say where it started; the item is matched by
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
    keyDirty = true
    later(true)
  elseif not (type(pin) == "number" and ns.GearID(pin)) then
    -- A bare id is the whole pin for a stackable, but it names no copy of gear -- the same rule
    -- refuses a typed id. A drop that could not carry a link, the client answering a worn copy by
    -- id alone, must not flatten the pin it was lifted from into an id: nothing is pinned at all.
    self:Set(index, pin)
  end
end

function Pocket:DropID(id)
  id = tonumber(id)
  if not id then return false end
  local list = self:List()
  for i = 1, self:Count() do
    if ns.ItemStubID(list[i]) == id then
      self:Set(i, nil)
      if self.picksFrame and self.picksFrame:IsShown() then self:PickPaint() end
      return true
    end
  end
  return false
end

function Pocket:AddID(id, pin)
  id = tonumber(id)
  if not id then return false end
  if not pin and ns.GearID(id) then
    print("|cffd9a85fWarpee|r |cffffffff"
      .. (ns.L["Gear is pinned by dragging it or pasting its link, a bare id cannot tell one copy from another."] or "") .. "|r")
    return false
  end
  local list = self:List()
  local n = self:Count()
  for i = 1, n do
    if ns.ItemStubID(list[i]) == id then return false end
  end
  for i = 1, n do
    if not list[i] then
      if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
      self:Set(i, pin or id)
      if self.picksFrame and self.picksFrame:IsShown() then self:PickPaint() end
      C_Timer.After(0.4, function() Pocket:Refresh() end)
      return true
    end
  end
  return false
end

function Pocket:AddByText(text)
  local s = tostring(text or "")
  local link = s:match("|H(item:[^|]+)|h") or s:match("^(item:[^|%s]+)")
  local id = tonumber(s:match("item:(%d+)")) or tonumber(s:match("%d+"))
  if not id then return end
  local get = C_Item and C_Item.GetItemInfoInstant
  if get and not get(id) then return end
  self:AddID(id, link and ns.PinFor(id, link) or nil)
end

function Pocket:Cooldowns()
  if not (self.frame and self.frame:IsShown()) then return end
  for i = 1, (self.max or 0) do
    local b = self.slots[i]
    if b and b.link and b.holder:IsVisible() then ns.UpdateCooldown(b) end
  end
  for i = 1, (self.recMax or 0) do
    local b = self.recSlots[i]
    if b and b.link and b.holder:IsVisible() then ns.UpdateCooldown(b) end
  end
end

function Pocket:Build()
  if self.frame then return self.frame end
  local w = CreateFrame("Frame", "WarpeePocket", UIParent, "BackdropTemplate")
  Theme:Panel(w, "bg", "stroke")
  Theme:Window(w, "WarpeePocket")
  w:SetFrameStrata("HIGH")
  -- The pocket had no panel of its own: its cells stood on the window's own paint, while the
  -- cells of the bags stand on one. Same rect, laid out in every pass of the layout.
  local gridBg = Theme:Rect(w, "panel", "BACKGROUND")
  gridBg:SetDrawLayer("BACKGROUND", 1)
  self.gridBg = gridBg
  w:SetClampedToScreen(true)
  w:SetMovable(true)
  w:EnableMouse(true)
  w:RegisterForDrag("LeftButton")
  w:SetScript("OnDragStart", function(s)
    if Pocket:Locked() then return end
    ns.DragMove(s)
  end)
  w:SetScript("OnDragStop", function(s)
    if not s.wpeMoving then return end
    s.wpeMoving = nil
    s:StopMovingOrSizing()
    ns.Rebase(s, "pocketPos", "CENTER")
    ns.SeamDrop(s)
  end)
  ns.EscClose(w)
  ns.PixelJob(w, function(s) ns.AlignToScreen(s) end, "align")

  local title = Theme:Title(w, 14, "accent")
  self.title = title
  paintTitle()

  local close = ns.CreateGlyphButton(w, "×")
  close:SetScript("OnClick", function() Pocket:Close() end)
  close.wpeIconPaint = function(s)
    local hot = s.wpeHot and not s.offDuty
    ns.TintMarkX(s, hot and "text" or "dim")
  end
  close.wpeIconPaint(close)
  self.closeBtn = close

  -- The gear as art on the icon path rather than a texture escape inside the label, the way the bags
  -- and the bank carry theirs: only a real texture can be given the ground the drawn marks wear, and
  -- the layout below sizes it off the header box like every other icon: 62% of this box, the same
  -- share the bags and the bank give the same 16px cog.
  local gear = ns.CreateGlyphButton(w, "")
  gear:SetScript("OnClick", function() if ns.Options then ns.Options:Toggle() end end)
  -- The key, not ns.L[key]: the tip resolves it on every show, so a language switch reaches it
  -- without a reload (a pre-resolved word would freeze in the language it was built in).
  ns.AddTip(gear, "Settings", "top")
  local gearIcon = gear:CreateTexture(nil, "ARTWORK")
  gearIcon:SetTexture([[Interface\AddOns\Warpee\Media\Icons\gear.tga]])
  gearIcon:SetPoint("CENTER")
  gear.icon = gearIcon
  gear.iconPct = 62
  gear.wpeIconPaint = function(s)
    if not s.icon then return end
    local hot = s.wpeHot and not s.offDuty
    s.icon:SetVertexColor(Theme:C(hot and "text" or "dim"))
  end
  gear.wpeIconPaint(gear)
  ns.IconSilhouette(gear, gearIcon)
  self.gearBtn = gear

  local plus = ns.CreateGlyphButton(w, "+")
  plus:SetScript("OnClick", function() Pocket:TogglePicks() end)
  ns.AddTip(plus, "Popular", "top")
  plus.wpeMarkW = 2
  plus.wpeIconPaint = function(s)
    local hot = s.wpeHot and not s.offDuty
    ns.TintMarkX(s, hot and "text" or "dim")
  end
  plus.wpeIconPaint(plus)
  ns.FitMarkPlus(plus)
  self.plusBtn = plus

  -- The lock is drawn in code, like the X and the plus, and carries its own ground. State is shown by
  -- the shape of the shackle, not by colour: closed = locked, open (the shackle hinged up on the left,
  -- the universal open-padlock) = unlocked. The glyph keeps the row's own ink in both states (dim at
  -- rest, text under the pointer) with no accent, so nothing in the row jumps. wpeLockHinge tells the
  -- fit to reserve headroom for the lift in both states, so the body never moves when it toggles;
  -- wpeLockOpen picks the pose. The paint runs on every hover, so the pose is reasserted there.
  local lock = ns.CreateGlyphButton(w, "lock")
  lock.wpeLockHinge = true
  lock:SetScript("OnClick", function() Pocket:ToggleLock() end)
  lock.wpeIconPaint = function(s)
    local hot = s.wpeHot and not s.offDuty
    s.wpeLockOpen = not Pocket:Locked()
    ns.TintMarkX(s, hot and "text" or "dim")
    ns.FitMarkLock(s)
  end
  ns.AddTip(lock, function() return ns.L["Lock the pocket"] end, "top")
  self.lockBtn = lock

  self.nudge = ns.CreateNudgeRow(w, "pocketPos")

  local rec = Theme:Label(w, 11, "dim")
  rec:SetJustifyH("LEFT")
  ns.LocalText(rec, "Recent")
  rec:Hide()
  self.recLabel = rec

  local clr = ns.CreateTextButton(w, 10)
  ns.LocalText(clr.Text, "Clear")
  clr:SetScript("OnClick", function(s)
    if s.wpeOn and ns.Recent then ns.Recent:Wipe() end
  end)
  clr:Hide()
  self.recWipe = clr

  local picks = CreateFrame("Frame", "WarpeePocketPicks", UIParent, "BackdropTemplate")
  Theme:Panel(picks, "bg", "stroke")
  Theme:Window(picks)
  picks:SetFrameStrata("HIGH")
  picks:SetClampedToScreen(true)
  picks:EnableMouse(true)
  picks:Hide()
  ns.EscClose(picks)
  self.picksFrame = picks

  local ptitle = Theme:Title(picks, 14, "accent")
  ns.LocalText(ptitle, "Popular")
  self.picksTitle = ptitle

  local pclose = ns.CreateGlyphButton(picks, "×", 22)
  pclose:SetScript("OnClick", function() Pocket:TogglePicks() end)
  pclose.wpeIconPaint = function(s)
    local hot = s.wpeHot and not s.offDuty
    ns.TintMarkX(s, hot and "text" or "dim")
  end
  pclose.wpeIconPaint(pclose)
  self.picksClose = pclose

  self.pickBtns = {}
  for i = 1, PICK_MAX do
    local b = CreateFrame("Button", nil, picks, "BackdropTemplate")
    ns.PixelBackdrop(b)
    ns.SetBg(b, Theme:C("slot"))
    ns.SetEdge(b, Theme:C("emptyLine"))
    local function pickBorder(s)
      ns.SetEdge(s, Theme:C(s.wpePinned and "accent" or "emptyLine"))
    end
    Theme:Track(b, function(s)
      ns.SetBg(s, Theme:C("slot"))
      pickBorder(s)
    end)
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnEnter", function(s)
      ns.SetBg(s, Theme:C("panelHi"))
      ns.SetEdge(s, Theme:C("accent"))
      GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
      if s.wpeID then
        GameTooltip:SetItemByID(s.wpeID)
        if s.wpePinned then
          GameTooltip:AddLine(ns.TipInk(ns.L["Already in the pocket"], 0.9, 0.9, 0.9), 0.9, 0.9, 0.9, true)
        end
      end
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(s)
      ns.SetBg(s, Theme:C("slot"))
      pickBorder(s)
      GameTooltip:Hide()
    end)
    b:SetScript("OnClick", function(s)
      if not s.wpeID then return end
      if s.wpePinned then
        Pocket:DropID(s.wpeID)
      elseif Pocket:AddID(s.wpeID) then
        if ns.ItemSound then ns.ItemSound("pickup") end
      end
    end)
    local ic = b:CreateTexture(nil, "ARTWORK")
    ic:SetPoint("TOPLEFT", 1, -1)
    ic:SetPoint("BOTTOMRIGHT", -1, 1)
    ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.icon = ic
    local tier = b:CreateTexture(nil, "OVERLAY")
    tier:SetPoint("TOPLEFT", b, "TOPLEFT", -3, 2)
    tier:Hide()
    b.tier = tier
    b:Hide()
    self.pickBtns[i] = b
  end

  -- The same id field the category editor's pin entry uses (Core/Widgets.lua): a number box that takes
  -- nothing but digits, with a live preview of the item that id names beside it, so what was typed is seen
  -- to resolve before it lands in the pocket — the icon and the name, exactly as the pins panel shows
  -- them. Enter adds it and the "+" does the same; a shift-clicked link arrives as its bare id. It used to
  -- be the plain search box, which took any text and gave nothing back until the item showed up in the
  -- grid. Losing focus still empties it, the way the old field did, so nothing typed is left standing when
  -- the panel closes.
  local field = ns.CreateIdField(picks, {
    hint = "Add ID",
    height = BOX_H,
    font = FONT - 2,
    smallFont = FONT - 3,
    onCommit = function(id) Pocket:AddByText(id) end,
  })
  self.idField = field

  w:Hide()
  self.frame = w
  if ns.Theme and ns.Theme.ApplyWindowAlpha then ns.Theme:ApplyWindowAlpha() end
  return w
end

-- Every cell is a container slot button, so all of them are built here, out of combat,
-- and a redraw only moves and re-ids them after that. A button made during a fight is
-- tainted for good, and the overlay above it cannot be configured then either.
function Pocket:Warm()
  if not self:Enabled() then return end
  local w = self:Build()
  if InCombatLockdown() then self.cold = true; return end
  local n = self:Count()
  for i = 1, n do
    if not self.slots[i] then
      local b = ns.CreateItemButton(w, 0, 1)
      b:RegisterForClicks(unpack(ns.CLICKS_USE))
      b:RegisterForDrag()
      b.wpeClicks, b.wpeLockable, b.wpeTotal = ns.CLICKS_USE, nil, true
      b.holder:Hide()
      self.slots[i] = b
    end
    if not self.ghosts[i] then
      local g = ns.PinGhost(w)
      ns.ShowMark(g, false)
      g:Hide()
      self.ghosts[i] = g
    end
    if not self.catchers[i] then
      local c = makeCatcher(w, i)
      c:Hide()
      self.catchers[i] = c
    end
  end
  local m = self:Cols()
  for i = 1, m do
    if not self.recSlots[i] then
      -- The same cells the bag row draws, and the pocket had them a button short of
      -- it: the factory registers both mouse buttons and the drag, and this row wants
      -- all three now that the cell answers for itself.
      local b = ns.CreateItemButton(w, 0, 1)
      b.wpeClicks, b.wpeLockable, b.wpeTotal = ns.CLICKS_SLOT, nil, nil
      b.wpeNoNew, b.wpeNoReagent = true, true
      b.holder:Hide()
      self.recSlots[i] = b
    end
    if not self.recGhosts[i] then
      local g = ns.SlotGhost(w)
      ns.ShowMark(g, false)
      g.icon:Hide()
      ns.RecMark(g)
      g:Hide()
      self.recGhosts[i] = g
    end
  end
  self.cold = nil
  self.warmed = math.max(self.warmed or 0, n)
  self.recWarmed = math.max(self.recWarmed or 0, m)
end

function Pocket:Flush()
  if not self.cold or InCombatLockdown() then return end
  self:Warm()
  self:Refresh()
end

function Pocket:Layout()
  local w = self.frame
  if not w then return end
  applyDensity()
  if w.wpeNudge then w.wpeNudge:Size(ns.Density(pocketSize()).arrow) end
  local Bags = ns.Bags
  local size, gap, step = ns.GridMetrics(w, ns.PocketIconSize(), Bags and Bags.gap or 4)
  local cols, rows = self:Cols(), self:Rows()
  local n = cols * rows
  if (self.warmed or 0) < n or (self.recWarmed or 0) < cols then self:Warm() end
  local band = Theme:HeaderBand(w, BAND)
  local head = band and (band + 6) or (30 + Theme:TopInset())
  local mid = (band or head) / 2 + Theme:TitleDrop()
  local path = ns.Fonts:Current()
  self.title:SetFont(path, FONT - 1, ns.OutlineFlags())
  paintTitle()
  self.title:ClearAllPoints()
  ns.SnapPoint(self.title, "LEFT", w, "TOPLEFT", PAD, -mid)
  local hb = math.min(ns.Density(pocketSize()).pocketBand - 4, 24)
  sizeGlyph(self.closeBtn, hb)
  sizeGlyph(self.gearBtn, hb)
  sizeGlyph(self.lockBtn, hb)
  sizeGlyph(self.plusBtn, hb)
  self.closeBtn:ClearAllPoints()
  ns.SnapPoint(self.closeBtn, "RIGHT", w, "TOPRIGHT", -6, -mid)
  local rightBtn = self.closeBtn
  if self.gearBtn then
    self.gearBtn:ClearAllPoints()
    ns.SnapPoint(self.gearBtn, "RIGHT", rightBtn, "LEFT", -4, 0)
    rightBtn = self.gearBtn
  end
  -- The lock sits between the gear and the plus, so the plus keeps the outermost slot it has
  -- always had and the new button is the one that moves in.
  if self.lockBtn then
    self.lockBtn:ClearAllPoints()
    ns.SnapPoint(self.lockBtn, "RIGHT", rightBtn, "LEFT", -4, 0)
    rightBtn = self.lockBtn
    -- The lock's state is an accent underline the paint shows or hides, so the flip only has to ask for
    -- the repaint -- sizeGlyph above repaints on a size change alone and would leave the mark wearing the
    -- old state otherwise.
    self.lockBtn:Repaint()
    self.lockBtn:Show()
  end
  if self.plusBtn then
    self.plusBtn:ClearAllPoints()
    ns.SnapPoint(self.plusBtn, "RIGHT", rightBtn, "LEFT", -4, 0)
    rightBtn = self.plusBtn
  end

  local gen = ((Bags and Bags.styleGen) or 0) .. ":" .. tostring(path) .. ":" .. size
  -- Only drop a cell's cached link when the style generation moved (theme/font/size/badge change), the
  -- way Favorites and Recent gate it. Without this the loops below cleared b.link every pass, so
  -- UpdateItemButton's early return (b.link == link and ...) never held and every live cell repainted in
  -- full on every Layout -- and Layout runs on each bag event while the pocket is open.
  local repaint = self.paintKey ~= gen
  self.paintKey = gen

  local R = ns.Recent
  local recOn = (R and R:PocketOn()) and true or false
  local y = head
  if recOn then
    self.recLabel:SetFont(path, FONT - 4, ns.OutlineFlags())
    self.recLabel:ClearAllPoints()
    ns.SnapPoint(self.recLabel, "TOPLEFT", w, "TOPLEFT", PAD, -y)
    self.recLabel:Show()
    local capY = y
    y = y + LABEL_H + LABEL_GAP
    local feed = R:Feed(cols)
    self.recWipe.Text:SetFont(path, FONT - 5, ns.OutlineFlags())
    self.recWipe:SetSize(math.ceil(self.recWipe.Text:GetStringWidth()) + 8, LABEL_H)
    self.recWipe:ClearAllPoints()
    ns.SnapPoint(self.recWipe, "TOPLEFT", w, "TOPLEFT",
                 PAD + math.ceil(self.recLabel:GetStringWidth()) + 10, -capY)
    self.recWipe:SetOn(feed[1] and true or false)
    self.recWipe:Show()
    for i = 1, math.max(cols, self.recMax or 0) do
      local b, g = self.recSlots[i], self.recGhosts[i]
      if b then b.wpeCell = size end
      if g then g.wpeCell = size end
      local id = (i <= cols) and feed[i] or nil
      local bag, slot = R:Where(id)
      if id and bag and not b then self.cold = true end
      local live = (id and bag and b) and true or false
      if live then
        if b.pkBag ~= bag or b.pkSlot ~= slot then
          b.pkBag, b.pkSlot, b.wpeBagID = bag, slot, bag
          b.holder:SetID(bag)
          b:SetID(slot)
          b.link = nil
        end
        local h = b.holder
        ns.SnapSize(h, size, size)
        h:ClearAllPoints()
        ns.SnapPoint(h, "TOPLEFT", w, "TOPLEFT", PAD + (i - 1) * step, -y)
        h:Show(); b:Show()
        b.wpeForce = R:Got(id)
        if repaint then b.link = nil end
        ns.UpdateItemButton(b)
        if g then g:Hide() end
      else
        if b then b.holder:Hide(); b.pkBag, b.wpeForce = nil, nil end
        if g and i <= cols then
          ns.SnapBox(g, size, size)
          g:ClearAllPoints()
          ns.SnapPoint(g, "TOPLEFT", w, "TOPLEFT", PAD + (i - 1) * step, -y)
          ns.PaintGhostBg(g)
          g:Show()
        elseif g then
          g:Hide()
        end
      end
    end
    self.recMax = cols
    y = y + size + SPLIT
  else
    self.recLabel:Hide()
    self.recWipe:Hide()
    for i = 1, (self.recMax or 0) do
      local b, g = self.recSlots[i], self.recGhosts[i]
      if b then b.holder:Hide(); b.pkBag, b.wpeForce = nil, nil end
      if g then g:Hide() end
    end
  end

  -- The scan runs before the loop reads the list, not inside the first locate: an
  -- adoption rewrites a stale pin in place, and the entry read before the scan would
  -- paint the old item string for a cycle.
  scan()
  local list = self:List()
  local gridTop = y
  local seen = {}
  for i = 1, math.max(n, self.max or 0) do
    local b, g, c = self.slots[i], self.ghosts[i], self.catchers[i]
    if i > n then
      if b then b.holder:Hide() end
      if g then g:Hide() end
      if c then c:Hide() end
    else
      local pin = list[i]
      local key = pin and ns.ItemKey(pin)
      if key and seen[key] then list[i], pin, key = nil, nil, nil end
      if key then seen[key] = true end
      local px = PAD + ((i - 1) % cols) * step
      local py = gridTop + math.floor((i - 1) / cols) * step
      -- The badges of this window are measured against its own cell. The pocket has a size of
      -- its own and its cells belong to no view the badge reader could ask, so without this a
      -- pocket set to another size would draw its badges at the bags' measure.
      if b then b.wpeCell = size end
      if g then g.wpeCell = size end
      local bag, slot = locate(pin)
      if bag and not b then self.cold = true end
      local live = (bag and b) and true or false
      if live and (b.pkBag ~= bag or b.pkSlot ~= slot) then
        b.pkBag, b.pkSlot, b.wpeBagID = bag, slot, bag
        b.holder:SetID(bag)
        b:SetID(slot)
        b.link = nil
      end
      if live then
        local h = b.holder
        ns.SnapSize(h, size, size)
        h:ClearAllPoints()
        ns.SnapPoint(h, "TOPLEFT", w, "TOPLEFT", px, -py)
        h:Show(); b:Show()
        if repaint then b.link = nil end
        ns.UpdateItemButton(b)
        if g then g:Hide() end
      else
        if b then b.holder:Hide(); b.pkBag = nil end
        if g then
          ns.SnapBox(g, size, size)
          g:ClearAllPoints()
          ns.SnapPoint(g, "TOPLEFT", w, "TOPLEFT", px, -py)
          ns.PaintPin(g, pin, pins)
          g:Show()
        end
      end
      if c then
        ns.SnapBox(c, size, size)
        c:ClearAllPoints()
        ns.SnapPoint(c, "TOPLEFT", w, "TOPLEFT", px, -py)
        c.wpeLockable = live or nil
        c:Show()
      end
    end
  end
  self.max = n
  self:Cooldowns()
  -- The band under the arrows is reserved whether they are up or not. Locking a window is not
  -- a resize: the pocket used to shrink by the band the moment it was pinned, so pinning it
  -- moved everything in it. Only the arrows themselves come and go.
  local editable = not self:Locked()
  if self.nudge then self.nudge:SetShown(editable) end
  local foot = gridTop + (rows - 1) * step + size + BOX_GAP
  -- The plate runs the whole window, the band under the arrows included, and stops only under a
  -- skin's own header (Theme:FitPlate).
  Theme:FitPlate(self.gridBg, w)
  ns.SnapSize(w, PAD * 2 + cols * step - gap, foot + NUDGE_BAND)
  ns.AlignToScreen(w)
  local free = 0
  if rightBtn and rightBtn.GetLeft then
    local rl, wl = rightBtn:GetLeft(), w:GetLeft()
    if rl and wl then free = rl - wl - PAD - 4 end
  end
  self.title:SetShown(free <= 0 or self.title:GetStringWidth() <= free)
end

function Pocket:PickPaint()
  local p = self.picksFrame
  if not (p and self.pickBtns) then return end
  applyDensity()
  local list = self:List()
  local n = #POCKET_PICKS
  local path = ns.Fonts:Current()
  local Bags = ns.Bags
  local size, gap = ns.GridMetrics(self.frame, ns.PocketIconSize(), Bags and Bags.gap or 4)
  local band = Theme:HeaderBand(p, BAND)
  local head = band and (band + 6) or (30 + Theme:TopInset())
  local mid = (band or head) / 2 + Theme:TitleDrop()
  if self.picksTitle then
    self.picksTitle:SetFont(path, FONT - 1, ns.OutlineFlags())
    self.picksTitle:ClearAllPoints()
    ns.SnapPoint(self.picksTitle, "LEFT", p, "TOPLEFT", PICK_PAD, -mid)
  end
  if self.picksClose then
    sizeGlyph(self.picksClose, math.min(ns.Density(pocketSize()).pocketBand - 4, 24))
    self.picksClose:ClearAllPoints()
    ns.SnapPoint(self.picksClose, "RIGHT", p, "TOPRIGHT", -6, -mid)
  end
  if self.idField then
    -- Density first: the field stands 6 taller than its box, the room the border takes.
    self.idField:SetBoxHeight(BOX_H)
    self.idField:ApplyFont(path, FONT - 2, FONT - 3)
    self.idField:ClearAllPoints()
    ns.SnapPoint(self.idField, "TOPLEFT", p, "TOPLEFT", PICK_PAD, -head)
    ns.SnapPoint(self.idField, "TOPRIGHT", p, "TOPRIGHT", -PICK_PAD, -head)
  end
  local gridTop = head + BOX_H + 6 + BOX_GAP
  for i = 1, n do
    local id = POCKET_PICKS[i]
    local b = self.pickBtns[i]
    b.wpeID = id
    b.icon:SetTexture(ns.PinIcon(id))
    local pinned = false
    for j = 1, self:Count() do
      if ns.ItemStubID(list[j]) == id then pinned = true; break end
    end
    b.wpePinned = pinned
    ns.SetBg(b, Theme:C("slot"))
    ns.SetEdge(b, Theme:C(pinned and "accent" or "emptyLine"))
    b.icon:SetDesaturated(false)
    b.icon:SetAlpha(pinned and 0.55 or 1)
    local atlas = ns.PinTier(id)
    if atlas then
      b.tier:SetAtlas(atlas, true)
      local w0, h0 = b.tier:GetWidth() or 0, b.tier:GetHeight() or 0
      if w0 > 0 and h0 > 0 then
        local k = size / 37
        b.tier:SetSize(math.max(1, w0 * k), math.max(1, h0 * k))
      end
      b.tier:Show()
    else b.tier:Hide() end
    b:Show()
  end
  for i = n + 1, PICK_MAX do self.pickBtns[i]:Hide() end
  local cols = math.max(1, math.min(PICK_COLS, n))
  local rows = n > 0 and math.ceil(n / cols) or 0
  local gridH = rows > 0 and (rows * size + (rows - 1) * gap) or 0
  local pickW = PICK_PAD * 2 + cols * size + (cols - 1) * gap
  ns.SnapSize(p, math.max(pickW, PICK_MINW), gridTop + gridH + PICK_PAD)
  for i = 1, n do
    local b = self.pickBtns[i]
    ns.SnapSize(b, size, size)
    b:ClearAllPoints()
    local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
    ns.SnapPoint(b, "TOPLEFT", p, "TOPLEFT",
      PICK_PAD + col * (size + gap),
      -(gridTop + row * (size + gap)))
  end
  local w = self.frame
  if w then
    p:ClearAllPoints()
    ns.SnapPoint(p, "TOPRIGHT", w, "TOPLEFT", -6, 0)
  end
end

function Pocket:TogglePicks()
  local p = self.picksFrame
  if not p then return end
  if p:IsShown() then
    p:Hide()
    if self.idField then self.idField.box:ClearFocus() end
    return
  end
  self:PickPaint()
  p:Show()
  for _, id in ipairs(POCKET_PICKS) do
    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
  end
  if self.idField then self.idField.box:SetFocus() end
end

function Pocket:Soon()
  later()
end

function Pocket:Refresh()
  keyDirty = true
  if not (self.frame and self.frame:IsShown()) then return end
  -- Our own drag holds the item itself, and pickup fires BAG_UPDATE_DELAYED at once: a scan taken
  -- then reads the bags without it and paints the pin's cell as a ghost for the rest of the drag.
  -- The item is not gone, it is on the cursor. The drop clears the cursor and asks again -- the
  -- frame-late pass in Drop, and PinFromCursor for a drop on a cell -- so waiting loses nothing.
  if self.lifted and CursorHasItem() then return end
  self:Layout()
  if self.picksFrame and self.picksFrame:IsShown() then self:PickPaint() end
end

function Pocket:Open()
  if not self:Enabled() then return end
  local w = self:Build()
  w:ClearAllPoints()
  local pp = WarpeeDB and WarpeeDB.pocketPos
  local anchor = ns.Bags and ns.Bags.frame
  if pp then
    ns.PlaceWindow(w, "pocketPos")
  elseif anchor then
    ns.SnapPoint(w, "TOPLEFT", anchor, "TOPRIGHT", 8, 0)
  else
    w:SetPoint("CENTER")
  end
  WarpeeDB.pocketOpen = true
  self:Layout()
  w:Show()
  Theme:Raise(w)
  -- Layout runs before the frame is shown, so its cooldown pass sees nothing visible.
  -- One pass after Show picks up a cooldown that started while the window was closed.
  self:Cooldowns()
end

function Pocket:Close(keep)
  if self.idField then self.idField.box:SetText(""); self.idField.box:ClearFocus(); self.idField:Preview() end
  if self.picksFrame then self.picksFrame:Hide() end
  if self.frame then self.frame:Hide() end
  if not keep then WarpeeDB.pocketOpen, self.solo = nil, nil end
end

function Pocket:Toggle()
  if self.frame and self.frame:IsShown() then
    self:Close()
  else
    self.solo = nil
    self:Open()
  end
end

function Pocket:Hotkey()
  if not self:Enabled() then return end
  if self.frame and self.frame:IsShown() then
    self:Close()
    return
  end
  local f = ns.Bags and ns.Bags.frame
  self.solo = not (f and f:IsShown()) or nil
  self:Open()
end

function Pocket:Apply()
  if not self:Enabled() then self:Close(true); return end
  self:Refresh()
end

-- Bindings.xml is picked up by the client from the addon folder on its own. Listing it
-- in the toc sends it through the frame XML parser instead, which does not know the
-- Binding tag and drops the whole file, so it stays out of the file list.
ns.LocalGlobal("BINDING_NAME_WARPEE_POCKET", "Pocket")

function WarpeePocketToggle()
  if ns.Pocket then ns.Pocket:Hotkey() end
end

-- The pocket used to take F7 outright. It takes the first free key of a short ladder now,
-- and the one line it says on the way is built from the key it actually got.
local function defaultKey()
  if not WarpeeDB or WarpeeDB.pocketBind then return end
  if InCombatLockdown() then return end
  -- A pocket that is switched off gets no key and no line about one. Its header button is
  -- hidden with it, so a binding would sit on the player's keys doing nothing, and the line
  -- would describe a window that never opens. The mark is still set: there is nothing here
  -- to say later.
  if not ns.Pocket:Enabled() then
    WarpeeDB.pocketBind = true
    return
  end
  if not (GetBindingKey and GetBindingAction and SetBinding and SaveBindings) then return end
  -- Both binding slots: a key already set in the second slot must count as bound, or the auto-bind
  -- below would add SHIFT-B on top of the player's own choice.
  local k1, k2 = GetBindingKey("WARPEE_POCKET")
  local key = (k1 and k1 ~= "" and k1) or (k2 and k2 ~= "" and k2) or nil
  if not key then
    if (GetBindingAction("SHIFT-B") or "") == "" then
      key = "SHIFT-B"
    elseif (GetBindingAction("F7") or "") == "" then
      key = "F7"
    end
    if key then
      SetBinding(key, "WARPEE_POCKET")
      SaveBindings((GetCurrentBindingSet and GetCurrentBindingSet()) or 1)
      if GetBindingKey("WARPEE_POCKET") ~= key then key = nil end
    end
  end
  -- The line names the key it just took, so it is built from the localized sentence with
  -- the key spliced in, not from an English string glued to an English tail.
  local line
  if key then
    line = (ns.L["The pocket is a small window of bookmark cells beside the bags. Open it with %s or the grid button in the header."]):format(key)
  else
    line = ns.L["The pocket is a small window of bookmark cells beside the bags. Open it with the grid button in the header, or bind a key in the settings."]
  end
  WarpeeDB.pocketBind = true
  print("|cffd9a85fWarpee|r |cffffffff" .. line .. "|r")
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:RegisterEvent("BAG_UPDATE_COOLDOWN")
ev:RegisterEvent("SPELL_UPDATE_COOLDOWN")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:RegisterEvent("EQUIPMENT_SETS_CHANGED")
ev:RegisterEvent("EQUIPMENT_SWAP_FINISHED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ITEM_CHANGED")
pcall(ev.RegisterEvent, ev, "ITEM_DATA_LOAD_RESULT")
ev:SetScript("OnEvent", function(_, event, a1, a2)
  if event == "ITEM_CHANGED" then
    if ns.PinRetarget(Pocket:List(), Pocket:Count(), a1, a2) then later() end
    return
  end
  if event == "ITEM_DATA_LOAD_RESULT" then
    if Pocket.picksFrame and Pocket.picksFrame:IsShown() then Pocket:PickPaint() end
    return
  end
  if event == "PLAYER_LOGIN" then
    C_Timer.After(1, defaultKey)
    return
  end
  if event == "PLAYER_REGEN_ENABLED" then
    Pocket:Flush()
    return
  end
  if event == "BAG_UPDATE_DELAYED" or event == "PLAYER_EQUIPMENT_CHANGED"
     or event == "EQUIPMENT_SETS_CHANGED" or event == "EQUIPMENT_SWAP_FINISHED" then
    later()
    return
  end
  Pocket:Cooldowns()
end)
