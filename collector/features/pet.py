"""우리 동네 반려동물 — 「같이 갈 수 있는 곳」 모으기 (반려동물 테마 방)

한국관광공사 반려동물 동반여행 서비스 (KorPetTourService2, 공공데이터포털 15135102 · 활용신청 필요, 자동 승인)
 - 전국 목록(지역기반)을 한 번에 받아 0.5도 칸으로 나눠 저장 → 앱은 단지 둘레 칸만 받는다
 - 동반 조건(자세히)은 앱이 누를 때만 부른다 (개발 계정 하루 1,000회라 목록만 여기서)
 - 실패하면 예전 파일을 그대로 둔다

    DATA_GO_KR_KEY   공공데이터포털 인증키

저장: web/data/pet/t_<위도*2 내림>_<경도*2 내림>.json  {"updated", "src", "items": [{id, t, ct, a, tel, img, y, x}]}
      web/data/pet/trip_index.json  {"updated", "count", "tiles": [...]}

같이 갈 곳은 자주 안 바뀌어서 6일이 지났을 때만 다시 받는다 (하루 여러 번 돌아도 영상만 새로 모음).

── 추천 영상 (대표님 11-26) ──
훈련사·수의사 채널의 새 영상(RSS, 열쇠 없음)을 모아 장르별로 나눈다 → web/data/pet/videos.json
 - 영상 파일은 받지 않는다. 번호·제목·채널만 (제목은 유튜브가 주는 그대로)
 - 퍼가기 막힌 영상은 oEmbed 로 알아내 e=false → 앱이 「유튜브에서 보기」로
 - YOUTUBE_KEY(유튜브 Data API, 선택)가 있으면 하루 한 번 채널 안에서 장르별 검색을 더해 묶음을 채운다
 - 모은 영상은 계속 쌓는다 (장르마다 최근·관련 순으로 넉넉히 보관)

    YOUTUBE_KEY   (선택) 유튜브 Data API v3 열쇠
"""
import json
import math
import re
import os
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from collections import defaultdict
from datetime import datetime, timedelta, timezone

KEY = os.environ.get("DATA_GO_KR_KEY", "").strip()
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "web", "data", "pet")
KST = timezone(timedelta(hours=9))
BASE = "https://apis.data.go.kr/B551011/KorPetTourService2/"


def get_json(url):
    for tryn in range(3):
        try:
            with urllib.request.urlopen(url, timeout=40) as r:
                t = r.read().decode("utf-8")
            try:
                return json.loads(t)
            except Exception:  # noqa: BLE001
                print("  JSON 아님:", t[:200].replace("\n", " "))
                return None
        except Exception as e:  # noqa: BLE001
            body = ""
            try:
                body = e.read().decode("utf-8", "replace")[:200]  # type: ignore[attr-defined]
            except Exception:  # noqa: BLE001
                pass
            if body or tryn == 2:
                print("  오류:", str(e)[:100], body.replace("\n", " "))
                return None
            time.sleep(2)


def items_of(j):
    body = ((j or {}).get("response") or {}).get("body") or {}
    it = body.get("items") or {}
    if isinstance(it, dict):
        it = it.get("item") or []
    return (it if isinstance(it, list) else [it]), int(body.get("totalCount") or 0)


def page(op, n):
    key = KEY if "%" in KEY else urllib.parse.quote(KEY, safe="")
    q = urllib.parse.urlencode({"MobileOS": "ETC", "MobileApp": "yogikok", "_type": "json", "numOfRows": 1000, "pageNo": n, "arrange": "C"})
    return get_json(f"{BASE}{op}?serviceKey={key}&{q}")


def main():
    try:
        videos()
    except Exception as e:  # noqa: BLE001
        print("추천 영상 오류:", e)
    try:
        with open(os.path.join(OUT, "trip_index.json"), encoding="utf-8") as f:
            last = datetime.strptime(json.load(f)["updated"], "%Y-%m-%d %H:%M").replace(tzinfo=KST)
        if datetime.now(KST) - last < timedelta(days=6) and os.environ.get("PET_TRIP") != "1":
            print("반려동물: 같이 갈 곳은 6일 안에 받음 → 이번엔 건너뜀")
            return
    except Exception:  # noqa: BLE001
        pass
    trip()


