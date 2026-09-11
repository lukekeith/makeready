export async function fetchPlatforms() {
  const res = await fetch('/api/platforms');
  if (!res.ok) throw new Error(`platforms fetch failed: ${res.status}`);
  return res.json();
}

export async function fetchManifest(platform) {
  const res = await fetch(`/api/${platform}/manifest`);
  if (!res.ok) throw new Error(`manifest fetch failed: ${res.status}`);
  return res.json();
}

export async function fetchFixture(platform, folder, file) {
  const res = await fetch(`/api/${platform}/fixture/${folder}/${file}`);
  if (!res.ok) throw new Error(`fixture fetch failed: ${res.status}`);
  return res.json();
}

export async function fetchBladeComponents(view, step) {
  const params = new URLSearchParams({ view });
  if (step) params.set('step', step);
  const res = await fetch(`/api/client/blade-components?${params}`);
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error ?? `blade-components fetch failed: ${res.status}`);
  }
  return res.json();
}

export async function startCapture(platform, { scope, target }) {
  const res = await fetch(`/api/${platform}/capture`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ scope, target }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error ?? `capture start failed: ${res.status}`);
  }
  return res.json();
}

// ── Compare ──

export async function fetchCompareManifest() {
  const res = await fetch('/api/compare/manifest');
  if (!res.ok) throw new Error(`compare manifest fetch failed: ${res.status}`);
  return res.json();
}

export async function fetchComparison(id) {
  const res = await fetch(`/api/compare/comparison/${id}`);
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error ?? `comparison fetch failed: ${res.status}`);
  }
  return res.json();
}

