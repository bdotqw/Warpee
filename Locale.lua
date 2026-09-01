local addonName, ns = ...

local TABLES = {}

local L = setmetatable({}, { __index = function(_, k)
  local t = TABLES[ns.LocalePick()]
  local v = t and t[k]
  return v or k
end })
ns.L = L

ns.LOCALES = { "enUS", "deDE", "ruRU" }
ns.LOCALE_LABELS = { enUS = "English", deDE = "Deutsch", ruRU = "Русский" }

local watched = {}

local function paint(w)
  local o = w.obj
  local t = (o.Text ~= nil) and o.Text or o
  if t.SetText then t:SetText(L[w.key]) end
end

function ns.LocalText(obj, key)
  if not obj then return obj end
  local w = { obj = obj, key = key }
  watched[#watched + 1] = w
  paint(w)
  return obj
end

function ns.ApplyLocaleText()
  for _, w in ipairs(watched) do paint(w) end
  if ns.Bags and ns.Bags.frame and ns.Bags.frame:IsShown() and ns.Bags.Layout then
    ns.Bags:Layout()
  end
  if ns.Bank and ns.Bank.frame and ns.Bank.frame:IsShown() and ns.Bank.Refresh then
    ns.Bank:Refresh()
  end
end

local function supported(code)
  if type(code) ~= "string" then return nil end
  for _, v in ipairs(ns.LOCALES) do
    if v == code then return code end
  end
  return nil
end

function ns.LocalePick()
  return supported(WarpeeDB and WarpeeDB.locale)
      or supported(GetLocale and GetLocale())
      or "enUS"
end

local COIN_LETTERS = {
  enUS = { g = "g", s = "s", c = "c" },
  deDE = { g = "g", s = "s", c = "k" },
  ruRU = { g = "з", s = "с", c = "м" },
}

function ns.CoinLetter(key)
  local t = COIN_LETTERS[ns.LocalePick()] or COIN_LETTERS.enUS
  return t[key] or key
end

local SHORT_FORMS = {
  enUS = { dec = ".", units = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } },
  deDE = { dec = ",", units = { { 1e12, " Bio." }, { 1e9, " Mrd." }, { 1e6, " Mio." }, { 1e3, "k" } } },
  ruRU = { dec = ",", units = { { 1e6, "кк" }, { 1e3, "к" } } },
}

function ns.ShortForm()
  return SHORT_FORMS[ns.LocalePick()] or SHORT_FORMS.enUS
end

local function foldByte(ch)
  local a, b = ch:byte(1, 2)
  if a == 208 then
    if b >= 144 and b <= 159 then return "\208" .. string.char(b + 32) end
    if b >= 160 and b <= 175 then return "\209" .. string.char(b - 32) end
    if b == 129 then return "\209\145" end
  elseif a == 195 then
    if b >= 128 and b <= 158 and b ~= 151 then return "\195" .. string.char(b + 32) end
  end
  return ch
end

function ns.SearchFold(s)
  if type(s) ~= "string" then return s end
  return (s:lower():gsub("[\195\208\209][\128-\191]", foldByte))
end

local RU_WORDS = {
  ["плохое"] = "poor", ["хлам"] = "junk", ["серое"] = "gray", ["серый"] = "gray",
  ["обычное"] = "common", ["белое"] = "white",
  ["необычное"] = "uncommon", ["зеленое"] = "green", ["зелёное"] = "green",
  ["редкое"] = "rare", ["синее"] = "blue",
  ["эпическое"] = "epic", ["эпик"] = "epic", ["фиолетовое"] = "purple",
  ["легендарное"] = "legendary", ["оранжевое"] = "orange",
  ["артефакт"] = "artifact", ["наследие"] = "heirloom",
  ["голова"] = "head", ["шлем"] = "helm", ["шея"] = "neck",
  ["плечи"] = "shoulder", ["плечо"] = "shoulder",
  ["спина"] = "back", ["плащ"] = "cloak", ["грудь"] = "chest",
  ["запястья"] = "wrist", ["наручи"] = "bracers",
  ["перчатки"] = "gloves", ["кисти"] = "hands",
  ["пояс"] = "waist", ["ремень"] = "belt",
  ["ноги"] = "legs", ["штаны"] = "pants",
  ["ступни"] = "feet", ["сапоги"] = "boots", ["ботинки"] = "boots",
  ["палец"] = "finger", ["кольцо"] = "ring", ["кольца"] = "rings",
  ["аксессуар"] = "trinket", ["тринкет"] = "trinket",
  ["щит"] = "shield", ["накидка"] = "tabard", ["рубашка"] = "shirt",
  ["реликвия"] = "relic",
  ["дальнобойное"] = "ranged", ["метательное"] = "thrown",
  ["боеприпасы"] = "ammo", ["патроны"] = "ammo", ["колчан"] = "quiver",
  ["инструмент"] = "tool", ["профснаряжение"] = "profgear",
  ["слотсумки"] = "bagslot",
  ["оружие"] = "weapon", ["правая"] = "mainhand", ["левая"] = "offhand",
  ["двуручное"] = "2h", ["двуруч"] = "2h",
  ["одноручное"] = "1h", ["одноруч"] = "1h",
  ["ткань"] = "cloth", ["кожа"] = "leather", ["кольчуга"] = "mail", ["латы"] = "plate",
  ["косметическое"] = "cosmetic", ["косметика"] = "cosmetic",
  ["кинжал"] = "dagger", ["меч"] = "sword", ["топор"] = "axe",
  ["дробящее"] = "mace", ["булава"] = "mace",
  ["древковое"] = "polearm", ["копье"] = "polearm", ["копьё"] = "polearm",
  ["посох"] = "staff", ["лук"] = "bow",
  ["огнестрельное"] = "gun", ["ружье"] = "gun", ["ружьё"] = "gun",
  ["арбалет"] = "crossbow", ["жезл"] = "wand", ["кистевое"] = "fist",
  ["глефа"] = "warglaive", ["глефы"] = "warglaive", ["удочка"] = "fishing",
  ["транспорт"] = "mount", ["маунт"] = "mount",
  ["самоцвет"] = "gem", ["рецепт"] = "recipe", ["символ"] = "glyph",
  ["сумка"] = "bag", ["сумки"] = "bag", ["контейнер"] = "container",
  ["питомец"] = "pet", ["снаряды"] = "projectile",
  ["хозтовары"] = "tradegoods", ["товары"] = "tradegoods",
  ["разное"] = "misc", ["улучшение"] = "enhancement",
  ["реагент"] = "reagent", ["реагенты"] = "reagents", ["маты"] = "mats",
  ["задание"] = "quest", ["квест"] = "quest",
  ["расходуемые"] = "consumable", ["расходники"] = "consumables",
  ["снаряжение"] = "gear", ["экип"] = "equip",
  ["ключ"] = "keystone", ["мифик"] = "mythic",
  ["токен"] = "token", ["тир"] = "tier",
  ["заблокировано"] = "locked", ["заперто"] = "blocked",
  ["отряд"] = "warband", ["персональное"] = "soulbound",
  ["неперсональное"] = "boe",
  ["текущее"] = "current", ["старое"] = "legacy",
}

