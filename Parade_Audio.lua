-- Parade on Master SFX; temporarily pause/resume only the Master Music bus.
ParadeAudio={}
local active=false
local loaded=false
local pending=nil
local age=0
local backgroundPaused=false
local PLAY='Play_MilitaryParade_Internationale_V311'
local STOP='Stop_MilitaryParade_Internationale_V311'
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
        if age>=23.1 then active=false end
    end
end
ExposedMembers.ParadeV311Audio=ParadeAudio
