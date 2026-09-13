# fix-109684.ps1
# Baja el branch con el fix de #109684 (arrastrar un chat de bot al split),
# compila el INSTALADOR del Hermes Desktop y lo abre para que instales la app
# como siempre, con el fix adentro.
#
# Uso:
#   irm https://raw.githubusercontent.com/Synero/hermes-agent/fix109684-helper/fix-109684.ps1 | iex
#
# Requisitos: Node 22.22+ / 24.11+ y unos 4 GB libres en disco.
# El Desktop instalado debe estar CERRADO mientras instalas la nueva version.

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Fail([string]$msg) {
  Write-Host ""
  Write-Host "ERROR: $msg" -ForegroundColor Red
  exit 1
}

$root    = Join-Path $HOME "hermes-fix109684"
$tarball = "https://github.com/Synero/hermes-agent/archive/refs/heads/fix/desktop-bot-chat-split.tar.gz"

Write-Host ""
Write-Host "== Hermes Desktop con el fix de #109684 ==" -ForegroundColor Cyan
Write-Host "   Esto compila el instalador de la app, no el modo dev."
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

# --- 2. bajar el branch ----------------------------------------------------
if (Test-Path $root) { Remove-Item -Recurse -Force $root }
New-Item -ItemType Directory -Force $root | Out-Null
Write-Host "   bajando el branch con el fix"
Invoke-WebRequest $tarball -OutFile (Join-Path $root "src.tar.gz")
tar -xzf (Join-Path $root "src.tar.gz") -C $root --strip-components=1
if (-not (Test-Path (Join-Path $root "apps\desktop\package.json"))) {
  Fail "la descarga no quedo completa (falta apps\desktop\package.json)"
}
Write-Host "   codigo listo  OK" -ForegroundColor Green

# --- 3. dependencias del workspace ----------------------------------------
Write-Host ""
Write-Host "   npm install en la raiz. Varios minutos, dejalo correr"
Push-Location $root
npm install
if ($LASTEXITCODE -ne 0) { Pop-Location; Fail "npm install fallo (mira el error de arriba)" }
Pop-Location
Write-Host "   dependencias  OK" -ForegroundColor Green

# --- 4. compilar el instalador --------------------------------------------
Write-Host ""
Write-Host "   compilando el instalador. La primera vez baja herramientas de build,"
Write-Host "   puede tardar 5 a 15 minutos"
Push-Location (Join-Path $root "apps\desktop")
npm run dist:win
if ($LASTEXITCODE -ne 0) { Pop-Location; Fail "fallo el build del instalador (mira el error de arriba)" }
Pop-Location

$releaseDir = Join-Path $root "apps\desktop\release"
$installer = Get-ChildItem -Path $releaseDir -Filter "*.exe" -ErrorAction SilentlyContinue |
             Where-Object { $_.Name -notmatch "uninstall" } |
             Sort-Object LastWriteTime -Descending |
             Select-Object -First 1
if (-not $installer) {
  Fail "el build termino pero no encontre el instalador en $releaseDir"
}

Write-Host ""
Write-Host "   instalador listo  OK" -ForegroundColor Green
Write-Host "   $($installer.FullName)"
Write-Host ""
Write-Host "== Abriendo el instalador ==" -ForegroundColor Cyan
Write-Host "   Windows va a avisar que el archivo no esta firmado (es normal, lo" -ForegroundColor Gray
Write-Host "   compilamos nosotros): Mas informacion -> Ejecutar de todas formas." -ForegroundColor Gray
Write-Host "   Instalalo encima del Hermes que ya tienes: mismo acceso, mismo perfil," -ForegroundColor Gray
Write-Host "   mismos bots. Despues cerralo y volvelo a abrir." -ForegroundColor Gray
Write-Host ""
Write-Host "   Para probar: abri un chat de bot desde BOTS y arrastra el tab al borde" -ForegroundColor Gray
Write-Host "   del workspace. Tiene que aparecer el split con el chat adentro." -ForegroundColor Gray
Write-Host "   Antes de este fix, el arrastre no hacia nada." -ForegroundColor Gray
Write-Host ""

Start-Process -FilePath $installer.FullName
