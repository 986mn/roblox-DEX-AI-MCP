<p align="center">
  <img src="../assets/dex-mcp/banner.svg" alt="dex-mcp — DEX Bidirectional Bridge" width="100%"/>
</p>

<h1 align="center">dex-mcp</h1>

<p align="center">
  <strong>Standalone DEX bundle — DEX with the AI bridge already baked in</strong><br/>
  <sub>No patching, no build step. Download one file, run it, done.</sub>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/DEX-12%2C684%20lines-0b5aaf.svg" alt="DEX lines"/>
  <img src="https://img.shields.io/badge/builds-4%20ready--to--run-success.svg" alt="Builds"/>
  <img src="https://img.shields.io/badge/built%20by-deepseek--v4.1--flash-ff6b35.svg" alt="Built by AI"/>
</p>

<p align="center">
  <strong>English</strong> · <a href="README.zh-CN.md">中文</a>
</p>

---

> ### 🤖 Built entirely by AI
>
> Every file in this folder — the three patch modules, the four pre-built
> dex.lua bundles, this README and its graphics — was written by
> **`deepseek-v4.1-flash`**. No human wrote any code here.

---

## What's in this folder

You get **two ways** to run it: pre-built bundles (easiest) or patches (if you want to apply them yourself).

### Option 1 — Pre-built bundles (`builds/`)

Complete `dex.lua` with the bridge already merged in. **Just paste and run.**

| File | Size | What you get |
|---|---|---|
| `builds/dex_A.lua` | 494 KB | Read/write API — AI can read your selection and drive DEX |
| `builds/dex_B.lua` | 490 KB | Same API, self-contained variant |
| `builds/dex_C.lua` | 493 KB | Floating **[→ MCP]** button + context menu + hotkey |
| `builds/dex_AC.lua` | 510 KB | **Both** — recommended ⭐ |

### Option 2 — Patches (`dex_mcp_*.lua`)

If you'd rather keep your own `dex.lua` untouched and apply the bridge yourself:

| File | How to use |
|---|---|
| `dex_mcp_A.lua` | Append to the **end** of `dex.lua`, after `Main.Init()` |
| `dex_mcp_B.lua` | Load standalone — downloads dex.lua and merges at runtime |
| `dex_mcp_C.lua` | Append to the **end** of `dex.lua` (adds the button UI) |

---

## Quick start

### Fastest path

1. Open `builds/dex_AC.lua` in this repo
2. Copy the **entire** file
3. Paste into your executor, hit run

That's it. You'll see:

```
[DEX-MCP] 方案A 已注入 | version=mcp-A-1.0
[DEX-MCP] 方案C 已注入 | version=mcp-C-1.0
```

And DEX opens, with a small **[→ MCP]** button in the bottom-right corner.

### Connect it to the AI

In the executor, **before** loading the DEX bundle:

```lua
getgenv().BridgeURL = "http://localhost:16384"      -- local server
-- getgenv().BridgeURL = "https://xxx-16384.app.github.dev"   -- Codespaces
```

Without this, DEX still works perfectly — it just runs in "pull only" mode
(the AI can still query it, but pushes to `/dex/event` are skipped).

---

## What it looks like

<p align="center">
  <img src="../assets/dex-mcp/demo.gif" alt="DEX MCP bridge demo" width="820"/>
  <br/>
  <sub>Select in DEX → click the button → the AI reads the exact path → AI can send you back to that object</sub>
</p>

### Step by step

<table>
<tr>
<td width="50%" align="center">
  <img src="../assets/dex-mcp/steps/step1-select.png" alt="Step 1: select an object" width="100%"/>
  <br/><b>1.</b> Select any object in DEX
</td>
<td width="50%" align="center">
  <img src="../assets/dex-mcp/steps/step2-events.png" alt="Step 2: click → MCP" width="100%"/>
  <br/><b>2.</b> Click <b>[→ MCP]</b> — the path is queued
</td>
</tr>
<tr>
<td width="50%" align="center">
  <img src="../assets/dex-mcp/steps/step3-properties.png" alt="Step 3: AI reads properties" width="100%"/>
  <br/><b>3.</b> The AI reads the real properties
</td>
<td width="50%" align="center">
  <img src="../assets/dex-mcp/steps/step4-dex-select.png" alt="Step 4: AI selects in DEX" width="100%"/>
  <br/><b>4.</b> AI can jump DEX to any object
</td>
</tr>
<tr>
<td colspan="2" align="center">
  <img src="../assets/dex-mcp/steps/step5-execute.png" alt="Step 5: execute" width="100%"/>
  <br/><b>5.</b> Then act on it — change properties, run code, fire remotes
</td>
</tr>
</table>

