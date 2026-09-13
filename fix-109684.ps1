# fix-109684.ps1
# Baja el branch con el fix de #109684 (arrastrar un chat de bot al split),
# instala el Hermes Desktop desde fuente y lo abre para probarlo.
#
# Uso:
#   irm https://raw.githubusercontent.com/Synero/hermes-agent/fix109684-helper/fix-109684.ps1 | iex
#
# Requisitos: Node 22.22+ / 24.11+ y uv o Python 3.11+.
# El Desktop instalado debe estar CERRADO (comparte el perfil %LOCALAPPDATA%\hermes).

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Fail([string]$msg) {
  Write-Host ""
  Write-Host "ERROR: $msg" -ForegroundColor Red
  exit 1
}

$root     = Join-Path $HOME "hermes-fix109684"
$branch   = "fix/desktop-bot-chat-split"
$tarball  = "https://github.com/Synero/hermes-agent/archive/refs/heads/fix/desktop-bot-chat-split.tar.gz"

Write-Host ""
Write-Host "== Hermes Desktop con el fix de #109684 ==" -ForegroundColor Cyan
Write-Host "   carpeta: $root"
Write-Host ""

# --- 1. Node ---------------------------------------------------------------
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeCmd) {
  Fail "no encontre Node. Instalalo con:  winget install OpenJS.NodeJS.LTS"
}
$nodeVer = (& node -v).Trim().TrimStart("v")
$parts = $nodeVer.Split(".")
$maj = [int]$parts[0]
$min = [int]$parts[1]
$nodeOk = ($maj -eq 22 -and $min -ge 22) -or ($maj -eq 24 -and $min -ge 11) -or ($maj -gt 24)
if (-not $nodeOk) {
  Fail "Node $nodeVer no sirve: el repo pide 22.22+, 24.11+ o superior. Actualizalo con:  winget upgrade OpenJS.NodeJS.LTS"
}
Write-Host "   node $nodeVer  OK" -ForegroundColor Green

# --- 2. bajar y descomprimir el branch ------------------------------------
New-Item -ItemType Directory -Force $root | Out-Null
Write-Host "   bajando $branch"
Invoke-WebRequest $tarball -OutFile (Join-Path $root "src.tar.gz")
tar -xzf (Join-Path $root "src.tar.gz") -C $root --strip-components=1
if (-not (Test-Path (Join-Path $root "apps\desktop\package.json"))) {
  Fail "la descarga no quedo completa (falta apps\desktop\package.json)"
}
Write-Host "   codigo listo  OK" -ForegroundColor Green

# --- 3. dependencias del workspace (raiz) ---------------------------------
Write-Host ""
Write-Host "   npm install en la raiz. Son varios minutos, dejalo correr"
Push-Location $root
npm install
if ($LASTEXITCODE -ne 0) { Pop-Location; Fail "npm install fallo (mira el error de arriba)" }
Pop-Location
Write-Host "   dependencias  OK" -ForegroundColor Green

# --- 4. venv del backend --------------------------------------------------
$py = Join-Path $root "venv\Scripts\python.exe"
$uvCmd = Get-Command uv -ErrorAction SilentlyContinue
if (-not (Test-Path $py)) {
  if ($uvCmd) {
    Write-Host "   creando venv con uv"
    Push-Location $root
    uv venv venv --python 3.11
    Pop-Location
  } else {
    Write-Host "   creando venv con python -m venv"
    Push-Location $root
    python -m venv venv
    if ($LASTEXITCODE -ne 0) { Pop-Location; Fail "no pude crear el venv: necesito uv o Python 3.11+ en el PATH" }
    Pop-Location
  }
}
if (-not (Test-Path $py)) { Fail "el venv quedo sin python.exe" }

Write-Host "   instalando el agente en el venv"
Push-Location $root
if ($uvCmd) {
  uv pip install --python $py -e ".[all]"
} else {
  & $py -m pip install -e ".[all]"
}
if ($LASTEXITCODE -ne 0) { Pop-Location; Fail "fallo la instalacion del agente en el venv" }
Pop-Location
Write-Host "   backend listo  OK" -ForegroundColor Green

# --- 5. abrir --------------------------------------------------------------
Write-Host ""
Write-Host "   Si lo que quieres es la app instalada y no el modo dev, corta esto" -ForegroundColor Yellow
Write-Host "   y corre en $root\apps\desktop :  npm run dist:win" -ForegroundColor Yellow
Write-Host ""
Write-Host "== abriendo el Desktop ==" -ForegroundColor Cyan
Write-Host "   Para probar: abri un chat de bot desde BOTS, arrastra el tab al borde" -ForegroundColor Gray
Write-Host "   del workspace, tiene que aparecer el split con el chat adentro." -ForegroundColor Gray
Write-Host "   Si el backend no arranca: %LOCALAPPDATA%\hermes\logs\desktop.log" -ForegroundColor Gray
Write-Host ""

Push-Location (Join-Path $root "apps\desktop")
npm run dev
