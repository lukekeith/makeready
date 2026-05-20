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
