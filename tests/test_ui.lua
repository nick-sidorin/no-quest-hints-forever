-- Tests for the new UI, option independence and objective tracker lifecycle.
-- Run from repo root: lua5.1 tests/test_ui.lua
local addon = "NoQuestHintsForever/NoQuestHintsForever.lua"
local ui = "NoQuestHintsForever/Options.lua"
local cvarNames = {
    "questPOI", "showQuestObjectivesOnMap", "questPOILocalStory",
    "minimapShowQuestBlobs", "showInGameNavigation",
}

local function session(char, account, withSettings, withTracker)
    NoQuestHintsForeverChar = nil
    NoQuestHintsForeverAccount = nil
    NoQuestHintsForeverAPI = nil
    NoQuestHintsForeverOptionsFrame = nil
    SlashCmdList = {}
    UISpecialFrames = {}
    local current = {}
    for _, name in ipairs(cvarNames) do current[name] = "1" end
    current.UnitNameFriendlySpecialNPCName = "1"
    current.UnitNameHostleNPC = "0"
    current.UnitNameNPC = "0"
    local deferred, checks, panels, combat = {}, {}, {}, false
    local openedCategories, proxySettings = {}, {}
    local eventFrame

    local function frame(kind, name, parent, template)
        local obj = {
            kind = kind, name = name, parent = parent, template = template,
            shown = false, alpha = 1, mouse = true, checked = false, scripts = {},
            events = {},
        }
        function obj:SetSize() end
        function obj:SetPoint() end
        function obj:SetFrameStrata() end
        function obj:SetClampedToScreen() end
        function obj:SetMovable() end
        function obj:EnableMouse(value) self.mouse = value end
        function obj:IsMouseEnabled() return self.mouse end
        function obj:RegisterForDrag() end
        function obj:StartMoving() end
        function obj:StopMovingOrSizing() end
        function obj:SetScript(which, callback) self.scripts[which] = callback end
        function obj:RegisterEvent(e) self.events[e] = true end
        function obj:UnregisterEvent(e) self.events[e] = nil end
        function obj:SetChecked(value) self.checked = value end
        function obj:GetChecked() return self.checked end
        function obj:SetText(text) self.text = text end
        function obj:GetName() return self.name end
        function obj:SetAlpha(value) self.alpha = value end
        function obj:GetAlpha() return self.alpha end
        function obj:IsShown() return self.shown end
        function obj:Show()
            self.shown = true
            if self.scripts.OnShow then self.scripts.OnShow(self) end
        end
        function obj:Hide() self.shown = false end
        function obj:CreateFontString()
            local label = { text = "" }
            function label:SetPoint() end
            function label:SetText(text) self.text = text end
            return label
        end
        if name then _G[name] = obj end
        if template == "BasicFrameTemplateWithInset" then
            obj.TitleText = { SetText = function(self, text) self.text = text end }
        end
        if kind == "CheckButton" then checks[#checks + 1] = obj end
        if not eventFrame and kind == "Frame" and not parent and not name then eventFrame = obj end
        return obj
    end

    UIParent = frame("Frame", "UIParent")
    -- Core's event frame has no parent, whereas UI frames do.
    CreateFrame = frame
    Settings = nil
    if withSettings then
        Settings = {
            VarType = { Boolean = "boolean" },
            RegisterVerticalLayoutCategory = function(name)
                local cat = { name = name, id = 42 }
                function cat:GetID() return self.id end
                panels[#panels + 1] = cat
                return cat
            end,
            RegisterProxySetting = function(cat, variable, varType, name, defaultValue, getter, setter)
                assert(cat == panels[1] and varType == "boolean" and defaultValue == false)
                assert(type(getter) == "function" and type(setter) == "function")
                local setting = { variable = variable, name = name }
                function setting:GetValue() return getter() end
                function setting:SetValue(value) setter(value) end
                proxySettings[#proxySettings + 1] = setting
                return setting
            end,
            CreateCheckbox = function(cat, setting, tooltip)
                assert(cat == panels[1] and type(tooltip) == "string" and #tooltip > 0,
                    "each native checkbox must have a tooltip")
                local check = { setting = setting, tooltip = tooltip, scripts = {} }
                function check:SetChecked(value) self.pending = value end
                function check:GetChecked()
                    if self.pending ~= nil then return self.pending end
                    return self.setting:GetValue()
                end
                check.scripts.OnClick = function(self)
                    local value = self:GetChecked()
                    self.pending = nil
                    self.setting:SetValue(value)
                end
                checks[#checks + 1] = check
                return check
            end,
            RegisterAddOnCategory = function(cat) cat.registered = true end,
            OpenToCategory = function(id)
                assert(id == panels[1].id and panels[1].registered, "invalid native settings category")
                openedCategories[#openedCategories + 1] = id
            end,
        }
    end
    C_CVar = {
        GetCVar = function(name) return current[name] end,
        SetCVar = function(name, value)
            if current[name] == nil then error("unknown CVar") end
            current[name] = value
        end,
        GetCVarInfo = function(name)
            return current[name], "1", name == "showInGameNavigation", name ~= "showInGameNavigation"
        end,
    }
    C_Timer = {
        After = function(delay, fn)
            assert(delay == 0)
            deferred[#deferred + 1] = fn
        end
    }
    InCombatLockdown = function() return combat end
    hooksecurefunc = function(object, method, fn)
        local original = object[method]
        assert(type(original) == "function", "cannot hook " .. method)
        object[method] = function(self, ...)
            local value = original(self, ...)
            fn(self, ...)
            return value
        end
    end
    print = function() end

    assert(loadfile(addon))()
    assert(loadfile(ui))()
    NoQuestHintsForeverChar = char
    NoQuestHintsForeverAccount = account
    assert(eventFrame and eventFrame.events.ADDON_LOADED, "core event frame missing")
    local function event(e, value)
        assert(eventFrame.events[e], "missing event " .. e)
        eventFrame.scripts.OnEvent(eventFrame, e, value)
    end
    local function flush()
        local count = 0
        while #deferred > 0 do
            count = count + 1
            assert(count < 30, "infinite deferred hook loop")
            local fn = table.remove(deferred, 1)
            fn()
        end
    end
    local tracker
    if withTracker then
        tracker = frame("Frame", "ObjectiveTrackerFrame", UIParent)
        tracker.shown = true
        tracker.alpha = 0.8
        tracker.mouse = true
    else
        ObjectiveTrackerFrame = nil
    end
    event("ADDON_LOADED", "NoQuestHintsForever")
    event("PLAYER_LOGIN")
    local function command(message) SlashCmdList.NOQUESTHINTSFOREVER(message) end
    return {
        command = command, event = event, flush = flush, current = current,
        tracker = tracker, checks = checks, panels = panels,
        opened = openedCategories, proxySettings = proxySettings,
        setCombat = function(value) combat = value end,
        newFrame = frame
    }
end

local original = { enabled = true }
local shared = {}
local s = session(original, shared, true, true)
assert(original.enabled == true and original.hideTracker == nil and original.hideQuestTooltips == nil
    and original.hideSellPrices == nil and original.hideQuestProgressMessages == nil)
assert(s.current.questPOI == "0", "existing map enabled state lost")
assert(s.tracker:GetAlpha() == 0.8, "tracker should be untouched when option is OFF")
assert(#s.panels == 1 and s.panels[1].registered, "Blizzard settings category not registered")

-- /nqh opens the real Blizzard settings category, not a standalone frame.
s.command("")
assert(#s.opened == 1 and s.opened[1] == s.panels[1]:GetID(),
    "/nqh did not navigate to native Settings category")
assert(NoQuestHintsForeverOptionsFrame == nil,
    "legacy floating settings window must never be created")
assert(#s.proxySettings == 6, "each option needs a native proxy setting")
for _, control in ipairs(s.checks) do
    assert(type(control.tooltip) == "string" and #control.tooltip > 0,
        "native checkbox description must be shown in tooltip")
end
assert(#s.checks == 6, "expected six independent quest and immersion checkboxes")
assert(s.checks[1]:GetChecked() == true and s.checks[2]:GetChecked() == false
    and s.checks[3]:GetChecked() == false and s.checks[4]:GetChecked() == false
    and s.checks[5]:GetChecked() == false and s.checks[6]:GetChecked() == false,
    "checkbox defaults do not match existing settings")
s.checks[2]:SetChecked(true)
s.checks[2].scripts.OnClick(s.checks[2])
assert(original.hideTracker == true, "tracker setting not stored per character")
assert(s.tracker:GetAlpha() == 0 and not s.tracker:IsMouseEnabled(), "tracker not hidden")
s.checks[3]:SetChecked(true)
s.checks[3].scripts.OnClick(s.checks[3])
assert(original.hideQuestTooltips == true,
    "new tooltip setting not persisted per character")
s.checks[4]:SetChecked(true)
s.checks[4].scripts.OnClick(s.checks[4])
assert(original.hideQuestNPCNames == true, "NPC name override not saved per character")
assert(s.current.UnitNameFriendlySpecialNPCName == "0", "quest/special names CVar not suppressed")
assert(shared.npcNameOriginal == "1", "account baseline not preserved")
assert(s.current.UnitNameHostleNPC == "0" and s.current.UnitNameNPC == "0",
    "NPC name override changed unrelated name categories")
s.checks[5]:SetChecked(true)
s.checks[5].scripts.OnClick(s.checks[5])
assert(original.hideSellPrices == true and NoQuestHintsForeverAPI.IsSellPriceHidden() == true,
    "sell price preference not enabled per character")
s.checks[6]:SetChecked(true)
s.checks[6].scripts.OnClick(s.checks[6])
assert(original.hideQuestProgressMessages == true
    and NoQuestHintsForeverAPI.IsQuestProgressHidden() == true,
    "quest progress messages preference not enabled independently")
assert(original.enabled == true and original.hideQuestNPCNames == true
    and original.hideQuestTooltips == true and original.hideTracker == true,
    "sell price option changed independent feature states")
assert(s.current.questPOI == "0" and original.enabled == true
    and original.hideTracker == true, "tooltip checkbox must be independent")

-- Blizzard tries to re-show and change opacity: secure hooks defer the fix.
s.tracker:SetAlpha(1)
assert(s.tracker:GetAlpha() == 1, "tracker update must not run inside secure hook")
s.flush()
assert(s.tracker:GetAlpha() == 0, "tracker alpha not re-enforced")
s.tracker:Show()
s.flush()
assert(s.tracker:GetAlpha() == 0, "tracker visibility not re-enforced")

-- The old slash commands control only map hints, not the tracker option.
s.command("off")
assert(original.enabled == false and original.hideTracker == true
    and original.hideQuestTooltips == true and original.hideQuestNPCNames == true
    and original.hideSellPrices == true and original.hideQuestProgressMessages == true,
    "slash off changed independent settings")
assert(s.current.UnitNameFriendlySpecialNPCName == "0",
    "map off must not restore independent NPC name setting")
assert(s.current.questPOI == "1", "map hints not restored")
assert(s.tracker:GetAlpha() == 0, "tracker should stay hidden")
s.command("on")
assert(original.enabled == true and original.hideTracker == true
    and original.hideQuestTooltips == true and original.hideQuestNPCNames == true
    and original.hideSellPrices == true and original.hideQuestProgressMessages == true,
    "slash on changed independent settings")

-- UI toggles remain independent in both directions.
s.checks[1]:SetChecked(false)
s.checks[1].scripts.OnClick(s.checks[1])
assert(original.enabled == false and original.hideTracker == true, "map checkbox modified tracker")
assert(s.current.questPOI == "1", "map checkbox did not restore CVars")
s.checks[2]:SetChecked(false)
s.checks[2].scripts.OnClick(s.checks[2])
assert(original.hideTracker == false, "tracker option not turned OFF")
assert(s.tracker:GetAlpha() == 0.8 and s.tracker:IsMouseEnabled(), "tracker state not restored")
s.checks[3]:SetChecked(false)
s.checks[3].scripts.OnClick(s.checks[3])
assert(original.hideQuestTooltips == false and original.hideTracker == false
    and original.enabled == false and original.hideQuestNPCNames == true,
    "tooltip option changed unrelated settings")
-- Blizzard resets our cvar while the override is enabled: keep it suppressed.
s.current.UnitNameFriendlySpecialNPCName = "1"
s.event("CVAR_UPDATE", "UnitNameFriendlySpecialNPCName")
assert(s.current.UnitNameFriendlySpecialNPCName == "0",
    "CVAR_UPDATE did not re-enforce the user-selected name override")
s.checks[4]:SetChecked(false)
s.checks[4].scripts.OnClick(s.checks[4])
assert(original.hideQuestNPCNames == false and shared.npcNameOriginal == nil
    and s.current.UnitNameFriendlySpecialNPCName == "1",
    "disabling NPC override must restore account baseline")
s.checks[4]:SetChecked(true)
s.checks[4].scripts.OnClick(s.checks[4])
s.checks[3]:SetChecked(true)
s.checks[3].scripts.OnClick(s.checks[3])
s.command("")
assert(#s.opened == 2, "/nqh should navigate to the category again")

-- Enter combat: cosmetic alpha still changes; mouse state is recovered after combat.
s.setCombat(true)
s.command("")
assert(#s.opened == 3, "native Settings should remain accessible")
s.checks[2]:SetChecked(true)
s.checks[2].scripts.OnClick(s.checks[2])
assert(s.tracker:GetAlpha() == 0 and s.tracker:IsMouseEnabled(), "combat tracker alpha should be hidden")
s.setCombat(false)
s.event("PLAYER_REGEN_ENABLED")
assert(not s.tracker:IsMouseEnabled(), "mouse input not updated after combat")
s.checks[2]:SetChecked(false)
s.checks[2].scripts.OnClick(s.checks[2])
assert(s.tracker:GetAlpha() == 0.8 and s.tracker:IsMouseEnabled())

-- The price option is independent, and toggling it is reversible.
s.checks[5]:SetChecked(false)
s.checks[5].scripts.OnClick(s.checks[5])
assert(original.hideSellPrices == false
    and NoQuestHintsForeverAPI.IsSellPriceHidden() == false,
    "turning off price concealment did not restore native behavior")
s.checks[5]:SetChecked(true)
s.checks[5].scripts.OnClick(s.checks[5])

s.checks[6]:SetChecked(false)
s.checks[6].scripts.OnClick(s.checks[6])
assert(original.hideQuestProgressMessages == false
    and not NoQuestHintsForeverAPI.IsQuestProgressHidden(),
    "popup suppression did not restore native behavior")
s.checks[6]:SetChecked(true)
s.checks[6].scripts.OnClick(s.checks[6])

-- Reload: stored tracker option should be reapplied, without changing map.
original.enabled = false
original.hideTracker = true
local reload = session(original, shared, true, true)
assert(reload.tracker:GetAlpha() == 0, "tracker hide did not persist through reload")
assert(reload.current.questPOI == "1", "map setting inherited tracker state")
reload.command("off")
assert(reload.tracker:GetAlpha() == 0, "slash off unexpectedly enabled tracker")
reload.command("")
assert(#reload.opened == 1, "/nqh must open native settings after reload")
assert(reload.checks[2]:GetChecked() == true and reload.checks[3]:GetChecked() == true
    and reload.checks[4]:GetChecked() == true and reload.checks[5]:GetChecked() == true
    and reload.checks[6]:GetChecked() == true,
    "UI did not reflect loaded tracker/tooltip settings")

-- Different character starts without any suppression.
local alt = session({}, shared, true, true)
assert(alt.tracker:GetAlpha() == 0.8 and alt.tracker:IsMouseEnabled(),
    "new alt inherited objective tracker suppression")
assert(alt.current.questPOI == "1", "new alt inherited map suppression")
assert(NoQuestHintsForeverAPI.IsTooltipHintsHidden() == false
    and NoQuestHintsForeverAPI.IsQuestNPCNamesHidden() == false
    and NoQuestHintsForeverAPI.IsSellPriceHidden() == false
    and NoQuestHintsForeverAPI.IsQuestProgressHidden() == false,
    "new alt inherited other character settings")
assert(alt.current.UnitNameFriendlySpecialNPCName == "1" and shared.npcNameOriginal == nil,
    "new alt should restore original account-wide NPC name CVar")

-- Missing Blizzard Settings API does not create a floating fallback or break commands.
local noSettings = session({}, {}, false, true)
noSettings.command("")
assert(#noSettings.opened == 0 and NoQuestHintsForeverOptionsFrame == nil,
    "missing native settings must not spawn a custom popup")
noSettings.command("on")
assert(noSettings.current.questPOI == "0", "missing Settings API broke core slash toggles")

-- Late creation of the objective tracker after our addon has loaded.
local lateChar = {hideTracker = true}
local late = session(lateChar, {}, false, false)
local lateFrame = late.newFrame("Frame", "ObjectiveTrackerFrame", UIParent)
lateFrame.alpha = 1
late.event("ADDON_LOADED", "Blizzard_ObjectiveTracker")
assert(lateFrame:GetAlpha() == 0, "late objective tracker not hidden")

io.write("PASS: native vertical Settings controls/tooltips, independent options, tracker hooks, reload and alts\n")
