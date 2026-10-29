-- Runs against a supplied, installed-game HistoricMoments.lua (XP1 or XP2).
-- The companion launcher strips Firaxis's Lua type annotations for Lua 5.4.
-- Firaxis's ipairs ignores fallback entries; Lua 5.4 follows __index. The
-- stock illustration map supplies a fallback for every key, so emulate the
-- game's raw-array iteration rather than walking that fallback forever.
ipairs=function(t)
 local function nextArray(a,i)i=i+1;local v=rawget(a,i);if v~=nil then return i,v end end
 return nextArray,t,0
end
local props={
 PARADE_V314_MOMENT_0_READY=1,PARADE_V314_MOMENT_0_TURN=10,PARADE_V314_MOMENT_0_SCORE=2,
 PARADE_V314_MOMENT_0_CITY='Old Capital',PARADE_V314_MOMENT_0_NAME='',
 PARADE_V314_MOMENT_1_READY=1,PARADE_V314_MOMENT_1_TURN=60,PARADE_V314_MOMENT_1_SCORE=1,
 PARADE_V314_MOMENT_1_CITY='New Capital',PARADE_V314_MOMENT_1_NAME='General',PARADE_V314_MOMENT_1_GENERAL=1}
local native={{ID=100,Turn=4,GameEra=0,Type=2,InstanceDescription='Native A',EraScore=3,ExtraData={}},
 {ID=101,Turn=50,GameEra=1,Type=2,InstanceDescription='Native B',EraScore=4,ExtraData={}}}
local eras={{Index=0,Name='Ancient'},{Index=1,Name='Classical'}}
local moment={Index=2,InterestLevel=3,BackgroundTexture='NativeArt',MomentType='NATIVE',Description='Native tooltip'}
local function rows(items,indices)
 return setmetatable(indices or {},{__call=function()local i=0;return function()i=i+1;return items[i]end end})
end
Players={[0]={GetProperty=function(_,k)if props[k]==nil then return end;return props[k]end}}
GameInfo={Eras=rows(eras,{[0]=eras[1],[1]=eras[2]}),Moments=rows({moment},{[2]=moment}),MomentIllustrations=rows({})}
MomentDataTypes=setmetatable({}, {__index=function(t,k)local n=0;for _ in pairs(t)do n=n+1 end;t[k]=n+1;return n+1 end})
local manager={GetAllMomentsData=function(_,owner)assert(owner==0);return native end}
Game={GetLocalPlayer=function()return 0 end,GetHistoryManager=function()return manager end}
local getter=Game.GetHistoryManager
local instances={}
local function control()
 local c={sizeX=530,sizeY=483,children={}}
 function c:SetText(v)self.text=v end
 function c:SetTexture(v)self.texture=v end
 function c:SetToolTipString(v)self.tooltip=v end
 function c:SetHide(v)self.hidden=v end
 function c:SetOffsetVal(x,y)self.x=x;self.y=y end
 function c:SetSizeVal(x,y)self.sizeX=x;self.sizeY=y end
 function c:SetOffsetY(v)self.y=v end
 function c:GetSizeX()return self.sizeX end
 function c:GetSizeY()return self.sizeY end
 function c:SetSizeX(v)self.sizeX=v end
 function c:CalculateSize()if #self.children>0 then self.sizeX=#self.children*580 end end
 function c:SetToBeginning()end
 function c:Play()end
 function c:SetAnchor(v)end
 function c:SetOffsetX(v)end
 function c:HideScrollBar(v)end
 function c:SetScrollValue(v)end
 return c
