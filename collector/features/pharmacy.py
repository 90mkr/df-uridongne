"""지금 문 연 약국 — 자료 모으기 (이 파일은 약국 담당 방만 고침)

국립중앙의료원 공공데이터(공공데이터포털)에서 전국 약국·소아청소년과·응급실의
요일별 운영시간을 받아 web/data/pharmacy/ 에 저장한다. 앱은 이 운영시간으로
「지금 열었는지」를 직접 계산한다 (운영시간은 자주 안 바뀌므로 매주 한 번이면 충분).

    DATA_GO_KR_KEY   공공데이터포털 인증키 (깃허브 비밀)

저장 파일
    web/data/pharmacy/t_<위도×10>_<경도×10>.json   0.1도 칸마다 약국(p)·소아과(h)
    web/data/pharmacy/er.json                         전국 응급실(e)
    web/data/pharmacy/meta.json                       갱신 시각·개수·공휴일

운영시간은 8칸 목록: 월 화 수 목 금 토 일 공휴일, 각 칸은 "0900-2200" (닫는 시각이
여는 시각보다 작으면 다음 날 새벽까지) 또는 "" (그날 쉼).
"""
import json
import math
import os
import sys
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone

KEY = os.environ.get("DATA_GO_KR_KEY", "").strip()
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "web", "data", "pharmacy")
KST = timezone(timedelta(hours=9))
BASE = "https://apis.data.go.kr/B552657"

PHARM = f"{BASE}/ErmctInsttInfoInqireService/getParmacyListInfoInqire"
HOSP = f"{BASE}/HsptlAsembySearchService/getHsptlMdcncListInfoInqire"
ER = f"{BASE}/ErmctInfoInqireService/getEgytListInfoInqire"
HOLI = "https://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService/getRestDeInfo"

# 특일 API가 안 될 때 쓰는 공휴일 (대체공휴일 포함)
HOLIDAYS_FALLBACK = [
    "2026-01-01", "2026-02-16", "2026-02-17", "2026-02-18", "2026-03-01", "2026-03-02", "2026-05-05",
    "2026-05-24", "2026-05-25", "2026-06-03", "2026-06-06", "2026-08-15", "2026-08-17", "2026-09-24",
    "2026-09-25", "2026-09-26", "2026-10-03", "2026-10-05", "2026-10-09", "2026-12-25",
    "2027-01-01", "2027-02-06", "2027-02-07", "2027-02-08", "2027-02-09", "2027-03-01", "2027-05-05",
    "2027-05-13", "2027-06-06", "2027-08-15", "2027-08-16", "2027-09-14", "2027-09-15", "2027-09-16",
    "2027-10-03", "2027-10-04", "2027-10-09", "2027-10-11", "2027-12-25", "2027-12-27",
]

calls = 0
LOG = []  # 사람이 볼 기록 (status.json 에 남김)


def log(*a):
    m = " ".join(str(x) for x in a)
    print(m, flush=True)
    LOG.append(m)


def fetch(url, params, tries=3):
    """공공데이터 한 번 부르기 → (item 목록, 전체 개수). 실패하면 None."""
    global calls
    q = "serviceKey=" + (KEY if "%" in KEY else urllib.parse.quote(KEY, safe="")) + "&" + urllib.parse.urlencode(params)
    for n in range(tries):
        try:
            calls += 1
            with urllib.request.urlopen(f"{url}?{q}", timeout=40) as r:
                raw = r.read()
            text = raw.decode("utf-8", "replace").strip()
            if text.startswith("{"):
                j = json.loads(text)
                body = j.get("response", {}).get("body", {})
                items = body.get("items") or {}
                items = items.get("item", []) if isinstance(items, dict) else items
                if isinstance(items, dict):
                    items = [items]
                return [{k: ("" if v is None else str(v)) for k, v in it.items()} for it in items], int(body.get("totalCount") or 0)
            root = ET.fromstring(raw)
            code = (root.findtext(".//resultCode") or "").strip()
            if code and code not in ("00", "0000"):
                log("  응답 오류:", url.rsplit("/", 1)[-1], code, root.findtext(".//resultMsg"), root.findtext(".//returnAuthMsg"))
                return None
            if root.find(".//returnAuthMsg") is not None:
                log("  인증 오류:", url.rsplit("/", 1)[-1], root.findtext(".//returnAuthMsg"), root.findtext(".//returnReasonCode"))
                return None
            items = [{c.tag: (c.text or "").strip() for c in it} for it in root.iter("item")]
            return items, int(root.findtext(".//totalCount") or 0)
        except Exception as e:
            if n == tries - 1:
                log("  부르기 실패:", url.rsplit("/", 1)[-1], e)
                return None
            time.sleep(2 * (n + 1))


