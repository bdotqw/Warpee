local addonName, ns = ...
local Options = ns.Options
local Theme = ns.Theme

-- The options window itself: the tabs and their sub strips, the lazy page cache, open/close, refresh,
-- search and the scroll helpers that ride with them. It is the other half of the window — Options.lua
-- keeps the rows and the factories, this file keeps the frame that holds them.
-- The scaffold it lays out (the page builder, the scroll area, the shared row pool) and the numbers it
-- measures with come from Options.lua through ns.OptionShellEnv, set there at load.
local env = ns.OptionShellEnv
local T = env.T
local BASE_FONT = env.baseFont
local TAB_H = env.tabH
local SUB_H = env.subH
local SUB_GAP = env.subGap
local SUB_DROP = env.subDrop
local HEADER_H = env.headerH
local PAD = env.pad
local WIN_W = env.winW
local WIN_H = env.winH
local SCROLL_W = env.scrollW
local track = env.track
local rows = env.rows
local fonts = env.fonts
local makeScrollArea = env.makeScrollArea
local closeDropdown = env.closeDropdown
local dropdownFont = env.dropdownFont
local localeGet = env.localeGet
local sectionOpen = env.sectionOpen
local sectionToggle = env.sectionToggle

local function paintTab(b)
  if b.sel then
    local def = Theme.SkinDef and Theme:SkinDef()
    ns.SetBg(b, Theme:C((def and def.quietTabs) and "panel" or "panelHi"))
    ns.SetEdge(b, Theme:C("accent"))
    b.Text:SetTextColor(Theme:C("text"))
  else
    ns.SetBg(b, Theme:C("panel"))
    ns.SetEdge(b, Theme:C("stroke"))
    b.Text:SetTextColor(Theme:C("dim"))
  end
end

-- The strip's paint, held per button, since its own repaint drops the accent.
local function paintSub(b)
  ns.SetBg(b, Theme:C(b.sel and "panelHi" or "panel"))
  ns.SetEdge(b, Theme:C(b.sel and "accent" or "stroke"))
  b.Text:SetTextColor(Theme:C(b.sel and "text" or "dim"))
end

local function paintSubs(entry)
  for _, b in ipairs(entry.btns) do paintSub(b) end
end

-- Measure and chain one page's strip buttons, from reflow and build alike.
local function layoutStrip(entry, defs)
  local prev
  for k, b in ipairs(entry.btns) do
    if defs and defs[k] then b.Text:SetText(T(defs[k].name)) end
    b:SetWidth(math.max(56, b.Text:GetStringWidth() + 18))
    b:ClearAllPoints()
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0)
    else b:SetPoint("LEFT", entry.strip, "LEFT", 0, 0) end
    prev = b
  end
  paintSubs(entry)
end

function Options:Select(index)
  closeDropdown()
  self.current = index
  -- The tab builds its lists on first visit, one page at a time.
  self:BuildPage(index)
  for i, tab in ipairs(self.tabs) do
    tab.sel = (i == index)
    paintTab(tab)
  end
  for i = 1, #Options.pages do
    local entry = self.subs[i]
    if entry then
      local at = self.subAt[i] or 1
      for k, area in ipairs(entry.areas) do
        local on = (i == index and k == at)
        area:SetShown(on)
        area.bar:SetShown(on)
      end
      if entry.strip then entry.strip:SetShown(i == index) end
      for k, b in ipairs(entry.btns) do b.sel = (i == index and k == at) end
      paintSubs(entry)
    end
  end
  local area = self.subs[index].areas[self.subAt[index] or 1]
  area:ScrollTo(0)
  area:PaintBar()
  self:Refresh()
end

-- The sub buttons switch lists; the pick is remembered per page.
function Options:SubSelect(k)
  self.subAt[self.current] = k
  self:Select(self.current)
end

function Options:ApplyFont()
  -- The same guard ReflowPages opens with, and for the same reason: ns.ApplyAll calls both
  -- of them, and an apply that runs before this window was ever built has no tabs or pages
  -- to measure. Build's own ApplyFont puts the fonts on once there are.
  if not (self.tabs and self.areas) then return end
  local path = ns.Fonts:Current()
  for _, e in ipairs(fonts) do
    e.fs:SetFont(path, math.max(7, BASE_FONT + e.delta), ns.OutlineFlags())
  end
  local function measure()
    for _, tab in ipairs(self.tabs) do
      tab:SetWidth(math.max(70, tab.Text:GetStringWidth() + 22))
    end
    if self.profilesBtn then
      self.profilesBtn:SetWidth(math.max(64, self.profilesBtn.Text:GetStringWidth() + 20))
    end
    if self.searchBox and self.searchPh then
      -- The box fits its placeholder, so a long translation stays inside it.
      local tw = math.ceil(self.searchPh:GetStringWidth() or 0)
      self.searchBox:SetWidth(math.max(180, math.min(340, tw + 42)))
    end
    for i, area in ipairs(self.areas) do
      area.page.Relayout()
      area:PaintBar()
    end
  end
  measure()
  C_Timer.After(0, measure)
