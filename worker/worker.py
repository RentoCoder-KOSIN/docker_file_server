"""
File Processing Worker
Go APIからファイル一覧を定期ポーリングし、新しいファイルを自動処理する。

処理内容:
  - PDF  → テキスト抽出 → .txt として保存
  - 画像 → サムネイル生成 (300x300) → _thumb.jpg として保存
  - その他 → ファイル情報をログ出力
"""

import os
import io
import time
import logging
import requests
from pathlib import Path

# ── サードパーティ（なければスキップ）──
try:
    import PyPDF2
    HAS_PDF = True
except ImportError:
    HAS_PDF = False

try:
    from PIL import Image
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

# ── 設定 ──
GO_API      = os.environ.get("GO_API_URL", "http://localhost:8080")
POLL_SEC    = int(os.environ.get("POLL_INTERVAL", "10"))   # ポーリング間隔(秒)
OUTPUT_DIR  = Path(os.environ.get("OUTPUT_DIR", "./processed"))

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("worker")


def fetch_file_list() -> list[dict]:
    """Go APIからファイル一覧を取得"""
    try:
        res = requests.get(f"{GO_API}/files", timeout=5)
        res.raise_for_status()
        return res.json() or []
    except requests.RequestException as e:
        log.warning(f"API接続失敗: {e}")
        return []


def download_file(name: str) -> bytes | None:
    """Go APIからファイルをダウンロード"""
    try:
        res = requests.get(f"{GO_API}/files/{name}", timeout=30)
        res.raise_for_status()
        return res.content
    except requests.RequestException as e:
        log.error(f"ダウンロード失敗 [{name}]: {e}")
        return None


def upload_file(name: str, data: bytes, content_type: str = "application/octet-stream"):
    """処理済みファイルをGo APIにアップロード"""
    try:
        res = requests.post(
            f"{GO_API}/upload",
            files={"file": (name, io.BytesIO(data), content_type)},
            timeout=30,
        )
        res.raise_for_status()
        log.info(f"  → アップロード完了: {name}")
    except requests.RequestException as e:
        log.error(f"  → アップロード失敗 [{name}]: {e}")


def process_pdf(name: str, data: bytes):
    """PDFからテキスト抽出"""
    if not HAS_PDF:
        log.info(f"  [PDF] PyPDF2 未インストール、スキップ: {name}")
        return

    try:
        reader = PyPDF2.PdfReader(io.BytesIO(data))
        pages  = [page.extract_text() or "" for page in reader.pages]
        text   = f"# {name}\n\n" + "\n\n--- Page Break ---\n\n".join(pages)
        out_name = Path(name).stem + "_extracted.txt"
        upload_file(out_name, text.encode("utf-8"), "text/plain")
        log.info(f"  [PDF] {len(reader.pages)}ページ → {out_name}")
    except Exception as e:
        log.error(f"  [PDF] 処理失敗: {e}")


def process_image(name: str, data: bytes):
    """画像サムネイル生成"""
    if not HAS_PIL:
        log.info(f"  [IMG] Pillow 未インストール、スキップ: {name}")
        return

    try:
        img = Image.open(io.BytesIO(data))
        img.thumbnail((300, 300), Image.LANCZOS)
        buf = io.BytesIO()
        img.save(buf, format="JPEG", quality=85)
        out_name = Path(name).stem + "_thumb.jpg"
        upload_file(out_name, buf.getvalue(), "image/jpeg")
        log.info(f"  [IMG] {img.size} → サムネイル {out_name}")
    except Exception as e:
        log.error(f"  [IMG] 処理失敗: {e}")


def process_file(name: str):
    """ファイルを種別判定して処理"""
    log.info(f"処理中: {name}")
    data = download_file(name)
    if data is None:
        return

    suffix = Path(name).suffix.lower()

    if suffix == ".pdf":
        process_pdf(name, data)
    elif suffix in {".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp"}:
        process_image(name, data)
    else:
        log.info(f"  [OTHER] {name} ({len(data):,} bytes) — 対応処理なし")


# ── メインループ ──
def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    seen: set[str] = set()   # 処理済みファイル名

    log.info("=" * 48)
    log.info(f"Worker 起動 (API: {GO_API}, interval: {POLL_SEC}s)")
    log.info(f"PDF抽出: {'✓' if HAS_PDF else '✗ (pip install PyPDF2)'}  "
             f"画像処理: {'✓' if HAS_PIL else '✗ (pip install Pillow)'}")
    log.info("=" * 48)

    while True:
        files = fetch_file_list()

        for f in files:
            name = f["name"]
            # サムネイルや抽出済みファイルは処理対象外
            if name.endswith(("_thumb.jpg", "_extracted.txt")):
                seen.add(name)
                continue
            if name not in seen:
                seen.add(name)
                process_file(name)

        time.sleep(POLL_SEC)


if __name__ == "__main__":
    main()
