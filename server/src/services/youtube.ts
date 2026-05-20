/**
 * YouTube service for extracting video metadata from URLs.
 * Uses oEmbed API (no API key required) for title and thumbnail.
 * Fetches duration by parsing the YouTube video page.
 */

export interface YouTubeMetadata {
  videoId: string
  title: string
  thumbnailUrl: string
  authorName: string
  durationSeconds: number | null
}

/**
 * Extract YouTube video ID from various URL formats:
 * - https://www.youtube.com/watch?v=VIDEO_ID
 * - https://youtu.be/VIDEO_ID
 * - https://www.youtube.com/embed/VIDEO_ID
 * - https://youtube.com/watch?v=VIDEO_ID&t=90
 */
export function extractYouTubeVideoId(url: string): string | null {
  const patterns = [
    /(?:youtube\.com\/watch\?.*v=)([a-zA-Z0-9_-]{11})/,
    /(?:youtu\.be\/)([a-zA-Z0-9_-]{11})/,
    /(?:youtube\.com\/embed\/)([a-zA-Z0-9_-]{11})/,
    /(?:youtube\.com\/v\/)([a-zA-Z0-9_-]{11})/,
    /(?:youtube\.com\/shorts\/)([a-zA-Z0-9_-]{11})/,
  ]

  for (const pattern of patterns) {
    const match = url.match(pattern)
    if (match) return match[1]
  }

  return null
}

/**
 * Extract start time from YouTube URL (t= or start= parameter)
 */
export function extractStartTime(url: string): number | null {
  const match = url.match(/[?&](?:t|start)=(\d+)/)
  return match ? parseInt(match[1], 10) : null
}

/**
 * Parse ISO 8601 duration (PT#H#M#S) to seconds.
 */
function parseISO8601Duration(duration: string): number | null {
  const match = duration.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/)
  if (!match) return null
  const hours = parseInt(match[1] || '0', 10)
  const minutes = parseInt(match[2] || '0', 10)
  const seconds = parseInt(match[3] || '0', 10)
  return hours * 3600 + minutes * 60 + seconds
}

/**
 * Fetch video duration by parsing the YouTube video page HTML.
 * Looks for duration in the page's meta tags or JSON-LD.
 */
async function fetchYouTubeDuration(videoId: string): Promise<number | null> {
  try {
    const response = await fetch(`https://www.youtube.com/watch?v=${videoId}`, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; MakeReady/1.0)',
      },
    })

    if (!response.ok) return null

    const html = await response.text()

    // Try to find duration in meta tag: <meta itemprop="duration" content="PT5M30S">
    const metaMatch = html.match(/itemprop="duration"[^>]*content="([^"]+)"/)
    if (metaMatch) {
      return parseISO8601Duration(metaMatch[1])
    }

    // Try JSON-LD: "duration":"PT5M30S"
    const jsonLdMatch = html.match(/"duration"\s*:\s*"(PT[^"]+)"/)
    if (jsonLdMatch) {
      return parseISO8601Duration(jsonLdMatch[1])
    }

    // Try approxDurationMs from player response
    const approxMatch = html.match(/"approxDurationMs"\s*:\s*"(\d+)"/)
    if (approxMatch) {
      return Math.round(parseInt(approxMatch[1], 10) / 1000)
    }

    return null
  } catch {
    return null
  }
}

/**
 * Fetch video metadata from YouTube oEmbed API + duration from page.
 * No API key required.
 */
export async function fetchYouTubeMetadata(url: string): Promise<YouTubeMetadata | null> {
  const videoId = extractYouTubeVideoId(url)
  if (!videoId) return null

  try {
    // Fetch oEmbed (required) and duration (best-effort) in parallel
    const [oEmbedResponse, durationSeconds] = await Promise.all([
      fetch(`https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=${videoId}&format=json`),
      fetchYouTubeDuration(videoId).catch(() => null),
    ])

    if (!oEmbedResponse.ok) return null

    const data = await oEmbedResponse.json() as { title?: string; author_name?: string }

    return {
      videoId,
      title: data.title || '',
      thumbnailUrl: `https://img.youtube.com/vi/${videoId}/hqdefault.jpg`,
      authorName: data.author_name || '',
      durationSeconds,
    }
  } catch (err) {
    console.error('fetchYouTubeMetadata error:', err)
    return null
  }
}

/**
 * Validate that a URL is a valid YouTube video URL.
 */
export function isValidYouTubeUrl(url: string): boolean {
  return extractYouTubeVideoId(url) !== null
}

/**
 * Build a privacy-enhanced YouTube embed URL with parameters.
 */
export function buildYouTubeEmbedUrl(
  videoId: string,
  options?: { start?: number; end?: number; loop?: boolean }
): string {
  const params = new URLSearchParams({
    rel: '0',
    modestbranding: '1',
  })

  if (options?.start) params.set('start', String(options.start))
  if (options?.end) params.set('end', String(options.end))
  if (options?.loop) {
    params.set('loop', '1')
    params.set('playlist', videoId)
  }

  return `https://www.youtube-nocookie.com/embed/${videoId}?${params.toString()}`
}
