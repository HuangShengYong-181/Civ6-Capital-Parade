print('[MilitaryParade][RELEASE_2_0_5] Parade_Diplomacy.lua loaded')
-- Gameplay reward and invitation service; loaded after shared rules.
ParadeDiplomacy={}
local D,R=ParadeDiplomacy,ParadeRules
local function N(p,k,d)return R.Number(p,k,d)end
local function Log(s)print('[Parade2][Diplomacy] '..s)end
function D.Notify(p,text)
 local n=N(p,'PARADE2_NOTICE_COUNT',0)+1
 p:SetProperty('PARADE2_NOTICE_'..n,text);p:SetProperty('PARADE2_NOTICE_COUNT',n)
end
function D.Leader(id)
 local c=PlayerConfigurations[id]
 return c and Locale.Lookup(c:GetLeaderName()) or tostring(id)
end
D.Luxuries=R.Luxuries
D.GoldFloor=R.GoldFloor
function D.Gift(from,to,resource,gold,minimum)
 if not R.Friendly(from,to) then return false,'关系不再符合参观条件' end
 local giver,host=Players[from],Players[to]
 if resource and resource>=0 then
  local legal=false;for _,id in ipairs(D.Luxuries(from,to)) do if id==resource then legal=true end end
  if not legal then return false,'所选奢侈品已无可交易余量，请重新选择' end
  if DealManager.HasPendingDeal and (DealManager.HasPendingDeal(from,to) or DealManager.HasPendingDeal(to,from)) then return false,'双方有待处理交易，请处理后重试' end
  DealManager.ClearWorkingDeal(DealDirection.OUTGOING,from,to)
  local deal=DealManager.GetWorkingDeal(DealDirection.OUTGOING,from,to)
  if not deal then return false,'无法建立交易草稿' end
  local item=deal:AddItemOfType(DealItemTypes.RESOURCES,from)
  if not item then return false,'无法加入奢侈品' end
  item:SetValueType(resource);item:SetAmount(1);item:SetFromPlayerID(from);item:SetToPlayerID(to);item:SetDuration(30)
  deal:Validate();if not item:IsValid() then return false,'原版交易校验未通过' end
  local before=0
  for _,d in ipairs(DealManager.GetPlayerDeals(from,to) or {}) do
   for _,i in ipairs(d:FindItemsByType(DealItemTypes.RESOURCES,DealItemSubTypes.NONE,from) or {}) do if i:GetValueType()==resource then before=before+i:GetAmount() end end
  end
  DealManager.EnactWorkingDeal(from,to)
  local after=0
  for _,d in ipairs(DealManager.GetPlayerDeals(from,to) or {}) do
   for _,i in ipairs(d:FindItemsByType(DealItemTypes.RESOURCES,DealItemSubTypes.NONE,from) or {}) do if i:GetValueType()==resource then after=after+i:GetAmount() end end
  end
  if after<=before then return false,'尚未确认交易生效；不会发放观摩奖励' end
  return true,Locale.Lookup(GameInfo.Resources[resource].Name)..' ×1（30回合；进口资源不可再次出售）'
 end
 gold=tonumber(gold)
 if gold and (gold~=gold or gold==math.huge or gold==-math.huge) then return false,'金币金额无效' end
 if not gold or gold~=math.floor(gold) or gold<(minimum or D.GoldFloor()) then return false,'金币不得低于最低贺金 '..D.GoldFloor() end
 if giver:GetTreasury():GetGoldBalance()<gold then return false,'国库余额不足，请重新选择贺礼' end
 giver:GetTreasury():ChangeGoldBalance(-gold);host:GetTreasury():ChangeGoldBalance(gold)
 return true,tostring(gold)..' 金币'
end
local function Knowledge(p)
 local t,c=0,0
 for row in GameInfo.Technologies() do if p:GetTechs():HasTech(row.Index) then t=t+1 end end
 for row in GameInfo.Civics() do if p:GetCulture():HasCivic(row.Index) then c=c+1 end end
 return t,c
