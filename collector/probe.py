import os, urllib.request, urllib.parse, urllib.error
K = urllib.parse.quote(os.environ.get("DATA_GO_KR_KEY", "").strip(), safe="")
def get(u):
    try:
        with urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"}), timeout=40) as r: return r.read(3000).decode("utf-8", "replace")
    except urllib.error.HTTPError as e: return "!!%s %s" % (e.code, e.read(200).decode("utf-8", "replace"))
    except Exception as e: return "!!" + repr(e)[:200]
print("CALL kapt4", get("https://apis.data.go.kr/1613000/AptListService4/getSigunguAptList4?serviceKey=%s&sigunguCode=28185&pageNo=1&numOfRows=2" % K)[:800])
print("CALL kapt4tot", get("https://apis.data.go.kr/1613000/AptListService4/getTotalAptList4?serviceKey=%s&pageNo=1&numOfRows=2" % K)[:800])
for s in ("general_restaurants", "pharmacies", "beauty_salons", "laundries"):
    print("CALL", s, get("https://apis.data.go.kr/1741000/%s/info?serviceKey=%s&pageNo=1&numOfRows=1&returnType=json" % (s, K))[:1500])
