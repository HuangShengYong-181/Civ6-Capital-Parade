-- Shared read-only rules. No player access or game mutations during include.
ParadeRules={Version='2.0.5',Window=15,Duration=10,Thresholds={200,500,1000,2000}}
local R=ParadeRules
R.Kinds={'VICTORY','LIBERATION','RALLY','STRENGTH'}
R.Names={VICTORY='凯旋阅兵',LIBERATION='光复阅兵',RALLY='振军阅兵',STRENGTH='强军阅兵'}
R.Verses={VICTORY='铁骑奏凯，旌旗载扬；拓疆振旅，声威远彰。',LIBERATION='故土重光，山河无恙；王师振旅，社稷永昌。',RALLY='整甲砺兵，誓雪国殇；重张旗鼓，再振封疆。',STRENGTH='戈甲成林，鹰扬海疆；陈师示武，四海知强。'}
R.Costs={{30,5,8,12},{50,8,12,18},{80,12,18,25},{120,18,25,35},{200,25,40,55},{300,40,60,80},{450,55,85,110},{650,75,110,150},{900,100,150,200}}
function R.Number(p,k,d) local v=p:GetProperty(k); return tonumber(v) or d or 0 end
function R.Project(kind) return 'PROJECT_PARADE_'..kind end
function R.Kind(id)
 for _,kind in ipairs(R.Kinds) do local row=GameInfo.Projects[R.Project(kind)]; if row and (id==row.Index or id==row.Hash or id==row.ProjectType) then return kind end end
end
-- Native UI uses GetCurrentProductionTypeHash, independent of queue-entry layout.
function R.ActiveProject(city)
 local queue=city:GetBuildQueue()
 if queue.GetCurrentProductionTypeHash then
  local hash=queue:GetCurrentProductionTypeHash()
  for _,kind in ipairs(R.Kinds) do
   local row=GameInfo.Projects[R.Project(kind)]
   if row and hash==row.Hash then return kind end
  end
  return nil
 end
 -- Compatibility with older queue providers; never scan queued future projects.
 if queue.GetSize and queue.GetAt then
  local entry=queue:GetSize()>0 and queue:GetAt(0)
  return entry and R.Kind(entry.ProjectType)
 end
 error('Current production cannot be read')
end
function R.Era()
 if Game.GetEras then local ok,e=pcall(function()return Game.GetEras():GetCurrentEra()end);if ok and e then return e end end
 return 0
end
function R.EraOrder()
 local row=GameInfo.Eras[R.Era()];return math.max(1,math.min(9,(row and row.ChronologyIndex or 0)+1))
end
function R.Speed()
 local key=GameConfiguration and GameConfiguration.GetGameSpeedType and GameConfiguration.GetGameSpeedType()
 local row=key and GameInfo.GameSpeeds and GameInfo.GameSpeeds[key]
 return (row and row.CostMultiplier or 100)/100
end
function R.Turns(n)return math.max(1,math.floor(n*R.Speed()+0.5))end
function R.Military(u)
 local row=GameInfo.Units[u:GetType()];return row and ((row.Combat or 0)>0 or (row.RangedCombat or 0)>0)
end
function R.Branch(u)
 local row=GameInfo.Units[u:GetType()];local domain=row and row.Domain
 return domain=='DOMAIN_SEA' and 'SEA' or domain=='DOMAIN_AIR' and 'AIR' or 'LAND'
end
function R.Formation(u)
 if u.GetMilitaryFormation then local n=u:GetMilitaryFormation();if n==2 then return 3 elseif n==1 then return 2 end end
 return 1
