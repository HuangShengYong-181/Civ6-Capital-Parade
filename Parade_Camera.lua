-- UI-only, fixed close-up review. World-space focus follows the stock
-- NaturalDisasterPopup path, rather than combining a pan and simulated drag.
ParadeCamera={Duration=20,Zoom=0.0,Approach=1.25}
local saved=nil
local hidden={}
local target=nil
local nextFocus=0
local nextSelection=0
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
local function FocusTarget(zoom)
    if not target or not target.X or not target.Y then return end
    zoom=zoom or ParadeCamera.Zoom
    Call('PanMap',0,0)
    Call('SpinMap',0,0)
    if target.WorldX and target.WorldY then
        -- Same signature as stock NaturalDisasterPopup: immediate world focus.
        if not Call('LookAtPosition',target.WorldX,target.WorldY,true) then
            Call('LookAtPlot',target.X,target.Y)
        end
    else
        Call('LookAtPlot',target.X,target.Y)
    end
    -- Always set zoom LAST; a native focus command may have its own zoom.
    Call('SetMapZoom',zoom,0,0)
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
    -- A review always focuses the current capital's center, never an adjacent
    -- unit. Historical replay may have no garrison: keep focus on the capital.
    local candidates={}
    local player=Players[data.Owner]
    local capital=player and player:GetCities():GetCapitalCity()
    local cx=capital and capital:GetX()
    local cy=capital and capital:GetY()
    if capital then
        for _,unit in player:GetUnits():Members() do
            local row=GameInfo.Units[unit:GetType()]
            if row and ((row.Combat or 0)>0 or (row.RangedCombat or 0)>0)
                and unit:GetX()==cx and unit:GetY()==cy then
                candidates[#candidates+1]={Unit=unit,ID=unit:GetID(),X=cx,Y=cy,
                    InCity=true,Name=Locale.Lookup(row.Name)}
            end
        end
    end
    table.sort(candidates,function(a,b)return a.ID<b.ID end)
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
    nextFocus=0;nextSelection=0
    saved.LastSpin=0
    SelectTarget()
    Call('SpinMap',0,0)
    if target.X and target.Y then
        Call('SetMapZoom',math.max(0.3,saved.Zoom or 0.45),0,0)
        FocusTarget(math.max(0.3,saved.Zoom or 0.45))
    end
    print('[MilitaryParade][CAMERA] fixed-close-up owner='..tostring(data.Owner)..' capital='..tostring(capital and capital:GetID())..' xy='..tostring(cx)..','..tostring(cy)..' world='..tostring(target.WorldX)..','..tostring(target.WorldY)..' unit='..tostring(target.ID)..' zoom='..ParadeCamera.Zoom)
    return target.Name,target.InCity
end
local function Smooth(v)v=math.max(0,math.min(1,v));return v*v*(3-2*v)end
function ParadeCamera.Tick(elapsed)
    if not saved or not target or not target.X or not target.Y then return end
    local wide=math.max(0.3,saved.Zoom or 0.45)
    local zoom=wide+(ParadeCamera.Zoom-wide)*Smooth(elapsed/ParadeCamera.Approach)
    Call('PanMap',0,0)
    Call('SpinMap',0,0)
    if elapsed>=nextSelection then
        nextSelection=elapsed+0.25
        local ok,selected=Call('GetHeadSelectedUnit')
        if target.Unit and (not ok or not selected or
            selected:GetOwner()~=target.Unit:GetOwner() or selected:GetID()~=target.ID) then
            SelectTarget()
        end
    end
    -- Fixed view: re-anchor at 5 Hz so production/selection/edge movement
    -- cannot leave the unit off screen. Immediate world focus has no tween to
    -- restart. Never select an adjacent unit or issue GameCore movement.
    if elapsed>=nextFocus then nextFocus=elapsed+0.2;FocusTarget(zoom) end
    Call('SetMapZoom',zoom,0,0)
    local read,actual=Call('GetMapZoom')
    if read and type(actual)=='number' then
        local diagnostic=ExposedMembers.MilitaryParadeDiagnostic or {}
        ExposedMembers.MilitaryParadeDiagnostic=diagnostic
        diagnostic.ZoomActual=actual
        diagnostic.FocusX=target.X;diagnostic.FocusY=target.Y
        diagnostic.FocusUnit=target.ID
        if actual>zoom+0.005 then Call('SetMapZoom',zoom,0,0) end
    end
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