end
-- Plans are frozen at ceremony completion; later host approval cannot change yields.
function D.PlanObservation(host,guest,prefix)
 if host:GetProperty(prefix..'READY') then return end
 local ht,hc=Knowledge(host);local gt,gc=Knowledge(guest)
 for _,part in ipairs({{'TECH',ht>gt,GameInfo.Technologies,host:GetTechs(),guest:GetTechs(),'HasTech'},
                       {'CIVIC',hc>gc,GameInfo.Civics,host:GetCulture(),guest:GetCulture(),'HasCivic'}}) do
  local candidates={}
  if part[2] then for row in part[3]() do
   if part[4][part[6]](part[4],row.Index) and not part[5][part[6]](part[5],row.Index) and not part[5]:HasBoostBeenTriggered(row.Index) then candidates[#candidates+1]=row.Index end
  end end
  host:SetProperty(prefix..part[1],#candidates>0 and candidates[Game.GetRandNum(#candidates,'Parade observation '..part[1])+1] or -1)
 end
 host:SetProperty(prefix..'SCIENCE',math.max(0,guest:GetTechs():GetScienceYield())*1.5)
 host:SetProperty(prefix..'CULTURE',math.max(0,guest:GetCulture():GetCultureYield())*1.5)
 host:SetProperty(prefix..'READY',1)
end
function D.Observation(host,guest,hostPoints,ledger,plan)
 ledger=ledger or ('PARADE2_DIRECT_OBS_'..N(guest,'PARADE2_DIRECT_OBS_COUNT',0)..'_')
 if not plan then
  guest:SetProperty('PARADE2_DIRECT_OBS_COUNT',N(guest,'PARADE2_DIRECT_OBS_COUNT',0)+1)
  plan=ledger..'PLAN_';D.PlanObservation(host,guest,plan)
 end
 local details={}
 for _,part in ipairs({{'TECH','SCIENCE',guest:GetTechs(),GameInfo.Technologies,'HasTech','尤里卡'},
                       {'CIVIC','CULTURE',guest:GetCulture(),GameInfo.Civics,'HasCivic','鼓舞'}}) do
  local done=ledger..part[1]..'_DONE'
  if not guest:GetProperty(done) then
   local id=N(host,plan..part[1],-1)
   local attempted=N(guest,ledger..part[1]..'_ATTEMPT',-1)
   -- A previously granted boost or a completed target receives the frozen fallback.
   if id>=0 and (attempted==id or (not part[3][part[5]](part[3],id) and not part[3]:HasBoostBeenTriggered(id))) then
    guest:SetProperty(ledger..part[1]..'_ATTEMPT',id)
    if not part[3]:HasBoostBeenTriggered(id) and not part[3][part[5]](part[3],id) then part[3]:TriggerBoost(id,1) end
    if not part[3]:HasBoostBeenTriggered(id) and not part[3][part[5]](part[3],id) then error(part[6]..'触发后未确认生效: '..id) end
    guest:SetProperty(ledger..part[1]..'_TEXT',part[6]..'：'..Locale.Lookup(part[4][id].Name))
   else
    -- Queue entitlements in saved properties first. Tick spends them after research selection.
    local amount=N(host,plan..part[2],0)
    local pending='PARADE2_PENDING_'..part[2]
    guest:SetProperty(pending,N(guest,pending,0)+amount)
    guest:SetProperty(ledger..part[1]..'_TEXT',string.format('%s %.1f（研究进度）',part[1]=='TECH' and '科研' or '文化',amount))
   end
   guest:SetProperty(done,1)
  end
  details[#details+1]=guest:GetProperty(ledger..part[1]..'_TEXT') or ''
 end
 local points=math.max(1,math.floor(hostPoints/2))
 if not guest:GetProperty(ledger..'GENERAL_DONE') then
  guest:GetGreatPeoplePoints():ChangePointsTotal(GameInfo.GreatPersonClasses['GREAT_PERSON_CLASS_GENERAL'].Index,points)
  guest:SetProperty(ledger..'GENERAL_DONE',1)
 end
 D.FlushKnowledge(guest)
 return tostring(points)..' 大将军点数；'..table.concat(details,'；'),'COMBINED'
end
local function Bound(g,host,session)
 return N(g,'PARADE2_INVITE_HOST',-1)==host and N(g,'PARADE2_INVITE_SESSION',-1)==session
end
local function Release(g,host,session,state)
 if Bound(g,host,session) then g:SetProperty('PARADE2_INVITE_HOST',-1);g:SetProperty('PARADE2_INVITE_STATE',state) end
end
local function Key(session,guest)return 'PARADE2_INVITE_'..session..'_'..guest end
local function CanPay(g,host)
 if g:GetTreasury():GetGoldBalance()>=D.GoldFloor() then return true end
 local ok,items=pcall(D.Luxuries,g:GetID(),host)
 -- API failure is not proof of poverty.
 if not ok then return nil end
 return #items>0
end
function D.Reconcile(g)
 local host=N(g,'PARADE2_INVITE_HOST',-1);if host<0 then return end
 local h=Players[host];local session=N(g,'PARADE2_INVITE_SESSION',-1)
 local state=h and h:GetProperty(Key(session,g:GetID()))
 if state=='RESELECT' and h:GetProperty('PARADE2_SETTLEMENT_POINTS_'..session)~=nil and CanPay(g,host)==false then D.RequestWaiver(host,g:GetID(),session);return end
 local live=state=='OFFERED' or state=='ACCEPTED' or state=='RESELECT'
 if not h or not live or (N(h,'PARADE2_SESSION',-1)~=session and h:GetProperty('PARADE2_SETTLEMENT_POINTS_'..session)==nil) then
  if h and live then h:SetProperty(Key(session,g:GetID()),'EXPIRED') end
  Release(g,host,session,state or 'EXPIRED')
 end
end
function D.RequestWaiver(hostID,guestID,session)
 local h,g=Players[hostID],Players[guestID];if not h or not g then return false end
 local key=Key(session,guestID);local state=h:GetProperty(key)
 if state~='OFFERED' and state~='ACCEPTED' and state~='RESELECT' then return false end
 if CanPay(g,hostID)~=false then return false end
 h:SetProperty(key,'WAIT_HOST');Release(g,hostID,session,'WAIT_HOST')
 if not h:GetProperty(key..'_WAIVER_REQUEST') then
  local n=N(h,'PARADE2_WAIVER_COUNT',0)+1
  h:SetProperty('PARADE2_WAIVER_'..n..'_SESSION',session);h:SetProperty('PARADE2_WAIVER_'..n..'_GUEST',guestID)
  h:SetProperty(key..'_WAIVER_REQUEST',n);h:SetProperty('PARADE2_WAIVER_COUNT',n)
 end
 D.Notify(h,D.Leader(guestID)..'无力赠礼，请您决定是否准许无礼观摩。')
 Log('WAIVER REQUEST host='..hostID..' guest='..guestID..' session='..session)
 if not h:IsHuman() then return D.DecideWaiver(hostID,{Guest=guestID,Session=session,Accept=1}) end
 return true
end
function D.DecideWaiver(hostID,params)
 local h=Players[hostID];local guestID,session=tonumber(params.Guest),tonumber(params.Session)
 local g=guestID and Players[guestID];if not h or not g or not session then return false end
 local key=Key(session,guestID)
 if h:GetProperty(key)~='WAIT_HOST' then return false end
 local active=h:GetProperty('PARADE2_ACTIVE_KIND')=='STRENGTH' and N(h,'PARADE2_SESSION',-1)==session
 if not active and h:GetProperty('PARADE2_SETTLEMENT_POINTS_'..session)==nil then h:SetProperty(key,'EXPIRED');return false end
 local accept=params.Accept==1 and R.Friendly(guestID,hostID)
 h:SetProperty(key,accept and 'NO_GIFT_ACCEPTED' or 'DECLINED')
 Release(g,hostID,session,accept and 'NO_GIFT_ACCEPTED' or 'DECLINED')
 D.Notify(h,D.Leader(guestID)..(accept and '获准无礼出席。' or '未获准出席。'))
 D.Notify(g,D.Leader(hostID)..(accept and '准许您无礼观摩。' or '拒绝了您的无礼观摩请求。'))
 if accept and h:GetProperty('PARADE2_SETTLEMENT_POINTS_'..session)~=nil then D.Settle(hostID,session,N(h,'PARADE2_SETTLEMENT_POINTS_'..session,0)) end
 return true
end
function D.Invite(hostID,guestID,session)
 print('[Parade2][INVITE] version='..R.Version..' host='..tostring(hostID)..' guest='..tostring(guestID)..' session='..tostring(session))
 local h,g=Players[hostID],Players[guestID]
 local function Reject(reason)print('[Parade2][INVITE] rejected: '..reason);if h then D.Notify(h,'邀请未发送：'..reason) end;return false end
 if not h or not g or not g:IsMajor() or hostID==guestID or h:GetProperty('PARADE2_ACTIVE_KIND')~='STRENGTH' or N(h,'PARADE2_SESSION',-1)~=session then return Reject('请在强军阅兵筹备期间邀请有效领袖') end
 if N(h,'PARADE2_INVITE_COUNT',0)>=3 then return Reject('本次已邀请3位领袖') end
 local friendly,reason=R.Friendly(guestID,hostID)
 if not friendly then return Reject(reason or '对方关系尚未达到友好') end
 local key='PARADE2_INVITE_'..session..'_'..guestID
 if h:GetProperty(key)~=nil then return Reject('已向这位领袖发送过邀请') end
 -- One outstanding invitation per recipient avoids replacing another host's offer.
 D.Reconcile(g)
  if N(g,'PARADE2_INVITE_HOST',-1)>=0 then return Reject('对方仍有待处理的阅兵邀请或贺礼') end
 h:SetProperty(key,'OFFERED');h:SetProperty('PARADE2_INVITE_COUNT',N(h,'PARADE2_INVITE_COUNT',0)+1)
 g:SetProperty('PARADE2_INVITE_HOST',hostID);g:SetProperty('PARADE2_INVITE_SESSION',session)
 g:SetProperty('PARADE2_INVITE_STATE','OFFERED')
 D.Notify(g,D.Leader(hostID)..'邀请您观摩强军阅兵。接受前请选择贺礼；奖励每时代限领取一次。')
 D.Notify(h,'已邀请'..D.Leader(guestID)..'；贺礼在阅兵礼成时交付。')
 if not g:IsHuman() then D.Tick(g) end
 return true
end
function D.Answer(guestID,params)
 local g=Players[guestID];local hostID=N(g,'PARADE2_INVITE_HOST',-1);local h=hostID>=0 and Players[hostID]
 local session=N(g,'PARADE2_INVITE_SESSION',-1)
 if not h or session~=tonumber(params.Session) or hostID~=tonumber(params.Host) or not R.Friendly(guestID,hostID) then return false end
 local key='PARADE2_INVITE_'..session..'_'..guestID
 if h:GetProperty(key)~='OFFERED' and h:GetProperty(key)~='RESELECT' then return false end
 if params.Accept~=1 then
  h:SetProperty(key,'DECLINED');g:SetProperty('PARADE2_INVITE_HOST',-1);g:SetProperty('PARADE2_INVITE_STATE','DECLINED');D.Notify(h,D.Leader(guestID)..'婉拒了本次阅兵邀请。');return true
 end
 if params.NoGift==1 then return D.RequestWaiver(hostID,guestID,session) end
  local resource=tonumber(params.Resource) or -1;local gold=tonumber(params.Gold) or 0
 if resource~=math.floor(resource) or gold~=gold or gold==math.huge or gold==-math.huge then return false end
 if resource>=0 then
  local found=false;for _,id in ipairs(D.Luxuries(guestID,hostID)) do if resource==id then found=true end end
  if not found then D.Notify(g,'选择的奢侈品不可交易，请重新选择。');return false end
 elseif gold<D.GoldFloor() or gold~=math.floor(gold) or gold>g:GetTreasury():GetGoldBalance() then D.Notify(g,'金币金额不符合要求，请重新选择。');return false end
 h:SetProperty(key..'_MIN_GOLD',D.GoldFloor());h:SetProperty(key..'_RESOURCE',resource);h:SetProperty(key..'_GOLD',gold);h:SetProperty(key,'ACCEPTED');g:SetProperty('PARADE2_INVITE_STATE','ACCEPTED')
 D.Notify(h,D.Leader(guestID)..'已接受阅兵邀请，将在礼成时交付贺礼。'..(not g:IsHuman() and resource<0 and gold>g:GetTreasury():GetGoldBalance() and '来宾正在筹备贺金，备齐后才会实际交付。' or ''))
 local settlement=h:GetProperty('PARADE2_SETTLEMENT_POINTS_'..session)
 if settlement~=nil then D.Settle(hostID,session,tonumber(settlement) or 0) end
 return true
end
local awarding={}
local function AwardObservation(h,g,session,points)
 local key=Key(session,g:GetID());local era=N(h,key..'_ERA',R.Era())
 local ledger='PARADE2_OBS_'..era..'_'
 local lock=g:GetID()..':'..era;if awarding[lock] then return false end
 if N(g,'PARADE2_OBSERVATION_ERA',-1)==era or g:GetProperty(ledger..'DONE') then return true end
 -- Bind the first attempt to its original plan so retries cannot change its targets.
 if not g:GetProperty(ledger..'HOST') then
  g:SetProperty(ledger..'HOST',h:GetID());g:SetProperty(ledger..'SESSION',session);g:SetProperty(ledger..'POINTS',points)
 end
 local source=Players[N(g,ledger..'HOST',h:GetID())]
 local sourceKey=Key(N(g,ledger..'SESSION',session),g:GetID())
 if not g:GetProperty(ledger..'RETRY') then
  local n=N(g,'PARADE2_AWARD_RETRY_COUNT',0)+1;local prefix='PARADE2_AWARD_RETRY_'..n..'_'
  g:SetProperty(prefix..'HOST',source:GetID());g:SetProperty(prefix..'SESSION',N(g,ledger..'SESSION',session))
  g:SetProperty('PARADE2_AWARD_RETRY_COUNT',n);g:SetProperty(ledger..'RETRY',n)
 end
 local planned,err=pcall(D.PlanObservation,source,g,sourceKey..'_OBS_');if not planned then Log('OBSERVATION PLAN ERROR '..tostring(err));return false end
 awarding[lock]=true
 local called,text=pcall(D.Observation,source,g,N(g,ledger..'POINTS',points),ledger,sourceKey..'_OBS_')
 awarding[lock]=nil
 if not called then Log('OBSERVATION ERROR host='..h:GetID()..' guest='..g:GetID()..' '..tostring(text));return false end
 g:SetProperty(ledger..'DONE',1);g:SetProperty('PARADE2_OBSERVATION_ERA',era)
 g:SetProperty('PARADE2_LAST_OBSERVATION',text);g:SetProperty('PARADE2_REWARD_SOUND_COUNT',N(g,'PARADE2_REWARD_SOUND_COUNT',0)+1)
 D.Notify(g,'观兵问道：获得 '..text..'。');Log('OBSERVATION SETTLED host='..h:GetID()..' guest='..g:GetID()..' session='..session..' '..text)
 return true
end
function D.Settle(hostID,session,points)
 local h=Players[hostID];if not h then return end
 h:SetProperty('PARADE2_SETTLEMENT_SESSION',session);h:SetProperty('PARADE2_SETTLEMENT_POINTS',points);h:SetProperty('PARADE2_SETTLEMENT_POINTS_'..session,points)
 for _,g in ipairs(PlayerManager.GetAliveMajors()) do
  local gid=g:GetID();local key=Key(session,gid);local state=h:GetProperty(key)
  if state=='ACCEPTED' or state=='RESELECT' or state=='WAIT_HOST' or state=='NO_GIFT_ACCEPTED' or state=='SETTLED' or state=='ATTENDED' then
   if h:GetProperty(key..'_ERA')==nil then h:SetProperty(key..'_ERA',R.Era()) end
   local planned,planError=pcall(D.PlanObservation,h,g,key..'_OBS_')
   if not planned then Log('OBSERVATION PLAN ERROR '..tostring(planError)) end
   if state=='SETTLED' or state=='ATTENDED' then
    if N(h,key..'_AWARD_DONE',0)~=1 and AwardObservation(h,g,session,points) then h:SetProperty(key..'_AWARD_DONE',1) end
   elseif not R.Friendly(gid,hostID) then h:SetProperty(key,'CANCELLED');Release(g,hostID,session,'CANCELLED')
   elseif state=='NO_GIFT_ACCEPTED' then
    h:SetProperty(key,'ATTENDED');Release(g,hostID,session,'ATTENDED')
    D.Notify(h,D.Leader(gid)..'无礼出席，未收取贺礼。')
    if AwardObservation(h,g,session,points) then h:SetProperty(key..'_AWARD_DONE',1) end
   elseif state~='WAIT_HOST' then
    local called,ok,text=pcall(D.Gift,gid,hostID,N(h,key..'_RESOURCE',-1),N(h,key..'_GOLD',0),N(h,key..'_MIN_GOLD',D.GoldFloor()))
    if not called then text=tostring(ok);ok=false end
    if not ok and not g:IsHuman() and N(h,key..'_RESOURCE',-1)>=0 then
     called,ok,text=pcall(D.Gift,gid,hostID,-1,D.GoldFloor())
     if not called then text=tostring(ok);ok=false end
     if ok then h:SetProperty(key..'_RESOURCE',-1);h:SetProperty(key..'_GOLD',D.GoldFloor()) end
    end
    if ok then
     h:SetProperty(key..'_RECEIPT',text);h:SetProperty(key,'SETTLED');Release(g,hostID,session,'SETTLED')
     h:SetProperty('PARADE2_GIFT_SOUND_COUNT',N(h,'PARADE2_GIFT_SOUND_COUNT',0)+1)
     Log('GIFT SETTLED host='..hostID..' guest='..gid..' session='..session..' gift='..text)
     D.Notify(h,D.Leader(gid)..'赠礼已到账：'..text..'。')
     if AwardObservation(h,g,session,points) then h:SetProperty(key..'_AWARD_DONE',1) end
    else
     Log('GIFT FAILED host='..hostID..' guest='..gid..' session='..session..' resource='..N(h,key..'_RESOURCE',-1)..' gold='..N(h,key..'_GOLD',0)..' balance='..g:GetTreasury():GetGoldBalance()..' reason='..tostring(text))
     h:SetProperty(key..'_ERROR',tostring(text));h:SetProperty(key,'RESELECT')
     if Bound(g,hostID,session) then g:SetProperty('PARADE2_INVITE_STATE','RESELECT') end
     if not D.RequestWaiver(hostID,gid,session) then D.Notify(g,tostring(text)..'；请重新选择贺礼。') end
    end
   end
  elseif state=='OFFERED' then h:SetProperty(key,'EXPIRED');Release(g,hostID,session,'EXPIRED') end
 end
end
function D.Cancel(hostID,session)
 local h=Players[hostID]
 for _,p in ipairs(PlayerManager.GetAliveMajors()) do local key='PARADE2_INVITE_'..session..'_'..p:GetID();local state=h:GetProperty(key)
  if state=='OFFERED' or state=='ACCEPTED' or state=='RESELECT' or state=='WAIT_HOST' or state=='NO_GIFT_ACCEPTED' then h:SetProperty(key,'CANCELLED');Release(p,hostID,session,'CANCELLED');D.Notify(p,'主办方停止筹备本次阅兵，参观邀请已取消，未扣除贺礼。') end
 end
end
function D.FlushKnowledge(p)
 for _,part in ipairs({{'SCIENCE',p:GetTechs(),'GetResearchingTech','ChangeCurrentResearchProgress'},
                       {'CULTURE',p:GetCulture(),'GetProgressingCivic','ChangeCurrentCulturalProgress'}}) do
  local key='PARADE2_PENDING_'..part[1];local amount=N(p,key,0)
  if amount>0 and part[2][part[3]](part[2])>=0 then
   part[2][part[4]](part[2],amount);p:SetProperty(key,0)
   p:SetProperty('PARADE2_KNOWLEDGE_PAID_'..part[1],N(p,'PARADE2_KNOWLEDGE_PAID_'..part[1],0)+amount)
   Log('KNOWLEDGE PAID player='..p:GetID()..' kind='..part[1]..' amount='..amount)
  end
 end
end
function D.Tick(p)
 D.Reconcile(p)
 local flushed,err=pcall(D.FlushKnowledge,p);if not flushed then Log('KNOWLEDGE RETRY '..tostring(err)) end
 for n=1,N(p,'PARADE2_AWARD_RETRY_COUNT',0) do
  local prefix='PARADE2_AWARD_RETRY_'..n..'_'
  if N(p,prefix..'DONE',0)~=1 then
   local h=Players[N(p,prefix..'HOST',-1)];local session=N(p,prefix..'SESSION',-1)
   if h then
    local key=Key(session,p:GetID());local state=h:GetProperty(key)
    if state=='SETTLED' or state=='ATTENDED' then
     if AwardObservation(h,p,session,N(h,'PARADE2_SETTLEMENT_POINTS_'..session,0)) then h:SetProperty(key..'_AWARD_DONE',1);p:SetProperty(prefix..'DONE',1) end
    else p:SetProperty(prefix..'DONE',1) end
   end
  end
 end
 if not p:IsHuman() then
  local host=N(p,'PARADE2_INVITE_HOST',-1);local state=p:GetProperty('PARADE2_INVITE_STATE')
  if host>=0 and (state=='OFFERED' or state=='RESELECT') then
   local session=N(p,'PARADE2_INVITE_SESSION',-1);local h=Players[host]
   if not h then return end
   local key='PARADE2_INVITE_'..session..'_'..p:GetID()
   -- Persist one decision per invitation, independent of gift reselection and
   -- repeated turn/UI callbacks. Alliances never roll a rejection.
   local accepted=h:GetProperty(key..'_AI_ACCEPT')
   if accepted==nil and state=='RESELECT' then
    -- Legacy save: reselection means attendance was already accepted.
    accepted=1;h:SetProperty(key..'_AI_ACCEPT',1)
   end
   if accepted==nil then
    local chance,relation=R.AttendanceChance(p:GetID(),host)
    local roll=chance==100 and -1 or Game.GetRandNum(100,'Parade AI attendance')
    accepted=(chance==100 or roll<chance) and 1 or 0
    h:SetProperty(key..'_AI_CHANCE',chance);h:SetProperty(key..'_AI_RELATION',relation)
    h:SetProperty(key..'_AI_ROLL',roll);h:SetProperty(key..'_AI_ACCEPT',accepted)
    Log('AI ATTEND host='..host..' guest='..p:GetID()..' session='..session..' relation='..relation..' chance='..chance..' roll='..roll..' accepted='..accepted)
   end
   local gold=D.GoldFloor();local cash=p:GetTreasury():GetGoldBalance()>=gold
   local lux={};if not cash then local ok,items=pcall(D.Luxuries,p:GetID(),host);if ok then lux=items end end
   if accepted==1 and not cash and #lux==0 then D.RequestWaiver(host,p:GetID(),session);return end
   D.Answer(p:GetID(),{Host=host,Session=session,Accept=accepted,Resource=lux[1] or -1,Gold=gold})
  end
 end
end
