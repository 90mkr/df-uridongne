"""복권 자료 모으기 (복권 담당 방만 고침). 자동 제작이 매주 돌린다.

만드는 파일 (web/data/lotto/)
  draws.json        1회부터 최근 회차까지 로또 당첨번호 (앱의 「이번 주 당첨번호」·「내 번호 확인」)
  wins_all.json     전국 1등 나온 판매점 누적 (중간 저장용, 앱은 안 읽음)
  area_<동네id>.json 동네별 「1등 나온 집」 + 카카오로 찾은 복권 판매점

자료 출처
  당첨번호   1순위 동행복권 홈페이지가 쓰는 조회 주소(lt645/selectPstLt645Info.do, 정식 공개 API 아님)
             막히거나 형식이 바뀌면 공개 모음(smok95/lotto, 깃허브)으로 채운다. 둘 다 안 되면 지난 파일 유지.
  1등 판매점 공개 모음(smok95/lotto winning-stores, 262회부터, 위경도 포함) — 새 회차만 받아 누적
  판매점     카카오 장소 검색 「복권」「로또」 (KAKAO_REST_KEY, 이미 있는 열쇠)

오류는 잡아서 출력만 하고, 받은 것만 저장한다 (다른 기능에 영향 없게).
"""
import json
import math
import os
import re
import time
import urllib.parse
import urllib.request
from datetime import date, datetime, timedelta, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "web", "data", "lotto")
REGIONS = os.path.join(ROOT, "web", "data", "regions.json")
KEY = os.environ.get("KAKAO_REST_KEY", "").strip()
KST = timezone(timedelta(hours=9))
UA = {"User-Agent": "Mozilla/5.0 (compatible; dongne-collector)", "Accept": "application/json"}

OFFICIAL = "https://www.dhlottery.co.kr/lt645/selectPstLt645Info.do"
MIRROR = "https://raw.githubusercontent.com/smok95/lotto/main"
FIRST_DAY = date(2002, 12, 7)  # 1회 추첨일 (토요일)
WIN_FROM = 262  # 공개 모음의 1등 판매점은 262회부터


def get(url, tries=3, timeout=25):
    for n in range(tries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=timeout) as r:
                return r.read().decode("utf-8")
        except Exception as e:
            if n == tries - 1:
                print("  받기 실패:", url[:90], e)
                return None
            time.sleep(2 * (n + 1))


def get_json(url, **kw):
    t = get(url, **kw)
    if t is None:
        return None
    try:
        return json.loads(t)
    except Exception:
        print("  JSON 아님 (막혔거나 형식 바뀜):", url[:90], t[:120].replace("\n", " "))
        return None


def load(path, default):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return default


def save(path, obj, lines=False):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        if lines and isinstance(obj, dict) and isinstance(obj.get("draws"), list):
            # 회차 하나를 한 줄로 → 매주 변경이 한 줄 추가로 보임
            head = {k: v for k, v in obj.items() if k != "draws"}
            f.write(json.dumps(head, ensure_ascii=False)[:-1] + ',"draws":[\n')
            f.write(",\n".join(json.dumps(d, ensure_ascii=False, separators=(",", ":")) for d in obj["draws"]))
            f.write("\n]}\n")
        elif lines and isinstance(obj, dict) and isinstance(obj.get("stores"), dict):
            # 판매점 하나를 한 줄로 (매주 바뀐 줄만 저장소에 쌓이게)
            head = {k: v for k, v in obj.items() if k != "stores"}
            f.write(json.dumps(head, ensure_ascii=False)[:-1] + ',"stores":{\n')
            f.write(",\n".join(json.dumps(k, ensure_ascii=False) + ":" + json.dumps(v, ensure_ascii=False, separators=(",", ":"))
                               for k, v in sorted(obj["stores"].items())))
            f.write("\n}}\n")
        else:
            json.dump(obj, f, ensure_ascii=False, separators=(",", ":"))
    os.replace(tmp, path)


def expected_latest(now=None):
    """지금 시각에 나와 있어야 할 최신 회차 (토요일 21시 이후면 그 주 회차)."""
    now = now or datetime.now(KST)
    days = (now.date() - FIRST_DAY).days
    n = days // 7 + 1
    if days % 7 == 0 and now.hour < 21:
        n -= 1
    return n


