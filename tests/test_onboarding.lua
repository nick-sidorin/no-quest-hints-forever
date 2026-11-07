-- First-run decisions, persistence, reversible presets and uninstall preparation.
local mapNames = { "questPOI", "showQuestObjectivesOnMap", "questPOILocalStory",
    "minimapShowQuestBlobs", "showInGameNavigation" }
local npc = "UnitNameFriendlySpecialNPCName"
local function session(char, account, suppliedValues, combat, locale, withoutAtlases, pauseBeforeWorld)
    local values = suppliedValues or { [npc] = "1" }
    for _, name in ipairs(mapNames) do if values[name] == nil then values[name] = "1" end end
    local frames, writes, failed = {}, {}, {}
    local deferred={}
    C_Timer={After=function(delay,fn) assert(delay==0);deferred[#deferred+1]=fn end}
    local function flush()
        local count=0
        while #deferred>0 do
            count=count+1;assert(count<50,"deferred startup loop")
            table.remove(deferred,1)()
        end
    end
    NoQuestHintsForeverChar, NoQuestHintsForeverAccount, NoQuestHintsForeverAPI = nil, nil, nil
    NoQuestHintsForeverWelcome, NoQuestHintsForeverWelcomeBlocker, ObjectiveTrackerFrame, Settings = nil, nil, nil, nil
    GameTooltip = { shown=true, hideCount=0, Hide=function(self) self.shown=false; self.hideCount=self.hideCount+1 end }
    SlashCmdList, UISpecialFrames = {}, {}
    C_Texture = { GetAtlasInfo = function(name)
        if withoutAtlases then return nil end
        if name == "Mode-Selection-Card-Regular" or name == "Mode-Selection-Card-Regular-yellow-glow" then
            return { width=300, height=600 }
        elseif name == "Mode-Selection-Ring" or name == "CircleMask" then
            return { width=80, height=80 }
        end
    end }
    local function region()
        local obj = {}
        function obj:SetSize(w,h) self.width,self.height=w,h end
        function obj:SetWidth(w) self.width=w end
        function obj:SetHeight(h) self.height=h end
        function obj:SetPoint(...) self.point={...} end
        function obj:ClearAllPoints() self.point=nil end
        function obj:SetAllPoints(target) self.target=target end
        function obj:SetText(value) self.text=value end
        function obj:SetJustifyH() end
        function obj:SetJustifyV() end
        function obj:SetTexture(value) self.texture=value; return true end
        function obj:SetAtlas(value, useAtlasSize)
            self.atlas=value; self.useAtlasSize=useAtlasSize
            if useAtlasSize then
                local info=C_Texture.GetAtlasInfo(value)
                self:SetSize(info.width,info.height)
            end
        end
        function obj:SetAlpha(value) self.alpha=value end
        function obj:SetColorTexture(...) self.color={...} end
        function obj:SetTexCoord(...) self.coords={...} end
        function obj:AddMaskTexture(mask) self.mask=mask end
        function obj:Hide() self.hidden=true end
        function obj:Show() self.hidden=false end
        return obj
    end
    local function frame(kind, name, parent, template)
        local obj = region()
        obj.kind,obj.name,obj.parent,obj.template=kind,name,parent,template
        obj.scripts,obj.events,obj.textures={}, {}, {}
        function obj:SetFrameStrata(value) self.strata=value end
        function obj:SetFrameLevel(value) self.level=value end
        function obj:GetFrameLevel() return self.level or 0 end
        function obj:SetClampedToScreen() end
        function obj:EnableMouse(value) self.mouse=value end
        function obj:EnableMouseWheel(value) self.wheel=value end
        function obj:SetPropagateMouseClicks(value) self.propagateClicks=value end
        function obj:SetPropagateMouseMotion(value) self.propagateMotion=value end
        function obj:SetBackdrop(data) self.backdrop=data end
        function obj:SetBackdropColor() end
        function obj:SetBackdropBorderColor(...) self.border={...} end
        function obj:SetScale(value) self.scale=value end
        function obj:GetWidth() return self.width end
        function obj:GetHeight() return self.height end
        function obj:RegisterEvent(event) self.events[event]=true end
        function obj:SetScript(event,callback) self.scripts[event]=callback end
        function obj:GetName() return self.name end
        function obj:SetNormalFontObject(value) self.normalFont=value end
        function obj:SetHighlightFontObject(value) self.highlightFont=value end
        function obj:Enable() self.disabled=false end
        function obj:Disable() self.disabled=true end
        function obj:Show() self.shown=true end
        function obj:Hide()
            local wasShown=self.shown
            self.shown=false
            if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
        end
        function obj:GetFontString()
            if not self.label then self.label=region() end
            return self.label
        end
        function obj:CreateTexture()
            local texture=region(); self.textures[#self.textures+1]=texture; return texture
        end
        function obj:CreateMaskTexture() return region() end
        function obj:CreateFontString() return region() end
        frames[#frames+1]=obj
        if name then _G[name]=obj end
        return obj
    end
    UIParent=frame("Frame", "UIParent"); UIParent:SetSize(1280,720)
    CreateFrame=frame
    InCombatLockdown=function() return combat end
    GetLocale=function() return locale or "enUS" end
    print=function() end
    C_CVar={
        GetCVar=function(name) return values[name] end,
        GetCVarInfo=function(name) return values[name], "1", name=="showInGameNavigation", name~="showInGameNavigation" end,
        SetCVar=function(name,value)
            if failed[name] then error("simulated write failure") end
            assert(values[name]~=nil)
            values[name]=value; writes[#writes+1]={name,value}
            for _, f in ipairs(frames) do
                if f.events.CVAR_UPDATE then f.scripts.OnEvent(f,"CVAR_UPDATE",name) end
            end
        end,
    }
    assert(loadfile("NoQuestHintsForever/Localization.lua"))()
    assert(loadfile("NoQuestHintsForever/NoQuestHintsForever.lua"))()
    local api=NoQuestHintsForeverAPI
    local opened=0
    api.OpenOptions=function() opened=opened+1; return true end
    assert(loadfile("NoQuestHintsForever/Onboarding.lua"))()
    NoQuestHintsForeverChar, NoQuestHintsForeverAccount=char,account
    local function event(event, detail, withoutFlush)
        -- Call only registered handlers, as the client does.
        local current={}; for i,f in ipairs(frames) do current[i]=f end
        for _,f in ipairs(current) do
            if f.events[event] then f.scripts.OnEvent(f,event,detail) end
        end
        if not withoutFlush then flush() end
    end
    event("ADDON_LOADED","NoQuestHintsForever"); event("PLAYER_LOGIN")
    if not pauseBeforeWorld then
        event("PLAYER_ENTERING_WORLD")
        event("LOADING_SCREEN_DISABLED")
    end
    local function findButton(label)
        for _,f in ipairs(frames) do if f.kind=="Button" and f.text==label then return f end end
        error("button not found: "..label)
    end
    local function click(button)
        if not button.disabled then button.scripts.OnClick(button) end
    end
    local function cards()
        local result={}
        for _,f in ipairs(frames) do
            if f.parent==NoQuestHintsForeverWelcome and f.width==260 and f.height==530 then result[#result+1]=f end
        end
        return result
    end
    return { api=api,values=values,writes=writes,failed=failed,event=event,cards=cards,click=click,button=findButton,
        opened=function() return opened end, setCombat=function(value) combat=value end, flush=flush }
end

local char, account={},{}
local s=session(char,account)
assert(s.api.IsOnboardingPending() and char.onboardingComplete==false)
assert(#s.writes==0 and char.enabled==nil, "first run changed settings without consent")
local welcome=NoQuestHintsForeverWelcome
local shield=NoQuestHintsForeverWelcomeBlocker
assert(shield.shown and shield.target==UIParent and shield.mouse and shield.wheel,
    "modal shield must cover the full viewport, not just the scaled panel")
assert(welcome.parent==shield and welcome.level>shield:GetFrameLevel())
assert(shield.strata=="FULLSCREEN_DIALOG" and not shield.propagateClicks and not shield.propagateMotion)
assert(not GameTooltip.shown, "an already visible background tooltip must close on modal open")
GameTooltip.shown=true; shield.scripts.OnEnter(shield)
assert(not GameTooltip.shown)
local mainLabel=welcome.Apply:GetFontString()
assert(mainLabel.point[1]=="CENTER" and mainLabel.point[2]==welcome.Apply,
    "main label must be centered in the button")
assert(welcome.Apply.template=="SharedGoldRedButtonExtraLargeTemplate")
for _,label in ipairs({NoQuestHintsForeverLocale.WELCOME_LATER,NoQuestHintsForeverLocale.WELCOME_SETTINGS}) do
    assert(s.button(label).template=="SharedButtonSmallTemplate", "secondary actions need native button states")
end
assert(welcome.shown and #s.cards()==3 and welcome.scale<1, "welcome must fit the viewport")
assert(welcome.Apply.disabled, "confirm must wait for a selection")
local instruction=welcome.Prompt.text
assert(instruction==NoQuestHintsForeverLocale.WELCOME_SELECT)
s.click(s.cards()[2])
assert(welcome.Prompt.text==instruction, "selection replaced the static instruction with a status")
assert(s.cards()[2].Choice.text==NoQuestHintsForeverLocale.WELCOME_SELECTED)
assert(#s.writes==0 and not welcome.Apply.disabled, "selection applied before confirmation")
local art=s.cards()[2].textures
assert(art[1].atlas=="Mode-Selection-Card-Regular" and art[1].useAtlasSize
    and art[1].width==300 and art[1].height==600,
    "native card art must retain authored dimensions")
assert(not s.cards()[2].backdrop, "native card must not also draw a backdrop border")
assert(art[3].atlas=="Mode-Selection-Ring" and art[3].useAtlasSize,
    "portrait must use the native beveled ring")
assert(art[2].texture=="Interface\\Icons\\icon_treasuremap" and art[2].mask,
    "immersion icon must be the chosen map, with a circular mask")
s.click(welcome.Apply)
assert(not welcome.shown and not shield.shown and char.onboardingComplete==true, "confirmation must release the input shield")
assert(char.enabled and char.hideTracker and char.hideQuestTooltips and char.hideQuestNPCNames
    and char.hideQuestProgressMessages and char.hideSellPrices==false, "quest preset must leave prices visible")
assert(s.values.questPOI=="0" and s.values[npc]=="0")
assert(s.api.ApplyPreset("full") and char.hideSellPrices==true)
local count=#s.writes
assert(not s.api.ApplyPreset("typo") and #s.writes==count)

-- Retired commands must not mutate anything.
SlashCmdList.NOQUESTHINTSFOREVER("off"); SlashCmdList.NOQUESTHINTSFOREVER("on")
assert(char.enabled==true and #s.writes==count)

-- Clean shutdown restores CVars while retaining the chosen profile. Synchronous
-- CVAR_UPDATE during restoration must not immediately hide things again.
s.event("PLAYER_LOGOUT")
for _,name in ipairs(mapNames) do assert(s.values[name]=="1", "logout failed to restore "..name) end
assert(s.values[npc]=="1" and char.enabled and char.hideSellPrices)
assert(next(char.original)==nil and next(account.original)==nil and account.npcNameOriginal==nil)
s.event("PLAYER_ENTERING_WORLD")
assert(s.values.questPOI=="1", "shutdown was re-enforced by another event")
s=session(char,account,s.values)
assert(not NoQuestHintsForeverWelcome and s.values.questPOI=="0" and char.hideSellPrices,
    "reload must preserve and reapply preferences without repeating onboarding")
char.revealedQuests={[42]=true}
SlashCmdList.NOQUESTHINTSFOREVER("restore")
assert(not char.enabled and not char.hideTracker and not char.hideQuestTooltips and not char.hideQuestNPCNames
    and not char.hideSellPrices and not char.hideQuestProgressMessages)
assert(s.values.questPOI=="1" and s.values[npc]=="1" and char.revealedQuests[42])
assert(s.api.RestoreGameSettings(), "restore must be idempotent")

-- A failed restore keeps original values for retry, and never invents defaults.
s.values.questPOI="0"; s.values[npc]="0" -- user's actual pre-addon choices
s.api.ApplyPreset("full")
s.failed.questPOILocalStory=true
assert(not s.api.RestoreGameSettings() and char.original.questPOILocalStory=="1")
assert(s.values.questPOI=="0" and s.values[npc]=="0", "restore overwrote personal pre-addon choices")
s.failed.questPOILocalStory=nil
assert(s.api.RestoreGameSettings() and next(char.original)==nil)

-- Closing or customizing is not consent. Persist false so reload does not
-- mistake the bookkeeping keys of a pending first run for a legacy install.
local pending={}
s=session(pending,{})
s.click(s.button(NoQuestHintsForeverLocale.WELCOME_LATER))
assert(s.api.IsOnboardingPending() and #s.writes==0 and not NoQuestHintsForeverWelcomeBlocker.shown)
s=session(pending,{})
assert(NoQuestHintsForeverWelcome.shown and s.api.IsOnboardingPending())
s.click(s.button(NoQuestHintsForeverLocale.WELCOME_SETTINGS))
assert(s.opened()==1 and not NoQuestHintsForeverWelcome.shown and not NoQuestHintsForeverWelcomeBlocker.shown and s.api.IsOnboardingPending())
s.api.CompleteOnboarding() -- the native settings setter does this on first edit
assert(not s.api.IsOnboardingPending())

for _,existing in ipairs({{enabled=false},{enabled=true},{hideSellPrices=true},{original={}}}) do
    s=session(existing,{})
    assert(not s.api.IsOnboardingPending() and not NoQuestHintsForeverWelcome,
        "upgrade must preserve choices and never show first-run onboarding")
end

-- Defer opening in combat; Esc/close remains session-only dismissal.
s=session({}, {}, nil, true, "ruRU")
assert(not NoQuestHintsForeverWelcome)
s.setCombat(false); s.event("PLAYER_REGEN_ENABLED")
assert(NoQuestHintsForeverWelcome.shown)
s.click(s.cards()[1]); s.click(NoQuestHintsForeverWelcome.Apply)
assert(#s.writes==0 and not s.api.IsOnboardingPending(), "Blizzard first-run choice must write no CVars")
s.api.ShowWelcome(); assert(NoQuestHintsForeverWelcome.shown)
s.setCombat(true); s.event("PLAYER_REGEN_DISABLED")
assert(not NoQuestHintsForeverWelcome.shown and not NoQuestHintsForeverWelcomeBlocker.shown)

-- A write failure on logout must keep recovery data across sessions.
local interrupted, backups={},{}
s=session(interrupted,backups)
s.api.ApplyPreset("full")
s.failed.questPOI=true; s.failed[npc]=true
s.event("PLAYER_LOGOUT")
assert(interrupted.original.questPOI=="1" and backups.npcNameOriginal=="1")
s=session(interrupted,backups,s.values)
assert(s.api.RestoreGameSettings() and s.values.questPOI=="1" and s.values[npc]=="1")

-- Esc/close and explicit restore must also release the full-screen shield.
s=session({}, {})
NoQuestHintsForeverWelcome:Hide() -- UISpecialFrames/Esc uses the same Hide path
assert(not NoQuestHintsForeverWelcomeBlocker.shown)
s.api.ShowWelcome()
assert(NoQuestHintsForeverWelcomeBlocker.shown)
s.api.RestoreGameSettings()
assert(not NoQuestHintsForeverWelcome.shown and not NoQuestHintsForeverWelcomeBlocker.shown)

-- Older clients keep one usable fallback frame when realm-rule atlases are
-- unavailable. The first-run decision and restore behavior stay the same.
s=session({}, {}, nil, false, "enUS", true)
assert(s.cards()[1].FallbackBorder and s.cards()[1].backdrop)
s.click(s.cards()[1]); s.click(NoQuestHintsForeverWelcome.Apply)
assert(#s.writes==0 and not s.api.IsOnboardingPending())

io.write("PASS: consent-only presets, migration, grouped playstyles, retired commands, restore retry, logout/reload and native welcome art\n")

-- The welcome command reopens the chooser without resetting saved preferences.
local welcomeChar = { onboardingComplete=true, hideQuestLevels=true, hideAuctionSellPrices=true }
s=session(welcomeChar,{})
assert(not NoQuestHintsForeverWelcome)
SlashCmdList.NOQUESTHINTSFOREVER("welcome")
assert(NoQuestHintsForeverWelcome.shown and NoQuestHintsForeverWelcomeBlocker.shown)
assert(welcomeChar.onboardingComplete and welcomeChar.hideQuestLevels and welcomeChar.hideAuctionSellPrices)
s.api.HideWelcome()
s.setCombat(true)
SlashCmdList.NOQUESTHINTSFOREVER("welcome")
assert(not NoQuestHintsForeverWelcome.shown)
s.setCombat(false); s.event("PLAYER_REGEN_ENABLED")
assert(NoQuestHintsForeverWelcome.shown and welcomeChar.hideQuestLevels)

-- Exact owner request: explicitly reset a configured character, save through
-- normal logout/reload, and reopen automatically without losing any preferences.
local resetProfile={onboardingComplete=true,hideQuestLevels=true,hideAuctionSellPrices=true}
local resetAccount={}
s=session(resetProfile,resetAccount)
assert(not NoQuestHintsForeverWelcome and not s.api.IsOnboardingPending())
resetProfile.onboardingComplete=false
s.event("PLAYER_LOGOUT")
assert(resetProfile.onboardingComplete==false, "logout overwrote the explicit reset")
s=session(resetProfile,resetAccount,s.values)
assert(s.api.IsOnboardingPending() and NoQuestHintsForeverWelcome.shown,
    "explicit false flag did not survive saved-variable initialization")
assert(resetProfile.hideQuestLevels and resetProfile.hideAuctionSellPrices,
    "onboarding reset changed the custom profile")

-- Regression: pending remains true after full login, but early PLAYER_LOGIN
-- presentation can be lost during loading. Wait for loading completion and a
-- deferred callback; ordinary world transitions must not reopen a dismissed UI.
local lateProfile={onboardingComplete=false,hideQuestLevels=true}
s=session(lateProfile,{},nil,false,"enUS",false,true)
assert(s.api.IsOnboardingPending() and not NoQuestHintsForeverWelcome,
    "first-run modal was created during PLAYER_LOGIN before loading completed")
s.event("PLAYER_ENTERING_WORLD")
assert(not NoQuestHintsForeverWelcome, "modal opened before LOADING_SCREEN_DISABLED")
s.event("LOADING_SCREEN_DISABLED",nil,true)
assert(not NoQuestHintsForeverWelcome, "modal opened inside loading-screen event")
s.flush()
assert(NoQuestHintsForeverWelcome.shown and NoQuestHintsForeverWelcomeBlocker.shown)
assert(lateProfile.hideQuestLevels and lateProfile.onboardingComplete==false)
s.click(s.button(NoQuestHintsForeverLocale.WELCOME_LATER))
s.event("LOADING_SCREEN_ENABLED");s.event("PLAYER_ENTERING_WORLD");s.event("LOADING_SCREEN_DISABLED")
assert(not NoQuestHintsForeverWelcome.shown, "zoning repeated a dismissed first-run modal")
-- If another loading screen starts before the queued open, defer until it ends.
s=session({onboardingComplete=false},{},nil,false,"enUS",false,true)
s.event("LOADING_SCREEN_DISABLED",nil,true)
s.event("LOADING_SCREEN_ENABLED")
assert(not NoQuestHintsForeverWelcome, "queued popup escaped a new loading screen")
s.event("LOADING_SCREEN_DISABLED")
assert(NoQuestHintsForeverWelcome.shown)
