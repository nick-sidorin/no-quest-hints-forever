-- Native minimap quest tracking, identified by enum rather than localized names
-- or unstable tracking-list indices. Never overwrite the full tracking bitfield.
local api = NoQuestHintsForeverAPI
if not api then return end
local KEY = "minimapQuestTrackingOriginal"
local queued, applying, loggingOut = false, false, false

local function inCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function questFilter()
    local id = Enum and Enum.MinimapTrackingFilter and Enum.MinimapTrackingFilter.QuestPOIs
    if not id or not C_Minimap or type(C_Minimap.GetNumTrackingTypes) ~= "function"
        or type(C_Minimap.GetTrackingFilter) ~= "function"
        or type(C_Minimap.GetTrackingInfo) ~= "function"
        or type(C_Minimap.SetTracking) ~= "function" then return end
    local ok, count = pcall(C_Minimap.GetNumTrackingTypes)
    if not ok or type(count) ~= "number" then return end
    for index = 1, count do
        local found, filter = pcall(C_Minimap.GetTrackingFilter, index)
        if found and type(filter) == "table" and filter.filterID == id then
            local read, info = pcall(C_Minimap.GetTrackingInfo, index)
            if read and type(info) == "table" and type(info.active) == "boolean" then
                return index, info.active
            end
        end
    end
end

local function store()
    local account, character = NoQuestHintsForeverAccount, NoQuestHintsForeverChar
    if type(account) ~= "table" or type(character) ~= "table" then return end
    -- Honor existing recovery data even if scope metadata loads later.
    if type(account[KEY]) == "boolean" then return account end
    if type(character[KEY]) == "boolean" then return character end
    local getter = C_CVar and C_CVar.GetCVarInfo or GetCVarInfo
    if type(getter) == "function" then
        local ok, _, _, shared, personal = pcall(getter, "minimapTrackedInfov4")
        if ok and personal == true and shared ~= true then return character end
    end
    -- If scope is unknown, retain a shared baseline so an OFF alt can recover it.
    return account
end

local function write(index, value)
    applying = true
    local ok = pcall(C_Minimap.SetTracking, index, value)
    local _, active = questFilter()
    applying = false
    return ok and active == value
end

function api.RestoreMinimapQuestMarkers()
    local saved = store()
    if not saved or type(saved[KEY]) ~= "boolean" then return true end
    if inCombat() then return false end
    local index, active = questFilter()
    if not index then return false end
    if active == saved[KEY] or write(index, saved[KEY]) then
        saved[KEY] = nil
        return true
    end
    return false
end

local function refresh()
    if loggingOut or inCombat() then return end
    if not api.IsMinimapQuestMarkersHidden() then
        api.RestoreMinimapQuestMarkers()
        return
    end
    local index, active = questFilter()
    local saved = store()
    if not index or not saved then return end
    if type(saved[KEY]) ~= "boolean" then saved[KEY] = active end
    if active then write(index, false) end
end

local function queue()
    if queued or applying or loggingOut then return end
    if C_Timer and type(C_Timer.After) == "function" then
        queued = true
        C_Timer.After(0, function() queued = false; refresh() end)
    else
        refresh()
    end
end
api.RefreshMinimapQuestMarkers = queue

local events = CreateFrame("Frame")
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD",
    "VARIABLES_LOADED", "SPELLS_CHANGED", "MINIMAP_UPDATE_TRACKING", "CVAR_UPDATE",
    "PLAYER_REGEN_ENABLED", "PLAYER_LOGOUT"}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGOUT" then
        loggingOut = true
        api.RestoreMinimapQuestMarkers()
    elseif event ~= "CVAR_UPDATE" or (type(name) == "string" and name:lower() == "minimaptrackedinfov4") then
        queue()
    end
end)
