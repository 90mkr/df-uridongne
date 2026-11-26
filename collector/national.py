"""니즈콕 전국 자료 만들기 (본부 방만 고침) — 깃허브 자동 제작에서 돈다.

카카오 자료는 저장하면 안 되므로(카카오 정책: 실시간 호출만) 공공데이터로만 만든다.
  1) 소상공인 상가(상권)정보  → 전국 가게 바탕 + 동네 나누기 (시군구, 큰 곳은 행정동 묶음으로 더 나눔)
  2) K-apt 단지 목록·기본정보 → 아파트 단지 (좌표는 브이월드 지오코더, 없으면 같은 건물 가게 좌표)
  3) 지방행정 인허가          → 전화번호 (상호·주소로 맞추기)

    DATA_GO_KR_KEY  공공데이터포털 키      VWORLD_KEY  브이월드 키 (없으면 건너뜀)
    SIDO            이번에 만들 시도 코드 (쉼표, 비우면 전국)
    OUT             결과 폴더 (기본 web/data)

결과 (동네 id = 'k' + 시군구 코드 [+ '_' + 번호], 연수구는 예전처럼 'songdo')
    <OUT>/regions.json         동네 목록 (모두 ready)
    <OUT>/<동네>.json          가게
    <OUT>/apt_<동네>.json      아파트 단지
"""
import json
import math
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone

KEY = os.environ.get("DATA_GO_KR_KEY", "").strip()
VKEY = os.environ.get("VWORLD_KEY", "").strip()
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.environ.get("OUT") or os.path.join(ROOT, "web", "data")
KST = timezone(timedelta(hours=9))
NOW = datetime.now(KST).strftime("%Y-%m-%d %H:%M")

SIDO = [  # 소상공인 시도 코드, 짧은 이름 (앱 동네 고르기 순서)
    ("11", "서울"), ("28", "인천"), ("41", "경기"), ("26", "부산"), ("27", "대구"), ("12", "전남광주"), ("29", "전남광주"), ("46", "전남광주"),
    ("30", "대전"), ("31", "울산"), ("36", "세종"), ("51", "강원"), ("42", "강원"), ("43", "충북"), ("44", "충남"), ("52", "전북"), ("45", "전북"),
    ("47", "경북"), ("48", "경남"), ("50", "제주"),
]
SPLIT = 15000  # 한 동네 가게가 이보다 많으면 행정동 묶음으로 나눈다 (파일 크기·앱 속도)

# 소상공인 업종 소분류 코드 → 앱 전화번호부 분야 (앞자리가 맞으면 그 분야)
CAT_RULES = [
    ("cafe", ("I212", "I21001", "I21008")),
    ("ricecake", ("I21002", "G20509")),
    ("food", ("I2",)),
    ("mart", ("G20404", "G20405", "G20499", "G20503", "G20505", "G20506", "G20507", "G20504")),
    ("pharm", ("G21501",)),
    ("hosp", ("Q101", "Q102")),
    ("acad", ("P1",)),
    ("laundry", ("S209",)),
    ("hair", ("S207",)),
    ("flower", ("G21901",)),
    ("repair", ("S206", "S205", "S201", "S202")),
    ("hardware", ("G210", "M11201")),
    ("realty", ("L10203",)),
    ("car", ("S203", "G202")),
    ("pet", ("M11101", "G22001", "S20704")),
]


def cat_of(code):
    for cat, pre in CAT_RULES:
        if code.startswith(pre):
            return cat
    return None


calls = Counter()


def get_json(url, tries=4):
    for t in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 yogikok"})
            with urllib.request.urlopen(req, timeout=90) as r:
                raw = r.read().decode("utf-8", "replace")
            return json.loads(raw)
        except urllib.error.HTTPError as e:
            body = e.read(300).decode("utf-8", "replace")
            if e.code in (401, 403) or "LIMITED" in body:
                print("  !! 막힘", e.code, body[:160])
                return None
            time.sleep(2 * (t + 1))
        except Exception as e:  # 잠깐 끊기면 쉬었다 다시
            if t == tries - 1:
                print("  !! 오류", repr(e)[:160])
                return None
            time.sleep(2 * (t + 1))
    return None


