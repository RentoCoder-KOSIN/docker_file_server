# ⚙️ セットアップガイド

## Chromebook (Linux)

```bash
chmod +x setup.sh
./setup.sh
```

インストールされるもの: Go 1.22 / Node.js 20 / Python 3 / Docker

---

## Windows

PowerShell を**管理者として**開いて実行：

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
.\setup.ps1
```

インストールされるもの: Go / Node.js LTS / Python 3.12 / Docker Desktop

> Docker Desktop は起動後に WSL2 の有効化を求められる場合があります。

---

## インストール後の起動

```bash
# Chromebook
docker compose up --build

# Windows (PowerShell)
docker compose up --build
```

→ http://localhost:3000
