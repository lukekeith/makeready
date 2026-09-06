/**
 * The JS ↔ Swift boundary for the ui2 preview-build lane (docs/ui2/preview-build.md).
 *
 * Four kinds of string cross from a `capture/fixtures/ui2/C-###.json` fixture into
 * Swift, and until now nothing validated any of them against the Swift side:
 *
 *   - `variants[].props` keys      → fields on `struct CaptureComponent`
 *                                     (iphone/MakeReadyCaptureTests/CaptureFixture.swift)
 *   - `view`                       → a `case "<view>":` in ViewRegistry.swift
 *   - `devices[]` entries          → a `case … = "<value>"` raw value in
 *                                     CaptureDevices.swift
 *
 * The worst of the four fails SILENTLY: `CaptureComponent` is a fixed `Codable`
 * struct, so a JSON prop key with no matching field just decodes to nothing — no
 * error, no diagnostic, the component renders wrong. This test is file reads and
 * regexes against the real Swift sources — no simulator, no Xcode — so it runs in
 * milliseconds and still catches the defect class that appeared three times while
 * this branch was built.
 *
 * A second test below is drift detection (not a boundary check): re-deriving a
 * fixture from its contract with the same parser the build command uses and
 * asserting the variant name/slug set hasn't moved. It does NOT rebuild anything —
 * whether a drifted contract auto-rebuilds is OQ-PB-4, an open question this test
 * is not the place to settle.
 */
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import { makereadyRoot } from '../lib/fs-index.mjs';
import { ui2FixtureDir } from '../lib/ui2-fixture.mjs';
import { contractsDir, parseContract } from '../lib/ui2-index.mjs';
import { fixtureFromContract } from '../lib/ui2-fixture.mjs';

const captureFixtureSwift = path.resolve(makereadyRoot, 'iphone/MakeReadyCaptureTests/CaptureFixture.swift');
const viewRegistrySwift = path.resolve(makereadyRoot, 'iphone/MakeReadyCaptureTests/ViewRegistry.swift');
const captureDevicesSwift = path.resolve(makereadyRoot, 'iphone/MakeReadyCaptureTests/CaptureDevices.swift');

const relSwift = (abs) => path.relative(makereadyRoot, abs);
const escapeRe = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

/**
 * The brace-balanced body of `struct <name>: Codable { … }` — CaptureFixture.swift
 * declares dozens of structs (`CaptureComponent` is one of them, per file), so a
 * naive "read up to the next `}`" would stop at whatever closes first, and would
 * be fooled by a nested type declared inside the struct itself (its own closing
 * brace isn't the struct's). Counting brace depth from the opening `{` is correct
 * regardless of what — if anything — is nested inside.
 */
function structBody(source, name, file) {
  const decl = new RegExp(`struct\\s+${name}\\s*:\\s*Codable\\s*\\{`);
  const m = decl.exec(source);
  if (!m) throw new Error(`struct ${name} not found in ${relSwift(file)}`);
  let i = m.index + m[0].length;
  let depth = 1;
  const start = i;
  for (; i < source.length && depth > 0; i += 1) {
    if (source[i] === '{') depth += 1;
    else if (source[i] === '}') depth -= 1;
  }
  if (depth !== 0) throw new Error(`unbalanced braces reading struct ${name} in ${relSwift(file)}`);
  return source.slice(start, i - 1);
}

/** `let <name>: <Type>` (or `<name>: <Type>?`) at the top of a struct body. */
function structFieldNames(body) {
  return [...body.matchAll(/^\s*let\s+(\w+)\s*:/gm)].map((m) => m[1]);
}

