/**
 * Adapter: CardLesson (component comparison).
 *
 * Projects one canonical lesson-card description into:
 *   - toClient → card-lesson.vue via the ComponentCapture island
 *   - toIphone → CardLesson.swift via the component.CardLesson ViewRegistry case
 *
 * The canonical `shared` block matches the SwiftUI prop bag (mode, day,
 * activities, …) so the iPhone side passes it straight through. For the web
 * twin we reshape per mode:
 *   - planning activities keep their SF-symbol `icon`, mapped to inline SVG.
 *   - lesson activities carry a raw `type` (READ/VIDEO/…); the Vue component
 *     derives the colored icon box from it, so we just forward `activityType`.
 *   - `date` is pre-formatted here ("Friday, Jan 30, 2026") to avoid timezone
 *     drift in the browser.
 *   - `lessonStatus` ("complete" | "next" | "upcoming:Thursday") splits into a
 *     `status` + `upcomingText` pair.
 */

// Planning-mode SF symbols → inline SVG (small 14px white glyphs).
const PLANNING_ICONS = {
  book:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/></svg>',
  'play.fill':
    '<svg viewBox="0 0 24 24" fill="currentColor" stroke="none"><path d="M8 5v14l11-7z"/></svg>',
};

function formatDate(iso) {
  if (!iso) return undefined;
  // Parse as a local date (avoid UTC midnight shifting the day).
  const [y, m, d] = iso.split('-').map(Number);
  const date = new Date(y, (m ?? 1) - 1, d ?? 1);
  return date.toLocaleDateString('en-US', {
    weekday: 'long',
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
}

function splitStatus(lessonStatus) {
  if (!lessonStatus) return { status: undefined, upcomingText: undefined };
  if (lessonStatus.startsWith('upcoming')) {
    const text = lessonStatus.split(':')[1] ?? 'Upcoming';
    return { status: 'upcoming', upcomingText: text };
  }
  return { status: lessonStatus, upcomingText: undefined };
}

function toClientProps(shared) {
  const { mode = 'planning', day, activities = [] } = shared ?? {};

  if (mode === 'planning') {
    return {
      mode,
      day,
      activities: activities.map((a) => ({
        icon: PLANNING_ICONS[a.icon] ?? '',
        type: a.type,
        title: a.title,
        isConfigured: a.isConfigured !== false,
      })),
    };
  }

  if (mode === 'lesson') {
    return {
      mode,
      day,
      title: shared.title,
      date: formatDate(shared.date),
      estimatedMinutes: shared.estimatedMinutes,
      activities: activities.map((a) => ({
        activityType: a.type,
        status: a.status ?? 'default',
      })),
    };
  }

  if (mode === 'progress') {
    return {
      mode,
      day,
      title: shared.title,
      description: shared.description,
      progress: shared.progress,
      sections: (shared.sections ?? []).map((s) => ({
        name: s.name,
        completed: s.completed === true,
      })),
    };
  }

  // lessonList
  const { status, upcomingText } = splitStatus(shared.lessonStatus);
  return {
    mode,
    day,
    title: shared.title,
    status,
    upcomingText,
  };
}

export default {
  toClient(shared) {
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the
      // iPhone sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'CardLesson',
        componentProps: toClientProps(shared),
      },
    };
  },

  toIphone(shared) {
    return {
      platform: 'iphone',
      view: 'component.CardLesson',
      state: { component: shared ?? {} },
    };
  },
};
