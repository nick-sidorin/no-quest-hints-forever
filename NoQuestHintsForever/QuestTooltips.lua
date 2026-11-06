-- Hide quest-specific lines from native unit and world-object tooltips.
-- Blizzard's line pre-callback consumes the line BEFORE text is added, so
-- normal NPC details, health, names, and tooltip layout are unchanged.
-- No quest lookup, localized text parsing, or tooltip frame replacement.
local api = NoQuestHintsForeverAPI
if not api then return end

local registered = {}

local function isWorldTooltip(tooltip)
    if not tooltip then return false end
    local data = tooltip.processingInfo and tooltip.processingInfo.tooltipData
    if not data and type(tooltip.GetPrimaryTooltipData) == "function" then
        local ok, primary = pcall(tooltip.GetPrimaryTooltipData, tooltip)
        if ok then data = primary end
    end
    if type(data) ~= "table" or type(data.type) ~= "number" then return false end

    local kinds = Enum and Enum.TooltipDataType
    return kinds ~= nil and (data.type == kinds.Unit or data.type == kinds.Object)
end

local function hideQuestLine(tooltip)
    if type(api.IsTooltipHintsHidden) == "function"
        and api.IsTooltipHintsHidden() == true
        and isWorldTooltip(tooltip) then
        -- A truthy return skips Blizzard's AddLineDataText, with no blank line.
        return true
    end
end

local function install()
    if not TooltipDataProcessor
        or type(TooltipDataProcessor.AddLinePreCall) ~= "function"
        or not Enum or not Enum.TooltipDataLineType
        or not Enum.TooltipDataType then
        return false
    end

    local lineTypes = Enum.TooltipDataLineType
    for _, key in ipairs({"QuestTitle", "QuestObjective", "QuestPlayer"}) do
        local lineType = lineTypes[key]
        if type(lineType) == "number" and not registered[key] then
            local ok = pcall(TooltipDataProcessor.AddLinePreCall, lineType, hideQuestLine)
            if ok then registered[key] = true end
        end
    end
    return registered.QuestTitle and registered.QuestObjective and registered.QuestPlayer
end

if not install() then
    -- Some clients initialize their TooltipDataProcessor after addon chunks.
    -- Retry only until all three hooks are registered; never register twice.
    local events = CreateFrame("Frame")
    events:RegisterEvent("ADDON_LOADED")
    events:RegisterEvent("PLAYER_LOGIN")
    events:SetScript("OnEvent", function(self)
        if install() then
            self:UnregisterEvent("ADDON_LOADED")
            self:UnregisterEvent("PLAYER_LOGIN")
        end
    end)
end
