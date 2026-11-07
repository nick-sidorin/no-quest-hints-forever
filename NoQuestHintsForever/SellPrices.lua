-- Hide vendor sell values away from merchants, with an optional auction exception.
-- Blizzard's SellPrice tooltip line generates both text and coin widgets.
-- Consuming it before rendering removes the entire price without affecting
-- item descriptions, stats, rarity, stacks, or vendor transactions.
local api = NoQuestHintsForeverAPI
if not api then return end

local installed = false

local function frameIsOpen(frame)
    if not frame then return false end
    if type(frame.IsVisible) == "function" then return frame:IsVisible() == true end
    return type(frame.IsShown) == "function" and frame:IsShown() == true
end

local function auctionPricesAllowed()
    return type(api.IsAuctionSellPriceShown) == "function"
        and api.IsAuctionSellPriceShown() == true
        and (frameIsOpen(AuctionHouseFrame) or frameIsOpen(AuctionFrame))
end

local function isItemTooltip(tooltip)
    if not tooltip then return false end

    local data = tooltip.processingInfo and tooltip.processingInfo.tooltipData
    if not data and type(tooltip.GetPrimaryTooltipData) == "function" then
        local ok, primary = pcall(tooltip.GetPrimaryTooltipData, tooltip)
        if ok then data = primary end
    end

    local types = Enum and Enum.TooltipDataType
    return type(data) == "table" and types ~= nil and data.type == types.Item
end

local function hideSellPrice(tooltip)
    if type(api.IsSellPriceHidden) == "function"
        and api.IsSellPriceHidden() == true
        and not frameIsOpen(MerchantFrame)
        and not auctionPricesAllowed()
        and isItemTooltip(tooltip) then
        -- Skip the original SellPrice line and its Blizzard money widget.
        return true
    end
end

local function install()
    if installed then return true end
    local processor = TooltipDataProcessor
    local enums = Enum
    local lineType = enums and enums.TooltipDataLineType
        and enums.TooltipDataLineType.SellPrice

    if not processor or type(processor.AddLinePreCall) ~= "function"
        or type(lineType) ~= "number"
        or not enums.TooltipDataType or type(enums.TooltipDataType.Item) ~= "number" then
        return false
    end

    local ok = pcall(processor.AddLinePreCall, lineType, hideSellPrice)
    if ok then installed = true end
    return installed
end

if not install() then
    -- TooltipDataProcessor may become available after this addon loads.
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:SetScript("OnEvent", function(self)
        if install() then
            self:UnregisterEvent("ADDON_LOADED")
            self:UnregisterEvent("PLAYER_LOGIN")
        end
    end)
end
