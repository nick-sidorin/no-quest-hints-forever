-- Selective native Blizzard quest POI icons ("..." / "?") for revealed quests.
-- This data provider is independent from NQH's blue objective-area provider.
-- It uses Blizzard's own QuestPinMixin widgets and initialization sequence
-- instead of inventing textures, locations, click actions or styles.
local api = NoQuestHintsForeverAPI
if not api then return end

local TEMPLATE = "NQHQuestMarkerPinTemplate"
local provider

-- POIButtonUtil.GetStyle and POIButtonMixin:GetQuestClassification populate
-- Blizzard's shared QuestCache. Creating its entries from addon execution
-- taints later native journal/map updates. Read live C APIs instead, and
-- override classification ONLY on widgets created for NQH.
local function readBool(fn, id)
    if type(fn) ~= "function" then return false end
    local ok, value = pcall(fn, id)
    return ok and value == true
end

function api.GetQuestPOIStyle(id)
    local styles = POIButtonUtil and POIButtonUtil.Style
    if not styles then return end
    local log = C_QuestLog or {}
    if readBool(log.IsComplete or log.ReadyForTurnIn, id) then return styles.QuestComplete end
    if readBool(log.IsQuestDisabledForSession, id) then return styles.QuestDisabled end
    return styles.QuestInProgress
end

local function getQuestClassification(self)
    local id = self:GetQuestID()
    local fn = C_QuestInfoSystem and C_QuestInfoSystem.GetQuestClassification
    if id and type(fn) == "function" then return fn(id) end
end

function api.ConfigureQuestPOI(button)
    button.GetQuestClassification = getQuestClassification
end

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
    -- Do not seed Blizzard's shared Lua map-query cache from addon code.
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
    if not api.IsMapHidden or api.IsMapHidden() ~= true then return end
    local hasRevealedQuest = false
    local db = NoQuestHintsForeverChar
    local list = type(db) == "table" and db.revealedQuests
    for id, enabled in pairs(type(list) == "table" and list or {}) do
        if enabled == true and permitted(id) then hasRevealedQuest = true; break end
    end
    -- Leave native map provider/pin pools alone while this layer is unused.
    if not hasRevealedQuest then return end

    local candidate = CreateFromMixins(QuestDataProviderMixin)
    function candidate:GetPinTemplate() return TEMPLATE end

    -- Same native widgets/initialization as QuestDataProviderMixin:AddQuest,
    -- with cache-free style/classification reads on this unique pin template.
    function candidate:AddQuest(id, x, y, offset, waypoint)
        local pin = self:GetMap():AcquirePin(TEMPLATE)
        api.ConfigureQuestPOI(pin)
        pin:SetQuestID(id)
        pin.dataProvider = self
        local tracked = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID
            and C_SuperTrack.GetSuperTrackedQuestID() == id or false
        pin.isSuperTracked = tracked
        if tracked then
            pin:UseFrameLevelType("PIN_FRAME_LEVEL_SUPER_TRACKED_QUEST")
        else
            pin:UseFrameLevelType("PIN_FRAME_LEVEL_ACTIVE_QUEST", offset)
        end
        pin.Display:ClearAllPoints()
        pin.Display:SetPoint("CENTER")
        pin:SetSelected(tracked)
        pin:SetStyle(waypoint and POIButtonUtil.Style.Waypoint or api.GetQuestPOIStyle(id))
        pin:UpdateButtonStyle()
        pin:EvaluateManagedHighlight()
        if type(MapPinHighlight_CheckHighlightPin) == "function" then
            MapPinHighlight_CheckHighlightPin(pin:GetHighlightType(), pin, pin.NormalTexture)
        end
        pin:SetPosition(x, y)
        return pin
    end

    -- Do not call QuestDataProviderMixin.OnAdded: it builds a quantizer
    -- intended for the full, global quest set. We display only a few pins.
    function candidate:OnAdded(map)
        MapCanvasDataProviderMixin.OnAdded(self, map)
        self:RefreshAllData()
    end
    function candidate:OnShow() self:RefreshAllData() end
    function candidate:OnMapChanged() self:RefreshAllData() end
    function candidate:OnCanvasSizeChanged() end

    function candidate:RemoveAllData()
        self.snapshot = nil
        -- Unique template: never release Blizzard's own pins.
        QuestDataProviderMixin.RemoveAllData(self)
    end

    function candidate:RefreshAllData()
        if not api.IsMapHidden or api.IsMapHidden() ~= true then
            self:RemoveAllData()
            return
        end
        local map = self:GetMap()
        local mapID = map and map.GetMapID and map:GetMapID()
        if not mapID then self:RemoveAllData(); return end
        local seen, entries = {}, {}
        local function add(id, x, y, waypoint)
            local style = api.GetQuestPOIStyle(id)
            local tracked = C_SuperTrack and type(C_SuperTrack.GetSuperTrackedQuestID) == "function"
                and C_SuperTrack.GetSuperTrackedQuestID() == id or false
            entries[#entries + 1] = {id=id, x=x, y=y, waypoint=waypoint, style=style, tracked=tracked}
            seen[id] = true
        end
        for _, list in ipairs(getMapQuestInfo(mapID)) do
            for _, info in ipairs(list) do
                local id = info.questID
                if permitted(id) and not seen[id]
                    and validPosition(info.x, info.y) then
                    add(id, info.x, info.y, false)
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
                        add(id, x, y, true)
                    end
                end
            end
        end
        -- Repeated quest events (including header expansion on hover) need not
        -- recycle the same map pins and trigger new enter/leave transitions.
        table.sort(entries, function(a, b) return a.id < b.id end)
        local old = self.snapshot
        local unchanged = old and old.mapID == mapID and #old.entries == #entries
        if unchanged then
            for index, entry in ipairs(entries) do
                local previous = old.entries[index]
                for _, key in ipairs({ "id", "x", "y", "waypoint", "style", "tracked" }) do
                    if entry[key] ~= previous[key] then unchanged = false; break end
                end
                if not unchanged then break end
            end
        end
        if unchanged then return end
        self:RemoveAllData()
        for index, entry in ipairs(entries) do
            -- Keep the genuine native hover/click scripts and tooltip renderer.
            local pin = self:AddQuest(entry.id, entry.x, entry.y, index, entry.waypoint)
            if pin then
                -- Forever assigns OnMouseEnter as the periodic tooltip callback.
                -- That also emits MapCanvas.QuestPin.OnEnter, rebuilding/scrolling
                -- the entire journal on every tooltip tick. Our unique pins show
                -- fresh native tooltip content on real entry instead.
                pin.UpdateTooltip = nil
            end
        end
        self.snapshot = {mapID=mapID, entries=entries}
    end

    local ok = pcall(WorldMapFrame.AddDataProvider, WorldMapFrame, candidate)
    if ok then
        provider = candidate
        pcall(candidate.RefreshAllData, candidate)
    end
end

function api.RefreshQuestMarkers()
    installProvider()
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
events:RegisterEvent("SUPER_TRACKING_CHANGED")
events:SetScript("OnEvent", function(_, event)
    if event == "ADDON_LOADED" or event == "PLAYER_LOGIN"
        or event == "PLAYER_ENTERING_WORLD" then
        installProvider()
    elseif event == "QUEST_LOG_UPDATE" or event == "QUEST_POI_UPDATE"
        or event == "SUPER_TRACKING_CHANGED" then
        api.RefreshQuestMarkers()
    end
end)
