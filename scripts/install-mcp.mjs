#!/usr/bin/env node
/**
 * install-mcp.mjs — one-command MCP client setup for roblox-DEX-AI-MCP
 *
 * Detects which AI clients you have installed, and writes the MCP server
 * entry into each one's config file. Safe to re-run: it merges rather than
 * overwrites, and preserves everything else already in the file.
 *
 * Usage:
 *   node scripts/install-mcp.mjs                # interactive: pick clients
 *   node scripts/install-mcp.mjs --all          # configure every detected client
 *   node scripts/install-mcp.mjs --client cursor,claude-desktop
 *   node scripts/install-mcp.mjs --print        # just print the JSON, write nothing
 *   node scripts/install-mcp.mjs --remove       # remove the entry everywhere
 *   node scripts/install-mcp.mjs --yes          # don't prompt, assume yes
 *
 * Written by deepseek-v4.1-flash.
 */

import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import readline from "node:readline";
import { fileURLToPath } from "node:url";

const SERVER_NAME = "roblox-dex-ai-mcp";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, "..");
const SERVER_ENTRY = path.join(REPO_ROOT, "dist", "index.js");

const isWin = process.platform === "win32";
const HOME = os.homedir();
const APPDATA = process.env.APPDATA || path.join(HOME, "AppData", "Roaming");

/* ------------------------------------------------------------------ */
/*  Client registry                                                    */
/* ------------------------------------------------------------------ */

/**
 * Each client describes:
 *   id        unique key
 *   label     human name
 *   format    "json" | "toml" | "cli"
 *   paths     candidate config paths (first existing wins)
 *   detect    candidate install paths used to decide "is this installed"
 *   note      optional hint shown to the user
 */
const CLIENTS = [
  {
    id: "claude-desktop",
    label: "Claude Desktop",
    format: "json",
    paths: isWin
      ? [path.join(APPDATA, "Claude", "claude_desktop_config.json")]
      : [
          path.join(HOME, "Library", "Application Support", "Claude", "claude_desktop_config.json"),
          path.join(HOME, ".config", "Claude", "claude_desktop_config.json"),
        ],
    detect: isWin
      ? [path.join(APPDATA, "Claude")]
      : [
          path.join(HOME, "Library", "Application Support", "Claude"),
          path.join(HOME, ".config", "Claude"),
        ],
    note: "Fully quit and reopen Claude Desktop after installing.",
  },
  {
    id: "cursor",
    label: "Cursor",
    format: "json",
    paths: [path.join(HOME, ".cursor", "mcp.json")],
    detect: [path.join(HOME, ".cursor")],
    note: "Reload the window, or Settings > Features > MCP > refresh.",
  },
  {
    id: "windsurf",
    label: "Windsurf",
    format: "json",
    paths: [path.join(HOME, ".codeium", "windsurf", "mcp_config.json")],
    detect: [path.join(HOME, ".codeium", "windsurf")],
    note: "Reload the window for Cascade to pick it up.",
  },
  {
    id: "antigravity",
    label: "Antigravity",
    format: "json",
    paths: [
      path.join(HOME, ".gemini", "antigravity", "mcp_config.json"),
      path.join(HOME, ".gemini", "config", "mcp_config.json"),
    ],
    detect: [path.join(HOME, ".gemini")],
    note: "Use the Refresh button next to 'View raw config'.",
  },
  {
    id: "claude-code",
    label: "Claude Code (CLI)",
    format: "json",
    paths: [path.join(HOME, ".claude.json")],
    detect: [path.join(HOME, ".claude.json"), path.join(HOME, ".claude")],
    note: "Or run: claude mcp add roblox-dex-ai-mcp -- node <repo>/dist/index.js",
  },
  {
    id: "codex",
    label: "Codex CLI",
    format: "toml",
    paths: [path.join(HOME, ".codex", "config.toml")],
    detect: [path.join(HOME, ".codex")],
    note: "Restart your Codex session.",
  },
  {
    id: "vscode",
    label: "VS Code (Copilot MCP)",
    format: "json",
    paths: [path.join(HOME, ".vscode", "mcp.json")],
    detect: [path.join(HOME, ".vscode")],
    note: "Requires the MCP-enabled Copilot build.",
  },
];

