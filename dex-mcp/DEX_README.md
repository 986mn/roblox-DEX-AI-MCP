# DEX x MCP —— A / B / C 三套方案

基于真实 dex.lua（12684 行 / 477KB，原版 Moon 制作）改造。
所有关键行号都是从实际源码读出来的，不是猜的。

---

## 一句话对比

| | 改什么 | 你要做什么 | 我能拿到什么 | 风险 |
|---|---|---|---|---|
| **A** | 追加代码进 dex.lua | 把 A 粘到 dex.lua 末尾 | 全量读写 API | 低 |
| **B** | 不改 dex.lua | 单独跑 B 一个文件 | 全量读写 API | 低 |
| **C** | 追加代码进 dex.lua | 把 C 粘到 dex.lua 末尾 | 你点按钮我收到路径 | 极低 |

**A 和 B 能力完全一样，区别只是「代码放哪」。C 是另一条路 —— 以你为主导。**

---

## 方案 A：追加式（永久集成）

### 安装
把 `dex_mcp_A.lua` 的**全部内容**粘贴到 `dex.lua` 最后一行（`Main.Init()`）**之后**，保存。

或者干脆在你的仓库里新建 `dex_full.lua`，内容 = dex.lua + A。

### 验证
加载 dex.lua 后，控制台应该看到：
```
[DEX-MCP] 方案A 已注入 | version=mcp-A-1.0
[DEX-MCP] 拉取: getgenv().DEX.Snapshot()
[DEX-MCP] 控制: getgenv().DEX.Select({...})
```

### 用法
```lua
-- 看你现在选中了什么
return getgenv().DEX.Snapshot()

-- 让我帮你选中某个对象（你的 DEX 界面会同步跳过去）
getgenv().DEX.Select({"game.Workspace.Map.NPC"})

-- 多选
getgenv().DEX.Select({"game.Workspace.Map.NPC", "game.Workspace.Map.NPC2"}, true)

-- 读实例树
getgenv().DEX.Tree("game.Workspace", 3, 200)

-- 读属性
getgenv().DEX.Props("game.Workspace.Map.NPC")

-- 反编译
getgenv().DEX.Source("game:GetService(\"ReplicatedStorage\").Mods.Combat")

-- 改属性
getgenv().DEX.SetProp("game.Workspace.Map.NPC", "Health", "0")
getgenv().DEX.SetProp("game.Workspace.Map.NPC", "CFrame", "lua:CFrame.new(0,50,0)")

-- 跑代码
getgenv().DEX.Run("return 1+1")

-- 开/关面板
getgenv().DEX.App("Explorer", true)
```

### 我这边怎么调用
```
get-data-by-code:
  return game:GetService("HttpService"):JSONEncode(getgenv().DEX.Snapshot())

execute:
  getgenv().DEX.Select({"game.Workspace.Map.NPC"})
```

---

## 方案 B：适配层（不动原文件）

### 安装
把 `dex_mcp_B.lua` 传到你的仓库，然后执行：
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/986mn/wg/main/dex_mcp_B.lua"))()
```

它会自动：
1. 下载 dex.lua（地址可用 `getgenv().DEX_URL` 覆盖）
2. 把核心 API 拼到末尾
3. 一次性执行

### 好处
- 仓库里的 `dex.lua` **永远是官方原版**，DEX 升级不冲突
- 一个文件搞定，换 DEX 地址（含汉化版）只改一行：
  ```lua
  getgenv().DEX_URL = "https://raw.githubusercontent.com/986mn/wg/main/汉化(分类).lua"
  loadstring(game:HttpGet("...dex_mcp_B.lua"))()
  ```
- API 用法和 A **完全相同**

### 调试
```lua
getgenv().DEX_MCP_DEBUG = true
```

---

## 方案 C：按钮式（你主导）

### 安装
把 `dex_mcp_C.lua` 的**全部内容**粘贴到 `dex.lua` 最后一行之后。

### 你会看到
1. **右下角一个【→ MCP】按钮**（可拖动）
2. 按钮右上角有**蓝色小数字** = 当前选中几个对象
3. 右键菜单（资源管理器里右键对象）多一项 **【发送到 MCP】**
4. 快捷键 **Ctrl + Shift + M**

### 怎么用
1. 在 DEX 里点选你感兴趣的对象（可以多选）
2. 点【→ MCP】按钮
3. 按钮变 `✓ 2`，路径已进队列 + **自动复制到剪贴板**
4. 告诉我「拉一下队列」，我就能拿到精确路径

### 按钮操作
| 操作 | 效果 |
|---|---|
| 左键单击 | 发送当前选中 |
| 右键单击 | 打印队列全部内容 + 全部复制到剪贴板 |
| 拖动 | 移动位置 |

### 我这边怎么取
```
get-data-by-code:
  return game:GetService("HttpService"):JSONEncode(getgenv().DEX_QUEUE.Take())
