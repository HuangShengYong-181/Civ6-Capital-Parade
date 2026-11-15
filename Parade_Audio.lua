-- Parade on Master SFX; temporarily pause/resume only the Master Music bus.
if include then include('Parade_CustomMusic.lua') end
ParadeAudio={}
local selected=nil
local notice=nil
local active=false
local loaded=false
local pending=nil
local age=0
local backgroundPaused=false
local PLAY='Play_MilitaryParade_Internationale_V311'
local STOP='Stop_MilitaryParade_Internationale_V311'
local function Choice()
    return selected or (GameConfiguration and GameConfiguration.GetValue('PARADE2_MUSIC')) or 'DEFAULT'
end
local function SelectEvents()
    local custom=Choice()=='CUSTOM'
    PLAY=custom and 'Play_MilitaryParade_Custom' or 'Play_MilitaryParade_Internationale_V311'
    STOP=custom and 'Stop_MilitaryParade_Custom' or 'Stop_MilitaryParade_Internationale_V311'
end
local function EnsureLoaded()
    if loaded then return end
    if type(UI.LoadSoundBankGroup)=='function' then
        local ok,err=pcall(UI.LoadSoundBankGroup,5)
        loaded=ok
        print('[ParadeV311][AUDIO] load FMV group callOK='..tostring(ok)..' detail='..tostring(err))
    else
        print('[ParadeV311][AUDIO] LoadSoundBankGroup unavailable; using InGame load')
    end
    -- Never unload a shared bank group when closing this popup.
end
local function ResumeBackground()
    if not backgroundPaused then return end
    local ok,err=pcall(UI.PlaySound,'Resume_MilitaryParade_Background_V311')
    if ok then backgroundPaused=false end
    print('[ParadeV311][AUDIO] resume background callOK='..tostring(ok)..' detail='..tostring(err))
end
function ParadeAudio.BeginPresentation()
    if Choice()=='OFF' then return end
    if Choice()=='CUSTOM' and not (ParadeCustomMusic and ParadeCustomMusic.Installed) then
        notice='尚未导入自选音乐：请使用模组附带的音乐导入工具选择MP3。'
        return
    end
    SelectEvents()
    EnsureLoaded()
    if backgroundPaused then return end
    local ok,err=pcall(UI.PlaySound,'Pause_MilitaryParade_Background_V311')
    backgroundPaused=ok
    print('[ParadeV311][AUDIO] pause background callOK='..tostring(ok)..' detail='..tostring(err))
end
local function Post()
    local ok,err=pcall(UI.PlaySound,PLAY)
    active=ok;age=0
    if not ok then ResumeBackground() end
    print('[ParadeV311][AUDIO] play '..PLAY..' callOK='..tostring(ok)..' detail='..tostring(err))
    return ok
end
function ParadeAudio.Stop()
    pending=nil
    if not active then return end
    local ok,err=pcall(UI.PlaySound,STOP)
    print('[ParadeV311][AUDIO] stop callOK='..tostring(ok)..' detail='..tostring(err))
    active=false
end
function ParadeAudio.EndPresentation()
    ParadeAudio.Stop()
    ResumeBackground()
end
function ParadeAudio.Play()
    if Choice()=='OFF' then notice='阅兵音乐已关闭';return false end
    if Choice()=='CUSTOM' and not (ParadeCustomMusic and ParadeCustomMusic.Installed) then notice='尚未导入音乐：退出游戏后，双击模组目录中的选择阅兵音乐.cmd';return false end
    ParadeAudio.BeginPresentation()
    if active or pending then
        ParadeAudio.Stop()
        pending=0.12
        return true
    end
    return Post()
end
function ParadeAudio.Tick(dt)
    if pending then
        pending=pending-dt
        if pending<=0 then pending=nil;Post() end
    elseif active then
        age=age+dt
        local duration=Choice()=='CUSTOM' and ParadeCustomMusic and ParadeCustomMusic.Duration or 23.1
        if age>=(duration or 23.1) then active=false;ResumeBackground() end
    end
end
function ParadeAudio.Description()
 if notice then return notice end
 if Choice()=='OFF' then return '音乐已关闭 · 点击切换' end
 if Choice()=='CUSTOM' then return '自选：'..(ParadeCustomMusic and ParadeCustomMusic.Title or '尚未导入') end
 return '国际歌 · 点击切换音乐'
end
function ParadeAudio.SetChoice(value)
 if value~='DEFAULT' and value~='CUSTOM' and value~='OFF' then return false end
 ParadeAudio.EndPresentation()
 selected=value;notice=nil
 return ParadeAudio.Play()
end
function ParadeAudio.Cycle()
 local previous=Choice()
 ParadeAudio.EndPresentation()
 selected=previous=='DEFAULT' and 'CUSTOM' or previous=='CUSTOM' and 'OFF' or 'DEFAULT'
 notice=nil
 local ok=ParadeAudio.Play()
 print('[Parade2][AUDIO] selection='..selected..' status='..ParadeAudio.Description())
 return ok
end
ExposedMembers.ParadeV311Audio=ParadeAudio
