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
    local deferred, checks, panels, combat = {}, {}, {}, false
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
        if not eventFrame and kind == "Frame" and not parent then eventFrame = obj end
        return obj
    end

    UIParent = frame("Frame", "UIParent")
    -- Core's event frame has no parent, whereas UI frames do.
    CreateFrame = frame
    Settings = nil
    if withSettings then
        Settings = {
            RegisterCanvasLayoutCategory = function(panel, name)
                local cat = { name = name, panel = panel }
                panels[#panels + 1] = cat
                return cat
            end,
            RegisterAddOnCategory = function(cat) cat.registered = true end,
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
        setCombat = function(value) combat = value end,
        newFrame = frame
    }
end

local original = { enabled = true }
local shared = {}
local s = session(original, shared, true, true)
assert(original.enabled == true and original.hideTracker == nil)
assert(s.current.questPOI == "0", "existing map enabled state lost")
assert(s.tracker:GetAlpha() == 0.8, "tracker should be untouched when option is OFF")
assert(#s.panels == 1 and s.panels[1].registered, "Blizzard settings category not registered")

-- /nqh opens the standalone window and keeps native-looking check buttons.
s.command("")
assert(NoQuestHintsForeverOptionsFrame:IsShown(), "/nqh did not open settings")
assert(#s.checks == 2, "expected exactly two checkboxes")
assert(s.checks[1]:GetChecked() == true and s.checks[2]:GetChecked() == false,
    "checkbox defaults do not match existing settings")
s.checks[2]:SetChecked(true)
s.checks[2].scripts.OnClick(s.checks[2])
assert(original.hideTracker == true, "tracker setting not stored per character")
assert(s.tracker:GetAlpha() == 0 and not s.tracker:IsMouseEnabled(), "tracker not hidden")

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
assert(original.enabled == false and original.hideTracker == true, "slash off changed tracker option")
assert(s.current.questPOI == "1", "map hints not restored")
assert(s.tracker:GetAlpha() == 0, "tracker should stay hidden")
s.command("on")
assert(original.enabled == true and original.hideTracker == true, "slash on did not restore map mode")

-- UI toggles remain independent in both directions.
s.checks[1]:SetChecked(false)
s.checks[1].scripts.OnClick(s.checks[1])
assert(original.enabled == false and original.hideTracker == true, "map checkbox modified tracker")
assert(s.current.questPOI == "1", "map checkbox did not restore CVars")
s.checks[2]:SetChecked(false)
s.checks[2].scripts.OnClick(s.checks[2])
assert(original.hideTracker == false, "tracker option not turned OFF")
assert(s.tracker:GetAlpha() == 0.8 and s.tracker:IsMouseEnabled(), "tracker state not restored")
s.command("")
assert(not NoQuestHintsForeverOptionsFrame:IsShown(), "/nqh should toggle the window")

-- Enter combat: cosmetic alpha still changes; mouse state is recovered after combat.
s.setCombat(true)
s.command("")
s.checks[2]:SetChecked(true)
s.checks[2].scripts.OnClick(s.checks[2])
assert(s.tracker:GetAlpha() == 0 and s.tracker:IsMouseEnabled(), "combat tracker alpha should be hidden")
s.setCombat(false)
s.event("PLAYER_REGEN_ENABLED")
assert(not s.tracker:IsMouseEnabled(), "mouse input not updated after combat")
s.checks[2]:SetChecked(false)
s.checks[2].scripts.OnClick(s.checks[2])
assert(s.tracker:GetAlpha() == 0.8 and s.tracker:IsMouseEnabled())

-- Reload: stored tracker option should be reapplied, without changing map.
original.enabled = false
original.hideTracker = true
local reload = session(original, shared, true, true)
assert(reload.tracker:GetAlpha() == 0, "tracker hide did not persist through reload")
assert(reload.current.questPOI == "1", "map setting inherited tracker state")
reload.command("off")
assert(reload.tracker:GetAlpha() == 0, "slash off unexpectedly enabled tracker")
reload.command("")
assert(reload.checks[2]:GetChecked() == true, "UI did not reflect loaded setting")

-- Different character starts without any suppression.
local alt = session({}, shared, true, true)
assert(alt.tracker:GetAlpha() == 0.8 and alt.tracker:IsMouseEnabled(),
    "new alt inherited objective tracker suppression")
assert(alt.current.questPOI == "1", "new alt inherited map suppression")

-- Missing Blizzard Settings API doesn't break /nqh.
local noSettings = session({}, {}, false, true)
noSettings.command("")
assert(NoQuestHintsForeverOptionsFrame:IsShown(), "standalone UI requires Settings API")

-- Late creation of the objective tracker after our addon has loaded.
local lateChar = {hideTracker = true}
local late = session(lateChar, {}, false, false)
local lateFrame = late.newFrame("Frame", "ObjectiveTrackerFrame", UIParent)
lateFrame.alpha = 1
late.event("ADDON_LOADED", "Blizzard_ObjectiveTracker")
assert(lateFrame:GetAlpha() == 0, "late objective tracker not hidden")

io.write("PASS: independent UI checkboxes, settings launcher, tracker hooks, combat, reload and alts\n")
