# CurseForge — No Quest Hints

> **Maintainer note (not part of the public description):** This is the source of truth for the CurseForge project page. Copy the **Short description** and **Full description** sections into the corresponding CurseForge fields when releasing. Update this file in the release PR whenever user-facing features or compatibility notes change. The file is documentation, not part of the installed addon.

## Short description

Explore Azeroth without quest spoilers. Hide markers, NPC hints, progress popups and sell prices. Reveal Blizzard's original quest hints only when needed.

---

## Full description

# No Quest Hints

**Explore Azeroth. Not your quest markers.**

Take control of how much the game tells you. **No Quest Hints** removes unwanted quest guidance and distractions in **World of Warcraft: Forever**, while letting you bring back Blizzard's original hints whenever you need help.

## ✨ Features at a Glance

Six independent, optional settings:

- 🗺️ **Hide Quest Map Hints** — Remove quest markers, blue objective areas and navigation guidance.
- 📜 **Hide Objective Tracker** — Clear the on-screen quest list without losing your journal or quest progress.
- 💬 **Hide Quest Tooltip Hints** — Remove quest names and objective counters when hovering over creatures and objects.
- 🎯 **Hide Quest NPC Names** — Stop floating NPC names from revealing which creatures are quest targets.
- 💰 **Hide Item Sell Prices** — Discover what your loot is worth only when you visit a merchant.
- 🔕 **Hide Quest Progress Popups** — Remove yellow objective counters and completion messages without hiding other game notifications.

**All settings are independent, saved per character, and disabled by default.**

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

## ⚙️ Settings

Open **Options → AddOns → No Quest Hints** directly with `/nqh`, or select it from Blizzard's AddOns settings list. All six checkboxes appear on that page, with explanations on hover — no separate settings window.

| Command | Action |
|---|---|
| `/nqh` | Open addon settings |
| `/nqh on` | Hide default quest map hints |
| `/nqh off` | Restore default quest map hints |
| `/nqh status` | Show current settings |

The `on` and `off` commands affect map hints only. All other options have their own checkboxes.

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
