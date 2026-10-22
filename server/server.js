// AIRBLADE reference server: crew, chat, event progress, shop receipts and shared district control.
// Run:  node server.js        (PORT env var, default 8080; state is kept in state.json next to this file)
// Then enter http://<your-ip>:8080 in the app (CREW > LOGS > SERVER). Plain Node, no dependencies. No auth beyond
// a client-made player id: put it behind HTTPS and add real accounts before exposing it publicly.
const http = require('http'), fs = require('fs'), path = require('path');
const FILE = path.join(__dirname, 'state.json');
const EVENT_GOAL = 50, EVENT_REWARD = 2500;
let S = { players: {}, requests: [
  { id: 'r1', name: 'NightOwl', level: 6, role: 'Recruit', status: 2, last: 'Request' },
  { id: 'r2', name: 'Vex', level: 8, role: 'Recruit', status: 2, last: 'Request' }], chat: [], world: {}, event: {}, purchases: [] };
try { S = Object.assign(S, JSON.parse(fs.readFileSync(FILE, 'utf8'))); } catch (e) {}
const save = () => fs.writeFile(FILE, JSON.stringify(S), () => {});
const ago = t => { const m = Math.floor((Date.now() - t) / 60000); return m < 1 ? 'Now' : m < 60 ? m + 'm ago' : Math.floor(m / 60) + 'h ago'; };
const status = t => Date.now() - t < 30000 ? 0 : Date.now() - t < 300000 ? 1 : 2;
const touch = (id, extra) => { const p = S.players[id] = Object.assign({ name: 'Player', level: 1, role: 'Member', seen: 0 }, S.players[id], extra); p.seen = Date.now(); return p; };

function body(req) { return new Promise(r => { let d = ''; req.on('data', c => d += c); req.on('end', () => { try { r(JSON.parse(d || '{}')); } catch (e) { r({}); } }); }); }

http.createServer(async (req, res) => {
  const send = (o, code = 200) => { res.writeHead(code, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(o)); };
  const url = req.url.split('?')[0], pid = req.headers['x-player'] || '';
  const b = req.method === 'POST' ? await body(req) : {};
  if (pid) touch(pid);
  if (url === '/api/hello') { const first = Object.keys(S.players).length <= 1; touch(b.player, { name: String(b.name || 'Player').slice(0, 16), level: b.level | 0, role: first ? 'Leader' : 'Member' }); save(); return send({ ok: true }); }
  if (url === '/api/crew') {
    const members = Object.entries(S.players).map(([id, p]) => ({ id, name: p.name, level: p.level, role: p.role, status: status(p.seen), last: ago(p.seen) }));
    return send({ members, requests: S.requests, chat: S.chat.slice(-60) });
  }
  if (url === '/api/crew/chat') { S.chat.push({ id: Date.now() + Math.random().toString(36).slice(2, 6), from: String(b.name || 'Player').slice(0, 16), text: String(b.text || '').slice(0, 140), ts: Date.now() / 1000 }); S.chat = S.chat.slice(-200); save(); return send({ ok: true }); }
  if (url === '/api/crew/request') {
    const r = S.requests.find(x => x.id === b.id); S.requests = S.requests.filter(x => x.id !== b.id);
    if (r && b.accept) S.players['npc-' + r.id] = { name: r.name, level: r.level, role: 'Member', seen: Date.now() - 3600000 };
    save(); return send({ ok: true });
  }
  if (url === '/api/event/progress') { const e = S.event[b.player] = S.event[b.player] || { takedowns: 0, claimed: false }; e.takedowns += Math.max(0, Math.min(10, b.delta | 0)); save(); return send({ ok: true }); }
  if (url === '/api/event') { const e = S.event[pid] || { takedowns: 0, claimed: false }; return send(e); }
  if (url === '/api/event/claim') {
    const e = S.event[b.player];
    if (!e || e.claimed || e.takedowns < EVENT_GOAL) return send({ ok: false });
    e.claimed = true; save(); return send({ ok: true, coins: EVENT_REWARD });
  }
  if (url === '/api/shop/checkout') {
    const cost = b.cost | 0; if (cost <= 0 || !Array.isArray(b.items)) return send({ ok: false }, 400);
    S.purchases.push({ player: b.player, items: b.items, cost, ts: Date.now() }); save(); return send({ ok: true });
  }
  if (url === '/api/world') return send(S.world);
  if (url === '/api/world/delta') {
    const id = b.district | 0, cur = S.world[id] != null ? S.world[id] : 50;
    S.world[id] = Math.max(0, Math.min(100, cur + Math.max(-10, Math.min(10, b.delta | 0)))); save(); return send({ ok: true });
  }
  send({ error: 'not found' }, 404);
}).listen(process.env.PORT || 8080, () => console.log('AIRBLADE server on :' + (process.env.PORT || 8080)));
