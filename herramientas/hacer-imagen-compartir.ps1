# Dibuja estatico/img/compartir.png (1200x630), la vista previa al compartir Guatusa en WhatsApp o Telegram.
# Solo en Windows (usa System.Drawing). La guatusa es la misma del logo (estatico/img/guatusa.svg).
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$salida = Join-Path (Split-Path -Parent $PSScriptRoot) 'estatico\img\compartir.png'

$ancho = 1200; $alto = 630
$bmp = New-Object System.Drawing.Bitmap $ancho, $alto
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'; $g.InterpolationMode = 'HighQualityBicubic'

function Color([string]$hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }

# Fondo verde de Brizna Soft
$fondo = New-Object System.Drawing.Drawing2D.LinearGradientBrush ([System.Drawing.Point]::new(0, 0)), ([System.Drawing.Point]::new($ancho, $alto)), (Color '#157A5A'), (Color '#1D9E75')
$g.FillRectangle($fondo, 0, 0, $ancho, $alto)

# Cuadro canela con la guatusa (escala 5.4 sobre las medidas de 64x64 del logo)
$x0 = 90; $y0 = 142; $s = 5.4
function P([double]$x, [double]$y) { [System.Drawing.PointF]::new($x0 + $x * $s, $y0 + $y * $s) }
$caja = New-Object System.Drawing.Drawing2D.GraphicsPath
$r = 15 * $s; $l = 64 * $s
$caja.AddArc($x0, $y0, $r * 2, $r * 2, 180, 90); $caja.AddArc($x0 + $l - $r * 2, $y0, $r * 2, $r * 2, 270, 90)
$caja.AddArc($x0 + $l - $r * 2, $y0 + $l - $r * 2, $r * 2, $r * 2, 0, 90); $caja.AddArc($x0, $y0 + $l - $r * 2, $r * 2, $r * 2, 90, 90); $caja.CloseFigure()
$g.FillPath((New-Object System.Drawing.SolidBrush (Color '#B0601E')), $caja)

$blanco = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
$cuerpo = New-Object System.Drawing.Drawing2D.GraphicsPath
$cuerpo.AddBezier((P 8 34), (P 10 30), (P 13 27.5), (P 17 26.5))
$cuerpo.AddBezier((P 17 26.5), (P 19 26), (P 21 25.5), (P 23 25))
$cuerpo.AddBezier((P 23 25), (P 29 19), (P 37 15), (P 45 16.5))
$cuerpo.AddBezier((P 45 16.5), (P 52 18), (P 56.5 24), (P 56 31))
$cuerpo.AddBezier((P 56 31), (P 55.5 37), (P 52 40.5), (P 47 41))
$cuerpo.AddLine((P 47 41), (P 28 41))
$cuerpo.AddBezier((P 28 41), (P 24 41), (P 21 39.5), (P 19 37.5))
$cuerpo.AddBezier((P 19 37.5), (P 16 37.5), (P 12 37), (P 8 34))
$cuerpo.CloseFigure()
$g.FillPath($blanco, $cuerpo)

function Elipse([double]$cx, [double]$cy, [double]$rx, [double]$ry, [double]$giro) {
    $estado = $g.Save()
    $c = P $cx $cy
    $g.TranslateTransform($c.X, $c.Y); $g.RotateTransform($giro)
    $g.FillEllipse($blanco, -$rx * $s, -$ry * $s, 2 * $rx * $s, 2 * $ry * $s)
    $g.Restore($estado)
}
Elipse 23.2 22.4 2.4 3.4 -15
Elipse 10.5 48.5 3.6 2.4 -28
$pata = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), (2.8 * $s)
$pata.StartCap = 'Round'; $pata.EndCap = 'Round'
foreach ($p in @(@(22.5, 39.5, 21.5, 52), @(27, 41, 27.8, 52), @(46, 40.5, 47.2, 52), @(51, 38, 53.2, 51.5))) { $g.DrawLine($pata, (P $p[0] $p[1]), (P $p[2] $p[3])) }
$ojo = P 15.2 30.6
$g.FillEllipse((New-Object System.Drawing.SolidBrush (Color '#B0601E')), $ojo.X - 1.3 * $s, $ojo.Y - 1.3 * $s, 2.6 * $s, 2.6 * $s)

# Textos
$titulo = New-Object System.Drawing.Font 'Segoe UI', 104, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$sub = New-Object System.Drawing.Font 'Segoe UI', 46, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$chico = New-Object System.Drawing.Font 'Segoe UI', 32, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
$suave = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(225, 255, 255, 255))
$g.DrawString('Guatusa', $titulo, $blanco, 520, 150)
$g.DrawString('Lo gratis y legal,', $sub, $blanco, 528, 290)
$g.DrawString('en un solo lugar.', $sub, $blanco, 528, 346)
$g.DrawString('Juegos, programas y cine gratis', $chico, $suave, 530, 430)
$g.DrawString('Una sección de Brizna Soft · Honduras', $chico, $suave, 530, 474)

$bmp.Save($salida, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Host "Listo: $salida"
