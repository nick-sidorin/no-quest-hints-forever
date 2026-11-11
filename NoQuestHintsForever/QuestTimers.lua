-- Client-owned quest deadlines; never persist or restart an addon countdown.
-- Forever's C_QuestLog.GetQuestTimers returns {questID, questTimer} records.
local api = NoQuestHintsForeverAPI
if not api then return end
local L = NoQuestHintsForeverLocale
local panel, nativeHooked
local dragging=false
local offerLabel, offerOwner, offeredQuestID
local rows, timers = {}, {}
local states = setmetatable({}, {__mode="k"})
local ready, stopped, queued = false, false, false
local refresh

local function combat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function read(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, value = pcall(fn, ...)
    if ok then return value end
end

local function finite(value)
    return type(value)=="number" and value==value and value<math.huge and value>=0
end

local function snapshot()
    local list = read(C_QuestLog and C_QuestLog.GetQuestTimers)
    local result = {}
    if type(list)=="table" then
        for _, info in pairs(list) do
            if type(info)=="table" and type(info.questID)=="number" and info.questID>0
                and info.questID%1==0 and finite(info.questTimer) and info.questTimer>0 then
                result[info.questID]=info.questTimer
            end
        end
    end
    return result
end

local function queue()
    if type(api.RefreshQuestTimers)=="function" then api.RefreshQuestTimers() end
end

local function nativeFrame()
    return QuestTimerFrame or (ObjectiveTrackerFrame and ObjectiveTrackerFrame.QuestTimerFrame)
end

local function restoreNative()
    if combat() then return end
    for object, record in pairs(states) do
        local done=true
        if record.wasShown and next(timers) and type(object.Show)=="function" then
            done=pcall(object.Show,object)
        end
        if done then states[object]=nil end
    end
end

local function suppress(object)
    if not object or type(object.Hide)~="function" then return end
    local record=states[object] or {wasShown=false};states[object]=record
    if read(object.IsShown,object) then
        record.wasShown=true
        pcall(object.Hide,object)
    end
end

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

local function placePanel()
    if not panel or dragging then return end
    panel:ClearAllPoints()
    local position=api.GetQuestTimerPosition()
    if position then
        panel:SetPoint("CENTER",UIParent,"BOTTOMLEFT",
            position.x*UIParent:GetWidth(),position.y*UIParent:GetHeight())
    elseif Minimap then
        panel:SetPoint("TOP",Minimap,"BOTTOM",0,-24)
    else
        panel:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-32,-220)
    end
end

local function endDrag()
    if not dragging or not panel then return end
    panel:StopMovingOrSizing();dragging=false
    local x,y=panel:GetCenter()
    local width,height=UIParent:GetWidth(),UIParent:GetHeight()
    local scale=read(panel.GetEffectiveScale,panel) or 1
    local rootScale=read(UIParent.GetEffectiveScale,UIParent) or 1
    if finite(x) and finite(y) and width>0 and height>0 and rootScale>0 then
        api.SetQuestTimerPosition(math.max(0,math.min(1,x*scale/rootScale/width)),
            math.max(0,math.min(1,y*scale/rootScale/height)))
    end
    placePanel()
end

local function hideTooltip()
    if GameTooltip and read(GameTooltip.GetOwner,GameTooltip)==panel then GameTooltip:Hide() end
end

local function decoratePanel()
    local backdrop={bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
        tile=true,tileSize=16,insets={left=6,right=6,top=6,bottom=6}}
    if NineSliceUtil and type(NineSliceUtil.GetLayout)=="function"
        and type(NineSliceUtil.ApplyLayoutByName)=="function" and NineSliceUtil.GetLayout("Dialog") then
        -- Reuse dialog art only, without inheriting popup focus/binding scripts.
        panel.NineSlice=CreateFrame("Frame",nil,panel)
        panel.NineSlice:SetAllPoints(panel)
        panel.NineSlice:SetFrameLevel(panel:GetFrameLevel())
        panel.NineSlice.layoutType="Dialog"
        NineSliceUtil.ApplyLayoutByName(panel.NineSlice,"Dialog")
    else
        backdrop.edgeFile="Interface\\DialogFrame\\UI-DialogBox-Gold-Border"
        backdrop.edgeSize=16
    end
    panel:SetBackdrop(backdrop)
    panel:SetBackdropColor(0,0,0,0.95)
end

