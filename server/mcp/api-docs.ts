#!/usr/bin/env node

/**
 * MakeReady API Docs MCP Server
 *
 * Exposes OpenAPI documentation as MCP tools so Claude can query
 * specific endpoints on demand without reading all route files.
 *
 * Run standalone: npx tsx mcp/api-docs.ts
 */

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js'
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js'
import { z } from 'zod'
import swaggerJsdoc from 'swagger-jsdoc'
import path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

// ── Generate OpenAPI spec from route files (fresh on each call) ─────

// Import the shared definition - use path.resolve for tsx compatibility
const { definition } = await import(path.resolve(__dirname, '../src/docs/openapi-definition.ts'))

const swaggerOptions = {
  definition,
  apis: [
    path.join(__dirname, '../src/routes/*.ts'),
    path.join(__dirname, '../src/routes/*.js'),
  ],
}

function getSpec(): Record<string, any> {
  return swaggerJsdoc(swaggerOptions) as Record<string, any>
}

// ── Helpers ─────────────────────────────────────────────────────────

interface EndpointInfo {
  method: string
  path: string
  summary: string
  description?: string
  tags: string[]
  security: string[]
  parameters?: any[]
  requestBody?: any
  responses?: any
}

function getAllEndpoints(spec: Record<string, any>): EndpointInfo[] {
  const endpoints: EndpointInfo[] = []
  const paths = spec.paths || {}

  for (const pathKey of Object.keys(paths)) {
    const pathItem = paths[pathKey]
    for (const method of Object.keys(pathItem)) {
      if (!['get', 'post', 'put', 'patch', 'delete'].includes(method)) continue
      const op = pathItem[method]
      const security = (op.security || [])
        .flatMap((s: Record<string, any>) => Object.keys(s))
      endpoints.push({
        method: method.toUpperCase(),
        path: pathKey,
        summary: op.summary || '',
        description: op.description,
        tags: op.tags || [],
        security,
        parameters: op.parameters,
        requestBody: op.requestBody,
        responses: op.responses,
      })
    }
  }

  return endpoints
}

function formatEndpointLine(ep: EndpointInfo): string {
  const tags = ep.tags.length ? ` [${ep.tags.join(', ')}]` : ''
  const auth = ep.security.length ? ` (${ep.security.join(', ')})` : ' (public)'
  return `${ep.method} ${ep.path} - ${ep.summary}${tags}${auth}`
}

function resolveRef(spec: Record<string, any>, ref: string): any {
  // e.g. "#/components/schemas/Member"
  const parts = ref.replace('#/', '').split('/')
  let obj: any = spec
  for (const part of parts) {
    obj = obj?.[part]
  }
  return obj
}

function resolveSchema(spec: Record<string, any>, schema: any): any {
  if (!schema) return schema
  if (schema.$ref) return resolveRef(spec, schema.$ref)
  if (schema.allOf) {
    const merged: any = {}
    for (const item of schema.allOf) {
      const resolved = resolveSchema(spec, item)
      Object.assign(merged, resolved)
      if (resolved.properties) {
        merged.properties = { ...merged.properties, ...resolved.properties }
      }
    }
    return merged
  }
  if (schema.items) {
    return { ...schema, items: resolveSchema(spec, schema.items) }
  }
  return schema
}

function schemaToMarkdown(spec: Record<string, any>, schema: any, indent = 0): string {
  const resolved = resolveSchema(spec, schema)
  if (!resolved) return 'N/A'

  const prefix = '  '.repeat(indent)

  if (resolved.type === 'object' && resolved.properties) {
    const required = new Set(resolved.required || [])
    const lines: string[] = []
    for (const [name, prop] of Object.entries(resolved.properties) as [string, any][]) {
      const resolvedProp = resolveSchema(spec, prop)
      const req = required.has(name) ? '' : '?'
      const type = resolvedProp.enum
        ? `enum(${resolvedProp.enum.join('|')})`
        : resolvedProp.format
          ? `${resolvedProp.type}(${resolvedProp.format})`
          : resolvedProp.type || 'any'
      const nullable = resolvedProp.nullable ? ', nullable' : ''
      const desc = resolvedProp.description ? ` — ${resolvedProp.description}` : ''
      const example = resolvedProp.example !== undefined ? ` (e.g. ${JSON.stringify(resolvedProp.example)})` : ''
      lines.push(`${prefix}- \`${name}${req}\`: ${type}${nullable}${desc}${example}`)

      if (resolvedProp.type === 'object' && resolvedProp.properties) {
        lines.push(schemaToMarkdown(spec, resolvedProp, indent + 1))
      }
    }
    return lines.join('\n')
  }

  if (resolved.type === 'array') {
    const itemResolved = resolveSchema(spec, resolved.items)
    if (itemResolved?.type === 'object' && itemResolved.properties) {
      return `${prefix}Array of:\n${schemaToMarkdown(spec, itemResolved, indent + 1)}`
    }
    return `${prefix}Array of ${itemResolved?.type || 'any'}`
  }

  return `${prefix}${resolved.type || JSON.stringify(resolved)}`
}

