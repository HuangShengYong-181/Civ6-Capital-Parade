-- A queued, wonder-style UI celebration; no GameCore movement commands and no
-- cinematic mode/engine event lock. Works when raised by the UI polling bridge.
include('InputSupport')
include('Parade_Camera.lua')
include('Parade_Audio.lua')
include('Parade_Rules.lua')
include('Parade_March.lua')
local function InitializeLabels()
 Controls.CelebrationTitle:SetText(Locale.Lookup("LOC_PARADE_CELEBRATION_FIRST"))
 Controls.BuildStatus:SetText("3.20 B1")
 Controls.Parade_CelebrationStatic1:SetText(Locale.Lookup("LOC_PARADE_CELEBRATION_CLOSE"))
 Controls.MusicTitle:SetText('阅兵音乐')
 Controls.MusicDefaultText:SetText('国际歌')
 Controls.MusicCustomText:SetText('已导入的自选曲目')
 Controls.MusicOffText:SetText('关闭阅兵音乐')
 Controls.MusicCloseText:SetText('完成')
 Controls.CombatMetricCaption:SetText("战斗力")
 Controls.LoyaltyMetricCaption:SetText("忠诚度")
 Controls.AmenitiesMetricCaption:SetText("宜居度")
 Controls.ProductionMetricCaption:SetText("军事生产")
 Controls.Parade_CelebrationStatic2:SetText(Locale.Lookup("LOC_PARADE_SKIP_TO_AWARD"))
 Controls.Parade_CelebrationStatic3:SetText("音乐设置")
 Controls.Parade_CelebrationStatic4:SetText(Locale.Lookup("LOC_PARADE_REPLAY_CAMERA"))
end
InitializeLabels()

local pending={}
local pendingRetry=0
local current=nil
local queued=false
local started=false
local soundPlayed=false
local elapsed=0
local reviewTime=0
local awardTime=nil
local pushed=false
local lastCount=0
local sealPlayed=false
local failureTime=nil
-- Civ6 SetUpdate requires a function; nil is rejected by the native binding.
local function IdleUpdate()end
local function Close()
    if not current and not queued and not pushed then return end
    -- Closing is never gated by a timer, a UI bridge or camera state.
    local finished=current
    local reviewed=ParadeMarch.IsComplete()
    local wasShown=queued or pushed
    current=nil;started=false
    local function cleanup(label,action)
        local ok,err=pcall(action)
        if not ok then print('[ParadeV313][CLOSE] '..label..': '..tostring(err)) end
    end
    cleanup('update',function()ContextPtr:SetUpdate(IdleUpdate)end)
    cleanup('audio',function()ParadeAudio.EndPresentation()end)
    cleanup('march',function()ParadeMarch.End()end)
    cleanup('camera',function()ParadeCamera.End()end)
    if pushed then
        pushed=false;cleanup('input',function()Input.PopContext()end)
    end
    if queued then
        queued=false;cleanup('dequeue',function()UIManager:DequeuePopup(ContextPtr)end)
    end
    cleanup('hide',function()Controls.MusicPanel:SetHide(true);ContextPtr:SetHide(true)end)
    -- Native timeline follows the review, never obscures it. Only an actual
    -- awarded completion queues a card; replay/zero-score/duplicate close do not.
    local gifts=ExposedMembers.ParadeV2UI
    if reviewed and wasShown and finished and not finished.Replay and finished.Kind=='STRENGTH' and gifts and gifts.ShowGifts then
        local ok,shown=pcall(gifts.ShowGifts,finished)
        if ok and shown then return end
    end
    local host=ExposedMembers.ParadeV38UI
    if host and host.QueueAwardTimeline and finished and wasShown then
        cleanup('timeline',function()host.QueueAwardTimeline(finished)end)
    end
