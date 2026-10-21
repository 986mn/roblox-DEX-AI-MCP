/**
 * POST /dex/event
 *
 * Receives selection events pushed from the in-game DEX bridge
 * (dex-mcp/dex_mcp_A.lua or dex_mcp_C.lua).
 *
 * Body shape (all fields optional):
 *   { type?, reason?, time?, paths?: string[], data?: any }
 *
 * Responds 204 with no body on success, which is what the Luau side checks.
 */

import type { IncomingMessage, ServerResponse } from "http";
import { readJsonBody } from "../../body.js";
import { pushDexEvent } from "../../dex-store.js";

interface DexEventBody {
  type?: unknown;
  reason?: unknown;
  time?: unknown;
  paths?: unknown;
  data?: unknown;
  clientId?: unknown;
}

export async function POST(req: IncomingMessage, res: ServerResponse): Promise<void> {
  let body: DexEventBody;
  try {
    body = await readJsonBody<DexEventBody>(req);
  } catch {
    res.writeHead(400, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ ok: false, error: "invalid JSON body" }));
    return;
  }

  const event = pushDexEvent({
    type: typeof body.type === "string" ? body.type : undefined,
    reason: typeof body.reason === "string" ? body.reason : undefined,
    time: typeof body.time === "string" ? body.time : undefined,
    paths: Array.isArray(body.paths) ? (body.paths as string[]) : undefined,
    data: body.data,
    clientId: typeof body.clientId === "string" ? body.clientId : undefined,
  });

  console.error(
    `[Dex] #${event.seq} ${event.type}` +
      (event.reason ? ` (${event.reason})` : "") +
      ` — ${event.paths.length} path(s)`
  );

  res.writeHead(204);
  res.end();
}

/** GET /dex/event — convenience for debugging in a browser. */
export async function GET(_req: IncomingMessage, res: ServerResponse): Promise<void> {
  const { getDexStats } = await import("../../dex-store.js");
  const stats = getDexStats();
  res.writeHead(200, { "Content-Type": "application/json" });
  res.end(JSON.stringify({ ok: true, ...stats }, null, 2));
}
