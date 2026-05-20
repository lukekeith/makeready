/**
 * @openapi
 * tags:
 *   - name: Join
 *     description: |
 *       Open Graph meta tag pages for social media link previews.
 *       These endpoints serve HTML pages designed to be shared on social media, iMessage, etc.
 *       They include Open Graph and Twitter Card meta tags for rich previews and automatically
 *       redirect users to the client application.
 *
 *       **Note:** These endpoints return HTML content, not JSON. They are public endpoints
 *       that do not require authentication.
 */

/**
 * @openapi
 * components:
 *   schemas:
 *     JoinPageHtml:
 *       type: string
 *       description: |
 *         HTML page with Open Graph meta tags for social media previews.
 *         The page includes:
 *         - Open Graph meta tags (og:title, og:description, og:image, etc.)
 *         - Twitter Card meta tags
 *         - Apple/iMessage meta tags
 *         - Automatic redirect to the client application
 *         - Fallback content for users with JavaScript disabled
 *       example: |
 *         <!DOCTYPE html>
 *         <html lang="en">
 *         <head>
 *           <meta property="og:title" content="Join Group Name on MakeReady">
 *           <meta property="og:description" content="...">
 *           <meta http-equiv="refresh" content="0;url=...">
 *         </head>
 *         ...
 *         </html>
 */

import { Router } from 'express';
import { prisma } from '../lib/prisma.js';
import {
  generateGroupOgMeta,
  generateEventOgMeta,
  generateLessonOgMeta,
  generateStudyOgMeta,
} from '../lib/og-meta.js';

const router = Router();

/**
 * @openapi
 * /join/group/{code}:
 *   get:
 *     tags: [Join]
 *     summary: Get OG meta page for joining a group
 *     description: |
 *       Generates an HTML page with Open Graph meta tags for sharing group invite links
 *       on social media platforms. The page displays a rich preview with the group's
 *       name, description, and cover image, then redirects to the client app.
 *
 *       **Example URL:** https://app.makeready.org/join/group/NNNM76
 *     parameters:
 *       - name: code
 *         in: path
 *         required: true
 *         description: The 6-character alphanumeric group code
 *         schema:
 *           type: string
 *           pattern: '^[A-Z0-9]{6}$'
 *           example: NNNM76
 *     responses:
 *       200:
 *         description: HTML page with Open Graph meta tags
 *         content:
 *           text/html:
 *             schema:
 *               $ref: '#/components/schemas/JoinPageHtml'
 */
router.get('/group/:code', async (req, res) => {
  const { code } = req.params;
  const clientUrl = process.env.CLIENT_URL || 'https://app.makeready.org';

  const result = await generateGroupOgMeta(code, clientUrl);

  res.setHeader('Content-Type', 'text/html');
  res.send(result.html);
});

/**
 * @openapi
 * /join/group/{code}/study/{studyCode}:
 *   get:
 *     tags: [Join]
 *     summary: Get OG meta page for joining a scheduled lesson in a group
 *     description: |
 *       Generates an HTML page with Open Graph meta tags for sharing scheduled lesson
 *       (study) invite links on social media platforms. The page displays a rich preview
 *       with the lesson title, group name, and scheduled time, then redirects to the client app.
 *
 *       **Example URL:** https://app.makeready.org/join/group/NNNM76/study/ABC123
 *     parameters:
 *       - name: code
 *         in: path
 *         required: true
 *         description: The 6-character alphanumeric group code
 *         schema:
 *           type: string
 *           pattern: '^[A-Z0-9]{6}$'
 *           example: NNNM76
 *       - name: studyCode
 *         in: path
 *         required: true
 *         description: The 6-character alphanumeric study/lesson code
 *         schema:
 *           type: string
 *           pattern: '^[A-Z0-9]{6}$'
 *           example: ABC123
 *     responses:
 *       200:
 *         description: HTML page with Open Graph meta tags
 *         content:
 *           text/html:
 *             schema:
 *               $ref: '#/components/schemas/JoinPageHtml'
 */
router.get('/group/:code/study/:studyCode', async (req, res) => {
  const { code, studyCode } = req.params;
  const clientUrl = process.env.CLIENT_URL || 'https://app.makeready.org';

  const result = await generateLessonOgMeta(code, studyCode, clientUrl);

  res.setHeader('Content-Type', 'text/html');
  res.send(result.html);
});

