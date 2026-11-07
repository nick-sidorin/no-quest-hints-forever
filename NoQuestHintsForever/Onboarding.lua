-- Realm-rule-style choices using game art only. Glue screen templates are
-- deliberately not inherited: those templates are not loaded in the game UI.
local api = NoQuestHintsForeverAPI
if not api then return end
local L = NoQuestHintsForeverLocale
local window, selected, shownThisSession, requested
local cards = {}
local presets = {
    { id = "blizzard", title = "PRESET_BLIZZARD", description = "PRESET_BLIZZARD_DESC",
      icon = "Interface\\Icons\\INV_Misc_Map_01", fallback = 134269 },
    { id = "immersion", title = "PRESET_IMMERSION", description = "PRESET_IMMERSION_DESC",
      icon = "Interface\\Icons\\icon_treasuremap", fallback = 134269 },
    { id = "full", title = "PRESET_FULL", description = "PRESET_FULL_DESC",
      icon = "Interface\\Icons\\Achievement_Zone_ElwynnForest", fallback = 134269 },
}

local function inCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function text(parent, value, font, width, point, relative, relativePoint, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", font)
    label:SetWidth(width)
    label:SetPoint(point, relative, relativePoint, x, y)
    label:SetJustifyH("CENTER")
    label:SetText(value)
    return label
end

local function atlas(texture, name)
    if C_Texture and type(C_Texture.GetAtlasInfo) == "function"
        and C_Texture.GetAtlasInfo(name) and type(texture.SetAtlas) == "function" then
        texture:SetAtlas(name)
        return true
    end
    return false
end

local function fit()
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    window:SetScale(math.min(1, width * 0.94 / 1000, height * 0.94 / 700))
end

local function circularIcon(card, preset)
    local ring = card:CreateTexture(nil, "ARTWORK")
    ring:SetSize(88, 88)
    ring:SetPoint("TOP", 0, -94)
    ring:SetColorTexture(0.52, 0.40, 0.22, 1)
    local inset = card:CreateTexture(nil, "ARTWORK", nil, 1)
    inset:SetSize(80, 80)
    inset:SetPoint("CENTER", ring, "CENTER")
    inset:SetColorTexture(0.06, 0.045, 0.025, 1)
    local icon = card:CreateTexture(nil, "ARTWORK", nil, 2)
    icon:SetSize(74, 74)
    icon:SetPoint("CENTER", ring, "CENTER")
    if not icon:SetTexture(preset.icon) then icon:SetTexture(preset.fallback) end
    icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    -- Masks are native in Forever. Keep a square icon fallback if unavailable.
    if type(card.CreateMaskTexture) == "function" then
        for _, target in ipairs({ ring, inset, icon }) do
            local mask = card:CreateMaskTexture()
            mask:SetAllPoints(target)
            mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            target:AddMaskTexture(mask)
        end
    end
end

local function createWindow()
    if window then return end
    window = CreateFrame("Frame", "NoQuestHintsForeverWelcome", UIParent, "BackdropTemplate")
    window:Hide()
    window:SetSize(1000, 700)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    local dim = window:CreateTexture(nil, "BACKGROUND")
    dim:SetPoint("TOPLEFT", UIParent, "TOPLEFT")
    dim:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT")
    dim:SetColorTexture(0, 0, 0, 0.88)
    text(window, L.WELCOME_TITLE, "GameFontHighlightHuge", 920, "TOP", window, "TOP", 0, -12)
    text(window, L.WELCOME_SUBTITLE, "GameFontNormalLarge", 920, "TOP", window, "TOP", 0, -55)
    text(window, L.WELCOME_SELECT, "GameFontHighlight", 920, "TOP", window, "TOP", 0, -85)

    for index, preset in ipairs(presets) do
        local card = CreateFrame("Button", nil, window, "BackdropTemplate")
        card:SetSize(286, 470)
        card:SetPoint("TOPLEFT", window, "TOPLEFT", 49 + (index - 1) * 308, -122)
        card:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border", edgeSize = 24,
            insets = { left = 7, right = 7, top = 7, bottom = 7 } })
        card:SetBackdropColor(0.16, 0.12, 0.07, 1)
        local background = card:CreateTexture(nil, "BORDER")
        background:SetAllPoints()
        -- Native Forever experience-selection art, when exposed in-game.
        if not atlas(background, "Preset-Selection-Card-Regular") then background:Hide() end
        local title = text(card, L[preset.title], "GameFontNormalLarge", 240, "TOP", card, "TOP", 0, -33)
        title:SetHeight(50)
        circularIcon(card, preset)
        local description = text(card, L[preset.description], "GameFontHighlight", 224,
            "TOP", card, "TOP", 0, -210)
        description:SetJustifyV("TOP")
        local highlight = card:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 0.82, 0.35, 0.10)
        local choice = text(card, "", "GameFontNormal", 230, "BOTTOM", card, "BOTTOM", 0, 24)
        card:SetScript("OnClick", function()
            selected = preset.id
            for _, other in ipairs(cards) do
                other:SetBackdropBorderColor(0.6, 0.48, 0.28, 1)
                other.Choice:SetText("")
                other.Selection:Hide()
            end
            card:SetBackdropBorderColor(1, 0.82, 0, 1)
            choice:SetText(L.WELCOME_SELECTED)
            card.Selection:Show()
            window.Apply:Enable()
        end)
        card.Selection = card:CreateTexture(nil, "OVERLAY", nil, -1)
        card.Selection:SetAllPoints()
        if not atlas(card.Selection, "Preset-Selection-Card-Regular-yellow-glow") then
            card.Selection:SetColorTexture(1, 0.82, 0.25, 0.08)
        end
        card.Selection:Hide()
        card.Choice = choice
        cards[index] = card
    end
    text(window, L.WELCOME_FOOTER, "GameFontHighlight", 900, "TOP", window, "TOP", 0, -604)
    local function button(label, width, x, onClick)
        local control = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
        control:SetSize(width, 30)
        control:SetPoint("BOTTOM", window, "BOTTOM", x, 15)
        control:SetText(label)
        control:SetScript("OnClick", onClick)
        return control
    end
    window.Apply = button(L.WELCOME_APPLY, 230, 0, function()
        if selected and not inCombat() and api.ApplyPreset(selected) then window:Hide() end
    end)
    button(L.WELCOME_LATER, 140, -300, function() window:Hide() end)
    button(L.WELCOME_SETTINGS, 230, 300, function()
        if not inCombat() and api.OpenOptions() then window:Hide() end
    end)
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", window, "TOPRIGHT", 8, 8)
    window:RegisterEvent("UI_SCALE_CHANGED")
    window:RegisterEvent("DISPLAY_SIZE_CHANGED")
    window:RegisterEvent("PLAYER_REGEN_DISABLED")
    window:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then window:Hide() else fit() end
    end)
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, window:GetName()) end
end

function api.HideWelcome()
    if window then window:Hide() end
end

function api.ShowWelcome()
    if inCombat() then requested = true; return false end
    createWindow()
    selected, requested, shownThisSession = nil, false, true
    for _, card in ipairs(cards) do
        card:SetBackdropBorderColor(0.6, 0.48, 0.28, 1)
        card.Choice:SetText("")
        card.Selection:Hide()
    end
    window.Apply:Disable()
    fit()
    window:Show()
    return true
end

function api.MaybeShowWelcome()
    if requested or (not shownThisSession and api.IsOnboardingPending()) then
        api.ShowWelcome()
    end
end