def dg(path, **q):
    calls[path.split("/")[0]] += 1
    q = {"serviceKey": KEY, **q}
    return get_json(f"https://apis.data.go.kr/{path}?" + urllib.parse.urlencode(q))


# ---------------- 1) 소상공인 상가정보 ----------------

def sdsc_page(code, page):
    j = dg("B553077/api/open/sdsc2/storeListInDong", divId="ctprvnCd", key=code, numOfRows=1000, pageNo=page, type="json")
    if not j or "body" not in j:
        return None, 0
    return j["body"].get("items") or [], int(j["body"].get("totalCount") or 0)


def sdsc_sido(code):
    first, total = sdsc_page(code, 1)
    if not first:
        return []
    pages = math.ceil(total / 1000)
    out = list(first)
    with ThreadPoolExecutor(8) as ex:
        for items, _ in ex.map(lambda p: sdsc_page(code, p), range(2, pages + 1)):
            if items is None:
                print("  !! 한 쪽 못 받음")
                continue
            out += items
    print(f"  상가 {len(out):,}/{total:,}곳 ({pages}쪽)")
    return out


def shop_of(it):
    c = cat_of(it.get("indsSclsCd") or "")
    if not c:
        return None
    try:
        x, y = float(it["lon"]), float(it["lat"])
    except Exception:
        return None
    name = (it.get("bizesNm") or "").strip()
    br = (it.get("brchNm") or "").strip()
    if br and br not in name:
        name = f"{name} {br}"
    return {
        "id": it.get("bizesId", ""),
        "n": name,
        "c": [c],
        "s": (it.get("indsSclsNm") or "").strip(),
        "a": (it.get("rdnmAdr") or it.get("lnoAdr") or "").strip(),
        "t": "",
        "y": round(y, 6),
        "x": round(x, 6),
        "_g": it.get("signguCd", ""),
        "_gn": it.get("signguNm", ""),
        "_d": it.get("adongCd", ""),
        "_dn": it.get("adongNm", ""),
        "_l": (it.get("ldongCd") or "")[:10],
    }


def pct(vals, p):
    v = sorted(vals)
    return v[min(len(v) - 1, max(0, int(len(v) * p)))]


def bbox_of(shops):
    xs, ys = [s["x"] for s in shops], [s["y"] for s in shops]
    pad = 0.004
    return [round(pct(xs, 0.005) - pad, 4), round(pct(ys, 0.005) - pad, 4), round(pct(xs, 0.995) + pad, 4), round(pct(ys, 0.995) + pad, 4)]


def split_dongs(dongs, limit):
    """행정동 [(코드, 이름, 가게 수, x, y)] 를 가까운 것끼리 묶어 limit 이하로 나눈다 (긴 쪽으로 반씩 자르기)."""
    n = sum(d[2] for d in dongs)
    if n <= limit or len(dongs) < 2:
        return [dongs]
    xs, ys = [d[3] for d in dongs], [d[4] for d in dongs]
    axis = 3 if (max(xs) - min(xs)) * 0.88 > (max(ys) - min(ys)) else 4
    dongs = sorted(dongs, key=lambda d: d[axis])
    acc, cut = 0, 1
    for i, d in enumerate(dongs):
        acc += d[2]
        if acc >= n / 2:
            cut = max(1, min(len(dongs) - 1, i + 1))
            break
    return split_dongs(dongs[:cut], limit) + split_dongs(dongs[cut:], limit)


def short_dong(nm):
    nm = re.sub(r"제?\d+(\.\d+)?(가)?동$", "", nm)
    nm = re.sub(r"(동|읍|면)$", "", nm) if len(nm) > 2 else nm
    return nm


