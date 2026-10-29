"""Static package validation only; does not test Civ6's texture loader."""
from pathlib import Path
import sqlite3,struct,xml.etree.ElementTree as E
from PIL import Image
r=Path(__file__).resolve().parents[1]
ns={'m':'http://schemas.microsoft.com/developer/msbuild/2003'}
p=E.parse(r/'MilitaryParade.civ6proj');refs=[x.attrib['Include'].replace('\\','/')for x in p.findall('.//m:Content',ns)]
assert len(refs)==len(set(refs))
for fn in refs:assert(r/fn).is_file(),fn
m=E.parse(r/'MilitaryParade.modinfo');fileRefs=[x.text for x in m.findall('./Files/File')]
assert len(fileRefs)==len(set(fileRefs))and set(refs)==set(fileRefs)
for x in m.findall('./InGameActions/*/File'):assert(r/x.text).is_file(),x.text
for x in m.findall('.//LuaReplace'):assert(r/x.text).is_file(),x.text
for name in ['InGameActionData','ActionCriteriaData']:
 E.fromstring(p.find('.//m:'+name,ns).text)
# The ModBuddy Build path and direct-install path must install identical actions.
a=E.fromstring(p.find('.//m:InGameActionData',ns).text.replace('(Mod Art Dependency File)','MilitaryParade.dep'))
def canonical(node):return(node.tag,tuple(sorted(node.attrib.items())),(node.text or'').strip(),tuple(canonical(x)for x in node))
assert canonical(a)==canonical(m.find('./InGameActions'))
c=sqlite3.connect(':memory:')
c.executescript('CREATE TABLE LocalizedText(Language TEXT,Tag TEXT,Text TEXT,PRIMARY KEY(Language,Tag));CREATE TABLE IconTextureAtlases(Name TEXT,IconSize INTEGER,IconsPerRow INTEGER,IconsPerColumn INTEGER,Filename TEXT,PRIMARY KEY(Name,IconSize));CREATE TABLE IconDefinitions(Name TEXT PRIMARY KEY,Atlas TEXT,"Index" INTEGER);')
c.executescript((r/'Parade_Text.sql').read_text());c.executescript((r/'Parade_Icons.sql').read_text())
c.executescript((r/'Parade_Quotes.sql').read_text())
assert c.execute('SELECT COUNT(*),MIN(QuoteID),MAX(QuoteID) FROM ParadeQuotes').fetchone()==(40,1,40)
assert '现代文学' in c.execute('SELECT Attribution FROM ParadeQuotes WHERE QuoteID=2').fetchone()[0]
imports={x.text for x in m.findall('./InGameActions/ImportFiles/File')}
rows=c.execute('SELECT IconSize,Filename FROM IconTextureAtlases').fetchall()
assert len(rows)==44
for n,fn in rows:
 assert fn in imports and fn in refs
 raw=(r/fn).read_bytes();assert raw[:4]==b'DDS 'and raw[84:88]==b'DXT5'
 h,w=struct.unpack_from('<II',raw,12);assert h==w and w>=n and w&(w-1)==0
 size=((w+3)//4)**2*16;assert len(raw)==128+size and struct.unpack_from('<I',raw,20)[0]==size
 im=Image.open(r/fn);im.load();assert im.mode=='RGBA'and im.size==(w,w)
 lo,hi=im.crop((0,0,n,n)).getchannel('A').getextrema();assert lo<255 and hi>0
print('PASS: matched direct-install/ModBuddy actions, 44 DXT5 atlases, exact import names, SQL, alpha, DDS headers and decoding')

for xml in r.glob('*.xml'):E.fromstring(xml.read_text(encoding='utf-8-sig').replace('AssetObjects::','AssetObjects..'))
print('PASS: 40 quotations with unique IDs; modern excerpt labelled; all UI XML parses')

# Every statically referenced top-level control must actually exist in its XML.
import re
for name in ['Parade_UI','Parade_Celebration']:
 ids={x.attrib['ID']for x in E.parse(r/(name+'.xml')).iter()if 'ID'in x.attrib}
 names=set(re.findall(r'Controls\.([A-Za-z_][A-Za-z_0-9]*)',(r/(name+'.lua')).read_text()))
 assert names<=ids,(name,sorted(names-ids))
print('PASS: actual XML contains every top-level control referenced by UI Lua')

header=next(x for x in E.parse(r/'Parade_Celebration.xml').iter('Grid') if x.attrib.get('Texture')=='Controls_LensHeaderSmall')
assert header.attrib['Anchor']=='C,T' and header.attrib['Offset']=='0,0' and header.attrib['Size']=='parent,64'
print('PASS: full-width celebration header anchored at top with zero offset')

art=r/'Parade_EraMoment.dds';raw=art.read_bytes()
assert raw[:4]==b'DDS 'and raw[84:88]==b'DXT5'
h,w=struct.unpack_from('<II',raw,12);assert(w,h)==(1024,512)
im=Image.open(art);im.load();assert im.size==(1024,512)
assert 'Parade_EraMoment.dds' in imports and 'Parade_EraMoment.dds' in refs
assert not any('Parade_History'in name for name in refs)
assert not (r/'Parade_History.lua').exists()and not(r/'Parade_History.xml').exists()
print('PASS: scroll art DXT5 decode/import, removed chronicle files and actions')

# The previous 1024x512 texture was shown as a clipped top-left viewport.
# Each target now receives a complete resized composition in its exact logical
# pixel rectangle, with transparent POT padding, like the working icon atlases.
for fn,logical,padded in [('Parade_TimelineMoment.dds',(456,228),(512,256)),('Parade_EraMoment.dds',(720,360),(1024,512))]:
 im=Image.open(r/fn);im.load();assert im.size==padded and im.mode=='RGBA'
 w,h=logical
 assert im.crop((0,0,w,h)).getchannel('A').getextrema()==(255,255)
 assert im.crop((w,0,padded[0],padded[1])).getchannel('A').getextrema()==(0,0)
 assert im.crop((0,h,w,padded[1])).getchannel('A').getextrema()==(0,0)
 assert fn in imports and fn in refs
print('PASS: exact-pixel full-composition timeline/ceremony textures with transparent POT padding')

description=c.execute("SELECT Text FROM LocalizedText WHERE Language='zh_Hans_CN'AND Tag='LOC_PROJECT_MILITARY_PARADE_DESCRIPTION'").fetchone()[0]
assert len(description.replace('[NEWLINE]',''))<=160 and description.count('[NEWLINE]')==2
assert '+10%'in description and '+50%'in description and '10回合'in description
print('PASS: concise three-paragraph project description retains duration and both distinct production bonuses')
