/**
 * Adapter registry.
 *
 * Each comparison declares an `adapter` key (defaults to its `id`). The adapter
 * projects the comparison's canonical `shared` block into the two platform
 * fixture shapes via `toClient(shared)` and `toIphone(shared)`.
 *
 * To add a new comparison: write `<id>.mjs` exporting { toClient, toIphone },
 * register it here, then drop a `fixtures/compare/<group>/<id>.json` spec.
 */
import groupHome from './group-home.mjs';
import cardStudy from './card-study.mjs';
import groupCard from './GroupCard.mjs';

export const adapters = {
  'group-home': groupHome,
  'card-study': cardStudy,
  GroupCard: groupCard,
};

export function getAdapter(key) {
  const adapter = adapters[key];
  if (!adapter) {
    throw new Error(
      `No compare adapter registered for "${key}". Available: ${Object.keys(adapters).join(', ') || '(none)'}`,
    );
  }
  return adapter;
}
