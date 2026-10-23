# DEX — the core of this project

> 本目录是整个项目的**主体**。服务端（`src/`）只是为 DEX 服务的配套设施。

[English](README.md) · **中文**

---

## 为什么 DEX 是主体

大多数 Roblox MCP 项目的思路是：**AI 直接操作游戏**。

这个项目换了个思路：**以 DEX 为中心**。

| 传统 MCP | 本项目（DEX-first） |
|---|---|
| AI 盲猜对象路径 | 你在 DEX 里点，AI 精确知道 |
| AI 改属性后你看不到 | AI 操作后你的 DEX 界面同步跳转 |
| 调试全靠猜 | 可视化浏览 + AI 批量操作 |

DEX 本来就是个成熟的调试器（12,684 行，作者 Moon）。
我们**不重写它**，只给它接上双向通道。

---

## 两种形态

本目录提供两种使用方式：

| 形态 | 目录 | 说明 |
|---|---|---|
| **完整版** ⭐ | `builds/` | 已拼接好的 dex.lua，直接运行 |
| **补丁** | `patches/` | 追加到你自己的 dex.lua，或独立加载 |

### 完整版（推荐）

| 文件 | 大小 | 内容 |
|---|---|---|
| **`builds/dex_AC.lua`** | 510 KB | 原版 DEX + 读写 API + 按钮 UI ⭐ **推荐** |
| `builds/dex_A.lua` | 494 KB | 原版 DEX + 读写 API |
| `builds/dex_C.lua` | 493 KB | 原版 DEX + 按钮 UI |

```lua
-- 零配置，直接跑
loadstring(game:HttpGet("https://raw.githubusercontent.com/986mn/roblox-DEX-AI-MCP/main/dex/builds/dex_AC.lua"))()
```

### 补丁

| 文件 | 用法 |
|---|---|
| `patches/dex_mcp_A.lua` | 追加到 dex.lua 末尾（`Main.Init()` 之后） |
| `patches/dex_mcp_B.lua` | **独立加载，不改 dex.lua** |
| `patches/dex_mcp_C.lua` | 追加到 dex.lua 末尾 |

**补丁 B 的用法**（最灵活，可换任意 DEX 源，含汉化版）：

```lua
getgenv().DEX_URL = "https://raw.githubusercontent.com/986mn/wg/main/dex.lua"
loadstring(game:HttpGet("https://raw.githubusercontent.com/986mn/roblox-DEX-AI-MCP/main/dex/patches/dex_mcp_B.lua"))()
```

### 对比

| | 改动 | 读写 API | 按钮 UI | 适用 |
|---|---|---|---|---|
| `builds/dex_AC.lua` | 无 | ✅ | ✅ | **大多数人** |
| `builds/dex_A.lua` | 无 | ✅ | ❌ | 只要 API |
| `builds/dex_C.lua` | 无 | 只读 | ✅ | 只要按钮 |
| `patches/dex_mcp_A.lua` | 追加 | ✅ | ❌ | 想自己拼 |
| `patches/dex_mcp_B.lua` | 独立 | ✅ | ❌ | 想保持原版 |
| `patches/dex_mcp_C.lua` | 追加 | 只读 | ✅ | 想自己拼 |

---

## 装好后确认

控制台应出现：

```
[DEX-MCP] 方案A 已注入 | version=mcp-A-1.0
[DEX-MCP] 拉取: getgenv().DEX.Snapshot()
[DEX-MCP] 控制: getgenv().DEX.Select({...})
[DEX-MCP] 方案C 已注入 | version=mcp-C-1.0
[DEX-MCP] 点【→ MCP】按钮 或 Ctrl+Shift+M 发送选中对象
```

AC 版右下角会出现【→ MCP】按钮。

---

## 双向通道

```
① 你在 DEX 里点中 workspace.Map.NPC
   ↓ 点【→ MCP】按钮
② AI 收到路径 → 调用 dex-events
③ AI 调 get-instance-properties → 知道是 Model / Health=100
④ AI 调 dex-select → 你的 DEX 界面跳到该对象
⑤ AI 调 execute → Health 改成 0
```

反向也通：AI 说「帮我选中所有 NPC」，你的 DEX 界面同步高亮。

---

## DEX API（A / AC 版）

