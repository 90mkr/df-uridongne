"""지하철 노선도 자료 — 권역마다 모든 지하철역 위치를 모아 호선별 노선 선을 만든다 (대표님 11-26).

공식 노선도 그림은 운영사 저작물이라 쓰지 않고, 역 위치(카카오 SW8)를 이어 우리 지도 위에 노선 색 선으로 그린다.
역 순서 자료가 노선마다 따로 없어서, 같은 호선 역들을 「가장 짧게 다 잇는 선(최소 신장 나무)」으로 잇는다.
갈라지는 노선(1호선·경의중앙선 등)도 저절로 가지가 생기고, 2호선처럼 도는 노선은 양 끝을 이어 고리로 만든다.

    KAKAO_REST_KEY   카카오 REST 키

저장 파일
    web/data/subway/lines_<권역>.json
      {"updated", "bbox": [x1, y1, x2, y2], "lines": [{"l": 호선, "c": "#색", "p": [[[y, x], …], …], "s": [[역, y, x], …]}]}
"""
import json
import math
import os
import time
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

KKEY = os.environ.get("KAKAO_REST_KEY", "").strip()
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "web", "data", "subway")
KST = timezone(timedelta(hours=9))

# 권역: (이름, [서 경도, 남 위도, 동 경도, 북 위도])
REGIONS = [
    ("capital", [126.30, 36.75, 127.75, 38.05]),  # 수도권 (서울·인천·경기)
    ("busan", [128.75, 35.00, 129.35, 35.45]),  # 부산·양산·김해
    ("daegu", [128.35, 35.75, 128.85, 36.05]),
    ("gwangju", [126.70, 35.05, 127.00, 35.25]),
    ("daejeon", [127.25, 36.25, 127.50, 36.50]),
]

# 호선 색 (운영사 공식 색) — 권역마다 「1호선」 같은 이름이 겹쳐서 권역별로
COLORS = {
    "capital": {
        "1호선": "#0052A4", "2호선": "#00A84D", "3호선": "#EF7C1C", "4호선": "#00A5DE", "5호선": "#996CAC",
        "6호선": "#CD7C2F", "7호선": "#747F00", "8호선": "#E6186C", "9호선": "#BDB092", "수인분당선": "#F5A200",
        "신분당선": "#D4003B", "경의중앙선": "#77C4A3", "공항철도": "#0090D2", "경춘선": "#0C8E72", "인천1호선": "#7CA8D5",
        "인천2호선": "#ED8B00", "서해선": "#8FC31F", "김포골드라인": "#A17800", "우이신설선": "#B0CE18", "신림선": "#6789CA",
        "의정부경전철": "#FDA600", "에버라인": "#509F22", "용인경전철": "#509F22", "경강선": "#0054A6", "GTX-A": "#9A6292",
        "자기부상철도": "#FFCD12",
    },
    "busan": {"부산1호선": "#F06A00", "부산2호선": "#81BF48", "부산3호선": "#BB8C00", "부산4호선": "#217DCB", "부산김해경전철": "#8652A1", "동해선": "#0054A6"},
    "daegu": {"대구1호선": "#D93F5C", "대구2호선": "#00AA80", "대구3호선": "#FFB100", "대경선": "#1E5AA8"},
    "gwangju": {"광주1호선": "#009088"},
    "daejeon": {"대전1호선": "#007448"},
}
LOOPS = {("capital", "2호선")}

calls = 0


def get(url, headers=None):
    global calls
    for tryn in range(3):
        try:
            calls += 1
            req = urllib.request.Request(url, headers=headers or {})
            with urllib.request.urlopen(req, timeout=20) as r:
                return r.read().decode("utf-8")
        except Exception as e:  # noqa: BLE001
            if tryn == 2:
                print("  부르기 오류:", str(e)[:120])
                return ""
            time.sleep(1.5 * (tryn + 1))


def sw8(rect, depth=0):
    """사각형 안 지하철역 (45곳 넘으면 넷으로 나눠 다시)"""
    docs, total = [], 0
    for page in (1, 2, 3):
        q = urllib.parse.urlencode({"category_group_code": "SW8", "rect": ",".join(f"{x:.6f}" for x in rect), "page": page, "size": 15})
        t = get("https://dapi.kakao.com/v2/local/search/category.json?" + q, {"Authorization": f"KakaoAK {KKEY}"})
        try:
            j = json.loads(t)
        except Exception:  # noqa: BLE001
            break
        docs += j.get("documents", [])
        total = j.get("meta", {}).get("total_count", 0)
        if j.get("meta", {}).get("is_end", True):
            break
    if total > 45 and depth < 8:
        x1, y1, x2, y2 = rect
        mx, my = (x1 + x2) / 2, (y1 + y2) / 2
        out = []
        for r in ((x1, y1, mx, my), (mx, y1, x2, my), (x1, my, mx, y2), (mx, my, x2, y2)):
            out += sw8(r, depth + 1)
        return out
    return docs


def short(name):
    n = name.split(" ")[0]
    return n[:-1] if n.endswith("역") and len(n) > 2 else n


def line_of(d):
    cn = d.get("category_name", "")
    last = cn.split(">")[-1].strip() if cn else ""
    w = d.get("place_name", "").split(" ")
    return (" ".join(w[1:]) if len(w) > 1 else last).strip()


