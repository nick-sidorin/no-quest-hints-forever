-- Native container border lifecycle; no dependence on bag addons or item rarity.
local hidden, combat, timers = false, false, {}
local eventFrame
local questInfo = {}
local function texture(alpha)
    local t = {alpha=alpha, shown=true}
    function t:GetAlpha() return self.alpha end
    function t:SetAlpha(value)
        assert(not combat, "protected write in combat")
        if self.fail then error("blocked write") end
        self.alpha=value
    end
    function t:Show() self.shown=true end
    function t:Hide() self.shown=false end
    return t
end
local function button(bag, slot, alpha)
    local b = {bag=bag, slot=slot, IconQuestTexture=texture(alpha), quality=texture(0.9), newItem=texture(0.7)}
    function b:GetBagID() return self.bag end
    function b:GetID() return self.slot end
    function b:UpdateQuestItem()
        local info=questInfo[self.bag .. ':' .. self.slot]
        self.IconQuestTexture.shown=info and (info.isQuestItem or info.questID) and true or false
    end
    return b
end
local function container(items)
    local c={items=items}
    function c:EnumerateValidItems()
        local last = self.slotCount or #self.items
        return function(_,index)
            index=index+1
            if index<=last then return index,self.items[index] end
        end,self,0
    end
    function c:UpdateItems() for _, b in ipairs(self.items) do b:UpdateQuestItem() end end
    function c:Show() end
    return c
end
local quest = button(0,1,0.6)
local regular = button(1,1,1)
local starter = button(2,1,0.8)
local bank = button(6,1,1)
questInfo['0:1']={isQuestItem=true}
questInfo['1:1']={}
questInfo['2:1']={questID=50,isActive=false}
questInfo['6:1']={isQuestItem=true}
local bags=container({quest,regular,starter})
local bankFrame=container({bank})
local frames={bags,bankFrame}
ContainerFrameUtil_EnumerateContainerFrames=nil -- delayed Blizzard UI
Constants={InventoryConstants={NumBagSlots=5}}
C_Container={GetContainerItemQuestInfo=function(bag,slot) return questInfo[bag .. ':' .. slot] end}
InCombatLockdown=function() return combat end
C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
local hooks=0
hooksecurefunc=function(obj,key,fn)
    hooks=hooks+1
    local original=obj[key]
    obj[key]=function(self,...) original(self,...);fn(self,...) end
end
CreateFrame=function()
    eventFrame={events={}}
    function eventFrame:RegisterEvent(e) self.events[e]=true end
    function eventFrame:SetScript(_,fn) self.onEvent=fn end
    return eventFrame
end
NoQuestHintsForeverAPI={IsQuestItemHighlightHidden=function() return hidden end}
assert(loadfile('NoQuestHintsForever/QuestItemHighlight.lua'))()
local api=NoQuestHintsForeverAPI
local function flush()
    local count=0
    while #timers>0 do
        count=count+1; assert(count<20, 'refresh loop')
        table.remove(timers,1)()
    end
end
local function event(e) assert(eventFrame.events[e]); eventFrame.onEvent(eventFrame,e);flush() end
event('PLAYER_LOGIN')
ContainerFrameUtil_EnumerateContainerFrames=function() return ipairs(frames) end
event('ADDON_LOADED')
assert(quest.IconQuestTexture.alpha==0.6)
-- The client can enumerate an unmaterialized button between real slots,
-- even when the hiding feature is OFF. A nil value does not end iteration.
bags.items={[1]=quest,[3]=regular,[4]=starter};bags.slotCount=4
event('BAG_UPDATE_DELAYED')
hidden=true;api.RefreshQuestItemHighlight();flush()
assert(quest.IconQuestTexture.alpha==0)
assert(regular.IconQuestTexture.alpha==1 and starter.IconQuestTexture.alpha==0.8)
bags.items={quest,regular,starter};bags.slotCount=nil
assert(bank.IconQuestTexture.alpha==1, 'bank must remain native')
assert(quest.quality.alpha==0.9 and quest.newItem.alpha==0.7, 'unrelated overlays changed')
assert(quest.IconQuestTexture.shown, 'do not change native visibility')
local count=hooks
event('QUEST_LOG_UPDATE');event('BAG_UPDATE_DELAYED');assert(hooks==count, 'duplicate hooks')
-- Actual pre-created button method, not a mixin/global reference.
quest:UpdateQuestItem();flush();assert(quest.IconQuestTexture.alpha==0)
questInfo['0:1']={questID=51,isActive=false}
quest:UpdateQuestItem();flush()
assert(quest.IconQuestTexture.alpha==0.6, 'reused slot must show quest-start marker')
questInfo['0:1']={questID=51,isActive=true}
quest:UpdateQuestItem();flush();assert(quest.IconQuestTexture.alpha==0)
-- New pooled slots, combined/individual containers and detached regions.
local late=button(5,1,0.4);questInfo['5:1']={isQuestItem=true}
bags.items[#bags.items+1]=late
bags:UpdateItems();flush();assert(late.IconQuestTexture.alpha==0)
bags.items={regular,starter,late};event('BAG_UPDATE_DELAYED')
assert(quest.IconQuestTexture.alpha==0.6, 'released slot retained alpha override')
-- Native hidden state is preserved; restoration does not resurrect empty slots.
late.IconQuestTexture:Hide()
hidden=false;api.RefreshQuestItemHighlight();flush()
assert(late.IconQuestTexture.alpha==0.4 and not late.IconQuestTexture.shown)
assert(api.RestoreQuestItemHighlight())
-- Combat and failed writes keep restoration pending and retry on regeneration.
hidden=true;event('BAG_UPDATE_DELAYED');assert(late.IconQuestTexture.alpha==0)
combat=true;hidden=false;api.RefreshQuestItemHighlight();flush()
assert(not api.RestoreQuestItemHighlight() and late.IconQuestTexture.alpha==0)
combat=false;late.IconQuestTexture.fail=true
event('PLAYER_REGEN_ENABLED');assert(not api.RestoreQuestItemHighlight())
late.IconQuestTexture.fail=false;event('PLAYER_REGEN_ENABLED')
assert(api.RestoreQuestItemHighlight() and late.IconQuestTexture.alpha==0.4)
-- Missing container/item APIs are a passive no-op.
C_Container=nil;hidden=true;event('BAG_UPDATE_DELAYED')
assert(late.IconQuestTexture.alpha==0.4)
-- A missing container entry is also harmless during native UI startup.
ContainerFrameUtil_EnumerateContainerFrames=function()
    return function(_,i) i=i+1;if i==1 then return i,nil elseif i==2 then return i,bags end end,nil,0
end
event('ADDON_LOADED')
io.write('PASS: native bag quest borders, quest-start preservation, pool reuse, exact alpha restore and combat retry\n')
