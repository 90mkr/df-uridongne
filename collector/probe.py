import os, json, urllib.request, urllib.parse, urllib.error
K = urllib.parse.quote(os.environ.get("DATA_GO_KR_KEY", "").strip(), safe="")
for u in ("http://api.data.go.kr/openapi/tn_pubr_public_toilet_api?serviceKey=%s&pageNo=1&numOfRows=3&type=json" % K,):
    try:
        b = urllib.request.urlopen(u, timeout=120).read().decode("utf-8", "replace")
        print("T", b[:1800])
    except urllib.error.HTTPError as e:
        print("T!!", e.code, e.read(300).decode("utf-8", "replace"))
    except Exception as e:
        print("T!!", repr(e))
