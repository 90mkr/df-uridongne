import re, json, urllib.request
s = urllib.request.urlopen(urllib.request.Request("https://www.data.go.kr/data/15154916/openapi.do", headers={"User-Agent": "Mozilla/5.0"}), timeout=60).read().decode("utf-8", "replace")
for m in re.finditer(r'"parameters":\[(.*?)\]', s):
    for p in re.findall(r'"name":"([^"]+)","description":"([^"]*)"', m.group(1)): print("PARAM", p)
i = s.find('"definitions"'); print("DEF", re.sub(r"\s+", " ", s[i:i+5000]))
