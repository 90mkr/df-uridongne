# 전국 자료 원천 시험 (본부, 임시) — 키는 찍지 않음
import os, re, json, urllib.request, urllib.parse, urllib.error
K = os.environ.get("DATA_GO_KR_KEY", "").strip()
def get(u, n=700):
    try:
        req = urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=40) as r:
            b = r.read(400000); print("  ->", r.status, len(b)); return b.decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        print("  !!", e.code, e.read(600).decode("utf-8", "replace").replace("\n", " ")); return ""
    except Exception as e:
        print("  !!", repr(e)[:200]); return ""
def T(name, u, n=700):
    print("==", name); s = get(u.replace("{K}", urllib.parse.quote(K, safe="")))
    print("  ", s[:n].replace("\n", " ")); return s
for op in ("getTotalAptList3?", "getSigunguAptList3?sigunguCode=28185&", "getLegaldongAptList3?bjdCode=2818510600&", "getSidoAptList3?sidoCode=28&"):
    T("kapt "+op, "https://apis.data.go.kr/1613000/AptListService3/"+op+"serviceKey={K}&pageNo=1&numOfRows=3")
# 인허가 API 페이지에서 요청 주소 뽑기
for pid in ("15045016", "15154921", "15155058"):
    print("== page", pid)
    s = get("https://www.data.go.kr/data/%s/openapi.do" % pid)
    for m in sorted(set(re.findall(r"https?://apis\.data\.go\.kr/[0-9A-Za-z_/]+", s))): print("   url", m)
    t = re.sub(r"<[^>]+>", " ", s); t = re.sub(r"\s+", " ", t)
    i = t.find("요청변수"); print("   ", t[i:i+1500] if i >= 0 else t[:300])
    i = t.find("출력결과"); print("   ", t[i:i+2500] if i >= 0 else "")
