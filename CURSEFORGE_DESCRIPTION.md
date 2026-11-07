# CurseForge — No Quest Hints

> **Maintainer note:** Copy the Short description and Full description content into the corresponding CurseForge fields. Preserve the established feature-first structure and prominent Source Code & Bug Reports link when updating facts for a release. The release workflow does not update the project description automatically.

## Short description

Explore Azeroth without quest spoilers. Hide markers, NPC hints, progress popups and sell prices. Reveal Blizzard's original quest hints only when needed.

---

## Full description

# No Quest Hints

**Explore Azeroth. Not your quest markers.**

## ✨ Features at a Glance

Ten independent, optional controls:

- 🗺️ **Hide Quest Map Hints** — Remove quest markers, blue objective areas and navigation guidance.
- 📜 **Hide Objective Tracker** — Clear the on-screen quest list while keeping your journal and quest progress.
- 💬 **Hide Quest Tooltip Hints** — Remove quest names and objective counters from NPC and object tooltips.
- 🎯 **Hide Quest NPC Names** — Hide floating names that reveal quest targets.
- 💰 **Hide Item Sell Prices** — Hide vendor values outside trading and at auction with two independent options.
- 🔕 **Hide Quest Progress Popups** — Remove yellow objective updates while keeping other game messages.
- 🔢 **Hide Quest Levels** — Remove numeric level prefixes from journal and tracker titles.
- 🎨 **Hide Difficulty Colors** — Show quest titles in ordinary yellow instead of difficulty colors.
- 🎒 **Hide Quest Item Borders** — Remove yellow quest-item borders from Blizzard's bags.

**All controls are optional and saved per character. Nothing changes until you choose a playstyle or enable an option. Existing users keep their choices.**

## 🧭 Need Help? Reveal Just One Quest.

1. Hide the default quest guidance.
2. Read your quest journal and explore the world.
3. If you're stuck, select **Show hint** for that quest in your journal or its right-click menu.

The game restores its original guidance for the selected quest, where available:

- Blue highlighted objective areas
- Native interactive quest markers
- In-world navigation and distance
- Native quest indicators in the journal and objective tracker

Select **Hide hint** when you no longer need help. You can reveal multiple quests independently.

**No external quest database. Just Blizzard's own guidance, under your control.**

## 🌍 Choose Your Adventure

Choose a playstyle on first setup, or reopen the chooser with `/nqh welcome`:

- **As in Blizzard:** keep your current game settings; nothing is hidden.
- **Immersion:** hide the five forms of quest guidance.
- **Full immersion:** everything in Immersion, plus hidden numeric quest levels and item sell prices outside trading.

Select a card and confirm to apply it. Customize any option afterward. Difficulty colors, auction prices and quest-item borders remain visible in every preset unless you hide them manually.

## ⚙️ Settings

Open **Options → AddOns → No Quest Hints** with `/nqh`. All controls appear directly on that page, with explanations on hover. Playstyle and restoration are at the top; support is at the bottom.

| Command | Action |
| --- | --- |
| `/nqh` | Open addon settings |
| `/nqh welcome` | Reopen the playstyle chooser |
| `/nqh restore` | Immediately turn off all restrictions and restore saved original game settings |
| `/nqh status` | Show current settings and diagnostics |

The **Restore game settings** button asks for confirmation. Cancel or Escape keeps your configuration. **Use restoration before disabling or removing the addon.** It restores your saved personal values; cleanup cannot be guaranteed after a crash or once the addon is unloaded.

Upgrade messages distinguish new features from fixes. Newly added checkboxes carry Blizzard's native **New** marker until viewed.

## ℹ️ Good to Know

- Designed specifically for **World of Warcraft: Forever**.
- Automatically supports **English, Russian, German, French, Spanish, Italian, Brazilian Portuguese, Korean, Simplified Chinese and Traditional Chinese**, including both English and Spanish client variants.
- Preserves the geographical map, quest text, quest progress and quest-giver exclamation marks.
- Merchants always show native vendor sell values. The price controls do not change auction-market prices or selling mechanics.
- Bag-border hiding preserves quality colors, new-item highlights and quest-start exclamation marks.
- Some special NPC names may also be hidden because Blizzard groups them with quest NPC names.
- Custom bag borders and price overlays from other addons remain under those addons' control.

**Known issue:** An intermittent Blizzard protected-action warning is under investigation. See [Issue #3](https://github.com/nick-sidorin/no-quest-hints-forever/issues/3).

**[Source Code & Bug Reports](https://github.com/nick-sidorin/no-quest-hints-forever)**

For feedback, open **Issues → New issue** on the project page. Include your Forever build, addon version and steps to reproduce. The **Support → Report a problem** button in settings provides a copyable project link.

---

*Read the quest. Explore the world. Find your own way.*
