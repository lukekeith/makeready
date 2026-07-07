/**
 * Open Graph Meta Tag Generator
 *
 * Generates HTML pages with OG meta tags for social media link previews.
 * Handles groups, studies, and events with proper cover image fallbacks.
 */

import { prisma } from './prisma.js';
import { normalizeGroupCode } from './group-code.js';

const DEFAULT_CLIENT_URL = 'https://app.makeready.org';

/**
 * Escape HTML special characters to prevent XSS
 */
function escapeHtml(text: string): string {
  const map: Record<string, string> = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#039;',
  };
  return text.replace(/[&<>"']/g, (char) => map[char]);
}

// ============================================================================
// Types
// ============================================================================

export type OgContentType = 'group' | 'study' | 'event' | 'lesson';

export interface OgMetaResult {
  html: string;
  found: boolean;
}

interface OgContent {
  title: string;
  description: string;
  imageUrl: string;
  url: string;
  isValid: boolean;
}

// ============================================================================
// Content Fetchers
// ============================================================================

/**
 * Fetch group data for OG meta tags
 */
async function fetchGroupContent(code: string, clientUrl: string): Promise<OgContent> {
  const normalizedCode = normalizeGroupCode(code);

  const group = await prisma.group.findUnique({
    where: { code: normalizedCode },
    include: {
      _count: {
        select: { members: { where: { isActive: true } } },
      },
    },
  });

  if (!group) {
    return {
      title: 'Join on MakeReady',
      description: 'Join a group on MakeReady.',
      imageUrl: `${clientUrl}/og-default.png`,
      url: `${clientUrl}/join/group/${code}`,
      isValid: false,
    };
  }

  const memberCount = group._count.members;
  const memberText = memberCount === 1 ? '1 member' : `${memberCount} members`;

  return {
    title: `Join ${group.name} on MakeReady`,
    description: group.description
      ? truncateText(group.description, 150)
      : `Join ${group.name} with ${memberText}.`,
    imageUrl: group.coverImageUrl || `${clientUrl}/og-default.png`,
    url: `${clientUrl}/join/group/${code}`,
    isValid: true,
  };
}

/**
 * Fetch lesson data for OG meta tags
 * Falls back to program cover image, then group cover image
 */
async function fetchLessonContent(
  groupCode: string,
  lessonCode: string,
  clientUrl: string
): Promise<OgContent> {
  const normalizedGroupCode = normalizeGroupCode(groupCode);
  const normalizedLessonCode = lessonCode.toUpperCase().trim();

  // Fetch group first
  const group = await prisma.group.findUnique({
    where: { code: normalizedGroupCode },
  });

  if (!group) {
    return {
      title: 'Study on MakeReady',
      description: 'Join a Bible study on MakeReady.',
      imageUrl: `${clientUrl}/og-default.png`,
      url: `${clientUrl}/join/group/${groupCode}/study/${lessonCode}`,
      isValid: false,
    };
  }

  // Find the lesson schedule by code
  const schedule = await prisma.lessonSchedule.findFirst({
    where: {
      code: normalizedLessonCode,
      enrollment: {
        groupId: group.id,
      },
    },
    include: {
      lesson: {
        include: {
          studyProgram: true,
        },
      },
      scheduledActivities: {
        orderBy: { orderNumber: 'asc' },
        take: 1,
        include: { sourceReferences: true },
      },
    },
  });

  if (!schedule || !schedule.lesson) {
    return {
      title: `${group.name} Study`,
      description: 'Join a Bible study on MakeReady.',
      imageUrl: group.coverImageUrl || `${clientUrl}/og-default.png`,
      url: `${clientUrl}/join/group/${groupCode}/study/${lessonCode}`,
      isValid: false,
    };
  }

  const program = schedule.lesson.studyProgram;
  const dayNumber = schedule.lesson.dayNumber;
  const totalDays = program.days;
  const firstActivity = schedule.scheduledActivities[0];
  const passageReference = firstActivity?.sourceReferences?.[0]?.passageReference;

  // Cover image priority: program > group > default
  const coverImage =
    program.coverImageUrl || group.coverImageUrl || `${clientUrl}/og-default.png`;

  // Build description
  let description = `Day ${dayNumber} of ${totalDays}`;
  if (passageReference) {
    description += ` • ${passageReference}`;
  }
  description += ` with ${group.name}`;

  return {
    title: `${program.name} - Day ${dayNumber}`,
    description,
    imageUrl: coverImage,
    url: `${clientUrl}/join/group/${groupCode}/study/${lessonCode}`,
    isValid: true,
  };
}

/**
 * Fetch lesson data for OG meta tags by ID or code (without requiring group code)
 * Supports both UUID (lesson schedule ID) and 6-char alphanumeric codes
 */
async function fetchLessonContentByIdOrCode(
  idOrCode: string,
  clientUrl: string
): Promise<OgContent> {
  // Determine if this looks like a UUID or a short code
  const isUuid = idOrCode.length > 10 && idOrCode.includes('-');

  let schedule;

  const lessonScheduleInclude = {
    lesson: {
      include: {
        studyProgram: true,
      },
    },
    scheduledActivities: {
      orderBy: { orderNumber: 'asc' as const },
      take: 1,
      include: { sourceReferences: true },
    },
    enrollment: {
      include: {
        group: true,
      },
    },
  };

  if (isUuid) {
    // Look up by ID
    schedule = await prisma.lessonSchedule.findUnique({
      where: { id: idOrCode },
      include: lessonScheduleInclude,
    });
  } else {
    // Look up by 6-char code
    const normalizedCode = idOrCode.toUpperCase().trim();
    schedule = await prisma.lessonSchedule.findFirst({
      where: { code: normalizedCode },
      include: lessonScheduleInclude,
    });
  }

  if (!schedule || !schedule.lesson) {
    return {
      title: 'Study on MakeReady',
      description: 'Join a Bible study on MakeReady.',
      imageUrl: `${clientUrl}/og-default.png`,
      url: `${clientUrl}/join/study/${idOrCode}`,
      isValid: false,
    };
  }

  const group = schedule.enrollment.group;
  const program = schedule.lesson.studyProgram;
  const dayNumber = schedule.lesson.dayNumber;
  const totalDays = program.days;
  const firstActivity = schedule.scheduledActivities[0];
  const passageReference = firstActivity?.sourceReferences?.[0]?.passageReference;

  // Cover image priority: program > group > default
  const coverImage =
    program.coverImageUrl || group.coverImageUrl || `${clientUrl}/og-default.png`;

  // Build description
  let description = `Day ${dayNumber} of ${totalDays}`;
  if (passageReference) {
    description += ` • ${passageReference}`;
  }
  description += ` with ${group.name}`;

  return {
    title: `${program.name} - Day ${dayNumber}`,
    description,
    imageUrl: coverImage,
    // Always use the schedule ID in the URL for consistency
    url: `${clientUrl}/join/study/${schedule.id}`,
    isValid: true,
  };
}

/**
 * Fetch event data for OG meta tags
 * Falls back to group cover image if event has none
 */
async function fetchEventContent(
  groupCode: string,
  eventCode: string,
  clientUrl: string
): Promise<OgContent> {
  const normalizedGroupCode = normalizeGroupCode(groupCode);

  // Fetch group first
  const group = await prisma.group.findUnique({
    where: { code: normalizedGroupCode },
  });

  if (!group) {
    return {
      title: 'Event on MakeReady',
      description: 'View event details on MakeReady.',
      imageUrl: `${clientUrl}/og-default.png`,
      url: `${clientUrl}/join/group/${groupCode}/event/${eventCode}`,
      isValid: false,
    };
  }

  // Find the event
  const event = await prisma.event.findFirst({
    where: {
      groupId: group.id,
      code: eventCode.toUpperCase(),
    },
  });

  if (!event) {
    return {
      title: `${group.name} Event`,
      description: 'View event details on MakeReady.',
      imageUrl: group.coverImageUrl || `${clientUrl}/og-default.png`,
      url: `${clientUrl}/join/group/${groupCode}/event/${eventCode}`,
      isValid: false,
    };
  }

  // Cover image priority: event > group > default
  const coverImage =
    event.coverImageUrl || group.coverImageUrl || `${clientUrl}/og-default.png`;

  // Format event date
  const eventDate = new Date(event.date);
  const dateStr = eventDate.toLocaleDateString('en-US', {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
  });

  return {
    title: `${event.title} - ${group.name}`,
    description: event.description
      ? truncateText(event.description, 150)
      : `${dateStr} with ${group.name}`,
    imageUrl: coverImage,
    url: `${clientUrl}/join/group/${groupCode}/event/${eventCode}`,
    isValid: true,
  };
}

// ============================================================================
// HTML Generator
// ============================================================================

/**
 * Generate HTML page with Open Graph meta tags
 */
function generateHtml(content: OgContent, clientUrl: string): string {
  const { title, description, imageUrl, url, isValid } = content;

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(title)}</title>

  <!-- Open Graph / Facebook -->
  <meta property="og:type" content="website">
  <meta property="og:url" content="${escapeHtml(url)}">
  <meta property="og:title" content="${escapeHtml(title)}">
  <meta property="og:description" content="${escapeHtml(description)}">
  <meta property="og:image" content="${escapeHtml(imageUrl)}">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:site_name" content="MakeReady">

  <!-- Twitter Card -->
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${escapeHtml(title)}">
  <meta name="twitter:description" content="${escapeHtml(description)}">
  <meta name="twitter:image" content="${escapeHtml(imageUrl)}">

  <!-- Apple / iMessage -->
  <meta name="apple-mobile-web-app-title" content="MakeReady">
  <link rel="apple-touch-icon" href="${clientUrl}/apple-touch-icon.png">

  <!-- Redirect to client app -->
  <meta http-equiv="refresh" content="0;url=${escapeHtml(url)}">

  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      background: #0d101a;
      color: white;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 2rem;
      text-align: center;
    }
    .container { max-width: 400px; width: 100%; }
    .logo {
      width: 80px; height: 80px;
      background: linear-gradient(135deg, #6c47ff, #9747ff);
      border-radius: 20px;
      margin: 0 auto 1.5rem;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .cover-image {
      width: 100%;
      height: 200px;
      object-fit: cover;
      border-radius: 12px;
      margin-bottom: 1.5rem;
    }
    h1 { font-size: 1.5rem; font-weight: 700; margin-bottom: 0.75rem; }
    p { color: rgba(255,255,255,0.7); font-size: 1rem; line-height: 1.5; margin-bottom: 1.5rem; }
    .button {
      display: inline-block;
      background: #6c47ff;
      color: white;
      text-decoration: none;
      padding: 1rem 2rem;
      border-radius: 12px;
      font-weight: 600;
      font-size: 1rem;
      transition: background 0.2s;
    }
    .button:hover { background: #5a3dd6; }
    .redirect-text { margin-top: 1.5rem; font-size: 0.875rem; color: rgba(255,255,255,0.5); }
  </style>
</head>
<body>
  <div class="container">
    ${
      imageUrl.includes('og-default')
        ? `<div class="logo">
      <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2">
        <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
        <circle cx="9" cy="7" r="4"/>
        <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
        <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
      </svg>
    </div>`
        : `<img src="${escapeHtml(imageUrl)}" alt="Cover" class="cover-image">`
    }
    <h1>${escapeHtml(title)}</h1>
    <p>${escapeHtml(description)}</p>
    ${isValid ? `<a href="${escapeHtml(url)}" class="button">Open</a>` : `<a href="${clientUrl}" class="button">Go to MakeReady</a>`}
    <p class="redirect-text">Redirecting you automatically...</p>
  </div>
  <script>window.location.href = '${escapeHtml(url)}';</script>
</body>
</html>`;
}

/**
 * Generate a minimal error HTML page
 */
function generateErrorHtml(url: string): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>MakeReady</title>
  <meta property="og:title" content="MakeReady">
  <meta property="og:description" content="Join groups and studies on MakeReady.">
  <meta http-equiv="refresh" content="0;url=${escapeHtml(url)}">
</head>
<body>
  <script>window.location.href = '${escapeHtml(url)}';</script>
</body>
</html>`;
}

// ============================================================================
// Utilities
// ============================================================================

/**
 * Truncate text to a maximum length with ellipsis
 */
function truncateText(text: string, maxLength: number): string {
  if (text.length <= maxLength) return text;
  return text.substring(0, maxLength).trim() + '...';
}

// ============================================================================
// Public API
// ============================================================================

/**
 * Generate OG meta HTML for a group join page
 */
export async function generateGroupOgMeta(
  code: string,
  clientUrl: string = DEFAULT_CLIENT_URL
): Promise<OgMetaResult> {
  try {
    const content = await fetchGroupContent(code, clientUrl);
    return {
      html: generateHtml(content, clientUrl),
      found: content.isValid,
    };
  } catch (error) {
    console.error('[OG Meta] Error generating group meta:', error);
    return {
      html: generateErrorHtml(`${clientUrl}/join/group/${code}`),
      found: false,
    };
  }
}

/**
 * Generate OG meta HTML for an event page
 */
export async function generateEventOgMeta(
  groupCode: string,
  eventCode: string,
  clientUrl: string = DEFAULT_CLIENT_URL
): Promise<OgMetaResult> {
  try {
    const content = await fetchEventContent(groupCode, eventCode, clientUrl);
    return {
      html: generateHtml(content, clientUrl),
      found: content.isValid,
    };
  } catch (error) {
    console.error('[OG Meta] Error generating event meta:', error);
    return {
      html: generateErrorHtml(`${clientUrl}/join/group/${groupCode}/event/${eventCode}`),
      found: false,
    };
  }
}

/**
 * Generate OG meta HTML for a lesson page (legacy route with group code)
 */
export async function generateLessonOgMeta(
  groupCode: string,
  lessonCode: string,
  clientUrl: string = DEFAULT_CLIENT_URL
): Promise<OgMetaResult> {
  try {
    const content = await fetchLessonContent(groupCode, lessonCode, clientUrl);
    return {
      html: generateHtml(content, clientUrl),
      found: content.isValid,
    };
  } catch (error) {
    console.error('[OG Meta] Error generating lesson meta:', error);
    return {
      html: generateErrorHtml(`${clientUrl}/join/group/${groupCode}/study/${lessonCode}`),
      found: false,
    };
  }
}

/**
 * Generate OG meta HTML for a study page by ID or code
 * Supports both UUID (lesson schedule ID) and 6-char alphanumeric codes
 */
export async function generateStudyOgMeta(
  idOrCode: string,
  clientUrl: string = DEFAULT_CLIENT_URL
): Promise<OgMetaResult> {
  try {
    const content = await fetchLessonContentByIdOrCode(idOrCode, clientUrl);
    return {
      html: generateHtml(content, clientUrl),
      found: content.isValid,
    };
  } catch (error) {
    console.error('[OG Meta] Error generating study meta:', error);
    return {
      html: generateErrorHtml(`${clientUrl}/join/study/${idOrCode}`),
      found: false,
    };
  }
}
