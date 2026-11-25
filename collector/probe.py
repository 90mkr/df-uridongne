import os, re, json, urllib.request, urllib.parse, urllib.error
from concurrent.futures import ThreadPoolExecutor
K = os.environ.get("DATA_GO_KR_KEY", "").strip()
def get(u):
    try:
        req = urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=40) as r: return r.read(800000).decode("utf-8", "replace")
    except urllib.error.HTTPError as e: return "!!%s %s" % (e.code, e.read(300).decode("utf-8", "replace"))
    except Exception as e: return "!!" + repr(e)[:200]
ids = open("collector/ids.txt").read().split()
def one(i):
    s = get("https://www.data.go.kr/data/%s/openapi.do" % i)
    t = re.search(r'"name":"([^"]+)"', s); u = sorted(set(re.findall(r"https?://apis\.data\.go\.kr/[0-9A-Za-z_]+/[0-9A-Za-z_]+", s)))
    return i, t.group(1) if t else "?", u
with ThreadPoolExecutor(8) as ex:
    for i, t, u in ex.map(one, ids): print("API", i, t, " ".join(u))
s = get("https://www.data.go.kr/data/15057332/openapi.do")
print("KAPT", re.findall(r'"name":"([^"]+)"', s)[:1], sorted(set(re.findall(r"https?://apis\.data\.go\.kr/[0-9A-Za-z_/]+", s))))
ops = re.findall(r'"(/[A-Za-z0-9]+)":\{"get"', s); print("KAPTOPS", ops)
# 한 개 인허가 응답 필드 보기 (활용신청 안 됐으면 403)
for u in ("https://apis.data.go.kr/1741000/public_restroom_info_v2/info_v2",):
    print("CALL", get(u + "?serviceKey=%s&pageNo=1&numOfRows=1&returnType=json" % urllib.parse.quote(K, safe=""))[:1200])
