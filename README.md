# roblox-AI-mcp

**Roblox Executor MCP + DEX 双向桥接**

一个 Model Context Protocol (MCP) 服务器，让 AI 直接与运行中的 Roblox 客户端交互；并在此基础上集成 [DEX](https://github.com/LorekeeperZinnia/Dex) 调试器，实现「你在 DEX 里点什么，AI 就知道」的双向联动。

---

## 这是什么

本项目基于 [notpoiu/roblox-executor-mcp](https://github.com/notpoiu/roblox-executor-mcp)（上游已 404），并做了两层扩展：

| 层 | 内容 |
|---|---|
| **基础层** | 原版 Roblox Executor MCP 的全部能力（执行 Luau、反编译、Remote Spy、GUI 自动化等） |
| **DEX 层**（本 fork 新增） | DEX 三套桥接方案 + 服务端 `/dex/*` 路由 + 3 个 MCP 工具 |

---

## 核心能力

### 基础工具（26 个）

| 类别 | 工具 |
|---|---|
| **客户端管理** | `list-clients`、`set-active-client` |
| **执行** | `execute`、`execute-file`、`get-data-by-code`、`teleport-player`、`set-player-property` |
| **检查与搜索** | `get-script-content`、`get-console-output`、`search-instances`、`get-descendants-tree`、`get-instance-properties`、`get-game-info`、`get-executor-environment`、`script-grep`、`semantic-search-scripts` |
| **Remote 网络** | `ensure-remote-spy`、`get-remote-spy-logs`、`clear-remote-spy-logs`、`block-remote`、`ignore-remote`、`fire-remote` |
| **GUI** | `click-button`、`type-text-box` |
| **Windows** | `list-roblox-windows`、`screenshot-window` |

### DEX 工具（3 个，本 fork 新增）

| 工具 | 作用 |
|---|---|
| **`dex-events`** | 读取你在 DEX 里点选的对象路径（你点按钮 → AI 收到） |
| **`dex-select`** | 让 AI 在 DEX 里选中对象（AI → 你的 DEX 界面同步跳转） |
| **`dex-snapshot`** | 读取 DEX 当前完整状态（选中了什么、有哪些面板、队列长度） |

### DEX 服务端路由（新增）

| 路由 | 作用 |
|---|---|
| `POST /dex/event` | 接收 DEX 推送的选中事件（返回 204） |
| `GET /dex/event` | 查看最新事件与统计 |
| `GET /dex/events?since=N` | 拉取事件列表，支持增量 |
| `DELETE /dex/events` | 清空事件缓冲 |

---

## 目录结构

```
roblox-AI-mcp/
├── src/
│   ├── http/
│   │   ├── dex-store.ts              ← 新增：DEX 事件存储
│   │   └── routes/dex/
│   │       ├── event.ts              ← 新增：POST/GET /dex/event
│   │       └── events.ts             ← 新增：GET/DELETE /dex/events
│   └── tools/impl/dex/               ← 新增
│       ├── dex-events.ts
│       ├── dex-select.ts
│       └── dex-snapshot.ts
├── dex-mcp/                          ← 新增：DEX 三套桥接方案
│   ├── dex_mcp_A.lua                 方案 A：追加式完整 API
│   ├── dex_mcp_B.lua                 方案 B：适配层（不改 dex.lua）
│   ├── dex_mcp_C.lua                 方案 C：带按钮 UI
│   └── DEX_README.md                 详细文档
├── connector.luau                    已打协议自适应补丁
├── .devcontainer/                    Codespaces 自动部署
└── docs/
```

---

## 快速开始

### 1. 安装依赖并构建

```bash
npm install --ignore-scripts --no-package-lock
npm run build
```

> `--ignore-scripts` 必须加，否则 `prepare` 钩子会连带触发 build 导致失败。

### 2. 启动服务

```bash
node dist/index.js < /dev/zero
```

> MCP 是 stdio 协议，**stdin 关闭服务就会退出**。所以用 `< /dev/zero` 保持 stdin 常开。

服务启动后监听 `16384`：

```
MCP Server started and connected via stdio.
[Router] Loaded 34 HTTP route(s), 1 WS route(s) + WS fallback.
[Primary] MCP Bridge listening on port 16384 (WebSocket + HTTP)
```

### 3. 注入 Roblox 加载器

在 Roblox 执行器里：

```lua
getgenv().BridgeURL = "localhost:16384"          -- 本地
-- getgenv().BridgeURL = "192.168.1.100:16384"   -- 局域网
-- getgenv().BridgeURL = "https://xxx-16384.app.github.dev"  -- Codespaces

loadstring(game:HttpGet("http://" .. getgenv().BridgeURL .. "/script.luau"))()
```

> 加载器支持 `https://` 前缀，会自动转成 `wss://`（协议补丁已内置）。

### 4. 加载 DEX 桥接

把 `dex-mcp/dex_mcp_A.lua` 的内容**追加**到 `dex.lua` 最后一行（`Main.Init()`）之后。

或者在执行器里独立加载（方案 B，不改原文件）：

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/986mn/wg/main/dex_mcp_B.lua"))()
```

### 5. 在 AI 客户端配置 MCP

```json
{
  "mcpServers": {
    "roblox-ai-mcp": {
      "command": "node",
      "args": ["/path/to/roblox-AI-mcp/dist/index.js"]
    }
  }
}
```

---

## DEX 三套方案

| | 改动方式 | 能力 | 适用场景 |
|---|---|---|---|
| **A** | 追加到 dex.lua 末尾 | 完整读写 API | 想永久集成 |
| **B** | 独立文件，运行时拼接 | 完整读写 API | 想保持 dex.lua 原版 |
| **C** | 追加到 dex.lua 末尾 | 按钮 UI + 队列 | 想手动控制 |

**推荐 A + C 一起装**（实测可共存，A 选中后 C 的角标会同步）。

详细用法见 [`dex-mcp/DEX_README.md`](dex-mcp/DEX_README.md)。

---

## 完整工作流示例

```
你：在 DEX 里点中 workspace.Map.NPC
    ↓ 点【→ MCP】按钮
AI：调用 dex-events → 收到 ["game.Workspace.Map.NPC"]
    ↓ 调用 get-instance-properties
AI：知道这是 Model，有 Humanoid，Health=100
    ↓ 调用 dex-select
你的 DEX：界面自动跳到该对象，属性面板展开
    ↓ AI 调用 execute
AI：Health 改成 0
```

---

## Codespaces 部署

`.devcontainer/` 已配置好自动部署：

- `postCreateCommand`：安装依赖 + 打协议补丁 + 编译
- `postStartCommand`：启动服务 + 设端口 public + 启动保活
- `forwardPorts: [16384]`，`visibility: public`

创建 Codespace 后等 1-3 分钟，然后访问：

```
https://<codespace-name>-16384.app.github.dev/
```

加载器用：

```lua
getgenv().BridgeURL = "https://<codespace-name>-16384.app.github.dev"
loadstring(game:HttpGet(getgenv().BridgeURL .. "/script.luau"))()
```

---

## 已知限制

1. **`screenshot-window` / `list-roblox-windows` 仅 Windows** — 在 Codespaces（Linux 容器）里无效
2. **nil 实例路径无法解析回去** — DEX 对无父对象会输出 `getNil(...)` 代码片段，不是可解析表达式
3. **反编译依赖执行器** — 需要执行器提供 `decompile`，否则回退到 `.Source`（通常为空）
4. **Codespaces 12 小时上限** — 无法绕过，到点需重建
5. **DEX 用了 Luau 专有语法** — `continue`、`..=`，只能在 Roblox 执行器里跑

---

## ⚠️ 安全

**端口 16384 无任何认证。**

- 本服务允许**任意代码执行**
- 只连接可信的 AI 客户端
- **绝不要**把端口暴露到公网
- 跨机使用请走 VPN 或 SSH 隧道：
  ```bash
  ssh -L 16384:localhost:16384 user@target-machine
  ```

Codespaces 的 `public` 端口意味着**任何拿到域名的人**都能在你的 Roblox 会话里跑代码。域名虽然难猜，但这是靠隐蔽性当安全。用完请及时停止 Codespace。

---

## 来源与致谢

- 上游：[notpoiu/roblox-executor-mcp](https://github.com/notpoiu/roblox-executor-mcp)（已 404）
- 中间 fork：[Potato5466794/Roblox-MCP](https://github.com/Potato5466794/Roblox-MCP)
- DEX：[LorekeeperZinnia/Dex](https://github.com/LorekeeperZinnia/Dex)（作者 Moon）
- Remote Spy：[notpoiu/cobalt](https://github.com/notpoiu/cobalt)

---

## License

MIT