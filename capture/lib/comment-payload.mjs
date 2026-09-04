/**
 * Shared comment payload builders (docs/features/component-browser/03 §2.5, §3).
 *
 * `describeComment` moved here VERBATIM from mcp/comments.mjs so the HTTP scope
 * route and the MCP tools emit the identical shape (the MCP server re-imports
 * it; existing tool payloads are unchanged).
 */
import path from 'node:path';
import { prisma, listUnresolved, latestScreenshots } from '../db/index.mjs';
import { compareRoot } from '../runners/compare/lib.mjs';
import { buildIndex, resolveScope, makereadyRoot } from './fs-index.mjs';

export const abs = (rel) => (rel ? path.join(compareRoot, rel) : null);

/** Rich, LLM-friendly description of one comment + everything around it. */
export async function describeComment(c) {
  const latest = await latestScreenshots(c.comparisonId, c.viewport);
  const v = c.version ?? {};
  const px = {
    x: c.screenshot?.width ? Math.round(c.x * c.screenshot.width) : null,
    y: c.screenshot?.height ? Math.round(c.y * c.screenshot.height) : null,
  };
  return {
    commentId: c.id,
    comparison: { id: c.comparisonId, title: c.comparison?.title, type: c.comparison?.type },
    target: {
      platform: c.platform,
      viewport: c.viewport,
      component: v.componentName ?? null,
      iphoneView: v.iphoneView ?? null,
      clientView: v.clientView ?? null,
      device: c.screenshot?.device ?? null,
    },
    position: { xFraction: c.x, yFraction: c.y, xPx: px.x, yPx: px.y },
    // The exact DOM element the pin resolved to (live hit-test of the web twin):
    // its BEM selector → the SCSS rule to edit, plus current computed styles so a
    // terse comment ("bottom radius should be 0") needs no extra interpretation.
    commentedElement: c.targetSelector
      ? {
          selector: c.targetSelector,
          label: c.targetLabel,
          tag: c.targetMeta?.tag ?? null,
          text: c.targetMeta?.text ?? null,
          boxFraction: c.targetMeta?.rect ?? null,
          computedStyles: c.targetMeta?.styles ?? null,
        }
      : null,
    pinnedScreenshot: abs(c.screenshot?.path),
    latestScreenshots: { iphone: abs(latest.iphone?.path), client: abs(latest.client?.path) },
    version: { id: c.versionId, capturedAt: v.capturedAt, gitSha: v.gitSha, gitDirty: v.gitDirty, sourceHash: v.sourceHash },
    sharedData: v.sharedData ?? null,
    thread: (c.messages ?? []).map((m) => ({ source: m.source, text: m.text, at: m.createdAt })),
    createdAt: c.createdAt,
  };
}

/** versionLabel per suite CR15. */
async function versionLabelFor(c) {
  if (!c.versionId) return 'unanchored (no version recorded)';
  const newest = await prisma.version.findFirst({
    where: { comparisonId: c.comparisonId, variantName: c.variantName, viewport: c.viewport },
    orderBy: { capturedAt: 'desc' },
    select: { id: true },
  });
  if (newest && c.versionId === newest.id) return 'current';
  const when = c.version?.capturedAt ? new Date(c.version.capturedAt).toISOString().slice(0, 10) : 'unknown date';
  return `old — captured ${when}; current version is ${newest?.id ?? 'none'}`;
}

/**
 * The full scope payload (03 §2.5): resolves the scope against the fs index and
 * gathers every unresolved IPHONE-platform comment per matched component,
 * across all variants and versions, each as describeComment() + versionLabel.
 * Throws ScopeError for not-found / ambiguous / collision scopes.
 */
export async function buildScopePayload(scope) {
  const index = await buildIndex();
  const matched = resolveScope(index, scope);

  const components = [];
  let totalComments = 0;
  for (const node of matched) {
    let unresolvedComments = [];
    if (node.comparisonId) {
      const rows = (await listUnresolved(node.comparisonId)).filter((c) => c.platform === 'iphone');
      for (const c of rows) {
        unresolvedComments.push({ ...(await describeComment(c)), versionLabel: await versionLabelFor(c) });
      }
    }
    totalComments += unresolvedComments.length;
    components.push({
      path: node.path,
      comparisonId: node.comparisonId,
      swiftFile: path.relative(makereadyRoot, node.file),
      fixtureFile: node.fixtureFile,
      viewports: node.viewports,
      unresolvedComments,
    });
  }
  return {
    scope,
    components,
    totals: {
      components: components.length,
      withComments: components.filter((c) => c.unresolvedComments.length > 0).length,
      unresolvedComments: totalComments,
    },
  };
}
