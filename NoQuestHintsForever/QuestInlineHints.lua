-- Quest POI icons *next to quest names*, using original Blizzard widgets.
-- Never force quest-watch entries into the objective tracker. The right-hand
-- tracker remains controlled by the separate Hide Objective Tracker option.
local api = NoQuestHintsForeverAPI
if not api then return end

local journalHooked, blockHooked = false, false
local refreshingJournal, refreshingTracker = false, false
local queued = {}

local function shouldShow(questID)
    return type(api.IsMapHidden) == "function" and api.IsMapHidden() == true
        and type(api.IsQuestRevealed) == "function" and api.IsQuestRevealed(questID)
end

-- WoW's journal normally calls GetButtonForQuest(), which refuses to create
-- any POI icon when questPOI=0. Use the exact same pooled Blizzard POIButton
-- through its lower-level method, but ONLY for whitelisted quest IDs.
local function updateJournalIcons()
    if not api.IsMapHidden or api.IsMapHidden() ~= true then return end
    if not QuestScrollFrame or not QuestScrollFrame.titleFramePool
        or not QuestScrollFrame.Contents or not POIButtonUtil then return end

    local owner = QuestScrollFrame.Contents
    if type(owner.GetButtonForQuestInternal) ~= "function"
        or type(owner.PostInitButtonInternal) ~= "function"
        or type(owner.FindButtonByQuestID) ~= "function" then return end

    for button in QuestScrollFrame.titleFramePool:EnumerateActive() do
        local questID = button and button.questID
        if shouldShow(questID) and not owner:FindButtonByQuestID(questID) then
            local okStyle, style = pcall(POIButtonUtil.GetStyle, questID)
            if okStyle and style then
                local ok, icon = pcall(owner.GetButtonForQuestInternal, owner, questID, style)
                if ok and icon then
                    pcall(owner.PostInitButtonInternal, owner, icon)
                    if type(icon.ClearAllPoints) == "function" then icon:ClearAllPoints() end
                    if type(icon.SetPoint) == "function" then
                        icon:SetPoint("TOPLEFT", button, 6, -4)
                    end
                    icon.parent = button
                end
            end
        end
    end
end

local function refreshJournal()
    if refreshingJournal then return end
    if not QuestScrollFrame or not QuestMapFrame then return end
    if type(QuestLogQuests_Update) ~= "function" then return end
    -- Full native rebuild releases old pooled icons when a quest is hidden.
    -- The secure post-hook then restores only the permitted quest icons.
    refreshingJournal = true
    pcall(QuestLogQuests_Update)
    refreshingJournal = false
end

local function safeBool(func, id)
    if type(func) ~= "function" then return false end
    local ok, value = pcall(func, id)
    return ok and value == true
end

local function applyTrackerIcon(block)
    if not block or not api.IsMapHidden or api.IsMapHidden() ~= true then return end
    -- The native OnLayout() releases its POI under questPOI=0. That may
    -- clear poiQuestID entirely, so recover the quest from the active block.
    local id = block.id
    if type(id) ~= "number" or id <= 0 then return end
    if shouldShow(id) then
        if not block.poiButton and type(block.AddPOIButton) == "function" then
            if not block.poiQuestID and type(block.SetPOIInfo) == "function" then
                local ready = C_QuestLog and safeBool(C_QuestLog.ReadyForTurnIn, id)
                local worldQuest = C_QuestLog and safeBool(C_QuestLog.IsWorldQuest, id)
                local isSuperTracked = C_SuperTrack
                    and type(C_SuperTrack.GetSuperTrackedQuestID) == "function"
                    and C_SuperTrack.GetSuperTrackedQuestID() == id
                pcall(block.SetPOIInfo, block, id, ready == true, isSuperTracked == true, worldQuest == true)
            end
            -- Original Blizzard method sets QuestInProgress / QuestComplete
            -- and anchors the native POI directly beside the header.
            if block.poiQuestID then pcall(block.AddPOIButton, block) end
        end
    elseif block.poiButton and type(block.CheckAndReleasePOIButton) == "function" then
        pcall(block.CheckAndReleasePOIButton, block)
    end
end

local function refreshTracker()
    if refreshingTracker then return end
    if not QuestObjectiveTracker or type(QuestObjectiveTracker.usedBlocks) ~= "table" then return end
    refreshingTracker = true
    for _, blocks in pairs(QuestObjectiveTracker.usedBlocks) do
        for _, block in pairs(blocks) do
            applyTrackerIcon(block)
        end
    end
    refreshingTracker = false
end

local function queueTrackerBlock(block)
    if not block or block.parentModule ~= QuestObjectiveTracker or queued[block] then return end
    if C_Timer and type(C_Timer.After) == "function" then
        queued[block] = true
        C_Timer.After(0, function()
            queued[block] = nil
            if type(InCombatLockdown) ~= "function" or not InCombatLockdown() then
                applyTrackerIcon(block)
            end
        end)
    else
        -- Older or mocked clients without the timer API.
        applyTrackerIcon(block)
    end
end

local function installHooks()
    if not journalHooked and type(QuestLogQuests_Update) == "function"
        and type(hooksecurefunc) == "function" then
        journalHooked = pcall(hooksecurefunc, "QuestLogQuests_Update", updateJournalIcons)
    end
    if not blockHooked and type(ObjectiveTrackerQuestPOIBlockMixin) == "table"
        and type(ObjectiveTrackerQuestPOIBlockMixin.OnLayout) == "function"
        and type(hooksecurefunc) == "function" then
        -- Never mutate Blizzard's tracked block inside a secure layout hook.
        blockHooked = pcall(hooksecurefunc, ObjectiveTrackerQuestPOIBlockMixin,
            "OnLayout", queueTrackerBlock)
    end
end

function api.RefreshQuestInlineHints()
    installHooks()
    refreshJournal()
    refreshTracker()
    if QuestObjectiveTracker and type(QuestObjectiveTracker.MarkDirty) == "function" then
        -- Blizzard will repopulate block.poiQuestID on the next refresh
        -- even if CheckAndReleasePOIButton() cleared it when hiding.
        pcall(QuestObjectiveTracker.MarkDirty, QuestObjectiveTracker)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        refreshTracker()
    else
        installHooks()
        if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
            updateJournalIcons()
            refreshTracker()
        end
    end
end)
