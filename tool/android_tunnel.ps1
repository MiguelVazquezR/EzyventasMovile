<#
.SYNOPSIS
    Abre (o cierra) el tunel USB que permite probar la app en un telefono fisico
    contra el servidor Laravel Herd del equipo.

.DESCRIPTION
    El servidor local publica cada proyecto en un dominio .test que solo resuelve
    en este equipo (`C:\Windows\System32\drivers\etc\hosts`) y Herd escucha
    unicamente en `127.0.0.1`, asi que desde el Wi-Fi el telefono no puede
    alcanzarlo. La solucion sin tocar la red es un tunel inverso por USB:

        adb reverse tcp:8443 tcp:443

    Con el tunel, `https://127.0.0.1:8443` en el telefono llega al Herd del
    equipo. Como Herd elige el sitio por el header `Host`, la app debe declararlo:

        --dart-define=API_BASE_URL=https://127.0.0.1:8443/api/v1
        --dart-define=API_HOST_HEADER=ezyventas2.test

    (esto ya esta en `.vscode/launch.json`: basta con F5).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tool\android_tunnel.ps1
    powershell -ExecutionPolicy Bypass -File tool\android_tunnel.ps1 -Status
    powershell -ExecutionPolicy Bypass -File tool\android_tunnel.ps1 -Remove
#>
[CmdletBinding()]
param(
    # Puerto local del telefono que se tuneliza hacia el HTTPS del equipo.
    [int]$Port = 8443,
    # Quita el tunel en lugar de crearlo.
    [switch]$Remove,
    # Solo muestra el estado del tunel y de los dispositivos conectados.
    [switch]$Status
)

$ErrorActionPreference = 'Stop'

function Get-AdbPath {
    $candidates = @()
    if ($env:ANDROID_HOME) { $candidates += (Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe') }
    if ($env:ANDROID_SDK_ROOT) { $candidates += (Join-Path $env:ANDROID_SDK_ROOT 'platform-tools\adb.exe') }
    if ($env:LOCALAPPDATA) { $candidates += (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe') }
    $candidates += 'C:\Program Files (x86)\Android\android-sdk\platform-tools\adb.exe'

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) { return $candidate }
    }

    $onPath = Get-Command adb -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }

    throw 'No encontre adb.exe. Instala Android SDK Platform-Tools o define ANDROID_HOME.'
}

$adb = Get-AdbPath
Write-Host "adb: $adb"

$devices = & $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '\sdevice$' }
if (-not $devices) {
    Write-Warning 'No hay ningun dispositivo Android conectado (USB + depuracion USB activada).'
}

# `adb reverse --remove` escribe en stderr cuando no habia un listener previo
# ("error: listener 'tcp:<puerto>' not found"). Con $ErrorActionPreference = 'Stop'
# esa salida de un comando nativo aborta el script, justo en el caso mas comun
# (primer tunel, o tunel que ya se habia caido). Alrededor de los --remove se
# relaja la preferencia para que sea de verdad idempotente.
function Remove-ReverseTunnel {
    param([int]$RemovePort)

    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $adb reverse --remove "tcp:$RemovePort" 2>&1 | Out-Null
    } finally {
        $ErrorActionPreference = $previous
    }
}

if ($Remove) {
    Remove-ReverseTunnel -RemovePort $Port
    Write-Host "Tunel tcp:$Port eliminado."
} elseif (-not $Status) {
    # Se quita primero: si el telefono se reconecto (o el servidor adb se
    # reinicio), el registro puede quedar "vivo" en la lista pero muerto en la
    # practica (el telefono no llega a Herd). Volver a crearlo sin quitarlo deja
    # ese estado pegado; quitarlo y volver a crearlo siempre funciona.
    Remove-ReverseTunnel -RemovePort $Port
    & $adb reverse "tcp:$Port" 'tcp:443'
    Write-Host "Tunel listo: en el telefono, https://127.0.0.1:$Port -> https://127.0.0.1:443 (Herd)."
    Write-Host ''
    Write-Host 'Comprueba desde el TELEFONO que llega a la API (Herd exige el Host del vhost):'
    Write-Host "  adb push tool\android_tunnel_check.sh /data/local/tmp/   # y dos2unix si lo editas en Windows"
    Write-Host "  adb shell sh /data/local/tmp/android_tunnel_check.sh correo@negocio.com 'secreto'"
    Write-Host '  (404 sin Host, 401 con Host sin token, 200 en el login real = tunel OK)'
}

Write-Host ''
Write-Host 'Tuneles activos:'
& $adb reverse --list
