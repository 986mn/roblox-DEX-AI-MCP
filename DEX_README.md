# DEX — the core of this project

> This directory is the **heart** of the project. The server (`src/`) exists only to serve DEX.

**English** · [中文](README.zh-CN.md)

---

## Why DEX is the core

Most Roblox MCP projects take the approach: **the AI operates the game directly**.

This project takes a different route: **DEX at the center**.

| Traditional MCP | This project (DEX-first) |
|---|---|
| The AI guesses object paths | You click in DEX, the AI knows exactly |
| Property changes happen invisibly | Your DEX UI follows along |
| Debugging is guesswork | Visual browsing + AI batch operations |

DEX is already a mature debugger (12,684 lines, by Moon).
We **don't rewrite it** — we just wire up a two-way channel.

---

## Two forms

This directory ships both:

| Form | Folder | Description |
|---|---|---|
| **Pre-built** ⭐ | `builds/` | Complete dex.lua, ready to run |
| **Patches** | `patches/` | Append to your own dex.lua, or load standalone |

### Pre-built (recommended)

| File | Size | Contents |
|---|---|---|
| **`builds/dex_AC.lua`** | 510 KB | Original DEX + read/write API + button UI ⭐ **recommended** |
| `builds/dex_A.lua` | 494 KB | Original DEX + read/write API |
| `builds/dex_C.lua` | 493 KB | Original DEX + button UI |

```lua
-- Zero configuration
loadstring(game:HttpGet("https://raw.githubusercontent.com/986mn/roblox-DEX-AI-MCP/main/dex/builds/dex_AC.lua"))()
```

### Patches

| File | Usage |
|---|---|
| `patches/dex_mcp_A.lua` | Append to the end of dex.lua (after `Main.Init()`) |
| `patches/dex_mcp_B.lua` | **Standalone — no need to touch dex.lua** |
| `patches/dex_mcp_C.lua` | Append to the end of dex.lua |

**Patch B** (most flexible — works with any DEX source, including translated builds):

```lua
getgenv().DEX_URL = "https://raw.githubusercontent.com/986mn/wg/main/dex.lua"
loadstring(game:HttpGet("https://raw.githubusercontent.com/986mn/roblox-DEX-AI-MCP/main/dex/patches/dex_mcp_B.lua"))()
```

### Comparison

| | Editing | Read/write API | Button UI | Best for |
|---|---|---|---|---|
| `builds/dex_AC.lua` | none | ✅ | ✅ | **most people** |
| `builds/dex_A.lua` | none | ✅ | ❌ | API only |
| `builds/dex_C.lua` | none | read-only | ✅ | button only |
| `patches/dex_mcp_A.lua` | append | ✅ | ❌ | merge yourself |
| `patches/dex_mcp_B.lua` | standalone | ✅ | ❌ | keep DEX pristine |
| `patches/dex_mcp_C.lua` | append | read-only | ✅ | merge yourself |

---

## Verify it loaded

The console should print:

```
[DEX-MCP] 方案A 已注入 | version=mcp-A-1.0
[DEX-MCP] 拉取: getgenv().DEX.Snapshot()
[DEX-MCP] 控制: getgenv().DEX.Select({...})
[DEX-MCP] 方案C 已注入 | version=mcp-C-1.0
[DEX-MCP] 点【→ MCP】按钮 或 Ctrl+Shift+M 发送选中对象
```

The AC build also adds an [→ MCP] button in the bottom-right corner.

---

## The two-way channel

```
① You click workspace.Map.NPC inside DEX
   ↓ click the [→ MCP] button
② The AI receives the path → calls dex-events
③ The AI calls get-instance-properties → learns Model / Health=100
④ The AI calls dex-select → your DEX UI jumps to that object
⑤ The AI calls execute → Health becomes 0
```

Works in reverse too: the AI says "select every NPC" and your DEX UI highlights them.

---

## DEX API (A / AC builds)