local function draw(show)
    if not show then if panel then panel:Hide() end;return end
    if not panel then
        panel=CreateFrame("Frame","NoQuestHintsForeverQuestTimers",UIParent,"BackdropTemplate")
        panel:SetSize(190,32)
        panel:SetMovable(true);panel:SetClampedToScreen(true);panel:EnableMouse(true)
        panel:RegisterForDrag("LeftButton")
        panel:SetScript("OnDragStart",function()
            hideTooltip();dragging=true;panel:StartMoving()
        end)
        panel:SetScript("OnDragStop",endDrag)
        panel:SetScript("OnHide",function() endDrag();hideTooltip() end)
        panel:SetScript("OnEnter",function()
            if not GameTooltip then return end
            GameTooltip:SetOwner(panel,"ANCHOR_LEFT");GameTooltip:SetText(L.TIMED_QUEST)
            for _,row in ipairs(rows) do
                if row:IsShown() then GameTooltip:AddLine(row.Title:GetText(),1,1,1,true) end
            end
            GameTooltip:AddLine(L.TIMERS_MOVE_HINT,1,0.82,0,true);GameTooltip:Show()
        end)
        panel:SetScript("OnLeave",hideTooltip)
        decoratePanel();placePanel()
    end
    local ids={};for id in pairs(timers) do ids[#ids+1]=id end;table.sort(ids)
    for index,id in ipairs(ids) do
        local row=rows[index]
        if not row then
            row=CreateFrame("Frame",nil,panel);rows[index]=row
            row:SetSize(166,16);row:SetPoint("TOPLEFT",panel,"TOPLEFT",12,-8-(index-1)*18)
            row.Title=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            row.Title:SetPoint("LEFT");row.Title:SetWidth(120);row.Title:SetHeight(16);row.Title:SetJustifyH("LEFT")
            row.Clock=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            row.Clock:SetPoint("RIGHT",row,"RIGHT",0,0);row.Clock:SetWidth(42);row.Clock:SetJustifyH("RIGHT")
        end
        row.Title:SetText(read(C_QuestLog and C_QuestLog.GetTitleForQuestID,id) or L.TIMED_QUEST)
        local seconds=math.ceil(timers[id])
        row.Clock:SetText(string.format("%d:%02d",math.floor(seconds/60),seconds%60))
        row:Show()
    end
    for index=#ids+1,#rows do rows[index]:Hide() end
    local height=16+#ids*18
    panel:SetHeight(height)
    if panel.NineSlice and type(NineSliceUtil.UpdateCornerCropping)=="function" then
        NineSliceUtil.UpdateCornerCropping(panel,height)
    end
    panel:Show()
end

refresh=function()
    if not ready or stopped then return end
    timers=snapshot()
    local hidden=api.IsQuestTimersHidden()==true
    local native=nativeFrame()
    if not combat() then
        if hidden then suppress(native) else restoreNative() end
        if native and native~=nativeHooked and type(native.HookScript)=="function" then
            nativeHooked=native;native:HookScript("OnShow",queue)
        end
        npcOffer()
    end
    -- Do not duplicate the native panel when it is usable outside the hidden tracker.
    local nativeVisible=native and read(native.IsVisible or native.IsShown,native)
    local alpha=native and read(native.GetEffectiveAlpha,native)
    -- IsVisible can stay true under an alpha-zero tracker. Conversely, some
    -- client layouts already keep the native timer directly under UIParent.
    local nativeUsable=nativeVisible and (type(alpha)=="number" and alpha>0
        or alpha==nil and not api.IsTrackerHidden())
    draw(not hidden and next(timers)~=nil and not nativeUsable)
end

local events=CreateFrame("Frame")
for _, event in ipairs({"ADDON_LOADED","PLAYER_ENTERING_WORLD","LOADING_SCREEN_ENABLED",
    "LOADING_SCREEN_DISABLED","QUEST_LOG_UPDATE","PLAYER_REGEN_ENABLED","PLAYER_LOGOUT",
    "UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED","QUEST_DETAIL","QUEST_FINISHED","QUEST_GREETING","QUEST_PROGRESS","QUEST_COMPLETE","QUEST_DATA_LOAD_RESULT"}) do
    events:RegisterEvent(event)
end
local elapsed=0
local function tick(_, delta)
    elapsed=elapsed+delta
    if elapsed<0.25 then return end
    elapsed=0
    refresh()
    if not next(timers) then events:SetScript("OnUpdate",nil) end
end
local function start()
    refresh()
    events:SetScript("OnUpdate",next(timers) and tick or nil)
end
-- Settings changes also start polling when an active timer was just received.
api.RefreshQuestTimers=function()
    if queued or not ready or stopped then return end
    if C_Timer and type(C_Timer.After)=="function" then
        queued=true
        C_Timer.After(0,function() queued=false;if ready and not stopped then start() end end)
    end
end
events:SetScript("OnEvent",function(_,event)
    if event=="QUEST_DETAIL" then
        offeredQuestID=read(GetQuestID)
        if offerLabel then offerLabel:Hide() end
    elseif event=="QUEST_FINISHED" or event=="QUEST_GREETING" or event=="QUEST_PROGRESS"
        or event=="QUEST_COMPLETE" or event=="LOADING_SCREEN_ENABLED" or event=="PLAYER_LOGOUT" then
        offeredQuestID=nil
        if offerLabel then offerLabel:Hide() end
    end
    if event=="PLAYER_LOGOUT" then
        stopped=true;ready=false;events:SetScript("OnUpdate",nil);draw(false)
        restoreNative()
    elseif event=="LOADING_SCREEN_ENABLED" then
        ready=false;events:SetScript("OnUpdate",nil);draw(false)
    else
        if event=="LOADING_SCREEN_DISABLED" or event=="PLAYER_ENTERING_WORLD" then ready=true end
        if event=="UI_SCALE_CHANGED" or event=="DISPLAY_SIZE_CHANGED"
            or event=="PLAYER_ENTERING_WORLD" then placePanel() end
        api.RefreshQuestTimers()
    end
end)
