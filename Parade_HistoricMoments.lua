-- Extend the installed XP1/XP2 timeline; keep its XML, notifications and input.
-- Records below are UI cards backed by saved player properties, not fabricated
-- GameCore moment IDs. Gameplay awards the actual score separately, once.
include('HistoricMoments.lua')
local BaseDisplay=DisplayTimeline
local BaseAdd=AddMoment
local BaseIllustration=AddIllustration
local BaseReset=ResetTimeline
local BasePopupParameters=GetPopupParameters
local automaticOpen=false
local autoQueue={}
local diagnostic=ExposedMembers.MilitaryParadeDiagnostic or {}
ExposedMembers.MilitaryParadeDiagnostic=diagnostic
diagnostic.TimelineBuild='3.20 B1'
function GetPopupParameters()
    local original=BasePopupParameters()
    if not automaticOpen and #autoQueue==0 then return original end
    local parameters={}
    for key,value in pairs(original) do parameters[key]=value end
    -- Custom automatic opening must not depend on stock notification timing.
    -- Queue it with ordinary visibility and confirm the resulting screen state.
    parameters.DelayShow=false
    return parameters
end
local artIM=InstanceManager:new('LargeIllustration','Root')
local rendering=nil
local captured=nil
local template=nil
local function FindTemplate()
    if template then return template end
    for row in GameInfo.Moments() do
        if (row.InterestLevel or 0)>1 and row.BackgroundTexture and not row.MomentIllustrationType then
            template=row.Index;return template
        end
    end
end
local function ReadRecords(playerID)
    local result={}
    local player=Players[playerID]
    local kind=FindTemplate()
    if not player or kind==nil then return result end
    for era in GameInfo.Eras() do
        local prefix='PARADE_V314_MOMENT_'..era.Index..'_'
        local function value(key)local v=player:GetProperty(prefix..key);return v end
        if value('READY')==1 then
            result[#result+1]={ID=-1000000-era.Index,Type=kind,GameEra=era.Index,
                Turn=tonumber(value('TURN')) or 0,EraScore=tonumber(value('SCORE')) or 0,
                Parade=true,City=value('CITY') or '',General=value('GENERAL')==1,
                GeneralName=value('NAME') or '',ExtraData={},HasEverBeenCommemorated=false}
        end
    end
    local completed=tonumber((player:GetProperty('PARADE_V35_COUNT'))) or 0
    for number=1,completed do
        local prefix='PARADE_V315_MOMENT_'..number..'_'
        local function value(key)local v=player:GetProperty(prefix..key);return v end
        if value('READY')==1 then
            result[#result+1]={ID=-2000000-number,Type=kind,GameEra=tonumber(value('ERA')) or 0,
                Turn=tonumber(value('TURN')) or 0,EraScore=tonumber(value('SCORE')) or 0,
                Parade=true,City=value('CITY') or '',General=value('GENERAL')==1,
                GeneralName=value('NAME') or '',ExtraData={},HasEverBeenCommemorated=false}
        end
    end
    -- Upgrade migration: v3.13 saved only the latest award snapshot. Preserve
    -- that completion, even a repeat with +0; do not invent older award dates.
    local latestEra=tonumber((player:GetProperty('PARADE_V313_WORLD_ERA')))
    local latestScore=tonumber((player:GetProperty('PARADE_V313_ERA_SCORE'))) or 0
    if player:GetProperty('PARADE_V315_ARCHIVE_STARTED')~=1 and latestEra and latestEra>=0 and
        (latestScore>0 or player:GetProperty('PARADE_V313_ERA_DONE_'..latestEra)==1) and
        player:GetProperty('PARADE_V314_MOMENT_'..latestEra..'_READY')~=1 then
        result[#result+1]={ID=-1000000-latestEra,Type=kind,GameEra=latestEra,
            Turn=tonumber((player:GetProperty('PARADE_V35_TURN'))) or 0,EraScore=latestScore,
            Parade=true,City=player:GetProperty('PARADE_V312_CITY_NAME') or '',
            General=player:GetProperty('PARADE_V38_GENERAL')==1,
            GeneralName=player:GetProperty('PARADE_V312_GENERAL_NAME') or '',ExtraData={}}
    end
    return result
end
function ResetTimeline()
    artIM:ResetInstances()
    return BaseReset()
end
function AddIllustration(instance,texture,dataType,momentType)
    if not rendering then return BaseIllustration(instance,texture,dataType,momentType) end
    captured=instance
    local art=artIM:GetInstance(instance.Illustrations).Root
    art:SetTexture('Parade_TimelineMoment.dds')
    art:SetSizeVal(456,228)
    art:SetOffsetVal(0,0)
end
function AddMoment(data,isNew)
    if not data.Parade then return BaseAdd(data,isNew) end
    local first=data.EraScore==2
    local title=Locale.Lookup(first and 'LOC_PARADE_ERA_FIRST_TITLE' or 'LOC_PARADE_ERA_REPEAT_TITLE')
    local body=Locale.Lookup(data.General and 'LOC_PARADE_ERA_GENERAL_BODY' or
        (first and 'LOC_PARADE_ERA_FIRST_BODY' or 'LOC_PARADE_ERA_REPEAT_BODY'))
    local signature=Locale.Lookup(data.City)
    if data.GeneralName~='' then signature=signature..' · '..Locale.Lookup(data.GeneralName) end
    local card={}
    for k,v in pairs(data) do card[k]=v end
    card.InstanceDescription=title
    rendering=card;captured=nil
    -- Use a native large-card template to preserve the original renderer's
    -- small-moment stack boundaries and era ordering. Only its UI template is
    -- borrowed; none of its event data, illustrations or score is recorded.
    local ok,err=pcall(BaseAdd,card,isNew)
    rendering=nil
    if ok and captured then
        captured.Description:SetOffsetY(65)
        captured.Root:SetToolTipString(title..'[NEWLINE]'..signature..'[NEWLINE]'..body)
    end
    captured=nil
    if not ok then error(err) end
