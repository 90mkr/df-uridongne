"""학교 급식·학사일정 — 동네 초·중·고 위치 + 급식(앞으로 2주) + 학사일정(앞으로 두 달) 모으기
(학교 담당: 본부, 대표님 요청 11-24)

1) 카카오 분류 SC4(학교)로 동네 안 초·중·고 위치를 모은다.
2) 교육청 나이스 공개 자료(open.neis.go.kr)로 학교 코드 → 급식 식단 · 학사일정을 받는다.
   NEIS_KEY 가 있으면 쓰고, 없으면 견본 호출(한 번에 5건)로 하루·한 주씩 나눠 받는다.

    KAKAO_REST_KEY   카카오 REST 키
    NEIS_KEY         나이스 공개 자료 인증키 (선택)

저장 파일
    web/data/school/sc_<동네>.json
      {"updated", "sc": [{n, k, y, x, a, c, meal: {"YYYYMMDD": {"m": [반찬…], "cal": "…"}}, ev: [["YYYYMMDD", "행사"], …]}]}
"""
import json
import os
import re
import time
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

KKEY = os.environ.get("KAKAO_REST_KEY", "").strip()
NKEY = os.environ.get("NEIS_KEY", "").strip()
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = os.path.join(ROOT, "web", "data")
OUT = os.path.join(DATA, "school")
KST = timezone(timedelta(hours=9))
NEIS = "https://open.neis.go.kr/hub/"
PSIZE = 100 if NKEY else 5

calls = 0


def get(url, headers=None):
    global calls
    for tryn in range(3):
        try:
            calls += 1
            with urllib.request.urlopen(urllib.request.Request(url, headers=headers or {}), timeout=20) as r:
                return r.read().decode("utf-8")
        except Exception as e:  # noqa: BLE001
            if tryn == 2:
                print("  부르기 오류:", str(e)[:160])
                return ""
            time.sleep(1.5 * (tryn + 1))


def kakao_sc4(rect, depth=0):
    docs, total = [], 0
    for page in (1, 2, 3):
        q = urllib.parse.urlencode({"category_group_code": "SC4", "rect": ",".join(f"{x:.6f}" for x in rect), "page": page, "size": 15})
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
            out += kakao_sc4(r, depth + 1)
        return out
    return docs


def neis(op, params):
    """나이스 한 번 부르기 → 행 목록 (없으면 [])"""
    q = {"Type": "json", "pIndex": 1, "pSize": PSIZE, **params}
    if NKEY:
        q["KEY"] = NKEY
    t = get(NEIS + op + "?" + urllib.parse.urlencode(q))
    try:
        j = json.loads(t)
    except Exception:  # noqa: BLE001
        return []
    blk = j.get(op)
    if not blk:
        res = j.get("RESULT", {})
        if res and res.get("CODE") not in ("INFO-200",):
            print(f"  나이스 {op}: {res.get('CODE')} {res.get('MESSAGE', '')[:80]}")
        return []
    rows = []
    for part in blk:
        if "row" in part:
            rows += part["row"]
    return rows


KIND = (("초등학교", "초"), ("중학교", "중"), ("고등학교", "고"))


def kind_of(name):
    for suf, k in KIND:
        if name.endswith(suf):
            return k
    return ""


def clean_dish(s):
    # 「돼지불고기(5.6.10.13.)」 → 「돼지불고기」
    s = re.sub(r"\([0-9.\s]*\)", "", s)
    s = re.sub(r"[*#@]", "", s)
    return s.strip()


