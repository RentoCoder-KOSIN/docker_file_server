package main

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"sync"
	"time"
)

const uploadDir = "./uploads"

// ── パスワード設定（環境変数 ADMIN_PASSWORD で上書き可）──
func adminPassword() string {
	if p := os.Getenv("ADMIN_PASSWORD"); p != "" {
		return p
	}
	return "admin1234" // デフォルトパスワード
}

// ── セッション管理 ──
type session struct {
	createdAt time.Time
}

var (
	sessions   = map[string]session{}
	sessionsMu sync.Mutex
)

func newToken() string {
	b := make([]byte, 32)
	rand.Read(b)
	return hex.EncodeToString(b)
}

func hashPassword(p string) string {
	h := sha256.Sum256([]byte(p))
	return hex.EncodeToString(h[:])
}

// トークンが有効か確認（24時間で失効）
func validToken(token string) bool {
	sessionsMu.Lock()
	defer sessionsMu.Unlock()
	s, ok := sessions[token]
	if !ok {
		return false
	}
	if time.Since(s.createdAt) > 24*time.Hour {
		delete(sessions, token)
		return false
	}
	return true
}

// ── 認証ミドルウェア ──
func requireAuth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		cookie, err := r.Cookie("session_token")
		if err != nil || !validToken(cookie.Value) {
			writeJSON(w, http.StatusUnauthorized, Response{Error: "ログインが必要です"})
			return
		}
		next(w, r)
	}
}

// ── 型定義 ──
type FileInfo struct {
	Name      string    `json:"name"`
	Size      int64     `json:"size"`
	UpdatedAt time.Time `json:"updated_at"`
}

type Response struct {
	Message string `json:"message,omitempty"`
	Error   string `json:"error,omitempty"`
}

// ── main ──
func main() {
	if err := os.MkdirAll(uploadDir, 0755); err != nil {
		log.Fatal("Failed to create upload directory:", err)
	}

	mux := http.NewServeMux()

	// 認証不要
	mux.HandleFunc("POST /login", loginHandler)
	mux.HandleFunc("POST /logout", logoutHandler)
	mux.HandleFunc("GET /auth/check", authCheckHandler)
	mux.HandleFunc("GET /files", listFilesHandler)
	mux.HandleFunc("GET /files/{name}", downloadHandler)

	// 認証必要
	mux.HandleFunc("POST /upload", requireAuth(uploadHandler))
	mux.HandleFunc("DELETE /files/{name}", requireAuth(deleteHandler))

	fmt.Println("🚀 File server running on http://localhost:8080")
	fmt.Println("  POST   /login          - ログイン")
	fmt.Println("  POST   /logout         - ログアウト")
	fmt.Println("  GET    /auth/check     - 認証状態確認")
	fmt.Println("  POST   /upload         - アップロード (要認証)")
	fmt.Println("  GET    /files          - ファイル一覧")
	fmt.Println("  GET    /files/{name}   - ダウンロード")
	fmt.Println("  DELETE /files/{name}   - 削除 (要認証)")

	log.Fatal(http.ListenAndServe(":8080", mux))
}

// POST /login
func loginHandler(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Error: "リクエスト不正"})
		return
	}

	if hashPassword(body.Password) != hashPassword(adminPassword()) {
		log.Printf("[LOGIN] 失敗 from %s", r.RemoteAddr)
		writeJSON(w, http.StatusUnauthorized, Response{Error: "パスワードが違います"})
		return
	}

	token := newToken()
	sessionsMu.Lock()
	sessions[token] = session{createdAt: time.Now()}
	sessionsMu.Unlock()

	http.SetCookie(w, &http.Cookie{
		Name:     "session_token",
		Value:    token,
		Path:     "/",
		HttpOnly: true,
		MaxAge:   86400,
		SameSite: http.SameSiteLaxMode,
	})

	log.Printf("[LOGIN] 成功 from %s", r.RemoteAddr)
	writeJSON(w, http.StatusOK, Response{Message: "ログイン成功"})
}

// POST /logout
func logoutHandler(w http.ResponseWriter, r *http.Request) {
	if cookie, err := r.Cookie("session_token"); err == nil {
		sessionsMu.Lock()
		delete(sessions, cookie.Value)
		sessionsMu.Unlock()
	}
	http.SetCookie(w, &http.Cookie{
		Name:   "session_token",
		Value:  "",
		Path:   "/",
		MaxAge: -1,
	})
	writeJSON(w, http.StatusOK, Response{Message: "ログアウトしました"})
}

// GET /auth/check
func authCheckHandler(w http.ResponseWriter, r *http.Request) {
	cookie, err := r.Cookie("session_token")
	if err != nil || !validToken(cookie.Value) {
		writeJSON(w, http.StatusUnauthorized, Response{Error: "未ログイン"})
		return
	}
	writeJSON(w, http.StatusOK, Response{Message: "認証済み"})
}

// POST /upload (要認証)
func uploadHandler(w http.ResponseWriter, r *http.Request) {
	r.ParseMultipartForm(32 << 20)
	file, header, err := r.FormFile("file")
	if err != nil {
		writeJSON(w, http.StatusBadRequest, Response{Error: "ファイルが見つかりません: " + err.Error()})
		return
	}
	defer file.Close()

	filename := filepath.Base(header.Filename)
	destPath := filepath.Join(uploadDir, filename)

	dest, err := os.Create(destPath)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Error: "ファイル作成失敗: " + err.Error()})
		return
	}
	defer dest.Close()

	if _, err := io.Copy(dest, file); err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Error: "ファイル保存失敗: " + err.Error()})
		return
	}

	log.Printf("[UPLOAD] %s (%d bytes)", filename, header.Size)
	writeJSON(w, http.StatusOK, Response{Message: fmt.Sprintf("'%s' をアップロードしました", filename)})
}

// GET /files
func listFilesHandler(w http.ResponseWriter, r *http.Request) {
	entries, err := os.ReadDir(uploadDir)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Error: "ディレクトリ読み込み失敗"})
		return
	}

	files := []FileInfo{}
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		info, err := entry.Info()
		if err != nil {
			continue
		}
		files = append(files, FileInfo{
			Name:      entry.Name(),
			Size:      info.Size(),
			UpdatedAt: info.ModTime(),
		})
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(files)
}

// GET /files/{name}
func downloadHandler(w http.ResponseWriter, r *http.Request) {
	name := r.PathValue("name")
	filePath := filepath.Join(uploadDir, filepath.Base(name))

	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		writeJSON(w, http.StatusNotFound, Response{Error: "ファイルが見つかりません"})
		return
	}

	log.Printf("[DOWNLOAD] %s", name)
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=%q", name))
	http.ServeFile(w, r, filePath)
}

// DELETE /files/{name} (要認証)
func deleteHandler(w http.ResponseWriter, r *http.Request) {
	name := r.PathValue("name")
	filePath := filepath.Join(uploadDir, filepath.Base(name))

	if err := os.Remove(filePath); os.IsNotExist(err) {
		writeJSON(w, http.StatusNotFound, Response{Error: "ファイルが見つかりません"})
		return
	} else if err != nil {
		writeJSON(w, http.StatusInternalServerError, Response{Error: "削除失敗: " + err.Error()})
		return
	}

	log.Printf("[DELETE] %s", name)
	writeJSON(w, http.StatusOK, Response{Message: fmt.Sprintf("'%s' を削除しました", name)})
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}