export async function saveComparisonShared(id, shared) {
  const res = await fetch(`/api/compare/comparison/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ shared }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error ?? `save failed: ${res.status}`);
  }
  return res.json();
}

export async function saveComparisonRating(id, rating, versionId) {
  const res = await fetch(`/api/compare/comparison/${id}/rating`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ rating, versionId }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error ?? `rating save failed: ${res.status}`);
  }
  return res.json();
}

// ── Versions ──

export async function fetchVersions(id) {
  const res = await fetch(`/api/compare/comparison/${id}/versions`);
  if (!res.ok) throw new Error(`versions fetch failed: ${res.status}`);
  return res.json();
}

export async function fetchVersion(id, versionId) {
  const res = await fetch(`/api/compare/comparison/${id}/version/${versionId}`);
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error ?? `version fetch failed: ${res.status}`);
  }
  return res.json();
}

// ── Variants (the version system replacement) ──

/** A comparison's variants + per-platform render counts (for the left nav). */
export async function fetchVariants(id, viewport) {
  const q = viewport ? `?viewport=${encodeURIComponent(viewport)}` : '';
  const res = await fetch(`/api/compare/comparison/${id}/variants${q}`);
  if (!res.ok) throw new Error(`variants fetch failed: ${res.status}`);
  return res.json();
}

/** A complete prompt to build the web (Vue) twin of an unbuilt component. */
export async function fetchBuildPrompt(id) {
  const res = await fetch(`/api/compare/comparison/${id}/build-prompt`);
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error ?? `build-prompt failed: ${res.status}`);
  }
  return res.json();
}

/** The variant-locked view: latest iPhone shot + live web + comments + rating. */
export async function fetchVariant(id, variant, viewport) {
  const q = viewport ? `?viewport=${encodeURIComponent(viewport)}` : '';
  const res = await fetch(`/api/compare/comparison/${id}/variant/${encodeURIComponent(variant)}${q}`);
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error ?? `variant fetch failed: ${res.status}`);
  }
  return res.json();
}

// ── Comments (Figma-style pins) ──

export async function fetchComments(id) {
  const res = await fetch(`/api/compare/comparison/${id}/comments`);
  if (!res.ok) throw new Error(`comments fetch failed: ${res.status}`);
  return res.json();
}

export async function addComment(id, { variantName, platform, viewport, x, y, text, screenshotId, source = 'user', targetSelector, targetLabel, targetMeta }) {
  const res = await fetch(`/api/compare/comparison/${id}/comments`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ variantName, platform, viewport, x, y, text, screenshotId, source, targetSelector, targetLabel, targetMeta }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error ?? `add comment failed: ${res.status}`);
  }
  return res.json();
}

export async function replyComment(id, commentId, text, source = 'user') {
  const res = await fetch(`/api/compare/comparison/${id}/comments/${commentId}/replies`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text, source }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error ?? `reply failed: ${res.status}`);
  }
  return res.json();
}

export async function resolveComment(id, commentId, resolved) {
  const res = await fetch(`/api/compare/comparison/${id}/comments/${commentId}/resolved`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ resolved }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error ?? `resolve failed: ${res.status}`);
  }
  return res.json();
}

export async function deleteComment(id, commentId) {
  const res = await fetch(`/api/compare/comparison/${id}/comments/${commentId}`, { method: 'DELETE' });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error ?? `delete comment failed: ${res.status}`);
  }
  return res.json();
}

export async function startCompareCapture({ id, viewport, platform, variant }) {
  const res = await fetch('/api/compare/capture', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ id, viewport, platform, variant }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error ?? `capture start failed: ${res.status}`);
  }
  return res.json();
}

export async function startCompareBatchCapture({ ids, viewport = 'pro-max' }) {
  const res = await fetch('/api/compare/capture-batch', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ ids, viewport }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error ?? `capture start failed: ${res.status}`);
  }
  return res.json();
}

export function subscribeCapture(runId, { onLine, onDone, onError } = {}) {
  const es = new EventSource(`/api/capture/stream/${runId}`);
  es.onmessage = (evt) => {
    try { onLine?.(JSON.parse(evt.data)); } catch { onLine?.(evt.data); }
  };
  es.addEventListener('done', (evt) => {
    try { onDone?.(JSON.parse(evt.data)); } catch { onDone?.({}); }
    es.close();
  });
  es.onerror = (err) => { onError?.(err); es.close(); };
  return () => es.close();
}

// ── Components browser (docs/features/component-browser 03 §2) ──

export async function fetchComponentsTree() {
  const res = await fetch('/api/components/tree');
  if (!res.ok) throw new Error(`components tree fetch failed: ${res.status}`);
  return res.json();
}

export async function fetchComponentDetail(path, viewport) {
  const q = new URLSearchParams({ path });
  if (viewport) q.set('viewport', viewport);
  const res = await fetch(`/api/components/detail?${q}`);
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error ?? `component detail fetch failed: ${res.status}`);
  }
  return res.json();
}

export async function fetchComponentVersion(versionId) {
  const res = await fetch(`/api/components/version/${encodeURIComponent(versionId)}`);
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error ?? `component version fetch failed: ${res.status}`);
  }
  return res.json();
}

export async function saveComponentFixture(path, variant, shared) {
  const res = await fetch('/api/components/fixture', {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ path, variant, shared }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error ?? `fixture save failed: ${res.status}`);
  }
  return res.json();
}

// ── UI 2.0 spec browser (docs/ui2 — the 2.0 era of the components browser) ──

export async function fetchUi2Tree() {
  const res = await fetch('/api/ui2/tree');
  if (!res.ok) throw new Error(`ui2 tree fetch failed: ${res.status}`);
  return res.json();
}

export async function fetchUi2Detail(id) {
  const res = await fetch(`/api/ui2/detail?${new URLSearchParams({ id })}`);
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error ?? `ui2 detail fetch failed: ${res.status}`);
  }
  return res.json();
}

export async function fetchUi2Screens() {
  const res = await fetch('/api/ui2/screens');
  if (!res.ok) throw new Error(`ui2 screens fetch failed: ${res.status}`);
  return res.json();
}

export async function fetchUi2ScreenDetail(id) {
  const res = await fetch(`/api/ui2/screen-detail?${new URLSearchParams({ id })}`);
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error ?? `ui2 screen fetch failed: ${res.status}`);
  }
  return res.json();
}

export async function fetchUi2Version(versionId) {
  const res = await fetch(`/api/ui2/version/${encodeURIComponent(versionId)}`);
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error ?? `ui2 version fetch failed: ${res.status}`);
  }
  return res.json();
}

/** Re-read the frozen Figma snapshot from disk; appends a design version if
 *  /ui2-component refreshed it. The 2.0 analogue of a recapture. */
export async function refreshUi2Snapshot(id) {
  const res = await fetch('/api/ui2/refresh', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ id }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error ?? `ui2 refresh failed: ${res.status}`);
  }
  return res.json();
}

/** Remove one capture from a state's timeline. Only versions carrying a built
 *  render can be deleted; the frozen-snapshot versions are refused (409). */
export async function deleteUi2Version(versionId) {
  const res = await fetch(`/api/ui2/version/${versionId}`, { method: 'DELETE' });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error ?? `version delete failed: ${res.status}`);
  }
  return res.json();
}

/** Edit the props ONE state of a built 2.0 component renders with, in
 *  capture/fixtures/ui2/C-###.json. `variant` is the state NAME, not its slug. */
export async function saveUi2Fixture(id, variant, props) {
  const res = await fetch('/api/ui2/fixture', {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ id, variant, props }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error ?? `ui2 fixture save failed: ${res.status}`);
  }
  return res.json();
}

/** Capture the BUILT side of a 2.0 component. Returns { runId } — the job streams
 *  over SSE; follow it with subscribeCapture(). */
export async function captureUi2(id, variant = '*') {
  const res = await fetch('/api/ui2/capture', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ id, variant }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error ?? `ui2 capture failed: ${res.status}`);
  }
  return res.json();
}

// ── UI 2.0 notes (docs/features/ui2-component-notes/03-data-and-api.md §2) ──

/** A target's notes, newest first, with every mention resolved to a current name. */
export async function fetchUi2Notes(target) {
  const res = await fetch(`/api/ui2/notes?${new URLSearchParams({ target })}`);
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error ?? `ui2 notes fetch failed: ${res.status}`);
  }
  return res.json();
}

/** Append one note. `after` is the newest note id the composer was opened with —
 *  the server 409s when the file has moved on since, rather than appending under
 *  a note this author never saw (suite 09 §G-7). */
export async function postUi2Note(target, body, after = null) {
  const res = await fetch('/api/ui2/notes', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ target, body, after }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error ?? `ui2 note save failed: ${res.status}`);
  }
  return res.json();
}

/** Every mentionable component and screen — fetched once and filtered in the
 *  composer, because it is ~98 rows and the typeahead runs per keystroke. */
export async function fetchUi2Mentions() {
  const res = await fetch('/api/ui2/mentions');
  if (!res.ok) throw new Error(`ui2 mentions fetch failed: ${res.status}`);
  return res.json();
}

