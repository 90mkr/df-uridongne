"""게시판 알림 보내기 (본부 방만 고침) — 깃허브 「알림 보내기」가 15분마다.
새 글(dn_posts) → 그 게시판 주제(dn_b_<게시판키>_<분류>), 새 댓글 → 글쓴이 주제(dn_u_<회원id>).
    FIREBASE_SA  파이어베이스 서비스 계정 JSON (깃허브 비밀) — 없으면 건너뜀
    STATE        지난번 본 시각을 적어 두는 파일 (액션 캐시)
"""
import json, os, re, sys, time, urllib.request
from datetime import datetime, timedelta, timezone

SA = os.environ.get("FIREBASE_SA", "").strip()
STATE = os.environ.get("STATE", "/tmp/push_state/last.txt")
NAMES = {"news": "공지·소식", "share": "나눔터", "free": "자유게시판", "rec": "업체 추천", "lost": "분실물"}


def safe(s):
    return re.sub(r"[^a-zA-Z0-9\-_.~%]", "_", s)


def token(sa):
    from google.oauth2 import service_account
    import google.auth.transport.requests as gr
    cred = service_account.Credentials.from_service_account_info(sa, scopes=["https://www.googleapis.com/auth/datastore", "https://www.googleapis.com/auth/firebase.messaging"])
    cred.refresh(gr.Request())
    return cred.token


def call(url, tok, body=None):
    req = urllib.request.Request(url, data=json.dumps(body).encode() if body is not None else None, method="POST" if body is not None else "GET",
                                 headers={"Authorization": f"Bearer {tok}", "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode() or "{}")


def query(project, tok, coll, since, all_desc=False):
    body = {"structuredQuery": {"from": [{"collectionId": coll, "allDescendants": all_desc}],
                                "where": {"fieldFilter": {"field": {"fieldPath": "at"}, "op": "GREATER_THAN", "value": {"timestampValue": since}}},
                                "limit": 200}}
    url = f"https://firestore.googleapis.com/v1/projects/{project}/databases/(default)/documents:runQuery"
    out = []
    for row in call(url, tok, body) if True else []:
        d = row.get("document")
        if d:
            out.append(d)
    return out


def sv(d, k):
    v = (d.get("fields") or {}).get(k) or {}
    return v.get("stringValue") or v.get("timestampValue") or ""


def send(project, tok, topic, title, body, data):
    msg = {"message": {"topic": topic, "notification": {"title": title, "body": body}, "data": data,
                       "android": {"notification": {"channel_id": "board"}}}}
    try:
        call(f"https://fcm.googleapis.com/v1/projects/{project}/messages:send", tok, msg)
        return True
    except Exception as e:
        print("  보내기 실패", topic, repr(e)[:120])
        return False


def main():
    if not SA:
        print("FIREBASE_SA 가 없어 건너뜁니다.")
        return 0
    sa = json.loads(SA)
    project = sa["project_id"]
    tok = token(sa)
    now = datetime.now(timezone.utc)
    try:
        since = open(STATE).read().strip()
    except Exception:
        since = (now - timedelta(minutes=20)).strftime("%Y-%m-%dT%H:%M:%SZ")
    n = 0
    for d in query(project, tok, "dn_posts", since):
        cid, cat, t = sv(d, "cid"), sv(d, "cat"), sv(d, "t")
        where = "우리 동네" if cid.startswith("a_") else "우리 단지"
        n += send(project, tok, safe(f"dn_b_{cid}_{cat}"), f"[{where} {NAMES.get(cat, '게시판')}] 새 글", t[:60], {"open": "board", "cid": cid, "cat": cat})
    for d in query(project, tok, "cm", since, all_desc=True):
        parent = d["name"].rsplit("/cm/", 1)[0]
        try:
            p = call(f"https://firestore.googleapis.com/v1/{parent}", tok)
        except Exception:
            continue
        uid = sv(p, "uid")
        if not uid or uid == sv(d, "uid"):
            continue
        n += send(project, tok, safe(f"dn_u_{uid}"), "내 글에 댓글이 달렸어요", f"「{sv(p, 't')[:30]}」 {sv(d, 'b')[:40]}", {"open": "board", "cid": sv(p, "cid")})
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    open(STATE, "w").write(now.strftime("%Y-%m-%dT%H:%M:%SZ"))
    print(f"보낸 알림 {n}건 (기준 {since})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