# ---------------- 당첨번호 ----------------
# 한 회차 = [회차, "yyyy-mm-dd", [번호6], 보너스, [[1등 인원, 1인당], [2등…], [3등…], [4등…], [5등…]], [자동, 수동, 반자동]]

def valid(d):
    try:
        nums, b = d[2], d[3]
        balls = nums + [b]
        return (isinstance(d[0], int) and d[0] >= 1 and re.match(r"^\d{4}-\d{2}-\d{2}$", d[1])
                and len(nums) == 6 and all(isinstance(x, int) and 1 <= x <= 45 for x in balls) and len(set(balls)) == 7)
    except Exception:
        return False


def from_official(x):
    ymd = str(x.get("ltRflYmd", ""))
    d = [int(x["ltEpsd"]), f"{ymd[:4]}-{ymd[4:6]}-{ymd[6:8]}",
         sorted(int(x[f"tm{i}WnNo"]) for i in range(1, 7)), int(x["bnsWnNo"]),
         [[int(x.get(f"rnk{r}WnNope") or 0), int(x.get(f"rnk{r}WnAmt") or 0)] for r in range(1, 6)], []]
    return d


def from_mirror(x):
    div = x.get("divisions") or []
    ranks = []
    for r in range(5):
        v = div[r] if r < len(div) and isinstance(div[r], dict) else {}
        ranks.append([int(v.get("winners") or 0), int(v.get("prize") or 0)])
    wc = x.get("winners_combination") or {}
    return [int(x["draw_no"]), str(x.get("date", ""))[:10], sorted(int(n) for n in x["numbers"]), int(x["bonus_no"]), ranks,
            [int(wc.get("auto") or 0), int(wc.get("manual") or 0), int(wc.get("semi_auto") or 0)]]


def fetch_official(start, end):
    j = get_json(f"{OFFICIAL}?srchStrLtEpsd={start}&srchEndLtEpsd={end}", tries=2)
    try:
        lst = j["data"]["list"]
    except Exception:
        return []
    out = []
    for x in lst:
        try:
            d = from_official(x)
            if valid(d):
                out.append(d)
        except Exception:
            pass
    return out


def fetch_mirror(start, end):
    out = []
    if end - start > 20:
        j = get_json(f"{MIRROR}/results/all.json", timeout=60)
        for x in j or []:
            try:
                if start <= int(x["draw_no"]) <= end:
                    d = from_mirror(x)
                    if valid(d):
                        out.append(d)
            except Exception:
                pass
        return out
    for n in range(start, end + 1):
        x = get_json(f"{MIRROR}/results/{n}.json", tries=2)
        if not x:
            break
        try:
            d = from_mirror(x)
            if valid(d):
                out.append(d)
        except Exception:
            pass
    return out


def update_draws():
    path = os.path.join(OUT, "draws.json")
    old = load(path, {})
    have = {d[0]: d for d in old.get("draws", []) if valid(d)}
    want = expected_latest()
    start = (max(have) + 1) if have else 1
    if start > want:
        print(f"  당첨번호: 새 회차 없음 (최신 {start - 1}회)")
        return have
    print(f"  당첨번호: {start}~{want}회 받기")
    got = {d[0]: d for d in fetch_official(start, want)}
    src = "동행복권"
    miss = [n for n in range(start, want + 1) if n not in got]
    if miss:
        more = {d[0]: d for d in fetch_mirror(min(miss), max(miss))}
        if more:
            src = "공개 모음" if not got else "동행복권+공개 모음"
        for n in miss:
            if n in more:
                got[n] = more[n]
    # 공식 응답에는 자동·수동 인원이 없어서, 있으면 공개 모음 값으로 보충 (최근 회차만)
    for n, d in got.items():
        if not d[5] and n >= want - 2:
            m = fetch_mirror(n, n)
            if m and m[0][2] == d[2] and m[0][3] == d[3]:
                d[5] = m[0][5]
            elif m and (m[0][2] != d[2] or m[0][3] != d[3]):
                print(f"  !! {n}회 번호가 출처마다 다름 — 동행복권 값을 씀")
    # 빠진 회차 없이 이어지는 것만 넣는다
    n = start
    added = 0
    while n in got:
        have[n] = got[n]
        n += 1
        added += 1
    if not added:
        print("  당첨번호: 받지 못함 — 지난 파일 유지")
        return have
    draws = [have[k] for k in sorted(have)]
    save(path, {"updated": datetime.now(KST).strftime("%Y-%m-%d %H:%M"), "source": src, "latest": draws[-1][0], "draws": draws}, lines=True)
    print(f"  당첨번호: {added}회 추가 → 최신 {draws[-1][0]}회 ({draws[-1][1]}) {draws[-1][2]}+{draws[-1][3]} [{src}]")
    return have