/* ------------------------------------------------------------------ */
/*  Terminal helpers                                                   */
/* ------------------------------------------------------------------ */

const C = {
  reset: "\x1b[0m",
  dim: "\x1b[2m",
  bold: "\x1b[1m",
  red: "\x1b[31m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  cyan: "\x1b[36m",
};

const say = (s) => console.log(`${C.cyan}[mcp]${C.reset} ${s}`);
const ok = (s) => console.log(`${C.cyan}[mcp]${C.reset} ${C.green}${s}${C.reset}`);
const warn = (s) => console.log(`${C.cyan}[mcp!]${C.reset} ${C.yellow}${s}${C.reset}`);
const die = (s) => {
  console.log(`${C.cyan}[mcp!]${C.reset} ${C.red}${s}${C.reset}`);
  process.exit(1);
};

/* ------------------------------------------------------------------ */
/*  Arg parsing                                                        */
/* ------------------------------------------------------------------ */

const argv = process.argv.slice(2);
const has = (f) => argv.includes(f);
const val = (f) => {
  const i = argv.indexOf(f);
  return i >= 0 && argv[i + 1] && !argv[i + 1].startsWith("--") ? argv[i + 1] : null;
};

const MODE = {
  all: has("--all"),
  print: has("--print"),
  remove: has("--remove"),
  yes: has("--yes") || has("-y"),
  plain: has("--plain"),
  help: has("--help") || has("-h"),
};

const explicitClients = (val("--client") || "")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);

if (MODE.help) {
  console.log(`
${C.bold}roblox-DEX-AI-MCP · MCP client installer${C.reset}

  node scripts/install-mcp.mjs                 interactive picker
  node scripts/install-mcp.mjs --all           configure every detected client
  node scripts/install-mcp.mjs --client a,b    configure specific clients
  node scripts/install-mcp.mjs --print         print config, write nothing
  node scripts/install-mcp.mjs --remove        remove the entry everywhere
  node scripts/install-mcp.mjs --yes           skip confirmation
  node scripts/install-mcp.mjs --plain         no fancy output

Clients: ${CLIENTS.map((c) => c.id).join(", ")}
Server entry: ${SERVER_ENTRY}
`);
  process.exit(0);
}

/* ------------------------------------------------------------------ */
/*  Build the server entry                                             */
/* ------------------------------------------------------------------ */

function serverEntry() {
  return {
    command: "node",
    args: [SERVER_ENTRY],
    env: {},
  };
}

/* ------------------------------------------------------------------ */
/*  JSON merge                                                         */
/* ------------------------------------------------------------------ */

function readJson(file) {
  if (!fs.existsSync(file)) return {};
  const raw = fs.readFileSync(file, "utf8").trim();
  if (!raw) return {};
  try {
    return JSON.parse(raw);
  } catch (e) {
    throw new Error(`existing file is not valid JSON: ${file}\n  ${e.message}`);
  }
}

function writeJson(file, obj) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  // keep a one-time backup
  if (fs.existsSync(file)) {
    const bak = file + ".bak";
    if (!fs.existsSync(bak)) fs.copyFileSync(file, bak);
  }
  fs.writeFileSync(file, JSON.stringify(obj, null, 2) + "\n", "utf8");
}

function mergeJsonClient(client, remove) {
  const file = client.paths.find((p) => fs.existsSync(p)) || client.paths[0];
  const data = readJson(file);

  if (!data.mcpServers || typeof data.mcpServers !== "object") {
    data.mcpServers = {};
  }

  const present = Boolean(data.mcpServers[SERVER_NAME]);

  if (remove) {
    if (!present) return { file, action: "absent" };
    delete data.mcpServers[SERVER_NAME];
    writeJson(file, data);
    return { file, action: "removed" };
  }

  data.mcpServers[SERVER_NAME] = serverEntry();
  writeJson(file, data);
  return { file, action: present ? "updated" : "added" };
}

