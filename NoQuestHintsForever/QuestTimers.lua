-- Client-owned quest deadlines; never persist or restart an addon countdown.
-- Forever's C_QuestLog.GetQuestTimers returns {questID, questTimer} records.
local api = NoQuestHintsForeverAPI
if not api then return end
local L = NoQuestHintsForeverLocale
local panel, label, detailsOwner, nativeHooked
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

local function journal()
    local details=QuestMapFrame and QuestMapFrame.DetailsFrame
    if details~=detailsOwner then
        if label then label:Hide() end
        label=nil;detailsOwner=details
    end
    if not details or type(details.CreateFontString)~="function" or combat() then return end
    if not label then
        label=details:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        label:SetPoint("BOTTOMLEFT",details.BackFrame or details,"BOTTOMLEFT",12,3)
        label:SetWidth(275);label:SetHeight(14);label:SetJustifyH("LEFT")
        label:SetText(L.TIMED_QUEST)
        if type(details.HookScript)=="function" then details:HookScript("OnShow",queue) end
    end
    if ready and timed(details.questID) then label:Show() else label:Hide() end
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
        offerLabel=owner:CreateFontString(nil,"OVERLAY","GameFontNormal")
        -- The native panel leaves a band above the parchment/scroll frame.
        -- Keep the note visible while scrolling without moving native content.
        offerLabel:SetPoint("TOPLEFT",owner,"TOPLEFT",20,-42)
        offerLabel:SetWidth(290);offerLabel:SetHeight(18);offerLabel:SetJustifyH("CENTER")
        offerLabel:SetText(L.TIMED_QUEST)
        if type(owner.HookScript)=="function" then
            owner:HookScript("OnShow",queue)
            owner:HookScript("OnHide",function() if offerOwner==owner and offerLabel then offerLabel:Hide() end end)
        end
    end
    local current=read(GetQuestID)
    if ready and offeredQuestID and current==offeredQuestID and timed(current)
        and read(owner.IsShown,owner) then offerLabel:Show() else offerLabel:Hide() end
end

local function draw(show)
    if not show then if panel then panel:Hide() end;return end
    if not panel then
        panel=CreateFrame("Frame","NoQuestHintsForeverQuestTimers",UIParent,"BackdropTemplate")
        panel:SetSize(260,40)
        panel:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-70,-220)
        panel:EnableMouse(false)
        panel:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=16,
            insets={left=4,right=4,top=4,bottom=4}})
        panel:SetBackdropColor(0,0,0,0.85)
    end
    local ids={};for id in pairs(timers) do ids[#ids+1]=id end;table.sort(ids)
    for index,id in ipairs(ids) do
        local row=rows[index]
        if not row then
            row=CreateFrame("Frame",nil,panel);rows[index]=row
            row:SetSize(236,34);row:SetPoint("TOPLEFT",panel,"TOPLEFT",12,-10-(index-1)*36)
            row.Title=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            row.Title:SetPoint("TOPLEFT");row.Title:SetWidth(236);row.Title:SetHeight(14);row.Title:SetJustifyH("LEFT")
            row.Clock=row:CreateFontString(nil,"OVERLAY","GameFontNormal")
            row.Clock:SetPoint("TOPLEFT",row.Title,"BOTTOMLEFT",0,-3)
        end
        row.Title:SetText(read(C_QuestLog and C_QuestLog.GetTitleForQuestID,id) or L.TIMED_QUEST)
        local seconds=math.ceil(timers[id])
        row.Clock:SetText(string.format("%d:%02d",math.floor(seconds/60),seconds%60))
        row:Show()
    end
    for index=#ids+1,#rows do rows[index]:Hide() end
    panel:SetHeight(20+#ids*36);panel:Show()
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
        journal()
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
    "QUEST_DETAIL","QUEST_FINISHED","QUEST_GREETING","QUEST_PROGRESS","QUEST_COMPLETE","QUEST_DATA_LOAD_RESULT"}) do
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
local hookInstalled=false
local function install()
    if not hookInstalled and type(QuestMapFrame_ShowQuestDetails)=="function" and type(hooksecurefunc)=="function" then
        hookInstalled=pcall(hooksecurefunc,"QuestMapFrame_ShowQuestDetails",api.RefreshQuestTimers)
    end
end
events:SetScript("OnEvent",function(_,event)
    if event=="QUEST_DETAIL" then offeredQuestID=read(GetQuestID)
    elseif event=="QUEST_FINISHED" or event=="QUEST_GREETING" or event=="QUEST_PROGRESS"
        or event=="QUEST_COMPLETE" or event=="LOADING_SCREEN_ENABLED" or event=="PLAYER_LOGOUT" then
        offeredQuestID=nil
        if offerLabel then offerLabel:Hide() end
    end
    if event=="PLAYER_LOGOUT" then
        stopped=true;ready=false;events:SetScript("OnUpdate",nil);draw(false)
        if label then label:Hide() end
        restoreNative()
    elseif event=="LOADING_SCREEN_ENABLED" then
        ready=false;events:SetScript("OnUpdate",nil);draw(false)
        if label then label:Hide() end
    else
        install()
        if event=="LOADING_SCREEN_DISABLED" or event=="PLAYER_ENTERING_WORLD" then ready=true end
        api.RefreshQuestTimers()
    end
end)