# ---------------- 1등 나온 판매점 (전국 누적) ----------------

def norm_name(s):
    return re.sub(r"[\s()\[\]·\-_.,]|복권|로또|lotto|판매점|방|점$", "", (s or "").lower())


def store_key(name, addr):
    a = re.sub(r"\s+", "", addr or "")
    return f"{norm_name(name)}|{a}"


def update_wins(latest):
    path = os.path.join(OUT, "wins_all.json")
    allw = load(path, {})
    done = int(allw.get("done", WIN_FROM - 1))
    stores = allw.get("stores", {})
    if done >= latest:
        print(f"  1등 판매점: 새 회차 없음 ({done}회까지)")
        return stores
    print(f"  1등 판매점: {done + 1}~{latest}회 받기")
    t0 = time.time()
    n = done + 1
    skipped = allw.get("skipped", [])
    miss = []  # 연달아 빠진 회차 (한두 회차만 빠진 것은 건너뛴다)
    while n <= latest:
        lst = get_json(f"{MIRROR}/winning-stores/{n}.json", tries=2, timeout=20)
        if lst is None:
            miss.append(n)
            if len(miss) >= 3 or n == latest:
                n = miss[0]  # 끝부분이 아직 안 올라옴 → 다음에 거기서부터
                print(f"  1등 판매점: {n}회부터 아직 없음 — 다음에 이어서")
                break
            n += 1
            continue
        skipped += miss
        miss = []
        for s in lst if isinstance(lst, list) else []:
            name, addr = (s.get("name") or "").strip(), (s.get("address") or "").strip()
            if not name:
                continue
            k = store_key(name, addr)
            v = stores.get(k)
            if not v:
                v = stores[k] = {"n": name, "a": re.sub(r"\s+", " ", addr), "y": s.get("lat"), "x": s.get("lng"), "c": [0, 0, 0], "r": []}
            if v.get("y") is None and s.get("lat") is not None:
                v["y"], v["x"] = s.get("lat"), s.get("lng")
            comb = s.get("combination") or ""
            v["c"][1 if comb == "수동" else 2 if comb == "반자동" else 0] += 1
            v["r"].append(n)
        n += 1
        if time.time() - t0 > 1200:
            print("  1등 판매점: 시간이 길어져 여기서 멈춤 — 다음에 이어서")
            break
    allw = {"done": n - 1, "skipped": sorted(set(skipped)), "updated": datetime.now(KST).strftime("%Y-%m-%d %H:%M"), "stores": stores}
    save(path, allw, lines=True)
    print(f"  1등 판매점: {n - 1}회까지, 전국 {len(stores)}곳" + (f" (자료 없는 회차 {sorted(set(skipped))})" if skipped else ""))
    return stores


# ---------------- 동네별 파일 ----------------

def meters(lat1, lng1, lat2, lng2):
    r = 6371000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = p2 - p1, math.radians(lng2 - lng1)
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))


def grow(b, km):
    dy = km / 111.0
    dx = km / (111.0 * math.cos(math.radians((b[1] + b[3]) / 2)))
    return [b[0] - dx, b[1] - dy, b[2] + dx, b[3] + dy]


def inside(b, lat, lng):
    return lat is not None and lng is not None and b[0] <= lng <= b[2] and b[1] <= lat <= b[3]


kcalls = 0


def kakao(params):
    global kcalls
    url = "https://dapi.kakao.com/v2/local/search/keyword.json?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"Authorization": f"KakaoAK {KEY}"})
    for n in range(3):
        try:
            kcalls += 1
            with urllib.request.urlopen(req, timeout=15) as r:
                return json.loads(r.read().decode("utf-8"))
        except Exception as e:
            if n == 2:
                print("  카카오 오류:", e)
                return {"documents": [], "meta": {"is_end": True, "total_count": 0}}
            time.sleep(1.5 * (n + 1))


def is_lotto(d):
    t = f"{d.get('place_name', '')} {d.get('category_name', '')}".lower()
    return "복권" in t or "로또" in t or "lotto" in t