def build_regions(sido_name, shops):
    by_g = defaultdict(list)
    for s in shops:
        by_g[s["_g"]].append(s)
    regions = []
    for g, lst in sorted(by_g.items()):
        gn = Counter(s["_gn"] for s in lst).most_common(1)[0][0]
        if g == "28185":  # 연수구는 예전 id 그대로 (앱에 저장된 단지·자료와 이어짐)
            parts = [("songdo", "송도/연수", lst)]
        else:
            dmap = defaultdict(list)
            for s in lst:
                dmap[s["_d"]].append(s)
            dongs = [(d, Counter(s["_dn"] for s in v).most_common(1)[0][0], len(v), sum(s["x"] for s in v) / len(v), sum(s["y"] for s in v) / len(v)) for d, v in dmap.items()]
            groups = split_dongs(dongs, SPLIT)
            if len(groups) == 1:
                parts = [(f"k{g}", gn, lst)]
            else:
                parts = []
                for i, grp in enumerate(groups, 1):
                    codes = {d[0] for d in grp}
                    big = max(grp, key=lambda d: d[2])
                    parts.append((f"k{g}_{i}", f"{gn} {short_dong(big[1])}", [s for s in lst if s["_d"] in codes]))
        for rid, name, ps in parts:
            bb = bbox_of(ps)
            regions.append({
                "id": rid, "name": name, "gu": gn,
                "lat": round((bb[1] + bb[3]) / 2, 5), "lng": round((bb[0] + bb[2]) / 2, 5),
                "bbox": bb, "zoom": 13, "ready": True, "collect": True, "updated": NOW, "count": len(ps),
                "_g": g, "_dongs": sorted({s["_d"] for s in ps}), "_ldongs": Counter(s["_l"] for s in ps), "_shops": ps,
            })
    return regions


# ---------------- 2) 아파트 (K-apt) ----------------

def kapt_list_sigungu(g):
    out, page = [], 1
    while True:
        j = dg("1613000/AptListService4/getSigunguAptList4", sigunguCode=g, pageNo=page, numOfRows=1000, _type="json")
        if not j:
            return None
        body = (j.get("response") or {}).get("body") or {}
        items = body.get("items") or []
        if isinstance(items, dict):
            items = items.get("item") or []
        if isinstance(items, dict):
            items = [items]
        out += items
        if len(out) >= int(body.get("totalCount") or 0) or not items:
            return out
        page += 1


KAPT_CACHE = {}


def kapt_basis(code):
    if code in KAPT_CACHE:
        return KAPT_CACHE[code]
    j = dg("1613000/AptBasisInfoServiceV5/getAphusBassInfoV5", kaptCode=code, _type="json")
    it = (((j or {}).get("response") or {}).get("body") or {}).get("item") if j else None
    KAPT_CACHE[code] = it if isinstance(it, dict) else None
    return KAPT_CACHE[code]


GEO = {}


def vworld(addr):
    if not VKEY or not addr:
        return None
    if addr in GEO:
        return GEO[addr]
    calls["vworld"] += 1
    q = {"service": "address", "request": "getcoord", "version": "2.0", "crs": "epsg:4326", "address": addr, "format": "json", "type": "road", "key": VKEY}
    j = get_json("https://api.vworld.kr/req/address?" + urllib.parse.urlencode(q), tries=2)
    try:
        p = j["response"]["result"]["point"]
        GEO[addr] = (float(p["y"]), float(p["x"]))
    except Exception:
        GEO[addr] = None
    return GEO[addr]


