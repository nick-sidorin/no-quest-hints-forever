-- View-only quest title filtering. Forever's Camelot prefix ignores the native
-- showQuestLevel CVar, so changing that CVar alone cannot remove [level].
-- Never replace return-value functions, alter quest data or hook all FontStrings.
local api = NoQuestHintsForeverAPI
if not api then return end
local records = setmetatable({}, { __mode = "k" })
local hooked, queued = {}, false

local function inCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return value end
end

local function questID(owner)
    return owner and (owner.questID or owner.id)
end

local function metadata(owner)
    local id = questID(owner)
    if type(id) ~= "number" or id <= 0 then return end
    local info = type(owner.info) == "table" and owner.info or nil
    if info and info.isHeader then return end
    local log = C_QuestLog or {}
    local title = info and info.title or call(log.GetTitleForQuestID, id)
    local level = info and info.difficultyLevel or call(log.GetQuestDifficultyLevel, id)
    if type(title) == "string" and type(level) == "number" then return id, title, level end
end

local function removeLevel(text, title, level)
    local titleStart = text:find(title, 1, true)
    if not titleStart then return text end
    -- Only inspect decoration BEFORE the real title. Preserve group-member
    -- counts and [numbers] which belong to the actual quest name itself.
    local prefix = text:sub(1, titleStart - 1)
    local pattern = "%[" .. tostring(math.floor(level)) .. "%+?%]%s*"
    local start, finish, from = nil, nil, 1
    while true do
        local a, b = prefix:find(pattern, from)
        if not a then break end
        start, finish, from = a, b, b + 1
    end
    if start then prefix = prefix:sub(1, start - 1) .. prefix:sub(finish + 1) end
    return prefix .. text:sub(titleStart)
end

local function color(font)
    if type(font.GetTextColor) ~= "function" then return end
    local ok, r, g, b, a = pcall(font.GetTextColor, font)
    if ok then return {r,g,b,a or 1} end
end

local function sameColor(a, b)
    if not a or not b then return false end
    for i=1,4 do if a[i] ~= b[i] then return false end end
    return true
end

local function restore()
    for font, record in pairs(records) do
        if questID(record.owner) ~= record.id then
            records[font] = nil -- pooled region belongs to a different quest now
        else
            local done = true
            if call(font.GetText, font) == record.lastText and type(font.SetText) == "function" then
                done = pcall(font.SetText, font, record.originalText)
            end
            if record.originalColor and sameColor(color(font), record.lastColor)
                and type(font.SetTextColor) == "function" then
                local ok = pcall(font.SetTextColor, font, unpack(record.originalColor))
                done = done and ok
            end
            if done then records[font] = nil end
        end
    end
end

local function apply(font, owner, hideLevels, hideDifficulty)
    if not font or type(font.SetText) ~= "function" then return end
    local id, title, level = metadata(owner)
    if not id then return end
    local current = call(font.GetText, font)
    if type(current) ~= "string" then return end
    local currentColor = color(font)
    local record = records[font]
    if not record or record.id ~= id or record.lastText ~= current then
        local originalColor = currentColor
        if record and record.id == id and sameColor(currentColor, record.lastColor) then
            originalColor = record.originalColor
        end
        record = { owner=owner, id=id, originalText=current, originalColor=originalColor }
        records[font] = record
    elseif currentColor and not sameColor(currentColor, record.lastColor) then
        -- A fresh native hover/layout may have set a new difficulty color.
        record.originalColor = currentColor
    end
    local desired = record.originalText
    if hideLevels then desired = removeLevel(desired, title, level) end
    if hideDifficulty then
        -- The tracker may wrap its whole title with a native difficulty color.
        -- Preserve internal link/icon markup and unrelated colored fragments.
        desired = desired:match("^|c%x%x%x%x%x%x%x%x(.-)|r$") or desired
    end
    if desired ~= current then pcall(font.SetText, font, desired) end
    if hideDifficulty and type(font.SetTextColor) == "function" then
        local normal = NORMAL_FONT_COLOR or {r=1,g=0.82,b=0}
        pcall(font.SetTextColor, font, normal.r, normal.g, normal.b, currentColor and currentColor[4] or 1)
    elseif record.originalColor and type(font.SetTextColor) == "function" then
        pcall(font.SetTextColor, font, unpack(record.originalColor))
    end
    record.lastText, record.lastColor = call(font.GetText, font), color(font)
end

local function refresh()
    if inCombat() then return end
    local levels = api.IsQuestLevelsHidden() == true
    local difficulty = api.IsQuestDifficultyHidden() == true
    if not levels and not difficulty then restore(); return end
    if QuestScrollFrame and QuestScrollFrame.titleFramePool
        and type(QuestScrollFrame.titleFramePool.EnumerateActive) == "function" then
        for button in QuestScrollFrame.titleFramePool:EnumerateActive() do
            if not (button.info and button.info.isHeader) then
                apply(button.Text, button, levels, difficulty)
                apply(button.TagText, button, false, difficulty)
            end
        end
    end
    if QuestObjectiveTracker and type(QuestObjectiveTracker.usedBlocks) == "table" then
        for _, blocks in pairs(QuestObjectiveTracker.usedBlocks) do
            if type(blocks) == "table" then
                for _, block in pairs(blocks) do
                    if type(block) == "table" or type(block) == "userdata" then
                        apply(block.HeaderText, block, levels, difficulty)
                    end
                end
            end
        end
    end
end

local function queue()
    if queued or (not api.IsQuestLevelsHidden() and not api.IsQuestDifficultyHidden() and not next(records)) then return end
    if C_Timer and type(C_Timer.After) == "function" then
        queued = true
        C_Timer.After(0, function() queued = false; refresh() end)
    end
end

local function install()
    if type(hooksecurefunc) ~= "function" then return end
    for _, name in ipairs({"QuestLogQuests_Update", "QuestMapLogTitleButton_OnEnter", "QuestMapLogTitleButton_OnLeave"}) do
        if not hooked[name] and type(_G[name]) == "function" then hooked[name] = pcall(hooksecurefunc, name, queue) end
    end
    local mixin = ObjectiveTrackerBlockMixin
    if type(mixin) == "table" then
        for _, name in ipairs({"SetHeader", "UpdateHighlight"}) do
            local key = "block:" .. name
            if not hooked[key] and type(mixin[name]) == "function" then
                hooked[key] = pcall(hooksecurefunc, mixin, name, function(block)
                    if block.parentModule == QuestObjectiveTracker then queue() end
                end)
            end
        end
    end
end

function api.RefreshQuestPresentation()
    if api.IsQuestLevelsHidden() or api.IsQuestDifficultyHidden() or next(records) then install(); queue() end
end

function api.RestoreQuestPresentation()
    if api.IsQuestLevelsHidden() or api.IsQuestDifficultyHidden() then return false end
    if not inCombat() then restore() end
    return next(records) == nil
end

local events = CreateFrame("Frame")
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED", "CVAR_UPDATE"}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function() api.RefreshQuestPresentation() end)
