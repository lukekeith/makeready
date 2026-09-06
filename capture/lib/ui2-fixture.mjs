/**
 * The ui2 preview fixture (docs/ui2/preview-build.md §5).
 *
 * Deliberately NOT under fixtures/compare/: that tree is walked by
 * runners/compare/lib.mjs loadComparisons(), which would sync the same
 * `ui2-c-###` comparison id with its own type/group/title and fight
 * syncUi2Row on every request (syncComparison overwrites those columns on
 * every call). Keeping it in its own root leaves syncUi2Row the single writer.
 */
import fs from 'node:fs/promises';
import path from 'node:path';
import { makereadyRoot } from './fs-index.mjs';
import { ui2ComparisonId } from './ui2-index.mjs';

export const ui2FixtureDir = path.resolve(makereadyRoot, 'capture/fixtures/ui2');
export const ui2FixturePath = (registryId) => path.join(ui2FixtureDir, `${registryId.toUpperCase()}.json`);

export async function readUi2Fixture(registryId) {
  try { return JSON.parse(await fs.readFile(ui2FixturePath(registryId), 'utf-8')); }
  catch { return null; }
}

export async function writeUi2Fixture(registryId, fixture) {
  await fs.mkdir(ui2FixtureDir, { recursive: true });
  await fs.writeFile(ui2FixturePath(registryId), `${JSON.stringify(fixture, null, 2)}\n`, 'utf-8');
}

/** "Built" is fixture presence — the 2.0 twin of how 1.0 derives `wired`. */
export async function isBuilt(registryId) {
  try { await fs.access(ui2FixturePath(registryId)); return true; }
  catch { return false; }
}

/**
 * Contract → fixture. Only DESIGNED states get an entry: an `undesigned` row
 * has a proposed default waiting on a ruling, and rendering one would pre-empt
 * that ruling (preview-build.md §3 rule 6).
 */
export function fixtureFromContract(contract) {
  const variants = contract.states
    .filter((s) => s.consumptionState !== 'undesigned')
    .map((s) => ({
      name: s.name,
      slug: s.slug,
      props: Object.fromEntries(s.propValues.map((p) => [p.name, p.value])),
    }));
  return {
    id: ui2ComparisonId(contract.id),
    registryId: contract.id,
    component: contract.name,
    view: `component.ui2.${contract.id}`,
    devices: ['pro-max'],
    variants,
  };
}
