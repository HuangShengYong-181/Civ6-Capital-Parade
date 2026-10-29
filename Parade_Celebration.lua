-- A queued, wonder-style UI celebration; no GameCore movement commands and no
-- cinematic mode/engine event lock. Works when raised by the UI polling bridge.
include('InputSupport')
include('Parade_Camera.lua')
include('Parade_Audio.lua')
local pending={}
local pendingRetry=0
local current=nil
local queued=false
local started=false
local soundPlayed=false
local elapsed=0
local pushed=false
local lastCount=0
local sealPlayed=false
local function Close()
    if not current and not queued and not pushed then return end
    -- Closing is never gated by a timer, a UI bridge or camera state.
    local finished=current
    local wasShown=queued or pushed
    current=nil;started=false
    local function cleanup(label,action)
        local ok,err=pcall(action)
        if not ok then print('[ParadeV313][CLOSE] '..label..': '..tostring(err)) end
    end
    cleanup('update',function()ContextPtr:SetUpdate(nil)end)
    cleanup('audio',function()ParadeAudio.EndPresentation()end)
    cleanup('camera',function()ParadeCamera.End()end)
    if pushed then
        pushed=false;cleanup('input',function()Input.PopContext()end)
    end
    if queued then
        queued=false;cleanup('dequeue',function()UIManager:DequeuePopup(ContextPtr)end)
    end
    cleanup('hide',function()ContextPtr:SetHide(true)end)
    -- Native timeline follows the review, never obscures it. Only an actual
    -- awarded completion queues a card; replay/zero-score/duplicate close do not.
    local host=ExposedMembers.ParadeV38UI
    if host and host.QueueAwardTimeline and finished and wasShown then
        cleanup('timeline',function()host.QueueAwardTimeline(finished)end)
    end
end
local function PlayCompletionSound()ParadeAudio.Play()end
local function Phase()
    local host=ExposedMembers.ParadeV38UI
    if Controls.BuildStatus then
        Controls.BuildStatus:SetText(host and host.DiagnosticText and host.DiagnosticText() or '3.20 B1 | 主界面扩展未加载')
    end
    local award=elapsed>=16
    Controls.CeremonyPanel:SetHide(elapsed<11)
    Controls.QuoteText:SetHide(award);Controls.QuoteSource:SetHide(award)
    Controls.SealPanel:SetHide(not award)
    Controls.AwardText:SetHide(not award);Controls.GeneralAward:SetHide(not award)
    Controls.SkipCeremony:SetHide(award)
    Controls.EraAward:SetHide(not award)
    local scroll=award and current and (current.EraScore or 0)>0
    Controls.EraMomentPanel:SetHide(not scroll)
    local stage=elapsed<3 and 'OPEN' or elapsed<11 and 'REVIEW' or elapsed<16 and 'QUOTE' or 'AWARD'
    Controls.StageLabel:SetText(Locale.Lookup('LOC_PARADE_STAGE_'..stage))
    if elapsed>=11 then
        local alpha=math.min(1,(elapsed-(award and 16 or 11))/0.8)
        Controls.QuoteText:SetAlpha(alpha);Controls.QuoteSource:SetAlpha(alpha)
        Controls.SealPanel:SetAlpha(alpha)
        Controls.AwardText:SetAlpha(math.min(1,math.max(0,(elapsed-16.5)/1.0)))
        Controls.GeneralAward:SetAlpha(math.min(1,math.max(0,(elapsed-17.3)/1.0)))
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
    local ok,name=pcall(ParadeCamera.Begin,current)
    if ok then Controls.FocusName:SetText(name or '')
    else print('[ParadeV38][CAMERA] BEGIN ERROR: '..tostring(name)) end
    if not current.Replay and not soundPlayed then PlayCompletionSound();soundPlayed=true end
