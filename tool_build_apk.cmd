@echo off
rem Script temporal: build RELEASE del APK + instalacion en el telefono, con log.
rem
rem 1) SDK sin espacios: el `flutter` del PATH vive en "...\Desktop\flutter"
rem    (con espacios) y ahi los hooks de native assets fallan con
rem    `"C:\Users\windows" no se reconoce como un comando interno o externo.`
rem    (README §4). Por eso se usa C:\flutter, que ya no necesita apagar los
rem    native assets (el flag del proyecto queda como lo pide README).
rem 2) La URL de produccion va por --dart-define: en release el certificado
rem    autofirmado de Herd NO se acepta (README §4.1), asi que este APK no
rem    sirve contra el tunel USB; para eso esta tool_build_apk_debug.cmd.
rem    Tampoco lleva API_HOST_HEADER: ese header existe solo para el tunel.
rem 3) El release firma con el keystore de debug (android/app/build.gradle.kts),
rem    la misma firma del APK de depuracion, asi que `adb install -r` actualiza
rem    en sitio y conserva la sesion del telefono.
setlocal
cd /d "%~dp0"

set "APK=%~dp0build\app\outputs\flutter-apk\app-release.apk"
set "LOG=%~dp0build\release_build.log"

call C:\flutter\bin\flutter.bat build apk --release --dart-define=API_BASE_URL=https://ezyventas.com/api/v1 > "%LOG%" 2>&1
set "BUILD_RC=%ERRORLEVEL%"
echo EXITCODE=%BUILD_RC% >> "%LOG%"

if not "%BUILD_RC%"=="0" (
    echo El build fallo. Revisa "%LOG%"
    exit /b %BUILD_RC%
)

rem --- adb: mismo criterio de busqueda que tool\android_tunnel.ps1 ----------
set "ADB="
if defined ANDROID_HOME if exist "%ANDROID_HOME%\platform-tools\adb.exe" set "ADB=%ANDROID_HOME%\platform-tools\adb.exe"
if not defined ADB if defined ANDROID_SDK_ROOT if exist "%ANDROID_SDK_ROOT%\platform-tools\adb.exe" set "ADB=%ANDROID_SDK_ROOT%\platform-tools\adb.exe"
if not defined ADB if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if not defined ADB for %%I in (adb.exe) do set "ADB=%%~$PATH:I"
if not defined ADB (
    echo No encontre adb.exe. Instala Android SDK Platform-Tools o define ANDROID_HOME.
    exit /b 1
)

echo adb: %ADB% >> "%LOG%"
"%ADB%" install -r "%APK%" >> "%LOG%" 2>&1
echo INSTALL_EXITCODE=%ERRORLEVEL% >> "%LOG%"
