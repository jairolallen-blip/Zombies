// Tiny OBS WebSocket v5 client (no auth, localhost). usage: node obs.js '<json array of [requestType, requestData?]>'
const reqs = JSON.parse(process.argv[2] || "[]");
const ws = new WebSocket("ws://127.0.0.1:4455");
let id = 0;
const pending = new Map();
const send = (type, data) => new Promise((res) => {
	const requestId = String(++id);
	pending.set(requestId, res);
	ws.send(JSON.stringify({ op: 6, d: { requestType: type, requestId, requestData: data || {} } }));
});
ws.onmessage = async (ev) => {
	const m = JSON.parse(ev.data);
	if (m.op === 0) {
		if (m.d.authentication) { console.log("AUTH REQUIRED: turn off authentication in OBS"); process.exit(2); }
		ws.send(JSON.stringify({ op: 1, d: { rpcVersion: 1, eventSubscriptions: 0 } }));
	} else if (m.op === 2) {
		for (const [type, data] of reqs) {
			const r = await send(type, data);
			console.log(type, JSON.stringify(r.requestStatus.result ? r.responseData ?? "ok" : r.requestStatus));
		}
		ws.close();
	} else if (m.op === 7) {
		pending.get(m.d.requestId)?.(m.d);
	}
};
ws.onerror = (e) => { console.log("ERROR connecting to OBS:", e.message || e.type); process.exit(1); };
ws.onclose = () => process.exit(0);
setTimeout(() => { console.log("timeout"); process.exit(3); }, 15000);
