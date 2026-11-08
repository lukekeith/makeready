import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(__dirname, '..')
const docker = () => readFileSync(resolve(root, 'Dockerfile'), 'utf8')
const pkg = () => JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8'))

describe('boot chain (D30)', () => {
  it('boot runs migrations and the server only', () => {
    for (const s of [docker(), pkg().scripts.start]) expect(s).not.toMatch(/load-themes|backfill/)
    expect(docker()).toMatch(/migrate apply/)
    expect(docker()).toMatch(/node dist\/index\.js/)
  })

  it('has no themes or study-sync npm scripts', () => {
    expect(pkg().scripts['themes:load']).toBeUndefined()
    expect(pkg().scripts['backfill:study-sync']).toBeUndefined()
  })
})