def trip():
    if not KEY:
        print("반려동물: DATA_GO_KR_KEY 없음 → 건너뜀")
        return
    op = None
    first = None
    for cand in ("areaBasedList2", "areaBasedList"):
        first = page(cand, 1)
        if first and items_of(first)[1] > 0:
            op = cand
            break
    if not op:
        print("반려동물: 동반여행 목록을 못 받음 (활용신청 확인) → 예전 파일 유지")
        return
    rows, total = items_of(first)
    pages = math.ceil(total / 1000)
    for n in range(2, pages + 1):
        j = page(op, n)
        if not j:
            print(f"  {n}쪽 실패 → 이번엔 저장하지 않음")
            return
        rows += items_of(j)[0]
    tiles = defaultdict(list)
    seen = set()
    for it in rows:
        try:
            y, x = float(it.get("mapy") or 0), float(it.get("mapx") or 0)
        except Exception:  # noqa: BLE001
            continue
        cid = str(it.get("contentid") or "")
        if not (33 < y < 39 and 124 < x < 132) or not cid or cid in seen:
            continue
        seen.add(cid)
        img = (it.get("firstimage2") or it.get("firstimage") or "").replace("http://", "https://")
        tiles[f"{math.floor(y * 2)}_{math.floor(x * 2)}"].append({
            "id": cid,
            "t": (it.get("title") or "").strip(),
            "ct": str(it.get("contenttypeid") or ""),
            "a": " ".join(s for s in [(it.get("addr1") or "").strip(), (it.get("addr2") or "").strip()] if s),
            "tel": (it.get("tel") or "").strip(),
            "img": img,
            "y": round(y, 6),
            "x": round(x, 6),
        })
    if not tiles:
        print("반려동물: 좌표 있는 곳이 없음 → 예전 파일 유지")
        return
    os.makedirs(OUT, exist_ok=True)
    now = datetime.now(KST).strftime("%Y-%m-%d %H:%M")
    for name in os.listdir(OUT):  # 없어진 칸 지우기
        if name.startswith("t_") and name.endswith(".json") and name[2:-5] not in tiles:
            os.remove(os.path.join(OUT, name))
    for k, v in tiles.items():
        v.sort(key=lambda z: z["t"])
        with open(os.path.join(OUT, f"t_{k}.json"), "w", encoding="utf-8") as f:
            json.dump({"updated": now, "src": "한국관광공사 반려동물 동반여행", "items": v}, f, ensure_ascii=False, separators=(",", ":"))
    with open(os.path.join(OUT, "trip_index.json"), "w", encoding="utf-8") as f:
        json.dump({"updated": now, "count": len(seen), "tiles": sorted(tiles)}, f, ensure_ascii=False)
    print(f"반려동물: 같이 갈 곳 {len(seen):,}곳 · 칸 {len(tiles)}개")


# ───────────────────────── 추천 영상 ─────────────────────────

YT_KEY = os.environ.get("YOUTUBE_KEY", "").strip()
VFILE = os.path.join(OUT, "videos.json")
UA = {"User-Agent": "Mozilla/5.0 (df-uridongne collector)", "Accept-Language": "ko-KR,ko;q=0.9"}

# 채널 (대표님 11-26: 훈련사 + 수의사 채널 섞기). handle 만 알면 채널 번호는 처음 한 번 찾아 videos.json 에 적어 둔다.
CHANNELS = [
    {"key": "bodeum", "id": "UCee1MvXr6E8qC_d2WEYTU5g", "handle": "@bodeumofficial", "who": "훈련사", "pet": "dog"},
    {"key": "knollo", "id": "", "handle": "@knollo_with_dvmseol", "who": "수의사", "pet": "dog"},
    {"key": "miyaong", "id": "UC69l_rtlCQ7M4Mz2RCS80BA", "handle": "", "who": "수의사", "pet": "cat"},
]

# 장르: (id, 이름, 누구용 dog/cat/both, 제목에 이 말이 들어가면, API 검색어)
GENRES = [
    ("walk", "산책·예절", "dog", ["산책", "줄당김", "리드줄", "목줄", "하네스", "펫티켓", "입마개"], "산책"),
    ("potty", "배변 훈련", "dog", ["배변", "소변", "대변", "마킹", "패드", "오줌"], "배변 훈련"),
    ("alone", "분리불안", "dog", ["분리불안", "혼자 있", "혼자있", "외출", "하울링", "집에 혼자"], "분리불안"),
    ("bark", "짖음·입질", "dog", ["짖", "입질", "무는", "물어", "공격", "으르렁"], "짖음"),
    ("litter", "고양이 화장실", "cat", ["화장실", "모래", "감자", "맛동산", "배변"], "화장실"),
    ("catmind", "고양이 마음", "cat", ["속마음", "고양이 언어", "고양이언어", "꾹꾹", "골골", "그루밍", "스크래치", "놀이", "행동"], "고양이 행동"),
    ("senior", "노견·노묘 돌보기", "both", ["노견", "노묘", "노령", "나이 든", "나이든", "시니어", "치매", "늙"], "노령"),
    ("health", "건강·병원", "both", ["병원", "질병", "증상", "수술", "접종", "심장사상충", "구토", "설사", "피부", "슬개골", "양치", "치아", "건강검진", "중성화", "신장", "당뇨"], "건강"),
    ("food", "먹거리·간식", "both", ["사료", "간식", "음식", "영양", "다이어트", "음수", "물 마시", "비만"], "사료"),
    ("first", "처음 키울 때", "both", ["입양", "처음", "퍼피", "아기 강아지", "아기 고양이", "새끼", "초보", "첫날"], "입양"),
]
KEEP_PER_GENRE = 40
NS = {"a": "http://www.w3.org/2005/Atom", "yt": "http://www.youtube.com/xml/schemas/2015", "media": "http://search.yahoo.com/mrss/"}


