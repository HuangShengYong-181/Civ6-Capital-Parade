print('[MilitaryParade][RELEASE_2_0_5] Parade_Delegation.lua loaded')
include('InstanceManager')
include('Parade_Rules.lua')
local function InitializeLabels()
 Controls.OpenText:SetText("阅兵外交")
 Controls.InviteTitle:SetText('观兵问道 · 阅兵请柬')
 Controls.InviteStudyTitle:SetText('观礼与研习')
 Controls.InviteGiftTitle:SetText('选择随行贺礼')
 Controls.InviteFootnote:SetText('贺礼于礼成时交付，接受邀请不会立即扣除。奖励与来宾状态将在礼成总结中显示。')
 Controls.InviteDismissText:SetText('稍后答复')
 Controls.Title:SetText("阅兵使团")
 Controls.GoldLabel:SetText("金币金额")
 Controls.AcceptText:SetText("携礼赴会 · 接受邀请")
 Controls.DeclineText:SetText("婉拒邀请")
 Controls.CloseText:SetText("关闭")
 Controls.GiftTitle:SetText('万邦来贺')
 Controls.GiftSubtitle:SetText('阅兵礼成 · 来宾赠礼汇总')
 Controls.GiftFooter:SetText('仅“已到账”的贺礼完成了实际交付；无礼出席与待处理请求单独列明。')
 Controls.GiftCloseText:SetText('收讫 · 返回地图')
 Controls.GiftCountLabel:SetText('来宾答复')
 Controls.GiftSettledLabel:SetText('赠礼到账')
 Controls.WaiverTitle:SetText('无礼观摩请求')
 Controls.WaiverAcceptText:SetText('准许观摩')
 Controls.WaiverDeclineText:SetText('拒绝出席')
 Controls.WaiverLaterText:SetText('稍后决定')
end
InitializeLabels()

local R=ParadeRules
local rows=InstanceManager:new('DelegationRow','Button',Controls.Rows)
local giftChoices=InstanceManager:new('GiftChoiceRow','Choice',Controls.GiftChoices)
local waiverShown=nil
local waiverSeen={}
local function ShowWaiver(session,guest)
 local p=Players[Game.GetLocalPlayer()]
 if not p or p:GetProperty('PARADE2_INVITE_'..session..'_'..guest)~='WAIT_HOST' then return end
 local c=PlayerConfigurations[guest]
 local civ=c and c.GetCivilizationShortDescription and Locale.Lookup(c:GetCivilizationShortDescription()) or ''
 local leader=c and Locale.Lookup(c:GetLeaderName()) or tostring(guest)
 Controls.WaiverBody:SetText('卑微的'..civ..'领袖'..leader..'，如今贫困至极，无力奉上贺礼，却仍渴望观摩贵国军威、研习治军之道。您是否准许其出席？[NEWLINE][NEWLINE]准许后，对方无需赠礼，仍可获得本时代尚未领取的观摩奖励。')
 Controls.WaiverSubtitle:SetText('第 '..session..' 场阅兵 · 无礼观摩请求')
 Controls.WaiverAccept:SetDisabled(false);Controls.WaiverDecline:SetDisabled(false)
 Controls.WaiverPanel:SetHide(false);Controls.Panel:SetHide(true)
 waiverShown={Session=session,Guest=guest};waiverSeen[session..':'..guest]=true
end
local function DecideWaiver(accept)
 if not waiverShown then return end
 local params={Action='DECIDE_WAIVER',Guest=waiverShown.Guest,Session=waiverShown.Session,Accept=accept,OnStart='Parade2Action'}
 UI.RequestPlayerOperation(Game.GetLocalPlayer(),PlayerOperations.EXECUTE_SCRIPT,params)
 Controls.WaiverAccept:SetDisabled(true);Controls.WaiverDecline:SetDisabled(true)
end
Controls.WaiverAccept:RegisterCallback(Mouse.eLClick,function()DecideWaiver(1)end)
Controls.WaiverDecline:RegisterCallback(Mouse.eLClick,function()DecideWaiver(0)end)
Controls.WaiverLater:RegisterCallback(Mouse.eLClick,function()Controls.WaiverPanel:SetHide(true);waiverShown=nil end)

