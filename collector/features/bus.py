"""단지 앞 버스 — 단지 둘레 정류장 미리 모으기 (이 파일은 단지 앞 버스 담당 방만 고침)

국토교통부 TAGO 「버스정류소정보」의 좌표 둘레 정류장 조회로, 동네마다 아파트 단지
(web/data/apt_<동네>.json) 둘레 800m 안 정류장을 가까운 순 10곳까지 모아 둔다.
정류장은 자주 바뀌지 않으므로 매주 한 번이면 충분. 실시간 도착은 앱이 직접 부른다.

    DATA_GO_KR_KEY   공공데이터포털 인증키 (깃허브 비밀)

저장 파일
    web/data/bus/near_<동네>.json   {"updated", "near": {단지id: [{i,n,no,c,y,x}, …]}}
    web/data/bus/meta.json          갱신 시각 · 동네별 단지·정류장 수

「앱 제작」 수동 실행 때 동네 칸에 bus 를 넣으면 (예: bus 또는 bus,songdo) 버스 정류장만 모은다.
서울은 TAGO 에 없어 비어 있게 된다 (서울시 버스 자료는 다음 단계).
"""
import glob
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
OUT = os.path.join(DATA, "bus")
KST = timezone(timedelta(hours=9))
NEAR = "https://apis.data.go.kr/1613000/BusSttnInfoInqireService/getCrdntPrxmtSttnList"
RADIUS = 800
MAX_STOPS = 10
MAX_CALLS = 6000  # 개발 계정 하루 10,000회 — 앱 사용분을 남겨 둔다

calls = 0


def meters(a, b):
    r = 6371000.0
    la1, lo1, la2, lo2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))


def fetch(params, tries=3):
    """정류장 목록 → item 목록 (없으면 빈 목록), 실패하면 None"""
    global calls
    key = KEY if "%" in KEY else urllib.parse.quote(KEY, safe="")
    q = f"serviceKey={key}&_type=json&" + urllib.parse.urlencode(params)
    for n in range(tries):
        try:
            calls += 1
            with urllib.request.urlopen(f"{NEAR}?{q}", timeout=30) as r:
                text = r.read().decode("utf-8", "replace").strip()
            if not text.startswith("{"):
                print("  ! 응답이 JSON 이 아님:", text[:160].replace("\n", " "))
                return None
            j = json.loads(text)
            resp = j.get("response") or {}
            code = str((resp.get("header") or {}).get("resultCode", ""))
            if code not in ("", "00", "0"):
                print("  ! 결과 코드", code, (resp.get("header") or {}).get("resultMsg"))
                return None
            items = (resp.get("body") or {}).get("items")
            it = items.get("item") if isinstance(items, dict) else None
            if isinstance(it, dict):
                return [it]
            return it if isinstance(it, list) else []
        except Exception as e:  # noqa: BLE001
            if n == tries - 1:
                print("  ! 부르기 실패:", e)
                return None
            time.sleep(1.5 * (n + 1))
    return None


def stops_near(lat, lng):
    items = fetch({"gpsLati": f"{lat:.6f}", "gpsLong": f"{lng:.6f}", "numOfRows": 40, "pageNo": 1})
    if items is None:
        return None
    out = []
    for x in items:
        try:
            y, xx = float(x.get("gpslati")), float(x.get("gpslong"))
        except (TypeError, ValueError):
            continue
        nid = str(x.get("nodeid") or "").strip()
        if not nid:
            continue
        d = meters((lat, lng), (y, xx))
        if d > RADIUS:
            continue
        out.append((d, {"i": nid, "n": str(x.get("nodenm") or "").strip(), "no": str(x.get("nodeno") or "").strip(),
                        "c": int(x.get("citycode") or 0), "y": round(y, 6), "x": round(xx, 6)}))
    out.sort(key=lambda t: t[0])
    seen, res = set(), []
    for _, s in out:
        if s["i"] in seen:
            continue
        seen.add(s["i"])
        res.append(s)
        if len(res) >= MAX_STOPS:
            break
    return res


def main():
    if not KEY:
        print("DATA_GO_KR_KEY 가 없어 버스 정류장을 모으지 않습니다")
        return 0
    os.makedirs(OUT, exist_ok=True)
    want = set(filter(None, os.environ.get("AREAS", "").replace(" ", "").split(",")))
    want.discard("bus")
    others = {"gas", "trash", "pharmacy", "lotto", "parking", "charger", "postcode", "phonebook", "deals", "weather"}
    if want & others and not want - others:
        print("다른 기능만 모으는 실행이라 버스는 건너뜁니다")
        return 0
    want -= others
    now = datetime.now(KST).strftime("%Y-%m-%d %H:%M")
    meta_path = os.path.join(OUT, "meta.json")
    try:
        meta = json.load(open(meta_path, encoding="utf-8"))
    except Exception:  # noqa: BLE001
        meta = {"areas": {}}
    for path in sorted(glob.glob(os.path.join(DATA, "apt_*.json"))):
        area = os.path.basename(path)[4:-5]
        if want and area not in want:
            continue
        try:
            apts = json.load(open(path, encoding="utf-8")).get("apts") or []
        except Exception as e:  # noqa: BLE001
            print(f"[{area}] 단지 파일을 못 읽음: {e}")
            continue
        out_path = os.path.join(OUT, f"near_{area}.json")
        try:
            old = (json.load(open(out_path, encoding="utf-8")).get("near")) or {}
        except Exception:  # noqa: BLE001
            old = {}
        near, fails, cache = {}, 0, {}
        print(f"[{area}] 단지 {len(apts)}곳 정류장 모으는 중")
        for a in apts:
            if calls >= MAX_CALLS:
                print("  하루 사용량 보호로 멈춤 — 남은 단지는 지난 자료 유지")
                break
            if a.get("y") is None or a.get("x") is None:
                continue
            cid = str(a.get("id"))
            # 같은 건물 묶음(좌표가 거의 같은 단지)은 한 번만 부른다
            ck = (round(float(a["y"]), 3), round(float(a["x"]), 3))
            if ck in cache:
                res = cache[ck]
            else:
                res = stops_near(float(a["y"]), float(a["x"]))
                cache[ck] = res
                time.sleep(0.05)
            if res is None:
                fails += 1
                if cid in old:
                    near[cid] = old[cid]
                if fails >= 25 and not near:
                    print("  계속 실패 — 이 동네는 지난 자료 유지")
                    break
                continue
            if res:
                near[cid] = res
        for cid, v in old.items():
            near.setdefault(cid, v)
        if not near:
            print("  모은 정류장이 없어 저장하지 않음")
            continue
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump({"area_id": area, "updated": now, "near": near}, f, ensure_ascii=False, separators=(",", ":"))
        n_stops = len({s["i"] for v in near.values() for s in v})
        meta.setdefault("areas", {})[area] = {"updated": now, "complexes": len(near), "stops": n_stops}
        print(f"  단지 {len(near)}곳 · 정류장 {n_stops}곳 저장 (실패 {fails})")
    meta["updated"] = now
    meta["calls"] = calls
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)
    print(f"버스: 부른 횟수 {calls}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except SystemExit:
        raise
    except Exception as e:  # noqa: BLE001
        print("버스 자료 모으기 오류:", e)
        raise SystemExit(0)
