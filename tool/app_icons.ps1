<#
.SYNOPSIS
    Genera el icono de lanzamiento de Android a partir de assets\images\ezyventas_icon.jpg.

.DESCRIPTION
    Android pide un PNG por densidad (48..192 px) y, desde Android 8 (API 26),
    un icono adaptativo de dos capas (fondo + primer plano) que el launcher
    recorta con su propia mascara. El script hace las dos cosas:

      * mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}\ic_launcher.png: el arte
        original recortado con su esquina redondeada, para que las esquinas
        queden transparentes y el launcher pinte lo suyo.
      * Icono adaptativo: mipmap-anydpi-v26\ic_launcher.xml + el color de
        fondo de la marca (values\ic_launcher_background.xml) + el arte al 80%
        centrado en mipmap-*\ic_launcher_foreground.png (108..432 px), dentro
        de la zona segura (66%) de cualquier mascara.

    Es idempotente: se puede volver a ejecutar cuando cambie el arte de origen
    (y conviene recompilar con `flutter build apk`). Usa System.Drawing, que ya
    viene con Windows PowerShell 5.1.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tool\app_icons.ps1
#>
[CmdletBinding()]
param(
    # Arte original del icono (cuadrado; 1024 px recomendado).
    [string]$Source,
    # Carpeta res de la app Android donde se escriben los mipmap.
    [string]$ResRoot,
    # Radio de la esquina sobre un lienzo de 1024 px. El arte original redondea
    # en 153; se recorta un poco mas adentro para que no quede borde blanco.
    [int]$CornerRadius = 145,
    # Color de fondo del icono adaptativo (el del arte original).
    [string]$BackgroundColor = '#14191D',
    # Tamano del arte dentro del icono adaptativo (la zona segura es 0.66).
    [double]$ForegroundScale = 0.80
)

$ErrorActionPreference = 'Stop'

# $PSScriptRoot todavia no esta inicializado cuando PowerShell evalua los
# valores por defecto de param(), asi que las rutas se resuelven aqui.
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Source) {
    $Source = Join-Path $scriptDir '..\assets\images\ezyventas_icon.jpg'
}
if (-not $ResRoot) {
    $ResRoot = Join-Path $scriptDir '..\android\app\src\main\res'
}

Add-Type -AssemblyName System.Drawing

$Source = [System.IO.Path]::GetFullPath($Source)
$ResRoot = [System.IO.Path]::GetFullPath($ResRoot)

if (-not (Test-Path $Source)) {
    throw "No encontre el arte de origen: $Source"
}

# La densidad base es 48 px (mdpi) para el PNG legacy y 108 px (108 dp) para la
# capa de primer plano del icono adaptativo.
$densities = @(
    @{ Name = 'mdpi';    Legacy = 48;  Adaptive = 108 },
    @{ Name = 'hdpi';    Legacy = 72;  Adaptive = 162 },
    @{ Name = 'xhdpi';   Legacy = 96;  Adaptive = 216 },
    @{ Name = 'xxhdpi';  Legacy = 144; Adaptive = 324 },
    @{ Name = 'xxxhdpi'; Legacy = 192; Adaptive = 432 }
)

