import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import { parseContract } from '../lib/ui2-index.mjs';
import { fixtureFromContract, ui2FixturePath, isBuilt, writeUi2Fixture } from '../lib/ui2-fixture.mjs';

const CONTRACT = `# C-040 PageHeader — pushed-page bar

## 3. Variant & state matrix

| \`style\` | \`showTitle\` | Renders | Consumption |
|---|---|---|---|
| Default | true | back · title | consumed — members-profile |
| Default | false | — undesigned | proposed default + OQ-C-040-3 |
| Two icons | true | — undesigned | proposed default + OQ-C-040-3 |
| Two icons | false | back | designed-unconsumed |

## 4. Props contract

| Prop | Type | Purpose |
|---|---|---|
| \`style\` | \`default \\| textButtons \\| twoIcons\` | the variant axis |
| \`showTitle\` | \`Bool\` | gates the title |
`;

test('fixtureFromContract emits one entry per DESIGNED state', () => {
  const fixture = fixtureFromContract(parseContract(CONTRACT, { file: 'x/C-040.md' }));

  assert.equal(fixture.id, 'ui2-c-040');
  assert.equal(fixture.registryId, 'C-040');
  assert.equal(fixture.component, 'PageHeader');
  assert.equal(fixture.view, 'component.ui2.C-040');
  // Device must be the iOS CaptureDevice raw value, not a viewport key. The Swift
  // side does CaptureDevice(rawValue: deviceKey) on each devices array entry, and
  // an unknown raw value silently fails after a full xcodebuild cycle. Derived from
  // COMPARE_VIEWPORTS['pro-max'].iphone to stay in sync with capture.mjs.
  assert.deepEqual(fixture.devices, ['iphone-16-pro-max']);
  // The undesigned row is skipped — there is no design to render.
  assert.deepEqual(fixture.variants.map((v) => v.name), ['Default · showTitle', 'Two icons · no showTitle']);
  // Props come from the matrix row, keyed by the §4 prop name.
  assert.deepEqual(fixture.variants[0].props, { style: 'Default', showTitle: 'true' });
  assert.deepEqual(fixture.variants[1].props, { style: 'Two icons', showTitle: 'false' });
});

test('ui2FixturePath is case-stable and outside fixtures/compare', () => {
  const p = ui2FixturePath('C-040');
  assert.match(p, /capture\/fixtures\/ui2\/C-040\.json$/);
  assert.doesNotMatch(p, /fixtures\/compare/);
});

test('isBuilt tracks fixture presence', async () => {
  const id = 'C-999';                       // a registry id no contract uses
  await fs.rm(ui2FixturePath(id), { force: true });
  assert.equal(await isBuilt(id), false);

  await writeUi2Fixture(id, { id: 'ui2-c-999', registryId: id, variants: [] });
  try {
    assert.equal(await isBuilt(id), true);
  } finally {
    await fs.rm(ui2FixturePath(id), { force: true });
  }
  assert.equal(await isBuilt(id), false);
});
