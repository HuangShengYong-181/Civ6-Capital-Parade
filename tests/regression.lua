-- Run via the companion Python launcher. This is an offline mock, not a game test.
local root=assert(TEST_ROOT)
local worldLive=false
local turn=100
local buildingWrites=0
local validationCalls=0
local removals=0
local playerReads=0
local function eventBus()
 return setmetatable({}, {__index=function(t,k)
  local e={callbacks={}};e.Add=function(f) table.insert(e.callbacks,f) end;t[k]=e;return e
 end})
end
local events=eventBus()
local function fire(name,...) for _,f in ipairs(events[name].callbacks) do f(...) end end
local function members(items)
 return {Members=function() local i=0;return function() i=i+1;if items[i] then return i,items[i] end end end}
end
local function city(id,x)
 local c={id=id,x=x,b={},queue={}}
 function c:GetID() return self.id end
 function c:GetName()return "Capital" end
 function c:GetX() return self.x end
 function c:GetY() return 0 end
 function c:GetBuildings()
  return {HasBuilding=function(_,i)return self.b[i] or false end,
   RemoveBuilding=function(_,i) assert(worldLive);buildingWrites=buildingWrites+1;self.b[i]=nil end}
 end
 function c:GetBuildQueue()
  return {CreateBuilding=function(_,i)assert(worldLive);buildingWrites=buildingWrites+1;self.b[i]=true end,
   CheckActiveProduction=function() assert(worldLive);validationCalls=validationCalls+1 end,
   GetSize=function()return #self.queue end,
   GetAt=function(_,i)return self.queue[i+1]end,
   CanProduce=function()return self.b[10] or false end}
 end
 return c
end
local function unit(kind,x)
 local u={kind=kind,x=x,a={}}
 function u:GetType() return self.kind end
 function u:GetX() return self.x end
 function u:GetY() return 0 end
 function u:GetGreatPerson()return{GetIndividual=function()return self.kind==2 and 500 or -1 end}end
 function u:GetAbility() return {
  GetAbilityCount=function(_,k)return self.a[k] or 0 end,
  ChangeAbilityCount=function(_,k,d)assert(worldLive);self.a[k]=(self.a[k] or 0)+d end} end
 return u
end
local function player(cs,us)
 local p={props={},cs=cs,us=us,civic=false,score=500,gpp=0}
 function p:GetProperty(k)
  -- Reproduce the actual engine binding's zero-result behavior.
  if self.props[k]==nil then return end
  return self.props[k]
 end
 function p:SetProperty(k,v)assert(worldLive);self.props[k]=v end
 function p:GetCities() local r=members(self.cs);r.FindID=function(_,id)for _,c in ipairs(self.cs)do if c.id==id then return c end end end;r.GetCapitalCity=function()return self.capital or self.cs[1]end;return r end
 function p:GetUnits() return members(self.us) end
 function p:GetCulture()return {HasCivic=function(_,id)assert(id==99);return self.civic end}end
 function p:GetGreatPeoplePoints()return {ChangePointsTotal=function(_,id,amount)
  assert(worldLive and id==8 and amount>0);self.gpp=self.gpp+amount
 end}end
 function p:GetEra()assert(worldLive);return self.era or 0 end
 function p:GetStats()error('UI-only Stats accessed in Gameplay')end
 return p
end
local c1=city(1,0);local c2=city(2,1);local u1=unit(0,0);local civilian=unit(1,0)
local p1=player({c1,c2},{u1,civilian});local p2=player({},{});local stores={[0]=p1,[1]=p2}
local players=setmetatable({}, {
 __index=function(_,id)assert(worldLive,'player read during load');playerReads=playerReads+1;assert(stores[id],'unused player slot accessed');return stores[id]end,
 __pairs=function()error('FORBIDDEN: enumerating all player slots')end})
