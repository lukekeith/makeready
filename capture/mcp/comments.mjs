#!/usr/bin/env node
/**
 * MakeReady Capture-Compare MCP server.
 *
 * Exposes the capture comparison database (Postgres `makeready_capture`) so
 * Claude can read every unresolved comment with full context — the exact
 * component/screen, device, the screenshot files for both platforms, the
 * code version (git sha) + data snapshot that produced them, and the comment's
 * pixel position — then reply and resolve as it fixes things.
 *
 * Run standalone: node mcp/comments.mjs
 */
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import path from 'node:path';
import {
  prisma,
  listUnresolved,
  getComment,
  latestScreenshots,
  replyComment,
  setResolved,
  summarize,
} from '../db/index.mjs';
import { compareRoot } from '../runners/compare/lib.mjs';

const abs = (rel) => (rel ? path.join(compareRoot, rel) : null);

/** Rich, LLM-friendly description of one comment + everything around it. */
async function describeComment(c) {
  const latest = await latestScreenshots(c.comparisonId, c.viewport);
  const v = c.version ?? {};
  const px = {
    x: c.screenshot?.width ? Math.round(c.x * c.screenshot.width) : null,
    y: c.screenshot?.height ? Math.round(c.y * c.screenshot.height) : null,
  };
  return {
    commentId: c.id,
    comparison: { id: c.comparisonId, title: c.comparison?.title, type: c.comparison?.type },
    target: {
      platform: c.platform,
      viewport: c.viewport,
      component: v.componentName ?? null,
      iphoneView: v.iphoneView ?? null,
      clientView: v.clientView ?? null,
      device: c.screenshot?.device ?? null,
    },
    position: { xFraction: c.x, yFraction: c.y, xPx: px.x, yPx: px.y },
    pinnedScreenshot: abs(c.screenshot?.path),
    latestScreenshots: { iphone: abs(latest.iphone?.path), client: abs(latest.client?.path) },
    version: { id: c.versionId, capturedAt: v.capturedAt, gitSha: v.gitSha, gitDirty: v.gitDirty, sourceHash: v.sourceHash },
    sharedData: v.sharedData ?? null,
    thread: (c.messages ?? []).map((m) => ({ source: m.source, text: m.text, at: m.createdAt })),
    createdAt: c.createdAt,
  };
}

const server = new McpServer({ name: 'makeready-capture', version: '1.0.0' });

server.tool(
  'list_unresolved_comments',
  'List every UNRESOLVED compare comment with full context: the component/screen, device, both platforms\' latest screenshot file paths, the code version (git sha) + data that produced them, the pin position, and the message thread. Read the screenshot files to see what the user is pointing at. Optionally filter by comparison id.',
  { comparisonId: z.string().optional().describe('Filter to one comparison (e.g. "card-study")') },
  async ({ comparisonId }) => {
    const rows = await listUnresolved(comparisonId);
    const described = [];
    for (const c of rows) described.push(await describeComment(c));
    if (described.length === 0) {
      return { content: [{ type: 'text', text: comparisonId ? `No unresolved comments for "${comparisonId}".` : 'No unresolved comments anywhere. 🎉' }] };
    }
    return { content: [{ type: 'text', text: `${described.length} unresolved comment(s):\n\n${JSON.stringify(described, null, 2)}` }] };
  },
);

server.tool(
  'get_comment',
  'Get one comment by id with full context (component, device, screenshot paths, version, data, thread).',
  { commentId: z.string().describe('The comment id') },
  async ({ commentId }) => {
    const c = await getComment(commentId);
    if (!c) return { content: [{ type: 'text', text: `Comment "${commentId}" not found.` }] };
    return { content: [{ type: 'text', text: JSON.stringify(await describeComment(c), null, 2) }] };
  },
);

server.tool(
  'list_comparisons',
  'List all comparisons in the capture database with their rating and unresolved-comment count.',
  {},
  async () => {
    const rows = await prisma.comparison.findMany({ orderBy: [{ type: 'asc' }, { id: 'asc' }] });
    const out = [];
    for (const r of rows) {
      const { total, unresolved } = await summarize(r.id);
      out.push({ id: r.id, title: r.title, type: r.type, rating: r.rating, comments: total, unresolved });
    }
    return { content: [{ type: 'text', text: JSON.stringify(out, null, 2) }] };
  },
);

server.tool(
  'get_latest_screenshots',
  'Get the absolute file paths of the latest iPhone + Web screenshots for a comparison + viewport, so you can Read them to compare.',
  {
    comparisonId: z.string(),
    viewport: z.string().describe('e.g. "pro-max", "se"'),
  },
  async ({ comparisonId, viewport }) => {
    const latest = await latestScreenshots(comparisonId, viewport);
    return {
      content: [{
        type: 'text',
        text: JSON.stringify({
          iphone: { path: abs(latest.iphone?.path), capturedAt: latest.iphone?.createdAt ?? null, gitSha: latest.iphone?.version?.gitSha ?? null },
          client: { path: abs(latest.client?.path), capturedAt: latest.client?.createdAt ?? null, gitSha: latest.client?.version?.gitSha ?? null },
        }, null, 2),
      }],
    };
  },
);

server.tool(
  'reply_comment',
  'Add a reply to a comment (as Claude). Use this to record what you changed for that comment.',
  { commentId: z.string(), text: z.string() },
  async ({ commentId, text }) => {
    await replyComment(commentId, text, 'claude');
    return { content: [{ type: 'text', text: `Replied to ${commentId}.` }] };
  },
);

server.tool(
  'resolve_comment',
  'Mark a comment resolved (true) or reopen it (false). Resolve only once the issue is actually fixed and verified.',
  { commentId: z.string(), resolved: z.boolean().default(true) },
  async ({ commentId, resolved }) => {
    await setResolved(commentId, resolved);
    return { content: [{ type: 'text', text: `${resolved ? 'Resolved' : 'Reopened'} ${commentId}.` }] };
  },
);

const transport = new StdioServerTransport();
await server.connect(transport);