end
function R.Distance(x,y,a,b)return Map.GetPlotDistance(x,y,a,b)end
function R.Facilities(city)
 local harbor,airfields=nil,{}
 local districts=city.GetDistricts and city:GetDistricts()
 if districts and not districts.Members then
  local ui=ExposedMembers and ExposedMembers.ParadeV3UI
  if ui and ui.GetFacilities then
   local ok,h,a=pcall(ui.GetFacilities,city:GetOwner(),city:GetID())
   if ok and a then return h,a end
  end
 end
 if districts and districts.Members then for _,d in districts:Members() do
  local row=GameInfo.Districts[d:GetType()]
  if row and not (d.IsPillaged and d:IsPillaged()) then
   local replaces=false
   if GameInfo.DistrictReplaces then for rr in GameInfo.DistrictReplaces() do if rr.CivUniqueDistrictType==row.DistrictType and rr.ReplacesDistrictType=='DISTRICT_HARBOR' then replaces=true end end end
   if row.DistrictType=='DISTRICT_HARBOR' or replaces then harbor={X=d:GetX(),Y=d:GetY()} end
   if row.DistrictType=='DISTRICT_AERODROME' then airfields[#airfields+1]={X=d:GetX(),Y=d:GetY()} end
  end
 end end
 airfields[#airfields+1]={X=city:GetX(),Y=city:GetY()}
 return harbor,airfields
end
function R.Participants(p,city)
 if not city then return {} end
 local result={};local harbor,airfields=R.Facilities(city)
 for _,u in p:GetUnits():Members() do if R.Military(u) then
  local x,y=u:GetX(),u:GetY();local plot=(x>=0 and y>=0 and not (u.IsDelayedDeath and u:IsDelayedDeath())) and Map.GetPlot(x,y) or nil;local branch=R.Branch(u);local valid=false
  if plot and plot:GetOwner()==p:GetID() then
   if branch=='LAND' then valid=not plot:IsWater() and x==city:GetX() and y==city:GetY()
   elseif branch=='SEA' then valid=harbor and plot:IsWater() and R.Distance(x,y,harbor.X,harbor.Y)<=1
   else for _,base in ipairs(airfields) do if x==base.X and y==base.Y then valid=true;break end end end
  end
  if valid then result[#result+1]={ID=u:GetID(),X=x,Y=y,Branch=branch,Weight=R.Formation(u)} end
 end end
 table.sort(result,function(a,b)
  local function rank(r)if r.Branch=='LAND' and r.X==city:GetX() and r.Y==city:GetY() then return 0 end;return ({LAND=1,SEA=2,AIR=3})[r.Branch] end
  if rank(a)~=rank(b) then return rank(a)<rank(b) end;return a.ID<b.ID
 end);return result
end
function R.CapitalGuard(p,city,roster)
 if not city then return nil end
 for _,r in ipairs(roster or R.Participants(p,city)) do
  if r.Branch=='LAND' and r.X==city:GetX() and r.Y==city:GetY() then return r end
 end
end
function R.Count(roster)local n=0;for _,u in ipairs(roster) do n=n+u.Weight end;return n end
function R.Scale(n) return n>=12 and 3 or n>=8 and 2 or n>=4 and 1 or 0 end
function R.Cost(roster)
 local c=R.Costs[R.EraOrder()];local total=c[1]
 for _,u in ipairs(roster) do total=total+c[u.Branch=='LAND' and 2 or u.Branch=='SEA' and 3 or 4]*u.Weight end
 return math.max(1,math.ceil(total*R.Speed()))
end
function R.Legal(p,city,kind,ignoreGold)
 local capital=p:GetCities():GetCapitalCity();local civic=GameInfo.Civics['CIVIC_EARLY_EMPIRE']
 if not capital or not city or capital:GetID()~=city:GetID() then return false,'仅限当前首都' end
 if not civic or not p:GetCulture():HasCivic(civic.Index) then return false,'需要完成帝国初期' end
 local started=p:GetProperty('PARADE2_ACTIVE_KIND')==kind and R.Number(p,'PARADE2_ACTIVE_CITY',-1)==city:GetID()
 local slot=kind=='STRENGTH' and 'STRONG' or 'WAR'
 if not started and (p:GetProperty('PARADE2_'..slot..'_KIND')~=kind or R.Number(p,'PARADE2_'..slot..'_END',-1)<Game.GetCurrentGameTurn()) then return false,'需要对应大事触发，资格保留15回合' end
 local roster=R.Participants(p,city)
 if not R.CapitalGuard(p,city,roster) then return false,'首都市中心必须驻扎陆军军事单位，才能举行阅兵' end
 if started then
  local locked={};for i=1,R.Number(p,'PARADE2_ROSTER_COUNT',0) do local id=p:GetProperty('PARADE2_ROSTER_'..i..'_ID');if id then locked[id]=true end end
  local guard=R.CapitalGuard(p,city,roster)
  if not guard or not locked[guard.ID] then return false,'原参阅陆军必须驻扎在首都市中心' end
 end
 if kind=='STRENGTH' then
  local ui=ExposedMembers and ExposedMembers.ParadeV3UI
  local ok,score=false,nil
  if ui and ui.GetMilitaryScore then ok,score=pcall(ui.GetMilitaryScore,p:GetID()) end
  local threshold=R.Number(p,started and 'PARADE2_ACTIVE_THRESHOLD' or 'PARADE2_STRONG_THRESHOLD',200)
  if not ok or type(score)~='number' or score<threshold then return false,'军事分须达到 '..threshold end
 end
 if not started and not ignoreGold and p:GetTreasury():GetGoldBalance()<R.Cost(roster)*(p:IsHuman() and 1 or 2) then return false,'金币不足；筹备费 '..R.Cost(roster) end
 return true,started and '正在筹备' or ('筹备费 '..R.Cost(roster)..' 金币')
end
-- DiplomaticAI state getters are UI-context APIs in some game builds.
-- nil means unavailable, false means a known non-friendly state.
function R.NativeRelation(from,to)
 local ok,result=pcall(function()
  local p=Players[from];local ai=p and p.GetDiplomaticAI and p:GetDiplomaticAI()
  if not ai then return nil end
  local state
  if ai.GetDiplomaticState then state=ai:GetDiplomaticState(to)
  elseif ai.GetDiplomaticStateIndex then state=ai:GetDiplomaticStateIndex(to) end
  if state==nil then return nil end
  local row=GameInfo.DiplomaticStates[state]
  return row and row.StateType or 'DIPLO_STATE_NEUTRAL'
 end)
 if ok then return result end
 return nil
end
function R.NativeFriendly(from,to)
 local state=R.NativeRelation(from,to)
 if state==nil then return nil end
 return state=='DIPLO_STATE_FRIENDLY' or state=='DIPLO_STATE_DECLARED_FRIEND' or state=='DIPLO_STATE_ALLIED'
end
function R.AttendanceChance(from,to)
 if not R.Friendly(from,to) then return 0,'INELIGIBLE' end
 local d=Players[from]:GetDiplomacy()
 if d.IsAlliedWith and d:IsAlliedWith(to) then return 100,'ALLIED' end
 local state=R.NativeRelation(from,to)
 if state==nil then
  local ui=ExposedMembers and ExposedMembers.ParadeV2UI
  if ui and ui.GetRelationState then local ok,value=pcall(ui.GetRelationState,from,to);if ok then state=value end end
 end
 if state=='DIPLO_STATE_ALLIED' then return 100,'ALLIED' end
 if (d.IsDeclaredFriend and d:IsDeclaredFriend(to)) or state=='DIPLO_STATE_DECLARED_FRIEND' then return 80,'DECLARED_FRIEND' end
 return 50,'FRIENDLY'
end
function R.Friendly(from,to)
 local p=Players[from];if not p or not Players[to] then return false end
 local d=p:GetDiplomacy();if not d:HasMet(to) or d:IsAtWarWith(to) then return false end
 if d.IsDeclaredFriend and d:IsDeclaredFriend(to) then return true end
 if d.IsAlliedWith and d:IsAlliedWith(to) then return true end
 local friendly=R.NativeFriendly(from,to)
 if friendly~=nil then return friendly end
 local ui=ExposedMembers and ExposedMembers.ParadeV2UI
 if ui and ui.GetFriendlyState then
  local ok,value=pcall(ui.GetFriendlyState,from,to)
  if ok and type(value)=='boolean' then return value end
 end
 return false,'外交状态暂未同步，请返回地图后重试'
end

function R.Luxuries(from,to)
 local out={};local p=Players[from];if not p then return out end
 local imports={}
 for _,other in ipairs(PlayerManager.GetAliveMajors()) do if other:GetID()~=from then
  for _,deal in ipairs(DealManager.GetPlayerDeals(from,other:GetID()) or {}) do
   for _,item in ipairs(deal:FindItemsByType(DealItemTypes.RESOURCES,DealItemSubTypes.NONE,other:GetID()) or {}) do
    local id=item:GetValueType();imports[id]=(imports[id] or 0)+item:GetAmount()
   end
  end
 end end
 for row in GameInfo.Resources() do
  if row.ResourceClassType=='RESOURCECLASS_LUXURY' and p:GetResources():GetResourceAmount(row.Index)-(imports[row.Index] or 0)>=2 then out[#out+1]=row.Index end
 end
 table.sort(out,function(a,b)
  local ar=Players[to]:GetResources():GetResourceAmount(a);local br=Players[to]:GetResources():GetResourceAmount(b)
  if (ar==0)~=(br==0) then return ar==0 end;return a<b
 end)
 return out
end
-- Explicit beta price policy, not the private AI trade valuation. Visible in UI.
-- Replaceable after native valuation is verified; never silently accept 1 gold.
function R.GoldFloor()return math.ceil(({60,90,120,180,240,300,420,540,660})[R.EraOrder()]*R.Speed())end
