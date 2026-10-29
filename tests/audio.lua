-- Native calls are mocked: verifies balanced music lifecycle, not audible output.
local played={};local loaded=0
local audioEnv=setmetatable({ExposedMembers={},UI={
 LoadSoundBankGroup=function(group)assert(group==5);loaded=loaded+1 end,
 PlaySound=function(event)played[#played+1]=event end}},{__index=_G})
assert(loadfile(root..'/Parade_Audio.lua','t',audioEnv))()
local audio=audioEnv.ParadeAudio
local PAUSE='Pause_MilitaryParade_Background_V311'
local RESUME='Resume_MilitaryParade_Background_V311'
assert(audio.Play() and loaded==1 and #played==2 and played[1]==PAUSE)
audio.BeginPresentation();assert(#played==2,'replay nested the background pause')
audio.Play();assert(#played==3 and played[3]=='Stop_MilitaryParade_Internationale_V311')
audio.Tick(.06);assert(#played==3)
audio.EndPresentation();assert(played[4]==RESUME)
audio.Tick(.2);assert(#played==4,'closed popup restarted pending music')
audio.Play();assert(#played==6 and played[5]==PAUSE and loaded==1)
audio.Play();audio.Tick(.13);assert(#played==8 and loaded==1)
audio.EndPresentation();assert(#played==10 and played[10]==RESUME)
audio.EndPresentation();assert(#played==10,'duplicate close resumed someone else\'s pause')
audio.Play();audio.Tick(24);audio.EndPresentation();assert(#played==13 and played[13]==RESUME,'natural clip end left background paused')
-- Missing group API and failed native posting must not break the celebration.
audioEnv.UI.LoadSoundBankGroup=nil
audioEnv.UI.PlaySound=function()error('EXPECTED audio post failure')end
assert(loadfile(root..'/Parade_Audio.lua','t',audioEnv))()
assert(not audioEnv.ParadeAudio.Play())
audioEnv.ParadeAudio.EndPresentation()
print('PASS: one balanced background pause per scene, delayed replay, cancel-on-close, natural-end resume, no master resume, native error containment')
