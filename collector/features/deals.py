"""우리 단지 실거래가·전월세 모으기 (실거래가 방만 고침).

국토교통부 실거래가(공공데이터포털)를 시군구별·달별로 받아 단지별로 묶어
web/data/deals/<시군구코드>.json 에 저장한다. 앱은 고른 단지의 시군구 파일 하나만 받는다.

  - 아파트 매매(상세)  RTMSDataSvcAptTradeDev
  - 아파트 전월세      RTMSDataSvcAptRent
  - 오피스텔 매매·전월세 RTMSDataSvcOffiTrade · RTMSDataSvcOffiRent (활용신청이 안 돼 있으면 건너뜀)
  - K-apt 시군구 단지 목록(AptListService4) → 단지 코드(kaptCode)를 붙여 앱이 「단지 정보」를 부를 수 있게

시군구 목록은 본부 「전국 자료」의 store/regions.json 에서 (k<시군구코드> 동네 id).
최근 3달은 하루 한 번 다시 받고(신고가 30일 늦게 들어옴), 그보다 오래된 달은 한 번만 받는다.
한 번에 다 못 받으면 시간 한도(DEALS_BUDGET 초, 기본 1500)에서 멈추고 다음 실행이 이어 받는다.

    DATA_GO_KR_KEY   공공데이터포털 열쇠 (깃허브 비밀)
    DEALS_SGG        이 시군구만 (쉼표로, 시험용) — 비우면 전국
"""
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone

KEY = os.environ.get("DATA_GO_KR_KEY", "").strip()
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "web", "data", "deals")
KST = timezone(timedelta(hours=9))
NOW = datetime.now(KST)
START = time.time()
BUDGET = int(os.environ.get("DEALS_BUDGET", "1500") or 1500)
MONTHS = 13  # 1년 흐름 + 이번 달
RECENT = 3  # 최근 몇 달은 매일 다시
RENT_KEEP = 80  # 단지마다 전월세는 최근 몇 건만
STORE = "https://raw.githubusercontent.com/90mkr/df-uridongne/store/"

APIS = {
    # 종류: (주소, 아파트냐)
    "as": ("1613000/RTMSDataSvcAptTradeDev/getRTMSDataSvcAptTradeDev", True),
    "ar": ("1613000/RTMSDataSvcAptRent/getRTMSDataSvcAptRent", True),
    "os": ("1613000/RTMSDataSvcOffiTrade/getRTMSDataSvcOffiTrade", False),
    "or": ("1613000/RTMSDataSvcOffiRent/getRTMSDataSvcOffiRent", False),
}

# store/regions.json 이 아직 안 만든 시도(광주·전남) — 미리 넣어 둠
EXTRA_SGG = ["29110", "29140", "29155", "29170", "29200",
             "46110", "46130", "46150", "46170", "46230", "46710", "46720", "46730", "46770", "46780", "46790", "46800",
             "46810", "46820", "46830", "46840", "46860", "46870", "46880", "46890", "46900", "46910"]

blocked = set()  # 활용신청이 안 된 자료
calls = {k: 0 for k in APIS}
calls["kapt"] = 0


def keys():
    return [KEY] if "%" in KEY else [urllib.parse.quote(KEY, safe=""), KEY]


def fetch(path, q):
    """공공데이터 부르기 → (items[dict], totalCount) · 막히면 None"""
    last = None
    for k in keys():
        for tryn in range(3):
            try:
                url = f"https://apis.data.go.kr/{path}?serviceKey={k}&" + urllib.parse.urlencode(q)
                req = urllib.request.Request(url, headers={"User-Agent": "df-uridongne"})
                with urllib.request.urlopen(req, timeout=40) as r:
                    txt = r.read().decode("utf-8", "replace")
                t = txt.lstrip()
                if t.startswith("{"):
                    j = json.loads(t)
                    root = j.get("response", j)
                    head = root.get("header", {}) or {}
                    code = str(head.get("resultCode", "00"))
                    if code not in ("00", "000", "0", "03"):
                        last = f"결과 {code} {head.get('resultMsg')}"
                        break
                    body = root.get("body", {}) or {}
                    items = body.get("items") or []
                    if isinstance(items, dict):
                        items = items.get("item") or []
                    if isinstance(items, dict):
                        items = [items]
                    return items, int(body.get("totalCount") or 0)
                if not t.startswith("<"):
                    last = "알 수 없는 응답: " + t[:120]
                    break
                x = ET.fromstring(t)
                code = (x.findtext(".//resultCode") or "").strip()
                if x.tag == "OpenAPI_ServiceResponse" or (code and code not in ("00", "000", "0", "03")):
                    last = "막힘: " + re.sub(r"\s+", " ", t[:220])
                    break
                items = [{c.tag: (c.text or "").strip() for c in it} for it in x.iter("item")]
                return items, int((x.findtext(".//totalCount") or "0").strip() or 0)
            except urllib.error.HTTPError as e:
                last = f"HTTP {e.code}"
                if e.code in (401, 403):
                    break
                time.sleep(2 * (tryn + 1))
            except Exception as e:
                last = str(e)[:160]
                time.sleep(2 * (tryn + 1))
    print("    !!", path.split("/")[1], q.get("LAWD_CD") or q.get("sigunguCode"), q.get("DEAL_YMD", ""), last)
    return None


