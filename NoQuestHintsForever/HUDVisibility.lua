-- Hide existing HUD frames without changing CVars, native data, parents,
-- saved layouts, scripts or gamepad registries. Disabled controls install no hooks.
local api = NoQuestHintsForeverAPI
if not api then return end
local records, hooked = {}, setmetatable({}, {__mode="k"})
local queued, applying, stopping = false, false, false
local layoutPending = false
local queue

local function available(frame)
    return frame and not (frame.IsForbidden and frame:IsForbidden())
        and type(frame.IsShown)=="function" and type(frame.Show)=="function"
        and type(frame.Hide)=="function"
end

local function inCombat()
    return type(InCombatLockdown)=="function" and InCombatLockdown()
end

local function requestLayout()
    if not layoutPending then return true end
    if inCombat() then return false end
    if EditModeManagerFrame and type(EditModeManagerFrame.IsInitialized)=="function"
        and not EditModeManagerFrame:IsInitialized() then return false end
    if not EventRegistry or type(EventRegistry.TriggerEvent)~="function" then return false end
    -- This is the notification used by native UpdateShownState. Let Blizzard
    -- calculate the stack from current visibility; never set action-bar anchors.
    local ok = pcall(EventRegistry.TriggerEvent, EventRegistry,
        "EditModeManager.UpdateBottomActionBarPositions")
    if ok then layoutPending = false end
    return ok
end

local function setShown(frame, shown, affectsStack)
    if frame:IsShown()==shown then return true end
    -- EditMode's Hide wrapper breaks snapped layouts. Its saved widget method
    -- hides this frame without breaking its saved frame snaps.
    local method = shown and frame.Show or frame.HideBase or frame.Hide
    applying = true
    local ok = pcall(method, frame)
    applying = false
    local changed = ok and frame:IsShown()==shown
    if changed and affectsStack then layoutPending = true end
    return changed
end

local function hook(frame)
    if hooked[frame] or type(hooksecurefunc)~="function" then return end
    local methods = {}
    local function watch(name, shown)
        if type(frame[name])~="function" then return end
        methods[name] = pcall(hooksecurefunc, frame, name, function(_, value)
            if applying or stopping then return end
            local record = records[frame]
            if record then
                if name=="SetShown" then record.shown = value==true
                else record.shown = shown end
                queue()
            end
        end)
    end
    watch("Show", true)
    watch("Hide", false)
    watch("HideBase", false)
    watch("SetShown")
    hooked[frame] = methods
end

local function restore(frame)
    local record = records[frame]
    if record and available(frame) and setShown(frame, record.shown, record.affectsStack) then
        records[frame] = nil
    end
end

local function refresh()
    if stopping or inCombat() then return end
    local targets, xpContainers = {}, {}
    if api.IsMinimapHidden() and available(MinimapCluster) then
        targets[MinimapCluster] = not MinimapCluster.isInEditMode
    end
    local manager = StatusTrackingBarManager
    if api.IsExperienceBarHidden() and available(manager) and type(manager.barContainers)=="table" then
        if not hooked[manager] and type(hooksecurefunc)=="function"
            and type(manager.UpdateBarsShown)=="function" then
            hooked[manager] = pcall(hooksecurefunc, manager, "UpdateBarsShown", queue)
        end
        for _, container in ipairs(manager.barContainers) do
            if available(container) then
                xpContainers[container] = true
                -- Both containers can change from XP to reputation and back.
                -- Read the actual displayed bar, not the pending animation target.
                local bar = container.bars and container.bars[container.shownBarIndex]
                targets[container] = bar and bar.isExpBar==true and not container.isInEditMode or false
                if not hooked[container] and type(hooksecurefunc)=="function" then
                    -- Reconcile after native animations commit a pending bar.
                    if type(container.UpdateShownState)=="function" then
                        pcall(hooksecurefunc, container, "UpdateShownState", queue)
                    end
                    if type(container.ApplyPendingBarToShow)=="function" then
                        pcall(hooksecurefunc, container, "ApplyPendingBarToShow", queue)
                    end
                end
                hook(container)
            end
        end
    end
    for frame in pairs(records) do
        if not targets[frame] then restore(frame) end
    end
    for frame, hidden in pairs(targets) do
        if hidden then
            if not records[frame] then
                records[frame] = {shown=frame:IsShown(), affectsStack=xpContainers[frame]==true}
                hook(frame)
            end
            setShown(frame, false, records[frame].affectsStack)
        end
    end
    requestLayout()
end

queue = function()
    if queued or stopping or applying then return end
    if not api.IsExperienceBarHidden() and not api.IsMinimapHidden() and next(records)==nil and not layoutPending then return end
    if not C_Timer or type(C_Timer.After)~="function" then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        refresh()
    end)
end

api.RefreshHUDVisibility = queue
api.RestoreHUDVisibility = function()
    if inCombat() then return next(records)==nil and not layoutPending end
    for frame in pairs(records) do restore(frame) end
    return requestLayout() and next(records)==nil
end

local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ADDON_LOADED",
    "PLAYER_REGEN_ENABLED", "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "UPDATE_FACTION",
    "PLAYER_LEVEL_UP", "PLAYER_LOGOUT"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event)
    if event=="PLAYER_LOGOUT" then
        stopping = true
        api.RestoreHUDVisibility()
    else
        queue()
    end
end)
if EventRegistry and type(EventRegistry.RegisterCallback)=="function" then
    EventRegistry:RegisterCallback("EditMode.Enter", queue, events)
    EventRegistry:RegisterCallback("EditMode.Exit", queue, events)
end
