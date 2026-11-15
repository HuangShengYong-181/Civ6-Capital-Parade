-- UI schedules native movement. Gameplay validates each destination and stores
-- recovery positions. Replays never call this module.
ParadeMarch={}
local M,R=ParadeMarch,ParadeRules
local active=nil
local waiting=nil
local quickMovement=nil
local status=''
local outcome='IDLE'
function M.Outcome()return outcome end
function M.IsComplete()return outcome=='COMPLETE' end
local function Report(text)status=text;print('[Parade2][MARCH] '..text)end
function M.Status()return status end
local function Send(params)
 params.Action='MARCH';params.OnStart='Parade2Action';params.Count=active.Count
 UI.RequestPlayerOperation(active.Owner,PlayerOperations.EXECUTE_SCRIPT,params)
end
local function SafePlot(owner,x,y,sea)
 local p=Map.GetPlot(x,y);local visibility=PlayersVisibility and PlayersVisibility[owner]
 if not p or p:GetOwner()~=owner or p:IsWater()~=sea or p:IsImpassable() then return false end
 if visibility and not visibility:IsRevealed(x,y) then return false end
 local units=Units.GetUnitsInPlot(p);return not units or #units==0
end
local function Route(owner,r,u)
 if r.Branch=='AIR' then return {} end
 local path={};local visited={[tostring(r.X)..':'..r.Y]=true};local x,y=r.X,r.Y
 -- A short outward/return pass lets the native engine validate each leg.
 for step=1,1 do
  local nextPlot=nil
  for direction=0,5 do local p=Map.GetAdjacentPlot(x,y,direction)
   if p then local key=p:GetX()..':'..p:GetY()
    if not visited[key] and SafePlot(owner,p:GetX(),p:GetY(),r.Branch=='SEA') then
     local params={[UnitOperationTypes.PARAM_X]=p:GetX(),[UnitOperationTypes.PARAM_Y]=p:GetY()}
     if UnitManager.CanStartOperation(u,UnitOperationTypes.MOVE_TO,nil,params) then nextPlot=p;visited[key]=true;break end
    end
   end
  end
  if not nextPlot then break end
  x,y=nextPlot:GetX(),nextPlot:GetY();path[#path+1]={X=x,Y=y}
 end
 local n=#path
 for i=n-1,1,-1 do path[#path+1]={X=path[i].X,Y=path[i].Y} end
 if n>0 then path[#path+1]={X=r.X,Y=r.Y} end
 return path
end
-- Native renderer callback, as used by stock SelectedUnit.lua. Logical plot
-- changes occur before the visual animation ends and are not a completion gate.
local function OnPosition(owner,id,wx,wy,wz,visible,complete)
 local a=active;local r=a and a.Units[a.Index]
 if not r or owner~=a.Owner or id~=r.ID then return end
 if ParadeCamera and ParadeCamera.SimPosition then ParadeCamera.SimPosition(owner,id,wx,wy) end
 if a.Phase=='PLAYBACK' then
  a.LastRender=a.Age
  if not complete then a.VisualStarted=true;a.VisualDone=false
  else
   -- Completion can be the first callback (quick/short/offscreen movement).
   -- Model/formation coordinates may be offset from the plot centre. The
   -- native completion flag and unit's logical destination are the gate.
   local p=Players[owner];local u=p and p:GetUnits():FindID(id)
   if u and a.Dest and u:GetX()==a.Dest.X and u:GetY()==a.Dest.Y then
    a.VisualDone=true;a.QuietUntil=a.Age+1.25
   end
  end
 end
end
-- Native QuickMovement is an integer flag, not a Lua boolean. Only change
-- the live UserConfiguration value; never persist the temporary override in
-- Options. Snapshot once and restore on every exit, including failed setters.
local function Flag(value)
 if value==true or value==1 or value=='1' then return 1 end
 if value==false or value==0 or value=='0' then return 0 end
end
local function RestoreQuickMovement()
 if quickMovement==nil then return true end
 local ok,err=pcall(UserConfiguration.SetValue,'QuickMovement',quickMovement)
 if ok then
  print('[Parade2][OPTIONS] restored QuickMovement='..quickMovement)
  quickMovement=nil
 else print('[Parade2][OPTIONS] restore failed; snapshot retained: '..tostring(err)) end
 return ok
end
local function SuspendQuickMovement()
 if quickMovement~=nil and not RestoreQuickMovement() then error('Previous QuickMovement restore is pending') end
 if not UserConfiguration or not UserConfiguration.GetValue or not UserConfiguration.SetValue then return end
 local ok,value=pcall(UserConfiguration.GetValue,'QuickMovement')
 if not ok then value=nil end
 -- Repair legacy boolean overrides from older releases using the real menu
 -- preference when available. Unknown values must never erase that preference.
 if (type(value)~='number' or Flag(value)==nil) and Options and Options.GetUserOption then
  local saved,pref=pcall(Options.GetUserOption,'Gameplay','QuickMovement')
  if saved and Flag(pref)~=nil then value=pref end
 end
 local original=Flag(value)
 if original==nil then print('[Parade2][OPTIONS] QuickMovement unreadable; left unchanged');return end
 quickMovement=original
 print('[Parade2][OPTIONS] snapshot QuickMovement='..original..'; temporary=0')
 UserConfiguration.SetValue('QuickMovement',0)
end
local hooked=false
function M.Begin(data)
 if data.Replay then outcome='COMPLETE';return end
 if active then return end
 outcome='RUNNING'
 local p=Players[data.Owner]
 if not p or R.Number(p,'PARADE2_MARCH_COMPLETION',-1)~=tonumber(data.Count) or p:GetProperty('PARADE2_MARCH_STATE')~='READY' then
  if not waiting then waiting={Data=data,Age=0};Report('等待参阅名单同步') end;return
 end
 waiting=nil
 local roster={};local eligible={}
 local city=p:GetCities():GetCapitalCity()
 for _,r in ipairs(R.Participants(p,city)) do eligible[r.ID]=r end
 for i=1,R.Number(p,'PARADE2_MARCH_COUNT',0) do
  local r={};for _,f in ipairs({'ID','X','Y','Branch'}) do r[f]=p:GetProperty('PARADE2_MARCH_'..i..'_'..f) end
  local valid=eligible[r.ID]
  if valid and valid.Branch==r.Branch and valid.X==r.X and valid.Y==r.Y then roster[#roster+1]=r
  else print('[Parade2][MARCH] excluded stale/out-of-scope roster unit='..tostring(r.ID)) end
 end
 local guard=R.CapitalGuard(p,p:GetCities():GetCapitalCity(),roster)
 if not guard then outcome='FAILED';Report('首都市中心没有参阅陆军，本次不进行检阅');return end
 local candidates={guard}
 table.sort(roster,function(a,b)
  local rank={LAND=1,SEA=2,AIR=3}
  if a.Branch~=b.Branch then return rank[a.Branch]<rank[b.Branch] end
  return a.ID<b.ID
 end)
 for _,r in ipairs(roster) do if r.ID~=guard.ID then candidates[#candidates+1]=r end end
 if not Events or not Events.UnitSimPositionChanged then outcome='FAILED';Report('缺少原生动画完成事件，停止检阅以避免动作重叠');return end
 if not hooked then Events.UnitSimPositionChanged.Add(OnPosition);hooked=true end
 active={Owner=data.Owner,Count=data.Count,Units=candidates,Index=1,Step=1,Age=0,Next=0,Phase='START',Ticket=0}
 local ok,err=pcall(SuspendQuickMovement)
 if not ok then Report('无法临时设置移动动画：'..tostring(err));M.End();return end
 Report('依次检阅：首都驻军 → 海军 → 空军')
end
local function Operation(u,x,y,op)
 local t={};t[UnitOperationTypes.PARAM_X]=x;t[UnitOperationTypes.PARAM_Y]=y
 if op and UnitManager.CanStartOperation(u,op,nil,t) then return t end
end
function M.Tick(dt)
 if waiting then
  waiting.Age=waiting.Age+dt
  if waiting.Age>5 then waiting=nil;outcome='FAILED';Report('参阅名单未就绪，请保留Lua.log') else M.Begin(waiting.Data) end
 end
 if not active then return end
 local a=active;a.Age=a.Age+dt;if a.Age<a.Next then return end
 local r=a.Units[a.Index];if not r then M.End(true);return end
 local p=Players[a.Owner];local u=p and p:GetUnits():FindID(r.ID)
 if not u then Report('参阅单位已不存在，停止检阅');M.End();return end
 local function Next()a.Index=a.Index+1;a.Phase='START';a.Step=1;a.Next=a.Age+0.5 end
 local function Prepare(mode,dest,after)
  a.Ticket=a.Ticket+1;a.Dest=dest;a.AfterPrep=after;a.Phase='PREPARED';a.Deadline=a.Age+10
  Send({Mode=mode,Unit=r.ID,X=dest and dest.X,Y=dest and dest.Y,Ticket=a.Count..':'..a.Ticket})
 end
 local function Play(op,x,y,after)
  local params=Operation(u,x,y,op)
  if not params then Report('原生移动校验未通过，停止检阅并恢复');M.End();return false end
  a.Phase='PLAYBACK';a.VisualDone=false;a.VisualStarted=false;a.AfterPlayback=after;a.Deadline=a.Age+60
  print('[Parade2][MARCH] move unit='..r.ID..' op='..tostring(op)..' to='..x..','..y)
  a.Dest={X=x,Y=y};UnitManager.RequestOperation(u,op,params)
  if ParadeCamera and ParadeCamera.HoldForMotion then ParadeCamera.HoldForMotion() end
  return true
 end
 if a.Phase=='START' then
  if ParadeCamera and ParadeCamera.FocusUnit then ParadeCamera.FocusUnit(u) end
  Report((({LAND='首都驻军',SEA='海军',AIR='空军'})[r.Branch])..' · 单位 '..r.ID)
  a.Phase='FOCUS';a.FocusStarted=a.Age

 elseif a.Phase=='FOCUS' then
  local ready=ParadeCamera and ParadeCamera.IsReady and ParadeCamera.IsReady() or not (ParadeCamera and ParadeCamera.IsReady) and a.Age-a.FocusStarted>=1.5
  if ready then a.Phase=r.Branch=='AIR' and 'AIR_PREP' or 'GROUND_PREP'
  elseif a.Age-a.FocusStarted>6 then Report('镜头未到达近景，检阅已停止，请保留Lua.log');M.End() end
 elseif a.Phase=='GROUND_PREP' then Prepare('MOVE_PREP',{X=r.X,Y=r.Y},'ROUTE')
 elseif a.Phase=='ROUTE' then
  a.Path=Route(a.Owner,r,u)
  print('[Parade2][MARCH] route unit='..r.ID..' branch='..r.Branch..' legs='..#a.Path)
  if #a.Path==0 then Report('周边无原生校验通过的安全路线，原地检阅 · 单位 '..r.ID);a.Phase='STATIC';a.Next=a.Age+3
  else a.Phase='WALK' end
 elseif a.Phase=='WALK' then
  local dest=a.Path[a.Step]
  if not dest then Next() else Prepare('MOVE_PREP',dest,'MOVE') end
 elseif a.Phase=='AIR_PREP' then Prepare('AIR_PREP',nil,'AIR_OUT')
 elseif a.Phase=='AIR_PREP_RETURN' then Prepare('AIR_PREP',nil,'AIR_RETURN')
 elseif a.Phase=='PREPARED' then
  if p:GetProperty('PARADE2_MARCH_ACK')==a.Count..':'..a.Ticket then a.Phase=a.AfterPrep
  elseif a.Age>a.Deadline then Report('行动力准备未确认，停止检阅');M.End() end
 elseif a.Phase=='MOVE' then
  Play(UnitOperationTypes.MOVE_TO,a.Dest.X,a.Dest.Y,'WALK_DONE')
 elseif a.Phase=='AIR_OUT' then
  local dest,op
  for direction=0,5 do local plot=Map.GetAdjacentPlot(r.X,r.Y,direction)
   if plot and plot:GetOwner()==a.Owner and Operation(u,plot:GetX(),plot:GetY(),UnitOperationTypes.DEPLOY) then dest=plot;op=UnitOperationTypes.DEPLOY;break end
  end
  if not dest then for _,city in p:GetCities():Members() do
   if (city:GetX()~=r.X or city:GetY()~=r.Y) and Operation(u,city:GetX(),city:GetY(),UnitOperationTypes.REBASE) then dest=city;op=UnitOperationTypes.REBASE;break end
  end end
  if dest then Play(op,dest:GetX(),dest:GetY(),'AIR_PREP_RETURN') else Report('空军没有合法部署点或备用基地，原地检阅');a.Phase='STATIC';a.Next=a.Age+3 end
 elseif a.Phase=='AIR_RETURN' then Play(UnitOperationTypes.REBASE,r.X,r.Y,'NEXT')
 elseif a.Phase=='PLAYBACK' then
  if a.VisualDone and a.Age>=(a.QuietUntil or a.Age) and u:GetX()==a.Dest.X and u:GetY()==a.Dest.Y then
   a.Phase=a.AfterPlayback;a.Next=a.Age+0.5
  elseif a.Age>a.Deadline then
   print('[Parade2][MARCH] timeout unit='..r.ID..' target='..a.Dest.X..','..a.Dest.Y..' logical='..u:GetX()..','..u:GetY()..' started='..tostring(a.VisualStarted)..' complete='..tostring(a.VisualDone)..' lastRender='..tostring(a.LastRender))
   Report('未收到动画完成确认，本次检阅已中止，正在恢复部队');M.End()
  end
 elseif a.Phase=='WALK_DONE' then a.Step=a.Step+1;a.Phase='WALK'
 elseif a.Phase=='NEXT' or a.Phase=='STATIC' then Next() end
end
function M.End(completed)
 if completed then outcome='COMPLETE';Report('全部参阅单位已完成检阅并返回，可以授奖')
 elseif outcome~='COMPLETE' then outcome='FAILED' end
 waiting=nil
 if hooked then Events.UnitSimPositionChanged.Remove(OnPosition);hooked=false end
 if active then
  local ok,err=pcall(Send,{Mode='END'});active=nil
  if not ok then Report('返回请求失败：'..tostring(err)) end
 end
 RestoreQuickMovement()
end
function M.IsActive()return active~=nil or waiting~=nil end

function M.CurrentUnit()
 local a=active;local r=a and a.Units[a.Index]
 return r and Players[a.Owner]:GetUnits():FindID(r.ID) or nil
end
