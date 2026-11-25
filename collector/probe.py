import os, json, urllib.request, urllib.parse, urllib.error, datetime
K = urllib.parse.quote(os.environ.get("DATA_GO_KR_KEY", "").strip(), safe="")
B = "https://apis.data.go.kr/B552584/EvCharger/"
def get(u, h=None):
    try:
        r = urllib.request.urlopen(urllib.request.Request(u, headers=h or {}), timeout=60)
        return r.status, r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read(400).decode("utf-8", "replace")
    except Exception as e:
        return -1, repr(e)
print("now KST", datetime.datetime.utcnow() + datetime.timedelta(hours=9))
for sid in os.environ["SIDS"].split(","):
    c, b = get(f"{B}getChargerInfo?serviceKey={K}&pageNo=1&numOfRows=50&dataType=JSON&zcode=28&statId={sid}")
    print("DIRECT", sid, c, b[:200] if c != 200 else [(i.get("chgerId"), i.get("stat"), i.get("statUpdDt")) for i in (json.loads(b).get("items") or {}).get("item", [])])
    c, b = get(f"https://dongne-dari.dfmail.workers.dev/dg/B552584/EvCharger/getChargerInfo?pageNo=1&numOfRows=50&dataType=JSON&zcode=28&statId={sid}&_c=30", {"X-App": "dongne"})
    print("DARI  ", sid, c, b[:300] if c != 200 else [(i.get("chgerId"), i.get("stat"), i.get("statUpdDt")) for i in (json.loads(b).get("items") or {}).get("item", [])])
c, b = get(f"{B}getChargerStatus?serviceKey={K}&pageNo=1&numOfRows=20&dataType=JSON&period=10&zcode=28")
print("STATUS", c, b[:600])
