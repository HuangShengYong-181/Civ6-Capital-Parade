-- Independent UI contracts. Does not run the Firaxis UI engine.
local root=assert(TEST_ROOT)
local function bus()
 return setmetatable({},{__index=function(t,k)
  local e=setmetatable({callbacks={}}, {__call=function(self,...)for _,f in ipairs(self.callbacks)do f(...)end end})
  e.Add=function(f)e.callbacks[#e.callbacks+1]=f end;t[k]=e;return e
 end})
end
local events=bus();local luaevents=bus()
local toolbarRequests={}
luaevents.PrideMoments_ToggleTimeline.Add(function(animated)
 assert(animated==false,'waiting native page should not consume award animation')
 toolbarRequests[#toolbarRequests+1]=true
end)
local function control()
 local c={hidden=false,text='',children={}}
 function c:SetHide(v)self.hidden=v end
 function c:IsHidden()return self.hidden end
 function c:SetText(v)self.text=v end
 function c:SetToolTipString(v)self.tooltip=v end
 function c:SetIcon(v)self.icon=v;return true end
 function c:SetOffsetVal(x,y)self.x=x;self.y=y end
 function c:SetAlpha(v)self.alpha=v end
 function c:RegisterCallback(_,f)self.click=f end
 function c:DestroyChild(v)v.destroyed=true end
 return c
end
local function controls(name)
 local allowed=assert(TEST_CONTROL_IDS[name])
 return setmetatable({},{__index=function(t,k)
  if not allowed[k]then return nil end
  local c=control();t[k]=c;return c
 end})
end
local function context()
 local ctx={hidden=true}
 function ctx:SetHide(v)self.hidden=v;if self.showHide then self.showHide(v)end end
 function ctx:IsHidden()return self.hidden end
 function ctx:SetUpdate(f)
  -- Simulate a hidden AddUserInterfaces context not being frame-driven.
  self.update=f and function(dt)if not self.hidden then return f(dt)end end or nil
 end
 function ctx:SetInputHandler(f)self.input=f end
 function ctx:SetShowHideHandler(f)self.showHide=f end
 function ctx:SetShutdown(f)self.shutdown=f end
 function ctx:SetInitHandler(f)end
 function ctx:BuildInstanceForControl(kind,result,parent)
  result.Root=control();result.ClockText=control();result.UnitIcon=control()
  parent.children[#parent.children+1]=result.Root
 end
 return ctx
end
local function members(items)
 return {Members=function()local i=0;return function()i=i+1;if items[i]then return i,items[i]end end end}
end
local function unit(id,kind,x)
 return {GetID=function()return id end,GetOwner=function()return 0 end,GetType=function()return kind end,
 GetX=function()return x end,GetY=function()return 0 end}
end
local units={unit(1,0,0),unit(2,1,0),unit(3,0,9),unit(5,0,1)}
local capitalX=0
local city={GetID=function()return 1 end,GetX=function()return capitalX end,GetY=function()return 0 end,GetName=function()return'Capital'end,
 GetBuildQueue=function()return {GetSize=function()return 0 end,CanProduce=function()return true end}end,
 GetBuildings=function()return {HasBuilding=function()return true end}end}
local props={PARADE_V3_END=20,PARADE_V3_TIER=3,PARADE_V3_SCORE=500,
 PARADE_V35_QUOTE=1,PARADE_V35_CITY=1,PARADE_V35_TURN=10,PARADE_V35_COUNT=1}
local p={GetProperty=function(_,k)if props[k]==nil then return end;return props[k]end,
 GetCities=function()local cs=members({city});cs.FindID=function(_,id)if id==1 then return city end end;cs.GetCapitalCity=function()return city end;return cs end,
 GetUnits=function()local list=members(units);list.FindID=function(_,id)for _,u in ipairs(units)do if u:GetID()==id then return u end end end;return list end,GetCulture=function()return {HasCivic=function()return true end}end}
local now=10;local gi={Projects={PROJECT_MILITARY_PARADE={Index=7,Hash=777,ProjectType='PROJECT_MILITARY_PARADE'}},
 Buildings={BUILDING_PARADE_ELIGIBLE={Index=10}},Civics={CIVIC_EARLY_EMPIRE={Index=99}},
 Units={[0]={Combat=20,UnitType='UNIT_WARRIOR',Name='Warrior'},[1]={Combat=0,UnitType='UNIT_BUILDER',Name='Builder'}},
 ParadeQuotes={[1]={QuoteText='Quote one',Attribution='Source one'},[2]={QuoteText='Quote two',Attribution='Source two'}}}
local quoteRows={{QuoteID=1,QuoteText='Quote one',Attribution='Source one'},{QuoteID=2,QuoteText='Quote two',Attribution='Source two'}}
-- Deliberately omit numeric indexing: custom tables are queried by QuoteID.
gi.ParadeQuotes=function()local i=0;return function()i=i+1;return quoteRows[i]end end
gi.ParadeTiers=function()local done=false;return function()if not done then done=true;return{Tier=3,Combat=3,Loyalty=8,Amenities=1}end end end
local exposed={ParadeV3Gameplay={Ready=true}}
local autoRequests={}
exposed.ParadeV316Timeline={Ready=true,RequestAuto=function(owner,count)
 assert(owner==0);autoRequests[#autoRequests+1]=count;return true
end,Pump=function()end}
local inputDepth=0;local queued=0;local sounds=0
local uiContext=context();local uiControls=controls("Parade_UI");local popupContext=context();local popupControls=controls("Parade_Celebration")
local zoom=.55
local lastFocus=nil
local screenFocusCalls=0
local nearFocusCalls=0
local worldFocusCalls=0
local renderView=2
local worldX,worldY=1210,3420
local panX,panY=0,0
local selectionRebuilds=0
local spins={}
local soundNames={}
local stopped=0
local loads=0
local pauses=0;local resumes=0;local sealSounds=0
local cameraYaw=0
local deferredYaw=nil
local hud={}
for _,key in ipairs({'EdgeScroll','HUD','TopLevelHUD','PartialScreens','WorldViewControls'})do hud['/InGame/'..key]=control()end
hud['/InGame/PartialScreens'].hidden=true
for _,key in ipairs({'BannerAndFlags','WorldViewIconsManager','DistrictPlotIconManager','PlotInfo','MapPinManager','TourismBannerManager'})do
 hud['/InGame/WorldViewControls/'..key]=control()
end
local selectedUnit=units[3]
local selectedCalls=0
function popupContext:LookUpControl(path)return hud[path]end
local common={Game={GetLocalPlayer=function()return 0 end,GetCurrentGameTurn=function()return now end},GameInfo=gi,Players={[0]=p},
 ExposedMembers=exposed,Events=events,LuaEvents=luaevents,Mouse={eLClick=1},Keys={VK_ESCAPE=27},KeyEvents={KeyUp=1,KeyDown=2},PopupPriority={High=10},
 WorldRenderView={VIEW_2D=2,VIEW_3D=3},InputContext={Reveal=1},Input={PushActiveContext=function()inputDepth=inputDepth+1 end,PopContext=function()inputDepth=inputDepth-1;assert(inputDepth>=0)end},
 UI={LoadSoundBankGroup=function(group)assert(group==5);loads=loads+1 end,PlaySound=function(name)
  if name=='ALERT_POSITIVE' then sealSounds=sealSounds+1
  elseif name=='Pause_MilitaryParade_Background_V311' then pauses=pauses+1
  elseif name=='Resume_MilitaryParade_Background_V311' then resumes=resumes+1
  elseif name=='Stop_MilitaryParade_Internationale_V311' then stopped=stopped+1
  else sounds=sounds+1;soundNames[#soundNames+1]=name end
 end,
 LookAtPlot=function(x,y,z,duration,instant)
  assert(cameraYaw==0,'focus command rebased a rotated camera');lastFocus={x,y};worldX=x*100+10;worldY=y*100+20
  if z then assert(duration==0 and instant==true);nearFocusCalls=nearFocusCalls+1;zoom=z end
 end,
 GridToWorld=function(x,y)return x*100+10,y*100+20,0 end,
 LookAtPosition=function(wx,wy,instant)
  assert(instant==true and cameraYaw==0);worldX=wx;worldY=wy
  lastFocus={(wx-10)/100,(wy-20)/100};worldFocusCalls=worldFocusCalls+1
 end,
 PanMap=function(x,y)panX=x;panY=y end,
 GetWorldRenderView=function()return renderView end,
 SetWorldRenderView=function(view)renderView=view end,
 LookAtPlotScreenPosition=function(x,y,sx,sy)
  assert(cameraYaw==0,'screen focus rebased a rotated camera')
  assert(sx==.5 and sy==.42);screenFocusCalls=screenFocusCalls+1;lastFocus={x,y}
 end,
 RebuildSelectionList=function(u)assert(u==selectedUnit);selectionRebuilds=selectionRebuilds+1 end,
 GetHeadSelectedUnit=function()return selectedUnit end,GetHeadSelectedCity=function()return nil end,
 DeselectAllUnits=function()selectedUnit=nil end,DeselectAllCities=function()end,
 SelectUnit=function(u)selectedUnit=u;selectedCalls=selectedCalls+1 end,SetCycleAdvanceTimer=function()end,
 GetMapZoom=function()return zoom end,SetMapZoom=function(v)zoom=v end,
 GetMapLookAtWorldTarget=function()return worldX,worldY end,GetPlotCoordFromWorld=function(x,y)return (x-10)/100,(y-20)/100 end,
 SpinMap=function(x,y)cameraYaw=x;spins[#spins+1]=x end},
 UIManager={QueuePopup=function(_,ctx)queued=queued+1;ctx:SetHide(false)end,DequeuePopup=function(_,ctx)ctx:SetHide(true)end},
 Map={GetPlotDistance=function(x,y,x2,y2)return math.abs(x-x2)+math.abs(y-y2)end},
 Locale={Lookup=function(k,...)return k..' '..table.concat({...},',')end},include=function()end}
setmetatable(common,{__index=_G})
local popupEnv=setmetatable({ContextPtr=popupContext,Controls=popupControls},{__index=common})
popupEnv.include=function(file)
 if file=='Parade_Camera.lua' or file=='Parade_Audio.lua'then assert(loadfile(root..'/'..file,'t',popupEnv))()end
end
assert(loadfile(root..'/Parade_Celebration.lua','t',popupEnv))()
assert(popupControls.CapitalName==nil,'obsolete control exists in strict fixture')
local oldOK=pcall(function()popupControls.CapitalName:SetText('old bug')end)
assert(not oldOK,'the old nil-control error did not reproduce')
local uiEnv=setmetatable({ContextPtr=uiContext,Controls=uiControls},{__index=common})
assert(uiContext.hidden,'fixture must reproduce InGame hidden=true loader')
assert(loadfile(root..'/Parade_UI.lua','t',uiEnv))()
assert(not uiContext.hidden,'transparent controller remains hidden after native loading')
local function SettleCamera()for _=1,12 do uiContext.update(.1)end end
local function Complete(count,score,status)
 props.PARADE_V35_COUNT=count;props.PARADE_V313_ERA_SCORE=score;props.PARADE_V313_ERA_STATUS=status
 uiContext.update(.6)
end
uiContext.update(.6);assert(queued==0,'reloaded completion auto-replayed')
Complete(2,2,1)
assert(queued==1 and inputDepth==1 and not popupContext.hidden)
assert(sounds==1 and pauses==1)
assert(popupControls.CeremonyPanel.hidden and popupControls.EraMomentPanel.hidden)
-- Reproduce another UI's queued selection stealing the focus after opening.
selectedUnit=units[3];lastFocus={9,0}
popupContext.update(.4);assert(zoom>0 and zoom<.55)
assert(lastFocus[1]==0 and lastFocus[2]==0 and selectedUnit:GetID()==1)
assert(worldFocusCalls>=2 and screenFocusCalls==0 and selectionRebuilds>=2,'instant world focus not used')
assert(renderView==3 and hud['/InGame/EdgeScroll'].hidden and panX==0 and panY==0,'edge scrolling or strategic view left active')
popupContext.update(3);popupContext.update(2);assert(cameraYaw==0 and selectedUnit:GetID()==1 and zoom==0,'fixed close-up drifted or zoom remained wide')
selectedUnit=units[3];worldX=910;worldY=20;panX=1;zoom=.8
popupContext.update(.3)
assert(selectedUnit:GetID()==1 and lastFocus[1]==0 and zoom==0 and panX==0,'late selection/pan/zoom not recovered')
popupControls.ReplayCamera.click();assert(cameraYaw==0)
popupContext.update(3.4);popupContext.update(3);popupContext.update(4.2)
assert(cameraYaw==0,'review did not return before declaration')
popupContext.update(.5);assert(not popupControls.QuoteText.hidden and popupControls.AwardText.hidden)
popupContext.update(5.1);assert(not popupControls.EraMomentPanel.hidden and sealSounds==1)
assert(popupControls.EraMomentTitle.text:find('LOC_PARADE_ERA_FIRST_TITLE',1,true))
popupContext.update(3.8);assert(popupContext.update==nil)
assert(popupContext.hidden and inputDepth==0,'completed awarded review did not automatically hand off to history')
-- Reproduce the v3.12 deadlock: camera completion never reports ready.
local oldRestoring=exposed.ParadeV38UI.IsCameraRestoring
exposed.ParadeV38UI.IsCameraRestoring=function()return true end
popupControls.CloseCelebration.click()
assert(popupContext.hidden and inputDepth==0,'finished ceremony cannot close without camera pump')
exposed.ParadeV38UI.IsCameraRestoring=oldRestoring
assert(cameraYaw==0)
SettleCamera();assert(zoom==.55 and selectedUnit:GetID()==3)
assert(lastFocus[1]==12 and lastFocus[2]==34)
assert(renderView==2 and not hud['/InGame/EdgeScroll'].hidden,'render mode/edge scrolling did not restore')
for _,value in ipairs(spins)do assert(value==0,'fixed view issued a simulated drag rotation')end
assert(#autoRequests==1 and autoRequests[1]==2,'awarded completion did not queue its timeline on close')
print('PASS: closing after final frame does not wait on camera bridge; hidden immediately and input released')

exposed.ParadeV38UI.IsCameraRestoring=function()return true end
Complete(3,0,0)
assert(not popupContext.hidden and inputDepth==1,'new completion blocked on stale camera restore flag')
exposed.ParadeV38UI.IsCameraRestoring=oldRestoring
popupControls.SkipCeremony.click()
assert(not popupControls.EraAward.hidden and popupControls.EraMomentPanel.hidden)
assert(popupControls.EraAward.text:find('LOC_PARADE_ERA_ALREADY',1,true))
popupContext.input({GetMessageType=function()return 1 end,GetKey=function()return 27 end})
assert(popupContext.hidden and inputDepth==0,'ESC did not immediately close')
popupControls.CloseX.click();assert(inputDepth==0,'repeated close unbalanced input')
SettleCamera()
assert(#autoRequests==1,'zero-score/repeated close queued a timeline')

props.PARADE_V38_GENERAL=1;props.PARADE_V312_GENERAL_NAME='LOC_TEST_HANNIBAL'
Complete(4,1,2)
popupContext.update(3.4);popupContext.update(2);assert(cameraYaw==0)
popupControls.SoundTest.click();uiContext.update(.13)
popupControls.SkipCeremony.click()
assert(not popupControls.EraMomentPanel.hidden)
assert(popupControls.EraMomentTitle.text:find('LOC_PARADE_ERA_REPEAT_TITLE',1,true))
assert(popupControls.EraMomentBody.text:find('LOC_PARADE_ERA_GENERAL_BODY',1,true))
assert(popupControls.EraMomentSignature.text:find('LOC_TEST_HANNIBAL',1,true))
popupControls.CloseX.click();assert(popupContext.hidden and inputDepth==0)
local afterCloseSounds=sounds
popupControls.ReplayCamera.click();popupControls.SoundTest.click()
assert(sounds==afterCloseSounds,'hidden ceremony accepted replay')
SettleCamera();assert(zoom==.55 and selectedUnit:GetID()==3)

-- Failure isolation: neither audio/camera exceptions nor dequeue errors may trap input.
Complete(5,0,0)
local cameraEnd=popupEnv.ParadeCamera.End
popupEnv.ParadeCamera.End=function()error('EXPECTED camera cleanup failure')end
popupControls.CloseX.click()
assert(popupContext.hidden and inputDepth==0,'camera error blocked close')
popupEnv.ParadeCamera.End=cameraEnd;cameraEnd();SettleCamera()
Complete(6,0,0)
local dequeue=common.UIManager.DequeuePopup
common.UIManager.DequeuePopup=function()error('EXPECTED dequeue failure')end
popupControls.CloseX.click();assert(popupContext.hidden and inputDepth==0,'dequeue failure bypassed hide fallback')
common.UIManager.DequeuePopup=dequeue;SettleCamera()

Complete(7,0,0);Complete(8,1,2)
local beforeQueue=queued
popupControls.CloseX.click();assert(popupContext.hidden and inputDepth==0)
uiContext.update(.01);assert(queued==beforeQueue+1 and inputDepth==1,'next scene waited on background camera cleanup')
popupControls.CloseX.click();assert(popupContext.hidden and inputDepth==0);SettleCamera()

-- A render failure must not consume the completion's presentation stamp.
local setText=popupControls.QuoteText.SetText
popupControls.QuoteText.SetText=function()error('EXPECTED render failure')end
Complete(9,0,0);assert(popupContext.hidden and inputDepth==0)
popupControls.QuoteText.SetText=setText
assert(exposed.ParadeV38Presentation.Show({Owner=0,Count=9,CityName='Capital',QuoteID=1,
 Score=500,Tier=3,Combat=3,Loyalty=8,Amenities=1,Ending=30,Turn=20,EraScore=0,EraStatus=0}))
popupControls.CloseX.click();SettleCamera()
assert(pauses==resumes,'close left background paused')
assert(uiControls.ParadeHistory==nil and exposed.ParadeV312History==nil)
print('PASS: first/repeat/general scrolls, duplicate-era status, skip/ESC/X, exception-safe close, queued scenes, render retry, no chronicle')

-- A transferred capital uses its own center garrison, even with an old-capital
-- warrior and an adjacent warrior still present. No fallback to those units.
capitalX=9
Complete(10,0,0);popupContext.update(.5)
assert(selectedUnit:GetID()==3 and lastFocus[1]==9,'relocated capital targeted the original capital unit')
popupControls.CloseX.click();SettleCamera();capitalX=0
local savedUnits=units;units={savedUnits[2],savedUnits[3],savedUnits[4]}
Complete(11,0,0);popupContext.update(.5)
assert(lastFocus[1]==0 and selectedUnit:GetID()==3,'missing garrison selected an adjacent or distant unit')
popupControls.CloseX.click();SettleCamera();units=savedUnits
-- Older API fallback remains available without the screen-position method.
local worldFocus=common.UI.LookAtPosition;common.UI.LookAtPosition=nil
Complete(12,0,0);popupContext.update(.5);assert(lastFocus[1]==0)
popupControls.CloseX.click();SettleCamera();common.UI.LookAtPosition=worldFocus
print('PASS: delayed selection override, relocated-capital garrison, no remote-unit fallback, legacy focus API')

-- Temporary renderer failures recover automatically; a failed count is not
-- suppressed until the player reloads the UI.
local realText=popupControls.QuoteText.SetText
popupControls.QuoteText.SetText=function()error('EXPECTED transient renderer failure')end
Complete(13,1,2);assert(popupContext.hidden)
popupControls.QuoteText.SetText=realText
uiContext.update(1.6)
assert(not popupContext.hidden and inputDepth==1,'automatic presentation retry failed')
popupControls.CloseX.click();SettleCamera()
assert(zoom==.55 and selectedUnit:GetID()==3)
print('PASS: transient display failure retries automatically and final close restores the original camera')

-- Accepted-but-queued celebrations must also survive a transient render error.
Complete(14,1,2);Complete(15,1,2)
popupControls.QuoteText.SetText=function()error('EXPECTED queued renderer failure')end
popupControls.CloseX.click();uiContext.update(.1)
assert(popupContext.hidden)
popupControls.QuoteText.SetText=realText
uiContext.update(1.6)
assert(not popupContext.hidden and inputDepth==1,'failed queued parade was discarded')
popupControls.CloseX.click();SettleCamera()
print('PASS: queued repeat animation retries instead of silently disappearing')

local expectedAuto={[2]=true,[4]=true,[8]=true,[13]=true,[14]=true,[15]=true}
assert(#autoRequests==6 and #toolbarRequests==0,'accepted native awards must not also toggle the screen')
for _,count in ipairs(autoRequests)do assert(expectedAuto[count],'replay/failed frame/duplicate close opened a timeline');expectedAuto[count]=nil end
print('PASS: positive-score close queues native timeline once; zero-score, rendering failures and duplicate close do not')

-- Build may omit the replacement script. The native toolbar entry must still
-- fire, instead of silently waiting forever for a missing extension bridge.
local timelineBridge=exposed.ParadeV316Timeline;exposed.ParadeV316Timeline=nil
Complete(16,1,2);popupContext.update(3.4)
zoom=.4 -- delayed selection/focus transition overrides the close-up request
popupContext.update(.3);assert(zoom==0,'late camera transition overwrote zoom permanently')
popupContext.update(.1);assert(exposed.MilitaryParadeDiagnostic.ZoomActual==0)
popupControls.CloseX.click();SettleCamera()
assert(#toolbarRequests==1,'missing extension stopped the compatibility stock timeline entry')
assert(uiControls.BuildStatus.text:find('3.20 B1',1,true))
assert(uiControls.BuildStatus.text:find('未加载',1,true),'missing timeline extension is not visible in the diagnostics')
exposed.ParadeV316Timeline=timelineBridge
print('PASS: native toolbar event without timeline bridge, visible Build identity, live zoom readback and late zoom override recovery')

-- Skip-to-award must keep the timer alive and hand off after four seconds.
Complete(17,1,2);popupControls.SkipCeremony.click()
assert(popupContext.update and not popupContext.hidden)
popupContext.update(4.1);assert(popupContext.hidden and inputDepth==0,'skip-to-award stranded the automatic timeline')
SettleCamera();assert(#toolbarRequests==1)
print('PASS: skip-to-award now reaches the same automatic history handoff')

-- Unit flag integration remains independent and read-only.
local flags={}
for _,u in ipairs(units)do flags[u:GetID()]={m_Instance={FlagRoot=control()},GetUnit=function()return u end}end
local flagEnv=setmetatable({UnitFlag={UpdateStats=function()end,destroy=function(self)self.destroyed=true end},
 GetUnitFlag=function(_,id)return flags[id]end},{__index=common})
assert(loadfile(root..'/Parade_UnitFlagManager.lua','t',flagEnv))()
luaevents.ParadeV38_RefreshClocks()
local badge=flags[1].m_Instance.ParadeClock
assert(badge and badge.ClockText.text=='[ICON_Turn]10'and not badge.Root.hidden)
assert(not flags[2].m_Instance.ParadeClock)
now=20;luaevents.ParadeV38_RefreshClocks();assert(badge.Root.hidden)
flagEnv.UnitFlag.destroy(flags[1]);assert(badge.Root.destroyed)
print('PASS: military clock, civilian exclusion, expiry and cleanup')