def road_key(a):
    """도로명주소에서 「시군구 도로명 건물번호」만 (동·호·괄호 빼고)."""
    a = re.sub(r"\(.*?\)", "", a or "")
    a = re.sub(r"(로|길)\s+(\d+번?[가-힣]*길)", r"\1\2", a)
    w = a.split()
    gu = w[1] if len(w) > 1 else ""
    m = re.search(r"(\S+(?:로|길))\s+(\d+(?:-\d+)?)", a)
    return f"{gu} {m.group(1)} {m.group(2)}" if m else ""


def kapt_all():
    out, page = [], 1
    while True:
        j = dg("1613000/AptListService4/getTotalAptList4", pageNo=page, numOfRows=1000, _type="json")
        if not j:
            return None if not out else out
        body = (j.get("response") or {}).get("body") or {}
        items = body.get("items") or []
        if isinstance(items, dict):
            items = items.get("item") or []
        if isinstance(items, dict):
            items = [items]
        out += items
        if len(out) >= int(body.get("totalCount") or 0) or not items:
            return out
        page += 1


def build_apts(regions, bld):
    """전국 단지를 한 번에 — 좌표(브이월드, 없으면 같은 건물 가게) → 법정동으로 동네, 못 찾으면 가장 가까운 동네."""
    lst = kapt_all()
    if lst is None:
        print("  K-apt 단지 목록 막힘 (활용신청 필요) — 아파트 건너뜀")
        return None
    print(f"  K-apt 단지 {len(lst):,}곳")
    reg_of_ldong = {}
    for r in regions:
        for ld, n in r["_ldongs"].items():
            if n > reg_of_ldong.get(ld, ("", 0))[1]:
                reg_of_ldong[ld] = (r["id"], n)
    with ThreadPoolExecutor(6) as ex:  # 기본정보 미리 (지난번 받아 둔 건 건너뜀)
        list(ex.map(lambda it: kapt_basis(it.get("kaptCode")), [it for it in lst if it.get("kaptCode") not in KAPT_CACHE]))
    todo = sorted({(KAPT_CACHE.get(it.get("kaptCode")) or {}).get("doroJuso", "").strip() for it in lst} - set(GEO) - {""})
    if VKEY:
        with ThreadPoolExecutor(6) as ex:
            list(ex.map(vworld, todo))
    apts = defaultdict(list)
    miss = 0
    for it in lst:
        code = it.get("kaptCode")
        b = KAPT_CACHE.get(code) or {}
        road = (b.get("doroJuso") or "").strip()
        yx = GEO.get(road) or bld.get(road_key(road))
        if not yx:
            miss += 1
            continue
        bjd = str(it.get("bjdCode") or b.get("bjdCode") or "")
        rid = reg_of_ldong.get(bjd, (None, 0))[0]
        if not rid:
            near = [r for r in regions if r["bbox"][0] <= yx[1] <= r["bbox"][2] and r["bbox"][1] <= yx[0] <= r["bbox"][3]]
            if not near:  # 이번에 만든 시도 밖 (시도만 골라 돌릴 때)
                continue
            rid = min(near, key=lambda r: (r["lat"] - yx[0]) ** 2 + (r["lng"] - yx[1]) ** 2)["id"]
        kind = (b.get("codeAptNm") or "").strip()
        apts[rid].append({"id": code, "n": (it.get("kaptName") or b.get("kaptName") or "").strip(), "k": "" if kind in ("", "아파트") else kind,
                          "a": road or (b.get("kaptAddr") or "").strip(), "t": (b.get("kaptTel") or "").strip(),
                          "h": int(b.get("kaptdaCnt") or 0), "y": round(yx[0], 6), "x": round(yx[1], 6)})
    print(f"  아파트 {sum(len(v) for v in apts.values()):,}단지 (좌표 못 찾음 {miss})")
    return apts


