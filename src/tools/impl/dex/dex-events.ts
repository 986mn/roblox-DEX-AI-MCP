import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { getDexEvents, getDexStats } from "../../../http/dex-store.js";

/**
 * dex-events — read what the user selected inside the in-game DEX UI.
 *
 * Requires dex-mcp/dex_mcp_A.lua or dex_mcp_C.lua to be loaded in the
 * Roblox client, with getgenv().BridgeURL pointing at this server.
 */
export default function register(server: McpServer): void {
  server.registerTool(
    "dex-events",
    {
      title: "Read DEX selection events",
      description:
        "Read object paths pushed from the in-game DEX bridge. The user clicks the [-> MCP] button (or Ctrl+Shift+M) inside DEX, and the selected instance paths arrive here. Use this to learn exactly which object the user is looking at, instead of guessing from screenshots or descriptions. Returns the newest events first.",
      inputSchema: z.object({
        since: z
          .number()
          .describe(
            "Only return events with seq greater than this value. Omit to get the full recent buffer (up to 200 events)."
          )
          .optional(),
        limit: z
          .number()
          .describe("Maximum number of events to return, newest first (default: 20, max: 200).")
          .optional()
          .default(20),
        clear: z
          .boolean()
          .describe("Clear the event buffer after reading. Default false.")
          .optional()
          .default(false),
      }),
    },
    async ({ since, limit, clear }) => {
      const all = getDexEvents(since);
      const max = Math.min(Math.max(limit ?? 20, 1), 200);
      const selected = all.slice(-max).reverse();

      const stats = getDexStats();

      if (selected.length === 0) {
        return {
          content: [
            {
              type: "text" as const,
              text:
                `No DEX events yet (buffer=${stats.count}, lastSeq=${stats.lastSeq}).\n\n` +
                "To enable this:\n" +
                "1. Load DEX with dex-mcp/dex_mcp_A.lua or dex_mcp_C.lua appended\n" +
                '2. Set getgenv().BridgeURL = "<your-bridge-host>" in the executor\n' +
                "3. Select objects in DEX and click the [-> MCP] button (or Ctrl+Shift+M)",
            },
          ],
        };
      }

      if (clear) {
        const { clearDexEvents } = await import("../../../http/dex-store.js");
        clearDexEvents();
      }

      const lines: string[] = [];
      lines.push(`DEX events: ${selected.length} shown (buffer=${stats.count}, lastSeq=${stats.lastSeq})`);
      if (clear) lines.push("Buffer cleared after read.");
      lines.push("");

      for (const e of selected) {
        lines.push(`#${e.seq}  ${e.receivedAt}  type=${e.type}${e.reason ? ` reason=${e.reason}` : ""}`);
        if (e.paths.length === 0) {
          lines.push("  (no paths)");
        } else {
          for (const p of e.paths) lines.push(`  ${p}`);
        }
        lines.push("");
      }

      // Collect a flat list of unique paths for convenience
      const uniquePaths: string[] = [];
      for (const e of selected) {
        for (const p of e.paths) {
          if (!uniquePaths.includes(p)) uniquePaths.push(p);
        }
      }
      if (uniquePaths.length > 0) {
        lines.push("Latest unique paths:");
        for (const p of uniquePaths) lines.push(`  ${p}`);
      }

      return { content: [{ type: "text" as const, text: lines.join("\n") }] };
    }
  );
}