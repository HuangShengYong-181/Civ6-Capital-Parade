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
local lastDiagnostic=''
local function EligibilityStatus(player)
    if not project then return 'LOC_PARADE_DATA_MISSING' end
    local civic=GameInfo.Civics['CIVIC_EARLY_EMPIRE']
    local permit=GameInfo.Buildings['BUILDING_PARADE_ELIGIBLE']
    local capital=player:GetCities():GetCapitalCity()
    local hasCivic=civic and player:GetCulture():HasCivic(civic.Index) or false
    if not capital then return 'LOC_PARADE_NEED_CAPITAL' end
    local hasMilitary=false
    for _,unit in player:GetUnits():Members() do
        local row=GameInfo.Units[unit:GetType()]
        if row and ((row.Combat or 0)>0 or (row.RangedCombat or 0)>0)
            and unit:GetX()==capital:GetX() and unit:GetY()==capital:GetY() then
            hasMilitary=true;break
        end
    end
    local hasPermit=permit and capital:GetBuildings():HasBuilding(permit.Index) or false
    local canProduce=false
    if project and project.Hash then
        local ok,value=pcall(function() return capital:GetBuildQueue():CanProduce(project.Hash,false) end)
        canProduce=ok and value or false
    end
    local xp2=GameInfo.Projects_XP2 and GameInfo.Projects_XP2[project.ProjectType] or nil
    local diag='capital='..tostring(capital:GetID())..' civic='..tostring(hasCivic)
        ..' ownGarrison='..tostring(hasMilitary)..' permit='..tostring(hasPermit)
        ..' canProduce='..tostring(canProduce)..' xp2Required='..tostring(xp2 and xp2.RequiredBuilding)
    if diag~=lastDiagnostic then print('[ParadeV38][UI] GATE '..diag);lastDiagnostic=diag end
    if not hasCivic then return 'LOC_PARADE_NEED_CIVIC' end
    if not hasMilitary then return 'LOC_PARADE_NEED_GARRISON' end
    if not hasPermit then return 'LOC_PARADE_WAIT_PERMIT' end
    if not canProduce then return 'LOC_PARADE_ENGINE_BLOCKED' end
    local general=GameInfo.Buildings['BUILDING_PARADE_GENERAL']
    if general and capital:GetBuildings():HasBuilding(general.Index) then return 'LOC_PARADE_AVAILABLE_GENERAL' end
    return 'LOC_PARADE_AVAILABLE'
end
local function UpdateStatus()
    if presentationHidden then Controls.ParadeStatus:SetHide(true);return end
    local bridge=ExposedMembers.ParadeV3Gameplay
    if not bridge or not bridge.Ready then Controls.ParadeStatus:SetHide(true);return end
    CheckIcons()
    local id=Game.GetLocalPlayer()
    if type(id)~='number' or id<0 then Controls.ParadeStatus:SetHide(true);return end
    local player=Players[id]
    if not player then Controls.ParadeStatus:SetHide(true);return end
    local endValue=player:GetProperty('PARADE_V3_END')
    local tierValue=player:GetProperty('PARADE_V3_TIER')
    local ending=tonumber(endValue) or -1
    local tier=tonumber(tierValue) or 0
    local remaining=ending-Game.GetCurrentGameTurn()
    if remaining<=0 or tier<=0 then
        Controls.ParadeStatus:SetText(Locale.Lookup(EligibilityStatus(player)))
        Controls.ParadeStatus:SetHide(false);return
    end
    for row in GameInfo.ParadeTiers() do
        if row.Tier==tier then
            Controls.ParadeStatus:SetText(Locale.Lookup('LOC_PARADE_ACTIVE_STATUS',
                remaining,row.Loyalty,row.Combat,row.Amenities))
            Controls.ParadeStatus:SetHide(false)
            return
        end
    end
