"""지하철 전국 역 시간표 (대표님 11-28 「우리 앱을 쓰면 기존 앱을 지울 수 있게」) — 지금은 자료 길 확인 단계

연수구만 되던 시간표(subway.py)를 전국 역으로 넓히려고, 어떤 공공 자료가 우리 열쇠로 열리는지 먼저 찍어 본다.
(이 단계에서는 파일을 쓰지 않는다 — 기록만 남김)

11-28 찍어 본 결과
  · TAGO 「지하철정보」(SubwayInfoService) = 「해당 오픈API 서비스가 없거나 폐기됨」 → 더는 못 씀 (subway.py 의 TAGO 단계도 늘 빈손)
  · KRIC 「열차별 운행시각표」 = 우리 열쇠로 열림. 인천1(IC,I1,136) 304줄 · 서울2 강남(S1,2,222) 479줄 · 공항철도(AR,A1,A05) 416줄 · 광주1(GJ,1,105) 240줄
    나머지(서울 1·5·9호선, 신분당, 부산·대구·대전)는 역 번호를 어림으로 넣어 0줄 → 공식 「운영기관·호선·역 번호」 목록이 있어야 함
  · KRIC 「도시철도 전체노선정보」(subwayRouteInfo)·「역사별 정보」(stationInfo)·stationGateInfo = 「등록되지 않은 서비스키」 → 레일포털에서 활용신청만 하면 열림
    (전체노선정보가 열리면 호선별 역 순서·역 번호가 한 번에 나와 전국 시간표를 모을 수 있고, 노선 선 모양도 공식 순서로 고칠 수 있음)

    DATA_GO_KR_KEY   공공데이터포털 (TAGO 지하철정보)
    KRIC_KEY         레일포털 (열차별 운행시각표)
"""
import json
import os
import re
import urllib.parse
import urllib.request

DKEY = os.environ.get("DATA_GO_KR_KEY", "").strip()
RKEY = os.environ.get("KRIC_KEY", "").strip()
UA = {"User-Agent": "Mozilla/5.0 (udongkok collector)"}


def get(url, n=4000, headers=None):
    try:
        req = urllib.request.Request(url, headers=headers or UA)
        with urllib.request.urlopen(req, timeout=40) as r:
            return r.status, r.read().decode("utf-8", "replace")[:n]
    except urllib.error.HTTPError as e:  # type: ignore[attr-defined]
        return e.code, e.read().decode("utf-8", "replace")[:600]
    except Exception as e:  # noqa: BLE001
        return "ERR", repr(e)[:300]


def show(title, res, n=900):
    code, body = res
    print(f"--- {title} → {code}")
    print("   ", body[:n].replace("\n", " "))


