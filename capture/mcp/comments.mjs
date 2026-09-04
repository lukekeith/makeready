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
import { buildInventory, queryInventory } from '../runners/compare/inventory.mjs';
// describeComment moved to the shared lib (component-browser suite) so the HTTP
// scope route and these tools emit identical payloads. Behavior unchanged.
import { describeComment, buildScopePayload } from '../lib/comment-payload.mjs';
import { ScopeError } from '../lib/fs-index.mjs';

const abs = (rel) => (rel ? path.join(compareRoot, rel) : null);

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
  'inventory',
  'Cross-platform component/page/layout inventory for replicating the iPhone UI on web. ' +
    'Each entry reports whether it EXISTS on iphone vs client(web), its per-variant schema ' +
    '(the prop fields + sample options), capture status per platform, rating, unresolved ' +
    'comment counts per platform, and a per-variant match status ' +
    '(no-web-twin | uncaptured | commented | rating-mismatch | matched). ' +
    'Use the filters to answer the common questions:\n' +
    '  • "components that do NOT exist on the client app" → missingOnClient:true\n' +
    '  • "components that exist but have comments on the client implementation" → hasClientComments:true\n' +
    '  • "components with variants that do not match" → mismatched:true\n' +
    'Sort defaults to most-variants first; pass limit for "top N". Set detail:true for each variant\'s full data.',
  {
    missingOnClient: z.boolean().optional().describe('Only components with no web/client twin yet'),
    hasClientComments: z.boolean().optional().describe('Only components that have a web twin AND unresolved client comments'),
    mismatched: z.boolean().optional().describe('Only components with ≥1 variant flagged commented or low-rated'),
    type: z.enum(['component', 'page', 'layout']).optional().describe('Filter by kind'),
    sort: z.enum(['variants', 'comments', 'mismatches', 'alpha']).optional().describe('Sort order (default: variants)'),
    limit: z.number().int().positive().optional().describe('Return only the top N'),
    detail: z.boolean().optional().describe('Include each variant\'s full prop data (heavier)'),
  },
  async ({ missingOnClient, hasClientComments, mismatched, type, sort, limit, detail }) => {
    const inv = await buildInventory({ detail: !!detail });
    const rows = queryInventory(inv, { missingOnClient, hasClientComments, mismatched, type, sort, limit });
    if (rows.length === 0) {
      return { content: [{ type: 'text', text: 'No components matched that query.' }] };
    }
    return { content: [{ type: 'text', text: `${rows.length} component(s):\n\n${JSON.stringify(rows, null, 2)}` }] };
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

server.tool(
  'resolve_scope',
  'Resolve a component-browser scope (an iPhone filesystem path relative to iphone/MakeReady/Components/) into its matched components and every UNRESOLVED iPhone-platform comment across all variants and versions. Scope forms: "Card/CardEvent" (one component) · "Card/**" or "Card" (folder, recursive) · "**" (everything) · a bare unique component name. Each comment carries the full context payload plus versionLabel ("current" | "old — captured <date>; current version is <id>" | "unanchored") so old-render comments read as references against the current render. Used by /component-resolve.',
  { scope: z.string().describe('e.g. "Card/CardEvent", "Card/**", "**", or a unique component name') },
  async ({ scope }) => {
    try {
      const payload = await buildScopePayload(scope);
      return { content: [{ type: 'text', text: JSON.stringify(payload, null, 2) }] };
    } catch (err) {
      if (err instanceof ScopeError) {
        return { content: [{ type: 'text', text: `Scope error (${err.code}): ${err.message}${err.paths.length ? `\nPaths: ${err.paths.join(', ')}` : ''}` }] };
      }
      throw err;
    }
  },
);

const transport = new StdioServerTransport();
await server.connect(transport);
