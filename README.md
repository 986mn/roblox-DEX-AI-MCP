# roblox-AI-mcp

> **Roblox Executor MCP + DEX 双向桥接**
>
> 让 AI 知道你在 DEX 里点了什么，也让 AI 能在 DEX 里替你点。

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Node](https://img.shields.io/badge/node-%E2%89%A518-brightgreen.svg)](https://nodejs.org)
[![MCP](https://img.shields.io/badge/MCP-29%20tools-purple.svg)](https://modelcontextprotocol.io)

---

## 一句话说明

原版 Roblox Executor MCP 只能「AI → 游戏」单向操作。
本项目加了 **DEX 桥接层**，把它变成**双向**：

```
你在 DEX 点选对象  →  AI 立刻知道是哪个对象
AI 决定操作        →  你的 DEX 界面自动跳转并高亮
```

---

## 目录

- [快速开始](#快速开始)
- [DEX 三种用法](#dex-三种用法)
- [完整工作流](#完整工作流)
- [MCP 工具清单](#mcp-工具清单)
- [HTTP 路由](#http-路由)
- [项目结构](#项目结构)
- [Codespaces 部署](#codespaces-部署)
- [已知限制](#已知限制)
- [安全](#安全)

---

## 快速开始

### 1. 构建服务端

```bash
git clone https://github.com/986mn/roblox-AI-mcp.git
cd roblox-AI-mcp
npm install --ignore-scripts --no-package-lock
npm run build
```

> `--ignore-scripts` 不能省。`package.json` 里的 `prepare` 钩子会连带触发 build，一旦失败整个 install 都会报 `ELIFECYCLE`。

### 2. 启动

```bash
node dist/index.js < /dev/zero
```

> MCP 走 stdio，**stdin 一关服务就退出**。`< /dev/zero` 用来保持 stdin 常开。

启动成功的标志：

```
MCP Server started and connected via stdio.
[Router] Loaded 34 HTTP route(s), 1 WS route(s) + WS fallback.
[Primary] MCP Bridge listening on port 16384 (WebSocket + HTTP)
```

### 3. 注入 Roblox 加载器

在 Roblox 执行器里：

```lua
getgenv().BridgeURL = "localhost:16384"                     -- 本机
-- getgenv().BridgeURL = "192.168.1.100:16384"             -- 局域网
-- getgenv().BridgeURL = "https://xxx-16384.app.github.dev" -- Codespaces

loadstring(game:HttpGet("http://" .. getgenv().BridgeURL .. "/script.luau"))()
```

`connector.luau` 已内置协议自适应补丁，`https://` 会自动转 `wss://`。

### 4. 加载 DEX（三选一，见下节）

### 5. 配置 AI 客户端

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

## DEX 三种用法

### 方式一：直接用完整版 ⭐ 最省事

仓库 `dex-full/` 里是**已拼接好的完整 dex.lua**，直接运行即可，不用改任何东西。

| 文件 | 大小 | 内容 |
|---|---|---|
| `dex-full/dex_AC.lua` | 510 KB | 原版 DEX + 读写 API + 按钮 UI（**推荐**） |
| `dex-full/dex_A.lua` | 494 KB | 原版 DEX + 读写 API |
| `dex-full/dex_C.lua` | 493 KB | 原版 DEX + 按钮 UI |

```lua
-- 直接加载，零配置
loadstring(game:HttpGet("https://raw.githubusercontent.com/986mn/roblox-AI-mcp/main/dex-full/dex_AC.lua"))()
```

### 方式二：用补丁（保持 dex.lua 原版）

`dex-mcp/` 里是纯补丁，追加到你自己 dex.lua 的最后一行（`Main.Init()`）之后：

| 文件 | 追加到 dex.lua 末尾 |
|---|---|
| `dex-mcp/dex_mcp_A.lua` | 完整读写 API |
| `dex-mcp/dex_mcp_B.lua` | 独立运行，**不用改 dex.lua** |
| `dex-mcp/dex_mcp_C.lua` | 按钮 UI |

**方案 B 的用法**（最灵活，可换任意 DEX 源，含汉化版）：

```lua
getgenv().DEX_URL = "https://raw.githubusercontent.com/986mn/wg/main/dex.lua"
loadstring(game:HttpGet("https://raw.githubusercontent.com/986mn/roblox-AI-mcp/main/dex-mcp/dex_mcp_B.lua"))()
```

### 方式三：自己拼

```bash
cat dex.lua dex-mcp/dex_mcp_A.lua > dex_custom.lua
```

### 三种版本对比

| | 改动方式 | API | 按钮 UI | 适用 |
|---|---|---|---|---|
| **dex-full/dex_AC.lua** | 无（已拼好） | ✅ | ✅ | **大多数情况** |
| **dex-full/dex_A.lua** | 无（已拼好） | ✅ | ❌ | 只要 API |
| **dex-full/dex_C.lua** | 无（已拼好） | 只读 | ✅ | 只要按钮 |
| **dex_mcp_A.lua** | 追加 | ✅ | ❌ | 想自己拼 |
| **dex_mcp_B.lua** | 独立文件 | ✅ | ❌ | 想保持原版 |
| **dex_mcp_C.lua** | 追加 | 只读 | ✅ | 想自己拼 |

---

## 完整工作流

```
① 你在 DEX 里点中 workspace.Map.NPC
   ↓ 点【→ MCP】按钮（或 Ctrl+Shift+M）
② AI 调用 dex-events 工具
   → 收到 ["game.Workspace.Map.NPC"]
③ AI 调用 get-instance-properties
   → 知道这是 Model，有 Humanoid，Health=100
④ AI 调用 dex-select
   → 你的 DEX 界面自动跳到该对象，属性面板展开
⑤ AI 调用 execute
   → Health 改成 0
```

### 反向也通

```lua
-- AI 说「帮你选中所有 NPC」
getgenv().DEX.Select({
    "game.Workspace.Map.NPC",
    "game.Workspace.Map.NPC2",
}, true)
-- 你的 DEX 界面同步高亮这两个
```

---

## DEX API 参考

### 读写 API（A / AC 版本）

```lua
local D = getgenv().DEX

-- 读
D.Snapshot()                          -- 当前选中快照（含路径、类名、位置、血量）
D.Tree("game.Workspace", 3, 200)      -- 实例树（深度, 上限）
D.Props("game.Workspace.NPC")         -- 属性 + Attributes + CollectionService 标签
D.Source("game.ReplicatedStorage.X")  -- 反编译源码
D.Info(node)                          -- 单个节点信息
D.Resolve("game.Workspace.NPC")       -- 路径 → Instance

-- 写
D.Select({"game.Workspace.NPC"})          -- 设置选中
D.Select({p1, p2}, true)                  -- 追加选中
D.SetProp(path, "Health", "0")            -- 改属性
D.SetProp(path, "CFrame", "lua:CFrame.new(0,50,0)")  -- lua: 前缀求值
D.Run("return 1+1")                       -- 执行 Luau
D.App("Explorer", true)                   -- 开面板
D.App("Explorer", false)                  -- 关面板
D.Refresh()                               -- 刷新界面

-- 队列
D.PushPending("reason")               -- 当前选中入队
D.TakePending()                       -- 取走并清空

-- 原生模块直通（高级）
D.Main / D.Apps / D.Explorer / D.Properties / D.ScriptViewer / D.Console
D.nodes / D.selection / D.env / D.API / D.RMD / D.Lib
```

### 队列 API（C / AC 版本）

```lua
local Q = getgenv().DEX_QUEUE

Q.Take()          -- 取走队列并清空
Q.Peek()          -- 只看不清空
Q.Send("reason")  -- 手动发送当前选中
Q.Selected()      -- 当前选中的路径数组
Q.Count()         -- 队列长度
Q.Button()        -- 重建按钮
Q.Select(paths)   -- 选中（C 版本也支持）
```

### 路径格式

全部支持：

```lua
game.Workspace.Map.NPC                          -- 普通
Workspace.Map.NPC                               -- 省略 game 前缀
game:GetService("ReplicatedStorage").Mods       -- 服务
game.Workspace:GetChildren()[3]                 -- 重名索引
game.Workspace["奇怪 名字"]                      -- 特殊字符
```

### 按钮操作（C / AC 版本）

| 操作 | 效果 |
|---|---|
| 左键点【→ MCP】 | 发送当前选中，按钮变 `✓ N` |
| 右键点按钮 | 打印队列 + 全部复制到剪贴板 |
| 拖动按钮 | 移动位置 |
| 右键对象 → 发送到 MCP | 同上（资源管理器右键菜单） |
| Ctrl + Shift + M | 同上（快捷键） |

---

## MCP 工具清单

### DEX 工具（3 个，本项目新增）

| 工具 | 作用 |
|---|---|
| **`dex-events`** | 读取你在 DEX 里点选的对象路径，支持 `since` 增量、`clear` 清空 |
| **`dex-select`** | 让 AI 在 DEX 里选中对象，支持多选、`additive` 追加 |
| **`dex-snapshot`** | 读 DEX 实时状态（选中了什么、有哪些面板、队列长度） |

### 基础工具（26 个）

| 类别 | 工具 |
|---|---|
| **客户端** | `list-clients`、`set-active-client` |
| **执行** | `execute`、`execute-file`、`get-data-by-code`、`teleport-player`、`set-player-property` |
| **检查** | `get-script-content`、`get-console-output`、`search-instances`、`get-descendants-tree`、`get-instance-properties`、`get-game-info`、`get-executor-environment` |
| **搜索** | `script-grep`、`semantic-search-scripts` |
| **Remote** | `ensure-remote-spy`、`get-remote-spy-logs`、`clear-remote-spy-logs`、`block-remote`、`ignore-remote`、`fire-remote` |
| **GUI** | `click-button`、`type-text-box` |
| **Windows** | `list-roblox-windows`、`screenshot-window` |

**合计 29 个工具。**

---

## HTTP 路由

### DEX 路由（新增）

| 路由 | 说明 |
|---|---|
| `POST /dex/event` | 接收 DEX 推送的选中事件 → **204** |
| `GET /dex/event` | 查看最新事件与统计 |
| `GET /dex/events?since=N` | 拉取事件列表（增量） |
| `DELETE /dex/events` | 清空事件缓冲 |

推送 body 格式：

```json
{
  "type": "selection",
  "reason": "button",
  "time": "12:00:00",
  "paths": ["game.Workspace.Map.NPC"]
}
```

### 原版路由

```
GET  /                       仪表盘（Console / Executor / Tools / Scripts）
GET  /script.luau            加载器
GET  /api/status             状态
GET  /api/tools              工具目录
POST /api/tool               执行工具
GET  /api/scripts            脚本列表
GET  /api/client-logs        客户端日志
GET  /api/screenshot         截图
POST /register               客户端注册
GET  /poll                   HTTP 轮询
POST /respond                响应
GET  /script-sources         脚本源
WS   /mcp-relay              主从中继
```

---

## 项目结构

```
roblox-AI-mcp/
├── dex-full/                    ⭐ 已拼接的完整版（直接用）
│   ├── dex_AC.lua               原版 DEX + API + 按钮（510 KB）
│   ├── dex_A.lua                原版 DEX + API（494 KB）
│   └── dex_C.lua                原版 DEX + 按钮（493 KB）
├── dex-mcp/                     纯补丁（自己拼）
│   ├── dex_mcp_A.lua
│   ├── dex_mcp_B.lua
│   ├── dex_mcp_C.lua
│   └── DEX_README.md
├── src/
│   ├── http/
│   │   ├── dex-store.ts         DEX 事件存储（200 条环形缓冲）
│   │   └── routes/dex/
│   │       ├── event.ts         POST/GET /dex/event
│   │       └── events.ts        GET/DELETE /dex/events
│   ├── tools/impl/dex/
│   │   ├── dex-events.ts
│   │   ├── dex-select.ts
│   │   └── dex-snapshot.ts
│   ├── bridge/                  主从中继、客户端注册
│   ├── http/                    路由、仪表盘
│   └── semantic/                向量搜索（Ollama）
├── connector.luau               注入客户端的 Luau（已打协议补丁）
├── .devcontainer/               Codespaces 自动部署
├── keepalive.sh                 防休眠 + 服务自愈
├── push-to-github.sh            一键推送（自动建仓库）
└── docs/                        各客户端配置指南
```

---

## Codespaces 部署

`.devcontainer/` 已配好，创建 Codespace 后自动：

1. `postCreate`：`npm install --ignore-scripts` → 打协议补丁 → `npm run build`
2. `postStart`：启动服务 → 设端口 16384 为 public → 启动保活

等 1-3 分钟后：

```
https://<codespace-name>-16384.app.github.dev/
```

加载器：

```lua
getgenv().BridgeURL = "https://<codespace-name>-16384.app.github.dev"
loadstring(game:HttpGet(getgenv().BridgeURL .. "/script.luau"))()
```

**注意**：Codespace 有 12 小时硬性上限，到点必须重建。`keepalive.sh` 只能防空闲休眠。

---

## 已知限制

| 限制 | 说明 |
|---|---|
| **只能在 Roblox 执行器里跑** | DEX 用了 Luau 专有语法（`continue` 7 处、`..=` 复合赋值），纯 Lua 环境会语法报错 |
| **nil 实例路径无法解析回去** | DEX 对无父对象输出 `getNil(...)` 代码片段，不是可解析表达式 |
| **反编译依赖执行器** | 需要 `decompile`，否则回退 `.Source`（通常为空） |
| **Windows 工具在 Linux 无效** | `screenshot-window` / `list-roblox-windows` 仅 Windows |
| **Codespaces 12 小时上限** | 无法绕过 |
| **语义搜索需 Ollama** | `semantic-search-scripts` 需要本地 Ollama 或配置 OpenAI 嵌入 |

---

## 验证记录

| 项目 | 结果 |
|---|---|
| `tsc --noEmit` | ✅ **0 错误** |
| `npm run build` | ✅ 成功 |
| 路由加载 | ✅ **34 条** |
| `POST /dex/event` | ✅ 返回 204 |
| `GET /dex/events?since=N` | ✅ 增量过滤正确 |
| `DELETE /dex/events` | ✅ `{"cleared":2}` |
| MCP `tools/list` | ✅ **29 个工具**，3 个 DEX 工具已注册 |
| `dex_A.lua` 语法 | ✅ 通过 |
| `dex_C.lua` 语法 | ✅ 通过 |
| `dex_AC.lua` 语法 | ✅ 通过 |
| `dex_A.lua` 功能测试 | ✅ **11/11** |
| `dex_C.lua` 功能测试 | ✅ **8/8** |
| A+C 共存测试 | ✅ 通过（A 选中后 C 角标同步） |
| 补丁字节完整性 | ✅ SHA256 一致 |
| `Main.Init()` 唯一性 | ✅ 每个文件仅 1 次 |

功能测试覆盖：挂载、6 种路径解析、选中、快照、实例树、属性读取、反编译、属性设置（含 `lua:` 求值）、代码执行（成功/失败）、队列、面板开关、按钮创建、多选发送、A+C 协同。

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

Codespaces 设成 `public` 端口意味着**任何拿到域名的人**都能在你的 Roblox 会话里跑代码。域名虽然难猜，但这是靠隐蔽性当安全。用完请及时停止 Codespace。

---

## 来源与致谢

| 项目 | 说明 |
|---|---|
| [notpoiu/roblox-executor-mcp](https://github.com/notpoiu/roblox-executor-mcp) | 上游（**已 404**） |
| [Potato5466794/Roblox-MCP](https://github.com/Potato5466794/Roblox-MCP) | 中间 fork |
| [LorekeeperZinnia/Dex](https://github.com/LorekeeperZinnia/Dex) | DEX 本体（作者 Moon） |
| [notpoiu/cobalt](https://github.com/notpoiu/cobalt) | Remote Spy 后端 |
| [luau/UniversalSynSaveInstance](https://github.com/luau/UniversalSynSaveInstance) | SaveInstance |

---

## License

MIT

---

<p align="center">
  <sub>本项目仅用于自建测试环境。在公开游戏中使用可能违反 Roblox 服务条款。</sub>
</p>