-- UI context. The military-strength API is UI-only.
print('[ParadeV38][UI] BOOT')
local presentationHidden=false
local project=GameInfo.Projects['PROJECT_MILITARY_PARADE']
ExposedMembers.ParadeV3UI={}
function ExposedMembers.ParadeV3UI.GetMilitaryScore(playerID)
    local player=Players[playerID]
    if not player then error('Unknown player '..tostring(playerID)) end
    local stats=player:GetStats()
    if not stats.GetMilitaryStrengthWithoutTreasury then
        error('GetMilitaryStrengthWithoutTreasury unavailable in UI')
    end
    return stats:GetMilitaryStrengthWithoutTreasury()
end
-- GetSize/GetAt are UI-only. Return primitives across the bridge.
function ExposedMembers.ParadeV3UI.GetActiveParade(playerID)
 local p=Players[playerID];if not p then return end
 for _,c in p:GetCities():Members() do
  local kind=ParadeRules.ActiveProject(c)
  if kind then return c:GetID(),ParadeRules.Project(kind) end
 end
end
function ExposedMembers.ParadeV3UI.GetFacilities(playerID,cityID)
 local p=Players[playerID];local city=p and p:GetCities():FindID(cityID)
 if city then return ParadeRules.Facilities(city) end
end
local iconsChecked=false
local function CheckIcons()
    if iconsChecked or not IconManager then return end
    iconsChecked=true
    for _,name in ipairs({'ICON_PROJECT_MILITARY_PARADE','ICON_PROJECT_MILITARY_PARADE_COLOR'}) do
        for _,size in ipairs({22,30,32,38,50}) do
            local ok,x,y,sheet=pcall(function() return IconManager:FindIconAtlas(name,size) end)
            print('[ParadeV38][ICON] '..name..' size='..size..' found='..tostring(ok and sheet~=nil)
                ..' texture='..tostring(sheet)..' x='..tostring(x)..' y='..tostring(y))
        end
    end
end
include('Parade_Rules.lua')
local R=ParadeRules
local queueSyncPending=true
local queueSyncConfirmed=false
for _,name in ipairs({'CityProductionChanged','CityProductionUpdated','CityProductionCompleted','CityProjectCompleted','LoadGameViewStateDone','PlayerTurnActivated'}) do
 if Events[name] then Events[name].Add(function()queueSyncPending=true;queueSyncConfirmed=false end) end
end
-- Only publish-complete can confirm a removed project as cancelled. It must
-- not dirty the queue itself, or REFRESH operations would send an endless loop.
if Events.GameCoreEventPublishComplete then Events.GameCoreEventPublishComplete.Add(function()
 if queueSyncPending then queueSyncConfirmed=true end
end) end
local function Refresh()
    local bridge=ExposedMembers.ParadeV3Gameplay
    if presentationHidden or not bridge or not bridge.Ready then Controls.ParadeStatus:SetHide(true);return end
    local id=Game.GetLocalPlayer();local p=id and id>=0 and Players[id]
    if not p then return end
    CheckIcons()
    local remaining=R.Number(p,'PARADE_V3_END',-1)-Game.GetCurrentGameTurn()
    local text=''
    if remaining>0 then text='阅兵鼓舞：剩余 '..remaining..' 回合'
    else
        local c=p:GetCities():GetCapitalCity()
        for _,kind in ipairs(R.Kinds) do local ok,reason=R.Legal(p,c,kind);if ok then text=R.Names[kind]..'可筹备 · '..reason;break end end
        if text=='' then text='阅兵：完成帝国初期，等待战事大捷、失城或强军里程碑' end
    end
    Controls.ParadeStatus:SetText(text);Controls.ParadeStatus:SetHide(false)
end
for _,name in ipairs({'LoadGameViewStateDone','PlayerTurnActivated','TurnBegin','UnitMoved','UnitAddedToMap','UnitRemovedFromMap','CityProductionChanged','CivicCompleted','CitySelectionChanged','GameCoreEventPublishComplete'}) do
    if Events[name] then Events[name].Add(Refresh) end
end
ContextPtr:SetInitHandler(function()ContextPtr:SetHide(false);Refresh()end)
Refresh()

