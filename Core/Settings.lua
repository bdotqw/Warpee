local addonName, ns = ...

-- One key, one writer. A setting is declared where its redraw lives, and the setter it hands back is the
-- only code that writes that key: the store, the value the next read sees and the one pass behind the
-- change are always the same call, so a row cannot save a value and leave the window that reads it showing
-- the old one.
--
--   local setRows = ns.Setting("pocketRows", function() Pocket:Refresh() end)
--   setRows(6)
--
-- The apply runs after the store, never before: a redraw that reads the key back has to find the new value.
-- A key with no pass of its own passes no apply -- not every setting is drawn, and a switch the next open
-- reads is still a setting. A key a hot path also holds on the module (the bags' split gaps above all) is
-- handed that table as the mirror: the copy moves in the same call, before the pass, so the redraw never
-- reads the old one. Reads stay outside this file: some keys fall back to another key or to ns.DEFAULTS when
-- unset, and that is a property of the getter, not of the store.
local function setting(key, apply, mirror)
  return function(value)
    -- Saved variables are read after ADDON_LOADED. A write before that has nowhere to land and no window
    -- to redraw, so it is dropped: keeping it in memory would only lose it at the next reload.
    if not WarpeeDB then return end
    WarpeeDB[key] = value
    if mirror then mirror[key] = value end
    if apply then apply(value) end
  end
end
ns.Setting = setting
