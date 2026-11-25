# 주유소 가격 모으기 (주유소 담당 방만 고침) — 0.3 전국판 (대표님 11-25: 출시 날부터 전국)
#
# 오피넷 무료 열쇠는 하루 300회. 그래서 반경 검색 대신 「지역별 최저가 주유소 20곳(lowTop10)」을 쓴다.
# - 휘발유·경유: 전국 시군구(약 230곳)마다 최저가 20곳 → 한 번에 한 기름·한 시군구 = 1회
# - LPG: 시도(17곳)마다 최저가 20곳
# - 하루 예산(GAS_DAY_BUDGET, 기본 285회) 안에서 「가장 오래된 것부터」 새로 받는다.
#   → 지금 한도로는 휘발유·경유가 대략 이틀에 한 번씩 번갈아 새로워지고 LPG·평균은 매일.
#   → 오피넷이 한도를 늘려 주면 예산 숫자만 올리면 모두 매일 새로워진다.
# - 하루 3번 불려도 그날 예산을 나눠 쓴다(state.json 에 오늘 쓴 횟수 기록).
# 저장: web/data/gas/index.json (파일 목록·범위·시도 평균), web/data/gas/a/<지역코드>.json (주유소·가격)
# 앱은 단지 위치를 품는 파일들만 받아 합친다. 열쇠는 깃허브 비밀 OPINET_KEY (없으면 아무것도 안 함).
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
AREA_DIR = os.path.join(OUT, 'a')
KEY = os.environ.get('OPINET_KEY', '').strip()
API = 'https://www.opinet.co.kr/api/'
KST = timezone(timedelta(hours=9))

DAY_BUDGET = int(os.environ.get('GAS_DAY_BUDGET', '285'))
SGG_FUELS = ['B027', 'D047']  # 시군구 단위
SIDO_FUELS = ['K015']  # 시도 단위 (충전소는 수가 적음)
CNT = 20
calls = 0
budget = 0


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


# ───────────────── 오피넷 부르기
def call(name, **params):
    global calls
    if calls >= budget:
        return None
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
            if calls >= budget:
                return None
            time.sleep(2 + attempt * 3)
    return None


def num(v):
    try:
        return float(str(v).strip())
    except Exception:  # noqa: BLE001
        return None


def brand(o):
    return str(o.get('POLL_DIV_CD') or o.get('POLL_DIV_CO') or '').strip()


def load(path):
    try:
        with open(path, encoding='utf-8') as f:
            return json.load(f)
    except Exception:  # noqa: BLE001
        return None


def save(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, separators=(',', ':'))


def age_h(stamp, now):
    try:
        t = datetime.strptime(stamp, '%Y-%m-%d %H:%M').replace(tzinfo=KST)
        return (now - t).total_seconds() / 3600
    except Exception:  # noqa: BLE001
        return 10 ** 6


# ───────────────── 지역 코드 (한 달에 한 번)
def areas(state, now):
    a = state.get('areas')
    if a and age_h(state.get('areas_at', ''), now) < 24 * 30:
        return a
    sido = call('areaCode.do')
    if not sido:
        return a or []
    out = []
    for s in sido:
        sc, sn = str(s.get('AREA_CD') or '').strip(), str(s.get('AREA_NM') or '').strip()
        if not sc:
            continue
        out.append({'c': sc, 'n': sn, 'lv': 'sido', 'sido': sc, 'sn': sn})
        for g in call('areaCode.do', area=sc) or []:
            gc, gn = str(g.get('AREA_CD') or '').strip(), str(g.get('AREA_NM') or '').strip()
            if len(gc) == 4:
                out.append({'c': gc, 'n': gn, 'lv': 'sgg', 'sido': sc, 'sn': sn})
    if out:
        state['areas'], state['areas_at'] = out, now.strftime('%Y-%m-%d %H:%M')
    return out or a or []


