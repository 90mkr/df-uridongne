# 주유소 가격 모으기 (주유소 담당 방만 고침)
#
# 한국석유공사 오피넷 무료 API로 동네(regions.json 에서 ready·collect 인 곳)마다
# 주유소·충전소의 휘발유·경유·고급휘발유·LPG 가격을 모아 web/data/gas/<동네id>.json 에 저장한다.
# 앱은 이 파일만 읽는다 (열쇠값이 앱에 들어가지 않고, 오피넷 하루 조회 한도도 아낌).
#
# - 가격: 반경 검색(aroundAll) — 동네 범위를 5km 원 몇 개로 덮어 기름별로 한 번씩
# - 전화·주소·세차·편의점: 상세(detailById) — 처음 보는 주유소와 매주 월요일에만 (나머지는 지난 파일에서 그대로)
# - 시도 평균: avgSidoPrice 한 번
# - 오피넷 좌표는 KATEC(베셀 타원체 TM) → 위경도로 바꿔 저장 (아래 변환은 pyproj 없이 직접 계산)
#
# 열쇠: 환경 변수 OPINET_KEY (깃허브 비밀). 없으면 아무것도 안 하고 끝냄.
import json
import math
import os
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'web', 'data', 'gas')
REGIONS = os.path.join(ROOT, 'web', 'data', 'regions.json')
KEY = os.environ.get('OPINET_KEY', '').strip()
API = 'https://www.opinet.co.kr/api/'
KST = timezone(timedelta(hours=9))

PRODS = ['B027', 'D047', 'B034', 'K015']  # 휘발유 · 경유 · 고급휘발유 · LPG(자동차부탄)
RADIUS = 5000  # 오피넷 최대
STEP_LAT, STEP_LNG = 0.055, 0.065  # 5km 원이 빈틈없이 덮이는 간격 (약 6km 칸)
MARGIN = 0.012  # 동네 범위 밖 약 1km 까지는 같이 담음 (경계 단지용)

calls = 0


# ───────────────── KATEC ↔ 위경도 ─────────────────
# KATEC = +proj=tmerc +lat_0=38 +lon_0=128 +k=0.9999 +x_0=400000 +y_0=600000 +ellps=bessel
#         +towgs84=-115.80,474.99,674.11,1.16,-2.31,-1.63,6.43
WGS = (6378137.0, 1 / 298.257223563)
BES = (6377397.155, 1 / 299.1528128)
TOWGS = (-115.80, 474.99, 674.11, 1.16, -2.31, -1.63, 6.43)
LAT0, LON0, K0, X0, Y0 = math.radians(38), math.radians(128), 0.9999, 400000.0, 600000.0
SEC = math.pi / 180 / 3600


def _geo2ecef(lat, lon, ell):
    a, f = ell
    e2 = f * (2 - f)
    n = a / math.sqrt(1 - e2 * math.sin(lat) ** 2)
    return (n * math.cos(lat) * math.cos(lon), n * math.cos(lat) * math.sin(lon), n * (1 - e2) * math.sin(lat))


def _ecef2geo(x, y, z, ell):
    a, f = ell
    e2 = f * (2 - f)
    lon = math.atan2(y, x)
    p = math.hypot(x, y)
    lat = math.atan2(z, p * (1 - e2))
    for _ in range(8):
        n = a / math.sqrt(1 - e2 * math.sin(lat) ** 2)
        lat = math.atan2(z + e2 * n * math.sin(lat), p)
    return lat, lon


def _helmert(x, y, z, inverse=False):
    tx, ty, tz, rx, ry, rz, s = TOWGS
    rx, ry, rz, s = rx * SEC, ry * SEC, rz * SEC, s * 1e-6
    if not inverse:  # 베셀 → WGS84 (Position Vector)
        return (tx + (1 + s) * (x - rz * y + ry * z),
                ty + (1 + s) * (rz * x + y - rx * z),
                tz + (1 + s) * (-ry * x + rx * y + z))
    x, y, z = (x - tx) / (1 + s), (y - ty) / (1 + s), (z - tz) / (1 + s)
    return (x + rz * y - ry * z, -rz * x + y + rx * z, ry * x - rx * y + z)


