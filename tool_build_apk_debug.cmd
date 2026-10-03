@echo off
rem Script temporal: build DEBUG del APK para probar a mano en el telefono
rem contra la API local por el tunel USB (README §4.1).
rem
rem 1) SDK sin espacios: el `flutter` del PATH vive en "...\Desktop\flutter"
rem    (con espacios) y ahi los hooks de native assets fallan (README §4).
rem 2) Tiene que ser --debug: el certificado autofirmado de Herd solo se acepta
rem    con kDebugMode, asi que un APK de release/profile apuntado al tunel
rem    falla la conexion (README §4.1).
rem 3) Los defines son los mismos que usa .vscode/launch.json (F5).
cd /d "%~dp0"
call C:\flutter\bin\flutter.bat build apk --debug --dart-define=API_BASE_URL=https://127.0.0.1:8443/api/v1 --dart-define=API_HOST_HEADER=ezyventas2.test > "%~dp0build\debug_build.log" 2>&1
echo EXITCODE=%ERRORLEVEL% >> "%~dp0build\debug_build.log"
