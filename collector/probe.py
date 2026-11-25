import os, json, urllib.request, urllib.parse
K = urllib.parse.quote(os.environ.get("DATA_GO_KR_KEY", "").strip(), safe="")
for nm, x, y in (("광주", 126.8526, 35.1596), ("목포", 126.3922, 34.8118), ("순천", 127.4872, 34.9507)):
    u = "https://apis.data.go.kr/B553077/api/open/sdsc2/storeListInRadius?serviceKey=%s&radius=500&cx=%s&cy=%s&numOfRows=2&pageNo=1&type=json" % (K, x, y)
    j = json.loads(urllib.request.urlopen(u, timeout=60).read().decode())
    it = j["body"]["items"][0]; print("SIDO", nm, it["ctprvnCd"], it["ctprvnNm"], it["signguCd"], it["signguNm"])
