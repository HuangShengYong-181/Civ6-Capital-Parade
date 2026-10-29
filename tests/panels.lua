-- Test only our screen extensions, with small contracts for stock UI code.
local root=assert(TEST_ROOT)
local function event()return {Add=function()end}end
local events=setmetatable({},{__index=function(t,k)local v=event();t[k]=v;return v end})
local civic=true
local military=true
local cap={GetID=function()return 1 end}
local player={GetCities=function()return {GetCapitalCity=function()return cap end}end,
GetCulture=function()return {HasCivic=function()return civic end}end,
GetUnits=function()return {Members=function()local first=true;return function()
 if first and military then first=false;return 1,{GetType=function()return 0 end,GetX=function()return 10 end,GetY=function()return 20 end}end
end end}end}
local function city(id)return {GetID=function()return id end,GetOwner=function()return 0 end,GetX=function()return 10 end,GetY=function()return 20 end}end
local selected=city(2)
local stockCalls=0
local env={GameInfo={Civics={CIVIC_EARLY_EMPIRE={Index=9}},Units={[0]={Combat=20}}},
Players={[0]=player},UI={GetHeadSelectedCity=function()return selected end},
Locale={Lookup=function(k)return k end},ContextPtr={IsHidden=function()return true end},Events=events}
setmetatable(env,{__index=_G})
env.include=function()
 if not env.GetData then
  env.GetData=function()return {City=selected,ProjectItems={{Type='OTHER_PROJECT'},{Type='PROJECT_MILITARY_PARADE'},{Type='ANOTHER_PROJECT'}}}end
  env.AdvanceProject=function()stockCalls=stockCalls+1 end
  env.Refresh=function()end
 end
end
assert(loadfile(root..'/Parade_ProductionPanel.lua','t',env))()
local data=env.GetData();assert(#data.ProjectItems==2 and data.ProjectItems[2].Type=='ANOTHER_PROJECT')
selected=city(1);data=env.GetData();assert(#data.ProjectItems==3 and not data.ProjectItems[2].Disabled)
military=false;data=env.GetData();assert(data.ProjectItems[2].Disabled)
env.AdvanceProject(selected,{ProjectType='PROJECT_MILITARY_PARADE'});assert(stockCalls==0)
env.AdvanceProject(selected,{ProjectType='OTHER_PROJECT'});assert(stockCalls==1)
military=true;civic=false;env.AdvanceProject(selected,{ProjectType='PROJECT_MILITARY_PARADE'});assert(stockCalls==1)
civic=true;env.AdvanceProject(selected,{ProjectType='PROJECT_MILITARY_PARADE'});assert(stockCalls==2)
cap={GetID=function()return 2 end};data=env.GetData();assert(#data.ProjectItems==2)
selected=city(2);assert(#env.GetData().ProjectItems==3)
print('PASS: non-capital parade hidden with other items preserved; stale clicks blocked; relocated capital visible')
local names={};local control={SetIcon=function(_,name)names[#names+1]=name;return true end,SetHide=function()end}
local instance={Icon=control,UnlockIcon={}}
local im={GetInstance=function()return instance end}
env.PopulateUnlockablesForCivic=function(_,_,items)
 local it=items:GetInstance();assert(it.UnlockIcon==instance.UnlockIcon)
 assert(it.Icon:SetIcon('ICON_PROJECT_MILITARY_PARADE'));it.Icon:SetHide(false)
 it.Icon:SetIcon('ICON_UNIT_SCOUT')
 return 2
end
assert(loadfile(root..'/Parade_CivicIcons.lua','t',env))()
assert(env.PopulateUnlockablesForCivic(0,9,im,nil)==2)
assert(names[1]=='ICON_PROJECT_MILITARY_PARADE_COLOR' and names[2]=='ICON_UNIT_SCOUT')
print('PASS: civic foreground selects colour definition; unrelated icons unchanged')
