-- Preserve Blizzard's actual QuestTimerFrame, including its native callbacks.
-- Never run its update/layout, tooltip or quest-selection code from addon code.
local api=NoQuestHintsForeverAPI
if not api then return end
local L=NoQuestHintsForeverLocale
local record, anchor, dragging
local offerLabel, offerOwner, offeredQuestID
local timers={}
local ready, stopped, queued, applying=false,false,false,false
local hooked=setmetatable({}, {__mode="k"})
local refresh

local function combat()
    return type(InCombatLockdown)=="function" and InCombatLockdown()
end
local function read(fn,...)
    if type(fn)~="function" then return end
    local ok,value=pcall(fn,...)
    if ok then return value end
end
local function finite(value)
    return type(value)=="number" and value==value and value>=0 and value<math.huge
end
local function nativeFrame()
    return QuestTimerFrame or (ObjectiveTrackerFrame and ObjectiveTrackerFrame.QuestTimerFrame)
end
local function snapshot()
    local list=read(C_QuestLog and C_QuestLog.GetQuestTimers)
    local result={}
    if type(list)=="table" then
        for _,info in pairs(list) do
            if type(info)=="table" and type(info.questID)=="number" and info.questID>0
                and info.questID%1==0 and finite(info.questTimer) and info.questTimer>0 then
                result[info.questID]=info.questTimer
            end
        end
    end
    return result
end
local function queue()
    if queued or stopped or not ready or applying then return end
    if C_Timer and type(C_Timer.After)=="function" then
        queued=true
        C_Timer.After(0,function() queued=false;if ready and not stopped then refresh() end end)
    end
end
api.RefreshQuestTimers=queue

local function timed(id)
    if type(id)~="number" or id<=0 then return false end
    if timers[id] then return true end
    -- This identifies a timed quest without exposing its numerical deadline.
    local total=read(C_QuestLog and C_QuestLog.GetTimeAllowed,id)
    return finite(total) and total>0 or false
end

-- Offer metadata is separate from the selected journal quest. Never use a
-- different active quest's timer to label a not-yet-accepted NPC offer.
local function npcOffer()
    local owner=QuestFrameDetailPanel
    if owner~=offerOwner then
        if offerLabel then offerLabel:Hide() end
        offerLabel=nil;offerOwner=owner
    end
    if not owner or type(owner.CreateFontString)~="function" or combat() then return end
    if not offerLabel then
        offerLabel=owner:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        -- Fit the duration-free note between the native accept/decline buttons.
        if QuestFrameAcceptButton then
            offerLabel:SetPoint("LEFT",QuestFrameAcceptButton,"RIGHT",8,0)
            if QuestFrameDeclineButton then
                offerLabel:SetPoint("RIGHT",QuestFrameDeclineButton,"LEFT",-8,0)
            else offerLabel:SetWidth(150) end
        else
            offerLabel:SetPoint("BOTTOM",owner,"BOTTOM",0,5)
            offerLabel:SetWidth(150)
        end
        offerLabel:SetHeight(22);offerLabel:SetJustifyH("CENTER")
        offerLabel:SetText(L.TIMED_QUEST)
        if type(owner.HookScript)=="function" then
            owner:HookScript("OnShow",queue)
            owner:HookScript("OnHide",function()
                if offerOwner==owner then
                    offeredQuestID=nil
                    if offerLabel then offerLabel:Hide() end
                end
            end)
        end
    end
    local current=read(GetQuestID)
    if ready and offeredQuestID and current==offeredQuestID and timed(current)
        and read(owner.IsShown,owner) then offerLabel:Show() else offerLabel:Hide() end
end

local function placeAnchor()
    if not anchor or dragging then return end
    anchor:ClearAllPoints()
    local position=api.GetQuestTimerPosition()
    if position then
        anchor:SetPoint("CENTER",UIParent,"BOTTOMLEFT",
            position.x*UIParent:GetWidth(),position.y*UIParent:GetHeight())
    elseif Minimap then anchor:SetPoint("TOP",Minimap,"BOTTOM",0,-24)
    else anchor:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-32,-220) end
end
local function endDrag()
    if not dragging or not anchor then return end
    local ok=pcall(anchor.StopMovingOrSizing,anchor)
    if not ok then return end
    dragging=false
    local x,y=anchor:GetCenter()
    local width,height=UIParent:GetWidth(),UIParent:GetHeight()
    local scale=read(anchor.GetEffectiveScale,anchor) or 1
    local rootScale=read(UIParent.GetEffectiveScale,UIParent) or 1
    if finite(x) and finite(y) and width>0 and height>0 and rootScale>0 then
        api.SetQuestTimerPosition(math.max(0,math.min(1,x*scale/rootScale/width)),
            math.max(0,math.min(1,y*scale/rootScale/height)))
    end
    if not combat() then placeAnchor() end
end
local function underTracker(frame)
    local seen={}
    while frame and not seen[frame] do
        if frame==ObjectiveTrackerFrame then return true end
        seen[frame]=true;frame=read(frame.GetParent,frame)
    end
    return false
end
local function restoreNative()
    if not record or combat() then return end
    local f=record.frame
    if record.ignore~=nil and type(f.SetIgnoreParentAlpha)=="function" then
        pcall(f.SetIgnoreParentAlpha,f,record.ignore)
    end
    if record.anchored then
        pcall(f.ClearAllPoints,f)
        for _,point in ipairs(record.points) do pcall(f.SetPoint,f,unpack(point,1,5)) end
    end
    if record.hiddenByUs and next(timers) then pcall(f.Show,f) end
    record.keepInput=false
    if record.handle then record.handle:Hide() end
end

