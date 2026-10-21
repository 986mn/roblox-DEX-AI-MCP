/**
 * DEX event store.
 *
 * Holds the latest events pushed by the DEX in-game bridge
 * (see dex-mcp/dex_mcp_A.lua and dex_mcp_C.lua, which POST to /dex/event).
 *
 * Kept in memory only — events are transient and re-sent on selection change.
 */

export interface DexEvent {
  /** Monotonic sequence number assigned by the server. */
  seq: number;
  /** ISO timestamp of receipt. */
  receivedAt: string;
  /** Event type, e.g. "selection". */
  type: string;
  /** Why it was sent: "button" | "context-menu" | "hotkey" | "manual" | ... */
  reason?: string;
  /** Client-reported time string. */
  time?: string;
  /** Instance paths selected in DEX. */
  paths: string[];
  /** Full snapshot payload when supplied. */
  data?: unknown;
  /** Which Roblox client this came from, when known. */
  clientId?: string;
}

const MAX_EVENTS = 200;

let seq = 0;
const events: DexEvent[] = [];

export function pushDexEvent(input: {
  type?: string;
  reason?: string;
  time?: string;
  paths?: string[];
  data?: unknown;
  clientId?: string;
}): DexEvent {
  const paths = Array.isArray(input.paths)
    ? input.paths.filter((p): p is string => typeof p === "string" && p.length > 0)
    : [];

  const event: DexEvent = {
    seq: ++seq,
    receivedAt: new Date().toISOString(),
    type: typeof input.type === "string" && input.type ? input.type : "selection",
    reason: typeof input.reason === "string" ? input.reason : undefined,
    time: typeof input.time === "string" ? input.time : undefined,
    paths,
    data: input.data,
    clientId: typeof input.clientId === "string" ? input.clientId : undefined,
  };

  events.push(event);
  while (events.length > MAX_EVENTS) events.shift();

  return event;
}

/** Return events newer than `sinceSeq` (all events when omitted). */
export function getDexEvents(sinceSeq?: number): DexEvent[] {
  if (typeof sinceSeq !== "number" || !Number.isFinite(sinceSeq)) {
    return events.slice();
  }
  return events.filter((e) => e.seq > sinceSeq);
}

/** Most recent event, if any. */
export function getLatestDexEvent(): DexEvent | null {
  return events.length > 0 ? events[events.length - 1] : null;
}

/** Clear the store. Returns how many events were dropped. */
export function clearDexEvents(): number {
  const count = events.length;
  events.length = 0;
  return count;
}

/** Stats for the dashboard. */
export function getDexStats(): { count: number; lastSeq: number; latest: DexEvent | null } {
  return {
    count: events.length,
    lastSeq: seq,
    latest: getLatestDexEvent(),
  };
}
