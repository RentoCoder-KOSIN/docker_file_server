#!/bin/bash
# ============================================================
#  setup-brew.sh — Homebrew セットアップ
#  Mac / Chromebook(Linux) 共通
#  Go + Node.js + Python + Docker を Homebrew で一括インストール
# ============================================================
set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
step()  { echo -e "\n${YELLOW}▶ $1${NC}"; }

echo "======================================"
echo "  File Server セットアップ (Homebrew)"
echo "======================================"

# ── 0. root チェック ──
if [ "$EUID" -eq 0 ]; then
  error "root では実行しないでください。通常ユーザーで実行してください。"
fi

# ── 1. Homebrew インストール ──
step "Homebrew 確認"
if command -v brew &>/dev/null; then
  info "Homebrew すでにインストール済み: $(brew --version | head -1)"
  brew update --quiet
  info "Homebrew 更新完了"
else
  warn "Homebrew をインストールします..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Linux (Chromebook) の場合 PATH 追加
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi

  info "Homebrew インストール完了"
fi

# ── 2. Go ──
step "Go インストール"
if command -v go &>/dev/null; then
  info "Go すでにインストール済み: $(go version)"
else
  brew install go
  info "Go $(go version) インストール完了"
fi

# ── 3. Node.js ──
step "Node.js インストール"
if command -v node &>/dev/null; then
  info "Node.js すでにインストール済み: $(node -v)"
else
  brew install node@20
  brew link node@20 --force --overwrite
  info "Node.js $(node -v) インストール完了"
fi

# ── 4. Python ──
step "Python インストール"
if command -v python3 &>/dev/null; then
  info "Python すでにインストール済み: $(python3 --version)"
else
  brew install python@3.12
  info "Python $(python3 --version) インストール完了"
fi

# pip パッケージ
pip3 install requests PyPDF2 Pillow watchdog --break-system-packages 2>/dev/null || \
pip3 install requests PyPDF2 Pillow watchdog
info "Python パッケージインストール完了"

# ── 5. Docker ──
step "Docker インストール"
if command -v docker &>/dev/null; then
  info "Docker すでにインストール済み: $(docker --version)"
else
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # Mac → Docker Desktop
    brew install --cask docker
    warn "Docker Desktop を起動してください (アプリケーション → Docker)"
  else
    # Linux → docker engine
    brew install docker docker-compose
    info "Docker インストール完了"
  fi
fi

# ── 6. プロジェクト依存インストール ──
step "プロジェクト依存関係のインストール"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/fileserver/go.mod" ]; then
  cd "$SCRIPT_DIR/fileserver" && go mod tidy 2>/dev/null || true
  info "Go モジュール準備完了"
  cd "$SCRIPT_DIR"
fi

if [ -f "$SCRIPT_DIR/dashboard/package.json" ]; then
  cd "$SCRIPT_DIR/dashboard" && npm install --silent
  info "npm パッケージインストール完了"
  cd "$SCRIPT_DIR"
fi

# ── 7. 完了 ──
echo ""
echo "======================================"
echo -e "  ${GREEN}セットアップ完了！${NC}"
echo "======================================"
echo ""
echo "起動方法:"
echo ""
echo "  [Docker で起動 — 推奨]"
echo "    docker compose up --build"
echo ""
echo "  [個別起動]"
echo "    ターミナル1: cd fileserver && go run main.go"
echo "    ターミナル2: cd dashboard && npm start"
echo "    ターミナル3: cd worker  && python3 worker.py"
echo ""
echo "  ブラウザ: http://localhost:3000"
echo ""
warn "変更を反映するため 'source ~/.bashrc' (Linux) または新しいターミナルを開いてください"
