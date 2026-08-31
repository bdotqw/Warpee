local addonName, ns = ...

local L = setmetatable({}, { __index = function(_, k) return k end })
ns.L = L

ns.LOCALES = { "auto", "enUS", "ruRU" }
ns.LOCALE_LABELS = { auto = "Game language", enUS = "English", ruRU = "Русский" }

function ns.LocalePick()
  local pick = WarpeeDB and WarpeeDB.locale
  if pick == nil or pick == "auto" then return GetLocale() end
  return pick
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
  ["Bank and Warband grid"] = "Сетка банка и общего банка",
  ["Item level number"] = "Число уровня предмета",
  ["Stack count number"] = "Число в стаке",
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
  ["Capacity bar"] = "Полоса заполнения",
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
  ["Merge reagents"] = "Слить реагенты",
  ["Slot background"] = "Фон ячейки",
  ["Spacing opacity"] = "Плотность подложки",
  ["Bank slots per row"] = "Ячеек в ряду в банке",
  ["Warband slots per row"] = "Ячеек в ряду в общем банке",
  ["Size of one slot in the bags."] = "Размер одной ячейки в сумках.",
  ["How wide the bag window grows."] = "Насколько широким становится окно сумок.",
  ["Gap between slots, in every grid."] = "Промежуток между ячейками во всех сетках.",
  ["1.00 fills the slot. Less shrinks the icon, more crops it."] =
    "1.00 — иконка заполняет ячейку. Меньше — отодвигает от рамки, больше — обрезает.",
  ["Lay the reagent bag out with the main bags, without its caption."] =
    "Разложить реагентную сумку вместе с основными, без её заголовка.",
  ["What sits behind every icon. Transparent shows the plate through the slot, Highlight lifts it out, Solid closes it off, Stone swaps the fill for a texture tinted to the theme."] =
    "Что находится за каждой иконкой. Прозрачный показывает подложку сквозь ячейку, Подсветка приподнимает её, Плотный закрывает целиком, Камень заменяет заливку текстурой в цвете темы.",
  ["The plate behind the slots, seen in the gaps. At Spacing 0 there are none."] =
    "Подложка за ячейками, видимая в промежутках. При отступе 0 промежутков нет.",
  ["The bank keeps its own width and icon size, apart from the bags."] =
    "У банка своя ширина и свой размер иконки, независимо от сумок.",
  ["One icon size for both bank tabs."] = "Один размер иконки для обеих вкладок банка.",
  ["Transparent"] = "Прозрачный",
  ["Highlight"] = "Подсветка",
  ["Solid"] = "Плотный",
  ["Stone"] = "Камень",
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
  ["Include Warband"] = "Учитывать общий банк",
  ["Adds an Inventory block to item tooltips: how many each character carries."] =
    "Добавляет в подсказки предметов блок «Инвентарь»: сколько несёт каждый персонаж.",
  ["Count each character's bank too. Off = bags only."] =
    "Считать и банк каждого персонажа. Выкл — только сумки.",
  ["Count the shared Warband bank on its own line."] =
    "Считать общий банк отряда отдельной строкой.",
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
  ["Guild first"] = "Сначала гильдия",
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
  ["Language changes after a UI reload."] = "Язык сменится после перезагрузки интерфейса.",
}

do
  local t = (ns.LocalePick() == "ruRU") and RU or nil
  if t then for k, v in pairs(t) do L[k] = v end end
end
