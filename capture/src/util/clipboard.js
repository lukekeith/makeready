// Clipboard write with a fallback for non-secure origins.
//
// navigator.clipboard is gated on a secure context. The capture UI is served over plain
// http:// on a LAN address as often as it is on localhost, and only localhost counts as
// secure — so the async API is genuinely absent for some of the people using this, and the
// execCommand path is a real code path, not legacy politeness.
export async function copyToClipboard(text) {
  try {
    await navigator.clipboard.writeText(text);
  } catch {
    const ta = document.createElement('textarea');
    ta.value = text;
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand('copy'); } catch { /* ignore */ }
    document.body.removeChild(ta);
  }
}

export default copyToClipboard;
