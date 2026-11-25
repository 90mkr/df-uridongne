import os, json, urllib.request, urllib.parse
K = urllib.parse.quote(os.environ.get("DATA_GO_KR_KEY", "").strip(), safe="")
u = "https://apis.data.go.kr/B553077/api/open/sdsc2/smallUpjongList?serviceKey=%s&type=json" % K
j = json.loads(urllib.request.urlopen(u, timeout=60).read().decode())
for x in j["body"]["items"]: print("UP", x.get("indsLclsCd"), x.get("indsLclsNm"), x.get("indsMclsCd"), x.get("indsMclsNm"), x.get("indsSclsCd"), x.get("indsSclsNm"))