ALIAS = {
    "경의선": "경의중앙선", "중앙선": "경의중앙선", "분당선": "수인분당선", "수인선": "수인분당선",
    "인천지하철1호선": "인천1호선", "인천지하철2호선": "인천2호선", "공항철도1호선": "공항철도",
    "김포도시철도": "김포골드라인", "용인경전철": "에버라인", "우이신설경전철": "우이신설선", "신림경전철": "신림선",
}


def norm_line(l):
    l = l.replace(" ", "")
    if l.startswith("수도권"):
        l = l[3:]
    return ALIAS.get(l, l)


def km(a, b):
    dy = (a[0] - b[0]) * 111.0
    dx = (a[1] - b[1]) * 111.0 * math.cos(math.radians((a[0] + b[0]) / 2))
    return math.hypot(dx, dy)


def mst(pts):
    """최소 신장 나무 — 이어진 역 쌍 목록"""
    n = len(pts)
    if n < 2:
        return []
    used = [False] * n
    best = [float("inf")] * n
    par = [-1] * n
    best[0] = 0
    edges = []
    for _ in range(n):
        u = min((i for i in range(n) if not used[i]), key=lambda i: best[i])
        used[u] = True
        if par[u] >= 0:
            edges.append((par[u], u))
        for v in range(n):
            if not used[v]:
                d = km(pts[u], pts[v])
                if d < best[v]:
                    best[v], par[v] = d, u
    return edges


def paths(n, edges, pts):
    """나무를 갈림 없는 선 여러 개로 (끝·갈림 역에서 끊음)"""
    adj = {i: [] for i in range(n)}
    for a, b in edges:
        adj[a].append(b)
        adj[b].append(a)
    seen = set()
    out = []
    for s in range(n):
        if len(adj[s]) == 2:
            continue
        for nb in adj[s]:
            if (s, nb) in seen:
                continue
            path = [s, nb]
            seen.add((s, nb))
            seen.add((nb, s))
            prev, cur = s, nb
            while len(adj[cur]) == 2:
                nxt = adj[cur][0] if adj[cur][0] != prev else adj[cur][1]
                seen.add((cur, nxt))
                seen.add((nxt, cur))
                path.append(nxt)
                prev, cur = cur, nxt
            out.append([[round(pts[i][0], 5), round(pts[i][1], 5)] for i in path])
    if not out and n >= 2:  # 모두 갈림 없는 고리
        out.append([[round(pts[i][0], 5), round(pts[i][1], 5)] for i in range(n)])
    return out


def main():
    if not KKEY:
        print("카카오 키가 없어 노선도를 만들지 않습니다")
        return 0
    os.makedirs(OUT, exist_ok=True)
    now = datetime.now(KST).strftime("%Y-%m-%d %H:%M")
    for rid, bbox in REGIONS:
        print(f"[{rid}] 지하철역 모으기")
        by = {}
        seen = set()
        for d in sw8(bbox):
            n, l = short(d.get("place_name", "")), norm_line(line_of(d))
            if not n or not l or (n, l) in seen:
                continue
            seen.add((n, l))
            try:
                by.setdefault(l, []).append((n, float(d["y"]), float(d["x"])))
            except Exception:  # noqa: BLE001
                continue
        lines = []
        colors = COLORS.get(rid, {})
        for l, st in sorted(by.items(), key=lambda kv: -len(kv[1])):
            if len(st) < 2:
                continue
            pts = [(y, x) for _, y, x in st]
            edges = mst(pts)
            # 너무 먼 이음(8km 넘음)은 다른 구간끼리 억지로 이은 것 → 버림
            edges = [(a, b) for a, b in edges if km(pts[a], pts[b]) <= 8]
            if (rid, l) in LOOPS:
                deg = {}
                for a, b in edges:
                    deg[a] = deg.get(a, 0) + 1
                    deg[b] = deg.get(b, 0) + 1
                ends = [i for i in range(len(pts)) if deg.get(i, 0) == 1]
                # 2호선 본선 고리: 가장 가까운 끝 두 곳을 이음
                pair = min(((a, b) for i, a in enumerate(ends) for b in ends[i + 1:]), key=lambda p: km(pts[p[0]], pts[p[1]]), default=None)
                if pair and km(pts[pair[0]], pts[pair[1]]) <= 4:
                    edges.append(pair)
            lines.append({
                "l": l,
                "c": colors.get(l, "#8A93A3"),
                "p": paths(len(pts), edges, pts),
                "s": [[n, round(y, 5), round(x, 5)] for n, y, x in st],
            })
        print(f"  호선 {len(lines)}개 · 역 {sum(len(x['s']) for x in lines)}곳")
        if not lines:
            print("  하나도 못 받아 예전 파일을 그대로 둠")
            continue
        with open(os.path.join(OUT, f"lines_{rid}.json"), "w", encoding="utf-8") as f:
            json.dump({"updated": now, "bbox": bbox, "lines": lines}, f, ensure_ascii=False, separators=(",", ":"))
    print(f"끝 · 부른 횟수 {calls}번")
    return 0


if __name__ == "__main__":
    main()
