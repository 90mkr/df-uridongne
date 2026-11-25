import os, re, json, urllib.request, urllib.parse, urllib.error
K = os.environ.get("DATA_GO_KR_KEY", "").strip()
def get(u):
    try:
        req = urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=40) as r: return r.read(600000).decode("utf-8", "replace")
    except urllib.error.HTTPError as e: return "!!%s %s" % (e.code, e.read(400).decode("utf-8", "replace"))
    except Exception as e: return "!!" + repr(e)[:200]
def txt(s): return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", s))
# 1) 목록 검색: 단지 목록, 인허가(행정안전부 1741000) 
for kw in ("공동주택 단지 목록제공", "행정안전부_식품", "행정안전부_건강", "행정안전부_생활", "행정안전부_문화", "행정안전부_동물", "행정안전부_기타", "행정안전부_자원환경", "행정안전부_체육", "행정안전부_인허가"):
    for page in (1, 2, 3):
        s = get("https://www.data.go.kr/tcs/dss/selectDataSetList.do?dType=API&keyword=%s&perPage=40&currentPage=%d" % (urllib.parse.quote(kw), page))
        hits = re.findall(r'href="/data/(\d+)/openapi\.do"[^>]*>\s*(?:<[^>]+>\s*)*([^<]{3,80})', s)
        if not hits: break
        for i, t in hits: print("LIST", kw, i, t.strip())
# 2) 휴게음식점 상세
s = get("https://www.data.go.kr/data/15154921/openapi.do"); t = txt(s)
for key in ("serviceKey", "SITETEL", "전화", "좌표"):
    for m in re.finditer(key, t):
        print("CTX", key, t[max(0, m.start()-300):m.start()+500]); break
print("CALL", get("https://apis.data.go.kr/1741000/rest_cafes/info?serviceKey=%s&pageNo=1&numOfRows=2&returnType=json" % urllib.parse.quote(K, safe=""))[:1500])
