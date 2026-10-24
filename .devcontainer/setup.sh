#!/usr/bin/env bash
# ============================================================
#  Roblox-MCP · Codespaces postCreate 脚本
#  容器首次创建时执行：打补丁 → 装依赖 → 编译
#  幂等，可重复执行。
# ============================================================
set -u

# 进入仓库根目录
cd "$(dirname "$0")/.." || exit 1
ROOT="$(pwd)"

# 避免 corepack 依据 packageManager 字段强制切换包管理器
export COREPACK_ENABLE_STRICT=0

echo "=========================================="
echo " roblox-DEX-AI-MCP · Codespaces 初始化"
echo " 仓库: $ROOT"
echo "=========================================="

# ---------- 1. 协议自适应补丁 ----------
echo
echo "[1/4] 应用协议自适应补丁"
if [ -f .devcontainer/patch-connector.mjs ]; then
  # 保留一份原始文件备份
  [ -f connector.luau.bak ] || cp connector.luau connector.luau.bak 2>/dev/null || true
  node .devcontainer/patch-connector.mjs "$ROOT/connector.luau" || {
    echo "  ✗ 补丁失败（服务仍可启动，但 Roblox 客户端可能连不上）"
  }
else
  echo "  ! 找不到 .devcontainer/patch-connector.mjs"
fi

# ---------- 2. 依赖 ----------
echo
echo "[2/4] 安装依赖"
if [ -d node_modules ] && [ -f node_modules/.package-lock.json ]; then
  echo "  node_modules 已存在，跳过"
else
  # --ignore-scripts：跳过 prepare 钩子（否则 install 会连带跑 build，失败会一起崩）
  # --no-package-lock：不生成 package-lock.json，避免与 pnpm-lock.yaml 冲突
  npm install --ignore-scripts --no-package-lock --no-audit --no-fund 2>&1 | tail -5
fi

# ---------- 3. 编译 ----------
echo
echo "[3/4] 编译 TypeScript"
npm run build 2>&1 | tail -5

if [ -f dist/index.js ]; then
  echo "  ✓ dist/index.js 已生成"
else
  echo "  ✗ 编译失败：dist/index.js 不存在"
  exit 1
fi

# ---------- 4. DEX 完整性检查 ----------
echo
echo "[4/4] 检查 DEX 构建产物"
DEX_OK=1
for f in dex.lua dex_mcp_A.lua dex_mcp_B.lua dex_mcp_C.lua; do
  if [ -f "$f" ]; then
    echo "  ✓ $f ($(wc -c < "$f") bytes)"
  else
    echo "  ✗ 缺少 $f"
    DEX_OK=0
  fi
done
for f in builds/dex_A.lua builds/dex_B.lua builds/dex_C.lua builds/dex_AC.lua; do
  if [ -f "$f" ]; then
    echo "  ✓ $f ($(wc -c < "$f") bytes)"
  else
    echo "  ✗ 缺少 $f"
    DEX_OK=0
  fi
done

if [ "$DEX_OK" = "1" ]; then
  echo "  DEX 层完整"
else
  echo "  ! DEX 层不完整 —— MCP 服务仍可运行，但无法直接注入 DEX"
fi

echo
echo "=========================================="
echo " 初始化完成"
echo "=========================================="
echo " MCP 服务  : http://localhost:16384/"
echo " DEX 整合包: builds/dex_AC.lua （推荐）"
echo "=========================================="