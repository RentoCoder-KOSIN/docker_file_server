const express = require("express");
const { createProxyMiddleware } = require("http-proxy-middleware");
const path = require("path");
const os = require("os");

const app = express();
const PORT = process.env.PORT || 3000;
const GO_API = process.env.GO_API_URL || "http://localhost:8080";

// ローカルIPアドレス取得（Dockerの仮想NICを除外）
function getLocalIP() {
  const interfaces = os.networkInterfaces();
  for (const name of Object.keys(interfaces)) {
    // Docker仮想NIC(docker0, br-xxxx, eth*)は除外、物理/Wi-Fi系を優先
    if (name.startsWith("br-") || name === "docker0") continue;
    for (const iface of interfaces[name]) {
      if (iface.family === "IPv4" && !iface.internal) {
        // 172.x.x.x (Dockerブリッジ帯域) は除外
        if (iface.address.startsWith("172.")) continue;
        return iface.address;
      }
    }
  }
  return "localhost";
}

// 静的ファイル配信
app.use(express.static(path.join(__dirname, "public")));

// GoのAPIにプロキシ（/api/* → Go :8080/*）
app.use(
  "/api",
  createProxyMiddleware({
    target: GO_API,
    changeOrigin: true,
    pathRewrite: { "^/api": "" },
    on: {
      error: (err, req, res) => {
        console.error("Proxy error:", err.message);
        res.status(502).json({ error: "GoサーバーへのProxy失敗。Go serverが起動しているか確認してください。" });
      },
    },
  })
);

app.listen(PORT, "0.0.0.0", () => {
  const localIP = getLocalIP();
  console.log(`🌐 Dashboard running!`);
  console.log(`   ローカル:       http://localhost:${PORT}`);
  console.log(`   他デバイスから: http://${localIP}:${PORT}`);
  console.log(`   → GoAPI proxy: ${GO_API}`);
});