local selection=1
local gifts={}
local seen=nil
local notice=''
local clock=0
local lastInviteSession=nil
local lastIncoming=nil
local lastSignature=nil
local statusNames={OFFERED='已邀请，等待答复',ACCEPTED='已接受，礼成时赠礼',SETTLED='贺礼已到账',DECLINED='已婉拒',RESELECT='等待重新选择或备齐贺礼',EXPIRED='邀请已过期',CANCELLED='已取消',WAIT_HOST='无力赠礼，等待主办方裁决',NO_GIFT_ACCEPTED='获准无礼出席',ATTENDED='已无礼出席'}
local function Number(p,k,d)return R.Number(p,k,d)end
local function Leader(id)local c=PlayerConfigurations[id];return c and Locale.Lookup(c:GetLeaderName()) or tostring(id)end
local function Send(params)
 params.OnStart='Parade2Action'
 UI.RequestPlayerOperation(Game.GetLocalPlayer(),PlayerOperations.EXECUTE_SCRIPT,params)
end
local function HasTradeRoute(from,to)
 local p=Players[from];if not p then return false end
 for _,route in ipairs(p:GetTrade():GetOutgoingRoutes() or {}) do if route.DestinationCityPlayer==to then return true end end
 for _,route in ipairs(p:GetTrade():GetIncomingRoutes() or {}) do if route.OriginCityPlayer==to then return true end end
 return false
end
ExposedMembers.ParadeV2UI={HasTradeRoute=HasTradeRoute,GetFriendlyState=function(from,to)return R.NativeFriendly(from,to)end,GetRelationState=function(from,to)return R.NativeRelation(from,to)end}
local function GiftText(p)
 local g=gifts[selection]
 if not g then return '' end
 if g==-2 then Controls.GoldInput:SetHide(true);Controls.GoldLabel:SetHide(true);return '当前无力赠礼，可请求主办方准许无礼观摩。' end
 if g<0 then
  Controls.GoldInput:SetHide(false);Controls.GoldLabel:SetHide(false)
  return '国库贺金 · 最低 '..R.GoldFloor()..' 金币。请在下方填写金额。'
 end
 Controls.GoldInput:SetHide(true);Controls.GoldLabel:SetHide(true)
 return '奢侈品贺礼：'..Locale.Lookup(GameInfo.Resources[g].Name)..' ×1，持续30回合。完成时交付；若余量不足需重新选择。'