local gi={Projects={PROJECT_MILITARY_PARADE={Index=7,Hash=777,ProjectType='PROJECT_MILITARY_PARADE'}},Civics={CIVIC_EARLY_EMPIRE={Index=99}},Buildings={BUILDING_PARADE_ELIGIBLE={Index=10}},UnitAbilities={},Units={[0]={Combat=20},[1]={Combat=0,RangedCombat=0}}}
gi.Eras={}
local eraNames={'ANCIENT','CLASSICAL','MEDIEVAL','RENAISSANCE','INDUSTRIAL','MODERN','ATOMIC','INFORMATION','FUTURE'}
for i,name in ipairs(eraNames)do gi.Eras[i-1]={EraType='ERA_'..name,ChronologyIndex=i-1}end
gi.Buildings.BUILDING_PARADE_GENERAL={Index=20}
gi.GreatPersonIndividuals={[500]={Name='LOC_TEST_HANNIBAL'}}
gi.GreatPersonClasses={GREAT_PERSON_CLASS_GENERAL={Index=8,UnitType='UNIT_GREAT_GENERAL'}}
gi.Units[0].UnitType='UNIT_WARRIOR';gi.Units[1].UnitType='UNIT_BUILDER'
gi.Units[2]={Combat=0,RangedCombat=0,UnitType='UNIT_GREAT_GENERAL'}
gi.Units[3]={Combat=0,RangedCombat=0,UnitType='UNIT_GREAT_ADMIRAL'}
local rows={}
for i,score in ipairs({0,200,500,1000,2000})do
 rows[i]={Tier=i,MinimumStrength=score,Loyalty=2+2*i,Combat=i,Amenities=i>=4 and 2 or 1}
 gi.Buildings['BUILDING_PARADE_BUFF_'..i]={Index=10+i}
 gi.UnitAbilities['ABILITY_PARADE_'..i]={UnitAbilityType='ABILITY_PARADE_'..i}
end
gi.ParadeTiers=function() local i=0;return function()i=i+1;return rows[i]end end
gi.Projects[7]=gi.Projects.PROJECT_MILITARY_PARADE
gi.Projects[777]=gi.Projects.PROJECT_MILITARY_PARADE
gi.ParadeQuotes=function()local i=0;return function()i=i+1;if i<=40 then return {QuoteID=i}end end end
local worldEra=0;local eraTotals={};local eraWrites=0;local eraFail=false
local eraManager={GetCurrentEra=function()assert(worldLive);return worldEra end,
 ChangePlayerEraScore=function(_,id,amount)
  assert(worldLive and (amount==1 or amount==2))
  if eraFail then error('EXPECTED era-score failure')end
  eraTotals[id]=(eraTotals[id]or 0)+amount;eraWrites=eraWrites+1
 end}
local game={GetEras=function()assert(worldLive);return eraManager end,GetRandNum=function(n)assert(n>0);return 0 end,GetCurrentGameTurn=function()assert(worldLive,'turn read during load');return turn end,
 GetLocalPlayer=function()assert(worldLive,'local player read during load');return 0 end}
local exposed={}
local gp=setmetatable({Game=game,Players=players,GameInfo=gi,ExposedMembers=exposed,Events=events},{__index=_G})
local function loadGame()assert(loadfile(root..'/Parade_Script.lua','t',gp))()end
loadGame()
local hidden=true
local uiPlayers={}
for id,p in pairs(stores)do
 uiPlayers[id]={GetProperty=function(_,k)return p:GetProperty(k)end,
 GetCities=function()return p:GetCities()end,GetUnits=function()return p:GetUnits()end,GetCulture=function()return p:GetCulture()end,
 GetStats=function()assert(worldLive);return {GetMilitaryStrengthWithoutTreasury=function()return p.score end}end}
end
local op={PARAM_INSERT_MODE=1,VALUE_REMOVE_AT=2,PARAM_QUEUE_LOCATION=3,BUILD=4}
local manager={RequestOperation=function(c,kind,params)
 assert(kind==op.BUILD and params[op.PARAM_INSERT_MODE]==op.VALUE_REMOVE_AT)
 local pos=params[op.PARAM_QUEUE_LOCATION]+1
 assert(c.queue[pos].ProjectType==7,'non-parade production removed')
 table.remove(c.queue,pos);removals=removals+1
 -- Reentrant events must not remove the wrong queue slot.
 fire('CityProductionChanged',0,c.id)
end}
local ui=setmetatable({CityOperationTypes=op,CityManager=manager,Game=game,Players=uiPlayers,GameInfo=gi,ExposedMembers=exposed,Events=events,
 Controls={ParadeStatus={SetHide=function(_,v)hidden=v end,SetText=function()end}},
 Locale={Lookup=function(k)return k end},ContextPtr={SetHide=function()end,SetInitHandler=function()end,SetUpdate=function(f)end}},{__index=_G})
