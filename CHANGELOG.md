# Warpee

## 2.0.0

New

- The Pocket, a small window of bookmark cells beside the bags. Its own key opens it without the bags, F7 by default, and the binding is captured right in the settings. Drag an item onto a cell to pin it, or type an id into the box behind the plus in the header. A pin knows where its copy is, a blue edge while you wear it and an amber one while it sits in no bag you own, and gear carries its item level, crafted things their tier, set pieces their badge. A click on a pin finishes an enchant or a gem on the cursor, alt click sets the do not sell lock, right click uses the item, shift click links it
- Recent, a row above the favorites that holds whatever came into your bags this session. The number on a cell counts only what arrived and falls as you use the delivery up. Mail and auction wins count, gray junk never takes a cell, two identical rings take two, and a word beside the row label empties it by hand
- Favorites pin the exact copy. An upgrade, a gem or an enchant moves the pin onto the new link, a stale pin adopts the copy you are wearing, and the twin of a ring pinned in the bank no longer steals its place. The worn edge, the item level, the craft tier and the gear set badge follow the favorites too
- The bank and the warband bank switch on the game's own tab strip, carried into our header, and the window opens on whichever tab the game has active
- Six pages in the settings, General, Grid, Items, Pocket, Vendor and Characters. The rows moved under Grid, the pocket has a page of its own with its own slot size, and the descriptions that had drifted behind the code were rewritten
- The auto open boxes now decide. Mail, a vendor, the auction house and the other windows bring up the bags only when their box is ticked, and whenever a window opens the bags for you the pocket steps aside until you call it back
- Escape closes every Warpee window at once, and the transmogrifier pushes the bags and the pocket off the screen
- Shift click an item to link it into chat, or drop its name straight into the search box
- Hide reagents, a setting on the grid page: the reagent bag is left out of the window, its slots keep counting in the header, and reagents still go into it
- The bag header names its slot counter again, and the bank windows name theirs the same way
- One on the zoom slider now draws about eight percent bigger on a side than it did, decorations zoom with the icon, and a decorated item drops the quality border that fought its artwork
- The bag header reads sort, sell, pocket, bank, bags, settings, close from left to right, and the buttons close their gaps when a neighbour hides

Fixes

- The bags stay quiet while cooldowns tick, the counting digit was one text rewrite a second on every cell and is gone under ten seconds, and the global cooldown got its swipe back
- A gear swap repaints the window once instead of firing an event per slot
- The bank window no longer drags you out of another character's snapshot on exit, and the banker closing while you browse one leaves it open
- A cooldown that starts while the bags are closed shows up when you open them
- The do not sell lock reaches the recent rows, and taking an item off the list in the settings clears its lock at once
- On a search miss the quality ring greys out with the icon instead of staying the one colored thing on the cell
- The vendor pump stops in combat and never sells off a held cursor
- An item taken off the character, a gear swap for instance, no longer walks into the recent row
- A stack that comes out of a container you just opened is counted on a favorite right away
- The Russian tooltip on the clean up button read as scrapping rather than sorting, and the Spanish one carried an article the game does not use
