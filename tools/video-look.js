// video-look: see fast things in a local video, with ffmpeg. Guide: vault/Playing Roblox Games.md
//   node tools/video-look.js events <video> [threshold=0.12]           lists sudden changes, so you know where to look
//   node tools/video-look.js strip <video> <start s> <count> <out.jpg> [fps=30] [crop=w:h:x:y]   every frame, as one image
const { execFileSync } = require("child_process");
const fs = require("fs");

const ffmpeg = fs.existsSync("C:/ffmpeg/bin/ffmpeg.exe") ? "C:/ffmpeg/bin/ffmpeg.exe" : "ffmpeg";
const [mode, video, ...rest] = process.argv.slice(2);
if (!video || !fs.existsSync(video)) throw new Error("usage is in the header of tools/video-look.js");
const named = Object.fromEntries(rest.filter((a) => a.includes("=")).map((a) => a.split("=")));
const args = rest.filter((a) => !a.includes("="));
const crop = named.crop ? `crop=${named.crop},` : "";
const run = (a) => execFileSync(ffmpeg, ["-v", "error", "-y", ...a], { stdio: ["ignore", "pipe", "pipe"], maxBuffer: 1 << 28 }).toString();

if (mode === "events") {
	const out = run(["-i", video, "-an", "-vf", `scale=320:-1,select='gt(scene,${args[0] || 0.12})',metadata=print:file=-`, "-f", "null", "-"]);
	const times = [...out.matchAll(/pts_time:([\d.]+)/g)].map((m) => Number(m[1]));
	const scores = [...out.matchAll(/scene_score=([\d.]+)/g)].map((m) => Number(m[1]));
	times.forEach((t, i) => console.log(`${t.toFixed(2)}s  change ${scores[i].toFixed(2)}`));
	console.log(`${times.length} events`);
} else if (mode === "strip") {
	const [start, count, out] = args;
	const fps = Number(named.fps || 30);
	const cols = Math.ceil(Math.sqrt(count));
	const rows = Math.ceil(count / cols);
	const width = Math.floor(1920 / cols);
	run(["-ss", start, "-i", video, "-an", "-vf", `fps=${fps},${crop}scale=${width}:-2,tile=${cols}x${rows}`, "-frames:v", "1", "-q:v", "3", out]);
	console.log(`${out}: ${count} frames from ${start}s, ${(1000 / fps).toFixed(0)} ms apart`);
} else {
	throw new Error("mode must be events or strip");
}
