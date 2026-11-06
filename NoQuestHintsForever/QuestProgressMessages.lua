-- Hide only the yellow Blizzard quest objective progress announcements.
-- Do not hide UIErrorsFrame: it also contains spell errors and other warnings.
-- The stock UIErrorsMixin:SetMessageTypeEnabled() controls each message
-- category by ID, without parsing translated quest text or replacing scripts.
local api = NoQuestHintsForeverAPI
if not api then return end

local questMessageNames = {
    "LE_GAME_ERR_QUEST_OBJECTIVE_COMPLETE_S",
    "LE_GAME_ERR_QUEST_UNKNOWN_COMPLETE",
    "LE_GAME_ERR_QUEST_ADD_KILL_SII",
    "LE_GAME_ERR_QUEST_ADD_FOUND_SII",
    "LE_GAME_ERR_QUEST_ADD_ITEM_SII",
    "LE_GAME_ERR_QUEST_ADD_PLAYER_KILL_SII",
}

-- Keep the original visibility of each message category so turning this
-- option off restores any preference set by the client or another addon.
local previous = {}

local function update()
    local errors = UIErrorsFrame
    if not errors or type(errors.SetMessageTypeEnabled) ~= "function" then return end
    local hide = type(api.IsQuestProgressHidden) == "function"
        and api.IsQuestProgressHidden() == true

    for _, name in ipairs(questMessageNames) do
        local kind = _G[name]
        if type(kind) == "number" then
            if hide then
                if previous[kind] == nil then
                    local blacklist = BLACK_LISTED_MESSAGE_TYPES
                    previous[kind] = {
                        enabled = type(blacklist) ~= "table" or blacklist[kind] ~= true,
                    }
                end
                errors:SetMessageTypeEnabled(kind, false)
            elseif previous[kind] then
                errors:SetMessageTypeEnabled(kind, previous[kind].enabled)
                previous[kind] = nil
            end
        end
    end
end

api.RefreshQuestProgressMessages = update

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function()
    update()
end)
