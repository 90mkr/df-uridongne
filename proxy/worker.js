// 우리동네 「중간 다리」 — 공공데이터 열쇠를 서버에만 두고 대신 불러 준다 (본부 방만 고침)
// 클라우드플레어 Workers (이름: dongne-dari). 비밀 변수 DG_KEY = 공공데이터포털 일반 인증키
// 사용: https://<다리>/dg/<apis.data.go.kr 뒤 경로>?<원래 질문 (serviceKey 빼고)>
//   예) /dg/1613000/ArvlInfoInqireService/getSttnAcctoArvlPrearngeInfoList?cityCode=23&nodeId=ICB..&_type=json
//   _c=초  → 묶어 두는 시간 (기본 30초, 최대 12시간). 노선·정류장 목록처럼 잘 안 바뀌는 건 43200
// 카카오 장소: https://<다리>/kk/<v2/local/... 경로>?<질문>&_c=초 — 비밀 변수 KK_KEY = 카카오 REST API 키
//   쓰는 순간에만 부른다(미리 긁어 모으지 않음, 카카오 정책). 같은 질문은 최대 7일 묶어 둔다.
// 막기: 미리보기 주소(github.io)·내 컴퓨터에서 온 요청, 또는 앱이 보내는 X-App: dongne 머리값만 통과
const ORIGINS = ['https://90mkr.github.io', 'http://localhost', 'http://127.0.0.1'];
const PATHS = /^(1613000|1360000|B552584|B552657|B551182|B553077|1741000|1611000|B551011|1471000|1230000|1192000|B190001|B552555|6260000|B553530|1543061|B552061|1262000|B552015)\//;

function cors(origin) {
  return {
    'Access-Control-Allow-Origin': origin && ORIGINS.some((o) => origin.startsWith(o)) ? origin : '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
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
  const ttl = Math.min(Math.max(parseInt(q.get('_c') || '86400', 10) || 86400, 60), 604800);
  q.delete('_c');
  q.sort();
  const qs = q.toString();
  const cache = caches.default;
  const ckey = new Request(`https://dari.cache/kk/${path}?${qs}`);
  let res = await cache.match(ckey);
  if (!res) {
    const up = await fetch(`https://dapi.kakao.com/${path}?${qs}`, { headers: { Authorization: `KakaoAK ${env.KK_KEY}` } });
    const body = await up.arrayBuffer();
    res = new Response(body, { status: up.status, headers: { 'content-type': 'application/json; charset=utf-8', 'Cache-Control': `public, max-age=${ttl}` } });
    if (up.ok) ctx.waitUntil(cache.put(ckey, res.clone()));
  }
  const out = new Response(res.body, res);
  for (const [k, v] of Object.entries(h)) out.headers.set(k, v);
  return out;
}
