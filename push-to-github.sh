#!/usr/bin/env bash
# ============================================================
#  创建 GitHub 仓库 roblox-AI-mcp 并推送
#
#  用法：
#    GITHUB_TOKEN=ghp_xxx bash push-to-github.sh [owner] [repo]
#
#  默认：owner=986mn  repo=roblox-AI-mcp
#
#  Token 需要权限：repo（Contents: Read and write）
#  创建仓库还需要：Administration: Read and write 或 repo 完整权限
# ============================================================
set -u

TOKEN="${GITHUB_TOKEN:-}"
OWNER="${1:-986mn}"
REPO="${2:-roblox-AI-mcp}"
BASE="/home/roblox-AI-mcp"

if [ -z "$TOKEN" ]; then
  echo "✗ 缺少 GITHUB_TOKEN"
  echo "  用法: GITHUB_TOKEN=ghp_xxx bash push-to-github.sh"
  exit 1
fi

mask() { sed "s|${TOKEN}|***|g"; }
say() { printf '\033[1;36m[push]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[push!]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[push!]\033[0m %s\n' "$*"; exit 1; }

say "目标: ${OWNER}/${REPO}"
cd "$BASE" || die "无法进入 $BASE"

# ---------- 1. 验证 token ----------
say "[1/5] 验证 token"
USER_JSON="$(curl -sS -m 20 -H "Authorization: Bearer ${TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/user 2>&1)"

LOGIN="$(printf '%s' "$USER_JSON" | node -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
  try{const j=JSON.parse(s);console.log(j.login||"")}catch(e){console.log("")}
});')"

if [ -z "$LOGIN" ]; then
  warn "token 无效或已过期"
  printf '%s\n' "$USER_JSON" | mask | head -5 | sed 's/^/    /'
  exit 1
fi
say "  已认证为: ${LOGIN}"

# ---------- 2. 创建仓库（已存在则跳过） ----------
say "[2/5] 创建仓库 ${OWNER}/${REPO}"
CHECK="$(curl -sS -m 20 -o /dev/null -w '%{http_code}' \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${OWNER}/${REPO}")"

if [ "$CHECK" = "200" ]; then
  say "  仓库已存在，直接推送"
elif [ "$CHECK" = "404" ]; then
  say "  仓库不存在，正在创建..."
  CREATE_BODY="$(node -e '
const repo=process.argv[1];
console.log(JSON.stringify({
  name: repo,
  description: "Roblox Executor MCP + DEX bidirectional bridge. AI can read what you select in DEX, and drive DEX selection from the other side.",
  private: false,
  has_issues: true,
  has_wiki: false,
  has_projects: false,
  license_template: "mit"
}));' "$REPO")"

  RESP="$(curl -sS -m 30 -X POST \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "Content-Type: application/json" \
    -d "$CREATE_BODY" \
    "https://api.github.com/user/repos" 2>&1)"

  NEW_URL="$(printf '%s' "$RESP" | node -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
  try{const j=JSON.parse(s);console.log(j.html_url||"")}catch(e){console.log("")}
});')"

  if [ -z "$NEW_URL" ]; then
    warn "  创建失败："
    printf '%s\n' "$RESP" | mask | head -10 | sed 's/^/    /'
    exit 1
  fi
  say "  创建成功: ${NEW_URL}"
else
  die "  无法检查仓库状态（HTTP ${CHECK}），token 权限可能不足"
fi

# ---------- 3. 配置 remote ----------
say "[3/5] 配置 remote"
git remote remove origin 2>/dev/null || true
git remote add origin "https://${TOKEN}@github.com/${OWNER}/${REPO}.git"
git remote -v | mask | sed 's/^/  /'

# ---------- 4. 推送 ----------
say "[4/5] 推送 main"
git push -u origin main 2>&1 | mask | sed 's/^/  /'
PUSH_RC=${PIPESTATUS[0]}

if [ "$PUSH_RC" != "0" ]; then
  die "  推送失败"
fi
say "  推送成功"

# ---------- 5. 清理凭据 ----------
say "[5/5] 清理凭据"
git remote set-url origin "https://github.com/${OWNER}/${REPO}.git"
say "  remote 已改为无 token 形式"

echo
echo "============================================"
echo " 完成"
echo "============================================"
echo " 仓库   : https://github.com/${OWNER}/${REPO}"
echo " 克隆   : git clone https://github.com/${OWNER}/${REPO}.git"
echo " Codespaces: https://github.com/codespaces/new?repo=${OWNER}/${REPO}"
echo "============================================"
