"""택배·우편 방(우편번호 폴더): 동네별로 두 가지를 미리 모아 둔다.

1) 아파트 단지의 우편번호·도로명·지번 주소

- 읽는 곳: web/data/apt_<동네>.json (본부가 모은 단지 목록, 읽기만 함)
- 쓰는 곳: web/data/postcode/<동네>.json
    {"area_id", "updated", "z": {"<단지 id>": ["우편번호", "도로명 주소", "지번 주소", "건물 이름"]}}
2) 우체국(우편취급국 포함)과 택배 접수 편의점(CU·GS25) 위치 — 카카오 장소 검색
- 쓰는 곳: web/data/postcode/po_<동네>.json
    {"area_id", "updated", "po": [{"id","k":"po|cu|gs","n","a","t","y","x"}]}
- 주소는 거의 안 바뀌므로 이미 찾은 단지는 다시 묻지 않는다 (카카오 호출 아끼기).
- 열쇠: KAKAO_REST_KEY (없으면 건너뜀). 실패해도 다른 기능에 영향 없게 오류는 출력만.
"""
import glob
import json
import math
import os
import time
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

KEY = os.environ.get("KAKAO_REST_KEY", "").strip()
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = os.path.join(ROOT, "web", "data")
OUT = os.path.join(DATA, "postcode")
KST = timezone(timedelta(hours=9))
MAX_CALLS = 3000  # 한 번 돌 때 최대 호출 수 (카카오 하루 한도 안에서 넉넉히)

calls = 0


def find(addr):
    global calls
    url = "https://dapi.kakao.com/v2/local/search/address.json?" + urllib.parse.urlencode({"query": addr, "size": 1})
    req = urllib.request.Request(url, headers={"Authorization": f"KakaoAK {KEY}"})
    for tryn in range(3):
        try:
            calls += 1
            with urllib.request.urlopen(req, timeout=15) as r:
                docs = json.loads(r.read().decode("utf-8")).get("documents") or []
            break
        except Exception as e:
            if tryn == 2:
                print("  카카오 오류:", e)
                return None
            time.sleep(1.5 * (tryn + 1))
    if not docs:
        return None
    d = docs[0]
    road = d.get("road_address") or {}
    jibun = (d.get("address") or {}).get("address_name", "")
    zone = road.get("zone_no", "")
    if not zone:
        return None
    return [zone, road.get("address_name", ""), jibun, road.get("building_name", "")]


def keyword(q, rect, page):
    global calls
    p = {"query": q, "rect": ",".join(f"{v:.6f}" for v in rect), "page": page, "size": 15}
    url = "https://dapi.kakao.com/v2/local/search/keyword.json?" + urllib.parse.urlencode(p)
    req = urllib.request.Request(url, headers={"Authorization": f"KakaoAK {KEY}"})
    for tryn in range(3):
        try:
            calls += 1
            with urllib.request.urlopen(req, timeout=15) as r:
                return json.loads(r.read().decode("utf-8"))
        except Exception as e:
            if tryn == 2:
                print("  카카오 오류:", e)
                return {"documents": [], "meta": {"is_end": True, "total_count": 0}}
            time.sleep(1.5 * (tryn + 1))


def sweep(q, rect, keep, out, depth=0):
    docs, total = [], 0
    for page in (1, 2, 3):
        j = keyword(q, rect, page)
        docs += j.get("documents", [])
        total = j.get("meta", {}).get("total_count", 0)
        if j.get("meta", {}).get("is_end", True):
            break
    if total > 45 and depth < 5:  # 한 번에 45곳까지만 주므로 네 칸으로 나눠 다시
        x1, y1, x2, y2 = rect
        mx, my = (x1 + x2) / 2, (y1 + y2) / 2
        for r in ([x1, y1, mx, my], [mx, y1, x2, my], [x1, my, mx, y2], [mx, my, x2, y2]):
            sweep(q, r, keep, out, depth + 1)
        return
    for d in docs:
        k = keep(d)
        if k:
            out[d["id"]] = (k, d)


def kind_po(d):
    n, c = d.get("place_name", ""), d.get("category_name", "")
    if ("우체국" in n or "우편취급국" in n) and "우체국" in c and "택배" not in n and "보험" not in n:
        return "po"
    return None