def http(url, timeout=25):
    req = urllib.request.Request(url, headers=UA)
    for tryn in range(3):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.status, r.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:  # type: ignore[attr-defined]
            return e.code, ""
        except Exception as e:  # noqa: BLE001
            if tryn == 2:
                print("  연결 실패:", url[:80], str(e)[:80])
                return 0, ""
            time.sleep(2)
    return 0, ""


def resolve_channel(ch):
    """handle(@이름) → 채널 번호 (채널 첫 화면에 적힌 RSS 주소에서)"""
    if ch.get("id") or not ch.get("handle"):
        return ch.get("id", "")
    st, html = http("https://www.youtube.com/" + ch["handle"])
    m = re.search(r"feeds/videos\.xml\?channel_id=(UC[\w-]{22})", html) or re.search(r'"(?:externalId|channelId)":"(UC[\w-]{22})"', html)
    return m.group(1) if m else ""


def parse_rss(xml_text):
    """채널 RSS → (채널 이름, [{v, t, d, s}])"""
    root = ET.fromstring(xml_text)
    name = (root.findtext("a:title", default="", namespaces=NS) or "").strip()
    out = []
    for e in root.findall("a:entry", NS):
        vid = e.findtext("yt:videoId", default="", namespaces=NS)
        if not vid:
            continue
        link = (e.find("a:link", NS).get("href") if e.find("a:link", NS) is not None else "") or ""
        out.append({
            "v": vid,
            "t": (e.findtext("a:title", default="", namespaces=NS) or "").strip(),
            "d": (e.findtext("a:published", default="", namespaces=NS) or "")[:10],
            "s": "/shorts/" in link,
        })
    return name, out


def genres_of(title, pet):
    g = []
    for gid, _, gp, words, _ in GENRES:
        if gp != "both" and gp != pet:
            continue
        if any(w in title for w in words):
            g.append(gid)
    return g


def embeddable(vid):
    """퍼가기 되나 (oEmbed: 200 되고, 401 막힘, 404 없어짐 → None)"""
    st, body = http(f"https://www.youtube.com/oembed?format=json&url=https://www.youtube.com/watch?v={vid}", timeout=15)
    if st == 200:
        return True
    if st == 401 or st == 403:
        return False
    if st == 404:
        return None
    return True  # 잠깐 실패면 일단 되는 것으로 (앱이 막히면 유튜브로 넘김)


def yt_api(path, params):
    params = dict(params, key=YT_KEY)
    st, body = http("https://www.googleapis.com/youtube/v3/" + path + "?" + urllib.parse.urlencode(params))
    if st != 200:
        print("  유튜브 API 실패", path, st)
        return None
    return json.loads(body)


def api_search(ch, gid, q):
    """채널 안에서 장르 검색 (100 단위) → [{v, t, d, rk}]"""
    j = yt_api("search", {"part": "snippet", "channelId": ch["id"], "q": q, "type": "video", "order": "relevance", "maxResults": 8, "regionCode": "KR", "relevanceLanguage": "ko"})
    out = []
    for i, it in enumerate((j or {}).get("items") or []):
        vid = ((it.get("id") or {}).get("videoId")) or ""
        sn = it.get("snippet") or {}
        if vid:
            out.append({"v": vid, "t": sn.get("title", ""), "d": (sn.get("publishedAt") or "")[:10], "rk": i})
    return out


def api_details(ids):
    """퍼가기·길이·정확한 제목 (50개씩 1 단위)"""
    info = {}
    for i in range(0, len(ids), 50):
        j = yt_api("videos", {"part": "snippet,status,contentDetails", "id": ",".join(ids[i:i + 50])})
        for it in (j or {}).get("items") or []:
            dur = (it.get("contentDetails") or {}).get("duration", "")
            m = re.match(r"PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?", dur)
            sec = (int(m.group(1) or 0) * 3600 + int(m.group(2) or 0) * 60 + int(m.group(3) or 0)) if m else 0
            info[it["id"]] = {"t": (it.get("snippet") or {}).get("title", ""), "e": bool((it.get("status") or {}).get("embeddable", True)), "sec": sec}
    return info


