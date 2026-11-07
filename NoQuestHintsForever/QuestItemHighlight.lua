-- Hide only the native quest-item border in carried bags. Alpha keeps Blizzard's
-- own visibility/texture updates intact, including quest-start exclamation marks.
local api = NoQuestHintsForeverAPI
if not api then return end
local originals = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })
local queued = false
local queue

local function inCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function restore(texture)
    local alpha = originals[texture]
    if alpha == nil then return end
    if texture:GetAlpha() ~= 0 or pcall(texture.SetAlpha, texture, alpha) then
        originals[texture] = nil
    end
end

local function hook(object, method)
    if not hooksecurefunc or type(object[method]) ~= "function" then return end
    local methods = hooked[object] or {}
    hooked[object] = methods
    if not methods[method] then methods[method] = pcall(hooksecurefunc, object, method, queue) end
end

local function refresh()
    if inCombat() then return end
    local active = {}
    if type(ContainerFrameUtil_EnumerateContainerFrames) == "function" then
        for _, container in ContainerFrameUtil_EnumerateContainerFrames() do
            hook(container, "UpdateItems")
            hook(container, "Show")
            if type(container.EnumerateValidItems) == "function" then
                for _, button in container:EnumerateValidItems() do
                    hook(button, "UpdateQuestItem")
                    local texture = button.IconQuestTexture
                    if texture and type(texture.GetAlpha) == "function"
                        and type(texture.SetAlpha) == "function" then
                        local bag = type(button.GetBagID) == "function" and button:GetBagID()
                        local lastBag = Constants and Constants.InventoryConstants
                            and Constants.InventoryConstants.NumBagSlots or NUM_BAG_SLOTS or 4
                        local info
                        if type(bag) == "number" and bag >= 0 and bag <= lastBag
                            and C_Container and type(C_Container.GetContainerItemQuestInfo) == "function"
                            and type(button.GetID) == "function" then
                            info = C_Container.GetContainerItemQuestInfo(bag, button:GetID())
                        end
                        -- The same region also draws a '!' on quest-start items.
                        -- Never suppress that marker or bank/equipped item UI.
                        local border = info and (info.questID or info.isQuestItem)
                            and not (info.questID and not info.isActive)
                        if api.IsQuestItemHighlightHidden() and border then
                            active[texture] = true
                            if originals[texture] == nil then originals[texture] = texture:GetAlpha() end
                            pcall(texture.SetAlpha, texture, 0)
                        else
                            restore(texture)
                        end
                    end
                end
            end
        end
    end
    -- Released/reparented buttons must not retain our alpha override.
    for texture in pairs(originals) do
        if not active[texture] then restore(texture) end
    end
end

queue = function()
    if queued or inCombat() or not C_Timer or type(C_Timer.After) ~= "function" then return end
    queued = true
    C_Timer.After(0, function() queued = false; refresh() end)
end

api.RefreshQuestItemHighlight = queue
function api.RestoreQuestItemHighlight()
    if api.IsQuestItemHighlightHidden() then return false end
    if not inCombat() then
        for texture in pairs(originals) do restore(texture) end
    end
    return next(originals) == nil
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD",
    "BAG_UPDATE_DELAYED", "BAG_OPEN", "QUEST_LOG_UPDATE", "PLAYER_REGEN_ENABLED" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", queue)
