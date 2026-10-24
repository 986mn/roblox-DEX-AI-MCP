#!/usr/bin/env bash
# ============================================================
#  roblox-DEX-AI-MCP · Codespaces 健康检查
#
#  用途：修 Codespaces「从休眠唤醒后 postStart 不执行」的老问题。
#  可以手动跑，也可以挂到 cron / 每次开终端时触发。
#
#  用法：
#    bash .devcontainer/ensure-running.sh          # 检查并按需拉起
#    bash .devcontainer/ensure-running.sh --status # 只看状态
#    bash .devcontainer/ensure-running.sh --quiet  # 静默模式
# ============================================================
set -u

cd "$(dirname "$0")/.." || exit 1
ROOT="$(pwd)"
PORT=16384
LOG_DIR="$ROOT/logs"

MODE="${1:-}"

mkdir -p "$LOG_DIR"

# ---------- 探测服务是否活着 ----------
is_up() {
  curl -sf -m 3 -o /dev/null "http://127.0.0.1:${PORT}/api/status" 2>/dev/null
}

if [ "$MODE" = "--status" ]; then
  if is_up; then
    echo "服务运行中: http://127.0.0.1:${PORT}/"
    curl -sS -m 5 "http://127.0.0.1:${PORT}/api/status"
    echo
  else
    echo "服务未运行"
  fi
  exit 0
fi

if is_up; then
  [ "$MODE" = "--quiet" ] || echo "服务已在运行，无需处理"
  exit 0
fi

# ---------- 服务没起来，按需拉起 ----------
[ "$MODE" = "--quiet" ] || echo "服务未响应，开始拉起..."

# dist 缺失就先构建
if [ ! -f dist/index.js ]; then
  [ "$MODE" = "--quiet" ] || echo "  dist 缺失，先构建..."
  if [ ! -d node_modules ]; then
    npm install --ignore-scripts --no-package-lock --no-audit --no-fund >/dev/null 2>&1
  fi
  npm run build >/dev/null 2>&1
fi

if [ ! -f dist/index.js ]; then
  echo "✗ 构建失败，无法启动"
  exit 1
fi

# 清理旧实例
for f in /proc/[0-9]*/cmdline; do
  [ -r "$f" ] || continue
  pid="${f#/proc/}"; pid="${pid%/cmdline}"
  [ "$pid" = "$$" ] && continue
  case "$(tr '\0' ' ' < "$f" 2>/dev/null)" in
    *"dist/index.js"*) kill -9 "$pid" 2>/dev/null || true ;;
  esac
done

: > "$LOG_DIR/server.log"
nohup node dist/index.js > "$LOG_DIR/server.log" 2>&1 &
PID=$!
echo "$PID" > "$LOG_DIR/server.pid"

# 等待就绪
READY=0
for _ in $(seq 1 40); do
  if is_up; then READY=1; break; fi
  sleep 0.5
done

if [ "$READY" = "1" ]; then
  [ "$MODE" = "--quiet" ] || echo "✓ 服务已拉起 (PID $PID)"
  exit 0
else
  echo "✗ 启动失败，日志："
  tail -15 "$LOG_DIR/server.log" | sed 's/^/    /'
  exit 1
fi
