# 🌐 File Server Dashboard (Node.js)

GoのファイルサーバーAPIと繋がるWebダッシュボードです。

## セットアップ

```bash
npm install
npm start
```

ブラウザで `http://localhost:3000` を開くとダッシュボードが表示されます。

> **注意**: Goサーバー (`go run main.go`) が先に起動している必要があります。

---

## 起動順序

```bash
# ターミナル1: Goサーバー起動
cd ../fileserver
go run main.go

# ターミナル2: Dashboardを起動
cd ../dashboard
npm install
npm start
```

---

## 環境変数

| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `GO_API_URL` | `http://localhost:8080` | GoサーバーのURL |
| `PORT` | `3000` | ダッシュボードのポート番号 |

```bash
# 例: Goが別ホストにある場合
GO_API_URL=http://192.168.1.10:8080 npm start
```

---

## 機能

- **ファイル一覧** — ファイル名・サイズ・更新日時の表示
- **アップロード** — ドラッグ&ドロップ または クリックで選択（複数対応）
- **ダウンロード** — ワンクリックでダウンロード
- **削除** — 確認ダイアログ付き削除
- **自動更新** — 10秒ごとにファイル一覧を再取得
- **リアルタイム統計** — ファイル数・合計サイズの表示

## ディレクトリ構成

```
dashboard/
├── server.js         # Expressサーバー（GoへのProxyを含む）
├── package.json
├── README.md
└── public/
    └── index.html    # ダッシュボードUI（全部入り）
```
