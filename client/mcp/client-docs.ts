#!/usr/bin/env node

/**
 * MakeReady Client Docs MCP Server
 *
 * Exposes the client app's routes, Blade components, Vue components,
 * layouts, pages, and stores so that sibling apps (server, iphone)
 * always have up-to-date knowledge of the web client's structure.
 *
 * Everything is read fresh from disk on each tool call — no caching,
 * so changes are reflected immediately.
 *
 * Run standalone: npx tsx mcp/client-docs.ts
 */

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js'
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js'
import { z } from 'zod'
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const CLIENT_ROOT = path.resolve(__dirname, '..')

// ── Helpers ─────────────────────────────────────────────────────────

function readFile(filePath: string): string {
  return fs.readFileSync(filePath, 'utf-8')
}

function listFiles(dir: string, ext?: string): string[] {
  if (!fs.existsSync(dir)) return []
  return fs.readdirSync(dir, { recursive: true })
    .map(f => f.toString())
    .filter(f => !ext || f.endsWith(ext))
    .sort()
}

// ── Route Parsing ───────────────────────────────────────────────────

interface RouteInfo {
  method: string
  path: string
  controller: string
  action: string
  name: string
  middleware: string[]
  section: string
}

function parseRoutes(): RouteInfo[] {
  const routeFile = path.join(CLIENT_ROOT, 'routes/web.php')
  if (!fs.existsSync(routeFile)) return []
  const content = readFile(routeFile)
  const routes: RouteInfo[] = []

  // Track current middleware/prefix context
  let currentMiddleware: string[] = []
  let currentPrefix = ''
  let currentSection = 'Public'

  const lines = content.split('\n')

  for (const line of lines) {
    const trimmed = line.trim()

    // Detect section comments
    const sectionMatch = trimmed.match(/^\/\/\s*[─━]+\s*(.+?)\s*[─━]+/)
    if (sectionMatch) {
      currentSection = sectionMatch[1].trim()
    }

    // Detect middleware groups
    const middlewareMatch = trimmed.match(/Route::middleware\(['"](.+?)['"]\)->prefix\(['"](.+?)['"]\)/)
    if (middlewareMatch) {
      currentMiddleware = [middlewareMatch[1]]
      currentPrefix = '/' + middlewareMatch[2]
      continue
    }

    // Detect prefix-only groups
    const prefixMatch = trimmed.match(/Route::prefix\(['"](.+?)['"]\)/)
    if (prefixMatch && !trimmed.includes('middleware')) {
      currentPrefix = '/' + prefixMatch[1]
      continue
    }

    // Detect closing group
    if (trimmed === '});') {
      currentMiddleware = []
      currentPrefix = ''
      continue
    }

    // Parse route definitions
    const routeMatch = trimmed.match(
      /Route::(get|post|put|patch|delete|match)\((?:\[.*?\],\s*)?['"]([^'"]+)['"]\s*,\s*\[([^,]+)::class\s*,\s*['"](\w+)['"]\]\)(?:.*?->name\(['"]([^'"]+)['"]\))?/i
    )
    if (routeMatch) {
      const [, method, routePath, controller, action, name] = routeMatch
      const fullPath = currentPrefix + routePath
      const controllerName = controller.trim().split('\\').pop() || controller

      routes.push({
        method: method.toUpperCase(),
        path: fullPath,
        controller: controllerName,
        action,
        name: name || '',
        middleware: [...currentMiddleware],
        section: currentSection,
      })
    }

    // Handle Route::match
    const matchRoute = trimmed.match(
      /Route::match\(\[(.+?)\]\s*,\s*['"]([^'"]+)['"]\s*,\s*\[([^,]+)::class\s*,\s*['"](\w+)['"]\]\)/
    )
    if (matchRoute) {
      const [, methods, routePath, controller, action] = matchRoute
      const fullPath = currentPrefix + routePath
      const controllerName = controller.trim().split('\\').pop() || controller
      const nameMatch = trimmed.match(/->name\(['"]([^'"]+)['"]\)/)

      routes.push({
        method: methods.replace(/['"]/g, '').trim(),
        path: fullPath,
        controller: controllerName,
        action,
        name: nameMatch?.[1] || '',
        middleware: [...currentMiddleware],
        section: currentSection,
      })
    }
  }

  return routes
}

function formatRouteList(routes: RouteInfo[]): string {
  const sections = new Map<string, RouteInfo[]>()
  for (const r of routes) {
    const sec = r.section
    if (!sections.has(sec)) sections.set(sec, [])
    sections.get(sec)!.push(r)
  }

  const lines: string[] = []
  for (const [section, sectionRoutes] of sections) {
    lines.push(`## ${section}`)
    lines.push('')
    for (const r of sectionRoutes) {
      const auth = r.middleware.length ? ` [${r.middleware.join(', ')}]` : ' (public)'
      const name = r.name ? ` → ${r.name}` : ''
      lines.push(`${r.method.padEnd(8)} ${r.path}${auth}`)
      lines.push(`         ${r.controller}@${r.action}${name}`)
    }
    lines.push('')
  }

  return lines.join('\n')
}

// ── Component Parsing ───────────────────────────────────────────────

interface BladeComponentInfo {
  name: string
  category: string
  path: string
  props: BladePropsInfo[]
  slots: string[]
  variants: Record<string, Record<string, string>>
  defaultVariants: Record<string, string>
}

interface BladePropsInfo {
  name: string
  default: string | null
}

function parseBladeComponent(filePath: string, name: string, category: string): BladeComponentInfo {
  const content = readFile(filePath)
  const info: BladeComponentInfo = {
    name,
    category,
    path: path.relative(CLIENT_ROOT, filePath),
    props: [],
    slots: [],
    variants: {},
    defaultVariants: {},
  }

  // Parse @props directive
  const propsMatch = content.match(/@props\(\[([\s\S]*?)\]\)/)
  if (propsMatch) {
    const propsBlock = propsMatch[1]
    // Match each 'key' => value line
    const propRegex = /['"](\w[-\w]*)['"]\s*=>\s*(.+)/g
    let match
    while ((match = propRegex.exec(propsBlock)) !== null) {
      info.props.push({
        name: match[1],
        default: match[2].trim().replace(/,\s*$/, '').trim(),
      })
    }
  }

  // Parse slots — exclude known props and standard Blade variables
  const propNames = new Set(info.props.map(p => p.name))
  const nonSlots = new Set(['attributes', 'errors', 'loop', 'component', '__env', '__data'])

  const slotRegex = /\{\{\s*\$(\w+)\s*\}\}/g
  const slots = new Set<string>()
  let slotMatch
  while ((slotMatch = slotRegex.exec(content)) !== null) {
    const name = slotMatch[1]
    if (!propNames.has(name) && !nonSlots.has(name)) {
      slots.add(name)
    }
  }
  // Also check @isset($name) for named slots
  const issetRegex = /@isset\(\$(\w+)\)/g
  while ((slotMatch = issetRegex.exec(content)) !== null) {
    const name = slotMatch[1]
    if (!propNames.has(name) && !nonSlots.has(name)) {
      slots.add(name)
    }
  }
  info.slots = Array.from(slots)

  // Parse CVA variants — find all cva() calls and extract variant options
  const cvaRegex = /cva\(['"](\w+)['"],\s*\[/g
  let cvaStart
  while ((cvaStart = cvaRegex.exec(content)) !== null) {
    // Extract the full config array by counting bracket depth
    const startIdx = cvaStart.index + cvaStart[0].length - 1 // position of '['
    let depth = 0
    let endIdx = startIdx
    for (let i = startIdx; i < content.length; i++) {
      if (content[i] === '[') depth++
      else if (content[i] === ']') depth--
      if (depth === 0) { endIdx = i; break }
    }
    const configBlock = content.slice(startIdx, endIdx + 1)

    // Find 'variants' => [...] block inside config
    const variantsStart = configBlock.indexOf("'variants'")
    if (variantsStart === -1) continue

    // Find the opening '[' after 'variants' =>
    const variantsArrayStart = configBlock.indexOf('[', variantsStart + 10)
    if (variantsArrayStart === -1) continue

    // Extract matched bracket content for variants
    let vDepth = 0
    let vEnd = variantsArrayStart
    for (let i = variantsArrayStart; i < configBlock.length; i++) {
      if (configBlock[i] === '[') vDepth++
      else if (configBlock[i] === ']') vDepth--
      if (vDepth === 0) { vEnd = i; break }
    }
    const variantsBlock = configBlock.slice(variantsArrayStart + 1, vEnd)

    // Parse each variant dimension: 'name' => ['Option' => 'class', ...]
    const dimRegex = /'(\w+)'\s*=>\s*\[([^\]]*)\]/g
    let dimMatch
    while ((dimMatch = dimRegex.exec(variantsBlock)) !== null) {
      const variantName = dimMatch[1]
      const options: Record<string, string> = {}
      const optionRegex = /'(\w+)'\s*=>\s*'([^']+)'/g
      let optMatch
      while ((optMatch = optionRegex.exec(dimMatch[2])) !== null) {
        options[optMatch[1]] = optMatch[2]
      }
      if (Object.keys(options).length > 0) {
        // Merge (multiple cva calls in same component get combined)
        info.variants[variantName] = { ...info.variants[variantName], ...options }
      }
    }

    // Parse defaultVariants
    const defaultStart = configBlock.indexOf("'defaultVariants'")
    if (defaultStart !== -1) {
      const defArrayStart = configBlock.indexOf('[', defaultStart + 17)
      if (defArrayStart !== -1) {
        const defArrayEnd = configBlock.indexOf(']', defArrayStart)
        const defBlock = configBlock.slice(defArrayStart, defArrayEnd + 1)
        const defRegex = /'(\w+)'\s*=>\s*'(\w+)'/g
        let defMatch
        while ((defMatch = defRegex.exec(defBlock)) !== null) {
          info.defaultVariants[defMatch[1]] = defMatch[2]
        }
      }
    }
  }

  return info
}

function getAllBladeComponents(): BladeComponentInfo[] {
  const componentsDir = path.join(CLIENT_ROOT, 'resources/views/components')
  if (!fs.existsSync(componentsDir)) return []

  const components: BladeComponentInfo[] = []
  const categories = fs.readdirSync(componentsDir).filter(f =>
    fs.statSync(path.join(componentsDir, f)).isDirectory()
  )

  for (const category of categories) {
    const catDir = path.join(componentsDir, category)
    const files = listFiles(catDir, '.blade.php')
    for (const file of files) {
      const name = path.basename(file, '.blade.php')
      components.push(parseBladeComponent(path.join(catDir, file), name, category))
    }
  }

  return components
}

interface VueComponentInfo {
  name: string
  category: string
  path: string
  props: VuePropInfo[]
  emits: string[]
  hasStory: boolean
}

interface VuePropInfo {
  name: string
  type: string
  required: boolean
  default?: string
}

function parseVueComponent(filePath: string, name: string, category: string): VueComponentInfo {
  const content = readFile(filePath)
  const info: VueComponentInfo = {
    name,
    category,
    path: path.relative(CLIENT_ROOT, filePath),
    props: [],
    emits: [],
    hasStory: false,
  }

  // Check for story file
  const storyPath = filePath.replace('.vue', '.story.vue')
  info.hasStory = fs.existsSync(storyPath)

  // Parse defineProps
  const propsMatch = content.match(/defineProps<\{([\s\S]*?)\}>/)
    || content.match(/defineProps\(\{([\s\S]*?)\}\)/)
  if (propsMatch) {
    const propsBlock = propsMatch[1]
    // TypeScript interface style: name?: type
    const propRegex = /(\w+)(\?)?:\s*([^;\n]+)/g
    let match
    while ((match = propRegex.exec(propsBlock)) !== null) {
      info.props.push({
        name: match[1],
        type: match[3].trim().replace(/[,;]$/, '').trim(),
        required: !match[2],
      })
    }
  }

  // Parse withDefaults
  const defaultsMatch = content.match(/withDefaults\([\s\S]*?\{([\s\S]*?)\}\s*\)/)
  if (defaultsMatch) {
    const defaultsBlock = defaultsMatch[1]
    const defRegex = /(\w+):\s*(.+?)(?=,\s*\w+:|$)/g
    let match
    while ((match = defRegex.exec(defaultsBlock)) !== null) {
      const prop = info.props.find(p => p.name === match[1])
      if (prop) prop.default = match[2].trim().replace(/,$/, '').trim()
    }
  }

  // Parse defineEmits
  const emitsMatch = content.match(/defineEmits<\{([\s\S]*?)\}>/)
    || content.match(/defineEmits\(\[([\s\S]*?)\]\)/)
  if (emitsMatch) {
    const emitsBlock = emitsMatch[1]
    // Array style: 'event-name'
    const arrayRegex = /['"]([^'"]+)['"]/g
    let match
    while ((match = arrayRegex.exec(emitsBlock)) !== null) {
      info.emits.push(match[1])
    }
    // TypeScript style: (e: 'event-name', ...): void
    const tsRegex = /\(e:\s*['"]([^'"]+)['"]/g
    while ((match = tsRegex.exec(emitsBlock)) !== null) {
      if (!info.emits.includes(match[1])) {
        info.emits.push(match[1])
      }
    }
  }

  return info
}

function getAllVueComponents(): VueComponentInfo[] {
  const componentsDir = path.join(CLIENT_ROOT, 'resources/js/components')
  if (!fs.existsSync(componentsDir)) return []

  const components: VueComponentInfo[] = []
  const categories = fs.readdirSync(componentsDir).filter(f =>
    fs.statSync(path.join(componentsDir, f)).isDirectory()
  )

  for (const category of categories) {
    const catDir = path.join(componentsDir, category)
    const componentDirs = fs.readdirSync(catDir).filter(f =>
      fs.statSync(path.join(catDir, f)).isDirectory()
    )
    for (const compDir of componentDirs) {
      const vueFile = path.join(catDir, compDir, `${compDir}.vue`)
      if (fs.existsSync(vueFile)) {
        components.push(parseVueComponent(vueFile, compDir, category))
      }
    }
  }

  return components
}

// ── Layout / Page Parsing ───────────────────────────────────────────

interface LayoutInfo {
  name: string
  path: string
  sections: string[]
  yields: string[]
}

function getLayouts(): LayoutInfo[] {
  const layoutDir = path.join(CLIENT_ROOT, 'resources/views/layouts')
  if (!fs.existsSync(layoutDir)) return []

  return listFiles(layoutDir, '.blade.php').map(file => {
    const content = readFile(path.join(layoutDir, file))
    const name = path.basename(file, '.blade.php')
    const sections: string[] = []
    const yields: string[] = []

    // Find @yield directives
    const yieldRegex = /@yield\(['"](\w+)['"]\)/g
    let match
    while ((match = yieldRegex.exec(content)) !== null) {
      yields.push(match[1])
    }

    // Find @section references in child templates
    const sectionRegex = /@section\(['"](\w+)['"]\)/g
    while ((match = sectionRegex.exec(content)) !== null) {
      sections.push(match[1])
    }

    return {
      name,
      path: `resources/views/layouts/${file}`,
      sections,
      yields,
    }
  })
}

interface PageInfo {
  name: string
  path: string
  layout: string | null
  components: string[]
  vueIslands: string[]
}

function getPages(): PageInfo[] {
  const pageDir = path.join(CLIENT_ROOT, 'resources/views/pages')
  if (!fs.existsSync(pageDir)) return []

  return listFiles(pageDir, '.blade.php').map(file => {
    const content = readFile(path.join(pageDir, file))
    const name = path.basename(file, '.blade.php')

    // Detect layout
    const layoutMatch = content.match(/@extends\(['"]layouts\.(\w+)['"]\)/)
    const layout = layoutMatch ? layoutMatch[1] : null

    // Detect Blade component usage
    const componentRegex = /<x-([\w.-]+)/g
    const components = new Set<string>()
    let match
    while ((match = componentRegex.exec(content)) !== null) {
      components.add(match[1])
    }

    // Detect Vue islands
    const vueRegex = /<([\w-]+)\s[^>]*(?:v-|:|\@|id="app)/g
    const vueIslands = new Set<string>()
    // Also detect @vite references or data-island patterns
    const islandRegex = /<div[^>]*id=["'](\w+)["'][^>]*data-component/g
    while ((match = islandRegex.exec(content)) !== null) {
      vueIslands.add(match[1])
    }
    // Detect Vue component tags directly
    const vueTagRegex = /<((?:phone-entry|verify-code|navigation-island|lesson-island|join-phone-island|join-verify-island|login-verify-island|join-code-island|home-profile-button|modal-provider|keypad|bullet-text-input|digit|modal|video-player|admin-\w+))/g
    while ((match = vueTagRegex.exec(content)) !== null) {
      vueIslands.add(match[1])
    }

    return {
      name,
      path: `resources/views/pages/${file}`,
      layout,
      components: Array.from(components),
      vueIslands: Array.from(vueIslands),
    }
  })
}

// ── Store Parsing ───────────────────────────────────────────────────

interface StoreInfo {
  name: string
  type: 'domain' | 'ui' | 'global'
  path: string
  stateFields: string[]
  actions: string[]
  getters: string[]
}

function parseStore(filePath: string, name: string, type: 'domain' | 'ui' | 'global'): StoreInfo {
  const content = readFile(filePath)
  const info: StoreInfo = { name, type, path: path.relative(CLIENT_ROOT, filePath), stateFields: [], actions: [], getters: [] }

  // Parse state (in defineStore's state function or ref declarations)
  const stateMatch = content.match(/state:\s*\(\)\s*=>\s*\(\{([\s\S]*?)\}\)/)
  if (stateMatch) {
    const stateRegex = /(\w+):/g
    let match
    while ((match = stateRegex.exec(stateMatch[1])) !== null) {
      info.stateFields.push(match[1])
    }
  }
  // Also check for ref() declarations (Composition API)
  const refRegex = /const\s+(\w+)\s*=\s*ref[<(]/g
  let refMatch
  while ((refMatch = refRegex.exec(content)) !== null) {
    info.stateFields.push(refMatch[1])
  }

  // Parse actions
  const actionMatch = content.match(/actions:\s*\{([\s\S]*?)\}(?:\s*\})/)
  if (actionMatch) {
    const actionRegex = /(?:async\s+)?(\w+)\s*\(/g
    let match
    while ((match = actionRegex.exec(actionMatch[1])) !== null) {
      info.actions.push(match[1])
    }
  }
  // Composition API functions
  const fnRegex = /(?:async\s+)?function\s+(\w+)|const\s+(\w+)\s*=\s*(?:async\s*)?\(/g
  let fnMatch
  while ((fnMatch = fnRegex.exec(content)) !== null) {
    const fnName = fnMatch[1] || fnMatch[2]
    if (fnName && !fnName.startsWith('use') && !['ref', 'computed', 'watch', 'defineStore'].includes(fnName)) {
      // Heuristic: if it's in a return statement, it's likely an action
      if (content.includes(`return`) && content.includes(fnName)) {
        info.actions.push(fnName)
      }
    }
  }

  // Parse getters
  const gettersMatch = content.match(/getters:\s*\{([\s\S]*?)\}(?:\s*,|\s*\})/)
  if (gettersMatch) {
    const getterRegex = /(\w+)\s*(?:\(|:)/g
    let match
    while ((match = getterRegex.exec(gettersMatch[1])) !== null) {
      info.getters.push(match[1])
    }
  }
  // Composition API computed
  const computedRegex = /const\s+(\w+)\s*=\s*computed/g
  let compMatch
  while ((compMatch = computedRegex.exec(content)) !== null) {
    info.getters.push(compMatch[1])
  }

  return info
}

function getAllStores(): StoreInfo[] {
  const stores: StoreInfo[] = []

  // Global stores
  const globalDir = path.join(CLIENT_ROOT, 'resources/js/stores')
  if (fs.existsSync(globalDir)) {
    for (const file of listFiles(globalDir, '.ts')) {
      if (file.includes('.d.ts')) continue
      const name = path.basename(file, '.ts').replace('.store', '')
      stores.push(parseStore(path.join(globalDir, file), name, 'global'))
    }
  }

  // Admin island stores
  const adminStoresDir = path.join(CLIENT_ROOT, 'resources/js/islands/admin-island/stores')
  for (const type of ['domain', 'ui'] as const) {
    const dir = path.join(adminStoresDir, type)
    if (!fs.existsSync(dir)) continue
    for (const file of listFiles(dir, '.ts')) {
      if (file.includes('.d.ts')) continue
      const name = path.basename(file, '.ts').replace('.store', '')
      stores.push(parseStore(path.join(dir, file), `admin/${name}`, type))
    }
  }

  return stores
}

// ── Component Detail Formatting ─────────────────────────────────────

function formatBladeComponent(comp: BladeComponentInfo): string {
  const lines: string[] = []
  lines.push(`## <x-${comp.category}.${comp.name}>`)
  lines.push('')
  lines.push(`**Category:** ${comp.category}`)
  lines.push(`**File:** ${comp.path}`)
  lines.push('')

  if (comp.props.length) {
    lines.push('### Props')
    for (const p of comp.props) {
      lines.push(`- \`${p.name}\` — default: \`${p.default}\``)
    }
    lines.push('')
  }

  if (Object.keys(comp.variants).length) {
    lines.push('### Variants (CVA)')
    for (const [variantName, options] of Object.entries(comp.variants)) {
      const defaultVal = comp.defaultVariants[variantName]
      const optionList = Object.keys(options).map(o =>
        o === defaultVal ? `**${o}** (default)` : o
      ).join(', ')
      lines.push(`- \`${variantName}\`: ${optionList}`)
    }
    lines.push('')
  }

  if (comp.slots.length) {
    lines.push('### Slots')
    for (const s of comp.slots) {
      lines.push(`- \`$${s}\``)
    }
    lines.push('')
  }

  lines.push('### Usage')
  const propsStr = comp.props
    .filter(p => p.default === 'null' || p.default === 'false')
    .map(p => ` ${p.name}="..."`)
    .join('')
  lines.push('```blade')
  lines.push(`<x-${comp.category}.${comp.name}${propsStr}>`)
  if (comp.slots.includes('slot')) {
    lines.push('    Content here')
  }
  lines.push(`</x-${comp.category}.${comp.name}>`)
  lines.push('```')

  return lines.join('\n')
}

function formatVueComponent(comp: VueComponentInfo): string {
  const lines: string[] = []
  lines.push(`## <${comp.name}>`)
  lines.push('')
  lines.push(`**Category:** ${comp.category}`)
  lines.push(`**File:** ${comp.path}`)
  lines.push(`**Story:** ${comp.hasStory ? 'Yes' : 'No'}`)
  lines.push('')

  if (comp.props.length) {
    lines.push('### Props')
    for (const p of comp.props) {
      const req = p.required ? '(required)' : '(optional)'
      const def = p.default ? ` — default: \`${p.default}\`` : ''
      lines.push(`- \`${p.name}\`: \`${p.type}\` ${req}${def}`)
    }
    lines.push('')
  }

  if (comp.emits.length) {
    lines.push('### Events')
    for (const e of comp.emits) {
      lines.push(`- \`@${e}\``)
    }
    lines.push('')
  }

  return lines.join('\n')
}

// ── MCP Server ──────────────────────────────────────────────────────

const server = new McpServer({
  name: 'makeready-client',
  version: '1.0.0',
})

// Tool 1: List all routes
server.tool(
  'list_routes',
  'List all web routes in the MakeReady client app. Returns method, path, controller, action, middleware, and route name. Optionally filter by section, method, or path substring.',
  {
    section: z.string().optional().describe('Filter by section (e.g. "Public", "Protected")'),
    method: z.string().optional().describe('Filter by HTTP method (GET, POST, etc.)'),
    path: z.string().optional().describe('Filter by path substring (e.g. "/admin", "/join")'),
  },
  async ({ section, method, path: pathFilter }) => {
    let routes = parseRoutes()

    if (section) {
      const sLower = section.toLowerCase()
      routes = routes.filter(r => r.section.toLowerCase().includes(sLower))
    }
    if (method) {
      const mUpper = method.toUpperCase()
      routes = routes.filter(r => r.method.includes(mUpper))
    }
    if (pathFilter) {
      const pLower = pathFilter.toLowerCase()
      routes = routes.filter(r => r.path.toLowerCase().includes(pLower))
    }

    if (routes.length === 0) {
      return { content: [{ type: 'text' as const, text: 'No routes match the given filters.' }] }
    }

    return { content: [{ type: 'text' as const, text: `Found ${routes.length} route(s):\n\n${formatRouteList(routes)}` }] }
  }
)

// Tool 2: Get route detail
server.tool(
  'get_route_detail',
  'Get full details for a specific route including its controller, middleware, and the controller source code.',
  {
    name: z.string().optional().describe('Route name (e.g. "login", "home", "join.group")'),
    path: z.string().optional().describe('Route path (e.g. "/login", "/member/home")'),
  },
  async ({ name, path: routePath }) => {
    const routes = parseRoutes()
    let match: RouteInfo | undefined

    if (name) {
      match = routes.find(r => r.name === name || r.name.includes(name))
    }
    if (!match && routePath) {
      match = routes.find(r => r.path === routePath || r.path.includes(routePath))
    }

    if (!match) {
      const allNames = routes.filter(r => r.name).map(r => `  ${r.name} → ${r.method} ${r.path}`)
      return {
        content: [{
          type: 'text' as const,
          text: `No route found. Available named routes:\n${allNames.join('\n')}`,
        }],
      }
    }

    const lines = [
      `## ${match.method} ${match.path}`,
      '',
      `**Controller:** ${match.controller}@${match.action}`,
      `**Route name:** ${match.name || '(none)'}`,
      `**Middleware:** ${match.middleware.length ? match.middleware.join(', ') : 'none (public)'}`,
      `**Section:** ${match.section}`,
    ]

    // Try to find and read the controller
    const controllerFile = path.join(CLIENT_ROOT, 'app/Http/Controllers', `${match.controller}.php`)
    if (fs.existsSync(controllerFile)) {
      const source = readFile(controllerFile)
      // Extract the specific method
      const methodRegex = new RegExp(
        `public function ${match.action}\\b[\\s\\S]*?(?=\\n    public function |\\n\\}$)`,
        'm'
      )
      const methodMatch = source.match(methodRegex)
      if (methodMatch) {
        lines.push('')
        lines.push('### Controller Method')
        lines.push('```php')
        lines.push(methodMatch[0].trim())
        lines.push('```')
      }
    }

    // Try to find the corresponding page view
    const viewDir = path.join(CLIENT_ROOT, 'resources/views/pages')
    const possibleView = match.name.replace(/\./g, '-') + '.blade.php'
    if (fs.existsSync(path.join(viewDir, possibleView))) {
      lines.push('')
      lines.push(`**View:** resources/views/pages/${possibleView}`)
    }

    return { content: [{ type: 'text' as const, text: lines.join('\n') }] }
  }
)

// Tool 3: List components
server.tool(
  'list_components',
  'List all UI components in the MakeReady client. Returns both Blade (server-rendered) and Vue (interactive island) components with their category, props summary, and variants.',
  {
    type: z.enum(['blade', 'vue', 'all']).optional().describe('Component type filter (default: all)'),
    category: z.string().optional().describe('Filter by category (primitive, domain, layout, panel, admin)'),
    search: z.string().optional().describe('Search by component name'),
  },
  async ({ type = 'all', category, search }) => {
    const lines: string[] = []

    if (type === 'all' || type === 'blade') {
      let bladeComponents = getAllBladeComponents()
      if (category) bladeComponents = bladeComponents.filter(c => c.category === category)
      if (search) {
        const sLower = search.toLowerCase()
        bladeComponents = bladeComponents.filter(c => c.name.toLowerCase().includes(sLower))
      }

      if (bladeComponents.length > 0) {
        lines.push(`## Blade Components (${bladeComponents.length})`)
        lines.push('')
        const byCategory = new Map<string, BladeComponentInfo[]>()
        for (const c of bladeComponents) {
          if (!byCategory.has(c.category)) byCategory.set(c.category, [])
          byCategory.get(c.category)!.push(c)
        }
        for (const [cat, comps] of byCategory) {
          lines.push(`### ${cat}`)
          for (const c of comps) {
            const propsStr = c.props.map(p => p.name).join(', ')
            const variantStr = Object.entries(c.variants)
              .map(([k, v]) => `${k}: ${Object.keys(v).join('|')}`)
              .join('; ')
            lines.push(`- **<x-${cat}.${c.name}>** — props: [${propsStr}]${variantStr ? ` | variants: ${variantStr}` : ''}`)
          }
          lines.push('')
        }
      }
    }

    if (type === 'all' || type === 'vue') {
      let vueComponents = getAllVueComponents()
      if (category) vueComponents = vueComponents.filter(c => c.category === category)
      if (search) {
        const sLower = search.toLowerCase()
        vueComponents = vueComponents.filter(c => c.name.toLowerCase().includes(sLower))
      }

      if (vueComponents.length > 0) {
        lines.push(`## Vue Components (${vueComponents.length})`)
        lines.push('')
        const byCategory = new Map<string, VueComponentInfo[]>()
        for (const c of vueComponents) {
          if (!byCategory.has(c.category)) byCategory.set(c.category, [])
          byCategory.get(c.category)!.push(c)
        }
        for (const [cat, comps] of byCategory) {
          lines.push(`### ${cat}`)
          for (const c of comps) {
            const propsStr = c.props.map(p => `${p.name}: ${p.type}`).join(', ')
            lines.push(`- **<${c.name}>** — ${propsStr || 'no props'}${c.hasStory ? ' [story]' : ''}`)
          }
          lines.push('')
        }
      }
    }

    if (lines.length === 0) {
      return { content: [{ type: 'text' as const, text: 'No components found matching filters.' }] }
    }

    return { content: [{ type: 'text' as const, text: lines.join('\n') }] }
  }
)

// Tool 4: Get component detail
server.tool(
  'get_component_detail',
  'Get full documentation for a specific component including all props, variants, slots, events, and usage examples.',
  {
    name: z.string().describe('Component name (e.g. "button", "phone-entry", "admin-table")'),
  },
  async ({ name }) => {
    const nameLower = name.toLowerCase().replace(/^<x-|^<|>$/g, '').replace(/^(primitive|domain|layout|panel|admin)\./, '')

    // Search Blade components
    const bladeComponents = getAllBladeComponents()
    const bladeMatch = bladeComponents.find(c => c.name.toLowerCase() === nameLower)

    // Search Vue components
    const vueComponents = getAllVueComponents()
    const vueMatch = vueComponents.find(c => c.name.toLowerCase() === nameLower)

    const parts: string[] = []

    if (bladeMatch) {
      parts.push(formatBladeComponent(bladeMatch))
    }

    if (vueMatch) {
      if (parts.length) parts.push('\n---\n')
      parts.push(formatVueComponent(vueMatch))
    }

    if (parts.length === 0) {
      // Suggest similar
      const allNames = [
        ...bladeComponents.map(c => `<x-${c.category}.${c.name}> (Blade)`),
        ...vueComponents.map(c => `<${c.name}> (Vue)`),
      ]
      const suggestions = allNames.filter(n => n.toLowerCase().includes(nameLower))
      return {
        content: [{
          type: 'text' as const,
          text: suggestions.length
            ? `No exact match for "${name}". Similar:\n${suggestions.join('\n')}`
            : `No component named "${name}". Use list_components to see all available components.`,
        }],
      }
    }

    return { content: [{ type: 'text' as const, text: parts.join('\n') }] }
  }
)

// Tool 5: List pages and layouts
server.tool(
  'list_pages',
  'List all pages and layouts in the MakeReady client, showing which layout each page extends and which components it uses.',
  {},
  async () => {
    const layouts = getLayouts()
    const pages = getPages()

    const lines: string[] = []

    lines.push(`## Layouts (${layouts.length})`)
    lines.push('')
    for (const l of layouts) {
      lines.push(`- **${l.name}** — yields: [${l.yields.join(', ')}] | file: ${l.path}`)
    }
    lines.push('')

    lines.push(`## Pages (${pages.length})`)
    lines.push('')
    for (const p of pages) {
      const layout = p.layout ? `extends ${p.layout}` : 'standalone'
      const comps = p.components.length ? ` | components: ${p.components.join(', ')}` : ''
      const islands = p.vueIslands.length ? ` | vue: ${p.vueIslands.join(', ')}` : ''
      lines.push(`- **${p.name}** (${layout})${comps}${islands}`)
    }

    return { content: [{ type: 'text' as const, text: lines.join('\n') }] }
  }
)

// Tool 6: List stores
server.tool(
  'list_stores',
  'List all Pinia stores in the MakeReady client (global, domain, and UI stores) with their state, actions, and getters.',
  {
    type: z.enum(['domain', 'ui', 'global', 'all']).optional().describe('Store type filter (default: all)'),
  },
  async ({ type = 'all' }) => {
    let stores = getAllStores()
    if (type !== 'all') {
      stores = stores.filter(s => s.type === type)
    }

    if (stores.length === 0) {
      return { content: [{ type: 'text' as const, text: 'No stores found.' }] }
    }

    const lines: string[] = [`## Stores (${stores.length})`, '']

    const byType = new Map<string, StoreInfo[]>()
    for (const s of stores) {
      if (!byType.has(s.type)) byType.set(s.type, [])
      byType.get(s.type)!.push(s)
    }

    for (const [storeType, typeStores] of byType) {
      lines.push(`### ${storeType}`)
      for (const s of typeStores) {
        const state = s.stateFields.length ? `state: [${s.stateFields.join(', ')}]` : ''
        const actions = s.actions.length ? `actions: [${s.actions.join(', ')}]` : ''
        const getters = s.getters.length ? `getters: [${s.getters.join(', ')}]` : ''
        const details = [state, actions, getters].filter(Boolean).join(' | ')
        lines.push(`- **${s.name}** — ${details || 'empty'}`)
        lines.push(`  file: ${s.path}`)
      }
      lines.push('')
    }

    return { content: [{ type: 'text' as const, text: lines.join('\n') }] }
  }
)

// Tool 7: Search across everything
server.tool(
  'search_client',
  'Search across routes, components, pages, and stores by keyword. Returns all matches across the client app.',
  {
    query: z.string().describe('Search term (e.g. "button", "login", "admin", "group")'),
  },
  async ({ query }) => {
    const qLower = query.toLowerCase()
    const results: string[] = []

    // Search routes
    const routes = parseRoutes().filter(r =>
      r.path.toLowerCase().includes(qLower) ||
      r.name.toLowerCase().includes(qLower) ||
      r.controller.toLowerCase().includes(qLower) ||
      r.action.toLowerCase().includes(qLower)
    )
    if (routes.length) {
      results.push(`## Routes (${routes.length} matches)`)
      for (const r of routes) {
        results.push(`- ${r.method} ${r.path} → ${r.controller}@${r.action}`)
      }
      results.push('')
    }

    // Search Blade components
    const bladeComps = getAllBladeComponents().filter(c =>
      c.name.toLowerCase().includes(qLower) ||
      c.category.toLowerCase().includes(qLower)
    )
    if (bladeComps.length) {
      results.push(`## Blade Components (${bladeComps.length} matches)`)
      for (const c of bladeComps) {
        results.push(`- <x-${c.category}.${c.name}>`)
      }
      results.push('')
    }

    // Search Vue components
    const vueComps = getAllVueComponents().filter(c =>
      c.name.toLowerCase().includes(qLower) ||
      c.category.toLowerCase().includes(qLower)
    )
    if (vueComps.length) {
      results.push(`## Vue Components (${vueComps.length} matches)`)
      for (const c of vueComps) {
        results.push(`- <${c.name}> (${c.category})`)
      }
      results.push('')
    }

    // Search pages
    const pages = getPages().filter(p =>
      p.name.toLowerCase().includes(qLower) ||
      p.components.some(c => c.toLowerCase().includes(qLower))
    )
    if (pages.length) {
      results.push(`## Pages (${pages.length} matches)`)
      for (const p of pages) {
        results.push(`- ${p.name}`)
      }
      results.push('')
    }

    // Search stores
    const stores = getAllStores().filter(s =>
      s.name.toLowerCase().includes(qLower)
    )
    if (stores.length) {
      results.push(`## Stores (${stores.length} matches)`)
      for (const s of stores) {
        results.push(`- ${s.name} (${s.type})`)
      }
      results.push('')
    }

    if (results.length === 0) {
      return { content: [{ type: 'text' as const, text: `No matches for "${query}" across routes, components, pages, or stores.` }] }
    }

    return { content: [{ type: 'text' as const, text: results.join('\n') }] }
  }
)

// ── Start ───────────────────────────────────────────────────────────

const transport = new StdioServerTransport()
await server.connect(transport)
