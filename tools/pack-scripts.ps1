# Packs every src/**/*.luau into one JSON object {relativePath: source} for tools/studio-import.luau.
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/pack-scripts.ps1 -Out <file.json>
param([string]$Out = (Join-Path $env:TEMP 'samz-restore.json'))
$src = (Resolve-Path (Join-Path $PSScriptRoot '..\src')).Path
$map = [ordered]@{}
Get-ChildItem $src -Recurse -File -Filter *.luau | ForEach-Object {
    $map[$_.FullName.Substring($src.Length + 1).Replace('\', '/')] = [IO.File]::ReadAllText($_.FullName).TrimStart([char]0xFEFF)
}
[IO.File]::WriteAllText($Out, ($map | ConvertTo-Json -Compress -Depth 3), (New-Object Text.UTF8Encoding($false)))
Write-Output "$($map.Count) files -> $Out"
