"""Build the first public release bundle. Does not publish or contact Steam.
Usage: python tools/package_release.py /path/to/new/output-directory
"""
from pathlib import Path
import hashlib,shutil,sys,xml.etree.ElementTree as E

def build(destination):
 source=Path(__file__).resolve().parents[1]
 destination=Path(destination).resolve()
 if destination.is_relative_to(source):raise ValueError('Output must be outside the source tree')
 if destination.exists():raise FileExistsError('Choose a new output directory; existing files will not be overwritten')
 destination.mkdir(parents=True)
 release=destination/'Release/MilitaryParade';release.mkdir(parents=True)
 manifest=E.parse(source/'MilitaryParade.modinfo')
 names=['MilitaryParade.modinfo']+[n.text for n in manifest.findall('./Files/File')]
 assert len(names)==len(set(names))
 for name in names:
  rel=Path(name)
  if rel.is_absolute()or'..'in rel.parts:raise ValueError('Unsafe manifest path')
  target=release/rel;target.parent.mkdir(parents=True,exist_ok=True)
  shutil.copy2(source/rel,target)
 actual={p.relative_to(release).as_posix()for p in release.rglob('*')if p.is_file()}
 assert actual==set(names),'runtime file set differs from manifest'
 shutil.copytree(source,destination/'Source/MilitaryParade',ignore=shutil.ignore_patterns('__pycache__','*.pyc','.git'))
 docs=destination/'Docs';docs.mkdir()
 for name in ['README.md','CHANGELOG.md','VALIDATION.md','WORKSHOP_DESCRIPTION_zh_CN.md']:
  shutil.copy2(source/name,docs/name)
 shutil.copytree(source/'Workshop',destination/'Workshop')
 shutil.copy2(source/'PUBLISH_zh_CN.txt',destination/'PUBLISH_zh_CN.txt')
 (destination/'README_FIRST_zh_CN.txt').write_text(
  '阅兵 Military Parade 1.0.0 首发发行包\n\n'
  'Steam上传：打开PUBLISH_zh_CN.txt，选择Release/MilitaryParade/MilitaryParade.modinfo。\n'
  '简介与预览图：Workshop。直接上传发行目录，无需再次Build。\n'
  '本包已完成发行整理，实际Steam上传需通过本机Steam Workshop Uploader。\n\n'
  '手动安装：完整退出游戏，仅把Release/MilitaryParade放进Mods，替换旧版。\n'
  '源码：Source/MilitaryParade/MilitaryParade.sln。源码、音频构建工具和许可证保留。\n'
  '已知问题：原版历史年表不能可靠自动弹出；镜头聚焦与距离仍需优化，当前固定近景。\n',encoding='utf-8')
 hashes=[]
 for name in sorted(names):
  hashes.append(hashlib.sha256((release/name).read_bytes()).hexdigest()+'  Release/MilitaryParade/'+name)
 (destination/'SHA256SUMS.txt').write_text('\n'.join(hashes)+'\n')
 print('Built release bundle:',destination)
 print('Runtime files:',len(names))

if __name__=='__main__':
 if len(sys.argv)!=2:raise SystemExit(__doc__)
 build(sys.argv[1])
