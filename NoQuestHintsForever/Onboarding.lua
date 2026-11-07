-- Realm-rule-style choices using game art only. Glue screen templates are
-- deliberately not inherited: those templates are not loaded in the game UI.
local api = NoQuestHintsForeverAPI
if not api then return end
local L = NoQuestHintsForeverLocale
local window, selected, shownThisSession, requested
local cards = {}
-- Match the native Forever SuperDistrictButtonTemplate (260 x 530).
-- Atlas artwork includes its own border/padding; never stretch it to the frame.
local WINDOW_WIDTH, WINDOW_HEIGHT = 980, 806
local CARD_WIDTH, CARD_HEIGHT, CARD_GAP = 260, 530, 34
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
        texture:SetAtlas(name, true)
        return true
    end
    return false
end

local function fit()
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    window:SetScale(math.min(1, width * 0.94 / WINDOW_WIDTH, height * 0.94 / WINDOW_HEIGHT))
end

local function circularIcon(card, preset, title)
    local icon = card:CreateTexture(nil, "ARTWORK")
    icon:SetSize(64, 64)
    icon:SetPoint("TOP", title, "BOTTOM", 0, -25)
    if not icon:SetTexture(preset.icon) then icon:SetTexture(preset.fallback) end
    if type(card.CreateMaskTexture) == "function" then
        local mask = card:CreateMaskTexture()
        mask:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, -3)
        mask:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
        if not atlas(mask, "CircleMask") then
            mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        end
        icon:AddMaskTexture(mask)
    end
    -- The exact sculpted portrait ring used on Blizzard's realm-rule cards.
    -- Its authored size includes the bevel and shadow around a 64px portrait.
    local ring = card:CreateTexture(nil, "OVERLAY")
    ring:SetPoint("CENTER", icon, "CENTER")
    if not atlas(ring, "Mode-Selection-Ring") then
        ring:SetSize(82, 82)
        ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        ring:SetTexCoord(0, 0.82, 0, 0.82)
    end
    return icon
end

local function setSelected(card, value)
    card.Choice:SetText(value and L.WELCOME_SELECTED or "")
    if value then card.Selection:Show() else card.Selection:Hide() end
    if card.FallbackBorder then
        if value then card:SetBackdropBorderColor(1, 0.82, 0, 1)
        else card:SetBackdropBorderColor(0.6, 0.48, 0.28, 1) end
    end
end

local function createWindow()
    if window then return end
    window = CreateFrame("Frame", "NoQuestHintsForeverWelcome", UIParent, "BackdropTemplate")
    window:Hide()
    window:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    local dim = window:CreateTexture(nil, "BACKGROUND")
    dim:SetPoint("TOPLEFT", UIParent, "TOPLEFT")
    dim:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT")
    dim:SetColorTexture(0, 0, 0, 0.88)
    local heading = text(window, L.WELCOME_TITLE, "GameFontHighlightHuge", 900,
        "TOP", window, "TOP", 0, -14)
    heading:SetHeight(32)
    local subtitle = text(window, L.WELCOME_SUBTITLE, "GameFontNormalLarge", 900,
        "TOP", heading, "BOTTOM", 0, -16)
    subtitle:SetHeight(24)

    for index, preset in ipairs(presets) do
        local card = CreateFrame("Button", nil, window, "BackdropTemplate")
        card:SetSize(CARD_WIDTH, CARD_HEIGHT)
        card:SetPoint("TOPLEFT", window, "TOPLEFT",
            (WINDOW_WIDTH - (3 * CARD_WIDTH + 2 * CARD_GAP)) / 2 + (index - 1) * (CARD_WIDTH + CARD_GAP), -116)
        local background = card:CreateTexture(nil, "BACKGROUND")
        background:SetPoint("CENTER", card, "CENTER")
        if not atlas(background, "Mode-Selection-Card-Regular") then
            -- Mutually exclusive fallback: never draw two borders together.
            background:Hide()
            card.FallbackBorder = true
            card:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border", edgeSize = 24,
                insets = { left = 7, right = 7, top = 7, bottom = 7 } })
            card:SetBackdropColor(0.16, 0.12, 0.07, 1)
        end
        local title = text(card, L[preset.title], "GameFontNormalLarge", 200,
            "TOP", card, "TOP", 0, -69)
        title:SetHeight(24)
        local icon = circularIcon(card, preset, title)
        local description = text(card, L[preset.description], "GameFontHighlight", 180,
            "TOP", icon, "BOTTOM", 0, -40)
        description:SetHeight(260)
        description:SetJustifyV("TOP")
        card.Selection = card:CreateTexture(nil, "OVERLAY", nil, -1)
        card.Selection:SetPoint("CENTER", card, "CENTER")
        if not atlas(card.Selection, "Mode-Selection-Card-Regular-yellow-glow") then
            card.Selection:SetAllPoints()
            card.Selection:SetColorTexture(1, 0.82, 0.25, 0.08)
        end
        local highlight = card:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetPoint("CENTER", card, "CENTER")
        if not atlas(highlight, "Mode-Selection-Card-Regular-yellow-glow") then
            highlight:SetAllPoints()
            highlight:SetColorTexture(1, 0.82, 0.35, 0.06)
        end
        highlight:SetAlpha(0.45)
        card.Choice = text(card, "", "GameFontNormal", 180,
            "BOTTOM", card, "BOTTOM", 0, 24)
        setSelected(card, false)
        card:SetScript("OnClick", function()
            selected = preset.id
            for _, other in ipairs(cards) do setSelected(other, other == card) end
            window.Prompt:SetText(string.format(L.WELCOME_READY, L[preset.title]))
            window.Apply:Enable()
        end)
        cards[index] = card
    end
    -- One instruction below the cards, instead of a third header style.
    window.Prompt = text(window, L.WELCOME_SELECT, "GameFontHighlight", 860,
        "TOP", window, "TOP", 0, -666)
    window.Prompt:SetHeight(24)
    window.Apply = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    window.Apply:SetSize(320, 44)
    window.Apply:SetPoint("BOTTOM", window, "BOTTOM", 0, 60)
    window.Apply:SetNormalFontObject("GameFontNormalLarge")
    window.Apply:SetHighlightFontObject("GameFontHighlightLarge")
    window.Apply:SetText(L.WELCOME_APPLY)
    window.Apply:SetScript("OnClick", function()
        if selected and not inCombat() and api.ApplyPreset(selected) then window:Hide() end
    end)
    local function secondary(label, x, callback)
        local control = CreateFrame("Button", nil, window)
        control:SetSize(180, 24)
        control:SetPoint("BOTTOM", window, "BOTTOM", x, 20)
        control:SetNormalFontObject("GameFontHighlightSmall")
        control:SetHighlightFontObject("GameFontNormalSmall")
        control:SetText(label)
        control:SetScript("OnClick", callback)
    end
    secondary(L.WELCOME_LATER, -110, function() window:Hide() end)
    secondary(L.WELCOME_SETTINGS, 110, function()
        if not inCombat() and api.OpenOptions() then window:Hide() end
    end)
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -6, -4)
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
    for _, card in ipairs(cards) do setSelected(card, false) end
    window.Prompt:SetText(L.WELCOME_SELECT)
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