local DE_WORDS = {
  ["schlecht"] = "poor", ["schrott"] = "junk", ["grau"] = "gray",
  ["gewöhnlich"] = "common", ["weiß"] = "white", ["weiss"] = "white",
  ["ungewöhnlich"] = "uncommon", ["grün"] = "green", ["gruen"] = "green",
  ["selten"] = "rare", ["blau"] = "blue",
  ["episch"] = "epic", ["lila"] = "purple", ["violett"] = "purple",
  ["legendär"] = "legendary", ["artefakt"] = "artifact", ["erbstück"] = "heirloom",
  ["kopf"] = "head", ["hals"] = "neck", ["schulter"] = "shoulder",
  ["rücken"] = "back", ["umhang"] = "cloak", ["brust"] = "chest",
  ["handgelenke"] = "wrist", ["armschienen"] = "bracers",
  ["hände"] = "hands", ["handschuhe"] = "gloves",
  ["taille"] = "waist", ["gürtel"] = "belt",
  ["beine"] = "legs", ["hose"] = "pants",
  ["füße"] = "feet", ["stiefel"] = "boots",
  ["schmuck"] = "trinket", ["schild"] = "shield",
  ["wappenrock"] = "tabard", ["hemd"] = "shirt", ["relikt"] = "relic",
  ["distanz"] = "ranged", ["wurfwaffe"] = "thrown",
  ["munition"] = "ammo", ["köcher"] = "quiver",
  ["werkzeug"] = "tool", ["berufsausrüstung"] = "profgear",
  ["taschenplatz"] = "bagslot",
  ["waffe"] = "weapon", ["waffenhand"] = "mainhand", ["nebenhand"] = "offhand",
  ["zweihand"] = "2h", ["einhand"] = "1h",
  ["stoff"] = "cloth", ["leder"] = "leather",
  ["kette"] = "mail", ["ketten"] = "mail",
  ["platte"] = "plate", ["platten"] = "plate", ["kosmetisch"] = "cosmetic",
  ["dolch"] = "dagger", ["schwert"] = "sword", ["axt"] = "axe",
  ["streitkolben"] = "mace", ["stangenwaffe"] = "polearm", ["stab"] = "staff",
  ["bogen"] = "bow", ["schusswaffe"] = "gun", ["armbrust"] = "crossbow",
  ["zauberstab"] = "wand", ["faustwaffe"] = "fist", ["kriegsglefe"] = "warglaive",
  ["angel"] = "fishing", ["angelrute"] = "fishing",
  ["reittier"] = "mount", ["edelstein"] = "gem", ["rezept"] = "recipe",
  ["glyphe"] = "glyph", ["tasche"] = "bag", ["behälter"] = "container",
  ["haustier"] = "pet", ["projektil"] = "projectile",
  ["handelswaren"] = "tradegoods", ["verschiedenes"] = "misc",
  ["verbesserung"] = "enhancement",
  ["reagenz"] = "reagent", ["reagenzien"] = "reagents",
  ["verbrauchbar"] = "consumable", ["ausrüstung"] = "gear",
  ["schlüsselstein"] = "keystone", ["marke"] = "token",
  ["gesperrt"] = "locked", ["kriegsmeute"] = "warband",
  ["seelengebunden"] = "soulbound", ["anlegen"] = "boe",
  ["aktuell"] = "current", ["alt"] = "legacy",
}

local aliasMap

function ns.SearchAlias(token)
  if not aliasMap then
    aliasMap = {}
    for _, t in ipairs({ RU_WORDS, DE_WORDS }) do
      for k, v in pairs(t) do aliasMap[ns.SearchFold(k)] = v end
    end
  end
  return aliasMap[ns.SearchFold(token)]
end

