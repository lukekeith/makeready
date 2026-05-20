/**
 * Bot Guard Middleware
 *
 * Immediately 404s requests to known scanner/exploit paths before they
 * reach any route processing, session middleware, or database queries.
 * Also blocks requests with empty or obviously bot User-Agent strings.
 */

import { Request, Response, NextFunction } from 'express'

// Paths that scanners and bots probe for — no legitimate client hits these
const BLOCKED_PATHS = [
  // WordPress
  '/wp-json', '/wp-admin', '/wp-login', '/wp-content', '/wp-includes',
  '/xmlrpc.php', '/wp-cron.php', '/wp-config',
  // PHP admin tools
  '/phpMyAdmin', '/phpmyadmin', '/pma', '/myadmin',
  '/adminer', '/adminer.php',
  // Config/env probes
  '/.env', '/.git', '/.svn', '/.htaccess', '/.htpasswd',
  '/.DS_Store', '/config.json', '/composer.json', '/package.json',
  '/server-status', '/server-info',
  // Common exploit paths
  '/cgi-bin', '/shell', '/cmd', '/eval',
  '/setup.php', '/install.php', '/config.php',
  '/debug', '/trace', '/console',
  // Java/Spring
  '/actuator', '/jolokia', '/metrics',
  // Node/misc
  '/node_modules', '/.npmrc',
]

// Prefixes to block
const BLOCKED_PREFIXES = [
  '/wp-',
  '/wordpress/',
  '/.well-known/security.txt',  // Allow .well-known for other purposes but block probes
]

// User-Agent patterns that are always bots
const BOT_UA_PATTERNS = [
  /^$/,                    // Empty user agent
  /curl\/\d/i,            // curl (unless you want to allow CLI testing)
  /python-requests/i,
  /Go-http-client/i,
  /Java\//i,
  /libwww-perl/i,
  /Wget/i,
  /scrapy/i,
  /zgrab/i,
  /masscan/i,
  /nuclei/i,
  /nikto/i,
  /sqlmap/i,
  /nmap/i,
  /dirbuster/i,
  /gobuster/i,
  /wpscan/i,
  /semrush/i,
  /ahrefs/i,
  /mj12bot/i,
  /dotbot/i,
  /petalbot/i,
]

function isBlockedPath(path: string): boolean {
  const lower = path.toLowerCase()
  for (const blocked of BLOCKED_PATHS) {
    if (lower === blocked || lower.startsWith(blocked + '/') || lower.startsWith(blocked + '?')) {
      return true
    }
  }
  for (const prefix of BLOCKED_PREFIXES) {
    if (lower.startsWith(prefix)) return true
  }
  return false
}

function isBotUserAgent(ua: string | undefined): boolean {
  if (!ua) return true // No user agent = bot
  for (const pattern of BOT_UA_PATTERNS) {
    if (pattern.test(ua)) return true
  }
  return false
}

const IS_TEST = process.env.NODE_ENV === 'test'

export function botGuard(req: Request, res: Response, next: NextFunction) {
  // Disable in test environment so test runners aren't blocked
  if (IS_TEST) return next()

  // Allow health checks and robots.txt through
  if (req.path === '/health' || req.path === '/robots.txt') return next()

  // Block known scanner paths
  if (isBlockedPath(req.path)) {
    return res.status(404).end()
  }

  // Block known bot user agents on API paths
  // (Allow bots on static paths like /robots.txt, handled above)
  // Skip bot check for API key requests (Bearer mr_ prefix) — these are
  // legitimate programmatic clients (CLI tools, scripts, Claude, etc.)
  const authHeader = req.get('authorization') || ''
  const hasApiKey = authHeader.startsWith('Bearer mr_')
  if (req.path.startsWith('/api/') && !hasApiKey && isBotUserAgent(req.get('user-agent'))) {
    return res.status(403).json({ error: 'Forbidden' })
  }

  next()
}