end
function DisplayTimeline(showAnim)
    local playerID=Game.GetLocalPlayer()
    local records=ReadRecords(playerID)
    if #records==0 then return BaseDisplay(showAnim) end
    local originalGetter=Game.GetHistoryManager
    -- Synchronous, context-local adapter. The original getter is restored even
    -- if rendering throws. Native GameCore history is never modified.
    Game.GetHistoryManager=function(...)
        local manager=originalGetter(...)
        return setmetatable({GetAllMomentsData=function(_,owner,interest)
            local original=manager:GetAllMomentsData(owner,interest)
            local merged={}
            for _,entry in ipairs(original) do merged[#merged+1]=entry end
            if owner==playerID then
                for _,entry in ipairs(records) do merged[#merged+1]=entry end
            end
            table.sort(merged,function(a,b)
                if a.Turn~=b.Turn then return a.Turn<b.Turn end
                if a.GameEra~=b.GameEra then return a.GameEra<b.GameEra end
                if (a.Parade==true)~=(b.Parade==true) then return b.Parade==true end
                return (a.ID or 0)<(b.ID or 0)
            end)
            return merged
        end},{__index=function(_,key)
            local member=manager[key]
            if type(member)=='function' then return function(_,...)return member(manager,...)end end
            return member
        end})
    end
    local ok,err=pcall(BaseDisplay,showAnim)
    Game.GetHistoryManager=originalGetter
    if not ok then
        rendering=nil;captured=nil
        print('[ParadeV314][TIMELINE] ERROR: '..tostring(err))
        -- Keep stock history usable when an incompatible timeline mod is active.
        return BaseDisplay(showAnim)
    end
    print('[ParadeV314][TIMELINE] merged parade cards='..#records)
end

-- Automatic display follows stock priority/suppression settings. Synthetic IDs
-- are consumed by the UI renderer only, never sent to GameCore notifications.
local autoSeen={}
local function RequestAuto(owner,count)
    if owner~=Game.GetLocalPlayer() or type(count)~='number' or count<=0 then return true end
    local key=tostring(owner)..':'..tostring(count)
    if autoSeen[key] then return true end
    if Options.GetAppOption('Debug','SuppressInfoPopups')==1 then return true end
    autoSeen[key]=true
    autoQueue[#autoQueue+1]={Owner=owner,Count=count}
    return true
end
local function PumpAuto(dt)
    if #autoQueue==0 then return end
    local presentation=ExposedMembers.ParadeV38Presentation
    if presentation and presentation.IsActive and presentation.IsActive() then return end
    local item=autoQueue[1]
    local player=Players[item.Owner]
    local prefix='PARADE_V315_MOMENT_'..item.Count..'_'
    if not player or player:GetProperty(prefix..'READY')~=1 then return end
    local score=tonumber((player:GetProperty(prefix..'SCORE'))) or 0
    if score<=0 then table.remove(autoQueue,1);return end
    if not item.Submitted then
        -- Stock OnProcessNotification defers new-moment display until popup
        -- priority allows it. The now-visible root controller keeps retrying.
        if UI.CanShowPopup and not UI.CanShowPopup(GetPopupPriority()) then return end
        automaticOpen=true
        local ok,err=true,nil
        -- Same award entry as stock OnProcessNotification: select the moment
        -- and request the native screen in ONE call, rather than opening a
        -- generic timeline and toggling/rebuilding it on the next frame.
        ok,err=pcall(ShowNewTimelineMoment,{momentID=-2000000-item.Count,showAnim=true})
        automaticOpen=false
        if not ok then
            print('[MilitaryParade][Timeline] queue failed: '..tostring(err));return
        end
        item.Submitted=true;item.Wait=0
        print('[MilitaryParade][Timeline] queued count='..item.Count..' delayed-show=false')
    end
    if ContextPtr:IsHidden() then
        item.Wait=(item.Wait or 0)+(type(dt)=='number' and dt or 0)
        -- Keep the request until it is visible. The native queue controls popup
        -- priority; a false CanShowPopup response cannot strand our own queue.
        if item.Wait>=2 and not UIManager:IsInPopupQueue(ContextPtr) then
            item.Submitted=false;item.Wait=0
            print('[MilitaryParade][Timeline] lost queue registration; retry count='..item.Count)
        end
        return
    end
    -- Submission is not visibility acknowledgement. Emit the award cue only
    -- after the native queue has actually presented this screen.
    UI.PlaySound('Pride_Moment')
    diagnostic.Stage='原版年表已显示 # '..item.Count
    table.remove(autoQueue,1)
    print('[MilitaryParade][Timeline] visible count='..item.Count)
end
ExposedMembers.ParadeV316Timeline={Ready=true,RequestAuto=RequestAuto,Pump=PumpAuto}
if Events.UIIdle then Events.UIIdle.Add(PumpAuto) end
