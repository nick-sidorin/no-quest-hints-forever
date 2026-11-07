-- Native-title-only filtering: preserve real names, group counts and game data.
local levels,difficulty,combat=false,false,false
local deferred,events,hookCount={},nil,0
local info={
 [1]={questID=1,title="Example [14] title",difficultyLevel=14},
 [2]={questID=2,title="Red quest",difficultyLevel=16},
 [3]={questID=3,title="Reused title",difficultyLevel=2},
}
local function font(text,r,g,b)
 local f={text=text,rgba={r,g,b,1}}
 function f:GetText() return self.text end
 function f:SetText(v) assert(not combat,"presentation write in combat");self.text=v end
 function f:GetTextColor() return unpack(self.rgba) end
 function f:SetTextColor(...) assert(not combat,"color write in combat");self.rgba={...} end
 return f
end
local journal={questID=1,info=info[1],Text=font("[2] [14+] Example [14] title",0,1,0),TagText=font("Elite",0,1,0)}
local header={questID=0,info={isHeader=true},Text=font("[14] Zone",0,1,0)}
local buttons={journal,header}
QuestScrollFrame={titleFramePool={EnumerateActive=function()
 local i=0;return function() i=i+1;return buttons[i] end
end}}
QuestObjectiveTracker={usedBlocks={quest={}}}
local tracked={id=2,parentModule=QuestObjectiveTracker,HeaderText=font("|cffff0000[16] Red quest|r",1,0.82,0)}
QuestObjectiveTracker.usedBlocks.quest[2]=tracked
C_QuestLog={GetTitleForQuestID=function(id) return info[id].title end,GetQuestDifficultyLevel=function(id) return info[id].difficultyLevel end}
NORMAL_FONT_COLOR={r=1,g=0.82,b=0}
NoQuestHintsForeverAPI={IsQuestLevelsHidden=function() return levels end,IsQuestDifficultyHidden=function() return difficulty end}
C_Timer={After=function(_,fn) deferred[#deferred+1]=fn end}
InCombatLockdown=function() return combat end
CreateFrame=function()
 events={registered={}}
 function events:RegisterEvent(e) self.registered[e]=true end
 function events:SetScript(_,fn) self.callback=fn end
 return events
end
QuestLogQuests_Update=function()
 journal.Text.text="[2] [14+] Example [14] title";journal.Text.rgba={0,1,0,1}
end
QuestMapLogTitleButton_OnEnter=function(button) button.Text.rgba={1,0.4,0,1} end
QuestMapLogTitleButton_OnLeave=function(button) button.Text.rgba={0,1,0,1} end
-- XML binds these function references when the row is created, BEFORE our
-- global-name hooks are installed. Calling the global directly is insufficient.
local xmlEnter,xmlLeave=QuestMapLogTitleButton_OnEnter,QuestMapLogTitleButton_OnLeave
journal.scripts={OnEnter=xmlEnter,OnLeave=xmlLeave}
journal.scriptHooks={}
function journal:HookScript(event, fn)
 self.scriptHooks[event]=(self.scriptHooks[event] or 0)+1
 local original=self.scripts[event]
 self.scripts[event]=function(...) if original then original(...) end;fn(...) end
end
ObjectiveTrackerBlockMixin={SetHeader=function() end,UpdateHighlight=function() end}
hooksecurefunc=function(owner,name,fn)
 hookCount=hookCount+1
 if type(owner)=="string" then
  local original=_G[owner];local after=name
  _G[owner]=function(...) local result=original(...);after(...);return result end
 else
  local original=owner[name]
  owner[name]=function(...) local result=original(...);fn(...);return result end
 end
end
local function flush()
 local count=0
 while #deferred>0 do count=count+1;assert(count<20);table.remove(deferred,1)() end
end
assert(loadfile("NoQuestHintsForever/QuestPresentation.lua"))()
local api=NoQuestHintsForeverAPI
api.RefreshQuestPresentation();flush()
assert(hookCount==0 and journal.Text.text:find("[14+]",1,true),"default OFF must be passive")
levels=true;api.RefreshQuestPresentation();flush()
assert(journal.Text.text=="[2] Example [14] title", "removed party count or real title content")
assert(tracked.HeaderText.text=="|cffff0000Red quest|r", "level-only option must preserve difficulty markup")
assert(journal.Text.rgba[2]==1 and header.Text.text=="[14] Zone")
QuestLogQuests_Update()
assert(journal.Text.text:find("[14+]",1,true),"native post-hook changed UI synchronously")
flush();assert(journal.Text.text=="[2] Example [14] title")
levels=false;difficulty=true;api.RefreshQuestPresentation();flush()
assert(journal.Text.text=="[2] [14+] Example [14] title", "color-only setting removed numeric level")
assert(tracked.HeaderText.text=="[16] Red quest" and journal.Text.rgba[1]==1 and journal.Text.rgba[2]==0.82)
assert(journal.TagText.rgba[2]==0.82 and header.Text.rgba[2]==1)
journal.scripts.OnEnter(journal);flush()
assert(journal.Text.rgba[2]==0.82,"XML-bound journal hover bypassed difficulty concealment")
journal.scripts.OnLeave(journal);flush()
assert(journal.Text.rgba[2]==0.82,"XML-bound journal leave bypassed difficulty concealment")
assert(journal.scriptHooks.OnEnter==1 and journal.scriptHooks.OnLeave==1,
 "pooled journal row scripts must be hooked once")
-- Rows acquired after the first pass use the same XML-bound references.
local added={questID=3,info=info[3],Text=font("[2] Reused title",0,1,0),TagText=font("",0,1,0),
 scripts={OnEnter=xmlEnter,OnLeave=xmlLeave},scriptHooks={},HookScript=journal.HookScript}
buttons[#buttons+1]=added
QuestLogQuests_Update();flush()
added.scripts.OnEnter(added);flush()
assert(added.Text.rgba[2]==0.82,"newly acquired journal row leaked hover difficulty")
added.scripts.OnLeave(added);flush()
assert(added.Text.rgba[2]==0.82 and added.scriptHooks.OnEnter==1 and added.scriptHooks.OnLeave==1)
QuestMapLogTitleButton_OnEnter(journal);flush()
assert(journal.Text.rgba[2]==0.82,"hover leaked difficulty color")
levels=true;api.RefreshQuestPresentation();flush()
assert(journal.Text.text=="[2] Example [14] title")
levels=false;difficulty=false;api.RefreshQuestPresentation();flush()
assert(journal.Text.text=="[2] [14+] Example [14] title")
assert(journal.Text.rgba[2]==0.4,"original native hover color not restored")
assert(tracked.HeaderText.text=="|cffff0000[16] Red quest|r")
QuestMapLogTitleButton_OnLeave(journal)
assert(journal.Text.rgba[2]==1)
journal.scripts.OnEnter(journal);flush()
assert(journal.Text.rgba[2]==0.4,"disabled concealment suppressed native row hover")
journal.scripts.OnLeave(journal);flush()
assert(journal.Text.rgba[2]==1 and added.Text.rgba[2]==1)
assert(journal.scriptHooks.OnEnter==1 and journal.scriptHooks.OnLeave==1)
-- A party count equal to the level must remain; remove the rightmost level
-- decoration before the real title, never every bracketed number.
journal.questID=3;journal.info=info[3];journal.Text.text="[2] [2] Reused title"
levels=true;api.RefreshQuestPresentation();flush()
assert(journal.Text.text=="[2] Reused title")
-- Reused pooled buttons must not receive the old quest's text on restore.
journal.questID=1;journal.info=info[1];journal.Text.text="Fresh native title"
levels=false;api.RefreshQuestPresentation();flush()
assert(journal.Text.text=="Fresh native title")
QuestLogQuests_Update()
combat=true;levels=true;api.RefreshQuestPresentation();flush()
assert(journal.Text.text:find("[14+]",1,true))
combat=false;events.callback(events,"PLAYER_REGEN_ENABLED");flush()
assert(journal.Text.text=="[2] Example [14] title")
combat=true;levels=false;api.RefreshQuestPresentation();flush()
assert(not api.RestoreQuestPresentation(), "combat restoration must retain pending originals")
combat=false;events.callback(events,"PLAYER_REGEN_ENABLED");flush()
assert(journal.Text.text=="[2] [14+] Example [14] title")
assert(api.RestoreQuestPresentation())
assert(info[1].title=="Example [14] title" and info[1].difficultyLevel==14,"quest data mutated")
io.write("PASS: quest numeric prefixes and difficulty colors independent, native hover, group counts, pooled reuse and combat deferral\n")
