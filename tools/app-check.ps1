# Prints which of Claude's working apps are open. Run it before a task that needs them.
# The list and why each app matters: vault/Apps To Keep Open.md
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/app-check.ps1
$running = Get-Process -ErrorAction SilentlyContinue
function Title($name, $like) {
	return ($running | Where-Object { $_.ProcessName -eq $name -and $_.MainWindowTitle -like $like } | Select-Object -First 1)
}
$apps = @(
	@{ Name = "Roblox Studio: main place"; Open = Title "RobloxStudioBeta" "*1,000,000 Zombies*"; Need = "always" },
	@{ Name = "OBS Studio"; Open = Title "obs64" "OBS *"; Need = "always" },
	@{ Name = "Obsidian"; Open = Title "Obsidian" "*"; Need = "always" },
	@{ Name = "Roblox Studio: Outbreak"; Open = Title "RobloxStudioBeta" "Outbreak*"; Need = "when shared code changes" },
	@{ Name = "Roblox player"; Open = ($running | Where-Object { $_.ProcessName -eq "RobloxPlayerBeta" } | Select-Object -First 1); Need = "for live checks" }
)
foreach ($a in $apps) {
	$state = if ($a.Open) { "open" } else { "MISSING" }
	"{0,-8} {1,-28} {2}" -f $state, $a.Name, $a.Need
}
try {
	$t = New-Object Net.Sockets.TcpClient
	$t.Connect("127.0.0.1", 4455)
	$t.Close()
	"open     OBS WebSocket port 4455"
} catch {
	"MISSING  OBS WebSocket port 4455"
}
