/**
 * tokens.md → UI2PreviewTokens.swift (preview-build.md §3 rule 4).
 *
 * migration.md rule 4 says 2.0 tokens are GENERATED into the 2.0 namespace and
 * Colors.swift/Typography.swift are never touched. This is that generator: it
 * makes tokens.md executable instead of aspirational.
 *
 * Color goes through Color(red:green:blue:opacity:) rather than Color(hex:) —
 * the SwiftLint gate reserves that initialiser for Colors.swift.
 */
import fs from 'node:fs/promises';
import path from 'node:path';
import { makereadyRoot } from './fs-index.mjs';

const tokensPath = path.resolve(makereadyRoot, 'docs/ui2/design-system/tokens.md');
export const tokensOutPath = path.resolve(makereadyRoot, 'iphone/MakeReady/UI2Preview/UI2PreviewTokens.swift');

const cells = (line) => line.split(/(?<!\\)\|/).slice(1, -1).map((c) => c.replace(/\\\|/g, '|').trim());

/** Rows of the table under `## <heading>`, as [token, value] pairs. */
function familyRows(md, heading) {
  const section = md.split(/^## /m).find((s) => s.toLowerCase().startsWith(heading.toLowerCase()));
  if (!section) return [];
  return section.split('\n')
    .filter((l) => l.trim().startsWith('|'))
    .filter((l) => !/^\|[\s:-]+\|/.test(l.trim()))
    .map(cells)
    .filter((c) => /^[a-z]+-[a-z0-9-]+$/.test(c[0] ?? ''))
    .map((c) => ({ name: c[0], value: c[1] }));
}

/**
 * Typography is prose, not a value: "SF Pro Text Semibold 16 / 21, letter-spacing
 * −0.32". Parse what the program actually writes and report the rest.
 * - "SF Pro" and "SF Pro Text" are one family (Text is Apple's optical size).
 * - No "/ N" means no designed line-height — null, never a guess.
 * - tokens.md uses the Unicode minus U+2212 for negative tracking.
 */
const TYPE_RE = /^SF Pro(?: Text)?\s+(Regular|Medium|Semibold|Bold)\s+(\d+(?:\.\d+)?)(?:\s*\/\s*(\d+(?:\.\d+)?))?/i;
const TRACK_RE = /(?:letter-spacing|tracking)\s*([+−-]?\d+(?:\.\d+)?)/i;

function parseType(rows) {
  const type = [];
  const skipped = [];
  for (const row of rows) {
    const m = TYPE_RE.exec(row.value);
    if (!m) { skipped.push(row.name); continue; }
    const track = TRACK_RE.exec(row.value);
    type.push({
      name: row.name,
      weight: m[1].toLowerCase(),
      size: m[2],
      lineHeight: m[3] ?? null,
      tracking: track ? track[1].replace('−', '-').replace('+', '') : null,
    });
  }
  return { type, skipped };
}

export function parseTokens(md) {
  const { type, skipped } = parseType(familyRows(md, 'Typography'));
  return {
    colors: familyRows(md, 'Color').filter((r) => /^#[0-9a-f]{6}([0-9a-f]{2})?$/i.test(r.value)),
    type,
    skipped,
    spacing: familyRows(md, 'Spacing').filter((r) => /^\d+(\.\d+)?$/.test(r.value)),
    radii: familyRows(md, 'Radius').filter((r) => /^\d+(\.\d+)?$/.test(r.value)),
  };
}

/** color-card-background → cardBackground (the family prefix is the enum). */
const member = (name) => {
  const [, ...rest] = name.split('-');
  return rest.map((p, i) => (i === 0 ? p : p[0].toUpperCase() + p.slice(1))).join('');
};

const channel = (hex, i) => (parseInt(hex.slice(1 + i * 2, 3 + i * 2), 16) / 255).toFixed(4).replace(/0+$/, '').replace(/\.$/, '.0');

function colorLine({ name, value }) {
  const alpha = value.length === 9 ? (parseInt(value.slice(7, 9), 16) / 255) : 1;
  const a = Number(alpha.toFixed(2));
  return `    static let ${member(name)} = Color(red: ${channel(value, 0)}, green: ${channel(value, 1)}, blue: ${channel(value, 2)}, opacity: ${a})`;
}

export function tokensToSwift(t) {
  return `//
//  UI2PreviewTokens.swift
//  MakeReady — UI 2.0 preview namespace
//
//  GENERATED FROM docs/ui2/design-system/tokens.md — DO NOT EDIT.
//  Regenerate with: node capture/lib/ui2-tokens.mjs
//  Rules: docs/ui2/preview-build.md §3 rule 4.
//

import SwiftUI

/// A designed text style: SwiftUI has no line-height, so the leading is applied
/// as lineSpacing (lineHeight − size) by the \`ui2TextStyle\` modifier.
struct UI2TextStyle {
    let weight: Font.Weight
    let size: CGFloat
    let lineHeight: CGFloat?
    let tracking: CGFloat

    var font: Font { .system(size: size, weight: weight) }
    var lineSpacing: CGFloat { max((lineHeight ?? size) - size, 0) }
}

extension View {
    func ui2TextStyle(_ style: UI2TextStyle) -> some View {
        font(style.font).tracking(style.tracking).lineSpacing(style.lineSpacing)
    }
}

enum UI2Token {
${t.colors.map(colorLine).join('\n')}

    // NOT \`Type\`: \`UI2Token.Type\` is Swift's metatype syntax for the enum itself.
    enum TypeStyle {
${t.type.map((r) => `        static let ${member(r.name)} = UI2TextStyle(weight: .${r.weight}, size: ${r.size}, lineHeight: ${r.lineHeight ?? 'nil'}, tracking: ${r.tracking ?? 0})`).join('\n')}
    }

    enum Space {
${t.spacing.map((r) => `        static let ${member(r.name)}: CGFloat = ${r.value}`).join('\n')}
    }

    enum Radius {
${t.radii.map((r) => `        static let ${member(r.name)}: CGFloat = ${r.value}`).join('\n')}
    }
}
`;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const md = await fs.readFile(tokensPath, 'utf-8');
  await fs.mkdir(path.dirname(tokensOutPath), { recursive: true });
  const parsed = parseTokens(md);
  await fs.writeFile(tokensOutPath, tokensToSwift(parsed), 'utf-8');
  console.log(`wrote ${path.relative(makereadyRoot, tokensOutPath)}`);
  console.log(`  ${parsed.colors.length} colors · ${parsed.type.length} type · ${parsed.spacing.length} spacing · ${parsed.radii.length} radius`);
  if (parsed.skipped.length) console.log(`  NOT PARSED (no token emitted): ${parsed.skipped.join(', ')}`);
}
