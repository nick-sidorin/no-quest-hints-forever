-- Native UI_INFO_MESSAGE category suppression for quest objective updates.
-- Run: lua5.1 tests/test_quest_progress.lua
local source = "NoQuestHintsForever/QuestProgressMessages.lua"
local questNames = {
    "LE_GAME_ERR_QUEST_OBJECTIVE_COMPLETE_S",
    "LE_GAME_ERR_QUEST_UNKNOWN_COMPLETE",
    "LE_GAME_ERR_QUEST_ADD_KILL_SII",
    "LE_GAME_ERR_QUEST_ADD_FOUND_SII",
    "LE_GAME_ERR_QUEST_ADD_ITEM_SII",
    "LE_GAME_ERR_QUEST_ADD_PLAYER_KILL_SII",
}

for i, key in ipairs(questNames) do _G[key] = 290 + i end
LE_GAME_ERR_INV_FULL = 3
LE_GAME_ERR_SPELL_OUT_OF_RANGE = 365
LE_GAME_ERR_NEWTAXIPATH = 287

local function session(enabled, late, initiallyHidden)
    local hidden = enabled
    local calls, lifecycle, state = {}, nil, {}
    for i, key in ipairs(questNames) do
        local id=_G[key]
        -- Other addons may have hidden a quest message already.
        if id then state[id] = initiallyHidden and i == 2 or false end
    end
    state[LE_GAME_ERR_INV_FULL] = false
    state[LE_GAME_ERR_SPELL_OUT_OF_RANGE] = false
    state[LE_GAME_ERR_NEWTAXIPATH] = false
    BLACK_LISTED_MESSAGE_TYPES = state

    local function newUIErrorsFrame()
        return {
            SetMessageTypeEnabled = function(self, kind, allowed)
                calls[#calls+1]={kind=kind, allowed=allowed}
                BLACK_LISTED_MESSAGE_TYPES[kind] = not allowed
            end,
            ShouldDisplayMessageType = function(self, kind)
                return BLACK_LISTED_MESSAGE_TYPES[kind] ~= true
            end,
        }
    end

    UIErrorsFrame = not late and newUIErrorsFrame() or nil
    NoQuestHintsForeverAPI = {
        IsQuestProgressHidden = function() return hidden end,
    }
    CreateFrame = function()
        lifecycle={events={}}
        function lifecycle:RegisterEvent(e) self.events[e]=true end
        function lifecycle:SetScript(_,callback) self.handler=callback end
        return lifecycle
    end
    assert(loadfile(source))()
    local function fire(e)
        assert(lifecycle.events[e], "missing lifecycle event "..e)
        lifecycle.handler(lifecycle,e)
    end
    return {
        frame = lifecycle, state = state, calls = calls, fire = fire,
        api=NoQuestHintsForeverAPI,
        enabled = function(value)
            hidden=value
            NoQuestHintsForeverAPI.RefreshQuestProgressMessages()
        end,
        loadNative = function() UIErrorsFrame=newUIErrorsFrame();fire("ADDON_LOADED") end,
        canShow=function(kind) return UIErrorsFrame:ShouldDisplayMessageType(kind) end,
    }
end

local s=session(false,false,false)
s.fire("ADDON_LOADED")
assert(#s.calls==0, "disabled default should never touch Blizzard message settings")
assert(s.canShow(LE_GAME_ERR_QUEST_ADD_ITEM_SII))
assert(s.canShow(LE_GAME_ERR_SPELL_OUT_OF_RANGE))
s.enabled(true)
assert(#s.calls==6, "should disable precisely 6 native quest objective types")
for _,name in ipairs(questNames) do
    assert(not s.canShow(_G[name]),"quest progress was not suppressed: "..name)
end
assert(s.canShow(LE_GAME_ERR_INV_FULL),"inventory full warning incorrectly suppressed")
assert(s.canShow(LE_GAME_ERR_SPELL_OUT_OF_RANGE),"spell error incorrectly suppressed")
assert(s.canShow(LE_GAME_ERR_NEWTAXIPATH),"discovery notification incorrectly suppressed")
s.fire("PLAYER_LOGIN")
s.fire("PLAYER_ENTERING_WORLD")
assert(not s.canShow(LE_GAME_ERR_QUEST_ADD_FOUND_SII))
s.enabled(false)
for _,name in ipairs(questNames) do
    assert(s.canShow(_G[name]),"quest progress was not restored: "..name)
end
local count=#s.calls
s.enabled(false)
assert(#s.calls==count,"disabled option must not repeatedly rewrite Blizzard state")

-- Do not unhide a category already suppressed by another addon / Blizzard.
local existing=session(true,false,true)
existing.fire("PLAYER_LOGIN")
for _,name in ipairs(questNames) do
    assert(not existing.canShow(_G[name]))
end
existing.enabled(false)
assert(not existing.canShow(LE_GAME_ERR_QUEST_UNKNOWN_COMPLETE),
    "existing blacklist preference must survive disabling our option")
assert(existing.canShow(LE_GAME_ERR_QUEST_ADD_KILL_SII),
    "newly hidden kill message must be restored")
assert(existing.canShow(LE_GAME_ERR_SPELL_OUT_OF_RANGE))

-- Save per-character via core UI; this module must not inherit the setting
-- or touch other characters' normal UI messages.
local another=session(false,false,false)
another.fire("PLAYER_LOGIN")
assert(another.canShow(LE_GAME_ERR_QUEST_ADD_ITEM_SII))
assert(#another.calls==0)

-- Blizzard UIErrorsFrame can be loaded later; retry safely.
local delayed=session(true,true,false)
delayed.fire("ADDON_LOADED")
assert(#delayed.calls==0)
delayed.loadNative()
assert(#delayed.calls==6)
assert(not delayed.canShow(LE_GAME_ERR_QUEST_OBJECTIVE_COMPLETE_S))
delayed.enabled(false)
assert(delayed.canShow(LE_GAME_ERR_QUEST_OBJECTIVE_COMPLETE_S))

-- A missing game constant must not hide an unrelated type or crash.
local old = LE_GAME_ERR_QUEST_ADD_PLAYER_KILL_SII
LE_GAME_ERR_QUEST_ADD_PLAYER_KILL_SII = nil
local missing=session(true,false,false)
missing.fire("PLAYER_LOGIN")
assert(#missing.calls==5)
missing.enabled(false)
LE_GAME_ERR_QUEST_ADD_PLAYER_KILL_SII = old

io.write("PASS: selective quest info IDs, regular warnings unaffected, restoration and delayed UI\n")
