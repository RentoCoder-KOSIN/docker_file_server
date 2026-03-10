# 📁 Go File Server

Python・Go・JSを組み合わせたファイル管理サーバーの **Goバックエンド** です。

## セットアップ

```bash
# Go 1.22以上が必要
go run main.go
```

サーバーが `http://localhost:8080` で起動します。

---

## API エンドポイント

### ファイルアップロード
```bash
POST /upload
Content-Type: multipart/form-data

curl -X POST http://localhost:8080/upload \
  -F "file=@/path/to/yourfile.txt"
```

### ファイル一覧取得
```bash
GET /files

curl http://localhost:8080/files
# → [{"name":"yourfile.txt","size":1234,"updated_at":"2024-..."}]
```

### ファイルダウンロード
```bash
GET /files/{name}

curl -O http://localhost:8080/files/yourfile.txt
```

### ファイル削除
```bash
DELETE /files/{name}

curl -X DELETE http://localhost:8080/files/yourfile.txt
```

---

## 次のステップ

| 言語 | 追加する機能 |
|------|------------|
| **Python** | ファイル変換・テキスト抽出・データ解析 |
| **Node.js** | Webダッシュボード・ファイル一覧UI |

## ディレクトリ構成

```
fileserver/
├── main.go       # メインサーバー
├── go.mod        # モジュール定義
├── README.md     # このファイル
└── uploads/      # アップロードされたファイルが保存される（自動作成）
```
