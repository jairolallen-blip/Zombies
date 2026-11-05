// rbxl-scripts: copies every script out of a binary Roblox place file (.rbxl) into a folder, with no web requests.
// Get the file with File > Download a Copy in Studio. Useful since execute_luau can't reach localhost.
//   node tools/rbxl-scripts.js <place.rbxl> <out folder> [root,root]
// Roots default to the four code roots. It prints every script's byte size and the same hash the Studio checks use.
// Format notes: 32-byte header, then chunks (INST classes, PROP values, PRNT parents), each LZ4 or ZSTD compressed.
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const [file, outDir, rootArg] = process.argv.slice(2);
if (!file || !outDir) throw new Error("usage is in the header of tools/rbxl-scripts.js");
const ROOTS = (rootArg || "ServerScriptService,ReplicatedStorage,StarterPlayer,ReplicatedFirst,StarterGui").split(",");
const buf = fs.readFileSync(file);
if (buf.toString("latin1", 0, 8) !== "<roblox!") throw new Error("not a binary place file");

function lz4(src, size) {
	const out = Buffer.alloc(size);
	let s = 0;
	let d = 0;
	while (s < src.length) {
		const token = src[s++];
		let n = token >> 4;
		if (n === 15) for (let b = 255; b === 255; n += b) b = src[s++];
		src.copy(out, d, s, s + n);
		s += n;
		d += n;
		if (s >= src.length) break;
		const offset = src.readUInt16LE(s);
		s += 2;
		let m = token & 15;
		if (m === 15) for (let b = 255; b === 255; m += b) b = src[s++];
		m += 4;
		for (let i = 0; i < m; i++, d++) out[d] = out[d - offset];
	}
	return out;
}

// referents: 4 interleaved big-endian bytes, zigzag, then delta coded
function referents(b, pos, count) {
	const out = new Array(count);
	let last = 0;
	for (let i = 0; i < count; i++) {
		const v = ((b[pos + i] << 24) | (b[pos + count + i] << 16) | (b[pos + 2 * count + i] << 8) | b[pos + 3 * count + i]) >>> 0;
		last += v % 2 ? -((v + 1) / 2) : v / 2;
		out[i] = last;
	}
	return out;
}

const classes = new Map(); // class id -> { name, refs }
const insts = new Map(); // referent -> { className, Name, Source, parent }
let pos = 32;
while (pos < buf.length) {
	const name = buf.toString("latin1", pos, pos + 4).replace(/\0/g, "");
	const packed = buf.readUInt32LE(pos + 4);
	const size = buf.readUInt32LE(pos + 8);
	pos += 16;
	let data = buf.subarray(pos, pos + (packed || size));
	pos += packed || size;
	if (name === "END") break;
	if (packed) data = data.readUInt32BE(0) === 0x28b52ffd ? zlib.zstdDecompressSync(data) : lz4(data, size);
	if (name === "INST") {
		const id = data.readUInt32LE(0);
		const len = data.readUInt32LE(4);
		const className = data.toString("latin1", 8, 8 + len);
		let p = 8 + len + 1;
		const count = data.readUInt32LE(p);
		p += 4;
		const refs = referents(data, p, count);
		classes.set(id, { name: className, refs });
		for (const r of refs) insts.set(r, { className });
	} else if (name === "PROP") {
		const id = data.readUInt32LE(0);
		const len = data.readUInt32LE(4);
		const prop = data.toString("latin1", 8, 8 + len);
		let p = 8 + len;
		const type = data[p++];
		const cls = classes.get(id);
		if (cls && type === 1 && (prop === "Name" || prop === "Source")) {
			for (const r of cls.refs) {
				const n = data.readUInt32LE(p);
				p += 4;
				insts.get(r)[prop] = data.toString("utf8", p, p + n);
				p += n;
			}
		}
	} else if (name === "PRNT") {
		const count = data.readUInt32LE(1);
		const kids = referents(data, 5, count);
		const parents = referents(data, 5 + count * 4, count);
		kids.forEach((k, i) => {
			if (insts.has(k)) insts.get(k).parent = parents[i];
		});
	}
}

const hash = (s) => {
	const b = Buffer.from(s);
	let h = 5381;
	for (const x of b) h = (h * 33 + x) % 4294967296;
	return `${b.length}:${h}`;
};
const fullPath = (i) => {
	const parts = [];
	for (let at = i; at; at = insts.get(at.parent)) parts.unshift(at.Name);
	return parts;
};
const lines = [];
for (const inst of insts.values()) {
	if (!["Script", "LocalScript", "ModuleScript"].includes(inst.className)) continue;
	const parts = fullPath(inst);
	if (!ROOTS.includes(parts[0])) continue;
	const source = (inst.Source || "").replace(/\r\n/g, "\n");
	const suffix = inst.className === "Script" ? ".server.luau" : inst.className === "LocalScript" ? ".client.luau" : ".luau";
	const target = path.join(outDir, ...parts.slice(0, -1), parts[parts.length - 1] + suffix);
	fs.mkdirSync(path.dirname(target), { recursive: true });
	fs.writeFileSync(target, source);
	lines.push(`${parts.join(".")}=${hash(source)}`);
}
lines.sort();
fs.writeFileSync(path.join(outDir, "hashes.txt"), lines.join("\n") + "\n");
console.log(`${lines.length} scripts from ${insts.size} instances`);
