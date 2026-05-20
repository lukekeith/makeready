/**
 * Cloudflare Stream Service
 * Provides wrapper functions for Cloudflare Stream API
 *
 * Docs: https://developers.cloudflare.com/stream/
 */

const accountId = process.env.CLOUDFLARE_ACCOUNT_ID
const apiToken = process.env.CLOUDFLARE_API_TOKEN

const CLOUDFLARE_API_BASE = 'https://api.cloudflare.com/client/v4'

// ============================================================================
// Type Definitions
// ============================================================================

export interface CreateUploadUrlResult {
  success: boolean
  uploadUrl?: string
  uid?: string
  error?: string
}

export interface VideoDetails {
  uid: string
  status: {
    state: 'pendingupload' | 'queued' | 'inprogress' | 'ready' | 'error'
    pctComplete?: string
    errorReasonCode?: string
    errorReasonText?: string
  }
  meta?: Record<string, string>
  created?: string
  modified?: string
  size?: number
  duration?: number
  thumbnail?: string
  input?: {
    width?: number
    height?: number
  }
  playback?: {
    hls?: string
    dash?: string
  }
}

export interface GetVideoResult {
  success: boolean
  video?: VideoDetails
  error?: string
}

export interface DeleteVideoResult {
  success: boolean
  error?: string
}

// Cloudflare API response types
interface CloudflareError {
  code: number
  message: string
}

interface CloudflareResponse<T> {
  success: boolean
  errors?: CloudflareError[]
  result?: T
}

interface DirectUploadResult {
  uid: string
  uploadURL: string
}

// ============================================================================
// Helper Functions
// ============================================================================

function isConfigured(): boolean {
  return !!(accountId && apiToken)
}

function getHeaders(): Record<string, string> {
  return {
    Authorization: `Bearer ${apiToken}`,
    'Content-Type': 'application/json',
  }
}

// ============================================================================
// Cloudflare Stream API Functions
// ============================================================================

/**
 * Create a direct upload URL for client-side video uploads
 * This allows the iOS app to upload directly to Cloudflare without going through our server
 *
 * @param maxDurationSeconds - Maximum allowed video duration (default: 300 = 5 minutes)
 * @param meta - Optional metadata to attach to the video
 * @returns Upload URL and video UID
 */
export async function createDirectUploadUrl(
  maxDurationSeconds: number = 300,
  meta?: Record<string, string>
): Promise<CreateUploadUrlResult> {
  try {
    if (!isConfigured()) {
      console.error('[Cloudflare] Credentials not configured')
      return {
        success: false,
        error: 'Cloudflare Stream credentials not configured',
      }
    }

    const response = await fetch(
      `${CLOUDFLARE_API_BASE}/accounts/${accountId}/stream/direct_upload`,
      {
        method: 'POST',
        headers: getHeaders(),
        body: JSON.stringify({
          maxDurationSeconds,
          ...(meta && { meta }),
        }),
      }
    )

    const data = (await response.json()) as CloudflareResponse<DirectUploadResult>

    if (!response.ok || !data.success) {
      console.error('[Cloudflare] Error creating upload URL:', JSON.stringify(data.errors))
      console.error('[Cloudflare] Response status:', response.status, response.statusText)
      console.error('[Cloudflare] Account ID:', accountId ? `${accountId.substring(0, 8)}...` : 'MISSING')
      console.error('[Cloudflare] API Token:', apiToken ? `${apiToken.substring(0, 8)}...` : 'MISSING')
      return {
        success: false,
        error: data.errors?.[0]?.message || 'Failed to create upload URL',
      }
    }

    console.log(`[Cloudflare] Created upload URL for video: ${data.result?.uid}`)

    return {
      success: true,
      uploadUrl: data.result?.uploadURL,
      uid: data.result?.uid,
    }
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error'
    console.error('[Cloudflare] Error creating upload URL:', errorMessage)
    return {
      success: false,
      error: errorMessage || 'Failed to create upload URL',
    }
  }
}