```lua
local D = getgenv().DEX

-- read
D.Snapshot()                          -- current selection
D.Tree("game.Workspace", 3, 200)      -- instance tree
D.Props("game.Workspace.NPC")         -- properties + Attributes + tags
D.Source("game.ReplicatedStorage.X")  -- decompiled source
D.Resolve("game.Workspace.NPC")       -- path → Instance

-- write
D.Select({"game.Workspace.NPC"})          -- replace selection
D.Select({p1, p2}, true)                  -- add to selection
D.SetProp(path, "Health", "0")            -- set a property
D.SetProp(path, "CFrame", "lua:CFrame.new(0,50,0)")
D.Run("return 1+1")                       -- execute code
D.App("Explorer", true)                   -- open a panel
D.Refresh()                               -- refresh

-- direct module access
D.Main / D.Explorer / D.Properties / D.ScriptViewer / D.Console
D.nodes / D.selection / D.env / D.API / D.Lib
```

## Queue API (C / AC builds)

```lua
local Q = getgenv().DEX_QUEUE
Q.Take()          -- drain the queue
Q.Peek()          -- read without draining
Q.Send("reason")  -- send now
Q.Selected()      -- selected paths
Q.Count()         -- queue length
```

## Path formats

```lua
game.Workspace.Map.NPC                          -- plain
Workspace.Map.NPC                               -- game prefix omitted
game:GetService("ReplicatedStorage").Mods       -- service
game.Workspace:GetChildren()[3]                 -- duplicate-name index
game.Workspace["odd name"]                      -- special characters
```

## Button controls (C / AC)

| Action | Effect |
|---|---|
| Left-click [→ MCP] | Send selection; button flashes `✓ N` |
| Right-click the button | Print queue + copy all to clipboard |
| Drag | Reposition |
| Right-click object → Send to MCP | Same |
| Ctrl+Shift+M | Same |

---

## Connect to the server

To let the AI receive your selections automatically, set this **before** loading DEX:

```lua
getgenv().BridgeURL = "https://xxx-16384.app.github.dev"  -- Codespaces
getgenv().BridgeURL = "192.168.1.100:16384"              -- LAN
getgenv().BridgeURL = "localhost:16384"                  -- local
```

Works without it too (local-only mode — the AI must call the tools actively).

---

## Known limitations

| Limitation | Details |
|---|---|
| **Roblox executor only** | DEX uses Luau-only syntax (`continue` ×7, `..=` compound assignment) |
| **nil-instance paths can't round-trip** | DEX emits a `getNil(...)` snippet for parentless objects |
| **Decompilation depends on the executor** | Requires `decompile`; otherwise falls back to `.Source` (usually empty) |

---

## Verification record

| Check | Result |
|---|---|
| `builds/dex_A.lua` syntax | ✅ |
| `builds/dex_C.lua` syntax | ✅ |
| `builds/dex_AC.lua` syntax | ✅ |
| A functional tests | ✅ **11/11** |
| C functional tests | ✅ **8/8** |
| A+C coexistence | ✅ pass |
| Patch byte integrity | ✅ SHA256 match |
| `Main.Init()` uniqueness | ✅ exactly once per file |

Method: patch code is extracted from the complete builds and **actually executed**
in a mock Roblox environment.
Coverage: mounting, 6 path formats, selection, snapshot, instance tree, property
read/write, decompilation, code execution, queueing, panel toggling, button
creation, multi-select send, A+C interaction.

---

## Credits

- Original DEX: [LorekeeperZinnia/Dex](https://github.com/LorekeeperZinnia/Dex) — by Moon, 12,684 lines, unobfuscated
- MCP server foundation: [Shayeem/Roblox-MCP](https://github.com/Muhammad-Tanvirul-Islam-Shayeem/Roblox-MCP) — every file in `src/` and `connector.luau` originates from his work
- All DEX integration code in this project was written by the **deepseek-v4.1-flash AI**

---

<p align="center">
  <sub>For self-hosted test environments only. Using this in public games may violate the Roblox Terms of Service.</sub>
</p>