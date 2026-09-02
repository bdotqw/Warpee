# Warpee

## 1.3.0

- No more blocked action errors while a window is open in combat: Esc closes the windows through the game's own list instead of a keyboard hook of ours
- Esc now closes every open Warpee window at once, the way the rest of the interface behaves
- Favourites keep one slot per item: pinning something that already sits in the row moves it there instead of adding a copy, and rows saved with duplicates lose them
- An item can no longer be pulled out of a favourite slot with the left button; right click uses it as before

## 1.2.1

- Slot words in the search now work on snapshots as well: `hands`, `ring` or `2h` find items in another character's bags and in a recorded bank
- Searching a snapshot by plain text also looks at the item type and subtype, the way it already does in your own bags

## 1.2.0

- Spanish interface text, and Spanish words in the search; Latin American clients use it too
- Coin letters now match the ones the game itself uses in each language
- The favourites row redraws at once when a marker or slot setting changes, instead of waiting for a reload

## 1.1.0

- French interface text, and French words in the search
- Reagent border is a setting now: turn it off and reagents take the quality border instead
- Marker checkboxes reordered on the Items page
- Removed the `/warpee cols` command, the column count stays in the settings

## 1.0.0

First release.

- Separate bag, bank and Warband bank windows with a shared search
- Snapshots of every character's bags, bank and gold
- Guild bank skinned to match, without recording its contents
- Item level, stack counts, quality borders, quest and junk markers
- Favourite reagents row, vendor selling, repairs and token tracking
- Fourteen colour themes, six bundled fonts, per-language glyph checks
- English, German and Russian
