-- Selective native-template badges must never seed Blizzard's shared caches.
local allowed, hidden, combat = {}, true, false
local frames, icons, callbacks = {}, {}, {}
local nativeIcons, rebuilds = {}, 0
local rows = {{questID=101}, {questID=102}}
local blocks = {[101]={id=101, HeaderText={}}, [102]={id=102, HeaderText={}}}
local function forbidden() error('shared native cache/pool/rebuild touched') end
QuestCache={Get=forbidden}
GetQuestsOnMapCached=forbidden
POIButtonUtil={GetStyle=forbidden,Style={QuestComplete='complete',QuestDisabled='disabled',QuestInProgress='progress',WorldQuest='world'}}
QuestDataProviderMixin=nil
WorldMapFrame=nil
C_QuestInfoSystem={GetQuestClassification=function() return 'normal' end}
C_QuestLog={IsComplete=function(id) return id==101 end, IsQuestDisabledForSession=function() return false end,
 IsWorldQuest=function() return false end}
C_SuperTrack={GetSuperTrackedQuestID=function() return 101 end}
InCombatLockdown=function() return combat end
C_Timer={After=function(_,fn) callbacks[#callbacks+1]=fn end}
local function flush() while #callbacks>0 do table.remove(callbacks,1)() end end
function CreateFrame(kind,name,parent,template)
 local f={events={},scripts={}}
 function f:RegisterEvent(e) self.events[e]=true end
 function f:SetScript(e,fn) self.scripts[e]=fn end
 if kind=='Button' then
  assert(template=='POIButtonTemplate' or template=='ObjectiveTrackerPOIButtonTemplate')
  f.parentFrame=parent
  function f:SetQuestID(id) self.id=id end
  function f:GetQuestID() return self.id end
  function f:SetStyle(style) self.style=style end
  function f:SetSelected(value) self.selected=value end
  function f:UpdateButtonStyle() assert(self:GetQuestClassification()=='normal') end
  function f:Show() self.shown=true end
  function f:Hide() self.shown=false end
  function f:ClearAllPoints() end
  function f:SetPoint(...) self.point={...} end
  icons[parent]=f
 end
 frames[#frames+1]=f
 return f
end
NoQuestHintsForeverAPI={IsMapHidden=function() return hidden end,IsQuestRevealed=function(id) return allowed[id]==true end}
assert(loadfile('NoQuestHintsForever/QuestMarkers.lua'))()
local api=NoQuestHintsForeverAPI
local owner={FindButtonByQuestID=function(_,id) return nativeIcons[id] end,
 GetButtonForQuestInternal=forbidden,PostInitButtonInternal=forbidden}
QuestScrollFrame={Contents=owner,titleFramePool={EnumerateActive=function()
 local i=0;return function() i=i+1;return rows[i] end
end}}
QuestMapFrame={}
QuestObjectiveTracker={usedBlocks={quest=blocks},MarkDirty=forbidden}
for _,b in pairs(blocks) do b.parentModule=QuestObjectiveTracker;b.AddPOIButton=forbidden;b.SetPOIInfo=forbidden end
local hooks={}
function hooksecurefunc(target,method,handler)
 local obj,key,fn
 if type(target)=='string' then obj,key,fn=_G,target,method else obj,key,fn=target,method,handler end
 local original=obj[key];assert(type(original)=='function')
 obj[key]=function(...) original(...);fn(...) end
 hooks[key]=true
end
QuestLogQuests_Update=function() rebuilds=rebuilds+1 end
ObjectiveTrackerQuestPOIBlockMixin={OnLayout=function() end,Free=function() end}
assert(loadfile('NoQuestHintsForever/QuestInlineHints.lua'))()
api.RefreshQuestInlineHints()
assert(rebuilds==0,'addon eagerly rebuilt the native journal')
assert(hooks.QuestLogQuests_Update and hooks.OnLayout and hooks.Free)
allowed[101]=true
api.RefreshQuestInlineHints()
local j,t=icons[rows[1]],icons[blocks[101]]
assert(j and t and j.shown and t.shown and j.style=='complete' and t.style=='complete')
assert(j.selected and t.selected and not icons[rows[2]])
assert(j.point[1]=='TOPLEFT' and t.point[1]=='TOPRIGHT')
assert(not blocks[101].poiButton and not blocks[101].poiQuestID,'native tracker ownership was changed')
for _=1,5 do api.RefreshQuestInlineHints() end
assert(icons[rows[1]]==j and icons[blocks[101]]==t,'unchanged badges were recreated')
assert(rebuilds==0)
allowed[101]=nil;allowed[102]=true;api.RefreshQuestInlineHints()
assert(not j.shown and not t.shown and icons[rows[2]].shown and icons[blocks[102]].shown)
assert(icons[rows[2]].style=='progress')
local second=icons[rows[2]]
nativeIcons[102]={};api.RefreshQuestInlineHints();assert(not second.shown,'duplicate native badge')
nativeIcons[102]=nil
QuestLogQuests_Update();assert(second.shown and rebuilds==1,'native update did not reconcile private badge')
rows[2].questID=103;api.RefreshQuestInlineHints();assert(not second.shown,'pooled row retained old permission')
rows[2].questID=102;api.RefreshQuestInlineHints();assert(second.shown)
local tracker=icons[blocks[102]]
ObjectiveTrackerQuestPOIBlockMixin.Free(blocks[102]);assert(not tracker.shown)
ObjectiveTrackerQuestPOIBlockMixin.OnLayout(blocks[102]);assert(not tracker.shown)
flush();assert(tracker.shown,'deferred layout failed')
blocks[102].poiButton={};api.RefreshQuestInlineHints();assert(not tracker.shown,'duplicate tracker badge')
blocks[102].poiButton=nil
api.RefreshQuestInlineHints();assert(tracker.shown)
hidden=false;api.RefreshQuestInlineHints();assert(not second.shown and not tracker.shown)
hidden=true;combat=true;api.RefreshQuestInlineHints();assert(not second.shown)
combat=false
for _,f in ipairs(frames) do if f.events.PLAYER_REGEN_ENABLED then f.scripts.OnEvent(f,'PLAYER_REGEN_ENABLED') end end
assert(second.shown and tracker.shown,'combat-end retry failed')
QuestObjectiveTracker.usedBlocks={};api.RefreshQuestInlineHints();assert(not tracker.shown,'detached tracker badge remained')
rows={};api.RefreshQuestInlineHints();assert(not second.shown,'released journal row remained')
assert(rebuilds==1,'addon invoked a full native rebuild')
io.write('PASS: cache-free private native badges, selection, pooling, removal, native priority and combat retry\n')
