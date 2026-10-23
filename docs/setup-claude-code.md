# Claude Code (CLI) Setup

## 1. Add the MCP server

Run this command in your terminal:

```bash
claude mcp add roblox-dex-ai-mcp -- node /path/to/roblox-dex-ai-mcp/dist/index.js
```

Replace `/path/to/roblox-dex-ai-mcp` with the actual path where you cloned the repo.

This adds the server to your local project config (`.claude/settings.local.json`). To add it globally instead, use:

```bash
claude mcp add --global roblox-dex-ai-mcp -- node /path/to/roblox-dex-ai-mcp/dist/index.js
```

## 2. Verify

Start Claude Code and run:

```
/mcp
```

You should see `roblox-dex-ai-mcp` listed with a status of `connected`. If it shows `failed`:

- Make sure you ran `pnpm install && pnpm run build` first
- Check that the path to `dist/index.js` is correct
- Ensure Node.js ≥ 18 is installed

## Managing the server

```bash
# List configured MCP servers
claude mcp list

# Remove the server
claude mcp remove roblox-dex-ai-mcp
```