def fetch_all(kind, sgg, ym):
    path = APIS[kind][0]
    out, page = [], 1
    while True:
        calls[kind] += 1
        r = fetch(path, {"LAWD_CD": sgg, "DEAL_YMD": ym, "pageNo": page, "numOfRows": 1000})
        if r is None:
            return None
        items, total = r
        out += items
        if len(out) >= total or not items or page > 30:
            return out
        page += 1


# ---------------- 다듬기 ----------------

def num(v):
    try:
        s = str(v).replace(",", "").strip()
        return int(float(s)) if s else 0
    except Exception:
        return 0


def g(it, *names):
    for n in names:
        v = it.get(n)
        if v not in (None, ""):
            return str(v).strip()
    return ""


def jibun_of(it):
    j = g(it, "jibun", "지번")
    if j:
        return j
    b, s = num(g(it, "bonbun")), num(g(it, "bubun"))
    return f"{b}-{s}" if b and s else (str(b) if b else "")


def road_of(it):
    nm = g(it, "roadNm", "도로명")
    b, s = num(g(it, "roadNmBonbun", "도로명건물본번호코드")), num(g(it, "roadNmBubun", "도로명건물부번호코드"))
    if not nm or not b:
        return ""
    return f"{nm} {b}" + (f"-{s}" if s else "")


def ymd(it):
    y, m, d = num(g(it, "dealYear", "년")), num(g(it, "dealMonth", "월")), num(g(it, "dealDay", "일"))
    return y * 10000 + m * 100 + d if y else 0


def area100(it):
    try:
        return round(float(g(it, "excluUseAr", "전용면적") or 0) * 100)
    except Exception:
        return 0


def apt_key(it):
    return f"{g(it, 'umdNm', '법정동')}|{jibun_of(it)}|{g(it, 'aptNm', 'offiNm', '아파트', '단지')}"


def norm(s):
    s = re.sub(r"\(.*?\)|\[.*?\]", "", s or "")
    s = re.sub(r"아파트|오피스텔|APT|apt|단지|\s|-|·|,|\.", "", s)
    return s.lower()


# ---------------- 저장된 자료 ----------------

def load(sgg):
    try:
        d = json.load(open(os.path.join(OUT, f"{sgg}.json"), encoding="utf-8"))
    except Exception:
        return {}
    apts = {}
    for a in d.get("apts", []):
        apts[a["key"]] = a
    return apts


def save(sgg, apts, months):
    os.makedirs(OUT, exist_ok=True)
    lo = int(months[-1]) * 100
    out = []
    for a in apts.values():
        a["s"] = sorted([x for x in a.get("s", []) if x[0] >= lo], key=lambda x: -x[0])
        a["e"] = sorted([x for x in a.get("e", []) if x[0] >= lo], key=lambda x: -x[0])[:RENT_KEEP]
        if a["s"] or a["e"]:
            out.append(a)
    out.sort(key=lambda a: (a.get("u", ""), a.get("n", "")))
    with open(os.path.join(OUT, f"{sgg}.json"), "w", encoding="utf-8") as f:
        json.dump({"sgg": sgg, "updated": NOW.strftime("%Y-%m-%d %H:%M"), "src": "국토교통부 실거래가 공개시스템",
                   "apts": out}, f, ensure_ascii=False, separators=(",", ":"))


