"""지하철 — 동네 지하철역과 역별 시간표 미리 모으기 (지하철 담당: 본부, 대표님 요청 11-24)

1) 카카오 분류 SW8(지하철역)로 동네 안 역 위치를 모은다 (동네마다 몇십 곳뿐, 주 1회).
2) 국토교통부 TAGO 「지하철정보」로 역마다 평일·토·휴일 × 상·하행 시간표를 모은다.
   인천1·2호선은 실시간 도착 자료가 공개되지 않아 시간표 기준으로 보여 준다.

    KAKAO_REST_KEY   카카오 REST 키
    DATA_GO_KR_KEY   공공데이터포털 인증키 (TAGO 지하철정보 활용신청 필요)

저장 파일
    web/data/subway/st_<동네>.json   {"updated", "st": [{n, l, y, x, id, tt: {"01U": [[hhmm, 종착], …], …}}]}
"""
import glob
import json
import os
import re
import time
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

KKEY = os.environ.get("KAKAO_REST_KEY", "").strip()
DKEY = os.environ.get("DATA_GO_KR_KEY", "").strip()
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = os.path.join(ROOT, "web", "data")
OUT = os.path.join(DATA, "subway")
KST = timezone(timedelta(hours=9))
TAGO = "https://apis.data.go.kr/1613000/SubwayInfoService/"

calls = 0


def get(url, headers=None):
    global calls
    for tryn in range(3):
        try:
            calls += 1
            req = urllib.request.Request(url, headers=headers or {})
            with urllib.request.urlopen(req, timeout=20) as r:
                return r.read().decode("utf-8")
        except Exception as e:  # noqa: BLE001
            if tryn == 2:
                print("  부르기 오류:", str(e)[:120])
                return ""
            time.sleep(1.5 * (tryn + 1))


def kakao_sw8(rect, depth=0):
    docs, total = [], 0
    for page in (1, 2, 3):
        q = urllib.parse.urlencode({"category_group_code": "SW8", "rect": ",".join(f"{x:.6f}" for x in rect), "page": page, "size": 15})
        t = get("https://dapi.kakao.com/v2/local/search/category.json?" + q, {"Authorization": f"KakaoAK {KKEY}"})
        try:
            j = json.loads(t)
        except Exception:  # noqa: BLE001
            break
        docs += j.get("documents", [])
        total = j.get("meta", {}).get("total_count", 0)
        if j.get("meta", {}).get("is_end", True):
            break
    if total > 45 and depth < 3:
        x1, y1, x2, y2 = rect
        mx, my = (x1 + x2) / 2, (y1 + y2) / 2
        out = []
        for r in ((x1, y1, mx, my), (mx, y1, x2, my), (x1, my, mx, y2), (mx, my, x2, y2)):
            out += kakao_sw8(r, depth + 1)
        return out
    return docs


def tago(op, params):
    q = urllib.parse.urlencode({**params, "_type": "json", "numOfRows": params.get("numOfRows", 500), "pageNo": 1})
    key = DKEY if "%" in DKEY else urllib.parse.quote(DKEY, safe="")
    t = get(f"{TAGO}{op}?serviceKey={key}&{q}")
    try:
        j = json.loads(t)
    except Exception:  # noqa: BLE001
        print("  TAGO 응답이 JSON 이 아님:", t[:200].replace("\n", " "))
        return None
    body = (j.get("response") or {}).get("body") or {}
    items = (body.get("items") or {})
    if not items:
        return []
    it = items.get("item") or []
    return it if isinstance(it, list) else [it]


def short(name):
    # 카카오 「센트럴파크역 인천1호선」 → 「센트럴파크」
    n = name.split(" ")[0]
    return n[:-1] if n.endswith("역") and len(n) > 2 else n


def line_of(d):
    cn = d.get("category_name", "")
    last = cn.split(">")[-1].strip() if cn else ""
    w = d.get("place_name", "").split(" ")
    return (w[1] if len(w) > 1 else last).strip()


def hhmm(s):
    s = re.sub(r"\D", "", str(s or ""))
    return s[:4] if len(s) >= 4 else ""


def main():
    if not KKEY:
        print("카카오 키가 없어 지하철역을 모으지 않습니다")
        return 0
    want = set(filter(None, os.environ.get("AREAS", "").replace(" ", "").split(",")))
    want.discard("subway")
    os.makedirs(OUT, exist_ok=True)
    reg = json.load(open(os.path.join(DATA, "regions.json"), encoding="utf-8"))
    now = datetime.now(KST).strftime("%Y-%m-%d %H:%M")
    for s in reg["sido"]:
        for a in s["areas"]:
            if not a.get("bbox") or not a.get("ready"):
                continue
            if want and a["id"] not in want:
                continue
            print(f"[{s['name']} {a['name']}] 지하철역")
            seen, st = set(), []
            for d in kakao_sw8(a["bbox"]):
                key = (short(d.get("place_name", "")), line_of(d))
                if key in seen:
                    continue
                seen.add(key)
                try:
                    st.append({"n": key[0], "l": key[1], "y": round(float(d["y"]), 6), "x": round(float(d["x"]), 6)})
                except Exception:  # noqa: BLE001
                    continue
            print(f"  역 {len(st)}곳 (호선별)")
            if DKEY:
                ok = 0
                for x in st:
                    found = tago("getKwrdFndSubwaySttnList", {"subwayStationName": x["n"]}) or []
                    # 호선 이름이 맞는 역 고르기 (예: 「인천1호선」 ↔ 「인천지하철 1호선」)
                    digits = re.sub(r"\D", "", x["l"])
                    city = "인천" if "인천" in x["l"] else ("" if not x["l"] else x["l"][:2])
                    best = None
                    for f in found:
                        rn = str(f.get("subwayRouteName", ""))
                        if (not digits or digits in rn) and (not city or city in rn or city in str(f.get("subwayStationId", ""))):
                            best = f
                            break
                    if best is None and len(found) == 1:
                        best = found[0]
                    if best is None:
                        if found:
                            print(f"  {x['n']} {x['l']}: 맞는 호선 없음 →", [f.get('subwayRouteName') for f in found][:4])
                        continue
                    x["id"] = str(best.get("subwayStationId", ""))
                    tt = {}
                    for day in ("01", "02", "03"):
                        for ud in ("U", "D"):
                            rows = tago("getSubwaySttnAcctoSchdulList", {"subwayStationId": x["id"], "dailyTypeCode": day, "upDownTypeCode": ud}) or []
                            lst = []
                            for r in rows:
                                t = hhmm(r.get("depTime")) or hhmm(r.get("arrTime"))
                                if t and t != "0000":
                                    lst.append([t, str(r.get("endSubwayStationNm", "")).strip()])
                            lst.sort()
                            if lst:
                                tt[day + ud] = lst
                    if tt:
                        x["tt"] = tt
                        ok += 1
                print(f"  시간표 받은 역 {ok}곳")
            else:
                print("  DATA_GO_KR_KEY 가 없어 시간표는 건너뜀")
            with open(os.path.join(OUT, f"st_{a['id']}.json"), "w", encoding="utf-8") as f:
                json.dump({"area_id": a["id"], "updated": now, "st": st}, f, ensure_ascii=False, separators=(",", ":"))
    print(f"끝 · 부른 횟수 {calls}번")
    return 0


if __name__ == "__main__":
    main()
