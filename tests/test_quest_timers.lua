-- Preserve the real native widget's art, update and button behavior, not a replica.
local function session(saved, list, withNative, inCombat, missingAPI)
    local db=saved or {hideTracker=true}
    list=list or {{questID=1,questTimer=300}}
    local frames,deferred={},{}
    local function frame(kind,name,parent,template)
        assert(template==nil,'timer integration must not inherit a popup/secure template')
        local f={parent=parent,shown=true,scripts={},events={},alpha=0.8,ignore=false,points={}}
        function f:SetSize(w,h) self.width,self.height=w,h end
        function f:SetHeight(h) self.height=h end
        function f:SetWidth(w) self.width=w end
        function f:GetWidth() return self.width or 158 end
        function f:GetHeight() return self.height or 59 end
        function f:SetPoint(...) self.point={...};self.points[#self.points+1]=self.point end
        function f:ClearAllPoints() self.point=nil;self.points={} end
        function f:GetPoint(i) return unpack(self.points[i or 1],1,5) end
        function f:GetNumPoints() return #self.points end
        function f:GetParent() return self.parent end
        function f:GetFrameLevel() return 1 end
        function f:SetFrameLevel(v) self.level=v end
        function f:SetMovable(v) self.movable=v end
        function f:SetClampedToScreen(v) self.clamped=v end
        function f:RegisterForDrag(v) self.dragButton=v end
        function f:StartMoving() self.moving=true end
        function f:StopMovingOrSizing() self.moving=false end
        function f:GetCenter() return self.centerX or 512,self.centerY or 384 end
        function f:GetEffectiveScale() return 1 end
        function f:SetIgnoreParentAlpha(v) assert(not inCombat);self.ignore=v end
        function f:IsIgnoringParentAlpha() return self.ignore end
        function f:GetEffectiveAlpha()
            return self.alpha*(not self.ignore and self.parent and self.parent:GetEffectiveAlpha() or 1)
        end
        function f:IsShown() return self.shown end
        function f:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
        function f:IsForbidden() return self.forbidden or false end
        function f:Show()
            local was=self.shown;self.shown=true
            if not was and self.scripts.OnShow then self.scripts.OnShow(self) end
        end
        function f:Hide()
            local was=self.shown;self.shown=false
            if was and self.scripts.OnHide then self.scripts.OnHide(self) end
        end
        function f:EnableMouse(v) self.mouse=v end
        function f:SetText(v) self.text=v end
        function f:SetJustifyH() end
        function f:RegisterEvent(e) self.events[e]=true end
        function f:SetScript(e,fn) self.scripts[e]=fn end
        function f:HookScript(e,fn)
            local old=self.scripts[e]
            self.scripts[e]=function(...) if old then old(...) end;fn(...) end
        end
        function f:CreateFontString() return frame('FontString',nil,self) end
        frames[#frames+1]=f;if name then _G[name]=f end
        return f
    end
    CreateFrame=frame
    UIParent=frame('Frame');UIParent.alpha=1;UIParent:SetSize(1024,768)
    Minimap=frame('Frame',nil,UIParent)
    ObjectiveTrackerFrame=frame('Frame',nil,UIParent)
    ObjectiveTrackerFrame.alpha=db.hideTracker and 0 or 0.75
    NoQuestHintsForeverQuestTimers=nil;NoQuestHintsForeverQuestTimerAnchor=nil
    local opened,button,tick,click,enter,native
    GameTooltip={SetOwner=function(self,v) self.owner=v end,GetOwner=function(self) return self.owner end,
        SetText=function(self,v) self.text=v end,Show=function(self) self.shown=true end,
        Hide=function(self) self.shown=false end}
    local function makeNative()
        native=frame('Frame',nil,ObjectiveTrackerFrame);native.mouse=true
        native:SetPoint('TOP',ObjectiveTrackerFrame,'TOP',0,-10)
        button=frame('Button',nil,native);button.questID=1;button.mouse=true
        tick=function() native.nativeTicks=(native.nativeTicks or 0)+1 end
        click=function() opened=button.questID end
        enter=function() GameTooltip:SetOwner(button);GameTooltip:SetText('Quest '..button.questID);GameTooltip:Show() end
        native:SetScript('OnUpdate',tick)
        button:SetScript('OnClick',click);button:SetScript('OnEnter',enter)
        native.Update=function() error('addon must not call native updater') end
        native.UpdateIfNeeded=native.Update
        QuestTimerFrame=native
        return native
    end
    QuestTimerFrame=nil
    if withNative~=false then makeNative() end
    QuestMapFrame={DetailsFrame=frame('Frame',nil,UIParent)}
    QuestFrameDetailPanel=frame('Frame',nil,UIParent);QuestFrameDetailPanel:Hide()
    QuestFrameAcceptButton=frame('Button',nil,QuestFrameDetailPanel)
    QuestFrameDeclineButton=frame('Button',nil,QuestFrameDetailPanel)
    local offerID
    GetQuestID=function() return offerID end
    C_Timer={After=function(delay,fn) assert(delay==0);deferred[#deferred+1]=fn end}
    InCombatLockdown=function() return inCombat end
    C_QuestLog=not missingAPI and {GetQuestTimers=function() return list end,
        GetTimeAllowed=function(id) if id==3 then return 600,30 end end} or nil
    local api={IsQuestTimersHidden=function() return db.hideQuestTimers==true end,
        IsTrackerHidden=function() return db.hideTracker==true end,
        GetQuestTimerPosition=function() return db.questTimerPosition end,
        SetQuestTimerPosition=function(x,y) db.questTimerPosition={x=x,y=y} end}
    api.UpdateTracker=function()
        ObjectiveTrackerFrame.alpha=db.hideTracker and 0 or 0.75
        if native then
            native.mouse=not db.hideTracker or api.IsQuestTimerInputExempt(native)
            button.mouse=native.mouse
        end
        api.RefreshQuestTimers() -- exercise the actual core's deferred-refresh cycle
    end
    NoQuestHintsForeverAPI=api
    NoQuestHintsForeverLocale={TIMED_QUEST='Timed quest',TIMERS_MOVE_HINT='Drag to move.'}
    local before=#frames
    assert(loadfile('NoQuestHintsForever/QuestTimers.lua'))()
    local events=frames[before+1]
    local function flush()
        local n=0
        while #deferred>0 do n=n+1;assert(n<20,'native refresh loop');table.remove(deferred,1)() end
    end
    local function event(e) assert(events.events[e],e);events.scripts.OnEvent(events,e);flush() end
    local function label(parent)
        for _,f in ipairs(frames) do if f.parent==parent and f.text=='Timed quest' then return f end end
    end
    return {db=db,api=api,event=event,flush=flush,frame=function() return native end,
        button=function() return button end,
        handle=function()
            for _,f in ipairs(frames) do if f.parent==native and f.dragButton=='LeftButton' then return f end end
        end,
        assertCallbacks=function()
            assert(native.scripts.OnUpdate==tick and button.scripts.OnClick==click and button.scripts.OnEnter==enter)
            assert(not native.nativeTicks and button.questID==1,'addon updated native timer data')
        end,
        opened=function() return opened end,
        update=function(value) list=value;event('QUEST_LOG_UPDATE') end,
        loadNative=function() makeNative();event('ADDON_LOADED') end,
        combat=function(v) inCombat=v end,
        offer=function(id) offerID=id;QuestFrameDetailPanel:Show();event('QUEST_DETAIL') end,
        offerLabel=function() return label(QuestFrameDetailPanel) end,
        journalLabel=function() return label(QuestMapFrame.DetailsFrame) end,
        polling=function() return events.scripts.OnUpdate~=nil end,
    }
end

local saved={hideTracker=true}
local s=session(saved);s.event('PLAYER_ENTERING_WORLD')
local native=s.frame()
assert(native==QuestTimerFrame and native.parent==ObjectiveTrackerFrame)
assert(native.ignore and native:GetEffectiveAlpha()==0.8 and native.mouse and s.button().mouse)
assert(not NoQuestHintsForeverQuestTimers and not s.polling(),'custom timer rendering/polling was retained')
assert(s.journalLabel()==nil,'native journal was annotated')
s.assertCallbacks()
s.button().scripts.OnEnter();assert(GameTooltip.text=='Quest 1')
s.button().scripts.OnClick();assert(s.opened()==1,'native quest click stopped working')
local handle=s.handle();local anchor=NoQuestHintsForeverQuestTimerAnchor
assert(handle and anchor and native.point[2]==anchor)
assert(anchor.point[2]==Minimap and anchor.point[3]=='BOTTOM')
handle.scripts.OnDragStart();assert(anchor.moving and not native.moving,'drag must move the owned anchor')
anchor.centerX=600;anchor.centerY=300;handle.scripts.OnDragStop()
assert(not anchor.moving and saved.questTimerPosition.x==600/1024 and saved.questTimerPosition.y==300/768)
s.assertCallbacks()
s=session(saved,{{questID=1,questTimer=172}});s.event('PLAYER_ENTERING_WORLD')
assert(NoQuestHintsForeverQuestTimerAnchor.point[4]==600,'placement lost after reload')
s.assertCallbacks() -- native updater and client data remain the sole countdown source
UIParent:SetSize(2048,1536);s.event('DISPLAY_SIZE_CHANGED')
assert(NoQuestHintsForeverQuestTimerAnchor.point[4]==1200)
s.db.hideTracker=false;s.api.UpdateTracker();s.flush()
assert(not s.frame().ignore and s.frame().alpha==0.8 and s.button().mouse)
s.db.hideTracker=true;s.api.UpdateTracker();s.flush();assert(s.frame().ignore)
s.db.hideQuestTimers=true;s.api.RefreshQuestTimers();s.flush();assert(not s.frame().shown)
s.frame():Show();s.flush();assert(not s.frame().shown,'native reshow escaped timer hiding')
s.db.hideQuestTimers=false;s.api.RefreshQuestTimers();s.flush()
assert(s.frame().shown and s.button().mouse and s.frame().ignore)
s.update({});s.frame():Hide();s.flush()
assert(not s.frame().shown,'completed timer was forced visible')
s.event('PLAYER_LOGOUT')
assert(not s.frame().ignore and s.frame().point[2]==ObjectiveTrackerFrame,'native visual state was not restored')

s=session({hideTracker=true},nil,false);s.event('PLAYER_ENTERING_WORLD')
assert(not NoQuestHintsForeverQuestTimerAnchor,'missing native UI fabricated a replacement')
s.loadNative();assert(s.frame().ignore and s.frame().mouse,'late native timer not preserved')
s=session({hideTracker=true},nil,true,true);s.event('PLAYER_ENTERING_WORLD')
assert(not s.frame().ignore and not NoQuestHintsForeverQuestTimerAnchor,'combat mutated native timer')
s.combat(false);s.event('PLAYER_REGEN_ENABLED');assert(s.frame().ignore)
s.combat(true);s.handle().scripts.OnDragStart();assert(not NoQuestHintsForeverQuestTimerAnchor.moving)
s=session({hideTracker=true});s.frame().ignore=true;s.event('PLAYER_ENTERING_WORLD');s.event('PLAYER_LOGOUT')
assert(s.frame().ignore,'pre-existing ignore-parent-alpha choice was lost')
s=session({hideTracker=true});s.frame().forbidden=true;s.event('PLAYER_ENTERING_WORLD')
assert(not NoQuestHintsForeverQuestTimerAnchor,'forbidden native timer was modified')
s=session({hideTracker=true});s.frame().parent=UIParent;s.event('PLAYER_ENTERING_WORLD')
assert(not s.frame().ignore and s.frame().parent==UIParent,'independent timer was reparented or recolored')

s=session({hideTracker=true,hideQuestTimers=true});s.event('PLAYER_ENTERING_WORLD')
s.offer(3);assert(s.offerLabel().shown and s.offerLabel().point[2]==QuestFrameDeclineButton)
s.offer(2);assert(not s.offerLabel().shown,'another active timer classified this offer')
s.offer(1);s.event('QUEST_FINISHED');assert(not s.offerLabel().shown)
s.offer(1);s.event('QUEST_PROGRESS');assert(not s.offerLabel().shown)
s.offer(1);QuestFrameDetailPanel:Hide();assert(not s.offerLabel().shown)
s.offer(1);s.combat(true);s.offer(2);assert(not s.offerLabel().shown)
s=session({},nil,true,false,true);s.event('PLAYER_ENTERING_WORLD');s.offer(3)
assert(not s.offerLabel().shown,'missing API fabricated pre-acceptance metadata')
io.write('PASS: actual native timer visibility/input, original callbacks, header dragging, restoration, reload, combat and NPC scope\n')
