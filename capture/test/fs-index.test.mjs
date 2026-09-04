/**
 * fs-index build + join (docs/features/component-browser/07 §1, 01 D3/D16/D17/D18).
 * Drives buildIndex with a temp component tree + injected comparisons/registry.
 */
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { buildIndex, scanComponentsTree, kebab } from '../lib/fs-index.mjs';

async function makeTree(spec, dir) {
  for (const [name, content] of Object.entries(spec)) {
    const p = path.join(dir, name);
    if (typeof content === 'object') {
      await fs.mkdir(p, { recursive: true });
      await makeTree(content, p);
    } else {
      await fs.writeFile(p, content);
    }
  }
}

const comparisons = [
  { id: 'CardEvent', type: 'component', adapter: 'CardEvent', viewports: ['pro-max', 'se'], variants: [{ name: 'A', shared: {} }, { name: 'B', shared: {} }], _file: 'cards/CardEvent.json' },
  { id: 'card-study', type: 'component', adapter: 'card-study', viewports: ['pro-max'], shared: {}, _file: 'cards/card-study.json' },
  { id: 'GhostOnly', type: 'component', adapter: 'GhostOnly', shared: {}, _file: 'x/GhostOnly.json' }, // no Swift file
];
const registry = new Set(['CardEvent', 'card-study']);
const adapterCheck = () => true; // every joined spec counts as adapter-registered in this fixture

let tmp;
test.before(async () => {
  tmp = await fs.mkdtemp(path.join(os.tmpdir(), 'cb-fsindex-'));
  await makeTree({
    Card: {
      'CardEvent.swift': '// view',
      'CardStudy.swift': '// view (kebab-joined)',
      'CardData.swift': '// helper — never wired',
    },
    Chart: {
      'TimeChart.swift': '// view',
      Nested: { 'DeepThing.swift': '// nested component' },
    },
    Dupes: { 'CardEvent.swift': '// basename collision with Card/CardEvent' },
  }, tmp);
});
test.after(async () => { await fs.rm(tmp, { recursive: true, force: true }); });

test('fs-index', async (t) => {
  // registryCases reads a real file; inject by writing a fake registry file.
  const regFile = path.join(tmp, 'ViewRegistry.swift');
  await fs.writeFile(regFile, [...registry].map((c) => `case "component.${c}": return X()`).join('\n'));
  const index = await buildIndex({ root: tmp, comparisons, adapterCheck, registryFile: regFile });

  await t.test('tree mirrors folders + nesting', () => {
    const card = index.tree.find((n) => n.name === 'Card');
    assert.equal(card.type, 'folder');
    assert.ok(card.children.some((c) => c.name === 'CardEvent'));
    assert.ok(index.byPath.get('Chart/Nested/DeepThing'));
  });

  await t.test('exact-basename join wires CardEvent', () => {
    const c = index.byPath.get('Card/CardEvent');
    assert.equal(c.comparisonId, 'CardEvent');
    assert.deepEqual(c.wired, { fixture: true, adapter: true, registry: true });
    assert.equal(c.isWired, true);
    assert.equal(c.variantCount, 2);
    assert.deepEqual(c.viewports, ['pro-max', 'se']);
    assert.equal(c.fixtureFile, 'capture/fixtures/compare/cards/CardEvent.json');
  });

  await t.test('kebab-case join wires CardStudy ↔ card-study (CR1)', () => {
    const c = index.byPath.get('Card/CardStudy');
    assert.equal(kebab('CardStudy'), 'card-study');
    assert.equal(c.comparisonId, 'card-study');
    assert.equal(c.isWired, true);
  });

  await t.test('helper file is permanently not-capturable (D18)', () => {
    const c = index.byPath.get('Card/CardData');
    assert.equal(c.comparisonId, null);
    assert.deepEqual(c.wired, { fixture: false, adapter: false, registry: false });
  });

  await t.test('comparison with no Swift file is absent from the tree', () => {
    assert.ok(!index.components.some((c) => c.comparisonId === 'GhostOnly'));
  });

  await t.test('basename collision flagged on both nodes (D17)', () => {
    assert.equal(index.byPath.get('Card/CardEvent').collision, true);
    assert.equal(index.byPath.get('Dupes/CardEvent').collision, true);
    assert.equal(index.byPath.get('Card/CardStudy').collision, false);
  });

  await t.test('non-default root is not cached (fresh walk sees new files)', async () => {
    await fs.writeFile(path.join(tmp, 'Chart', 'Brand.swift'), '// new');
    const again = await scanComponentsTree(tmp);
    assert.ok(again.byPath.get('Chart/Brand'));
  });
});