# ---------------- 3) 인허가 전화번호 ----------------
# 공공데이터포털 「행정안전부_○○ 조회서비스」 (업종마다 활용신청). 영업 중인 곳의 전화번호를 상호·도로명주소로 가게에 붙인다.
LICENSES = ["general_restaurants", "rest_cafes", "bakeries", "instant_food_processors", "livestock_retail",
            "beauty_salons", "barber_shops", "laundries", "public_baths", "building_sanitation",
            "pharmacies", "clinics", "hospitals", "optical_shops", "postpartum_care",
            "animal_hospitals", "pet_grooming", "animal_boarding",
            "fitness_centers", "martial_arts_dojo", "golf_practice_ranges", "karaoke_rooms", "pc_bangs"]


def norm_name(t):
    t = re.sub(r"\(.*?\)|주식회사|\(주\)|㈜|유한회사", "", t or "")
    return re.sub(r"[\s·\-_.,&]", "", t).lower()


def lic_page(svc, page):
    calls[svc] += 1
    q = {"serviceKey": KEY, "pageNo": page, "numOfRows": 100, "returnType": "json"}
    j = get_json(f"https://apis.data.go.kr/1741000/{svc}/info?" + urllib.parse.urlencode(q), tries=3)
    if not j:
        return None, 0
    body = (j.get("response") or {}).get("body") or {}
    items = (body.get("items") or {})
    items = items.get("item") if isinstance(items, dict) else items
    if isinstance(items, dict):
        items = [items]
    return items or [], int(body.get("totalCount") or 0)


def license_index():
    """도로명주소(도로명+번호) → [(상호, 전화)]  (영업 중이고 전화가 있는 곳만)"""
    idx = defaultdict(list)
    for svc in LICENSES:
        first, total = lic_page(svc, 1)
        if first is None:
            print(f"  인허가 {svc}: 막힘 (활용신청 필요)")
            continue
        pages = math.ceil(total / 100)
        n = 0

        def take(items):
            nonlocal n
            for it in items or []:
                if (it.get("SALS_STTS_CD") or "") not in ("01", "1", "") and "영업" not in (it.get("SALS_STTS_NM") or ""):
                    continue
                tel = re.sub(r"[^0-9-]", "", it.get("TELNO") or "")
                if len(re.sub(r"\D", "", tel)) < 8:
                    continue
                k = road_key(it.get("ROAD_NM_ADDR") or "")
                if k:
                    idx[k].append((norm_name(it.get("BPLC_NM")), tel))
                    n += 1
        take(first)
        with ThreadPoolExecutor(8) as ex:
            for items, _ in ex.map(lambda p: lic_page(svc, p), range(2, pages + 1)):
                take(items)
        print(f"  인허가 {svc}: {total:,}건 중 전화 {n:,}")
    return idx


def add_phones(shops, idx):
    hit = 0
    for s in shops:
        cands = idx.get(road_key(s["a"]))
        if not cands:
            continue
        n = norm_name(s["n"])
        n1 = norm_name(s["n"].split(" ")[0])
        for nm, tel in cands:
            if nm and (nm == n or (len(n1) >= 2 and (n1 in nm or nm in n))):
                s["t"] = tel
                hit += 1
                break
    return hit


# ---------------- 4) 공중화장실 (행정안전부 공중화장실정보) ----------------
# 2025-02부터 원천에서 좌표가 빠짐 → 도로명주소를 브이월드로 좌표로 바꾸고(없으면 같은 건물 가게 좌표), 동네별 toilet_<동네>.json

def toilet_all():
    first, total = None, 0
    def page(n):
        calls["toilet"] += 1
        q = {"serviceKey": KEY, "pageNo": n, "numOfRows": 100, "returnType": "json"}
        j = get_json("https://apis.data.go.kr/1741000/public_restroom_info_v2/info_v2?" + urllib.parse.urlencode(q), tries=4)
        body = (((j or {}).get("response") or {}).get("body") or {})
        items = (body.get("items") or {})
        items = items.get("item") if isinstance(items, dict) else items
        return (items if isinstance(items, list) else ([items] if items else [])), int(body.get("totalCount") or 0)
    first, total = page(1)
    if not total:
        print("  화장실 자료 못 받음")
        return []
    out = list(first)
    with ThreadPoolExecutor(6) as ex:
        for items, _ in ex.map(page, range(2, math.ceil(total / 100) + 1)):
            out += items
    print(f"  화장실 {len(out):,}/{total:,}곳")
    return out


