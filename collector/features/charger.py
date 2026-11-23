"""전기차 충전소 자료 모으기 (충전소 담당 방만 고침).

환경부(한국환경공단) 전기자동차 충전소 정보 API(공공데이터포털 15076352)의 getChargerInfo 로
동네(regions.json)가 속한 시도의 충전기를 모두 받아, 동네 범위(+약 3km)에 드는 충전소만
web/data/charger/<동네id>.json 으로 저장한다.

    EV_KEY / DATA_GO_KR_KEY   공공데이터포털 열쇠 (EV_KEY 가 비면 DATA_GO_KR_KEY)

저장 모양 (용량을 줄이려 짧은 이름):
    s: [{i 충전소ID, n 이름, a 주소, d 상세위치, y, x, b 운영기관, tel 운영기관 전화, t 이용시간,
         p 주차 무료(1/0), l 이용 제한 설명(없으면 ""), k 시설 구분, z 시도코드,
         c: [[충전기ID, 충전기 종류, kW, 상태, 상태 바뀐 시각], …]}]
    live: 충전소ID로 실시간 상태를 받을 수 있는지 (앱이 이 값을 보고 부르는 방식을 고름)

충전기 상태: 1 통신이상 · 2 충전대기(빈 충전기) · 3 충전 중 · 4 운영중지 · 5 점검 중 · 9 상태 미확인
"""
import json
import os
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

KEY = (os.environ.get("EV_KEY") or os.environ.get("DATA_GO_KR_KEY") or "").strip()
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = os.path.join(ROOT, "web", "data")
OUT = os.path.join(DATA, "charger")
KST = timezone(timedelta(hours=9))
BASE = "https://apis.data.go.kr/B552584/EvCharger/getChargerInfo"
MARGIN = 0.03  # 동네 범위 밖으로 약 3km 더

SIDO = {
    "서울": "11", "부산": "26", "대구": "27", "인천": "28", "광주": "29", "대전": "30", "울산": "31",
    "세종": "36", "경기": "41", "강원": "51", "충북": "43", "충남": "44", "전북": "52", "전남": "46",
    "경북": "47", "경남": "48", "제주": "50",
}

KIND = {
    "A0": "공공시설", "B0": "주차시설", "C0": "휴게시설", "D0": "관광시설", "E0": "상업시설",
    "F0": "차량정비시설", "G0": "기타시설", "H0": "공동주택", "I0": "근린생활시설", "J0": "교육문화시설",
}

calls = 0


def key_param():
    # 「인코딩」 열쇠(%가 들어 있음)는 그대로, 「디코딩」 열쇠는 주소용으로 바꿔서
    return KEY if "%" in KEY else urllib.parse.quote(KEY, safe="")


def get(params):
    global calls
    url = f"{BASE}?serviceKey={key_param()}&" + urllib.parse.urlencode({**params, "dataType": "JSON"})
    for tryn in range(4):
        try:
            calls += 1
            with urllib.request.urlopen(url, timeout=60) as r:
                raw = r.read().decode("utf-8", "replace")
            return json.loads(raw)
        except Exception as e:
            if tryn == 3:
                print("  충전소 API 오류:", str(e)[:200])
                return None
            time.sleep(3 * (tryn + 1))


def items(j):
    x = j
    if isinstance(x, dict) and isinstance(x.get("response"), dict):
        x = x["response"].get("body", {})
    if isinstance(x, dict):
        x = x.get("items")
    if isinstance(x, dict):
        x = x.get("item")
    if isinstance(x, list):
        return x
    if isinstance(x, dict):
        return [x]
    return []


def total(j):
    x = j
    if isinstance(x, dict) and isinstance(x.get("response"), dict):
        x = x["response"].get("body", {})
    try:
        return int(x.get("totalCount", 0))
    except Exception:
        return 0


def fetch_sido(zcode):
    rows, page = [], 1
    while True:
        j = get({"pageNo": page, "numOfRows": 9999, "zcode": zcode})
        if j is None:
            break
        got = items(j)
        rows += got
        t = total(j)
        print(f"  시도 {zcode} {page}쪽: {len(got)}줄 (모두 {t})")
        if not got or len(rows) >= t or page >= 40:
            break
        page += 1
        time.sleep(0.5)
    return rows


