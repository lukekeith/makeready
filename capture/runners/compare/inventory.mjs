/**
 * Cross-platform component/page inventory.
 *
 * Rolls up, for every comparison (component | page | layout):
 *   - which platforms it EXISTS on (iPhone always; web/client = the adapter
 *     produces a client projection — i.e. a Vue twin is wired into compare),
 *   - the per-variant schema (the prop bag each variant supplies),
 *   - per-variant capture status, rating, and comment counts per platform,
 *   - a derived match status per variant + a rollup per comparison.
 *
 * This is the read model behind the `inventory` MCP tool and
 * GET /api/compare/inventory, so Claude can ask:
 *   - "components that don't exist on the client app"  → platforms.client.exists == false
 *   - "components that exist but have client comments"  → client.exists && unresolvedClientComments > 0
 *   - "components with variants that don't match"       → variantMismatches > 0
 */
import { loadComparisons, projectComparison, getVariants } from './lib.mjs';
import { prisma } from '../../db/index.mjs';

// Per-variant match status (see queryInventory for how these are filtered).
export const VARIANT_STATUS = {
  NO_WEB_TWIN: 'no-web-twin',   // web side not built yet — can't be compared
  UNCAPTURED: 'uncaptured',     // web twin exists but one/both platforms not shot yet
  COMMENTED: 'commented',       // both captured, but has unresolved client comments
  RATING_LOW: 'rating-mismatch',// both captured, rated 1–2 (user flagged poor match)
  MATCHED: 'matched',           // both captured, no open comments, rating null or ≥3
};

const MISMATCH_STATUSES = new Set([VARIANT_STATUS.COMMENTED, VARIANT_STATUS.RATING_LOW]);

/** Builds the full inventory. `detail:true` includes each variant's raw data. */
export async function buildInventory({ detail = false } = {}) {
  const specs = await loadComparisons();
  const out = [];

  for (const spec of specs) {
    if (spec.error) { out.push({ id: spec.id, error: spec.error }); continue; }

    let projected = null;
    try { projected = projectComparison(spec); } catch { /* adapter missing → treat as no client */ }
    const clientExists = projected?.client != null;
    const iphoneView = projected?.iphone?.view ?? null;
    const clientView = projected?.client?.view ?? null;

    const variants = getVariants(spec);
    const versions = await prisma.version.findMany({
      where: { comparisonId: spec.id },
      orderBy: { capturedAt: 'desc' },
      include: {
        screenshots: { select: { platform: true } },
        comments: { select: { platform: true, resolved: true } },
      },
    });

    const perVariant = variants.map((v) => {
      const vv = versions.filter((x) => x.variantName === v.name);
      const iphoneCaptured = vv.some((x) => x.screenshots.some((s) => s.platform === 'iphone'));
      const clientCaptured = vv.some((x) => x.screenshots.some((s) => s.platform === 'client'));
      const rating = vv.find((x) => x.rating != null)?.rating ?? null;
      const comments = vv.flatMap((x) => x.comments);
      const unresolvedClient = comments.filter((c) => c.platform === 'client' && !c.resolved).length;
      const unresolvedIphone = comments.filter((c) => c.platform === 'iphone' && !c.resolved).length;

      let status;
      if (!clientExists) status = VARIANT_STATUS.NO_WEB_TWIN;
      else if (!iphoneCaptured || !clientCaptured) status = VARIANT_STATUS.UNCAPTURED;
      else if (unresolvedClient > 0) status = VARIANT_STATUS.COMMENTED;
      else if (rating != null && rating <= 2) status = VARIANT_STATUS.RATING_LOW;
      else status = VARIANT_STATUS.MATCHED;

      return {
        name: v.name,
        schema: Object.keys(v.shared ?? {}),
        ...(detail ? { data: v.shared ?? {} } : {}),
        captured: { iphone: iphoneCaptured, client: clientCaptured },
        rating,
        unresolvedComments: { iphone: unresolvedIphone, client: unresolvedClient },
        status,
      };
    });

    // Union schema across variants → field → sample values (the "options").
    const fieldSamples = {};
    for (const v of variants) {
      for (const [k, val] of Object.entries(v.shared ?? {})) {
        (fieldSamples[k] ??= new Set()).add(typeof val === 'object' ? JSON.stringify(val) : String(val));
      }
    }
    const schema = Object.fromEntries(
      Object.entries(fieldSamples).map(([k, set]) => [k, [...set].slice(0, 12)]),
    );

    const variantMismatches = perVariant.filter((v) => MISMATCH_STATUSES.has(v.status)).length;
    const unresolvedClientComments = perVariant.reduce((a, v) => a + v.unresolvedComments.client, 0);

    out.push({
      id: spec.id,
      type: spec.type,            // component | page | layout
      group: spec.group,
      title: spec.title,
      platforms: {
        iphone: { exists: true, view: iphoneView, captured: perVariant.some((v) => v.captured.iphone) },
        client: { exists: clientExists, view: clientView, captured: perVariant.some((v) => v.captured.client) },
      },
      variantCount: variants.length,
      capturedVariants: {
        iphone: perVariant.filter((v) => v.captured.iphone).length,
        client: perVariant.filter((v) => v.captured.client).length,
      },
      unresolvedClientComments,
      variantMismatches,
      schema,
      variants: perVariant,
    });
  }
  return out;
}

const SORTS = {
  variants: (a, b) => b.variantCount - a.variantCount,
  comments: (a, b) => b.unresolvedClientComments - a.unresolvedClientComments,
  mismatches: (a, b) => b.variantMismatches - a.variantMismatches,
  alpha: (a, b) => a.id.localeCompare(b.id),
};

/**
 * Filters/sorts the inventory for the common questions.
 *   missingOnClient   — only comparisons with no web twin yet
 *   hasClientComments — only ones with a web twin AND unresolved client comments
 *   mismatched        — only ones with ≥1 variant flagged commented/low-rating
 *   type              — "component" | "page" | "layout"
 *   sort              — "variants" (default) | "comments" | "mismatches" | "alpha"
 *   limit             — top N
 */
export function queryInventory(inv, opts = {}) {
  const { missingOnClient, hasClientComments, mismatched, type, sort = 'variants', limit } = opts;
  let rows = inv.filter((r) => !r.error);
  if (type) rows = rows.filter((r) => r.type === type);
  if (missingOnClient) rows = rows.filter((r) => !r.platforms.client.exists);
  if (hasClientComments) rows = rows.filter((r) => r.platforms.client.exists && r.unresolvedClientComments > 0);
  if (mismatched) rows = rows.filter((r) => r.variantMismatches > 0);
  rows = [...rows].sort(SORTS[sort] ?? SORTS.variants);
  if (limit && limit > 0) rows = rows.slice(0, limit);
  return rows;
}
