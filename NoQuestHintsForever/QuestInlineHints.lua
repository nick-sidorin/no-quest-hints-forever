-- Quest POI icons *next to quest names*, using original Blizzard widgets.
-- Never force quest-watch entries into the objective tracker. The right-hand
-- tracker remains controlled by the separate Hide Objective Tracker option.
local api = NoQuestHintsForeverAPI
if not api then return end

local journalHooked, blockHooked, freeHooked = false, false, false
local refreshingTracker = false
local journalIcons, trackerIcons = {}, {}
local queued = {}

local function shouldShow(questID)
    return type(api.IsMapHidden) == "function" and api.IsMapHidden() == true
        and type(api.IsQuestRevealed) == "function" and api.IsQuestRevealed(questID)
end

-- Own the native-template widgets instead of borrowing Blizzard's pools.
-- A native rebuild from addon code seeds shared QuestCache entries for every
-- row, even with questPOI=0. Reconcile only our own badges here.
local function inCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function hideIcon(icon)
    if icon then icon:Hide() end
end

local function iconFor(icons, owner, template)
    local icon = icons[owner]
    if not icon and type(api.ConfigureQuestPOI) == "function" then
        local ok, frame = pcall(CreateFrame, "Button", nil, owner, template)
        if not ok or not frame then return end
        api.ConfigureQuestPOI(frame)
        icon = frame
        icons[owner] = icon
    end
    return icon
end

local function updateIcon(icon, id, style)
    if not icon or not style then return end
    icon:SetQuestID(id)
    icon:SetStyle(style)
    local styles = POIButtonUtil and POIButtonUtil.Style
    if type(icon.SetEnabled) == "function" then
        icon:SetEnabled(not styles or style ~= styles.QuestDisabled)
    end
    local tracked = C_SuperTrack and type(C_SuperTrack.GetSuperTrackedQuestID) == "function"
        and C_SuperTrack.GetSuperTrackedQuestID() == id or false
    icon:SetSelected(tracked)
    icon:UpdateButtonStyle()
    icon:Show()
end

local function updateJournalIcons()
    if inCombat() then return end
    local seen = {}
    local scroll = QuestScrollFrame
    local owner = scroll and scroll.Contents
    if scroll and scroll.titleFramePool and owner then
        for row in scroll.titleFramePool:EnumerateActive() do
            local id = row and row.questID
            seen[row] = true
            -- Native icons win when the native UI already supplies this row.
            local native = type(owner.FindButtonByQuestID) == "function"
                and owner:FindButtonByQuestID(id)
            if shouldShow(id) and not native and api.GetQuestPOIStyle then
                local icon = iconFor(journalIcons, row, "POIButtonTemplate")
                if icon then
                    icon.smartNavigationIgnored = true
                    icon.parent = row
                    icon:ClearAllPoints()
                    icon:SetPoint("TOPLEFT", row, 6, -4)
                    updateIcon(icon, id, api.GetQuestPOIStyle(id))
                end
            else
                hideIcon(journalIcons[row])
            end
        end
    end
    for row, icon in pairs(journalIcons) do
        if not seen[row] then hideIcon(icon) end
    end
end

local function applyTrackerIcon(block)
    if not block or inCombat() then return end
    local id = block.id
    if block.parentModule == QuestObjectiveTracker and type(id) == "number" and id > 0 and shouldShow(id)
        and not block.poiButton and block.HeaderText and api.GetQuestPOIStyle then
        local icon = iconFor(trackerIcons, block, "ObjectiveTrackerPOIButtonTemplate")
        if icon then
            icon:ClearAllPoints()
            icon:SetPoint("TOPRIGHT", block.HeaderText, "TOPLEFT", -7, 5)
            -- Only our own button state changes; do not alter native POI data,
            -- block ownership, watch lists or Blizzard's shared frame pools.
            local styles = POIButtonUtil and POIButtonUtil.Style
            local world = C_QuestLog and C_QuestLog.IsWorldQuest
            local style = type(world) == "function" and world(id) and styles and styles.WorldQuest
                or api.GetQuestPOIStyle(id)
            updateIcon(icon, id, style)
        end
    else
        hideIcon(trackerIcons[block])
    end
end

local function refreshTracker()
    if refreshingTracker then return end
    refreshingTracker = true
    local seen = {}
    local used = QuestObjectiveTracker and QuestObjectiveTracker.usedBlocks
    for _, blocks in pairs(type(used) == "table" and used or {}) do
        for _, block in pairs(blocks) do
            seen[block] = true
            applyTrackerIcon(block)
        end
    end
    if not inCombat() then
        for block, icon in pairs(trackerIcons) do
            if not seen[block] then hideIcon(icon) end
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
    if not freeHooked and type(ObjectiveTrackerQuestPOIBlockMixin) == "table"
        and type(ObjectiveTrackerQuestPOIBlockMixin.Free) == "function"
        and type(hooksecurefunc) == "function" then
        freeHooked = pcall(hooksecurefunc, ObjectiveTrackerQuestPOIBlockMixin, "Free", function(block)
            if not inCombat() then hideIcon(trackerIcons[block]) end
        end)
    end
end

function api.RefreshQuestInlineHints()
    installHooks()
    updateJournalIcons()
    refreshTracker()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        updateJournalIcons()
        refreshTracker()
    else
        installHooks()
        if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
            updateJournalIcons()
            refreshTracker()
        end
    end
end)
