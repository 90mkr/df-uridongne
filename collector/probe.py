import os, json, urllib.request, urllib.parse
from collections import Counter
K = urllib.parse.quote(os.environ.get("DATA_GO_KR_KEY", "").strip(), safe="")
u = "https://apis.data.go.kr/1741000/public_restroom_info_v2/info_v2?serviceKey=%s&pageNo=7&numOfRows=30&returnType=json" % K
j = json.loads(urllib.request.urlopen(u, timeout=180).read().decode())
it = j["response"]["body"]["items"]["item"]
print("KEYS", sorted(it[0].keys()))
c = Counter(k for x in it for k, v in x.items() if str(v).strip())
print("FILLED", c.most_common())
print("EX", json.dumps(it[3], ensure_ascii=False)[:1500])
