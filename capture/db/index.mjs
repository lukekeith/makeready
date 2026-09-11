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

/**
 * Platforms a screenshot can belong to.
 *
 * `iphone` + `client` are the two captured sides of a /compare pair. `design` is
 * the UI 2.0 side: a frozen Figma snapshot from `docs/ui2/design-system/
 * components/assets/`, registered as a screenshot so 2.0 components get the same
 * version timeline and pinned comments as captured ones (there is no 2.0 code to
 * capture yet). It is never produced by a capture run.
 */
export const CAPTURE_PLATFORMS = ['iphone', 'client'];
export const ALL_PLATFORMS = [...CAPTURE_PLATFORMS, 'design'];

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
  for (const platform of ALL_PLATFORMS) {
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
 * History is KEPT (component-browser DB-1): every capture leaves a permanent
 * Version and its Screenshot rows. For each platform NOT captured this run, the
 * prior latest screenshot is COPY-forwarded — a new Screenshot row on the new
 * version pointing at the same PNG file — so the new version pairs both
 * platforms while every retained version keeps its own rows (and the comments
 * anchored to them).
 *
 * `capturedPlatforms` is the set of platforms that actually produced a shot in
 * this run (a skipped/failed platform is treated as "not captured" and copied
 * forward, so a failed recapture can't lose the previous good shot).
 *
 * `platforms` defaults to the two captured platforms; the ui2 lane passes
 * ['iphone','design'] so the frozen Figma snapshot rides along with a freshly
 * built render.
 */
export async function finalizeVariantVersion({ newVersionId, comparisonId, variantName, viewport, capturedPlatforms, platforms = CAPTURE_PLATFORMS }) {
  await prisma.$transaction(async (tx) => {
    for (const platform of platforms) {
      if (capturedPlatforms.includes(platform)) continue;
      const prior = await tx.screenshot.findFirst({
        where: { platform, versionId: { not: newVersionId }, version: { comparisonId, variantName, viewport } },
        orderBy: { createdAt: 'desc' },
      });
      if (prior) {
        await tx.screenshot.create({
          data: { versionId: newVersionId, platform, device: prior.device, path: prior.path, width: prior.width, height: prior.height },
        });
      }
    }
  });
}

/**
 * The two screenshots shown when a version is selected: that version's own shot
 * per platform, falling back to the latest shot of a platform it didn't capture
 * (at or before its capture time) so the comparison stays useful.
 */
export async function versionShots(version) {
  const out = {};
  for (const platform of ALL_PLATFORMS) {
    let shot = await prisma.screenshot.findFirst({ where: { versionId: version.id, platform } });
    if (!shot) {
      // Fall back to the latest shot of the platform this version didn't capture
      // AT OR BEFORE its capture time (DB-1b), so a historical version pairs with
      // its contemporaneous shot rather than today's.
      shot = await prisma.screenshot.findFirst({
        where: { platform, createdAt: { lte: version.capturedAt }, version: { comparisonId: version.comparisonId, viewport: version.viewport } },
        orderBy: { createdAt: 'desc' },
      });
    }
    out[platform] = shot;
  }
  return out;
}

/**
 * Versions for a comparison, newest first, with platforms + rating + comment counts.
 * Optional filters (component-browser DB-3): `variantName`, `viewport` narrow the list;
 * `withScreenshots` includes the full Screenshot rows as `screenshots` on each entry.
 * The single-arg call keeps its original shape.
 */
export async function listVersions(comparisonId, { variantName, viewport, withScreenshots } = {}) {
  const rows = await prisma.version.findMany({
    where: { comparisonId, ...(variantName ? { variantName } : {}), ...(viewport ? { viewport } : {}) },
    orderBy: { capturedAt: 'desc' },
    include: { screenshots: withScreenshots ? true : { select: { platform: true } }, comments: { select: { resolved: true } } },
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
    // The fixture data this version was captured WITH, recorded at capture time.
    // Distinct from the fixture on disk, which is what the NEXT capture will
    // use — the two diverge as soon as the fixture is edited.
    sharedData: v.sharedData,
    componentName: v.componentName,
    platforms: [...new Set(v.screenshots.map((s) => s.platform))],
    commentCount: v.comments.length,
    unresolvedCount: v.comments.filter((c) => !c.resolved).length,
    ...(withScreenshots ? { screenshots: v.screenshots } : {}),
  }));
}

/**
 * The version a given source snapshot already produced, if any. UI 2.0 design
 * versions are keyed by the frozen PNG's sha: re-reading an unchanged asset must
 * NOT mint a new version, while a refreshed snapshot (a /ui2-component re-run)
 * must — that's what makes the design timeline meaningful.
 */
export async function findVersionBySourceHash(comparisonId, { variantName, viewport, sourceHash }) {
  return prisma.version.findFirst({ where: { comparisonId, variantName, viewport, sourceHash } });
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
/** A pin carries both coordinates; a chat message carries neither. */
function isAnchored(v) {
  return v !== null && v !== undefined && Number.isFinite(Number(v));
}
const clamp01 = (v) => Math.max(0, Math.min(1, Number(v)));

export async function addComment({ comparisonId, variantName = 'default', screenshotId, platform, viewport, x, y, text, source = 'user', targetSelector = null, targetLabel = null, targetMeta = null }) {
  if (!text || !String(text).trim()) throw new Error('comment text is required');
  if (!ALL_PLATFORMS.includes(platform)) throw new Error(`platform must be ${ALL_PLATFORMS.join('|')}`);
  if (!viewport) throw new Error('viewport is required');
  if (isAnchored(x) !== isAnchored(y)) throw new Error('x and y must both be set (a pin) or both omitted (an unanchored message)');

  // Resolve an anchor screenshot for pins drawn on an image (iPhone captures,
  // UI 2.0 design snapshots). The web pane is live, so it has none.
  let shot = null;
  if (screenshotId) {
    shot = await prisma.screenshot.findUnique({ where: { id: screenshotId }, include: { version: true } });
  } else if (platform !== 'client') {
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
      // Unanchored (x/y omitted or null) = a message about the variant as a whole, typed
      // into the comments panel's chat input. Distinct from a pin that happens to sit at
      // 0,0 — which is why these are NULL rather than a sentinel coordinate: the render
      // overlay filters on `x == null`, and nothing has to know a magic pair.
      x: isAnchored(x) ? clamp01(x) : null,
      y: isAnchored(y) ? clamp01(y) : null,
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