/**
 * @openapi
 * /join/study/{id}:
 *   get:
 *     tags: [Join]
 *     summary: Get OG meta page for joining a scheduled lesson by ID or code
 *     description: |
 *       Generates an HTML page with Open Graph meta tags for sharing scheduled lesson
 *       (study) invite links on social media platforms. Supports both UUID and 6-character
 *       alphanumeric codes for flexibility.
 *
 *       **Example URLs:**
 *       - https://app.makeready.org/join/study/765c2f2e-e0f6-45c4-ac44-6ee767da96ac
 *       - https://app.makeready.org/join/study/ABC123
 *     parameters:
 *       - name: id
 *         in: path
 *         required: true
 *         description: The study/lesson identifier - either a UUID or 6-character alphanumeric code
 *         schema:
 *           type: string
 *           oneOf:
 *             - pattern: '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
 *               description: UUID format
 *             - pattern: '^[A-Z0-9]{6}$'
 *               description: 6-character alphanumeric code
 *           examples:
 *             uuid:
 *               value: 765c2f2e-e0f6-45c4-ac44-6ee767da96ac
 *               summary: UUID format
 *             code:
 *               value: ABC123
 *               summary: Short code format
 *     responses:
 *       200:
 *         description: HTML page with Open Graph meta tags
 *         content:
 *           text/html:
 *             schema:
 *               $ref: '#/components/schemas/JoinPageHtml'
 */
router.get('/study/:id', async (req, res) => {
  const { id } = req.params;
  const clientUrl = process.env.CLIENT_URL || 'https://app.makeready.org';

  const result = await generateStudyOgMeta(id, clientUrl);

  res.setHeader('Content-Type', 'text/html');
  res.send(result.html);
});

/**
 * @openapi
 * /join/group/{code}/event/{eventCode}:
 *   get:
 *     tags: [Join]
 *     summary: Get OG meta page for viewing an event
 *     description: |
 *       Generates an HTML page with Open Graph meta tags for sharing event links
 *       on social media platforms. The page displays a rich preview with the event
 *       title, description, date/time, and location, then redirects to the client app.
 *
 *       **Example URL:** https://app.makeready.org/join/group/NNNM76/event/ABC123
 *     parameters:
 *       - name: code
 *         in: path
 *         required: true
 *         description: The 6-character alphanumeric group code
 *         schema:
 *           type: string
 *           pattern: '^[A-Z0-9]{6}$'
 *           example: NNNM76
 *       - name: eventCode
 *         in: path
 *         required: true
 *         description: The 6-character alphanumeric event code
 *         schema:
 *           type: string
 *           pattern: '^[A-Z0-9]{6}$'
 *           example: ABC123
 *     responses:
 *       200:
 *         description: HTML page with Open Graph meta tags
 *         content:
 *           text/html:
 *             schema:
 *               $ref: '#/components/schemas/JoinPageHtml'
 */
router.get('/group/:code/event/:eventCode', async (req, res) => {
  const { code, eventCode } = req.params;
  const clientUrl = process.env.CLIENT_URL || 'https://app.makeready.org';

  const result = await generateEventOgMeta(code, eventCode, clientUrl);

  res.setHeader('Content-Type', 'text/html');
  res.send(result.html);
});

/**
 * @openapi
 * /join/{token}:
 *   get:
 *     tags: [Join]
 *     summary: Get OG meta page for direct invite token
 *     description: |
 *       Generates an HTML page with Open Graph meta tags for sharing personal/direct
 *       invite links on social media platforms. This endpoint handles legacy personal
 *       invites with unique tokens.
 *
 *       The page displays:
 *       - Group name and cover image (if available)
 *       - Inviter's name
 *       - Invitation status (valid or expired)
 *
 *       If the invite is invalid or expired, a fallback page is shown with a link
 *       to the MakeReady homepage.
 *
 *       **Example URL:** https://app.makeready.org/join/abc123xyz
 *     parameters:
 *       - name: token
 *         in: path
 *         required: true
 *         description: The unique invite token string
 *         schema:
 *           type: string
 *           minLength: 1
 *           example: abc123xyz789def
 *     responses:
 *       200:
 *         description: |
 *           HTML page with Open Graph meta tags. The page content varies based on
 *           invite validity:
 *           - **Valid invite:** Shows group name, inviter name, and "Join Group" button
 *           - **Invalid/expired invite:** Shows "Invite Not Found" message with link to homepage
 *
 *           In both cases, the page automatically redirects to the client app.
 *         content:
 *           text/html:
 *             schema:
 *               $ref: '#/components/schemas/JoinPageHtml'
 *             examples:
 *               validInvite:
 *                 summary: Valid invite page
 *                 value: |
 *                   <!DOCTYPE html>
 *                   <html lang="en">
 *                   <head>
 *                     <meta property="og:title" content="Join Bible Study Group on MakeReady">
 *                     <meta property="og:description" content="John Doe invited you to join Bible Study Group. Tap to accept your invitation.">
 *                     ...
 *                   </head>
 *                   ...
 *                   </html>
 *               invalidInvite:
 *                 summary: Invalid or expired invite page
 *                 value: |
 *                   <!DOCTYPE html>
 *                   <html lang="en">
 *                   <head>
 *                     <meta property="og:title" content="Join on MakeReady">
 *                     <meta property="og:description" content="You've been invited to join a group on MakeReady.">
 *                     ...
 *                   </head>
 *                   ...
 *                   </html>
 */
