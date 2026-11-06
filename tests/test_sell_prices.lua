-- Native SellPrice line filtering, with prices visible only at the vendor.
-- Run: lua5.1 tests/test_sell_prices.lua
local addon = "NoQuestHintsForever/SellPrices.lua"

local function session(initialHidden, delayed)
    local hidden = initialHidden
    local handlers, registrations, eventFrame = {}, 0, nil
    local merchantVisible, merchantStyle = false, "visible"

    Enum = {
        TooltipDataType = {Item=0,Unit=2,Object=4,Quest=23},
        TooltipDataLineType = {SellPrice=11,ItemName=1,QuestTitle=17},
    }
    NoQuestHintsForeverAPI = {
        IsSellPriceHidden = function() return hidden end,
    }

    if delayed then
        TooltipDataProcessor = nil
    else
        TooltipDataProcessor = {
            AddLinePreCall = function(line, fn)
                assert(line==11 and handlers[line]==nil, "duplicate or wrong price hook")
                handlers[line]=fn
                registrations=registrations+1
            end,
        }
    end

    CreateFrame = function()
        local frame={events={}}
        function frame:RegisterEvent(e) self.events[e]=true end
        function frame:UnregisterEvent(e) self.events[e]=nil end
        function frame:SetScript(_,fn) self.onEvent=fn end
        eventFrame=frame
        return frame
    end

    MerchantFrame = {
        IsVisible = function() return merchantVisible end,
        IsShown = function() return merchantVisible end,
    }

    assert(loadfile(addon))()

    local function hover(dataType, primary)
        local data={type=dataType}
        local tooltip={}
        if primary then
            function tooltip:GetPrimaryTooltipData() return data end
        else
            tooltip.processingInfo={tooltipData=data}
        end
        local output={"Item name", "Item attributes"}
        local hook=handlers[11]
        local consumed=hook and hook(tooltip,{type=11,price=10000})
        if not consumed then output[#output+1]="Sell Price: 1g" end
        return table.concat(output,"|")
    end

    return {
        hover=hover,
        hidden=function(v) hidden=v end,
        merchant=function(v) merchantVisible=v end,
        merchantFrame=function(v) MerchantFrame=v end,
        ready=function()
            TooltipDataProcessor={
                AddLinePreCall=function(line,fn)
                    assert(line==11 and handlers[line]==nil)
                    handlers[line]=fn
                    registrations=registrations+1
                end,
            }
            assert(eventFrame and eventFrame.onEvent)
            eventFrame.onEvent(eventFrame,"ADDON_LOADED")
        end,
        frame=function() return eventFrame end,
        registrationCount=function() return registrations end,
    }
end

local s=session(false,false)
assert(s.registrationCount()==1,"price hook not installed exactly once")
assert(s.hover(0)=="Item name|Item attributes|Sell Price: 1g",
    "default off must show sell price")

s.hidden(true)
assert(s.hover(0)=="Item name|Item attributes",
    "bag item should not reveal sell price away from merchant")
assert(s.hover(0,true)=="Item name|Item attributes",
    "fallback primary Item tooltip should be filtered")
assert(s.hover(2):find("Sell Price: 1g"),"Unit tooltip must be unchanged")
assert(s.hover(4):find("Sell Price: 1g"),"Object tooltip must be unchanged")
assert(s.hover(23):find("Sell Price: 1g"),"Quest tooltip must be unchanged")

s.merchant(true)
assert(s.hover(0)=="Item name|Item attributes|Sell Price: 1g",
    "merchant open should show sell price in inventory tooltip")
s.merchant(false)
assert(s.hover(0)=="Item name|Item attributes",
    "leaving vendor should hide sell prices again")
s.merchantFrame({IsShown=function() return true end})
assert(s.hover(0):find("Sell Price: 1g"),"older merchant IsShown fallback missing")
s.merchantFrame(nil)
assert(s.hover(0)=="Item name|Item attributes","missing MerchantFrame should count as closed")

s.hidden(false)
assert(s.hover(0):find("Sell Price: 1g"),"turning option off must restore normal prices")

local late=session(true,true)
assert(late.registrationCount()==0 and late.frame(),"late tooltip processor must install event handler")
late.ready()
assert(late.registrationCount()==1,"late tooltip initialization failed")
assert(next(late.frame().events)==nil,"late event handler not removed")
assert(late.hover(0)=="Item name|Item attributes")
late.frame().onEvent(late.frame(),"PLAYER_LOGIN")
assert(late.registrationCount()==1,"duplicate pre-hook on repeated load")

local alt=session(false,false)
assert(alt.hover(0):find("Sell Price: 1g"),"fresh character should show prices by default")

io.write("PASS: merchant-only item sell prices, dynamic toggles, fallback, isolation, late loading\n")
