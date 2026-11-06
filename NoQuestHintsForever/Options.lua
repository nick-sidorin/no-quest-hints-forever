-- Blizzard-native addon settings for No Quest Hints — Forever.
-- Uses the same vertical Settings layout as the game's own options:
-- short checkbox labels, with the explanatory text only on hover.
-- All option state and game-side effects remain owned by the core addon.
local api = NoQuestHintsForeverAPI
if not api then return end

local L = NoQuestHintsForeverLocale or {}
local TITLE = L.TITLE or "No Quest Hints"
local category

local controls = {
    { "NQH_HIDE_MAP_HINTS", "MAP_HINTS", "MAP_HINTS_DESC",
      "IsMapHidden", "SetMapHidden" },
    { "NQH_HIDE_TRACKER", "TRACKER", "TRACKER_DESC",
      "IsTrackerHidden", "SetTrackerHidden" },
    { "NQH_HIDE_QUEST_TOOLTIPS", "TOOLTIP_HINTS", "TOOLTIP_HINTS_DESC",
      "IsTooltipHintsHidden", "SetTooltipHintsHidden" },
    { "NQH_HIDE_QUEST_NPC_NAMES", "NPC_NAME_HINTS", "NPC_NAME_HINTS_DESC",
      "IsQuestNPCNamesHidden", "SetQuestNPCNamesHidden" },
    { "NQH_HIDE_SELL_PRICES", "SELL_PRICES", "SELL_PRICES_DESC",
      "IsSellPriceHidden", "SetSellPriceHidden" },
    { "NQH_HIDE_QUEST_PROGRESS", "PROGRESS_HINTS", "PROGRESS_HINTS_DESC",
      "IsQuestProgressHidden", "SetQuestProgressHidden" },
}

local function registerCategory()
    if category then return true end
    if not Settings or type(Settings.RegisterVerticalLayoutCategory) ~= "function"
        or type(Settings.RegisterProxySetting) ~= "function"
        or type(Settings.CreateCheckbox) ~= "function"
        or type(Settings.RegisterAddOnCategory) ~= "function"
        or not Settings.VarType or not Settings.VarType.Boolean then
        return false
    end

    local newCategory = Settings.RegisterVerticalLayoutCategory(TITLE)

    for _, item in ipairs(controls) do
        -- Do not store copied state in the Settings framework. Getters read the
        -- active character's SavedVariables on every access; setters delegate
        -- to the existing routines that update Blizzard UI immediately.
        local isEnabled, setEnabled = api[item[4]], api[item[5]]
        local setting = Settings.RegisterProxySetting(
            newCategory, item[1], Settings.VarType.Boolean,
            L[item[2]] or item[2], false,
            function() return isEnabled() == true end,
            function(value) setEnabled(value == true) end)
        Settings.CreateCheckbox(newCategory, setting, L[item[3]] or "")
    end

    Settings.RegisterAddOnCategory(newCategory)
    category = newCategory
    return true
end

function api.OpenOptions()
    if not registerCategory() or not Settings
        or type(Settings.OpenToCategory) ~= "function"
        or not category or type(category.GetID) ~= "function" then
        return false
    end
    -- Opens the ordinary Options > AddOns panel, not a floating duplicate UI.
    local ok = pcall(Settings.OpenToCategory, category:GetID())
    return ok
end

-- Settings is normally already present in Forever. If another load order
-- delays the Settings addon, register only when the API becomes available.
if not registerCategory() then
    local events = CreateFrame("Frame")
    events:RegisterEvent("ADDON_LOADED")
    events:RegisterEvent("PLAYER_LOGIN")
    events:SetScript("OnEvent", function(self)
        if registerCategory() then
            self:UnregisterEvent("ADDON_LOADED")
            self:UnregisterEvent("PLAYER_LOGIN")
        end
    end)
end
