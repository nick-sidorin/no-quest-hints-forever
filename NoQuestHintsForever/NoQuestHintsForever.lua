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

NoQuestHintsForeverChar = NoQuestHintsForeverChar or {}
NoQuestHintsForeverAccount = NoQuestHintsForeverAccount or {}

local character = NoQuestHintsForeverChar
local account = NoQuestHintsForeverAccount
character.original = character.original or {}
account.original = account.original or {}

local applying = false

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
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("CVAR_UPDATE")
frame:SetScript("OnEvent", function(_, event, changed)
    if event == "PLAYER_LOGIN" then
        if character.enabled == true then
            enforce()
        else
            -- Retry any failed restore and undo account-scoped changes
            -- left by another ON character. Otherwise do not touch CVars.
            restore(character.original)
            restore(account.original)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        enforce()
    elseif event == "CVAR_UPDATE" and character.enabled == true and type(changed) == "string" then
        for _, name in ipairs(cvars) do
            if changed:lower() == name:lower() then
                enforce()
                break
            end
        end
    end
end)
