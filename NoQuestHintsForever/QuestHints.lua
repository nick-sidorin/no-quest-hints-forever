-- No Quest Hints: selectively reveal Blizzard's *native* quest objective blobs.
-- This intentionally does NOT change the game's watch list or questPOI CVar.
local api = NoQuestHintsForeverAPI
if not api then return end
local L = NoQuestHintsForeverLocale or {}

local PIN_TEMPLATE = "NQHQuestBlobPinTemplate"
-- The XML template is parsed after this Lua file; the original Blizzard
-- QuestBlobPinMixin may load later with Blizzard_SharedMapDataProviders.
NQHQuestBlobPinMixin = NQHQuestBlobPinMixin or {}

local provider, pinMixinReady, menusInstalled = nil, false, false
local journalButtons = {}
local journalHooked, popupHooked, selectedHooked = false, false, false

local function validQuestID(id)
    return type(id) == "number" and id > 0 and id % 1 == 0
end

local function allowed()
    if type(NoQuestHintsForeverChar) ~= "table" then return nil end
    local db = NoQuestHintsForeverChar
    if type(db.revealedQuests) ~= "table" then db.revealedQuests = {} end
    return db.revealedQuests
end

local function isRevealed(id)
    local list = allowed()
    return list ~= nil and validQuestID(id) and list[id] == true or false
end

local function refreshMap()
    if provider and provider.pin and type(provider.pin.Refresh) == "function" then
        -- Use a protected refresh while the map changes/loads.
        pcall(provider.pin.Refresh, provider.pin)
    end
    if type(api.RefreshQuestMarkers) == "function" then
        api.RefreshQuestMarkers()
    end
    if type(api.RefreshQuestInlineHints) == "function" then
        api.RefreshQuestInlineHints()
    end
end

local function updateJournalButtons()
    for _, entry in ipairs(journalButtons) do
        local id = entry.details.questID
        if validQuestID(id) then
            entry.button:SetText(isRevealed(id)
                and (L.HIDE_HINT_BUTTON or "Hide hint")
                or (L.SHOW_HINT_BUTTON or "Show hint"))
            entry.button:Show()
        else
            entry.button:Hide()
        end
    end
end

local function setRevealed(id, value)
    local list = allowed()
    if not list or not validQuestID(id) then return false end
    if value then
        list[id] = true
        -- Point Blizzard's native in-world diamond at this quest.
        -- SuperTrack is distinct from adding it to the objective watch list.
        if api.IsMapHidden() and C_SuperTrack
            and type(C_SuperTrack.SetSuperTrackedQuestID) == "function" then
            pcall(C_SuperTrack.SetSuperTrackedQuestID, id)
        end
    else
        list[id] = nil
    end
    updateJournalButtons()
    refreshMap()
    if type(api.RefreshNavigation) == "function" then
        api.RefreshNavigation()
    end
    return true
end

function api.IsQuestNavigationAllowed()
    if not C_SuperTrack or type(C_SuperTrack.GetSuperTrackedQuestID) ~= "function" then
        return false
    end
    if type(C_SuperTrack.IsSuperTrackingQuest) == "function" then
        local ok, active = pcall(C_SuperTrack.IsSuperTrackingQuest)
        if ok and active ~= true then return false end
    end
    local ok, id = pcall(C_SuperTrack.GetSuperTrackedQuestID)
    return ok and isRevealed(id) or false
end

api.IsQuestRevealed = isRevealed
api.SetQuestRevealed = setRevealed
-- Preserve the existing callback used by the map hints checkbox.
api.RefreshQuestHintPins = refreshMap

local function createJournalButton(details)
    if not details or not details.TrackButton then return end
    local button = CreateFrame("Button", nil, details, "UIPanelButtonTemplate")
    -- Use the real Blizzard Back button as our anchor when present.
    -- This is the same vertical centerline even if UI scaling changes.
    button:SetSize(94, 22)
    local backButton = details.BackFrame and details.BackFrame.BackButton
    if backButton then
        button:SetPoint("LEFT", backButton, "RIGHT", 10, 0)
    elseif details.ShowMapButton then
        -- Separate popup quest journal: stay beside the Show Map control.
        button:SetPoint("RIGHT", details.ShowMapButton, "LEFT", -10, 0)
    else
        button:SetPoint("TOPLEFT", details, "TOPLEFT", 105, -20)
    end
    button:SetText(L.SHOW_HINT_BUTTON or "Show hint")
    button:SetScript("OnClick", function()
        local id = details.questID
        if validQuestID(id) then setRevealed(id, not isRevealed(id)) end
    end)
    if type(button.SetScript) == "function" then
        button:SetScript("OnEnter", function(self)
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L.HINT_TOOLTIP or "Show or hide this quest's map area")
                GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)
    end
    table.insert(journalButtons, {details=details, button=button})
    updateJournalButtons()
