# GitHub Codespaces 部署

容器里跑服务，Roblox 客户端在你自己设备上。两者通过 Codespaces 的**公网端口转发**连起来。

---

## 一键开始

点这个按钮：

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/986mn/roblox-DEX-AI-MCP)

或者在 GitHub 仓库页：**Code** → **Codespaces** → **Create codespace on main**

---

## 它会自动做什么

| 时机 | 动作 |
|---|---|
| **容器创建**（postCreate） | 给 connector.luau 打协议补丁 → 装依赖 → 编译 TS → 校验 DEX 层 |
| **每次启动**（postStart） | 清旧实例 → 拉起服务 → 等就绪 → 设端口 public → 启动保活 |

约 1-3 分钟。完成后终端会打印类似：

```
==========================================
 部署完成
==========================================
 仪表盘   : https://xxxxx-16384.app.github.dev/
 加载器   : https://xxxxx-16384.app.github.dev/script.luau
 状态接口 : https://xxxxx-16384.app.github.dev/api/status
==========================================
```

**记住你的 `https://<名字>-16384.app.github.dev` 地址**，下面要用。

---

## 连 Roblox

### 方式 A：直接上 DEX（推荐）

在 Roblox 执行器里：

```lua
getgenv().BridgeURL = "https://你的codespace名-16384.app.github.dev"
loadstring(game:HttpGet("https://raw.githubusercontent.com/986mn/roblox-DEX-AI-MCP/main/builds/dex_AC.lua"))()
```

执行后你会看到：

```
[DEX-MCP] 方案A 已注入 | version=mcp-A-1.0
[DEX-MCP] 方案C 已注入 | version=mcp-C-1.0
```

DEX 界面打开，右下角有 **[→ MCP]** 按钮。

### 方式 B：只要桥接，不要 DEX 界面

```lua
getgenv().BridgeURL = "https://你的codespace名-16384.app.github.dev"
loadstring(game:HttpGet(getgenv().BridgeURL .. "/script.luau"))()
```

### 验证连上了

浏览器打开：

```
https://你的codespace名-16384.app.github.dev/api/status
```

`clientCount` 从 `0` 变 `1` 就说明 Roblox 连上了。

---

## 为什么必须带 `https://`

Codespaces 的端口转发**只提供 HTTPS**，而原版 connector 把协议硬编码成了 `http://` 和 `ws://`。

`.devcontainer/patch-connector.mjs` 在容器创建时自动打补丁，让 `BridgeURL` 自动推导：

| 你填的 | 内部用的 |
|---|---|
| `https://xxx.app.github.dev` | HTTP → `https://`，WS → `wss://` |
| `http://localhost:16384` | HTTP → `http://`，WS → `ws://` |
| `xxx-16384.app.github.dev`（无协议） | 默认 http/ws（**Codespaces 上会失效**） |

**所以在 Codespaces 上，`getgenv().BridgeURL` 必须带 `https://` 前缀。**

---

## 端口必须 public

Roblox 客户端不是浏览器，没有你的 GitHub 登录态。端口如果是 private，它会收到登录页而不是你的服务。

- `devcontainer.json` 里已经设了 `"visibility": "public"`
- `start.sh` 也会尝试用 `gh` 自动设置
- 都失败的话，手动：**PORTS 面板** → 端口 `16384` → 右键 → **Port Visibility** → **Public**

---

## 常见问题

### 睡了 30 分钟醒来，服务没了

Codespaces 空闲会自动停。**唤醒后 `postStart` 不一定重跑**（GitHub 的已知行为）。

修法：

```bash
bash .devcontainer/ensure-running.sh
```

它会检测服务是否活着，没活就自动拉起。也可以随时查状态：

```bash
bash .devcontainer/ensure-running.sh --status
```

### Codespace 12 小时上限

免费额度有硬性上限，无法绕过。到时间需要重建（重建后 URL 会变，`BridgeURL` 也要更新）。

`keepalive.sh` 只能防空闲休眠，绕不过 12 小时限制。

### 端口还是 private

`gh` CLI 在容器里可能没有权限。手动去 PORTS 面板改，或者：

```bash
gh auth login
gh codespace ports visibility 16384:public -c "$CODESPACE_NAME"
```

### 想省额度

不用时及时停止：

```
https://github.com/codespaces
```

---

## 手动执行（不想用自动部署）

```bash
# 1. 打补丁 + 装依赖 + 编译
bash .devcontainer/setup.sh

# 2. 启动服务
bash .devcontainer/start.sh

# 3. 查状态
bash .devcontainer/ensure-running.sh --status
```

---

## 目录里都有什么

```
.devcontainer/
├── devcontainer.json      容器定义：端口转发、public 可见性、postCreate/postStart
├── setup.sh               创建时：打补丁 → 装依赖 → 编译 → 校验 DEX
├── start.sh               每次启动：拉服务 → 等就绪 → 设 public → 启保活
├── ensure-running.sh      健康检查：服务挂了就自动拉起（修休眠问题）
└── patch-connector.mjs    协议自适应补丁（http/https、ws/wss 自动推导）
```

---

## ⚠️ 安全

`public` 端口 = **任何拿到这个域名的人都能在你的 Roblox 会话里执行任意代码**。

域名虽然难猜，但这本质是靠隐蔽性当安全。

- 用完及时停 Codespace
- 不要把域名分享出去
- 不要 Fork 到公开仓库后一直开着

---

*全部由 deepseek-v4.1-flash 完成*