-- Test selective navigation and safe CVar restoration (Lua 5.1).
local names = {
    "questPOI","showQuestObjectivesOnMap","questPOILocalStory",
    "minimapShowQuestBlobs","showInGameNavigation",
}
local values={}
for _,name in ipairs(names) do values[name]="1" end
local originalPrint=print
print=function() end
SlashCmdList={}
NoQuestHintsForeverChar=nil
NoQuestHintsForeverAccount=nil
NoQuestHintsForeverAPI=nil
local f
CreateFrame=function()
    f={events={}}
    function f:RegisterEvent(event) self.events[event]=true end
    function f:SetScript(_,callback) self.callback=callback end
    return f
end
local writes={}
C_CVar={
    GetCVar=function(name) return values[name] end,
    SetCVar=function(name,value)
        assert(values[name]~=nil)
        values[name]=value
        writes[#writes+1]={name,value}
        if f and f.events.CVAR_UPDATE then f.callback(f,"CVAR_UPDATE",name) end
    end,
    GetCVarInfo=function(name)
        return values[name], "1", name=="showInGameNavigation", name~="showInGameNavigation"
    end,
}
C_SuperTrack={
    GetSuperTrackedQuestID=function() return C_SuperTrack.current end,
    SetSuperTrackedQuestID=function(id)
        C_SuperTrack.current=id
        if f then f.callback(f,"SUPER_TRACKING_CHANGED") end
    end,
}
assert(loadfile("NoQuestHintsForever/NoQuestHintsForever.lua"))()
local char={revealedQuests={}}
local account={}
NoQuestHintsForeverChar=char
NoQuestHintsForeverAccount=account
f.callback(f,"ADDON_LOADED","NoQuestHintsForever")
f.callback(f,"PLAYER_LOGIN")
local api=NoQuestHintsForeverAPI
api.IsQuestNavigationAllowed=function()
    return char.revealedQuests[C_SuperTrack.current] == true
end
SlashCmdList.NOQUESTHINTSFOREVER("on")
for _,name in ipairs(names) do
    assert(values[name]=="0","expected map hints off: "..name)
end
assert(char.enabled==true)
assert(account.original.showInGameNavigation=="1")
char.revealedQuests[101]=true
C_SuperTrack.SetSuperTrackedQuestID(101)
assert(values.showInGameNavigation=="1","navigation not enabled for revealed supertracked quest")
for _,name in ipairs(names) do
    if name~="showInGameNavigation" then
        assert(values[name]=="0","other map CVar leaked after navigation: "..name)
    end
end
C_SuperTrack.SetSuperTrackedQuestID(200)
assert(values.showInGameNavigation=="0","navigation leaked toward hidden quest")
char.revealedQuests[200]=true
api.RefreshNavigation()
assert(values.showInGameNavigation=="1","navigation not reenabled for second allowed quest")
char.revealedQuests[200]=nil
api.RefreshNavigation()
assert(values.showInGameNavigation=="0","navigation not hidden on permission removal")
SlashCmdList.NOQUESTHINTSFOREVER("off")
assert(char.enabled==false)
for _,name in ipairs(names) do
    assert(values[name]=="1","OFF failed to restore original "..name)
end
assert(next(account.original)==nil and next(char.original)==nil)
-- While globally OFF, SUPER_TRACKING_CHANGED may not enforce anything.
C_SuperTrack.SetSuperTrackedQuestID(200)
assert(values.showInGameNavigation=="1","OFF still suppressed native navigation")
print=originalPrint
io.write("PASS: selective SuperTrack diamond, no unrelated navigation, original CVars restored\n")
