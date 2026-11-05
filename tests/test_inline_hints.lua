-- Native POI icons beside quest names, selective hide/reveal, Lua 5.1.
local path="NoQuestHintsForever/QuestInlineHints.lua"
local visible = { [101]=false,[102]=false }
local hidden=true
local journalIcons={}
local updateCount,trackerRebuilds=0,0
local rows={{questID=101},{questID=102}}
local owner={}
function owner:FindButtonByQuestID(id) return journalIcons[id] end
function owner:GetButtonForQuestInternal(id,style)
    local icon={id=id,style=style}
    function icon:ClearAllPoints() end
    function icon:SetPoint(point,frame,x,y)
        self.point={point,frame,x,y}
    end
    journalIcons[id]=icon
    return icon
end
function owner:PostInitButtonInternal(icon) icon.shown=true end
QuestScrollFrame={
    titleFramePool={
        EnumerateActive=function()
            local i=0
            return function() i=i+1;return rows[i] end
        end,
    },
    Contents=owner,
}
QuestMapFrame={}
POIButtonUtil={GetStyle=function(id) return id==101 and "Complete" or "InProgress" end}
local trackerBlocks={}
for _,id in ipairs({101,102}) do
    local block={id=id,poiQuestID=id,poiIsComplete=id==101}
    function block:AddPOIButton()
        local style=self.poiIsComplete and "Complete" or "InProgress"
        self.poiButton={id=self.poiQuestID,style=style}
    end
    function block:CheckAndReleasePOIButton()
        self.poiButton=nil
        self.poiQuestID=nil
    end
    trackerBlocks[id]=block
end
QuestObjectiveTracker={usedBlocks={quest=trackerBlocks}}
function QuestObjectiveTracker:MarkDirty()
    trackerRebuilds=trackerRebuilds+1
    for _,block in pairs(self.usedBlocks.quest) do
        block.poiQuestID=block.id
    end
end
local hookFunctions={}
hooksecurefunc=function(target, method, handler)
    local isGlobal=type(target)=="string"
    local orig = isGlobal and _G[target] or target[method]
    local callback = isGlobal and method or handler
    assert(type(orig)=="function" and type(callback)=="function")
    local hooked=function(...)
        local rv=orig(...)
        callback(...)
        return rv
    end
    if type(target)=="string" then _G[target]=hooked else target[method]=hooked end
    hookFunctions[type(target)=="string" and target or method]=true
end
QuestLogQuests_Update=function()
    updateCount=updateCount+1
    journalIcons={}
end
ObjectiveTrackerQuestPOIBlockMixin={
    OnLayout=function(block)
        -- Blizzard hides all POI buttons under questPOI=0.
        block.poiButton=nil
        block.poiQuestID=block.id
    end,
}
local eventFrame,registered
CreateFrame=function()
    local frame={}
    registered={}
    function frame:RegisterEvent(e) registered[e]=true end
    function frame:SetScript(_,fn) self.onEvent=fn end
    eventFrame=frame
    return frame
end
local callbacks={}
C_Timer={After=function(t,fn) callbacks[#callbacks+1]=fn end}
local function flush()
    while #callbacks>0 do
        local fn=table.remove(callbacks,1)
        fn()
    end
end
InCombatLockdown=function() return false end
NoQuestHintsForeverAPI={
    IsMapHidden=function() return hidden end,
    IsQuestRevealed=function(id) return visible[id] == true end,
}
assert(loadfile(path))()
eventFrame.onEvent(nil,"ADDON_LOADED")
assert(hookFunctions.QuestLogQuests_Update,"journal update must be hooked")
assert(hookFunctions.OnLayout,"native tracker layout must be hooked")
local api=NoQuestHintsForeverAPI
api.RefreshQuestInlineHints()
assert(not journalIcons[101] and not journalIcons[102])
assert(not trackerBlocks[101].poiButton and not trackerBlocks[102].poiButton)
visible[101]=true
api.RefreshQuestInlineHints()
assert(journalIcons[101] and not journalIcons[102],"only allowed journal icon should show")
assert(journalIcons[101].style=="Complete","journal icon style must be Blizzard's")
assert(journalIcons[101].point[1]=="TOPLEFT" and journalIcons[101].point[2]==rows[1])
assert(trackerBlocks[101].poiButton and not trackerBlocks[102].poiButton,
    "only allowed tracker icon should show")
assert(trackerBlocks[101].poiButton.style=="Complete")
visible[101]=false
api.RefreshQuestInlineHints()
assert(not journalIcons[101] and not trackerBlocks[101].poiButton,
    "un-revealing must remove both native icons")
visible[102]=true
api.RefreshQuestInlineHints()
assert(journalIcons[102] and not journalIcons[101])
assert(trackerBlocks[102].poiButton and trackerBlocks[102].poiButton.style=="InProgress")
-- Blizzard's next layout removes the marker; deferred posthook must restore it.
ObjectiveTrackerQuestPOIBlockMixin.OnLayout(trackerBlocks[102])
assert(not trackerBlocks[102].poiButton,"layout hook should not mutate secure frame")
flush()
assert(trackerBlocks[102].poiButton,"deferred update should restore allowed marker")
hidden=false
api.RefreshQuestInlineHints()
assert(not journalIcons[101] and not journalIcons[102],
    "global hints visible: must not duplicate journal POIs")
hidden=true
api.RefreshQuestInlineHints()
assert(journalIcons[102] and not journalIcons[101],"revealed journal POI not restored")
assert(trackerRebuilds>0 and updateCount>0)
io.write("PASS: native journal/tracker markers, completion style, no duplicates and deferred layout\n")
