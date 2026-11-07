-- Upgrade notices use actual TOC metadata and the real SavedVariables lifecycle.
local function session(char, account, version, locale, mode)
    NoQuestHintsForeverChar, NoQuestHintsForeverAccount = nil, nil
    NoQuestHintsForeverAPI, ObjectiveTrackerFrame = nil, nil
    SlashCmdList = {}
    local messages, frames = {}, {}
    print = function(message) messages[#messages+1]=message end
    GetLocale = function() return locale or 'enUS' end
    assert(loadfile('NoQuestHintsForever/Localization.lua'))()
    C_CVar, GetCVar, SetCVar = nil, nil, nil
    C_AddOns, GetAddOnMetadata = nil, nil
    local function metadata(addon, field)
        assert(addon=='NoQuestHintsForever' and field=='Version')
        if mode=='throws' then error('metadata unavailable') end
        return version
    end
    if mode=='legacy' then GetAddOnMetadata=metadata
    elseif mode~='missing' then C_AddOns={GetAddOnMetadata=metadata} end
    CreateFrame=function()
        local f={events={}}
        function f:RegisterEvent(e) self.events[e]=true end
        function f:SetScript(_,fn) self.onEvent=fn end
        frames[#frames+1]=f
        return f
    end
    assert(loadfile('NoQuestHintsForever/NoQuestHintsForever.lua'))()
    assert(NoQuestHintsForeverChar==nil and NoQuestHintsForeverAccount==nil)
    NoQuestHintsForeverChar, NoQuestHintsForeverAccount=char,account
    local function event(e,detail)
        for _,f in ipairs(frames) do if f.events[e] then f.onEvent(f,e,detail) end end
    end
    event('ADDON_LOADED','NoQuestHintsForever')
    assert(#messages==0, 'upgrade notice emitted before login')
    event('PLAYER_LOGIN')
    return {messages=messages,event=event}
end
local fresh,account={},{}
local s=session(fresh,account,'1.4.0')
assert(#s.messages==0 and account.lastSeenVersion=='1.4.0', 'first install must be silent')
assert(fresh.onboardingComplete==false, 'version bookkeeping broke first-run detection')
s=session(fresh,account,'1.4.0')
assert(#s.messages==0, 'ordinary reload repeated notice')
s=session(fresh,account,'1.5.0','ruRU')
assert(#s.messages==1 and s.messages[1]:find('обновлён',1,true)
    and s.messages[1]:find('1.5.0',1,true))
s.event('PLAYER_LOGIN');s.event('PLAYER_ENTERING_WORLD');s.event('ADDON_LOADED','OtherAddon')
assert(#s.messages==1, 'repeated lifecycle events repeated notice')
assert(#session({},account,'1.5.0').messages==0, 'alt repeated account-wide notice')
assert(#session(fresh,account,'1.4.0').messages==0 and account.lastSeenVersion=='1.5.0',
    'downgrade announced an upgrade or reset the baseline')
assert(#session(fresh,account,'1.5.0').messages==0)
assert(#session(fresh,account,'1.10.0').messages==1, 'versions compared lexically')
assert(#session(fresh,account,'2.0.0-alpha.2').messages==1)
assert(#session(fresh,account,'2.0.0-alpha.10').messages==1)
assert(#session(fresh,account,'2.0.0-beta.1').messages==1)
assert(#session(fresh,account,'2.0.0').messages==1)
assert(#session(fresh,account,'2.0.0-beta.5').messages==0)
-- Upgrade from existing releases without version bookkeeping is announced once.
local old={enabled=false,hideQuestDifficulty=true,onboardingComplete=true,revealedQuests={[123]=true}}
local legacyAccount={}
s=session(old,legacyAccount,'1.4.0','enUS','legacy')
assert(#s.messages==1 and s.messages[1]:find('Updated to version 1.4.0',1,true))
assert(old.hideQuestDifficulty and old.revealedQuests[123] and not old.enabled)
assert(#session(old,legacyAccount,'1.4.0').messages==0)
for _,mode in ipairs({'missing','throws','modern'}) do
    for _,value in ipairs({'@project-version@','unknown','1.4','1.4.0-preview'}) do
        local invalid={}
        assert(#session({},invalid,value,'enUS',mode).messages==0 and invalid.lastSeenVersion==nil)
    end
end
local damaged={lastSeenVersion=42}
assert(#session({},damaged,'1.4.0').messages==0 and damaged.lastSeenVersion=='1.4.0')
io.write('PASS: account-wide upgrade notice, metadata versions, legacy migration, no reload/alt/downgrade spam\n')

-- Fix-only versions use a neutral message; skipped feature releases count.
local patch={lastSeenVersion='1.4.0'}
s=session({},patch,'1.4.1')
assert(#s.messages==1 and not s.messages[1]:find('new features',1,true) and not patch.newSettings)
local skipped={lastSeenVersion='1.3.0'}
s=session({},skipped,'1.4.5')
assert(#s.messages==1 and s.messages[1]:find('new features',1,true))
assert(NoQuestHintsForeverAPI.IsSettingNew('NQH_HIDE_QUEST_LEVELS'))
assert(not NoQuestHintsForeverAPI.IsSettingNew('NQH_HIDE_MAP_HINTS'))
NoQuestHintsForeverAPI.MarkSettingSeen('NQH_HIDE_QUEST_LEVELS')
assert(not NoQuestHintsForeverAPI.IsSettingNew('NQH_HIDE_QUEST_LEVELS'))
s=session({},skipped,'1.4.6')
assert(not s.messages[1]:find('new features',1,true))
assert(not NoQuestHintsForeverAPI.IsSettingNew('NQH_HIDE_QUEST_LEVELS'))
assert(NoQuestHintsForeverAPI.IsSettingNew('NQH_HIDE_QUEST_DIFFICULTY'), 'unseen feature lost across patch')
assert(#session({},skipped,'1.4.6').messages==0)
assert(not NoQuestHintsForeverAPI.IsSettingNew('NQH_HIDE_QUEST_LEVELS'), 'viewed marker returned on alt')
local freshFeatures={}
session({},freshFeatures,'1.4.0')
assert(not freshFeatures.newSettings, 'first install marked everything as an upgrade')
