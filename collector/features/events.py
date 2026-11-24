"""주변 행사·축제 — 시험 수집 (행사 담당: 본부, 대표님 요청 11-24)

1) 한국관광공사 국문 관광정보(KorService2) 「행사정보 조회」 searchFestival2
2) 전국문화축제표준데이터 (api.data.go.kr/openapi/tn_pubr_public_cltur_fstvl_api)
동네 가운데에서 30km 안, 오늘 이후 끝나는 행사만 저장.

    DATA_GO_KR_KEY   공공데이터포털 인증키 (두 서비스 모두 활용신청 필요)

저장: web/data/events/ev_<동네>.json  {"updated", "ev": [{t, s, e, p, y, x, img, src, id, tel}]}
"""
import json
import math
import os
import time
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

KEY = os.environ.get("DATA_GO_KR_KEY", "").strip()
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = os.path.join(ROOT, "web", "data")
OUT = os.path.join(DATA, "events")
KST = timezone(timedelta(hours=9))


def km(a, b):
    r = 6371.0
    la1, lo1, la2, lo2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))


def get_json(url):
    for tryn in range(3):
        try:
            with urllib.request.urlopen(url, timeout=30) as r:
                t = r.read().decode("utf-8")
            try:
                return json.loads(t)
            except Exception:  # noqa: BLE001
                print("  JSON 아님:", t[:200].replace("\n", " "))
                return None
        except Exception as e:  # noqa: BLE001
            body = ""
            try:
                body = e.read().decode("utf-8", "replace")[:200]  # type: ignore[attr-defined]
            except Exception:  # noqa: BLE001
                pass
            if body or tryn == 2:
                print("  오류:", str(e)[:100], body.replace("\n", " "))
                return None
            time.sleep(2)


def items_of(j):
    body = ((j or {}).get("response") or {}).get("body") or {}
    it = body.get("items") or {}
    if isinstance(it, dict):
        it = it.get("item") or []
    return it if isinstance(it, list) else [it]


def ymd(s):
    s = "".join(ch for ch in str(s or "") if ch.isdigit())
    return s[:8] if len(s) >= 8 else ""


def main():
    if not KEY:
        print("DATA_GO_KR_KEY 가 없어 행사를 모으지 않습니다")
        return 0
    key = KEY if "%" in KEY else urllib.parse.quote(KEY, safe="")
    os.makedirs(OUT, exist_ok=True)
    today = datetime.now(KST).strftime("%Y%m%d")
    stamp = datetime.now(KST).strftime("%Y-%m-%d %H:%M")
    # 1) 관광공사 행사 (전국, 오늘 이후 시작·진행 중)
    tour = []
    for page in range(1, 6):
        q = urllib.parse.urlencode({"MobileOS": "AND", "MobileApp": "uridongne", "_type": "json", "numOfRows": 500, "pageNo": page, "eventStartDate": (datetime.now(KST) - timedelta(days=60)).strftime("%Y%m%d"), "arrange": "A"})
        j = get_json(f"https://apis.data.go.kr/B551011/KorService2/searchFestival2?serviceKey={key}&{q}")
        its = items_of(j)
        tour += its
        if len(its) < 500:
            break
    print(f"관광공사 행사 {len(tour)}건")
    # 2) 전국문화축제표준데이터
    std = []
    for page in range(1, 6):
        q = urllib.parse.urlencode({"type": "json", "numOfRows": 1000, "pageNo": page})
        j = get_json(f"https://api.data.go.kr/openapi/tn_pubr_public_cltur_fstvl_api?serviceKey={key}&{q}")
        its = items_of(j)
        std += its
        if len(its) < 1000:
            break
    print(f"문화축제 표준데이터 {len(std)}건")
    reg = json.load(open(os.path.join(DATA, "regions.json"), encoding="utf-8"))
    for s in reg["sido"]:
        for a in s["areas"]:
            if not a.get("bbox") or not a.get("ready"):
                continue
            x1, y1, x2, y2 = a["bbox"]
            mid = ((y1 + y2) / 2, (x1 + x2) / 2)
            ev, seen = [], set()
            for it in tour:
                try:
                    p = (float(it.get("mapy")), float(it.get("mapx")))
                except Exception:  # noqa: BLE001
                    continue
                e = ymd(it.get("eventenddate"))
                if not e or e < today or km(mid, p) > 30:
                    continue
                t = (it.get("title") or "").strip()
                k = (t.replace(" ", ""), ymd(it.get("eventstartdate")))
                if k in seen:
                    continue
                seen.add(k)
                ev.append({"t": t, "s": ymd(it.get("eventstartdate")), "e": e, "p": (it.get("addr1") or "").strip(), "y": round(p[0], 6), "x": round(p[1], 6),
                           "img": it.get("firstimage") or "", "tel": it.get("tel") or "", "id": str(it.get("contentid") or ""), "src": "한국관광공사"})
            for it in std:
                try:
                    p = (float(it.get("latitude")), float(it.get("longitude")))
                except Exception:  # noqa: BLE001
                    continue
                e = ymd(it.get("fstvlEndDate"))
                if not e or e < today or km(mid, p) > 30:
                    continue
                t = (it.get("fstvlNm") or "").strip()
                k = (t.replace(" ", ""), ymd(it.get("fstvlStartDate")))
                if k in seen:
                    continue
                seen.add(k)
                ev.append({"t": t, "s": ymd(it.get("fstvlStartDate")), "e": e, "p": (it.get("opar") or it.get("rdnmadr") or "").strip(), "y": round(p[0], 6), "x": round(p[1], 6),
                           "img": "", "tel": it.get("phoneNumber") or "", "id": "", "src": it.get("institutionNm") or "전국문화축제표준데이터", "info": (it.get("fstvlCo") or "")[:200]})
            ev.sort(key=lambda z: (z["s"], z["t"]))
            print(f"[{s['name']} {a['name']}] 30km 안 진행·예정 행사 {len(ev)}건")
            with open(os.path.join(OUT, f"ev_{a['id']}.json"), "w", encoding="utf-8") as f:
                json.dump({"area_id": a["id"], "updated": stamp, "ev": ev}, f, ensure_ascii=False, separators=(",", ":"))
    return 0


if __name__ == "__main__":
    main()
