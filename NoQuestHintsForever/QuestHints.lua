-- Opt-in quest hints on the world map, independent of Blizzard's quest watch.
-- Blizzard map markers remain globally suppressed while our map-hint option is ON.
-- Only quests explicitly chosen by this character get a small custom map pin.
local api = NoQuestHintsForeverAPI
if not api then return end

local PIN_TEMPLATE = "NQHQuestHintPinTemplate"
local provider
local journalButtons = {}
local hookedDetails, hookedPopup = false, false

local function allowed()
    local db = NoQuestHintsForeverChar
    if type(db) ~= "table" then return nil end
    if type(db.revealedQuests) ~= "table" then db.revealedQuests = {} end
    return db.revealedQuests
end

local function validQuestID(questID)
    return type(questID) == "number" and questID > 0 and questID % 1 == 0
end

local function isRevealed(questID)
    local list = allowed()
    return list and validQuestID(questID) and list[questID] == true or false
end

local function refreshMap()
    if provider and type(provider.RefreshAllData) == "function" then
        -- Map may not have finished loading yet.
        pcall(provider.RefreshAllData, provider)
    end
end

local function updateButtons()
    for _, item in ipairs(journalButtons) do
        local details = item.details
        local button = item.button
        local questID = details and details.questID
        if validQuestID(questID) and (not details.IsShown or details:IsShown()) then
            button:SetText(isRevealed(questID) and "Hide map hint" or "Show map hint")
            button:Show()
        else
            button:Hide()
        end
    end
end

local function setRevealed(questID, reveal)
    if not validQuestID(questID) then return false end
    local list = allowed()
    if not list then return false end
    if reveal then list[questID] = true else list[questID] = nil end
    updateButtons()
    refreshMap()
    return true
end

api.IsQuestRevealed = isRevealed
api.SetQuestRevealed = setRevealed
api.RefreshQuestHintPins = refreshMap

-- Map canvas pin: one lightweight icon and a quest-name tooltip.
if type(CreateFromMixins) == "function" and type(MapCanvasPinMixin) == "table" then
    NQHQuestHintPinMixin = CreateFromMixins(MapCanvasPinMixin)
    function NQHQuestHintPinMixin:OnLoad()
        if self.UseFrameLevelType then self:UseFrameLevelType("PIN_FRAME_LEVEL_TOPMOST") end
    end
    function NQHQuestHintPinMixin:OnAcquired(questID, x, y)
        self.questID = questID
        self:SetPosition(x, y)
    end
    function NQHQuestHintPinMixin:OnReleased()
        self.questID = nil
    end
    function NQHQuestHintPinMixin:OnMouseEnter()
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local title
        if C_QuestLog and type(C_QuestLog.GetTitleForQuestID) == "function" then
            local ok, value = pcall(C_QuestLog.GetTitleForQuestID, self.questID)
            if ok then title = value end
        end
        GameTooltip:SetText(title or ("Quest " .. tostring(self.questID)))
        GameTooltip:AddLine("Shown by No Quest Hints", 0.9, 0.8, 0.4)
        GameTooltip:Show()
    end
    function NQHQuestHintPinMixin:OnMouseLeave()
        if GameTooltip then GameTooltip:Hide() end
    end
end

local function getMapQuests(mapID)
    if C_QuestLog and type(C_QuestLog.GetQuestsOnMap) == "function" then
        local ok, quests = pcall(C_QuestLog.GetQuestsOnMap, mapID)
        if ok and type(quests) == "table" then return quests end
    end
    if type(GetQuestsOnMapCached) == "function" then
        local ok, quests = pcall(GetQuestsOnMapCached, mapID)
        if ok and type(quests) == "table" then return quests end
    end
    return {}
end

local function nextWaypoint(questID, mapID)
    if C_QuestLog and type(C_QuestLog.GetNextWaypointForMap) == "function" then
        local ok, x, y = pcall(C_QuestLog.GetNextWaypointForMap, questID, mapID)
        if ok then return x, y end
    end
end

local function coordinate(value)
    return type(value) == "number" and value >= 0 and value <= 1
end

