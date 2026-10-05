from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import hashlib

ROOT = Path(__file__).resolve().parents[1]
PATCH = ROOT / "v5"
FILES = PATCH / "files"
PROJECTUI = FILES / "projectui"
PROJECTUI.mkdir(parents=True, exist_ok=True)

W, H = 3072, 1728
FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT_ITALIC = "/usr/share/fonts/truetype/dejavu/DejaVuSans-BoldOblique.ttf"
FONT_REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

def f(path, size):
    return ImageFont.truetype(path, size)

def background():
    im = Image.new("RGB", (W, H), (4, 10, 24))
    px = im.load()
    for y in range(H):
        t = y / float(H - 1)
        col = (int(4 + 6*t), int(10 + 22*t), int(24 + 52*t))
        for x in range(W):
            px[x, y] = col
    im = im.convert("RGBA")
    glow = Image.new("RGBA", (W, H), (0,0,0,0))
    gd = ImageDraw.Draw(glow)
    for radius, alpha in ((1050,8),(820,10),(620,13),(440,17),(280,23)):
        cx, cy = int(W*0.08), int(H*0.50)
        gd.ellipse((cx-radius, cy-radius, cx+radius, cy+radius), fill=(38,94,235,alpha))
    glow = glow.filter(ImageFilter.GaussianBlur(80))
    im = Image.alpha_composite(im, glow)
    d = ImageDraw.Draw(im, "RGBA")
    for x in range(-300, W+500, 128):
        d.line((x,0,x+560,H), fill=(76,132,255,34), width=2)
    for y in range(0, H, 112):
        d.line((0,y,W,y), fill=(74,130,255,30), width=2)
    for x in (W*0.075,W*0.095,W*0.855,W*0.875):
        d.rectangle((x,0,x+2,H), fill=(132,182,255,36))
    return im

def save_jpeg(im, path):
    im.convert("RGB").save(path, "JPEG", quality=92, subsampling=0, optimize=True, progressive=True)

# Splash: no publisher/modder credit.
im = background()
im = Image.alpha_composite(im, Image.new("RGBA",(W,H),(0,0,0,85)))
d = ImageDraw.Draw(im, "RGBA")
word = "seeiyn"
ft = f(FONT_BOLD, 172)
bb = d.textbbox((0,0), word, font=ft)
d.text(((W-(bb[2]-bb[0]))/2,H*0.425), word, font=ft, fill=(245,249,255,255))
d.rectangle((W*0.392,H*0.568,W*0.608,H*0.573), fill=(91,151,255,190))
sub = "TAP BATTLE  /  CORE 26"
fs = f(FONT_REG, 31)
bb = d.textbbox((0,0), sub, font=fs)
d.text(((W-(bb[2]-bb[0]))/2,H*0.605), sub, font=fs, fill=(162,193,240,230))
save_jpeg(im, FILES/"SeeiynSplash.jpg")

# Tap-to-start screen.
im = background()
d = ImageDraw.Draw(im, "RGBA")
for dx, alpha in ((0,220),(15,120),(30,60)):
    d.rectangle((W*0.115+dx,H*0.24,W*0.117+dx,H*0.73), fill=(92,154,255,alpha))
d.text((W*0.158,H*0.265), "DRAGON BALL", font=f(FONT_BOLD,55), fill=(188,214,255,245))
d.text((W*0.15,H*0.355), "TAP", font=f(FONT_ITALIC,214), fill=(248,251,255,255))
d.text((W*0.15,H*0.505), "BATTLE", font=f(FONT_ITALIC,214), fill=(248,251,255,255))
d.text((W*0.157,H*0.705), "2026 REMASTER", font=f(FONT_REG,34), fill=(141,183,247,228))
x0,x1,y0,y1 = W*0.565,W*0.875,H*0.715,H*0.825
d.rounded_rectangle((x0,y0,x1,y1), radius=30, fill=(8,27,68,205), outline=(127,179,255,220), width=4)
cta = "TAP TO START"
fc = f(FONT_BOLD,44)
bb=d.textbbox((0,0),cta,font=fc)
d.text(((x0+x1-(bb[2]-bb[0]))/2,(y0+y1-(bb[3]-bb[1]))/2-8),cta,font=fc,fill=(248,251,255,255))
d.text((W*0.158,H*0.865),"seeiyn",font=f(FONT_REG,29),fill=(179,204,241,230))
save_jpeg(im, PROJECTUI/"TitleScreen.jpg")

# Five-row remaster menu: three live routes plus inert Event/News placeholders.
im = background()
d = ImageDraw.Draw(im, "RGBA")
d.text((W*0.10,H*0.145),"MODE",font=f(FONT_ITALIC,118),fill=(248,251,255,255))
d.text((W*0.10,H*0.24),"SELECT",font=f(FONT_ITALIC,118),fill=(248,251,255,255))
d.text((W*0.105,H*0.385),"Choose a route",font=f(FONT_REG,34),fill=(154,187,239,230))
d.rectangle((W*0.105,H*0.45,W*0.36,H*0.454),fill=(85,148,255,155))
d.text((W*0.105,H*0.79),"TAP BATTLE",font=f(FONT_BOLD,42),fill=(191,216,255,236))
d.text((W*0.105,H*0.843),"seeiyn",font=f(FONT_REG,28),fill=(126,163,222,224))
labels = ["ARCADE","VERSUS","DATA","RANKING","TRAINING","OPTIONS"]
centers = [41,84,127.5,172,216.5,261]
for idx,(label,logical_y) in enumerate(zip(labels,centers)):
    cy=logical_y/320.0*H
    x0,x1=W*0.52,W*0.90
    hh=H*0.091
    y0,y1=cy-hh/2,cy+hh/2
    fill=(26,70,156,225) if idx==0 else (10,34,84,208)
    outline=(173,210,255,245) if idx==0 else (100,159,255,215)
    d.rounded_rectangle((x0,y0,x1,y1), radius=29, fill=fill, outline=outline, width=4)
    d.text((x0+34,y0+27),f"{idx+1:02d}",font=f(FONT_BOLD,29),fill=(121,169,239,220))
    d.text((x0+122,y0+18),label,font=f(FONT_BOLD,46),fill=(248,251,255,255))
    d.polygon([(x1-65,cy-17),(x1-36,cy),(x1-65,cy+17)], fill=(196,222,255,235))
save_jpeg(im, PROJECTUI/"MainMenu.jpg")

# Keep Patch 2 roster state cumulative but remove the proof-only suffix from the user-facing form name.
roster = (ROOT/"v4/files/projectui/roster.properties").read_text(encoding="utf-8")
roster = roster.replace("57=granolah|Granolah|Base (Signed Patch 2)|0", "57=granolah|Granolah|Base|0")
(PROJECTUI/"roster.properties").write_text(roster, encoding="utf-8", newline="\n")

payloads = [
    ("SeeiynSplash.jpg", "v5/files/SeeiynSplash.jpg"),
    ("projectui/TitleScreen.jpg", "v5/files/projectui/TitleScreen.jpg"),
    ("projectui/MainMenu.jpg", "v5/files/projectui/MainMenu.jpg"),
    ("projectui/roster.properties", "v5/files/projectui/roster.properties"),
]
entries=[]
total=0
for dest, source in payloads:
    data=(ROOT/source).read_bytes()
    total += len(data)
    entries.append((dest,source,len(data),hashlib.sha256(data).hexdigest()))

lines=[
    "schema=1",
    "patch.version=5",
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
print("PATCH5_UI_GENERATED")
