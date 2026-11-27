# 임시 확인: 브이월드 좌표·K-apt 기본정보가 왜 비는지 (11-28)
import json, os, urllib.parse, urllib.request, urllib.error
KEY = os.environ.get("DATA_GO_KR_KEY", "").strip()
VK = os.environ.get("VWORLD_KEY", "").strip()
print("VWORLD_KEY 길이", len(VK), "DATA 키 길이", len(KEY))
def get(u, h=None):
    try:
        r = urllib.request.urlopen(urllib.request.Request(u, headers=h or {"User-Agent": "Mozilla/5.0 yogikok"}), timeout=40)
        return r.status, r.read(600).decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read(400).decode("utf-8", "replace")
    except Exception as e:
        return "ERR", repr(e)[:300]
for typ, addr in (("road", "인천광역시 연수구 인천타워대로 323"), ("parcel", "인천광역시 연수구 송도동 30")):
    for dom in ("", "designfeel.kr"):
        q = {"service": "address", "request": "getcoord", "version": "2.0", "crs": "epsg:4326", "address": addr, "format": "json", "type": typ, "key": VK}
        if dom: q["domain"] = dom
        print("vworld", typ, dom or "-", *get("https://api.vworld.kr/req/address?" + urllib.parse.urlencode(q)))
# 사이트 이름 붙여서 (브이월드는 등록한 서비스 URL 을 Referer 로 보기도 함)
q = {"service": "address", "request": "getcoord", "version": "2.0", "crs": "epsg:4326", "address": "인천광역시 연수구 인천타워대로 323", "format": "json", "type": "road", "key": VK}
print("vworld referer", *get("https://api.vworld.kr/req/address?" + urllib.parse.urlencode(q), {"User-Agent": "Mozilla/5.0", "Referer": "https://designfeel.kr/"}))
# K-apt 기본정보 (하루 한도?)
for code in ("A10027875", "A41982101"):
    u = "https://apis.data.go.kr/1613000/AptBasisInfoServiceV5/getAphusBassInfoV5?" + urllib.parse.urlencode({"serviceKey": KEY, "kaptCode": code, "_type": "json"})
    print("kapt", code, *get(u))
