"""Generate platform launcher assets from the shared SVG mark. Requires Pillow."""
import json
from pathlib import Path
import xml.etree.ElementTree as ET
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
svg = ET.parse(ROOT / "assets/brand/valora-mark.svg").getroot()
ns = {"svg": "http://www.w3.org/2000/svg"}
background = svg.find("svg:rect", ns).attrib["fill"]
polygon = svg.find("svg:polygon", ns)
points = [tuple(map(float, point.split(","))) for point in polygon.attrib["points"].split()]
master = Image.new("RGB", (1024, 1024), background)
ImageDraw.Draw(master).polygon(points, fill=polygon.attrib["fill"])

def save(path, size):
    path.parent.mkdir(parents=True, exist_ok=True)
    master.resize((size, size), Image.Resampling.LANCZOS).save(path)

for density, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    save(ROOT / f"android/app/src/main/res/mipmap-{density}/ic_launcher.png", size)

ios = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
for icon in json.loads((ios / "Contents.json").read_text())["images"]:
    if "filename" in icon:
        size = round(float(icon["size"].split("x")[0]) * float(icon["scale"].removesuffix("x")))
        save(ios / icon["filename"], size)

for size in (192, 512):
    for prefix in ("Icon", "Icon-maskable"):
        save(ROOT / f"web/icons/{prefix}-{size}.png", size)
save(ROOT / "web/favicon.png", 32)
print("Generated Valora Android, iOS, and web icons.")
