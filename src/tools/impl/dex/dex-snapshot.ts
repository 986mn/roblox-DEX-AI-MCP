import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendAndWait } from "../../factory.js";
import { threadContextSchema } from "../../schemas.js";

/**
 * dex-snapshot — read the live DEX state (current selection, loaded apps, queue).
 *
 * Requires dex-mcp/dex_mcp_A.lua or dex_mcp_B.lua (both expose DEX.Snapshot()).
 */
export default function register(server: McpServer): void {
  server.registerTool(
    "dex-snapshot",
    {
      title: "Read DEX state snapshot",
      description:
        "Read the current state of the in-game DEX UI: which instances are selected (with names, classes and paths), which app panels exist, and how many paths are queued. This is the fastest way to know what the user is looking at right now. Requires the DEX MCP bridge (dex_mcp_A.lua or dex_mcp_B.lua) to be loaded.",
      inputSchema: z.object({
        threadContext: threadContextSchema,
        timeout: z
          .number()
          .describe("Timeout in milliseconds (default: 15000, max: 120000).")
          .optional()
          .default(15000),
      }),
    },
    async ({ threadContext, timeout }) => {
      const clampedTimeout = Math.min(Math.max(timeout, 1000), 120000);

      const code = [
        "local DEX = getgenv().DEX",
        'if not DEX then return "ERR: getgenv().DEX not found — load dex_mcp_A.lua or dex_mcp_B.lua first" end',
        "local s = DEX.Snapshot()",
        'local HttpService = game:GetService("HttpService")',
        "return HttpService:JSONEncode(s)",
      ].join("\n");

      return sendAndWait({
        type: "get-data-by-code",
        data: { source: `setthreadidentity(${threadContext});${code}` },
        timeoutMs: clampedTimeout,
        failureMessage: (response) =>
          "Failed to read DEX snapshot. Response: " + JSON.stringify(response),
      });
    }
  );
}