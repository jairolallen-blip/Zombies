// vault-code-notes: writes one Obsidian note per source file into vault/Code (run: node tools/vault-code-notes.js).
// Each note holds the file's header comment plus [[links]] to the modules it uses, the modules that use it
// and the design notes it names ("vault: Lobby.md"), so Obsidian's graph shows how the code fits together.
// vault/Code is wiped and rebuilt every run: never hand-edit it, write design notes in the vault root.
const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..");
const SRC = path.join(ROOT, "src");
const OUT = path.join(ROOT, "vault", "Code");
// All games share one vault (Game Kit/Gamekit), so every code note carries the game's name to stay unique.
const TAG = " (Zombies)";
const HOME = "Zombies Home";
const RENAME = { Home: HOME, Roadmap: "Zombies Roadmap" };

// folder under src -> group (folder under vault/Code + its index note)
const GROUPS = [
	{ dir: "server/Services", group: "Server services", blurb: "Server game systems. Server Main loads them in order and calls Init, then Start." },
	{ dir: "server/Map", group: "Map builders", blurb: "Edit-mode builders that bake the lobby and city into Workspace.OurMap, plus the zombie nav grid." },
	{ dir: "server", group: "Server services", blurb: null },
	{ dir: "client/Controllers", group: "Client controllers", blurb: "Client systems. Client Main loads them and calls Init, then Start." },
	{ dir: "client", group: "Client controllers", blurb: null },
	{ dir: "client/UI", group: "Client controllers", blurb: null },
	{ dir: "shared/Config", group: "Config", blurb: "Pure data tables read by server and client. Tune numbers here." },
	{ dir: "shared", group: "Shared modules", blurb: "Modules both sides require: state, remotes, helpers, model builders." },
	{ dir: "character", group: "Shared modules", blurb: null },
	{ dir: "first", group: "Client controllers", blurb: null }, // ReplicatedFirst (JoinCover)
];

function walk(dir) {
	return fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
		const p = path.join(dir, e.name);
		return e.isDirectory() ? walk(p) : e.name.endsWith(".luau") ? [p] : [];
	});
}

const files = walk(SRC).map((full) => {
	const rel = path.relative(SRC, full).replace(/\\/g, "/");
	const dir = path.dirname(rel);
	const base = path.basename(rel).replace(/\.(server|client)?\.?luau$/, "").replace(/\.$/, "");
	const g = GROUPS.find((x) => dir === x.dir);
	let note = base;
	if (base === "Main") note = dir === "server" ? "Server Main" : "Client Main";
	else if (base === "Health") note = "Health script";
	else if (dir === "shared/Config" && base !== "GameConfig") note = base + " config";
	else if (dir === "server/Map" && base === "Survivors") note = "Survivors map";
	return { full, rel, dir, base, note: note + TAG, group: g.group, text: fs.readFileSync(full, "utf8") };
});

// a module reference -> the file it means
function resolve(name, hint, from) {
	const cands = files.filter((f) => f.base === name && f !== from);
	if (cands.length <= 1) return cands[0];
	if (hint === "config") return cands.find((f) => f.dir === "shared/Config");
	if (hint === "map") return cands.find((f) => f.dir === "server/Map");
	return cands.find((f) => f.dir === from.dir) || cands.find((f) => f.dir !== "shared/Config");
}

