-- Native QuestPinTemplate regression tests, Lua 5.1.
local function run(db, ready)
    NoQuestHintsForeverChar = db
    local hidden=true
    local map={id=9,pins={},count=0}
    function map:GetMapID() return self.id end
    function map:AddDataProvider(p) self.provider=p;self.count=self.count+1;p:OnAdded(self) end
    WorldMapFrame=map
    MapCanvasDataProviderMixin={
        OnAdded=function(self,m) self.map=m end,
        GetMap=function(self) return self.map end,
    }
    CreateFromMixins=function(proto) local o={};for k,v in pairs(proto) do o[k]=v end;return o end
    local function native()
        return {
            RemoveAllData=function(self) self:GetMap().pins={} end,
            AddQuest=function(self,id,x,y,index,waypoint)
                assert(self:GetPinTemplate()=="NQHQuestMarkerPinTemplate")
                assert(x>=0 and x<=1 and y>=0 and y<=1)
                local pins=self:GetMap().pins
                pins[#pins+1]={id=id,waypoint=waypoint,style=(id==15 and "turnin" or "progress")}
            end,
        }
    end
    QuestDataProviderMixin=ready and native() or nil
    GetQuestsOnMapCached=function(id)
        if id~=9 then return {} end
        return {{questID=14,x=.1,y=.2},{questID=15,x=.7,y=.5},{questID=16,x=.4,y=.4},
            {questID=18,x=10,y=.4}}
    end
    C_QuestLog={
        GetQuestsOnMap=function(id) return id==9 and {{questID=15,x=.7,y=.5}} or {} end,
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
    return {map=map,api=api,event=event,unhide=function()hidden=false;api.RefreshQuestMarkers()end,
        hide=function()hidden=true;api.RefreshQuestMarkers()end,
        ready=function()QuestDataProviderMixin=native();event("ADDON_LOADED")end}
end

local db={revealedQuests={[14]=true,[15]=true,[18]=true,[21]=true}}
local s=run(db,true)
assert(s.map.count==1)
io.write("DEBUG pins: "..#s.map.pins.." IDs: "..table.concat((function() local t={} for _,pin in ipairs(s.map.pins) do t[#t+1]=tostring(pin.id) end return t end)(),",").."\\n")
assert(#s.map.pins==3 and s.map.pins[1].id==14 and s.map.pins[2].id==15
    and s.map.pins[3].id==21,"filter, duplicate or waypoint incorrect")
assert(s.map.pins[2].style=="turnin","turn-in style lost")
assert(s.map.pins[3].waypoint==true)
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
io.write("PASS: Blizzard pin templates, turn-in/progress, per-quest map filtering and late load\n")
