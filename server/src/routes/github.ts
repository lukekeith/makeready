import { Router } from 'express'

const router = Router()

const GITHUB_ORG = 'lukekeith'
const REPO = 'makeready'

// Top-level monorepo folders that map to the apps shown on the activity page.
// A commit is attributed to every app whose folder it touches.
const APPS = ['client', 'server', 'iphone', 'capture'] as const
type App = (typeof APPS)[number]
const APP_SET: ReadonlySet<string> = new Set(APPS)

interface GitHubCommit {
  sha: string
  commit: {
    message: string
    author: {
      name: string
      date: string
    }
  }
  html_url: string
}

interface GitHubCommitDetail {
  files?: { filename: string }[]
}

/**
 * Classify a commit's changed files into the apps they belong to.
 * Returns the distinct app folders touched (empty if only root-level files changed).
 */
function classifyApps(files: { filename: string }[]): App[] {
  const apps = new Set<App>()
  for (const f of files) {
    const top = f.filename.split('/')[0]
    if (APP_SET.has(top)) apps.add(top as App)
  }
  return [...apps]
}

/**
 * @openapi
 * /api/github/commits:
 *   get:
 *     summary: Get recent commits from the MakeReady monorepo, classified by app
 *     description: |
 *       Fetches recent commits from the single `lukekeith/makeready` monorepo and
 *       attributes each to the app(s) whose top-level folder it touches
 *       (client, server, iphone, capture). A commit spanning multiple apps is
 *       tagged with all of them.
 *     tags: [GitHub]
 *     parameters:
 *       - in: query
 *         name: per_page
 *         schema:
 *           type: integer
 *           default: 40
 *           maximum: 100
 *         description: Number of recent commits to fetch and classify
 *     responses:
 *       200:
 *         description: Commit list sorted by date, each tagged with apps[]
 */
router.get('/commits', async (req, res) => {
  const token = process.env.GITHUB_TOKEN
  if (!token) {
    return res.status(500).json({ success: false, error: 'GITHUB_TOKEN not configured' })
  }

  const perPage = Math.min(Math.max(parseInt(req.query.per_page as string) || 40, 1), 100)

  const headers = {
    Authorization: `Bearer ${token}`,
    Accept: 'application/vnd.github.v3+json',
    'User-Agent': 'MakeReady-Server',
  }

  try {
    // 1. List recent commits on main + grab the repo's total commit count (Link header)
    const [listRes, countRes] = await Promise.all([
      fetch(
        `https://api.github.com/repos/${GITHUB_ORG}/${REPO}/commits?sha=main&per_page=${perPage}`,
        { headers }
      ),
      fetch(
        `https://api.github.com/repos/${GITHUB_ORG}/${REPO}/commits?sha=main&per_page=1`,
        { headers }
      ),
    ])

    if (!listRes.ok) {
      throw new Error(`GitHub API returned ${listRes.status} for ${REPO}`)
    }

    // Parse total from Link header: <...?page=N>; rel="last"
    let totalCount: number | null = null
    const link = countRes.headers.get('link')
    if (link) {
      const match = link.match(/[?&]page=(\d+)>;\s*rel="last"/)
      if (match) totalCount = parseInt(match[1], 10)
    }

    const list = (await listRes.json()) as GitHubCommit[]

    // 2. Fetch each commit's detail to read its changed files, then classify by app folder.
    //    (The list endpoint omits files, so a per-commit fetch is required.)
    const detailed = await Promise.allSettled(
      list.map(async (c) => {
        const detailRes = await fetch(
          `https://api.github.com/repos/${GITHUB_ORG}/${REPO}/commits/${c.sha}`,
          { headers }
        )

        let apps: App[] = []
        if (detailRes.ok) {
          const detail = (await detailRes.json()) as GitHubCommitDetail
          apps = classifyApps(detail.files || [])
        }

        return {
          sha: c.sha.slice(0, 7),
          fullSha: c.sha,
          message: c.commit.message,
          author: c.commit.author.name,
          date: c.commit.author.date,
          url: c.html_url,
          apps,
        }
      })
    )

    const commits = []
    const errors: string[] = []
    for (const result of detailed) {
      if (result.status === 'fulfilled') {
        commits.push(result.value)
      } else {
        errors.push(result.reason?.message || 'Failed to load a commit')
      }
    }

    commits.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime())

    res.json({
      success: true,
      commits,
      totalCount,
      ...(errors.length > 0 && { warnings: errors }),
    })
  } catch (err: any) {
    res.status(500).json({ success: false, error: err.message || 'Failed to load commits' })
  }
})

export default router
