# The Cookbook

In-game recipe browser for **World of Warcraft: Forever**. Every profession recipe, its skill levels, reagents, source, tools, and crafting math, in one window.

## Install

Copy the `Cookbook` folder to:

```
World of Warcraft\_forever_\Interface\AddOns\Cookbook
```

## Use

| Command | What it does |
|---|---|
| `/cookbook` or `/cb` | Toggle the window |
| `/cookbook alchemy` | Open a profession (prefixes work: `/cb lw`, no, 3+ letters: `/cb lea`) |
| `/cookbook thorium` | Search the current profession |
| `/cookbook reset` | Reset window position |

Also available from the addon compartment (the addons button by the minimap).

- **Tabs** on the left, one per profession.
- **List** is sorted by skill. Columns are *Learn / Yellow / Green / Gray*. Names are colored by difficulty at your skill.
- **Search** matches recipe names, products, categories, enchants **and reagents** (search "thorium bar" to see everything that uses it).
- **Skill box** uses your real skill, or type any number to preview another level.
- **Detail pane**: what it makes, skill thresholds, skill-up chance at your level, source (recipe item or trainer), required tools, reagents with have/need from bags and bank.
- **Calculator**: craft quantity scales reagents, shows how many you can craft now and the vendor value. "Level from X to Y" gives the expected number of crafts, and "Use as quantity" turns that into a shopping list.
- Shift-click a recipe, the product icon, a reagent, or a recipe item to link it in chat.

## The math

Classic-style skill-ups: orange always gives a point, gray never does. Between yellow and gray the chance is

```
chance = (gray - skill) / (gray - yellow)
```

Green is the midpoint between yellow and gray. Expected crafts from A to B is the sum of `1 / chance` for each skill level on the way.

## Data and its limits

`Data/Recipes.lua` is extracted from the WoW Forever client files (build 1.60.1.70790): ~2,490 recipes and ~4,150 items.

- **Learn levels** come from, in priority order:
  1. a trainer window you opened in game (read automatically, saved account-wide),
  2. the recipe item's required skill from the client files (what the game checks),
  3. [Wowhead's Forever database](https://www.wowhead.com/forever) (`learn` field, fetched 2026-11-05), which covers trainer recipes the client files don't have.

  About 2,375 of ~2,490 recipes have a learn level. The rest show `?` until you visit their trainer. Wowhead disagrees with the client on ~130 recipe items, usually by +25. The client value is used there.
- Faction-only recipes are not marked yet.
- Interface version is set to `16001` (from client 1.60.1). If the game says the addon is out of date, tick "Load out of date AddOns".
