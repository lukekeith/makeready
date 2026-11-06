#!/usr/bin/env node
// Builder's disposable verification checkouts only. Never load the human's env files.
import { spawnSync, execFileSync } from 'node:child_process'
import { lstatSync, mkdtempSync, writeFileSync, readFileSync, rmSync, readdirSync, existsSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { tmpdir, homedir } from 'node:os'

const root = dirname(dirname(fileURLToPath(import.meta.url)))
// The system Node 20.16 is too old for client Vite; prefer an installed modern nvm Node.
const nvmVersions = join(homedir(), '.nvm/versions/node')
const modern = existsSync(nvmVersions) ? readdirSync(nvmVersions).filter(v => /^v\d+\.\d+\.\d+$/.test(v) && Number(v.slice(1).split('.')[0]) >= 22).sort((a, b) => b.localeCompare(a, undefined, { numeric: true }))[0] : null
if (modern) process.env.PATH = `${join(nvmVersions, modern, 'bin')}:${process.env.PATH}`
function run(cmd, args, cwd = root, env = process.env) {
  execFileSync(cmd, args, { cwd, env, stdio: 'inherit' })
}
function noServerEnv() {
  for (const name of ['.env', '.env.test']) {
    try { lstatSync(join(root, 'server', name)) } catch (e) { if (e.code === 'ENOENT') continue; throw e }
    throw new Error(`Verifier refuses server/${name}; use a clean disposable checkout (never read the 1Password pipe)`)
  }
}
const safeEnv = {
  PATH: process.env.PATH,
  NODE_ENV: 'test', APP_ENV: 'testing', APP_KEY: 'base64:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
  API_URL: 'http://127.0.0.1:1', API_BASE_URL: 'http://127.0.0.1:1', CLIENT_URL: 'http://127.0.0.1:1',
  GOOGLE_CLIENT_ID: 'verifier-unconfigured', GOOGLE_CLIENT_SECRET: 'verifier-unconfigured', GOOGLE_CALLBACK_URL: 'http://127.0.0.1:1/auth/google/callback',
  SESSION_SECRET: 'verifier-only', TEST_VERIFICATION_CODES: '123456,000000', EMBEDDINGS_WARMUP: 'false', SEMANTIC_EXPANSION_ENABLED: 'false',
  ANTHROPIC_API_KEY: '', API_BIBLE_KEY: '', CLOUDFLARE_API_TOKEN: '', APNS_KEY_ID: '', APNS_KEY_PATH: '', APNS_TEAM_ID: '',
  TWILIO_ACCOUNT_SID: '', TWILIO_AUTH_TOKEN: '', TWILIO_VERIFY_SERVICE_ID: '', TWILIO_PHONE_NUMBER: '', TWILIO_MESSAGING_SERVICE_SID: '',
  R2_ENDPOINT: 'http://127.0.0.1:1', R2_ACCOUNT_ID: 'verifier', R2_ACCESS_KEY_ID: 'verifier', R2_SECRET_ACCESS_KEY: 'verifier', R2_BUCKET_NAME: 'verifier', R2_PUBLIC_URL: 'http://127.0.0.1:1/verifier',
}

const mode = process.argv[2]
if (mode === 'setup') {
  noServerEnv()
  const env = { ...process.env, ...safeEnv, NODE_ENV: 'development', DATABASE_URL: 'postgresql://postgres:postgres@localhost:5434/postgres', DIRECT_URL: 'postgresql://postgres:postgres@localhost:5434/postgres' }
  run('npm', ['ci'], root, env)
  run('npx', ['--no-install', 'prisma', 'generate'], join(root, 'server'), env)
  run('composer', ['install', '--no-interaction', '--prefer-dist'], join(root, 'client'), env)
} else if (mode === 'db-prepare') {
  noServerEnv()
  const url = new URL(process.env.DATABASE_URL)
  if (!['localhost', '127.0.0.1'].includes(url.hostname) || url.port !== '5434' || !/^\/postgres_vt_tpl_[a-f0-9]+_b_\d+$/.test(url.pathname)) throw new Error('Refusing Atlas apply outside a verifier template build database')
  // Explicit URL and migration directory: no dotenv wrapper, shared Atlas dev DB or migration generation.
  run(join(root, 'server/scripts/atlas.sh'), ['migrate', 'apply', '--url', url.href, '--dir', `file://${join(root, 'server/atlas/migrations')}`], join(root, 'server/atlas'))
  run('npx', ['--no-install', 'tsx', 'scripts/ensure-session-table.ts'], join(root, 'server'))
  // Fixtures require system roles; this seed creates no user/organization fixture data in an empty template.
  run('npx', ['--no-install', 'tsx', 'prisma/seed.ts'], join(root, 'server'))
} else if (mode === 'lease') {
  noServerEnv()
  for (const [key, value] of Object.entries(safeEnv)) console.log(`${key}=${value}`)
  if (process.env.BUILDER_NEED === 'verify-ios') {
    const dir = mkdtempSync(join(tmpdir(), 'makeready-verifier-'))
    let udid
    try {
      udid = execFileSync('xcrun', ['simctl', 'create', `builder-verify-${process.pid}-${Date.now()}`, 'iPhone 17 Pro Max'], { encoding: 'utf8' }).trim()
      writeFileSync(join(dir, 'device'), udid)
      execFileSync('xcrun', ['simctl', 'boot', udid])
      execFileSync('xcrun', ['simctl', 'bootstatus', udid, '-b'], { stdio: ['ignore', 'ignore', 'inherit'] })
      console.log(`SIMULATOR_UDID=${udid}`)
      console.log(`BUILDER_VERIFY_TMP=${dir}`)
    } catch (e) {
      if (udid) spawnSync('xcrun', ['simctl', 'delete', udid])
      rmSync(dir, { recursive: true, force: true })
      throw e
    }
  }
} else if (mode === 'release') {
  if (process.env.BUILDER_NEED === 'verify-ios') {
    const dir = process.env.BUILDER_VERIFY_TMP
    const udid = process.env.SIMULATOR_UDID
    if (!dir?.startsWith(join(tmpdir(), 'makeready-verifier-')) || readFileSync(join(dir, 'device'), 'utf8') !== udid) throw new Error('Refusing to delete a simulator not owned by this verifier lease')
    spawnSync('xcrun', ['simctl', 'shutdown', udid])
    run('xcrun', ['simctl', 'delete', udid])
    rmSync(dir, { recursive: true, force: true })
  }
} else if (mode === 'swiftlint') {
  const cwd = join(root, 'iphone')
  const r = spawnSync('swiftlint', ['lint', '--quiet', '--baseline', '.swiftlint-baseline.json', '--reporter', 'json'], { cwd, encoding: 'utf8' })
  if (r.error) throw r.error
  const findings = JSON.parse(r.stdout)
  for (const f of findings) console.log(`${f.file.replace(`${cwd}/`, '')}:${f.line}:${f.character ?? 0}: ${f.severity}: ${f.rule_id}: ${f.reason}`)
  if (r.status !== 0 && !findings.length) throw new Error(`SwiftLint failed without findings: ${r.stderr}`)
  process.exitCode = r.status
} else if (mode === 'staging-build') {
  // Builds the three configurations the Staging work can break and asserts the built Info.plist values.
  const gitOut = args => { const r = spawnSync('git', args, { cwd: root, encoding: 'utf8' }); return r.status === 0 ? r.stdout.trim() : '' }
  const base = gitOut(['merge-base', 'HEAD', 'main']) || gitOut(['merge-base', 'HEAD', 'origin/main'])
  const watched = ['iphone/Debug.xcconfig', 'iphone/Release.xcconfig', 'iphone/Staging.xcconfig', 'iphone/MakeReady.xcodeproj', 'iphone/MakeReady/Info.plist']
  if (base && !gitOut(['diff', '--name-only', base, 'HEAD', '--', ...watched])) {
    console.log('staging-build: nothing to check')
  } else {
    const iphone = join(root, 'iphone')
    const dir = mkdtempSync(join(tmpdir(), 'makeready-verifier-staging-'))
    try {
      const builds = [['MakeReady Staging', 'Staging'], ['MakeReady', 'Release'], ['MakeReadyCapture', 'Debug']]
      for (const [scheme, configuration] of builds) {
        run('xcodebuild', ['-project', 'MakeReady.xcodeproj', '-scheme', scheme, '-configuration', configuration, '-destination', 'generic/platform=iOS Simulator', '-derivedDataPath', dir, 'CODE_SIGNING_ALLOWED=NO', 'build'], iphone)
      }
      const read = (config, key) => {
        const plist = join(dir, 'Build/Products', `${config}-iphonesimulator`, 'MakeReady.app/Info.plist')
        const r = spawnSync('plutil', ['-extract', key, 'raw', plist], { encoding: 'utf8' })
        return r.status === 0 ? r.stdout.trim() : ''
      }
      const expected = [
        ['Staging', { CFBundleIdentifier: 'com.makeready.app.staging', DEV_MODE: 'YES', CFBundleDisplayName: 'MakeReady-Staging' }],
        ['Release', { CFBundleIdentifier: 'com.makeready.app', DEV_MODE: 'NO', FIXTURE_ACCESS_KEY: '', CFBundleDisplayName: 'MakeReady' }],
      ]
      let failed = false
      for (const [config, keys] of expected) {
        for (const [key, want] of Object.entries(keys)) {
          const got = read(config, key)
          if (got !== want) { console.error(`staging-build: ${config} ${key}: expected "${want}", got "${got}"`); failed = true }
        }
      }
      if (failed) process.exitCode = 1
    } finally {
      spawnSync('git', ['checkout', '--', 'iphone/MakeReady/Info.plist'], { cwd: root })
      rmSync(dir, { recursive: true, force: true })
    }
  }
} else throw new Error(`Unknown verifier operation: ${mode}`)