end

function Options:ReflowPages()
  if not self.areas then return end
  if self.tabs then
    local prev
    for i, tab in ipairs(self.tabs) do
      tab.Text:SetText(T(Options.pages[i].name))
      tab:SetWidth(math.max(70, tab.Text:GetStringWidth() + 22))
      tab:ClearAllPoints()
      if prev then
        tab:SetPoint("TOPLEFT", prev, "TOPRIGHT", 5, 0)
      else
        ns.SnapPoint(tab, "TOPLEFT", self.frame, "TOPLEFT", PAD,
          -(HEADER_H + 7 + Theme:TopInset()))
      end
      prev = tab
      tab:Show()
      paintTab(tab)
    end
  end
  -- The strip's buttons measure like the tabs, chained left to right.
  for i = 1, #Options.pages do
    local entry = self.subs[i]
    if entry then layoutStrip(entry, Options.pages[i].subs) end
  end
  self:AnchorHeader()
  for _, row in ipairs(rows) do row.Refresh() end
  for _, area in ipairs(self.areas) do
    area.page.Relayout()
    area:ScrollTo(area:GetVerticalScroll())
    area:PaintBar()
  end
end

-- The rows on screen; Select fills it, so hidden lists wait their turn.
function Options:VisibleRows()
  local entry = self.subs and self.subs[self.current]
  if not entry then return rows end
  local area = entry.areas[self.subAt[self.current] or 1]
  local page = area and area.page
  if not (page and page.rows) then return rows end
  -- Hidden rows are left out: a folded section is not on screen.
  local out = {}
  for i = 1, #page.rows do
    local row = page.rows[i].row
    if row:IsShown() then out[#out + 1] = row end
  end
  return out
end

function Options:Refresh()
  local live = self:VisibleRows()
  for i = 1, #live do live[i].Refresh() end
  self:SyncProfilesSoon()
end

-- The capture trails the row passes; closing the window writes it at once.
function Options:SyncProfilesSoon()
  if self.syncQ then return end
  self.syncQ = true
  C_Timer.After(0.3, function()
    self.syncQ = nil
    if ns.Profiles and ns.Profiles.SyncActive then ns.Profiles:SyncActive() end
  end)
end

-- One row pass per frame at most, however many settings moved in it. The flag lives on the
-- table rather than in a local: Options.lua is the file closest to the main-chunk limit, and
-- the deferral costs a C_Timer, not a slot.
function Options:RefreshSoon()
  if self.refreshQ then return end
  self.refreshQ = true
  C_Timer.After(0, function()
    self.refreshQ = nil
    self:Refresh()
  end)
end

-- Re-render the open editor after a change made from outside it — a pin dropped on a section in the
-- bag window files into a category, and the category editor, if it happens to be open, must redraw so
-- the new pin's row and icon appear at once rather than only after the tab is left and re-entered.
-- A no-op when the window is closed, so the bag drop can call it unconditionally.
function Options:RefreshOpen()
  if not (self.frame and self.frame:IsShown()) then return end
  self:Refresh()
  -- Only the list on screen is measured; the pages behind wait their turn.
  local entry = self.subs and self.subs[self.current]
  local area = entry and entry.areas[self.subAt[self.current] or 1]
  if area and area.page and area.page.Relayout then
    area.page.Relayout()
    area:PaintBar()
  end
end

-- Crude inflection stripper: Russian cases and plurals, Latin plurals, German -en.
local RU_TAIL2 = { "ая","яя","ое","ее","ые","ие","ой","ей","ый","ий","ом","ем","ах","ях","ов","ев" }
local RU_TAIL1 = { "а","я","ы","и","у","ю","о","е","ё","й","ь" }
local function stemWord(w)
  local last = w:sub(-1)
  if (last >= "a" and last <= "z") or (last >= "A" and last <= "Z") then
    local tail2 = w:sub(-2)
    if #w > 4 and (tail2 == "en" or tail2 == "es") then return w:sub(1, -3) end
    if #w > 3 and (last == "s" or last == "x" or last == "n") then return w:sub(1, -2) end
    return w
  end
  if last < "\128" then return w end
  for i = 1, #RU_TAIL2 do
    local t = RU_TAIL2[i]
    if #w > #t + 2 and w:sub(-#t) == t then return w:sub(1, -#t - 1) end
  end
  for i = 1, #RU_TAIL1 do
    local t = RU_TAIL1[i]
    if #w > #t + 2 and w:sub(-#t) == t then return w:sub(1, -#t - 1) end
  end
  return w
end
local function stemBlob(s)
  if type(s) ~= "string" then return "" end
  local words = {}
  for w in s:gmatch("[%w\128-\255]+") do words[#words + 1] = stemWord(w) end
  return table.concat(words, " ")
end

-- Plain-language synonyms the labels never spell: slang and translits a player types instead of the
-- written word. Per locale, each maps the typed word to the words the labels and tooltips carry, in the
-- player's spelling first and in English second, so "голда" answers the way "золото" and "gold" do.
-- Compared folded, like the query itself; a query that is already a written word never reaches this table.
local SEARCH_SYN = {
  enUS = {
    ["ah"] = { "auction" },
    ["ilvl"] = { "item level" },
  },
  deDE = {
    ["rucksack"] = { "taschen", "bags" },
    ["skin"] = { "design", "theme" },
  },
  frFR = {
    ["hv"] = { "hôtel des ventes" },
    ["stuff"] = { "objets", "items" },
  },
  itIT = {
    ["asta"] = { "casa d'aste" },
  },
  ptBR = {
    ["leilão"] = { "casa de leilões" },
    ["leilao"] = { "casa de leilões" },
    ["grana"] = { "ouro" },
  },
  koKR = {
    ["인벤"] = { "가방" },
    ["렙"] = { "레벨" },
  },
  zhCN = {
    ["g"] = { "金币" },
  },
  zhTW = {
    ["g"] = { "金幣" },
  },
  ruRU = {
    ["голда"] = { "золото", "gold" },
    ["бабки"] = { "золото", "gold" },
    ["бабло"] = { "золото", "gold" },
    ["голд"] = { "золото", "gold" },
    ["прозрачность"] = { "opacity" },
    ["илвл"] = { "item level" },
    ["зазор"] = { "промежуток", "gap" },
    ["вендор"] = { "торговец", "vendor" },
    ["мейл"] = { "почта", "mail" },
    ["трейд"] = { "обмен", "trade" },
    ["варбанд"] = { "отряд", "warband" },
    ["шмот"] = { "item" },
    ["крафт"] = { "профессии", "professions" },
    ["лут"] = { "sell", "продавать" },
    ["починка"] = { "ремонт", "repair" },
    ["квест"] = { "quest", "задание" },
    ["ах"] = { "аукцион", "auction" },
    ["скин"] = { "тема", "theme" },
    ["табы"] = { "вкладка", "tab" },
  },
}

-- The search index: one entry per row of every page, its name and its tooltip, built once and dropped when
-- the language moves, since a player types the label they read. It walks the page tables rather than the
-- built rows, so a setting on a page nobody has opened this session is found all the same, and no page has to
-- be built to be searched. Every page and every list of it is an entry as well: a place, with no row to walk
-- to, so a query that names a tab answers with the tab: without that a query like "grid" found nothing at
-- all here, which is the one answer a player looking in the wrong tab must never get.
-- The label's spellings in every loaded language, folded: the search answers a word typed in a language
-- the window is not reading, the way the bag search reads every language's words whatever the interface is
-- set to. Only static labels travel: a function name is already the spelling on screen.
local function crossLabels(key)
  if type(key) ~= "string" or key == "" then return nil end
  local codes = ns.LOCALES
  if type(codes) ~= "table" then return nil end
  local out
  for i = 1, #codes do
    local t = ns.LocaleStrings and ns.LocaleStrings(codes[i]) or nil
    local s = (type(t) == "table" and t[key]) or nil
    if type(s) == "string" and s ~= "" then
      local f = ns.SearchFold(s)
      if f ~= "" then out = out or {}; out[#out + 1] = f end
    end
  end
  return out
end

function Options:SearchIndex()
  if self.searchIdx then return self.searchIdx end
  local out = {}
  local function place(i, label, sub, parent)
    if type(label) ~= "string" or label == "" then return end
    local loc = T(label)
    local plab = parent and T(parent) or ""
    -- The breadcrumb is searchable as one more word for the place: a query that names a page lists the lists
    -- under it, so "grid" answers with Grid and with the three lists of it in the same breath. Both spellings
    -- go in, since a player types whichever one is on their screen.
    local fold = ns.SearchFold(label)
    local foldLoc = ns.SearchFold(loc)
    local e = {
      page = i, sub = sub, place = true, loc = loc, where = plab,
      l = fold, ll = foldLoc,
      hay = parent and ns.SearchFold(parent .. " " .. label .. " " .. plab .. " " .. loc) or nil,
      n = (fold:gsub(" ", "")), nl = (foldLoc:gsub(" ", "")),
      lx = crossLabels(label),
    }
    e.st = stemBlob(e.l .. " " .. e.ll .. " " .. (e.hay or "") .. " " .. table.concat(e.lx or {}, " "))
    out[#out + 1] = e
  end
  for i = 1, #Options.pages do
    local page = Options.pages[i]
    local lists = page.subs or { { list = page.list } }
    -- The page first, then each list of it: the page answers to its own name, a list to its name with the
    -- page it belongs to as its breadcrumb.
    place(i, page.name, 1)
    for k = 1, #lists do
      local sub = lists[k]
      place(i, sub.name, k, page.name)
      local where = T(page.name) .. (sub.name and (" / " .. T(sub.name)) or "")
      local list = sub.list or {}
      for j = 1, #list do
        local spec = list[j]
        local label = spec.name
        if type(label) == "function" then label = label() end
        -- A description row is a paragraph, not a setting: its words are not a name to look for.
        if type(label) == "string" and label ~= "" and spec.type ~= "description" then
          local loc = T(label)
          local tip = type(spec.desc) == "string" and spec.desc or ""
          -- SearchFold and not :lower(): the client folds ASCII alone, so a Russian label only answered a
          -- query that copied its capital letters. The bag search has folded this way all along.
          local fold, foldLoc = ns.SearchFold(label), ns.SearchFold(loc)
          local e = {
            page = i, sub = k, spec = spec, loc = loc, where = where,
            hd = spec.type == "header" and true or nil,
            l = fold, ll = foldLoc, ld = ns.SearchFold(tip .. " " .. (T(tip) or "")),
            n = (fold:gsub(" ", "")), nl = (foldLoc:gsub(" ", "")),
            lx = crossLabels(type(spec.name) == "string" and spec.name or nil),
          }
          e.st = stemBlob(e.l .. " " .. e.ll .. " " .. (e.ld or "") .. " " .. table.concat(e.lx or {}, " "))
          out[#out + 1] = e
        end
      end
    end
  end
  self.searchIdx = out
  return out
end

-- One query against the index: the name exactly, then a prefix, then anywhere in the name, then the name with
-- its spaces dropped (so "plateopacity" finds "Plate opacity"), then the breadcrumb a place carries, then
-- anywhere in the tooltip, and last the stemmed words, so an inflection answers its dictionary form. The first
-- three tiers read every language's spelling of the name, so a word typed in a language the window is not
-- reading still answers. A synonym of the query answers with the same tiers through the words it stands for. The name is read in both spellings at every one of those tiers, since the written
-- label and the one on screen are two names for one row and a player may type either. The first tier that
-- answers wins, and the list comes back in tier then alphabetical order, which puts the row the player means at
-- the top without any scoring arithmetic, and never lets a place reached by its page outrank a row that wears
-- the query in its own name. A place and a row are the two kinds here: a row holds a setting, a place is a page
-- or one list of it, so it carries no row of its own to walk to and its name is the whole of what it is.
-- One spelling among the entry's other-language labels answering exactly, by prefix or by part.
local function lxHit(e, qq, mode)
  local lx = e.lx
  if not lx then return false end
  if mode == 1 then
    for i = 1, #lx do if lx[i] == qq then return true end end
  elseif mode == 2 then
    for i = 1, #lx do if lx[i]:sub(1, #qq) == qq then return true end end
  else
    for i = 1, #lx do if lx[i]:find(qq, 1, true) then return true end end
  end
  return false
end

function Options:SearchMatches(query)
  local q = ns.SearchFold(query or ""):match("^%s*(.-)%s*$")
  if q == "" then return {} end
  local tight = q:gsub(" ", "")
  -- The query plus what its synonyms stand for: every spelling answers with the same tiers, and the entry
  -- keeps the best tier any of them reaches. A single latin letter is never a word, only an abbreviation, so it
  -- answers exactly and through its synonyms: without this "g" prefix-matched every English label starting
  -- with g and buried the gold rows it stood for.
  local tiny = (#q == 1 and q:find("%a")) and true or nil
  local queries = { { q = q, tight = tight, sq = stemBlob(q), bare = tiny } }
  local loc = localeGet and localeGet() or nil
  local syn = (loc and SEARCH_SYN[loc]) or nil
  -- esMX carries no strings of its own, only overrides over esES (see the FALLBACK in Core/Locale.lua),
  -- so it reads the Spanish synonyms too.
  if not syn and loc == "esMX" then syn = SEARCH_SYN.esES end
  -- English abbreviations travel: "ilvl" and "ah" are typed whatever the window reads. So does slang:
  -- the tables hold no word twice with two meanings, and every canonical answers in both spellings, so a
  -- Russian "голда" typed into an English window still lands on the gold rows.
  local alt = (syn and syn[q]) or (SEARCH_SYN.enUS and SEARCH_SYN.enUS[q]) or nil
  if not alt then
    for _, t in pairs(SEARCH_SYN) do
      local v = t[q]
      if v then alt = v; break end
    end
  end
  if alt then
    for i = 1, #alt do
      local fq = ns.SearchFold(alt[i]):match("^%s*(.-)%s*$")
      if fq ~= "" and fq ~= q then queries[#queries + 1] = { q = fq, tight = fq:gsub(" ", ""), sq = stemBlob(fq) } end
    end
  end
  local idx = self:SearchIndex()
  local out = {}
  for i = 1, #idx do
    local e = idx[i]
    local tier
    for k = 1, #queries do
      local qq, tt, ss = queries[k].q, queries[k].tight, queries[k].sq
      local t
      if e.l == qq or e.ll == qq or lxHit(e, qq, 1) then t = 1
      elseif e.l:sub(1, #qq) == qq or e.ll:sub(1, #qq) == qq or lxHit(e, qq, 2) then t = 2
      elseif e.l:find(qq, 1, true) or e.ll:find(qq, 1, true) or lxHit(e, qq, 3) then t = 3
      elseif e.n:find(tt, 1, true) or e.nl:find(tt, 1, true) then t = 4
      elseif e.hay and e.hay:find(qq, 1, true) then t = 5
      elseif e.ld and e.ld:find(qq, 1, true) then t = 6
      elseif e.st and ss ~= "" and #ss >= 3 and e.st:find(ss, 1, true) then t = 7
      end
      if t and (not tier or t < tier) then tier = t end
      local sp = queries[k]
      if sp.bare and tier and tier > 1 then tier = nil end
    end
    if tier then out[#out + 1] = { e = e, t = tier } end
  end
  table.sort(out, function(a, b)
    if a.t ~= b.t then return a.t < b.t end
    -- Inside one tier the places come first: a query that names a page or one of its lists reads as "take me
    -- there", and the row that happens to spell the same word stays a line under it.
    if a.e.place ~= b.e.place then return a.e.place end
    -- A heading names a block, it does not set anything: where a row and the heading over it share a name,
    -- the row is the one a player means.
    if (a.e.hd or false) ~= (b.e.hd or false) then return not a.e.hd end
    if a.e.l ~= b.e.l then return a.e.l < b.e.l end
    return (a.e.where or "") < (b.e.where or "")
  end)
  return out
end

-- One keystroke: the count beside the box, and the matches under it. Nothing is built for a query that finds
-- nothing, and the list is the window's own menu, so it brings its scrollbar, its click catcher and its cap of
-- nine visible rows for free. showDropdown and not openDropdown: the ordinary way in closes the menu when the
-- control that opened it is pressed again, which is exactly wrong while the player is still typing.
function Options:SearchRefresh(query)
  if not self.searchBox then return end
  local hits = self:SearchMatches(query)
  self.searchTop = hits[1] and hits[1].e or nil
  if #hits == 0 then
    -- A query that finds nothing says so beside the box; an empty box just says nothing.
    local idle = (query == nil or query == "")
    self.searchCount:SetText(idle and "" or T("Nothing found"))
    closeDropdown()
    return
  end
  self.searchCount:SetText(("%d"):format(#hits))
  local keys = {}
  for i = 1, math.min(#hits, 40) do keys[i] = hits[i].e end
  -- A row reads "its name   the page it lives on", which is the whole answer to "where is this one": the player
  -- came to the box because the page they would have looked on was the wrong one, so the breadcrumb is what
  -- teaches them. A place wears the accent instead and carries no name of its own, so the two never read as
  -- the same kind of hit.
  local ar, ag, ab = Theme:C("accent")
  local accent = ("|cff%02x%02x%02x"):format(math.floor(ar * 255 + 0.5), math.floor(ag * 255 + 0.5), math.floor(ab * 255 + 0.5))
  -- The breadcrumb in dim, so the eye stops at the name: one ink for both made "Gold format General /
  -- Interface" read as a single sentence with the page lost somewhere in the middle of it.
  local dr, dg, db = Theme:C("dim")
  local dim = ("|cff%02x%02x%02x"):format(math.floor(dr * 255 + 0.5), math.floor(dg * 255 + 0.5), math.floor(db * 255 + 0.5))
  showDropdown(self.searchBox, {
    keys = function() return keys end,
    get = function() end,
    label = function(k)
      if k.place then return accent .. (k.where ~= "" and (k.where .. "  /  " .. k.loc) or k.loc) .. "|r" end
      return k.loc .. "   " .. dim .. k.where .. "|r"
    end,
    set = function(k) self:GoToRow(k) end,
  })
end

-- Walk the window to what the search found: its page, its sub-list, its section if the row is folded away,
-- then the list scrolls it into sight and the wash says which one it was. Select does the page, the sub and
-- the row pass; everything after it is the walk itself, and the top of the query is what Enter walks to. A
-- place stops after the page and the sub, since there is no row of its own to reach.
function Options:GoToRow(entry)
  local e = entry
  if not (e and e.page) then return end
  self.subAt[e.page] = e.sub or 1
  self:Select(e.page)
  -- A place is the page and its list, and there is no row after that: the strip button the query named takes
  -- the wash, so a jump onto a list the window was already sitting on still says where it went.
  if not e.spec then
    local entryAt = self.subs[e.page]
    local btn = entryAt and entryAt.btns and entryAt.btns[e.sub or 1]
    if btn then self:WashRow(btn) end
    return
  end
  if e.spec.section and not sectionOpen(e.spec.section) then
    sectionToggle(e.spec.section)
    self:ReflowPages()
  end
  local area = self.subs[e.page] and self.subs[e.page].areas[self.subAt[e.page] or 1]
  local page = area and area.page
  if not (page and page.rows) then return end
  local row
  for i = 1, #page.rows do
    if page.rows[i].spec == e.spec then row = page.rows[i].row; break end
  end
  if not (row and row:IsShown()) then return end
  local off = (page:GetTop() or 0) - (row:GetTop() or 0)
  local cur = area:GetVerticalScroll() or 0
  local view = area:GetHeight() or 0
  if off < cur or off + row:GetHeight() > cur + view then
    area:ScrollTo(math.max(0, off - 12))
  end
  self:WashRow(row)
end

-- The wash over a row or a sub button the search walked to: the same accent a freshly added category wears when its own list
-- scrolls to it, at a low alpha baked into the colour, since a theme change repaints the texture and would
-- flare a SetAlpha wash back to full. It lives on its own field, away from the wash the category list keeps
-- on its own rows, so the two timers never cut each other short.
function Options:WashRow(row)
  local f = row.wpeWash
  if not f then
    f = CreateFrame("Frame", nil, row)
    f:SetFrameLevel(row:GetFrameLevel() + 40)
    local wash = f:CreateTexture(nil, "OVERLAY")
    wash:SetAllPoints(f)
    local function paintWash(x) local r, g, b = Theme:C("accent"); x:SetColorTexture(r, g, b, 0.22) end
    paintWash(wash)
    Theme:Track(wash, paintWash)
    row.wpeWash = f
  end
  f:ClearAllPoints()
  f:SetAllPoints(row)
  f:Show()
  self.washSeq = (self.washSeq or 0) + 1
  local mine = self.washSeq
  C_Timer.After(1.1, function()
    if mine == self.washSeq and row.wpeWash then row.wpeWash:Hide() end
  end)
end

-- One page's lists, built once and hidden until selected: whatever Select did not pick stays down,
-- like every other page it never built. A second call is a no-op returning what the first made.
function Options:BuildPage(i)
  if self.subs[i] then return self.subs[i] end
  local pageDef = Options.pages[i]
  local f = self.frame
  if not (pageDef and f) then return nil end
  local list = pageDef.subs or { { list = pageDef.list } }
  local entry = { areas = {}, btns = {} }
  if #list > 1 then
    local strip = CreateFrame("Frame", nil, f)
    strip:SetHeight(SUB_H)
    strip:Hide()
    entry.strip = strip
  end
  for k, sub in ipairs(list) do
    if entry.strip then
      local b = ns.CreateButton(entry.strip, T(sub.name), 80, SUB_H)
      track(b.Text, -2)
      b:SetScript("OnClick", function() self:SubSelect(k) end)
      b:HookScript("OnLeave", paintSub)
      entry.btns[k] = b
    end
    local area = makeScrollArea(f, sub.list)
    area:SetPoint("TOPLEFT", PAD, -(HEADER_H + TAB_H + 14))
    area:SetPoint("BOTTOMRIGHT", -(PAD + SCROLL_W + 6), PAD)
    area.bar:SetPoint("TOPLEFT", area, "TOPRIGHT", 6, 0)
    area.bar:SetPoint("BOTTOMLEFT", area, "BOTTOMRIGHT", 6, 0)
    area:Hide()
    area.bar:Hide()
    entry.areas[k] = area
    self.areas[#self.areas + 1] = area
  end
  self.subs[i] = entry
  -- Placed here and not at the next reflow: the strip buttons are measured by layoutStrip and the strip
  -- and lists anchored by AnchorHeader, and neither pass runs on a tab switch.
  layoutStrip(entry, pageDef.subs)
  self:AnchorHeader()
  return entry
end

function Options:Build()
  if self.frame then return self.frame end

  local f = CreateFrame("Frame", "WarpeeOptionsFrame", UIParent, "BackdropTemplate")
  f:Hide()
  Theme:Panel(f, "bg", "stroke", true)
  ns.SnapBox(f, WIN_W, math.min(WIN_H, UIParent:GetHeight() - 60), true)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(s) ns.DragMove(s) end)
  f:SetScript("OnDragStop", function(s)
    -- The move flag is cleared with the gesture here as it is on the bags, the bank and the pocket. It was
    -- left standing after the first drag, and it is the flag the move driver reads on every frame this
    -- window stays open.
    if not s.wpeMoving then return end
    s.wpeMoving = nil
    s:StopMovingOrSizing()
    local p, rp, x, y = ns.SnapFrame(s)
    if p then WarpeeDB.optPos = { p = p, rp = rp, x = x, y = y } end
    if ns.Profiles and ns.Profiles.SyncActive then ns.Profiles:SyncActive() end
  end)
  f:SetScript("OnMouseDown", function(s) Theme:Raise(s) end)
  Theme:Window(f, "WarpeeOptionsFrame")
  f:SetFrameStrata("DIALOG")
  Theme:HeaderBand(f, HEADER_H + Theme:TopInset())
  f:SetScript("OnHide", function()
    local row = Options.charsRow
    if row and row.delMode then
      row.delMode = nil
      if row.Rebuild then row.Rebuild() end
    end
    ns.HideTip()
    -- The query is dropped with the window: the box comes back empty and the list unfiltered, rather than
    -- showing a word from last time over a page that has nothing to do with it.
    if Options.searchBox then Options.searchBox:SetText("") end
    -- The profile capture trails the row passes by a moment, so the window closing is where the last one is
    -- written: whatever was moved before walking away stands in the active profile when it is read next.
    if ns.Profiles and ns.Profiles.SyncActive then ns.Profiles:SyncActive() end
  end)
  self.frame = f

  local title = Theme:Title(f, BASE_FONT + 2, "accent")
  title:SetPoint("TOPLEFT", PAD, -10)
  title:SetText(ns.TITLE)
  track(title, 2)
  self.title = title

  local close = ns.CreateGlyphButton(f, "×", 28)
  close:SetPoint("TOPRIGHT", -PAD, -8)
  close:SetScript("OnClick", function() self:Close() end)
  track(close.Text, 2)
  self.closeBtn = close

  local prof = ns.CreateButton(f, "", 76, 28)
  ns.LocalText(prof.Text, "Profiles")
  track(prof.Text, -1)
  prof:SetWidth(math.max(64, prof.Text:GetStringWidth() + 20))
  ns.SnapPoint(prof, "RIGHT", close, "LEFT", -6, 0)
  prof:SetScript("OnClick", function() ns.Profiles:Toggle() end)
  self.profilesBtn = prof

  -- The search field. Seven pages and three sub-lists deep, the player who comes back to change one setting
  -- looks for it by name rather than by the page it lives on, so every row answers to its own words as well:
  -- the matches hang under the box like any other menu, and a pick walks the window to that row and washes
  -- it once. The box rides in the header over no list at all, so it costs the pages none of their room.
  -- The box sits at the right end of the header, just left of the Profiles button, where a search field is
  -- looked for: the two are the window's only header controls, so they line up as one group. Snapped and even
  -- sized like every other control here, so the hairline of its border lands on the pixel grid and stays one
  -- pixel from edge to edge.
  local search = CreateFrame("EditBox", nil, f, "BackdropTemplate")
  ns.SnapBox(search, 214, 22, true)
  ns.SnapPoint(search, "RIGHT", prof, "LEFT", -8, 0)
  ns.PixelBackdrop(search)
  -- The fill the window's own search fields use: a light theme paints the box as a slot, since the panel
  -- colour there would leave the box and its border the same value and the field would read as a hole.
  local function searchBg() return Theme:C(Theme:IsLight() and "slot" or "bg") end
  ns.SetBg(search, searchBg())
  ns.SetEdge(search, Theme:C("stroke"))
  Theme:Track(search, function(s)
    ns.SetBg(s, searchBg())
    s:SetTextColor(Theme:C("text"))
    if not s:HasFocus() then ns.SetEdge(s, Theme:C("stroke")) end
  end)
  search:SetFont(dropdownFont(), BASE_FONT - 1, ns.OutlineFlags())
  search:SetTextColor(Theme:C("text"))
  search:SetJustifyH("LEFT")
  search:SetTextInsets(8, 8, 0, 0)
  search:SetAutoFocus(false)
  search:SetMaxLetters(32)
  track(search, -1)
  self.searchBox = search

  local placeholder = track(Theme:Label(search, BASE_FONT - 1, "faint"), -1)
  placeholder:SetPoint("LEFT", 8, 0)
  -- Through LocalText, so a language switch repaints it with everything else instead of waiting for a reload.
  ns.LocalText(placeholder, "Search settings")
  self.searchPh = placeholder

  -- How many the query found, on the far side of the box: the room to the right of it now belongs to the
  -- Profiles button, so the count grows leftwards from the field instead of pushing into it.
  local hits = track(Theme:Label(f, BASE_FONT - 3, "faint"), -3)
  ns.SnapPoint(hits, "RIGHT", search, "LEFT", -8, 0)
  self.searchCount = hits

  search:SetScript("OnTextChanged", function(s)
    local q = s:GetText() or ""
    placeholder:SetShown(q == "")
    Options:SearchRefresh(q)
  end)
  search:SetScript("OnEscapePressed", function(s)
    s:SetText("")
    s:ClearFocus()
  end)
  search:SetScript("OnEnterPressed", function(s)
    local top = Options.searchTop
    if top then s:ClearFocus(); Options:GoToRow(top) end
  end)
  search:SetScript("OnEditFocusGained", function(s) ns.SetEdge(s, Theme:C("accent")) end)
  search:SetScript("OnEditFocusLost", function(s) ns.SetEdge(s, Theme:C("stroke")) end)

  local line = Theme:Rect(f, "strokeSoft", "ARTWORK")
  ns.PixelLine(line, 1)
  line:SetPoint("TOPLEFT", PAD, -HEADER_H)
  line:SetPoint("TOPRIGHT", -PAD, -HEADER_H)
  self.headLine = line

  -- A page holds one list, or a set of them behind a strip of its own buttons: the long pages reach a
  -- screenful each that way, and a page that already fits keeps the single list it has always had. areas
  -- is every list of every sub, flat, for the font pass that walks them all.
  -- Only the built pages are in either: tabs rise with the window, but a page's lists are built on the
  -- first visit (BuildPage), so the first open pays for one page instead of all seven.
  self.tabs, self.areas = {}, {}
  self.subs, self.subAt = {}, {}
  for i, pageDef in ipairs(Options.pages) do
    local tab = ns.CreateButton(f, T(pageDef.name), 90, TAB_H)
    track(tab.Text, -1)
    tab:SetWidth(math.max(70, tab.Text:GetStringWidth() + 22))
    -- Placement is done by ReflowPages so a hidden tab leaves no gap; here we only create it.
    tab:HookScript("OnLeave", paintTab)
    tab:SetScript("OnClick", function() self:Select(i) end)
    self.tabs[i] = tab
    self.subAt[i] = 1
  end
  self:BuildPage(1)

  self:ApplyFont()
  self:ReflowPages()
  self:AnchorHeader()
  self:Select(1)
  return f
end

function Options:AnchorHeader()
  local f = self.frame
  if not f then return end
  local top = Theme:TopInset()
  if self.title then
    self.title:ClearAllPoints()
    self.title:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(10 + top))
  end
  if self.closeBtn then
    self.closeBtn:ClearAllPoints()
    ns.SnapPoint(self.closeBtn, "TOPRIGHT", f, "TOPRIGHT", -PAD, -(8 + top))
  end
  -- The search field rides on the same band as the rest of the header: its left side hugs the Profiles
  -- button, an 8 pixel gap between them, and the count glows on the box's left, so the number grows toward
  -- the tabs. Both snapped to keywords so the Endless pixel grid keeps the pair sharp, and the skin's own
  -- TopInset only moves the band, because the pair only rides it once at build.
  if self.searchBox then
    self.searchBox:ClearAllPoints()
    ns.SnapPoint(self.searchBox, "RIGHT", self.profilesBtn, "LEFT", -8, 0)
    if self.searchCount then
      self.searchCount:ClearAllPoints()
      ns.SnapPoint(self.searchCount, "RIGHT", self.searchBox, "LEFT", -8, 0)
    end
  end
  if self.headLine then
    self.headLine:ClearAllPoints()
    self.headLine:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(HEADER_H + top))
    self.headLine:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -(HEADER_H + top))
  end
  local first = self.tabs and self.tabs[1]
  if first then
    first:ClearAllPoints()
    ns.SnapPoint(first, "TOPLEFT", f, "TOPLEFT", PAD, -(HEADER_H + 7 + top))
  end
  -- A page with a strip gives it room: the strip sits a gap under the tab row, and the page's list
  -- starts a gap under the strip. A page without one keeps the single list it has always had. Every
  -- offset is measured off the row the tabs sit in, so a translation or a font change never moves
  -- the window's frame.
  local tabsBottom = HEADER_H + 7 + TAB_H + top
  for i = 1, #Options.pages do
    local entry = self.subs[i]
    if entry then
    local areaTop = tabsBottom + 14
    if entry.strip then
      -- Both edges, not just the corner: a strip left at zero width is a degenerate rect, and the
      -- points of anything anchored to it do not resolve. The sub buttons chain off this frame's
      -- LEFT, so without a width they were built, shown and sized and still never drew. The level
      -- puts the row above the scroll areas of every page.
      local stripTop = tabsBottom + SUB_GAP
      entry.strip:ClearAllPoints()
      entry.strip:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -stripTop)
      entry.strip:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -stripTop)
      entry.strip:SetFrameLevel(f:GetFrameLevel() + 4)
      areaTop = stripTop + SUB_H + SUB_DROP
    end
    for _, area in ipairs(entry.areas) do
      area:ClearAllPoints()
      area:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -areaTop)
      area:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(PAD + SCROLL_W + 6), PAD)
    end
    end
  end
  local band = Theme:HeaderBand(f, HEADER_H + top)
  if self.headLine then self.headLine:SetShown(not band) end
end

function Options:Open()
  local f = self:Build()
  local pos = WarpeeDB and WarpeeDB.optPos
  f:ClearAllPoints()
  if pos then
    ns.SnapPoint(f, pos.p, UIParent, pos.rp, pos.x, pos.y)
  else
    ns.SnapPoint(f, "CENTER", UIParent, "CENTER", 260, 0)
  end
  self:Refresh()
  self:ApplyFont()
  f:Show()
  ns.AlignToScreen(f)
  Theme:Raise(f)
end

function Options:Close()
  closeDropdown()
  if ns.Profiles and ns.Profiles.panel then ns.Profiles.panel:Hide() end
  if self.frame then self.frame:Hide() end
end

function Options:Toggle()
  if self.frame and self.frame:IsShown() then self:Close() else self:Open() end
end
