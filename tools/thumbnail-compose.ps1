param([string]$Src, [string]$Out)
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force $Out | Out-Null

function Load($name) { return ,([System.Drawing.Image]::FromFile([string](Join-Path $Src $name))) }

# crop rect of the source, scaled to w x h
function Canvas($img, $cx, $cy, $cw, $ch, $w, $h) {
	$bmp = New-Object System.Drawing.Bitmap $w, $h
	$g = [System.Drawing.Graphics]::FromImage($bmp)
	$g.InterpolationMode = "HighQualityBicubic"; $g.SmoothingMode = "AntiAlias"; $g.TextRenderingHint = "AntiAliasGridFit"; $g.PixelOffsetMode = "HighQuality"
	$dst = New-Object System.Drawing.Rectangle 0, 0, $w, $h; $srcR = New-Object System.Drawing.Rectangle $cx, $cy, $cw, $ch; $g.DrawImage($img, $dst, $srcR, [System.Drawing.GraphicsUnit]::Pixel)
	return @($bmp, $g)
}

# dark edges, so the centre and the text pop
function Vignette($g, $w, $h, $strength) {
	$path = New-Object System.Drawing.Drawing2D.GraphicsPath
	$path.AddEllipse(-$w * 0.25, -$h * 0.25, $w * 1.5, $h * 1.5)
	$b = New-Object System.Drawing.Drawing2D.PathGradientBrush $path
	$b.CenterColor = [System.Drawing.Color]::FromArgb(0, 0, 0, 0)
	$b.SurroundColors = @([System.Drawing.Color]::FromArgb($strength, 0, 0, 0))
	$g.FillRectangle($b, 0, 0, $w, $h)
}

# a dark band behind text at the top or bottom
function Band($g, $w, $h, $y0, $y1, $top) {
	$r = New-Object System.Drawing.Rectangle 0, $y0, $w, ($y1 - $y0)
	$c0 = [System.Drawing.Color]::FromArgb(200, 0, 0, 0); $c1 = [System.Drawing.Color]::FromArgb(0, 0, 0, 0)
	$b = if ($top) { New-Object System.Drawing.Drawing2D.LinearGradientBrush $r, $c0, $c1, 90 } else { New-Object System.Drawing.Drawing2D.LinearGradientBrush $r, $c1, $c0, 90 }
	$g.FillRectangle($b, $r)
}

# outlined text, centred on x; fill can be a colour or a vertical gradient (two colours)
function Text($g, $s, $font, $size, $cx, $y, $fill, $fill2, $stroke, $strokeW) {
	$path = New-Object System.Drawing.Drawing2D.GraphicsPath
	$ff = New-Object System.Drawing.FontFamily $font
	$fmt = New-Object System.Drawing.StringFormat; $fmt.Alignment = "Center"
	$path.AddString($s, $ff, 0, $size, (New-Object System.Drawing.PointF $cx, $y), $fmt)
	$shadow = $path.Clone(); $m = New-Object System.Drawing.Drawing2D.Matrix; $m.Translate(0, $size * 0.06); $shadow.Transform($m)
	$g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(170, 0, 0, 0))), $shadow)
	$pen = New-Object System.Drawing.Pen $stroke, $strokeW; $pen.LineJoin = "Round"
	$g.DrawPath($pen, $path)
	$bounds = $path.GetBounds()
	if ($fill2) { $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush $bounds, $fill, $fill2, 90 } else { $br = New-Object System.Drawing.SolidBrush $fill }
	$g.FillPath($br, $path)
}

$white = [System.Drawing.Color]::White
$bone = [System.Drawing.Color]::FromArgb(255, 255, 236, 200)
$red = [System.Drawing.Color]::FromArgb(255, 235, 40, 30)
$deepRed = [System.Drawing.Color]::FromArgb(255, 60, 6, 4)
$amber = [System.Drawing.Color]::FromArgb(255, 255, 196, 60)
$orange = [System.Drawing.Color]::FromArgb(255, 255, 110, 20)
$black = [System.Drawing.Color]::FromArgb(255, 14, 8, 6)

$A = Load "mcp-Roblox_Studio-blob-1793827527441-40fnk6.jpg" # last stand down the street
$B = Load "mcp-Roblox_Studio-blob-1793827553358-42b9ho.jpg" # lunging zombie
$C = Load "mcp-Roblox_Studio-blob-1793827600306-65dww1.jpg" # surrounded, top down

# Icon 1: last stand. Square on the survivor and the horde; 1,000,000 across the top
$cv = Canvas $A 400 0 663 663 512 512; $bmp = $cv[0]; $g = $cv[1]
Vignette $g 512 512 170; Band $g 512 512 0 170 $true
Text $g "1,000,000" "Impact" 104 256 14 $white $bone $deepRed 12
Text $g "ZOMBIES" "Impact" 52 256 118 $red $null $black 9
$bmp.Save((Join-Path $Out "icon1-last-stand.png"), [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()

# Icon 2: in your face. Square on the lunging zombie; SURVIVE on top, 1,000,000 below
$cv = Canvas $B 380 0 663 663 512 512; $bmp = $cv[0]; $g = $cv[1]
Vignette $g 512 512 150; Band $g 512 512 0 120 $true; Band $g 512 512 360 512 $false
Text $g "SURVIVE" "Impact" 70 256 8 $white $bone $black 10
Text $g "1,000,000" "Impact" 108 256 388 $amber $orange $deepRed 12
$bmp.Save((Join-Path $Out "icon2-in-your-face.png"), [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()

# Icon 3: surrounded. Square on the ring; 1 VS 1,000,000
$cv = Canvas $C 406 0 663 663 512 512; $bmp = $cv[0]; $g = $cv[1]
Vignette $g 512 512 190; Band $g 512 512 380 512 $false
Text $g "1 VS 1,000,000" "Impact" 78 256 412 $white $bone $deepRed 11
$bmp.Save((Join-Path $Out "icon3-surrounded.png"), [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()

# Thumbnail 16:9 from the last stand
$cv = Canvas $A 148 0 1179 663 1920 1080; $bmp = $cv[0]; $g = $cv[1]
Vignette $g 1920 1080 160; Band $g 1920 1080 0 330 $true
Text $g "SURVIVE 1,000,000 ZOMBIES" "Impact" 150 960 40 $white $bone $deepRed 18
Text $g "HOW LONG CAN YOUR SQUAD HOLD THE LINE?" "Impact" 58 960 210 $amber $null $black 9
$bmp.Save((Join-Path $Out "thumbnail-1920x1080.png"), [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()

$A.Dispose(); $B.Dispose(); $C.Dispose()
Get-ChildItem $Out | ForEach-Object { "$($_.Name) $([math]::Round($_.Length / 1KB))KB" }
