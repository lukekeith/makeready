/**
 * Client analytics tracker — the web half of the event-ingestion pipe
 * (docs/features/analytics/event-ingestion.md).
 *
 * `track(eventType, ctx)` queues an event in memory with a client-generated
 * UUID (the server's idempotency key) and a client timestamp. Batches flush:
 *   - every 10 seconds,
 *   - immediately at queue ≥ 20,
 *   - on visibilitychange→hidden / pagehide via navigator.sendBeacon
 *     (keepalive-fetch fallback) — the page-close path is where naive
 *     implementations lose the last events.
 *
 * Delivery goes through the Laravel member proxy (POST /member/analytics/events
 * → server POST /api/analytics/events) so the member's server session rides
 * along. The route is CSRF-exempt because sendBeacon cannot send headers.
 *
 * Failure policy: network/5xx failures retry on the next flush with the SAME
 * UUIDs (idempotent server-side); 4xx batches are dropped (client bug — a
 * retry loop can't fix an unregistered event type); everything is dropped
 * after 24h. Errors are NEVER surfaced to members — a lost analytics batch
 * must never break the lesson player.
 *
 * Event types MUST be registered server-side first
 * (server/src/services/analytics-metrics.ts CLIENT_EVENT_TYPES) — unknown
 * types are rejected with a 400. That registration step is the tracking-plan
 * discipline; see event-ingestion.md § The extensibility recipe.
 */

export interface TrackContext {
  enrollmentId?: string
  lessonScheduleId?: string
  scheduledActivityId?: string
  value?: number
  metadata?: Record<string, unknown>
}

interface QueuedEvent extends TrackContext {
  id: string
  eventType: string
  occurredAt: string
  /** Local enqueue instant, for the 24h drop rule. Stripped before send. */
  queuedAt: number
}

const ENDPOINT = '/member/analytics/events'
const FLUSH_INTERVAL_MS = 10_000
const FLUSH_THRESHOLD = 20
const MAX_BATCH = 50
const MAX_AGE_MS = 24 * 60 * 60 * 1000

let queue: QueuedEvent[] = []
let timer: ReturnType<typeof setInterval> | null = null
let lifecycleBound = false
let flushing = false

function toPayload(events: QueuedEvent[]): string {
  return JSON.stringify({
    events: events.map(({ queuedAt: _queuedAt, ...event }) => event),
  })
}

function pruneExpired() {
  const cutoff = Date.now() - MAX_AGE_MS
  queue = queue.filter((e) => e.queuedAt > cutoff)
}

async function flush(): Promise<void> {
  if (flushing) return
  pruneExpired()
  if (queue.length === 0) return
  const batch = queue.slice(0, MAX_BATCH)
  flushing = true
  try {
    const res = await fetch(ENDPOINT, {
      method: 'POST',
      credentials: 'same-origin',
      headers: {
        'Content-Type': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
      },
      body: toPayload(batch),
    })
    if (res.ok) {
      const sent = new Set(batch.map((e) => e.id))
      queue = queue.filter((e) => !sent.has(e.id))
    } else if (res.status >= 400 && res.status < 500 && res.status !== 429) {
      // Client-side bug (unregistered type, auth expiry, …) — retrying the
      // identical batch can never succeed. Drop it, quietly.
      const dropped = new Set(batch.map((e) => e.id))
      queue = queue.filter((e) => !dropped.has(e.id))
      console.debug('[analytics] batch dropped:', res.status)
    }
    // 5xx / 429: keep the batch, same UUIDs retry on the next flush.
  } catch {
    // Network failure — retry next flush.
  } finally {
    flushing = false
  }
}

/**
 * Page-close flush. sendBeacon queues the request with the browser and
 * survives unload; there is no response to inspect, but the client UUIDs make
 * an eventual duplicate delivery harmless.
 */
function flushBeacon() {
  pruneExpired()
  if (queue.length === 0) return
  const batch = queue.slice(0, MAX_BATCH)
  const payload = toPayload(batch)
  let queued = false
  if (typeof navigator.sendBeacon === 'function') {
    try {
      queued = navigator.sendBeacon(ENDPOINT, new Blob([payload], { type: 'application/json' }))
    } catch {
      queued = false
    }
  }
  if (!queued) {
    void fetch(ENDPOINT, {
      method: 'POST',
      credentials: 'same-origin',
      keepalive: true,
      headers: {
        'Content-Type': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
      },
      body: payload,
    }).catch(() => {})
  }
  const sent = new Set(batch.map((e) => e.id))
  queue = queue.filter((e) => !sent.has(e.id))
}

function ensureLifecycle() {
  if (timer === null) {
    timer = setInterval(() => void flush(), FLUSH_INTERVAL_MS)
  }
  if (!lifecycleBound) {
    lifecycleBound = true
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'hidden') flushBeacon()
    })
    window.addEventListener('pagehide', flushBeacon)
  }
}

/**
 * Queue an analytics event. Fire-and-forget: never throws, never blocks,
 * never surfaces an error to the member.
 *
 * Send only the NARROW ids (enrollmentId / lessonScheduleId /
 * scheduledActivityId) — the server derives and validates every other
 * dimension (org, group, program, day number, activity type) itself.
 */
export function track(eventType: string, context: TrackContext = {}): void {
  try {
    queue.push({
      id: crypto.randomUUID(),
      eventType,
      occurredAt: new Date().toISOString(),
      ...context,
      queuedAt: Date.now(),
    })
    ensureLifecycle()
    if (queue.length >= FLUSH_THRESHOLD) void flush()
  } catch {
    // Analytics must never break the player.
  }
}
