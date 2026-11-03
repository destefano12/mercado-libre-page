@echo off
title Bot WhatsApp - NO CIERRES ESTA VENTANA
cd /d "%~dp0"
if not exist node_modules (
  echo Instalando dependencias, espera un momento...
  call npm install --no-audit --no-fund
)
start "" cmd /c "timeout /t 6 >nul & start http://localhost:3008"
:inicio
node app.mjs
echo.
echo El bot se detuvo. Se reinicia solo en 5 segundos... (cerra esta ventana para apagarlo)
timeout /t 5 >nul
goto inicio
