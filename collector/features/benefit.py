"""우리 동네 지원금·혜택 (지원금·혜택 방, 대표님 11-25)

1) 행정안전부 「대한민국 공공서비스(혜택) 정보」 (공공데이터포털 15113968, 정부24 보조금24)
   api.odcloud.kr/api/gov24/v3/serviceList · supportConditions — 전국 약 1만 1천 건
   열쇠 DATA_GO_KR_KEY (활용신청 필요, 자동승인)
2) 온통청년 청년정책 (한국고용정보원) www.youthcenter.go.kr/go/ythip/getPlcy
   열쇠 YOUTH_KEY (온통청년 누리집에서 따로 발급) — 없으면 건너뜀

자주 바뀌므로(일주일에 10% 넘게 바뀜) 하루 한 번 받는다. 받은 지 20시간이 안 됐으면 건너뜀 (FORCE=1 이면 무조건).
바뀐 파일만 다시 쓴다 (저장소가 매일 커지지 않게).

저장: web/data/benefit/
  meta.json             {updated, youth, c: {시군구코드: 우리 구 혜택 수}, s: {시도코드: 수}, n: 전국 수, y: {시군구코드: 청년정책 수}}
  n.json                전국(중앙부처·공공기관) 혜택 목록
  s_<시도코드 2자리>.json   시·도 혜택 목록 (예: s_28 인천광역시)
  l_<시군구코드 5자리>.json  우리 구 혜택 목록 (예: l_28185 연수구)
  d_<00~63>.json        혜택 자세히 (서비스ID 로 칸을 나눔 — 누를 때만 받음)
  y_<시군구코드>.json · y_n.json   청년정책 (목록+자세히 함께, 전국 공통은 y_n)
목록 한 줄: {i 번호, t 이름, s 한 줄 요약, f 분야, k 지원 형태, o 담당 기관, v 조회수, r 등록일, m 수정일, d 신청 기한(짧게), g 대상 꼬리표, a [최소 나이, 최대 나이]}
"""
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request
import zlib
from datetime import datetime, timedelta, timezone

KEY = os.environ.get("DATA_GO_KR_KEY", "").strip()
YKEY = os.environ.get("YOUTH_KEY", "").strip()
FORCE = os.environ.get("FORCE", "") == "1"
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "web", "data", "benefit")
KST = timezone(timedelta(hours=9))
REGIONS_URL = "https://raw.githubusercontent.com/90mkr/df-uridongne/store/regions.json"
BUCKETS = 64

# 시·도 이름 → 시도코드 (긴 이름·짧은 이름 모두)
SIDO = {
    "11": ["서울특별시", "서울시", "서울"], "26": ["부산광역시", "부산시", "부산"], "27": ["대구광역시", "대구시", "대구"],
    "28": ["인천광역시", "인천시", "인천"], "29": ["광주광역시", "광주시", "광주"], "30": ["대전광역시", "대전시", "대전"],
    "31": ["울산광역시", "울산시", "울산"], "36": ["세종특별자치시", "세종시", "세종"], "41": ["경기도", "경기"],
    "42": ["강원특별자치도", "강원도", "강원"], "51": ["강원특별자치도", "강원도", "강원"], "43": ["충청북도", "충북"],
    "44": ["충청남도", "충남"], "45": ["전북특별자치도", "전라북도", "전북"], "52": ["전북특별자치도", "전라북도", "전북"],
    "46": ["전라남도", "전남"], "47": ["경상북도", "경북"], "48": ["경상남도", "경남"], "50": ["제주특별자치도", "제주도", "제주"],
}

