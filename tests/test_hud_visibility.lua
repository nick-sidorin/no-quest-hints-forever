-- Native HUD visibility: preserve the latest native intent and select XP only.
local function session(xpHidden, mapHidden, late)
    local pending, frames, combat, hooks = {}, {}, false, 0
    local xp, minimap = xpHidden, mapHidden
    NoQuestHintsForeverAPI = {
        IsExperienceBarHidden=function() return xp end,
        IsMinimapHidden=function() return minimap end,
    }
    C_Timer={After=function(_, fn) pending[#pending+1]=fn end}
    InCombatLockdown=function() return combat end
    EventRegistry=nil
    hooksecurefunc=function(obj, name, fn)
        hooks=hooks+1
        local original=obj[name]
        obj[name]=function(self, ...)
            original(self, ...)
            fn(self, ...)
        end
    end
    local function frame(shown)
        local f={shown=shown, scripts={}, forbidden=false}
        function f:IsForbidden() return self.forbidden end
        function f:IsShown() return self.shown end
        function f:Show() assert(not combat); self.shown=true end
        function f:HideBase() assert(not combat); self.shown=false end
        function f:Hide() self.layoutChanges=(self.layoutChanges or 0)+1; self:HideBase() end
        function f:SetShown(value) if value then self:Show() else self:Hide() end end
        function f:RegisterEvent() end
        function f:SetScript(name, fn) self.scripts[name]=fn end
        frames[#frames+1]=f
        return f
    end
    CreateFrame=function() return frame(false) end
    local map=frame(true)
    local function container(index)
        local f=frame(true)
        f.bars={[4]={isExpBar=true},[1]={}}
        f.shownBarIndex=index
        function f:ApplyPendingBarToShow() self.shownBarIndex=self.pendingBarToShowIndex end
        function f:UpdateShownState() self:SetShown(self.shownBarIndex~=-1) end
        return f
    end
    local first, second=container(4), container(1)
    local manager=frame(true)
    manager.barContainers={first,second}
    function manager:UpdateBarsShown() end
    MinimapCluster=not late and map or nil
    StatusTrackingBarManager=not late and manager or nil
    assert(loadfile('NoQuestHintsForever/HUDVisibility.lua'))()
    local api=NoQuestHintsForeverAPI
    local function flush()
        local count=0
        while #pending>0 do
            count=count+1; assert(count<20,'refresh loop')
            local callbacks=pending;pending={}
            for _,fn in ipairs(callbacks) do fn() end
        end
    end
    return {api=api,map=map,first=first,second=second,manager=manager,
        flush=flush,frame=frame,hooks=function() return hooks end,
        set=function(x,m) xp=x;minimap=m;api.RefreshHUDVisibility();flush() end,
        combat=function(v) combat=v end,
        event=function(e) frames[#frames].scripts.OnEvent(nil,e);flush() end,
        late=function() MinimapCluster=map;StatusTrackingBarManager=manager end}
end

local s=session(false,false)
s.event('PLAYER_LOGIN')
assert(s.hooks()==0 and s.map.shown and s.first.shown,'OFF must be inert')
s.set(true,false)
assert(not s.first.shown and s.second.shown and s.map.shown,'XP only, leave reputation')
assert(not s.first.layoutChanges,'must not invoke EditMode layout-breaking Hide wrapper')
s.first:Show();s.flush();assert(not s.first.shown,'native XP refresh escaped')
s.set(false,true)
assert(s.first.shown and not s.map.shown and s.second.shown,'independent toggles')
s.map:Show();s.flush();assert(not s.map.shown)
s.map:Hide();s.flush()
s.set(false,false)
assert(not s.map.shown,'restore must honor a later native Hide, not initial Show')
s.map:Show()
s.set(false,true);s.set(false,false)
assert(s.map.shown,'restore initial native visibility')

s.set(true,false)
s.first.pendingBarToShowIndex=1;s.first:ApplyPendingBarToShow();s.first:UpdateShownState();s.flush()
assert(s.first.shown,'XP container reused for reputation must be restored')
s.second.pendingBarToShowIndex=4;s.second:ApplyPendingBarToShow();s.second:UpdateShownState();s.flush()
assert(not s.second.shown and s.first.shown,'XP moved to second container')
s.second.pendingBarToShowIndex=-1;s.second:ApplyPendingBarToShow();s.second:UpdateShownState();s.flush()
assert(not s.second.shown,'native empty container stays hidden')
s.set(false,false)
assert(not s.second.shown)

s=session(false,false)
s.combat(true);s.set(true,true)
assert(s.map.shown and s.first.shown,'must defer in combat')
s.combat(false);s.event('PLAYER_REGEN_ENABLED')
assert(not s.map.shown and not s.first.shown)
s.combat(true);s.set(false,false)
assert(not s.map.shown and not s.api.RestoreHUDVisibility(),'pending restore must report failure')
s.combat(false);s.event('PLAYER_REGEN_ENABLED')
assert(s.map.shown and s.first.shown and s.api.RestoreHUDVisibility())

s=session(true,true,true)
s.event('PLAYER_LOGIN');assert(s.hooks()==0)
s.late();s.event('ADDON_LOADED')
assert(not s.first.shown and not s.map.shown,'late UI loading')
s.first.isInEditMode=true;s.map.isInEditMode=true
s.api.RefreshHUDVisibility();s.flush()
assert(s.first.shown and s.map.shown,'show actual widgets in EditMode')
s.first.isInEditMode=false;s.map.isInEditMode=false
s.api.RefreshHUDVisibility();s.flush()
assert(not s.first.shown and not s.map.shown)
s.event('PLAYER_LOGOUT')
assert(s.first.shown and s.map.shown,'restore on normal logout')
s.event('PLAYER_ENTERING_WORLD');assert(s.first.shown and s.map.shown,'queued work after logout')

s=session(true,true)
s.map.forbidden=true;s.first.forbidden=true
s.event('PLAYER_LOGIN');assert(s.map.shown and s.first.shown,'leave forbidden UI alone')
s.map.forbidden=false;s.first.forbidden=false
s.event('ADDON_LOADED');assert(not s.map.shown and not s.first.shown)
s.first:Hide();s.flush();s.set(false,false)
assert(not s.first.shown,'restore respects native hidden intent even when already hidden')
-- Keep recovery state until a failed visibility write can be retried.
s=session(false,false)
s.map.shown=false
s.set(false,true);s.set(false,false)
assert(not s.map.shown, 'initially hidden minimap must stay hidden')
s.map:Show();s.set(false,true)
local show=s.map.Show
s.map.Show=function() error('temporarily blocked') end
s.set(false,false)
assert(not s.api.RestoreHUDVisibility(), 'failed restore lost its snapshot')
s.map.Show=show;s.event('PLAYER_REGEN_ENABLED')
assert(s.map.shown and s.api.RestoreHUDVisibility())
local count=s.hooks()
s.set(false,true);s.set(false,false);s.set(false,true)
assert(s.hooks()==count, 'repeated toggles installed duplicate hooks')
s.combat(true);s.set(false,false);s.set(false,true)
s.combat(false);s.event('PLAYER_REGEN_ENABLED')
assert(not s.map.shown, 'combat retry ignored the latest requested preference')
io.write('PASS: independent native HUD hiding, XP/reputation reuse, native visibility intent, combat, late UI and logout\n')
