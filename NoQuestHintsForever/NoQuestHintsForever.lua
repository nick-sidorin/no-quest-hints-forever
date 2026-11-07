-- No Quest Hints - Forever
-- The game's map CVars and objective tracker are independent, per-character options.
local ADDON_NAME = "NoQuestHintsForever"
local L = NoQuestHintsForeverLocale or {}

local cvars = {
    "questPOI",
    "showQuestObjectivesOnMap",
    "questPOILocalStory",
    "minimapShowQuestBlobs",
    "showInGameNavigation",
}

local function printMessage(message)
    print("|cff80c0ffNo Quest Hints|r: " .. message)
end

local function getCVar(name)
    local getter = C_CVar and C_CVar.GetCVar or GetCVar
    if not getter then return nil end
    local ok, value = pcall(getter, name)
    if ok then return value end
end

local function setCVar(name, value)
    local setter = C_CVar and C_CVar.SetCVar or SetCVar
    if not setter then return false end
    local ok = pcall(setter, name, value)
    return ok and getCVar(name) == value
end

local function isSharedCVar(name)
    if C_CVar and C_CVar.GetCVarInfo then
        local ok, _, _, isAccount, isCharacter = pcall(C_CVar.GetCVarInfo, name)
        if ok then
            if isAccount == true then return true end
            if isCharacter == true then return false end
        end
    end
    return name == "showInGameNavigation"
end

-- Do not capture SavedVariables until ADDON_LOADED: WoW loads them after Lua.
local character, account
local enforcing = false
local loggingOut = false

local function initialize()
    if type(NoQuestHintsForeverChar) ~= "table" then NoQuestHintsForeverChar = {} end
    if type(NoQuestHintsForeverAccount) ~= "table" then NoQuestHintsForeverAccount = {} end
    character, account = NoQuestHintsForeverChar, NoQuestHintsForeverAccount
    -- Inspect the saved table BEFORE adding bookkeeping keys. An existing
    -- installation (even all options OFF) must not be treated as a new player.
    if character.onboardingComplete == nil then
        character.onboardingComplete = next(character) ~= nil
    end
    -- A permissive sub-option of price hiding, not another hiding feature.
    -- Add this only AFTER detecting first-run/legacy data above.
    if character.showAuctionSellPrices == nil then character.showAuctionSellPrices = true end
    if type(character.original) ~= "table" then character.original = {} end
    if type(account.original) ~= "table" then account.original = {} end
    -- Preserve legacy 'enabled' from 1.1.1 as the map-hints option.
    -- Hide quest lines on unit/object tooltips is a new independent,
    -- opt-in option. Existing 1.2.0 users retain all their preferences.
    -- Both hideTracker and hideQuestTooltips default to false.
end

local function enforceMapHints()
    if loggingOut or not character or character.enabled ~= true or enforcing then return end
    enforcing = true
    for _, name in ipairs(cvars) do
        local value = getCVar(name)
        if value ~= nil then
            local original = isSharedCVar(name) and account.original or character.original
            if original[name] == nil then original[name] = value end
            local target = "0"
            -- Navigation is a single globally drawn diamond. Allow it ONLY
            -- when the currently super-tracked quest is explicitly revealed.
            if name == "showInGameNavigation" and NoQuestHintsForeverAPI
                and type(NoQuestHintsForeverAPI.IsQuestNavigationAllowed) == "function"
                and NoQuestHintsForeverAPI.IsQuestNavigationAllowed() then
                target = "1"
            end
            if value ~= target then setCVar(name, target) end
        end
    end
    enforcing = false
end

local function restoreMapValues(original)
    if not original then return end
    for name, value in pairs(original) do
        local current = getCVar(name)
        if current == value or (current ~= nil and setCVar(name, value)) then
            original[name] = nil
        end
    end
end

local function setMapHints(enabled)
    if not character then return end
    character.enabled = enabled == true
    if character.enabled then
        enforceMapHints()
    else
        restoreMapValues(character.original)
        restoreMapValues(account.original)
    end
    -- The opted-in map pin layer is independent of Blizzard's global CVars.
    if NoQuestHintsForeverAPI and type(NoQuestHintsForeverAPI.RefreshQuestHintPins) == "function" then
        NoQuestHintsForeverAPI.RefreshQuestHintPins()
    end
