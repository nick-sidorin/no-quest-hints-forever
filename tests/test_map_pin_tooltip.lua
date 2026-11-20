-- Owned map tooltip formats before display and never enters native journal hover.
local pad,combat,levels,difficulty=false,false,true,false
local frames,tooltips={},{}
UIParent={};InputUtil={IsGamepadUIEnabled=function()return pad end}
InCombatLockdown=function()return combat end
GameTooltip=setmetatable({}, {__index=function()error('shared tooltip touched')end})
EventRegistry={TriggerEvent=function()error('native journal event dispatched')end}
QuestCache=setmetatable({}, {__index=function()error('shared QuestCache touched')end})
local function frame(kind)
    local f={shown=true,scripts={},events={}}
    function f:RegisterEvent(e)self.events[e]=true end
    function f:SetScript(e,fn)self.scripts[e]=fn end
    function f:HookScript(e,fn)self.scripts[e]=fn end
    function f:Show()self.shown=true end
    function f:Hide()self.shown=false end
    function f:IsShown()return self.shown end
    function f:SetOwner(owner,anchor)self.owner,self.anchor=owner,anchor end
    function f:SetText(text,r,g,b)
        -- Catch even a transient forbidden prefix before any later Show/cleanup.
        if levels then assert(not text:find('[31]',1,true),'level reached SetText') end
        self.text=text;self.rgb={r,g,b};self.lines={}
    end
    function f:AddLine(text)self.lines[#self.lines+1]=text end
    frames[#frames+1]=f
    if kind=='GameTooltip'then tooltips[#tooltips+1]=f end
    return f
end
CreateFrame=frame
WorldMapFrame=frame()
local objectives={{text='0/1 objective',finished=false},{text='done',finished=true}}
C_QuestLog={GetTitleForQuestID=function(id)return id==1 and 'Quest [14] title' or 'Other quest'end,
    GetQuestDifficultyLevel=function()return 31 end,
    GetQuestObjectives=function()return objectives end}
GetQuestDifficultyColor=function()return {r=1,g=.1,b=0}end
NORMAL_FONT_COLOR={r=1,g=.82,b=0}
NoQuestHintsForeverAPI={IsQuestLevelsHidden=function()return levels end,
    IsQuestDifficultyHidden=function()return difficulty end,
    IsMapHidden=function()return true end,IsQuestMapHintAllowed=function()return true end}
assert(loadfile('NoQuestHintsForever/ControllerSupport.lua'))()
local api=NoQuestHintsForeverAPI
local a={GetQuestID=function()return 1 end,GetCenter=function()return 10,20 end}
local b={GetQuestID=function()return 2 end,GetCenter=function()return 20,20 end}
api.GuardQuestMapPin(a,true);api.GuardQuestMapPin(b,true)
api.ShowQuestMapTooltip(a)
assert(#tooltips==1 and tooltips[1].text=='Quest [14] title')
assert(tooltips[1].rgb[2]==.1 and #tooltips[1].lines==1)
api.HideQuestMapTooltip(b);assert(tooltips[1].shown,'another pin dismissed owned tooltip')
api.HideQuestMapTooltip(a);assert(not tooltips[1].shown)
for i=1,30 do
    api.ShowQuestMapTooltip(a);api.HideQuestMapTooltip(a)
    api.ShowQuestMapTooltip(b);api.HideQuestMapTooltip(b)
end
assert(#tooltips==1,'hover created unbounded tooltip widgets')
levels=false;api.ShowQuestMapTooltip(a);assert(tooltips[1].text=='[31] Quest [14] title')
difficulty=true;api.ShowQuestMapTooltip(a);assert(tooltips[1].rgb[2]==.82)
levels=true;api.ShowQuestMapTooltip(a);assert(tooltips[1].text=='Quest [14] title')
WorldMapFrame.scripts.OnHide();assert(not tooltips[1].shown,'map close leaked mouse tooltip')
combat=true;api.ShowQuestMapTooltip(a);assert(not tooltips[1].shown)
combat=false;pad=true;api.ShowQuestMapTooltip(a);assert(not tooltips[1].shown)
pad=false;api.ShowQuestMapTooltip(a)
for _,f in ipairs(frames)do
    if f.events.PLAYER_REGEN_DISABLED then f.scripts.OnEvent(f,'PLAYER_REGEN_DISABLED')end
end
assert(not tooltips[1].shown,'combat entry leaked mouse tooltip')
io.write('PASS: private mouse tooltip, pre-display title settings, internal numbers, owner-scoped cleanup and no native journal dispatch\n')
