# OneForAll NoSpoilers

A companion addon for [OneForAll](https://www.curseforge.com/wow/addons/oneforall-forever), the WoW Forever addon by Smoergi. It hides OneForAll's content until your character has discovered it, so a zone you haven't visited looks blank and the addon fills in as you explore.

OneForAll itself is left completely unchanged and keeps updating as normal.

> **Unofficial.** This addon is not made or endorsed by OneForAll's author. If something in OneForAll looks wrong, turn this addon off and check again **before** reporting it to them.

## What it hides, and when it appears

Progress is saved **per character**. A new alt starts with everything hidden.

| OneForAll feature | Appears when |
|---|---|
| **Dungeons & raids**: the Dungeons tab, entrance icons, "Drops from" tooltips, quest sharing | You've cleared the dungeon, as recorded in the Legacy System (Forever's achievements). A popup then offers a reload to add it. Raids, and any dungeon the Legacy System doesn't track, show once you've been inside. |
| **Map landmarks**: flight masters, ships, zeppelins, the tram, zone transitions, Skyborne spots | You've been within about 80–100 yards. They show on the map straight away. |
| **Quest givers on the world map** (the `!` icons) | You've been within about 80–100 yards of the giver. Turn-ins (`?`) always show, as they're only for quests in your log. |
| **Library Books**: map icons, the "book nearby" alert, the Books tab | You've been within about 80–100 yards, or picked the book up. The Books tab updates after a reload. |
| **Library Book reward tiers**: the rewards for turning in 10, 20, … books (Books tab) | You've seen that reward quest |
| **Zone level ranges**: top right of a zone's map, and after zone names on the continent map | You've been in the zone. The zone map shows it straight away; the continent map after a reload. |
| **Weapon masters**: who teaches which weapon, and where (trainer window) | You've been within about 80–100 yards. They show straight away. |
| **Professions**: the recipe browser, Merchant's Favor, the Crafting List, camping items | You've learnt the recipe |
| **Armory**: item sets and reputation rewards | You've owned the item, or the game has shown it to you: a loot window, a loot roll, a loot chat line, at a vendor, or as a quest reward |
| **Gear Planner** | It follows the rows above: dungeon loot from dungeons you've cleared, crafted items from your recipes, set and rep items you've seen, and quest rewards from quests you've seen (offered, in your log or completed). Enchant suggestions show once you've learnt the recipe or owned or seen the item that applies it. |
| **Hunter pets**: families, tameable beasts, ability teachers, rare tames | You've tamed that beast, or had a pet of that family |
| **What's New** window | Never |
| **Remove Fog** (Quality of Life) | Never: it would uncover areas you haven't explored |

Unless marked otherwise, new discoveries show up after your next `/reload` or login.

Every part can be switched off in the options (see below).

### Things you might notice

- **New quest givers on the map:** OneForAll reads a zone's quest givers the first time you open that zone's map in a session. A giver you meet after that shows on the map after your next `/reload` or login.
- **Cleared, not entered:** the Legacy System records a dungeon when you clear it, and this addon follows that. "Ragefire Chasm or Hall of Thanes" counts the one on your side. If the Legacy System is account-wide or can't be read, dungeons show once you've been inside instead, and a chat line says so. Dungeons you'd already entered before this change stay shown.
- **Shared wings:** where dungeons show on entering, entering any Dire Maul wing reveals all three, and the same goes for both halves of Blackrock Spire. The game reports the same dungeon for each wing. Scarlet Monastery's wings are told apart correctly.
- **Set piece counts:** an Armory set lists only the pieces you've seen. Until you've seen them all, its name shows how many, for example "Battlegear of Glory (1/6 seen)". OneForAll's own counter only counts the listed pieces, so it reads "Owned 1 / 1".
- **Book alerts only once:** OneForAll's "Library Book nearby" popup shows only the first time this character is near each book, not every time you pass it again. Switch it off in the options to get it every time.
- **Pet alerts:** OneForAll's "this beast teaches …" alert only works for beasts you've already tamed.
- **Enchant suggestions:** enchanting enchants are spells, not items, so if you're not an enchanter you'll only see the ones applied with items (armour kits, scopes and so on).
- **Left as they are:** class trainer spells, talents, class quest milestones, the Merchant's Favor guide and profession trainers. They're game mechanics or help you find things.