def kind_cvs(d):
    n, c = d.get("place_name", ""), d.get("category_name", "")
    if "편의점" not in c:
        return None
    if n.upper().startswith("CU"):
        return "cu"
    if n.upper().startswith("GS25"):
        return "gs"
    return None


def grow(b, km):
    dy = km / 111.0
    dx = km / (111.0 * math.cos(math.radians((b[1] + b[3]) / 2)))
    return [b[0] - dx, b[1] - dy, b[2] + dx, b[3] + dy]


def collect_places(now):
    try:
        reg = json.load(open(os.path.join(DATA, "regions.json"), encoding="utf-8"))
    except Exception as e:
        print("[우체국] 동네 목록 읽기 실패:", e)
        return
    have_apts = {os.path.basename(p)[4:-5] for p in glob.glob(os.path.join(DATA, "apt_*.json"))}
    for s in reg.get("sido", []):
        for a in s.get("areas", []):
            if a.get("id") not in have_apts or not a.get("bbox"):
                continue
            if calls >= MAX_CALLS:
                print("[우체국] 이번 호출 한도에 닿아 나머지는 다음에 모읍니다.")
                return
            rect = grow(a["bbox"], 1.0)
            found = {}
            sweep("우체국", rect, kind_po, found)
            sweep("CU", rect, kind_cvs, found)
            sweep("GS25", rect, kind_cvs, found)
            out = []
            for i, (k, d) in found.items():
                try:
                    out.append({"id": i, "k": k, "n": d["place_name"], "a": d.get("road_address_name") or d.get("address_name", ""),
                                "t": d.get("phone", ""), "y": round(float(d["y"]), 6), "x": round(float(d["x"]), 6)})
                except Exception:
                    pass
            if not out:
                print(f"[우체국] {a['id']}: 못 찾아 저장하지 않음")
                continue
            out.sort(key=lambda z: (z["k"], z["n"]))
            with open(os.path.join(OUT, f"po_{a['id']}.json"), "w", encoding="utf-8") as f:
                json.dump({"area_id": a["id"], "updated": now, "po": out}, f, ensure_ascii=False, separators=(",", ":"))
            n_po = sum(1 for z in out if z["k"] == "po")
            print(f"[우체국] {a['id']}: 우체국 {n_po}곳, 편의점 {len(out) - n_po}곳")


def main():
    if not KEY:
        print("[우편번호] 카카오 키(KAKAO_REST_KEY)가 없어 건너뜁니다.")
        return
    os.makedirs(OUT, exist_ok=True)
    now = datetime.now(KST).strftime("%Y-%m-%d %H:%M")
    for path in sorted(glob.glob(os.path.join(DATA, "apt_*.json"))):
        if calls >= MAX_CALLS:
            print("[우편번호] 이번 호출 한도에 닿아 나머지는 다음에 모읍니다.")
            break
        try:
            src = json.load(open(path, encoding="utf-8"))
        except Exception as e:
            print("[우편번호] 단지 목록 읽기 실패:", path, e)
            continue
        area = src.get("area_id") or os.path.basename(path)[4:-5]
        out_path = os.path.join(OUT, f"{area}.json")
        have = {}
        if os.path.exists(out_path):
            try:
                have = json.load(open(out_path, encoding="utf-8")).get("z", {})
            except Exception:
                have = {}
        z, new, miss = {}, 0, 0
        for a in src.get("apts", []):
            i, addr = str(a.get("id", "")), (a.get("a") or "").strip()
            if not i or not addr:
                continue
            if i in have and have[i][0]:
                z[i] = have[i]
                continue
            if calls >= MAX_CALLS:
                break
            r = find(addr)
            if r:
                z[i] = r
                new += 1
            else:
                miss += 1
            time.sleep(0.05)
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump({"area_id": area, "updated": now, "z": z}, f, ensure_ascii=False, separators=(",", ":"))
        print(f"[우편번호] {area}: 단지 {len(z)}곳 (새로 {new}, 못 찾음 {miss})")
    collect_places(now)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # 다른 기능에 영향 없게
        print("[우편번호] 오류:", e)
