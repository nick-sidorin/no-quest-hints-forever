-- Regression: alpha=0 does not disable mouse input on tracker descendants.
local eventFrame, deferred, combat = nil, {}, false
local values = { UnitNameFriendlySpecialNPCName="1" }
C_CVar={GetCVar=function(name) return values[name] end, SetCVar=function(name,v) values[name]=v end}
C_Timer={After=function(_,fn) deferred[#deferred+1]=fn end}
InCombatLockdown=function() return combat end
SlashCmdList={}; print=function() end
local function frame(parent, click, motion, wheel)
    local f={parent=parent,children={},click=click,motion=motion,wheel=wheel,alpha=0.75,events={},writes=0}
    if parent then parent.children[#parent.children+1]=f end
    function f:GetChildren() return unpack(self.children) end
    function f:GetParent() return self.parent end
    function f:IsMouseClickEnabled() return self.click end
    function f:IsMouseMotionEnabled() return self.motion end
    function f:IsMouseWheelEnabled() return self.wheel end
    function f:SetMouseClickEnabled(v) assert(not combat); if self.fail then error("denied") end; self.click=v; self.writes=self.writes+1 end
    function f:SetMouseMotionEnabled(v) assert(not combat); self.motion=v; self.writes=self.writes+1 end
    function f:EnableMouseWheel(v) assert(not combat); self.wheel=v; self.writes=self.writes+1 end
    function f:SetAlpha(v) self.alpha=v end
    function f:GetAlpha() return self.alpha end
    function f:Show() end
    function f:Update() if self.addChild then self.addChild();self.addChild=nil end end
    function f:RegisterEvent(e) self.events[e]=true end
    function f:SetScript(_,fn) self.callback=fn end
    return f
end
CreateFrame=function() eventFrame=frame(nil,false,false,false);return eventFrame end
hooksecurefunc=function(owner,name,fn)
    local original=owner[name]
    owner[name]=function(self,...) local result=original(self,...);fn(self,...);return result end
end
ObjectiveTrackerFrame=frame(nil,false,false,false)
local root=ObjectiveTrackerFrame
local block=frame(root,false,false,false)
local header=frame(block,true,true,false)
local passive=frame(block,false,true,true) -- mixed flags must restore exactly
local outside=frame(nil,true,true,true)
GameTooltip={owner=header,shown=true,GetOwner=function(self) return self.owner end,Hide=function(self) self.shown=false end}
assert(loadfile("NoQuestHintsForever/NoQuestHintsForever.lua"))()
NoQuestHintsForeverChar={};NoQuestHintsForeverAccount={}
eventFrame.callback(eventFrame,"ADDON_LOADED","NoQuestHintsForever")
eventFrame.callback(eventFrame,"PLAYER_LOGIN")
local api=NoQuestHintsForeverAPI
local function flush()
    local count=0
    while #deferred>0 do count=count+1;assert(count<20);table.remove(deferred,1)() end
end
api.SetTrackerHidden(true)
assert(root.alpha==0 and not header.click and not header.motion and not passive.motion and not passive.wheel)
assert(not GameTooltip.shown, "existing tooltip owned by a hidden descendant must close")
assert(outside.click and outside.motion and outside.wheel, "unrelated UI input changed")
local added
root.addChild=function() added=frame(block,true,true,false) end
root:Update()
assert(added.motion, "post-hook must defer input mutation")
flush()
assert(not added.motion and not added.click, "new pooled quest headers remained interactive")
-- A detached child must not be left inert outside the tracker.
for i,node in ipairs(block.children) do if node==added then table.remove(block.children,i);break end end
added.parent=outside
root:Update();flush()
assert(added.click and added.motion, "detached/reparented pooled child input not restored")
GameTooltip.owner=outside;GameTooltip.shown=true
root:Update();flush()
assert(GameTooltip.shown, "unrelated tooltip was hidden")
api.SetTrackerHidden(false)
assert(root.alpha==0.75 and not root.click and not root.motion)
assert(header.click and header.motion and not header.wheel)
assert(not passive.click and passive.motion and passive.wheel, "mixed original flags were flattened")
-- No protected input writes during combat, and queued restoration survives it.
combat=true
local before=header.writes
api.SetTrackerHidden(true)
assert(header.writes==before and header.motion)
combat=false;eventFrame.callback(eventFrame,"PLAYER_REGEN_ENABLED")
assert(not header.motion)
combat=true
assert(not api.RestoreGameSettings())
assert(not header.motion)
combat=false;eventFrame.callback(eventFrame,"PLAYER_REGEN_ENABLED")
assert(header.motion and api.RestoreGameSettings())
-- Failed writes keep recovery state instead of reporting a false success.
api.SetTrackerHidden(true);header.fail=true
assert(not api.RestoreGameSettings())
header.fail=false
assert(api.RestoreGameSettings() and header.click and header.motion)
io.write("PASS: tracker descendant hover/click/wheel suppression, new/detached blocks, exact restoration and combat retry\n")
