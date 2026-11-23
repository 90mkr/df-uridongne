"""주차장 자료 모으기 (주차장 담당 방만 고침).

공공데이터포털 「전국주차장정보표준데이터」(tn_pubr_prkplce_info_api)를 전부 받아
가로세로 0.1도(약 10km) 칸으로 나눠 web/data/parking/t/<칸>.json 에 저장한다.
앱은 고른 단지가 있는 칸과 이웃 칸만 받는다 → 아직 모으기 전인 동네도 전국 어디서나 바로 보임.

    DATA_GO_KR_KEY   공공데이터포털 열쇠 (깃허브 비밀)

표준데이터는 반기마다 바뀌므로, 지난번에 받은 지 20일이 안 됐으면 건너뛴다 (PARKING_FORCE=1 이면 무조건 받음).
실패하면 지난 자료를 그대로 둔다.
"""
import json
import math
import os
import shutil
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

KEY = os.environ.get("DATA_GO_KR_KEY", "").strip()
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "web", "data", "parking")
KST = timezone(timedelta(hours=9))
URL = "https://api.data.go.kr/openapi/tn_pubr_prkplce_info_api"
ROWS = 1000
TILE = 10  # 1도를 몇 칸으로 (10 → 0.1도)


def call(page):
    q = urllib.parse.urlencode({"pageNo": page, "numOfRows": ROWS, "type": "json"})
    # 열쇠는 이미 인코딩된 값일 수도, 아닐 수도 있어 둘 다 시도
    keys = [KEY] if "%" in KEY else [urllib.parse.quote(KEY, safe=""), KEY]
    last = None
    for k in keys:
        for tryn in range(3):
            try:
                req = urllib.request.Request(f"{URL}?serviceKey={k}&{q}", headers={"User-Agent": "df-uridongne"})
                with urllib.request.urlopen(req, timeout=40) as r:
                    txt = r.read().decode("utf-8", "replace")
                if txt.lstrip().startswith("<"):
                    last = "XML 응답: " + txt[:200].replace("\n", " ")
                    break  # 열쇠 문제 → 다른 열쇠 모양으로
                j = json.loads(txt)
                body = j.get("response", {}).get("body", {})
                head = j.get("response", {}).get("header", {})
                if str(head.get("resultCode", "00")) not in ("00", "0", "03"):
                    last = f"결과 코드 {head.get('resultCode')} {head.get('resultMsg')}"
                    break
                items = body.get("items") or []
                if isinstance(items, dict):
                    items = items.get("item") or []
                if isinstance(items, dict):
                    items = [items]
                return items, int(body.get("totalCount") or 0)
            except Exception as e:  # 잠깐 막히면 쉬었다 다시
                last = str(e)
                time.sleep(2 * (tryn + 1))
    raise RuntimeError(last or "알 수 없는 오류")


def num(v):
    try:
        s = str(v).replace(",", "").strip()
        return int(float(s)) if s else 0
    except Exception:
        return 0


def hhmm(v):
    s = str(v or "").strip().replace(":", "")
    if not s.isdigit():
        return ""
    s = s.zfill(4)[:4]
    return f"{s[:2]}:{s[2:]}"


def clean(v):
    s = str(v or "").strip()
    return "" if s in ("-", "없음", "해당없음", "null", "None") else s