if type(CreateFromMixins) == "function" and type(MapCanvasDataProviderMixin) == "table" then
    NQHQuestHintDataProviderMixin = CreateFromMixins(MapCanvasDataProviderMixin)
    function NQHQuestHintDataProviderMixin:RemoveAllData()
        local map = self:GetMap()
        if map then map:RemoveAllPinsByTemplate(PIN_TEMPLATE) end
    end
    function NQHQuestHintDataProviderMixin:RefreshAllData()
        self:RemoveAllData()
        if api.IsMapHidden() ~= true then return end
        local list = allowed()
        if not list or not next(list) then return end
        local map = self:GetMap()
        if not map or not map.GetMapID or not map.AcquirePin then return end
        local mapID = map:GetMapID()
        if not mapID then return end

        local drawn = {}
        local mapQuests = getMapQuests(mapID)
        for _, info in ipairs(mapQuests) do
            local questID = info.questID
            if isRevealed(questID) and not drawn[questID]
                and coordinate(info.x) and coordinate(info.y) then
                map:AcquirePin(PIN_TEMPLATE, questID, info.x, info.y)
                drawn[questID] = true
            end
        end
        -- Some quests have only a waypoint, and aren't in GetQuestsOnMap.
        for questID, reveal in pairs(list) do
            if reveal == true and validQuestID(questID) and not drawn[questID] then
                local x, y = nextWaypoint(questID, mapID)
                if coordinate(x) and coordinate(y) then
                    map:AcquirePin(PIN_TEMPLATE, questID, x, y)
                end
            end
        end
    end
end

local function installProvider()
    if provider or not NQHQuestHintDataProviderMixin or not NQHQuestHintPinMixin then return end
    if not WorldMapFrame or type(WorldMapFrame.AddDataProvider) ~= "function" then return end
    local candidate = CreateFromMixins(NQHQuestHintDataProviderMixin)
    local ok = pcall(WorldMapFrame.AddDataProvider, WorldMapFrame, candidate)
    if ok then provider = candidate end
end

local function createJournalButton(details)
    if not details or not details.CreateFontString then return end
    if not details.questID and not details.TrackButton then return end

    local button = CreateFrame("Button", nil, details, "UIPanelButtonTemplate")
    button:SetSize(136, 23)
    -- Top band: do not overlap Blizzard's bottom row of Track/Share buttons.
    button:SetPoint("TOPRIGHT", details, "TOPRIGHT", -8, -7)
    button:SetText("Show map hint")
    button:SetScript("OnClick", function()
        local questID = details.questID
        if validQuestID(questID) then setRevealed(questID, not isRevealed(questID)) end
    end)
    journalButtons[#journalButtons + 1] = {details = details, button = button}
    if type(details.HookScript) == "function" then
        details:HookScript("OnShow", updateButtons)
        details:HookScript("OnHide", updateButtons)
    end
    updateButtons()
end

local function installJournal()
    if QuestMapFrame and QuestMapFrame.DetailsFrame and not hookedDetails then
        hookedDetails = true
        createJournalButton(QuestMapFrame.DetailsFrame)
    end
    if type(QuestMapFrame_ShowQuestDetails) == "function" and not api.detailHooked
        and type(hooksecurefunc) == "function" then
        local ok = pcall(hooksecurefunc, "QuestMapFrame_ShowQuestDetails", updateButtons)
        if ok then api.detailHooked = true end
    end
    if QuestLogPopupDetailFrame and not hookedPopup then
        hookedPopup = true
        createJournalButton(QuestLogPopupDetailFrame)
        if type(hooksecurefunc) == "function" and type(QuestLogPopupDetailFrame.ShowQuest) == "function" then
            pcall(hooksecurefunc, QuestLogPopupDetailFrame, "ShowQuest", updateButtons)
        end
    end
end

local lifecycle = CreateFrame("Frame")
lifecycle:RegisterEvent("ADDON_LOADED")
lifecycle:RegisterEvent("PLAYER_LOGIN")
lifecycle:RegisterEvent("QUEST_LOG_UPDATE")
lifecycle:RegisterEvent("QUEST_POI_UPDATE")
lifecycle:SetScript("OnEvent", function(_, event)
    if event == "ADDON_LOADED" or event == "PLAYER_LOGIN" then
        installProvider()
        installJournal()
    elseif event == "QUEST_LOG_UPDATE" then
        updateButtons()
        refreshMap()
    elseif event == "QUEST_POI_UPDATE" then
        refreshMap()
    end
end)
