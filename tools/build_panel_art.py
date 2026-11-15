from pathlib import Path
from PIL import Image,ImageDraw
import math
r=Path(__file__).resolve().parents[1];out=r/'Art/UI';out.mkdir(parents=True,exist_ok=True)
def make(name,base,accent,emblem):
 w,h=1024,768;im=Image.new('RGB',(w,h));pix=im.load()
 for y in range(h):
  for x in range(w):
   light=math.exp(-((x-170)**2/150000+(y-55)**2/70000));rim=math.exp(-((x-930)**2/200000+(y-650)**2/150000))
   weave=((x+y)%7==0)*1.3
   pix[x,y]=tuple(min(255,int(v+light*18+rim*5+weave)) for v in base)
 d=ImageDraw.Draw(im,'RGBA')
 # Fine architectural lattice and a soft medallion watermark, outside reading areas.
 for x in range(-800,1700,54):d.line((x,0,x+768,768),fill=(*accent,9),width=1)
 d.rounded_rectangle((5,5,1018,762),radius=14,outline=(*accent,185),width=2)
 d.rounded_rectangle((15,15,1008,752),radius=9,outline=(*accent,50),width=1)
 d.rectangle((20,20,1004,118),fill=(*accent,13))
 d.line((44,119,980,119),fill=(*accent,115),width=1)
 for cx in (32,992):
  for cy in (32,736):
   sx=1 if cx<512 else -1;sy=1 if cy<384 else -1
   d.line((cx,cy+35*sy,cx,cy,cx+65*sx,cy),fill=(*accent,170),width=3)
 # Gold laurel emblem with a central shield/compass, intentionally faint.
 cx,cy=875,637
 for side in (-1,1):
  pts=[]
  for k in range(13):
   a=math.radians(20+k*11);x=cx+side*92*math.sin(a);y=cy+85*math.cos(a);pts.append((x,y))
   dx=side*20*math.cos(a);dy=-16*math.sin(a)
   d.polygon([(x,y),(x+dx-6,y+dy-5),(x+dx*1.6,y+dy*1.6),(x+dx+5,y+dy+5)],fill=(*accent,36))
  d.line(pts,fill=(*accent,35),width=2)
 if emblem=='shield':
  d.polygon([(cx-40,cy-48),(cx+40,cy-48),(cx+32,cy+12),(cx,cy+47),(cx-32,cy+12)],outline=(*accent,45),width=3)
  d.line((cx-23,cy+16,cx+22,cy-25),fill=(*accent,40),width=5)
 else:
  d.ellipse((cx-48,cy-48,cx+48,cy+48),outline=(*accent,40),width=2)
  for a in range(0,360,45):
   v=math.radians(a);d.line((cx,cy,cx+42*math.cos(v),cy+42*math.sin(v)),fill=(*accent,30),width=2)
 # Header ornament, footer procession rhythm.
 for x in range(430,595,18):d.polygon([(x,16),(x+4,20),(x,24),(x-4,20)],fill=(*accent,135))
 im.convert('RGBA').save(r/(name+'.dds'),pixel_format='DXT5')
 im.save(out/(name+'.png'))
make('ParadeCeremony',(34,18,27),(208,168,89),'shield')
make('ParadeDiplomacy',(13,30,41),(202,171,112),'globe')
make('ParadeVisit',(20,36,37),(188,184,139),'globe')
make('ParadeTest',(19,27,41),(112,157,186),'shield')
