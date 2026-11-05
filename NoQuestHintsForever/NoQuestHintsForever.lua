-- No Quest Hints - Forever
-- Native quest hints are optional for each character. No map frames are replaced.

local cvars = {
    "questPOI",
    "showQuestObjectivesOnMap",
    "questPOILocalStory",
    "minimapShowQuestBlobs",
    "showInGameNavigation",
}

local function getCVar(name)
    local getter = C_CVar and C_CVar.GetCVar or GetCVar
    if not getter then return nil end
    local ok, value = pcall(getter, name)
    if ok then return value end
end

local function setCVar(name, value)
    local setter = C_CVar and C_CVar.SetCVar or SetCVar
    if not setter then return false end
    local ok = pcall(setter, name, value)
    return ok and getCVar(name) == value
end

-- The listed quest CVars are documented as character-scoped, while
-- showInGameNavigation is account-scoped. Prefer the running client metadata.
-- GetCVarInfo reports *server-synchronized* scopes, so an unmarked CVar
-- needs the documented fallback below.
local function isSharedCVar(name)
    if C_CVar and C_CVar.GetCVarInfo then
        local ok, _, _, isAccount, isCharacter = pcall(C_CVar.GetCVarInfo, name)
        if ok then
            if isAccount == true then return true end
            if isCharacter == true then return false end
        end
    end
    return name == "showInGameNavigation"
end

-- SavedVariables are loaded AFTER the addon Lua chunk, before ADDON_LOADED.
-- Do not capture a table here: WoW replaces the global during SV loading.
local character, account
local applying = false

local function initializeSavedVariables()
    if type(NoQuestHintsForeverChar) ~= "table" then
        NoQuestHintsForeverChar = {}
    end
    if type(NoQuestHintsForeverAccount) ~= "table" then
        NoQuestHintsForeverAccount = {}
    end
    character = NoQuestHintsForeverChar
    account = NoQuestHintsForeverAccount
    if type(character.original) ~= "table" then character.original = {} end
    if type(account.original) ~= "table" then account.original = {} end
end

local function enforce()
    if character.enabled ~= true or applying then return end
    applying = true

    for _, name in ipairs(cvars) do
        local current = getCVar(name)
        if current ~= nil then
            -- Keep the value from before *our* first change. Never overwrite
            -- the snapshot with zero on a later login or CVAR_UPDATE.
            local original = isSharedCVar(name) and account.original or character.original
            if original[name] == nil then original[name] = current end
            if current ~= "0" then setCVar(name, "0") end
        end
    end

    applying = false
end

local function restore(original)
    for name, value in pairs(original) do
        -- A failed restore should remain in the snapshot for the next login.
        local current = getCVar(name)
        if current == value or (current ~= nil and setCVar(name, value)) then
            original[name] = nil
        end
    end
end

local function printMessage(message)
    print("|cff80c0ffNo Quest Hints|r: " .. message)
end

SLASH_NOQUESTHINTSFOREVER1 = "/nqh"
SlashCmdList.NOQUESTHINTSFOREVER = function(message)
    if not character then
        printMessage("Still initializing. Please try again after login.")
        return
    end
    local command = (message or ""):match("^%s*(%S+)")
    command = command and command:lower() or "status"

    if command == "on" then
        character.enabled = true
        enforce()
        printMessage("ON for this character. Quest hints are suppressed where supported.")
    elseif command == "off" then
        character.enabled = false
        restore(character.original)
        restore(account.original)
        printMessage("OFF for this character. Blizzard controls quest hints now.")
    elseif command == "status" then
        printMessage(character.enabled == true and "ON for this character" or "OFF for this character")
        for _, name in ipairs(cvars) do
            local value = getCVar(name)
            printMessage(name .. " = " .. (value == nil and "unavailable" or tostring(value)))
        end
    else
        printMessage("Commands: /nqh on, /nqh off, /nqh status")
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("CVAR_UPDATE")
frame:SetScript("OnEvent", function(_, event, changed)
    if event == "ADDON_LOADED" then
        if changed ~= "NoQuestHintsForever" then return end
        initializeSavedVariables()
        frame:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        if not character then initializeSavedVariables() end
        if character.enabled == true then
            enforce()
        else
            -- Retry failed restores, including shared values changed on another
            -- character. Never continuously enforce while OFF.
            restore(character.original)
            restore(account.original)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        enforce()
    elseif event == "CVAR_UPDATE" and character and character.enabled == true and type(changed) == "string" then
        for _, name in ipairs(cvars) do
            if changed:lower() == name:lower() then
                enforce()
                break
            end
        end
    end
end)