local RU = {
  ["General"] = "Общее",
  ["Grid"] = "Сетка",
  ["Items"] = "Предметы",
  ["Vendor"] = "Торговец",
  ["Characters"] = "Персонажи",
  ["Look"] = "Вид",
  ["Windows"] = "Окна",
  ["Money"] = "Деньги",
  ["Search"] = "Поиск",
  ["Markers"] = "Метки",
  ["Slot look"] = "Вид ячейки",
  ["Bags grid"] = "Сетка сумок",
  ["Bank and Warband grid"] = "Сетка банка и банка отряда",
  ["Item level number"] = "Уровень предмета на иконке",
  ["Stack count number"] = "Количество в стопке",
  ["Locked items"] = "Защищённые предметы",
  ["Item tooltips"] = "Подсказки предметов",
  ["Open bags with"] = "Открывать сумки вместе с",
  ["Runs on its own"] = "Автоматически",
  ["The coin button"] = "Кнопка монеты",
  ["Token expansions"] = "Дополнения для токенов",
  ["Never sell"] = "Никогда не продавать",
  ["Theme"] = "Тема",
  ["Font"] = "Шрифт",
  ["Language"] = "Язык",
  ["Lock windows"] = "Закрепить окна",
  ["Hide X/Y fields"] = "Скрыть поля X/Y",
  ["Capacity bar"] = "Полоса заполнения",
  ["Hide minimap icon"] = "Скрыть иконку у миникарты",
  ["Gold format"] = "Формат сумм",
  ["Gold only"] = "Только золото",
  ["Coin letters"] = "Буквы вместо монет",
  ["Clear on close"] = "Очищать при закрытии",
  ["Bags and bank together"] = "Сумки и банк вместе",
  ["Color scheme for the whole addon."] = "Цветовая схема всего аддона.",
  ["Used for every label Warpee draws. Other addons can add to this list."] =
    "Используется для всех надписей Warpee. Другие аддоны могут добавлять шрифты в этот список.",
  ["Language for the addon's own text. Item names always come from the game."] =
    "Язык текста самого аддона. Названия предметов всегда берутся из игры.",
  ["Freeze the windows in place. Unlocked, each shows X/Y fields along its bottom edge — type a value or nudge with the arrows (Shift = 10)."] =
    "Закрепляет окна на месте. Если отметку снять, у каждого окна снизу появятся поля X и Y: значение можно ввести вручную или менять стрелками (Shift — шаг 10).",
  ["The windows stay movable by dragging, but the X/Y fields are not drawn."] =
    "Окна по-прежнему можно перетаскивать мышью, но поля X и Y не показываются.",
  ["Fill bar in the bags header showing how full they are."] =
    "Полоса в шапке сумок, показывающая, насколько они заполнены.",
  ["Takes the Warpee button off the minimap."] = "Убирает кнопку Warpee с миникарты.",
  ["Grouping for printed amounts. Short abbreviates to K and M."] =
    "Как разделяются разряды в суммах. Краткий формат сокращает тысячи до «к», миллионы — до «кк».",
  ["Show gold only, hide silver and copper."] = "Показывать только золото, без серебра и меди.",
  ["On = g/s/c letters. Off = coin icons."] = "Вкл. — буквы з/с/м вместо иконок монет.",
  ["Empty the search box when the window closes, so it opens unfiltered next time."] =
    "Очищать поле поиска при закрытии окна, чтобы в следующий раз оно открылось без фильтра.",
  ["While both windows are open, typing in either box searches both at once."] =
    "Пока открыты оба окна, ввод в любом поле ищет сразу в обоих.",
  ["The bags open together with these windows and close with them again."] =
    "Сумки открываются вместе с этими окнами и закрываются вместе с ними.",
  ["Bank"] = "Банк",
  ["Mail"] = "Почта",
  ["Auction house"] = "Аукцион",
  ["Trade"] = "Обмен",
  ["Guild bank"] = "Банк гильдии",
  ["Professions"] = "Профессии",
  ["Icon size"] = "Размер иконки",
  ["Slots per row"] = "Ячеек в ряду",
  ["Spacing"] = "Отступ",
  ["Icon zoom"] = "Масштаб иконки",
  ["Merge reagents"] = "Объединить реагенты",
  ["Slot background"] = "Фон ячейки",
  ["Plate opacity"] = "Плотность подложки",
  ["Bank slots per row"] = "Ячеек в ряду (банк)",
  ["Warband slots per row"] = "Ячеек в ряду (банк отряда)",
  ["Size of one slot in the bags."] = "Размер одной ячейки в сумках.",
  ["How wide the bag window grows."] = "От этого зависит ширина окна сумок.",
  ["Gap between slots, in every grid."] = "Промежуток между ячейками во всех сетках.",
  ["1.00 fills the slot. Less shrinks the icon, more crops it."] =
    "1.00 — иконка занимает всю ячейку. Меньше — уменьшает иконку, больше — обрезает её края.",
  ["Lay the reagent bag out with the main bags, without its caption."] =
    "Показывать сумку реагентов вместе с основными, без отдельного заголовка.",
  ["What sits behind every icon. Transparent shows the plate through the slot, Highlight lifts it out, Solid closes it off."] =
    "Что находится за иконкой. «Прозрачный» — сквозь ячейку видна подложка, «Подсветка» — ячейка чуть светлее фона, «Заливка» — фон полностью закрыт.",
  ["The plate behind the slots, seen in the gaps. At Spacing 0 there are none."] =
    "Подложка за ячейками, видимая в промежутках. При отступе 0 промежутков нет.",
  ["The bank keeps its own width and icon size, apart from the bags."] =
    "У банка своя ширина и свой размер иконок, отдельно от сумок.",
  ["One icon size for both bank tabs."] = "Один размер иконок для обеих вкладок банка.",
  ["Transparent"] = "Прозрачный",
  ["Highlight"] = "Подсветка",
  ["Solid"] = "Заливка",
  ["Top left"] = "Сверху слева",
  ["Top right"] = "Сверху справа",
  ["Bottom left"] = "Снизу слева",
  ["Bottom right"] = "Снизу справа",
  ["Game language"] = "Язык игры",
  ["Delete saved bags and bank of %s?"] = "Удалить сохранённые сумки и банк %s?",
  ["Quality border"] = "Рамка качества",
  ["Quest marker"] = "Метка задания",
  ["New item glow"] = "Свечение новых предметов",
  ["Junk coin"] = "Монета на хламе",
  ["Border thickness"] = "Толщина рамки",
  ["Color by quality"] = "Цвет по качеству",
  ["Corner"] = "Угол",
  ["Size"] = "Размер",
  ["X offset"] = "Сдвиг по X",
  ["Y offset"] = "Сдвиг по Y",
  ["Draw a rarity-colored border around uncommon+ items."] =
    "Рамка цвета качества вокруг предметов необычного качества и выше.",
  ["Blizzard quest art: a mark for unaccepted quests, a border for quest items."] =
    "Штатная графика заданий: восклицательный знак для непринятых заданий, рамка для предметов заданий.",
  ["Quality-colored glow on items the game still counts as new."] =
    "Свечение цвета качества на предметах, которые игра ещё считает новыми.",
  ["Gold coin marker on poor-quality (gray) items."] = "Значок монеты на предметах плохого качества (серых).",
  ["Thickness of the quality border."] = "Толщина рамки качества.",
  ["Tint the number with the item's rarity color."] = "Окрашивать число в цвет качества предмета.",
  ["Which corner of the slot the number sits in."] = "В каком углу ячейки стоит число.",
  ["Which corner of the slot the stack size sits in."] = "В каком углу ячейки стоит количество.",
  ["Alt-click an item in the bags or the bank to lock it: a padlock appears and the vendor never sells it. Alt-click again, or the cross here, to unlock."] =
    "Alt + щелчок по предмету в сумках или банке защищает его: появляется замок, и торговец такой предмет не продаст. Повторный Alt + щелчок или крестик в этом списке снимает защиту.",
  ["Count across characters"] = "Считать по всем персонажам",
  ["Include bank"] = "Учитывать банк",
  ["Include Warband"] = "Учитывать банк отряда",
  ["Adds an Inventory block to item tooltips: how many each character carries."] =
    "Добавляет в подсказки предметов блок «Инвентарь»: сколько предметов у каждого персонажа.",
  ["Count each character's bank too. Off = bags only."] =
    "Считать и банк каждого персонажа. Выкл. — только сумки.",
  ["Count the shared Warband bank on its own line."] =
    "Считать общий банк отряда отдельной строкой.",
  ["Unchecked characters stay saved but are hidden from the character list."] =
    "Персонажи без отметки остаются в сохранённых данных, но не показываются в списке.",
  ["Sell junk"] = "Продавать хлам",
  ["Repair"] = "Ремонт",
  ["Item level from"] = "Уровень предмета от",
  ["Item level under"] = "Уровень предмета до",
  ["Legion relics"] = "Реликвии Легиона",
  ["Old consumables"] = "Старые расходники",
  ["Tier tokens"] = "Тир-токены",
  ["Sell all of this automatically"] = "Продавать это автоматически",
  ["Keep BoE"] = "Оставлять непривязанное",
  ["Keep warbound"] = "Оставлять привязанное к отряду",
  ["Keep gems and enchants"] = "Оставлять с камнями и чарами",
  ["Your gold"] = "Своё золото",
  ["Guild / yours"] = "Гильдия / свои",
  ["These start when a merchant window opens, with no click from you."] =
    "Запускается само при открытии окна торговца, без нажатия кнопок.",
  ["Everything below is sold by the coin in the bags header, only when you press it."] =
    "Всё, что ниже, продаётся кнопкой-монетой в шапке сумок и только по нажатию.",
  ["Sell every gray item, whatever its item level."] =
    "Продавать любой серый предмет независимо от уровня.",
  ["Repair at merchants who offer it. Others are left alone, with no message."] =
    "Ремонт у торговцев, которые его предлагают. У остальных ничего не происходит и сообщений нет.",
  ["Where the repair money comes from. The guild bank is used only if your withdraw limit covers the whole bill."] =
    "Откуда берутся деньги на ремонт. Банк гильдии используется только если лимит вывода покрывает весь счёт.",
  ["Gear at or above this item level is sold."] =
    "Продаётся снаряжение этого уровня предмета и выше.",
  ["Gear under this item level is sold. Zero keeps every piece."] =
    "Продаётся снаряжение ниже этого уровня предмета. Ноль — снаряжение не продаётся вовсе.",
  ["Sell Legion artifact relics. Item level ignored."] =
    "Продавать реликвии артефактов Легиона. Уровень предмета не учитывается.",
  ["Sell potions, flasks, food and bandages older than the previous expansion."] =
    "Продавать зелья, настои, еду и бинты старше предыдущего дополнения.",
  ["Sell raid armor tokens, item level ignored. Only from the expansions ticked below."] =
    "Продавать рейдовые токены брони независимо от уровня предмета. Только из отмеченных ниже дополнений.",
  ["Sell the list above at every merchant, without pressing the coin."] =
    "Продавать всё из списка выше у каждого торговца, без нажатия монеты.",
  ["Sell tier tokens from this expansion."] = "Продавать тир-токены этого дополнения.",
  ["Which expansions tokens may be sold from. The four newest are kept by default. Expansions that never had tokens are not listed."] =
    "Из каких дополнений можно продавать токены. Четыре последних по умолчанию не продаются. Дополнения, где токенов не было, в списке не показаны.",
  ["Skip gear that is not bound yet, so it can go to the auction house."] =
    "Пропускать ещё не привязанное снаряжение, чтобы его можно было продать на аукционе.",
  ["Skip warbound gear — an alt can still use it."] =
    "Пропускать снаряжение, привязанное к отряду: его ещё может надеть другой персонаж.",
  ["Skip any piece with a gem socketed or an enchant applied."] =
    "Пропускать вещи со вставленным камнем или наложенными чарами.",
  ["Commas (5,000,000)"] = "Запятые (5,000,000)",
  ["Dots (5.000.000)"] = "Точки (5.000.000)",
  ["Spaces (5 000 000)"] = "Пробелы (5 000 000)",
  ["Short (5M, 284.4K)"] = "Кратко (5кк, 284,4к)",
  ["%d of %d"] = "%d из %d",
  ["1 item"] = "1 предмет",
  ["%d items"] = "предметов: %d",
  ["%d and %d wide"] = "%d и %d в ряду",
  ["Sort / clean up bags"] = "Разобрать сумки",
  ["Sort / clean up"] = "Разобрать",
  ["Settings"] = "Настройки",
  ["Bags"] = "Сумки",
  ["Bank / Warband"] = "Банк и банк отряда",
  ["Sell now"] = "Продать сейчас",
  ["Bags of another character"] = "Сумки другого персонажа",
  ["REAGENTS"] = "РЕАГЕНТЫ",
  ["BAGS"] = "СУМКИ",
  ["WARBAND BANK"] = "БАНК ОТРЯДА",
  ["Warband"] = "Отряд",
  ["Buy tab"] = "Купить",
  ["Buy tab · %s"] = "Купить · %s",
  ["Cost: %s"] = "Цена: %s",
  ["Hidden"] = "Скрытые",
  ["Visit a banker to record this bank"] = "Данные банка появятся после визита к банкиру",
  ["Browse another character's bank"] = "Посмотреть банк другого персонажа",
  ["Put your gold into the Warband bank"] = "Положить золото в банк отряда",
  ["Take gold out of the Warband bank"] = "Забрать золото из банка отряда",
  ["Buy another bank tab"] = "Купить ещё одну вкладку банка",
  ["Buy another Warband bank tab"] = "Купить ещё одну вкладку банка отряда",
  ["Show characters you hid"] = "Показать скрытых персонажей",
  ["Close"] = "Закрыть",
  ["Left-click: show this character"] = "ЛКМ — показать этого персонажа",
  ["Right-click: hide"] = "ПКМ — скрыть",
  ["Right-click: unhide"] = "ПКМ — вернуть в список",
  ["Warpee"] = "Warpee",
  ["Click opens the settings"] = "Щелчок открывает настройки",
  ["Drag to move around the minimap"] = "Перетаскивание перемещает иконку вокруг миникарты",
  ["Nothing to sell"] = "Продавать нечего",
  ["Selling now"] = "Идёт продажа",
  ["Talk to a merchant first"] = "Работает только у торговца",
  ["%d items for %s"] = "К продаже: %d, на сумму %s",
  ["%d items could not be sold and stayed in the bags"] =
    "Не удалось продать: %d — предметы остались в сумках",
  ["repaired for %s from %s"] = "ремонт за %s %s",
  ["guild funds"] = "из кассы гильдии",
  ["your gold"] = "из своего золота",
  ["Inventory"] = "Инвентарь",
  ["Warband bank"] = "Банк отряда",
  ["Total"] = "Всего",
  ["%d  (%d bags, %d bank)"] = "%d  (%d в сумках, %d в банке)",
  ["%d  (bank)"] = "%d  (в банке)",
  ["%d  (bags)"] = "%d  (в сумках)",
  ["loaded"] = "загружен",
  ["columns"] = "ячеек в ряду",
  ["Favorites"] = "Избранное",
  ["Favorite slots"] = "Ячейки избранного",
  ["How many slots"] = "Сколько ячеек",
  ["A row of slots above the grid, always in sight. Drag an item onto one to keep it a click away, Ctrl + right click clears a slot."] =
    "Ряд ячеек над сеткой, всегда на виду. Перетащите предмет в ячейку, чтобы держать его под рукой; Ctrl + правый щелчок освобождает ячейку.",
  ["Never more than the grid is wide. Zero keeps the row as wide as the grid."] =
    "Не больше, чем ширина сетки. Ноль — во всю ширину сетки.",
  ["As the grid"] = "Как сетка",
  ["Drag an item here to keep it one click away"] =
    "Перетащите сюда предмет, чтобы использовать его одним щелчком",
  ["Ctrl + right click clears the slot"] = "Ctrl + правый щелчок освобождает ячейку",
  ["No gold recorded yet"] = "Данных о золоте пока нет",
  ["Delete mode"] = "Режим удаления",
  ["Alt-click an item in your bags while this tab is open."] =
    "Alt + щелчок по предмету в сумках, пока открыта эта вкладка.",
}