-- The core restores any previously captured mouse flags for this subtree.
api.IsQuestTimerInputExempt=function(node)
    return record and record.frame==node and record.keepInput==true or false
end

local function attach(f)
    if record and record.frame==f then return end
    restoreNative()
    if anchor then endDrag();anchor:Hide() end
    local points={}
    if type(f.GetNumPoints)=="function" and type(f.GetPoint)=="function" then
        for i=1,f:GetNumPoints() do points[i]={f:GetPoint(i)} end
    end
    record={frame=f,points=points,ignore=read(f.IsIgnoringParentAlpha,f)}
    if not anchor then
        -- An invisible addon-owned movement anchor; all visible art stays native.
        anchor=CreateFrame("Frame","NoQuestHintsForeverQuestTimerAnchor",UIParent)
        anchor:SetMovable(true);anchor:SetClampedToScreen(true)
        anchor:SetScript("OnHide",endDrag)
    end
    placeAnchor()
    local handle=CreateFrame("Frame",nil,f)
    record.handle=handle
    handle:SetPoint("TOPLEFT",f,"TOPLEFT",0,11)
    handle:SetPoint("TOPRIGHT",f,"TOPRIGHT",0,11)
    handle:SetHeight(30);handle:SetFrameLevel(f:GetFrameLevel()+3)
    handle:EnableMouse(true);handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart",function()
        if combat() or stopped then return end
        dragging=pcall(anchor.StartMoving,anchor)
    end)
    handle:SetScript("OnDragStop",endDrag)
    local function hideHint()
        if GameTooltip and read(GameTooltip.GetOwner,GameTooltip)==handle then GameTooltip:Hide() end
    end
    handle:SetScript("OnEnter",function()
        if GameTooltip then
            GameTooltip:SetOwner(handle,"ANCHOR_LEFT");GameTooltip:SetText(L.TIMERS_MOVE_HINT);GameTooltip:Show()
        end
    end)
    handle:SetScript("OnLeave",hideHint)
    handle:SetScript("OnHide",function() endDrag();hideHint() end)
    if not hooked[f] and type(f.HookScript)=="function" then
        f:HookScript("OnShow",queue)
        f:HookScript("OnHide",queue)
        f:HookScript("OnSizeChanged",queue)
        hooked[f]=true
    end
end

refresh=function()
    if not ready or stopped or applying then return end
    timers=snapshot()
    if combat() then return end
    applying=true
    local f=nativeFrame()
    if f and not read(f.IsForbidden,f) then
        attach(f)
        local hidden=api.IsQuestTimersHidden()==true
        local needsIgnore=api.IsTrackerHidden() and underTracker(f) and not hidden
        local ignore=needsIgnore or record.ignore
        if ignore~=nil and type(f.SetIgnoreParentAlpha)=="function"
            and read(f.IsIgnoringParentAlpha,f)~=ignore then
            pcall(f.SetIgnoreParentAlpha,f,ignore)
        end
        record.keepInput=not hidden and (not needsIgnore or read(f.IsIgnoringParentAlpha,f)==true)
        local width,height=read(f.GetWidth,f),read(f.GetHeight,f)
        if finite(width) and width>0 and finite(height) and height>0 then
            local scale=read(f.GetEffectiveScale,f) or 1
            local rootScale=read(UIParent.GetEffectiveScale,UIParent) or 1
            anchor:SetSize(width*scale/rootScale,(height+11)*scale/rootScale)
            if not record.anchored then
                f:ClearAllPoints();f:SetPoint("TOP",anchor,"TOP",0,-11)
                record.anchored=true
            end
        end
        if hidden then
            if read(f.IsShown,f) then record.hiddenByUs=pcall(f.Hide,f) or record.hiddenByUs end
        elseif record.hiddenByUs and next(timers) then
            if pcall(f.Show,f) then record.hiddenByUs=false end
        end
        if read(f.IsShown,f) then anchor:Show() else anchor:Hide() end
        -- Restore native timer-button input captured by an earlier tracker pass.
        if type(api.UpdateTracker)=="function" then api.UpdateTracker() end
    end
    npcOffer()
    applying=false
end

local events=CreateFrame("Frame")
for _,event in ipairs({"ADDON_LOADED","PLAYER_ENTERING_WORLD","LOADING_SCREEN_ENABLED",
    "LOADING_SCREEN_DISABLED","QUEST_LOG_UPDATE","PLAYER_REGEN_ENABLED","PLAYER_LOGOUT",
    "UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED","QUEST_DETAIL","QUEST_FINISHED","QUEST_GREETING",
    "QUEST_PROGRESS","QUEST_COMPLETE","QUEST_DATA_LOAD_RESULT"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event)
    if event=="QUEST_DETAIL" then
        offeredQuestID=read(GetQuestID)
        if offerLabel then offerLabel:Hide() end
    elseif event=="QUEST_FINISHED" or event=="QUEST_GREETING" or event=="QUEST_PROGRESS"
        or event=="QUEST_COMPLETE" or event=="LOADING_SCREEN_ENABLED" or event=="PLAYER_LOGOUT" then
        offeredQuestID=nil;if offerLabel then offerLabel:Hide() end
    end
    if event=="PLAYER_LOGOUT" then
        stopped=true;ready=false;endDrag();restoreNative()
        if anchor then anchor:Hide() end
    elseif event=="LOADING_SCREEN_ENABLED" then
        ready=false;endDrag()
    else
        if event=="LOADING_SCREEN_DISABLED" or event=="PLAYER_ENTERING_WORLD" then ready=true end
        if event=="UI_SCALE_CHANGED" or event=="DISPLAY_SIZE_CHANGED"
            or event=="PLAYER_ENTERING_WORLD" then if not combat() then placeAnchor() end end
        queue()
    end
end)