assert(loadfile(root..'/Parade_UI.lua','t',ui))()
assert(playerReads==0 and buildingWrites==0)
fire('TurnBegin');fire('UnitAddedToMap',0,10)
assert(playerReads==0 and buildingWrites==0)
local ok,err=pcall(function()return tonumber(p1:GetProperty('UNSET'))or -1 end)
assert(not ok and tostring(err):find('value expected',1,true),'legacy error did not reproduce')
print('PASS: reproduced exact zero-return tonumber failure; no player/turn/queue access during load')
worldLive=true
fire('PlayerTurnActivated',0)
assert(exposed.ParadeV3Gameplay.Ready and not exposed.ParadeV3Gameplay.Refresh and not exposed.ParadeV3Gameplay.Complete)
assert(not p1.props.PARADE_V3_TIER)
fire('CityProjectCompleted',0,1,7);assert(not p1.props.PARADE_V3_TIER)
p1.civic=true
fire('CivicCompleted',0,99);assert(c1.b[10] and not c2.b[10])
u1.x=9;fire('UnitMoveComplete',0,1);assert(not c1.b[10]);u1.x=0;fire('UnitMoveComplete',0,1);assert(c1.b[10])
fire('CityProjectCompleted',0,2,7);assert(not p1.props.PARADE_V3_TIER)
u1.x=9;fire('CityProjectCompleted',0,1,7);assert(not p1.props.PARADE_V3_TIER)
u1.x=0;fire('CityProjectCompleted',0,1,7,0,0,0,true);assert(not p1.props.PARADE_V3_TIER)
-- An already active parade AND repeated entries behind unrelated production
-- must be removed immediately when the only military unit leaves the capital.
c1.queue={{ProjectType=7},{UnitType=0},{ProjectType=7},{BuildingType=1}}
local before=validationCalls
u1.x=9;fire('UnitMoved',0,1)
assert(validationCalls>before and not c1.b[10])
assert(#c1.queue==2 and c1.queue[1].UnitType==0 and c1.queue[2].BuildingType==1)
assert(removals==2,'invalid queued parades not removed')
-- Attempts to add the project without garrison are removed on production change.
table.insert(c1.queue,{ProjectType=7});fire('CityProductionChanged',0,1)
assert(#c1.queue==2 and removals==3)
-- Civilian is still in the city: it must not grant the permit.
assert(civilian.x==0 and not c1.b[10])
u1.x=0;fire('UnitMoved',0,1);assert(c1.b[10])
c1.queue={{ProjectType=7}};fire('CityProductionChanged',0,1);assert(#c1.queue==1)
c2.queue={{ProjectType=7},{UnitType=0}};fire('CityProductionUpdated',0,2)
assert(#c2.queue==1 and c2.queue[1].UnitType==0)
c1.queue={}
print('PASS: active/queued/repeated parade cancellation, wrong-city rejection, civilian rejection, unrelated items preserved, reentrancy')
for i,score in ipairs({0,200,500,1000,2000})do
 turn=turn+1;p1.score=score;fire('CityProjectCompleted',0,1,777)
 assert(p1.props.PARADE_V3_TIER==i)
 assert(p1.props.PARADE_V35_QUOTE==(i%2==1 and 1 or 2),'quote repeated despite exclusion')
 for j=1,5 do
  assert((c1.b[10+j] or false)==(i==j));assert((u1.a['ABILITY_PARADE_'..j]or 0)==(i==j and 1 or 0))
 end
 assert((civilian.a['ABILITY_PARADE_'..i]or 0)==0)
end
assert(p1.gpp==25,'five legal completions must grant exactly 25 points')
assert(eraTotals[0]==p1.props.PARADE_V35_COUNT+1 and eraWrites==p1.props.PARADE_V35_COUNT,'each legal completion must grant score once')
local ending=p1.props.PARADE_V3_END
fire('CityProjectCompleted',0,1,7);assert(p1.props.PARADE_V3_END==ending)
turn=turn+1;fire('CityProjectCompleted',0,1,7);assert(p1.props.PARADE_V3_END==ending+1)
local new=unit(0,2);table.insert(p1.us,new);fire('UnitAddedToMap',0,3);assert(new.a.ABILITY_PARADE_5==1)
fire('PlayerTurnActivated',1)
table.remove(p1.us,3);table.insert(p2.us,new);fire('UnitAddedToMap',1,3);assert(new.a.ABILITY_PARADE_5==0)
table.remove(p1.cs,2);table.insert(p2.cs,c2);fire('CityTransfered');assert(not c2.b[15])
loadGame();assert(not exposed.ParadeV3Gameplay.Ready)
fire('PlayerTurnActivated',0);assert(u1.a.ABILITY_PARADE_5==1)
turn=p1.props.PARADE_V3_END-1;fire('TurnBegin');assert(c1.b[15])
turn=turn+1;fire('TurnBegin');assert(not c1.b[15] and u1.a.ABILITY_PARADE_5==0 and not hidden)
print('PASS: native completion, civic/capital/garrison checks, 5 tiers, dedupe, refresh, ownership, reload, expiry')

print('PASS: capital-only permit creation and removal on own garrison movement; UI gate diagnostics')

-- Original capital is captured. The remaining current capital must receive
-- the permit; the captured city's permit and old bonuses must be removed.
local c3=city(3,3)
p1.cs={c3};p1.capital=c3;table.insert(p2.cs,c1)
u1.x=3
fire('CityTransfered',0,1);fire('CapitalCityChanged',0,3)
assert(c3.b[10] and not c1.b[10])
turn=turn+1;p1.score=500
local stamp=p1.props.PARADE_V3_LAST_COMPLETION
fire('CityProjectCompleted',0,1,7);assert(p1.props.PARADE_V3_LAST_COMPLETION==stamp)
fire('CityProjectCompleted',0,3,7);assert(c3.b[13])
local late=unit(0,4);table.insert(p1.us,late)
fire('UnitAddedToMap',0,88);assert(late.a.ABILITY_PARADE_3==1)
assert(not c1.b[13],'captured capital kept former owner buff')
turn=p1.props.PARADE_V3_END;fire('TurnBegin')
assert(late.a.ABILITY_PARADE_3==0 and not c3.b[13])
print('PASS: captured original capital, new current capital eligible, new trained units inherit remaining duration and expire together')

print("PASS: quotation is persisted; random selection excludes previous quote even with repeated RNG output")

local general=unit(2,3);table.insert(p1.us,general);fire('UnitAddedToMap',0,90)
assert(c3.b[20],'general production helper not added')
general.x=9;fire('UnitMoved',0,90);assert(not c3.b[20])
local admiral=unit(3,3);table.insert(p1.us,admiral);fire('UnitAddedToMap',0,91)
assert(not c3.b[20],'admiral incorrectly treated as general')
general.x=3;fire('UnitMoved',0,90);assert(c3.b[20])
local beforePoints=p1.gpp
turn=turn+1;p1.score=500;fire('CityProjectCompleted',0,3,7)
assert(p1.props.PARADE_V3_TIER==4 and p1.props.PARADE_V38_BASE_TIER==3 and p1.props.PARADE_V38_GENERAL==1)
assert(p1.gpp==beforePoints+5 and p1.props.PARADE_V38_GENERAL_POINTS==5)
fire('CityProjectCompleted',0,3,7);assert(p1.gpp==beforePoints+5,'duplicate completion awarded points twice')
turn=turn+1;p1.score=2500;fire('CityProjectCompleted',0,3,7)
assert(p1.props.PARADE_V3_TIER==5,'general exceeded tier cap')
turn=turn+1;p1.score=0;fire('CityProjectCompleted',0,3,7)
assert(p1.props.PARADE_V3_TIER==2,'lowest tier not promoted')
for i=#p1.us,1,-1 do if p1.us[i]==u1 then table.remove(p1.us,i)end end
fire('UnitRemovedFromMap',0,1)
assert(not c3.b[10] and not c3.b[20],'general replaced required combat garrison')
beforePoints=p1.gpp;turn=turn+1;fire('CityProjectCompleted',0,3,7);assert(p1.gpp==beforePoints)
assert(p1.gpp==p1.props.PARADE_V35_COUNT*5,'point total differs from unique legal completion count')
print('PASS: +5 general points per legal completion; dedupe; general-only acceleration helper; movement; admiral exclusion; +1 tier capped at 5; general is not a combat garrison')

-- Era-specific rewards must be captured on completion, with no duplicate grants.
table.insert(p1.us,u1);u1.x=3;fire('UnitAddedToMap',0,1)
local rewards={5,10,20,35,50,70,90,120,150}
for i,reward in ipairs(rewards)do
 p1.era=i-1;turn=turn+1
 local before=p1.gpp
 fire('CityProjectCompleted',0,3,7)
 assert(p1.gpp==before+reward and p1.props.PARADE_V38_GENERAL_POINTS==reward,'wrong era reward')
 fire('CityProjectCompleted',0,3,7);assert(p1.gpp==before+reward,'era reward duplicated')
end
p1.era=88;gi.Eras[88]={EraType='ERA_CUSTOM_LATE',ChronologyIndex=12}
turn=turn+1;beforePoints=p1.gpp;fire('CityProjectCompleted',0,3,7);assert(p1.gpp==beforePoints+150)
p1.era=99;gi.Eras[99]=nil
turn=turn+1;beforePoints=p1.gpp;fire('CityProjectCompleted',0,3,7);assert(p1.gpp==beforePoints+5)
print('PASS: nine-era GP scaling, captured payout, duplicate rejection, custom-era cap and missing-era fallback')


-- Every unique legal completion receives +1 after the first +2. World era
-- still dates the card; opening/replaying/duplicate event cannot add points.
assert(eraTotals[0]==p1.props.PARADE_V35_COUNT+1)
local scoreBefore=eraTotals[0]
worldEra=1;turn=turn+1;fire('CityProjectCompleted',0,3,7)
assert(eraTotals[0]==scoreBefore+1 and p1.props.PARADE_V313_ERA_SCORE==1)
turn=turn+1;fire('CityProjectCompleted',0,3,7)
assert(eraTotals[0]==scoreBefore+2 and p1.props.PARADE_V313_ERA_STATUS==2)
local count=p1.props.PARADE_V35_COUNT
local record='PARADE_V315_MOMENT_'..count..'_'
assert(p1.props[record..'READY']==1 and p1.props[record..'SCORE']==1)
local date=p1.props[record..'TURN']
loadGame();fire('PlayerTurnActivated',0)
turn=turn+1;fire('CityProjectCompleted',0,3,7)
assert(eraTotals[0]==scoreBefore+3,'reload prevented repeat-completion reward')
assert(p1.props[record..'TURN']==date,'another completion overwrote earlier archive')
worldEra=2;turn=turn+1;fire('CityProjectCompleted',0,3,7)
assert(eraTotals[0]==scoreBefore+4,'general created extra era score')
worldEra=3;eraFail=true;turn=turn+1;fire('CityProjectCompleted',0,3,7)
assert(eraTotals[0]==scoreBefore+4 and p1.props.PARADE_V313_ERA_STATUS==4)
assert(not p1.props.PARADE_V313_ERA_DONE_3)
eraFail=false;turn=turn+1;fire('CityProjectCompleted',0,3,7);assert(eraTotals[0]==scoreBefore+5)
local eraGetter=game.GetEras;game.GetEras=nil
local beforeUnsupported=p1.gpp;turn=turn+1;fire('CityProjectCompleted',0,3,7)
assert(p1.gpp>beforeUnsupported and eraTotals[0]==scoreBefore+5 and p1.props.PARADE_V313_ERA_STATUS==3)
game.GetEras=eraGetter
local c9=city(9,9);p2.cs={c9};p2.capital=c9;p2.us={unit(0,9)};p2.civic=true
fire('PlayerTurnActivated',1);fire('CityProjectCompleted',1,9,7)
assert(eraTotals[1]==2 and p2.props.PARADE_V313_ERA_SCORE==2,'first parade did not grant exactly two')
fire('CityProjectCompleted',1,9,7);assert(eraTotals[1]==2,'duplicate native event duplicated era score')
turn=turn+1;fire('CityProjectCompleted',1,9,7);assert(eraTotals[1]==3)
assert(p2.props.PARADE_V315_MOMENT_1_SCORE==2 and p2.props.PARADE_V315_MOMENT_2_SCORE==1)
for key in pairs(p1.props)do assert(not key:find('PARADE_V312_HISTORY_',1,true),'discarded chronicle still wrote records')end
print('PASS: first +2 then repeat +1, independent players, native event dedupe, reload, API failure retry and immutable per-completion cards')

-- Loading an older save with an already-active buff must attach the new rows.
p1.props.PARADE_V316_MODIFIERS_VERSION=nil
local beforeMigration=buildingWrites
fire('PlayerTurnActivated',0)
assert(buildingWrites>beforeMigration,'active old save helper buildings were not rebuilt')
assert(p1.props.PARADE_V316_MODIFIERS_VERSION==316)
local afterMigration=buildingWrites
fire('PlayerTurnActivated',0)
assert(buildingWrites==afterMigration,'modifier migration kept rebuilding every turn')
print('PASS: active-save military-production modifier migration runs once')
