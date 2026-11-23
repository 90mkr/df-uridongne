"""날씨·미세먼지: 에어코리아 측정소 위치 모으기 (날씨 담당 방만 고침).

앱은 단지에서 가장 가까운 측정소의 실시간 미세먼지를 부르므로,
전국 측정소 이름·위경도를 web/data/weather/stations.json 으로 저장해 둔다.
(측정소는 자주 바뀌지 않아 매주 한 번이면 충분. 실패하면 지난 파일을 그대로 둔다.)

    AIRKOREA_KEY 또는 DATA_GO_KR_KEY  공공데이터포털 열쇠 (에어코리아 측정소정보 조회 서비스)
"""
import json
import os
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "web", "data", "weather")
KST = timezone(timedelta(hours=9))
KEY = (os.environ.get("AIRKOREA_KEY") or os.environ.get("DATA_GO_KR_KEY") or "").strip()


def key_param():
    # 「인코딩」 열쇠(%가 들어 있음)는 그대로, 「디코딩」 열쇠는 인코딩해서
    return KEY if "%" in KEY else urllib.parse.quote(KEY, safe="")


def fetch(page):
    url = (
        "https://apis.data.go.kr/B552584/MsrstnInfoInqireSvc/getMsrstnList"
        f"?serviceKey={key_param()}&returnType=json&numOfRows=1000&pageNo={page}"
    )
    with urllib.request.urlopen(url, timeout=30) as r:
        body = r.read().decode("utf-8")
    if not body.lstrip().startswith("{"):
        raise RuntimeError("JSON이 아님 (열쇠·신청 확인): " + body[:200])
    b = json.loads(body)["response"]["body"]
    items = b.get("items") or []
    if isinstance(items, dict):
        items = items.get("item") or []
    return items, int(b.get("totalCount") or 0)


def main():
    if not KEY:
        print("날씨: 열쇠가 없어 건너뜀")
        return
    out, page, total = [], 1, 1
    while len(out) < total and page <= 5:
        items, total = fetch(page)
        if not items:
            break
        for s in items:
            try:
                a, b = float(s.get("dmX")), float(s.get("dmY"))
            except (TypeError, ValueError):
                continue
            lat, lng = (a, b) if a < 90 else (b, a)  # dmX·dmY 순서가 바뀌어 와도 맞게
            if not (32 < lat < 39.5 and 124 < lng < 132):
                continue
            out.append({"n": s.get("stationName", ""), "y": round(lat, 5), "x": round(lng, 5), "a": s.get("addr", "")})
        page += 1
    if len(out) < 100:
        print(f"날씨: 측정소가 {len(out)}곳뿐이라 저장하지 않음")
        return
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "stations.json"), "w", encoding="utf-8") as f:
        json.dump({"updated": datetime.now(KST).strftime("%Y-%m-%d %H:%M"), "stations": out}, f, ensure_ascii=False, separators=(",", ":"))
    print(f"날씨: 측정소 {len(out)}곳 저장")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # 실패해도 다른 기능은 계속
        print("날씨: 측정소 모으기 실패 —", e)
