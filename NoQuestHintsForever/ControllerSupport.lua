-- Isolate NQH-owned pins from Forever's native gamepad cursor pin list.
-- Inspired by the scoped fix in Questie #7922; no Blizzard methods are replaced.
local api = NoQuestHintsForeverAPI
if not api then return end
local pins = setmetatable({}, {__mode="k"})
local hookedMaps = setmetatable({}, {__mode="k"})
local poller, tooltip, hovered
local elapsed = 0
local loggingOut = false
local refresh

local function gamepadUI()
    return InputUtil and type(InputUtil.IsGamepadUIEnabled) == "function"
        and InputUtil.IsGamepadUIEnabled()
end
api.IsNativeGamepadUI = gamepadUI

local function inCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function visible(frame)
    local fn = frame and (frame.IsVisible or frame.IsShown)
    if type(fn) ~= "function" then return false end
    local ok, shown = pcall(fn, frame)
    return ok and shown == true
end

local function questID(pin, record)
    if not record.interactive or not visible(pin) then return end
    local ok, id = pcall(pin.GetQuestID, pin)
    if ok and type(id) == "number" and api.IsMapHidden and api.IsMapHidden()
        and api.IsQuestRevealed and api.IsQuestRevealed(id) then return id end
end

local function leave()
    hovered = nil
    if tooltip then tooltip:Hide() end
end

local function stop()
    if poller then poller:SetScript("OnUpdate", nil); poller:Hide() end
    leave()
end

local function showTooltip(pin, id)
    local log = C_QuestLog
    if not log or type(log.GetTitleForQuestID) ~= "function" then return end
    local ok, title = pcall(log.GetTitleForQuestID, id)
    if not ok or type(title) ~= "string" then return end
    if not tooltip then
        -- Never run the native pin's OnMouseEnter: it uses shared GameTooltip
        -- and dispatches map/journal events outside the secure cursor boundary.
        tooltip = CreateFrame("GameTooltip", "NoQuestHintsForeverGamepadTooltip", UIParent, "GameTooltipTemplate")
    end
    tooltip:SetOwner(pin, "ANCHOR_RIGHT")
    tooltip:SetText(title)
    if type(log.GetQuestObjectives) == "function" then
        local read, objectives = pcall(log.GetQuestObjectives, id)
        if read and type(objectives) == "table" then
            for _, objective in ipairs(objectives) do
                if type(objective) == "table" and type(objective.text) == "string" and not objective.finished then
                    tooltip:AddLine(objective.text, 1, 1, 1, true)
                end
            end
        end
    end
    tooltip:Show()
    hovered = pin
end

local function activeMap()
    local map = WorldMapFrame
    local getter = C_CVar and C_CVar.GetCVarBool or GetCVarBool
    if type(getter) == "function" then
        local ok, disabled = pcall(getter, "GamepadDisableTooltips")
        if ok and disabled then return nil end
    end
    return not loggingOut and visible(map) and gamepadUI() and not inCombat() and map or nil
end

local function update(_, delta)
    local map = activeMap()
    if not map then stop(); return end
    elapsed = elapsed + delta
    if elapsed < 0.05 then return end
    elapsed = 0
    local any, nearest, nearestID, distance = false, nil, nil, 144
    local scroll = map.ScrollContainer
    local x, y
    if visible(SoftCursor) and scroll and type(scroll.GetGamepadCursorPosition) == "function" then
        x, y = scroll:GetGamepadCursorPosition()
    end
    for pin, record in pairs(pins) do
        local id = questID(pin, record)
        if id then
            any = true
            if type(x) == "number" and type(y) == "number" then
                local ok, px, py = pcall(record.center, pin)
                if ok and type(px) == "number" and type(py) == "number" then
                    local d = (px-x)^2 + (py-y)^2
                    if d <= distance then nearest, nearestID, distance = pin, id, d end
                end
            end
        end
    end
    if not any then stop(); return end
    if nearest ~= hovered or (tooltip and tooltip.nqhQuestID ~= nearestID) then
        leave()
        if nearest then showTooltip(nearest, nearestID); if tooltip then tooltip.nqhQuestID = nearestID end end
    end
end

refresh = function()
    if not activeMap() then stop(); return end
    for pin, record in pairs(pins) do
        if questID(pin, record) then
            if not poller then poller = CreateFrame("Frame") end
            elapsed = 0
            poller:SetScript("OnUpdate", update)
            poller:Show()
            return
        end
    end
    stop()
end

function api.GuardQuestMapPin(pin, interactive)
    if not pin or type(pin.GetCenter) ~= "function" then return end
    if not pins[pin] or pin.GetCenter ~= pins[pin].guard then
        local original = pin.GetCenter
        local guard = function(self, ...)
            if gamepadUI() then return nil end
            return original(self, ...)
        end
        pins[pin] = {center=original, guard=guard}
        pin.GetCenter = guard
    end
    pins[pin].interactive = interactive == true
    local map = WorldMapFrame
    if map and not hookedMaps[map] and type(map.HookScript) == "function" then
        hookedMaps[map] = true
        map:HookScript("OnShow", refresh)
        map:HookScript("OnHide", stop)
    end
    refresh()
end
api.RefreshControllerQuestPins = refresh

local events = CreateFrame("Frame")
for _, name in ipairs({"GAME_PAD_ACTIVE_CHANGED", "CVAR_UPDATE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_LOGOUT"}) do
    events:RegisterEvent(name)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGOUT" then loggingOut = true; stop()
    elseif event == "PLAYER_REGEN_DISABLED" then stop() else refresh() end
end)
