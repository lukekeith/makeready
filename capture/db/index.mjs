/**
 * Capture database access layer (Prisma + Postgres `makeready_capture`).
 *
 * Owns comments, versioned screenshots, and the metadata that ties each comment
 * to the exact component/screen + code state that produced the image it sits on.
 * Comparison *definitions* still live in the fixture JSON; this DB holds their
 * mutable annotations (rating, comments) and capture history (versions/shots).
 */
import { PrismaClient } from '@prisma/client';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// @prisma/client doesn't load .env at runtime (only the CLI does) — load it.
if (!process.env.CAPTURE_DATABASE_URL) {
  try {
    const here = path.dirname(fileURLToPath(import.meta.url));
    process.loadEnvFile(path.resolve(here, '../.env'));
  } catch {}
}

export const prisma = new PrismaClient();

// ── Comparisons ──

export async function syncComparison(spec) {
  return prisma.comparison.upsert({
    where: { id: spec.id },
    create: { id: spec.id, type: spec.type, groupName: spec.group, title: spec.title, adapter: spec.adapter ?? spec.id },
    update: { type: spec.type, groupName: spec.group, title: spec.title, adapter: spec.adapter ?? spec.id },
  });
}

export async function getComparison(id) {
  return prisma.comparison.findUnique({ where: { id } });
}

// ── Versions & screenshots ──

export async function createVersion(data) {
  return prisma.version.create({ data });
}

export async function addScreenshot(data) {
  return prisma.screenshot.create({ data });
}

/** Rating is per-version now. */
export async function setVersionRating(versionId, rating) {
  const normalized = rating == null ? null : Math.max(1, Math.min(5, Math.round(Number(rating))));
  await prisma.version.update({ where: { id: versionId }, data: { rating: normalized } });
  return normalized;
}

/** Most-recent screenshot per platform for a comparison + viewport. */
export async function latestScreenshots(comparisonId, viewport) {
  const out = {};
  for (const platform of ['iphone', 'client']) {
    out[platform] = await prisma.screenshot.findFirst({
      where: { platform, version: { comparisonId, viewport } },
      orderBy: { createdAt: 'desc' },
      include: { version: true },
    });
  }
  return out;
}

export async function getVersion(versionId) {
  return prisma.version.findUnique({ where: { id: versionId }, include: { comparison: true } });
}

/**
 * Distinct variant names that have at least one captured screenshot of the given
 * platform (across any viewport) for a comparison. Used to compute per-component
 * completion in the compare nav.
 */
export async function capturedVariantNames(comparisonId, platform) {
  const rows = await prisma.screenshot.findMany({
    where: { platform, version: { comparisonId } },
    select: { version: { select: { variantName: true } } },
  });
  return new Set(rows.map((r) => r.version.variantName));
}

export async function latestVersion(comparisonId) {
  return prisma.version.findFirst({ where: { comparisonId }, orderBy: { capturedAt: 'desc' } });
}

/** The single (latest) capture for one variant + viewport, with its screenshots. */
export async function getVariantLatest(comparisonId, variantName, viewport) {
  return prisma.version.findFirst({
    where: { comparisonId, variantName, viewport },
    orderBy: { capturedAt: 'desc' },
    include: { screenshots: true, comparison: true },
  });
}

/** Discard a single version (used to roll back an empty version after a capture
 *  produced nothing — leaves the prior version and its screenshots untouched). */
export async function deleteVersion(versionId) {
  await prisma.version.delete({ where: { id: versionId } });
}

/**
 * Finalize a freshly-created version after its captures have completed.
 *
 * This is the "no history" replace, but done SAFELY: instead of deleting the
 * prior version up front (which cascade-deletes its screenshots — including the
 * platform we're NOT recapturing this run), we
 *   1. carry forward the most-recent screenshot of every platform NOT captured
 *      this run, by re-parenting it onto the new version, then
 *   2. delete the now-stale prior versions for this (comparison, variant, viewport).
 *
 * So capturing one platform never drops the other's shot, and a screenshot is
 * only ever removed AFTER its replacement is in place. Re-parenting (vs. delete)
 * also keeps any comment anchored to the carried-forward shot alive; comments
 * pinned to a pruned version fall back to SetNull as before.
 *
 * `capturedPlatforms` is the set of platforms that actually produced a shot in
 * this run (a skipped/failed platform is treated as "not captured" and carried
 * forward, so a failed recapture can't destroy the previous good shot).
 */
export async function finalizeVariantVersion({ newVersionId, comparisonId, variantName, viewport, capturedPlatforms }) {
  const PLATFORMS = ['iphone', 'client'];
  await prisma.$transaction(async (tx) => {
    for (const platform of PLATFORMS) {
      if (capturedPlatforms.includes(platform)) continue;
      const prior = await tx.screenshot.findFirst({
        where: { platform, versionId: { not: newVersionId }, version: { comparisonId, variantName, viewport } },
        orderBy: { createdAt: 'desc' },
      });
      if (prior) {
        await tx.screenshot.update({ where: { id: prior.id }, data: { versionId: newVersionId } });
      }
    }
    await tx.version.deleteMany({
      where: { comparisonId, variantName, viewport, id: { not: newVersionId } },
    });
  });
}

/**
 * The two screenshots shown when a version is selected: that version's own shot
 * per platform, falling back to the latest shot of a platform it didn't capture
 * (at or before its capture time) so the comparison stays useful.
 */
export async function versionShots(version) {
  const out = {};
  for (const platform of ['iphone', 'client']) {
    let shot = await prisma.screenshot.findFirst({ where: { versionId: version.id, platform } });
    if (!shot) {
      // Fall back to the latest shot of the platform this version didn't capture,
      // so the comparison always shows both sides.
      shot = await prisma.screenshot.findFirst({
        where: { platform, version: { comparisonId: version.comparisonId, viewport: version.viewport } },
        orderBy: { createdAt: 'desc' },
      });
    }
    out[platform] = shot;
  }
  return out;
}

