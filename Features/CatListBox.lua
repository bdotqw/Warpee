local addonName, ns = ...
local Options = ns.Options
local factories = Options.factories
local Theme = ns.Theme

-- The small edit box the category list types into: the name field on a row and the codes field under the
-- list. One shape for both, so a focus ring, a placeholder and the font read the same wherever they appear.
function factories.catlistbox(env)
  local BASE_FONT = env.baseFont
  local dropdownFont = env.dropdownFont

  return function(c, hint, maxLen)
    local box = CreateFrame("EditBox", nil, c, "BackdropTemplate")
    ns.SnapBox(box, 60, 22, true)
    ns.PixelBackdrop(box)
    ns.SetBg(box, Theme:C("bg"))
    ns.SetEdge(box, Theme:C("stroke"))
    Theme:Track(box, function(s)
      ns.SetBg(s, Theme:C("bg"))
      s:SetTextColor(Theme:C("text"))
      if not s:HasFocus() then ns.SetEdge(s, Theme:C("stroke")) end
    end)
    box:SetFont(dropdownFont(), BASE_FONT - 1, ns.OutlineFlags())
    box:SetTextColor(Theme:C("text"))
    box:SetTextInsets(6, 6, 0, 0)
    box:SetAutoFocus(false)
    box:SetMaxLetters(maxLen)
    local ph = Theme:Label(box, BASE_FONT - 2, "faint")
    ph:SetPoint("LEFT", 6, 0)
    -- Registered with the locale watcher rather than set once, so the background name (the "Categories
    -- code" caption) follows a language change live instead of keeping the old language until a reload.
    ns.LocalText(ph, hint)
    box.ph = ph
    box:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    box:SetScript("OnEditFocusGained", function(s) ns.SetEdge(s, Theme:C("accent")) end)
    return box
  end
end
