# Publishes one open Studio window to Roblox with its Alt+P shortcut, which works when the File menu is missing.
# usage: powershell -NoProfile -ExecutionPolicy Bypass -File tools/studio-key.ps1 <process id> "%p" <screenshot.png>
# Get the id from Get-Process RobloxStudioBeta. The "Published" toast takes about 4 seconds; the screenshot covers all monitors.
param([int]$ProcId, [string]$Keys, [string]$Shot)
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class Win {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
}
"@
$p = Get-Process -Id $ProcId
$h = $p.MainWindowHandle
[Win]::ShowWindow($h, 9) | Out-Null
(New-Object -ComObject WScript.Shell).AppActivate($ProcId) | Out-Null
[Win]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 500
if ([Win]::GetForegroundWindow() -ne $h) { throw "Studio window did not come to the front; no keys sent" }
"front: $($p.MainWindowTitle)"
[System.Windows.Forms.SendKeys]::SendWait($Keys)
Start-Sleep -Seconds 5
$b = [System.Windows.Forms.SystemInformation]::VirtualScreen
$bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
$bmp.Save($Shot)
"title now: $((Get-Process -Id $ProcId).MainWindowTitle)"
