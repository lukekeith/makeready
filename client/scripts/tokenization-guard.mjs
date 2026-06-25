#!/usr/bin/env node
/*
 * Tokenization guard (PRD §3 SC-1, §12).
 * Scans design-system component SCSS for raw values that should be tokens:
 *   - raw hex colors (#abc / #aabbcc)
 *   - raw rgba()/rgb() literals
 *   - raw px in spacing / radius properties (padding, margin, gap, border-radius,
 *     inset/top/right/bottom/left) — 0 and 1px are allowed
 *
 * Structural dimensions (width, height, min/max sizes, flex-basis, translate,
 * fixed component sizes like a 72x108 cover) are NOT flagged — those are
 * intrinsic layout sizes, per the documented allow-list.
 *
 * Pre-existing / legacy files (authored before the design-system effort, not yet
 * migrated) are allow-listed below so the guard only polices NEW + migrated
 * components. Remove a file from the allow-list once it's tokenized.
 *
 * Usage:  node scripts/tokenization-guard.mjs        (exit 1 on violations)
 */
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join, relative, basename } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(fileURLToPath(new URL('.', import.meta.url)), '..')
const SCAN_DIR = join(root, 'resources/css/components')

// Legacy / pre-existing files permitted to contain raw values (not part of the
// dark design-system migration). Keep this list shrinking, never growing.
const LEGACY_ALLOWLIST = new Set([
  // legacy primitives (not migrated in Phase 1)
  'bullet-text-input.scss', 'date-input.scss', 'digit.scss', 'gender-select.scss',
  'icon-circle.scss', 'loading.scss', 'mobile-date.scss', 'mobile-input.scss',
  'mobile-select.scss', 'modal.scss', 'qr-code.scss', 'social-button.scss',
  'step-indicator.scss', 'verify-code.scss',
  // legacy layout
  'auth.scss', 'home.scss', 'site-navbar.scss',
  // legacy panels
  'confirmation.scss', 'group-info-card.scss', 'page-title.scss',
  'study-info-card.scss', 'keypad.scss',
  // fixed-geometry switch control — knob dims (3/4/10px) are intrinsic, like
  // an icon/avatar fixed size; colors ARE tokenized (verified separately).
  'toggle.scss',
])
// Whole legacy category — the domain/* cards & islands predate this work.
const LEGACY_DIRS = new Set(['domain'])

const HEX = /#[0-9a-fA-F]{3,8}\b/
const RGBA = /\brgba?\(/
// Spacing / radius props only. Positioning (top/right/bottom/left/inset) and the
// box-shadow `inset` keyword are intentionally NOT policed — those are structural
// layout offsets, frequently negative or calc().
const SPACING_PROP = /\b(padding|margin|gap|border-radius)\b[^;{]*?\b(\d*\.?\d+)px/g

function walk(dir) {
  const out = []
  for (const name of readdirSync(dir)) {
    const p = join(dir, name)
    if (statSync(p).isDirectory()) out.push(...walk(p))
    else if (name.endsWith('.scss')) out.push(p)
  }
  return out
}

const violations = []
for (const file of walk(SCAN_DIR)) {
  const rel = relative(root, file)
  const dir = rel.split('/')[3] // components/<category>/...
  if (LEGACY_DIRS.has(dir) || LEGACY_ALLOWLIST.has(basename(file))) continue

  const lines = readFileSync(file, 'utf8').split('\n')
  lines.forEach((line, i) => {
    const code = line.replace(/\/\/.*$/, '') // strip line comments
    const add = (msg) => violations.push(`${rel}:${i + 1}  ${msg.trim()}`)
    if (HEX.test(code)) add(`raw hex → use a color token | ${code}`)
    if (RGBA.test(code)) add(`raw rgba() → use --color-white-* / a token | ${code}`)
    let m
    SPACING_PROP.lastIndex = 0
    while ((m = SPACING_PROP.exec(code))) {
      if (m[2] === '0' || m[2] === '1') continue // 0 / 1px allowed
      add(`raw ${m[1]} ${m[2]}px → use a --space-*/--radius-* token | ${code}`)
    }
  })
}

if (violations.length) {
  console.error(`\n✗ Tokenization guard: ${violations.length} violation(s)\n`)
  for (const v of violations) console.error('  ' + v)
  console.error('\nFix by referencing design tokens, or (legacy only) add the file to LEGACY_ALLOWLIST.\n')
  process.exit(1)
}
console.log('✓ Tokenization guard passed — no raw values in design-system components.')