```lua
local D = getgenv().DEX

-- 读
D.Snapshot()                          -- 当前选中快照
D.Tree("game.Workspace", 3, 200)      -- 实例树
D.Props("game.Workspace.NPC")         -- 属性 + Attributes + 标签
D.Source("game.ReplicatedStorage.X")  -- 反编译
D.Resolve("game.Workspace.NPC")       -- 路径 → Instance

-- 写
D.Select({"game.Workspace.NPC"})          -- 设选中
D.Select({p1, p2}, true)                  -- 追加选中
D.SetProp(path, "Health", "0")            -- 改属性
D.SetProp(path, "CFrame", "lua:CFrame.new(0,50,0)")
D.Run("return 1+1")                       -- 执行代码
D.App("Explorer", true)                   -- 开面板
D.Refresh()                               -- 刷新

-- 原生模块直通
D.Main / D.Explorer / D.Properties / D.ScriptViewer / D.Console
D.nodes / D.selection / D.env / D.API / D.Lib
```

## 队列 API（C / AC 版）

```lua
local Q = getgenv().DEX_QUEUE
Q.Take()          -- 取走并清空
Q.Peek()          -- 只看
Q.Send("reason")  -- 手动发送
Q.Selected()      -- 当前选中路径
Q.Count()         -- 队列长度
```

## 路径格式

```lua
game.Workspace.Map.NPC                          -- 普通
Workspace.Map.NPC                               -- 省略 game
game:GetService("ReplicatedStorage").Mods       -- 服务
game.Workspace:GetChildren()[3]                 -- 重名索引
game.Workspace["奇怪 名字"]                      -- 特殊字符
```

## 按钮操作（C / AC）

| 操作 | 效果 |
|---|---|
| 左键点【→ MCP】 | 发送选中，按钮变 `✓ N` |
| 右键点按钮 | 打印队列 + 全复制到剪贴板 |
| 拖动 | 移动位置 |
| 右键对象 → 发送到 MCP | 同上 |
| Ctrl+Shift+M | 同上 |

---

## 连接服务端

想让 AI 自动收到你的选中，在**加载 DEX 之前**设置：

```lua
getgenv().BridgeURL = "https://xxx-16384.app.github.dev"  -- Codespaces
getgenv().BridgeURL = "192.168.1.100:16384"              -- 局域网
getgenv().BridgeURL = "localhost:16384"                  -- 本机
```

不设也能用（纯本地模式，AI 需主动调工具读）。

---

## 已知限制

| 限制 | 说明 |
|---|---|
| **只能 Roblox 执行器** | DEX 用 Luau 专有语法（`continue` 7 处、`..=` 复合赋值） |
| **nil 实例路径无法回解析** | DEX 对无父对象输出 `getNil(...)` 代码片段 |
| **反编译依赖执行器** | 需 `decompile`，否则回退 `.Source`（通常空） |

---

## 验证记录

| 项目 | 结果 |
|---|---|
| `builds/dex_A.lua` 语法 | ✅ |
| `builds/dex_C.lua` 语法 | ✅ |
| `builds/dex_AC.lua` 语法 | ✅ |
| A 功能测试 | ✅ **11/11** |
| C 功能测试 | ✅ **8/8** |
| A+C 共存 | ✅ 通过 |
| 补丁字节完整性 | ✅ SHA256 一致 |
| `Main.Init()` 唯一性 | ✅ 每文件仅 1 次 |

测试方法：从完整文件中提取补丁代码，放进 mock Roblox 环境**真实执行**。
覆盖：挂载、6 种路径解析、选中、快照、实例树、属性读写、反编译、
代码执行、队列、面板开关、按钮创建、多选发送、A+C 协同。

---

## 来源

- 原版 DEX：[LorekeeperZinnia/Dex](https://github.com/LorekeeperZinnia/Dex) —— 作者 Moon，12,684 行，未混淆
- MCP 服务端基础：[Shayeem/Roblox-MCP](https://github.com/Muhammad-Tanvirul-Islam-Shayeem/Roblox-MCP) —— `src/` 与 `connector.luau` 全部源自他的工作
- 本项目所有 DEX 集成代码由 **deepseek-v4.1-flash AI** 编写

---

<p align="center">
  <sub>仅用于自建测试环境。公开游戏中使用可能违反 Roblox 服务条款。</sub>
</p>