def _mlen(lat, ell):  # 적도에서 위도까지 자오선 길이
    a, f = ell
    e2 = f * (2 - f)
    e4, e6 = e2 * e2, e2 ** 3
    return a * ((1 - e2 / 4 - 3 * e4 / 64 - 5 * e6 / 256) * lat - (3 * e2 / 8 + 3 * e4 / 32 + 45 * e6 / 1024) * math.sin(2 * lat)
                + (15 * e4 / 256 + 45 * e6 / 1024) * math.sin(4 * lat) - (35 * e6 / 3072) * math.sin(6 * lat))


def _tm_fwd(lat, lon):
    a, f = BES
    e2 = f * (2 - f)
    ep2 = e2 / (1 - e2)
    n = a / math.sqrt(1 - e2 * math.sin(lat) ** 2)
    t = math.tan(lat) ** 2
    c = ep2 * math.cos(lat) ** 2
    A = (lon - LON0) * math.cos(lat)
    m, m0 = _mlen(lat, BES), _mlen(LAT0, BES)
    x = X0 + K0 * n * (A + (1 - t + c) * A ** 3 / 6 + (5 - 18 * t + t * t + 72 * c - 58 * ep2) * A ** 5 / 120)
    y = Y0 + K0 * (m - m0 + n * math.tan(lat) * (A * A / 2 + (5 - t + 9 * c + 4 * c * c) * A ** 4 / 24
                                                  + (61 - 58 * t + t * t + 600 * c - 330 * ep2) * A ** 6 / 720))
    return x, y


def _tm_inv(x, y):
    a, f = BES
    e2 = f * (2 - f)
    ep2 = e2 / (1 - e2)
    m = _mlen(LAT0, BES) + (y - Y0) / K0
    mu = m / (a * (1 - e2 / 4 - 3 * e2 ** 2 / 64 - 5 * e2 ** 3 / 256))
    e1 = (1 - math.sqrt(1 - e2)) / (1 + math.sqrt(1 - e2))
    p1 = (mu + (3 * e1 / 2 - 27 * e1 ** 3 / 32) * math.sin(2 * mu) + (21 * e1 ** 2 / 16 - 55 * e1 ** 4 / 32) * math.sin(4 * mu)
          + (151 * e1 ** 3 / 96) * math.sin(6 * mu) + (1097 * e1 ** 4 / 512) * math.sin(8 * mu))
    n1 = a / math.sqrt(1 - e2 * math.sin(p1) ** 2)
    r1 = a * (1 - e2) / (1 - e2 * math.sin(p1) ** 2) ** 1.5
    t1 = math.tan(p1) ** 2
    c1 = ep2 * math.cos(p1) ** 2
    d = (x - X0) / (n1 * K0)
    lat = p1 - (n1 * math.tan(p1) / r1) * (d * d / 2 - (5 + 3 * t1 + 10 * c1 - 4 * c1 * c1 - 9 * ep2) * d ** 4 / 24
                                           + (61 + 90 * t1 + 298 * c1 + 45 * t1 * t1 - 252 * ep2 - 3 * c1 * c1) * d ** 6 / 720)
    lon = LON0 + (d - (1 + 2 * t1 + c1) * d ** 3 / 6 + (5 - 2 * c1 + 28 * t1 - 3 * c1 * c1 + 8 * ep2 + 24 * t1 * t1) * d ** 5 / 120) / math.cos(p1)
    return lat, lon


def wgs_to_katec(lat, lng):
    x, y, z = _geo2ecef(math.radians(lat), math.radians(lng), WGS)
    b = _ecef2geo(*_helmert(x, y, z, inverse=True), BES)
    return _tm_fwd(*b)


def katec_to_wgs(x, y):
    lat, lon = _tm_inv(x, y)
    w = _ecef2geo(*_helmert(*_geo2ecef(lat, lon, BES)), WGS)
    return math.degrees(w[0]), math.degrees(w[1])