def num(v):
    try:
        return int(float(v or 0))
    except Exception:
        return 0


def build_toilets(regions, bld):
    lst = toilet_all()
    if not lst:
        return None
    todo = sorted({(it.get("LCTN_ROAD_NM_ADDR") or "").strip() for it in lst} - set(GEO) - {""})
    if VKEY:
        with ThreadPoolExecutor(6) as ex:
            list(ex.map(vworld, todo))
    out = defaultdict(list)
    miss = 0
    for it in lst:
        road = (it.get("LCTN_ROAD_NM_ADDR") or "").strip()
        yx = GEO.get(road) or bld.get(road_key(road))
        if not yx:
            miss += 1
            continue
        near = [r for r in regions if r["bbox"][0] <= yx[1] <= r["bbox"][2] and r["bbox"][1] <= yx[0] <= r["bbox"][3]]
        if not near:
            continue
        rid = min(near, key=lambda r: (r["lat"] - yx[0]) ** 2 + (r["lng"] - yx[1]) ** 2)["id"]
        m = num(it.get("MALE_TOILT_CNT")) + num(it.get("MALE_URNL_CNT"))
        f = num(it.get("FEMALE_TOILT_CNT"))
        out[rid].append({
            "id": it.get("MNG_NO", ""), "n": (it.get("RSTRM_NM") or "").strip(), "k": (it.get("SE_NM") or "").strip(),
            "a": road or (it.get("LCTN_LOTNO_ADDR") or "").strip(),
            "h": (it.get("OPN_HR") or "").strip(), "hd": (it.get("OPN_HR_DTL") or "").strip(),
            "m": m, "f": f,
            "d": num(it.get("MALE_FRDBL_TOILT_CNT")) + num(it.get("FEMALE_FRDBL_TOILT_CNT")) > 0,
            "b": (it.get("DIAP_EXCHCON_EN") or "") == "Y", "e": (it.get("EMRGNCBLL_INSTL_YN") or "") == "Y",
            "c": (it.get("RSTRM_ENTRAN_CCTV_INSTL_EN") or "") == "Y",
            "o": (it.get("MNG_INST_NM") or "").strip(), "t": (it.get("TELNO") or "").strip(),
            "y": round(yx[0], 6), "x": round(yx[1], 6),
        })
    print(f"  화장실 위치 찾음 {sum(len(v) for v in out.values()):,}곳 (못 찾음 {miss:,})")
    return out

# ---------------- 저장 ----------------
# K-apt 기본정보·브이월드 좌표는 공공 자료라 다음 번을 위해 store 에 남겨 둔다 (하루 호출 한도 나눠 쓰기)
def load_caches():
    for name, d in (("_kapt.json", KAPT_CACHE), ("_geo.json", GEO)):
        try:
            for k, v in json.load(open(os.path.join(OUT, name), encoding="utf-8")).items():
                d[k] = tuple(v) if isinstance(v, list) else v
        except Exception:
            pass


def save_caches():
    dump("_kapt.json", {k: v for k, v in KAPT_CACHE.items() if v})
    dump("_geo.json", {k: v for k, v in GEO.items() if v})


def dump(name, obj):
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, separators=(",", ":"))


