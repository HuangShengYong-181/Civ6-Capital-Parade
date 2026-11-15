-- Gameplay campaign lifecycle. All mutating UI requests use EXECUTE_SCRIPT.
ParadeCampaign={}
local C,R,D=ParadeCampaign,ParadeRules,ParadeDiplomacy
local function N(p,k,d)return R.Number(p,k,d)end
local function Now()return Game.GetCurrentGameTurn()end
local function P(k)return 'PARADE2_'..k end
local function Building(city,name,wanted)
 local row=GameInfo.Buildings[name];if not row then return end
 local b=city:GetBuildings()
 if wanted and not b:HasBuilding(row.Index) then city:GetBuildQueue():CreateBuilding(row.Index)
 elseif not wanted and b:HasBuilding(row.Index) then b:RemoveBuilding(row.Index) end
end
function C.Score(id)
 local ui=ExposedMembers.ParadeV3UI
 if ui and ui.GetMilitaryScore then local ok,n=pcall(ui.GetMilitaryScore,id);if ok and type(n)=='number' then return math.floor(n) end end
 return nil
end
local function Offer(p,kind)
 local civic=GameInfo.Civics['CIVIC_EARLY_EMPIRE'];if not civic or not p:GetCulture():HasCivic(civic.Index) then return end
 -- Activate at the player's next controllable turn (or this turn if active).
 p:SetProperty(P('PENDING_'..(kind=='STRENGTH' and 'STRONG' or 'WAR')),kind)
end
local function Activate(p)
 for _,slot in ipairs({'WAR','STRONG'}) do
  local kind=p:GetProperty(P('PENDING_'..slot))
  if kind then
   p:SetProperty(P(slot..'_KIND'),kind);p:SetProperty(P(slot..'_END'),Now()+R.Turns(R.Window)-1)
   p:SetProperty(P('PENDING_'..slot),nil)
   D.Notify(p,R.Names[kind]..'已解锁，资格保留'..R.Turns(R.Window)..'回合。仅当前首都可筹备，另需金币和参阅部队。')
  end
 end
