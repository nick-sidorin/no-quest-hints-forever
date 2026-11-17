-- Native instance classification and temporary effects, never saved-option rewrites.
local function session(char, account, location, values)
    local events, pending, writes, callbacks = {}, {}, {}, {}
    local combat=false
    location=location or {inside=false,kind='none'}
    values=values or {}
    local names={'questPOI','showQuestObjectivesOnMap','questPOILocalStory','minimapShowQuestBlobs','showInGameNavigation','UnitNameFriendlySpecialNPCName'}
    for _,name in ipairs(names) do if values[name]==nil then values[name]='1' end end
    NoQuestHintsForeverChar=char or {}
    NoQuestHintsForeverAccount=account or {}
    NoQuestHintsForeverAPI=nil
    NoQuestHintsForeverLocale={}
    ObjectiveTrackerFrame=nil
    C_AddOns=nil;GetAddOnMetadata=nil;hooksecurefunc=nil
    SlashCmdList={};print=function() end
    local blocked={}
    IsInInstance=function()
        if location.throws then error('instance API not ready') end
        return location.inside, location.kind
    end
    InCombatLockdown=function() return combat end
    C_Timer={After=function(_,fn) pending[#pending+1]=fn end}
    CreateFrame=function()
        local f={events={}}
        function f:RegisterEvent(e) self.events[e]=true end
        function f:UnregisterEvent(e) self.events[e]=nil end
        function f:SetScript(_,fn) self.onEvent=fn end
        events[#events+1]=f
        return f
    end
    local function event(e,arg)
        for _,f in ipairs(events) do if f.events[e] then f.onEvent(f,e,arg) end end
    end
    C_CVar={
        GetCVar=function(name) return values[name] end,
        GetCVarInfo=function(name) return values[name],'1',name=='showInGameNavigation',name~='showInGameNavigation' end,
        SetCVar=function(name,value)
            if blocked[name] then error('write unavailable') end
            values[name]=value;writes[#writes+1]={name,value}
            event('CVAR_UPDATE',name)
        end,
    }
    assert(loadfile('NoQuestHintsForever/NoQuestHintsForever.lua'))()
    local api=NoQuestHintsForeverAPI
    local pinRefreshes=0
    api.RefreshQuestHintPins=function()
        assert(not combat,'pin refresh in combat')
        pinRefreshes=pinRefreshes+1
    end
    -- Unrelated effect entry points must never be called by a policy refresh.
    local unrelated=0
    for _,name in ipairs({'RefreshHUDVisibility','RefreshQuestTimers','RefreshQuestPresentation',
        'RefreshQuestItemHighlight','RefreshQuestProgressMessages'}) do
        api[name]=function() unrelated=unrelated+1 end
    end
    Enum={TooltipDataLineType={QuestTitle=1,QuestObjective=2,QuestPlayer=3},TooltipDataType={Unit=1,Object=2,Item=3}}
    TooltipDataProcessor={AddLinePreCall=function(kind,fn) callbacks[kind]=fn end}
    assert(loadfile('NoQuestHintsForever/QuestTooltips.lua'))()
    local function flush()
        local n=0
        while #pending>0 do
            n=n+1;assert(n<30,'deferred loop')
            local batch=pending;pending={}
            for _,fn in ipairs(batch) do fn() end
        end
    end
    event('ADDON_LOADED','NoQuestHintsForever');event('PLAYER_LOGIN');flush()
    if NoQuestHintsForeverChar.restoreGuidanceInInstances then
        for _,write in ipairs(writes) do
            assert(write[1]~='UnitNameFriendlySpecialNPCName','NPC policy must wait for loading')
        end
    end
    event('LOADING_SCREEN_DISABLED');flush()
    return {api=api,char=NoQuestHintsForeverChar,account=NoQuestHintsForeverAccount,values=values,
        where=location,event=event,flush=flush,blocked=blocked,
        combat=function(value) combat=value end,
        writes=function() return #writes end,
        pins=function() return pinRefreshes end,
        unrelated=function() return unrelated end,
        tooltip=function(kind) return callbacks[1]({processingInfo={tooltipData={type=kind or 1}}}) end}
end
local function profile(policy)
    return {enabled=true,hideQuestTooltips=true,hideQuestNPCNames=true,
        hideTracker=true,hideQuestLevels=true,hideQuestDifficulty=true,hideSellPrices=true,
        hideAuctionSellPrices=true,hideQuestProgressMessages=true,hideQuestItemHighlight=true,
        hideQuestTimers=true,hideExperienceBar=true,hideMinimap=true,
        restoreGuidanceInInstances=policy,onboardingComplete=true,revealedQuests={[123]=true}}
end
local function restricted(s,want)
    assert(s.api.IsMapHidden()==true,'instance policy changed map hiding')
    assert(s.api.IsTooltipHintsHidden()==want)
    assert(s.api.IsQuestNPCNamesHidden()==want)
    for _,name in ipairs({'IsTrackerHidden','IsSellPriceHidden','IsAuctionSellPriceHidden',
        'IsQuestLevelsHidden','IsQuestDifficultyHidden','IsQuestProgressHidden',
        'IsQuestItemHighlightHidden','IsQuestTimersHidden','IsExperienceBarHidden','IsMinimapHidden'}) do
        assert(s.api[name]()==true,'unrelated restriction changed: '..name)
    end
    assert(s.char.enabled and s.char.hideQuestTooltips and s.char.hideQuestNPCNames)
    assert(s.api.IsTooltipHidingConfigured() and s.api.IsNPCNameHidingConfigured())
    assert(s.char.revealedQuests[123],'instance policy changed quest permissions')
end
-- OFF is inert even in an instance, and outdoor parties/raids are not instances.
for _,kind in ipairs({'party','raid'}) do
    local s=session(profile(false),{}, {inside=true,kind=kind})
    restricted(s,true);assert(s.tooltip()==true)
end
local s=session(profile(true))
restricted(s,true);assert(s.values.questPOI=='0' and s.values.UnitNameFriendlySpecialNPCName=='0')
assert(s.tooltip()==true and not s.tooltip(3))
local unrelated=s.unrelated()
local before=s.writes();local pins=s.pins()
s.where.inside=true;s.where.kind='party'
s.event('PLAYER_ENTERING_WORLD');s.event('ZONE_CHANGED_NEW_AREA')
assert(s.writes()==before and s.pins()==pins,'location callback must defer game-side effects')
s.flush();restricted(s,false)
assert(s.values.questPOI=='0' and s.values.showInGameNavigation=='0')
assert(s.char.original.questPOI=='1','map baseline lost during exception')
assert(s.values.UnitNameFriendlySpecialNPCName=='1' and not s.tooltip())
assert(s.unrelated()==unrelated,'instance change refreshed an unrelated feature')
assert(s.pins()==pins)
-- Repeated signals coalesce without erasing the saved flags.
s.event('ZONE_CHANGED_NEW_AREA');s.event('ZONE_CHANGED_NEW_AREA');s.flush()
assert(s.pins()==pins)
s.where.inside=false;s.where.kind='none';s.event('PLAYER_ENTERING_WORLD');s.flush()
restricted(s,true);assert(s.values.questPOI=='0' and s.tooltip()==true)
-- Only party/raid instance types are covered, not battlegrounds/scenarios or map labels.
for _,kind in ipairs({'pvp','arena','scenario','none','unknown'}) do
    s.where.inside=true;s.where.kind=kind;s.event('ZONE_CHANGED_NEW_AREA');s.flush()
    restricted(s,true)
end
s.where.inside=false;s.where.kind='raid';s.event('ZONE_CHANGED_NEW_AREA');s.flush();restricted(s,true)
s.where.inside=true;s.event('ZONE_CHANGED_NEW_AREA');s.flush();restricted(s,false)
s.api.SetInstanceGuidanceEnabled(false);s.flush();restricted(s,true)
s.api.SetInstanceGuidanceEnabled(true);s.flush();restricted(s,false)
-- While suspended, manual edits change configuration without forcing effects back on.
s.api.SetMapHidden(false);s.api.SetTooltipHintsHidden(false);s.api.SetQuestNPCNamesHidden(false)
s.where.inside=false;s.event('ZONE_CHANGED_NEW_AREA');s.flush()
assert(not s.api.IsMapHidden() and not s.api.IsTooltipHintsHidden() and not s.api.IsQuestNPCNamesHidden())
-- Respect personal Blizzard baselines: pause removes our suppression, never forces 1.
s=session(profile(true),{},nil,{questPOI='0',UnitNameFriendlySpecialNPCName='0'})
s.where.inside=true;s.where.kind='party';s.event('ZONE_CHANGED_NEW_AREA');s.flush()
assert(s.values.questPOI=='0' and s.values.UnitNameFriendlySpecialNPCName=='0')
-- Preserve failed restoration backups; a later native CVar signal retries recovery.
s=session(profile(true));s.blocked.UnitNameFriendlySpecialNPCName=true
s.where.inside=true;s.where.kind='raid';s.event('ZONE_CHANGED_NEW_AREA');s.flush()
assert(s.account.npcNameOriginal=='1' and s.values.UnitNameFriendlySpecialNPCName=='0')
s.blocked.UnitNameFriendlySpecialNPCName=nil;s.event('CVAR_UPDATE','UnitNameFriendlySpecialNPCName');s.flush()
assert(s.values.UnitNameFriendlySpecialNPCName=='1' and s.account.npcNameOriginal==nil)
-- Native map changes and manual navigation permissions retain ordinary enforcement.
s.values.questPOI='1';s.event('CVAR_UPDATE','questPOI');assert(s.values.questPOI=='0')
s.api.IsQuestNavigationAllowed=function() return true end
s.event('SUPER_TRACKING_CHANGED');assert(s.values.showInGameNavigation=='1')
s.api.IsQuestNavigationAllowed=function() return false end
s.event('SUPER_TRACKING_CHANGED');assert(s.values.showInGameNavigation=='0')
-- Login/reload inside an instance also recovers suppression from a prior session.
s=session(profile(true),{npcNameOriginal='1',original={showInGameNavigation='1'}},
    {inside=true,kind='party'}, {UnitNameFriendlySpecialNPCName='0',showInGameNavigation='0'})
restricted(s,false);assert(s.values.UnitNameFriendlySpecialNPCName=='1' and s.values.showInGameNavigation=='0')
assert(s.account.original.showInGameNavigation=='1')
s=session(s.char,s.account,{inside=true,kind='party'},s.values)
restricted(s,false);assert(s.char.restoreGuidanceInInstances)
s.event('PLAYER_LOGOUT');assert(s.char.restoreGuidanceInInstances and s.char.enabled)
-- A character who did not select those hiding controls must never acquire them.
local disabled=profile(true)
disabled.enabled=false;disabled.hideQuestTooltips=false;disabled.hideQuestNPCNames=false
s=session(disabled,{}, {inside=true,kind='raid'})
assert(not s.api.IsMapHidden() and not s.api.IsTooltipHintsHidden() and not s.api.IsQuestNPCNamesHidden())
s.where.inside=false;s.event('ZONE_CHANGED_NEW_AREA');s.flush()
assert(not s.char.enabled and not s.char.hideQuestTooltips and not s.char.hideQuestNPCNames)
assert(s.values.questPOI=='1' and s.values.UnitNameFriendlySpecialNPCName=='1')
-- No capability/unknown results must not silently enable the exception.
s=session(profile(true),{}, {throws=true});restricted(s,true)
IsInInstance=nil;assert(not s.api.IsInstanceGuidanceActive() and s.api.IsMapHidden())
-- Loading and combat prevent CVar/pin work and respect the final requested state.
s=session(profile(true));before=s.writes()
s.event('LOADING_SCREEN_ENABLED');s.where.inside=true;s.where.kind='party'
s.event('PLAYER_ENTERING_WORLD');s.event('ZONE_CHANGED_NEW_AREA');s.flush()
assert(s.writes()==before,'loading callback changed CVars')
s.event('LOADING_SCREEN_DISABLED');s.flush()
assert(s.values.questPOI=='0' and s.values.UnitNameFriendlySpecialNPCName=='1')
s.where.inside=false;s.event('ZONE_CHANGED_NEW_AREA');s.flush()
s.combat(true);before=s.writes();s.where.inside=true;s.where.kind='raid'
s.event('PLAYER_ENTERING_WORLD');s.flush()
assert(s.writes()==before,'combat callback changed CVars')
s.combat(false);s.event('PLAYER_REGEN_ENABLED');s.flush();restricted(s,false)
s.combat(true);before=s.writes();s.api.SetInstanceGuidanceEnabled(false);s.flush()
s.event('CVAR_UPDATE','UnitNameFriendlySpecialNPCName');assert(s.writes()==before)
s.combat(false);s.event('PLAYER_REGEN_ENABLED');s.flush();restricted(s,true)
-- A stale queued callback cannot reapply after logout.
s=session(profile(true));s.where.inside=true;s.where.kind='party';s.event('ZONE_CHANGED_NEW_AREA')
s.event('PLAYER_LOGOUT');before=s.writes();s.flush();assert(s.writes()==before)
io.write('PASS: dungeon/raid guidance exception, only tooltips and NPC names; unchanged map/navigation, native baselines, deferred combat/loading, reload and saved choices\n')
