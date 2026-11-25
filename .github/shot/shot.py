"""우리동네 화면 사진 (휴대폰 390x844 · 태블릿 가로 1180x820). 사용: shot.py 주소 저장폴더"""
import json
import re
import os
import sys
import time

from playwright.sync_api import sync_playwright

URL, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
log = []
CPX = {"id": "403605977", "n": "힐스테이트송도더테라스", "a": "인천 연수구 센트럴로 415", "ar": "songdo", "y": 37.410352, "x": 126.626616}


def session(b, tag, W, H, steps):
    ctx = b.new_context(viewport={"width": W, "height": H}, device_scale_factor=2, locale="ko-KR")
    ctx.add_init_script(
        "localStorage.setItem('flutter.complex', %s);" % json.dumps(json.dumps(json.dumps(CPX, ensure_ascii=False)))
        + "localStorage.setItem('flutter.school.mine', %s);" % json.dumps(json.dumps(json.dumps(["7341308"])))
        + "localStorage.setItem('flutter.anniv.list', %s);" % json.dumps(json.dumps(json.dumps(ANNIV, ensure_ascii=False)))
    )
    pg = ctx.new_page()
    pg.on("console", lambda m: log.append(f"[{tag} 콘솔] {m.text}"[:300]) if m.type == "error" else None)
    n = [0]

    def shot(name):
        n[0] += 1
        pg.screenshot(path=f"{OUT}/{tag}_{n[0]:02d}_{name}.png")
        log.append(f"사진 {tag}_{n[0]:02d}_{name}")

    def sem():
        pg.evaluate("() => { const e = document.querySelector('flt-semantics-placeholder'); if (e) e.click(); }")
        time.sleep(1)

    def tap(text, wait=3.0, exact=True):
        pat = re.compile(text) if isinstance(text, re.Pattern) is False and text.startswith("^") else None
        gets = (lambda: pg.get_by_text(pat),) if pat else (lambda: pg.get_by_role("button", name=text, exact=exact), lambda: pg.get_by_text(text, exact=exact))
        for get in gets:
            try:
                loc = get()
                for i in range(loc.count()):
                    bb = loc.nth(i).bounding_box()
                    if bb and bb["width"] > 0 and 0 <= bb["y"] < H:
                        pg.mouse.click(bb["x"] + bb["width"] / 2, bb["y"] + bb["height"] / 2)
                        time.sleep(wait)
                        return True
            except Exception as e:
                log.append(f"찾기 오류 {text}: {e}")
        log.append(f"[{tag}] 못 찾음: {text}")
        return False

    def drag(x0, y0, x1, y1, wait=2.0):
        pg.mouse.move(x0, y0)
        pg.mouse.down()
        for i in range(1, 16):
            pg.mouse.move(x0 + (x1 - x0) * i / 15, y0 + (y1 - y0) * i / 15)
            time.sleep(0.02)
        pg.mouse.up()
        time.sleep(wait)

    pg.goto(URL, wait_until="load", timeout=120000)
    time.sleep(9)
    sem()
    global tap_xy, pg_wheel, seen, tap_has
    def tap_xy(x, y, wait=4.0):
        pg.mouse.click(x, y)
        time.sleep(wait)

    def pg_wheel(dy, x=None, y=None):
        pg.mouse.move(x or W // 2, y or H // 2)
        pg.mouse.wheel(0, dy)
        time.sleep(2)

    def tap_has(text, wait=4.0):
        """의미 칸(aria-label·글자)에 text 가 들어 있는 가장 작은 칸 누르기"""
        bb = pg.evaluate("""(t) => { let best = null;
          for (const e of document.querySelectorAll('flt-semantics, [aria-label], [role=button]')) {
            const s = (e.getAttribute('aria-label') || '') + ' ' + (e.textContent || '');
            if (!s.includes(t)) continue;
            const r = e.getBoundingClientRect();
            if (r.width < 4 || r.height < 4 || r.top < 0 || r.top > innerHeight - 40) continue;
            if (!best || r.width * r.height < best.w * best.h) best = {x: r.left + r.width / 2, y: r.top + Math.min(r.height / 2, 40), w: r.width, h: r.height};
          } return best; }""", text)
        if not bb:
            log.append(f"[{tag}] 못 찾음(칸): {text}")
            return False
        pg.mouse.click(bb["x"], bb["y"])
        time.sleep(wait)
        return True

    def seen(text):
        try:
            loc = pg.get_by_text(re.compile(text))
            for i in range(loc.count()):
                bb = loc.nth(i).bounding_box()
                if bb and 0 <= bb["y"] < H - 260:
                    return True
        except Exception:
            pass
        return False
    steps(shot, tap, drag, sem, W, H)
    ctx.close()


def phone(shot, tap, drag, sem, W, H):
    shot("홈")
    for i in range(4):
        pg_wheel(1500)
    pg_wheel(-1200)
    shot("홈_버스지하철")
    tap_has("단지 앞 버스", wait=10) or tap_xy(W // 2, 300, wait=10)
    shot("버스_지도_아래창")
    pg_wheel(500, W // 2, int(H * 0.75))
    shot("버스_아래창_내림")
    tap_has("목록으로 보기", wait=6)
    shot("버스_목록")


def school(shot, tap, drag, sem, W, H):
    tap_has("생활 도구", wait=4)
    shot("생활도구")
    tap_has("급식", wait=8)
    shot("학교급식")
    pg_wheel(900)
    shot("학교급식_아래")


def parcel(shot, tap, drag, sem, W, H):
    tap_has("생활 도구", wait=4)
    tap_has("택배", wait=8)
    shot("택배우편")


def trash(shot, tap, drag, sem, W, H):
    tap_has("생활 도구", wait=4)
    tap_has("분리수거", wait=8)
    shot("쓰레기")
    pg_wheel(700)
    shot("쓰레기_아래")


ANNIV = [{'id': 1, 't': '기타', 'k': '기타', 'm': 11, 'd': 25, 'l': False, 'r': [0, 1]}, {'id': 2, 't': '성하 생일', 'k': '생일', 'm': 6, 'd': 16, 'l': False, 'y': 1990, 'r': [0, 1]}, {'id': 3, 't': '엄마 제사', 'k': '제사', 'm': 6, 'd': 25, 'l': True, 'r': [0, 1]}, {'id': 4, 't': '결혼기념일', 'k': '기념일', 'm': 11, 'd': 24, 'l': False, 'y': 2010, 'r': [0, 1]}]


def anniv(shot, tap, drag, sem, W, H):
    tap_has("생활 도구", wait=4)
    tap_has("기념일", wait=8)
    shot("기념일")


def tablet(shot, tap, drag, sem, W, H):
    shot("홈")
    for i in range(4):
        pg_wheel(1500)
    pg_wheel(-1200)
    shot("홈_버스")
    tap_has("단지 앞 버스", wait=10) or tap_xy(W // 2, 300, wait=10)
    shot("버스_지도_창")


with sync_playwright() as p:
    b = p.chromium.launch(args=["--use-gl=swiftshader", "--enable-unsafe-swiftshader"])
    for tag, W, H, f in [("폰작은", 360, 740, phone), ("폰큰", 430, 932, phone), ("폰택배", 430, 932, parcel), ("폰작은택배", 360, 740, parcel), ("폰쓰레기", 430, 932, trash), ("폰작은쓰레기", 360, 740, trash), ("폰기념일", 430, 932, anniv), ("폰작은기념일", 360, 740, anniv), ("탭", 1180, 820, tablet), ("탭세로", 820, 1180, tablet)]:
        try:
            session(b, tag, W, H, f)
        except Exception as e:
            log.append(f"[{tag}] 오류 {e}")
    b.close()

open(f"{OUT}/log.txt", "w").write("\n".join(log))
print("\n".join(log))
