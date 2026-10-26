/**
 * `npm run fixtures:images:refresh` (fixture-real-uploads) — re-pulls the fixture image selection
 * from the d2m `makeready` image set into `fixtures/images/`: each selected original as
 * `<slug>.jpg` (longest side ≤ SOURCE_WIDTH) and `manifest.json`. Run it on the host, where d2m
 * listens (127.0.0.1); commit the result. Resets read only this folder and never contact d2m.
 */
import { existsSync, readFileSync } from 'node:fs'
import { mkdir, readdir, rm, writeFile } from 'node:fs/promises'
import path from 'node:path'
import sharp from 'sharp'
import { type D2mImage, IMAGE_DIR, MANIFEST_PATH, SOURCE_WIDTH, manifestOf, selectImages, sourceFile } from './images.js'

function d2mApi(): string {
  if (process.env.D2M_API_URL) return process.env.D2M_API_URL.replace(/\/$/, '')
  const config = path.resolve(IMAGE_DIR, '../../../.d2m.json')
  if (existsSync(config)) {
    const api = (JSON.parse(readFileSync(config, 'utf8')) as { api?: string }).api
    if (api) return api.replace(/\/$/, '')
  }
  return 'http://localhost:5961'
}

async function main(): Promise<void> {
  const api = d2mApi()
  const res = await fetch(`${api}/api/projects/makeready/images`, { signal: AbortSignal.timeout(10_000) })
  if (!res.ok) throw new Error(`d2m ${api} answered HTTP ${res.status}`)
  const catalog = ((await res.json()) as { items: D2mImage[] }).items
  const selection = selectImages(catalog)
  const manifest = manifestOf(selection)
  const slugs = Object.keys(manifest.images)

  await mkdir(IMAGE_DIR, { recursive: true })
  for (const slug of slugs) {
    const image = catalog.find((i) => i.slug === slug)!
    const original = await fetch(image.url, { signal: AbortSignal.timeout(30_000) })
    if (!original.ok) throw new Error(`d2m image ${slug}: HTTP ${original.status}`)
    const bytes = Buffer.from(await original.arrayBuffer())
    await writeFile(
      sourceFile(slug),
      await sharp(bytes).rotate().resize(SOURCE_WIDTH, SOURCE_WIDTH, { fit: 'inside', withoutEnlargement: true }).jpeg({ quality: 88 }).toBuffer()
    )
  }
  for (const file of await readdir(IMAGE_DIR)) {
    if (file.endsWith('.jpg') && !slugs.includes(file.slice(0, -4))) await rm(path.join(IMAGE_DIR, file))
  }
  await writeFile(MANIFEST_PATH, `${JSON.stringify(manifest, null, 2)}\n`)
  console.log(`fixtures: ${slugs.length} images from ${api} → ${IMAGE_DIR} — commit them`)
}

main().catch((error: unknown) => {
  console.error(`fixtures:images:refresh failed — ${(error as Error).message}`)
  process.exit(1)
})
