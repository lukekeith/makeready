/**
 * Adapter: edit-day (page comparison).
 * EditDay — the lesson editor listing a day's activity cards (ViewRegistry
 * pages.edit-day). The web side renders the CAPTURE-ONLY EditDay twin
 * (production = edit-day-pane.vue); the card title/description/status
 * mapping below mirrors EditDay.swift studyActivityCard/videoActivityCard
 * exactly so the twin receives pre-resolved card props.
 */

// iOS ActivityType.displayName (StudyModels.swift).
const DISPLAY_NAME = {
  USER_INPUT: 'Study',
  READ: 'Read',
  YOUTUBE: 'YouTube',
  EXEGESIS: 'Exegesis',
};
const displayName = (type) => DISPLAY_NAME[type] ?? type;

// iOS StudyActivity.isConfigured (StudyModels.swift).
function isConfigured(a) {
  switch (a.type) {
    case 'VIDEO':
      return Boolean(a.videoId || a.videoUrl);
    case 'YOUTUBE':
      return Boolean(a.youtubeUrl);
    case 'READ':
      if (a.readBlocks) return a.readBlocks.some((b) => (b.content ?? '') !== '');
      return Boolean(a.readContent);
    case 'EXEGESIS': {
      if (!a.title) return false;
      const locked = a.readBlocks?.find((b) => b.isLocked);
      return Boolean(locked?.content) && (locked.selections ?? []).length > 0;
    }
    case 'USER_INPUT':
      return Boolean(a.title);
    default:
      return Boolean(a.passageReference);
  }
}

// iOS EditDay.swift studyActivityCard pendingLabel.
function pendingLabel(type) {
  switch (type) {
    case 'READ': return 'Provide text to read';
    case 'USER_INPUT': return 'Describe what you want members to input';
    case 'EXEGESIS': return 'Select passage and add highlights';
    default: return 'Select passage';
  }
}

// iOS EditDay.swift readBlockSummary.
function readSummary(a) {
  const block = [...(a.readBlocks ?? [])].sort((x, y) => x.orderNumber - y.orderNumber)[0];
  if (!block?.content) return null;
  return block.title ? `${block.title}\n${block.content}` : block.content;
}

// One card, mirroring studyActivityCard / videoActivityCard.
function toCard(a) {
  const ready = isConfigured(a);
  const estimatedMinutes = a.estimatedSeconds
    ? Math.max(1, Math.round(a.estimatedSeconds / 60))
    : undefined;

  if (a.type === 'VIDEO') {
    return {
      id: a.id,
      type: a.type,
      title: a.videoTitle ?? a.title ?? displayName(a.type),
      description: ready ? a.videoDuration : 'Select video',
      status: ready ? 'confirmed' : 'new',
      estimatedMinutes,
      // iOS videoActivityCard passes play.fill (icon travels as data on iOS).
      iconKey: 'play',
    };
  }

  let description;
  if (!ready) {
    description = pendingLabel(a.type);
  } else if (a.type === 'READ' && readSummary(a)) {
    description = readSummary(a);
  } else if (a.type === 'EXEGESIS' && a.readBlocks?.find((b) => b.isLocked)?.title) {
    description = a.readBlocks.find((b) => b.isLocked).title;
  } else {
    description = a.passageReference ?? displayName(a.type);
  }

  return {
    id: a.id,
    type: a.type,
    title: a.passageReference ?? (a.title || null) ?? (a.type === 'USER_INPUT' ? 'Write' : displayName(a.type)),
    description,
    status: ready ? 'confirmed' : 'new',
    estimatedMinutes,
  };
}

export default {
  toClient(shared) {
    const lesson = shared?.lesson ?? {};
    return {
      platform: 'client',
      view: 'pages.leader-twin',
      data: {
        component: 'EditDay',
        componentProps: {
          statusBar: true,
          day: lesson.dayNumber ?? 1,
          lessonTitle: lesson.title ?? '',
          activities: (lesson.activities ?? []).map(toCard),
        },
      },
    };
  },

  toIphone(shared) {
    const { user = {}, lesson = {}, programId = 'capture-prog-0', programName } = shared ?? {};
    return {
      platform: 'iphone',
      view: 'pages.edit-day',
      auth: {
        isAuthenticated: true,
        currentUser: {
          id: user.id ?? 'user-1',
          name: user.name ?? 'Alex Rivera',
          email: user.email ?? 'alex@example.com',
          picture: user.picture ?? null,
        },
      },
      state: {
        programId,
        programName,
        lessonId: lesson.id ?? 'capture-lesson-0',
        lessons: [lesson],
      },
    };
  },
};
