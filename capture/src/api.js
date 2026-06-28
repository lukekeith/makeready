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