/** Versions for a comparison, newest first, with platforms + rating + comment counts. */
export async function listVersions(comparisonId) {
  const rows = await prisma.version.findMany({
    where: { comparisonId },
    orderBy: { capturedAt: 'desc' },
    include: { screenshots: { select: { platform: true } }, comments: { select: { resolved: true } } },
  });
  // version number per (variant, viewport), oldest = 1
  const seq = new Map();
  const ordered = [...rows].sort((a, b) => a.capturedAt - b.capturedAt);
  const numberOf = new Map();
  for (const v of ordered) {
    const key = `${v.variantName}|${v.viewport}`;
    const n = (seq.get(key) ?? 0) + 1;
    seq.set(key, n);
    numberOf.set(v.id, n);
  }
  return rows.map((v) => ({
    id: v.id,
    viewport: v.viewport,
    variantName: v.variantName,
    number: numberOf.get(v.id),
    label: `${v.variantName} ${v.viewport} ${numberOf.get(v.id)}`,
    capturedAt: v.capturedAt,
    rating: v.rating,
    gitSha: v.gitSha,
    gitDirty: v.gitDirty,
    componentName: v.componentName,
    platforms: [...new Set(v.screenshots.map((s) => s.platform))],
    commentCount: v.comments.length,
    unresolvedCount: v.comments.filter((c) => !c.resolved).length,
  }));
}

/** Screenshot history (newest first) for a comparison + viewport + platform. */
export async function screenshotHistory(comparisonId, viewport, platform) {
  return prisma.screenshot.findMany({
    where: { platform, version: { comparisonId, viewport } },
    orderBy: { createdAt: 'desc' },
    include: { version: true },
  });
}

// ── Comments ──

const commentInclude = {
  messages: { orderBy: { createdAt: 'asc' } },
  version: true,
  screenshot: true,
};

export async function listComments(comparisonId) {
  return prisma.comment.findMany({ where: { comparisonId }, include: commentInclude, orderBy: { createdAt: 'asc' } });
}

/** Comments made on a specific version (the version-locked view). */
export async function listCommentsForVersion(versionId) {
  return prisma.comment.findMany({ where: { versionId }, include: commentInclude, orderBy: { createdAt: 'asc' } });
}

/** Comments for a variant + viewport (survive recaptures; pin to the variant). */
export async function listCommentsForVariant(comparisonId, variantName, viewport) {
  return prisma.comment.findMany({
    where: { comparisonId, variantName, viewport },
    include: commentInclude,
    orderBy: { createdAt: 'asc' },
  });
}

export async function listUnresolved(comparisonId) {
  return prisma.comment.findMany({
    where: { resolved: false, ...(comparisonId ? { comparisonId } : {}) },
    include: { ...commentInclude, comparison: true },
    orderBy: { createdAt: 'asc' },
  });
}

export async function getComment(id) {
  return prisma.comment.findUnique({ where: { id }, include: { ...commentInclude, comparison: true } });
}

/**
 * Places a pin on a variant. iPhone pins link to the latest iPhone screenshot
 * (so they survive recaptures by x/y); web pins have no screenshot (the web side
 * is a live iframe), they pin to the variant + position directly.
 */
export async function addComment({ comparisonId, variantName = 'default', screenshotId, platform, viewport, x, y, text, source = 'user', targetSelector = null, targetLabel = null, targetMeta = null }) {
  if (!text || !String(text).trim()) throw new Error('comment text is required');
  if (platform !== 'iphone' && platform !== 'client') throw new Error('platform must be iphone|client');
  if (!viewport) throw new Error('viewport is required');

  // Resolve an anchor screenshot for iPhone pins (web is live → none).
  let shot = null;
  if (screenshotId) {
    shot = await prisma.screenshot.findUnique({ where: { id: screenshotId }, include: { version: true } });
  } else if (platform === 'iphone') {
    shot = await prisma.screenshot.findFirst({
      where: { platform, version: { comparisonId, variantName, viewport } },
      orderBy: { createdAt: 'desc' },
      include: { version: true },
    });
  }

  return prisma.comment.create({
    data: {
      comparisonId,
      variantName,
      versionId: shot?.versionId ?? null,
      screenshotId: shot?.id ?? null,
      platform,
      viewport,
      x: Math.max(0, Math.min(1, Number(x) || 0)),
      y: Math.max(0, Math.min(1, Number(y) || 0)),
      targetSelector: targetSelector || null,
      targetLabel: targetLabel || null,
      targetMeta: targetMeta ?? undefined,
      messages: { create: { source: source === 'claude' ? 'claude' : 'user', text: String(text).trim() } },
    },
    include: commentInclude,
  });
}

export async function replyComment(commentId, text, source = 'user') {
  if (!text || !String(text).trim()) throw new Error('reply text is required');
  await prisma.message.create({ data: { commentId, source: source === 'claude' ? 'claude' : 'user', text: String(text).trim() } });
  await prisma.comment.update({ where: { id: commentId }, data: { resolved: false, resolvedAt: null } });
  return getComment(commentId);
}

export async function setResolved(commentId, resolved) {
  await prisma.comment.update({ where: { id: commentId }, data: { resolved: Boolean(resolved), resolvedAt: resolved ? new Date() : null } });
}

export async function deleteComment(commentId) {
  await prisma.comment.delete({ where: { id: commentId } });
}

export async function summarize(comparisonId) {
  const total = await prisma.comment.count({ where: { comparisonId } });
  const unresolved = await prisma.comment.count({ where: { comparisonId, resolved: false } });
  return { total, unresolved };
}