end
Controls=setmetatable({}, {__index=function(t,k)local c=control();t[k]=c;return c end})
InstanceManager={}
function InstanceManager:new(kind,key,parent)
 local im={items={}}
 function im:ResetInstances()
  for _,entry in ipairs(self.items)do
   if entry.parent then for i=#entry.parent.children,1,-1 do
    if entry.parent.children[i]==entry then table.remove(entry.parent.children,i)end
   end end
  end
  self.items={}
 end
 function im:GetInstance(newParent)
  local item=setmetatable({kind=kind,parent=newParent or parent},{__index=function(t,k)local c=control();t[k]=c;return c end})
  self.items[#self.items+1]=item;instances[#instances+1]=item
  if item.parent then item.parent.children[#item.parent.children+1]=item end
  return item
 end
 return im
end
Options={GetAppOption=function()return 0 end,GetUserOption=function()return 0 end}
DB={MakeHash=function()return 1 end}
HasCapability=function()return false end
include=function()end
GameConfiguration={IsHotseat=function()return false end}
PlayerConfigurations={[0]={GetCivilizationDescription=function()return 'Civ' end}}
Locale={Lookup=function(k,...)return tostring(k)..' '..table.concat({...},',')end,ToUpper=function(k)return k end}
Calendar={MakeYearStr=function(t)return 'Year '..t end}
table.count=function(t)local n=0;for _ in pairs(t)do n=n+1 end;return n end
local event=setmetatable({},{__call=function()end})
LuaEvents=setmetatable({}, {__index=function()return event end})
UI={PlaySound=function()end,DataError=function(s)error(s)end}
UIManager={GetScreenSizeVal=function()return 1920,1080 end}
ContextPtr={hidden=true,IsHidden=function(self)return self.hidden end}
ExposedMembers={}
Events={UIIdle={Add=function(f)end}}
PopupPriority={Medium=10,Current=20}
UI.CanShowPopup=function()return true end
assert(load(TEST_NATIVE,'native HistoricMoments','t',_ENV))()
assert(loadfile(TEST_ROOT..'/Parade_HistoricMoments.lua','t',_ENV))()
local stockShow=Show
local shown=0
Show=function()shown=shown+1;ContextPtr.hidden=false end
local mockShow=Show
DisplayTimeline(false)
assert(Game.GetHistoryManager==getter,'history getter leaked out of the adapter')
assert(#native==2 and not native[1].Parade,'native data was mutated')
assert(shown==1 and Controls.EmptyTimelineMessage.hidden)
local cards={}
for _,entry in ipairs(Controls.TimelineStack.children)do if entry.kind=='LargeMoment'then cards[#cards+1]=entry end end
assert(#cards==4,'merged native timeline did not contain four cards')
local separators=0
for _,entry in ipairs(Controls.TimelineStack.children)do if entry.kind=='EraLabel'then separators=separators+1 end end
assert(separators==2,'world-era grouping changed while merging cards')
assert(cards[1].Description.text=='Native A')
assert(cards[2].Description.text:find('LOC_PARADE_ERA_FIRST_TITLE',1,true))
assert(not cards[2].Description.text:find('[NEWLINE]',1,true),'long poem still inside fixed-height caption')
assert(cards[2].Root.tooltip:find('LOC_PARADE_ERA_FIRST_BODY',1,true))
assert(cards[2].Effect.text:find('10,+2',1,true))
assert(cards[3].Description.text=='Native B')
assert(cards[4].Root.tooltip:find('LOC_PARADE_ERA_GENERAL_BODY',1,true))
assert(cards[4].Root.tooltip:find('New Capital',1,true))
local art=cards[2].Illustrations.children[1].Root
assert(art.texture=='Parade_TimelineMoment.dds'and art.sizeX==456 and art.sizeY==228)
DisplayTimeline(false)
local n=0;for _,entry in ipairs(Controls.TimelineStack.children)do if entry.kind=='LargeMoment'then n=n+1 end end
assert(n==4,'reopening duplicated cards')
-- Only custom moments: the native empty-message path must become nonempty.
native={};DisplayTimeline(false);assert(Controls.EmptyTimelineMessage.hidden)
-- Migration fallback must tolerate the engine returning zero values for missing properties.
props={PARADE_V313_WORLD_ERA=0,PARADE_V313_ERA_SCORE=2,PARADE_V35_TURN=12}
DisplayTimeline(false);assert(Controls.EmptyTimelineMessage.hidden)
-- v3.13 repeat as latest record: keep its real date and +0, never fake +2.
props={PARADE_V313_WORLD_ERA=0,PARADE_V313_ERA_SCORE=0,PARADE_V313_ERA_DONE_0=1,PARADE_V35_TURN=14}
DisplayTimeline(false)
local repeatCard
for _,entry in ipairs(Controls.TimelineStack.children)do if entry.kind=='LargeMoment'then repeatCard=entry end end
assert(repeatCard and repeatCard.Effect.text:find('NO_SCORE',1,true))
-- Each new completion is archived independently even within the same era.
props={PARADE_V315_ARCHIVE_STARTED=1,PARADE_V35_COUNT=2,
 PARADE_V315_MOMENT_1_READY=1,PARADE_V315_MOMENT_1_ERA=0,PARADE_V315_MOMENT_1_TURN=5,PARADE_V315_MOMENT_1_SCORE=2,
 PARADE_V315_MOMENT_2_READY=1,PARADE_V315_MOMENT_2_ERA=0,PARADE_V315_MOMENT_2_TURN=10,PARADE_V315_MOMENT_2_SCORE=1,
 PARADE_V313_WORLD_ERA=0,PARADE_V313_ERA_SCORE=1}
DisplayTimeline(false)
local repeatCards={};for _,entry in ipairs(Controls.TimelineStack.children)do if entry.kind=='LargeMoment'then repeatCards[#repeatCards+1]=entry end end
assert(#repeatCards==2,'new records missing, duplicated by legacy fallback, or merged into one era card')
assert(repeatCards[1].Effect.text:find('5,+2',1,true)and repeatCards[2].Effect.text:find('10,+1',1,true))
-- Real stock Show, QueuePopup and parameters: reproduce delayed-show=true
-- remaining hidden without a native notification. The old fixture's mock Show
-- unconditionally unhid the context and could never expose this failure.
local auto=ExposedMembers.ParadeV316Timeline
local busy=true
local queueCalls=0;local registered=false;local allowVisible=false;local pride=0
ExposedMembers.ParadeV38Presentation={IsActive=function()return busy end}
UI.CanShowPopup=function()return false end
UI.PlaySound=function(name)if name=='Pride_Moment'then pride=pride+1 end end
ContextPtr.ChangeParent=function()end;ContextPtr.LookUpControl=function()return control()end
RefreshYields=function()return true end
UIManager.QueuePopup=function(_,ctx,priority,parameters)
 queueCalls=queueCalls+1;registered=true
 assert(priority==10)
 assert(parameters.DelayShow==false,'custom moment still needs native delayed-show signal')
 if allowVisible then ctx.hidden=false end
end
UIManager.IsInPopupQueue=function()return registered end
ContextPtr.hidden=true;Show=stockShow
Options.GetUserOption=function()return 1 end
assert(GetPopupParameters().DelayShow==true,'manual stock parameters changed')
assert(auto.RequestAuto(0,2));auto.Pump(.1);assert(queueCalls==0)
busy=false;auto.Pump(.1);assert(queueCalls==0,'native priority gate ignored')
UI.CanShowPopup=function()return true end
auto.Pump(.1)
assert(queueCalls==1 and ContextPtr.hidden and pride==0,'hidden queue wrongly reported visible')
auto.Pump(.1);assert(queueCalls==1,'busy native queue got duplicate popup registration')
-- Native queue now makes it visible: only now acknowledge/play the award sound.
ContextPtr.hidden=false;auto.Pump(.1)
assert(pride==1 and Controls.ModalScreenTitle.text:find('LOC_HISTORY_NEW_MOMENT',1,true))
assert(GetPopupParameters().DelayShow==true,'automatic parameter override leaked')
local brush=false
for _,entry in ipairs(Controls.TimelineStack.children)do
 if entry.kind=='NewLargeMoment'and entry.Description.text:find('LOC_PARADE_ERA_REPEAT_TITLE',1,true)then brush=true end
end
assert(brush,'native historic moment animation path not used')
auto.RequestAuto(0,2);auto.Pump(.1);assert(queueCalls==1 and pride==1)
Options.GetAppOption=function()return 1 end
auto.RequestAuto(0,1);auto.Pump(.1);assert(queueCalls==1,'ignored suppressed popups')
Options.GetAppOption=function()return 0 end
-- A failed registration is retried; a hidden request must never be discarded.
ContextPtr.hidden=true;registered=false;allowVisible=false
auto.RequestAuto(0,1);auto.Pump(.1);assert(queueCalls==2)
registered=false;auto.Pump(2.1);allowVisible=true;auto.Pump(.1)
assert(queueCalls==3 and not ContextPtr.hidden and pride==2)
Show=mockShow
print('PASS: real stock Show path, no delayed-show dependency, visible-only acknowledgement/sound, native priority queue, lost-registration retry and manual parameter preservation')
-- If custom rendering fails, restore getter and keep stock timeline working.
local originalTexture=art.SetTexture
local realAdd=AddIllustration
AddIllustration=function()error('EXPECTED injected render failure')end
DisplayTimeline(false)
assert(Game.GetHistoryManager==getter and shown>=5)
AddIllustration=realAdd
-- No saved awards: use the exact stock renderer, with no adapter.
props={};DisplayTimeline(false);assert(not Controls.EmptyTimelineMessage.hidden)
print('PASS: actual stock timeline merge, chronology, era separators, custom artwork, original cards, reload, empty-native history, migration and getter restoration')
