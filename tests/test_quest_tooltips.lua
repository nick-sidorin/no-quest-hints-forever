-- Forever native tooltip-line filtering regression tests, Lua 5.1.
-- Verifies no string matching, no blank lines, and only Unit/Object types.
local path = "NoQuestHintsForever/QuestTooltips.lua"
local lineKinds = { QuestTitle=17, QuestObjective=8, QuestPlayer=18, UnitName=2 }
local dataKinds = { Unit=2, Object=4, Item=0, Quest=23 }

local function session(initial, delayed)
    local hidden = initial
    local calls, count = {}, {}
    local frames = {}
    Enum = {
        TooltipDataType = dataKinds,
        TooltipDataLineType = lineKinds,
    }
    NoQuestHintsForeverAPI = {
        IsTooltipHintsHidden = function() return hidden end,
    }
    -- Lua's "a and nil or b" always evaluates to b, even when a is true.
    -- Use an explicit branch to actually emulate a not-yet-loaded processor.
    if delayed then
        TooltipDataProcessor = nil
    else
        TooltipDataProcessor = {
            AddLinePreCall = function(kind, fn)
                assert(calls[kind] == nil, "duplicate line-pre registration")
                calls[kind] = fn
                count[kind] = (count[kind] or 0) + 1
            end,
        }
    end
    CreateFrame = function()
        local frame = {events={}}
        function frame:RegisterEvent(name) self.events[name]=true end
        function frame:UnregisterEvent(name) self.events[name]=nil end
        function frame:SetScript(_,fn) self.handler=fn end
        frames[#frames+1] = frame
        return frame
    end
    assert(loadfile(path))()

    local function hover(dataType, source, usePrimary)
        local tooltip={}
        local data={type=dataType}
        if usePrimary then
            function tooltip:GetPrimaryTooltipData() return data end
        else
            tooltip.processingInfo={tooltipData=data}
        end
        -- Emulate Blizzard: if line-pre hook returns true, skip the line.
        local output = {}
        for _, entry in ipairs(source) do
            local lineType, text = entry[1], entry[2]
            local handler = calls[lineType]
            local consumed = handler and handler(tooltip,{type=lineType,leftText=text}) or false
            if not consumed then output[#output+1] = text end
        end
        return table.concat(output, "|")
    end

    local sample={
        {2,"Furbolg Shaman"},
        {17,"Quest Title"},
        {8,"Furbolg teeth: 3/8"},
        {18,"Party Member Progress"},
        {2,"Level 12 Beast"},
    }
    return {
        calls=calls, count=count, sample=sample, hover=hover,
        setHidden=function(v) hidden=v end, frames=frames,
        ready=function()
            TooltipDataProcessor={
                AddLinePreCall=function(kind,fn)
                    assert(calls[kind] == nil, "duplicated delayed hook")
                    calls[kind]=fn
                    count[kind]=(count[kind] or 0)+1
                end,
            }
            assert(#frames==1 and frames[1].handler,"delayed frame not installed")
            frames[1].handler(frames[1],"ADDON_LOADED")
        end,
    }
end

local s=session(false,false)
assert(s.calls[17] and s.calls[8] and s.calls[18],"missing three pre-callbacks")
assert(not s.calls[2],"ordinary unit lines must never be intercepted")
assert(#s.frames==0,"unnecessary delayed setup")
assert(s.hover(2,s.sample)=="Furbolg Shaman|Quest Title|Furbolg teeth: 3/8|Party Member Progress|Level 12 Beast",
    "disabled setting must not alter unit tooltip")

s.setHidden(true)
assert(s.hover(2,s.sample)=="Furbolg Shaman|Level 12 Beast",
    "quest title/progress/player lines should be consumed without gaps")
assert(s.hover(4,s.sample)=="Furbolg Shaman|Level 12 Beast",
    "native world-object quest lines should be hidden")
assert(s.hover(0,s.sample)=="Furbolg Shaman|Quest Title|Furbolg teeth: 3/8|Party Member Progress|Level 12 Beast",
    "item tooltips must be unaffected")
assert(s.hover(23,s.sample)=="Furbolg Shaman|Quest Title|Furbolg teeth: 3/8|Party Member Progress|Level 12 Beast",
    "quest journal/details tooltips must be unaffected")
assert(s.hover(2,s.sample,true)=="Furbolg Shaman|Level 12 Beast",
    "primary-tooltip fallback must work")
s.setHidden(false)
assert(s.hover(2,s.sample)=="Furbolg Shaman|Quest Title|Furbolg teeth: 3/8|Party Member Progress|Level 12 Beast",
    "re-enabling the default UI must restore quest lines immediately")

local late=session(true,true)
assert(not late.calls[17] and #late.frames==1)
late.ready()
assert(late.calls[17] and late.calls[8] and late.calls[18],
    "late tooltip processor loading failed")
assert(next(late.frames[1].events)==nil,"did not unregister delayed events")
assert(late.hover(2,late.sample)=="Furbolg Shaman|Level 12 Beast")
assert(late.count[17]==1 and late.count[8]==1 and late.count[18]==1,
    "registered any tooltip hook twice")
local alt=session(false,false)
assert(alt.hover(2,alt.sample):find("Quest Title"),
    "fresh default/alt should retain original quest tooltip content")

io.write("PASS: native tooltip filter, Unit/Object only, toggle, delayed load and default-off\n")
