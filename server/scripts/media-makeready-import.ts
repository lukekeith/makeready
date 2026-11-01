/**
 * `npm run media:makeready:import -- --api <server url>` (media-library D15) — loads d2m's cover images
 * into MakeReady's own media library through the super-admin API, so it runs against any server
 * (production included) without touching a database. Needs d2m on this machine and a super-admin API
 * key in MAKEREADY_API_KEY. Idempotent: a slug already imported answers 409 and is skipped.
 *
 *   MAKEREADY_API_KEY=mr_… npm run media:makeready:import -- --api https://api.makeready.org
 *
 * Fixture resets do not use this; they import the committed images through the service directly.
 */
import { existsSync, readFileSync } from 'node:fs'
import path from 'node:path'
import sharp from 'sharp'
import { catalogCovers, type D2mCatalogImage } from '../src/services/makeready-media.js'

function arg(name: string): string | undefined {
  const i = process.argv.indexOf(`--${name}`)
  return i >= 0 ? process.argv[i + 1] : undefined
}

function d2mApi(): string {
  if (process.env.D2M_API_URL) return process.env.D2M_API_URL.replace(/\/$/, '')
  const config = path.resolve(import.meta.dirname, '../../.d2m.json')
  if (existsSync(config)) {
    const api = (JSON.parse(readFileSync(config, 'utf8')) as { api?: string }).api
    if (api) return api.replace(/\/$/, '')
  }
  return 'http://localhost:5961'
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms))

async function post(api: string, key: string, body: unknown): Promise<number> {
  for (let attempt = 0; attempt < 6; attempt++) {
    const res = await fetch(`${api}/api/makeready/media`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}`, 'User-Agent': 'Mozilla/5.0 makeready-import' },
      body: JSON.stringify(body),
    })
    if (res.status !== 429) return res.status
    await sleep(Number(res.headers.get('retry-after') ?? 1) * 1000 * (attempt + 1))
  }
  return 429
}

async function main(): Promise<void> {
  const api = (arg('api') ?? 'http://localhost:3010').replace(/\/$/, '')
  const key = process.env.MAKEREADY_API_KEY
  if (!key) throw new Error('set MAKEREADY_API_KEY to a super-admin API key')
  const d2m = d2mApi()
  const res = await fetch(`${d2m}/api/projects/makeready/images`, { signal: AbortSignal.timeout(10_000) })
  if (!res.ok) throw new Error(`d2m ${d2m} answered HTTP ${res.status}`)
  const covers = catalogCovers(((await res.json()) as { items: D2mCatalogImage[] }).items)
  const tally = { created: 0, skipped: 0, failed: 0 }
  for (const cover of covers) {
    const original = await fetch(cover.url, { signal: AbortSignal.timeout(30_000) })
    if (!original.ok) { tally.failed++; console.error(`  ✗ ${cover.slug}: d2m HTTP ${original.status}`); continue }
    // F10: under the 10 MB JSON body limit — 1200px longest side, as the server stores it.
    const jpeg = await sharp(Buffer.from(await original.arrayBuffer())).rotate().resize(1200, 1200, { fit: 'inside', withoutEnlargement: true }).jpeg({ quality: 88 }).toBuffer()
    const status = await post(api, key, {
      imageData: jpeg.toString('base64'), title: cover.title, description: cover.alt ?? undefined,
      altText: cover.alt ?? undefined, tags: cover.tags, d2mSlug: cover.slug,
    })
    if (status === 201) tally.created++
    else if (status === 409) tally.skipped++
    else { tally.failed++; console.error(`  ✗ ${cover.slug}: HTTP ${status}`) }
  }
  console.log(`MakeReady import → ${api}: ${tally.created} created · ${tally.skipped} already there · ${tally.failed} failed (of ${covers.length})`)
  if (tally.failed) process.exit(1)
}

main().catch((error: unknown) => {
  console.error(`media:makeready:import failed — ${(error as Error).message}`)
  process.exit(1)
})
