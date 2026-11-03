# Instalador automatico del Bot de WhatsApp (BuilderBot + Gemini)
# Uso (PowerShell):
#   irm https://raw.githubusercontent.com/destefano12/mercado-libre-page/claude/vigilant-pascal-e6k4al/whatsapp-bot/instalar.ps1 | iex

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Rama = 'claude/vigilant-pascal-e6k4al'
$Zip  = "https://codeload.github.com/destefano12/mercado-libre-page/zip/refs/heads/$Rama"
$Dest = Join-Path $env:USERPROFILE 'BotWhatsApp'

function Paso($t) { Write-Host "`n==> $t" -ForegroundColor Green }
function RefrescarPath {
  $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
}

Write-Host "`n  BOT DE WHATSAPP PARA TU NEGOCIO - instalador automatico`n" -ForegroundColor Cyan

# 1) Node.js
Paso 'Revisando Node.js...'
RefrescarPath
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  Write-Host 'Node.js no esta instalado. Instalando (puede pedir permiso de administrador, acepta)...'
  $ok = $false
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget install -e --id OpenJS.NodeJS.LTS --silent --accept-package-agreements --accept-source-agreements
    RefrescarPath
    $ok = [bool](Get-Command node -ErrorAction SilentlyContinue)
  }
  if (-not $ok) {
    $msi = Join-Path $env:TEMP 'node-lts.msi'
    Invoke-WebRequest 'https://nodejs.org/dist/v22.21.1/node-v22.21.1-x64.msi' -OutFile $msi
    Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /passive /norestart" -Wait
    RefrescarPath
  }
  if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    $env:Path += ';C:\Program Files\nodejs'
  }
  if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw 'No se pudo instalar Node.js. Cierra esta ventana, abre una nueva y vuelve a pegar el comando.'
  }
}
Write-Host ("Node.js " + (node -v) + " listo.")

# Cierra el bot si estaba abierto (dos bots a la vez hacen que WhatsApp cierre la sesion)
Get-CimInstance Win32_Process -Filter "Name='cmd.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like '*iniciar.bat*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Get-CimInstance Win32_Process -Filter "Name='node.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like '*app.mjs*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 2

# 2) Descargar el bot
Paso "Descargando el bot en $Dest ..."
$tmpZip = Join-Path $env:TEMP 'botwhatsapp.zip'
$tmpDir = Join-Path $env:TEMP 'botwhatsapp_src'
Invoke-WebRequest $Zip -OutFile $tmpZip
if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force }
Expand-Archive $tmpZip -DestinationPath $tmpDir -Force
$src = Get-ChildItem $tmpDir -Directory | Select-Object -First 1 | ForEach-Object { Join-Path $_.FullName 'whatsapp-bot' }
New-Item -ItemType Directory -Force -Path $Dest | Out-Null
# Copia todo, pero NO pisa tu negocio.txt ni tu sesion de WhatsApp si ya existen
$xf = @()
$neg = Join-Path $Dest 'negocio.txt'
if ((Test-Path $neg) -and -not (Select-String -Path $neg -Pattern 'Mi Negocio' -Quiet)) { $xf = @('/XF', 'negocio.txt') }
robocopy $src $Dest /E /NFL /NDL /NJH /NJS /NP @xf | Out-Null
Remove-Item $tmpZip, $tmpDir -Recurse -Force -ErrorAction SilentlyContinue

# 3) Clave de Google AI Studio
$envFile = Join-Path $Dest '.env'
if (-not (Test-Path $envFile) -or (Get-Content $envFile -Raw) -match 'pega_aqui') {
  Paso 'Configuracion'
  Write-Host 'Crea tu clave gratis en https://aistudio.google.com/apikey (boton "Create API key").'
  Start-Process 'https://aistudio.google.com/apikey'
  do { $key = (Read-Host 'Pega aqui tu clave de Google AI Studio y presiona Enter').Trim() } while ($key.Length -lt 20)
  $num = (Read-Host 'Tu celular personal para recibir avisos (ej 56912345678). Enter para omitir').Trim() -replace '\D',''
  $contenido = "GEMINI_API_KEY=$key`nGEMINI_MODEL=gemini-flash-latest`nNUMERO_DUENO=$num`nPORT=3008`n"
  [IO.File]::WriteAllText($envFile, $contenido, (New-Object System.Text.UTF8Encoding $false))
} else {
  Write-Host 'Ya tenias tu clave configurada, la mantengo.'
}

# 4) Instalar dependencias
Paso 'Instalando dependencias (1-2 minutos)...'
Push-Location $Dest
npm.cmd install --no-audit --no-fund
Pop-Location

# 5) Acceso directo en el escritorio
Paso 'Creando acceso directo "Bot WhatsApp" en tu escritorio...'
$ws = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'Bot WhatsApp.lnk'))
$lnk.TargetPath = Join-Path $Dest 'iniciar.bat'
$lnk.WorkingDirectory = $Dest
$lnk.IconLocation = 'shell32.dll,13'
$lnk.Save()

# 6) Iniciar
Paso 'Iniciando el bot...'
Start-Process (Join-Path $Dest 'iniciar.bat') -WorkingDirectory $Dest
Write-Host "`nLISTO. Se abrira el panel en tu navegador (http://localhost:3008)." -ForegroundColor Cyan
Write-Host 'Escanea el QR: WhatsApp > Dispositivos vinculados > Vincular un dispositivo.'
Write-Host 'La proxima vez solo haz doble clic en "Bot WhatsApp" en tu escritorio.'
Write-Host 'Para cambiar horarios/precios edita:' (Join-Path $Dest 'negocio.txt')