/* ------------------------------------------------------------------ */
/*  TOML merge (Codex)                                                 */
/* ------------------------------------------------------------------ */

function tomlBlock() {
  const p = SERVER_ENTRY.replace(/\\/g, "\\\\");
  return [
    `[mcp_servers.${SERVER_NAME}]`,
    `command = "node"`,
    `args = ["${p}"]`,
    "",
  ].join("\n");
}

function mergeTomlClient(client, remove) {
  const file = client.paths.find((p) => fs.existsSync(p)) || client.paths[0];
  let text = "";
  if (fs.existsSync(file)) text = fs.readFileSync(file, "utf8");

  const marker = `[mcp_servers.${SERVER_NAME}]`;
  const idx = text.indexOf(marker);

  if (remove) {
    if (idx < 0) return { file, action: "absent" };
    // cut from marker to the next top-level table header
    const rest = text.slice(idx + marker.length);
    const nextHeader = rest.search(/\n\[(?!mcp_servers\.roblox-dex-ai-mcp)/);
    const before = text.slice(0, idx);
    const after = nextHeader >= 0 ? rest.slice(nextHeader + 1) : "";
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, (before + after).replace(/\n{3,}/g, "\n\n").trimEnd() + "\n", "utf8");
    return { file, action: "removed" };
  }

  if (idx >= 0) {
    // replace existing block
    const rest = text.slice(idx + marker.length);
    const nextHeader = rest.search(/\n\[(?!mcp_servers\.roblox-dex-ai-mcp)/);
    const before = text.slice(0, idx);
    const after = nextHeader >= 0 ? rest.slice(nextHeader + 1) : "";
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, before + tomlBlock() + "\n" + after, "utf8");
    return { file, action: "updated" };
  }

  fs.mkdirSync(path.dirname(file), { recursive: true });
  const sep = text.length && !text.endsWith("\n") ? "\n\n" : text.length ? "\n" : "";
  fs.writeFileSync(file, text + sep + tomlBlock(), "utf8");
  return { file, action: "added" };
}

/* ------------------------------------------------------------------ */
/*  Detection                                                          */
/* ------------------------------------------------------------------ */

function isInstalled(client) {
  if (client.detect.some((p) => fs.existsSync(p))) return true;
  if (client.paths.some((p) => fs.existsSync(p))) return true;
  return false;
}

/* ------------------------------------------------------------------ */
/*  Preflight                                                          */
/* ------------------------------------------------------------------ */

function preflight() {
  if (!fs.existsSync(SERVER_ENTRY)) {
    console.log();
    warn(`server entry not built yet: ${SERVER_ENTRY}`);
    warn("run this first:");
    console.log(`     ${C.bold}npm install --ignore-scripts --no-package-lock${C.reset}`);
    console.log(`     ${C.bold}npm run build${C.reset}`);
    console.log();
    if (!MODE.print) die("aborting — build the server, then re-run");
    warn("continuing anyway because --print writes nothing");
  }
}

/* ------------------------------------------------------------------ */
/*  Interactive picker                                                 */
/* ------------------------------------------------------------------ */

function ask(question) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => rl.question(question, (a) => {
    rl.close();
    resolve(a.trim());
  }));
}

async function pick() {
  const detected = CLIENTS.map((c) => ({ c, installed: isInstalled(c) }));

  console.log();
  console.log(`${C.bold}Detected MCP clients${C.reset}`);
  console.log();
  detected.forEach((d, i) => {
    const mark = d.installed ? `${C.green}●${C.reset}` : `${C.dim}○${C.reset}`;
    const tag = d.installed ? "" : ` ${C.dim}(not found)${C.reset}`;
    console.log(`  ${String(i + 1).padStart(2)}. ${mark} ${d.c.label.padEnd(22)}${tag}`);
  });
  console.log();
  console.log(`  ${C.green}●${C.reset} = installed   ${C.dim}○ = not found${C.reset}`);
  console.log();

  const answer = await ask(
    `Configure which? [${C.bold}a${C.reset}]ll detected, a list like ${C.bold}1,3${C.reset}, or ${C.bold}n${C.reset} to cancel: `
  );

  if (!answer || answer.toLowerCase() === "n") {
    say("cancelled");
    process.exit(0);
  }

  if (answer.toLowerCase() === "a") {
    return detected.filter((d) => d.installed).map((d) => d.c);
  }

  const picks = answer
    .split(/[,\s]+/)
    .map((s) => parseInt(s, 10))
    .filter((n) => Number.isInteger(n) && n >= 1 && n <= detected.length);

  if (picks.length === 0) die("no valid selection");

  return picks.map((n) => detected[n - 1].c);
}

