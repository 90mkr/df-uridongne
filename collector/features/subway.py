"""지하철 — 동네 지하철역과 역별 시간표 미리 모으기 (지하철 담당: 본부, 대표님 요청 11-24)

1) 카카오 분류 SW8(지하철역)로 동네 안 역 위치를 모은다 (동네마다 몇십 곳뿐, 주 1회).
2) 국토교통부 TAGO 「지하철정보」로 역마다 평일·토·휴일 × 상·하행 시간표를 모은다.
   인천1·2호선은 실시간 도착 자료가 공개되지 않아 시간표 기준으로 보여 준다.

    KAKAO_REST_KEY   카카오 REST 키
    DATA_GO_KR_KEY   공공데이터포털 인증키 (TAGO 지하철정보 활용신청 필요)
    KRIC_KEY         철도산업정보센터(레일포털) 서비스키 — 「열차별 운행시각표」 trainUseInfo/subwayTimetable (11-25 발급)

3) TAGO 에 시간표가 없는 역(인천1·2호선 등)은 KRIC 「열차별 운행시각표」로 채운다.
   KRIC 응답엔 방향·종착이 없어서, 노선 순서(도시철도 전체노선정보)로 옆 역 시각과 견줘
   같은 열차번호가 다음 역에 더 늦게 오면 「번호 큰 쪽 끝역 방면」으로 나눈다.

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
RKEY = os.environ.get("KRIC_KEY", "").strip()
KRIC = "https://openapi.kric.go.kr/openapi/"

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
            body = ""
            try:
                body = e.read().decode("utf-8", "replace")[:300]  # type: ignore[attr-defined]
            except Exception:  # noqa: BLE001
                pass
            if body or tryn == 2:
                print("  부르기 오류:", str(e)[:120], body.replace("\n", " "))
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


# ---------------- KRIC (레일포털) ----------------
def kric(path, params):
    q = urllib.parse.urlencode({**params, "format": "json"})
    key = urllib.parse.quote(RKEY, safe="")
    t = get(f"{KRIC}{path}?serviceKey={key}&{q}")
    try:
        j = json.loads(t)
    except Exception:  # noqa: BLE001
        print("  KRIC 응답이 JSON 이 아님:", t[:200].replace("\n", " "))
        return None
    hdr = j.get("header") or {}
    code = str(hdr.get("resultCode", "00"))
    if code not in ("00", "03"):
        print("  KRIC 오류:", code, str(hdr.get("resultMsg", ""))[:120])
        return None
    b = j.get("body")
    if not b and os.environ.get("KRIC_DEBUG"):
        print("   (빈 응답)", t[:200].replace("\n", " "))
    if isinstance(b, dict):
        b = b.get("item") or b.get("items") or []
    return b if isinstance(b, list) else ([b] if b else [])


def norm(n):
    n = re.sub(r"\(.*?\)|\s", "", str(n or ""))
    return n[:-1] if n.endswith("역") and len(n) > 2 else n


# 역 순서·역 번호 (KRIC 「도시철도 전체노선정보」는 이 키로 안 열려서 직접 적어 둠 — 공식 역 번호)
I1 = ["계양", "귤현", "박촌", "임학", "계산", "경인교대입구", "작전", "갈산", "부평구청", "부평시장", "부평", "동수", "부평삼거리", "간석오거리",
      "인천시청", "예술회관", "인천터미널", "문학경기장", "선학", "신연수", "원인재", "동춘", "동막", "캠퍼스타운", "테크노파크", "지식정보단지",
      "인천대입구", "센트럴파크", "국제업무지구", "송도달빛축제공원"]
# 수인분당선 인천 쪽 (오이도 K258 ~ 인천) — 역 번호는 K+숫자, 호선 K1 (11-25 시험: K258 오이도 177줄)
SU = ["오이도", "달월", "월곶", "소래포구", "인천논현", "호구포", "남동인더스파크", "원인재", "연수", "송도", "인하대", "숭의", "신포", "인천"]
ROUTES = {
    "인천1호선": ("IC", "I1", [(str(110 + k), n) for k, n in enumerate(I1)], "계양", "송도달빛축제공원"),  # 역 번호는 숫자만 (인천대입구 = 136)
    "수인분당선": ("KR", "K1", [(f"K{258 + k}", n) for k, n in enumerate(SU)], "왕십리", "인천"),
}


def route_stations(line):
    opr, ln, lst, _, _ = ROUTES[line]
    return opr, ln, [(k, code, n) for k, (code, n) in enumerate(lst)]


def times(opr, ln, stin, day, dep_only=False):
    """{열차번호: hhmm} — dep_only: 이 역에서 떠나는 열차만 (끝역에 들어와 끝나는 열차 빼기)"""
    rows = kric("trainUseInfo/subwayTimetable", {"railOprIsttCd": opr, "dayCd": day, "lnCd": ln, "stinCd": stin}) or []
    out = {}
    for r in rows:
        if dep_only and not hhmm(r.get("dptTm")):
            continue
        t = hhmm(r.get("dptTm")) or hhmm(r.get("arvTm"))
        if t and t != "0000":
            if int(t[:2]) < 3:  # 자정 넘은 막차 00:01 → 24:01 (하루 끝에 오도록)
                t = f"{int(t[:2]) + 24}{t[2:]}"
            out[str(r.get("trnNo", ""))] = t
    return out


def near_times(opr, ln, route, i, step, code):
    """i 에서 step(+1/-1) 쪽으로 가며 시간표가 있는 첫 역 (번호가 비어 있는 역 건너뜀 — 예: 수인분당 K268)"""
    k = i + step
    while 0 <= k < len(route) and abs(k - i) <= 3:
        t = times(opr, ln, route[k][1], code)
        if t:
            return t
        k += step
    return {}


def fill_kric(st):
    if not RKEY:
        print("  KRIC_KEY 가 없어 KRIC 시간표는 건너뜀")
        return
    want = [x for x in st if not x.get("tt") and x.get("l") in ROUTES]
    skipped = sorted({x.get("l") for x in st if not x.get("tt") and x.get("l") not in ROUTES})
    if skipped:
        print("  KRIC 역 번호가 아직 없는 호선:", skipped)
    ok = 0
    for line in sorted({x["l"] for x in want}):
        opr, ln, route = route_stations(line)
        first, last = ROUTES[line][3], ROUTES[line][4]  # 방면 이름 (번호 작은 쪽 / 큰 쪽 끝)
        idx = {r[2]: i for i, r in enumerate(route)}
        for x in want:
            if x["l"] != line:
                continue
            i = idx.get(norm(x["n"]))
            if i is None:
                print(f"  {x['n']}: 노선 목록에 이름이 없음")
                continue
            tt = {}
            for day, code in (("01", "8"), ("02", "7"), ("03", "9")):
                here = times(opr, ln, route[i][1], code, dep_only=True)
                if not here:
                    continue
                nxt = near_times(opr, ln, route, i, 1, code)
                prv = near_times(opr, ln, route, i, -1, code)
                up, down = [], []
                for no, t in here.items():
                    # 같은 열차가 다음(번호 큰) 역에 더 늦게 오면 → 끝역 쪽(D), 앞(번호 작은) 역에 더 늦게 오면 → 첫역 쪽(U)
                    if no in nxt and nxt[no] >= t:
                        down.append([t, last])
                    elif no in prv and prv[no] >= t:
                        up.append([t, first])
                    elif i == len(route) - 1:
                        up.append([t, first])
                    elif i == 0:
                        down.append([t, last])
                if up:
                    tt[day + "U"] = sorted(up)
                if down:
                    tt[day + "D"] = sorted(down)
            # KRIC 은 토요일(7) 시간표를 안 줌 → 휴일 시간표를 토요일로 (주말 운행이 같은 노선이 대부분)
            for ud in ("U", "D"):
                if "02" + ud not in tt and "03" + ud in tt:
                    tt["02" + ud] = tt["03" + ud]
            if tt:
                x["tt"] = tt
                x["src"] = "kric"
                ok += 1
    print(f"  KRIC 시간표 받은 역 {ok}곳")


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
            path = os.path.join(OUT, f"st_{a['id']}.json")
            if not st:
                # 카카오가 잠깐 안 되면 빈 목록으로 덮지 않음 (11-25 사고)
                print("  역을 하나도 못 받아 예전 파일을 그대로 둠")
                continue
            if DKEY:
                ok = 0
                fails = 0
                for x in st:
                    if fails >= 3:
                        print("  TAGO 지하철정보가 계속 실패해 멈춤")
                        break
                    found = tago("getKwrdFndSubwaySttnList", {"subwayStationName": x["n"]})
                    if found is None:
                        fails += 1
                        continue
                    fails = 0
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
            fill_kric(st)
            with open(path, "w", encoding="utf-8") as f:
                json.dump({"area_id": a["id"], "updated": now, "st": st}, f, ensure_ascii=False, separators=(",", ":"))
    print(f"끝 · 부른 횟수 {calls}번")
    return 0


if __name__ == "__main__":
    main()
