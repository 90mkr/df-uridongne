"""쓰레기·분리수거 자료 모으기 (쓰레기·분리수거 방 소관).

1) 행정안전부 「생활쓰레기배출정보」 전국 파일(CSV, 지방행정 인허가 데이터개방)을 받아
   지자체(개방자치단체코드)별로 나눠 web/data/trash/g_<코드>.json 에 저장한다.
   - 관리구역마다: 배출 요일·시간, 배출 장소, 품목별 배출 방법, 대형(일시적 다량) 폐기물 방법,
     미수거일, 담당 부서·전화
2) 동네마다 아파트 단지(web/data/apt_<동네>.json, 본부가 모음)의 행정동·법정동을 카카오로 알아내
   그 단지가 속한 관리구역을 미리 짝지어 web/data/trash/apt_<동네>.json 에 저장한다.
   (같은 단지는 한 번 알아낸 동 이름을 _dong_cache.json 에 기억해 다시 묻지 않는다)

파일 받기가 실패하면 지난번 자료를 그대로 둔다 (지우지 않음).
"""
import csv
import glob
import io
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = os.path.join(ROOT, "web", "data")
OUT = os.path.join(DATA, "trash")
KST = timezone(timedelta(hours=9))
KAKAO = os.environ.get("KAKAO_REST_KEY", "").strip()
SRC_URL = "https://file.localdata.go.kr/file/download/household_waste_info/info"
UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36"

SIDO_SHORT = {
    "서울": "서울특별시", "부산": "부산광역시", "대구": "대구광역시", "인천": "인천광역시", "광주": "광주광역시",
    "대전": "대전광역시", "울산": "울산광역시", "세종": "세종특별자치시", "경기": "경기도", "강원": "강원특별자치도",
    "충북": "충청북도", "충남": "충청남도", "전북": "전북특별자치도", "전남": "전라남도", "경북": "경상북도",
    "경남": "경상남도", "제주": "제주특별자치도",
}


def now():
    return datetime.now(KST).strftime("%Y-%m-%d %H:%M")


def clean(s):
    s = (s or "").strip()
    return "" if s in ("없음", "-", "해당없음", "null") else re.sub(r"\s+", " ", s)


def days(s):
    """'일+월+화' → '일월화' (요일 글자만, 순서 일~토)"""
    s = s or ""
    return "".join(d for d in "일월화수목금토" if d in s)


def hm(s):
    s = (s or "").strip()
    m = re.match(r"^(\d{1,2}):(\d{2})", s)
    return f"{int(m.group(1)):02d}:{m.group(2)}" if m else ""


def dong_keys(text):
    """관리구역 글에서 동 이름을 뽑는다. '송도1,4,5동' → 송도1동·송도4동·송도5동, '만수1~3동' → 만수1동…"""
    out = set()
    t = text or ""
    for m in re.finditer(r"([가-힣]{1,6}?)\s?(\d+(?:\s*[,~·.]\s*\d+)*)\s?동", t):
        base, nums = m.group(1), m.group(2)
        parts = re.split(r"\s*[,·.]\s*", nums)
        for p in parts:
            if "~" in p:
                a, b = [int(x) for x in p.split("~")[:2]]
                for n in range(a, min(b, a + 20) + 1):
                    out.add(f"{base}{n}동")
            elif p.strip().isdigit():
                out.add(f"{base}{int(p)}동")
    for m in re.finditer(r"(?<![\d가-힣])([가-힣]{1,6}동)(?![가-힣])", t):
        w = m.group(1)
        if w not in ("행정동", "법정동", "전체동", "각동", "관내동"):
            out.add(w)
    for m in re.finditer(r"([가-힣]{1,5}[읍면])(?![가-힣])", t):
        out.add(m.group(1))
    return sorted(out)