def main():
    if not KKEY:
        print("카카오 키가 없어 학교를 모으지 않습니다")
        return 0
    os.makedirs(OUT, exist_ok=True)
    want = set(filter(None, os.environ.get("AREAS", "").replace(" ", "").split(",")))
    want.discard("school")
    reg = json.load(open(os.path.join(DATA, "regions.json"), encoding="utf-8"))
    now = datetime.now(KST)
    stamp = now.strftime("%Y-%m-%d %H:%M")
    print("나이스 키:", "있음" if NKEY else "없음 (견본 호출 5건씩)")
    for s in reg["sido"]:
        for a in s["areas"]:
            if not a.get("bbox") or not a.get("ready"):
                continue
            if want and a["id"] not in want:
                continue
            print(f"[{s['name']} {a['name']}] 학교")
            seen, sc = set(), []
            for d in kakao_sc4(a["bbox"]):
                n = d.get("place_name", "").split(" ")[0].strip()
                k = kind_of(n)
                if not k or n in seen:
                    continue
                seen.add(n)
                try:
                    sc.append({"n": n, "k": k, "y": round(float(d["y"]), 6), "x": round(float(d["x"]), 6), "addr": d.get("road_address_name") or d.get("address_name", "")})
                except Exception:  # noqa: BLE001
                    continue
            print(f"  초·중·고 {len(sc)}곳")
            city = (s.get("name") or "")[:2]
            got_meal = got_ev = 0
            for x in sc:
                rows = neis("schoolInfo", {"SCHUL_NM": x["n"]})
                pick = None
                for r in rows:
                    if r.get("SCHUL_NM") == x["n"] and (not city or city in (r.get("LCTN_SC_NM", "") + r.get("ORG_RDNMA", ""))):
                        pick = r
                        break
                if pick is None and len(rows) == 1:
                    pick = rows[0]
                if pick is None:
                    continue
                x["a"], x["c"] = pick.get("ATPT_OFCDC_SC_CODE", ""), pick.get("SD_SCHUL_CODE", "")
                base = {"ATPT_OFCDC_SC_CODE": x["a"], "SD_SCHUL_CODE": x["c"]}
                # 급식: 앞으로 14일 (주말 빼고), 견본 호출이면 하루씩
                meal = {}
                days = [now + timedelta(days=i) for i in range(15)]
                days = [d for d in days if d.weekday() < 5]
                if NKEY:
                    rows = neis("mealServiceDietInfo", {**base, "MLSV_FROM_YMD": days[0].strftime("%Y%m%d"), "MLSV_TO_YMD": days[-1].strftime("%Y%m%d")})
                else:
                    rows = []
                    for d in days:
                        rows += neis("mealServiceDietInfo", {**base, "MLSV_YMD": d.strftime("%Y%m%d")})
                        time.sleep(0.05)
                for r in rows:
                    if "중식" not in r.get("MMEAL_SC_NM", "중식"):
                        continue
                    dishes = [clean_dish(t) for t in re.split(r"<br\s*/?>", r.get("DDISH_NM", "")) if clean_dish(t)]
                    if dishes:
                        meal[r.get("MLSV_YMD", "")] = {"m": dishes, "cal": (r.get("CAL_INFO") or "").strip()}
                if meal:
                    x["meal"] = meal
                    got_meal += 1
                # 학사일정: 앞으로 60일, 견본 호출이면 한 주씩
                ev = []
                spans = [(now, now + timedelta(days=60))] if NKEY else [(now + timedelta(days=i), now + timedelta(days=i + 6)) for i in range(0, 60, 7)]
                for f, t in spans:
                    for r in neis("SchoolSchedule", {**base, "AA_FROM_YMD": f.strftime("%Y%m%d"), "AA_TO_YMD": t.strftime("%Y%m%d")}):
                        name = (r.get("EVENT_NM") or "").strip()
                        if not name or name == "토요휴업일":
                            continue
                        ev.append([r.get("AA_YMD", ""), name])
                    time.sleep(0.05)
                if ev:
                    x["ev"] = sorted({tuple(e) for e in ev})
                    got_ev += 1
            print(f"  급식 받은 학교 {got_meal}곳 · 학사일정 받은 학교 {got_ev}곳")
            for x in sc:
                x.pop("addr", None)
                if "ev" in x:
                    x["ev"] = [list(e) for e in x["ev"]]
            with open(os.path.join(OUT, f"sc_{a['id']}.json"), "w", encoding="utf-8") as f:
                json.dump({"area_id": a["id"], "updated": stamp, "sc": sc}, f, ensure_ascii=False, separators=(",", ":"))
    print(f"끝 · 부른 횟수 {calls}번")
    return 0


if __name__ == "__main__":
    main()