def merge(apts, kind, ym, items):
    """그 달·그 종류 거래를 지우고 새로 받은 것으로 채운다"""
    lo, hi = int(ym) * 100, int(ym) * 100 + 99
    field = "s" if kind.endswith("s") else "e"
    is_apt = APIS[kind][1]
    for a in apts.values():
        if a.get("o", 0) == (0 if is_apt else 1):
            a[field] = [x for x in a.get(field, []) if not (lo <= x[0] <= hi)]
    for it in items:
        d = ymd(it)
        if not d:
            continue
        if field == "s" and g(it, "cdealType", "해제여부") in ("O", "o"):
            continue  # 계약 해제된 거래
        k = apt_key(it) + ("" if is_apt else "|o")
        a = apts.get(k)
        if a is None:
            a = apts[k] = {"key": k, "n": g(it, "aptNm", "offiNm", "아파트", "단지"), "u": g(it, "umdNm", "법정동"), "j": jibun_of(it),
                           "s": [], "e": []}
            if not is_apt:
                a["o"] = 1
        bc = g(it, "sggCd") + g(it, "umdCd")
        if len(bc) == 10:
            a["d"] = bc
        r = road_of(it)
        if r:
            a["r"] = r
        by = num(g(it, "buildYear", "건축년도"))
        if by:
            a["b"] = by
        fl = num(g(it, "floor", "층"))
        if field == "s":
            a["s"].append([d, area100(it), fl, num(g(it, "dealAmount", "거래금액"))])
        else:
            dep, mon = num(g(it, "deposit", "보증금액", "보증금")), num(g(it, "monthlyRent", "월세금액", "월세"))
            renew = 1 if "갱신" in g(it, "contractType", "계약구분") else 0
            a["e"].append([d, area100(it), fl, dep, mon, renew])


# ---------------- K-apt 단지 코드 붙이기 ----------------

def kapt_list(sgg):
    out, page = [], 1
    while page < 20:
        calls["kapt"] += 1
        r = fetch("1613000/AptListService4/getSigunguAptList4", {"sigunguCode": sgg, "pageNo": page, "numOfRows": 1000, "_type": "json"})
        if r is None:
            return None
        items, total = r
        out += items
        if len(out) >= total or not items:
            break
        page += 1
    return out


def _stems(*words):
    out = set()
    for w in words:
        for x in (w or "").split():
            x = re.sub(r"\d*(동|읍|면|리|가)$", "", x)
            if len(x) >= 2:
                out.add(x.lower())
    return out


def _name_eq(n, kn, stems):
    if not n or not kn:
        return 0
    if n == kn:
        return 3
    for st in stems:  # 앞에 붙은 동네 이름(송도·기장 등)은 빼고 다시
        if n.startswith(st):
            n2 = n[len(st):]
            if n2 == kn or (kn.startswith(st) and n2 == kn[len(st):]):
                return 2
        if kn.startswith(st) and kn[len(st):] == n:
            return 2
    if (n in kn or kn in n) and min(len(n), len(kn)) >= 4:
        return 1
    return 0


def attach_kapt(apts, klist):
    by_umd, alln = {}, []
    for k in klist or []:
        a3, a4 = g(k, "as3"), g(k, "as4")
        item = (norm(g(k, "kaptName")), g(k, "kaptCode"), _stems(a3, a4, g(k, "as2")))
        alln.append(item)
        for key in {a3, a4, f"{a3} {a4}".strip(), "#" + g(k, "bjdCode")} - {"", "#"}:
            by_umd.setdefault(key, []).append(item)
    for a in apts.values():
        if a.get("o"):
            continue
        n = norm(a.get("n"))
        if not n:
            continue
        u = a.get("u", "")
        cands = []
        for key in {u, u.split()[-1] if u else "", u.split()[0] if u else "", "#" + a.get("d", "")} - {"", "#"}:
            cands += by_umd.get(key, [])
        best, bs = None, 0
        for kn, code, st in cands:
            sc = _name_eq(n, kn, st | _stems(u))
            if sc > bs:
                best, bs = code, sc
        if not best:  # 동 이름이 달라도 시군구 안에서 이름이 딱 맞는 곳이 하나면
            for need in (2, 1):
                same = {code for kn, code, st in alln if _name_eq(n, kn, st | _stems(u)) >= need}
                if len(same) == 1:
                    best = same.pop()
                    break
        if best:
            a["k"] = best


# ---------------- 시군구 목록 ----------------

