// Minimal classnames helper (no clsx dependency). Accepts strings, arrays, and
// objects ({ "Class--active": isActive }); falsy entries are dropped.
export function classnames(...inputs) {
  const out = [];
  for (const input of inputs) {
    if (!input) continue;
    if (typeof input === 'string' || typeof input === 'number') {
      out.push(String(input));
    } else if (Array.isArray(input)) {
      const inner = classnames(...input);
      if (inner) out.push(inner);
    } else if (typeof input === 'object') {
      for (const [key, value] of Object.entries(input)) {
        if (value) out.push(key);
      }
    }
  }
  return out.join(' ');
}