end

-- ObjectiveTrackerFrame is Blizzard-owned. Do not Hide() it in secure
-- update paths. Alpha avoids disturbing Blizzard's layout/visibility state.
-- Defer reapplication from Show/SetAlpha hooks to avoid taint.
local trackerFrame, trackerAlpha, trackerMouse
local trackerHooked, trackerApplying, trackerQueued = false, false, false

local function inCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local updateTracker

local function queueTrackerUpdate()
    if trackerQueued then return end
    if C_Timer and type(C_Timer.After) == "function" then
        trackerQueued = true
        C_Timer.After(0, function()
            trackerQueued = false
            if character then updateTracker() end
        end)
    end
end

local function trackFrame()
    local frame = ObjectiveTrackerFrame
    if not frame or type(frame.SetAlpha) ~= "function" then return nil end
    if trackerFrame ~= frame then
        trackerFrame, trackerAlpha, trackerMouse = frame, nil, nil
        trackerHooked = false
    end
    if not trackerHooked and type(hooksecurefunc) == "function" then
        -- A post-hook is harmless when the feature is OFF. It cannot be removed,
        -- so install it just once, and never mutate the frame in the hook body.
        local successShow = pcall(hooksecurefunc, frame, "Show", function()
            if character and character.hideTracker and not trackerApplying then
                queueTrackerUpdate()
            end
        end)
        local successAlpha = pcall(hooksecurefunc, frame, "SetAlpha", function()
            if character and character.hideTracker and not trackerApplying then
                queueTrackerUpdate()
            end
        end)
        trackerHooked = successShow or successAlpha
    end
    return frame
end

updateTracker = function()
    if loggingOut or not character or trackerApplying then return end
    local frame = trackFrame()
    if not frame then return end
    trackerApplying = true
    if character.hideTracker == true then
        if trackerAlpha == nil and type(frame.GetAlpha) == "function" then
            local ok, value = pcall(frame.GetAlpha, frame)
            if ok then trackerAlpha = value end
        end
        if trackerMouse == nil and type(frame.IsMouseEnabled) == "function" then
            local ok, value = pcall(frame.IsMouseEnabled, frame)
            if ok then trackerMouse = value end
        end
        -- Changing alpha is cosmetic and does not untrack quests.
        if type(frame.GetAlpha) == "function" then
            local ok, current = pcall(frame.GetAlpha, frame)
            if ok and current ~= 0 then pcall(frame.SetAlpha, frame, 0) end
        else
            pcall(frame.SetAlpha, frame, 0)
        end
        if not inCombat() and type(frame.EnableMouse) == "function" then
            pcall(frame.EnableMouse, frame, false)
        end
    else
        if trackerAlpha ~= nil then
            pcall(frame.SetAlpha, frame, trackerAlpha)
            trackerAlpha = nil
        end
        if trackerMouse ~= nil and not inCombat() and type(frame.EnableMouse) == "function" then
            pcall(frame.EnableMouse, frame, trackerMouse)
            trackerMouse = nil
        end
    end
    trackerApplying = false
end

local function setTrackerHidden(hidden)
    if not character then return end
    character.hideTracker = hidden == true
    updateTracker()
end

local function setTooltipHintsHidden(hidden)
    if not character then return end
    character.hideQuestTooltips = hidden == true
    -- The Blizzard line-pre-callback reads this at tooltip creation time.
    -- No reload, CVar change, or protected tooltip-frame manipulation.
end

local function setSellPriceHidden(hidden)
    if not character then return end
    character.hideSellPrices = hidden == true
    -- TooltipDataProcessor reads this dynamically; vendor UI remains native.
end

local function setAuctionSellPriceShown(shown)
    if not character then return end
    character.showAuctionSellPrices = shown == true
end

local function setQuestProgressHidden(hidden)
    if not character then return end
    character.hideQuestProgressMessages = hidden == true
    if NoQuestHintsForeverAPI and
        type(NoQuestHintsForeverAPI.RefreshQuestProgressMessages) == "function" then
        NoQuestHintsForeverAPI.RefreshQuestProgressMessages()
    end
end

