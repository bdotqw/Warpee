# Warpee

## 1.5.0

New

- Blizzard Flat, a second native skin built from the game's own flat panels: a frame edge, a plate body and a title strip across the header of the bags, the bank, the warband bank and the bag picker
- Every badge now picks how its text grows, left to right, right to left or from the center, so a one digit stack and a four digit stack both land where the preview showed them
- A plain left drag reorders the favorites row, and right click still uses the item

Themes

- The theme list keeps only the palettes that really change the window. Ember, Obsidian, Gunmetal and Moss are gone, and if you had one of them selected you will start on Midnight
- Midnight now wears the colors of the expansion, a void dark base under Sunwell gold, with borders and a hover you can actually see
- Abyss goes deeper teal with a coral accent, Nightbloom gets a richer violet and a cool counterpoint, Graphite reads as one true grey with no leftover tints, Nord sits deeper so its text carries, and Blood, Forest, Void and Blizzard had their hover, their slot separation and their warband color fixed
- The warbound label follows the theme's own warband color instead of one fixed blue
- The guild bank wears the border of the skin you picked

Fixes

- Taint: writing the game's bank panel broke right click use on every container slot, the game rebuilt its own bag frames on each press of the bag key, favorites slots could be created during a fight, and a vendor run could keep selling after the merchant window closed. All four are gone
- Gear that is warbound until equipped is no longer labeled BoE in bank snapshots, and an item bound to your character drops the flag
- A rerolled keystone repaints its level right away
- The binding and gear set badges take a new font without a reload
- Dropdowns in the settings show their tooltip when you hover the dropdown itself
- The hints on a favorites slot stay together with the rest of the addon's tooltip lines
