# Drives the real Roblox player on Windows, and works for any Roblox game.
# Studio's user_mouse_input and user_keyboard_input can't reach the live client, so these send real input.
# Every action brings the player to the front first and sends nothing if that fails.
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/roblox-input.ps1 -Action shot  -Out a.png
#   ... -Action click -X 960 -Y 1018 -Out a.png -Wait 3
#   ... -Action key -Key 08 -Hold 80 -Out a.png        Key is a Windows virtual key in hex (08 Backspace, 57 W, 20 Space)
#   ... -Action sheet -Out a.png -Frames 16 -Every 900  captures a contact sheet over time, sends no input
# Screen coordinates are for the player window at 0,0 on the main monitor. Guide: vault/Playing Roblox Games.md
param(
	[ValidateSet("shot", "click", "key", "sheet")][string]$Action = "shot",
	[int]$X, [int]$Y, [string]$Key, [int]$Hold = 80,
	[string]$Out, [int]$Wait = 2, [int]$Frames = 16, [int]$Every = 900
)
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
Add-Type @"
using System; using System.Runtime.InteropServices;
public class RobloxInput {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint c, uint t);
  [DllImport("user32.dll")] public static extern void keybd_event(byte v, byte s, uint f, UIntPtr e);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, int x, int y, uint d, UIntPtr e);
}
"@
$p = Get-Process RobloxPlayerBeta -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $p) { throw "the Roblox player is not running" }

function Front {
	(New-Object -ComObject WScript.Shell).AppActivate($p.Id) | Out-Null
	[RobloxInput]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
	Start-Sleep -Milliseconds 500
	if ([RobloxInput]::GetForegroundWindow() -ne $p.MainWindowHandle) { throw "the player did not come to the front; nothing was sent" }
}
function Grab {
	$size = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Size
	$bmp = New-Object System.Drawing.Bitmap $size.Width, $size.Height
	$g = [System.Drawing.Graphics]::FromImage($bmp)
	$g.CopyFromScreen(0, 0, 0, 0, $size)
	$g.Dispose()
	return $bmp
}
# Roblox buttons only hover on real absolute moves, so SetCursorPos alone isn't enough.
function MouseTo($px, $py) {
	$v = [System.Windows.Forms.SystemInformation]::VirtualScreen
	[RobloxInput]::mouse_event(0xC001, [int](($px + 0.5) * 65535 / $v.Width), [int](($py + 0.5) * 65535 / $v.Height), 0, [UIntPtr]::Zero)
}

if ($Action -eq "sheet") {
	$cols = [int][Math]::Ceiling([Math]::Sqrt($Frames))
	$rows = [int][Math]::Ceiling($Frames / $cols)
	$first = Grab
	$w = [int]($first.Width / $cols); $h = [int]($first.Height / $cols)
	$first.Dispose()
	$sheet = New-Object System.Drawing.Bitmap ($w * $cols), ($h * $rows)
	$g = [System.Drawing.Graphics]::FromImage($sheet)
	foreach ($i in 0..($Frames - 1)) {
		$bmp = Grab
		$g.DrawImage($bmp, ($i % $cols) * $w, [Math]::Floor($i / $cols) * $h, $w, $h)
		$bmp.Dispose()
		Start-Sleep -Milliseconds $Every
	}
	$sheet.Save($Out)
	"sheet $Out"
	exit
}
if ($Action -eq "click") {
	Front
	MouseTo ($X - 12) ($Y - 4); Start-Sleep -Milliseconds 150
	MouseTo ($X - 4) $Y; Start-Sleep -Milliseconds 150
	MouseTo $X $Y; Start-Sleep -Milliseconds 450
	[RobloxInput]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero)
	Start-Sleep -Milliseconds 140
	[RobloxInput]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)
	Start-Sleep -Seconds $Wait
} elseif ($Action -eq "key") {
	Front
	$v = [Convert]::ToByte($Key, 16)
	$s = [byte][RobloxInput]::MapVirtualKey($v, 0)
	[RobloxInput]::keybd_event($v, $s, 8, [UIntPtr]::Zero)
	Start-Sleep -Milliseconds $Hold
	[RobloxInput]::keybd_event($v, $s, 10, [UIntPtr]::Zero)
	Start-Sleep -Seconds $Wait
}
if ($Out) {
	$bmp = Grab
	$bmp.Save($Out)
	$bmp.Dispose()
}
"done: $Action"
