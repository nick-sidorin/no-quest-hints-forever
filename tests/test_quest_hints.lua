-- Run: lua5.1 tests/test_quest_hints.lua
-- Proves whitelisting, in-journal toggle, map filtering and missing APIs
-- without modifying Blizzard quest watch, native CVars or objective tracker.
local file = "NoQuestHintsForever/QuestHints.lua"

local function frame()
    local obj = {scripts={}, shown=true, buttonText="", hookScripts={}}
    function obj:SetSize() end
    function obj:SetPoint() end
    function obj:SetText(value) self.buttonText = value end
    function obj:SetScript(name, fn) self.scripts[name] = fn end
    function obj:Show() self.shown = true end
    function obj:Hide() self.shown = false end
    function obj:IsShown() return self.shown end
    function obj:CreateFontString() return {} end
    function obj:HookScript(name, fn)
        self.hookScripts[name] = fn
    end
    return obj
end

local function session(db, withMap)
    NoQuestHintsForeverChar = db
    local revealed = db.revealedQuests or {}
    db.revealedQuests = revealed
    local globalHidden = true
    local received = {}
    local map = { mapID = 101, pins = {} }
    function map:GetMapID() return self.mapID end
    function map:RemoveAllPinsByTemplate(template)
        assert(template == "NQHQuestHintPinTemplate")
        self.pins = {}
    end
    function map:AcquirePin(template, questID, x, y)
        assert(template == "NQHQuestHintPinTemplate")
        self.pins[#self.pins+1] = {id=questID, x=x, y=y}
    end
    function map:AddDataProvider(provider)
        received.provider = provider
        provider:OnAdded(self)
    end
    if withMap then WorldMapFrame = map else WorldMapFrame = nil end

    NQHQuestHintDataProviderMixin = nil
    NQHQuestHintPinMixin = nil
    MapCanvasPinMixin = {}
    MapCanvasDataProviderMixin = {
        OnAdded = function(self, worldMap) self.worldMap = worldMap end,
        GetMap = function(self) return self.worldMap end,
    }
    CreateFromMixins = function(parent)
        local o = {}
        for k,v in pairs(parent) do o[k]=v end
        return o
    end
    C_QuestLog = {
        GetQuestsOnMap = function(mapID)
            if mapID ~= 101 then return {} end
            return {
                {questID=11, x=0.2, y=0.3},
                {questID=12, x=0.6, y=0.7},
                {questID=13, x=0.1, y=0.9},
                {questID=15, x=1.2, y=0.1},
            }
        end,
        GetNextWaypointForMap = function(questID, mapID)
            if questID == 14 and mapID == 101 then return 0.9, 0.5 end
        end,
    }

    local details = frame()
    details.questID = 11
    details.TrackButton = frame()
    QuestMapFrame = {DetailsFrame=details}
    QuestLogPopupDetailFrame = frame()
    QuestLogPopupDetailFrame.questID = 12
    QuestLogPopupDetailFrame.TrackButton = frame()
    function QuestLogPopupDetailFrame:ShowQuest(questID) self.questID = questID end
    QuestMapFrame_ShowQuestDetails = function(questID) details.questID = questID end

    local buttons, events = {}, {}
    CreateFrame = function(kind, name, parent, template)
        local item = frame()
        item.template = template
        if kind == "Button" then
            item.parent = parent
            buttons[#buttons+1] = item
        else
            function item:RegisterEvent(name) events[name] = true end
            function item:UnregisterEvent(name) events[name] = nil end
            received.lifecycle = item
        end
        return item
    end
    hooksecurefunc = function(object, method, hook)
        if type(object) == "string" then
            local original = _G[object]
            assert(type(original)=="function")
            _G[object] = function(...)
                local result = original(...)
                method(...)
                return result
            end
        else
            local original = object[method]
            object[method] = function(self, ...)
                local result = original(self, ...)
                hook(self, ...)
                return result
            end
        end
    end

    NoQuestHintsForeverAPI = {
        IsMapHidden = function() return globalHidden end,
    }
    assert(loadfile(file))()
    local function event(name)
        assert(events[name], "unregistered event: " .. name)
        received.lifecycle.scripts.OnEvent(nil, name)
    end
    event("ADDON_LOADED")
    event("PLAYER_LOGIN")
    return {
        db=db, map=map, api=NoQuestHintsForeverAPI, buttons=buttons,
        details=details, event=event,
        setMapHidden=function(x) globalHidden=x; NoQuestHintsForeverAPI.RefreshQuestHintPins() end,
    }
end

local db = {}
local s = session(db, true)
assert(s.map.pins and #s.map.pins == 0, "no whitelisted quests should show pins")
assert(#s.buttons == 2, "journal detail and popup need separate buttons")
assert(s.buttons[1].buttonText == "Show map hint")
assert(s.buttons[2].buttonText == "Show map hint")

s.buttons[1].scripts.OnClick()
assert(s.api.IsQuestRevealed(11), "button did not whitelist the selected quest")
assert(#s.map.pins == 1 and s.map.pins[1].id == 11, "quest 11 missing")
assert(s.buttons[1].buttonText == "Hide map hint", "button label did not update")
assert(s.api.SetQuestRevealed(12, true))
assert(#s.map.pins == 2 and s.map.pins[1].id == 11 and s.map.pins[2].id == 12,
    "whitelisted quest IDs should appear, all others excluded")
assert(s.api.SetQuestRevealed(11, false))
assert(#s.map.pins == 1 and s.map.pins[1].id == 12, "disabling quest 11 removed wrong pins")
assert(not s.api.IsQuestRevealed(11) and s.api.IsQuestRevealed(12))

s.api.SetQuestRevealed(14, true)
assert(#s.map.pins == 2 and s.map.pins[2].id == 14, "waypoint fallback missing")
s.api.SetQuestRevealed(15, true)
assert(#s.map.pins == 2, "invalid coordinates should not create a pin")
s.api.SetQuestRevealed(15, false)
assert(not s.api.SetQuestRevealed(-1, true), "invalid ID accepted")

s.setMapHidden(false)
assert(#s.map.pins == 0, "turning OFF global hiding should remove custom pins")
assert(s.api.IsQuestRevealed(12), "global option should not erase user whitelist")
s.setMapHidden(true)
assert(#s.map.pins == 2, "whitelisted pins not restored when global hiding enabled")

QuestMapFrame_ShowQuestDetails(12)
assert(s.buttons[1].buttonText == "Hide map hint", "native quest selection did not update hint button")
s.buttons[2].scripts.OnClick()
assert(#s.map.pins == 1 and s.map.pins[1].id == 14, "popup toggle not respected")

s.map.mapID = 202
s.api.RefreshQuestHintPins()
assert(#s.map.pins == 0, "old map pins persisted on another zone")
s.map.mapID = 101
s.api.RefreshQuestHintPins()
assert(#s.map.pins == 1 and s.map.pins[1].id == 14, "map change lost waypoint pin")
assert(db.revealedQuests[14] == true, "per-character persistence not stored")

local alt = session({}, true)
assert(#alt.map.pins == 0 and alt.api.IsQuestRevealed(14) == false,
    "new character inherited hint permissions")
local reload = session(db, true)
assert(reload.api.IsQuestRevealed(14) and #reload.map.pins == 1,
    "per-character whitelist not restored after simulated reload")

local noMap = session({}, false)
assert(noMap.api.SetQuestRevealed(11, true), "missing world map blocked preference saving")
assert(noMap.api.IsQuestRevealed(11))

io.write("PASS: one-quest reveal, multiple whitelist pins, journal hooks, waypoints, map changes, reload and alts\n")