TABLES.ruRU = RU

local DE = {
  ["General"] = "Allgemein",
  ["Grid"] = "Raster",
  ["Items"] = "Gegenstände",
  ["Vendor"] = "Händler",
  ["Characters"] = "Charaktere",
  ["Look"] = "Aussehen",
  ["Windows"] = "Fenster",
  ["Money"] = "Geld",
  ["Search"] = "Suche",
  ["Markers"] = "Markierungen",
  ["Slot look"] = "Aussehen der Plätze",
  ["Bags grid"] = "Taschenraster",
  ["Bank and Warband grid"] = "Raster für Bank und Kriegsmeute",
  ["Item level number"] = "Gegenstandsstufe auf dem Symbol",
  ["Stack count number"] = "Stapelanzahl auf dem Symbol",
  ["Locked items"] = "Geschützte Gegenstände",
  ["Item tooltips"] = "Gegenstands-Tooltips",
  ["Open bags with"] = "Taschen öffnen mit",
  ["Runs on its own"] = "Automatisch",
  ["The coin button"] = "Münzknopf",
  ["Token expansions"] = "Erweiterungen für Token",
  ["Never sell"] = "Nie verkaufen",
  ["Theme"] = "Design",
  ["Font"] = "Schriftart",
  ["Language"] = "Sprache",
  ["Lock windows"] = "Fenster fixieren",
  ["Hide X/Y fields"] = "X/Y-Felder ausblenden",
  ["Capacity bar"] = "Füllstandsleiste",
  ["Hide minimap icon"] = "Minikartensymbol ausblenden",
  ["Gold format"] = "Zahlenformat",
  ["Gold only"] = "Nur Gold",
  ["Coin letters"] = "Münzbuchstaben",
  ["Clear on close"] = "Beim Schließen leeren",
  ["Bags and bank together"] = "Taschen und Bank zusammen",
  ["Color scheme for the whole addon."] = "Farbschema für das ganze Addon.",
  ["Used for every label Warpee draws. Other addons can add to this list."] =
    "Wird für jeden Text verwendet, den Warpee zeichnet. Andere Addons können diese Liste erweitern.",
  ["Language for the addon's own text. Item names always come from the game."] =
    "Sprache für die Texte des Addons. Gegenstandsnamen kommen immer aus dem Spiel.",
  ["Freeze the windows in place. Unlocked, each shows X/Y fields along its bottom edge — type a value or nudge with the arrows (Shift = 10)."] =
    "Hält die Fenster an ihrem Platz. Ohne Fixierung zeigt jedes Fenster am unteren Rand Felder für X und Y: Wert eintippen oder mit den Pfeilen ändern (Shift = 10er-Schritte).",
  ["The windows stay movable by dragging, but the X/Y fields are not drawn."] =
    "Die Fenster lassen sich weiter mit der Maus verschieben, die Felder für X und Y werden aber nicht angezeigt.",
  ["Fill bar in the bags header showing how full they are."] =
    "Leiste in der Kopfzeile der Taschen, die zeigt, wie voll sie sind.",
  ["Takes the Warpee button off the minimap."] = "Entfernt den Warpee-Knopf von der Minikarte.",
  ["Grouping for printed amounts. Short abbreviates to K and M."] =
    "Wie die Ziffern in Beträgen gruppiert werden. »Kurz« kürzt Tausender zu k und Millionen zu Mio.",
  ["Show gold only, hide silver and copper."] = "Nur Gold anzeigen, Silber und Kupfer ausblenden.",
  ["On = g/s/c letters. Off = coin icons."] = "Ein: Buchstaben g/s/k. Aus: Münzsymbole.",
  ["Empty the search box when the window closes, so it opens unfiltered next time."] =
    "Leert das Suchfeld beim Schließen des Fensters, damit es beim nächsten Öffnen ungefiltert ist.",
  ["While both windows are open, typing in either box searches both at once."] =
    "Solange beide Fenster offen sind, sucht die Eingabe in einem Feld gleichzeitig in beiden.",
  ["The bags open together with these windows and close with them again."] =
    "Die Taschen öffnen sich zusammen mit diesen Fenstern und schließen sich mit ihnen wieder.",
  ["Bank"] = "Bank",
  ["Mail"] = "Post",
  ["Auction house"] = "Auktionshaus",
  ["Trade"] = "Handel",
  ["Guild bank"] = "Gildenbank",
  ["Professions"] = "Berufe",
  ["Icon size"] = "Symbolgröße",
  ["Slots per row"] = "Plätze pro Reihe",
  ["Spacing"] = "Abstand",
  ["Icon zoom"] = "Symbolzoom",
  ["Merge reagents"] = "Reagenzien zusammenlegen",
  ["Slot background"] = "Platzhintergrund",
  ["Plate opacity"] = "Deckkraft der Unterlage",
  ["Bank slots per row"] = "Bankplätze pro Reihe",
  ["Warband slots per row"] = "Kriegsmeutenplätze pro Reihe",
  ["Size of one slot in the bags."] = "Größe eines Platzes in den Taschen.",
  ["How wide the bag window grows."] = "Davon hängt die Breite des Taschenfensters ab.",
  ["Gap between slots, in every grid."] = "Abstand zwischen den Plätzen in allen Rastern.",
  ["1.00 fills the slot. Less shrinks the icon, more crops it."] =
    "1.00 füllt den Platz ganz aus. Weniger verkleinert das Symbol, mehr beschneidet es.",
  ["Lay the reagent bag out with the main bags, without its caption."] =
    "Zeigt die Reagenzientasche zusammen mit den Haupttaschen an, ohne eigene Überschrift.",
  ["What sits behind every icon. Transparent shows the plate through the slot, Highlight lifts it out, Solid closes it off."] =
    "Was hinter jedem Symbol liegt. »Transparent« lässt die Unterlage durchscheinen, »Aufgehellt« hebt den Platz leicht hervor, »Deckend« schließt ihn ganz ab.",
  ["The plate behind the slots, seen in the gaps. At Spacing 0 there are none."] =
    "Die Unterlage hinter den Plätzen, sichtbar in den Zwischenräumen. Bei Abstand 0 gibt es keine Zwischenräume.",
  ["The bank keeps its own width and icon size, apart from the bags."] =
    "Die Bank hat ihre eigene Breite und Symbolgröße, unabhängig von den Taschen.",
  ["One icon size for both bank tabs."] = "Eine Symbolgröße für Bank und Kriegsmeute.",
  ["Transparent"] = "Transparent",
  ["Highlight"] = "Aufgehellt",
  ["Solid"] = "Deckend",
  ["Top left"] = "Oben links",
  ["Top right"] = "Oben rechts",
  ["Bottom left"] = "Unten links",
  ["Bottom right"] = "Unten rechts",
  ["Game language"] = "Spielsprache",
  ["Delete saved bags and bank of %s?"] = "Gespeicherte Taschen und Bank von %s löschen?",
  ["Quality border"] = "Qualitätsrahmen",
  ["Quest marker"] = "Questmarkierung",
  ["New item glow"] = "Leuchten neuer Gegenstände",
  ["Junk coin"] = "Münze auf Schund",
  ["Border thickness"] = "Rahmenstärke",
  ["Color by quality"] = "Nach Qualität einfärben",
  ["Corner"] = "Ecke",
  ["Size"] = "Größe",
  ["X offset"] = "X-Versatz",
  ["Y offset"] = "Y-Versatz",
  ["Draw a rarity-colored border around uncommon+ items."] =
    "Zeichnet einen Rahmen in der Qualitätsfarbe um Gegenstände ab »Ungewöhnlich«.",
  ["Blizzard quest art: a mark for unaccepted quests, a border for quest items."] =
    "Blizzards Questgrafik: ein Ausrufezeichen für nicht angenommene Quests, ein Rahmen für Questgegenstände.",
  ["Quality-colored glow on items the game still counts as new."] =
    "Leuchten in der Qualitätsfarbe auf Gegenständen, die das Spiel noch als neu zählt.",
  ["Gold coin marker on poor-quality (gray) items."] =
    "Goldmünze auf Gegenständen schlechter Qualität (grau).",
  ["Thickness of the quality border."] = "Stärke des Qualitätsrahmens.",
  ["Tint the number with the item's rarity color."] =
    "Färbt die Zahl in der Qualitätsfarbe des Gegenstands.",
  ["Which corner of the slot the number sits in."] = "In welcher Ecke des Platzes die Zahl steht.",
  ["Which corner of the slot the stack size sits in."] =
    "In welcher Ecke des Platzes die Stapelanzahl steht.",
  ["Alt-click an item in the bags or the bank to lock it: a padlock appears and the vendor never sells it. Alt-click again, or the cross here, to unlock."] =
    "Alt + Klick auf einen Gegenstand in den Taschen oder der Bank schützt ihn: ein Schloss erscheint und beim Händler wird er nie verkauft. Erneutes Alt + Klick oder das Kreuz in dieser Liste hebt den Schutz auf.",
  ["Count across characters"] = "Über alle Charaktere zählen",
  ["Include bank"] = "Bank einbeziehen",
  ["Include Warband"] = "Kriegsmeutenbank einbeziehen",
  ["Adds an Inventory block to item tooltips: how many each character carries."] =
    "Fügt Gegenstands-Tooltips einen Abschnitt »Inventar« hinzu: wie viele davon jeder Charakter hat.",
  ["Count each character's bank too. Off = bags only."] =
    "Zählt auch die Bank jedes Charakters. Aus: nur die Taschen.",
  ["Count the shared Warband bank on its own line."] =
    "Zählt die gemeinsame Kriegsmeutenbank in einer eigenen Zeile.",
  ["Unchecked characters stay saved but are hidden from the character list."] =
    "Charaktere ohne Häkchen bleiben gespeichert, erscheinen aber nicht in der Charakterliste.",
  ["Sell junk"] = "Schund verkaufen",
  ["Repair"] = "Reparieren",
  ["Item level from"] = "Gegenstandsstufe ab",
  ["Item level under"] = "Gegenstandsstufe unter",
  ["Legion relics"] = "Legion-Relikte",
  ["Old consumables"] = "Alte Verbrauchsgegenstände",
  ["Tier tokens"] = "Tier-Token",
  ["Sell all of this automatically"] = "Alles davon automatisch verkaufen",
  ["Keep BoE"] = "BoE behalten",
  ["Keep warbound"] = "Kriegsmeutengebundenes behalten",
  ["Keep gems and enchants"] = "Mit Sockel/Verzauberung behalten",
  ["Your gold"] = "Eigenes Gold",
  ["Guild / yours"] = "Gilde / eigenes",
  ["These start when a merchant window opens, with no click from you."] =
    "Läuft von selbst, sobald das Händlerfenster aufgeht, ohne Klick von Euch.",
  ["Everything below is sold by the coin in the bags header, only when you press it."] =
    "Alles Folgende wird über die Münze in der Kopfzeile der Taschen verkauft, und nur wenn Ihr sie drückt.",
  ["Sell every gray item, whatever its item level."] =
    "Verkauft jeden grauen Gegenstand, unabhängig von der Gegenstandsstufe.",
  ["Repair at merchants who offer it. Others are left alone, with no message."] =
    "Repariert bei Händlern, die Reparaturen anbieten. Bei allen anderen passiert nichts und es gibt keine Meldung.",
  ["Where the repair money comes from. The guild bank is used only if your withdraw limit covers the whole bill."] =
    "Woher das Gold für die Reparatur kommt. Die Gildenbank wird nur genutzt, wenn Euer Abhebelimit die ganze Rechnung deckt.",
  ["Gear at or above this item level is sold."] =
    "Ausrüstung ab dieser Gegenstandsstufe wird verkauft.",
  ["Gear under this item level is sold. Zero keeps every piece."] =
    "Ausrüstung unter dieser Gegenstandsstufe wird verkauft. Bei 0 wird keine Ausrüstung verkauft.",
  ["Sell Legion artifact relics. Item level ignored."] =
    "Verkauft Artefaktrelikte aus Legion. Die Gegenstandsstufe wird ignoriert.",
  ["Sell potions, flasks, food and bandages older than the previous expansion."] =
    "Verkauft Tränke, Fläschchen, Essen und Verbände, die älter als die vorherige Erweiterung sind.",
  ["Sell raid armor tokens, item level ignored. Only from the expansions ticked below."] =
    "Verkauft Rüstungsmarken aus Schlachtzügen, unabhängig von der Gegenstandsstufe. Nur aus den unten angehakten Erweiterungen.",
  ["Sell the list above at every merchant, without pressing the coin."] =
    "Verkauft alles aus der Liste oben bei jedem Händler, ohne Druck auf die Münze.",
  ["Sell tier tokens from this expansion."] = "Tier-Token aus dieser Erweiterung verkaufen.",
  ["Which expansions tokens may be sold from. The four newest are kept by default. Expansions that never had tokens are not listed."] =
    "Aus welchen Erweiterungen Token verkauft werden dürfen. Die vier neuesten sind standardmäßig ausgenommen. Erweiterungen ohne Token stehen nicht in der Liste.",
  ["Skip gear that is not bound yet, so it can go to the auction house."] =
    "Überspringt noch nicht gebundene Ausrüstung, damit sie ins Auktionshaus kann.",
  ["Skip warbound gear — an alt can still use it."] =
    "Überspringt kriegsmeutengebundene Ausrüstung: ein anderer Charakter kann sie noch tragen.",
  ["Skip any piece with a gem socketed or an enchant applied."] =
    "Überspringt jedes Teil mit eingesetztem Edelstein oder aufgetragener Verzauberung.",
  ["Commas (5,000,000)"] = "Komma (5,000,000)",
  ["Dots (5.000.000)"] = "Punkt (5.000.000)",
  ["Spaces (5 000 000)"] = "Leerzeichen (5 000 000)",
  ["Short (5M, 284.4K)"] = "Kurz (5 Mio., 284,4k)",
  ["%d of %d"] = "%d von %d",
  ["1 item"] = "1 Gegenstand",
  ["%d items"] = "%d Gegenstände",
  ["%d and %d wide"] = "%d und %d pro Reihe",
  ["Sort / clean up bags"] = "Taschen sortieren",
  ["Sort / clean up"] = "Sortieren",
  ["Settings"] = "Einstellungen",
  ["Bags"] = "Taschen",
  ["Bank / Warband"] = "Bank / Kriegsmeute",
  ["Sell now"] = "Jetzt verkaufen",
  ["Bags of another character"] = "Taschen eines anderen Charakters",
  ["REAGENTS"] = "REAGENZIEN",
  ["BAGS"] = "TASCHEN",
  ["WARBAND BANK"] = "KRIEGSMEUTENBANK",
  ["Warband"] = "Kriegsmeute",
  ["Buy tab"] = "Fach kaufen",
  ["Buy tab · %s"] = "Fach kaufen · %s",
  ["Cost: %s"] = "Kosten: %s",
  ["Hidden"] = "Versteckt",
  ["Visit a banker to record this bank"] = "Besucht einen Bankier, um diese Bank zu erfassen",
  ["Browse another character's bank"] = "Bank eines anderen Charakters ansehen",
  ["Put your gold into the Warband bank"] = "Gold in die Kriegsmeutenbank einzahlen",
  ["Take gold out of the Warband bank"] = "Gold aus der Kriegsmeutenbank abheben",
  ["Buy another bank tab"] = "Ein weiteres Bankfach kaufen",
  ["Buy another Warband bank tab"] = "Ein weiteres Kriegsmeutenbankfach kaufen",
  ["Show characters you hid"] = "Versteckte Charaktere anzeigen",
  ["Close"] = "Schließen",
  ["Left-click: show this character"] = "Linksklick: diesen Charakter anzeigen",
  ["Right-click: hide"] = "Rechtsklick: verstecken",
  ["Right-click: unhide"] = "Rechtsklick: wieder anzeigen",
  ["Warpee"] = "Warpee",
  ["Click opens the settings"] = "Klick öffnet die Einstellungen",
  ["Drag to move around the minimap"] = "Ziehen verschiebt das Symbol um die Minikarte",
  ["Nothing to sell"] = "Nichts zu verkaufen",
  ["Selling now"] = "Verkauf läuft",
  ["Talk to a merchant first"] = "Nur bei einem Händler möglich",
  ["%d items for %s"] = "Zu verkaufen: %d für %s",
  ["%d items could not be sold and stayed in the bags"] =
    "Nicht verkauft: %d – diese Gegenstände bleiben in den Taschen",
  ["repaired for %s from %s"] = "Reparatur für %s aus %s",
  ["guild funds"] = "der Gildenkasse",
  ["your gold"] = "eigenem Gold",
  ["Inventory"] = "Inventar",
  ["Warband bank"] = "Kriegsmeutenbank",
  ["Total"] = "Gesamt",
  ["%d  (%d bags, %d bank)"] = "%d  (%d Taschen, %d Bank)",
  ["%d  (bank)"] = "%d  (Bank)",
  ["%d  (bags)"] = "%d  (Taschen)",
  ["loaded"] = "geladen",
  ["columns"] = "Plätze pro Reihe",
  ["Favorites"] = "Favoriten",
  ["Favorite slots"] = "Favoritenplätze",
  ["How many slots"] = "Anzahl der Plätze",
  ["A row of slots above the grid, always in sight. Drag an item onto one to keep it a click away, Ctrl + right click clears a slot."] =
    "Eine Reihe Plätze über dem Raster, immer im Blick. Zieht einen Gegenstand darauf, um ihn mit einem Klick zu nutzen; Strg + Rechtsklick leert einen Platz.",
  ["Never more than the grid is wide. Zero keeps the row as wide as the grid."] =
    "Nie mehr, als das Raster breit ist. Bei 0 ist die Reihe so breit wie das Raster.",
  ["As the grid"] = "Wie das Raster",
  ["Drag an item here to keep it one click away"] =
    "Zieht einen Gegenstand hierher, um ihn mit einem Klick zu nutzen",
  ["Ctrl + right click clears the slot"] = "Strg + Rechtsklick leert den Platz",
  ["No gold recorded yet"] = "Noch kein Gold erfasst",
  ["Delete mode"] = "Löschmodus",
  ["Alt-click an item in your bags while this tab is open."] =
    "Alt + Klick auf einen Gegenstand in den Taschen, während diese Seite offen ist.",
}

TABLES.deDE = DE
