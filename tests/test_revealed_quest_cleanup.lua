-- Exercise actual core navigation together with authoritative quest cleanup.
local function session(saved)
    local frames, timers = {}, {}
    local combat, refreshes, targetWrites = false, 0, 0
    local values = {questPOI="1", showQuestObjectivesOnMap="1", questPOILocalStory="1",
        minimapShowQuestBlobs="1", showInGameNavigation="1"}
    NoQuestHintsForeverChar, NoQuestHintsForeverAccount, NoQuestHintsForeverAPI = nil, nil, nil
    NoQuestHintsForeverLocale = {}
    SlashCmdList = {}
    WorldMapFrame, QuestMapFrame, QuestLogPopupDetailFrame, QuestObjectiveTracker = nil, nil, nil, nil
    MapCanvasDataProviderMixin, QuestBlobPinMixin, Menu, hooksecurefunc = nil, nil, nil, nil
    C_AddOns, GetAddOnMetadata = nil, nil
    CreateFrame = function()
        local frame = {events={}}
        function frame:RegisterEvent(event) self.events[event]=true end
        function frame:SetScript(_, fn) self.callback=fn end
        frames[#frames+1]=frame
        return frame
    end
    local function fire(event, ...)
        for _, frame in ipairs(frames) do
            if frame.events[event] then frame.callback(frame, event, ...) end
        end
    end
    C_Timer = {After=function(_, fn) timers[#timers+1]=fn end}
    InCombatLockdown = function() return combat end
    C_CVar = {
        GetCVar=function(name) return values[name] end,
        GetCVarInfo=function(name) return values[name], "1", name=="showInGameNavigation", name~="showInGameNavigation" end,
        SetCVar=function(name, value)
            assert(values[name], "unrelated CVar write")
            values[name]=value
            fire("CVAR_UPDATE", name)
        end,
    }
    C_SuperTrack = {
        GetSuperTrackedQuestID=function() return C_SuperTrack.current end,
        SetSuperTrackedQuestID=function(id)
            targetWrites=targetWrites+1
            C_SuperTrack.current=id
            fire("SUPER_TRACKING_CHANGED")
        end,
    }
    -- A filtered/incomplete journal must never be used as evidence of removal.
    C_QuestLog = {GetNumQuestLogEntries=function() error("cleanup scanned an incomplete quest log") end}
    assert(loadfile("NoQuestHintsForever/NoQuestHintsForever.lua"))()
    NoQuestHintsForeverChar=saved
    NoQuestHintsForeverAccount={}
    assert(loadfile("NoQuestHintsForever/QuestHints.lua"))()
    local api=NoQuestHintsForeverAPI
    api.RefreshQuestMarkers=function() refreshes=refreshes+1 end
    local function flush()
        local guard=0
        while #timers>0 do
            local pending=timers; timers={}
            for _, fn in ipairs(pending) do fn() end
            guard=guard+1; assert(guard<20, "timer recursion")
        end
    end
    fire("ADDON_LOADED", "NoQuestHintsForever")
    return {fire=fire, flush=flush, api=api, db=saved, values=values,
        refreshes=function() return refreshes end,
        targetWrites=function() return targetWrites end,
        combat=function(value) combat=value end}
end

local db={revealedQuests={[101]=true,[102]=true,[103]=true,[104]=true}}
local s=session(db)
s.fire("QUEST_REMOVED",101)
s.fire("QUEST_TURNED_IN",102)
s.fire("PLAYER_LOGIN"); s.fire("PLAYER_ENTERING_WORLD")
s.fire("QUEST_REMOVED",103); s.fire("QUEST_LOG_UPDATE"); s.flush()
assert(db.revealedQuests[101] and db.revealedQuests[102] and db.revealedQuests[103],
    "startup/partial quest log pruned saved permissions")
s.fire("LOADING_SCREEN_DISABLED"); s.flush()
s.api.SetMapHidden(true)
C_SuperTrack.SetSuperTrackedQuestID(101)
assert(s.values.showInGameNavigation=="1")
local count, writes=s.refreshes(),s.targetWrites()
s.fire("QUEST_REMOVED",101)
assert(db.revealedQuests[101]==nil and db.revealedQuests[102],"removal pruned the wrong quest")
assert(s.refreshes()==count,"native map refreshed inside synchronous quest event")
s.flush()
assert(s.refreshes()==count+1 and s.values.showInGameNavigation=="0",
    "removed supertracked quest kept visible guidance")
assert(C_SuperTrack.current==101 and s.targetWrites()==writes,"cleanup changed the native target")
s.fire("QUEST_TURNED_IN",101); s.fire("QUEST_REMOVED",101); s.flush()
assert(s.refreshes()==count+1,"duplicate removal refreshed unchanged state")

-- Completion/progress and map/filter changes do not mean turn-in.
s.fire("QUEST_LOG_UPDATE"); s.fire("QUEST_POI_UPDATE"); s.flush()
s.fire("QUEST_REMOVED",104,true)
assert(db.revealedQuests[102] and db.revealedQuests[103] and db.revealedQuests[104])
count=s.refreshes()
for _, id in ipairs({0,-1,1.5,"102",999}) do s.fire("QUEST_REMOVED",id) end
s.fire("QUEST_TURNED_IN"); s.flush()
assert(s.refreshes()==count and db.revealedQuests[102],"invalid/unrevealed ID changed state")

-- A real turn-in works with hiding OFF and does not override native navigation.
s.api.SetMapHidden(false)
count=s.refreshes()
s.fire("QUEST_TURNED_IN",102,200,50); s.fire("QUEST_REMOVED",102); s.flush()
assert(not db.revealedQuests[102] and s.refreshes()==count+1)
assert(s.values.showInGameNavigation=="1","cleanup while OFF changed native navigation")

-- Dirty refreshes wait for combat/loading, while confirmed live removals persist.
s.combat(true); count=s.refreshes()
s.fire("QUEST_REMOVED",103); s.flush()
assert(not db.revealedQuests[103] and s.refreshes()==count)
s.combat(false); s.fire("PLAYER_REGEN_ENABLED"); s.flush()
assert(s.refreshes()==count+1)
db.revealedQuests[107]=true; db.revealedQuests[108]=true
count=s.refreshes()
s.fire("QUEST_REMOVED",107); s.fire("QUEST_TURNED_IN",108)
s.combat(true); s.flush()
assert(s.refreshes()==count,"combat began after queueing but native work still ran")
s.combat(false); s.fire("PLAYER_REGEN_ENABLED"); s.flush()
assert(s.refreshes()==count+1 and not db.revealedQuests[107] and not db.revealedQuests[108],
    "batched removals lost cleanup or refreshed multiple times")
db.revealedQuests[105]=true
s.fire("QUEST_REMOVED",105)
s.fire("LOADING_SCREEN_ENABLED"); count=s.refreshes()
s.fire("QUEST_REMOVED",104); s.fire("QUEST_TURNED_IN",104); s.flush()
assert(db.revealedQuests[104] and not db.revealedQuests[105] and s.refreshes()==count,
    "loading removed permissions or ran pending map work")
s.fire("LOADING_SCREEN_DISABLED"); s.flush()
assert(s.refreshes()==count+1,"pending refresh did not resume after loading")
s.fire("PLAYER_LEAVING_WORLD"); s.fire("QUEST_REMOVED",104)
assert(db.revealedQuests[104],"leaving-world teardown removed active permissions")
s.fire("LOADING_SCREEN_DISABLED"); s.flush()
db.revealedQuests[106]=true
s.fire("QUEST_REMOVED",106); s.fire("PLAYER_LOGOUT"); count=s.refreshes()
s.fire("LOADING_SCREEN_DISABLED"); s.fire("QUEST_REMOVED",104); s.flush()
assert(db.revealedQuests[104] and s.refreshes()==count,"logout cleanup refreshed map or pruned active quest")

-- Reload keeps active entries and does not resurrect removed ones. Alts stay isolated.
local reload=session(db)
reload.fire("PLAYER_LOGIN"); reload.fire("PLAYER_ENTERING_WORLD")
reload.fire("QUEST_LOG_UPDATE"); reload.fire("LOADING_SCREEN_DISABLED"); reload.flush()
assert(db.revealedQuests[104] and not db.revealedQuests[101] and not db.revealedQuests[102])
local altDb={revealedQuests={[104]=true}}
local alt=session(altDb)
alt.fire("LOADING_SCREEN_DISABLED"); alt.fire("QUEST_REMOVED",104); alt.flush()
assert(not altDb.revealedQuests[104] and db.revealedQuests[104],"cleanup crossed character boundaries")

-- Reaccept/reveal before the deferred refresh cannot be erased by a stale callback.
alt.api.SetQuestRevealed(201,true)
alt.fire("QUEST_REMOVED",201)
alt.api.SetQuestRevealed(201,true)
alt.flush()
assert(altDb.revealedQuests[201],"deferred refresh erased a newly revealed quest")
io.write("PASS: confirmed quest cleanup, load/logout/combat gates, deferred navigation, reload and alts\n")
