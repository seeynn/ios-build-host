from pathlib import Path
import shutil, hashlib

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "v3" / "files"
PATCH = ROOT / "v4"
FILES = PATCH / "files"

if FILES.exists():
    shutil.rmtree(FILES)
shutil.copytree(SRC, FILES)

payloads = [
    ("SeeiynSplash.jpg", "v4/files/SeeiynSplash.jpg"),
    ("projectui/TitleScreen.jpg", "v4/files/projectui/TitleScreen.jpg"),
    ("projectui/MainMenu.jpg", "v4/files/projectui/MainMenu.jpg"),
    ("projectui/roster.properties", "v4/files/projectui/roster.properties"),
]
entries=[]
total=0
for dest, source in payloads:
    data=(ROOT/source).read_bytes()
    total += len(data)
    entries.append((dest,source,len(data),hashlib.sha256(data).hexdigest()))

lines=[
    "schema=1",
    "patch.version=4",
    "core.min=26",
    "core.max=26",
    f"file.count={len(entries)}",
    f"patch.totalSize={total}",
    "patch.action=update",
    "revoked.versions=1,2,3",
    "",
]
for i,(dest,source,size,sha) in enumerate(entries):
    lines += [
        f"file.{i}.path={dest}",
        f"file.{i}.source={source}",
        f"file.{i}.size={size}",
        f"file.{i}.sha256={sha}",
        "",
    ]
(PATCH/"manifest.properties").write_text("\n".join(lines).rstrip()+"\n", encoding="utf-8", newline="\n")
print("PATCH4_RECOVERY_GENERATED")
