"""자동 제작 때 앱 아이콘·첫 화면 색을 넣는다 (flutter create 다음에 실행). 사용: brand.py [web] [android]
그림 원본: brand/ (대표님 11-24 웃는 집 + 위치 핀 아이콘)"""
import os
import re
import shutil
import sys

what = set(sys.argv[1:]) or {"web", "android"}
BLUE = "#015DFD"  # 새 아이콘 바탕 (대표님 11-24 웃는 집 아이콘)

if "web" in what and os.path.isdir("web"):
    os.makedirs("web/icons", exist_ok=True)
    for n in ("Icon-192", "Icon-512", "Icon-maskable-192", "Icon-maskable-512"):
        shutil.copy(f"brand/{n}.png", f"web/icons/{n}.png")
    shutil.copy("brand/favicon.png", "web/favicon.png")
    p = "web/index.html"
    if os.path.exists(p):
        s = open(p, encoding="utf-8").read()
        if "dongne-boot" not in s:
            s = s.replace("</head>", f'  <style id="dongne-boot">html,body{{background:{BLUE};}}</style>\n</head>', 1)
        open(p, "w", encoding="utf-8").write(s)
    p = "web/manifest.json"
    if os.path.exists(p):
        s = open(p, encoding="utf-8").read()
        s = re.sub(r'"background_color":\s*"[^"]*"', f'"background_color": "{BLUE}"', s)
        s = re.sub(r'"theme_color":\s*"[^"]*"', f'"theme_color": "{BLUE}"', s)
        open(p, "w", encoding="utf-8").write(s)

if "android" in what and os.path.isdir("android"):
    res = "android/app/src/main/res"
    for d in ("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"):
        os.makedirs(f"{res}/mipmap-{d}", exist_ok=True)
        shutil.copy(f"brand/ic_launcher_{d}.png", f"{res}/mipmap-{d}/ic_launcher.png")
    for d in ("drawable", "drawable-v21"):
        p = f"{res}/{d}/launch_background.xml"
        if os.path.exists(p):
            s = open(p, encoding="utf-8").read()
            s = re.sub(r'<item android:drawable="[^"]*"\s*/>', f'<item><color android:color="{BLUE}"/></item>', s, count=1)
            open(p, "w", encoding="utf-8").write(s)
print("brand ok", what)
