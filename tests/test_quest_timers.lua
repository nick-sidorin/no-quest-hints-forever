-- Client-sourced countdowns, native isolation, timed detail labels and reload recovery.
local function session(saved, initial, withNative, inCombat, missingAPI)
    local list=initial or {}
    local db=saved or {hideTracker=true}
    local frames, deferred, hooks={}, {}, {}
    local lifecycle
    local function frame(kind,name,parent,template)
        assert(not template or template=='BackdropTemplate','unexpected inherited timer template')
        local f={parent=parent,shown=true,scripts={},events={},alpha=0.8}
        function f:SetSize(w,h) self.width,self.height=w,h end
        function f:SetHeight(h) self.height=h end
        function f:SetWidth(w) self.width=w end
        function f:SetPoint(...) self.point={...};self.points=self.points or {};self.points[#self.points+1]=self.point end
        function f:ClearAllPoints() self.point=nil;self.points={} end
        function f:SetAllPoints(target) self.allPoints=target end
        function f:SetFrameLevel(level) self.level=level end
        function f:GetFrameLevel() return self.level or 1 end
        function f:SetMovable(value) self.movable=value end
        function f:SetClampedToScreen(value) self.clamped=value end
        function f:RegisterForDrag(button) self.dragButton=button end
        function f:StartMoving() self.moving=true end
        function f:StopMovingOrSizing() self.moving=false end
        function f:GetCenter() return self.centerX or 512,self.centerY or 384 end
        function f:GetEffectiveScale() return self.scale or 1 end
        function f:GetWidth() return self.width end
        function f:GetHeight() return self.height end
        function f:SetJustifyH() end
        function f:SetText(s) self.text=s end
        function f:GetText() return self.text end
        function f:Hide()
            local was=self.shown;self.shown=false
            if was and self.scripts.OnHide then self.scripts.OnHide(self) end
        end
        function f:IsShown() return self.shown end
        function f:GetEffectiveAlpha() return self.alpha*(self.parent and self.parent:GetEffectiveAlpha() or 1) end
        function f:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
        function f:Show()
            local was=self.shown;self.shown=true
            if not was and self.scripts.OnShow then self.scripts.OnShow(self) end
        end
        function f:EnableMouse(value) self.mouse=value end
        function f:SetBackdrop(value) self.backdrop=value end
        function f:SetBackdropColor() end
        function f:SetScript(e,fn) self.scripts[e]=fn end
        function f:HookScript(e,fn)
            local old=self.scripts[e]
            self.scripts[e]=function(...) if old then old(...) end;fn(...) end
        end
        function f:RegisterEvent(e) self.events[e]=true end
        function f:CreateFontString() return frame('FontString',nil,self) end
        frames[#frames+1]=f
        if name then _G[name]=f end
        return f
    end
    CreateFrame=frame
    UIParent=frame('Frame');UIParent:SetSize(1024,768)
    Minimap=frame('Frame',nil,UIParent)
    GameTooltip=nil
    NineSliceUtil={
        GetLayout=function(name) assert(name=='Dialog');return {} end,
        ApplyLayoutByName=function(owner,name) assert(name=='Dialog');owner.dialog=true end,
        UpdateCornerCropping=function(owner,height) assert(owner.NineSlice.dialog and height==owner.height) end,
    }
    NoQuestHintsForeverQuestTimers=nil
    ObjectiveTrackerFrame=frame('Frame',nil,UIParent)
    function ObjectiveTrackerFrame:GetEffectiveAlpha() return db.hideTracker and 0 or 1 end
    QuestTimerFrame=withNative and frame('Frame',nil,ObjectiveTrackerFrame) or nil
    QuestMapFrame={DetailsFrame=frame('Frame',nil,UIParent)}
    QuestMapFrame.DetailsFrame.BackFrame=frame('Frame',nil,QuestMapFrame.DetailsFrame)
    QuestMapFrame.DetailsFrame.questID=1
    QuestFrameDetailPanel=frame('Frame',nil,UIParent)
    QuestFrameDetailPanel:Hide()
    QuestFrameAcceptButton=frame('Button',nil,QuestFrameDetailPanel)
    QuestFrameDeclineButton=frame('Button',nil,QuestFrameDetailPanel)
    local offerID
    GetQuestID=function() return offerID end
    QuestMapFrame_ShowQuestDetails=function() end
    hooksecurefunc=function(name,fn) hooks[name]=fn end
    C_Timer={After=function(delay,fn) assert(delay==0);deferred[#deferred+1]=fn end}
    InCombatLockdown=function() return inCombat end
    local api={
        IsQuestTimersHidden=function() return db.hideQuestTimers==true end,
        IsTrackerHidden=function() return db.hideTracker==true end,
        GetQuestTimerPosition=function() return db.questTimerPosition end,
        SetQuestTimerPosition=function(x,y) db.questTimerPosition={x=x,y=y} end,
    }
    NoQuestHintsForeverAPI=api
    NoQuestHintsForeverLocale={TIMED_QUEST='Timed quest',TIMERS_MOVE_HINT='Drag to move.'}
    local queries=0
    C_QuestLog=not missingAPI and {
        GetQuestTimers=function() queries=queries+1;return list end,
        GetTitleForQuestID=function(id) return 'Quest '..id end,
        GetTimeAllowed=function(id) if id==3 then return 600,30 end end,
    } or nil
    local before=#frames
    assert(loadfile('NoQuestHintsForever/QuestTimers.lua'))()
    lifecycle=frames[before+1]
    local function flush()
        local count=0
        while #deferred>0 do count=count+1;assert(count<20,'timer refresh loop');table.remove(deferred,1)() end
    end
    local function event(e)
        assert(lifecycle.events[e],e);lifecycle.scripts.OnEvent(lifecycle,e);flush()
    end
    local function clock(index)
        local p=NoQuestHintsForeverQuestTimers
        local titles,clocks={},{}
        for _,f in ipairs(frames) do
            if p and f.parent and f.parent.parent==p and f.text then
                if f.text:match('^%d+:%d%d$') then clocks[#clocks+1]=f.text else titles[#titles+1]=f.text end
            end
        end
        return clocks[index or 1],titles[index or 1]
    end
    local function label()
        for _,f in ipairs(frames) do if f.parent==QuestMapFrame.DetailsFrame and f.text=='Timed quest' then return f end end
    end
    return {api=api,db=db,event=event,flush=flush,clock=clock,label=label,
        update=function(value) list=value;event('QUEST_LOG_UPDATE') end,
        tick=function(delta) if lifecycle.scripts.OnUpdate then lifecycle.scripts.OnUpdate(lifecycle,delta or 0.25) end;flush() end,
        polling=function() return lifecycle.scripts.OnUpdate~=nil end,
        combat=function(v) inCombat=v end,queries=function() return queries end,
        select=function(id) QuestMapFrame.DetailsFrame.questID=id;event('QUEST_LOG_UPDATE') end,
        offer=function(id) offerID=id;QuestFrameDetailPanel:Show();event('QUEST_DETAIL') end,
        offerLabel=function()
            for _,f in ipairs(frames) do if f.parent==QuestFrameDetailPanel and f.text=='Timed quest' then return f end end
        end,
    }
end

local saved={hideTracker=true}
local s=session(saved,{{questID=1,questTimer=300}})
s.event('LOADING_SCREEN_DISABLED')
assert(NoQuestHintsForeverQuestTimers.shown and s.clock()=='5:00')
assert(s.label()==nil,'addon must not annotate the native quest journal')
assert(saved.hideQuestTimers==nil and saved.expiry==nil,'timer state must not persist')
local queries=s.queries()
s.tick(0.1);assert(s.queries()==queries,'timer API queried every frame')
s.tick(0.15);assert(s.clock()=='5:00','addon invented elapsed time instead of reading the client')
s.update({{questID=1,questTimer=258}})
assert(s.clock()=='4:18','countdown did not re-read client time')
s.event('PLAYER_LOGOUT')
assert(not NoQuestHintsForeverQuestTimers.shown and not s.polling())
-- A new Lua session (reload/full login) must reconstruct solely from current API data.
s=session(saved,{{questID=1,questTimer=172}})
s.event('PLAYER_ENTERING_WORLD')
assert(s.clock()=='2:52','reload restarted a countdown instead of using client remaining time')
s.event('LOADING_SCREEN_ENABLED')
assert(not NoQuestHintsForeverQuestTimers.shown and not s.polling())
s.event('LOADING_SCREEN_DISABLED');assert(s.clock()=='2:52')
s.db.hideQuestTimers=true;s.api.RefreshQuestTimers();s.flush()
assert(not NoQuestHintsForeverQuestTimers.shown and s.label()==nil,'hiding timers changed native journal content')
s.select(2);assert(s.label()==nil)
s.select(3);assert(s.label()==nil)
s.select(1)
s.update({{questID=2,questTimer=61},{questID=4,questTimer=30}})
assert(s.label()==nil,'addon note leaked into native journal')
s.db.hideQuestTimers=false;s.api.RefreshQuestTimers();s.flush()
assert(s.clock(1)=='1:01' and s.clock(2)=='0:30','multiple timers are not client sourced')
s.update({});assert(not NoQuestHintsForeverQuestTimers.shown and not s.polling(),'empty list kept UI/polling')

s=session({hideTracker=false},{{questID=1,questTimer=100}},true)
s.event('PLAYER_ENTERING_WORLD')
assert(not NoQuestHintsForeverQuestTimers,'native countdown duplicated')
s.db.hideQuestTimers=true;s.api.RefreshQuestTimers();s.flush()
assert(not QuestTimerFrame.shown,'native timer not suppressed')
QuestTimerFrame:Show();s.flush();assert(not QuestTimerFrame.shown,'late native show escaped suppression')
s.db.hideQuestTimers=false;s.api.RefreshQuestTimers();s.flush()
assert(QuestTimerFrame.shown,'native timer not restored')
assert(QuestTimerFrame.alpha==0.8,'timer changed native alpha')
s.db.hideTracker=true;s.api.RefreshQuestTimers();s.flush()
assert(NoQuestHintsForeverQuestTimers.shown,'hidden tracker swallowed remaining time')
QuestTimerFrame.parent=UIParent;s.api.RefreshQuestTimers();s.flush()
assert(not NoQuestHintsForeverQuestTimers.shown,'independent native timer duplicated under UIParent')
QuestTimerFrame.parent=ObjectiveTrackerFrame;s.api.RefreshQuestTimers();s.flush()
s.db.hideQuestTimers=true;s.combat(true);s.api.RefreshQuestTimers();s.flush()
assert(not NoQuestHintsForeverQuestTimers.shown,'private timer must hide even in combat')
s.combat(false);s.event('PLAYER_REGEN_ENABLED');assert(not QuestTimerFrame.shown)
s.update({});s.db.hideQuestTimers=false;s.api.RefreshQuestTimers();s.flush()
assert(not QuestTimerFrame.shown,'completed timer restored stale native visibility')

s=session({hideTracker=true},{{questID=1,questTimer=1}},false,false,true)
s.event('PLAYER_ENTERING_WORLD')
assert(not NoQuestHintsForeverQuestTimers and s.label()==nil,'missing API fabricated a timer')
s=session({hideTracker=true},{{questID=1,questTimer=0},{questID=2,questTimer=-1},{questID=3,questTimer=math.huge},false})
s.event('PLAYER_ENTERING_WORLD');assert(not NoQuestHintsForeverQuestTimers,'invalid/expired time rendered')
-- Compact native dialog art, one line, drag persistence and resolution changes.
local movable={hideTracker=true}
s=session(movable,{{questID=1,questTimer=100}})
s.event('PLAYER_ENTERING_WORLD')
local window=NoQuestHintsForeverQuestTimers
assert(window.width==190 and window.height==34 and window.NineSlice.dialog)
assert(window.point[1]=='TOP' and window.point[2]==Minimap and window.point[3]=='BOTTOM')
assert(window.movable and window.clamped and window.dragButton=='LeftButton')
assert(not window.backdrop.edgeFile,'native nine-slice also drew a fallback border')
window.scripts.OnDragStart();assert(window.moving)
window.centerX=600;window.centerY=300
window.scripts.OnDragStop();assert(not window.moving)
assert(movable.questTimerPosition.x==600/1024 and movable.questTimerPosition.y==300/768)
s=session(movable,{{questID=1,questTimer=80}})
s.event('PLAYER_ENTERING_WORLD');window=NoQuestHintsForeverQuestTimers
assert(window.point[1]=='CENTER' and window.point[4]==600 and window.point[5]==300,'dragged position lost on reload')
UIParent:SetSize(2048,1536);s.event('DISPLAY_SIZE_CHANGED')
assert(window.point[4]==1200 and window.point[5]==600,'saved placement did not adapt to resolution')
window.scripts.OnDragStart();s.update({})
assert(not window.moving and not window.shown,'hidden timer kept dragging')
s=session({},{{questID=1,questTimer=20}})
NineSliceUtil=nil;s.event('PLAYER_ENTERING_WORLD')
assert(NoQuestHintsForeverQuestTimers.backdrop.edgeFile=='Interface\\DialogFrame\\UI-DialogBox-Gold-Border')

-- NPC offers use the offered ID, not the selected journal quest or another
-- active timer. Client metadata may be unavailable until acceptance.
s=session({hideTracker=true,hideQuestTimers=true},{{questID=1,questTimer=120}})
s.event('PLAYER_ENTERING_WORLD')
s.offer(3) -- GetTimeAllowed can identify this offer without an active timer.
assert(s.offerLabel().shown and s.offerLabel().text=='Timed quest')
assert(s.offerLabel().points[1][2]==QuestFrameAcceptButton and s.offerLabel().point[2]==QuestFrameDeclineButton)
assert(not NoQuestHintsForeverQuestTimers,'hidden timers should not reveal seconds on an NPC offer')
s.offer(2)
assert(not s.offerLabel().shown,'unclassified offer inherited another quest timer')
s.offer(1);assert(s.offerLabel().shown,'known active timed quest not identified at NPC')
s.event('QUEST_FINISHED');assert(not s.offerLabel().shown,'offer label survived conversation end')
s.offer(1);s.event('QUEST_PROGRESS');assert(not s.offerLabel().shown,'offer note leaked into turn-in UI')
s.offer(1);QuestFrameDetailPanel:Hide();assert(not s.offerLabel().shown)
s.offer(1);s.combat(true);s.offer(2)
assert(not s.offerLabel().shown,'combat-deferred update leaked previous offer marker')
s=session({}, {}, false, false, true)
s.event('PLAYER_ENTERING_WORLD');s.offer(3)
assert(not s.offerLabel().shown,'missing API fabricated a pre-acceptance timed flag')
io.write('PASS: client timer reload recovery, multiple quests, independent hiding, native restoration, combat/loading, compact draggable UI and NPC-offer metadata\n')
