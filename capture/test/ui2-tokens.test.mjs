import test from 'node:test';
import assert from 'node:assert/strict';
import { parseTokens, tokensToSwift } from '../lib/ui2-tokens.mjs';

const TOKENS = `# UI 2.0 Design Tokens

## Color

| Token | Value | Figma variable | iOS mapping | Web mapping |
|---|---|---|---|---|
| color-card-background | #1f2124 | \`card/background\` | (new) | (new) |
| color-accent-20 | #6c47ff33 | \`Purple/20%\` | (new) | (new) |

## Spacing

| Token | Value (pt/px) | Figma variable | Notes |
|---|---|---|---|
| space-page-margin | 16 | observed | inset |

## Radius

| Token | Value | Figma variable | Notes |
|---|---|---|---|
| radius-card-sm | 4 | observed | |
| radius-circle | 50% | observed | |
`;

test('parseTokens reads the typography family, and reports what it cannot parse', () => {
  const t = parseTokens(`## Typography

| Token | Font / size / weight / line-height | Figma variable | iOS mapping | Web mapping |
|---|---|---|---|---|
| type-callout-bold | SF Pro Text Semibold 16 / 21, letter-spacing −0.32 | \`Callout / Bold\` | (new) | (new) |
| type-body | SF Pro Regular 14 | observed | (new) | (new) |
| type-nav-action | SF Pro Regular 14 / 24, tracking +0.56 | observed | (new) | (new) |
| type-mystery | a hand-drawn font, vibes only | observed | (new) | (new) |
`);

  assert.deepEqual(t.type, [
    // "SF Pro Text" and "SF Pro" are the same family; the Text suffix is Apple's
    // optical size, not a different typeface.
    { name: 'type-callout-bold', weight: 'semibold', size: '16', lineHeight: '21', tracking: '-0.32' },
    // No "/ N" means no designed line-height — null, never a guessed one.
    { name: 'type-body', weight: 'regular', size: '14', lineHeight: null, tracking: null },
    { name: 'type-nav-action', weight: 'regular', size: '14', lineHeight: '24', tracking: '0.56' },
  ]);
  // Unparseable rows are surfaced, not dropped: a missing token is how a literal
  // font sneaks back into a preview view.
  assert.deepEqual(t.skipped, ['type-mystery']);
});

test('tokensToSwift emits a text style per type token', () => {
  const swift = tokensToSwift(parseTokens(`## Typography

| Token | Font / size / weight / line-height | Figma variable | iOS mapping | Web mapping |
|---|---|---|---|---|
| type-page-title | SF Pro Regular 14 / 20 | observed | (new) | (new) |
`));
  assert.match(swift, /struct DesignTextStyle/);
  assert.match(swift, /static let pageTitle = DesignTextStyle\(weight: \.regular, size: 14, lineHeight: 20, tracking: 0\)/);
});

test('parseTokens reads each family, skipping prose rows', () => {
  const t = parseTokens(TOKENS);
  assert.deepEqual(t.colors, [
    { name: 'color-card-background', value: '#1f2124' },
    { name: 'color-accent-20', value: '#6c47ff33' },
  ]);
  assert.deepEqual(t.spacing, [{ name: 'space-page-margin', value: '16' }]);
  // "50%" is not a CGFloat — a non-numeric radius is not silently dropped, it
  // is routed into `skipped` alongside the other families (see below).
  assert.deepEqual(t.radii, [{ name: 'radius-card-sm', value: '4' }]);
});

test('parseTokens reports color/spacing/radius rows that fail their value regex via `skipped`, same as typography', () => {
  const t = parseTokens(TOKENS);
  // radius-circle: 50% is the token every circular component needs (Avatar is
  // a live registry row) — it must be visible in `skipped`, not dropped by a
  // bare .filter() the way color/spacing/radius used to be.
  assert.ok(t.skipped.includes('radius-circle'), `expected "radius-circle" in skipped, got: ${JSON.stringify(t.skipped)}`);
});

test('tokensToSwift emits camelCased members with 8-digit hex alpha', () => {
  const swift = tokensToSwift(parseTokens(TOKENS));
  assert.match(swift, /enum Token \{/);
  assert.match(swift, /static let cardBackground = Color\(red: [\d.]+, green: [\d.]+, blue: [\d.]+, opacity: 1\)/);
  // #6c47ff33 → opacity 0.2
  assert.match(swift, /static let accent20 = Color\(red: [\d.]+, green: [\d.]+, blue: [\d.]+, opacity: 0\.2\)/);
  assert.match(swift, /static let pageMargin: CGFloat = 16/);
  assert.match(swift, /static let cardSm: CGFloat = 4/);
  // Generated file — say so, and say what regenerates it.
  assert.match(swift, /DO NOT EDIT.*ui2-tokens\.mjs/s);
});