def download():
    req = urllib.request.Request(SRC_URL, headers={"User-Agent": UA, "Referer": "https://file.localdata.go.kr/file/household_waste_info/info"})
    for tryn in range(3):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                raw = r.read()
            for enc in ("cp949", "utf-8-sig"):
                try:
                    txt = raw.decode(enc)
                    if "개방자치단체코드" in txt[:500]:
                        return txt
                except UnicodeDecodeError:
                    continue
            print("  받은 파일 모양이 달라요:", raw[:80])
            return None
        except Exception as e:
            print("  파일 받기 오류:", e)
            time.sleep(5 * (tryn + 1))
    return None


def build_zones(txt):
    rows = list(csv.DictReader(io.StringIO(txt)))
    by = {}
    for r in rows:
        code = (r.get("개방자치단체코드") or "").strip()
        sido, gu = clean(r.get("시도명")), clean(r.get("시군구명"))
        if not code or not sido:
            continue
        g = by.setdefault(code, {"code": code, "sido": sido, "gu": gu, "zones": []})
        zname, target = clean(r.get("관리구역명")), clean(r.get("관리구역대상지역명"))
        z = {
            "id": (r.get("관리번호") or "").strip(),
            "n": zname,
            "t": target,
            "k": dong_keys(f"{zname} {target}"),
            "pt": clean(r.get("배출장소유형")),
            "pl": clean(r.get("배출장소")),
            "m": {
                "g": clean(r.get("생활쓰레기배출방법")),
                "f": clean(r.get("음식물쓰레기배출방법")),
                "r": clean(r.get("재활용품배출방법")),
                "b": clean(r.get("일시적다량폐기물배출방법")),
            },
            "bp": clean(r.get("일시적다량폐기물배출장소")),
            "d": {
                "g": days(r.get("생활쓰레기배출요일")),
                "f": days(r.get("음식물쓰레기배출요일")),
                "r": days(r.get("재활용품배출요일")),
            },
            "h": {
                "g": [hm(r.get("생활쓰레기배출시작시각")), hm(r.get("생활쓰레기배출종료시각"))],
                "f": [hm(r.get("음식물쓰레기배출시작시각")), hm(r.get("음식물쓰레기배출종료시각"))],
                "r": [hm(r.get("재활용품배출시작시각")), hm(r.get("재활용품배출종료시각"))],
                "b": [hm(r.get("일시적다량폐기물배출시작시각")), hm(r.get("일시적다량폐기물배출종료시각"))],
            },
            "off": clean(r.get("미수거일")),
            "dept": clean(r.get("관리부서명")),
            "tel": clean(r.get("관리부서전화번호")),
            "date": clean(r.get("데이터기준일자")),
        }
        g["zones"].append(z)
    return by


def kakao_region(lng, lat):
    url = "https://dapi.kakao.com/v2/local/geo/coord2regioncode.json?" + urllib.parse.urlencode({"x": lng, "y": lat})
    req = urllib.request.Request(url, headers={"Authorization": f"KakaoAK {KAKAO}"})
    for tryn in range(3):
        try:
            with urllib.request.urlopen(req, timeout=15) as r:
                j = json.loads(r.read().decode("utf-8"))
            out = {}
            for d in j.get("documents", []):
                t = d.get("region_type")
                out["s"] = d.get("region_1depth_name", "")
                out["gu"] = d.get("region_2depth_name", "")
                if t == "B":
                    out["b"] = d.get("region_3depth_name", "")
                elif t == "H":
                    out["h"] = d.get("region_3depth_name", "")
            return out
        except Exception as e:
            if tryn == 2:
                print("  카카오 오류:", e)
                return None
            time.sleep(1.5 * (tryn + 1))


def gu_core(gu):
    # '수원시 장안구' → '장안구', '연수구' → '연수구'
    return (gu or "").split()[-1] if gu else ""


