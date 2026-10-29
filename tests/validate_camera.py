"""Check the ArtDef patch and optionally compare original DEFAULT_CAMERA.
Usage: python validate_camera.py [/original/Camera.artdef]
No engine rendering is performed.
"""
from pathlib import Path
import copy,sys,xml.etree.ElementTree as E
r=Path(__file__).resolve().parents[1]
root=E.fromstring((r/'ArtDefs/Camera.artdef').read_text().replace('AssetObjects::','AssetObjects..'))
assert root.find('m_TemplateName').get('text')=='Camera'
cameras=root.findall('m_RootCollections/Element/Element')
assert len(cameras)==1 and cameras[0].find('m_Name').get('text')=='DEFAULT_CAMERA'
camera=cameras[0]
def height_collection(cam):
 return next(x for x in cam.findall('m_ChildCollections/Element')if x.find('m_CollectionName').get('text')=='HeightCurve')
points={}
for element in height_collection(camera).findall('Element'):
 values={v.find('m_ParamName').get('text'):float(v.findtext('m_fValue'))for v in element.findall('m_Fields/m_Values/Element')}
 points[values['Time']]=values['Height']
assert points=={0:50,10:168,100:600}
assert all(a<b for a,b in zip([points[k]for k in sorted(points)],[points[k]for k in sorted(points)][1:]))
# .dep uses the engine's double-colon type spelling, not XML namespaces.
dep=E.fromstring((r/'MilitaryParade.dep').read_text().replace('::','..'))
consumer=dep.find('SystemDependencies/Element')
assert consumer.find('ConsumerName').get('text')=='Camera'
assert consumer.find('ArtDefDependencyPaths/Element').get('text')=='Camera.artdef'
mod=E.parse(r/'MilitaryParade.modinfo')
assert mod.find('./InGameActions/UpdateArt/File').text=='MilitaryParade.dep'
if len(sys.argv)>1:
 original=E.fromstring(Path(sys.argv[1]).read_text().replace('AssetObjects::','AssetObjects..'))
 baseline=copy.deepcopy(next(c for c in original.findall('m_RootCollections/Element/Element')if c.find('m_Name').get('text')=='DEFAULT_CAMERA'))
 patched=copy.deepcopy(camera)
 for item in [baseline,patched]:item.find('m_ChildCollections').remove(height_collection(item))
 def canonical(node):return(node.tag,tuple(sorted(node.attrib.items())),(node.text or'').strip(),tuple(canonical(c)for c in node))
 assert canonical(baseline)==canonical(patched),'unrequested FOV/tilt/fog/default changes'
print('PASS: default camera near-height 50 / return point 168 / far-height 600; ArtDef/dependency registration; other original fields preserved when baseline supplied')

spec=E.fromstring((r/'Mod.Art.xml').read_text().replace('AssetObjects::','AssetObjects..'))
assert spec.find('artConsumers/Element/consumerName').get('text')=='Camera'
assert spec.find('artConsumers/Element/relativeArtDefPaths/Element').get('text')=='Camera.artdef'
project=E.parse(r/'MilitaryParade.civ6proj');ns={'m':'http://schemas.microsoft.com/developer/msbuild/2003'}
assert any(n.attrib['Include']=='Mod.Art.xml'for n in project.findall('.//m:None',ns))
actions=E.fromstring(project.find('.//m:InGameActionData',ns).text)
assert actions.find('UpdateArt/File').text=='(Mod Art Dependency File)'
print('PASS: ModBuddy Mod.Art.xml consumer, canonical Windows SDK types and generated dependency placeholder')