end
-- Cancel every queued parade when the actual city conditions fail. UI uses
-- the same native BUILD / VALUE_REMOVE_AT operation as ProductionHelper.lua.
-- Never call Gameplay mutation closures across ExposedMembers.
local cleaning=false
local function CleanInvalidQueue()
    local bridge=ExposedMembers.ParadeV3Gameplay
    if cleaning or not bridge or not bridge.Ready or not project then return end
    local id=Game.GetLocalPlayer()
    if type(id)~='number' or id<0 then return end
    local player=Players[id]
    if not player then return end
    local civic=GameInfo.Civics['CIVIC_EARLY_EMPIRE']
    local capital=player:GetCities():GetCapitalCity()
    local unlocked=civic and player:GetCulture():HasCivic(civic.Index)
    cleaning=true
    local ok,err=pcall(function()
        for _,city in player:GetCities():Members() do
            local allowed=unlocked and capital and city:GetID()==capital:GetID()
            local garrison=false
            if allowed then
                for _,unit in player:GetUnits():Members() do
                    local row=GameInfo.Units[unit:GetType()]
                    if row and ((row.Combat or 0)>0 or (row.RangedCombat or 0)>0)
                        and unit:GetX()==city:GetX() and unit:GetY()==city:GetY() then
                        garrison=true;break
                    end
                end
            end
            if not allowed or not garrison then
                local queue=city:GetBuildQueue()
                -- Reverse order preserves indices; other production is untouched.
                for i=queue:GetSize()-1,0,-1 do
                    local entry=queue:GetAt(i)
                    local row=entry and entry.ProjectType~=nil and GameInfo.Projects[entry.ProjectType]
                    if row and row.ProjectType==project.ProjectType then
                        local params={}
                        params[CityOperationTypes.PARAM_INSERT_MODE]=CityOperationTypes.VALUE_REMOVE_AT
                        params[CityOperationTypes.PARAM_QUEUE_LOCATION]=i
                        CityManager.RequestOperation(city,CityOperationTypes.BUILD,params)
                        print('[ParadeV38][UI] REMOVE invalid parade city='..city:GetID()..' slot='..i)
                    end
                end
            end
        end
    end)
    cleaning=false
    if not ok then print('[ParadeV38][UI] QUEUE ERROR: '..tostring(err)) end
end
local function Refresh()
    CleanInvalidQueue()
    UpdateStatus()
end
local function OnCompleted(playerID,cityID,projectID,buildingIndex,x,y,cancelled)
    if project and (projectID==project.Index or projectID==project.Hash or projectID==project.ProjectType) then
        print('[ParadeV38][UI] Project completion reported, player='..tostring(playerID))
    end
    UpdateStatus()
end
Events.CityProjectCompleted.Add(OnCompleted)
for _,name in ipairs({'LoadGameViewStateDone','PlayerTurnActivated','TurnBegin',
    'UnitMoved','UnitMoveComplete','UnitTeleported','UnitAddedToMap','UnitRemovedFromMap',
    'CityUnitsChanged','CapitalCityChanged','PlayerTurnDeactivated','CityProductionChanged','CivicCompleted','CitySelectionChanged','CityProductionUpdated','BuildingAddedToMap','BuildingRemovedFromMap'}) do
    if Events[name] then Events[name].Add(Refresh) end
end
-- Paired XML/Lua contexts are loaded by AddUserInterfaces.
ContextPtr:SetInitHandler(function()
    -- InGame.Initialize loads EVERY AddUserInterfaces context hidden=true.
    -- This is a transparent controller, not a popup. Keep its update loop alive.
    ContextPtr:SetHide(false)
    Refresh()
end)
Refresh()
print('[ParadeV38][UI] READY military-score bridge')

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
    return '3.20 B1 | 数据 '..db..' | 年表扩展 '..hook..' | '..(diagnostic.Stage or '待阅兵')..(diagnostic.ZoomActual and (' | 检阅缩放 '..string.format('%.4f',diagnostic.ZoomActual)) or '')
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
    if not hidden then UpdateStatus() end
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
    return {Owner=id,Count=count,CityID=number('PARADE_V35_CITY',-1),
        CityName=textProperty('PARADE_V312_CITY_NAME')~='' and Locale.Lookup(textProperty('PARADE_V312_CITY_NAME')) or (city and Locale.Lookup(city:GetName()) or Locale.Lookup('LOC_PARADE_FORMER_CAPITAL')),
        EraName=textProperty('PARADE_V312_ERA_NAME'),GeneralName=textProperty('PARADE_V312_GENERAL_NAME'),
        X=city and city:GetX(),Y=city and city:GetY(),Score=number('PARADE_V3_SCORE',0),
        Tier=tier,Loyalty=row.Loyalty,Combat=row.Combat,Amenities=row.Amenities,
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
    if observedCount==nil then observedCount=count;print('[ParadeV38][UI] BASELINE count='..count) end
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