-- Blizzard groups names of quest-relevant units with certain special NPCs
-- behind one CVar. This is the closest native override, not per-quest filtering.
-- Preserve the player's original account-wide CVar across character switches.
local QUEST_NPC_NAME_CVAR = "UnitNameFriendlySpecialNPCName"
local npcNamesApplying = false
local function updateQuestNPCNames()
    if loggingOut or not character or not account or npcNamesApplying then return end
    npcNamesApplying = true
    local current = getCVar(QUEST_NPC_NAME_CVAR)
    if character.hideQuestNPCNames == true then
        if current ~= nil then
            if account.npcNameOriginal == nil then
                account.npcNameOriginal = current
            end
            if current ~= "0" then
                setCVar(QUEST_NPC_NAME_CVAR, "0")
            end
        end
    elseif account.npcNameOriginal ~= nil then
        local previous = account.npcNameOriginal
        if current == previous or (current ~= nil and setCVar(QUEST_NPC_NAME_CVAR, previous)) then
            account.npcNameOriginal = nil
        end
    end
    npcNamesApplying = false
end

local function setQuestNPCNamesHidden(hidden)
    if not character then return end
    character.hideQuestNPCNames = hidden == true
    updateQuestNPCNames()
end

-- UI module attaches an OpenOptions callback after its own Lua file loads.
local api = {}
NoQuestHintsForeverAPI = api
api.IsMapHidden = function() return character and character.enabled == true end
api.IsTrackerHidden = function() return character and character.hideTracker == true end
api.IsTooltipHintsHidden = function() return character and character.hideQuestTooltips == true end
api.IsSellPriceHidden = function() return character and character.hideSellPrices == true end
api.IsAuctionSellPriceShown = function() return not character or character.showAuctionSellPrices ~= false end
api.IsQuestProgressHidden = function() return character and character.hideQuestProgressMessages == true end
api.IsQuestNPCNamesHidden = function() return character and character.hideQuestNPCNames == true end
api.SetMapHidden = setMapHints
api.SetTrackerHidden = setTrackerHidden
api.SetTooltipHintsHidden = setTooltipHintsHidden
api.SetSellPriceHidden = setSellPriceHidden
api.SetAuctionSellPriceShown = setAuctionSellPriceShown
api.SetQuestProgressHidden = setQuestProgressHidden
api.SetQuestNPCNamesHidden = setQuestNPCNamesHidden
api.UpdateTracker = updateTracker
api.RefreshNavigation = enforceMapHints

function api.CompleteOnboarding()
    if character then character.onboardingComplete = true end
end

function api.IsOnboardingPending()
    return character ~= nil and character.onboardingComplete ~= true
end

-- Do not erase quest permissions or the player's choices during shutdown.
-- Restore only successful writes; failed/unavailable CVars keep their backup.
local function restorePersistentValues()
    restoreMapValues(character and character.original)
    restoreMapValues(account and account.original)
    if account and account.npcNameOriginal ~= nil then
        local previous = account.npcNameOriginal
        local current = getCVar(QUEST_NPC_NAME_CVAR)
        if current == previous or (current ~= nil and setCVar(QUEST_NPC_NAME_CVAR, previous)) then
            account.npcNameOriginal = nil
        end
    end
end

function api.RestoreGameSettings()
    if not character then return false end
    api.CompleteOnboarding()
    setMapHints(false)
    setTrackerHidden(false)
    setTooltipHintsHidden(false)
    setQuestNPCNamesHidden(false)
    setSellPriceHidden(false)
    setQuestProgressHidden(false)
    if api.RefreshOptions then api.RefreshOptions() end
    if api.HideWelcome then api.HideWelcome() end
    return next(character.original) == nil and next(account.original) == nil
        and account.npcNameOriginal == nil and trackerMouse == nil
end

function api.ApplyPreset(preset)
    if not character or (preset ~= "blizzard" and preset ~= "immersion" and preset ~= "full") then
        return false
    end
    api.CompleteOnboarding()
    local hide = preset ~= "blizzard"
    setMapHints(hide)
    setTrackerHidden(hide)
    setTooltipHintsHidden(hide)
    setQuestNPCNamesHidden(hide)
    setQuestProgressHidden(hide)
    setSellPriceHidden(preset == "full")
    if api.RefreshOptions then api.RefreshOptions() end
    return true