/* ------------------------------------------------------------------ */
/*  Main                                                               */
/* ------------------------------------------------------------------ */

async function main() {
  console.log();
  console.log(`${C.bold}roblox-DEX-AI-MCP${C.reset} · MCP client installer`);
  console.log(`${C.dim}server: ${SERVER_ENTRY}${C.reset}`);
  console.log(`${C.dim}name:   ${SERVER_NAME}${C.reset}`);
  console.log();

  preflight();

  if (MODE.print) {
    console.log(`${C.bold}JSON (Claude Desktop / Cursor / Windsurf / Antigravity / VS Code):${C.reset}`);
    console.log(JSON.stringify({ mcpServers: { [SERVER_NAME]: serverEntry() } }, null, 2));
    console.log();
    console.log(`${C.bold}TOML (Codex CLI):${C.reset}`);
    console.log(tomlBlock());
    console.log();
    console.log(`${C.bold}Claude Code CLI:${C.reset}`);
    console.log(`  claude mcp add ${SERVER_NAME} -- node "${SERVER_ENTRY}"`);
    console.log();
    return;
  }

  let targets;
  if (explicitClients.length) {
    targets = CLIENTS.filter((c) => explicitClients.includes(c.id));
    const unknown = explicitClients.filter((id) => !CLIENTS.some((c) => c.id === id));
    if (unknown.length) warn(`unknown client id(s): ${unknown.join(", ")}`);
    if (!targets.length) die("no matching clients");
  } else if (MODE.all) {
    targets = CLIENTS.filter(isInstalled);
    if (!targets.length) die("no clients detected — use --client to force one");
  } else {
    targets = await pick();
  }

  if (!targets.length) die("nothing to do");

  const verb = MODE.remove ? "Removing from" : "Configuring";
  console.log(`${verb}: ${targets.map((c) => c.label).join(", ")}`);
  console.log();

  const results = [];
  for (const client of targets) {
    try {
      const r =
        client.format === "toml"
          ? mergeTomlClient(client, MODE.remove)
          : mergeJsonClient(client, MODE.remove);
      results.push({ client, ...r, error: null });
    } catch (e) {
      results.push({ client, file: client.paths[0], action: "failed", error: e.message });
    }
  }

  console.log(`${C.bold}Results${C.reset}`);
  console.log();
  for (const r of results) {
    const label = r.client.label.padEnd(22);
    if (r.error) {
      console.log(`  ${C.red}✗${C.reset} ${label} ${C.red}${r.error}${C.reset}`);
    } else {
      const icon = r.action === "absent" ? `${C.dim}·${C.reset}` : `${C.green}✓${C.reset}`;
      console.log(`  ${icon} ${label} ${r.action.padEnd(9)} ${C.dim}${r.file}${C.reset}`);
    }
  }
  console.log();

  const withNotes = results.filter((r) => !r.error && r.action !== "absent" && r.client.note);
  if (withNotes.length && !MODE.remove) {
    console.log(`${C.bold}Next step for each client${C.reset}`);
    console.log();
    for (const r of withNotes) {
      console.log(`  ${r.client.label}`);
      console.log(`    ${C.dim}${r.client.note}${C.reset}`);
    }
    console.log();
  }

  const failed = results.filter((r) => r.error);
  if (failed.length) {
    console.log();
    warn(`${failed.length} client(s) failed — see above`);
    process.exitCode = 1;
  } else {
    ok(`done${MODE.remove ? "" : " — restart your AI client to pick up the server"}`);
    console.log();
  }
}

main().catch((e) => die(e.stack || e.message));
