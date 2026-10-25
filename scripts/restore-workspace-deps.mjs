#!/usr/bin/env node
// Root `postinstall`: re-installs workspace deps that a single-workspace `npm ci` pruned.
//
// `cd client && npm ci` implicitly runs as `npm ci --workspace=client`: it empties the SHARED
// root node_modules and reinstalls only the client's tree, so every server-only package
// (dotenv-cli, @prisma/client, express-session, ...) disappears and `cd server && npm run ...`
// breaks. npm still runs the ROOT package's lifecycle scripts for that `ci`, so this hook
// checks every workspace's direct deps and, if any are gone, runs one plain root
// `npm install` (lockfile-driven, no package.json or lockfile writes) to put them back.
import { execSync } from 'node:child_process'
import { existsSync, readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

if (process.env.npm_command !== 'ci' || process.env.MAKEREADY_RESTORING_WORKSPACE_DEPS) process.exit(0)

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const rootPkg = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8'))
const omitDev = (process.env.npm_config_omit || '').includes('dev') || process.env.NODE_ENV === 'production'

const missing = []
for (const ws of rootPkg.workspaces || []) {
  const pkgPath = join(root, ws, 'package.json')
  if (!existsSync(pkgPath)) continue
  const pkg = JSON.parse(readFileSync(pkgPath, 'utf8'))
  const deps = { ...pkg.dependencies, ...(omitDev ? {} : pkg.devDependencies) }
  for (const dep of Object.keys(deps)) {
    if (!existsSync(join(root, 'node_modules', dep)) && !existsSync(join(root, ws, 'node_modules', dep))) {
      missing.push(`${ws}:${dep}`)
    }
  }
}
if (missing.length === 0) process.exit(0)

console.log(`[restore-workspace-deps] ${missing.length} workspace deps pruned by a single-workspace npm ci (${missing.slice(0, 5).join(', ')}${missing.length > 5 ? ', ...' : ''}) — restoring`)
const env = { ...process.env, MAKEREADY_RESTORING_WORKSPACE_DEPS: '1' }
for (const key of Object.keys(env)) if (/^npm_config_workspaces?$/i.test(key)) delete env[key]
execSync('npm install --no-save --no-audit --no-fund', { cwd: root, env, stdio: 'inherit' })