# 대상 꼬리표 — 이름·지원 대상·선정 기준 글에 이 말이 있으면 그 사람들을 위한 혜택으로 본다
# (정부24 지원조건 Y 는 「이 사람도 빠지지 않음」이라 거르는 데 못 씀 → 글로 판단)
TAGS = {
    "청년": ["청년", "대학생", "사회초년", "취업준비"],
    "어르신": ["노인", "어르신", "65세 이상", "만65세", "만 65세", "경로", "기초연금", "장기요양", "노령"],
    "임신출산": ["임신", "임산부", "출산", "산모", "난임", "신생아", "산후"],
    "영유아": ["영유아", "영아", "유아", "어린이집", "보육", "아동수당", "육아", "아이돌봄", "부모급여"],
    "학생": ["초등", "중학", "고등학", "학생", "청소년", "학교"],
    "장애": ["장애"],
    "저소득": ["기초생활", "수급자", "차상위", "저소득", "한부모", "긴급복지"],
    "사장님": ["소상공인", "자영업", "창업"],
    "주거": ["월세", "전세", "주거", "임대주택", "주택"],
    "다자녀": ["다자녀", "셋째"],
}


def now():
    return datetime.now(KST)


def get_json(url, tries=3):
    for n in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 uridongne"})
            with urllib.request.urlopen(req, timeout=40) as r:
                t = r.read().decode("utf-8", "replace")
            try:
                return json.loads(t)
            except Exception:  # noqa: BLE001
                print("  JSON 아님:", t[:200].replace("\n", " "))
                return None
        except Exception as e:  # noqa: BLE001
            body = ""
            try:
                body = e.read().decode("utf-8", "replace")[:300]  # type: ignore[attr-defined]
            except Exception:  # noqa: BLE001
                pass
            if body or n == tries - 1:
                print("  오류:", str(e)[:120], body.replace("\n", " "))
                return None
            time.sleep(3)
    return None


def clean(s, n=0):
    s = re.sub(r"[ \t\r\f\v]+", " ", str(s or "")).strip()
    s = re.sub(r"\n\s*\n+", "\n", s)
    s = s.replace("○", "·").replace("ㅇ ", "· ")
    if n and len(s) > n:
        s = s[: n - 1].rstrip() + "…"
    return s


def ymd(s):
    d = "".join(ch for ch in str(s or "") if ch.isdigit())
    return d[:8] if len(d) >= 8 else ""


def tags_of(*texts):
    t = " ".join(str(x or "") for x in texts)
    return [k for k, words in TAGS.items() if any(w in t for w in words)]


def bucket(sid):
    return f"{zlib.crc32(str(sid).encode()) % BUCKETS:02d}"


