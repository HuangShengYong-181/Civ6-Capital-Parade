"""Static bank/link/media checks; does not emulate the game's audio engine."""
from pathlib import Path
import struct, wave, math, array, xml.etree.ElementTree as E
r=Path(__file__).resolve().parents[1]
def hash_name(name):
    n=2166136261
    for x in name.lower().encode(): n=((n*16777619)&0xffffffff)^x
    return n
def chunks(data,start=0):
    out={};i=start
    while i<len(data):
        tag=data[i:i+4];size=struct.unpack_from('<I',data,i+4)[0]
        assert i+8+size<=len(data)
        out[tag]=(i+8,size);i+=8+size+(size%2 if start else 0)
    assert i==len(data)
    return out
def integer(data,pos=0):return struct.unpack_from('<I',data,pos)[0]
name='MilitaryParade_Internationale_V311_Bank'
bank=r/('Platforms/Windows/Audio/'+name+'.bnk');data=bank.read_bytes();c=chunks(data)
assert set(c)=={b'BKHD',b'DIDX',b'DATA',b'HIRC'}
o,_=c[b'BKHD'];assert integer(data,o)==113 and integer(data,o+4)==hash_name(name)
do,ds=c[b'DATA'];assert do%16==0
io,isz=c[b'DIDX'];assert isz==12
mid,offset,length=struct.unpack_from('<III',data,io)
media=data[do+offset:do+offset+length];assert media[:4]==b'RIFF' and media[8:12]==b'WAVE'
wc=chunks(media,12);fo,fs=wc[b'fmt ']
assert struct.unpack_from('<HHI',media,fo)==(0xfffe,2,48000)
po,ps=wc[b'data']
with wave.open(str(r/'AudioSource/Parade_Internationale.wav'),'rb') as w:
    assert w.getnchannels()==2 and w.getsampwidth()==2 and w.getframerate()==48000
    assert 22.9<w.getnframes()/w.getframerate()<23.1
    assert w.readframes(w.getnframes())==media[po:po+ps]
pcm=array.array('h',media[po:po+ps]);assert max(abs(x) for x in pcm)<32767
assert math.sqrt(sum(x*x for x in pcm)/len(pcm))>100
ho,hs=c[b'HIRC'];count=integer(data,ho);pos=ho+4;objects={};order=[]
for _ in range(count):
    kind=data[pos];size=integer(data,pos+1);body=data[pos+5:pos+5+size];pos+=5+size
    oid=integer(body);assert oid not in objects
    objects[oid]=(kind,body);order.append(kind)
assert pos==ho+hs and order==[2,7,3,3,3,3,4,4,4,4]
sound_id,(kind,sound)=next((i,v)for i,v in objects.items()if v[0]==2)
assert integer(sound,4)==0x10001 and integer(sound,9)==mid and integer(sound,13)==length
parent=integer(sound,25);seen=set()
while parent:
    assert parent not in seen;seen.add(parent)
    kind,body=objects[parent];assert kind==7
    nfx=body[5];p=6+(1+nfx*7 if nfx else 0)+1
    bus=integer(body,p);parent=integer(body,p+4)
assert bus==3577355056 and len(seen)==1
assert body[4:7]==bytes([1,0,0]) and body[18]==0xc3
assert body[26:32]==bytes(6),"copied mixer has external states or RTPC"
play=objects[hash_name('Play_MilitaryParade_Internationale_V311')][1]
stop=objects[hash_name('Stop_MilitaryParade_Internationale_V311')][1]
assert integer(play,4)==1 and integer(stop,4)==1
stop_id=integer(stop,8);assert integer(play,8)!=stop_id
action=objects[stop_id][1]
assert struct.unpack_from('<H',action,4)[0]==0x0102 and integer(action,6)==sound_id
assert action[10:]==bytes(3)+b'\x04'+bytes(4)
assert struct.unpack_from('<H',objects[integer(play,8)][1],4)[0]==0x0403
m=E.parse(r/'MilitaryParade.modinfo')
assert {x.text for x in m.findall('./InGameActions/UpdateAudio/File')}=={
 'Platforms/Windows/Audio/MilitaryParadeBanks.ini','Platforms/Windows/Audio/'+name+'.bnk'}
ini=(bank.parent/'MilitaryParadeBanks.ini').read_text();assert '[InGame]\n!'+name+'.bnk' in ini and '[FMV]\n!'+name+'.bnk' in ini
print('PASS: native v113 bank, media alignment and exact PCM, 23s stereo audio, no clipping, unique IDs, direct Master SFX / explicit 2D / no states or FX, separate scoped stop, UpdateAudio registration')

for verb,atype in [('Pause',0x0202),('Resume',0x0302)]:
 event=objects[hash_name(verb+'_MilitaryParade_Background_V311')][1]
 assert integer(event,4)==1
 action=objects[integer(event,8)][1]
 assert struct.unpack_from('<H',action,4)[0]==atype
 assert integer(action,6)==48433064 and action[10]==1
 assert action[11:]==bytes(2)+b'\x04'+bytes(1)+bytes(4)
print('PASS: paired Pause_E/Resume_E target Master Music bus only; normal resume count; parade uses separate Master SFX')
