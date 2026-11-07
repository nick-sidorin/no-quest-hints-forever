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

function api.RefreshOptions()
    if not category or not Settings or type(Settings.NotifyUpdate) ~= "function" then return end
    for _, item in ipairs(controls) do Settings.NotifyUpdate(item[1]) end
end

local function registerCategory()
    if category then return true end
    if not Settings or type(Settings.RegisterVerticalLayoutCategory) ~= "function"
        or type(Settings.RegisterProxySetting) ~= "function"
        or type(Settings.CreateCheckbox) ~= "function"
        or type(Settings.RegisterAddOnCategory) ~= "function"
        or not Settings.VarType or not Settings.VarType.Boolean then
        return false
    end

    local newCategory, layout = Settings.RegisterVerticalLayoutCategory(TITLE)
    local function heading(text)
        if layout and type(CreateSettingsListSectionHeaderInitializer) == "function" then
            layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
        end
    end
    local function button(text, callback, tooltip)
        if layout and type(CreateSettingsButtonInitializer) == "function" then
            layout:AddInitializer(CreateSettingsButtonInitializer("", text, callback, tooltip, true))
        end
    end
    heading(L.QUEST_HINTS_GROUP)

    -- Keep quest options together; vendor prices are additional immersion.
    local order = { 1, 2, 3, 4, 6, 5 }
    for _, index in ipairs(order) do
        local item = controls[index]
        if index == 5 then heading(L.ADDITIONAL_GROUP) end
        -- Do not store copied state in the Settings framework. Getters read the
        -- active character's SavedVariables on every access; setters delegate
        -- to the existing routines that update Blizzard UI immediately.
        local isEnabled, setEnabled = api[item[4]], api[item[5]]
        local setting = Settings.RegisterProxySetting(
            newCategory, item[1], Settings.VarType.Boolean,
            L[item[2]] or item[2], false,
            function() return isEnabled() == true end,
            function(value)
                api.CompleteOnboarding()
                setEnabled(value == true)
            end)
        Settings.CreateCheckbox(newCategory, setting, L[item[3]] or "")
    end

    heading(L.MANAGE_GROUP)
    button(L.CHOOSE_PLAYSTYLE, function()
        if api.ShowWelcome then api.ShowWelcome() end
    end, L.CHOOSE_PLAYSTYLE_DESC)
    button(L.RESTORE_BUTTON, function()
        local restored = api.RestoreGameSettings()
        print("|cff80c0ffNo Quest Hints|r: " .. (restored and L.RESTORED or L.RESTORE_PENDING))
    end, L.RESTORE_DESC)

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
