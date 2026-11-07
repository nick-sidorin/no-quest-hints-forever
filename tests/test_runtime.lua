-- Run from repository root: lua5.1 tests/test_runtime.lua
-- Simulate WoW's real load order: Lua chunk -> SavedVariables -> ADDON_LOADED.
local addon = "NoQuestHintsForever/NoQuestHintsForever.lua"
local addonName = "NoQuestHintsForever"
local names = {
    "questPOI", "showQuestObjectivesOnMap", "questPOILocalStory",
    "minimapShowQuestBlobs", "showInGameNavigation",
}

local function createSession(savedChar, savedAccount, values, withInfo)
    -- No SavedVariables are visible while Lua chunks are executed.
    NoQuestHintsForeverChar = nil
    NoQuestHintsForeverAccount = nil
    SlashCmdList = {}
    local frame, writes
    writes = {}
    CreateFrame = function()
        frame = { events = {} }
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:UnregisterEvent(event) self.events[event] = nil end
        function frame:SetScript(_, callback) self.onEvent = callback end
        return frame
    end
    print = function() end
    C_CVar = {
        GetCVar = function(name) return values[name] end,
        SetCVar = function(name, value)
            if values[name] == nil then error("unknown CVar") end
            values[name] = value
            writes[#writes + 1] = { name, value }
            if frame and frame.events.CVAR_UPDATE then
                frame.onEvent(frame, "CVAR_UPDATE", name)
            end
        end,
    }
    if withInfo then
        C_CVar.GetCVarInfo = function(name)
            return values[name], "1", name == "showInGameNavigation", name ~= "showInGameNavigation"
        end
    end

    assert(loadfile(addon))()
    assert(NoQuestHintsForeverChar == nil, "Lua must not initialize SavedVariables before ADDON_LOADED")
    assert(NoQuestHintsForeverAccount == nil, "Lua must not initialize account SavedVariables before ADDON_LOADED")

    -- WoW loads these tables AFTER the Lua chunk. This is the lifecycle
    -- that was missing from the old test and caused the /reload bug.
    NoQuestHintsForeverChar = savedChar
    NoQuestHintsForeverAccount = savedAccount
    local function event(name, detail)
        assert(frame.events[name], "unexpected or unregistered event " .. name)
        frame.onEvent(frame, name, detail)
    end
    event("ADDON_LOADED", "SomeOtherAddon")
    event("ADDON_LOADED", addonName)
    assert(frame.events.ADDON_LOADED == true, "loaded event must watch for late Blizzard tracker loading")
    event("PLAYER_LOGIN")
    assert(NoQuestHintsForeverChar == savedChar, "character DB replaced")
    assert(NoQuestHintsForeverAccount == savedAccount, "account DB replaced")
    return function(command) SlashCmdList.NOQUESTHINTSFOREVER(command) end, event, writes
end

local a = {}
local shared = {}
local values = {}
for _, name in ipairs(names) do values[name] = "1" end

local run, event, writes = createSession(a, shared, values, true)
assert(a.enabled == nil and #writes == 0, "OFF by default must not change CVars")
NoQuestHintsForeverAPI.SetMapHidden(true)
assert(a.enabled == true, "ON not saved per character")
for _, name in ipairs(names) do assert(values[name] == "0", "not hidden: " .. name) end
assert(shared.original.showInGameNavigation == "1", "shared original wasn't saved")
assert(a.original.questPOI == "1", "character original wasn't saved")

-- CVar update while ON must be overridden.
C_CVar.SetCVar("questPOI", "1")
assert(values.questPOI == "0", "ON did not re-enforce")

-- The exact user-reported failure: enable -> /reload -> disable.
-- Persisted tables remain visible only AFTER the second Lua chunk executes.
run, event = createSession(a, shared, values, true)
assert(a.enabled == true, "ON did not survive reload")
run("status")
NoQuestHintsForeverAPI.SetMapHidden(false)
assert(a.enabled == false, "OFF did not save to the loaded character DB")
for _, name in ipairs(names) do
    assert(values[name] == "1", "OFF after reload did not restore " .. name)
end
assert(next(a.original) == nil and next(shared.original) == nil, "successful restoration not cleared")

-- OFF should not re-enforce, including after a second reload.
C_CVar.SetCVar("questPOI", "0")
assert(values.questPOI == "0", "OFF interfered with Blizzard setting")
run, event = createSession(a, shared, values, true)
assert(a.enabled == false, "OFF not persistent")
C_CVar.SetCVar("questPOI", "1")
assert(values.questPOI == "1", "OFF still enforces after reload")

-- Enable again, switch to a fresh second character: only shared CVar
-- suppression is reverted on the OFF character.
NoQuestHintsForeverAPI.SetMapHidden(true)
for _, name in ipairs(names) do assert(values[name] == "0", "not hidden on re-enable") end
local b = {}
for _, name in ipairs(names) do
    if name ~= "showInGameNavigation" then values[name] = "1" end
end
run, event, writes = createSession(b, shared, values, true)
assert(b.enabled == nil and #writes == 1, "fresh alt should only restore the shared CVar")
assert(values.showInGameNavigation == "1", "shared navigation wasn't restored on alt")
for _, name in ipairs(names) do assert(values[name] == "1", "alt hint altered: " .. name) end
C_CVar.SetCVar("questPOI", "0")
assert(values.questPOI == "0", "OFF alt interfered")

-- Coming back to A, its saved originals are still meaningful.
for _, name in ipairs(names) do
    values[name] = name == "showInGameNavigation" and "1" or "0"
end
run, event = createSession(a, shared, values, true)
assert(a.enabled == true, "main character lost ON")
NoQuestHintsForeverAPI.SetMapHidden(false)
for _, name in ipairs(names) do
    assert(values[name] == "1", "main character OFF could not restore " .. name)
end

-- Unknown CVars and missing GetCVarInfo must not crash.
values.questPOILocalStory = nil
run, event = createSession({}, {}, values, false)
run("status")
NoQuestHintsForeverAPI.SetMapHidden(true)
assert(values.questPOI == "0", "fallback on missing info API failed")

io.write("PASS: SavedVariables load order, reload->off, per-character settings, re-enforcement and unavailable APIs\n")
