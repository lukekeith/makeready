/**
 * Adapter: DatePickerField (component comparison, two-sided twin).
 *
 * Projects one canonical date-picker-field description into:
 *   - toClient → date-picker-field.vue via the ComponentCapture island
 *   - toIphone → DatePickerField.swift via the component.DatePickerField case
 *               (wrapped in a FieldGroup by ViewRegistry, unchanged)
 *
 * DATE/TIME PARITY: the iOS field formats the same Date twice —
 *   - date pill: DateFormatters.monthPaddedDayYear ("MMM dd, yyyy") → "Jan 30, 2026"
 *   - time pill: DateFormatters.shortTime (timeStyle .short)        → "03:41"
 * Both render in the device's LOCAL timezone. The capture host and the iOS
 * simulator share the machine timezone, so we format here with NO explicit
 * timeZone (same approach the dated card twins use — see the date-range note in
 * memory). `en-GB` gives the simulator's 24-hour short time ("03:41"); `en-US`
 * gives the zero-padded medium-ish date ("Jan 30, 2026").
 */
function formatDate(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return String(iso);
  // iOS monthPaddedDayYear → "MMM dd, yyyy" (zero-padded day).
  return d.toLocaleDateString('en-US', {
    month: 'short',
    day: '2-digit',
    year: 'numeric',
  });
}

function formatTime(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  // iOS shortTime (timeStyle .short) → 24-hour "HH:mm" in the simulator locale.
  return d.toLocaleTimeString('en-GB', {
    hour: '2-digit',
    minute: '2-digit',
  });
}

export default {
  toClient(shared = {}) {
    const { label, date } = shared;
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop to the component wrapper (FieldGroup + 16px gutters), matching
      // the iPhone snapshot (ViewRegistry wraps the field in FieldGroup.padding(16)).
      clip: '.capture-wrap',
      data: {
        component: 'DatePickerField',
        componentProps: {
          label: label ?? 'Date',
          dateText: formatDate(date),
          timeText: formatTime(date),
        },
      },
    };
  },

  toIphone(shared = {}) {
    // Forward the canonical shape unchanged.
    return {
      platform: 'iphone',
      view: 'component.DatePickerField',
      state: { component: shared },
    };
  },
};
