-- Verify locale selection and a complete Russian UI translation.
local function loadLocale(locale)
    GetLocale = function() return locale end
    NoQuestHintsForeverLocale = nil
    assert(loadfile("NoQuestHintsForever/Localization.lua"))()
    assert(loadfile("NoQuestHintsForever/LocaleTranslations.lua"))()
    return NoQuestHintsForeverLocale
end
local english = loadLocale("enUS")
local russian = loadLocale("ruRU")
local fallback = loadLocale("xxXX")
local keys = {
    "VERSION_UPDATED", "VERSION_FEATURES",
    "SUPPORT_GROUP", "REPORT_BUTTON", "REPORT_DESC", "REPORT_LINK_TEXT", "LINK_CLOSE",
    "QUEST_HINTS_GROUP", "ADDITIONAL_GROUP", "MANAGE_GROUP",
    "CHOOSE_PLAYSTYLE", "CHOOSE_PLAYSTYLE_DESC", "RESTORE_BUTTON", "RESTORE_DESC",
    "RESTORE_CONFIRM_TEXT", "RESTORE_CONFIRM_ACCEPT", "RESTORE_CONFIRM_CANCEL", "RESTORE_CONFIRM_UNAVAILABLE",
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

-- Every official client locale resolves automatically with a complete dictionary;
-- unsupported clients still fall back to English. Validate format placeholders,
-- not just nonempty strings, because these texts are passed to string.format.
local base=getmetatable(english).__index
local function placeholders(text)
    local result={}
    for token in text:gmatch("%%[sd]") do result[#result+1]=token end
    return table.concat(result,",")
end
for _,locale in ipairs({"enUS","enGB","ruRU","deDE","frFR","esES","esMX","itIT","ptBR","koKR","zhCN","zhTW"}) do
    local current=loadLocale(locale)
    for key,value in pairs(base) do
        assert(type(current[key])=="string" and #current[key]>0,locale .. " missing " .. key)
        if locale~="enUS" and locale~="enGB" then
            assert(rawget(current,key)~=nil,locale .. " silently fell back for " .. key)
        end
        assert(placeholders(value)==placeholders(current[key]),locale .. " bad placeholders in " .. key)
    end
    if locale=="enGB" then assert(current.WELCOME_TITLE==english.WELCOME_TITLE) end
    if locale=="deDE" then assert(current.WELCOME_APPLY=="Abenteuer beginnen") end
    if locale=="frFR" then assert(current.WELCOME_APPLY=="Commencer l'aventure") end
end
