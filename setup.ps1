# ============================================================
#  setup.ps1 — Windows セットアップ
#  Go + Node.js + Python + Docker を一括インストール
#
#  実行方法（PowerShell を管理者として開く）:
#    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
#    .\setup.ps1
# ============================================================

$ErrorActionPreference = "Stop"

function Info  { Write-Host "[✓] $args" -ForegroundColor Green }
function Warn  { Write-Host "[!] $args" -ForegroundColor Yellow }
function Step  { Write-Host "`n▶ $args" -ForegroundColor Cyan }
function Err   { Write-Host "[✗] $args" -ForegroundColor Red; exit 1 }

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  File Server セットアップ (Windows)"  -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

# ── 0. 管理者権限チェック ──
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
  Err "管理者として PowerShell を実行してください。`n右クリック → 管理者として実行"
}

# ── 1. winget チェック ──
Step "winget 確認"
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  Err "winget が見つかりません。Microsoft Store から 'アプリインストーラー' をインストールしてください。"
}
Info "winget 利用可能"

# ── 2. Go ──
Step "Go インストール"
if (Get-Command go -ErrorAction SilentlyContinue) {
  Info "Go すでにインストール済み: $(go version)"
} else {
  winget install --id GoLang.Go --silent --accept-package-agreements --accept-source-agreements
  # PATH を現在のセッションにも反映
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
              [System.Environment]::GetEnvironmentVariable("Path","User")
  Info "Go インストール完了"
}

# ── 3. Node.js ──
Step "Node.js インストール"
if (Get-Command node -ErrorAction SilentlyContinue) {
  Info "Node.js すでにインストール済み: $(node -v)"
} else {
  winget install --id OpenJS.NodeJS.LTS --silent --accept-package-agreements --accept-source-agreements
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
              [System.Environment]::GetEnvironmentVariable("Path","User")
  Info "Node.js インストール完了"
}

# ── 4. Python ──
Step "Python インストール"
if (Get-Command python -ErrorAction SilentlyContinue) {
  Info "Python すでにインストール済み: $(python --version)"
} else {
  winget install --id Python.Python.3.12 --silent --accept-package-agreements --accept-source-agreements
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
              [System.Environment]::GetEnvironmentVariable("Path","User")
  Info "Python インストール完了"
}

# pip パッケージ
Step "Python パッケージインストール"
python -m pip install --upgrade pip --quiet
python -m pip install requests PyPDF2 Pillow watchdog --quiet
Info "Python パッケージインストール完了"

# ── 5. Docker Desktop ──
Step "Docker Desktop インストール"
if (Get-Command docker -ErrorAction SilentlyContinue) {
  Info "Docker すでにインストール済み: $(docker --version)"
} else {
  winget install --id Docker.DockerDesktop --silent --accept-package-agreements --accept-source-agreements
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
              [System.Environment]::GetEnvironmentVariable("Path","User")
  Info "Docker Desktop インストール完了"
  Warn "Docker Desktop を起動してから docker compose を実行してください"
}

# ── 6. プロジェクト依存インストール ──
Step "プロジェクト依存関係のインストール"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Go
$goMod = Join-Path $ScriptDir "fileserver\go.mod"
if (Test-Path $goMod) {
  Push-Location (Join-Path $ScriptDir "fileserver")
  go mod tidy 2>$null
  Pop-Location
  Info "Go モジュール準備完了"
}

# Node.js
$pkgJson = Join-Path $ScriptDir "dashboard\package.json"
if (Test-Path $pkgJson) {
  Push-Location (Join-Path $ScriptDir "dashboard")
  npm install --silent
  Pop-Location
  Info "npm パッケージインストール完了"
}

# ── 7. 完了 ──
Write-Host ""
Write-Host "======================================" -ForegroundColor Green
Write-Host "  セットアップ完了！"                   -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host ""
Write-Host "起動方法:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  [Docker で起動 — 推奨]"
Write-Host "    docker compose up --build"
Write-Host ""
Write-Host "  [個別起動 (PowerShell 3つ開く)]"
Write-Host "    cd fileserver; go run main.go"
Write-Host "    cd dashboard; npm start"
Write-Host "    cd worker;    python worker.py"
Write-Host ""
Write-Host "  ブラウザ: http://localhost:3000" -ForegroundColor Green
Write-Host ""
Warn "PATH変更を反映するため、PowerShellを再起動してください"