## Installing

OneForAll must be installed too. This addon needs it.

**With WowUp:** go to *Get Addons → Install from URL* and paste `https://github.com/somecommoner/OneForAll_Forever-NoSpoilers`. WowUp installs the latest release and updates it when a new one comes out.

**By hand:** download `OneForAll_NoSpoilers-<version>-forever.zip` from [Releases](https://github.com/somecommoner/OneForAll_Forever-NoSpoilers/releases) and unpack it into `World of Warcraft/_forever_/Interface/AddOns/`.

Don't use GitHub's *Code → Download ZIP*. That folder is named after the repository, and the game only loads it if it's renamed to `OneForAll_NoSpoilers`.

## Options

*Options → AddOns → OneForAll NoSpoilers*, or type `/ofans`. There's one switch per part, each with a short description and your progress (for example "4 of 37 discovered").

- **What a switch does:** a part that's switched off leaves OneForAll alone, so it shows everything, but discoveries are still recorded. Switching it back on later loses nothing.
- **Account-wide:** switches apply to all characters. Progress stays per character.
- **Reloading:** changes take effect after a reload, and a *Reload now* button appears once you've changed something.

## Commands

| Command | What it does |
|---|---|
| `/ofans` | Opens the options |
| `/ofans status` | Prints each part in chat: what's discovered, what's hidden, and whether it's running |
| `/ofans reveal <dungeon>` | Marks a dungeon as discovered by hand, e.g. `/ofans reveal deadmines` |
| `/ofans legacy` | Says whether the Legacy System can be used, how many dungeons it tracks and how many you've cleared, and which dungeons show on entering instead. It names dungeons, so it can spoil. |

## How it works

OneForAll loads all its data first. This addon depends on it, so it always loads second. Before OneForAll builds any window or map icon, each part of this addon removes the undiscovered entries from OneForAll's own data lists. As you discover things, the entries go back in.

- **It never edits OneForAll's code or windows.** It only trims OneForAll's data lists, plus four small public entry points: the What's New window, the Remove Fog data, the "Library Book nearby" alert, and a request for the map icons to rebuild.
- **It saves only your progress.** That means the IDs of what you've discovered, never OneForAll's data. When an OneForAll update adds new dungeons, books or recipes, they're picked up automatically.
- **It's built to survive OneForAll updates.** Every part checks that OneForAll's data still looks the way it expects before changing anything. If it doesn't, that part leaves the data alone, says so once in chat, and the other parts keep working. The worst case after an update is that something shows when it should be hidden. It won't cause errors.

Files:

| File | Part |
|---|---|
| `Core.lua` | Loading, safety checks, switches, the reload prompt, slash commands |
| `Items.lua` | Remembers items owned or seen, for the Armory and enchant parts |
| `Places.lua` | Map landmarks, quest givers, Library Books and weapon masters, plus the trail of places you've been |
| `Zones.lua` | Zone level ranges |
| `Dungeons.lua` | Dungeons and raids |
| `Professions.lua` | Recipes and camping items |
| `Armory.lua` | Item sets and reputation rewards (items owned or seen) |
| `Pets.lua` | Hunter pets |
| `Quests.lua` | Gear Planner quest rewards and Library Book reward tiers |
| `Enchants.lua` | Gear Planner enchant suggestions |
| `Misc.lua` | What's New, Remove Fog and book alerts only once |
| `Options.lua` | The options page |

## Testing

`tools/test.lua` loads OneForAll's real data files together with this addon, using a small stand-in for the WoW API. It then plays through a fresh character, discoveries, a second login, and an OneForAll data change:

```sh
lua5.4 tools/test.lua "<path to>/Interface/AddOns/OneForAll" .
```

Run it after an OneForAll update to check that the data still lines up.

## Releasing

Raise `## Version:` in the `.toc` file, commit, then tag and push, for example `git tag v0.1.1 && git push origin v0.1.1`. The GitHub Action in `.github/workflows/release.yml` builds the zip and publishes the release, and WowUp picks it up from there.

## License

GPL-3.0-or-later, the same licence as OneForAll. See [LICENSE](LICENSE).