end
local function PlayCompletionSound()ParadeAudio.Play()end
local function Phase()
    local host=ExposedMembers.ParadeV38UI
    if Controls.BuildStatus then
        Controls.BuildStatus:SetText(host and host.DiagnosticText and host.DiagnosticText() or '2.0 B2 | 主界面扩展未加载')
    end
    local complete=ParadeMarch.IsComplete()
    local award=complete and awardTime~=nil and awardTime>=5
    Controls.CeremonyPanel:SetHide(not complete)
    Controls.QuoteText:SetHide(award);Controls.QuoteSource:SetHide(award)
    Controls.SealPanel:SetHide(not award)
    Controls.AwardText:SetHide(not award);Controls.GeneralAward:SetHide(not award)
    Controls.SkipCeremony:SetHide(not complete or award)
    Controls.EraAward:SetHide(not award)
    Controls.MetricPanel:SetHide(not award)
    Controls.GuestSummaryScroll:SetHide(not award or not current or current.Kind~='STRENGTH')
    if award and current and current.Kind=='STRENGTH' then
        local diplomacy=ExposedMembers.ParadeV2UI
        local text=diplomacy and diplomacy.GiftSummary and diplomacy.GiftSummary(current.Owner,current.GiftSession or ParadeRules.Number(Players[current.Owner],'PARADE2_COMPLETED_SESSION',-1)) or ''
        Controls.GuestSummary:SetText(text~='' and text or '本场没有来宾')
        Controls.GuestSummaryScroll:CalculateInternalSize()
    end
    local scroll=award and current and (current.EraScore or 0)>0
    Controls.EraMomentPanel:SetHide(true)
    local stage=not complete and (reviewTime<3 and 'OPEN' or 'REVIEW') or (award and 'AWARD' or 'QUOTE')
    Controls.StageLabel:SetText(Locale.Lookup('LOC_PARADE_STAGE_'..stage))
    if complete then
        local phaseTime=awardTime or 0
        local alpha=math.min(1,math.max(0,(phaseTime-(award and 5 or 0))/0.8))
        Controls.QuoteText:SetAlpha(alpha);Controls.QuoteSource:SetAlpha(alpha)
        Controls.SealPanel:SetAlpha(alpha)
        Controls.AwardText:SetAlpha(math.min(1,math.max(0,(phaseTime-5.5)/1.0)))
        Controls.GeneralAward:SetAlpha(math.min(1,math.max(0,(phaseTime-6.3)/1.0)))
        Controls.SealIcon:SetOffsetVal(15-(1-alpha)*14,0)
    end
    if award and not sealPlayed then
        sealPlayed=true
        if current and not current.Replay then pcall(UI.PlaySound,'ALERT_POSITIVE') end
    end
end
local function StartScene()
    if not current or started then return end
    started=true
    ParadeAudio.BeginPresentation()
    local marchOK,marchError=pcall(ParadeMarch.Begin,current)
    if not marchOK then print('[Parade2][MARCH] BEGIN ERROR: '..tostring(marchError));ParadeMarch.End() end
    local ok,name=pcall(ParadeCamera.Begin,current)
    if ok then Controls.FocusName:SetText(name or '')
    else print('[ParadeV38][CAMERA] BEGIN ERROR: '..tostring(name)) end
    if not current.Replay and not soundPlayed then PlayCompletionSound();soundPlayed=true end
end
local function Animate(dt)
    if not current or ContextPtr:IsHidden() then return end
    StartScene()
    if not started then return end
    elapsed=elapsed+dt;reviewTime=reviewTime+dt
    ParadeCamera.Tick(reviewTime)
    local marchOK,marchError=pcall(ParadeMarch.Tick,dt)
    if not marchOK then print('[Parade2][MARCH] TICK ERROR: '..tostring(marchError));ParadeMarch.End() end
    if ParadeMarch.IsComplete() then awardTime=(awardTime or 0)+dt else awardTime=nil end
    if ParadeMarch.Status()~='' then Controls.FocusName:SetText(ParadeMarch.Status()) end
    if ParadeAudio.Description then Controls.SoundTest:SetToolTipString(ParadeAudio.Description()) end
    Phase()
    if ParadeMarch.Outcome and ParadeMarch.Outcome()=='FAILED' then
        failureTime=(failureTime or 0)+dt
        Controls.CeremonyPanel:SetHide(false)
        Controls.QuoteText:SetHide(false);Controls.QuoteText:SetAlpha(1)
        Controls.QuoteText:SetText('检阅已中止')
        Controls.QuoteSource:SetHide(false);Controls.QuoteSource:SetAlpha(1)
        Controls.QuoteSource:SetText(ParadeMarch.Status()..'。将自动返回地图；请保留 Lua.log。')
        Controls.StageLabel:SetText('恢复部队与镜头')
        if failureTime>=4 then Close() end
        return
    end
    failureTime=nil
    if awardTime and awardTime>=14 then
        ContextPtr:SetUpdate(IdleUpdate)
        -- Repeated ceremonies must also reach gifts even when era score is zero.
        -- Explicit record replays retain their manual exit.
        if current and not current.Replay then Close() end
    end
