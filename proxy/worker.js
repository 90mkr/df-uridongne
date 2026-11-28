// 우리동네 「중간 다리」 — 공공데이터 열쇠를 서버에만 두고 대신 불러 준다 (본부 방만 고침)
// 클라우드플레어 Workers (이름: dongne-dari). 비밀 변수 DG_KEY = 공공데이터포털 일반 인증키
// 사용: https://<다리>/dg/<apis.data.go.kr 뒤 경로>?<원래 질문 (serviceKey 빼고)>
//   예) /dg/1613000/ArvlInfoInqireService/getSttnAcctoArvlPrearngeInfoList?cityCode=23&nodeId=ICB..&_type=json
//   _c=초  → 묶어 두는 시간 (기본 30초, 최대 12시간). 노선·정류장 목록처럼 잘 안 바뀌는 건 43200
// 카카오 장소: https://<다리>/kk/<v2/local/... 경로>?<질문>&_c=초 — 비밀 변수 KK_KEY = 카카오 REST API 키
//   쓰는 순간에만 부르고 저장·캐시하지 않는다 (카카오 정책: 실시간 호출만).
// 바로 알림: POST /notify?doc=<문서 경로> — 앱이 글·댓글·의견을 올린 직후 부름 (대표님 11-28)
//   비밀 변수 FIREBASE_SA = 파이어베이스 서비스 계정 JSON. 다리가 그 문서를 직접 읽어 확인한 뒤 알림을 보낸다
//   (앱이 보낸 글자를 그대로 쓰지 않음 · 3분 안에 만든 문서만 · 한 번만 → 문서에 nt 표시)
// 막기: 미리보기 주소(github.io)·내 컴퓨터에서 온 요청, 또는 앱이 보내는 X-App: dongne 머리값만 통과
const ORIGINS = ['https://90mkr.github.io', 'http://localhost', 'http://127.0.0.1'];
const PATHS = /^(1613000|1360000|B552584|B552657|B551182|B553077|1741000|1611000|B551011|1471000|1230000|1192000|B190001|B552555|6260000|B553530|1543061|B552061|1262000|B552015)\//;

function cors(origin) {
  return {
    'Access-Control-Allow-Origin': origin && ORIGINS.some((o) => origin.startsWith(o)) ? origin : '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'X-App',
    'Access-Control-Max-Age': '86400',
  };
}

export default {
  async fetch(req, env, ctx) {
    const url = new URL(req.url);
    const origin = req.headers.get('Origin') || '';
    const h = cors(origin);
    if (req.method === 'OPTIONS') return new Response(null, { headers: h });
    if (url.pathname === '/' || url.pathname === '/ping') return new Response('dongne dari OK', { headers: { ...h, 'content-type': 'text/plain; charset=utf-8' } });
    if (req.method === 'GET' && url.pathname.startsWith('/kk/')) return kakao(req, url, env, ctx, h);
    if (req.method === 'POST' && url.pathname === '/notify') return notify(req, url, env, h);
    if (req.method !== 'GET' || !url.pathname.startsWith('/dg/')) return new Response('not found', { status: 404, headers: h });

    const okOrigin = ORIGINS.some((o) => origin.startsWith(o));
    const okApp = req.headers.get('X-App') === 'dongne';
    if (!okOrigin && !okApp) return new Response('forbidden', { status: 403, headers: h });

    const path = url.pathname.slice(4);
    if (!PATHS.test(path)) return new Response('path not allowed', { status: 403, headers: h });
    if (!env.DG_KEY) return new Response('no key', { status: 500, headers: h });

    const q = new URLSearchParams(url.search);
    const ttl = Math.min(Math.max(parseInt(q.get('_c') || '30', 10) || 30, 10), 43200);
    q.delete('_c');
    q.delete('serviceKey');
    q.delete('ServiceKey');
    q.sort();
    const qs = q.toString();

    // 같은 질문은 묶어 두기 (열쇠 없는 주소로 저장)
    const cache = caches.default;
    const ckey = new Request(`https://dari.cache/${path}?${qs}`);
    let res = await cache.match(ckey);
    if (!res) {
      const key = env.DG_KEY.includes('%') ? env.DG_KEY : encodeURIComponent(env.DG_KEY);
      const up = await fetch(`https://apis.data.go.kr/${path}?serviceKey=${key}${qs ? '&' + qs : ''}`, { headers: { Accept: '*/*' } });
      const body = await up.arrayBuffer();
      res = new Response(body, {
        status: up.status,
        headers: { 'content-type': up.headers.get('content-type') || 'application/json; charset=utf-8', 'Cache-Control': `public, max-age=${ttl}` },
      });
      if (up.ok) ctx.waitUntil(cache.put(ckey, res.clone()));
    }
    const out = new Response(res.body, res);
    for (const [k, v] of Object.entries(h)) out.headers.set(k, v);
    return out;
  },
};

const KK_PATHS = /^v2\/local\/(search\/(keyword|category|address)|geo\/coord2(regioncode|address))\.json$/;

