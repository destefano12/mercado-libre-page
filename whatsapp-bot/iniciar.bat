@echo off
cd /d "%~dp0"
if not exist node_modules (
  echo Instalando dependencias, espera un momento...
  call npm install
)
start "" http://localhost:3008
node app.mjs
pause