end
local Refresh
Refresh=function(reset)
 local id=Game.GetLocalPlayer();local p=id and id>=0 and Players[id];if not p then return end
 rows:ResetInstances()
 local host=Number(p,'PARADE2_INVITE_HOST',-1)
 local state=p:GetProperty('PARADE2_INVITE_STATE')
 local offered=host>=0 and (state=='OFFERED' or state=='RESELECT')
 Controls.Panel:SetSizeY(520)
 Controls.InvitePanel:SetHide(not offered)
 if offered then Controls.Panel:SetHide(true); end
 for _,c in ipairs({Controls.Accept,Controls.Decline,Controls.GoldInput,Controls.GoldLabel}) do c:SetHide(not offered) end
 Controls.GiftText:SetText('')
 if offered then
  local rewarded=Number(p,'PARADE2_OBSERVATION_ERA',-1)==R.Era() or Number(p,'PARADE2_OBS_'..R.Era()..'_DONE',0)==1
  Controls.InviteHost:SetText('主办方  ·  '..Leader(host))
  Controls.InviteStudyBody:SetText('随行将领观阵习武，使团研习其军制与技艺。[NEWLINE]'..(rewarded and '本时代已完成研习，此次以礼相交，不再重复领取研习奖励。' or '首次观摩：科技、文化分别结算尤里卡与鼓舞；无可用启发的分项，获得自身每回合产出1.5倍的研究进度。'))
  local ok,items=pcall(R.Luxuries,id,host)
  gifts={-1};if ok then for _,v in ipairs(items) do gifts[#gifts+1]=v end end
  if ok and #items==0 and p:GetTreasury():GetGoldBalance()<R.GoldFloor() then gifts={-2} end
  if reset or selection>#gifts then selection=1;Controls.GoldInput:SetText(tostring(R.GoldFloor())) end
  Controls.GiftText:SetText(GiftText(p))
  Controls.AcceptText:SetText(gifts[selection]==-2 and '请求无礼观摩' or '接受邀请')
  giftChoices:ResetInstances()
  for index,gift in ipairs(gifts) do
   local choice=giftChoices:GetInstance();local selected=index
   choice.ChoiceText:SetText((selection==index and '● ' or '○ ')..(gift==-2 and '无力赠礼' or gift<0 and '金币贺礼' or Locale.Lookup(GameInfo.Resources[gift].Name)))
   choice.Choice:RegisterCallback(Mouse.eLClick,function()selection=selected;Refresh(false)end)
  end
  Controls.GiftChoices:CalculateSize();Controls.GiftChoices:ReprocessAnchoring();Controls.GiftChoiceScroll:CalculateInternalSize()
 elseif p:GetProperty('PARADE2_ACTIVE_KIND')=='STRENGTH' then
  Controls.Title:SetText('强军阅兵 · 第'..Number(p,'PARADE2_SESSION',0)..'场 · 邀请领袖')
  Controls.Description:SetText('邀请友好领袖，共襄强军盛典。[NEWLINE]已邀请 '..Number(p,'PARADE2_INVITE_COUNT',0)..'/3 · 来宾自选贺礼，于礼成后交付。[NEWLINE]同盟必定接受 · 宣友80% · 友好50% · 每场重新邀请。')
  Controls.GiftText:SetText('来宾答复与交付状态见上方列表；可滚动查看其他领袖。')
  local session=Number(p,'PARADE2_SESSION',0)
  for _,g in ipairs(PlayerManager.GetAliveMajors()) do local gid=g:GetID()
   if gid~=id and p:GetDiplomacy():HasMet(gid) then
    local eligible=R.Friendly(gid,id)
    local key='PARADE2_INVITE_'..session..'_'..gid;local status=p:GetProperty(key)
    local reason=g:GetDiplomacy():IsAtWarWith(id) and '正在交战' or '对方关系尚未达到友好'
    local instance=rows:GetInstance();instance.ButtonText:SetText(Leader(gid)..' · '..(statusNames[status] or status or (eligible and '点击邀请' or reason)))
    local blocked=Number(g,'PARADE2_INVITE_HOST',-1)>=0
    if not status and blocked then instance.ButtonText:SetText(Leader(gid)..' · 尚有待处理的其他邀请') end
    instance.Button:SetDisabled(not eligible or status~=nil or blocked or Number(p,'PARADE2_INVITE_COUNT',0)>=3)
    instance.Button:RegisterCallback(Mouse.eLClick,function()Send({Action='INVITE',Guest=gid,Session=session})end)
   end
  end
 else
  Controls.Title:SetText('阅兵使团 · 消息')
  Controls.Description:SetText((state=='ACCEPTED' and '您已接受邀请，等待阅兵完成。尚未交付贺礼。[NEWLINE]' or '')..'强军阅兵筹备期间可在这里邀请友好领袖。收到邀请后，可自选富余奢侈品或金币贺礼。')
  for _,other in ipairs(PlayerManager.GetAliveMajors()) do local oid=other:GetID()
   if oid~=id and not other:IsHuman() and p:GetDiplomacy():HasMet(oid) then
    local kind=other:GetProperty('PARADE2_ACTIVE_KIND');local total=Number(other,'PARADE_V35_COUNT',0)
    local row=rows:GetInstance()
    row.ButtonText:SetText(Leader(oid)..' · '..(kind and ('正在筹备'..(R.Names[kind] or '阅兵')) or '当前未筹备')..' · 本局礼成 '..total..' 场')
    row.Button:SetDisabled(true)
   end
  end
  local count=Number(p,'PARADE2_NOTICE_COUNT',0)
  for i=math.max(1,count-5),count do local text=p:GetProperty('PARADE2_NOTICE_'..i);if text then local instance=rows:GetInstance();instance.ButtonText:SetText(text);instance.Button:SetToolTipString(text);instance.Button:SetDisabled(false);instance.Button:RegisterCallback(Mouse.eLClick,function()Controls.Description:SetText((text:gsub('\n','[NEWLINE]')))end) end end
 end
 if not offered then
  for n=1,Number(p,'PARADE2_WAIVER_COUNT',0) do
   local session=Number(p,'PARADE2_WAIVER_'..n..'_SESSION',-1);local guest=Number(p,'PARADE2_WAIVER_'..n..'_GUEST',-1)
   if p:GetProperty('PARADE2_INVITE_'..session..'_'..guest)=='WAIT_HOST' then
    local row=rows:GetInstance();row.ButtonText:SetText('待裁决 · 第'..session..'场 · '..Leader(guest)..'请求无礼观摩')
    row.Button:SetDisabled(false);row.Button:RegisterCallback(Mouse.eLClick,function()ShowWaiver(session,guest)end)
   end
  end
 end
 Controls.StatusNotice:SetText(notice)
 Controls.Rows:CalculateSize();Controls.Rows:ReprocessAnchoring();Controls.Scroll:CalculateInternalSize()
end
Controls.Open:RegisterCallback(Mouse.eLClick,function()Controls.Panel:SetHide(false);Refresh(true)end)
Controls.InviteDismiss:RegisterCallback(Mouse.eLClick,function()Controls.InvitePanel:SetHide(true)end)
Controls.Close:RegisterCallback(Mouse.eLClick,function()Controls.Panel:SetHide(true)end)
Controls.Accept:RegisterCallback(Mouse.eLClick,function()
 local p=Players[Game.GetLocalPlayer()]
 local gift=gifts[selection] or -1
 local gold=tonumber(Controls.GoldInput:GetText())
 if gift==-2 then Send({Action='ANSWER',Host=Number(p,'PARADE2_INVITE_HOST',-1),Session=Number(p,'PARADE2_INVITE_SESSION',-1),Accept=1,NoGift=1});return end
 if gift<0 and (not gold or gold~=math.floor(gold) or gold<R.GoldFloor() or gold>p:GetTreasury():GetGoldBalance()) then Controls.GiftText:SetText('金币须为整数，至少 '..R.GoldFloor()..'，且不得超过现有国库。');return end
 Send({Action='ANSWER',Host=Number(p,'PARADE2_INVITE_HOST',-1),Session=Number(p,'PARADE2_INVITE_SESSION',-1),Accept=1,Resource=gift,Gold=gold or 0})
end)
Controls.Decline:RegisterCallback(Mouse.eLClick,function()
 local p=Players[Game.GetLocalPlayer()]
 Send({Action='ANSWER',Host=Number(p,'PARADE2_INVITE_HOST',-1),Session=Number(p,'PARADE2_INVITE_SESSION',-1),Accept=0})
end)
-- Gift delivery is part of the existing ceremony summary, with no extra receipt screen.
ExposedMembers.ParadeV2UI.GiftSummary=function(owner,session)
 local p=Players[owner];if not p then return '' end
 local lines={}
 for _,g in ipairs(PlayerManager.GetAliveMajors()) do
  local key='PARADE2_INVITE_'..session..'_'..g:GetID();local state=p:GetProperty(key)
  if state then lines[#lines+1]=Leader(g:GetID())..'：'..(state=='SETTLED' and ('已到账 '..tostring(p:GetProperty(key..'_RECEIPT') or '')) or statusNames[state] or state) end
 end
 return table.concat(lines,'[NEWLINE]')
end
local giftRows=InstanceManager:new('GiftResultRow','ResultRow',Controls.GiftRows)
local giftPresentation=nil
local giftShown={}
local function RefreshGiftSummary()
 local data=giftPresentation;if not data then return end
 local p=Players[data.Owner];if not p then return end
 giftRows:ResetInstances();local invited,settled=0,0
 for _,g in ipairs(PlayerManager.GetAliveMajors()) do
  local key='PARADE2_INVITE_'..data.GiftSession..'_'..g:GetID();local state=p:GetProperty(key)
  if state then
   invited=invited+1;local row=giftRows:GetInstance()
   row.GiftLeader:SetText(Leader(g:GetID()))
   row.GiftState:SetText(statusNames[state] or state)
   local detail
   if state=='SETTLED' then
    settled=settled+1;detail='已收到：'..tostring(p:GetProperty(key..'_RECEIPT') or '贺礼已完成交付')
   elseif state=='ATTENDED' or state=='NO_GIFT_ACCEPTED' then detail='经您准许无礼出席，本场未收取贺礼。'
   elseif state=='WAIT_HOST' then detail='来宾无力赠礼，等待您决定是否允许观摩。'
   elseif state=='RESELECT' then detail='尚未到账：'..tostring(p:GetProperty(key..'_ERROR') or '来宾需要重新选择贺礼。')
   elseif state=='DECLINED' then detail='来宾未出席，本场没有赠礼。'
   else detail='本场未收到该来宾的贺礼。' end
   row.GiftDetail:SetText(detail)
  end
 end
 if invited==0 then
  local row=giftRows:GetInstance();row.GiftLeader:SetText('本场未邀请外宾');row.GiftState:SetText('无赠礼');row.GiftDetail:SetText('强军阅兵筹备期间，可通过“阅兵外交”邀请友好领袖。')
 end
 Controls.GiftCount:SetText(tostring(invited)..' 位');Controls.GiftSettled:SetText(tostring(settled)..' 份')
 Controls.GiftSubtitle:SetText('第 '..data.GiftSession..' 场阅兵 · 礼成贺礼总览')
 Controls.GiftRows:CalculateSize();Controls.GiftRows:ReprocessAnchoring();Controls.GiftScroll:CalculateInternalSize()
end
ExposedMembers.ParadeV2UI.ShowGifts=function(data)
 if type(data)~='table' or data.Replay or data.Kind~='STRENGTH' or data.Owner~=Game.GetLocalPlayer() then return false end
 local p=Players[data.Owner];if not p then return false end
 local session=data.GiftSession or Number(p,'PARADE2_COMPLETED_SESSION',-1)
 if session<0 then return false end
 local key=data.Owner..':'..session;if giftShown[key] or session<=Number(p,'PARADE2_GIFT_SUMMARY_ACK',-1) then return false end
 if giftPresentation then return false end
 giftShown[key]=true;giftPresentation={Owner=data.Owner,GiftSession=session,Timeline=data}
 Controls.Panel:SetHide(true);Controls.InvitePanel:SetHide(true);Controls.WaiverPanel:SetHide(true)
 RefreshGiftSummary();Controls.GiftPanel:SetHide(false);return true
end
local function CloseGiftSummary()
 local data=giftPresentation;giftPresentation=nil;Controls.GiftPanel:SetHide(true)
 if data then Send({Action='ACK_GIFT_SUMMARY',Session=data.GiftSession}) end
 local host=ExposedMembers.ParadeV38UI
 if data and host and host.QueueAwardTimeline then host.QueueAwardTimeline(data.Timeline) end
end
Controls.GiftClose:RegisterCallback(Mouse.eLClick,CloseGiftSummary)
ContextPtr:SetInputHandler(function(input)
 local escape=input:GetMessageType()==KeyEvents.KeyUp and input:GetKey()==Keys.VK_ESCAPE
 if not Controls.GiftPanel:IsHidden() then if escape then CloseGiftSummary() end;return true end
 if not Controls.WaiverPanel:IsHidden() then
  if escape then Controls.WaiverPanel:SetHide(true);waiverShown=nil end
  return true
 end
 if not Controls.InvitePanel:IsHidden() then
  if escape then Controls.InvitePanel:SetHide(true) end
  return true
 end
 return false
end,true)

local giftSoundSeen=nil
local rewardSoundSeen=nil
local soundPending=false
local soundClock=0
local lastSound=-100
local function RewardSounds(p,reviewing)
 if giftPresentation then RefreshGiftSummary();return end
 local gifts=Number(p,'PARADE2_GIFT_SOUND_COUNT',0)
 local rewards=Number(p,'PARADE2_REWARD_SOUND_COUNT',0)
 if giftSoundSeen==nil then giftSoundSeen=gifts end
 if rewardSoundSeen==nil then rewardSoundSeen=rewards end
 if gifts>giftSoundSeen or rewards>rewardSoundSeen then soundPending=true end
 giftSoundSeen=gifts;rewardSoundSeen=rewards
 -- Coalesce same-frame settlements and wait until parade music has finished.
 if soundPending and not reviewing and soundClock-lastSound>=1.5 then
  local ok=pcall(UI.PlaySound,'ALERT_POSITIVE')
  if ok then soundPending=false;lastSound=soundClock end
 end
end
local function Poll()
 local id=Game.GetLocalPlayer();local p=id and id>=0 and Players[id];if not p then return end
 local count=Number(p,'PARADE2_NOTICE_COUNT',0)
 if seen==nil then seen=count end
 if count>seen then
  notice=p:GetProperty('PARADE2_NOTICE_'..count) or ''
  Controls.Open:SetToolTipString(notice);Controls.OpenText:SetText('阅兵外交 · 新消息')
  -- Persistent notification; full details remain available after closing review.
  if NotificationManager and NotificationTypes and NotificationTypes.USER_DEFINED_1 then
   pcall(NotificationManager.SendNotification,id,NotificationTypes.USER_DEFINED_1,'阅兵使团',notice)
  end
  seen=count
 end
 local presentation=ExposedMembers.ParadeV38Presentation
 local reviewing=presentation and presentation.IsActive and presentation.IsActive() or false
 RewardSounds(p,reviewing)
 if giftPresentation then RefreshGiftSummary();return end
 Controls.Open:SetHide(reviewing);
 if reviewing then Controls.InvitePanel:SetHide(true);Controls.WaiverPanel:SetHide(true);Controls.Panel:SetHide(true); end
 if waiverShown and p:GetProperty('PARADE2_INVITE_'..waiverShown.Session..'_'..waiverShown.Guest)~='WAIT_HOST' then
  Controls.WaiverPanel:SetHide(true);waiverShown=nil;Controls.Panel:SetHide(false);Refresh(false)
 end
 if not reviewing and Controls.WaiverPanel:IsHidden() and Controls.InvitePanel:IsHidden() then
  for n=1,Number(p,'PARADE2_WAIVER_COUNT',0) do
   local session=Number(p,'PARADE2_WAIVER_'..n..'_SESSION',-1);local guest=Number(p,'PARADE2_WAIVER_'..n..'_GUEST',-1)
   if p:GetProperty('PARADE2_INVITE_'..session..'_'..guest)=='WAIT_HOST' and not waiverSeen[session..':'..guest] then ShowWaiver(session,guest);return end
  end
  local session=Number(p,'PARADE2_SESSION',0)
  if p:GetProperty('PARADE2_ACTIVE_KIND')=='STRENGTH' and lastInviteSession~=session then
   lastInviteSession=session;Controls.Panel:SetHide(false);Refresh(true)
  end
  local state=p:GetProperty('PARADE2_INVITE_STATE')
  local inviteHost=Number(p,'PARADE2_INVITE_HOST',-1)
  local inviteSession=Number(p,'PARADE2_INVITE_SESSION',-1)
  local incoming=tostring(inviteHost)..':'..tostring(inviteSession)..':'..tostring(state or '')
  if (state=='OFFERED' or state=='RESELECT') and incoming~=lastIncoming then lastIncoming=incoming;Controls.Panel:SetHide(false);Refresh(true) end
 end
 local signature={tostring(count),tostring(p:GetProperty('PARADE2_ACTIVE_KIND') or ''),tostring(Number(p,'PARADE2_SESSION',0)),tostring(p:GetProperty('PARADE2_INVITE_STATE') or ''),tostring(Number(p,'PARADE2_INVITE_HOST',-1))}
 for _,g in ipairs(PlayerManager.GetAliveMajors()) do
  signature[#signature+1]=tostring(p:GetProperty('PARADE2_INVITE_'..Number(p,'PARADE2_SESSION',0)..'_'..g:GetID()) or '')
  if g:GetID()~=id then
   signature[#signature+1]=tostring(R.Friendly(g:GetID(),id))..':'..Number(g,'PARADE2_INVITE_HOST',-1)
   if not g:IsHuman() and p:GetDiplomacy():HasMet(g:GetID()) then signature[#signature+1]=tostring(g:GetProperty('PARADE2_ACTIVE_KIND') or '')..':'..Number(g,'PARADE_V35_COUNT',0) end
  end
 end
 signature=table.concat(signature,'|')
 -- Do not destroy/recreate clickable rows every second while a user clicks.
 if Controls.WaiverPanel:IsHidden() and (not Controls.Panel:IsHidden() or not Controls.InvitePanel:IsHidden()) and signature~=lastSignature then
  if not (Number(p,'PARADE2_INVITE_HOST',-1)>=0 and (p:GetProperty('PARADE2_INVITE_STATE')=='OFFERED' or p:GetProperty('PARADE2_INVITE_STATE')=='RESELECT')) then Controls.Panel:SetHide(false) end
  Refresh(false)
 end
 lastSignature=signature
end
ContextPtr:SetUpdate(function(dt)soundClock=soundClock+dt;clock=clock+dt;if clock>=1 then clock=0;Poll()end end)
ContextPtr:SetInitHandler(function()InitializeLabels();ContextPtr:SetHide(false)end)
ContextPtr:SetHide(false)
