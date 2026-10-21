import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendAndWait } from "../../factory.js";
import { threadContextSchema } from "../../schemas.js";

/**
 * dex-select — drive the in-game DEX UI from the AI side.
 *
 * Requires dex-mcp/dex_mcp_A.lua or dex_mcp_B.lua to be loaded, which exposes
 * getgenv().DEX.Select(...) in the Roblox client.
 */
export default function register(server: McpServer): void {
  server.registerTool(
    "dex-select",
    {
      title: "Select objects in DEX",
      description:
        "Select one or more instances inside the running DEX UI, so the user sees them highlighted and the properties panel switches to them. Requires the DEX MCP bridge (dex_mcp_A.lua or dex_mcp_B.lua) to be loaded in the client. Accepts the same path syntax that DEX itself produces, e.g. game.Workspace.Map.NPC or game:GetService(\"ReplicatedStorage\").Mods.",
      inputSchema: z.object({
        paths: z
          .array(z.string())
          .describe(
            'Instance paths to select, e.g. ["game.Workspace.Map.NPC"]. Supports game.Workspace.Foo, game:GetService("X").Y, game.Workspace:GetChildren()[3], and game.Workspace["odd name"].'
          ),
        additive: z
          .boolean()
          .describe("Add to the current selection instead of replacing it. Default false.")
          .optional()
          .default(false),
        threadContext: threadContextSchema,
        timeout: z
          .number()
          .describe("Timeout in milliseconds (default: 15000, max: 120000).")
          .optional()
          .default(15000),
      }),
    },
    async ({ paths, additive, threadContext, timeout }) => {
      if (!Array.isArray(paths) || paths.length === 0) {
        return {
          content: [{ type: "text" as const, text: "No paths supplied." }],
          isError: true,
        };
      }

      const clampedTimeout = Math.min(Math.max(timeout, 1000), 120000);

      const luaPaths = paths
        .map((p) => JSON.stringify(String(p)))
        .join(", ");

      const code = [
        "local DEX = getgenv().DEX",
        'if not DEX then return "ERR: getgenv().DEX not found — load dex_mcp_A.lua or dex_mcp_B.lua first" end',
        `local ok, n = DEX.Select({ ${luaPaths} }, ${additive ? "true" : "false"})`,
        'if not ok then return "ERR: " .. tostring(n) end',
        'return "OK selected " .. tostring(n) .. " object(s)"',
      ].join("\n");

      return sendAndWait({
        type: "get-data-by-code",
        data: { source: `setthreadidentity(${threadContext});${code}` },
        timeoutMs: clampedTimeout,
        failureMessage: (response) =>
          "Failed to select in DEX. Response: " + JSON.stringify(response),
      });
    }
  );
}