def videos():
    old = {}
    try:
        with open(VFILE, encoding="utf-8") as f:
            old = json.load(f)
    except Exception:  # noqa: BLE001
        pass
    known_ids = {c.get("key"): c.get("id") for c in old.get("channels", [])}
    items = {x["v"]: x for x in old.get("items", [])}  # 쌓인 영상
    chans = []
    for ch in CHANNELS:
        ch = dict(ch)
        ch["id"] = ch["id"] or known_ids.get(ch["key"], "") or resolve_channel(ch)
        if not ch["id"]:
            print("  채널 번호를 못 찾음:", ch["handle"])
            continue
        st, xml_text = http("https://www.youtube.com/feeds/videos.xml?channel_id=" + ch["id"])
        if st != 200 or not xml_text:
            print("  RSS 실패:", ch["key"], st)
            name = next((c.get("name") for c in old.get("channels", []) if c.get("key") == ch["key"]), "")
            if name:
                chans.append({"key": ch["key"], "id": ch["id"], "name": name, "who": ch["who"], "pet": ch["pet"]})
            continue
        name, rows = parse_rss(xml_text)
        chans.append({"key": ch["key"], "id": ch["id"], "name": name, "who": ch["who"], "pet": ch["pet"]})
        new = 0
        for r in rows:
            g = genres_of(r["t"], ch["pet"])
            if not g:
                continue
            x = items.get(r["v"]) or {"v": r["v"], "ch": ch["key"], "rk": 50}
            if r["v"] not in items:
                new += 1
            x.update(t=r["t"], d=r["d"], s=bool(r["s"]), g=sorted(set(x.get("g", [])) | set(g)))
            items[r["v"]] = x
        print(f"  {name}: 새 글 {len(rows)}개 중 장르 맞는 새 영상 {new}개")

    # 하루 한 번: 채널 안 장르 검색 (열쇠가 있을 때만)
    today = datetime.now(KST).strftime("%Y-%m-%d")
    searched = old.get("searched", "")
    if YT_KEY and searched != today:
        found = 0
        for ch in chans:
            for gid, _, gp, _, q in GENRES:
                if gp != "both" and gp != ch["pet"]:
                    continue
                for r in api_search(ch, gid, q):
                    x = items.get(r["v"]) or {"v": r["v"], "ch": ch["key"], "t": r["t"], "d": r["d"], "s": False}
                    x["g"] = sorted(set(x.get("g", [])) | {gid})
                    x["rk"] = min(x.get("rk", 50), r["rk"])
                    if r["v"] not in items:
                        found += 1
                    items[r["v"]] = x
        det = api_details([v for v, x in items.items() if "sec" not in x])
        for v, d in det.items():
            x = items[v]
            x.update(t=d["t"] or x.get("t", ""), e=d["e"], sec=d["sec"])
            if d["sec"] and d["sec"] <= 60:
                x["s"] = True
        searched = today
        print(f"  유튜브 검색으로 새 영상 {found}개")

    # 퍼가기 확인 (아직 모르는 것만)
    gone = []
    for v, x in items.items():
        if "e" not in x:
            e = embeddable(v)
            if e is None:
                gone.append(v)
            else:
                x["e"] = e
    for v in gone:
        items.pop(v, None)

    # 장르마다 넉넉히 남기기 (관련 순 → 최근 순)
    keep = set()
    for gid, *_ in GENRES:
        g = [x for x in items.values() if gid in x.get("g", [])]
        g.sort(key=lambda x: x.get("d", ""), reverse=True)
        g.sort(key=lambda x: x.get("rk", 50))  # 검색 관련 순이 먼저, 같으면 최근 순
        keep |= {x["v"] for x in g[:KEEP_PER_GENRE]}
    out_items = sorted((items[v] for v in keep), key=lambda x: x.get("d", ""), reverse=True)
    if not out_items and old.get("items"):
        print("추천 영상: 이번에 받은 게 없음 → 예전 파일 유지")
        return
    os.makedirs(OUT, exist_ok=True)
    data = {
        "updated": datetime.now(KST).strftime("%Y-%m-%d %H:%M"),
        "searched": searched,
        "note": "영상은 각 채널이 유튜브에 올린 것이에요. 재생·광고·조회수는 원래 채널 몫이에요.",
        "channels": chans,
        "genres": [{"id": g[0], "name": g[1], "pet": g[2]} for g in GENRES],
        "items": out_items,
    }
    with open(VFILE, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    cnt = {g[0]: sum(1 for x in out_items if g[0] in x.get("g", [])) for g in GENRES}
    print(f"추천 영상: {len(out_items)}개 · " + " ".join(f"{k}{v}" for k, v in cnt.items()))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # noqa: BLE001
        print("반려동물 수집 오류:", e)
