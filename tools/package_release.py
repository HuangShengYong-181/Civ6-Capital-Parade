"""Package declared runtime files only; no tests, Git metadata or local audio imports."""
from pathlib import Path
import shutil, zipfile, xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[1]
version="2.0.5"
out=root/"dist"/("MilitaryParade_"+version)
for component,source in [("MilitaryParade",root),("MilitaryParade_Settings",root/"Settings")]:
    manifest=source/(component+".modinfo")
    files={node.text for node in ET.parse(manifest).findall("./Files/File")}
    files.add(manifest.name)
    for name in files:
        rel=Path(name)
        if rel.is_absolute() or ".." in rel.parts: raise ValueError(name)
        src=source/rel
        if not src.is_file(): raise FileNotFoundError(src)
        dst=out/"Install"/component/rel
        dst.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(src,dst)
for name in ["README.md","LICENSE","THIRD_PARTY_NOTICES.md"]:
    shutil.copy2(root/name,out/name)
archive=root/"dist"/(out.name+".zip")
with zipfile.ZipFile(archive,"w",zipfile.ZIP_DEFLATED) as z:
    for src in sorted(out.rglob("*")):
        if src.is_file(): z.write(src,out.name+"/"+src.relative_to(out).as_posix())
print(archive)