# ───────────────── 오피넷 부르기 ─────────────────
def call(name, **params):
    global calls
    params.update({'certkey': KEY, 'out': 'json'})
    url = API + name + '?' + urllib.parse.urlencode(params)
    for attempt in range(3):
        try:
            calls += 1
            req = urllib.request.Request(url, headers={'User-Agent': 'df-uridongne/1.0'})
            with urllib.request.urlopen(req, timeout=20) as r:
                j = json.loads(r.read().decode('utf-8', 'replace'))
            oil = (j.get('RESULT') or {}).get('OIL') if isinstance(j, dict) else None
            if oil is None:
                return []
            return oil if isinstance(oil, list) else [oil]
        except Exception as e:  # noqa: BLE001
            print(f'  ! {name} 실패 ({attempt + 1}): {e}')
            time.sleep(2 + attempt * 3)
    return None


def num(v):
    try:
        return float(str(v).strip())
    except Exception:  # noqa: BLE001
        return None


def brand(o):
    return str(o.get('POLL_DIV_CD') or o.get('POLL_DIV_CO') or '').strip()


def yn(v):
    return str(v or '').strip().upper()


def grid(b):
    w, s, e, n = b[0] - MARGIN, b[1] - MARGIN, b[2] + MARGIN, b[3] + MARGIN
    nx, ny = max(1, math.ceil((e - w) / STEP_LNG)), max(1, math.ceil((n - s) / STEP_LAT))
    return [(s + (n - s) * (j + 0.5) / ny, w + (e - w) * (i + 0.5) / nx) for j in range(ny) for i in range(nx)]


def load(path):
    try:
        with open(path, encoding='utf-8') as f:
            return json.load(f)
    except Exception:  # noqa: BLE001
        return None


def collect_area(a, sido_avg, now):
    path = os.path.join(OUT, f"{a['id']}.json")
    old = load(path) or {}
    cache = {s['id']: s for s in old.get('st', []) if isinstance(s, dict) and s.get('id')}
    b = a['bbox']
    w, s, e, n = b[0] - MARGIN, b[1] - MARGIN, b[2] + MARGIN, b[3] + MARGIN
    st = {}
    failed = 0
    for lat, lng in grid(b):
        kx, ky = wgs_to_katec(lat, lng)
        for p in PRODS:
            rows = call('aroundAll.do', x=f'{kx:.1f}', y=f'{ky:.1f}', radius=RADIUS, prodcd=p, sort=2)
            if rows is None:
                failed += 1
                continue
            for o in rows:
                uid = str(o.get('UNI_ID') or '').strip()
                gx, gy, price = num(o.get('GIS_X_COOR')), num(o.get('GIS_Y_COOR')), num(o.get('PRICE'))
                if not uid or gx is None or gy is None:
                    continue
                y, x = katec_to_wgs(gx, gy)
                if not (w <= x <= e and s <= y <= n):
                    continue
                r = st.setdefault(uid, {'id': uid, 'n': str(o.get('OS_NM') or '').strip(), 'b': brand(o), 'y': round(y, 6), 'x': round(x, 6), 'p': {}})
                if price and price > 0:
                    r['p'][p] = int(round(price))
            time.sleep(0.15)
    if not st:
        print(f"  {a['name']}: 받은 주유소 없음 (실패 {failed}) — 지난 파일 유지")
        return None
    monday = now.weekday() == 0 and now.hour < 9
    fresh = 0
    for uid, r in st.items():
        c = cache.get(uid)
        if c and not monday and c.get('d'):
            for k in ('tel', 'a', 'lpg', 'wash', 'cvs', 'maint', 'kp', 'd'):
                if k in c:
                    r[k] = c[k]
            continue
        rows = call('detailById.do', id=uid)
        if rows:
            o = rows[0]
            r['tel'] = str(o.get('TEL') or '').strip()
            r['a'] = str(o.get('NEW_ADR') or o.get('VAN_ADR') or '').strip()
            r['lpg'] = yn(o.get('LPG_YN'))  # N 주유소 · Y 충전소 · C 겸업
            r['wash'] = yn(o.get('CAR_WASH_YN')) == 'Y'
            r['cvs'] = yn(o.get('CVS_YN')) == 'Y'
            r['maint'] = yn(o.get('MAINT_YN')) == 'Y'
            r['kp'] = yn(o.get('KPETRO_YN')) == 'Y'
            r['d'] = now.strftime('%Y-%m-%d')
            # 상세의 가격이 더 최신이면 그걸로 (반경 검색에 안 잡힌 기름도 채움)
            ops = o.get('OIL_PRICE') or []
            for op in (ops if isinstance(ops, list) else [ops]):
                pc, pr = str(op.get('PRODCD') or ''), num(op.get('PRICE'))
                if pc in PRODS and pr and pr > 0:
                    r['p'][pc] = int(round(pr))
            fresh += 1
            time.sleep(0.15)
        elif c:
            for k in ('tel', 'a', 'lpg', 'wash', 'cvs', 'maint', 'kp', 'd'):
                if k in c:
                    r[k] = c[k]
    sts = sorted((r for r in st.values() if r['p']), key=lambda r: (r['p'].get('B027') or r['p'].get('K015') or 9999, r['n']))
    avg = sido_avg.get(a['sido']) or {}
    data = {
        'area_id': a['id'],
        'updated': now.strftime('%Y-%m-%d %H:%M'),
        'sido': a['sido'],
        'avg': {k: v[0] for k, v in avg.items()},
        'diff': {k: v[1] for k, v in avg.items()},
        'st': sts,
    }
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
    print(f"  {a['name']}: 주유소 {len(sts)}곳 (상세 새로 {fresh}, 실패 {failed})")
    return {'id': a['id'], 'name': a['name'], 'updated': data['updated'], 'count': len(sts)}


