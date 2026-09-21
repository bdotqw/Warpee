# Warpee

## 10

ENG

New

- Categories: the bags, the bank and the warband bank lay out in sections — keystone, potions, food, flasks, quest, recipes, gems, toys, battle pets, junk, reagents, containers, trinkets, jewelry, weapons, armor, hearthstone, legacy, housing, consumables, misc, free space and the Other catch-all. Every caption carries its count, sections collapse, Shift-click folds them all at once, the order inside is your choice
- Category editor on its own tab, everything per profile: ready-made ones join by the buttons on top (a deleted one returns as a button), custom ones are built from a search string, Shift-clicking an item pins it to a section
- Items file by drag-and-drop: the section under the cursor highlights and names itself, over Empty the item unpins
- Search speaks kinds: potion, flask, food, toys, housing decor, account-bound (BoA) and an exact item id (id6948)
- Auction house: while it is open, things you cannot list go dim — unsellable reads at a glance
- The coin honestly says "This merchant only repairs" where there is nothing to sell to — instead of a dim coin with no reason
- Two new languages: Korean and Traditional Chinese; Latin-American Spanish split from European — Mexico reads Tropa where Spain reads banda guerrera; the British English client reads English
- Category names translated everywhere, short enough to fit their sections
- Section gap on a slider: untouched, it follows the density

Fixes

- The merchant keeps every alchemist stone from Classic to Midnight: the list audited per expansion
- Hiding reagents no longer hides them in the category view
- A BoE takes its badge off once bound
- Snapshots draw the keystone
- A key in the second binding slot counts: no double auto-binds, and the hints name the right key

RU

Новое

- Категории: сумки, банк и банк отряда раскладываются по секциям — ключ, зелья, еда, настои, задания, рецепты, камни, игрушки, питомцы, хлам, реагенты, контейнеры, аксессуары, украшения, оружие, броня, хартстоун, старое, дом, расходники, разное, свободное место и сборник Other. У каждой число в подписи, секции сворачиваются, Shift-клик сворачивает все сразу, порядок внутри — на выбор
- Редактор категорий на своей вкладке, всё на профиль: готовые добавляются кнопками сверху (удалённая возвращается кнопкой), свои собираются строкой, Shift-клик по предмету сажает его в пины секции
- Вещь раскладывается перетаскиванием: секция под курсором подсвечивается и называется, над Empty вещь открепляется
- Поиск понимает виды: зелья, настои, еду, игрушки, декор для дома, привязку к учётке (BoA) и точный ID предмета (id6948)
- Аукцион: при открытом доме вещи, которые нельзя выставить, тускнеют — сразу видно, что не продаётся
- Монета честно говорит «Этот торговец только чинит», когда продать негде, — вместо тусклой монеты без причины
- Два новых языка: корейский и традиционный китайский; латиноамериканский испанский отделён от европейского — Мексика читает Tropa там, где Испания читает banda guerrera; британский английский клиент читает английский
- Имена категорий переведены везде, короткие — влезают в секции
- Отступ между секциями — слайдером: пока не тронут, следует за плотностью

Исправления

- Торговец держит все алхимические камни от классики до Midnight: список сверен по дополнениям
- Скрытие реагентов больше не прячет их в виде категорий
- BoE после привязки снимает плашку
- Ключ рисуется в снапшотах
- Клавиша во втором слоте бинда считается: никаких двойных автобиндов, подсказки называют правильную клавишу

## 9.1

ENG

New

- Popular now has the Goblin Glider Kit and the current invisibility potion Void-Shrouded Tincture
- Conjured Mana Bun joined the food in Popular
- Badges scale with the cell in every window: tune them in the bags and the bank, the warband bank, the guild bank and the pocket follow; the editor shows the result for each window
- The Recent cells are plain cells again, in the bags and in the pocket: left click, drag, right click, the link and the try-on behave the way they do in the grid
- Ctrl-click a favourites or pocket cell to try the item on, the same way the grid does

Removed

- Plain Royal Roast left Popular, Hearty stays

Fixes

- Short gold format does not round up: "2.5K" is 2500 at the least, and the same for millions
- Lists switch on the first click: opening another list no longer eats the click, and the layering of the window and the list no longer changes
- An open list no longer slips behind the settings window
- Guild bank labels wear the game's yellow again: tab name, daily withdrawal limit, available amount
- Clear the cell refuses mouse buttons: the game eats them over the cells, so the middle mouse button and any keyboard key remain
- Middle-click a favourites or pocket cell to clear it, unless another binding sits on the middle mouse button
- A cell tooltip names the key in full, "ALT + R" and not "A-R", and reads it while the tooltip is showing, so a fresh binding shows at once
- Adding or swapping an item in a favourites or pocket cell redraws the tooltip on the spot, without moving the pointer away
- The pocket's Recent row runs left to right like the bags', the newest at the right
- The tooltip lines for the favourites and pocket cells are translated into all seven languages
- A cell tooltip names one way to clear it: the chosen key when one is bound, the middle click when none is, and asks for a key when the middle mouse button is taken too
- A bank or a snapshot opened in combat no longer throws an error: the layout paints in slices and the tooltip reads are rationed by time
- Esc stops holding the keyboard: the windows go back to the game's own list, so key bindings work with the bags, the bank or the settings open in a fight

RU

Новое

- В Популярном появились глайдер Goblin Glider Kit и актуальное зелье невидимости Void-Shrouded Tincture
- Conjured Mana Bun встал рядом с едой в Популярном
- Значки масштабируются вместе с ячейкой во всех окнах: настроили в сумках, а банк, банк отряда, банк гильдии и карман подхватят; редактор показывает итог для каждого окна
- Ячейки «Недавнего» снова обычные: и в сумках, и в кармане левый клик, перетаскивание, правый клик, ссылка и примерка ведут себя как в сетке
- Ctrl+клик по ячейке избранного или кармана примеряет предмет так же, как в сетке

Убрано

- Обычный Royal Roast убран из Популярного, остался Hearty

Исправления

- Краткий формат золота не округляет вверх: «2,5к» это минимум 2500, и так же с миллионами
- Списки переключаются с первого клика: открытие другого списка больше не съедает клик, и порядок наложения окна и списка больше не меняется
- Открытый список больше не уезжает за окно настроек
- Надписи в банке гильдии снова жёлтые, как в игре: имя вкладки, дневной лимит вывода, доступная сумма
- «Освободить ячейку» не берёт кнопки мыши: игра съедает их над ячейками, остаются средняя кнопка мыши и любая клавиша клавиатуры
- Средний клик по ячейке избранного или кармана освобождает её, если на средней кнопке мыши нет другого назначения
- Подсказка ячейки называет клавишу целиком, «ALT + R», а не «A-R», и читает её в момент показа, так что новое назначение видно сразу
- Новый или заменённый предмет в ячейке избранного или кармана обновляет подсказку на месте, без того чтобы уводить мышь
- «Недавнее» в кармане идёт слева направо, как в сумках, новое справа
- Строки подсказки для ячеек избранного и кармана переведены на все семь языков
- Подсказка ячейки называет один способ освободить её: выбранную клавишу, если она есть, средний клик, если её нет, и просит назначить клавишу, если занята и средняя кнопка мыши
- Банк и сохранённые данные, открытые в бою, больше не выдают ошибку: раскладка рисуется порциями, а чтения подсказки ограничены по времени
- Esc больше не держит клавиатуру: окна снова в родном списке игры, так что назначенные клавиши работают с открытыми сумками, банком или настройками в бою