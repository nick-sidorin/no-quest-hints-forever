# CurseForge — No Quest Hints

> **Development draft for unreleased 1.4.0. Do not publish this description before the version is verified and released.**

> **Maintainer note (not part of the public description):** This is the source of truth for the CurseForge project page. Copy the **Short description** and **Full description** sections into the corresponding CurseForge fields when releasing. Update this file in the release PR whenever user-facing features or compatibility notes change. The file is documentation, not part of the installed addon.

## Short description

Explore Azeroth without quest spoilers. Hide markers, NPC hints, progress popups and sell prices. Reveal Blizzard's original quest hints only when needed.

---

## Full description

# No Quest Hints

**Explore Azeroth. Not your quest markers.**

Take control of how much the game tells you. **No Quest Hints** removes unwanted quest guidance and distractions in **World of Warcraft: Forever**, while letting you bring back Blizzard's original hints whenever you need help.

## ✨ Features at a Glance

Seven quest controls and two independent item-price controls:

- 🗺️ **Hide Quest Map Hints** — Remove quest markers, blue objective areas and navigation guidance.
- 📜 **Hide Objective Tracker** — Clear the on-screen quest list without losing your journal or quest progress.
- 💬 **Hide Quest Tooltip Hints** — Remove quest names and objective counters when hovering over creatures and objects.
- 🎯 **Hide Quest NPC Names** — Stop floating NPC names from revealing which creatures are quest targets.
- 💰 **Hide Item Sell Prices** — Choose independently whether to hide vendor sell values outside trading and at the auction house.
- **Hide Quest Levels** — Remove numeric level prefixes from quest journal and tracker titles.
- **Hide Difficulty Colors** — Use normal yellow quest titles instead of difficulty colors; optional and enabled only manually.
- 🔕 **Hide Quest Progress Popups** — Remove yellow objective counters and completion messages without hiding other game notifications.

**The controls are independent and saved per character. Nothing changes until you choose a playstyle or enable an option. Existing users keep their choices.**

## 🧭 Need Help? Reveal Just One Quest.

You don't have to choose between having every quest marked and having no guidance at all.

1. Hide the default quest guidance.
2. Read your quest journal and explore the world.
3. If you're stuck, select **Show hint** for that quest in your journal or its right-click menu.

The game restores its original quest guidance for the selected quest, where available:

- Blue highlighted objective areas
- Native interactive quest markers
- In-world navigation and distance
- Native quest indicators in the journal and objective tracker

Select **Hide hint** when you no longer need help. You can reveal multiple quests independently.

**No external quest database. No replacement markers. Just Blizzard's own guidance, under your control.**

## 🌍 Choose Your Adventure

On your first visit with a new character, choose a playstyle:

- **As in Blizzard:** keep your game settings; nothing is hidden.
- **Immersion:** hide the five forms of quest guidance while keeping item prices visible.
- **Full immersion:** everything in Immersion, plus hidden numeric quest levels and item sell prices outside trading. Difficulty colors and auction prices remain visible unless you hide them separately.

Select a card and confirm to begin. Or customize individual options. You can change your playstyle later in settings.

## ⚙️ Settings

Open **Options → AddOns → No Quest Hints** directly with `/nqh`, or select it from Blizzard's AddOns settings list. The checkboxes appear directly on that page, grouped into **Quest hints**, **Item prices** and **Bags**, with explanations on hover.

The **Playstyle and restoration** buttons appear first. At the bottom, **Support → Report a problem** provides a copyable GitHub project link; open it in your browser and choose **Issues → New issue** for reports or suggestions.

The optional **Bags → Hide quest item borders** control hides yellow quest-item borders in native carried bags. Quality borders, new-item highlights and quest-start exclamation marks remain. It is OFF in every playstyle and must be enabled manually. Custom bag addons may draw independent borders.

The **Item prices** section has two equal-rank checkboxes: **Hide outside trading** and **Hide at auction**. Both mean hiding and work independently. Merchants always show prices; the auction checkbox affects the existing **NPC vendor sell value**, not an auction market estimate. Both default OFF, while Full immersion enables only hiding outside trading.

| Command | Action |
|---|---|
| `/nqh` | Open addon settings |
| `/nqh welcome` | Reopen the playstyle chooser |
| `/nqh restore` | Turn off all features and restore saved original game settings |
| `/nqh status` | Show current settings |

The **Restore game settings** button asks for confirmation before clearing your current configuration. Cancel or Escape keeps it. The explicit `/nqh restore` command restores immediately.

**Before disabling or removing the addon**, use **Restore game settings** or `/nqh restore`. This restores your saved personal settings, rather than resetting all of Blizzard’s options. If already removed and settings remain changed, reinstall with saved settings intact and run the restore command. The older map-only `on`/`off` commands have been removed.

## ℹ️ Good to Know

- Designed specifically for **World of Warcraft: Forever**.
- Supports **English and Russian**.
- Uses native Blizzard quest and tooltip information.
- Does not change quest progress, item prices or selling mechanics.
- Some special NPC names may also be hidden by the quest-name setting because Blizzard groups them together.
- Prices displayed by other inventory addons may require configuring those addons separately.

**Known issue:** An intermittent Blizzard protected-action warning has been reported and is under investigation. See [Issue #3](https://github.com/nick-sidorin/no-quest-hints-forever/issues/3).

**[Source Code & Bug Reports](https://github.com/nick-sidorin/no-quest-hints-forever)**

---

*Read the quest. Explore the world. Find your own way.*