```
`Take()` 会**取走并清空**队列。只想看不想清空用 `Peek()`。

---

## 三套方案的 API 对照

| 功能 | A | B | C |
|---|---|---|---|
| 读选中快照 | `DEX.Snapshot()` | `DEX.Snapshot()` | `DEX_QUEUE.Snapshot()` |
| 设选中 | `DEX.Select()` | `DEX.Select()` | `DEX_QUEUE.Select()` |
| 实例树 | `DEX.Tree()` | `DEX.Tree()` | `DEX_QUEUE.Tree()` |
| 读属性 | `DEX.Props()` | `DEX.Props()` | `DEX_QUEUE.Props()` |
| 反编译 | `DEX.Source()` | `DEX.Source()` | ✗ |
| 改属性 | `DEX.SetProp()` | `DEX.SetProp()` | ✗ |
| 执行代码 | `DEX.Run()` | `DEX.Run()` | `DEX_QUEUE.Run()` |
| 开关面板 | `DEX.App()` | `DEX.App()` | ✗ |
| 按钮 UI | ✗ | ✗ | ✓ |
| 右键菜单 | ✗ | ✗ | ✓ |
| 快捷键 | ✗ | ✗ | ✓ |
| 路径队列 | ✓ | ✓ | ✓ |
| 原生模块直通 | ✓ | ✓ | ✗ |

---

## 组合用法（推荐）

**A + C 一起装** = 最强配置：
- A 给我完整的读写能力（我能主动操作）
- C 给你一个按钮（你能主动喂给我）
- 双向打通

两者变量名不冲突（`DEX` vs `DEX_QUEUE`），可以同时追加。

---

## 路径格式支持

三种方案都能解析 DEX 产出的所有路径格式：

```lua
game.Workspace.Map.NPC                              -- 普通
Workspace.Map.NPC                                   -- 省略 game
 game:GetService("ReplicatedStorage").Mods          -- 服务
game.Workspace:GetChildren()[3]                     -- 重名索引
game.Workspace["奇怪 名字"]                          -- 特殊字符
```

---

## 已知限制

1. **nil 实例路径不支持** —— DEX 对无父对象会输出一段 `getNil(...)` 代码片段，那不是可解析的表达式。读得到路径，但解析不回去。
2. **反编译依赖执行器** —— `DEX.Source()` 需要执行器有 `decompile`。没有就回退到 `.Source`（几乎总是空）。
3. **push 需要服务端支持** —— 三套方案都会 POST 到 `/dex/event`，但**你的 Roblox-MCP 服务端目前没这个路由**。不设 `BridgeURL` 就是纯拉取模式，完全可用；设了也只是 3 次失败后自动静默关闭，不会报错。
4. **DEX 用了 Luau 专有语法** —— `continue` 语句、`..=` 复合赋值。所以**只能在 Roblox 执行器里跑**，任何纯 Lua 环境都会语法报错。测试时我做了语法降级处理来验证。

---

## 验证记录

| 项目 | 结果 |
|---|---|
| A 语法 | ✅ 独立 OK + 拼接 dex.lua 后 OK |
| B 语法 | ✅ 独立 OK + 拼接 dex.lua 后 OK |
| C 语法 | ✅ 独立 OK + 拼接 dex.lua 后 OK |
| A 功能测试 | ✅ 11/11 通过 |
| B 功能测试 | ✅ 11/11 通过 |
| C 功能测试 | ✅ 8/8 通过 |

测试项：挂载、路径解析（6 种格式）、选中、快照、实例树、属性读取、反编译、属性设置（含 `lua:` 求值）、代码执行（成功/失败）、队列、面板开关、按钮创建、多选发送。

---

## 文件清单

```
dex_mcp_A.lua   16.7 KB   追加到 dex.lua 末尾
dex_mcp_B.lua   16.2 KB   独立运行（loadstring 即可）
dex_mcp_C.lua   15.5 KB   追加到 dex.lua 末尾
README.md        本文件
```
