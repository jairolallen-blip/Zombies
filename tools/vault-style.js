// vault-style: colour-codes the Obsidian vault by zone (run: node tools/vault-style.js).
// Tags each design note, writes the zone colours to .obsidian/snippets/samz-zones.css, and sets the graph's colour
// groups. To colour a new note, add its name to a zone here and rerun. Code notes get their zone from
// tools/vault-code-notes.js. Reload Obsidian without saving afterwards, or it can write its old graph back.
const fs = require("fs");
const path = require("path");

const VAULT = path.join(__dirname, "..", "vault");
const ZONES = {
	home: { color: "#ffffff", label: "Home", notes: ["Home"] },
	gameplay: { color: "#ff4a3d", label: "Gameplay", notes: ["Zombies", "Waves and Boss", "Spawning", "Weapons", "Classes and Abilities", "Supply Drops", "Nightmare Mode", "Outbreak"] },
	world: { color: "#ffb43c", label: "World and story", notes: ["Lobby", "City Map", "Match Start", "Lore", "Tutorial"] },
	progress: { color: "#b98bff", label: "Progress and store", notes: ["Achievements", "Bounties", "Store", "Levels"] },
	working: { color: "#9cff5a", label: "How we work", notes: ["Roadmap", "Team Create Workflow", "Playing Roblox Games", "Playing Million Zombies", "Apps To Keep Open", "Servers and Teleports", "Phones and Gamepads"] },
	library: { color: "#e8d5a8", label: "Reference library", notes: ["Video References", "Game Feel Guide", "AI Art Pipeline", "UI Ideas"] },
	server: { color: "#4f9dff", label: "Server code", folder: "Code/Server services" },
	client: { color: "#4be3d0", label: "Client code", folder: "Code/Client controllers" },
	map: { color: "#ff8a3d", label: "Map code", folder: "Code/Map builders" },
	shared: { color: "#ffe45c", label: "Shared code", folder: "Code/Shared modules" },
	config: { color: "#ff5fd2", label: "Config", folder: "Code/Config" },
};

function tagNote(file, zone) {
	const text = fs.readFileSync(file, "utf8").replace(/^---\n[\s\S]*?\n---\n\n?/, (m) => (/samz-zone/.test(m) ? "" : m));
	fs.writeFileSync(file, `---\ntags: [zone-${zone}]\ncssclasses: [zone-${zone}]\nsamz-zone: ${zone}\n---\n\n${text}`);
}

let css = "/* Made by tools/vault-style.js. Don't edit it here: change ZONES there and rerun. */\n";
const groups = [];
for (const [zone, z] of Object.entries(ZONES)) {
	css += `.zone-${zone} { --zone: ${z.color}; }\n`;
	css += `.nav-folder-title[data-path="${z.folder || "\0"}"], .nav-folder-title[data-path="${z.folder || "\0"}"] .nav-folder-title-content { color: ${z.color}; font-weight: 700; }\n`;
	const pick = z.folder ? `[data-path^="${z.folder}/"], .nav-file-title[data-path="${z.folder}.md"]` : null;
	if (pick) css += `.nav-file-title${pick} { color: ${z.color}; }\n`;
	for (const note of z.notes || []) {
		const file = path.join(VAULT, note + ".md");
		if (!fs.existsSync(file)) throw new Error("no note: " + note);
		tagNote(file, zone);
		css += `.nav-file-title[data-path="${note}.md"] { color: ${z.color}; font-weight: 600; }\n`;
	}
	groups.push({ query: `tag:#zone-${zone}`, color: { a: 1, rgb: parseInt(z.color.slice(1), 16) } });
}
fs.mkdirSync(path.join(VAULT, ".obsidian", "snippets"), { recursive: true });
fs.writeFileSync(path.join(VAULT, ".obsidian", "snippets", "samz-zones.css"), css);

const untagged = fs.readdirSync(VAULT).filter((f) => f.endsWith(".md") && !Object.values(ZONES).some((z) => (z.notes || []).includes(f.slice(0, -3))));
if (untagged.length) console.log("notes with no zone: " + untagged.join(", "));

const graphFile = path.join(VAULT, ".obsidian", "graph.json");
const graph = JSON.parse(fs.readFileSync(graphFile, "utf8"));
graph.colorGroups = groups;
graph["collapse-color-groups"] = false;
fs.writeFileSync(graphFile, JSON.stringify(graph, null, 2));

const appearance = path.join(VAULT, ".obsidian", "appearance.json");
const look = JSON.parse(fs.readFileSync(appearance, "utf8") || "{}");
look.theme = "obsidian";
look.enabledCssSnippets = ["samz-theme", "samz-zones"];
fs.writeFileSync(appearance, JSON.stringify(look, null, 2));

const app = path.join(VAULT, ".obsidian", "app.json");
const settings = JSON.parse(fs.readFileSync(app, "utf8") || "{}");
settings.propertiesInDocument = "hidden";
settings.showInlineTitle = false; // every note already starts with its own # title
fs.writeFileSync(app, JSON.stringify(settings, null, 2));
console.log(`${groups.length} zones styled`);