# ───────────────── 한 지역·한 기름 받기 → 지역 파일 고치기
def fetch(area, fuel, now):
    rows = call('lowTop10.do', prodcd=fuel, area=area['c'], cnt=CNT)
    if rows is None:
        return False
    path = os.path.join(AREA_DIR, f"{area['c']}.json")
    d = load(path) or {}
    st = {x['id']: x for x in d.get('st', []) if isinstance(x, dict) and x.get('id')}
    # 이 기름의 지난 값은 지움 (20곳 밖으로 밀린 곳은 지금 값을 모르므로)
    for x in st.values():
        x.get('p', {}).pop(fuel, None)
    for o in rows:
        uid = str(o.get('UNI_ID') or '').strip()
        gx, gy, price = num(o.get('GIS_X_COOR')), num(o.get('GIS_Y_COOR')), num(o.get('PRICE'))
        if not uid or gx is None or gy is None or not price or price <= 0:
            continue
        y, x = katec_to_wgs(gx, gy)
        r = st.setdefault(uid, {'id': uid, 'p': {}})
        r.update({'n': str(o.get('OS_NM') or '').strip(), 'b': brand(o), 'y': round(y, 6), 'x': round(x, 6),
                  'a': str(o.get('NEW_ADR') or o.get('VAN_ADR') or '').strip()})
        r.setdefault('p', {})[fuel] = int(round(price))
    sts = [x for x in st.values() if x.get('p')]
    up = d.get('up', {})
    up[fuel] = now.strftime('%Y-%m-%d %H:%M')
    data = {'c': area['c'], 'n': area['n'], 'lv': area['lv'], 'sido': area['sido'], 'sn': area['sn'], 'up': up,
            'st': sorted(sts, key=lambda r: (r['p'].get('B027') or r['p'].get('D047') or r['p'].get('K015') or 9999))}
    save(path, data)
    return True


def bbox(path):
    d = load(path) or {}
    ys = [s['y'] for s in d.get('st', []) if 'y' in s]
    xs = [s['x'] for s in d.get('st', []) if 'x' in s]
    if not ys:
        return None
    return [round(min(xs), 4), round(min(ys), 4), round(max(xs), 4), round(max(ys), 4)]


def main():
    global budget
    if not KEY:
        print('OPINET_KEY 가 없어 주유소 가격을 모으지 않습니다')
        return 0
    now = datetime.now(KST)
    spath = os.path.join(OUT, 'state.json')
    state = load(spath) or {}
    today = now.strftime('%Y-%m-%d')
    used = state.get('used', 0) if state.get('day') == today else 0
    budget = max(0, DAY_BUDGET - used)
    if budget <= 0:
        print(f'주유소: 오늘 예산 다 씀 ({used}회)')
        return 0
    al = areas(state, now)
    # 평균: 시도 평균 + 전국 평균 (매 실행 2회 — 그날 첫 실행에서만)
    avg = state.get('avg', {})
    if used == 0 or not avg:
        nat = call('avgAllPrice.do')
        sid = call('avgSidoPrice.do')
        if sid:
            avg = {}
            for o in sid:
                sc, pc, pr = str(o.get('SIDOCD') or '').strip(), str(o.get('PRODCD') or ''), num(o.get('PRICE'))
                if sc and pc in ('B027', 'D047', 'K015', 'B034') and pr:
                    avg.setdefault(sc, {'n': str(o.get('SIDONM') or '').strip()})[pc] = [round(pr, 1), num(o.get('DIFF')) or 0.0]
        if nat:
            for o in nat:
                pc, pr = str(o.get('PRODCD') or ''), num(o.get('PRICE'))
                if pc in ('B027', 'D047', 'K015', 'B034') and pr:
                    avg.setdefault('00', {'n': '전국'})[pc] = [round(pr, 1), num(o.get('DIFF')) or 0.0]
        state['avg'] = avg
    # 할 일: (나이 + 휘발유 가산) 큰 순서
    jobs = []
    for a in al:
        fuels = SGG_FUELS if a['lv'] == 'sgg' else SIDO_FUELS
        d = load(os.path.join(AREA_DIR, f"{a['c']}.json")) or {}
        for f in fuels:
            h = age_h(d.get('up', {}).get(f, ''), now)
            if h < 18:
                continue
            jobs.append((h + (8 if f == 'B027' else 0) + (30 if f == 'K015' else 0), a, f))
    jobs.sort(key=lambda j: -j[0])
    done = 0
    for _, a, f in jobs:
        if calls >= budget:
            break
        if fetch(a, f, now):
            done += 1
        time.sleep(0.12)
    # 목록 파일
    lst = []
    for a in al:
        path = os.path.join(AREA_DIR, f"{a['c']}.json")
        b = bbox(path)
        if b:
            d = load(path) or {}
            lst.append({'c': a['c'], 'n': a['n'], 'lv': a['lv'], 'sido': a['sido'], 'sn': a['sn'], 'b': b, 'up': d.get('up', {})})
    save(os.path.join(OUT, 'index.json'), {'updated': now.strftime('%Y-%m-%d %H:%M'), 'avg': avg, 'list': lst})
    state.update({'day': today, 'used': used + calls})
    save(spath, state)
    print(f'주유소: 지역 {len(al)}곳 · 이번에 받은 것 {done}건 · 남은 할 일 {max(0, len(jobs) - done)}건 · 오피넷 {calls}회 (오늘 {used + calls}/{DAY_BUDGET})')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as e:  # noqa: BLE001
        print(f'주유소 모으기 실패: {e}')
        sys.exit(0)
