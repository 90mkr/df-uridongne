"""우리동네 업체 자료 모으기 (깃허브 자동 제작에서 돈다).

카카오 장소 검색으로 동네마다 생활 업체(세탁소·떡집·약국·어린이집 …)를 모아
web/data/<동네id>.json 으로 저장한다. 동네 id와 범위는 콕플과 똑같이 쓴다
(같은 가게는 카카오 장소 번호가 같아서 콕플 맛집 자료와 바로 이어짐).

    KAKAO_REST_KEY   카카오 REST 키 (깃허브 비밀)
    AREAS            이번에 모을 동네 id (쉼표, 비우면 regions.json에서 collect가 켜진 곳 전부)

카카오는 한 번 찾을 때 최대 45곳까지만 주므로, 45곳이 꽉 차면 칸을 4등분해서 다시 찾는다.
"""
import json
import os
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

KEY = os.environ.get("KAKAO_REST_KEY", "").strip()
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "web", "data")
KST = timezone(timedelta(hours=9))

# 앱의 분야 → 카카오 분류 코드(c) 또는 검색어(k). 검색어는 이름·분류에 그 말(m)이 들어간 곳만 남긴다.
CATS = [
    ("food", [("c", "FD6")]),
    ("cafe", [("c", "CE7")]),
    ("mart", [("c", "MT1"), ("c", "CS2")]),
    ("hosp", [("c", "HP8")]),
    ("pharm", [("c", "PM9")]),
    ("kids", [("c", "PS3")]),
    ("acad", [("c", "AC5")]),
    ("laundry", [("k", "세탁소", ["세탁", "크리닝", "클리닝"]), ("k", "빨래방", ["빨래", "세탁", "코인"])]),
    ("ricecake", [("k", "떡집", ["떡"]), ("k", "반찬가게", ["반찬"])]),
    ("hair", [("k", "미용실", ["미용", "헤어", "hair", "Hair", "HAIR"])]),
    ("flower", [("k", "꽃집", ["꽃", "플라워", "flower", "Flower"])]),
    ("repair", [("k", "옷수선", ["수선"]), ("k", "열쇠", ["열쇠", "키"]), ("k", "구두수선", ["구두", "수선"])]),
    ("hardware", [("k", "철물점", ["철물", "공구"]), ("k", "인테리어", ["인테리어", "도배", "설비"])]),
    ("realty", [("c", "AG2")]),
    ("bank", [("c", "BK9")]),
    ("car", [("c", "OL7"), ("k", "세차장", ["세차"]), ("k", "카센터", ["카센터", "정비", "자동차"])]),
    ("pet", [("k", "동물병원", ["동물", "펫", "애견", "애완"]), ("k", "애견미용", ["애견", "펫", "강아지", "도그"])]),
    ("public", [("c", "PO3")]),
]

calls = 0


def kakao(path, params):
    global calls
    url = f"https://dapi.kakao.com/v2/local/search/{path}.json?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"Authorization": f"KakaoAK {KEY}"})
    for tryn in range(3):
        try:
            calls += 1
            with urllib.request.urlopen(req, timeout=15) as r:
                return json.loads(r.read().decode("utf-8"))
        except Exception as e:  # 잠깐 막히면 쉬었다 다시
            if tryn == 2:
                print("  카카오 오류:", e)
                return {"documents": [], "meta": {"total_count": 0, "is_end": True}}
            time.sleep(1.5 * (tryn + 1))


def search_once(how, val, rect):
    docs, total = [], 0
    for page in (1, 2, 3):
        p = {"rect": ",".join(f"{x:.6f}" for x in rect), "page": page, "size": 15, "sort": "accuracy"}
        if how == "c":
            p["category_group_code"] = val
            j = kakao("category", p)
        else:
            p["query"] = val
            j = kakao("keyword", p)
        docs += j.get("documents", [])
        total = j.get("meta", {}).get("total_count", 0)
        if j.get("meta", {}).get("is_end", True):
            break
    return docs, total


def sweep(how, val, rect, depth=0):
    docs, total = search_once(how, val, rect)
    if total > 45 and depth < 4:
        x1, y1, x2, y2 = rect
        mx, my = (x1 + x2) / 2, (y1 + y2) / 2
        out = []
        for r in ((x1, y1, mx, my), (mx, y1, x2, my), (x1, my, mx, y2), (mx, my, x2, y2)):
            out += sweep(how, val, r, depth + 1)
        return out
    return docs