function endpointToMarkdown(spec: Record<string, any>, ep: EndpointInfo): string {
  const lines: string[] = []

  lines.push(`## ${ep.method} ${ep.path}`)
  lines.push('')
  if (ep.summary) lines.push(`**Summary:** ${ep.summary}`)
  if (ep.description) lines.push(`\n${ep.description}`)
  lines.push(`**Tags:** ${ep.tags.join(', ') || 'none'}`)
  lines.push(`**Auth:** ${ep.security.length ? ep.security.join(', ') : 'none (public)'}`)

  // Parameters
  if (ep.parameters?.length) {
    lines.push('')
    lines.push('### Parameters')
    for (const param of ep.parameters) {
      const required = param.required ? '' : '?'
      const schema = resolveSchema(spec, param.schema)
      const type = schema?.type || 'any'
      const desc = param.description ? ` — ${param.description}` : ''
      lines.push(`- \`${param.name}${required}\` (${param.in}): ${type}${desc}`)
    }
  }

  // Request body
  if (ep.requestBody) {
    lines.push('')
    lines.push('### Request Body')
    const content = ep.requestBody.content
    if (content) {
      for (const [contentType, mediaType] of Object.entries(content) as [string, any][]) {
        if (contentType !== 'application/json') {
          lines.push(`Content-Type: ${contentType}`)
        }
        if (mediaType.schema) {
          lines.push(schemaToMarkdown(spec, mediaType.schema))
        }
      }
    }
  }

  // Responses
  if (ep.responses) {
    lines.push('')
    lines.push('### Responses')
    for (const [code, response] of Object.entries(ep.responses) as [string, any][]) {
      lines.push(`\n**${code}:** ${response.description || ''}`)
      const content = response.content
      if (content?.['application/json']?.schema) {
        lines.push(schemaToMarkdown(spec, content['application/json'].schema))
      }
    }
  }

  return lines.join('\n')
}

// ── MCP Server ──────────────────────────────────────────────────────

const server = new McpServer({
  name: 'makeready-api',
  version: '1.0.0',
})

// Tool 1: List endpoints with optional filters
server.tool(
  'list_api_endpoints',
  'Browse MakeReady API endpoints. Filter by tag (e.g. "Groups"), method (e.g. "POST"), or path substring (e.g. "/members"). Returns compact list with method, path, summary, tags, and auth.',
  {
    tag: z.string().optional().describe('Filter by tag name (case-insensitive)'),
    method: z.string().optional().describe('Filter by HTTP method (GET, POST, PATCH, DELETE)'),
    path: z.string().optional().describe('Filter by path substring'),
  },
  async ({ tag, method, path: pathFilter }) => {
    const spec = getSpec()
    let endpoints = getAllEndpoints(spec)

    if (tag) {
      const tagLower = tag.toLowerCase()
      endpoints = endpoints.filter(ep =>
        ep.tags.some(t => t.toLowerCase().includes(tagLower))
      )
    }
    if (method) {
      const methodUpper = method.toUpperCase()
      endpoints = endpoints.filter(ep => ep.method === methodUpper)
    }
    if (pathFilter) {
      const pathLower = pathFilter.toLowerCase()
      endpoints = endpoints.filter(ep =>
        ep.path.toLowerCase().includes(pathLower)
      )
    }

    if (endpoints.length === 0) {
      return { content: [{ type: 'text', text: 'No endpoints match the given filters.' }] }
    }

    const text = [
      `Found ${endpoints.length} endpoint(s):`,
      '',
      ...endpoints.map(formatEndpointLine),
    ].join('\n')

    return { content: [{ type: 'text', text }] }
  }
)