---

## The three strategies

### A — Full read/write API

Exposes `getgenv().DEX` with everything the bridge can do.

```lua
getgenv().DEX.Snapshot()                              -- what's selected now
getgenv().DEX.Select({"game.Workspace.Map.NPC"})      -- make DEX jump there
getgenv().DEX.Tree("game.Workspace", 3, 200)          -- dump hierarchy
getgenv().DEX.Props("game.Workspace.Map.NPC")         -- read properties
getgenv().DEX.Source("game:GetService('ReplicatedStorage').Mods.Combat")  -- decompile
getgenv().DEX.SetProp("game.Workspace.Map.NPC", "Health", "0")
getgenv().DEX.Run("return 1+1")
```

### B — Runtime wrapper

Keeps `dex.lua` pristine on disk. Downloads it, merges the bridge in memory, runs once.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/986mn/roblox-DEX-AI-MCP/main/dex_mcp_B.lua"))()
```

Useful when you want to track upstream DEX updates without re-patching.

### C — Visible button

Adds a draggable **[→ MCP]** button (bottom-right), a right-click menu entry,
and `Ctrl+Shift+M`. A small badge shows how many objects are selected.

Click → paths go into a queue **and** get copied to your clipboard.

---

## API reference

### Read

| Call | Returns |
|---|---|
| `DEX.Snapshot()` | `{selection, selectionPaths, selectionCount, apps, pendingCount, uptime, ...}` |
| `DEX.Info(node)` | `{name, class, path, parent, position?, health?, hasHumanoid?}` |
| `DEX.Tree(path, depth, limit)` | Nested `{name, class, children[]}` |
| `DEX.Props(path)` | `{properties, attributes, tags}` |
| `DEX.Source(path)` | `{source, length, class}` (needs executor `decompile`) |

### Write

| Call | Effect |
|---|---|
| `DEX.Select(paths, additive?)` | Select in the DEX UI + scroll into view |
| `DEX.SetProp(path, prop, value)` | Set a property (or attribute). Prefix with `lua:` to evaluate |
| `DEX.App(name, open?)` | Show/hide a DEX panel |
| `DEX.Refresh()` | Force tree + properties refresh |
| `DEX.Run(code)` | Execute Luau, return results |

### Queue (C only)

| Call | Effect |
|---|---|
| `DEX_QUEUE.Send(reason?)` | Push current selection |
| `DEX_QUEUE.Take()` | Read **and clear** the queue |
| `DEX_QUEUE.Peek()` | Read without clearing |
| `DEX_QUEUE.Selected()` | Current paths only |

---

## Path syntax

All three strategies accept every format DEX itself produces:

```lua
game.Workspace.Map.NPC                          -- normal
Workspace.Map.NPC                                -- "game." optional
game:GetService("ReplicatedStorage").Mods        -- services
game.Workspace:GetChildren()[3]                  -- duplicate names
game.Workspace["weird name"]                     -- special characters
```

---

## Requirements

- A Roblox executor with `loadstring`, `getgenv`, and `request`
- `decompile` — only needed for `DEX.Source()`
- Optional: `WebSocket` for the faster transport (falls back to HTTP polling)

---

## Known limitations

1. **nil instances can't be resolved back** — DEX emits a `getNil(...)` snippet for parentless objects, which isn't a parseable expression. You can read the path, not navigate to it.
2. **`DEX.Source()` depends on your executor** — no `decompile` means it falls back to `.Source`, which is usually empty.
3. **Luau-only** — DEX uses `continue` and `..=`, so it won't parse in plain Lua. Roblox executors only.
4. **Push needs the server route** — without `getgenv().BridgeURL`, the bridge runs pull-only. It won't error, it just won't push.

---

## Verification

Each build was checked for:

| Check | Result |
|---|---|
| Full dex body present (starts at `-- https://github.com/LorekeeperZinnia/Dex`) | ✅ all 4 |
| `Main.Init()` appears **before** the bridge | ✅ all 4 |
| Bridge code lands at the end of file | ✅ all 4 |
| Files end with a proper `end` | ✅ all 4 |
| Syntax valid (Luau constructs normalized for the checker) | ✅ all 4 |
| Bridge API functional test (11 cases) | ✅ A / B |
| Button UI functional test (8 cases) | ✅ C |
| A + C coexistence | ✅ no variable conflicts |

---

## Credits

- **DEX** — [LorekeeperZinnia/Dex](https://github.com/LorekeeperZinnia/Dex), by Moon (12,684 lines, unmodified core)
- **MCP server** — [roblox-DEX-AI-MCP](../README.md)
- **Bridge code, builds, docs, graphics** — `deepseek-v4.1-flash`

## License

MIT