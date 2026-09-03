local addonName, ns = ...

local WORDS = {
  ["schlecht"] = "poor", ["schund"] = "junk", ["schrott"] = "junk", ["grau"] = "gray",
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
  ["schlüsselstein"] = "keystone", ["mythisch"] = "mythic", ["marke"] = "token",
  ["geschützt"] = "locked", ["gesperrt"] = "locked", ["kriegsmeute"] = "warband",
  ["seelengebunden"] = "soulbound", ["anlegen"] = "boe",
  ["aktuell"] = "current", ["alt"] = "legacy",
}

local STRINGS = {
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
  ["Badges"] = "Abzeichen",
  ["Item level"] = "Gegenstandsstufe",
  ["Stack count"] = "Stapelanzahl",
  ["Binding"] = "Bindung",
  ["Gear set"] = "Ausrüstungsset",
  ["Letters"] = "Buchstaben",
  ["How many letters of the set name to show."] =
    "Wie viele Buchstaben des Setnamens gezeigt werden.",
  ["Vendor lock"] = "Verkaufsschutz",
  ["Icon scale"] = "Abzeichengröße",
  ["Which corner of the slot the badge is pinned to."] =
    "An welcher Ecke des Platzes das Abzeichen hängt.",
  ["Drag a badge around the cell, or click where you want it. Click a name to show and pick that badge, right-click a name to hide it."] =
    "Zieht ein Abzeichen in der Zelle umher oder klickt dorthin, wo es stehen soll. Ein Linksklick auf einen Namen zeigt und wählt das Abzeichen, ein Rechtsklick auf den Namen blendet es aus.",
  ["Show only the selected badge"] = "Nur das gewählte Abzeichen zeigen",
  ["The item level of gear, and the level of a keystone."] =
    "Die Gegenstandsstufe von Ausrüstung und die Stufe eines Schlüsselsteins.",
  ["How many items the stack holds."] = "Wie viele Gegenstände im Stapel liegen.",
  ["BoE while the item is still unbound, WuE for warbound until equipped, BoA for account bound."] =
    "BoE solange der Gegenstand noch nicht gebunden ist, WuE für kriegsmeutengebunden bis angelegt, BoA für accountgebunden.",
  ["The name of the equipment set the item belongs to, cut to a few letters."] =
    "Der Name des Ausrüstungssets, zu dem der Gegenstand gehört, auf wenige Buchstaben gekürzt.",
  ["A coin on poor quality items, the gray junk a merchant buys."] =
    "Eine Münze auf Gegenständen schlechter Qualität, dem grauen Schund, den ein Händler kauft.",
  ["A padlock on the items you locked with Alt-click, which the vendor never sells."] =
    "Ein Schloss auf den Gegenständen, die Ihr mit Alt + Linksklick geschützt habt, der Händler verkauft sie nie.",
  ["In the cell above, hide every badge except the selected one."] =
    "In der Zelle oben alle Abzeichen außer dem gewählten ausblenden.",
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
  ["English"] = "Englisch",
  ["German"] = "Deutsch",
  ["Spanish"] = "Spanisch",
  ["French"] = "Französisch",
  ["Russian"] = "Russisch",
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
  ["Freeze the windows in place. Unlocked, each shows X/Y fields along its bottom edge. Type a value, or nudge with the arrows (Shift = 10)."] =
    "Hält die Fenster an ihrem Platz. Ohne Fixierung zeigt jedes Fenster am unteren Rand Felder für X und Y: Wert eintippen oder mit den Pfeilen ändern (Shift = 10er-Schritte).",
  ["The windows stay movable by dragging, but the X/Y fields are not drawn."] =
    "Die Fenster lassen sich weiter mit der Maus verschieben, die Felder für X und Y werden aber nicht angezeigt.",
  ["Fill bar in the bags header showing how full they are."] =
    "Leiste in der Kopfzeile der Taschen, die zeigt, wie voll sie sind.",
  ["Takes the Warpee button off the minimap."] = "Entfernt den Warpee-Knopf von der Minikarte.",
  ["Grouping for printed amounts. Short abbreviates to K and M."] =
    "Wie die Ziffern in Beträgen gruppiert werden. »Kurz« kürzt Tausender zu k und Millionen zu Mio.",
  ["Show gold only, hide silver and copper."] = "Nur Gold anzeigen, Silber und Kupfer ausblenden.",
  ["On = g/s/c letters. Off = coin icons."] = "Ein: Buchstaben G/S/K. Aus: Münzsymbole.",
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
  ["Reagents on top"] = "Reagenzien oben",
  ["Reverse slot order"] = "Taschenplätze umkehren",
  ["Fill grid upwards"] = "Raster von unten füllen",
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
  ["Draw the reagent bag above the main bags instead of below them."] =
    "Zeichnet die Reagenzientasche über den Haupttaschen statt darunter.",
  ["The bag slots run backwards, so the last slot of the last bag takes the first cell. Nothing moves inside your bags, only the order the slots are drawn in."] =
    "Die Taschenplätze laufen rückwärts: der letzte Platz der letzten Tasche steht an erster Stelle im Raster. In den Taschen selbst wird nichts verschoben, nur die Zeichenreihenfolge ändert sich.",
  ["The rows of cells stack from the bottom edge up, so the part-filled last row sits at the top."] =
    "Die Reihen des Rasters werden von der Unterkante nach oben gestapelt. Die letzte, unvollständige Reihe steht dann oben.",
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
  ["Delete saved bags and bank of %s?"] = "Gespeicherte Taschen und Bank von %s löschen?",
  ["Quality border"] = "Qualitätsrahmen",
  ["Quest marker"] = "Questmarkierung",
  ["New item glow"] = "Leuchten neuer Gegenstände",
  ["Junk coin"] = "Münze auf Schund",
  ["Reagent border"] = "Reagenzien-Rahmen",
  ["Border thickness"] = "Rahmenstärke",
  ["Item level by quality"] = "Gegenstandsstufe nach Qualität",
  ["Corner"] = "Ecke",
  ["Size"] = "Größe",
  ["X offset"] = "X-Versatz",
  ["Y offset"] = "Y-Versatz",
  ["Draw a rarity-colored border around every item, white for common and gray for junk."] =
    "Zeichnet einen Rahmen in der Qualitätsfarbe um jeden Gegenstand: weiß bei gewöhnlichen, grau bei Schund.",
  ["Blizzard quest art: a mark for unaccepted quests, a border for quest items."] =
    "Blizzards Questgrafik: ein Ausrufezeichen für nicht angenommene Quests, ein Rahmen für Questgegenstände.",
  ["Quality-colored glow on items the game still counts as new."] =
    "Leuchten in der Qualitätsfarbe auf Gegenständen, die das Spiel noch als neu zählt.",
  ["Tint slots in the reagent bag. Turn it off and reagents take the quality border instead."] =
    "Plätze der Reagenzientasche einfärben. Aus, und Reagenzien bekommen stattdessen den Qualitätsrahmen.",
  ["Thickness of the quality border."] = "Stärke des Qualitätsrahmens.",
  ["Tint the item level number with the item's rarity color."] =
    "Färbt die Gegenstandsstufe in der Qualitätsfarbe des Gegenstands.",
  ["Alt-click an item in the bags or the bank to lock it: a padlock appears, and the item can no longer be sold, neither automatically nor by right-clicking at a merchant. Alt-click again, or the cross here, to unlock."] =
    "Alt + Linksklick auf einen Gegenstand in den Taschen oder der Bank schützt ihn: ein Schloss erscheint, und der Gegenstand lässt sich nicht mehr verkaufen, weder automatisch noch mit einem Rechtsklick beim Händler. Ein erneuter Alt + Linksklick oder das Kreuz in dieser Liste hebt den Schutz auf.",
  ["Alt-click to lock it from the vendor"] = "Alt + Linksklick, um ihn vor dem Verkauf zu schützen",
  ["Locked from the vendor. Alt-click to unlock"] =
    "Vor dem Verkauf geschützt. Alt + Linksklick hebt den Schutz auf",
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
  ["Snapshots"] = "Gespeicherte Daten",
  ["Copies of what you carry, so another character's bags and bank open from your own window."] =
    "Kopien Eures Inventars, damit Taschen und Bank eines anderen Charakters in Eurem eigenen Fenster aufgehen.",
  ["Remember bags"] = "Taschen speichern",
  ["Save this character's bags and gold whenever the bag window opens. Off = other characters stop seeing them."] =
    "Speichert Taschen und Gold dieses Charakters, sobald das Taschenfenster geöffnet wird. Aus: andere Charaktere sehen sie nicht mehr.",
  ["Remember bank"] = "Bank speichern",
  ["Save the character bank while you stand at a banker."] =
    "Speichert die Charakterbank, während Ihr beim Bankier steht.",
  ["Remember Warband bank"] = "Kriegsmeutenbank speichern",
  ["Save the shared Warband bank while you stand at a banker."] =
    "Speichert die gemeinsame Kriegsmeutenbank, während Ihr beim Bankier steht.",
  ["Delete the saved Warband bank?"] = "Gespeicherte Kriegsmeutenbank löschen?",
  ["Account"] = "Konto",
  ["Nothing saved for other characters yet"] = "Für andere Charaktere ist noch nichts gespeichert",
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
  ["Skip warbound gear, since an alt can still use it."] =
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
    "Alt + Linksklick auf einen Gegenstand in den Taschen, während diese Seite offen ist.",
}

ns.AddLocale("deDE", "German", {
  coin = { g = "G", s = "S", c = "K" },
  short = { dec = ",", units = { { 1e12, " Bio." }, { 1e9, " Mrd." }, { 1e6, " Mio." }, { 1e3, "k" } } },
  words = WORDS,
  strings = STRINGS,
})