async function kakao(req, url, env, ctx, h) {
  const origin = req.headers.get('Origin') || '';
  if (!ORIGINS.some((o) => origin.startsWith(o)) && req.headers.get('X-App') !== 'dongne') return new Response('forbidden', { status: 403, headers: h });
  const path = url.pathname.slice(4);
  if (!KK_PATHS.test(path)) return new Response('path not allowed', { status: 403, headers: h });
  if (!env.KK_KEY) return new Response('no key', { status: 500, headers: h });
  const q = new URLSearchParams(url.search);
  // 카카오 정책: 결과를 저장·묶어 두지 않는다 (실시간 호출만) — 그래서 여기서는 캐시하지 않고 그대로 전달
  q.delete('_c');
  const up = await fetch(`https://dapi.kakao.com/${path}?${q.toString()}`, { headers: { Authorization: `KakaoAK ${env.KK_KEY}` } });
  const res = new Response(await up.arrayBuffer(), { status: up.status, headers: { 'content-type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' } });
  const out = new Response(res.body, res);
  for (const [k, v] of Object.entries(h)) out.headers.set(k, v);
  return out;
}


// ---------------- 바로 알림 (FCM) ----------------
const BOARD_NAMES = { news: '공지·소식', share: '나눔터', free: '자유게시판', rec: '업체 추천', lost: '분실물' };
let _tok = null, _tokExp = 0, _proj = '';

function b64url(buf) {
  const s = typeof buf === 'string' ? btoa(unescape(encodeURIComponent(buf))) : btoa(String.fromCharCode(...new Uint8Array(buf)));
  return s.replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_');
}

async function gToken(env) {
  if (_tok && Date.now() < _tokExp) return _tok;
  const sa = JSON.parse(env.FIREBASE_SA);
  _proj = sa.project_id;
  const now = Math.floor(Date.now() / 1000);
  const head = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claim = b64url(JSON.stringify({
    iss: sa.client_email, aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/firebase.messaging',
  }));
  const pem = sa.private_key.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey('pkcs8', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(`${head}.${claim}`));
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${head}.${claim}.${b64url(sig)}`,
  });
  const j = await r.json();
  _tok = j.access_token;
  _tokExp = Date.now() + 50 * 60 * 1000;
  return _tok;
}

const fv = (d, k) => { const v = (d.fields || {})[k] || {}; return v.stringValue ?? v.timestampValue ?? (v.booleanValue ?? ''); };

async function fsGet(tok, path) {
  const r = await fetch(`https://firestore.googleapis.com/v1/projects/${_proj}/databases/(default)/documents/${path}`, { headers: { Authorization: `Bearer ${tok}` } });
  return r.ok ? r.json() : null;
}

async function fsMark(tok, path) {
  await fetch(`https://firestore.googleapis.com/v1/projects/${_proj}/databases/(default)/documents/${path}?updateMask.fieldPaths=nt`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${tok}`, 'content-type': 'application/json' },
    body: JSON.stringify({ fields: { nt: { booleanValue: true } } }),
  });
}

async function fcm(tok, topic, title, body, data) {
  const t = topic.replace(/[^a-zA-Z0-9\-_.~%]/g, '_');
  const r = await fetch(`https://fcm.googleapis.com/v1/projects/${_proj}/messages:send`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${tok}`, 'content-type': 'application/json' },
    body: JSON.stringify({ message: { topic: t, notification: { title, body }, data, android: { notification: { channel_id: 'board' } } } }),
  });
  return r.ok;
}

async function notify(req, url, env, h) {
  const json = (o, s = 200) => new Response(JSON.stringify(o), { status: s, headers: { ...h, 'content-type': 'application/json' } });
  if (req.headers.get('X-App') !== 'dongne') return json({ ok: false }, 403);
  if (!env.FIREBASE_SA) return json({ ok: false, why: 'no sa' }, 500);
  const doc = url.searchParams.get('doc') || '';
  const m = doc.match(/^(dn_feedback|dn_posts)\/([A-Za-z0-9]{10,40})(?:\/cm\/([A-Za-z0-9]{10,40}))?$/);
  if (!m || (m[1] === 'dn_feedback' && m[3])) return json({ ok: false, why: 'bad doc' }, 400);
  const tok = await gToken(env);
  const d = await fsGet(tok, doc);
  if (!d) return json({ ok: false, why: 'none' }, 404);
  const at = Date.parse(fv(d, 'at'));
  if (!at || Date.now() - at > 3 * 60 * 1000 || fv(d, 'nt') === true) return json({ ok: true, skip: true });
  await fsMark(tok, doc); // 한 번만 (깃허브 15분 알림도 이 표시가 있으면 건너뜀)
  let sent = false;
  if (m[1] === 'dn_feedback') {
    const kind = fv(d, 'kind') === 'bug' ? '오류 신고' : '개선 제안';
    sent = await fcm(tok, 'dn_admin', `[우동콕 의견] ${kind}`, `${fv(d, 'name') || '이용자'} · ${String(fv(d, 'text')).slice(0, 80)}`, { open: 'feedback' });
  } else if (!m[3]) {
    const cid = fv(d, 'cid'), cat = fv(d, 'cat');
    const where = cid.startsWith('a_') ? '우리 동네' : '우리 단지';
    sent = await fcm(tok, `dn_b_${cid}_${cat}`, `[${where} ${BOARD_NAMES[cat] || '게시판'}] 새 글`, String(fv(d, 't')).slice(0, 60), { open: 'board', cid, cat });
  } else {
    const p = await fsGet(tok, `dn_posts/${m[2]}`);
    const owner = p ? fv(p, 'uid') : '';
    if (p && owner && owner !== fv(d, 'uid')) {
      sent = await fcm(tok, `dn_u_${owner}`, '내 글에 댓글이 달렸어요', `「${String(fv(p, 't')).slice(0, 30)}」 ${String(fv(d, 'b')).slice(0, 40)}`, { open: 'board', cid: fv(p, 'cid') });
    }
  }
  return json({ ok: true, sent });
}