end
local function Animate(dt)
    if not current or ContextPtr:IsHidden() then return end
    StartScene()
    if not started then return end
    elapsed=elapsed+dt
    ParadeCamera.Tick(elapsed)
    Phase()
    if elapsed>=ParadeCamera.Duration then
        ContextPtr:SetUpdate(nil)
        -- Awarded reviews flow straight into the native timeline. Zero-score
        -- diagnostics and explicit record replays retain the manual exit.
        if current and not current.Replay and (current.EraScore or 0)>0 then Close() end
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
    current=data;started=false;soundPlayed=false;elapsed=0;sealPlayed=false
    local quote=nil
    -- Custom GameInfo numeric indexing is not assumed to equal QuoteID.
    for row in GameInfo.ParadeQuotes() do
        if row.QuoteID==data.QuoteID then quote=row;break end
    end
    Controls.CelebrationTitle:SetText(Locale.Lookup('LOC_PARADE_CEREMONY_TITLE',data.CityName or '',data.Count))
    local signature=Locale.Lookup('LOC_PARADE_REVIEW_ARMY')
    if data.GeneralReviewed then
        local name=data.GeneralName and data.GeneralName~='' and Locale.Lookup(data.GeneralName) or Locale.Lookup('LOC_UNIT_GREAT_GENERAL_NAME')
        signature=Locale.Lookup('LOC_PARADE_REVIEW_SIGNATURE',name)
    end
    local era=data.EraName and data.EraName~='' and Locale.Lookup(data.EraName) or ''
    Controls.ReviewSignature:SetText(era..(era~='' and ' · ' or '')..signature)
    Controls.SealTitle:SetText(Locale.Lookup('LOC_PARADE_RANK_'..math.max(1,math.min(5,data.Tier or 1))))
    Phase()
    Controls.QuoteText:SetText(quote and quote.QuoteText or '')
    Controls.QuoteSource:SetText(quote and ('—— '..quote.Attribution) or '')
    local remaining=math.max(0,data.Ending-Game.GetCurrentGameTurn())
    Controls.AwardText:SetText(Locale.Lookup('LOC_PARADE_CELEBRATION_REWARD',data.Score,data.Combat,data.Loyalty,data.Amenities,remaining))
    local details=Locale.Lookup('LOC_PARADE_GENERAL_AWARD',data.GeneralPoints or 0)
    if data.GeneralReviewed then
        details=details..' · '..Locale.Lookup('LOC_PARADE_GENERAL_TIER',data.BaseTier or data.Tier or 1,data.Tier or 1)
    end
    Controls.GeneralAward:SetText(details)
    local eraTitle=(data.EraScore or 0)==2 and 'LOC_PARADE_ERA_FIRST_TITLE' or 'LOC_PARADE_ERA_REPEAT_TITLE'
    local eraBody=(data.EraScore or 0)==2 and 'LOC_PARADE_ERA_FIRST_BODY' or 'LOC_PARADE_ERA_REPEAT_BODY'
    if data.GeneralReviewed then eraBody='LOC_PARADE_ERA_GENERAL_BODY' end
    Controls.EraMomentTitle:SetText(Locale.Lookup(eraTitle))
    Controls.EraMomentBody:SetText(Locale.Lookup(eraBody))
    Controls.EraMomentSignature:SetText(signature)
    Controls.EraMomentScore:SetText(Locale.Lookup('LOC_PARADE_ERA_GAIN',data.EraScore or 0))
    local eraLine=(data.EraScore or 0)>0 and Locale.Lookup('LOC_PARADE_ERA_GAIN',data.EraScore)
        or Locale.Lookup((data.EraStatus or 3)>=3 and 'LOC_PARADE_ERA_UNAVAILABLE' or 'LOC_PARADE_ERA_ALREADY')
    Controls.EraAward:SetText(eraLine)
    Controls.CompletionTurn:SetText(Locale.Lookup('LOC_PARADE_CELEBRATION_TURN',data.Turn))
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
    PlayCompletionSound()
end)
Controls.ReplayCamera:RegisterCallback(Mouse.eLClick,function()
    if not current then return end
    elapsed=0;started=true
    Phase()
    local ok,err=pcall(ParadeCamera.Begin,current)
    if not ok then print('[ParadeV38][CAMERA] REPLAY ERROR: '..tostring(err)) end
    ContextPtr:SetUpdate(Animate)
end)
Controls.SkipCeremony:RegisterCallback(Mouse.eLClick,function()
    if not current then return end
    -- Leave four seconds to read the award, then use the same automatic
    -- handoff as normal playback. Stopping updates here stranded the timeline.
    elapsed=16;ParadeCamera.Tick(20);Phase();ContextPtr:SetUpdate(Animate)
end)
ContextPtr:SetInputHandler(function(input)
    if input:GetMessageType()==KeyEvents.KeyUp and input:GetKey()==Keys.VK_ESCAPE then Close();return true end
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
    if hidden and current then ParadeAudio.EndPresentation();ParadeCamera.End();started=false end
    if hidden and pushed then Input.PopContext();pushed=false end
end)
ContextPtr:SetShutdown(function()
    ParadeAudio.EndPresentation()
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
