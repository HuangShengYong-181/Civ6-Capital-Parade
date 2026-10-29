#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
"""Build only the parade's native v113 bank. No game DLL or Wwise editor required.
Routing template and bnktool: cru121/civ6-dev-ce (AGPL-3.0-only).
"""
from pathlib import Path
import json, struct
import bnktool as b

ROOT = Path(__file__).resolve().parents[1]
NAME = 'MilitaryParade_Internationale_V311_Bank'
PLAY = 'Play_MilitaryParade_Internationale_V311'
STOP = 'Stop_MilitaryParade_Internationale_V311'

def build():
    template = json.loads((ROOT/'tools/parade_audio_template.json').read_text())
    wav = ROOT/'AudioSource/Parade_Internationale.wav'
    # A single private 2D mixer routes straight to the stock Master SFX bus.
    # Discard the copied notification mixers, FX/state references and their buses.
    mixer = bytearray(bytes.fromhex(template['chain'][0]))
    assert len(mixer) == 44 and mixer[5] == 0
    mixer[4] = 1  # override parent FX, with no FX
    mixer[7:11] = b.u32(3577355056)
    mixer[11:15] = b.u32(0)
    mixer[18] = 0xC3  # explicit 2D positioning, no 3D attenuation
    blob, _ = b.build_bank(NAME, [dict(event=PLAY, wem=b.pcm_wem(str(wav)),
        body=bytes.fromhex(template['sound']), plugin=0x00010001)],
        chain=[bytes(mixer)])
    objects = b.read_hirc(blob)
    sound = next(body for kind, body in objects if kind == 2)
    target = struct.unpack_from('<I', sound)[0]
    stop_id = b.fnv(NAME+'/stop')
    # Wwise v113 Stop_E, target-specific across game objects. No Stop_ALL.
    # id, actionType, target, isBus, empty properties/ranges, linear fade, exceptions.
    stop = b.u32(stop_id) + struct.pack('<H',0x0102) + b.u32(target) + bytes(3) + b'\x04' + b.u32(0)
    # A play event only plays. Replay stops in Lua and waits a frame before play.
    events = list(objects)
    idx = next(i for i,(kind,_) in enumerate(events) if kind == 4)
    events.insert(idx,(3,stop))
    events.append((4,b.u32(b.fnv(STOP))+b.u32(1)+b.u32(stop_id)))
    # Pause/resume only the stock Master Music bus. Parade audio uses Master SFX.
    # Keep the normal resume count semantics (bIsMasterResume=0).
    for label,atype in [('Pause',0x0202),('Resume',0x0302)]:
        aid=b.fnv(NAME+'/'+label.lower()+'_background')
        action=b.u32(aid)+struct.pack('<H',atype)+b.u32(48433064)+b'\x01'+bytes(2)+b'\x04'+bytes(1)+b.u32(0)
        idx=next(i for i,(kind,_) in enumerate(events) if kind==4)
        events.insert(idx,(3,action))
        ename=label+'_MilitaryParade_Background_V311'
        events.append((4,b.u32(b.fnv(ename))+b.u32(1)+b.u32(aid)))
    chunks = {tag:(off,size) for tag,off,size in b.read_chunks(blob)}
    off,size = chunks['DIDX']; data_off,_ = chunks['DATA']
    media = []
    for i in range(0,size,12):
        mid,start,length = struct.unpack_from('<III',blob,off+i)
        media.append((mid,blob[data_off+start:data_off+start+length]))
    out = ROOT/'Platforms/Windows/Audio';out.mkdir(parents=True,exist_ok=True)
    (out/(NAME+'.bnk')).write_bytes(b.assemble(NAME,events,media))
    (out/'MilitaryParadeBanks.ini').write_bytes(('\r\n'.join([
        '[Global]','','[Menu]','','[InGame]','!'+NAME+'.bnk','','[2D]','','[3D]','','[FMV]','!'+NAME+'.bnk',''])).encode())
    print('Built native v113 bank:',PLAY,STOP)

if __name__ == '__main__': build()
