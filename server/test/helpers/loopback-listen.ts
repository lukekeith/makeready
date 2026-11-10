/**
 * Test-only: supertest's per-request server binds 127.0.0.1, not Node's `::` wildcard.
 *
 * Why: `request(app)` calls `app.listen(0)` — which binds `::` — and then connects to `http://127.0.0.1:<port>`.
 * On macOS a `::` bind can be handed a port that another local process already holds on 127.0.0.1 (Tailscale,
 * codex, other node servers), and that process wins the connection: a 401 or 405 with foreign headers, a reset,
 * or a socket that never answers. That was the random one-request failure in old-activity-routes-removed (device
 * probe 2026-11-10: 5 of 3,600 requests, every one on a port `lsof` showed held on 127.0.0.1 by another process).
 *
 * A 127.0.0.1 bind refuses a taken port, so the request always reaches the app under test. Node resolves a listen
 * host asynchronously, so the bind cannot happen in supertest's synchronous `serverAddress()`: it is deferred to
 * `end()` (every `await` / `.expect(cb)` path), which waits for `listening` and then sets the real URL.
 */
import type { Server } from 'node:http'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
const LOOPBACK = '127.0.0.1'
const PENDING = 'http://127.0.0.1:0'

type Pending = { server: Server; path: string; https: boolean }

export function installLoopbackListen(): void {
  const Test = require('supertest/lib/test.js')
  const proto = Test.prototype as {
    serverAddress: (app: Server, path: string) => string
    end: (fn?: unknown) => unknown
    loopbackInstalled?: boolean
  }
  if (proto.loopbackInstalled) return
  proto.loopbackInstalled = true
  const { Server: HttpsServer } = require('node:https')
  const originalServerAddress = proto.serverAddress
  const originalEnd = proto.end

  proto.serverAddress = function (this: { _loopback?: Pending }, app: Server, path: string) {
    if (app.address()) return originalServerAddress.call(this, app, path)
    this._loopback = { server: app, path, https: app instanceof HttpsServer }
    return PENDING + path
  }

  proto.end = function (this: { _loopback?: Pending; _server?: Server; url: string }, fn?: unknown) {
    const pending = this._loopback
    if (!pending) return originalEnd.call(this, fn)
    this._loopback = undefined
    pending.server.listen(0, LOOPBACK, () => {
      const address = pending.server.address()
      const port = typeof address === 'object' && address ? address.port : 0
      this._server = pending.server
      this.url = `${pending.https ? 'https' : 'http'}://${LOOPBACK}:${port}${pending.path}`
      originalEnd.call(this, fn)
    })
    return this
  }
}