end

local trackerContextQuestID
local trackerHeaderHooked, trackerClicksHooked = false, false

local function addMenuOption(owner, root)
    local id = owner and owner.questID
    if not validQuestID(id) then return end
    root:CreateDivider()
    root:CreateButton(isRevealed(id)
        and (L.HIDE_HINT or "Hide hint")
        or (L.SHOW_HINT or "Show hint"), function()
        -- Menus change only the permission, never open the world map.
        setRevealed(id, not isRevealed(id))
    end)
end

-- Unlike quest-journal menu tags, MENU_QUEST_OBJECTIVE_TRACKER does not
-- pass its questID to Menu.ModifyMenu. Capture the right-click on the
-- original header's MouseDown *before* Blizzard creates the popup.
-- HookScript/hooksecurefunc preserve the original Blizzard callbacks.
local function captureTrackerMouseDown(button, mouseButton)
    trackerContextQuestID = nil
    if mouseButton ~= "RightButton" or not button then return end
    local block = button:GetParent()
    if block and block.parentModule == QuestObjectiveTracker and validQuestID(block.id) then
        trackerContextQuestID = block.id
    end
end

local function hookTrackerHeader(button)
    if not button or button.nqhMouseHooked or type(button.HookScript) ~= "function" then return end
    button:HookScript("OnMouseDown", captureTrackerMouseDown)
    button.nqhMouseHooked = true
end

local function hookExistingTrackerHeaders()
    if not QuestObjectiveTracker or type(QuestObjectiveTracker.usedBlocks) ~= "table" then return end
    for _, blocks in pairs(QuestObjectiveTracker.usedBlocks) do
        for _, block in pairs(blocks) do
            hookTrackerHeader(block.HeaderButton)
        end
    end
end

local function installTrackerHooks()
    if not trackerHeaderHooked and type(ObjectiveTrackerBlockHeaderMixin) == "table"
        and type(ObjectiveTrackerBlockHeaderMixin.OnLoad) == "function"
        and type(hooksecurefunc) == "function" then
        trackerHeaderHooked = pcall(hooksecurefunc, ObjectiveTrackerBlockHeaderMixin,
            "OnLoad", hookTrackerHeader)
    end
    if not trackerClicksHooked and type(ObjectiveTrackerBlockHeaderMixin) == "table"
        and type(ObjectiveTrackerBlockHeaderMixin.OnClick) == "function"
        and type(hooksecurefunc) == "function" then
        -- Do not leave stale IDs for a later menu, even if a modified click
        -- did not create a context menu.
        trackerClicksHooked = pcall(hooksecurefunc, ObjectiveTrackerBlockHeaderMixin,
            "OnClick", function() trackerContextQuestID = nil end)
    end
    hookExistingTrackerHeaders()
end

local function addTrackerMenuOption(_, root)
    local id = trackerContextQuestID
    if not validQuestID(id) then return end
    root:CreateDivider()
    root:CreateButton(isRevealed(id)
        and (L.HIDE_HINT or "Hide hint")
        or (L.SHOW_HINT or "Show hint"), function()
        -- Menus change only the permission, never open the world map.
        setRevealed(id, not isRevealed(id))
    end)
end

local function installMenus()
    if menusInstalled or not Menu or type(Menu.ModifyMenu) ~= "function" then return end
    local success1 = pcall(Menu.ModifyMenu, "MENU_QUEST_MAP_LOG_TITLE", addMenuOption)
    local success2 = pcall(Menu.ModifyMenu, "MENU_QUEST_LOG_POPUP_DETAIL_FRAME", addMenuOption)
    local success3 = pcall(Menu.ModifyMenu, "MENU_QUEST_OBJECTIVE_TRACKER", addTrackerMenuOption)
    menusInstalled = success1 and success2 and success3
end

local function installJournal()
    if QuestMapFrame and QuestMapFrame.DetailsFrame and not journalHooked then
        journalHooked = true
        createJournalButton(QuestMapFrame.DetailsFrame)
    end
    if QuestLogPopupDetailFrame and not popupHooked then
        popupHooked = true
        createJournalButton(QuestLogPopupDetailFrame)
    end
    if not selectedHooked and type(QuestMapFrame_ShowQuestDetails) == "function"
        and type(hooksecurefunc) == "function" then
        selectedHooked = pcall(hooksecurefunc, "QuestMapFrame_ShowQuestDetails", updateJournalButtons)
    end
    if not api.popupSelectionHooked and QuestLogPopupDetailFrame
        and type(QuestLogPopupDetailFrame.ShowQuest) == "function"
        and type(hooksecurefunc) == "function" then
        api.popupSelectionHooked = pcall(hooksecurefunc, QuestLogPopupDetailFrame, "ShowQuest", updateJournalButtons)
    end
