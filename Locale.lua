local addonName, ns = ...

local TABLES = {}

local L = setmetatable({}, { __index = function(_, k)
  local t = TABLES[ns.LocalePick()]
  local v = t and t[k]
  return v or k
end })
ns.L = L

ns.LOCALES = { "enUS", "ruRU" }
ns.LOCALE_LABELS = { enUS = "English", ruRU = "Русский" }

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

function ns.LocalePick()
  local pick = WarpeeDB and WarpeeDB.locale
  if pick == "enUS" or pick == "ruRU" then return pick end
  return (GetLocale() == "ruRU") and "ruRU" or "enUS"
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
  ["Item level number"] = "Число уровня предмета",
  ["Stack count number"] = "Число стаков",
  ["Locked items"] = "Защищённые предметы",
  ["Item tooltips"] = "Подсказки предметов",
  ["Open bags with"] = "Открывать сумки вместе с",
  ["Runs on its own"] = "Работает само",
  ["The coin button"] = "Кнопка монеты",
  ["Token expansions"] = "Дополнения для токенов",
  ["Never sell"] = "Никогда не продавать",
  ["Theme"] = "Тема",
  ["Font"] = "Шрифт",
  ["Language"] = "Язык",
  ["Lock windows"] = "Закрепить окна",
  ["Capacity bar"] = "Полоса заполненности",
  ["Hide minimap icon"] = "Скрыть иконку у миникарты",
  ["Gold format"] = "Формат чисел",
  ["Gold only"] = "Только золото",
  ["Coin letters"] = "Буквы вместо монет",
  ["Clear on close"] = "Очищать при закрытии",
  ["Bags and bank together"] = "Сумки и банк вместе",
  ["Color scheme for the whole addon."] = "Цветовая схема всего аддона.",
  ["Used for every label Warpee draws. Other addons can add to this list."] =
    "Используется для всех надписей Warpee. Другие аддоны могут добавлять шрифты в этот список.",
  ["Language for the addon's own text. Item names always come from the game."] =
    "Язык текста самого аддона. Названия предметов всегда берутся из игры.",
  ["Freeze the windows in place. Unlocked, each shows X/Y fields at its top-left — type a value or nudge with the arrows (Shift = 10)."] =
    "Закрепляет окна на месте. Пока не закреплены, у каждого в левом верхнем углу поля X/Y: введи значение или подтолкни стрелками (Shift = 10).",
  ["Fill bar in the bags header showing how full they are."] =
    "Полоса в шапке сумок, показывающая, насколько они заполнены.",
  ["Takes the Warpee button off the minimap."] = "Убирает кнопку Warpee с миникарты.",
  ["Grouping for printed amounts. Short abbreviates to K and M."] =
    "Разделение разрядов в суммах. Короткий вид сокращает до K и M.",
  ["Show gold only, hide silver and copper."] = "Показывать только золото, скрыть серебро и медь.",
  ["On = g/s/c letters. Off = coin icons."] = "Вкл — буквы з/с/м. Выкл — иконки монет.",
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
  ["Icon zoom"] = "Приближение иконки",
  ["Merge reagents"] = "Объединить реагенты",
  ["Slot background"] = "Фон ячейки",
  ["Spacing opacity"] = "Плотность подложки",
  ["Bank slots per row"] = "Ячеек в ряду в банке",
  ["Warband slots per row"] = "Ячеек в ряду в банке отряда",
  ["Size of one slot in the bags."] = "Размер одной ячейки в сумках.",
  ["How wide the bag window grows."] = "Насколько широким становится окно сумок.",
  ["Gap between slots, in every grid."] = "Промежуток между ячейками во всех сетках.",
  ["1.00 fills the slot. Less shrinks the icon, more crops it."] =
    "1.00 — иконка заполняет ячейку. Меньше — отодвигает от рамки, больше — обрезает.",
  ["Lay the reagent bag out with the main bags, without its caption."] =
    "Разложить реагентную сумку вместе с основными, без её заголовка.",
  ["What sits behind every icon. Transparent shows the plate through the slot, Highlight lifts it out, Solid closes it off."] =
    "Что находится за каждой иконкой. Прозрачный показывает подложку сквозь ячейку, Подсветка приподнимает её, Плотный закрывает целиком.",
  ["The plate behind the slots, seen in the gaps. At Spacing 0 there are none."] =
    "Подложка за ячейками, видимая в промежутках. При отступе 0 промежутков нет.",
  ["The bank keeps its own width and icon size, apart from the bags."] =
    "У банка своя ширина и свой размер иконки, независимо от сумок.",
  ["One icon size for both bank tabs."] = "Один размер иконки для обеих вкладок банка.",
  ["Transparent"] = "Прозрачный",
  ["Highlight"] = "Подсветка",
  ["Solid"] = "Плотный",
  ["Top left"] = "Слева сверху",
  ["Top right"] = "Справа сверху",
  ["Bottom left"] = "Слева снизу",
  ["Bottom right"] = "Справа снизу",
  ["Game language"] = "Язык игры",
  ["Quality border"] = "Рамка качества",
  ["Quest marker"] = "Метка задания",
  ["New item glow"] = "Свечение новых",
  ["Junk coin"] = "Монета на хламе",
  ["Border thickness"] = "Толщина рамки",
  ["Color by quality"] = "Цвет по качеству",
  ["Corner"] = "Угол",
  ["Size"] = "Размер",
  ["X offset"] = "Сдвиг по X",
  ["Y offset"] = "Сдвиг по Y",
  ["Draw a rarity-colored border around uncommon+ items."] =
    "Рисовать рамку цвета редкости вокруг предметов необычного качества и выше.",
  ["Blizzard quest art: a mark for unaccepted quests, a border for quest items."] =
    "Штатная графика заданий: восклицательный знак для непринятых, рамка для предметов заданий.",
  ["Quality-colored glow on items the game still counts as new."] =
    "Свечение цвета качества на предметах, которые игра считает новыми.",
  ["Gold coin marker on poor-quality (grey) items."] = "Метка-монета на предметах плохого качества.",
  ["Thickness of the quality border."] = "Толщина рамки качества.",
  ["Tint the number with the item's rarity color."] = "Красить число в цвет редкости предмета.",
  ["Which corner of the slot the number sits in."] = "В каком углу ячейки стоит число.",
  ["Which corner of the slot the stack size sits in."] = "В каком углу ячейки стоит размер стака.",
  ["Alt-click an item in the bags or the bank to lock it: a padlock appears and the vendor never sells it. Alt-click again, or the cross here, to unlock."] =
    "Alt-клик по предмету в сумках или банке защищает его: появляется замок, и торговец никогда его не продаст. Alt-клик снова или крестик здесь — снять защиту.",
  ["Count across characters"] = "Считать по всем персонажам",
  ["Include bank"] = "Учитывать банк",
  ["Include Warband"] = "Учитывать банк отряда",
  ["Adds an Inventory block to item tooltips: how many each character carries."] =
    "Добавляет в подсказки предметов блок «Инвентарь»: сколько несёт каждый персонаж.",
  ["Count each character's bank too. Off = bags only."] =
    "Считать и банк каждого персонажа. Выкл — только сумки.",
  ["Count the shared Warband bank on its own line."] =
    "Считать банк отряда отдельной строкой.",
  ["Unchecked characters stay saved but are hidden from the character list."] =
    "Снятые персонажи остаются сохранёнными, но скрыты из списка.",
  ["Sell junk"] = "Продавать хлам",
  ["Repair"] = "Ремонт",
  ["Item level from"] = "Уровень предмета от",
  ["Item level under"] = "Уровень предмета до",
  ["Legion relics"] = "Реликвии Легиона",
  ["Old consumables"] = "Старые расходники",
  ["Tier tokens"] = "Тир-токены",
  ["Sell all of this automatically"] = "Продавать всё это автоматически",
  ["Keep BoE"] = "Оставлять непривязанное",
  ["Keep warbound"] = "Оставлять вещи отряда",
  ["Keep gems and enchants"] = "Оставлять с камнями и чарами",
  ["Your gold"] = "Своё золото",
  ["Guild or yours"] = "Гильдия/своё",
  ["These start when a merchant window opens, with no click from you."] =
    "Это запускается при открытии окна торговца, без нажатия с твоей стороны.",
  ["Everything below is sold by the coin in the bags header, only when you press it."] =
    "Всё, что ниже, продаётся монетой в шапке сумок и только когда ты её нажмёшь.",
  ["Sell every grey item, whatever its item level."] =
    "Продавать любой серый предмет, независимо от уровня.",
  ["Repair at merchants who offer it. Others are left alone, with no message."] =
    "Ремонт у торговцев, которые его предлагают. Остальных не трогаем и ничего не пишем.",
  ["Where the repair money comes from. The guild bank is used only if your withdraw limit covers the whole bill."] =
    "Откуда берутся деньги на ремонт. Банк гильдии используется только если твой лимит вывода покрывает весь счёт.",
  ["Gear at or above this item level is sold."] =
    "Продаётся снаряжение этого уровня предмета и выше.",
  ["Gear under this item level is sold. Zero keeps every piece."] =
    "Продаётся снаряжение ниже этого уровня. Ноль оставляет всё.",
  ["Sell Legion artifact relics. Item level ignored."] =
    "Продавать реликвии артефактов Легиона. Уровень предмета не учитывается.",
  ["Sell potions, flasks, food and bandages older than the previous expansion."] =
    "Продавать зелья, настои, еду и бинты старше предыдущего дополнения.",
  ["Sell raid armor tokens, item level ignored. Only from the expansions ticked below."] =
    "Продавать рейдовые токены брони, уровень предмета не учитывается. Только из отмеченных ниже дополнений.",
  ["Sell the list above at every merchant, without pressing the coin."] =
    "Продавать список выше у каждого торговца, без нажатия монеты.",
  ["Sell tier tokens from this expansion."] = "Продавать тир-токены из этого дополнения.",
  ["Which expansions tokens may be sold from. The four newest are kept by default. Expansions that never had tokens are not listed."] =
    "Из каких дополнений можно продавать токены. Четыре последних по умолчанию сохраняются. Дополнения, где токенов не было, в списке не показаны.",
  ["Skip gear that is not bound yet, so it can go to the auction house."] =
    "Пропускать ещё не привязанное снаряжение, чтобы его можно было продать на аукционе.",
  ["Skip warbound gear — an alt can still use it."] =
    "Пропускать вещи, привязанные к отряду — их ещё может надеть другой персонаж.",
  ["Skip any piece with a gem socketed or an enchant applied."] =
    "Пропускать всё, куда вставлен камень или наложены чары.",
  ["Commas (5,000,000)"] = "Запятые (5,000,000)",
  ["Dots (5.000.000)"] = "Точки (5.000.000)",
  ["Spaces (5 000 000)"] = "Пробелы (5 000 000)",
  ["Short (5M, 284.4K)"] = "Кратко (5M, 284.4K)",
  ["%d of %d"] = "%d из %d",
  ["1 item"] = "1 предмет",
  ["%d items"] = "%d предметов",
  ["%d and %d wide"] = "%d и %d в ряду",
  ["Sort / clean up bags"] = "Сортировать сумки",
  ["Sort / clean up"] = "Сортировать",
  ["Settings"] = "Настройки",
  ["Bags"] = "Сумки",
  ["Bank / Warband"] = "Банк и банк отряда",
  ["Sell low gear"] = "Продать старое снаряжение",
  ["Bags of another character"] = "Сумки других персонажей",
  ["REAGENTS"] = "РЕАГЕНТЫ",
  ["BAGS"] = "СУМКИ",
  ["WARBAND BANK"] = "БАНК ОТРЯДА",
  ["Warband"] = "Отряд",
  ["Buy tab"] = "Купить",
  ["Buy tab · %s"] = "Купить · %s",
  ["Cost: %s"] = "Цена: %s",
  ["Hidden"] = "Скрытые",
  ["Visit a banker to record this bank"] = "Зайди к банкиру, чтобы записать этот банк",
  ["Browse another character's bank"] = "Посмотреть банк другого персонажа",
  ["Put your gold into the Warband bank"] = "Положить золото в банк отряда",
  ["Take gold out of the Warband bank"] = "Забрать золото из банка отряда",
  ["Buy another bank tab"] = "Купить ещё одну ячейку банка",
  ["Buy another Warband bank tab"] = "Купить ещё одну ячейку банка отряда",
  ["Show characters you hid"] = "Показать скрытых персонажей",
  ["Close"] = "Закрыть",
  ["Left-click: show this character"] = "ЛКМ — показать этого персонажа",
  ["Right-click: hide"] = "ПКМ — скрыть",
  ["Right-click: unhide"] = "ПКМ — вернуть",
  ["Warpee"] = "Warpee",
  ["Click opens the settings"] = "Клик открывает настройки",
  ["Drag to move around the minimap"] = "Тащи, чтобы двигать вокруг миникарты",
  ["Nothing to sell"] = "Продавать нечего",
  ["Selling now"] = "Продаю",
  ["Talk to a merchant first"] = "Сначала подойди к торговцу",
  ["%d items for %s"] = "%d предметов за %s",
  ["%d items refused to sell, left in the bags"] =
    "%d предметов отказались продаваться и остались в сумках",
  ["repaired for %s from %s"] = "ремонт за %s, оплата: %s",
  ["guild funds"] = "касса гильдии",
  ["your gold"] = "своё золото",
  ["Inventory"] = "Инвентарь",
  ["Warband bank"] = "Банк отряда",
  ["Total"] = "Всего",
  ["%d  (%d bags, %d bank)"] = "%d  (%d в сумках, %d в банке)",
  ["%d  (bank)"] = "%d  (в банке)",
  ["%d  (bags)"] = "%d  (в сумках)",
  ["loaded"] = "загружен",
  ["columns"] = "ячеек в ряду",
}

TABLES.ruRU = RU