/**
 * Get video details from Cloudflare Stream
 * Use this to check video status and get playback URLs after upload
 *
 * @param videoUid - The Cloudflare video UID
 * @returns Video details including status, playback URLs, thumbnail
 */
export async function getVideo(videoUid: string): Promise<GetVideoResult> {
  try {
    if (!isConfigured()) {
      return {
        success: false,
        error: 'Cloudflare Stream credentials not configured',
      }
    }

    const response = await fetch(
      `${CLOUDFLARE_API_BASE}/accounts/${accountId}/stream/${videoUid}`,
      {
        method: 'GET',
        headers: getHeaders(),
      }
    )

    const data = (await response.json()) as CloudflareResponse<VideoDetails>

    if (!response.ok || !data.success) {
      console.error('[Cloudflare] Error getting video:', data.errors)
      return {
        success: false,
        error: data.errors?.[0]?.message || 'Failed to get video details',
      }
    }

    return {
      success: true,
      video: data.result,
    }
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error'
    console.error('[Cloudflare] Error getting video:', errorMessage)
    return {
      success: false,
      error: errorMessage || 'Failed to get video details',
    }
  }
}

/**
 * Delete a video from Cloudflare Stream
 *
 * @param videoUid - The Cloudflare video UID
 * @returns Success status
 */
export async function deleteVideo(videoUid: string): Promise<DeleteVideoResult> {
  try {
    if (!isConfigured()) {
      return {
        success: false,
        error: 'Cloudflare Stream credentials not configured',
      }
    }

    const response = await fetch(
      `${CLOUDFLARE_API_BASE}/accounts/${accountId}/stream/${videoUid}`,
      {
        method: 'DELETE',
        headers: getHeaders(),
      }
    )

    // Cloudflare returns 200 with empty body on successful delete
    if (!response.ok) {
      const data = (await response.json()) as CloudflareResponse<never>
      console.error('[Cloudflare] Error deleting video:', data.errors)
      return {
        success: false,
        error: data.errors?.[0]?.message || 'Failed to delete video',
      }
    }

    console.log(`[Cloudflare] Deleted video: ${videoUid}`)

    return {
      success: true,
    }
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error'
    console.error('[Cloudflare] Error deleting video:', errorMessage)
    return {
      success: false,
      error: errorMessage || 'Failed to delete video',
    }
  }
}

/**
 * Build the HLS playback URL for a video
 * @param videoUid - The Cloudflare video UID
 * @returns HLS manifest URL
 */
export function getPlaybackUrl(videoUid: string): string {
  // Cloudflare Stream uses customer subdomain format
  // The actual subdomain is provided in the API response, but we can construct a default
  return `https://customer-${accountId?.substring(0, 8)}.cloudflarestream.com/${videoUid}/manifest/video.m3u8`
}

/**
 * Build the thumbnail URL for a video
 * @param videoUid - The Cloudflare video UID
 * @param time - Time in seconds for the thumbnail (default: 0)
 * @returns Thumbnail image URL
 */
export function getThumbnailUrl(videoUid: string, time: number = 0): string {
  return `https://customer-${accountId?.substring(0, 8)}.cloudflarestream.com/${videoUid}/thumbnails/thumbnail.jpg?time=${time}s`
}

/**
 * Build a thumbnail URL at a random time in the video
 * @param videoUid - The Cloudflare video UID
 * @param duration - Video duration in seconds
 * @returns Thumbnail URL at a random timestamp
 */
export function getRandomThumbnailUrl(videoUid: string, duration: number): string {
  // Pick random time between 10% and 90% of video to avoid intro/outro
  const minTime = Math.floor(duration * 0.1)
  const maxTime = Math.floor(duration * 0.9)
  const randomTime = Math.floor(Math.random() * (maxTime - minTime + 1)) + minTime
  return getThumbnailUrl(videoUid, randomTime)
}
