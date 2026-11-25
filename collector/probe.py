# 전국 자료 원천 시험 (본부, 임시) — 키는 찍지 않음
import os, json, urllib.request, urllib.parse, ssl, zipfile, io
K = os.environ.get("DATA_GO_KR_KEY", "").strip()
def get(u, n=700, raw=False):
    try:
        req = urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=40) as r:
            b = r.read() if raw else r.read(200000)
            print("  ->", r.status, r.headers.get("Content-Type"), len(b))
            if raw: return b
            print("  ", b[:n].decode("utf-8", "replace").replace("\n", " "))
            return b
    except Exception as e:
        print("  !!", repr(e)[:300])
def T(name, u, **kw):
    print("==", name); return get(u.replace("{K}", urllib.parse.quote(K, safe="")), **kw)
T("kapt 전체목록", "https://apis.data.go.kr/1613000/AptListService3/getTotalAptList3?serviceKey={K}&pageNo=1&numOfRows=3&_type=json")
T("kapt 시군구목록", "https://apis.data.go.kr/1613000/AptListService3/getSigunguAptList3?serviceKey={K}&sigunguCode=28185&pageNo=1&numOfRows=3&_type=json")
for v in ("AptBasisInfoServiceV4/getAphusBassInfoV4", "AptBasisInfoServiceV5/getAphusBassInfoV5", "AptBasisInfoServiceV3/getAphusBassInfoV3"):
    T("kapt 기본 "+v, "https://apis.data.go.kr/1613000/"+v+"?serviceKey={K}&kaptCode=A10027875&_type=json", n=1500)
T("소상공인 시군구", "https://apis.data.go.kr/B553077/api/open/sdsc2/storeListInDong?serviceKey={K}&divId=signguCd&key=28185&numOfRows=2&pageNo=1&type=json", n=1500)
T("소상공인 업종대분류", "https://apis.data.go.kr/B553077/api/open/sdsc2/largeUpjongList?serviceKey={K}&type=json", n=1500)
T("상가정보 파일 페이지", "https://www.data.go.kr/data/15083033/fileData.do", n=300)
T("localdata 파일(일반음식점)", "https://www.localdata.go.kr/datafile/each/07_24_04_P_CSV.zip", n=200)
T("localdata 첫화면", "https://www.localdata.go.kr/devcenter/dataDown.do?menuNo=20001", n=300)
T("인허가 data.go.kr 일반음식점 API", "https://apis.data.go.kr/1741000/GeneralRestaurants/getGeneralRestaurants?serviceKey={K}&pageNo=1&numOfRows=2&type=json", n=1200)
T("vworld", "https://api.vworld.kr/req/address?service=address&request=getcoord&address=test&type=road&key=x", n=300)
T("juso", "https://business.juso.go.kr/addrlink/addrCoordApi.do", n=200)
