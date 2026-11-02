# One-shot local file server: answers a single GET on http://localhost:<Port>/ with a file's bytes,
# then exits. Used to push repo scripts INTO Studio (tools/studio-import.luau fetches it).
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/serve.ps1 -File <path>
param([string]$File, [int]$Port = 34998)
$l = New-Object System.Net.HttpListener
$l.Prefixes.Add("http://localhost:$Port/")
$l.Start()
Write-Output "serving on $Port"
$ctx = $l.GetContext()
$b = [IO.File]::ReadAllBytes($File)
$ctx.Response.ContentType = 'text/plain; charset=utf-8'
$ctx.Response.OutputStream.Write($b, 0, $b.Length)
$ctx.Response.Close()
$l.Stop()