def fetch_all(url, extra=None, rows=1000, limit=200):
    """첫 쪽으로 전체 개수를 알아낸 뒤 나머지 쪽은 여러 개를 함께 받는다."""
    t0 = time.time()
    first = fetch(url, {**(extra or {}), "pageNo": 1, "numOfRows": rows})
    if first is None:
        return []
    out, total = list(first[0]), first[1]
    got = len(first[0]) or rows
    pages = min(limit, -(-total // got)) if total else 1
    if pages > 1:
        with ThreadPoolExecutor(max_workers=6) as ex:
            res = list(ex.map(lambda pg: fetch(url, {**(extra or {}), "pageNo": pg, "numOfRows": got}), range(2, pages + 1)))
        for r in res:
            if r is not None:
                out += r[0]
    log(f"  {url.rsplit('/', 1)[-1]} {extra or ''}: {len(out)}곳 (전체 {total}, {pages}쪽, {time.time() - t0:.0f}초)")
    return out


def hhmm(v):
    v = (v or "").strip().replace(":", "")
    if not v.isdigit():
        return ""
    v = v.zfill(4)[-4:]
    h, m = int(v[:2]), int(v[2:])
    if h > 48 or m > 59:
        return ""
    return f"{h:02d}{m:02d}"


def hours(it):
    out = []
    for d in range(1, 9):
        s, c = hhmm(it.get(f"dutyTime{d}s")), hhmm(it.get(f"dutyTime{d}c"))
        out.append(f"{s}-{c}" if s and c and s != c else "")
    return out


def num(v):
    try:
        f = float(v)
        return f if math.isfinite(f) else None
    except (TypeError, ValueError):
        return None


def place(it, kind):
    y, x = num(it.get("wgs84Lat")), num(it.get("wgs84Lon"))
    if y is None or x is None or not (32 < y < 39.5 and 124 < x < 132):
        return None
    p = {
        "id": it.get("hpid", ""),
        "k": kind,
        "n": it.get("dutyName", "").strip(),
        "a": it.get("dutyAddr", "").strip(),
        "t": it.get("dutyTel1", "").strip(),
        "y": round(y, 6),
        "x": round(x, 6),
    }
    if kind != "e":
        p["h"] = hours(it)
    if kind == "h":
        p["d"] = it.get("dutyDivNam", "").strip()  # 의원·병원 등
    if kind == "e":
        p["t2"] = it.get("dutyTel3", "").strip()  # 응급실 직통
        p["d"] = (it.get("dutyEmclsName") or it.get("dutyEmcls") or "").strip()
    return p if p["n"] else None


def holidays():
    days = set()
    now = datetime.now(KST)
    for y in (now.year, now.year + 1):
        for m in range(1, 13):
            r = fetch(HOLI, {"solYear": y, "solMonth": f"{m:02d}", "numOfRows": 50}, tries=2)
            if r is None:
                return sorted(HOLIDAYS_FALLBACK), "기본 목록"
            for it in r[0]:
                d = it.get("locdate", "")
                if len(d) == 8 and it.get("isHoliday", "Y") == "Y":
                    days.add(f"{d[:4]}-{d[4:6]}-{d[6:]}")
    return sorted(days | set(HOLIDAYS_FALLBACK)), "특일 정보"


def save(name, obj, pretty=False):
    with open(os.path.join(OUT, name), "w", encoding="utf-8") as fp:
        json.dump(obj, fp, ensure_ascii=False, indent=1 if pretty else None, separators=None if pretty else (",", ":"))


def status(state):
    try:
        os.makedirs(OUT, exist_ok=True)
        save("status.json", {"at": datetime.now(KST).strftime("%Y-%m-%d %H:%M"), "state": state, "calls": calls, "log": LOG[-40:]}, pretty=True)
    except Exception as e:
        print("기록 저장 실패:", e)


def main():
    if not KEY:
        log("약국: 공공데이터 열쇠(DATA_GO_KR_KEY)가 없어 건너뜀")
        status("열쇠 없음")
        return
    os.makedirs(OUT, exist_ok=True)
    status("모으는 중")

    # 1) 약국 → 바로 저장 (소아과·응급실이 실패해도 약국은 남게)
    pharm = [p for p in (place(it, "p") for it in fetch_all(PHARM)) if p]
    if len(pharm) < 1000:
        log(f"약국 자료가 너무 적어({len(pharm)}곳) 지난 자료를 그대로 둠")
        status("약국 실패")
        return
    kids = [p for p in (place(it, "h") for it in fetch_all(HOSP, {"QD": "D002"})) if p]
    if not kids:
        # 지난 소아과 자료는 칸 파일 안에 있으니, 이번에 못 받으면 지난 칸에서 꺼내 다시 넣는다
        for f in os.listdir(OUT):
            if f.startswith("t_") and f.endswith(".json"):
                try:
                    kids += [x for x in json.load(open(os.path.join(OUT, f), encoding="utf-8")).get("items", []) if x.get("k") == "h"]
                except Exception:
                    pass
        log(f"  소아과는 지난 자료 {len(kids)}곳 유지")

    tiles = {}
    seen = set()
    for p in pharm + kids:
        key = (p["k"], p["id"] or p["n"] + p["a"])
        if key in seen:
            continue
        seen.add(key)
        t = f"t_{math.floor(p['y'] * 10)}_{math.floor(p['x'] * 10)}"
        tiles.setdefault(t, []).append(p)
    for f in os.listdir(OUT):
        if f.startswith("t_") and f.endswith(".json"):
            os.remove(os.path.join(OUT, f))
    for t, items in tiles.items():
        save(f"{t}.json", {"items": items})

    # 2) 응급실
    ers = [p for p in (place(it, "e") for it in fetch_all(ER)) if p]
    if len(ers) >= 100:
        save("er.json", {"items": ers})

    # 3) 공휴일
    holi, holi_src = holidays()
    save("meta.json", {
        "updated": datetime.now(KST).strftime("%Y-%m-%d %H:%M"),
        "source": "국립중앙의료원 (공공데이터포털)",
        "pharmacy": len(pharm),
        "kids": len(kids),
        "er": len(ers),
        "tiles": len(tiles),
        "holidays": holi,
        "holidaySource": holi_src,
    }, pretty=True)
    log(f"약국 {len(pharm)} · 소아과 {len(kids)} · 응급실 {len(ers)} · 칸 {len(tiles)} · 부른 횟수 {calls} · 공휴일 {holi_src}")
    status("완료")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # 다른 기능에 영향이 없게
        log("약국 자료 모으기 실패:", e)
        status("실패")
        sys.exit(0)