// uses = what the code requires or calls; mentions = modules its comments point to
const uses = new Map(files.map((f) => [f, new Set()]));
const mentions = new Map(files.map((f) => [f, new Set()]));
const design = new Map(files.map((f) => [f, new Set()]));
for (const f of files) {
	const add = (into, name, hint) => {
		const t = resolve(name, hint, f);
		if (t && t !== f) into.get(f).add(t);
	};
	for (const line of f.text.split("\n")) {
		const cut = line.indexOf("--");
		const code = cut < 0 ? line : line.slice(0, cut);
		const comment = cut < 0 ? "" : line.slice(cut);
		const req = code.match(/require\((.*)/);
		if (req) {
			const words = [...req[1].matchAll(/[.:"']\s*(\w+)/g)].map((m) => m[1]).filter((w) => files.some((x) => x.base === w));
			const hint = /Config/.test(req[1]) ? "config" : /script\.Parent/.test(req[1]) && f.dir === "server/Map" ? "map" : null;
			if (words.length) add(uses, words[words.length - 1], hint);
		}
		for (const m of code.matchAll(/\b(?:Services|Controllers)\.(\w+)/g)) add(uses, m[1]);
		for (const m of comment.matchAll(/\b(Server|Client|Shared)\/(?:(Services|Controllers|Map|Config|UI)\/)?(\w+)/g)) {
			add(mentions, m[3], m[2] === "Config" ? "config" : m[2] === "Map" ? "map" : null);
		}
		for (const m of comment.matchAll(/\bConfig[./](\w+)/g)) add(mentions, m[1], "config");
		const vault = comment.match(/vault: ([^)]*)/);
		if (vault) for (const m of vault[1].matchAll(/([A-Z][\w ]*?)\.md/g)) design.get(f).add(m[1]);
	}
}

function header(text) {
	const lines = [];
	for (const line of text.split("\n")) {
		if (!line.startsWith("--")) break;
		lines.push(line.replace(/^--\s?/, ""));
	}
	return lines.join("\n").trim();
}

const link = (f) => `[[${f.note}]]`;
// colour zone per group: the colours themselves are in tools/vault-style.js
const ZONE = { "Server services": "server", "Client controllers": "client", "Map builders": "map", "Shared modules": "shared", Config: "config" };
const front = (group) => `---\ntags: [zone-${ZONE[group]}]\ncssclasses: [zone-${ZONE[group]}]\n---\n\n`;
const list = (set) => ([...set].length ? [...set].map((f) => `- ${link(f)}`).sort().join("\n") : "- (none)");
const write = (rel, body) => {
	const p = path.join(OUT, rel);
	fs.mkdirSync(path.dirname(p), { recursive: true });
	fs.writeFileSync(p, body.replace(/\r/g, ""));
};

fs.rmSync(OUT, { recursive: true, force: true });
for (const f of files) {
	const usedBy = new Set(files.filter((o) => uses.get(o).has(f)));
	const lines = f.text.split("\n").length;
	const notes = [...design.get(f)].map((d) => `- [[${RENAME[d] || d}]]`).join("\n");
	const seeAlso = new Set([...mentions.get(f)].filter((o) => !uses.get(f).has(o) && !usedBy.has(o)));
	write(
		`${f.group}/${f.note}.md`,
		front(f.group) +
				`# ${f.note}\n\n` +
			`> Made by \`tools/vault-code-notes.js\` from \`src/${f.rel}\` (${lines} lines). Don't edit it here: rerun the script.\n\n` +
			`Part of [[${f.group}${TAG}|${f.group}]].\n\n` +
			`## What it does\n\n\`\`\`text\n${header(f.text) || "(no header comment)"}\n\`\`\`\n\n` +
			`## Uses\n\n${list(uses.get(f))}\n\n## Used by\n\n${list(usedBy)}\n` +
			(seeAlso.size ? `\n## Mentions\n\n${list(seeAlso)}\n` : "") +
			(notes ? `\n## Design notes\n\n${notes}\n` : "")
	);
}
for (const g of GROUPS.filter((x) => x.blurb)) {
	const members = files.filter((f) => f.group === g.group);
	write(
		`${g.group}${TAG}.md`,
		front(g.group) +
				`# ${g.group}${TAG}\n\n> Made by \`tools/vault-code-notes.js\`. Don't edit it here: rerun the script.\n\n` +
			`${g.blurb}\n\nBack to [[${HOME}]].\n\n` +
			members.map((f) => `- ${link(f)}: ${(header(f.text).split("\n")[0] || "").replace(/^\w+:\s*/, "")}`).sort().join("\n") +
			"\n"
	);
}
console.log(`${files.length} code notes in ${path.relative(ROOT, OUT)}`);
