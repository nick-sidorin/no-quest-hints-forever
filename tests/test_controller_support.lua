-- The native gamepad pin scanner must never receive NQH pins. Its substitute
-- tooltip must not call shared GameTooltip/native pin hover or run off-map.
local pad, combat, hidden = true, false, true
local disabledTooltips = false
GetCVarBool=function(name) assert(name=="GamepadDisableTooltips"); return disabledTooltips end
local permissions={[11]=true,[22]=true}
local frames, tooltips = {}, {}
UIParent={}
InputUtil={IsGamepadUIEnabled=function() return pad end}
InCombatLockdown=function() return combat end
GameTooltip={SetOwner=function() error("shared GameTooltip touched") end,Hide=function() error("shared GameTooltip touched") end}
local function frame(kind,name,parent,template)
    local f={shown=true,scripts={},events={},lines={}}
    function f:RegisterEvent(e) self.events[e]=true end
    function f:SetScript(e,fn) self.scripts[e]=fn end
    function f:IsShown() return self.shown end
    function f:Show() self.shown=true end
    function f:Hide() self.shown=false end
    function f:SetOwner(owner,anchor) self.owner,self.anchor=owner,anchor end
    function f:SetText(text) self.text=text;self.lines={} end
    function f:AddLine(text) self.lines[#self.lines+1]=text end
    frames[#frames+1]=f
    if kind=="GameTooltip" then
        assert(parent==UIParent and template=="GameTooltipTemplate")
        tooltips[#tooltips+1]=f
    end
    return f
end
CreateFrame=frame
WorldMapFrame=frame()
WorldMapFrame.hooks={}
function WorldMapFrame:HookScript(e,fn) self.hooks[e]=fn end
local x,y=100,100
WorldMapFrame.ScrollContainer={GetGamepadCursorPosition=function() return x,y end}
SoftCursor=frame()
NoQuestHintsForeverAPI={
    IsMapHidden=function() return hidden end,
    IsQuestRevealed=function(id) return permissions[id]==true end,
}
C_QuestLog={
    GetTitleForQuestID=function(id) return "Quest "..id end,
    GetQuestObjectives=function() return {{text="Objective 0/1",finished=false},{text="Done",finished=true}} end,
}
assert(loadfile("NoQuestHintsForever/ControllerSupport.lua"))()
local api=NoQuestHintsForeverAPI
assert(api.IsNativeGamepadUI(),"native gamepad mode must be independent of the last input device")
local function pin(id,px,py)
    local p={id=id,x=px,y=py,shown=true}
    function p:GetCenter() return self.x,self.y end
    function p:GetQuestID() return self.id end
    function p:IsVisible() return self.shown and WorldMapFrame.shown end
    function p:OnMouseEnter() error("native pin hover called") end
    return p
end
local a,b,blob,native=pin(11,100,100),pin(22,106,100),pin(11,100,100),pin(33,100,100)
local nativeCenter=native.GetCenter
api.GuardQuestMapPin(a,true); api.GuardQuestMapPin(b,true); api.GuardQuestMapPin(blob,false)
local aCenter=a.GetCenter
api.GuardQuestMapPin(a,true)
assert(a.GetCenter==aCenter,"pooled pin was wrapped twice")
assert(a:GetCenter()==nil and b:GetCenter()==nil and blob:GetCenter()==nil)
assert(native.GetCenter==nativeCenter and native:GetCenter()==100,"native pin was changed")
local function tick()
    local snapshot={};for i,f in ipairs(frames) do snapshot[i]=f end
    for _,f in ipairs(snapshot) do if f.scripts.OnUpdate then f.scripts.OnUpdate(f,0.05) end end
end
local function polling()
    for _,f in ipairs(frames) do if f.scripts.OnUpdate then return true end end
    return false
end
local function event(e)
    for _,f in ipairs(frames) do if f.events[e] then f.scripts.OnEvent(f,e) end end
end
tick()
assert(#tooltips==1 and tooltips[1].owner==a and tooltips[1].text=="Quest 11")
assert(tooltips[1].lines[1]=="Objective 0/1" and #tooltips[1].lines==1)
x=106; tick();assert(tooltips[1].owner==b,"nearest private pin was not selected")
b.id=11;tick();assert(tooltips[1].text=="Quest 11","pooled quest reuse retained stale tooltip")
x=500;tick();assert(not tooltips[1].shown)
x=100;SoftCursor.shown=false;tick();assert(not tooltips[1].shown)
SoftCursor.shown=true;tick();assert(tooltips[1].shown)
WorldMapFrame.shown=false;WorldMapFrame.hooks.OnHide()
assert(not polling() and not tooltips[1].shown,"map close leaked tooltip/tick")
WorldMapFrame.shown=true;WorldMapFrame.hooks.OnShow();tick()
assert(polling() and tooltips[1].shown)
pad=false;event("GAME_PAD_ACTIVE_CHANGED")
assert(not api.IsNativeGamepadUI())
assert(not polling() and a:GetCenter()==100 and b:GetCenter()==106,"mouse center/idle behavior changed")
pad=true;event("GAME_PAD_ACTIVE_CHANGED");tick()
combat=true;event("PLAYER_REGEN_DISABLED")
assert(not polling() and not tooltips[1].shown)
combat=false;event("PLAYER_REGEN_ENABLED");tick();assert(tooltips[1].shown)
disabledTooltips=true;event("CVAR_UPDATE")
assert(not polling() and not tooltips[1].shown,"native tooltip-disable preference was ignored")
disabledTooltips=false;event("CVAR_UPDATE");tick();assert(tooltips[1].shown)
hidden=false;api.RefreshControllerQuestPins()
assert(not polling() and not tooltips[1].shown,"global OFF leaked private hints")
hidden=true;permissions[11]=nil;permissions[22]=nil;api.RefreshControllerQuestPins()
assert(not polling(),"empty allowlist kept polling")
permissions[11]=true;a.shown=false;b.shown=false;api.RefreshControllerQuestPins()
assert(not polling(),"noninteractive blob started tooltip polling")
a.shown=true;api.RefreshControllerQuestPins();tick()
assert(tooltips[1].shown)
event("PLAYER_LOGOUT");event("CVAR_UPDATE")
assert(not polling() and not tooltips[1].shown,"logout restarted native-map work")
InputUtil=nil
assert(a:GetCenter()==100,"missing native input API broke mouse geometry")
a.GetCenter=function() return 300,400 end
InputUtil={IsGamepadUIEnabled=function() return pad end}
api.GuardQuestMapPin(a,true)
assert(a:GetCenter()==nil,"pooled native reset bypassed the guard")
pad=false
local px,py=a:GetCenter()
assert(px==300 and py==400,"guard lost the refreshed native geometry")
io.write("PASS: scoped native cursor guard, private hover, pooled pins and no off-map/combat polling\n")