def main():
    # 주마다 도는 전체 모으기에서는 쉬고, 「이것만」(features=subway_tt)으로 부를 때만 찍어 본다
    if "subway_tt" not in os.environ.get("FEATURES", ""):
        print("subway_tt: 자료 길 확인용 — 이번엔 건너뜀")
        return 0
    print("열쇠 길이: DATA", len(DKEY), "KRIC", len(RKEY))

    # 1) 전국도시철도역사정보표준데이터 (역 번호·노선 번호·운영기관·좌표) — 열쇠 없이 받는 길이 있는지
    code, html = get("https://www.data.go.kr/data/15013205/standard.do", n=400000)
    print("--- 표준데이터 쪽", code, "길이", len(html))
    tables = sorted(set(re.findall(r"tn_pubr_public_[a-z0-9_]+", html)))
    print("    표 이름:", tables)
    cols = re.findall(r'colNmList[^A-Z]{0,40}([A-Z][A-Z0-9_]{2,40})', html)
    print("    칸 이름(앞 60):", cols[:60])
    for m in re.finditer(r"(svcTableNm|publicDataPk|totalCount|atchFileId|fileDetailSn)[\"'\s:=]+[\"']?([A-Za-z0-9_\-]+)", html):
        print("    ", m.group(1), "=", m.group(2))
    svc = [t for t in tables if t.endswith("_svc")]
    for t in svc[:2]:
        q = urllib.parse.urlencode({"publicDataPk": "15013205", "svcTableNm": t, "perPage": 5, "page": 1})
        show(f"표준데이터 내려받기 {t}", get("https://www.data.go.kr/download/standard.json?" + q))
    for t in [x for x in tables if x.endswith("_api")][:2]:
        key = DKEY if "%" in DKEY else urllib.parse.quote(DKEY, safe="")
        show(f"표준데이터 오픈API {t}", get(f"https://api.data.go.kr/openapi/{t}?serviceKey={key}&pageNo=1&numOfRows=3&type=json"))

    # 2) TAGO 지하철정보 — 역 찾기·시간표가 우리 열쇠로 되는지, 권역별로
    key = DKEY if "%" in DKEY else urllib.parse.quote(DKEY, safe="")
    tago = "https://apis.data.go.kr/1613000/SubwayInfoService/"
    ids = {}
    for name in ("강남", "서울역", "인천대입구", "서면", "반월당", "대전역", "금남로4가", "판교", "김포공항"):
        q = urllib.parse.urlencode({"subwayStationName": name, "_type": "json", "numOfRows": 30, "pageNo": 1})
        code, body = get(f"{tago}getKwrdFndSubwaySttnList?serviceKey={key}&{q}")
        print(f"--- TAGO 역 찾기 {name} → {code}")
        try:
            it = (((json.loads(body).get("response") or {}).get("body") or {}).get("items") or {})
            it = it.get("item") if isinstance(it, dict) else []
            it = it if isinstance(it, list) else [it]
            for x in it[:12]:
                print("    ", x.get("subwayStationId"), x.get("subwayStationName"), "|", x.get("subwayRouteName"))
                ids.setdefault(name, x.get("subwayStationId"))
        except Exception:  # noqa: BLE001
            print("    ", body[:300].replace("\n", " "))
    for name, sid in list(ids.items())[:5]:
        q = urllib.parse.urlencode({"subwayStationId": sid, "dailyTypeCode": "01", "upDownTypeCode": "U", "_type": "json", "numOfRows": 5, "pageNo": 1})
        show(f"TAGO 시간표 {name} {sid}", get(f"{tago}getSubwaySttnAcctoSchdulList?serviceKey={key}&{q}"), 700)

    # 3) KRIC 열차별 운행시각표 — 운영기관·호선·역 번호를 어림으로 넣어 어디까지 열리는지
    rk = urllib.parse.quote(RKEY, safe="")
    kric = "https://openapi.kric.go.kr/openapi/"
    for label, opr, ln, stin in (
        ("인천1 인천대입구", "IC", "I1", "136"),
        ("서울2 강남", "S1", "2", "222"),
        ("서울5 광화문", "S5", "5", "533"),
        ("서울5 광화문(S1)", "S1", "5", "533"),
        ("코레일1 서울역", "KR", "1", "133"),
        ("서울1 서울역", "S1", "1", "133"),
        ("9호선 여의도", "S9", "9", "915"),
        ("신분당 판교", "DX", "D1", "D11"),
        ("공항철도 김포공항", "AR", "A1", "A05"),
        ("부산1 서면", "BS", "1", "119"),
        ("대구1 반월당", "DG", "1", "130"),
        ("대전1 대전역", "DJ", "1", "104"),
        ("광주1 금남로4가", "GJ", "1", "105"),
    ):
        q = urllib.parse.urlencode({"format": "json", "railOprIsttCd": opr, "dayCd": "8", "lnCd": ln, "stinCd": stin})
        code, body = get(f"{kric}trainUseInfo/subwayTimetable?serviceKey={rk}&{q}", n=200000)
        rows = 0
        try:
            b = json.loads(body).get("body")
            rows = len(b) if isinstance(b, list) else 0
            sample = b[0] if rows else json.loads(body).get("header")
        except Exception:  # noqa: BLE001
            sample = body[:200]
        print(f"--- KRIC 시각표 {label} ({opr},{ln},{stin}) → {code} · {rows}줄 ·", json.dumps(sample, ensure_ascii=False)[:400])
    # KRIC 다른 자료가 이 열쇠로 열리는지 (역 번호 목록을 얻을 길)
    for path, params in (
        ("trainUseInfo/subwayRouteInfo", {"mreaWideCd": "01", "lnCd": "2"}),
        ("convenientInfo/stationInfo", {"railOprIsttCd": "S1", "lnCd": "2", "stinCd": "222"}),
        ("convenientInfo/stationGateInfo", {"railOprIsttCd": "S1", "lnCd": "2", "stinCd": "222"}),
        ("convenientInfo/stationExitInfo", {"railOprIsttCd": "S1", "lnCd": "2", "stinCd": "222"}),
        ("trainUseInfo/subwayFastTransfer", {"railOprIsttCd": "S1", "lnCd": "2", "stinCd": "222"}),
    ):
        q = urllib.parse.urlencode({**params, "format": "json"})
        show(f"KRIC {path}", get(f"{kric}{path}?serviceKey={rk}&{q}"), 500)
    return 0


if __name__ == "__main__":
    main()
