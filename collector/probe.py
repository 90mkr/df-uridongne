import os, re, json, time, urllib.request, urllib.parse, urllib.error
K = urllib.parse.quote(os.environ.get("DATA_GO_KR_KEY", "").strip(), safe="")
def get(u, n=3000, binary=False):
    try:
        with urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"}), timeout=60) as r:
            b = r.read(n); return b if binary else b.decode("utf-8", "replace"), dict(r.headers)
    except urllib.error.HTTPError as e: return "!!%s %s" % (e.code, e.read(200).decode("utf-8", "replace")), {}
    except Exception as e: return "!!" + repr(e)[:200], {}
t0 = time.time()
s, h = get("https://apis.data.go.kr/B553077/api/open/sdsc2/storeListInDong?serviceKey=%s&divId=ctprvnCd&key=50&numOfRows=1000&pageNo=1&type=json" % K, n=5_000_000)
print("SDSC jeju 1000", round(time.time()-t0, 1), "s", len(s))
try:
    j = json.loads(s); print("SDSC total", j["body"]["totalCount"], "items", len(j["body"]["items"]))
except Exception as e: print("SDSC err", s[:300])
s, h = get("https://www.data.go.kr/data/15083033/fileData.do", n=600000)
for m in sorted(set(re.findall(r"fn_fileDataDown\([^)]*\)|atchFileId=[A-Za-z0-9_]+|fileDetailSn=\d+|publicDataPk[^,]{0,40}|uddi:[0-9a-f-]+", s)))[:30]: print("FD", m)
i = s.find("fileDownload"); print("FDCTX", re.sub(r"\s+", " ", s[i-800:i+600]) if i > 0 else "none")
