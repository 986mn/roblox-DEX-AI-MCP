#!/usr/bin/env bash
# ============================================================
#  roblox-DEX-AI-MCP · Codespaces postStart 脚本
#
#  每次容器启动（含从休眠唤醒）时执行：
#    清旧实例 → 确保编译 → 拉起服务 → 等就绪 → 端口 public
#    → 启动保活 → 打印连接信息
#
#  幂等，可重复执行。
# ============================================================
set -u

cd "$(dirname "$0")/.." || exit 1
ROOT="$(pwd)"
PORT=16384
LOG_DIR="$ROOT/logs"

export COREPACK_ENABLE_STRICT=0
mkdir -p "$LOG_DIR"

echo "=========================================="
echo " roblox-DEX-AI-MCP · 启动桥接服务"
echo "=========================================="

# ---------- 0. 前置：没有编译产物就先初始化 ----------
if [ ! -f dist/index.js ]; then
  echo "  ! 未发现 dist/index.js，先执行初始化..."
  bash .devcontainer/setup.sh || exit 1
fi

# ---------- 1. 清理旧实例（不依赖 pgrep/pkill） ----------
kill_stale() {
  local f pid cmd
  for f in /proc/[0-9]*/cmdline; do
    [ -r "$f" ] || continue
    pid="${f#/proc/}"; pid="${pid%/cmdline}"
    [ "$pid" = "$$" ] && continue
    cmd="$(tr '\0' ' ' < "$f" 2>/dev/null)"
    case "$cmd" in
      *"dist/index.js"*)
        echo "  停止旧实例 PID $pid"
        kill -9 "$pid" 2>/dev/null || true
        ;;
    esac
  done
}

kill_stale
for _ in $(seq 1 20); do
  still=0
  for f in /proc/[0-9]*/cmdline; do
    [ -r "$f" ] || continue
    case "$(tr '\0' ' ' < "$f" 2>/dev/null)" in *"dist/index.js"*) still=1 ;; esac
  done
  [ "$still" = "0" ] && break
  sleep 0.5
done

# ---------- 2. 启动服务 ----------
echo "  启动服务..."
: > "$LOG_DIR/server.log"
# MCP 是 stdio 协议：stdin 关闭会退出，所以用 /dev/zero 保持常开
nohup node dist/index.js < /dev/zero > "$LOG_DIR/server.log" 2>&1 &
PID=$!
echo "$PID" > "$LOG_DIR/server.pid"
echo "  PID=$PID"

# ---------- 3. 等就绪（最多 30 秒） ----------
READY=0
for _ in $(seq 1 60); do
  if curl -sf -m 2 -o /dev/null "http://127.0.0.1:${PORT}/api/status" 2>/dev/null; then
    READY=1
    break
  fi
  sleep 0.5
done

if [ "$READY" != "1" ]; then
  echo "  ✗ 服务未就绪，日志如下："
  tail -20 "$LOG_DIR/server.log" | sed 's/^/    /'
  exit 1
fi

echo "  ✓ 服务已就绪"
echo "  ---- 状态 ----"
curl -sS -m 5 "http://127.0.0.1:${PORT}/api/status" | sed 's/^/    /'
echo

# ---------- 4. 端口可见性（Roblox 客户端不带你登录态，必须 public） ----------
echo "  设置端口 ${PORT} 为 public..."
if command -v gh >/dev/null 2>&1 && [ -n "${CODESPACE_NAME:-}" ]; then
  if gh codespace ports visibility "${PORT}:public" -c "$CODESPACE_NAME" >/dev/null 2>&1; then
    echo "    ✓ 已设为 public"
  else
    echo "    ! 自动设置失败，请到 PORTS 面板手动设为 Public"
  fi
else
  echo "    ! 请到 PORTS 面板 → 端口 ${PORT} → 右键 → Port Visibility → Public"
fi

# ---------- 5. 保活（防空闲休眠） ----------
echo
echo "  启动保活进程（防止空闲休眠）..."
if [ -f "$ROOT/keepalive.sh" ]; then
  KEEPALIVE_INTERVAL="${KEEPALIVE_INTERVAL:-240}" bash "$ROOT/keepalive.sh" --daemon 2>/dev/null | sed 's/^/    /'
else
  echo "    ! 未找到 keepalive.sh，跳过"
fi

# ---------- 6. 连接信息 ----------
DOMAIN="${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
if [ -n "${CODESPACE_NAME:-}" ]; then
  BASE="https://${CODESPACE_NAME}-${PORT}.${DOMAIN}"
else
  BASE="http://localhost:${PORT}"
fi

echo
echo "=========================================="
echo " 部署完成"
echo "=========================================="
echo " 仪表盘   : ${BASE}/"
echo " 加载器   : ${BASE}/script.luau"
echo " 状态接口 : ${BASE}/api/status"
echo "=========================================="
echo " 在 Roblox 执行器里注入（BridgeURL 必须带 https://）："
echo "   getgenv().BridgeURL = \"${BASE}\""
echo "   loadstring(game:HttpGet(\"${BASE}/script.luau\"))()"
echo
echo " 或者直接用 DEX 整合包（自带 DEX 界面 + 桥接）："
echo "   getgenv().BridgeURL = \"${BASE}\""
echo "   loadstring(game:HttpGet(\"https://raw.githubusercontent.com/986mn/roblox-DEX-AI-MCP/main/builds/dex_AC.lua\"))()"
echo "=========================================="
echo " 健康检查 : bash .devcontainer/ensure-running.sh --status"
echo " 保活状态 : bash keepalive.sh --status"
echo " 停止保活 : bash keepalive.sh --stop"
echo "=========================================="