def main():
    if not KEY:
        print('OPINET_KEY 가 없어 주유소 가격을 모으지 않습니다 (깃허브 비밀에 넣으면 다음 실행부터 모음)')
        return 0
    os.makedirs(OUT, exist_ok=True)
    reg = load(REGIONS) or {}
    want = set(filter(None, os.environ.get('AREAS', '').replace(' ', '').split(',')))
    areas = []
    for sd in reg.get('sido', []):
        for a in sd.get('areas', []):
            if want and a.get('id') not in want:
                continue
            if want or a.get('ready') or a.get('collect'):
                if isinstance(a.get('bbox'), list) and len(a['bbox']) == 4:
                    areas.append({**a, 'sido': sd.get('name', '')})
    now = datetime.now(KST)
    sido_avg = {}
    for o in call('avgSidoPrice.do') or []:
        nm, pc, pr = str(o.get('SIDONM') or '').strip(), str(o.get('PRODCD') or ''), num(o.get('PRICE'))
        if nm and pc in PRODS and pr:
            sido_avg.setdefault(nm, {})[pc] = [round(pr, 1), num(o.get('DIFF')) or 0.0]
    print(f'주유소: 동네 {len(areas)}곳, 시도 평균 {len(sido_avg)}곳')
    idx = load(os.path.join(OUT, 'index.json')) or {}
    done = {x['id']: x for x in idx.get('areas', []) if isinstance(x, dict) and x.get('id')}
    for a in areas:
        try:
            r = collect_area(a, sido_avg, now)
            if r:
                done[a['id']] = r
        except Exception as e:  # noqa: BLE001
            print(f"  ! {a.get('name')} 실패: {e}")
    with open(os.path.join(OUT, 'index.json'), 'w', encoding='utf-8') as f:
        json.dump({'updated': now.strftime('%Y-%m-%d %H:%M'), 'areas': list(done.values())}, f, ensure_ascii=False, separators=(',', ':'))
    print(f'주유소: 오피넷 조회 {calls}회')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as e:  # noqa: BLE001
        print(f'주유소 모으기 실패: {e}')
        sys.exit(0)