end
local function SaveRoster(p,roster)
 p:SetProperty(P('ROSTER_COUNT'),#roster)
 for i,r in ipairs(roster) do for _,field in ipairs({'ID','X','Y','Branch','Weight'}) do p:SetProperty(P('ROSTER_'..i..'_'..field),r[field]) end end
end
function C.Roster(p,validOnly)
 local out={};local city=p:GetCities():GetCapitalCity();local valid={}
 if validOnly and city then for _,r in ipairs(R.Participants(p,city)) do valid[r.ID]=r end end
 for i=1,N(p,P('ROSTER_COUNT'),0) do
  local r={};for _,f in ipairs({'ID','X','Y','Branch','Weight'}) do r[f]=p:GetProperty(P('ROSTER_'..i..'_'..f)) end
  if r.ID and (not validOnly or valid[r.ID]) then out[#out+1]=validOnly and valid[r.ID] or r end
 end
 return out
end
function C.Officer(p,city)
 local harbor=R.Facilities(city);local roster=R.Participants(p,city);local fleet=false
 for _,u in ipairs(roster) do if u.Branch=='SEA' then fleet=true end end
 for _,u in p:GetUnits():Members() do local row=GameInfo.Units[u:GetType()]
  if row and row.UnitType=='UNIT_GREAT_GENERAL' and u:GetX()==city:GetX() and u:GetY()==city:GetY() then return u end
  if row and row.UnitType=='UNIT_GREAT_ADMIRAL' and fleet and harbor and u:GetX()==harbor.X and u:GetY()==harbor.Y then return u end
 end
 return nil
end
function C.Supervised(p,city)return C.Officer(p,city)~=nil end
local function ActiveEntry(p)
 local ui=ExposedMembers.ParadeV3UI
 if not ui or not ui.GetActiveParade then return nil,nil,false end
 local ok,cityID,project=pcall(ui.GetActiveParade,p:GetID())
 if not ok then return nil,nil,false end
 local city=cityID and p:GetCities():FindID(cityID)
 return city,project and R.Kind(project),true
end
function C.Start(p,city,kind)
 if p:GetProperty(P('ACTIVE_KIND')) then return false end
 local ok=R.Legal(p,city,kind);if not ok then return false end
 if kind=='STRENGTH' then local score=C.Score(p:GetID());if not score or score<N(p,P('STRONG_THRESHOLD'),200) then return false end end
 local roster=R.Participants(p,city);local cost=R.Cost(roster);local session=N(p,P('SESSION'),0)+1
 p:GetTreasury():ChangeGoldBalance(-cost)
 SaveRoster(p,roster);p:SetProperty(P('ACTIVE_KIND'),kind);p:SetProperty(P('ACTIVE_CITY'),city:GetID())
 p:SetProperty(P('ACTIVE_THRESHOLD'),N(p,P('STRONG_THRESHOLD'),200));p:SetProperty(P('ACTIVE_COST'),cost);p:SetProperty(P('ACTIVE_START'),Now());p:SetProperty(P('SESSION'),session);p:SetProperty(P('INVITE_COUNT'),0)
 print('[Parade2][SESSION] START player='..p:GetID()..' city='..city:GetID()..' kind='..kind..' session='..session..' cost='..cost)
 p:SetProperty(P((kind=='STRENGTH' and 'STRONG' or 'WAR')..'_KIND'),nil)
 D.Notify(p,R.Names[kind]..'开始筹备：已支付 '..cost..' 金币，参阅规模 '..R.Count(roster)..'。取消不退筹备费。')
 -- Human hosts explicitly choose guests each session. Never auto-renew past
 -- guests, and keep old session records separate from the new invitation list.
 for _,g in ipairs(PlayerManager.GetAliveMajors()) do
  local key=P('INVITE_'..session..'_'..g:GetID())
  p:SetProperty(key,nil)
  for _,field in ipairs({'RESOURCE','GOLD','RECEIPT','AI_CHANCE','AI_RELATION','AI_ROLL','AI_ACCEPT'}) do p:SetProperty(key..'_'..field,nil) end
 end
 if kind=='STRENGTH' and not p:IsHuman() then
  for _,g in ipairs(PlayerManager.GetAliveMajors()) do if g:GetID()~=p:GetID() then D.Invite(p:GetID(),g:GetID(),session) end end
 end
 return true
end
function C.CancelActive(p,reason)
 local kind=p:GetProperty(P('ACTIVE_KIND'));if not kind then return end
 D.Cancel(p:GetID(),N(p,P('SESSION'),-1))
 p:SetProperty(P('ACTIVE_KIND'),nil)
 p:SetProperty('PARADE_V3_PENDING_CITY',-1)
 print('[Parade2][SESSION] CANCEL player='..p:GetID()..' kind='..kind..' reason='..tostring(reason))
end
function C.Sync(p,activeTier,confirmedQueue)
 local activeKind=p:GetProperty(P('ACTIVE_KIND'));local city,kind,readable=ActiveEntry(p)
 if readable and activeKind and (not city or kind~=activeKind or city:GetID()~=N(p,P('ACTIVE_CITY'),-1)) then
  -- Native queue-change callbacks can precede CityProjectCompleted. Only a
  -- deferred UI snapshot may confirm cancellation, never these early callbacks.
  local pending=N(p,'PARADE_V3_PENDING_CITY',-1)>=0
  if confirmedQueue and not pending and not C.Committing then
   C.CancelActive(p,'settled queue changed')
   if city and kind then C.Start(p,city,kind) end
  end
 elseif readable and not C.Committing and not activeKind and city and kind then C.Start(p,city,kind) end
 local score=C.Score(p:GetID())
 if score then
  local highest=0
  for _,threshold in ipairs(R.Thresholds) do if score>=threshold and N(p,P('MILESTONE_'..threshold),0)==0 then highest=threshold end end
  if highest>0 then
   for _,threshold in ipairs(R.Thresholds) do if threshold<=highest then p:SetProperty(P('MILESTONE_'..threshold),1) end end
   p:SetProperty(P('STRONG_THRESHOLD'),highest);Offer(p,'STRENGTH')
  end
 end
 if p.IsTurnActive and p:IsTurnActive() then Activate(p) end
 local intimidate=Now()<N(p,P('INTIMIDATION_END'),-1)
 p:SetProperty(P('INTIMIDATION_ACTIVE'),intimidate and 1 or 0)
 if GameInfo.Modifiers['PARADE2_INTIMIDATION'] and N(p,P('INTIMIDATION_ATTACHED'),0)==0 then
  p:AttachModifierByID('PARADE2_INTIMIDATION');p:SetProperty(P('INTIMIDATION_ATTACHED'),1)
 end
 for _,c in p:GetCities():Members() do
  for _,k in ipairs(R.Kinds) do
   local row=GameInfo.Buildings['BUILDING_PARADE2_'..k];local had=row and c:GetBuildings():HasBuilding(row.Index)
   local allow=R.Legal(p,c,k);Building(c,'BUILDING_PARADE2_'..k,allow)
   if had and not allow then c:GetBuildQueue():CheckActiveProduction() end
  end
  Building(c,'BUILDING_PARADE_GENERAL',C.Supervised(p,c))
  for level=1,3 do Building(c,'BUILDING_PARADE2_SCALE_'..level,activeTier>0 and N(p,P('SCALE'),0)==level) end
 end
 D.Tick(p)
end
function C.CanComplete(p,cityID,projectID)
 local kind=R.Kind(projectID);if not kind then return false,'legacy project; choose an event project' end
 if p:GetProperty(P('ACTIVE_KIND'))~=kind or N(p,P('ACTIVE_CITY'),-1)~=cityID then return false,'no paid active session' end
 local city=p:GetCities():GetCapitalCity()
 if not city or city:GetID()~=cityID then return false,'capital changed' end
 if not R.CapitalGuard(p,city,C.Roster(p,true)) then return false,'首都市中心缺少原参阅陆军，不能举行阅兵' end
 if kind=='STRENGTH' then local score=C.Score(p:GetID());if not score or score<N(p,P('ACTIVE_THRESHOLD'),200) then return false,'military strength fell below threshold' end end
 return true
end
function C.Complete(p,kind,points,count)
 local roster=C.Roster(p,true);local scale=R.Scale(R.Count(roster));local session=N(p,P('SESSION'),0)
 p:SetProperty(P('COMPLETED_KIND'),kind);p:SetProperty(P('COMPLETED_COST'),N(p,P('ACTIVE_COST'),0));p:SetProperty(P('SCALE'),scale)
 p:SetProperty(P('COMPLETED_SIZE'),R.Count(roster));p:SetProperty(P('COMPLETED_SESSION'),session)
 p:SetProperty(P('ACTIVE_KIND'),nil)
 p:GetInfluence():ChangeTokensToGive(1)
 if kind=='STRENGTH' then p:SetProperty(P('INTIMIDATION_END'),Now()+R.Turns(R.Duration));p:SetProperty(P('INTIMIDATION_ACTIVE'),1);D.Settle(p:GetID(),session,points) end
 D.Notify(p,R.Names[kind]..'礼成：获得1位使者、'..points..'大将军点数；参阅规模 '..R.Count(roster)..'。'..(kind=='STRENGTH' and '效果期间新增不满减少20%。' or ''))
 -- Persist original positions before any real movement. Load recovery always
 -- returns these units and spends their movement, never repeats rewards.
 p:SetProperty(P('MARCH_COUNT'),#roster);p:SetProperty(P('MARCH_SCOPED'),0)
 for i,r in ipairs(roster) do for _,f in ipairs({'ID','X','Y','Branch','Weight'}) do p:SetProperty(P('MARCH_'..i..'_'..f),r[f]) end end
 p:SetProperty(P('MARCH_COMPLETION'),count);p:SetProperty(P('MARCH_STATE'),p:IsHuman() and 'READY' or 'DONE')
 for _,r in ipairs(roster) do local u=p:GetUnits():FindID(r.ID);if u then UnitManager.FinishMoves(u) end end
 for _,other in ipairs(PlayerManager.GetAliveMajors()) do if other:GetID()~=p:GetID() then
  local ui=ExposedMembers.ParadeV2UI;local heard=false
  if ui and ui.HasTradeRoute then local ok,v=pcall(ui.HasTradeRoute,other:GetID(),p:GetID());heard=ok and v end
  if heard and other:GetDiplomacy():HasMet(p:GetID()) then D.Notify(other,'商旅见闻：'..D.Leader(p:GetID())..'举行了'..R.Names[kind]..'。') end
 end end
end
local function Recover(p)
 local state=p:GetProperty(P('MARCH_STATE'));if state~='RUNNING' and state~='READY' then return end
 for i=1,N(p,P('MARCH_COUNT'),0) do local u=p:GetUnits():FindID(N(p,P('MARCH_'..i..'_ID'),-1))
  if u and (N(p,P('MARCH_SCOPED'),0)~=1 or N(p,P('MARCH_'..i..'_TOUCHED'),0)==1) then local x,y=N(p,P('MARCH_'..i..'_X')),N(p,P('MARCH_'..i..'_Y'));if u:GetX()~=x or u:GetY()~=y then UnitManager.MoveUnit(u,x,y) end;UnitManager.FinishMoves(u) end
 end
 p:SetProperty(P('MARCH_STATE'),'DONE')
end
function C.OnTurn(p)
 if not C.seen then C.seen={} end
 if not C.seen[p:GetID()] then C.seen[p:GetID()]=true;Recover(p) end
 for _,c in p:GetCities():Members() do p:SetProperty(P('OWNED_'..c:GetX()..'_'..c:GetY()),1) end
 Activate(p)
end
local function OnConquered(newID,oldID,cityID,x,y)
 local new,old=Players[newID],Players[oldID]
 if not new or not old or not new:IsMajor() or not old:IsMajor() or not new:GetDiplomacy():IsAtWarWith(oldID) then return end
 local key=P('CAPTURE_'..x..'_'..y);local cooldown=R.Turns(20)
 if Now()-N(new,key,-999)<cooldown then return end
 new:SetProperty(key,Now())
 local city=new:GetCities():FindID(cityID);local original=city and city.GetOriginalOwner and city:GetOriginalOwner()
 local recovered=original==newID or N(new,P('OWNED_'..x..'_'..y),0)==1
 Offer(new,recovered and 'LIBERATION' or 'VICTORY');Offer(old,'RALLY')
 new:SetProperty(P('OWNED_'..x..'_'..y),1)
end
local function OnOperation(playerID,params)
 local p=Players[playerID];if not p or type(params)~='table' then return end
 if params.Action=='ACK_GIFT_SUMMARY' then
  local session=tonumber(params.Session)
  if session and session==math.floor(session) and session>N(p,'PARADE2_GIFT_SUMMARY_ACK',-1) and session<=N(p,'PARADE2_COMPLETED_SESSION',-1) then p:SetProperty('PARADE2_GIFT_SUMMARY_ACK',session) end
 elseif params.Action=='REFRESH' then
  local bridge=ExposedMembers.ParadeV3Gameplay
  if bridge and bridge.Ready then C.Sync(p,Now()<N(p,'PARADE_V3_END',-1) and N(p,'PARADE_V3_TIER',0) or 0,params.ConfirmQueue==1) end
 elseif params.Action=='INVITE' then D.Invite(playerID,tonumber(params.Guest),tonumber(params.Session))
 elseif params.Action=='DECIDE_WAIVER' then D.DecideWaiver(playerID,params)
 elseif params.Action=='ANSWER' then D.Answer(playerID,params)
 elseif params.Action=='MARCH' and N(p,P('MARCH_COMPLETION'),-1)==tonumber(params.Count) then
  local state=p:GetProperty(P('MARCH_STATE'));if state~='READY' and state~='RUNNING' then return end
  if params.Mode=='END' then Recover(p);if state=='READY' then p:SetProperty(P('MARCH_STATE'),'DONE') end;return end
  local id=tonumber(params.Unit);local origin
  for i=1,N(p,P('MARCH_COUNT'),0) do if N(p,P('MARCH_'..i..'_ID'),-1)==id then origin=i;break end end
  local u=id and p:GetUnits():FindID(id);if not origin or not u then return end
  local capital=p:GetCities():GetCapitalCity()
  if R.Branch(u)=='LAND' and (not capital or N(p,P('MARCH_'..origin..'_X'))~=capital:GetX() or N(p,P('MARCH_'..origin..'_Y'))~=capital:GetY()) then return end
  local function Touch()
   -- Legacy READY rosters may contain nearby armies. Only units actually
   -- prepared by this scheduler should be restored or lose moves on exit.
   if N(p,P('MARCH_SCOPED'),0)~=1 then
    for i=1,N(p,P('MARCH_COUNT'),0) do p:SetProperty(P('MARCH_'..i..'_TOUCHED'),0) end
    p:SetProperty(P('MARCH_SCOPED'),1)
   end
   p:SetProperty(P('MARCH_'..origin..'_TOUCHED'),1)
  end
  local x,y=tonumber(params.X),tonumber(params.Y);local plot=x and y and Map.GetPlot(x,y)
  if params.Mode=='AIR_PREP' and R.Branch(u)=='AIR' then Touch();UnitManager.RestoreMovement(u);p:SetProperty(P('MARCH_STATE'),'RUNNING');p:SetProperty(P('MARCH_ACK'),params.Ticket);return end
  if params.Mode~='MOVE_PREP' then return end
  if not plot or plot:GetOwner()~=playerID then return end
  local ox,oy=N(p,P('MARCH_'..origin..'_X')),N(p,P('MARCH_'..origin..'_Y'))
  if x~=ox or y~=oy then
   if R.Branch(u)=='AIR' or R.Distance(u:GetX(),u:GetY(),x,y)~=1 or R.Distance(ox,oy,x,y)>(R.Branch(u)=='SEA' and 3 or 1) or plot:IsImpassable() then return end
   if plot:IsWater()~=(R.Branch(u)=='SEA') then return end
   local visibility=PlayersVisibility and PlayersVisibility[playerID]
   if visibility and not visibility:IsRevealed(x,y) then return end
   local us=Units.GetUnitsInPlot(plot);if us and #us>0 then return end
  end
  Touch();p:SetProperty(P('MARCH_STATE'),'RUNNING');UnitManager.RestoreMovement(u);p:SetProperty(P('MARCH_ACK'),params.Ticket)
 end
end
if GameEvents then
 GameEvents.CityConquered.Add(OnConquered)
 GameEvents.Parade2Action.Add(function(...)local ok,e=pcall(OnOperation,...);if not ok then print('[Parade2][ERROR] '..tostring(e)) end end)
end
