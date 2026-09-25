<#
.SYNOPSIS
    Genera el logotipo de la pantalla de carga nativa de Android a partir de
    assets\images\white_logo.png.

.DESCRIPTION
    El tema de lanzamiento (`LaunchTheme`) pinta el logotipo mientras el motor
    de Flutter levanta, y hasta ahora no había ninguno: lo único visible era el
    `windowBackground` (negro en tema oscuro), que es la "pantalla negra" que se
    veía antes del splash de la app.

    Se dibuja el logotipo **blanco** (el mismo que usa `BrandLogo` en el tema
    oscuro) al mismo tamaño lógico que el splash de Flutter (184 x 84 dp) y se
    guarda en `drawable-xxxhdpi` (4x = 736 x 336 px): Android lo reescala a la
    densidad del teléfono sin perder nitidez.

    Es idempotente: se puede volver a ejecutar cuando cambie el arte de origen.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tool\launch_logo.ps1
#>
[CmdletBinding()]
param(
    # Logotipo blanco (PNG con transparencia).
    [string]$Source,
    # Carpeta res de la app Android donde se escribe el PNG.
    [string]$ResRoot,
    # Ancho en pixeles del logo dentro del arranque (736 px = 184 dp a 4x).
    [int]$Width = 736
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Source) {
    $Source = Join-Path $scriptDir '..\assets\images\white_logo.png'
}
if (-not $ResRoot) {
    $ResRoot = Join-Path $scriptDir '..\android\app\src\main\res'
}

Add-Type -AssemblyName System.Drawing

$Source = [System.IO.Path]::GetFullPath($Source)
$ResRoot = [System.IO.Path]::GetFullPath($ResRoot)

if (-not (Test-Path $Source)) {
    throw "No encontre el logotipo de origen: $Source"
}

$art = [System.Drawing.Image]::FromFile($Source)

try {
    Write-Host ("Logotipo de origen: {0} ({1}x{2})" -f $Source, $art.Width, $art.Height)

    # La altura sale de la proporcion original del logotipo.
    $height = [int][Math]::Round($Width * $art.Height / $art.Width)

    $canvas = New-Object System.Drawing.Bitmap($Width, $height)
    $canvas.SetResolution(96, 96)
    $graphics = [System.Drawing.Graphics]::FromImage($canvas)

    try {
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $rect = New-Object System.Drawing.RectangleF(
            [single]0, [single]0, [single]$Width, [single]$height
        )
        $graphics.DrawImage($art, $rect)
    } finally {
        $graphics.Dispose()
    }

    $target = Join-Path $ResRoot 'drawable-xxxhdpi'
    if (-not (Test-Path $target)) {
        [void](New-Item -ItemType Directory -Path $target -Force)
    }

    $file = Join-Path $target 'launch_logo.png'
    $canvas.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host ("  drawable-xxxhdpi\launch_logo.png ({0}x{1})" -f $Width, $height)

    $canvas.Dispose()
} finally {
    $art.Dispose()
}

Write-Host ''
Write-Host 'Listo. Recompila para verlo en el telefono:'
Write-Host '  flutter build apk --debug'
