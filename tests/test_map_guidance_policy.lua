-- Real core, selective native blob and marker modules: four independent modes.
local function session(saved, original)
    NoQuestHintsForeverChar=saved or {};NoQuestHintsForeverAccount={}
    NoQuestHintsForeverAPI=nil;NoQuestHintsForeverLocale={};NQHQuestBlobPinMixin={}
    ObjectiveTrackerFrame=nil;QuestMapFrame=nil;QuestObjectiveTracker=nil
    QuestLogPopupDetailFrame=nil;hooksecurefunc=nil;Menu=nil;C_AddOns=nil
    SlashCmdList={};print=function()end;InCombatLockdown=function()return false end
    local frames,queued={},{}
    C_Timer={After=function(_,fn)queued[#queued+1]=fn end}
    CreateFrame=function()
        local f={events={}}
        function f:RegisterEvent(e)self.events[e]=true end
        function f:SetScript(_,fn)self.handler=fn end
        frames[#frames+1]=f;return f
    end
    local function event(e,...)
        for _,f in ipairs(frames)do if f.events[e]then f.handler(f,e,...)end end
    end
    local function flush()
        while #queued>0 do local batch=queued;queued={};for _,fn in ipairs(batch)do fn()end end
    end
    local values={}
    for _,key in ipairs({'questPOI','showQuestObjectivesOnMap','questPOILocalStory','minimapShowQuestBlobs','showInGameNavigation'})do values[key]=original or '1' end
    C_CVar={GetCVar=function(k)return values[k]end,
        SetCVar=function(k,v)values[k]=v;event('CVAR_UPDATE',k)end}
    local complete={[22]=true,[33]=true}
    local tracked=11
    C_SuperTrack={GetSuperTrackedQuestID=function()return tracked end,
        SetSuperTrackedQuestID=function(id)tracked=id;event('SUPER_TRACKING_CHANGED')end}
    C_QuestLog={
        ReadyForTurnIn=function(id)return complete[id]==true end,
        IsComplete=function()error('ReadyForTurnIn takes precedence')end,
        GetNumQuestLogEntries=function()return 4 end,
        GetInfo=function(i)return ({ {questID=11},{questID=22},{questID=33},{isHeader=true} })[i]end,
        GetQuestsOnMap=function(id)if id==1 then return {{questID=11,x=.2,y=.3},{questID=22,x=.7,y=.8}}end return {}end,
        GetNextWaypointForMap=function(id,mapID)if id==33 and mapID==1 then return .4,.5 end end,
        AddQuestWatch=function()error('watch list changed')end,
        RemoveQuestWatch=function()error('watch list changed')end,
    }
    GetQuestsOnMapCached=function()error('shared map cache')end
    POIButtonUtil={Style={QuestComplete='?',QuestInProgress='...',Waypoint='waypoint'},GetStyle=function()error('shared quest cache')end}
    C_QuestInfoSystem={GetQuestClassification=function()return 'normal'end}
    MapCanvasDataProviderMixin={OnAdded=function(self,map)self.map=map end,GetMap=function(self)return self.map end}
    CreateFromMixins=function(proto)local t={};for k,v in pairs(proto)do t[k]=v end;return t end
    QuestDataProviderMixin={GetMap=MapCanvasDataProviderMixin.GetMap,
        RemoveAllData=function(self)self:GetMap().pins={}end}
    QuestBlobPinMixin={OnLoad=function()end,
        OnMapChanged=function(self)self.mapAllowsBlobs=true;self:Refresh()end,
        TryDrawQuest=function(self,id)self.drawn[id]=true end}
    local map={id=1,pins={},providers={}}
    function map:GetMapID()return self.id end
    function map:AddDataProvider(p)self.providers[#self.providers+1]=p;p:OnAdded(self)end
    function map:AcquirePin(template)
        if template=='NQHQuestBlobPinTemplate'then
            local pin=CreateFromMixins(NQHQuestBlobPinMixin)
            function pin:GetMap()return map end
            function pin:SetPosition()end
            function pin:DrawNone()self.drawn={}end
            self.blob=pin;pin.drawn={};return pin
        end
        assert(template=='NQHQuestMarkerPinTemplate')
        local pin={Display={ClearAllPoints=function()end,SetPoint=function()end}}
        function pin:SetQuestID(id)self.id=id end
        function pin:GetQuestID()return self.id end
        function pin:UseFrameLevelType()end
        function pin:SetSelected()end
        function pin:SetStyle(style)self.style=style end
        function pin:UpdateButtonStyle()self:GetQuestClassification()end
        function pin:EvaluateManagedHighlight()end
        function pin:SetPosition(x,y)self.x,self.y=x,y end
        self.pins[#self.pins+1]=pin;return pin
    end
    WorldMapFrame=map
    assert(loadfile('NoQuestHintsForever/NoQuestHintsForever.lua'))()
    assert(loadfile('NoQuestHintsForever/QuestHints.lua'))()
    assert(loadfile('NoQuestHintsForever/QuestMarkers.lua'))()
    event('ADDON_LOADED','NoQuestHintsForever');event('PLAYER_LOGIN');event('LOADING_SCREEN_DISABLED');flush()
    local api=NoQuestHintsForeverAPI
    return {api=api,char=NoQuestHintsForeverChar,values=values,map=map,complete=complete,event=event,
        track=function(id)tracked=id;event('SUPER_TRACKING_CHANGED')end,
        refresh=function()event('QUEST_LOG_UPDATE');flush()end}
end
local function pins(s,ids)
    local actual={};for _,pin in ipairs(s.map.pins)do actual[pin.id]=pin.style end
    local count=0;for id,style in pairs(ids)do assert(actual[id]==style,'missing/wrong pin '..id);count=count+1 end
    assert(#s.map.pins==count,'unexpected map pin')
end
local s=session({enabled=true})
assert(s.char.hideQuestTurnIns==true,'legacy ON did not migrate')
pins(s,{})
s.api.SetQuestTurnInsHidden(false)
pins(s,{[22]='?',[33]='?'})
assert(not s.map.blob,'turn-ins alone must not create objective layer')
assert(s.values.questPOI=='0' and s.values.showInGameNavigation=='0')
s.track(22);assert(s.values.showInGameNavigation=='1')
s.track(11);assert(s.values.showInGameNavigation=='0')
s.complete[11]=true;s.refresh();pins(s,{[11]='?',[22]='?',[33]='?'})
assert(s.values.showInGameNavigation=='1','completion did not re-evaluate navigation')
s.complete[11]=false;s.refresh();assert(s.values.showInGameNavigation=='0')
s.api.SetQuestRevealed(11,true);pins(s,{[11]='...',[22]='?',[33]='?'})
assert(s.map.blob.drawn[11] and s.values.showInGameNavigation=='1')
s.api.SetQuestRevealed(11,false);pins(s,{[22]='?',[33]='?'})
assert(not s.map.blob.drawn[11] and s.values.showInGameNavigation=='0')
s.api.SetQuestObjectivesHidden(false);assert(not s.api.IsMapHidden())
assert(s.values.questPOI=='1');pins(s,{})
s.api.SetQuestTurnInsHidden(true)
pins(s,{[11]='...'})
assert(s.map.blob.drawn[11] and not s.map.blob.drawn[22] and not s.map.blob.drawn[33])
s.track(22);assert(s.values.showInGameNavigation=='0')
s.api.SetQuestRevealed(22,true);pins(s,{[11]='...',[22]='?'})
assert(s.values.showInGameNavigation=='1')
s.api.SetQuestRevealed(22,false);assert(s.values.showInGameNavigation=='0')
s.api.SetQuestObjectivesHidden(true);pins(s,{})
assert(not next(s.map.blob.drawn))
for _,preset in ipairs({'blizzard','immersion','full'})do
    assert(s.api.ApplyPreset(preset))
    assert(s.char.enabled==(preset~='blizzard') and s.char.hideQuestTurnIns==(preset~='blizzard'))
end
s.api.RestoreGameSettings();assert(not s.char.enabled and not s.char.hideQuestTurnIns)
-- Explicit split choices survive reload and are isolated across characters.
s=session({enabled=true,hideQuestTurnIns=false});pins(s,{[22]='?',[33]='?'})
s=session(s.char);assert(s.char.enabled and not s.char.hideQuestTurnIns);pins(s,{[22]='?',[33]='?'})
s=session({enabled=false});assert(not s.char.hideQuestTurnIns and not s.api.IsOnboardingPending())
s=session({});assert(not s.char.hideQuestTurnIns and s.api.IsOnboardingPending())
s=session({enabled=false,hideQuestTurnIns=true},'0');s.api.RestoreGameSettings()
assert(s.values.questPOI=='0' and s.values.showInGameNavigation=='0','personal baseline lost')
-- Missing readiness is not guessed from titles or synthetic cache entries.
C_QuestLog.ReadyForTurnIn=nil;C_QuestLog.IsComplete=nil
assert(not s.api.IsQuestReadyForTurnIn(11))
io.write('PASS: split map policy, migration, four modes, real native layers, completion, navigation, reload, manual overrides and personal restoration\n')