// Tool 2: Full docs for one endpoint
server.tool(
  'get_endpoint_detail',
  'Get full documentation for a specific API endpoint including description, auth, parameters, request body schema, and response schemas.',
  {
    method: z.string().describe('HTTP method (GET, POST, PATCH, DELETE)'),
    path: z.string().describe('Endpoint path (e.g. /api/groups)'),
  },
  async ({ method, path: reqPath }) => {
    const spec = getSpec()
    const endpoints = getAllEndpoints(spec)
    const match = endpoints.find(
      ep => ep.method === method.toUpperCase() && ep.path === reqPath
    )

    if (!match) {
      // Suggest close matches
      const similar = endpoints.filter(ep =>
        ep.path.includes(reqPath) || reqPath.includes(ep.path)
      )
      const suggestions = similar.length
        ? `\n\nDid you mean:\n${similar.map(formatEndpointLine).join('\n')}`
        : `\n\nAvailable paths containing "${reqPath.split('/').pop()}":\n${endpoints.filter(ep => ep.path.includes(reqPath.split('/').pop() || '')).map(formatEndpointLine).join('\n')}`

      return {
        content: [{
          type: 'text',
          text: `No endpoint found for ${method.toUpperCase()} ${reqPath}${suggestions}`,
        }],
      }
    }

    return { content: [{ type: 'text', text: endpointToMarkdown(spec, match) }] }
  }
)

// Tool 3: Schema definitions
server.tool(
  'get_schema',
  'Get a data model schema definition (e.g. Member, Group, Program). Shows all properties with types. If no name given or no match, lists available schemas.',
  {
    name: z.string().optional().describe('Schema name (e.g. Member, Group, Event)'),
  },
  async ({ name }) => {
    const spec = getSpec()
    const schemas = spec.components?.schemas || {}
    const schemaNames = Object.keys(schemas)

    if (!name) {
      return {
        content: [{
          type: 'text',
          text: `Available schemas (${schemaNames.length}):\n${schemaNames.map(n => `- ${n}`).join('\n')}`,
        }],
      }
    }

    // Case-insensitive match
    const match = schemaNames.find(n => n.toLowerCase() === name.toLowerCase())

    if (!match) {
      const similar = schemaNames.filter(n =>
        n.toLowerCase().includes(name.toLowerCase())
      )
      const suggestion = similar.length
        ? `\n\nSimilar schemas:\n${similar.map(n => `- ${n}`).join('\n')}`
        : `\n\nAvailable schemas:\n${schemaNames.map(n => `- ${n}`).join('\n')}`

      return {
        content: [{ type: 'text', text: `No schema named "${name}" found.${suggestion}` }],
      }
    }

    const schema = schemas[match]
    const lines = [
      `## ${match}`,
      '',
      schemaToMarkdown(spec, schema),
    ]

    return { content: [{ type: 'text', text: lines.join('\n') }] }
  }
)

// Tool 4: Free-text search
server.tool(
  'search_api',
  'Search across all API endpoints by keyword. Matches against path, summary, description, and tags. Returns matching endpoints with summaries.',
  {
    query: z.string().describe('Search query (e.g. "phone verification", "upload", "lesson progress")'),
  },
  async ({ query }) => {
    const queryLower = query.toLowerCase()
    const queryTerms = queryLower.split(/\s+/)
    const endpoints = getAllEndpoints(getSpec())

    const scored = endpoints.map(ep => {
      const searchText = [
        ep.method,
        ep.path,
        ep.summary,
        ep.description || '',
        ...ep.tags,
      ].join(' ').toLowerCase()

      let score = 0
      for (const term of queryTerms) {
        if (searchText.includes(term)) score++
      }
      // Bonus for exact phrase match
      if (searchText.includes(queryLower)) score += queryTerms.length

      return { ep, score }
    })

    const matches = scored
      .filter(s => s.score > 0)
      .sort((a, b) => b.score - a.score)

    if (matches.length === 0) {
      return {
        content: [{
          type: 'text',
          text: `No endpoints matched "${query}". Try broader terms or use list_api_endpoints to browse by tag.`,
        }],
      }
    }

    const text = [
      `Found ${matches.length} endpoint(s) matching "${query}":`,
      '',
      ...matches.map(({ ep, score }) =>
        `${formatEndpointLine(ep)}${score > queryTerms.length ? ' ★' : ''}`
      ),
    ].join('\n')

    return { content: [{ type: 'text', text }] }
  }
)

// ── Start ───────────────────────────────────────────────────────────

const transport = new StdioServerTransport()
await server.connect(transport)
