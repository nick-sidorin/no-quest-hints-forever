-- Verify locale selection and a complete Russian UI translation.
local function loadLocale(locale)
    GetLocale = function() return locale end
    NoQuestHintsForeverLocale = nil
    assert(loadfile("NoQuestHintsForever/Localization.lua"))()
    return NoQuestHintsForeverLocale
end
local english = loadLocale("enUS")
local russian = loadLocale("ruRU")
local fallback = loadLocale("deDE")
local keys = {
    "QUEST_HINTS_GROUP", "ADDITIONAL_GROUP", "MANAGE_GROUP",
    "CHOOSE_PLAYSTYLE", "CHOOSE_PLAYSTYLE_DESC", "RESTORE_BUTTON", "RESTORE_DESC",
    "RESTORED", "RESTORE_PENDING", "WELCOME_TITLE", "WELCOME_SUBTITLE",
    "PRESET_BLIZZARD", "PRESET_BLIZZARD_DESC", "PRESET_IMMERSION", "PRESET_IMMERSION_DESC",
    "PRESET_FULL", "PRESET_FULL_DESC", "WELCOME_FOOTER", "WELCOME_APPLY",
    "WELCOME_SETTINGS", "WELCOME_LATER", "WELCOME_SELECT", "WELCOME_SELECTED", "WELCOME_READY",
    "QUEST_LEVELS", "QUEST_LEVELS_DESC", "QUEST_DIFFICULTY", "QUEST_DIFFICULTY_DESC", "LEVELS_STATUS", "DIFFICULTY_STATUS",
    "TITLE", "MAP_HINTS", "MAP_HINTS_DESC",
    "TRACKER", "TRACKER_DESC", "TOOLTIP_HINTS", "TOOLTIP_HINTS_DESC",
    "NPC_NAME_HINTS", "NPC_NAME_HINTS_DESC",
    "SELL_PRICES", "SELL_PRICES_DESC", "AUCTION_PRICES", "AUCTION_PRICES_DESC", "AUCTION_PRICE_STATUS",
    "PROGRESS_HINTS", "PROGRESS_HINTS_DESC",
    "SHOW_HINT", "HIDE_HINT",
    "SHOW_HINT_BUTTON", "HIDE_HINT_BUTTON", "HINT_TOOLTIP",
    "INIT", "UNAVAILABLE",
    "MAP_STATUS", "TRACKER_STATUS", "TOOLTIP_STATUS", "NPC_NAME_STATUS",
    "SELL_PRICE_STATUS", "PROGRESS_STATUS", "COMMANDS",
    "STATUS_ON", "STATUS_OFF", "VALUE_UNAVAILABLE",
}
for _, key in ipairs(keys) do
    assert(type(english[key]) == "string" and #english[key] > 0, "missing English "..key)
    assert(type(russian[key]) == "string" and #russian[key] > 0, "missing Russian "..key)
    assert(fallback[key] == english[key], "unsupported locale fallback wrong for "..key)
end
assert(english.SHOW_HINT ~= russian.SHOW_HINT)
assert(russian.SHOW_HINT == "Показать подсказку")
assert(russian.SHOW_HINT_BUTTON == "Показать")
assert(russian.HIDE_HINT_BUTTON == "Скрыть")
assert(russian.TITLE == "No Quest Hints")
io.write("PASS: ruRU translation, compact journal buttons and enUS fallback\n")
