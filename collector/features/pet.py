"""우리 동네 반려동물 — 「같이 갈 수 있는 곳」 모으기 (반려동물 테마 방)

한국관광공사 반려동물 동반여행 서비스 (KorPetTourService2, 공공데이터포털 15135102 · 활용신청 필요, 자동 승인)
 - 전국 목록(지역기반)을 한 번에 받아 0.5도 칸으로 나눠 저장 → 앱은 단지 둘레 칸만 받는다
 - 동반 조건(자세히)은 앱이 누를 때만 부른다 (개발 계정 하루 1,000회라 목록만 여기서)
 - 실패하면 예전 파일을 그대로 둔다

    DATA_GO_KR_KEY   공공데이터포털 인증키

저장: web/data/pet/t_<위도*2 내림>_<경도*2 내림>.json  {"updated", "src", "items": [{id, t, ct, a, tel, img, y, x}]}
      web/data/pet/trip_index.json  {"updated", "count", "tiles": [...]}
"""
import json
import math
import os
import time
import urllib.parse
import urllib.request
from collections import defaultdict
from datetime import datetime, timedelta, timezone

KEY = os.environ.get("DATA_GO_KR_KEY", "").strip()
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "web", "data", "pet")
KST = timezone(timedelta(hours=9))
BASE = "https://apis.data.go.kr/B551011/KorPetTourService2/"


def get_json(url):
    for tryn in range(3):
        try:
            with urllib.request.urlopen(url, timeout=40) as r:
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
    return (it if isinstance(it, list) else [it]), int(body.get("totalCount") or 0)


def page(op, n):
    key = KEY if "%" in KEY else urllib.parse.quote(KEY, safe="")
    q = urllib.parse.urlencode({"MobileOS": "ETC", "MobileApp": "yogikok", "_type": "json", "numOfRows": 1000, "pageNo": n, "arrange": "C"})
    return get_json(f"{BASE}{op}?serviceKey={key}&{q}")


def main():
    if not KEY:
        print("반려동물: DATA_GO_KR_KEY 없음 → 건너뜀")
        return
    op = None
    first = None
    for cand in ("areaBasedList2", "areaBasedList"):
        first = page(cand, 1)
        if first and items_of(first)[1] > 0:
            op = cand
            break
    if not op:
        print("반려동물: 동반여행 목록을 못 받음 (활용신청 확인) → 예전 파일 유지")
        return
    rows, total = items_of(first)
    pages = math.ceil(total / 1000)
    for n in range(2, pages + 1):
        j = page(op, n)
        if not j:
            print(f"  {n}쪽 실패 → 이번엔 저장하지 않음")
            return
        rows += items_of(j)[0]
    tiles = defaultdict(list)
    seen = set()
    for it in rows:
        try:
            y, x = float(it.get("mapy") or 0), float(it.get("mapx") or 0)
        except Exception:  # noqa: BLE001
            continue
        cid = str(it.get("contentid") or "")
        if not (33 < y < 39 and 124 < x < 132) or not cid or cid in seen:
            continue
        seen.add(cid)
        img = (it.get("firstimage2") or it.get("firstimage") or "").replace("http://", "https://")
        tiles[f"{math.floor(y * 2)}_{math.floor(x * 2)}"].append({
            "id": cid,
            "t": (it.get("title") or "").strip(),
            "ct": str(it.get("contenttypeid") or ""),
            "a": " ".join(s for s in [(it.get("addr1") or "").strip(), (it.get("addr2") or "").strip()] if s),
            "tel": (it.get("tel") or "").strip(),
            "img": img,
            "y": round(y, 6),
            "x": round(x, 6),
        })
    if not tiles:
        print("반려동물: 좌표 있는 곳이 없음 → 예전 파일 유지")
        return
    os.makedirs(OUT, exist_ok=True)
    now = datetime.now(KST).strftime("%Y-%m-%d %H:%M")
    for name in os.listdir(OUT):  # 없어진 칸 지우기
        if name.startswith("t_") and name.endswith(".json") and name[2:-5] not in tiles:
            os.remove(os.path.join(OUT, name))
    for k, v in tiles.items():
        v.sort(key=lambda z: z["t"])
        with open(os.path.join(OUT, f"t_{k}.json"), "w", encoding="utf-8") as f:
            json.dump({"updated": now, "src": "한국관광공사 반려동물 동반여행", "items": v}, f, ensure_ascii=False, separators=(",", ":"))
    with open(os.path.join(OUT, "trip_index.json"), "w", encoding="utf-8") as f:
        json.dump({"updated": now, "count": len(seen), "tiles": sorted(tiles)}, f, ensure_ascii=False)
    print(f"반려동물: 같이 갈 곳 {len(seen):,}곳 · 칸 {len(tiles)}개")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # noqa: BLE001
        print("반려동물 수집 오류:", e)
