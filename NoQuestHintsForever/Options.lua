-- Native Blizzard-styled UI for No Quest Hints - Forever.
-- Keep all appearance here; NoQuestHintsForever.lua owns the state.
local api = NoQuestHintsForeverAPI
if not api then return end

local L = NoQuestHintsForeverLocale or {}
local TITLE = L.TITLE or "No Quest Hints"
local window, mapCheck, trackerCheck, tooltipCheck, npcNamesCheck

local function addText(parent, text, font, point, relative, relativePoint, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", font)
    label:SetPoint(point, relative, relativePoint, x, y)
    label:SetText(text)
    return label
end

local function refresh()
    if mapCheck then mapCheck:SetChecked(api.IsMapHidden()) end
    if trackerCheck then trackerCheck:SetChecked(api.IsTrackerHidden()) end
    if tooltipCheck then tooltipCheck:SetChecked(api.IsTooltipHintsHidden()) end
    if npcNamesCheck then npcNamesCheck:SetChecked(api.IsQuestNPCNamesHidden()) end
end

local function createCheck(parent, y, title, description, initialValue, onChange)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, y)
    check:SetChecked(initialValue())
    local titleText = addText(parent, title, "GameFontNormal", "LEFT", check, "RIGHT", 4, 0)
    addText(parent, description, "GameFontHighlightSmall", "TOPLEFT", titleText, "BOTTOMLEFT", 0, -4)
    check:SetScript("OnClick", function(self)
        onChange(self:GetChecked() == true)
        refresh()
    end)
    return check
end

local function createWindow()
    if window then return window end

    window = CreateFrame("Frame", "NoQuestHintsForeverOptionsFrame", UIParent, "BasicFrameTemplateWithInset")
    window:SetSize(545, 407)
    window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", function(self) self:StartMoving() end)
    window:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    if window.TitleText then
        window.TitleText:SetText(TITLE)
    else
        addText(window, TITLE, "GameFontNormalLarge", "TOP", window, "TOP", 0, -10)
    end

    addText(window,
        L.TAGLINE or "Read the quest. Explore the world. Find your own way.",
        "GameFontHighlight", "TOPLEFT", window, "TOPLEFT", 24, -46)

    mapCheck = createCheck(window, -85, L.MAP_HINTS or "Hide quest map hints",
        L.MAP_HINTS_DESC or "Quest markers, highlighted areas and navigation guidance.",
        api.IsMapHidden, api.SetMapHidden)

    trackerCheck = createCheck(window, -151, L.TRACKER or "Hide objective tracker",
        L.TRACKER_DESC or "The on-screen task list and its progress counters.",
        api.IsTrackerHidden, api.SetTrackerHidden)

    tooltipCheck = createCheck(window, -217, L.TOOLTIP_HINTS or "Hide quest hints in tooltips",
        L.TOOLTIP_HINTS_DESC or "Quest names and progress on NPC and object mouseover.",
        api.IsTooltipHintsHidden, api.SetTooltipHintsHidden)

    npcNamesCheck = createCheck(window, -283, L.NPC_NAME_HINTS or "Hide quest NPC names",
        L.NPC_NAME_HINTS_DESC or "Also hides some special NPC names (Blizzard limitation).",
        api.IsQuestNPCNamesHidden, api.SetQuestNPCNamesHidden)

    addText(window, L.CHAR_SAVED or "Settings are saved separately for each character.",
        "GameFontDisableSmall", "BOTTOMLEFT", window, "BOTTOMLEFT", 24, 22)

    window:SetScript("OnShow", refresh)
    window:Hide()
    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, window:GetName())
    end
    return window
end

function api.OpenOptions()
    local current = createWindow()
    if current:IsShown() then
        current:Hide()
    else
        refresh()
        current:Show()
    end
end

-- The client may have no modern Settings API. A missing category must never
-- block /nqh or the window itself.
local function registerBlizzardCategory()
    if not Settings
        or type(Settings.RegisterCanvasLayoutCategory) ~= "function"
        or type(Settings.RegisterAddOnCategory) ~= "function" then
        return
    end

    local panel = CreateFrame("Frame", nil, UIParent)
    panel:SetSize(550, 200)
    addText(panel, TITLE, "GameFontNormalLarge", "TOPLEFT", panel, "TOPLEFT", 16, -16)
    addText(panel, L.SETTINGS_INTRO or "Explore Azeroth without quest directions.",
        "GameFontHighlight", "TOPLEFT", panel, "TOPLEFT", 16, -52)

    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(type(GetLocale) == "function" and GetLocale() == "ruRU" and 245 or 190, 28)
    button:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -90)
    button:SetText(L.OPEN_SETTINGS or "Open addon settings")
    button:SetScript("OnClick", function()
        local current = createWindow()
        refresh()
        current:Show()
    end)

    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, TITLE)
    if ok and category then
        pcall(Settings.RegisterAddOnCategory, category)
    end
end

registerBlizzardCategory()
