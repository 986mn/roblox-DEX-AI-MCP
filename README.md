<p align="center">
  <img src="assets/banner.svg" alt="roblox-DEX-AI-MCP — DEX-first bidirectional bridge" width="100%"/>
</p>

<h1 align="center">roblox-DEX-AI-MCP</h1>

<p align="center">
  <strong>A DEX-first bidirectional AI bridge</strong><br/>
  <sub>The AI knows what you clicked in DEX — and can click things in DEX for you</sub>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"/></a>
  <a href="https://nodejs.org"><img src="https://img.shields.io/badge/node-%E2%89%A518-brightgreen.svg" alt="Node"/></a>
  <img src="https://img.shields.io/badge/MCP-29%20tools-purple.svg" alt="MCP tools"/>
  <img src="https://img.shields.io/badge/DEX-12%2C684%20lines-0b5aaf.svg" alt="DEX lines"/>
  <img src="https://img.shields.io/badge/built%20by-deepseek--v4.1--flash-ff6b35.svg" alt="Built by AI"/>
</p>

<p align="center">
  <strong>English</strong> · <a href="README.zh-CN.md">中文</a>
</p>

---

> ### 🤖 This entire project was built by AI
>
> **From the first line of code to this README, everything was written by `deepseek-v4.1-flash`.**
>
> That includes: three DEX bridge strategies, four new server routes, three MCP tools,
> three complete dex.lua builds, bilingual docs, the banner and the demo graphics.
>
> The human did exactly two things: state the requirements, and supply a GitHub token.
>
> See [How much of this is AI?](#how-much-of-this-is-ai).

---

## Contents

- [Why DEX is the center](#why-dex-is-the-center)
- [Quick start](#quick-start)
- [DEX integration (the core)](#dex-integration-the-core)
- [The two-way workflow](#the-two-way-workflow)
- [MCP tools](#mcp-tools)
- [HTTP routes](#http-routes)
- [Project structure](#project-structure)
- [How much of this is AI?](#how-much-of-this-is-ai)
- [Verification record](#verification-record)
- [Known limitations](#known-limitations)
- [Security](#security)

---

## Why DEX is the center

Most Roblox MCP projects work like this: **the AI operates the game directly**.
To find "that red thing" the AI has to guess paths and try again.

This project flips it: **DEX becomes the AI's eyes and hands**.

| Traditional MCP | This project (DEX-first) |
|---|---|
| The AI guesses object paths | You click in DEX; the AI knows `game.Workspace.Map.NPC` exactly |
| Property changes are invisible | Your DEX UI **jumps to and highlights** the object |
| Debugging is guesswork | Visual browsing + AI batch operations |
| AI and debugger are separate | They are two ends of one channel |

DEX is already a mature debugger (**12,684 lines**, by Moon, unobfuscated).
We **don't rewrite it** — we just wire up a two-way channel.

---

## Quick start

### 1. Use the pre-built DEX (zero config) ⭐

```lua
-- In your Roblox executor
loadstring(game:HttpGet("https://raw.githubusercontent.com/986mn/roblox-DEX-AI-MCP/main/dex/builds/dex_AC.lua"))()
```

If an [→ MCP] button appears in the bottom-right corner, it worked.

### 2. Build the server (optional — only needed for automatic push)

```bash
git clone https://github.com/986mn/roblox-DEX-AI-MCP.git
cd roblox-DEX-AI-MCP
npm install --ignore-scripts --no-package-lock
npm run build
node dist/index.js < /dev/zero
```

> `--ignore-scripts` is required (the `prepare` hook triggers a build).
> `< /dev/zero` is required (MCP speaks stdio; closing stdin kills the server).

Healthy start:

```
MCP Server started and connected via stdio.
[Router] Loaded 34 HTTP route(s), 1 WS route(s) + WS fallback.
[Primary] MCP Bridge listening on port 16384 (WebSocket + HTTP)
```

### 3. Point DEX at the server

Set this **before** loading DEX:

```lua
getgenv().BridgeURL = "localhost:16384"                     -- local
-- getgenv().BridgeURL = "192.168.1.100:16384"             -- LAN
-- getgenv().BridgeURL = "https://xxx-16384.app.github.dev" -- Codespaces

loadstring(game:HttpGet("https://raw.githubusercontent.com/986mn/roblox-DEX-AI-MCP/main/dex/builds/dex_AC.lua"))()
```

### 4. Configure your AI client

```json
{
  "mcpServers": {
    "roblox-dex-ai-mcp": {
      "command": "node",
      "args": ["/path/to/roblox-DEX-AI-MCP/dist/index.js"]
    }
  }
}
```

---

## DEX integration (the core)

Full docs: **[`dex/README.md`](dex/README.md)**.

### Two forms

| Form | Folder | Description |
|---|---|---|
| **Pre-built** ⭐ | `dex/builds/` | Complete dex.lua, ready to run |
| **Patches** | `dex/patches/` | Append to your own dex.lua, or load standalone |

### Pre-built

| File | Size | Contents |
|---|---|---|
| **`dex/builds/dex_AC.lua`** | 510 KB | DEX + read/write API + button UI ⭐ **recommended** |
| `dex/builds/dex_A.lua` | 494 KB | DEX + read/write API |
| `dex/builds/dex_C.lua` | 493 KB | DEX + button UI |

### Patches

| File | Usage |
|---|---|
| `dex/patches/dex_mcp_A.lua` | Append after `Main.Init()` |
| `dex/patches/dex_mcp_B.lua` | **Standalone — no need to touch dex.lua** |
| `dex/patches/dex_mcp_C.lua` | Append after `Main.Init()` |

**Patch B** (most flexible — works with any DEX source, including translated builds):

```lua
getgenv().DEX_URL = "https://raw.githubusercontent.com/986mn/wg/main/dex.lua"
loadstring(game:HttpGet("https://raw.githubusercontent.com/986mn/roblox-DEX-AI-MCP/main/dex/patches/dex_mcp_B.lua"))()
```

### DEX API cheat sheet

```lua
local D = getgenv().DEX

D.Snapshot()                          -- current selection
D.Select({"game.Workspace.NPC"})      -- select (UI jumps to it)
D.Tree("game.Workspace", 3, 200)      -- instance tree
D.Props("game.Workspace.NPC")         -- properties + Attributes + tags
D.Source("game.ReplicatedStorage.X")  -- decompiled source
D.SetProp(path, "Health", "0")        -- set a property
D.Run("return 1+1")                   -- execute code
D.App("Explorer", true)               -- open/close a panel
```

---

## The two-way workflow

<p align="center">
  <img src="assets/demo.gif" alt="Five-step bidirectional workflow: select in DEX, AI reads the path, inspects properties, drives DEX selection, executes code" width="100%"/>
</p>

<p align="center">
  <sub>Animated walkthrough — schematic, not an actual game capture</sub>
</p>

```
① You click workspace.Map.NPC inside DEX
   ↓ click the [→ MCP] button (or Ctrl+Shift+M)
② The AI calls dex-events
   → receives ["game.Workspace.Map.NPC"]
③ The AI calls get-instance-properties
   → learns it's a Model with a Humanoid, Health=100
④ The AI calls dex-select
   → your DEX UI jumps to that object and expands its properties
⑤ The AI calls execute
   → sets Health to 0
```

### Step by step

| Step | What happens |
|---|---|
| **1** Select in DEX | ![step 1](assets/steps/step1-select.png) |
| **2** AI reads the path | ![step 2](assets/steps/step2-events.png) |
| **3** AI inspects properties | ![step 3](assets/steps/step3-properties.png) |
| **4** AI drives DEX selection | ![step 4](assets/steps/step4-dex-select.png) |
| **5** AI executes code | ![step 5](assets/steps/step5-execute.png) |

The reverse direction is just as smooth:

```lua
-- AI: "selecting every NPC for you"
getgenv().DEX.Select({
    "game.Workspace.Map.NPC",
    "game.Workspace.Map.NPC2",
}, true)
-- your DEX UI highlights both instantly
```

---

## MCP tools

### DEX-specific (3, new in this project)

| Tool | Purpose |
|---|---|
| **`dex-events`** | Read what you selected in DEX (supports `since` and `clear`) |
| **`dex-select`** | Make the AI select objects in DEX (multi-select, `additive`) |
| **`dex-snapshot`** | Read live DEX state (selection, panels, queue) |

### Base tools (26)

| Category | Tools |
|---|---|
| **Clients** | `list-clients`, `set-active-client` |
| **Execution** | `execute`, `execute-file`, `get-data-by-code`, `teleport-player`, `set-player-property` |
| **Inspection** | `get-script-content`, `get-console-output`, `search-instances`, `get-descendants-tree`, `get-instance-properties`, `get-game-info`, `get-executor-environment` |
| **Search** | `script-grep`, `semantic-search-scripts` |
| **Remote** | `ensure-remote-spy`, `get-remote-spy-logs`, `clear-remote-spy-logs`, `block-remote`, `ignore-remote`, `fire-remote` |
| **GUI** | `click-button`, `type-text-box` |
| **Windows** | `list-roblox-windows`, `screenshot-window` |

**29 tools in total.**

---

## HTTP routes

### DEX routes (new)

| Route | Purpose |
|---|---|
| `POST /dex/event` | Receive a push from DEX → **204** |
| `GET /dex/event` | Latest event plus stats |
| `GET /dex/events?since=N` | Incremental read |
| `DELETE /dex/events` | Clear the buffer |

Push body:

```json
{
  "type": "selection",
  "reason": "button",
  "time": "12:00:00",
  "paths": ["game.Workspace.Map.NPC"]
}
```

### Original routes

```
GET  /                       dashboard
GET  /script.luau            loader
GET  /api/status             status
GET  /api/tools              tool catalog
POST /api/tool               run a tool
GET  /api/scripts            script list
GET  /api/client-logs        client logs
GET  /api/screenshot         screenshot
POST /register               client registration
GET  /poll                   HTTP polling
POST /respond                respond
GET  /script-sources         script sources
WS   /mcp-relay              primary/secondary relay
```

---

## Project structure

DEX sits at the **root**, not in a subfolder — it's the main thing here.

```
roblox-DEX-AI-MCP/
├── dex.lua                       ⭐ the DEX source (12,684 lines, unmodified)
├── dex_mcp_A.lua                 patch A — read/write API
├── dex_mcp_B.lua                 patch B — runtime wrapper
├── dex_mcp_C.lua                 patch C — button UI
├── DEX_README.md                 DEX docs (English)
├── DEX_README.zh-CN.md           DEX docs (中文)
├── builds/                       ⭐ pre-built, ready to run
│   ├── dex_AC.lua                DEX + API + button (510 KB) — recommended
│   ├── dex_A.lua                 DEX + API (494 KB)
│   ├── dex_B.lua                 DEX + API, self-contained (490 KB)
│   └── dex_C.lua                 DEX + button (493 KB)
├── dex-mcp/                      standalone bundle (docs + copies + own graphics)
│   ├── README.md / README.zh-CN.md
│   ├── builds/                    same four bundles
│   ├── assets/                    banner + demo.gif
│   └── dex_mcp_*.lua              the three patches
├── src/                          MCP server (serves DEX)
│   ├── http/
│   │   ├── dex-store.ts          DEX event store
│   │   └── routes/dex/
│   │       ├── event.ts          POST/GET /dex/event
│   │       └── events.ts         GET/DELETE /dex/events
│   ├── tools/impl/dex/
│   │   ├── dex-events.ts
│   │   ├── dex-select.ts
│   │   └── dex-snapshot.ts
│   ├── bridge/                   primary/secondary relay
│   ├── http/                     router + dashboard
│   └── semantic/                 vector search
├── assets/                       banner, demo.gif, step screenshots
│   └── dex-mcp/                  dex-mcp-specific graphics
├── connector.luau                client Luau (protocol-patched)
├── .devcontainer/                Codespaces auto-deploy
├── keepalive.sh                  idle guard + self-healing
└── scripts/                      build helpers
```

---

## How much of this is AI?

### Everything written by `deepseek-v4.1-flash`

| Output | Count | Details |
|---|---|---|
| **DEX bridge patches** | 3 files | A (read/write API), B (wrapper), C (button UI) |
| **Pre-built DEX** | 3 files | 12,684-line original DEX merged, 1.5 MB total |
| **New server code** | 6 files | event store + 2 routes + 3 MCP tools |
| **Documentation** | 6 docs | bilingual READMEs, dex folder docs |
| **Graphics** | banner + GIF | SVG + animated demo |

### Where the human contributed

| Item | Details |
|---|---|
| Stated the requirements | "add MCP support to DEX" |
| Supplied a token | GitHub PAT, for pushing |
| Supplied the DEX source | dex.lua from the `986mn/wg` repo |

> Note: the **server foundation** (`src/`, `connector.luau`) is not AI-written — it comes from Shayeem. See [Credits](#credits).

**Beyond that, all design, coding, debugging, testing, documentation and graphics were done by the AI.**

### Key engineering decisions (made autonomously by the AI)

| Decision | Why |
|---|---|
| Append after `Main.Init()` | Reading the source showed DEX discards its return value — nothing was ever exposed on `getgenv()` |
| Reuse `Explorer.GetInstancePath` | Line 1598 already has a working path generator; no need to reinvent it |
| Hook `ShowRightClick` | The context menu calls `Clear()` and rebuilds on every right-click, so a one-time `Register` is useless |
| Fix the `local API` shadowing bug | Testing revealed it clobbered DEX's global `API`, making `Props()` return nil |
| Protocol auto-detect patch | The connector hardcoded `http://`, but Codespaces only serves `https://` |
| Push via the Git Data API | `git push` died with a TLS error on large files; switched to blob→tree→commit→ref |

### Testing method

Not just reading code — **actually executing it**:

- Built a mock Roblox environment with Python `lupa`
- **Extracted the patch code from the complete builds** and ran it
- 11 tests for A, 8 tests for C, plus an A+C coexistence test
- Nothing was delivered until all of them passed

---

## Verification record

| Check | Result |
|---|---|
| `tsc --noEmit` | ✅ **0 errors** |
| `npm run build` | ✅ success |
| Route loading | ✅ **34 routes** |
| `POST /dex/event` | ✅ returns 204 |
| `GET /dex/events?since=N` | ✅ incremental filter works |
| `DELETE /dex/events` | ✅ `{"cleared":2}` |
| MCP `tools/list` | ✅ **29 tools** |
| `dex_A.lua` syntax | ✅ |
| `dex_C.lua` syntax | ✅ |
| `dex_AC.lua` syntax | ✅ |
| A functional tests | ✅ **11/11** |
| C functional tests | ✅ **8/8** |
| A+C coexistence | ✅ pass |
| Patch byte integrity | ✅ SHA256 match |
| `Main.Init()` uniqueness | ✅ exactly once per file |

---

## Known limitations

| Limitation | Details |
|---|---|
| **Roblox executor only** | DEX uses Luau-only syntax (`continue` ×7, `..=` compound assignment) |
| **nil-instance paths can't round-trip** | DEX emits a `getNil(...)` snippet for parentless objects |
| **Decompilation depends on the executor** | Requires `decompile`; otherwise falls back to `.Source` (usually empty) |
| **Windows tools don't work on Linux** | `screenshot-window` / `list-roblox-windows` are Windows-only |
| **Codespaces 12-hour cap** | Cannot be bypassed |
| **Semantic search needs Ollama** | `semantic-search-scripts` requires local Ollama |

---

## Security

**Port 16384 has no authentication whatsoever.**

- This server permits **arbitrary code execution**
- Only connect AI clients you trust
- **Never** expose it to the public internet
- For cross-machine use, tunnel through a VPN or SSH:

```bash
ssh -L 16384:localhost:16384 user@target-machine
```

Setting a Codespaces port to `public` means **anyone with the URL** can run code in your Roblox session.
Stop the Codespace when you're done.

---

## Credits

### Original author

<table>
<tr>
<td width="90" align="center">
  <a href="https://github.com/Muhammad-Tanvirul-Islam-Shayeem/Roblox-MCP">
    <img src="https://avatars.githubusercontent.com/u/184758083?v=4" width="72" style="border-radius:50%" alt="Shayeem"/>
  </a>
</td>
<td>
  <strong>Shayeem</strong> — <a href="https://github.com/Muhammad-Tanvirul-Islam-Shayeem/Roblox-MCP">@Muhammad-Tanvirul-Islam-Shayeem</a><br/>
  <em>Author of the Roblox Executor MCP server this project is built on.</em><br/>
  Repo: <a href="https://github.com/Muhammad-Tanvirul-Islam-Shayeem/Roblox-MCP"><code>Muhammad-Tanvirul-Islam-Shayeem/Roblox-MCP</code></a>
</td>
</tr>
</table>

> **This repository is a fork of [Shayeem/Roblox-MCP](https://github.com/Muhammad-Tanvirul-Islam-Shayeem/Roblox-MCP).**
>
> Every line of `src/` and `connector.luau` — the bridge, the tool catalog, the dashboard,
> the in-game connector — is **his work**. 14 stars, 105 files, the canonical copy.
> All this project does is add a DEX layer on top.

### The three pillars

| Project | Author | Role |
|---|---|---|
| **[Muhammad-Tanvirul-Islam-Shayeem/Roblox-MCP](https://github.com/Muhammad-Tanvirul-Islam-Shayeem/Roblox-MCP)** | **Shayeem** | **MCP server foundation** — forked directly, `parent` and `source` both point here |
| [LorekeeperZinnia/Dex](https://github.com/LorekeeperZinnia/Dex) | Moon | **DEX itself** — 12,684 lines, unobfuscated, the core of this project |
| [notpoiu/cobalt](https://github.com/notpoiu/cobalt) | notpoiu | Remote Spy backend |

### Lineage

```
Shayeem/Roblox-MCP                     <-- THIS REPO FORKS FROM HERE
Muhammad-Tanvirul-Islam-Shayeem        14 stars, 105 files, 1st Upload 2026-07-17
        |
        v
986mn/roblox-DEX-AI-MCP                 DEX layer added on top
        ^
        |  (Potato5466794/Roblox-MCP is an unrelated 1-star fork;
        |   notpoiu/roblox-executor-mcp is the deleted original concept)
```

### Also

| Project | Role |
|---|---|
| [luau/UniversalSynSaveInstance](https://github.com/luau/UniversalSynSaveInstance) | SaveInstance |

---

## License

MIT

---

<p align="center">
  <sub>For self-hosted test environments only. Using this in public games may violate the Roblox Terms of Service.</sub><br/>
  <sub>Every line of code and documentation here was written by <code>deepseek-v4.1-flash</code></sub>
</p>