def main():
    if not KEY:
        print("DATA_GO_KR_KEY 가 없어 건너뜁니다.")
        return 0
    want = [x.strip() for x in os.environ.get("SIDO", "").split(",") if x.strip()]
    reg_path = os.path.join(OUT, "regions.json")
    try:
        reg = json.load(open(reg_path, encoding="utf-8"))
    except Exception:
        reg = {"sido": []}
    reg["note"] = "동네 목록 — 전국 시군구(큰 곳은 나눔). 소상공인 상가정보·K-apt·인허가로 만듦(카카오 자료는 저장하지 않음)."
    have = {s["name"]: s for s in reg.get("sido", [])}
    lic = license_index() if os.environ.get("PHONES", "1") == "1" and os.environ.get("REUSE") != "1" else {}
    load_caches()
    all_regions, bld = [], {}
    done_names = set()
    if os.environ.get("REUSE") == "1":  # 가게는 다시 받지 않고 store 에 있는 것으로 (화장실·아파트만 다시 만들 때)
        for sd in reg.get("sido", []):
            for r in sd.get("areas", []):
                try:
                    for sh in json.load(open(os.path.join(OUT, f"{r['id']}.json"), encoding="utf-8")).get("shops", []):
                        k = road_key(sh.get("a", ""))
                        if k and k not in bld:
                            bld[k] = (sh["y"], sh["x"])
                except Exception:
                    pass
                all_regions.append({**r, "_ldongs": Counter()})
        print(f"  다시 쓰기: 동네 {len(all_regions)}곳 · 건물 {len(bld):,}곳")
    for code, sname in ([] if os.environ.get("REUSE") == "1" else SIDO):
        if want and code not in want:
            continue
        print(f"[{sname} {code}]")
        raw = sdsc_sido(code)
        if not raw:
            continue
        shops = [s for s in (shop_of(it) for it in raw) if s]
        if lic:
            print(f"  전화번호 붙임 {add_phones(shops, lic):,}곳")
        regions = build_regions(sname, shops)
        for sh in shops:
            k = road_key(sh["a"])
            if k and k not in bld:
                bld[k] = (sh["y"], sh["x"])
        for r in regions:
            ps = sorted(r.pop("_shops"), key=lambda z: (z["c"][0], z["n"]))
            clean = [{k: v for k, v in x.items() if not k.startswith("_")} for x in ps]
            dump(f"{r['id']}.json", {"area": r["name"], "area_id": r["id"], "updated": NOW, "count": len(clean), "src": "소상공인시장진흥공단 상가(상권)정보", "shops": clean})
        all_regions += regions
        entry = {"name": sname, "areas": [{k: v for k, v in r.items() if not k.startswith("_")} for r in regions]}
        if sname in done_names:  # 강원 51·42 처럼 코드가 둘인 곳
            have[sname]["areas"] += entry["areas"]
        else:
            have[sname] = entry
            done_names.add(sname)
        print(f"  동네 {len(regions)}곳 · 가게 {len(shops):,}곳")
        del raw, shops
    if all_regions and os.environ.get("APTS", "1") == "1":
        apts = build_apts(all_regions, bld)
        if apts is not None:
            for r in all_regions:
                al = sorted(apts.get(r["id"], []), key=lambda z: z["n"])
                dump(f"apt_{r['id']}.json", {"area_id": r["id"], "updated": NOW, "src": "공동주택관리정보시스템(K-apt)", "apts": al})
    if all_regions and os.environ.get("TOILETS", "1") == "1":
        tl = build_toilets(all_regions, bld)
        if tl is not None:
            for r in all_regions:
                dump(f"toilet_{r['id']}.json", {"area_id": r["id"], "updated": NOW, "src": "행정안전부 공중화장실정보", "toilets": sorted(tl.get(r["id"], []), key=lambda z: z["n"])})
    save_caches()
    order = [n for _, n in SIDO]
    reg["sido"] = sorted(have.values(), key=lambda s: order.index(s["name"]) if s["name"] in order else 99)
    with open(reg_path, "w", encoding="utf-8") as f:
        json.dump(reg, f, ensure_ascii=False, indent=1)
    print("끝 · 부른 횟수", dict(calls))
    return 0


if __name__ == "__main__":
    sys.exit(main())
