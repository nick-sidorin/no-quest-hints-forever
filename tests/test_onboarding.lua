-- First-run decisions, persistence, reversible presets and uninstall preparation.
local mapNames = { "questPOI", "showQuestObjectivesOnMap", "questPOILocalStory",
    "minimapShowQuestBlobs", "showInGameNavigation" }
local npc = "UnitNameFriendlySpecialNPCName"
local function session(char, account, suppliedValues, combat, locale, withoutAtlases)
    local values = suppliedValues or { [npc] = "1" }
    for _, name in ipairs(mapNames) do if values[name] == nil then values[name] = "1" end end
    local frames, writes, failed = {}, {}, {}
    NoQuestHintsForeverChar, NoQuestHintsForeverAccount, NoQuestHintsForeverAPI = nil, nil, nil
    NoQuestHintsForeverWelcome, ObjectiveTrackerFrame, Settings = nil, nil, nil
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
        function obj:SetFrameStrata() end
        function obj:SetClampedToScreen() end
        function obj:EnableMouse() end
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
        function obj:Hide() self.shown=false end
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
    local function event(event, detail)
        -- Call only registered handlers, as the client does.
        local current={}; for i,f in ipairs(frames) do current[i]=f end
        for _,f in ipairs(current) do
            if f.events[event] then f.scripts.OnEvent(f,event,detail) end
        end
    end
    event("ADDON_LOADED","NoQuestHintsForever"); event("PLAYER_LOGIN")
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
        opened=function() return opened end, setCombat=function(value) combat=value end }
end

local char, account={},{}
local s=session(char,account)
assert(s.api.IsOnboardingPending() and char.onboardingComplete==false)
assert(#s.writes==0 and char.enabled==nil, "first run changed settings without consent")
local welcome=NoQuestHintsForeverWelcome
assert(welcome.shown and #s.cards()==3 and welcome.scale<1, "welcome must fit the viewport")
assert(welcome.Apply.disabled, "confirm must wait for a selection")
s.click(s.cards()[2])
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
assert(not welcome.shown and char.onboardingComplete==true)
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
assert(s.api.IsOnboardingPending() and #s.writes==0)
s=session(pending,{})
assert(NoQuestHintsForeverWelcome.shown and s.api.IsOnboardingPending())
s.click(s.button(NoQuestHintsForeverLocale.WELCOME_SETTINGS))
assert(s.opened()==1 and not NoQuestHintsForeverWelcome.shown and s.api.IsOnboardingPending())
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
assert(not NoQuestHintsForeverWelcome.shown)

-- A write failure on logout must keep recovery data across sessions.
local interrupted, backups={},{}
s=session(interrupted,backups)
s.api.ApplyPreset("full")
s.failed.questPOI=true; s.failed[npc]=true
s.event("PLAYER_LOGOUT")
assert(interrupted.original.questPOI=="1" and backups.npcNameOriginal=="1")
s=session(interrupted,backups,s.values)
assert(s.api.RestoreGameSettings() and s.values.questPOI=="1" and s.values[npc]=="1")

-- Older clients keep one usable fallback frame when realm-rule atlases are
-- unavailable. The first-run decision and restore behavior stay the same.
s=session({}, {}, nil, false, "enUS", true)
assert(s.cards()[1].FallbackBorder and s.cards()[1].backdrop)
s.click(s.cards()[1]); s.click(NoQuestHintsForeverWelcome.Apply)
assert(#s.writes==0 and not s.api.IsOnboardingPending())

io.write("PASS: consent-only presets, migration, grouped playstyles, retired commands, restore retry, logout/reload and native welcome art\n")
