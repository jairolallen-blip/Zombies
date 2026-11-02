# Local receiver for exporting Studio scripts to disk (used with tools/studio-export.luau).
# Accepts POSTed JSON {path, source} on http://localhost:<Port>/file and writes it under $Root;
# a POST to /done stops it. Run it in the background, then run studio-export.luau in Studio (Edit).
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/receiver.ps1 -Root "D:\CLAUDE WORK\Zombies\src"
param([string]$Root = (Join-Path $PSScriptRoot '..\src'), [int]$Port = 34999)
$l = New-Object System.Net.HttpListener
$l.Prefixes.Add("http://localhost:$Port/")
$l.Start()
Write-Output "listening on $Port"
$rootFull = [IO.Path]::GetFullPath($Root)
while ($l.IsListening) {
    $ctx = $l.GetContext()
    $reader = New-Object IO.StreamReader($ctx.Request.InputStream, [Text.Encoding]::UTF8)
    $body = $reader.ReadToEnd()
    $msg = 'ok'
    if ($ctx.Request.Url.AbsolutePath -eq '/done') {
        $msg = 'bye'
    } else {
        $j = $body | ConvertFrom-Json
        $dest = [IO.Path]::GetFullPath((Join-Path $rootFull $j.path))
        if (-not $dest.StartsWith($rootFull)) { $msg = 'rejected' } else {
            New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
            [IO.File]::WriteAllText($dest, $j.source, (New-Object Text.UTF8Encoding($false)))
            Write-Output "wrote $($j.path) ($($j.source.Length))"
        }
    }
    $b = [Text.Encoding]::UTF8.GetBytes($msg)
    $ctx.Response.OutputStream.Write($b, 0, $b.Length)
    $ctx.Response.Close()
    if ($msg -eq 'bye') { $l.Stop() }
}