def match(groups, info):
    """단지의 시도·구·행정동·법정동으로 관리구역 후보를 고른다 → (코드, [관리번호…])"""
    sido = info.get("s", "")
    sido = SIDO_SHORT.get(sido[:2], sido) if len(sido) <= 3 else sido
    gu = gu_core(info.get("gu", ""))
    h, b = info.get("h", ""), info.get("b", "")
    in_sido = [g for g in groups.values() if g["sido"][:2] == sido[:2]]
    # 1) 행정동이 이름에 들어간 구역 (구 이름이 바뀐 곳도 잡히도록 시도 전체에서)
    for key in (h, b, re.sub(r"\d+(·\d+)*", "", h)):
        if not key:
            continue
        hits = [(g, z) for g in in_sido for z in g["zones"] if key in z["k"]]
        if hits:
            same = [x for x in hits if gu_core(x[0]["gu"]) == gu] or hits
            code = same[0][0]["code"]
            return code, [z["id"] for g, z in same if g["code"] == code]
    # 2) 같은 구
    gs = [g for g in in_sido if gu_core(g["gu"]) == gu or (gu and gu in g["gu"])]
    if gs:
        g = gs[0]
        if len(g["zones"]) == 1:
            return g["code"], [g["zones"][0]["id"]]
        return g["code"], []
    return None, []


def write_groups(groups):
    print(f"  지자체 {len(groups)}곳, 관리구역 {sum(len(g['zones']) for g in groups.values())}개")
    stamp = now()
    for code, g in groups.items():
        g["updated"] = stamp
        with open(os.path.join(OUT, f"g_{code}.json"), "w", encoding="utf-8") as f:
            json.dump(g, f, ensure_ascii=False, separators=(",", ":"))
    idx = {"updated": stamp, "src": "행정안전부 생활쓰레기배출정보", "gu": [[g["code"], g["sido"], g["gu"], len(g["zones"])] for g in groups.values()]}
    with open(os.path.join(OUT, "index.json"), "w", encoding="utf-8") as f:
        json.dump(idx, f, ensure_ascii=False, separators=(",", ":"))


def main():
    os.makedirs(OUT, exist_ok=True)
    txt = download()
    if txt:
        write_groups(build_zones(txt))
    elif not glob.glob(os.path.join(OUT, "g_*.json")):
        # 처음인데 받지 못했으면 저장소에 넣어 둔 수도권 첫 자료(seed_*.csv)로 만든다
        for p in glob.glob(os.path.join(OUT, "seed_*.csv")):
            write_groups(build_zones(open(p, encoding="utf-8").read()))
    else:
        print("  생활쓰레기배출정보를 받지 못해 지난 자료를 그대로 둡니다")
    # 단지 → 관리구역 짝짓기
    groups = {}
    for p in glob.glob(os.path.join(OUT, "g_*.json")):
        try:
            g = json.load(open(p, encoding="utf-8"))
            groups[g["code"]] = g
        except Exception:
            pass
    if not groups:
        return
    cpath = os.path.join(OUT, "_dong_cache.json")
    try:
        cache = json.load(open(cpath, encoding="utf-8"))
    except Exception:
        cache = {}
    calls = 0
    for p in sorted(glob.glob(os.path.join(DATA, "apt_*.json"))):
        area = os.path.basename(p)[4:-5]
        try:
            apts = json.load(open(p, encoding="utf-8")).get("apts", [])
        except Exception:
            continue
        out = {}
        for a in apts:
            aid = str(a.get("id"))
            info = cache.get(aid)
            if info is None and KAKAO and a.get("x") is not None:
                info = kakao_region(a["x"], a["y"])
                calls += 1
                if info:
                    cache[aid] = info
            if not info:
                continue
            code, zs = match(groups, info)
            if code:
                out[aid] = {"c": code, "z": zs, "h": info.get("h", ""), "b": info.get("b", "")}
        with open(os.path.join(OUT, f"apt_{area}.json"), "w", encoding="utf-8") as f:
            json.dump({"updated": now(), "apts": out}, f, ensure_ascii=False, separators=(",", ":"))
        print(f"  {area}: 단지 {len(apts)}곳 중 {len(out)}곳 구역 짝지음")
    with open(cpath, "w", encoding="utf-8") as f:
        json.dump(cache, f, ensure_ascii=False, separators=(",", ":"))
    print(f"  카카오 동 조회 {calls}번")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # 다른 기능에 영향 없게
        print("!! 쓰레기 자료 모으기 실패:", e)
        sys.exit(0)
