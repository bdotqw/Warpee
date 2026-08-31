# Warpee

One window for bags, bank and the Warband bank in World of Warcraft (Midnight, 12.x). No categories, fast, themed.

## Features

- **One window** for bags, bank and the Warband bank, with no category sorting.
- **4 themes** (Midnight, Ember, Obsidian, Ink), recolored on the fly.
- **Snapshots** of other characters' bags and bank, behind a shared switcher popup.
- **Vendor sell** in one click: item level range in the options, 12 items per pass, grey junk, Legion relics, old consumables and raid tier tokens optional; BoE, warbound and socketed gear stay in the bags, and any item can be locked with alt-click.
- **Item counts across every character** inside the Blizzard tooltip (bags / bank / Warband / total).
- **Gold formats** (commas, dots, spaces, K/M) and a gold tooltip listing characters.
- **X/Y bar** for placing windows exactly, plus a position lock.
- **Expressway** font by default; other fonts through LibSharedMedia.

## Install

Copy the `Warpee` folder into `Interface\AddOns\`. The `Media\Expressway.ttf` font ships with it.

## Commands

- `/warpee` or `/wpe` — open the options
- `/wpe bags` — bags, `/wpe bank` — bank, `/wpe warband` — Warband
- `/wpe cols N` — column count in the bags

## Libraries

LibStub, CallbackHandler-1.0, LibSharedMedia-3.0 — in `Libs/`, unmodified.
