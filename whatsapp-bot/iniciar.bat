@echo off
title Bot WhatsApp - NO CIERRES ESTA VENTANA
cd /d "%~dp0"
if not exist node_modules (
  echo Instalando dependencias, espera un momento...
  call npm install --no-audit --no-fund
)
start "" cmd /c "timeout /t 6 >nul & start http://localhost:3008"
node app.mjs
pause
