local addonName, ns = ...
local Options = ns.Options
local factories = Options.factories

-- The share line under the category list: one code, both directions. A code carries this list and
-- nothing else — no positions, no sizes, no theme — so it can be pasted to another player and mean
-- the same thing there. The field below serves both ways, the way the profile panel's own field does:
-- Export fills it, Import reads it. Import replaces the whole list, behind a confirm.
function factories.catlistshare(env)
  local makeBox = env.makeBox
  local tip = env.tip
  local say = env.say
  local T = env.T

  return function(row)
    local exp = ns.CreateButton(row, ns.L["Export"], 120, 22)
    ns.LocalText(exp, "Export")
    local imp = ns.CreateButton(row, ns.L["Import"], 120, 22)
    ns.LocalText(imp, "Import")
    tip(exp, "Fills the field below with a code for this list: copy it and paste it wherever it should be applied")
    tip(imp, "Reads the code in the field and replaces your list with it")
    -- The buttons carry their locale key so the layout can read the current language and measure the
    -- string that will actually land on them.
    local buttons = {
      { btn = exp, key = "Export" },
      { btn = imp, key = "Import" },
    }

    -- A code is long, so the field is the full width of the column and the placeholder is the only thing
    -- naming it. The 60-character default of a row's own field would cut a real code in half and a half
    -- code is one nobody can copy, so this one takes whatever a paste hands it.
    local codeBox = makeBox(row, "Categories code", 8192)
    codeBox:SetScript("OnTextChanged", function(s) s.ph:SetShown(s:GetText() == "") end)
    codeBox:SetScript("OnEditFocusLost", function(s) s.ph:SetShown(s:GetText() == "") end)
    codeBox.ph:Show()
    row.shareCode = codeBox

    -- Empty means empty however it was typed: a field holding a few spaces is one the player means to fill.
    local function noCode(text)
      return type(text) ~= "string" or text:gsub("%s", "") == ""
    end

    exp:SetScript("OnClick", function()
      local text = ns.Profiles:ExportCategories()
      if text == "" then say(T("Nothing to export")) return end
      codeBox:SetText(text)
      codeBox:SetFocus()
      codeBox:HighlightText()
      say(T("Exported %s, press Ctrl and C to copy"):format(T("Categories")))
    end)
    imp:SetScript("OnClick", function()
      local text = codeBox:GetText()
      if noCode(text) then say(T("Nothing to import")) return end
      -- A category import replaces the whole list. A profile code pasted here is applied like the profile
      -- panel does; catImport reads the kind off the code either way.
      Options.catImport(text, "replace")
    end)

    local share = { exp = exp, imp = imp, code = codeBox }
    -- The line sits last on the page: the buttons pack from the left like the makers above and are sized
    -- from their own labels, and the field takes the width under them. `extra` is the row the actions
    -- took when they had to wrap; the height comes back so the page can size itself.
    function share.Layout(y, extra, sidePad, gap)
      local shareY = y + 22 + extra + 14
      local sx = 0
      for _, e in ipairs(buttons) do
        e.btn.Text:SetText(T(e.key))
        local w = math.ceil(e.btn.Text:GetStringWidth()) + sidePad
        e.btn:ClearAllPoints()
        e.btn:SetPoint("TOPLEFT", sx, -shareY)
        ns.SnapBox(e.btn, w, 22)
        e.btn:Show()
        sx = sx + w + gap
      end
      codeBox:ClearAllPoints()
      codeBox:SetPoint("TOPLEFT", 0, -(shareY + 28))
      codeBox:SetPoint("TOPRIGHT", 0, -(shareY + 28))
      codeBox:Show()
      return shareY + 28 + 22
    end
    return share
  end
end
