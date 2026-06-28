/**
 * Generic iPhone-only card adapter factory.
 *
 * Most card comparisons are being stood up iPhone-first: we want to capture and
 * navigate the SwiftUI component for every variant before building the web (Vue)
 * twin. For those, the canonical `shared` block for a variant IS the component's
 * prop bag — it's handed straight to the matching `component.<View>` case in
 * `iphone/MakeReadyCaptureTests/ViewRegistry.swift` (decoded loosely there), and
 * the web side is intentionally absent until a Vue version exists.
 *
 * Usage (in adapters/index.mjs):
 *   import { iphoneCard } from './iphone-card.mjs';
 *   export const adapters = { ...,  CardEvent: iphoneCard('component.CardEvent') };
 *
 * The fixture's `adapter` key must match the registry key (its `id` by default).
 * When the Vue twin lands, swap the entry for a real two-sided adapter (see
 * card-study.mjs / GroupCard.mjs) — nothing else about the fixture changes.
 */
export function iphoneCard(view) {
  return {
    toIphone(shared) {
      return {
        platform: 'iphone',
        view,
        state: { component: shared ?? {} },
      };
    },
    // Web twin not built yet — return null so projectComparison records "no web
    // side" without throwing, and the comparison stays navigable iPhone-only.
    toClient() {
      return null;
    },
  };
}

export default iphoneCard;