async function loadSwiftBoundary() {
  const [componentSrc, registrySrc, devicesSrc] = await Promise.all([
    fs.readFile(captureFixtureSwift, 'utf-8'),
    fs.readFile(viewRegistrySwift, 'utf-8'),
    fs.readFile(captureDevicesSwift, 'utf-8'),
  ]);
  const fields = new Set(structFieldNames(structBody(componentSrc, 'CaptureComponent', captureFixtureSwift)));
  const hasCase = (view) => new RegExp(`case\\s+"${escapeRe(view)}"\\s*:`).test(registrySrc);
  const hasDevice = (raw) => new RegExp(`case\\s+\\w+\\s*=\\s*"${escapeRe(raw)}"`).test(devicesSrc);
  return { fields, hasCase, hasDevice };
}

async function loadFixtures() {
  const names = (await fs.readdir(ui2FixtureDir)).filter((f) => f.endsWith('.json'));
  const out = [];
  for (const name of names.sort()) {
    const fixture = JSON.parse(await fs.readFile(path.join(ui2FixtureDir, name), 'utf-8'));
    out.push({ name, fixture });
  }
  return out;
}

test('ui2 fixtures: every fixture value that crosses into Swift has a Swift-side match', async () => {
  const { fields, hasCase, hasDevice } = await loadSwiftBoundary();
  const fixtures = await loadFixtures();
  assert.ok(fixtures.length > 0, `no fixtures found under ${relSwift(ui2FixtureDir)} — nothing to check`);

  for (const { name, fixture } of fixtures) {
    assert.ok(
      hasCase(fixture.view),
      `${name}: view "${fixture.view}" has no matching case "${fixture.view}": in ${relSwift(viewRegistrySwift)}`,
    );

    for (const device of fixture.devices ?? []) {
      assert.ok(
        hasDevice(device),
        `${name}: device "${device}" is not a CaptureDevice raw value in ${relSwift(captureDevicesSwift)}`,
      );
    }

    for (const variant of fixture.variants ?? []) {
      for (const propName of Object.keys(variant.props ?? {})) {
        assert.ok(
          fields.has(propName),
          `${name}: variant "${variant.name}" prop "${propName}" has no matching field on ` +
            `struct CaptureComponent in ${relSwift(captureFixtureSwift)} — an unknown JSON key decodes ` +
            `to nothing, silently, so this prop would be dropped and the state would render wrong ` +
            `with no diagnostic`,
        );
      }
    }
  }
});

test('ui2 fixtures: variant name/slug still match a fresh re-derive from the contract (drift detection — no auto-rebuild, OQ-PB-4 owns that policy)', async () => {
  const fixtures = await loadFixtures();
  assert.ok(fixtures.length > 0, `no fixtures found under ${relSwift(ui2FixtureDir)} — nothing to check`);

  for (const { name, fixture } of fixtures) {
    const id = fixture.registryId;
    assert.ok(id, `${name}: fixture has no "registryId" to look its contract up by`);

    const contractFiles = (await fs.readdir(contractsDir)).filter((f) => f.startsWith(`${id}-`) && f.endsWith('.md'));
    assert.equal(
      contractFiles.length, 1,
      `${name}: expected exactly one contract file for ${id} under ${relSwift(contractsDir)}, found ${contractFiles.length}`,
    );

    const contractPath = path.join(contractsDir, contractFiles[0]);
    const contract = parseContract(await fs.readFile(contractPath, 'utf-8'), { file: contractPath });
    const fresh = fixtureFromContract(contract);

    const key = (v) => `${v.name} → ${v.slug}`;
    const onDisk = (fixture.variants ?? []).map(key).sort();
    const rederived = fresh.variants.map(key).sort();
    assert.deepEqual(
      onDisk,
      rederived,
      `${name}: ${relSwift(contractPath)} has drifted from the built fixture — re-deriving it now ` +
        `yields ${JSON.stringify(rederived)} but the fixture on disk has ${JSON.stringify(onDisk)}. ` +
        `This test only detects the drift; it does not rebuild anything (rebuild policy is OQ-PB-4, ` +
        `open, not this test's to settle).`,
    );
  }
});
