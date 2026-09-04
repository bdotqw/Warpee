# Warpee

Bag and bank windows for World of Warcraft (Midnight, 12.x). No categories, fast, themed.

## Features

- **Bags in one window**, the character bank and the Warband bank as tabs in a second one, with no category sorting.
- **11 themes**, recolored on the fly: mostly dark palettes, a Class theme that follows your class color, and two Blizzard skins built from the game's own panels.
- **Guild bank skin** matching the rest of the addon; its contents are not saved.
- **Snapshots** of other characters' bags and bank, behind a shared switcher popup.
- **Favorites row**: drag an item in to keep it one click away, reorder the row by dragging, and read the total you carry on the square, every stack in every bag added up.
- **Marks on the slots**, placed where you want them: item level, stack count, binding (BoE, WuE, BoA), gear set, a coin on junk and a padlock on locked items, each with its own corner, offset, size and growth direction, plus a countdown on anything on cooldown.
- **Vendor sell** in one click: item level range in the options, grey junk, Legion relics, old consumables and raid tier tokens optional; BoE, warbound and socketed gear stay in the bags, and any item can be locked with alt-click.
- **Item counts across every character** inside the Blizzard tooltip (bags / bank / Warband / total).
- **Search filters** by quality, slot, item type, expansion and item level, in English, Russian, German, French or Spanish.
- **Gold formats** (commas, dots, spaces, K/M) and a gold tooltip listing characters.
- **X/Y bar** for placing windows exactly, plus a position lock.
- **English, Russian, German, French and Spanish** interface text.
- **Six bundled fonts**, two of them bold; anything registered with LibSharedMedia also shows up.

## Install

Copy the `Warpee` folder into `Interface\AddOns\`. Fonts ship in `Media\Fonts\`.

## Commands

- `/warpee` or `/wpe` opens the options

Bags open on the game's own bag key or the minimap button; the bank and the
Warband bank open from the header of the bag window, or at a banker.

## Libraries

LibStub, CallbackHandler-1.0 and LibSharedMedia-3.0 live in `Libs/`, unmodified.

## License

All rights reserved, in `LICENSE`. The bundled libraries and fonts keep their own licenses.

## Fonts

Manrope Bold, Rubik Bold, Oswald, Russo One, Archivo and Fira Sans Condensed are licensed under the SIL Open Font License; the copyright and license notices are embedded in each font file.