def pick(x):
    try:
        lat, lng = float(x.get("latitude") or 0), float(x.get("longitude") or 0)
    except Exception:
        return None
    if 120 < lat < 135 and 30 < lng < 45:  # 위도·경도가 뒤바뀐 곳
        lat, lng = lng, lat
    if not (33 < lat < 39 and 124 < lng < 132):
        return None
    name = str(x.get("prkplceNm") or "").strip()
    if not name:
        return None
    o = {
        "id": str(x.get("prkplceNo") or "").strip() or f"{lat:.5f},{lng:.5f}",
        "n": name,
        "k": str(x.get("prkplceSe") or "").strip(),  # 공영·민영
        "ty": str(x.get("prkplceType") or "").strip(),  # 노상·노외·부설
        "a": str(x.get("rdnmadr") or "").strip() or str(x.get("lnmadr") or "").strip(),
        "c": num(x.get("prkcmprt")),
        "d": str(x.get("operDay") or "").strip(),
        "h": [hhmm(x.get(k)) for k in (
            "weekdayOperOpenHhmm", "weekdayOperColseHhmm",
            "satOperOperOpenHhmm", "satOperCloseHhmm",
            "holidayOperOpenHhmm", "holidayCloseOpenHhmm")],
        "f": str(x.get("parkingchrgeInfo") or "").strip(),  # 유료·무료·혼합
        "bt": num(x.get("basicTime")), "bc": num(x.get("basicCharge")),
        "at": num(x.get("addUnitTime")), "ac": num(x.get("addUnitCharge")),
        "dt": num(x.get("dayCmmtktAdjTime")), "dc": num(x.get("dayCmmtkt")),
        "mc": num(x.get("monthCmmtkt")),
        "pay": clean(x.get("metpay")),
        "sp": clean(x.get("spcmnt")),
        "org": str(x.get("institutionNm") or "").strip(),
        "tel": clean(x.get("phoneNumber")),
        "dis": 1 if str(x.get("pwdbsPpkZoneYn") or "").upper().startswith("Y") else 0,
        "ref": str(x.get("referenceDate") or "").strip(),
        "y": round(lat, 6), "x": round(lng, 6),
    }
    # 빈 칸은 빼서 파일을 가볍게
    return {k: v for k, v in o.items() if v not in ("", 0, None) or k in ("y", "x", "n", "id")}


def main():
    if not KEY:
        print("주차장: DATA_GO_KR_KEY 가 없어 건너뜀")
        return
    meta_p = os.path.join(OUT, "meta.json")
    if os.path.exists(meta_p) and os.environ.get("PARKING_FORCE") != "1":
        try:
            m = json.load(open(meta_p, encoding="utf-8"))
            last = datetime.fromisoformat(m["updated"])
            if datetime.now(KST) - last < timedelta(days=20):
                print(f"주차장: {m['updated'][:10]}에 받은 자료가 있어 건너뜀 ({m.get('count')}곳)")
                return
        except Exception:
            pass

    seen, tiles = {}, {}
    first, total = call(1)
    pages = max(1, math.ceil(total / ROWS))
    print(f"주차장: 전국 {total}곳, {pages}쪽")
    rows = list(first)
    for p in range(2, pages + 1):
        try:
            items, _ = call(p)
        except Exception as e:
            print(f"  {p}쪽 실패: {e}")
            continue
        rows += items
        if p % 10 == 0:
            print(f"  {p}/{pages}쪽")
        time.sleep(0.2)

    for x in rows:
        o = pick(x)
        if not o:
            continue
        key = o["id"] if not o["id"].startswith("-") else f"{o['n']}{o['y']}"
        if key in seen:
            continue
        seen[key] = 1
        t = f"{math.floor(o['y'] * TILE)}_{math.floor(o['x'] * TILE)}"
        tiles.setdefault(t, []).append(o)

    count = sum(len(v) for v in tiles.values())
    if count < max(1000, total * 0.5):  # 너무 적게 받았으면 지난 자료를 지킴
        print(f"주차장: {count}곳만 받아져 저장하지 않음")
        return

    tmp = os.path.join(OUT, "_t")
    shutil.rmtree(tmp, ignore_errors=True)
    os.makedirs(tmp)
    for t, v in tiles.items():
        v.sort(key=lambda o: (o["y"], o["x"]))
        with open(os.path.join(tmp, f"{t}.json"), "w", encoding="utf-8") as f:
            json.dump({"t": t, "p": v}, f, ensure_ascii=False, separators=(",", ":"))
    final = os.path.join(OUT, "t")
    shutil.rmtree(final, ignore_errors=True)
    os.replace(tmp, final)
    kinds = {}
    for v in tiles.values():
        for o in v:
            kinds[o.get("k", "")] = kinds.get(o.get("k", ""), 0) + 1
    with open(meta_p, "w", encoding="utf-8") as f:
        json.dump({"updated": datetime.now(KST).isoformat(timespec="minutes"), "count": count, "tiles": len(tiles),
                   "tile": TILE, "kinds": kinds, "source": "공공데이터포털 전국주차장정보표준데이터"}, f, ensure_ascii=False, indent=1)
    print(f"주차장: {count}곳 · 칸 {len(tiles)}개 저장 ({kinds})")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print("주차장 자료 모으기 실패:", e)
        sys.exit(0)
