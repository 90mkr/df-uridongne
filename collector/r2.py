"""폴더를 클라우드플레어 R2(yogikok-data)에 올린다 — 바뀐 파일만, gzip 압축 (본부 방만 고침).
    R2_KEY / R2_SECRET / R2_ACCOUNT  깃허브 비밀     사용: python3 r2.py <폴더> [앞 경로]
"""
import gzip, hashlib, os, subprocess, sys
try:
    import boto3
except ImportError:
    subprocess.run([sys.executable, "-m", "pip", "install", "-q", "boto3"], check=True)
    import boto3
from concurrent.futures import ThreadPoolExecutor

src = sys.argv[1]
prefix = sys.argv[2] if len(sys.argv) > 2 else ""
s3 = boto3.client("s3", endpoint_url=f"https://{os.environ['R2_ACCOUNT']}.r2.cloudflarestorage.com",
                  aws_access_key_id=os.environ["R2_KEY"], aws_secret_access_key=os.environ["R2_SECRET"], region_name="auto")
B = os.environ.get("R2_BUCKET", "yogikok-data")
old = {}
for page in s3.get_paginator("list_objects_v2").paginate(Bucket=B, Prefix=prefix):
    for o in page.get("Contents", []):
        old[o["Key"]] = o.get("ETag", "").strip('"')
files = [os.path.join(d, f) for d, _, fs in os.walk(src) if "/.git" not in d for f in fs if not f.startswith(".")]

def up(p):
    key = prefix + os.path.relpath(p, src).replace(os.sep, "/")
    raw = open(p, "rb").read()
    body = gzip.compress(raw, 6, mtime=0) if p.endswith(".json") else raw
    if old.get(key) == hashlib.md5(body).hexdigest():
        return 0
    ct = "application/json; charset=utf-8" if p.endswith(".json") else "application/octet-stream"
    extra = {"ContentEncoding": "gzip"} if p.endswith(".json") else {}
    s3.put_object(Bucket=B, Key=key, Body=body, ContentType=ct, CacheControl="public, max-age=600", **extra)
    return 1

with ThreadPoolExecutor(16) as ex:
    n = sum(ex.map(up, files))
print(f"R2: {len(files)}개 중 {n}개 새로 올림")
