"""Generate platform branding from the user-supplied Valora kit. Requires Pillow.
Run: python mobile/scripts/generate_brand_assets.py
"""
from pathlib import Path
import json
from xml.etree import ElementTree as ET
from PIL import Image

root=Path(__file__).resolve().parents[1]
brand=root/'assets/brand'
icon=Image.open(brand/'valora-app-icon-square.png').convert('RGB')
logo=Image.open(brand/'valora-logo-primary.png').convert('RGBA')
logo.crop(logo.getbbox()).save(brand/'valora-logo-app.png',optimize=True)
res=root/'android/app/src/main/res'
for density,size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    target=res/f'mipmap-{density}'
    target.mkdir(exist_ok=True)
    icon.resize((size,size),Image.Resampling.LANCZOS).save(target/'ic_launcher.png',optimize=True)

# Preserve the kit's exact vector path geometry for adaptive launcher masks.
svg=ET.parse(brand/'valora-app-icon-square.svg').getroot()
ns={'s':'http://www.w3.org/2000/svg'}
group=svg.find('s:g',ns)
paths=list(group)
base='<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="1024" android:viewportHeight="1024">'
transform='<group android:translateX="183.2" android:translateY="188.68" android:scaleX="5.48" android:scaleY="5.48">'
for monochrome in [False,True]:
    content=base+transform+''.join('<path android:fillColor="'+('#FFFFFFFF' if monochrome else path.attrib['fill'])+'" android:pathData="'+path.attrib['d']+'"/>' for path in paths)+'</group></vector>\n'
    (res/'drawable'/('valora_icon_monochrome.xml' if monochrome else 'valora_icon_foreground.xml')).write_text(content,encoding='utf-8')
(res/'values/brand_icon.xml').write_text('<resources><color name="valora_icon_background">#1F5A44</color></resources>\n',encoding='utf-8')
for version in ['v26','v33']:
    target=res/f'mipmap-anydpi-{version}'
    target.mkdir(exist_ok=True)
    content='<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@color/valora_icon_background"/><foreground android:drawable="@drawable/valora_icon_foreground"/>'
    if version=='v33':content+='<monochrome android:drawable="@drawable/valora_icon_monochrome"/>'
    (target/'ic_launcher.xml').write_text(content+'</adaptive-icon>\n',encoding='utf-8')

appicons=root/'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for entry in json.loads((appicons/'Contents.json').read_text(encoding='utf-8'))['images']:
    if 'filename' not in entry:continue
    size=round(float(entry['size'].split('x')[0])*float(entry['scale'].removesuffix('x')))
    icon.resize((size,size),Image.Resampling.LANCZOS).save(appicons/entry['filename'],optimize=True)
for name,size in [('Icon-192.png',192),('Icon-512.png',512),('Icon-maskable-192.png',192),('Icon-maskable-512.png',512)]:
    icon.resize((size,size),Image.Resampling.LANCZOS).save(root/'web/icons'/name,optimize=True)
icon.resize((32,32),Image.Resampling.LANCZOS).save(root/'web/favicon.png',optimize=True)
print('Generated in-app wordmark and Android/iOS/web icons from supplied brand artwork.')
