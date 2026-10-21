/**
 * GET  /dex/events?since=<seq>  — read pushed DEX events
 * DELETE /dex/events            — clear the store
 *
 * Used by the AI side (via the MCP `get-data-by-code` tool or plain HTTP)
 * to read what the user selected inside the in-game DEX UI.
 */

import type { IncomingMessage, ServerResponse } from "http";
import { clearDexEvents, getDexEvents, getDexStats } from "../../dex-store.js";

export async function GET(_req: IncomingMessage, res: ServerResponse, url: URL): Promise<void> {
  const sinceRaw = url.searchParams.get("since");
  const since = sinceRaw === null ? undefined : Number(sinceRaw);

  const events = getDexEvents(Number.isFinite(since as number) ? (since as number) : undefined);
  const stats = getDexStats();

  res.writeHead(200, { "Content-Type": "application/json" });
  res.end(
    JSON.stringify(
      {
        ok: true,
        since: since ?? null,
        lastSeq: stats.lastSeq,
        count: events.length,
        events,
      },
      null,
      2
    )
  );
}

export async function DELETE(_req: IncomingMessage, res: ServerResponse): Promise<void> {
  const cleared = clearDexEvents();
  res.writeHead(200, { "Content-Type": "application/json" });
  res.end(JSON.stringify({ ok: true, cleared }));
}