end
local function Show(data)
    if type(data)~='table' or data.Owner~=Game.GetLocalPlayer() then return false end
    if not data.Replay and data.Count<=lastCount then return true end
    if current then
        for _,item in ipairs(pending) do
            if not data.Replay and item.Owner==data.Owner and item.Count==data.Count then return true end
        end
        pending[#pending+1]=data
        return true
    end
    Controls.MusicPanel:SetHide(true)
    current=data;started=false;soundPlayed=false;elapsed=0;reviewTime=0;awardTime=nil;sealPlayed=false;failureTime=nil
    local quote=nil
    -- Custom GameInfo numeric indexing is not assumed to equal QuoteID.
    for row in GameInfo.ParadeQuotes() do
        if row.QuoteID==data.QuoteID then quote=row;break end
    end
    Controls.CelebrationTitle:SetText((ParadeRules.Names[data.Kind] or '盛大阅兵')..' · '..(data.CityName or ''))
    local signature=Locale.Lookup('LOC_PARADE_REVIEW_ARMY')
    if data.GeneralReviewed then
        local name=data.GeneralName and data.GeneralName~='' and Locale.Lookup(data.GeneralName) or Locale.Lookup('LOC_UNIT_GREAT_GENERAL_NAME')
        signature=Locale.Lookup('LOC_PARADE_REVIEW_SIGNATURE',name)
    end
    local era=data.EraName and data.EraName~='' and Locale.Lookup(data.EraName) or ''
    Controls.ReviewSignature:SetText(era..(era~='' and ' · ' or '')..signature)
    Controls.Parade_CelebrationStatic1:SetText('完成 · 返回地图')
    Controls.SealTitle:SetText(Locale.Lookup('LOC_PARADE_RANK_'..math.max(1,math.min(5,data.Tier or 1))))
    Phase()
    Controls.QuoteText:SetText((quote and quote.QuoteText) or ParadeRules.Verses[data.Kind] or '')
    Controls.QuoteSource:SetText(quote and ('—— '..quote.Attribution) or ('—— '..(ParadeRules.Names[data.Kind] or '阅兵')..' · 模组题辞'))
    local remaining=math.max(0,data.Ending-Game.GetCurrentGameTurn())
    Controls.AwardText:SetText('军事分 '..(data.Score or 0)..'  ·  参阅规模 '..(data.Size or 0)..'  ·  效果剩余 '..remaining..' 回合')
    Controls.CombatMetric:SetText('+'..(data.Combat or 0))
    Controls.LoyaltyMetric:SetText('+'..(data.Loyalty or 0))
    Controls.AmenitiesMetric:SetText('+'..(data.Amenities or 0))
    Controls.ProductionMetric:SetText('+'..(10+((data.Scale or 0)>=3 and 10 or (data.Scale or 0)>=2 and 5 or 0))..'%')
    Controls.GeneralAward:SetText('大将军点数 +'..(data.GeneralPoints or 0)..'    ·    使者 +1'..(data.GeneralReviewed and '    ·    大将军检阅加成已计入' or ''))
    local eraTitle=(data.EraScore or 0)==2 and 'LOC_PARADE_ERA_FIRST_TITLE' or 'LOC_PARADE_ERA_REPEAT_TITLE'
    local eraBody=(data.EraScore or 0)==2 and 'LOC_PARADE_ERA_FIRST_BODY' or 'LOC_PARADE_ERA_REPEAT_BODY'
    if data.GeneralReviewed then eraBody='LOC_PARADE_ERA_GENERAL_BODY' end
    Controls.EraMomentTitle:SetText(ParadeRules.Names[data.Kind] or Locale.Lookup(eraTitle))
    Controls.EraMomentBody:SetText((quote and quote.QuoteText) or ParadeRules.Verses[data.Kind] or Locale.Lookup(eraBody))
    Controls.EraMomentSignature:SetText(signature)
    Controls.EraMomentScore:SetText(Locale.Lookup('LOC_PARADE_ERA_GAIN',data.EraScore or 0))
    local eraLine=(data.EraScore or 0)>0 and Locale.Lookup('LOC_PARADE_ERA_GAIN',data.EraScore)
        or Locale.Lookup((data.EraStatus or 3)>=3 and 'LOC_PARADE_ERA_UNAVAILABLE' or 'LOC_PARADE_ERA_ALREADY')
    Controls.EraAward:SetText(eraLine)
    Controls.CompletionTurn:SetText(Locale.Lookup('LOC_PARADE_CELEBRATION_TURN',data.Turn))
    local host=Players and Players[data.Owner]
    data.GiftSession=host and ParadeRules.Number(host,'PARADE2_COMPLETED_SESSION',-1) or -1
    UIManager:QueuePopup(ContextPtr,PopupPriority.High)
    queued=true
    if not data.Replay then lastCount=data.Count end
    print('[ParadeV38][CELEBRATION] QUEUED count='..tostring(data.Count))
    ContextPtr:SetUpdate(Animate)
    if not ContextPtr:IsHidden() then StartScene() end
    return true
end
Controls.CloseCelebration:RegisterCallback(Mouse.eLClick,Close)
Controls.CloseX:RegisterCallback(Mouse.eLClick,Close)
Controls.SoundTest:RegisterCallback(Mouse.eLClick,function()
 if not current then return end
 Controls.MusicDescription:SetText(ParadeAudio.Description and ParadeAudio.Description() or '阅兵音乐')
 Controls.MusicPanel:SetHide(not Controls.MusicPanel:IsHidden())
end)
for _,entry in ipairs({{'MusicDefault','DEFAULT'},{'MusicCustom','CUSTOM'},{'MusicOff','OFF'}}) do
 local name,value=entry[1],entry[2]
 Controls[name]:RegisterCallback(Mouse.eLClick,function()
  if ParadeAudio.SetChoice then ParadeAudio.SetChoice(value) end
  Controls.MusicDescription:SetText(ParadeAudio.Description and ParadeAudio.Description() or '')
 end)
end
Controls.MusicClose:RegisterCallback(Mouse.eLClick,function()Controls.MusicPanel:SetHide(true)end)

Controls.ReplayCamera:RegisterCallback(Mouse.eLClick,function()
    if not current then return end
    elapsed=0;reviewTime=0;started=true
    Phase()
    local ok,err=pcall(ParadeCamera.Begin,current)
    if not ok then print('[ParadeV38][CAMERA] REPLAY ERROR: '..tostring(err))
    elseif ParadeMarch.CurrentUnit then
        local unit=ParadeMarch.CurrentUnit();if unit then ParadeCamera.FocusUnit(unit) end
    end
    ContextPtr:SetUpdate(Animate)
end)
Controls.SkipCeremony:RegisterCallback(Mouse.eLClick,function()
    if not current then return end
    -- Leave four seconds to read the award, then use the same automatic
    -- handoff as normal playback. Stopping updates here stranded the timeline.
    if not ParadeMarch.IsComplete() then return end
    awardTime=5;Phase();ContextPtr:SetUpdate(Animate)
end)
ContextPtr:SetInputHandler(function(input)
    if input:GetMessageType()==KeyEvents.KeyUp and input:GetKey()==Keys.VK_ESCAPE then
        if not Controls.MusicPanel:IsHidden() then Controls.MusicPanel:SetHide(true) else Close() end
        return true
    end
    -- Consume gameplay hotkeys while the celebration is in the popup queue.
    local kind=input:GetMessageType()
    return kind==KeyEvents.KeyUp or kind==KeyEvents.KeyDown
end,true)
ContextPtr:SetShowHideHandler(function(hidden)
    if not hidden and current then
        if not pushed then Input.PushActiveContext(InputContext.Reveal);pushed=true end
        StartScene()
        ContextPtr:SetUpdate(Animate)
    end
    if hidden and current then ParadeMarch.End();ParadeAudio.EndPresentation();ParadeCamera.End();started=false end
    if hidden and pushed then Input.PopContext();pushed=false end
end)
ContextPtr:SetShutdown(function()
    ParadeAudio.EndPresentation()
    ParadeMarch.End()
    ParadeCamera.End()
    if pushed then Input.PopContext();pushed=false end
    ExposedMembers.ParadeV311Audio=nil
    ExposedMembers.ParadeV38Presentation=nil
end)
local function Dispatch(data)
    local ok,result=pcall(Show,data)
    if not ok then
        print('[ParadeV38][CELEBRATION] SHOW ERROR: '..tostring(result))
        local cleaned,err=pcall(Close)
        if not cleaned then print('[ParadeV38][CELEBRATION] CLEANUP ERROR: '..tostring(err)) end
        return false
    end
    return result==true
end
LuaEvents.ParadeV38_ShowCelebration.Add(Dispatch)
ExposedMembers.ParadeV38Presentation={Ready=true,Show=Dispatch,IsActive=function()return current~=nil or queued or #pending>0 end,Pump=function(dt)
    pendingRetry=math.max(0,pendingRetry-(dt or 0))
    if current or #pending==0 or pendingRetry>0 then return end
    if Dispatch(pending[1]) then table.remove(pending,1) else pendingRetry=1.5 end
end}
ContextPtr:SetHide(true)
print('[ParadeV38][CELEBRATION] READY: unit-focused camera review, 40 quotes, native Internationale instrumental bank; no voice')
