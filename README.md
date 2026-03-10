# 📦 File Server — Go + Node.js + Python

3言語で構成されたファイル管理システムです。

```
┌─────────────────────────────────────────────────┐
│  Browser  →  Dashboard (Node.js :3000)           │
│                  ↓ proxy /api/*                  │
│           File API (Go :8080)                    │
│                  ↑ polling                       │
│           Worker (Python)                        │
└─────────────────────────────────────────────────┘
```

| サービス | 言語 | 役割 |
|---------|------|------|
| `fileserver` | Go | ファイルのCRUD API |
| `dashboard` | Node.js | WebUI・APIプロキシ |
| `worker` | Python | PDF抽出・サムネイル生成 |

---

## 🚀 起動（Docker推奨）

```bash
# ビルド & 起動
docker compose up --build

# バックグラウンド起動
docker compose up --build -d
```

ブラウザで **http://localhost:3000** を開く。

ログ確認：
```bash
docker compose logs -f
docker compose logs -f worker   # Pythonワーカーのみ
```

停止：
```bash
docker compose down
```

データを消す場合：
```bash
docker compose down -v   # ボリュームも削除
```

---

## 🛠 ローカル起動（Dockerなし）

```bash
# ターミナル1: Go
cd fileserver && go run main.go

# ターミナル2: Node.js
cd dashboard && npm install && npm start

# ターミナル3: Python
cd worker && pip install -r requirements.txt && python worker.py
```

---

## 📁 ディレクトリ構成

```
.
├── docker-compose.yml
├── fileserver/          # Go API
│   ├── main.go
│   ├── go.mod
│   └── Dockerfile
├── dashboard/           # Node.js + WebUI
│   ├── server.js
│   ├── public/index.html
│   ├── package.json
│   └── Dockerfile
└── worker/              # Python処理ワーカー
    ├── worker.py
    ├── requirements.txt
    └── Dockerfile
```

---

## ⚙️ 環境変数

| 変数 | デフォルト | サービス |
|------|-----------|---------|
| `GO_API_URL` | `http://localhost:8080` | dashboard, worker |
| `POLL_INTERVAL` | `10` (秒) | worker |

---

## 🔌 API エンドポイント (Go)

| Method | Path | 説明 |
|--------|------|------|
| `POST` | `/upload` | ファイルアップロード |
| `GET` | `/files` | ファイル一覧 |
| `GET` | `/files/{name}` | ダウンロード |
| `DELETE` | `/files/{name}` | 削除 |
