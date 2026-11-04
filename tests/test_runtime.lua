-- Run from the repository root: lua tests/test_runtime.lua
local addon = "NoQuestHintsForever/NoQuestHintsForever.lua"
local names = {
    "questPOI", "showQuestObjectivesOnMap", "questPOILocalStory",
    "minimapShowQuestBlobs", "showInGameNavigation",
}

local function createSession(characterDB, accountDB, values, withInfo)
    NoQuestHintsForeverChar = characterDB
    NoQuestHintsForeverAccount = accountDB
    SlashCmdList = {}
    local frame, writes = nil, {}
    CreateFrame = function()
        frame = { events = {} }
        function frame:RegisterEvent(event) self.events[event] = true end
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
    local function event(name, detail) frame.onEvent(frame, name, detail) end
    return function(command) SlashCmdList.NOQUESTHINTSFOREVER(command) end, event, writes
end

local a = {}
local shared = {}
local values = {}
for _, name in ipairs(names) do values[name] = "1" end

local run, event, writes = createSession(a, shared, values, true)
event("PLAYER_LOGIN")
assert(a.enabled == nil and #writes == 0, "OFF by default must not write CVars")
run("on")
assert(a.enabled == true, "ON not saved per character")
for _, name in ipairs(names) do assert(values[name] == "0", "not hidden: " .. name) end
assert(shared.original.showInGameNavigation == "1", "account CVar snapshot missing")
assert(a.original.questPOI == "1", "character CVar snapshot missing")

-- A Blizzard UI setting that turns the hint back on must be reverted.
C_CVar.SetCVar("questPOI", "1")
assert(values.questPOI == "0", "CVAR_UPDATE did not re-enforce")

-- Reinitializing the Lua addon should restore this character's mode.
run, event = createSession(a, shared, values, true)
event("PLAYER_LOGIN")
assert(a.enabled == true and values.questPOI == "0", "ON did not survive reload")

-- Character B has its own quest CVars, but inherits the account CVar.
local b = {}
for _, name in ipairs(names) do
    if name ~= "showInGameNavigation" then values[name] = "1" end
end
run, event, writes = createSession(b, shared, values, true)
event("PLAYER_LOGIN")
assert(b.enabled == nil, "new alt must be OFF")
assert(values.showInGameNavigation == "1", "shared navigation wasn't restored on alt")
for _, name in ipairs(names) do assert(values[name] == "1", "alt quest UI was modified: " .. name) end
assert(#writes == 1, "off-alt login should only restore shared CVar")
C_CVar.SetCVar("questPOI", "0")
assert(values.questPOI == "0", "OFF mode interfered with user setting")

-- Disabling on A restores A's original character CVar settings.
for _, name in ipairs(names) do
    values[name] = name == "showInGameNavigation" and "1" or "0"
end
run, event = createSession(a, shared, values, true)
event("PLAYER_LOGIN")
run("off")
assert(a.enabled == false, "OFF not saved")
for _, name in ipairs(names) do assert(values[name] == "1", "OFF failed to restore: " .. name) end
C_CVar.SetCVar("questPOI", "0")
assert(values.questPOI == "0", "OFF continued to enforce")

-- Unknown CVars and missing GetCVarInfo shouldn't abort the addon.
values.questPOILocalStory = nil
run, event = createSession({}, {}, values, false)
run("status")
run("on")
assert(values.questPOI == "0", "fallback on client with missing APIs failed")

io.write("PASS: per-character mode, shared-CVar restoration, enforcement and missing APIs\n")
