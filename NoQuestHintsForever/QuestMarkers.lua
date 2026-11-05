-- Selective native Blizzard quest POI icons ("..." / "?") for revealed quests.
-- This data provider is independent from NQH's blue objective-area provider.
-- It uses Blizzard's own QuestPinMixin/QuestDataProviderMixin:AddQuest()
-- instead of inventing textures, locations, click actions or styles.
local api = NoQuestHintsForeverAPI
if not api then return end

local TEMPLATE = "NQHQuestMarkerPinTemplate"
local provider

local function permitted(questID)
    return type(questID) == "number"
        and type(api.IsQuestRevealed) == "function"
        and api.IsQuestRevealed(questID)
end

local function validPosition(x, y)
    return type(x) == "number" and type(y) == "number"
        and x >= 0 and y >= 0 and x <= 1 and y <= 1
end

local function getMapQuestInfo(mapID)
    local sources = {}
    -- The native cached query is what Blizzard QuestDataProvider uses.
    if type(GetQuestsOnMapCached) == "function" then
        local ok, list = pcall(GetQuestsOnMapCached, mapID)
        if ok and type(list) == "table" then sources[#sources + 1] = list end
    end
    -- Some Forever clients return POI results via C_QuestLog instead.
    if C_QuestLog and type(C_QuestLog.GetQuestsOnMap) == "function" then
        local ok, list = pcall(C_QuestLog.GetQuestsOnMap, mapID)
        if ok and type(list) == "table" then sources[#sources + 1] = list end
    end
    return sources
end

local function installProvider()
    if provider or not WorldMapFrame or not QuestDataProviderMixin
        or not MapCanvasDataProviderMixin or not CreateFromMixins
        or type(WorldMapFrame.AddDataProvider) ~= "function" then return end

    local candidate = CreateFromMixins(QuestDataProviderMixin)
    function candidate:GetPinTemplate() return TEMPLATE end

    -- Do not call QuestDataProviderMixin.OnAdded: it builds a quantizer
    -- intended for the full, global quest set. We display only a few pins.
    function candidate:OnAdded(map)
        MapCanvasDataProviderMixin.OnAdded(self, map)
        self:RefreshAllData()
    end
    function candidate:OnShow() self:RefreshAllData() end
    function candidate:OnMapChanged() self:RefreshAllData() end
    function candidate:OnCanvasSizeChanged() end

    function candidate:RefreshAllData()
        self:RemoveAllData() -- unique pin template: never removes Blizzard's pins
        if not api.IsMapHidden or api.IsMapHidden() ~= true then return end
        local map = self:GetMap()
        local mapID = map and map.GetMapID and map:GetMapID()
        if not mapID then return end
        local seen, count = {}, 0
        for _, list in ipairs(getMapQuestInfo(mapID)) do
            for _, info in ipairs(list) do
                local id = info.questID
                if permitted(id) and not seen[id]
                    and validPosition(info.x, info.y) then
                    count = count + 1
                    -- Native GetStyle(questID) supplies the in-progress / turn-in
                    -- punctuation; these markers remain clickable like Blizzard's.
                    self:AddQuest(id, info.x, info.y, count, false)
                    seen[id] = true
                end
            end
        end
        -- A small number of quests supply only the next waypoint.
        -- Do not guess a location for quests lacking map data.
        if C_QuestLog and type(C_QuestLog.GetNextWaypointForMap) == "function"
            and type(NoQuestHintsForeverChar) == "table"
            and type(NoQuestHintsForeverChar.revealedQuests) == "table" then
            for id, enabled in pairs(NoQuestHintsForeverChar.revealedQuests) do
                if enabled and permitted(id) and not seen[id] then
                    local ok, x, y = pcall(C_QuestLog.GetNextWaypointForMap, id, mapID)
                    if ok and validPosition(x, y) then
                        count = count + 1
                        self:AddQuest(id, x, y, count, true)
                        seen[id] = true
                    end
                end
            end
        end
    end

    local ok = pcall(WorldMapFrame.AddDataProvider, WorldMapFrame, candidate)
    if ok then
        provider = candidate
        pcall(candidate.RefreshAllData, candidate)
    end
end

function api.RefreshQuestMarkers()
    if provider and type(provider.RefreshAllData) == "function" then
        pcall(provider.RefreshAllData, provider)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("QUEST_POI_UPDATE")
events:SetScript("OnEvent", function(_, event)
    if event == "ADDON_LOADED" or event == "PLAYER_LOGIN"
        or event == "PLAYER_ENTERING_WORLD" then
        installProvider()
    elseif event == "QUEST_LOG_UPDATE" or event == "QUEST_POI_UPDATE" then
        api.RefreshQuestMarkers()
    end
end)
