// StartRecord now, StopRecord after argv[2] seconds; prints the file path
const secs = Number(process.argv[2] || 65);
const ws = new WebSocket("ws://127.0.0.1:4455");
let id = 0; const pending = new Map();
const send = (t, d) => new Promise((res) => { const r = String(++id); pending.set(r, res); ws.send(JSON.stringify({ op: 6, d: { requestType: t, requestId: r, requestData: d || {} } })); });
ws.onmessage = async (ev) => {
	const m = JSON.parse(ev.data);
	if (m.op === 0) ws.send(JSON.stringify({ op: 1, d: { rpcVersion: 1, eventSubscriptions: 0 } }));
	else if (m.op === 2) {
		const a = await send("StartRecord"); console.log("start", JSON.stringify(a.requestStatus));
		setTimeout(async () => { const s = await send("GetRecordStatus"); console.log("status", JSON.stringify(s.responseData)); const b = await send("StopRecord"); console.log("stop", JSON.stringify(b.responseData || b.requestStatus)); ws.close(); }, secs * 1000);
	} else if (m.op === 7) pending.get(m.d.requestId)?.(m.d);
};
ws.onclose = () => process.exit(0);
