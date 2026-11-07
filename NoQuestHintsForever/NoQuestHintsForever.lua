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
    -- Migrate the preview's inverse, dependent auction exception to an
    -- independent hide flag, preserving the currently effective behavior.
    -- Do this AFTER first-run detection so new defaults don't look like old data.
    if character.hideAuctionSellPrices == nil then
        character.hideAuctionSellPrices = character.hideSellPrices == true
            and character.showAuctionSellPrices == false
    end
    character.showAuctionSellPrices = nil
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
local trackerFrame, trackerAlpha
local trackerInputs = setmetatable({}, { __mode = "k" })
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
        trackerFrame, trackerAlpha = frame, nil
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
        if type(frame.Update) == "function" then
            pcall(hooksecurefunc, frame, "Update", function()
                if character and character.hideTracker and not trackerApplying then queueTrackerUpdate() end
            end)
        end
        trackerHooked = successShow or successAlpha
    end
    return frame
end

local function readInput(node, getter)
    if type(node[getter]) ~= "function" then return nil end
    local ok, value = pcall(node[getter], node)
    if ok and type(value) == "boolean" then return value end
end

local inputProperties = {
    { "click", "IsMouseClickEnabled", "SetMouseClickEnabled" },
    { "motion", "IsMouseMotionEnabled", "SetMouseMotionEnabled" },
    { "wheel", "IsMouseWheelEnabled", "EnableMouseWheel" },
}

local function captureInput(node)
    local state = trackerInputs[node]
    if state then return state end
    state = {}
    if type(node.SetMouseClickEnabled) == "function" and type(node.SetMouseMotionEnabled) == "function" then
        for _, property in ipairs(inputProperties) do
            if type(node[property[3]]) == "function" then state[property[1]] = readInput(node, property[2]) end
        end
    elseif type(node.EnableMouse) == "function" then
        state.mouse = readInput(node, "IsMouseEnabled")
        if type(node.EnableMouseWheel) == "function" then state.wheel = readInput(node, "IsMouseWheelEnabled") end
    end
    if next(state) then trackerInputs[node] = state; return state end
end

local function applyInput(node, state, restoring)
    -- Input changes on protected children may be forbidden during combat.
    -- Keep exact original flags for retry after PLAYER_REGEN_ENABLED.
    if inCombat() then return end
    if state.mouse ~= nil and type(node.EnableMouse) == "function" then
        local target = restoring and state.mouse or false
        local ok = readInput(node, "IsMouseEnabled") == target or pcall(node.EnableMouse, node, target)
        if restoring and ok then state.mouse = nil end
    end
    for _, property in ipairs(inputProperties) do
        local key, getter, setter = unpack(property)
        if state[key] ~= nil and type(node[setter]) == "function" then
            local target = restoring and state[key] or false
            local ok = readInput(node, getter) == target or pcall(node[setter], node, target)
            if restoring and ok then state[key] = nil end
        end
    end
    if restoring and not next(state) then trackerInputs[node] = nil end
end

local function updateTrackerInput(root, hidden)
    local active = {}
    local function visit(node)
        if not node or active[node] then return end
        if type(node.IsForbidden) == "function" then
            local ok, forbidden = pcall(node.IsForbidden, node)
            if not ok or forbidden then return end
        end
        active[node] = true
        if hidden then
            local state = captureInput(node)
            if state then applyInput(node, state, false) end
        end
        if type(node.GetChildren) == "function" then
            local children = { pcall(node.GetChildren, node) }
            if children[1] then for index = 2, #children do visit(children[index]) end end
        end
    end
    if hidden then visit(root) end
    -- Restore detached/reparented pooled children too; never leave them inert.
    for node, state in pairs(trackerInputs) do
        if not hidden or not active[node] then applyInput(node, state, true) end
    end
    if hidden and GameTooltip and type(GameTooltip.GetOwner) == "function" then
        local ok, owner = pcall(GameTooltip.GetOwner, GameTooltip)
        if ok and active[owner] and type(GameTooltip.Hide) == "function" then pcall(GameTooltip.Hide, GameTooltip) end
    end
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
        -- Changing alpha is cosmetic and does not untrack quests.
        if type(frame.GetAlpha) == "function" then
            local ok, current = pcall(frame.GetAlpha, frame)
            if ok and current ~= 0 then pcall(frame.SetAlpha, frame, 0) end
        else
            pcall(frame.SetAlpha, frame, 0)
        end
    else
        if trackerAlpha ~= nil then
            pcall(frame.SetAlpha, frame, trackerAlpha)
            trackerAlpha = nil
        end
    end
    updateTrackerInput(frame, character.hideTracker == true)
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

local function setAuctionSellPriceHidden(hidden)
    if not character then return end
    character.hideAuctionSellPrices = hidden == true
end

