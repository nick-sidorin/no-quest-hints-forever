-- Native QuestPinTemplate regression tests, Lua 5.1.
local function run(db, ready, initialHidden)
    NoQuestHintsForeverChar = db
    local hidden=initialHidden ~= false
    local map={id=9,pins={},count=0,releases=0,enters=0,leaves=0,tooltipRenders=0}
    function map:GetMapID() return self.id end
    function map:AddDataProvider(p) self.provider=p;self.count=self.count+1;p:OnAdded(self) end
    WorldMapFrame=map
    MapCanvasDataProviderMixin={
        OnAdded=function(self,m) self.map=m end,
        GetMap=function(self) return self.map end,
    }
    CreateFromMixins=function(proto) local o={};for k,v in pairs(proto) do o[k]=v end;return o end
    local styles={[15]="turnin"}
    local tracked=15
    POIButtonUtil={Style={QuestComplete="turnin",QuestDisabled="disabled",QuestInProgress="progress",Waypoint="waypoint"},
        GetStyle=function() error("shared QuestCache helper used") end}
    C_SuperTrack={GetSuperTrackedQuestID=function() return tracked end}
    C_QuestInfoSystem={GetQuestClassification=function(id) return "normal" end}
    function map:AcquirePin(template)
        assert(template=="NQHQuestMarkerPinTemplate")
        local pin={Display={ClearAllPoints=function() end,SetPoint=function() end}}
        function pin:SetQuestID(id) self.id=id end
        function pin:GetQuestID() return self.id end
        function pin:UseFrameLevelType(kind,offset) self.level=kind end
        function pin:SetSelected(value) self.selected=value end
        function pin:SetStyle(value) self.style=value;self.waypoint=value=="waypoint" end
        function pin:UpdateButtonStyle() assert(self:GetQuestClassification()=="normal") end
        function pin:EvaluateManagedHighlight() end
        function pin:SetPosition(x,y) self.x,self.y=x,y end
        function pin:OnMouseEnter() map.enters=map.enters+1;map.tooltipRenders=map.tooltipRenders+1 end
        function pin:OnMouseLeave() map.leaves=map.leaves+1 end
        pin.UpdateTooltip=pin.OnMouseEnter
        self.pins[#self.pins+1]=pin
        return pin
    end
    local function native()
        return {
            GetMap=function(self) return self.map end,
            RemoveAllData=function(self) self:GetMap().releases=self:GetMap().releases+1;self:GetMap().pins={} end,
            AddQuest=function() error("native AddQuest seeds shared QuestCache") end,
        }
    end
    QuestDataProviderMixin=ready and native() or nil
    local x14=.1
    GetQuestsOnMapCached=function() error("shared map query cache used") end
    C_QuestLog={
        IsComplete=function(id) return styles[id]=="turnin" end,
        IsQuestDisabledForSession=function(id) return styles[id]=="disabled" end,
        GetQuestsOnMap=function(id)
            if id~=9 then return {} end
            return {{questID=14,x=x14,y=.2},{questID=15,x=.7,y=.5},{questID=16,x=.4,y=.4},
                {questID=18,x=10,y=.4},{questID=15,x=.7,y=.5}}
        end,
        GetNextWaypointForMap=function(id,mapID)
            if id==21 and mapID==9 then return .3,.6 end
        end,
    }
    local callbacks={}
    CreateFrame=function()
        local f={}
        function f:RegisterEvent(name) callbacks[name]=true end
        function f:SetScript(name,fn) self.handler=fn end
        callbacks.frame=f
        return f
    end
    NoQuestHintsForeverAPI={
        IsMapHidden=function() return hidden end,
        IsQuestRevealed=function(id) return db.revealedQuests and db.revealedQuests[id]==true end,
    }
    assert(loadfile("NoQuestHintsForever/QuestMarkers.lua"))()
    local api=NoQuestHintsForeverAPI
    local function event(e)
        assert(callbacks[e]);callbacks.frame.handler(nil,e)
    end
    event("ADDON_LOADED")
    return {map=map,api=api,event=event,styles=styles,move=function(x) x14=x end,track=function(id) tracked=id end,unhide=function()hidden=false;api.RefreshQuestMarkers()end,
        hide=function()hidden=true;api.RefreshQuestMarkers()end,
        ready=function()QuestDataProviderMixin=native();event("ADDON_LOADED")end}
end

local db={revealedQuests={[14]=true,[15]=true,[18]=true,[21]=true}}
local s=run(db,true)
assert(s.map.count==1)
assert(#s.map.pins==3 and s.map.pins[1].id==14 and s.map.pins[2].id==15
    and s.map.pins[3].id==21,"filter, duplicate or waypoint incorrect")
assert(s.map.pins[2].style=="turnin","turn-in style lost")
assert(s.map.pins[3].waypoint==true)
local hovered=s.map.pins[2]
hovered:OnMouseEnter()
for _=1,20 do if hovered.UpdateTooltip then hovered:UpdateTooltip() end end
assert(s.map.enters==1, "stationary map tooltip repeatedly re-entered and rebuilt journal")
hovered:OnMouseLeave();hovered:OnMouseEnter()
assert(s.map.enters==2 and s.map.leaves==1 and s.map.tooltipRenders==2,
    "real hover transitions and native tooltip content must remain")
local releases=s.map.releases
for _=1,20 do s.event("QUEST_LOG_UPDATE");s.event("QUEST_POI_UPDATE") end
assert(s.map.pins[2]==hovered and s.map.releases==releases,
    "unchanged quest events recycled the hovered pin")
s.styles[15]="progress";s.api.RefreshQuestMarkers()
assert(s.map.pins[2]~=hovered and s.map.pins[2].style=="progress", "quest style change was ignored")
s.styles[15]="disabled";s.api.RefreshQuestMarkers()
assert(s.map.pins[2].style=="disabled", "disabled quest style was lost")
s.styles[15]="progress";s.api.RefreshQuestMarkers()
hovered=s.map.pins[2];s.track(14);s.event("SUPER_TRACKING_CHANGED")
assert(s.map.pins[2]~=hovered, "supertrack selection change was ignored")
hovered=s.map.pins[2];s.move(.25);s.event("QUEST_POI_UPDATE")
assert(s.map.pins[2]~=hovered and s.map.pins[1].x==.25, "new objective position was ignored")
hovered=s.map.pins[2]
s.map.provider:RemoveAllData();s.api.RefreshQuestMarkers()
assert(#s.map.pins==3 and s.map.pins[2]~=hovered, "external removal left cached pins missing")
s.unhide()
assert(#s.map.pins==0,"native global mode must remove custom pins")
s.hide()
assert(#s.map.pins==3)
db.revealedQuests[14]=nil
s.api.RefreshQuestMarkers()
assert(#s.map.pins==2 and s.map.pins[1].id==15)
s.map.id=10;s.map.provider:OnMapChanged()
assert(#s.map.pins==0)
s.map.id=9;s.map.provider:OnMapChanged()
assert(#s.map.pins==2)
s.event("QUEST_POI_UPDATE")
assert(#s.map.pins==2)
assert(#run({},true).map.pins==0,"alt inherited revealedQuests")
local later=run({revealedQuests={[15]=true}},false)
assert(later.map.count==0)
later.ready()
assert(later.map.count==1 and #later.map.pins==1)
for _, saved in ipairs({{}, {revealedQuests={[15]=true}}}) do
    local idle=run(saved,true,false)
    idle.event("PLAYER_LOGIN"); idle.event("PLAYER_ENTERING_WORLD")
    idle.event("QUEST_POI_UPDATE"); idle.api.RefreshQuestMarkers()
    assert(idle.map.count==0,"disabled map hints registered a native provider")
    idle.hide()
    if not saved.revealedQuests then
        assert(idle.map.count==0,"empty allowlist registered a native provider")
        saved.revealedQuests={[15]=true}
        idle.api.RefreshQuestMarkers()
    end
    assert(idle.map.count==1 and #idle.map.pins==1,"lazy marker initialization failed")
    idle.api.RefreshQuestMarkers()
    assert(idle.map.count==1,"lazy marker initialization duplicated provider")
end
io.write("PASS: Blizzard pin templates, turn-in/progress, per-quest map filtering and late load\n")