-- Cleanup runs in this persistent UI context, including when the popup is hidden.
local cameraRestore=nil
local function ScheduleCameraRestore(snapshot)
    cameraRestore={Age=0,Step=1,Wait=0.3,Snapshot=snapshot}
end
local function CameraCleanupTick(dt)
    if not cameraRestore then return end
    local task=cameraRestore;task.Age=task.Age+dt
    local s=task.Snapshot
    -- Phase 1: stay on the review pivot and allow yaw to settle.
    if task.Step==1 and task.Age<task.Wait then pcall(UI.SpinMap,0,0);return end
    if task.Step==1 then
        pcall(function()
            UI.SpinMap(0,0)
            UI.DeselectAllUnits();UI.DeselectAllCities()
            if s.UnitOwner and s.UnitID then
                local player=Players[s.UnitOwner]
                local unit=player and player:GetUnits():FindID(s.UnitID)
                if unit then UI.SelectUnit(unit) end
            elseif s.CityOwner and s.CityID then
                local player=Players[s.CityOwner]
                local city=player and player:GetCities():FindID(s.CityID)
                if city then UI.SelectCity(city) end
            end
            if s.X and s.Y then UI.LookAtPlot(s.X,s.Y,s.Zoom or 0.45,0.0,true) end
            if s.Zoom then UI.SetMapZoom(s.Zoom,0,0) end
        end)
        task.Step=2;task.Wait=task.Age+0.3
        return
    end
    if task.Age>=task.Wait and task.Step==2 then
        if s.X and s.Y then pcall(UI.LookAtPlot,s.X,s.Y,s.Zoom or 0.45,0.0,true) end
        if s.Zoom then pcall(UI.SetMapZoom,s.Zoom,0,0) end
        pcall(UI.SpinMap,0,0);task.Step=3;task.Wait=task.Age+0.3
        return
    end
    if task.Step==3 and task.Age>=task.Wait then
        pcall(UI.SpinMap,0,0);cameraRestore=nil
        print('[ParadeV312][CAMERA] restore complete: yaw settled before selection/focus')
    end
end
-- A new completed parade must not wait on an old asynchronous restore flag.
local function FinishCameraRestoreNow()
    if not cameraRestore then return nil end
    local snapshot=cameraRestore.Snapshot
    cameraRestore=nil
    pcall(UI.SpinMap,0,0)
    if snapshot.X and snapshot.Y then pcall(UI.LookAtPlot,snapshot.X,snapshot.Y,snapshot.Zoom or 0.45,0.0,true) end
    if snapshot.Zoom then pcall(UI.SetMapZoom,snapshot.Zoom,0,0) end
    return snapshot
end
local diagnostic=ExposedMembers.MilitaryParadeDiagnostic or {}
ExposedMembers.MilitaryParadeDiagnostic=diagnostic
local function DiagnosticText()
    local db='?'
    if GameInfo.ParadeBuildInfo then
        for row in GameInfo.ParadeBuildInfo() do db=row.Version;break end
    end
    local hook=diagnostic.TimelineBuild or '未加载'
    return '2.0.5 | 数据 '..db..' | 年表扩展 '..hook..' | '..(diagnostic.Stage or '待阅兵')..(diagnostic.ZoomActual and (' | 检阅缩放 '..string.format('%.4f',diagnostic.ZoomActual)) or '')
end
local function UpdateDiagnostic()
    if Controls.BuildStatus then Controls.BuildStatus:SetText(DiagnosticText()) end