end

-- Populate our separate XML QuestPOIFrame with Blizzard's own QuestBlob
-- implementation. Only its Refresh policy differs: draw whitelisted IDs
-- even when questPOI=0. All shapes and artwork come from the client.
local function initializeNativePin()
    if pinMixinReady then return true end
    if type(QuestBlobPinMixin) ~= "table" or type(CreateFromMixins) ~= "function" then return false end
    for key, value in pairs(QuestBlobPinMixin) do NQHQuestBlobPinMixin[key] = value end

    function NQHQuestBlobPinMixin:OnShow()
        self:Refresh()
    end

    function NQHQuestBlobPinMixin:OnHide()
        self:DrawNone()
    end

    function NQHQuestBlobPinMixin:OnEvent()
        -- Do not react to Blizzard's super-tracking changes.
    end

    function NQHQuestBlobPinMixin:Refresh()
        self:DrawNone()
        if not self.mapAllowsBlobs or api.IsMapHidden() ~= true then return end
        local list = allowed()
        if not list then return end
        for id, enabled in pairs(list) do
            if enabled and validQuestID(id) then
                -- The same native filtering Blizzard uses for its own blobs.
                -- A quest without POI shape data simply draws nothing.
                self:TryDrawQuest(id)
            end
        end
    end

    function NQHQuestBlobPinMixin:OnMapChanged()
        local map = self:GetMap()
        local id = map and map:GetMapID()
        if not id then self:DrawNone(); return end
        -- Blizzard's helper handles zone/continent rules, map ID and scale.
        QuestBlobPinMixin.OnMapChanged(self)
    end

    pinMixinReady = true
    return true
end

local function installProvider()
    if provider or not initializeNativePin() then return end
    if type(MapCanvasDataProviderMixin) ~= "table"
        or not WorldMapFrame or type(WorldMapFrame.AddDataProvider) ~= "function" then return end

    local candidate = CreateFromMixins(MapCanvasDataProviderMixin)
    -- Blizzard's native QuestBlobPinMixin:TryDrawQuest() calls this method.
    -- We explicitly select only whitelisted quest IDs, including world quests.
    function candidate:IsShowingWorldQuests() return true end
    function candidate:OnAdded(map)
        MapCanvasDataProviderMixin.OnAdded(self, map)
        self.pin = map:AcquirePin(PIN_TEMPLATE)
        self.pin.dataProvider = self
        self.pin:SetPosition(0.5, 0.5)
        self:OnMapChanged()
    end
    function candidate:OnMapChanged()
        if self.pin then self.pin:OnMapChanged() end
    end
    function candidate:RefreshAllData()
        if self.pin then self.pin:Refresh() end
    end
    function candidate:RemoveAllData()
        if self.pin then self.pin:DrawNone() end
    end
    function candidate:OnRemoved()
        self:RemoveAllData()
        local map = self:GetMap()
        if self.pin and map and type(map.RemovePin) == "function" then
            map:RemovePin(self.pin)
            self.pin = nil
        end
    end
    -- If the client lacks the native POI template or APIs, never break login.
    local ok = pcall(WorldMapFrame.AddDataProvider, WorldMapFrame, candidate)
    if ok and candidate.pin then
        provider = candidate
        refreshMap()
    end
end

local lifecycle = CreateFrame("Frame")
lifecycle:RegisterEvent("ADDON_LOADED")
lifecycle:RegisterEvent("PLAYER_LOGIN")
lifecycle:RegisterEvent("PLAYER_ENTERING_WORLD")
lifecycle:RegisterEvent("QUEST_LOG_UPDATE")
lifecycle:RegisterEvent("QUEST_POI_UPDATE")
lifecycle:SetScript("OnEvent", function(_, event)
    if event == "ADDON_LOADED" or event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        installProvider()
        installJournal()
        installMenus()
        installTrackerHooks()
    elseif event == "QUEST_LOG_UPDATE" then
        updateJournalButtons()
        refreshMap()
        hookExistingTrackerHeaders()
    elseif event == "QUEST_POI_UPDATE" then
        refreshMap()
    end
end)