def sweep(q, rect, depth=0, out=None):
    out = {} if out is None else out
    docs, total = [], 0
    for page in (1, 2, 3):
        j = kakao({"query": q, "rect": ",".join(f"{v:.6f}" for v in rect), "page": page, "size": 15})
        docs += j.get("documents", [])
        total = j.get("meta", {}).get("total_count", 0)
        if j.get("meta", {}).get("is_end", True):
            break
    if total > 45 and depth < 5:
        x1, y1, x2, y2 = rect
        mx, my = (x1 + x2) / 2, (y1 + y2) / 2
        for r in ([x1, y1, mx, my], [mx, y1, x2, my], [x1, my, mx, y2], [mx, my, x2, y2]):
            sweep(q, r, depth + 1, out)
        return out
    for d in docs:
        if is_lotto(d):
            out[d["id"]] = d
    return out


def kakao_shops(bbox):
    if not KEY:
        return None
    found = {}
    for q in ("복권", "로또"):
        sweep(q, bbox, out=found)
    shops = []
    for d in found.values():
        try:
            shops.append({"id": d["id"], "n": d["place_name"], "a": d.get("road_address_name") or d.get("address_name", ""),
                          "t": d.get("phone", ""), "y": round(float(d["y"]), 6), "x": round(float(d["x"]), 6)})
        except Exception:
            pass
    return shops


def match_win(shop, wins):
    """카카오 판매점과 1등 판매점을 이어 붙인다 (60m 안 + 이름이 비슷하거나, 25m 안)."""
    best, bd = None, 1e9
    sn = norm_name(shop["n"])
    for w in wins:
        d = meters(shop["y"], shop["x"], w["y"], w["x"])
        if d > 60:
            continue
        wn = norm_name(w["n"])
        same = sn and wn and (sn in wn or wn in sn)
        if (same or d < 25) and d < bd:
            best, bd = w, d
    return best


def build_areas(stores, latest):
    reg = load(REGIONS, {})
    areas = [(s.get("name", ""), a) for s in reg.get("sido", []) for a in s.get("areas", [])]
    stamp = datetime.now(KST).strftime("%Y-%m-%d %H:%M")
    for sido, a in areas:
        try:
            box = [float(v) for v in a["bbox"]]
            wide = grow(box, 2.5)  # 동네 경계 바로 밖 명당도 보이게
            wins = []
            for v in stores.values():
                if inside(wide, v.get("y"), v.get("x")):
                    rs = sorted(v["r"])
                    wins.append({"n": v["n"], "a": v["a"], "y": round(float(v["y"]), 6), "x": round(float(v["x"]), 6),
                                 "w": len(rs), "c": v["c"], "last": rs[-1], "r": rs[-12:]})
            wins.sort(key=lambda w: (-w["w"], -w["last"]))
            path = os.path.join(OUT, f"area_{a['id']}.json")
            old = load(path, {})
            shops = old.get("shops", [])
            if a.get("collect") or a.get("ready"):
                got = kakao_shops(grow(box, 1.0))
                if got:
                    shops = got
                elif got is None:
                    print("  판매점: 카카오 열쇠 없음 — 지난 목록 유지")
            for s in shops:
                w = match_win(s, wins)
                s["w"] = w["w"] if w else 0
                if w:
                    w["id"] = s["id"]
                    if not w.get("t") and s.get("t"):
                        w["t"] = s["t"]
            save(path, {"area": a["id"], "name": a.get("name", ""), "updated": stamp, "upto": latest, "wins": wins, "shops": shops})
            print(f"  {sido} {a.get('name')}: 1등 나온 집 {len(wins)}곳, 판매점 {len(shops)}곳")
        except Exception as e:
            print("  동네 파일 오류:", a.get("id"), e)


def main():
    print("== 복권")
    os.makedirs(OUT, exist_ok=True)
    latest = 0
    try:
        have = update_draws()
        latest = max(have) if have else 0
    except Exception as e:
        print("  당첨번호 오류:", e)
    stores = {}
    try:
        stores = update_wins(latest or expected_latest())
    except Exception as e:
        print("  1등 판매점 오류:", e)
        stores = load(os.path.join(OUT, "wins_all.json"), {}).get("stores", {})
    try:
        build_areas(stores, latest)
    except Exception as e:
        print("  동네 파일 오류:", e)
    print(f"  카카오 호출 {kcalls}번")


if __name__ == "__main__":
    main()
