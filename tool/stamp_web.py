"""미리보기에 판 번호를 찍는다: 브라우저가 예전 화면을 붙들고 있으면 새 판을 알아채고 한 번 새로고침한다."""
import json
import re
import sys

v = sys.argv[1]
web = "build/web"

# 1) 판 번호 파일 (매번 새로 받아 봄)
with open(f"{web}/version.json", "w", encoding="utf-8") as f:
    json.dump({"v": v}, f)

# 2) 첫 화면: 판 번호 확인 스크립트 + 새 파일 이름표
path = f"{web}/index.html"
html = open(path, encoding="utf-8").read()
html = re.sub(r"<!-- 판확인 -->.*?<!-- /판확인 -->\s*", "", html, flags=re.S)
check = (
    "<!-- 판확인 --><script>(function(){var cur='" + v + "';"
    "fetch('version.json?t='+Date.now(),{cache:'no-store'}).then(function(r){return r.json();})"
    ".then(function(j){if(j.v&&j.v!==cur){try{if(sessionStorage.getItem('df_reload')===j.v)return;"
    "sessionStorage.setItem('df_reload',j.v);}catch(e){}location.reload();}}).catch(function(){});})();"
    "</script><!-- /판확인 -->\n"
)
html = re.sub(r'flutter_bootstrap\.js(\?v=\d+)?', f"flutter_bootstrap.js?v={v}", html)
html = html.replace('<script src="flutter_bootstrap.js', check + '<script src="flutter_bootstrap.js', 1)
open(path, "w", encoding="utf-8").write(html)

# 3) 앱 본체 파일 이름표
path = f"{web}/flutter_bootstrap.js"
js = open(path, encoding="utf-8").read()
js = re.sub(r'"mainJsPath":"main\.dart\.js(\?v=\d+)?"', f'"mainJsPath":"main.dart.js?v={v}"', js)
open(path, "w", encoding="utf-8").write(js)
print("판 번호", v, "/ 확인 스크립트", "있음" if "판확인" in html else "없음",
      "/ 본체", re.search(r'"mainJsPath":"[^"]*"', js).group(0) if '"mainJsPath"' in js else "없음")