end
local pendingAwardTimelines={}
local queuedAwardTimelines={}
local function QueueAwardTimeline(data)
    if type(data)~='table' or data.Replay or (data.EraScore or 0)<=0 then return end
    local key=tostring(data.Owner)..':'..tostring(data.Count)
    if queuedAwardTimelines[key] then return end
    queuedAwardTimelines[key]=true
    pendingAwardTimelines[#pendingAwardTimelines+1]={Owner=data.Owner,Count=data.Count}
end
local function PumpAwardTimelines(dt)
    local presentation=ExposedMembers.ParadeV38Presentation
    if presentation and presentation.IsActive and presentation.IsActive() then return end
    -- Finish the map restore before the native full-screen timeline takes input.
    if cameraRestore then return end
    local timeline=ExposedMembers.ParadeV316Timeline
    if #pendingAwardTimelines>0 then
        local data=pendingAwardTimelines[1]
        local suppressed=Options and Options.GetAppOption and Options.GetAppOption('Debug','SuppressInfoPopups')==1
        local accepted=false
        if timeline and timeline.Ready then
            local ok,result=pcall(timeline.RequestAuto,data.Owner,data.Count)
            accepted=ok and result==true
        end
        if suppressed then
            diagnostic.Stage='信息弹窗已禁用'
            table.remove(pendingAwardTimelines,1)
        elseif accepted then
            -- The extension calls stock ShowNewTimelineMoment itself. Do not
            -- additionally TOGGLE: toggling an open screen closes it again.
            diagnostic.Stage='等待原版年表显示 # '..data.Count
            table.remove(pendingAwardTimelines,1)
        else
            -- Compatibility fallback when another mod replaced the extension.
            diagnostic.TimelineCount=data.Count
            local ok,err=pcall(function()LuaEvents.PrideMoments_ToggleTimeline(false)end)
            if ok then
                diagnostic.Stage='已发原版年表入口 # '..data.Count
                table.remove(pendingAwardTimelines,1)
            else
                diagnostic.Stage='原版入口失败: '..tostring(err)
            end
        end
    end
    if timeline and timeline.Pump then
        local ok,err=pcall(timeline.Pump,dt)
        if not ok then diagnostic.Stage='年表处理失败: '..tostring(err) end
    end
end
-- Presentation bridge stays in UI. Gameplay publishes only saved properties.
ExposedMembers.ParadeV38UI={ScheduleCameraRestore=ScheduleCameraRestore,FinishCameraRestoreNow=FinishCameraRestoreNow,QueueAwardTimeline=QueueAwardTimeline,DiagnosticText=DiagnosticText,
    IsCameraRestoring=function()return cameraRestore~=nil end,
    CancelCameraRestore=function()cameraRestore=nil end,SetPresentationHidden=function(hidden)
    presentationHidden=hidden
    Controls.ParadeStatus:SetHide(hidden)
    if not hidden then Refresh() end
end,BuildClock=function(parent)
    local badge={}
    ContextPtr:BuildInstanceForControl('ParadeClockInstance',badge,parent)
    return badge
end}
local observedCount=nil
local lastWaitingCount=nil
local lastFailedCount=nil
local presentationClock=0
local retryAfter=0
local function ReadPresentation(player,id)
    local function number(key,default)
        local value=player:GetProperty(key)
        return tonumber(value) or default
    end
    local function textProperty(key)
        local value=player:GetProperty(key)
        return type(value)=='string' and value or ''
    end
    local count=number('PARADE_V35_COUNT',0)
    if count<=0 then return nil end
    local city=player:GetCities():FindID(number('PARADE_V35_CITY',-1))
    local tier=number('PARADE_V3_TIER',0)
    local row=nil
    for t in GameInfo.ParadeTiers() do if t.Tier==tier then row=t;break end end
    if not row then return nil end
    return {GiftSession=number('PARADE2_COMPLETED_SESSION',-1),Kind=textProperty('PARADE2_COMPLETED_KIND'),Size=number('PARADE2_COMPLETED_SIZE',0),Scale=number('PARADE2_SCALE',0),Cost=number('PARADE2_COMPLETED_COST',0),Owner=id,Count=count,CityID=number('PARADE_V35_CITY',-1),
        CityName=textProperty('PARADE_V312_CITY_NAME')~='' and Locale.Lookup(textProperty('PARADE_V312_CITY_NAME')) or (city and Locale.Lookup(city:GetName()) or Locale.Lookup('LOC_PARADE_FORMER_CAPITAL')),
        EraName=textProperty('PARADE_V312_ERA_NAME'),GeneralName=textProperty('PARADE_V312_GENERAL_NAME'),
        X=city and city:GetX(),Y=city and city:GetY(),Score=number('PARADE_V3_SCORE',0),
        Tier=tier,Loyalty=row.Loyalty+number('PARADE2_SCALE',0),Combat=row.Combat,Amenities=row.Amenities+(number('PARADE2_SCALE',0)>=3 and 1 or 0),
        QuoteID=number('PARADE_V35_QUOTE',1),Turn=number('PARADE_V35_TURN',0),
        Ending=number('PARADE_V3_END',-1),GeneralReviewed=number('PARADE_V38_GENERAL',0)==1,
        BaseTier=number('PARADE_V38_BASE_TIER',tier),GeneralPoints=number('PARADE_V38_GENERAL_POINTS',0),
        EraScore=number('PARADE_V313_ERA_SCORE',0),EraStatus=number('PARADE_V313_ERA_STATUS',3)}
end
local function CheckPresentation()
    local bridge=ExposedMembers.ParadeV3Gameplay
    if not bridge or not bridge.Ready then return end
    local id=Game.GetLocalPlayer()
    if type(id)~='number' or id<0 or not Players[id] then return end
    local data=ReadPresentation(Players[id],id)
    local count=data and data.Count or 0
    -- Establish a load baseline: reopening a save never replays old completions.
    if observedCount==nil then
        observedCount=count;print('[ParadeV38][UI] BASELINE count='..count)
        -- The temporary cinematic movement flag is UI-local; after loading use
        -- the player's saved menu preference instead of retaining the override.
        if count>0 and UserConfiguration and UserConfiguration.SetValue and Options and Options.GetUserOption then
            local ok,pref=pcall(Options.GetUserOption,'Gameplay','QuickMovement')
            local flag=(pref==true or pref==1 or pref=='1') and 1 or ((pref==false or pref==0 or pref=='0') and 0 or nil)
            if ok and flag~=nil then pcall(UserConfiguration.SetValue,'QuickMovement',flag) end
        end
        local diplomacy=ExposedMembers.ParadeV2UI
        if data and data.Kind=='STRENGTH' and data.GiftSession>ParadeRules.Number(Players[id],'PARADE2_GIFT_SUMMARY_ACK',-1) and diplomacy and diplomacy.ShowGifts then
            pcall(diplomacy.ShowGifts,data)
        end
    end
    if count>observedCount then
        local presentation=ExposedMembers.ParadeV38Presentation
        if presentation and presentation.Ready and presentation.Show then
            if lastFailedCount~=count or presentationClock>=retryAfter then
                print('[ParadeV38][UI] PRESENT count='..count)
                local ok,accepted=pcall(presentation.Show,data)
                if ok and accepted==true then
                    observedCount=count
                    lastFailedCount=nil
                else
                    lastFailedCount=count
                    retryAfter=presentationClock+1.5
                    print('[ParadeV38][UI] PRESENT FAILED count='..count..' detail='..tostring(accepted)..'; automatic retry in 1.5 seconds')
                end
            end
        elseif lastWaitingCount~=count then
            lastWaitingCount=count
            print('[ParadeV38][UI] WAIT PRESENTATION count='..count..'; celebration context not ready')
        end
    end
end
local presentationTimer=0
ContextPtr:SetUpdate(function(dt)
    presentationClock=presentationClock+dt
    if queueSyncPending and queueSyncConfirmed and ExposedMembers.ParadeV3Gameplay and ExposedMembers.ParadeV3Gameplay.Ready then
        queueSyncPending=false;queueSyncConfirmed=false
        UI.RequestPlayerOperation(Game.GetLocalPlayer(),PlayerOperations.EXECUTE_SCRIPT,{OnStart='Parade2Action',Action='REFRESH',ConfirmQueue=1})
    end
    UpdateDiagnostic()
    CameraCleanupTick(dt)
    local presentation=ExposedMembers.ParadeV38Presentation
    if presentation and presentation.Pump then presentation.Pump(dt) end
    PumpAwardTimelines(dt)
    local audio=ExposedMembers.ParadeV311Audio
    if audio and audio.Tick then audio.Tick(dt) end
    presentationTimer=presentationTimer+dt
    if presentationTimer<0.5 then return end
    presentationTimer=0
    CheckPresentation()
    LuaEvents.ParadeV38_RefreshClocks()
end)
if Events.PlayerTurnActivated then Events.PlayerTurnActivated.Add(CheckPresentation) end
if Events.GameCoreEventPublishComplete then Events.GameCoreEventPublishComplete.Add(CheckPresentation) end

if Events.CityProjectCompleted then Events.CityProjectCompleted.Add(CheckPresentation) end

-- AddUserInterfaces defaults to hidden in the actual InGame loader. Merely
-- supplying Hidden="0" in XML is insufficient: the loader passes hidden=true.
ContextPtr:SetHide(false)