def sgg_list():
    only = [s.strip() for s in os.environ.get("DEALS_SGG", "").split(",") if s.strip()]
    if only:
        return only
    s = set(EXTRA_SGG)
    try:
        req = urllib.request.Request(STORE + "regions.json", headers={"User-Agent": "df-uridongne"})
        with urllib.request.urlopen(req, timeout=40) as r:
            d = json.loads(r.read().decode("utf-8"))
        for sd in d.get("sido", []):
            for a in sd.get("areas", []):
                m = re.match(r"k(\d{5})", a.get("id", ""))
                if m:
                    s.add(m.group(1))
                elif a.get("id") == "songdo":
                    s.add("28185")
    except Exception as e:
        print("  !! 동네 목록 못 받음:", e)
        s.add("28185")
    # 우리 단지(송도)부터
    return sorted(s, key=lambda x: (x != "28185", x))


def month_list():
    out = []
    y, m = NOW.year, NOW.month
    for _ in range(MONTHS):
        out.append(f"{y}{m:02d}")
        m -= 1
        if m == 0:
            y, m = y - 1, 12
    return out


def main():
    if not KEY:
        print("  열쇠(DATA_GO_KR_KEY) 없음 — 건너뜀")
        return
    os.makedirs(OUT, exist_ok=True)
    stp = os.path.join(OUT, "_state.json")
    try:
        state = json.load(open(stp, encoding="utf-8"))
    except Exception:
        state = {}
    done = state.setdefault("done", {})  # "<sgg>|<kind>|<ym>": "받은 날 YYYYMMDD"
    state.pop("kapt", None)
    state.pop("kapt2", None)
    kdone = state.setdefault("kapt3", {})  # "<sgg>": "받은 날"
    months = month_list()
    recent = set(months[:RECENT])
    today = NOW.strftime("%Y%m%d")
    sggs = sgg_list()
    print(f"  시군구 {len(sggs)}곳 · {months[-1]}~{months[0]}")

    # 이번에 받을 것: (시군구, 종류, 달)
    todo = {}
    for s in sggs:
        for kind in APIS:
            for ym in months:
                got = done.get(f"{s}|{kind}|{ym}")
                if not got or (ym in recent and got != today):
                    todo.setdefault(s, []).append((kind, ym))
    print(f"  받을 것 {sum(len(v) for v in todo.values()):,}건")

    finished = 0
    for s in sggs:
        if time.time() - START > BUDGET:
            print("  시간 한도 — 다음 실행이 이어 받음")
            break
        jobs = [j for j in todo.get(s, []) if j[0] not in blocked]
        need_kapt = kdone.get(s, "")[:6] != today[:6]  # 단지 코드는 달마다
        if not jobs and not need_kapt:
            continue
        apts = load(s)
        with ThreadPoolExecutor(6) as ex:
            res = list(ex.map(lambda j: (j, fetch_all(j[0], s, j[1])), jobs))
        changed = False
        for (kind, ym), items in res:
            if items is None:
                # 오피스텔 등 활용신청이 안 된 자료는 이번 실행에서 그만 부름
                if kind not in ("as", "ar"):
                    blocked.add(kind)
                continue
            merge(apts, kind, ym, items)
            done[f"{s}|{kind}|{ym}"] = today
            changed = True
        if need_kapt and "kapt" not in blocked:
            kl = kapt_list(s)
            if kl is None:
                blocked.add("kapt")
            else:
                kdone[s] = today
                changed = True
                attach_kapt(apts, kl)
        elif changed:
            # 새로 생긴 단지에도 지난번 코드를 이어 붙임 (같은 key 면 load 에 이미 있음)
            pass
        if changed:
            save(s, apts, months)
            finished += 1
            n_s = sum(len(a.get("s", [])) for a in apts.values())
            n_e = sum(len(a.get("e", [])) for a in apts.values())
            print(f"  {s}: 단지 {len(apts):,} · 매매 {n_s:,} · 전월세 {n_e:,} (코드 {sum(1 for a in apts.values() if a.get('k')):,})")
        # 중간 저장 (끊겨도 이어 받게)
        with open(stp, "w", encoding="utf-8") as f:
            json.dump(state, f, ensure_ascii=False, separators=(",", ":"))

    # 지난 달 기록 정리
    keep = set(months)
    state["done"] = {k: v for k, v in done.items() if k.split("|")[-1] in keep}
    state["blocked"] = sorted(blocked)
    state["updated"] = NOW.strftime("%Y-%m-%d %H:%M")
    with open(stp, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, separators=(",", ":"))
    print(f"  저장 {finished}곳 · 부른 수 {calls} · 막힘 {sorted(blocked) or '없음'} · {int(time.time() - START)}초")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # 다른 기능에 영향 없게
        print("!! 실거래가 모으기 실패:", e)
        sys.exit(0)
