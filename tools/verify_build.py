"""Inspect a built/installed mod folder; never modifies it.
Usage: python tools/verify_build.py /path/to/the/built/mod
This checks files, not whether the game loaded them.
"""
from pathlib import Path
import sys,xml.etree.ElementTree as E

def verify(folder):
 root=Path(folder).resolve()
 mod=E.parse(root/'MilitaryParade.modinfo')
 assert mod.getroot().get('version')=='46','Build is not 2.0.5 production (mod version 46)'
 action=mod.find('./InGameActions/UpdateArt')
 assert action is not None,'UpdateArt missing from built manifest'
 dep_name=action.findtext('File')
 assert dep_name and dep_name!='(Mod Art Dependency File)','SDK did not resolve the art dependency placeholder'
 dep=(root/dep_name).read_text(encoding='utf-8-sig')
 assert 'Camera.artdef'in dep and 'Camera'in dep,'built dependency does not register Camera.artdef'
 art=(root/'ArtDefs/Camera.artdef').read_text(encoding='utf-8-sig')
 assert 'AssetObjects::ArtDefSet'in art,'Windows SDK ArtDef type spelling missing'
 camera=E.fromstring(art.replace('AssetObjects::','AssetObjects..'))
 heights=[]
 for item in camera.findall('m_RootCollections/Element/Element'):
  if item.find('m_Name').get('text')!='DEFAULT_CAMERA':continue
  for coll in item.findall('m_ChildCollections/Element'):
   if coll.find('m_CollectionName').get('text')!='HeightCurve':continue
   for point in coll.findall('Element'):
    values={v.find('m_ParamName').get('text'):float(v.findtext('m_fValue'))for v in point.findall('m_Fields/m_Values/Element')}
    if values['Time']==0:heights.append(values['Height'])
 assert heights==[18.0],f'built near camera height is {heights}, expected 18'
 replacement=next((a.find('Properties/LuaReplace').text for a in mod.findall('./InGameActions/ReplaceUIScript')if a.findtext('Properties/LuaContext')=='HistoricMoments'),None)
 assert replacement,'HistoricMoments replacement missing from built manifest'
 assert 'Parade' in (root/replacement).read_text(encoding='utf-8-sig'),'historic-moment extension missing'
 assert 'ContextPtr:SetHide(false)'in(root/'Parade_UI.lua').read_text(encoding='utf-8-sig'),'old UI dispatch in output'
 for file in mod.findall('./Files/File'):assert(root/file.text).is_file(),file.text
 for name in ['Parade_Rules.lua','Parade_Campaign.lua','Parade_Diplomacy.lua','Parade_March.lua','Parade_Delegation.xml','Parade_Setup.xml','Parade_Upgrade.sql','Parade_Upgrade_XP2.sql']:assert(root/name).is_file(),name
 print('PASS: 2.0.5 production runtime files, resolved art dependency, camera, timeline and upgrade modules. This is not an in-game validation.')

if __name__=='__main__':
 if len(sys.argv)!=2:raise SystemExit(__doc__)
 verify(sys.argv[1])
