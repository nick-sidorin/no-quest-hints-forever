-- Native quest-blob regression tests. Run from root with Lua 5.1.
local addon = "NoQuestHintsForever/QuestHints.lua"

local function newFrame()
    local f = { shown=true, texts={}, scripts={}, events={}, position=nil }
    function f:SetSize(w,h) self.width, self.height = w,h end
    function f:SetPoint(...) self.position = {...} end
    function f:SetText(text) self.text=text end
    function f:SetScript(event, fn) self.scripts[event]=fn end
    function f:Show() self.shown=true end
    function f:Hide() self.shown=false end
    function f:HookScript(event, fn) self.scripts[event]=fn end
    function f:GetName() return self.name end
    function f:GetParent() return self.parent end
    return f
end

local function session(char, hasNative, initialHidden)
    NoQuestHintsForeverAPI = nil
    NoQuestHintsForeverChar = char
    NQHQuestBlobPinMixin = nil
    local events, menus, buttons = {}, {}, {}
    local mapHidden = initialHidden ~= false
    local map = {mapID=301, added=0}
    function map:GetMapID() return self.mapID end
    function map:AddDataProvider(p)
        self.provider=p
        self.added=self.added+1
        p:OnAdded(self)
    end
    function map:AcquirePin(template)
        assert(template=="NQHQuestBlobPinTemplate", "not a native quest blob template")
        local pin = {map=self, drawn={}}
        function pin:GetMap() return self.map end
        function pin:DrawNone() self.drawn={} end
        function pin:DrawBlob(id, shape) assert(shape==true); self.drawn[#self.drawn+1]=id end
        function pin:SetPosition(x,y) self.position={x,y} end
        function pin:SetMapID(id) self.blobMapID=id end
        function pin:SetFillTexture(path) self.fill=path end
        function pin:SetBorderTexture(path) self.border=path end
        function pin:SetFillAlpha(v) self.fillAlpha=v end
        function pin:SetBorderAlpha(v) self.borderAlpha=v end
        function pin:SetBorderScalar(v) self.borderScalar=v end
        function pin:SetIgnoreGlobalPinScale(v) self.ignoreScale=v end
        function pin:UseFrameLevelType(t) self.level=t end
        for k,v in pairs(NQHQuestBlobPinMixin) do pin[k]=v end
        assert(pin.OnLoad, "Blizzard QuestBlobPinMixin wasn't inherited")
        pin:OnLoad()
        pin:OnShow()
        self.pin=pin
        return pin
    end
    function map:RemovePin(pin) assert(self.pin==pin); self.pin=nil end
    WorldMapFrame=map

    MapCanvasDataProviderMixin={
        OnAdded=function(self, canvas) self.map=canvas end,
        GetMap=function(self) return self.map end,
    }
    CreateFromMixins=function(parent)
        local obj={}
        for k,v in pairs(parent) do obj[k]=v end
        return obj
    end
    QuestBlobPinMixin=nil
    if hasNative then
        QuestBlobPinMixin={
            OnLoad=function(self)
                self:SetFillTexture("Interface\\WorldMap\\UI-QuestBlob-Inside")
                self:SetBorderTexture("Interface\\WorldMap\\UI-QuestBlob-Outside")
                self:SetFillAlpha(128)
                self:SetBorderAlpha(192)
                self:SetBorderScalar(1)
                self:SetIgnoreGlobalPinScale(true)
                self:UseFrameLevelType("PIN_FRAME_LEVEL_QUEST_BLOB")
            end,
            OnCanvasScaleChanged=function(self) self.dirty=true end,
            OnUpdate=function(self) if self.dirty then self.dirty=nil; self:Refresh() end end,
            OnMapChanged=function(self)
                self.mapAllowsBlobs = self:GetMap():GetMapID()==301
                self:SetMapID(self:GetMap():GetMapID())
                self:Refresh()
            end,
            TryDrawQuest=function(self,id)
                -- Real Blizzard mixin always calls IsShowingWorldQuests.
                assert(type(self.dataProvider.IsShowingWorldQuests) == "function",
                    "native QuestBlobPinMixin requires IsShowingWorldQuests")
                assert(self.dataProvider:IsShowingWorldQuests() == true)
                if id ~= 404 then self:DrawBlob(id, true) end
            end,
            OnAcquired=function() end,
            Refresh=function() error("stock global CVar check must not run") end,
        }
    end

    local detail=newFrame(); detail.questID=10; detail.TrackButton=newFrame()
    detail.BackFrame={BackButton=newFrame()}
    QuestMapFrame={DetailsFrame=detail}
    local popup=newFrame(); popup.questID=20; popup.TrackButton=newFrame()
    function popup:ShowQuest(id) self.questID=id end
    QuestLogPopupDetailFrame=popup
    local trackerHeader=newFrame()
    local trackerBlock={id=20}
    QuestObjectiveTracker={usedBlocks={Quest={}}}
    trackerBlock.parentModule=QuestObjectiveTracker
    trackerHeader.parent=trackerBlock
    trackerBlock.HeaderButton=trackerHeader
    QuestObjectiveTracker.usedBlocks.Quest[20]=trackerBlock
    ObjectiveTrackerBlockHeaderMixin={
        OnLoad=function() end,
        OnClick=function() end,
    }
    QuestMapFrame_ShowQuestDetails=function(id) detail.questID=id end
    local opened={}
    QuestMapFrame_OpenToQuestDetails=function(id) opened[#opened+1]=id end
    hooksecurefunc=function(owner, method, fn)
        if type(owner)=="string" then
            local orig=_G[owner]
            _G[owner]=function(...) local r=orig(...); method(...); return r end
        else
            local orig=owner[method]
            owner[method]=function(self,...) local r=orig(self,...); fn(self,...); return r end
        end
    end
    Menu={ModifyMenu=function(tag,cb) menus[tag]=cb end}
    CreateFrame=function(kind,name,parent,template)
        if kind=="Frame" then
            local f=newFrame()
            _G.__nqhLastEventFrame=f
            function f:RegisterEvent(e) events[e]=true end
            return f
        end
        assert(kind=="Button" and template=="UIPanelButtonTemplate")
        local b=newFrame(); b.parent=parent
        buttons[#buttons+1]=b
        return b
    end
    GameTooltip=nil
    local selected
    local navRefreshes=0
    C_SuperTrack={
        GetSuperTrackedQuestID=function() return selected end,
        SetSuperTrackedQuestID=function(id) selected=id end,
    }
    NoQuestHintsForeverAPI={
        IsMapHidden=function() return mapHidden end,
        RefreshNavigation=function() navRefreshes=navRefreshes+1 end,
    }

    assert(loadfile(addon))()
    local core=NoQuestHintsForeverAPI
    -- Find event frame: we don't expose it except via a monkey patch.
    local eventFrame = _G.__nqhLastEventFrame
    assert(eventFrame and eventFrame.scripts.OnEvent)
    local function fire(e)
        assert(events[e], "event not registered: "..e)
        eventFrame.scripts.OnEvent(eventFrame,e,"Blizzard_WorldMap")
    end
    fire("ADDON_LOADED")
    return {
        db=char, map=map, buttons=buttons, menus=menus, core=core, opened=opened,
        trackerHeader=trackerHeader,
        detail=detail, popup=popup, fire=fire,
        setMapHidden=function(v) mapHidden=v; core.RefreshQuestHintPins() end,
        selectedQuest=function() return selected end,
        navRefreshes=function() return navRefreshes end,
        enableNative=function()
            QuestBlobPinMixin={
                OnLoad=function(self) self.native=true end,
                OnMapChanged=function(self) self.mapAllowsBlobs=true;self:SetMapID(self:GetMap():GetMapID());self:Refresh() end,
                TryDrawQuest=function(self,id) self:DrawBlob(id,true) end,
            }
            fire("ADDON_LOADED")
        end,
    }
end

-- Capture the event frame while leaving every method functional.
local s=session({},true)
assert(s.map.added==0 and not s.map.pin,"empty allowlist must not register a provider or acquire a map pin")
assert(#s.buttons==2,"both journal layouts need a button")
assert(s.buttons[1].width==94 and s.buttons[1].position[1]=="LEFT" and s.buttons[1].position[2]==s.detail.BackFrame.BackButton,"journal button should align with Blizzard Back button")
assert(s.menus.MENU_QUEST_MAP_LOG_TITLE,"journal right click menu missing")
assert(s.menus.MENU_QUEST_LOG_POPUP_DETAIL_FRAME,"popup context menu missing")
assert(s.menus.MENU_QUEST_OBJECTIVE_TRACKER,"tracker context menu not registered")
assert(s.trackerHeader.scripts.OnMouseDown,"tracker quest header lacks a right-click capture")
local trackerRoot={items={}}
function trackerRoot:CreateDivider() self.items[#self.items+1]={divider=true} end
function trackerRoot:CreateButton(label,cb) self.items[#self.items+1]={label=label,click=cb} end
s.trackerHeader.scripts.OnMouseDown(s.trackerHeader,"RightButton")
-- The owner is Blizzard's tracker container, *not* the quest block.
s.menus.MENU_QUEST_OBJECTIVE_TRACKER({},trackerRoot)
assert(#trackerRoot.items==2 and trackerRoot.items[2].label=="Show hint",
    "right-click on quest 20 did not resolve the clicked quest")
trackerRoot.items[2].click()
assert(s.map.added==1,"first selective hint must install the native blob provider")
assert(s.map.pin.fill:find("UI%-QuestBlob%-Inside")~=nil,"native Blizzard art not configured")
assert(s.core.IsQuestRevealed(20) and #s.opened==0,
    "tracker action must allow quest 20 without opening the map")
ObjectiveTrackerBlockHeaderMixin.OnClick(s.trackerHeader,"RightButton")
local afterClick={items={}}
function afterClick:CreateDivider() self.items[#self.items+1]={divider=true} end
function afterClick:CreateButton(label,cb) self.items[#self.items+1]={label=label,click=cb} end
s.menus.MENU_QUEST_OBJECTIVE_TRACKER({},afterClick)
assert(#afterClick.items==0,"tracker right-click retained stale quest ID")
s.core.SetQuestRevealed(20,false)

assert(s.core.SetQuestRevealed(10,true))
assert(s.selectedQuest()==10 and s.core.IsQuestNavigationAllowed(),
    "Show hint failed to select the allowed native SuperTrack quest")
assert(s.navRefreshes()>0,"hint toggle did not refresh nav CVars")
assert(#s.map.pin.drawn==1 and s.map.pin.drawn[1]==10,"only quest 10 must be drawn")
assert(s.buttons[1].text=="Hide hint")
s.core.SetQuestRevealed(20,true)
assert(#s.map.pin.drawn==2,"both opted-in quest blobs should be drawn")
s.core.SetQuestRevealed(10,false)
assert(s.core.IsQuestNavigationAllowed() == true,
    "another revealed supertracked quest should keep navigation allowed")
assert(#s.map.pin.drawn==1 and s.map.pin.drawn[1]==20)
assert(s.buttons[1].text=="Show hint")
assert(s.core.SetQuestRevealed(404,true))
assert(#s.map.pin.drawn==1,"quest without shape data should not get fake icons")
assert(not s.core.SetQuestRevealed(-2,true),"invalid quest ID accepted")

-- A menu entry is created only for the clicked quest and changes that quest.
local root={items={}}
function root:CreateDivider() self.items[#self.items+1]={divider=true} end
function root:CreateButton(label,callback) self.items[#self.items+1]={label=label,click=callback} end
s.menus.MENU_QUEST_MAP_LOG_TITLE({questID=10},root)
assert(root.items[2].label=="Show hint")
root.items[2].click()
assert(s.core.IsQuestRevealed(10))
assert(#s.opened==0,"journal context action must not open the map")
local empty={items={}}
function empty:CreateDivider() self.items[#self.items+1]={divider=true} end
function empty:CreateButton(label,callback) self.items[#self.items+1]={label=label,click=callback} end
s.menus.MENU_QUEST_MAP_LOG_TITLE({},empty)
assert(#empty.items==0,"menu shown for nonquest header")

s.setMapHidden(false)
assert(#s.map.pin.drawn==0,"native hints ON must remove custom blob")
s.setMapHidden(true)
assert(#s.map.pin.drawn==2,"whitelist not restored after hiding globally")
s.map.mapID=500
s.map.provider:OnMapChanged()
assert(#s.map.pin.drawn==0,"blob must respect map type")
s.map.mapID=301
s.map.provider:OnMapChanged()
assert(#s.map.pin.drawn==2)

local saved=s.db
local reload=session(saved,true)
assert(reload.core.IsQuestRevealed(10) and #reload.map.pin.drawn==2,
    "reload did not restore saved whitelist")
local alt=session({},true)
assert(not alt.map.pin and not alt.core.IsQuestRevealed(10),
    "another character inherited whitelist")

local late=session({revealedQuests={[10]=true}},false)
assert(late.map.added==0,"provider registered before native module exists")
late.enableNative()
assert(late.map.added==1,"late loading Blizzard provider not detected")
-- All-off startup/reload and an empty Full immersion allowlist stay out of
-- native map pools. Opting in later must work without a UI reload.
for _, saved in ipairs({{}, {revealedQuests={[10]=true}}}) do
    local idle=session(saved,true,false)
    idle.fire("PLAYER_LOGIN"); idle.fire("PLAYER_ENTERING_WORLD")
    idle.fire("QUEST_LOG_UPDATE"); idle.core.RefreshQuestHintPins()
    assert(idle.map.added==0 and not idle.map.pin,"disabled map filtering touched native pin pools")
    idle.core.SetQuestRevealed(20,true)
    assert(idle.map.added==0,"allowlist editing with global hiding off created pins")
    idle.setMapHidden(true)
    assert(idle.map.added==1 and idle.map.pin,"enabling selective hints after login failed")
    idle.core.RefreshQuestHintPins()
    assert(idle.map.added==1,"lazy initialization registered a duplicate provider")
end
print("PASS: native Blizzard quest blob, independent whitelist, journal/menu, reload and alt\n")
