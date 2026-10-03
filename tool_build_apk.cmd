@echo off
rem Script temporal: build RELEASE del APK con log.
rem
rem 1) SDK sin espacios: el `flutter` del PATH vive en "...\Desktop\flutter"
rem    (con espacios) y ahi los hooks de native assets fallan con
rem    `"C:\Users\windows" no se reconoce como un comando interno o externo.`
rem    (README §4). Por eso se usa C:\flutter, que ya no necesita apagar los
rem    native assets (el flag del proyecto queda como lo pide README).
rem 2) La URL de produccion va por --dart-define: en release el certificado
rem    autofirmado de Herd NO se acepta (README §4.1), asi que este APK no
rem    sirve contra el tunel USB; para eso esta tool_build_apk_debug.cmd.
cd /d "%~dp0"
call C:\flutter\bin\flutter.bat build apk --release --dart-define=API_BASE_URL=https://app.ezyventas.com/api/v1 > "%~dp0build\release_build.log" 2>&1
echo EXITCODE=%ERRORLEVEL% >> "%~dp0build\release_build.log"
