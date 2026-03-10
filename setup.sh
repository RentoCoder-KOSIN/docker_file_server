#!/bin/bash
# ============================================================
#  setup.sh — Chromebook (Linux / Debian) セットアップ
#  Go + Node.js + Python + Docker を一括インストール
# ============================================================
set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
step()  { echo -e "\n${YELLOW}▶ $1${NC}"; }

echo "======================================"
echo "  File Server セットアップ (Linux)"
echo "======================================"

# ── 0. root チェック ──
if [ "$EUID" -eq 0 ]; then
  error "root では実行しないでください。通常ユーザーで実行してください。"
fi

# ── 1. apt 更新 ──
step "システム更新"
sudo apt-get update -qq
sudo apt-get install -y curl wget git unzip ca-certificates gnupg lsb-release libmagic1

# ── 2. Go ──
step "Go インストール"
GO_VERSION="1.22.4"
if command -v go &>/dev/null; then
  info "Go すでにインストール済み: $(go version)"
else
  wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf /tmp/go.tar.gz
  rm /tmp/go.tar.gz

  # PATH設定
  if ! grep -q '/usr/local/go/bin' ~/.bashrc; then
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
  fi
  export PATH=$PATH:/usr/local/go/bin
  info "Go ${GO_VERSION} インストール完了"
fi

# ── 3. Node.js (nvm 経由) ──
step "Node.js インストール"
NODE_VERSION="20"
if command -v node &>/dev/null; then
  info "Node.js すでにインストール済み: $(node -v)"
else
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  source "$NVM_DIR/nvm.sh"
  nvm install $NODE_VERSION
  nvm use $NODE_VERSION
  nvm alias default $NODE_VERSION
  info "Node.js $(node -v) インストール完了"
fi

# ── 4. Python ──
step "Python インストール"
if command -v python3 &>/dev/null; then
  info "Python すでにインストール済み: $(python3 --version)"
else
  sudo apt-get install -y python3 python3-pip python3-venv
  info "Python $(python3 --version) インストール完了"
fi

# pip パッケージ
pip3 install --user requests PyPDF2 Pillow watchdog --break-system-packages 2>/dev/null || \
pip3 install --user requests PyPDF2 Pillow watchdog
info "Python パッケージインストール完了"

# ── 5. Docker ──
step "Docker インストール"
if command -v docker &>/dev/null; then
  info "Docker すでにインストール済み: $(docker --version)"
else
  # 公式GPGキー追加
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  # リポジトリ追加
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update -qq
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

  # sudoなしでdocker実行できるよう設定
  sudo usermod -aG docker $USER
  info "Docker インストール完了"
  warn "Dockerをsudoなしで使うには一度ログアウト→再ログインが必要です"
fi

# ── 6. プロジェクト依存インストール ──
step "プロジェクト依存関係のインストール"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Go
if [ -f "$SCRIPT_DIR/fileserver/main.go" ]; then
  cd "$SCRIPT_DIR/fileserver"
  /usr/local/go/bin/go mod tidy 2>/dev/null || true
  info "Go モジュール準備完了"
  cd "$SCRIPT_DIR"
fi

# Node.js
if [ -f "$SCRIPT_DIR/dashboard/package.json" ]; then
  cd "$SCRIPT_DIR/dashboard"
  npm install --silent
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
warn "変更を反映するため、ターミナルを再起動するか 'source ~/.bashrc' を実行してください"