function New-RoundedRectPath {
    param(
        [System.Drawing.RectangleF]$Rect,
        [single]$Radius
    )

    $diameter = [single]($Radius * 2)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($Rect.X, $Rect.Y, $diameter, $diameter, 180, 90)
    $path.AddArc(($Rect.Right - $diameter), $Rect.Y, $diameter, $diameter, 270, 90)
    $path.AddArc(($Rect.Right - $diameter), ($Rect.Bottom - $diameter), $diameter, $diameter, 0, 90)
    $path.AddArc($Rect.X, ($Rect.Bottom - $diameter), $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function New-TransparentCanvas {
    param([int]$Size)

    $bitmap = New-Object System.Drawing.Bitmap(
        $Size,
        $Size,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

    return @{ Bitmap = $bitmap; Graphics = $graphics }
}

function Save-Png {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [string]$Path
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path $directory)) {
        [void](New-Item -ItemType Directory -Path $directory -Force)
    }

    $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host ("  {0} ({1}x{1})" -f $Path.Replace($ResRoot + '\', ''), $Bitmap.Width)
}

$art = [System.Drawing.Image]::FromFile($Source)
$master = $null

try {
    Write-Host ("Arte de origen: {0} ({1}x{2})" -f $Source, $art.Width, $art.Height)

    # Lienzo maestro: si el arte no es cuadrado se recorta al centro y se
    # escala a 1024 px, que es de donde salen todas las densidades.
    $side = [Math]::Min($art.Width, $art.Height)
    $sourceRect = New-Object System.Drawing.RectangleF(
        [single](($art.Width - $side) / 2),
        [single](($art.Height - $side) / 2),
        [single]$side,
        [single]$side
    )

    $masterSize = 1024
    $master = New-TransparentCanvas $masterSize
    $masterRect = New-Object System.Drawing.RectangleF(
        [single]0, [single]0, [single]$masterSize, [single]$masterSize
    )
    $clip = New-RoundedRectPath $masterRect ([single]($CornerRadius * ($masterSize / $side)))

    $master.Graphics.SetClip($clip)
    $master.Graphics.DrawImage($art, $masterRect, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)
    $master.Graphics.ResetClip()

    foreach ($density in $densities) {
        $legacy = New-TransparentCanvas $density.Legacy
        $legacyRect = New-Object System.Drawing.RectangleF(
            [single]0, [single]0, [single]$density.Legacy, [single]$density.Legacy
        )
        $legacy.Graphics.DrawImage($master.Bitmap, $legacyRect)
        Save-Png $legacy.Bitmap (Join-Path $ResRoot ("mipmap-{0}\ic_launcher.png" -f $density.Name))
        $legacy.Graphics.Dispose()
        $legacy.Bitmap.Dispose()

        $size = $density.Adaptive
        $artSize = [single]($size * $ForegroundScale)
        $offset = [single](($size - $artSize) / 2)
        $foreground = New-TransparentCanvas $size
        $foregroundRect = New-Object System.Drawing.RectangleF($offset, $offset, $artSize, $artSize)
        $foreground.Graphics.DrawImage($master.Bitmap, $foregroundRect)
        Save-Png $foreground.Bitmap (Join-Path $ResRoot ("mipmap-{0}\ic_launcher_foreground.png" -f $density.Name))
        $foreground.Graphics.Dispose()
        $foreground.Bitmap.Dispose()
    }
} finally {
    if ($master) {
        $master.Graphics.Dispose()
        $master.Bitmap.Dispose()
    }
    $art.Dispose()
}


# Icono adaptativo: el launcher recorta las dos capas con su mascara (circulo,
# squircle, etc.), asi que el XML solo apunta al color y al PNG ya generados.
$anydpi = Join-Path $ResRoot 'mipmap-anydpi-v26'
if (-not (Test-Path $anydpi)) {
    [void](New-Item -ItemType Directory -Path $anydpi -Force)
}

$launcherXml = @"
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"@
Set-Content -Path (Join-Path $anydpi 'ic_launcher.xml') -Value $launcherXml -Encoding Ascii
Write-Host '  mipmap-anydpi-v26\ic_launcher.xml'

$values = Join-Path $ResRoot 'values'
if (-not (Test-Path $values)) {
    [void](New-Item -ItemType Directory -Path $values -Force)
}

$backgroundXml = @"
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">$BackgroundColor</color>
</resources>
"@
Set-Content -Path (Join-Path $values 'ic_launcher_background.xml') -Value $backgroundXml -Encoding Ascii
Write-Host '  values\ic_launcher_background.xml'

Write-Host ''
Write-Host 'Listo. Recompila para verlo en el telefono:'
Write-Host '  flutter build apk --debug'
Write-Host '  adb install -r -t build\app\outputs\flutter-apk\app-debug.apk'