def tel(t):
    return (t or "").strip()


def collect_area(a):
    bbox = a["bbox"]
    shops = {}
    for cat, rules in CATS:
        n0 = len(shops)
        for rule in rules:
            how, val = rule[0], rule[1]
            words = rule[2] if len(rule) > 2 else None
            for d in sweep(how, val, bbox):
                try:
                    lng, lat = float(d["x"]), float(d["y"])
                except Exception:
                    continue
                if not (bbox[0] <= lng <= bbox[2] and bbox[1] <= lat <= bbox[3]):
                    continue
                name = d.get("place_name", "").strip()
                cname = d.get("category_name", "")
                if words and not any(w in name or w in cname for w in words):
                    continue
                pid = str(d.get("id", ""))
                if not pid:
                    continue
                if pid in shops:  # 여러 분야에 걸치면 분야를 더한다
                    if cat not in shops[pid]["c"]:
                        shops[pid]["c"].append(cat)
                    continue
                sub = cname.split(">")[-1].strip() if cname else ""
                shops[pid] = {
                    "id": pid,
                    "n": name,
                    "c": [cat],
                    "s": sub,
                    "a": d.get("road_address_name") or d.get("address_name", ""),
                    "t": tel(d.get("phone")),
                    "y": round(lat, 6),
                    "x": round(lng, 6),
                }
        print(f"  {cat}: {len(shops) - n0}곳")
    return list(shops.values())


APT_SKIP = ("상가", "관리사무소", "부동산", "공인중개", "경로당", "어린이집", "주차", "놀이터", "독서실", "유치원", "헬스", "커뮤니티")


def collect_apts(a):
    """동네의 아파트 단지 목록 (단지 고르기 화면용)."""
    out = {}
    for d in sweep("k", "아파트", a["bbox"]):
        cname = d.get("category_name", "")
        name = d.get("place_name", "").strip()
        if "아파트" not in cname or any(w in name for w in APT_SKIP):
            continue
        if not cname.endswith("아파트"):  # '…주거시설 > 아파트' 만 (아파트 안의 가게 제외)
            continue
        try:
            lng, lat = float(d["x"]), float(d["y"])
        except Exception:
            continue
        pid = str(d.get("id", ""))
        if pid and pid not in out:
            out[pid] = {"id": pid, "n": name, "a": d.get("road_address_name") or d.get("address_name", ""), "y": round(lat, 6), "x": round(lng, 6)}
    return sorted(out.values(), key=lambda z: z["n"])


def main():
    if not KEY:
        print("카카오 키(KAKAO_REST_KEY)가 없어 이번에는 건너뜁니다.")
        return
    reg_path = os.path.join(DATA, "regions.json")
    reg = json.load(open(reg_path, encoding="utf-8"))
    want = [x.strip() for x in os.environ.get("AREAS", "").split(",") if x.strip()]
    now = datetime.now(KST).strftime("%Y-%m-%d %H:%M")
    for s in reg["sido"]:
        for a in s["areas"]:
            if not a.get("bbox"):
                continue
            if want and a["id"] not in want:
                continue
            if not want and not a.get("collect"):
                continue
            print(f"[{s['name']} {a['name']}] 모으는 중")
            c0 = calls
            apts = collect_apts(a)
            if apts:
                with open(os.path.join(DATA, f"apt_{a['id']}.json"), "w", encoding="utf-8") as f:
                    json.dump({"area_id": a["id"], "updated": now, "apts": apts}, f, ensure_ascii=False, separators=(",", ":"))
                print(f"  아파트 단지 {len(apts)}곳")
            shops = collect_area(a)
            if not shops:
                print("  아무것도 못 찾아 저장하지 않음")
                continue
            shops.sort(key=lambda z: (z["c"][0], z["n"]))
            out = {"area": a["name"], "area_id": a["id"], "updated": now, "count": len(shops), "shops": shops}
            with open(os.path.join(DATA, f"{a['id']}.json"), "w", encoding="utf-8") as f:
                json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
            a["ready"] = True
            a["updated"] = now
            a["count"] = len(shops)
            print(f"  모두 {len(shops)}곳 · 카카오 조회 {calls - c0}번")
    with open(reg_path, "w", encoding="utf-8") as f:
        json.dump(reg, f, ensure_ascii=False, indent=1)
    print(f"끝 · 카카오 조회 모두 {calls}번")


if __name__ == "__main__":
    sys.exit(main())
