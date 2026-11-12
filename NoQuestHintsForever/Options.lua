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
    { "NQH_HIDE_AUCTION_SELL_PRICES", "AUCTION_PRICES", "AUCTION_PRICES_DESC",
      "IsAuctionSellPriceHidden", "SetAuctionSellPriceHidden" },
    { "NQH_HIDE_QUEST_LEVELS", "QUEST_LEVELS", "QUEST_LEVELS_DESC",
      "IsQuestLevelsHidden", "SetQuestLevelsHidden" },
    { "NQH_HIDE_QUEST_DIFFICULTY", "QUEST_DIFFICULTY", "QUEST_DIFFICULTY_DESC",
      "IsQuestDifficultyHidden", "SetQuestDifficultyHidden" },
    { "NQH_HIDE_QUEST_ITEM_HIGHLIGHT", "ITEM_HIGHLIGHT", "ITEM_HIGHLIGHT_DESC",
      "IsQuestItemHighlightHidden", "SetQuestItemHighlightHidden" },
    { "NQH_HIDE_QUEST_TIMERS", "QUEST_TIMERS", "QUEST_TIMERS_DESC",
      "IsQuestTimersHidden", "SetQuestTimersHidden" },
    { "NQH_HIDE_EXPERIENCE_BAR", "EXPERIENCE_BAR", "EXPERIENCE_BAR_DESC",
      "IsExperienceBarHidden", "SetExperienceBarHidden" },
    { "NQH_HIDE_MINIMAP", "MINIMAP", "MINIMAP_DESC",
      "IsMinimapHidden", "SetMinimapHidden" },
}

local PROJECT_URL = "https://github.com/nick-sidorin/no-quest-hints-forever"
local REPORT_DIALOG = "NOQUESTHINTSFOREVER_PROJECT_LINK"
local function editBox(dialog)
    if type(dialog.GetEditBox) == "function" then return dialog:GetEditBox() end
    return dialog.editBox or dialog.EditBox
end

function api.ShowProjectLink()
    if type(StaticPopupDialogs) ~= "table" or type(StaticPopup_Show) ~= "function" then
        print("|cff80c0ffNo Quest Hints|r: " .. L.REPORT_LINK_TEXT .. " " .. PROJECT_URL)
        return false
    end
    if not StaticPopupDialogs[REPORT_DIALOG] then
        StaticPopupDialogs[REPORT_DIALOG] = {
            text = L.REPORT_LINK_TEXT,
            button1 = L.LINK_CLOSE,
            hasEditBox = true,
            editBoxWidth = 440,
            maxLetters = 0,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            OnShow = function(dialog)
                local box = editBox(dialog)
                if box then
                    box:SetText(PROJECT_URL)
                    box:SetFocus()
                    box:HighlightText()
                end
            end,
            EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
            EditBoxOnEnterPressed = function(box) box:GetParent():Hide() end,
        }
    end
    return StaticPopup_Show(REPORT_DIALOG) ~= nil
end

function api.RequestRestoreGameSettings()
    if type(StaticPopupDialogs) ~= "table" or type(StaticPopup_Show) ~= "function" then
        print("|cff80c0ffNo Quest Hints|r: " .. L.RESTORE_CONFIRM_UNAVAILABLE)
        return false
    end
    local name = "NOQUESTHINTSFOREVER_CONFIRM_RESTORE"
    if not StaticPopupDialogs[name] then
        StaticPopupDialogs[name] = {
            text = L.RESTORE_CONFIRM_TEXT,
            button1 = L.RESTORE_CONFIRM_ACCEPT,
            button2 = L.RESTORE_CONFIRM_CANCEL,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            OnAccept = function()
                local restored = api.RestoreGameSettings()
                print("|cff80c0ffNo Quest Hints|r: " .. (restored and L.RESTORED or L.RESTORE_PENDING))
            end,
        }
    end
    return StaticPopup_Show(name) ~= nil
end

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
    heading(L.MANAGE_GROUP)
    button(L.CHOOSE_PLAYSTYLE, function()
        if api.ShowWelcome then api.ShowWelcome() end
    end, L.CHOOSE_PLAYSTYLE_DESC)
    button(L.RESTORE_BUTTON, api.RequestRestoreGameSettings, L.RESTORE_DESC)

    heading(L.QUEST_HINTS_GROUP)

    -- Keep quest options together; vendor prices are additional immersion.
    local order = { 1, 2, 3, 4, 6, 8, 9, 11, 5, 7, 10, 12, 13 }
    for _, index in ipairs(order) do
        local item = controls[index]
        if index == 5 then heading(L.ADDITIONAL_GROUP) end
        if index == 10 then heading(L.BAGS_GROUP) end
        if index == 12 then heading(L.HUD_GROUP) end
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
        local initializer = Settings.CreateCheckbox(newCategory, setting, L[item[3]] or "")
        if initializer and type(initializer.IsNewTagShown) == "function"
            and type(initializer.MarkSettingAsSeen) == "function" then
            -- Use the existing native NewFeature widget through our own row's
            -- initializer. Never register addon IDs in Blizzard's game-version
            -- NewSettings tables or replace global feature/Settings functions.
            initializer.IsNewTagShown = function() return api.IsSettingNew(item[1]) == true end
            initializer.MarkSettingAsSeen = function() api.MarkSettingSeen(item[1]) end
        end
    end

    heading(L.SUPPORT_GROUP)
    button(L.REPORT_BUTTON, api.ShowProjectLink, L.REPORT_DESC)

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
