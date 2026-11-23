"""우편번호 방: 동네별 아파트 단지의 우편번호·도로명·지번 주소를 미리 모아 둔다.

- 읽는 곳: web/data/apt_<동네>.json (본부가 모은 단지 목록, 읽기만 함)
- 쓰는 곳: web/data/postcode/<동네>.json
    {"area_id", "updated", "z": {"<단지 id>": ["우편번호", "도로명 주소", "지번 주소", "건물 이름"]}}
- 주소는 거의 안 바뀌므로 이미 찾은 단지는 다시 묻지 않는다 (카카오 호출 아끼기).
- 열쇠: KAKAO_REST_KEY (없으면 건너뜀). 실패해도 다른 기능에 영향 없게 오류는 출력만.
"""
import glob
import json
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


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # 다른 기능에 영향 없게
        print("[우편번호] 오류:", e)