router.get('/:token', async (req, res) => {
  const { token } = req.params;
  const clientUrl = process.env.CLIENT_URL || 'https://app.makeready.org';

  try {
    // Fetch invite with group and inviter details
    const invite = await prisma.invite.findUnique({
      where: { token },
      include: {
        group: true,
        inviter: true,
      },
    });

    // Default values for invalid/expired invites
    let title = 'Join on MakeReady';
    let description = "You've been invited to join a group on MakeReady.";
    let imageUrl = `${clientUrl}/og-default.png`;
    let groupName = 'MakeReady Group';
    let inviterName = 'Someone';
    let isValid = false;

    if (invite && invite.status === 'pending') {
      // Check if expired
      const isExpired =
        invite.expiresAt && new Date(invite.expiresAt) < new Date();

      if (!isExpired) {
        isValid = true;
        groupName = invite.group?.name || 'MakeReady Group';
        inviterName = invite.inviter?.name || 'Someone';
        title = `Join ${groupName} on MakeReady`;
        description = `${inviterName} invited you to join ${groupName}. Tap to accept your invitation.`;

        // Use group cover image if available
        if (invite.group?.coverImageUrl) {
          imageUrl = invite.group.coverImageUrl;
        }
      }
    }

    // Build the client redirect URL using the group's join code
    const groupCode = invite?.group?.code;
    const clientJoinUrl = groupCode
      ? `${clientUrl}/join/group/${groupCode}?invite=${token}`
      : `${clientUrl}/join/group?invite=${token}`;

    // Generate HTML with Open Graph meta tags
    const html = generateInviteHtml({
      title,
      description,
      imageUrl,
      url: clientJoinUrl,
      groupName,
      inviterName,
      isValid,
      clientUrl,
    });

    res.setHeader('Content-Type', 'text/html');
    res.send(html);
  } catch (error) {
    console.error('[Join] Error fetching invite:', error);

    // Return a basic error page that redirects to enter-code page
    const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Join on MakeReady</title>
  <meta property="og:title" content="Join on MakeReady">
  <meta property="og:description" content="You've been invited to join a group on MakeReady.">
  <meta http-equiv="refresh" content="0;url=${clientUrl}/join/group?invite=${token}">
</head>
<body>
  <script>window.location.href = '${clientUrl}/join/group?invite=${token}';</script>
</body>
</html>`;

    res.setHeader('Content-Type', 'text/html');
    res.send(html);
  }
});

// ============================================================================
// Helper for invite token pages (keeps legacy format)
// ============================================================================

interface InviteHtmlOptions {
  title: string;
  description: string;
  imageUrl: string;
  url: string;
  groupName: string;
  inviterName: string;
  isValid: boolean;
  clientUrl: string;
}

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

function generateInviteHtml(options: InviteHtmlOptions): string {
  const {
    title,
    description,
    imageUrl,
    url,
    groupName,
    inviterName,
    isValid,
    clientUrl,
  } = options;

  const hasCustomImage = !imageUrl.includes('og-default');

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
      hasCustomImage
        ? `<img src="${escapeHtml(imageUrl)}" alt="${escapeHtml(groupName)}" class="cover-image">`
        : `<div class="logo">
      <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2">
        <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
        <circle cx="9" cy="7" r="4"/>
        <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
        <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
      </svg>
    </div>`
    }
    <h1>${escapeHtml(isValid ? `Join ${groupName}` : 'Invite Not Found')}</h1>
    <p>${escapeHtml(isValid ? `${inviterName} invited you to join this group.` : 'This invite link is invalid or has expired.')}</p>
    ${isValid ? `<a href="${escapeHtml(url)}" class="button">Join Group</a>` : `<a href="${clientUrl}" class="button">Go to MakeReady</a>`}
    <p class="redirect-text">Redirecting you automatically...</p>
  </div>
  <script>window.location.href = '${escapeHtml(url)}';</script>
</body>
</html>`;
}

export default router;