end

SLASH_NOQUESTHINTSFOREVER1 = "/nqh"
SlashCmdList.NOQUESTHINTSFOREVER = function(message)
    if not character then
        printMessage(L.INIT or "Settings are still loading.")
        return
    end
    local command = (message or ""):match("^%s*(%S+)")
    command = command and command:lower() or ""
    if command == "" then
        if type(api.OpenOptions) ~= "function" or api.OpenOptions() ~= true then
            printMessage(L.UNAVAILABLE or "Addon settings are unavailable.")
        end
    elseif command == "restore" then
        local restored = api.RestoreGameSettings()
        printMessage(restored and (L.RESTORED or "Saved game settings restored.") or (L.RESTORE_PENDING or "Restore incomplete; saved backups retained. Retry /nqh restore."))
    elseif command == "status" then
        local statusOn, statusOff = L.STATUS_ON or "ON", L.STATUS_OFF or "OFF"
        printMessage((L.MAP_STATUS or "Hide map hints: ") .. (character.enabled == true and statusOn or statusOff))
        printMessage((L.TRACKER_STATUS or "Hide objective tracker: ") .. (character.hideTracker == true and statusOn or statusOff))
        printMessage((L.TOOLTIP_STATUS or "Hide quest tooltip hints: ") .. (character.hideQuestTooltips == true and statusOn or statusOff))
        printMessage((L.NPC_NAME_STATUS or "Hide quest NPC names: ") .. (character.hideQuestNPCNames == true and statusOn or statusOff))
        printMessage((L.SELL_PRICE_STATUS or "Hide item sell prices: ") .. (character.hideSellPrices == true and statusOn or statusOff))
        printMessage((L.AUCTION_PRICE_STATUS or "Show vendor prices at auction: ") .. (api.IsAuctionSellPriceShown() and statusOn or statusOff))
        printMessage((L.PROGRESS_STATUS or "Hide quest progress popups: ") .. (character.hideQuestProgressMessages == true and statusOn or statusOff))
        for _, name in ipairs(cvars) do
            local value = getCVar(name)
            printMessage(name .. " = " .. (value == nil and (L.VALUE_UNAVAILABLE or "unavailable") or tostring(value)))
        end
    else
        printMessage(L.COMMANDS or "Commands: /nqh, /nqh restore, /nqh status")
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("CVAR_UPDATE")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("SUPER_TRACKING_CHANGED")
frame:SetScript("OnEvent", function(_, event, changed)
    if event == "PLAYER_LOGOUT" then
        loggingOut = true
        restorePersistentValues()
        return
    end
    if loggingOut then return end
    if event == "ADDON_LOADED" then
        if changed == ADDON_NAME then initialize() end
        -- ObjectiveTrackerFrame can be loaded after our addon.
        if character and character.hideTracker == true then updateTracker() end
    elseif event == "PLAYER_LOGIN" then
        if not character then initialize() end
        if character.enabled == true then
            enforceMapHints()
        else
            restoreMapValues(character.original)
            restoreMapValues(account.original)
        end
        updateTracker()
        updateQuestNPCNames()
        if type(api.MaybeShowWelcome) == "function" then api.MaybeShowWelcome() end
    elseif event == "PLAYER_ENTERING_WORLD" then
        enforceMapHints()
        updateTracker()
        updateQuestNPCNames()
    elseif event == "CVAR_UPDATE" and character and type(changed) == "string" then
        if character.enabled == true then
            for _, name in ipairs(cvars) do
                if changed:lower() == name:lower() then enforceMapHints(); break end
            end
        end
        if character.hideQuestNPCNames == true
            and changed:lower() == QUEST_NPC_NAME_CVAR:lower() then
            updateQuestNPCNames()
        end
    elseif event == "SUPER_TRACKING_CHANGED" then
        -- Never reveal navigation toward a non-permitted quest.
        enforceMapHints()
    elseif event == "PLAYER_REGEN_ENABLED" then
        updateTracker()
        if type(api.MaybeShowWelcome) == "function" then api.MaybeShowWelcome() end
    end
end)