def write_if_changed(name, obj):
    """updated 같은 시각만 다르면 쓰지 않음 → 저장소가 매일 쓸데없이 커지지 않게"""
    path = os.path.join(OUT, name)
    body = json.dumps(obj, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
    try:
        with open(path, encoding="utf-8") as f:
            old = f.read()
        if old == body:
            return False
    except FileNotFoundError:
        pass
    with open(path, "w", encoding="utf-8") as f:
        f.write(body)
    return True


# ---------------- 동네(시군구) ----------------
def load_regions():
    reg = get_json(REGIONS_URL)
    if not isinstance(reg, dict):
        p = os.path.join(ROOT, "web", "data", "regions.json")
        if os.path.exists(p):
            reg = json.load(open(p, encoding="utf-8"))
    out = {}  # 시군구코드 → {sido 코드, gu 이름}
    for s in (reg or {}).get("sido", []):
        for a in s.get("areas", []):
            aid = str(a.get("id") or "")
            m = re.match(r"k(\d{5})", aid)
            code = m.group(1) if m else ("28185" if aid == "songdo" else "")
            if not code:
                continue
            out.setdefault(code, {"sido": code[:2], "gu": (a.get("gu") or a.get("name") or "").strip()})
    print(f"시군구 {len(out)}곳")
    return out


def split_org(org):
    """「경기도 성남시 분당구」 → ('41', ['성남시', '분당구']) / 중앙부처면 (None, [])"""
    org = clean(org)
    for code, names in SIDO.items():
        for nm in names:
            if org.startswith(nm):
                rest = org[len(nm):].strip()
                # 「인천광역시교육청」·「서울특별시 교육청」 → 시·도 단위
                if rest.startswith("교육청") or not rest:
                    return code, []
                return code, rest.split()
    return None, []


def match_codes(org, sggs, by_sido):
    """기관 이름 → (시도코드, [시군구코드…]) — 시군구가 비면 시·도 전체, 시도가 None 이면 전국"""
    sd, rest = split_org(org)
    if sd is None:
        return None, []
    cands = by_sido.get(sd, [])
    if not rest:
        return sd, []
    first = rest[0]
    if first.endswith("교육지원청"):
        first = first.replace("교육지원청", "")
    hit = []
    for code in cands:
        gu = sggs[code]["gu"].split()
        if not gu:
            continue
        g0 = gu[0]
        if first == g0 or first.rstrip("시군구") == g0.rstrip("시군구"):
            # 「성남시 분당구」 처럼 구가 더 있으면 기관에도 구가 적혔을 때만 맞춰 봄
            if len(rest) > 1 and len(gu) > 1 and rest[1].endswith("구") and rest[1] != gu[1]:
                continue
            hit.append(code)
    return sd, hit


# ---------------- 1) 정부24 공공서비스 ----------------
GOV = "https://api.odcloud.kr/api/gov24/v3/"


def gov_all(kind, key):
    out, page = [], 1
    while page <= 30:
        j = get_json(f"{GOV}{kind}?page={page}&perPage=1000&returnType=JSON&serviceKey={key}")
        if not isinstance(j, dict) or "data" not in j:
            print(f"  {kind} {page}쪽 실패:", str(j)[:200])
            return out if out else None
        d = j.get("data") or []
        out += d
        total = int(j.get("totalCount") or j.get("matchCount") or 0)
        if not d or (total and len(out) >= total) or len(d) < 1000:
            break
        page += 1
    return out


def age_of(c):
    try:
        lo = int(float(c.get("JA0110") or 0))
        hi = int(float(c.get("JA0111") or 0))
    except Exception:  # noqa: BLE001
        return None
    if lo <= 0 and (hi <= 0 or hi >= 100):
        return None
    if hi <= 0 or hi >= 100:
        hi = 120
    if lo < 0:
        lo = 0
    return [lo, hi]


def gov24(sggs):
    if not KEY:
        print("DATA_GO_KR_KEY 가 없어 정부24 혜택을 모으지 않습니다")
        return None
    key = KEY if "%" in KEY else urllib.parse.quote(KEY, safe="")
    items = gov_all("serviceList", key)
    if not items:
        print("정부24 목록을 받지 못함 — 공공데이터포털에서 「행정안전부_대한민국 공공서비스(혜택) 정보」 활용신청을 확인해 주세요")
        return None
    print(f"정부24 혜택 {len(items)}건")
    conds = {}
    for c in gov_all("supportConditions", key) or []:
        conds[str(c.get("서비스ID") or "")] = c
    print(f"지원 조건 {len(conds)}건")

    by_sido = {}
    for code, v in sggs.items():
        by_sido.setdefault(v["sido"], []).append(code)

    nat, sido, local, detail = [], {}, {}, {}
    skip = 0
    for it in items:
        sid = str(it.get("서비스ID") or "").strip()
        name = clean(it.get("서비스명"))
        if not sid or not name:
            continue
        user = clean(it.get("사용자구분"))
        # 법인·기관·단체만 받는 것은 뺌 (주민 앱이라 개인·가구·소상공인만)
        if user and not any(w in user for w in ("개인", "가구", "소상공인")):
            skip += 1
            continue
        target = clean(it.get("지원대상"))
        crit = clean(it.get("선정기준"))
        g = tags_of(name, target, crit, clean(it.get("서비스목적요약")))
        if "소상공인" in user and "사장님" not in g:
            g.append("사장님")
        row = {
            "i": sid,
            "t": name,
            "s": clean(it.get("서비스목적요약"), 90),
            "f": clean(it.get("서비스분야")),
            "k": clean(it.get("지원유형")),
            "o": clean(it.get("소관기관명")),
            "v": int(it.get("조회수") or 0),
            "r": ymd(it.get("등록일시")),
            "m": ymd(it.get("수정일시")),
            "d": clean(it.get("신청기한"), 40),
            "g": g,
        }
        a = age_of(conds.get(sid) or {})
        if a:
            row["a"] = a
        detail.setdefault(bucket(sid), {})[sid] = {
            "대상": clean(target, 1500),
            "기준": clean(crit, 1500),
            "내용": clean(it.get("지원내용"), 2000),
            "방법": clean(it.get("신청방법"), 1000),
            "기한": clean(it.get("신청기한"), 300),
            "접수": clean(it.get("접수기관")),
            "문의": clean(it.get("전화문의"), 200),
            "부서": clean(it.get("부서명")),
            "url": str(it.get("상세조회URL") or "").strip(),
        }
        sd, hit = match_codes(row["o"], sggs, by_sido)
        if sd is None:
            nat.append(row)
        elif not hit:
            sido.setdefault(sd, []).append(row)
        else:
            for code in hit:
                local.setdefault(code, []).append(row)
    print(f"전국 {len(nat)} · 시도 {sum(len(v) for v in sido.values())} · 시군구 {sum(len(v) for v in local.values())} · 기관 전용이라 뺌 {skip}")

    def srt(rows):
        rows.sort(key=lambda r: (-r["v"], r["t"]))
        return rows

    stamp = now().strftime("%Y-%m-%d %H:%M")
    ch = 0
    ch += write_if_changed("n.json", {"rows": srt(nat)})
    for sd, rows in sido.items():
        ch += write_if_changed(f"s_{sd}.json", {"rows": srt(rows)})
    for code, rows in local.items():
        ch += write_if_changed(f"l_{code}.json", {"rows": srt(rows)})
    for b, d in detail.items():
        ch += write_if_changed(f"d_{b}.json", d)
    print(f"바뀐 파일 {ch}개")
    return {"updated": stamp, "n": len(nat), "s": {k: len(v) for k, v in sido.items()}, "c": {k: len(v) for k, v in local.items()}}


# ---------------- 2) 온통청년 청년정책 ----------------
YC = "https://www.youthcenter.go.kr/go/ythip/getPlcy"


def youth(sggs):
    if not YKEY:
        print("YOUTH_KEY 가 없어 청년정책을 모으지 않습니다 (온통청년 누리집에서 오픈API 인증키 발급 → 깃허브 비밀 YOUTH_KEY)")
        return None
    rows, page = [], 1
    while page <= 60:
        q = urllib.parse.urlencode({"apiKeyNm": YKEY, "pageNum": page, "pageSize": 100, "rtnType": "json"})
        j = get_json(f"{YC}?{q}")
        res = (j or {}).get("result") or {}
        lst = res.get("youthPolicyList") or []
        if not isinstance(lst, list):
            lst = []
        if page == 1 and not lst:
            print("  청년정책을 받지 못함:", str(j)[:300])
            return None
        rows += lst
        tot = int(((res.get("pagging") or {}).get("totCount")) or 0)
        if not lst or (tot and len(rows) >= tot):
            break
        page += 1
    print(f"청년정책 {len(rows)}건")
    today = now().strftime("%Y%m%d")
    nat, local = [], {}
    all_codes = set(sggs.keys())
    for p in rows:
        pid = str(p.get("plcyNo") or "").strip()
        name = clean(p.get("plcyNm"))
        if not pid or not name:
            continue
        ap = str(p.get("aplyYmd") or "")
        ds = re.findall(r"\d{8}", ap)
        end = ds[-1] if ds else ""
        if end and end < today:
            continue  # 신청이 끝난 것은 뺌
        be = ymd(p.get("bizPrdEndYmd"))
        if not end and be and be < today:
            continue
        try:
            lo = int(p.get("sprtTrgtMinAge") or 0)
            hi = int(p.get("sprtTrgtMaxAge") or 0)
        except Exception:  # noqa: BLE001
            lo = hi = 0
        row = {
            "i": "y" + pid,
            "t": name,
            "s": clean(p.get("plcyExplnCn"), 90),
            "f": clean(p.get("lclsfNm")),
            "k": clean(p.get("mclsfNm")),
            "o": clean(p.get("sprvsnInstCdNm") or p.get("operInstCdNm")),
            "v": int(p.get("inqCnt") or 0),
            "r": ymd(p.get("frstRegDt")),
            "m": ymd(p.get("lastMdfcnDt")),
            "d": (f"~{end[4:6]}.{end[6:8]}" if end else clean(p.get("aplyPrdSeCdNm") or "상시", 20)),
            "e": end,
            "g": ["청년"] + [t for t in tags_of(name, p.get("plcyKywdNm"), p.get("plcySprtCn")) if t != "청년"],
            "x": {
                "대상": clean(" ".join(x for x in [
                    (f"만 {lo}~{hi}세" if hi and p.get("sprtTrgtAgeLmtYn") != "Y" else ""),
                    clean(p.get("addAplyQlfcCndCn")), clean(p.get("ptcpPrpTrgtCn"))] if x), 1500),
                "내용": clean(p.get("plcySprtCn"), 2000),
                "방법": clean(p.get("plcyAplyMthdCn"), 1000),
                "기한": clean(ap, 100) or "상시",
                "접수": clean(p.get("operInstCdNm")),
                "문의": "",
                "서류": clean(p.get("sbmsnDcmntCn"), 600),
                "url": str(p.get("aplyUrlAddr") or p.get("refUrlAddr1") or "").strip()
                       or f"https://www.youthcenter.go.kr/youthPolicy/ythPlcyTotalSearch/ythPlcyDetail/{pid}",
            },
        }
        if hi and hi < 100:
            row["a"] = [lo, hi]
        codes = set(re.findall(r"\d{5}", str(p.get("zipCd") or ""))) & all_codes
        # 거의 전국에 걸친 것(시군구 200곳 넘게)이나 지역이 없는 것은 전국 묶음으로
        if not codes or len(codes) > 200:
            nat.append(row)
        else:
            for c in codes:
                local.setdefault(c, []).append(row)

    def srt(rs):
        # 몰라서 못 받는 것 위주로 위에: 주거(월세 등) → 마감이 가까운 것 → 조회수
        rs.sort(key=lambda r: (0 if "주거" in r["g"] else 1, r.get("e") or "99999999", -r["v"]))
        return rs

    ch = write_if_changed("y_n.json", {"rows": srt(nat)})
    for c, rs in local.items():
        ch += write_if_changed(f"y_{c}.json", {"rows": srt(rs)})
    print(f"청년정책 전국 {len(nat)} · 시군구 {sum(len(v) for v in local.values())} · 바뀐 파일 {ch}개")
    return {"yn": len(nat), "y": {k: len(v) for k, v in local.items()}}


def main():
    os.makedirs(OUT, exist_ok=True)
    meta_path = os.path.join(OUT, "meta.json")
    meta = {}
    if os.path.exists(meta_path):
        try:
            meta = json.load(open(meta_path, encoding="utf-8"))
        except Exception:  # noqa: BLE001
            meta = {}
    last = meta.get("updated") or ""
    if not FORCE and last:
        try:
            t = datetime.strptime(last, "%Y-%m-%d %H:%M").replace(tzinfo=KST)
            if now() - t < timedelta(hours=20):
                print(f"혜택은 {last} 에 받았음 — 하루 한 번만 받으므로 건너뜀")
                return 0
        except Exception:  # noqa: BLE001
            pass
    sggs = load_regions()
    if not sggs:
        print("동네 목록을 못 받아 혜택을 나누지 못함")
        return 0
    g = gov24(sggs)
    y = youth(sggs)
    if g:
        meta.update(g)
    if y:
        meta.update(y)
        meta["youth"] = now().strftime("%Y-%m-%d %H:%M")
    if g or y:
        meta["updated"] = now().strftime("%Y-%m-%d %H:%M")
        write_if_changed("meta.json", meta)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:  # noqa: BLE001
        print("혜택 모으기 오류:", e)
        sys.exit(0)
