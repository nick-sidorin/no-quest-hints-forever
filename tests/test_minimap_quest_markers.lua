-- Native QuestPOIs filter: stable identity, exact baselines and real core lifecycle.
local module='NoQuestHintsForever/MinimapQuestMarkers.lua'
local KEY='minimapQuestTrackingOriginal'
local function session(char,account,scope,active,options)
    options=options or {}
    NoQuestHintsForeverChar,NoQuestHintsForeverAccount,NoQuestHintsForeverAPI=nil,nil,nil
    ObjectiveTrackerFrame,GetCVar,SetCVar,GetCVarInfo,C_AddOns,GetAddOnMetadata=nil,nil,nil,nil,nil,nil
    SlashCmdList={}
    local frames,timers,writes={},{},{}
    local combat,ready,fail,ignored=false,not options.notReady,false,false
    local entries={{filterID=1,active=true},{spellID=123,active=true},
        {filterID=65536,active=active},{filterID=64,active=false}}
    local quest=entries[3]
    local function event(name,detail)
        for _,f in ipairs(frames) do if f.events[name] then f.handler(f,name,detail) end end
    end
    CreateFrame=function()
        local f={events={}}
        function f:RegisterEvent(e) self.events[e]=true end
        function f:SetScript(_,fn) self.handler=fn end
        frames[#frames+1]=f;return f
    end
    print=function() end
    GetLocale=function() return 'enUS' end
    C_CVar={GetCVar=function() end,SetCVar=function() error('do not overwrite tracking CVar') end,
        GetCVarInfo=function(name)
            if name=='minimapTrackedInfov4' then return '0','0',scope=='account',scope=='character' end
        end}
    C_Timer=not options.noTimer and {After=function(delay,fn)
        assert(delay==0);timers[#timers+1]=fn
    end} or nil
    InCombatLockdown=function() return combat end
    Enum={MinimapTrackingFilter={QuestPOIs=65536}}
    local native={
        GetNumTrackingTypes=function() return #entries end,
        GetTrackingFilter=function(index)
            local e=entries[index];return {filterID=e.filterID,spellID=e.spellID}
        end,
        GetTrackingInfo=function(index)
            if ready then return {name='Нелокализованный поиск запрещён',active=entries[index].active} end
        end,
        SetTracking=function(index,value)
            assert(not combat,'tracking changed in combat')
            assert(entries[index]==quest,'unrelated tracking filter changed')
            if fail then error('write blocked') end
            writes[#writes+1]={index=index,value=value}
            if not ignored then entries[index].active=value end
            event('MINIMAP_UPDATE_TRACKING')
            event('CVAR_UPDATE','minimapTrackedInfov4')
        end,
    }
    C_Minimap=not options.missing and native or nil
    dofile('NoQuestHintsForever/Localization.lua')
    dofile('NoQuestHintsForever/NoQuestHintsForever.lua')
    dofile(module)
    NoQuestHintsForeverChar,NoQuestHintsForeverAccount=char,account
    local function flush()
        local count=0
        while #timers>0 do
            count=count+1;assert(count<30,'native tracking event loop')
            table.remove(timers,1)()
        end
    end
    event('ADDON_LOADED','NoQuestHintsForever');event('PLAYER_LOGIN');flush()
    return {api=NoQuestHintsForeverAPI,event=event,flush=flush,writes=writes,entries=entries,quest=quest,
        active=function() return quest.active end,
        enable=function() C_Minimap=native end,
        setReady=function(value) ready=value end,setCombat=function(value) combat=value end,
        setFail=function(value) fail=value end,setIgnored=function(value) ignored=value end}
end

local char,account={},{}
local s=session(char,account,'account',true)
assert(#s.writes==0 and account[KEY]==nil,'default OFF altered native tracking')
s.api.SetMinimapQuestMarkersHidden(true);s.flush()
assert(not s.active() and account[KEY]==true and char.hideMinimapQuestMarkers)
assert(s.entries[1].active and s.entries[2].active and not s.entries[4].active)
-- Never cache an index: hunter spells and other tracking entries can reorder it.
local mailbox=s.entries[4]
local quest=table.remove(s.entries,3);table.insert(s.entries,quest)
quest.active=true;s.event('MINIMAP_UPDATE_TRACKING');s.flush()
assert(not s.active() and s.writes[#s.writes].index==4)
mailbox.active=true -- a user change to another tracking bit must survive restore
local count=#s.writes
s.event('MINIMAP_UPDATE_TRACKING');s.event('CVAR_UPDATE','unrelated');s.flush()
assert(#s.writes==count,'unchanged native state caused redundant writes')
s.api.SetMinimapQuestMarkersHidden(false);s.flush()
assert(s.active() and account[KEY]==nil and mailbox.active,'exact original or unrelated state not restored')

-- Preserve an original OFF state, even if another source turns it on meanwhile.
local off,offAccount={},{}
s=session(off,offAccount,'account',false)
s.api.SetMinimapQuestMarkersHidden(true);s.flush()
assert(offAccount[KEY]==false and #s.writes==0)
s.quest.active=true;s.event('MINIMAP_UPDATE_TRACKING');s.flush()
s.api.SetMinimapQuestMarkersHidden(false);s.flush()
assert(not s.active() and offAccount[KEY]==nil)

-- Reload and normal logout retain the preference, but restore the saved filter.
char,account={},{}
s=session(char,account,'account',true)
s.api.SetMinimapQuestMarkersHidden(true);s.flush()
s=session(char,account,'account',false)
assert(account[KEY]==true and not s.active(),'reload replaced the original baseline')
s.event('PLAYER_LOGOUT');s.flush()
assert(s.active() and char.hideMinimapQuestMarkers and account[KEY]==nil)
s=session(char,account,'account',true)
assert(not s.active() and account[KEY]==true)
local alt={}
s=session(alt,account,'account',false)
assert(s.active() and not alt.hideMinimapQuestMarkers and account[KEY]==nil,
    'OFF alt did not recover shared tracking baseline')

-- Follow explicit per-character CVar scope instead of borrowing another alt's state.
char,account={},{}
s=session(char,account,'character',true)
s.api.SetMinimapQuestMarkersHidden(true);s.flush()
assert(char[KEY]==true and account[KEY]==nil)
s=session({},account,'character',false)
assert(not s.active() and #s.writes==0 and char[KEY]==true)
s=session(char,account,'character',false)
s.api.SetMinimapQuestMarkersHidden(false);s.flush();assert(s.active() and char[KEY]==nil)
-- Unavailable scope metadata uses shared recovery rather than dropping the backup.
s=session({}, {}, 'unknown',true)
s.api.SetMinimapQuestMarkersHidden(true);s.flush()
assert(NoQuestHintsForeverAccount[KEY]==true)

-- Combat defers both application and restoration; core restore reports pending.
char,account={},{}
s=session(char,account,'account',true)
s.setCombat(true);s.api.SetMinimapQuestMarkersHidden(true);s.flush()
assert(s.active() and account[KEY]==nil)
s.setCombat(false);s.event('PLAYER_REGEN_ENABLED');s.flush();assert(not s.active())
s.setCombat(true)
assert(not s.api.RestoreGameSettings(),'combat recovery should be pending')
assert(account[KEY]==true and not s.active() and not char.hideMinimapQuestMarkers)
s.setCombat(false);s.event('PLAYER_REGEN_ENABLED');s.flush()
assert(s.active() and account[KEY]==nil and s.api.RestoreGameSettings())

-- Failed/ignored writes retain recoverable originals; do not claim restoration.
char,account={},{}
s=session(char,account,'account',true)
s.api.SetMinimapQuestMarkersHidden(true);s.flush();s.setFail(true)
assert(not s.api.RestoreGameSettings());s.flush()
assert(account[KEY]==true and not s.active())
s.setFail(false);s.event('PLAYER_REGEN_ENABLED');s.flush()
assert(s.active() and account[KEY]==nil)
s=session({}, {}, 'account',true)
s.setIgnored(true);s.api.SetMinimapQuestMarkersHidden(true);s.flush()
assert(s.active() and NoQuestHintsForeverAccount[KEY]==true,'ignored write lost original')

-- Missing or not-yet-populated native APIs must be passive until available.
char,account={hideMinimapQuestMarkers=true},{}
s=session(char,account,'account',true,{missing=true})
assert(#s.writes==0 and account[KEY]==nil)
s.enable();s.event('ADDON_LOADED','Blizzard_Minimap');s.flush();assert(not s.active())
s.api.SetMinimapQuestMarkersHidden(false);s.flush();assert(s.active())
s=session({hideMinimapQuestMarkers=true},{},'account',true,{notReady=true})
assert(s.active() and NoQuestHintsForeverAccount[KEY]==nil)
s.setReady(true);s.event('VARIABLES_LOADED');s.flush();assert(not s.active())
-- Pending restore survives a missing API and retries when tracking returns.
s.enable();C_Minimap=nil
assert(not s.api.RestoreGameSettings())
s.enable();s.event('SPELLS_CHANGED');s.flush();assert(s.active())

-- Full immersion only; restore and logout cannot leave a queued reapplication.
char,account={},{}
s=session(char,account,'account',true)
for _,preset in ipairs({'blizzard','immersion','full'}) do
 assert(s.api.ApplyPreset(preset));s.flush()
 assert(s.active()==(preset~='full'))
end
assert(s.api.RestoreGameSettings());s.flush();assert(s.active())
s.api.SetMinimapQuestMarkersHidden(true)
s.event('PLAYER_LOGOUT');s.flush()
assert(s.active() and account[KEY]==nil,'queued write ran after logout')
s=session({}, {}, 'account',true,{noTimer=true})
s.api.SetMinimapQuestMarkersHidden(true);assert(not s.active())
s.api.SetMinimapQuestMarkersHidden(false);assert(s.active())
io.write('PASS: native minimap quest filter, isolated writes, exact scoped restore, reload/alts, combat and late APIs\n')
