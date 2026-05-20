import { Router } from 'express'

const router = Router()

const GITHUB_ORG = 'lukekeith'
const REPOS = [
  { name: 'makeready-server', label: 'server' },
  { name: 'makeready-web', label: 'web' },
  { name: 'makeready-iphone', label: 'iphone' },
]

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

/**
 * @openapi
 * /api/github/commits:
 *   get:
 *     summary: Get recent commits from all MakeReady repos
 *     tags: [GitHub]
 *     parameters:
 *       - in: query
 *         name: per_page
 *         schema:
 *           type: integer
 *           default: 30
 *           maximum: 100
 *         description: Number of commits per repo to fetch
 *     responses:
 *       200:
 *         description: Merged commit list sorted by date
 */
router.get('/commits', async (req, res) => {
  const token = process.env.GITHUB_TOKEN
  if (!token) {
    return res.status(500).json({ success: false, error: 'GITHUB_TOKEN not configured' })
  }

  const perPage = Math.min(Math.max(parseInt(req.query.per_page as string) || 30, 1), 100)

  const headers = {
    Authorization: `Bearer ${token}`,
    Accept: 'application/vnd.github.v3+json',
    'User-Agent': 'MakeReady-Server',
  }

  const results = await Promise.allSettled(
    REPOS.map(async (repo) => {
      // Fetch commits and total count in parallel
      const [commitsRes, countRes] = await Promise.all([
        fetch(
          `https://api.github.com/repos/${GITHUB_ORG}/${repo.name}/commits?sha=main&per_page=${perPage}`,
          { headers }
        ),
        fetch(
          `https://api.github.com/repos/${GITHUB_ORG}/${repo.name}/commits?sha=main&per_page=1`,
          { headers }
        ),
      ])

      if (!commitsRes.ok) {
        throw new Error(`GitHub API returned ${commitsRes.status} for ${repo.name}`)
      }

      // Parse total from Link header: <...?page=N>; rel="last"
      let totalCount: number | null = null
      const link = countRes.headers.get('link')
      if (link) {
        const match = link.match(/[?&]page=(\d+)>;\s*rel="last"/)
        if (match) totalCount = parseInt(match[1], 10)
      }

      const commits = (await commitsRes.json()) as GitHubCommit[]
      return {
        label: repo.label,
        totalCount,
        commits: commits.map((c) => ({
          repo: repo.label,
          sha: c.sha.slice(0, 7),
          fullSha: c.sha,
          message: c.commit.message,
          author: c.commit.author.name,
          date: c.commit.author.date,
          url: c.html_url,
        })),
      }
    })
  )

  type CommitEntry = {
    repo: string
    sha: string
    fullSha: string
    message: string
    author: string
    date: string
    url: string
  }

  const commits: CommitEntry[] = []
  const totals: Record<string, number | null> = {}
  const errors: string[] = []

  for (const result of results) {
    if (result.status === 'fulfilled') {
      commits.push(...(result.value.commits as CommitEntry[]))
      totals[result.value.label] = result.value.totalCount
    } else {
      errors.push(result.reason?.message || 'Unknown error')
    }
  }

  commits.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime())

  res.json({
    success: true,
    commits,
    totals,
    ...(errors.length > 0 && { warnings: errors }),
  })
})

export default router
