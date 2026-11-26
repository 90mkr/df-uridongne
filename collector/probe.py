import urllib.request, urllib.error
U = "https://dongne-dari.dfmail.workers.dev/dg/B552584/EvCharger/getChargerInfo?pageNo=1&numOfRows=50&dataType=JSON&zcode=28&statId=PW014293&_c=30"
for ua in ["Dart/3.9 (dart:io)", "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36", "okhttp/4.12.0", None]:
    h = {"X-App": "dongne"}
    if ua: h["User-Agent"] = ua
    try:
        r = urllib.request.urlopen(urllib.request.Request(U, headers=h), timeout=30)
        print("UA", ua, r.status, r.read(300).decode("utf-8", "replace"))
    except urllib.error.HTTPError as e:
        print("UA", ua, e.code, e.read(200).decode("utf-8", "replace"))