def num(v):
    try:
        return float(str(v).strip())
    except Exception:
        return None


def to_int(v, default=0):
    try:
        return int(float(str(v).strip()))
    except Exception:
        return default


def stations_from(rows):
    st = {}
    for r in rows:
        if str(r.get("delYn", "N")).upper() == "Y":
            continue
        sid = str(r.get("statId", "")).strip()
        y, x = num(r.get("lat")), num(r.get("lng"))
        if not sid or y is None or x is None or not (33 < y < 39 and 124 < x < 132):
            continue
        s = st.get(sid)
        if s is None:
            limit = ""
            if str(r.get("limitYn", "N")).upper() == "Y":
                limit = (str(r.get("limitDetail") or "").strip() or "이용 제한")
            loc = str(r.get("location") or "").strip()
            s = st[sid] = {
                "i": sid,
                "n": str(r.get("statNm") or "").strip(),
                "a": str(r.get("addr") or "").strip(),
                "d": "" if loc in ("null", "None") else loc,
                "y": round(y, 6),
                "x": round(x, 6),
                "b": str(r.get("busiNm") or r.get("bnm") or "").strip(),
                "tel": str(r.get("busiCall") or "").strip(),
                "t": str(r.get("useTime") or "").strip(),
                "p": 1 if str(r.get("parkingFree", "")).upper() == "Y" else 0,
                "l": limit,
                "k": KIND.get(str(r.get("kind") or "").strip(), ""),
                "z": str(r.get("zcode") or "").strip(),
                "c": [],
            }
        s["c"].append([
            str(r.get("chgerId", "")).strip(),
            str(r.get("chgerType", "")).strip().zfill(2),
            to_int(r.get("output"), 0),
            to_int(r.get("stat"), 9),
            str(r.get("statUpdDt") or "").strip(),
        ])
    for s in st.values():
        s["c"].sort(key=lambda c: c[0])
    return st


def check_live(sample, zcode):
    """충전소ID 하나만 골라 받을 수 있는지 시험 (앱이 실시간 상태를 이렇게 부름)."""
    if not sample:
        return False
    j = get({"pageNo": 1, "numOfRows": 50, "zcode": zcode, "statId": sample})
    got = items(j) if j else []
    ok = bool(got) and all(str(r.get("statId", "")) == sample for r in got)
    print(f"  충전소ID로 받기 시험({sample}): {'됨' if ok else '안 됨'} · {len(got)}줄")
    return ok


def main():
    if not KEY:
        print("충전소 열쇠(EV_KEY·DATA_GO_KR_KEY)가 없어 이번에는 건너뜁니다.")
        return 0
    reg = json.load(open(os.path.join(DATA, "regions.json"), encoding="utf-8"))
    os.makedirs(OUT, exist_ok=True)
    now = datetime.now(KST).strftime("%Y-%m-%d %H:%M")
    for s in reg.get("sido", []):
        zcode = SIDO.get(str(s.get("name", ""))[:2])
        areas = [a for a in s.get("areas", []) if a.get("bbox")]
        if not zcode or not areas:
            continue
        print(f"[{s['name']}] 충전기 받는 중")
        st = stations_from(fetch_sido(zcode))
        if not st:
            print("  받은 충전소가 없어 저장하지 않음")
            continue
        live = check_live(next(iter(st)), zcode)
        for a in areas:
            w, so, e, n = a["bbox"]
            w, so, e, n = w - MARGIN, so - MARGIN, e + MARGIN, n + MARGIN
            mine = [v for v in st.values() if w <= v["x"] <= e and so <= v["y"] <= n]
            if not mine:
                continue
            mine.sort(key=lambda v: v["n"])
            out = {"area_id": a["id"], "updated": now, "live": live, "count": len(mine), "chargers": sum(len(v["c"]) for v in mine), "s": mine}
            with open(os.path.join(OUT, f"{a['id']}.json"), "w", encoding="utf-8") as f:
                json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
            print(f"  {a['name']}: 충전소 {len(mine)}곳 · 충전기 {out['chargers']}대")
    print(f"끝 · 충전소 API 조회 {calls}번")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:  # 다른 기능에 영향 없게
        print("충전소 모으기 실패:", e)
        sys.exit(0)