local function refreshQuestPresentation()
    if NoQuestHintsForeverAPI and NoQuestHintsForeverAPI.RefreshQuestPresentation then
        NoQuestHintsForeverAPI.RefreshQuestPresentation()
    end
end

local function setQuestLevelsHidden(hidden)
    if not character then return end
    character.hideQuestLevels = hidden == true
    refreshQuestPresentation()
end

local function setQuestDifficultyHidden(hidden)
    if not character then return end
    character.hideQuestDifficulty = hidden == true
    refreshQuestPresentation()
end

local function setQuestItemHighlightHidden(hidden)
    if not character then return end
    character.hideQuestItemHighlight = hidden == true
    if NoQuestHintsForeverAPI.RefreshQuestItemHighlight then
        NoQuestHintsForeverAPI.RefreshQuestItemHighlight()
    end
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
api.IsAuctionSellPriceHidden = function() return character and character.hideAuctionSellPrices == true end
api.IsQuestLevelsHidden = function() return character and character.hideQuestLevels == true end
api.IsQuestDifficultyHidden = function() return character and character.hideQuestDifficulty == true end
api.IsQuestProgressHidden = function() return character and character.hideQuestProgressMessages == true end
api.IsQuestNPCNamesHidden = function() return character and character.hideQuestNPCNames == true end
api.SetMapHidden = setMapHints
api.SetTrackerHidden = setTrackerHidden
api.SetTooltipHintsHidden = setTooltipHintsHidden
api.SetSellPriceHidden = setSellPriceHidden
api.SetAuctionSellPriceHidden = setAuctionSellPriceHidden
api.SetQuestProgressHidden = setQuestProgressHidden
api.SetQuestLevelsHidden = setQuestLevelsHidden
api.SetQuestDifficultyHidden = setQuestDifficultyHidden
api.SetQuestNPCNamesHidden = setQuestNPCNamesHidden
api.IsQuestItemHighlightHidden = function() return character and character.hideQuestItemHighlight == true end
api.SetQuestItemHighlightHidden = setQuestItemHighlightHidden
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
    setAuctionSellPriceHidden(false)
    setQuestProgressHidden(false)
    setQuestLevelsHidden(false)
    setQuestDifficultyHidden(false)
    setQuestItemHighlightHidden(false)
    if api.RefreshOptions then api.RefreshOptions() end
    if api.HideWelcome then api.HideWelcome() end
    local itemsRestored = not api.RestoreQuestItemHighlight or api.RestoreQuestItemHighlight()
    local presentationRestored = not api.RestoreQuestPresentation or api.RestoreQuestPresentation()
    return itemsRestored and presentationRestored and next(character.original) == nil and next(account.original) == nil
        and account.npcNameOriginal == nil and next(trackerInputs) == nil
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
    -- All presets keep auction values visible; strict RP is a separate choice.
    setAuctionSellPriceHidden(false)
    setQuestLevelsHidden(preset == "full")
    setQuestDifficultyHidden(false)
    setQuestItemHighlightHidden(false)
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
    elseif command == "welcome" then
        if type(api.ShowWelcome) == "function" then api.ShowWelcome() end
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
        printMessage((L.AUCTION_PRICE_STATUS or "Hide vendor prices at auction: ") .. (api.IsAuctionSellPriceHidden() and statusOn or statusOff))
        printMessage((L.ITEM_HIGHLIGHT_STATUS or "Hide quest item borders: ") .. (api.IsQuestItemHighlightHidden() and statusOn or statusOff))
        printMessage((L.LEVELS_STATUS or "Hide quest levels: ") .. (api.IsQuestLevelsHidden() and statusOn or statusOff))
        printMessage((L.DIFFICULTY_STATUS or "Hide quest difficulty colors: ") .. (api.IsQuestDifficultyHidden() and statusOn or statusOff))
        printMessage((L.PROGRESS_STATUS or "Hide quest progress popups: ") .. (character.hideQuestProgressMessages == true and statusOn or statusOff))
        for _, name in ipairs(cvars) do
            local value = getCVar(name)
            printMessage(name .. " = " .. (value == nil and (L.VALUE_UNAVAILABLE or "unavailable") or tostring(value)))
        end
    else
        printMessage(L.COMMANDS or "Commands: /nqh, /nqh welcome, /nqh restore, /nqh status")
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
frame:RegisterEvent("QUEST_LOG_UPDATE")
frame:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
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
    elseif event == "QUEST_LOG_UPDATE" or event == "QUEST_WATCH_LIST_CHANGED" then
        if character and character.hideTracker then queueTrackerUpdate() end
    elseif event == "SUPER_TRACKING_CHANGED" then
        -- Never reveal navigation toward a non-permitted quest.
        enforceMapHints()
    elseif event == "PLAYER_REGEN_ENABLED" then
        updateTracker()
        if type(api.MaybeShowWelcome) == "function" then api.MaybeShowWelcome() end
    end
end)
