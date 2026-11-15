-- UI-only review: native plot+zoom shot, then rendered-model tracking.
ParadeCamera={Duration=24,Zoom=0.2,Approach=1.25}
local saved=nil
local hidden={}
local target=nil
local focusX,focusY=nil,nil
local focusRequested=false
local stableFrames=0
local retryAt=0
local motionLockAt=nil
local nextFocus=0
local nextSelection=0
local lastElapsed=0
local approachStart=0
local approachZoom=0.45
local function Call(name,...)
    if type(UI[name])~='function' then return false end
    local ok,a,b=pcall(UI[name],...)
    if not ok then print('[ParadeV38][CAMERA] '..name..' ERROR: '..tostring(a)) end
    return ok,a,b
end
local function HideControl(path)
    local control=ContextPtr:LookUpControl(path)
    if control then
        hidden[#hidden+1]={Control=control,WasHidden=control:IsHidden()}
        control:SetHide(true)
    end
end
-- Native LookAtPlot accepts the desired zoom as its third argument. Issue
-- this after selection callbacks have settled, once per shot, rather than
-- continually restarting independent position/zoom transitions every frame.
local function RequestShot()
 if not target or not target.X or not target.Y then return end
 local ok=Call('LookAtPlot',target.X,target.Y,ParadeCamera.Zoom)
 if not ok then Call('SetMapZoom',ParadeCamera.Zoom,0,0) end
 focusRequested=true;retryAt=lastElapsed+0.5
 focusX=target.WorldX;focusY=target.WorldY
 print('[Parade2][CAMERA] native shot unit='..tostring(target.ID)..' xy='..target.X..','..target.Y..' zoom='..ParadeCamera.Zoom)
end
local function FollowModel()
 if not target or not target.Simulated or not target.WorldX then return end
 if focusX~=target.WorldX or focusY~=target.WorldY then
  Call('LookAtPosition',target.WorldX,target.WorldY,true)
  focusX=target.WorldX;focusY=target.WorldY
 end
end
local function SelectTarget()
    if not target or not target.Unit then return end
    Call('DeselectAllCities')
    Call('DeselectAllUnits')
    Call('SelectUnit',target.Unit)
    -- Match WorldInput's direct-click path; stop automatic selection advancing
    -- to some other ready unit after this project's production event.
    Call('RebuildSelectionList',target.Unit)
    Call('SetCycleAdvanceTimer',0)
end
function ParadeCamera.Begin(data)
    local restarting=saved~=nil
    if not restarting then
    local host=ExposedMembers.ParadeV38UI
    local resumed=nil
    if host and host.FinishCameraRestoreNow then resumed=host.FinishCameraRestoreNow()
    elseif host and host.CancelCameraRestore then host.CancelCameraRestore() end
    saved=resumed or {}
    if not resumed then
    local selectedOK,selected=Call('GetHeadSelectedUnit')
    if selectedOK and selected then saved.UnitOwner=selected:GetOwner();saved.UnitID=selected:GetID() end
    local cityOK,selectedCity=Call('GetHeadSelectedCity')
    if cityOK and selectedCity then saved.CityOwner=selectedCity:GetOwner();saved.CityID=selectedCity:GetID() end
    local ok,zoom=Call('GetMapZoom')
    if ok and type(zoom)=='number' then saved.Zoom=zoom end
    local viewOK,view=Call('GetWorldRenderView')
    if viewOK then saved.RenderView=view end
    local positioned,wx,wy=Call('GetMapLookAtWorldTarget')
    if positioned and type(wx)=='number' and type(wy)=='number' then
        local converted,x,y=Call('GetPlotCoordFromWorld',wx,wy)
        if converted then saved.X=x;saved.Y=y end
    end
    end
    end
    Call('SpinMap',0,0)
    Call('PanMap',0,0)
    -- These containers are distinct from AdditionalUserInterfaces, where this
    -- popup lives. Save each state; do not blindly unhide previously closed UI.
    -- Leave SelectedUnit's logic context active; hide only its visible neighbours.
    -- Selecting a unit follows the same native display path as clicking its flag.
    if not restarting then
    for _,path in ipairs({'/InGame/EdgeScroll','/InGame/HUD','/InGame/TopLevelHUD','/InGame/PartialScreens',
        '/InGame/WorldViewControls/BannerAndFlags','/InGame/WorldViewControls/WorldViewIconsManager',
        '/InGame/WorldViewControls/DistrictPlotIconManager','/InGame/WorldViewControls/PlotInfo',
        '/InGame/WorldViewControls/MapPinManager','/InGame/WorldViewControls/TourismBannerManager'}) do HideControl(path) end
    local host=ExposedMembers.ParadeV38UI
    if host and host.SetPresentationHidden then host.SetPresentationHidden(true) end
    end
    local candidates={}
    local player=Players[data.Owner]
    local capital=player and player:GetCities():GetCapitalCity()
    local cx=capital and capital:GetX();local cy=capital and capital:GetY()
    if capital then
        for _,r in ipairs(ParadeRules.Participants(player,capital)) do
            local unit=player:GetUnits():FindID(r.ID);local row=unit and GameInfo.Units[unit:GetType()]
            if row then candidates[#candidates+1]={Unit=unit,ID=r.ID,X=r.X,Y=r.Y,InCity=r.X==cx and r.Y==cy,Name=Locale.Lookup(row.Name)} end
        end
    end
    table.sort(candidates,function(a,b)
        local ag=a.InCity and ParadeRules.Branch(a.Unit)=='LAND';local bg=b.InCity and ParadeRules.Branch(b.Unit)=='LAND'
        if ag~=bg then return ag end;return a.ID<b.ID
    end)
    target=candidates[1] or {X=cx,Y=cy,InCity=true,
        Name=Locale.Lookup(capital and 'LOC_PARADE_FOCUS_NO_GARRISON' or 'LOC_PARADE_NEED_CAPITAL')}
    if target.X and target.Y then
        local converted,wx,wy=Call('GridToWorld',target.X,target.Y)
        if converted and type(wx)=='number' and type(wy)=='number' then
            target.WorldX=wx;target.WorldY=wy
        end
    end
    if saved.RenderView~=nil and WorldRenderView and WorldRenderView.VIEW_3D then
        Call('SetWorldRenderView',WorldRenderView.VIEW_3D)
    end
    focusX=nil;focusY=nil;nextFocus=0;nextSelection=0;lastElapsed=0;approachStart=0;approachZoom=math.max(ParadeCamera.Zoom,saved.Zoom or 0.45)
    saved.LastSpin=0
    SelectTarget()
    focusRequested=false;stableFrames=0;motionLockAt=nil
    print('[MilitaryParade][CAMERA] orbit-close-up owner='..tostring(data.Owner)..' capital='..tostring(capital and capital:GetID())..' xy='..tostring(cx)..','..tostring(cy)..' world='..tostring(target.WorldX)..','..tostring(target.WorldY)..' unit='..tostring(target.ID)..' zoom='..ParadeCamera.Zoom)
    return target.Name,target.InCity
end
function ParadeCamera.Tick(elapsed)
 if not saved or not target or not target.X or not target.Y then return end
 lastElapsed=elapsed
 if not focusRequested and elapsed-approachStart>=0.3 then RequestShot() end
 if not focusRequested then return end
 FollowModel()
 if motionLockAt and elapsed>=motionLockAt then
  -- Native movement/selection callbacks may enqueue their own zoom. Reassert
  -- the held shot after the order, without resetting the approach gate.
  Call('SetMapZoom',ParadeCamera.Zoom,0,0);motionLockAt=nil
 end
 local ok,actual=Call('GetMapZoom')
 if ok and type(actual)=='number' then
  if elapsed-approachStart>=ParadeCamera.Approach and math.abs(actual-ParadeCamera.Zoom)<=0.015 then stableFrames=stableFrames+1 else stableFrames=0 end
  if math.abs(actual-ParadeCamera.Zoom)>0.015 and elapsed>=retryAt then
   retryAt=elapsed+0.5
   Call('SetMapZoom',ParadeCamera.Zoom,0,0)
  end
  local diagnostic=ExposedMembers.MilitaryParadeDiagnostic or {}
  ExposedMembers.MilitaryParadeDiagnostic=diagnostic
  diagnostic.ZoomActual=actual;diagnostic.FocusX=target.X;diagnostic.FocusY=target.Y;diagnostic.FocusUnit=target.ID
 end
end
function ParadeCamera.HoldForMotion()
 if saved then motionLockAt=lastElapsed+0.12 end
end
function ParadeCamera.End()
    if not saved then return end
    -- Zero rotation on the review pivot BEFORE any selection/focus restoration.
    -- The persistent UI then waits for that return before restoring the snapshot.
    Call('SpinMap',0,0)
    Call('PanMap',0,0)
    for i=#hidden,1,-1 do
        local item=hidden[i]
        pcall(function()item.Control:SetHide(item.WasHidden)end)
    end
    local snapshot=saved
    if snapshot.RenderView~=nil then Call('SetWorldRenderView',snapshot.RenderView) end
    hidden={};saved=nil;target=nil
    local host=ExposedMembers.ParadeV38UI
    if host and host.SetPresentationHidden then
        local ok,err=pcall(host.SetPresentationHidden,false)
        if not ok then print('[ParadeV311][CAMERA] HUD restore error: '..tostring(err)) end
    end
    -- SelectUnit/LookAtPlot can enqueue native camera work. Reset last, and
    -- finish in the persistent UI after popup dequeue/input-context removal.
    Call('SpinMap',0,0)
    if host and host.ScheduleCameraRestore then host.ScheduleCameraRestore(snapshot) end
    print('[ParadeV312][CAMERA] return on review pivot; selection/focus restore queued')
end

function ParadeCamera.FocusUnit(unit)
    if not saved or not unit then return end
    local row=GameInfo.Units[unit:GetType()]
    target={Unit=unit,ID=unit:GetID(),X=unit:GetX(),Y=unit:GetY(),Name=row and Locale.Lookup(row.Name) or ''}
    local ok,wx,wy=Call('GridToWorld',target.X,target.Y)
    if ok then target.WorldX=wx;target.WorldY=wy end
    local okZoom,currentZoom=Call('GetMapZoom')
    approachStart=lastElapsed;approachZoom=okZoom and currentZoom or 0.45
    focusX=nil;focusY=nil
    SelectTarget();focusRequested=false;stableFrames=0;motionLockAt=nil;nextFocus=0
    print('[Parade2][CAMERA] focus unit='..unit:GetID()..' startZoom='..tostring(approachZoom)..' targetZoom='..ParadeCamera.Zoom)
end

function ParadeCamera.SimPosition(owner,id,wx,wy)
 if target and target.Unit and target.ID==id and target.Unit:GetOwner()==owner then
  target.WorldX=wx;target.WorldY=wy;target.Simulated=true
 end
end

function ParadeCamera.IsReady()
 return saved~=nil and target~=nil and focusRequested and stableFrames>=2
end
