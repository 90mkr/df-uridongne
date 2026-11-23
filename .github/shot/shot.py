"""우리동네 화면 사진 (휴대폰 390x844 · 태블릿 가로 1180x820). 사용: shot.py 주소 저장폴더"""
import json
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
        for get in (lambda: pg.get_by_role("button", name=text, exact=exact), lambda: pg.get_by_text(text, exact=exact)):
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
    steps(shot, tap, drag, sem, W, H)
    ctx.close()


def phone(shot, tap, drag, sem, W, H):
    shot("홈")
    tap("전화번호부")
    shot("전화번호부")
    tap("세탁소", wait=7)
    shot("세탁소_지도")
    drag(W - 40, H - 120, 60, H - 120)
    shot("카드_넘김")
    drag(W - 40, H - 120, 60, H - 120)
    shot("카드_넘김2")
    tap("이웃 추천 순")
    tap("목록")
    shot("목록")
    tap("지도")
    tap("음식점", wait=1) if False else None
    pg_back = tap("−", wait=2)
    shot("축소")


def tablet(shot, tap, drag, sem, W, H):
    tap("전화번호부")
    shot("전화번호부")
    tap("세탁소", wait=7)
    shot("세탁소_나눔")
    drag(W * 0.75, H * 0.5, W * 0.6, H * 0.35)
    shot("지도_옮김")
    tap("−", wait=2)
    tap("−", wait=3)
    shot("지도_축소")


with sync_playwright() as p:
    b = p.chromium.launch(args=["--use-gl=swiftshader", "--enable-unsafe-swiftshader"])
    for tag, W, H, f in [("폰", 390, 844, phone), ("탭", 1180, 820, tablet)]:
        try:
            session(b, tag, W, H, f)
        except Exception as e:
            log.append(f"[{tag}] 오류 {e}")
    b.close()

open(f"{OUT}/log.txt", "w").write("\n".join(log))
print("\n".join(log))
