import { S3Client, PutObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3'

/**
 * Storage Service
 * Handles file uploads to Cloudflare R2 (S3-compatible)
 */

const MAX_FILE_SIZE = 5 * 1024 * 1024 // 5MB

let s3Client: S3Client | null = null

function getR2Client(): S3Client {
  if (s3Client) return s3Client

  const accountId = process.env.R2_ACCOUNT_ID
  const accessKeyId = process.env.R2_ACCESS_KEY_ID
  const secretAccessKey = process.env.R2_SECRET_ACCESS_KEY

  if (!accountId || !accessKeyId || !secretAccessKey) {
    throw new Error('R2 credentials not configured (R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY)')
  }

  s3Client = new S3Client({
    region: 'auto',
    endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
    credentials: {
      accessKeyId,
      secretAccessKey,
    },
  })
  return s3Client
}

function getBucket(): string {
  return process.env.R2_BUCKET_NAME || 'makeready-media'
}

function getPublicUrl(key: string): string {
  const baseUrl = process.env.R2_PUBLIC_URL
  if (!baseUrl) {
    throw new Error('R2_PUBLIC_URL not configured')
  }
  return `${baseUrl.replace(/\/$/, '')}/${key}`
}

/**
 * Upload a file to R2
 * @param key - The object key (path) in the bucket
 * @param buffer - The file buffer
 * @param contentType - The MIME type
 */
export async function uploadToR2(
  key: string,
  buffer: Buffer,
  contentType: string
): Promise<string> {
  const client = getR2Client()

  await client.send(
    new PutObjectCommand({
      Bucket: getBucket(),
      Key: key,
      Body: buffer,
      ContentType: contentType,
    })
  )

  return getPublicUrl(key)
}

/**
 * Delete a file from R2
 * @param key - The object key (path) in the bucket
 */
export async function deleteFromR2(key: string): Promise<void> {
  const client = getR2Client()

  await client.send(
    new DeleteObjectCommand({
      Bucket: getBucket(),
      Key: key,
    })
  )
}

/**
 * Extract the R2 object key from a public URL
 */
export function extractKeyFromUrl(url: string): string | null {
  const publicUrl = process.env.R2_PUBLIC_URL
  if (publicUrl && url.startsWith(publicUrl)) {
    return url.slice(publicUrl.replace(/\/$/, '').length + 1)
  }
  return null
}

export interface UploadResult {
  success: boolean
  url?: string
  error?: string
}

/**
 * No-op: R2 buckets are created via Cloudflare dashboard.
 * Kept for backward compatibility with server startup.
 */
export async function ensureAvatarBucket(): Promise<void> {
  // R2 bucket is pre-created in Cloudflare dashboard — nothing to do here
}

/**
 * Upload a member avatar to R2
 * @param memberId - The member's ID (used in the file path)
 * @param fileBuffer - The file buffer
 * @param mimeType - The file's MIME type
 * @returns The public URL of the uploaded file
 */
export async function uploadMemberAvatar(
  memberId: string,
  fileBuffer: Buffer,
  mimeType: string
): Promise<UploadResult> {
  try {
    // Validate file size
    if (fileBuffer.length > MAX_FILE_SIZE) {
      return {
        success: false,
        error: 'File size exceeds 5MB limit',
      }
    }

    // Validate mime type
    const allowedTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp']
    if (!allowedTypes.includes(mimeType)) {
      return {
        success: false,
        error: 'Invalid file type. Allowed: JPEG, PNG, GIF, WebP',
      }
    }

    // Get file extension from mime type
    const extensions: Record<string, string> = {
      'image/jpeg': 'jpg',
      'image/png': 'png',
      'image/gif': 'gif',
      'image/webp': 'webp',
    }
    const extension = extensions[mimeType] || 'jpg'

    // Generate unique filename with timestamp
    const timestamp = Date.now()
    const key = `avatars/members/${memberId}/${timestamp}.${extension}`

    const url = await uploadToR2(key, fileBuffer, mimeType)

    console.log(`✅ Avatar uploaded for member ${memberId}: ${url}`)

    return {
      success: true,
      url,
    }
  } catch (error) {
    console.error('Error in uploadMemberAvatar:', error)
    return {
      success: false,
      error: 'Internal error uploading avatar',
    }
  }
}

/**
 * Delete a member's old avatar from storage
 * @param avatarUrl - The full URL of the avatar to delete
 */
export async function deleteMemberAvatar(avatarUrl: string): Promise<void> {
  try {
    const key = extractKeyFromUrl(avatarUrl)
    if (!key) return

    await deleteFromR2(key)

    console.log(`✅ Deleted old avatar: ${key}`)
  } catch (error) {
    // Don't fail if delete doesn't work - old file will just remain
    console.warn('Warning: Could not delete old avatar:', error)
  }
}

/**
 * Upload image variants (original, medium, thumbnail) to R2
 * Used by program, group, and event cover image uploads.
 * Returns the public URL of the original image.
 */
export async function uploadImageVariants(
  prefix: string,
  baseName: string,
  extension: string,
  originalBuffer: Buffer,
  mediumBuffer: Buffer,
  thumbBuffer: Buffer,
  contentType: string = 'image/jpeg'
): Promise<{ url: string }> {
  const mediumSuffix = '-md'

  await Promise.all([
    uploadToR2(`${prefix}/${baseName}.${extension}`, originalBuffer, contentType),
    uploadToR2(`${prefix}/${baseName}${mediumSuffix}.${extension}`, mediumBuffer, contentType),
    uploadToR2(`${prefix}/${baseName}-thumb.${extension}`, thumbBuffer, contentType),
  ])

  const url = getPublicUrl(`${prefix}/${baseName}.${extension}`)
  return { url }
}

/**
 * Upload a single file to R2
 * Used for event attachments and other single-file uploads.
 * Returns the public URL.
 */
export async function uploadFile(
  prefix: string,
  path: string,
  buffer: Buffer,
  contentType: string
): Promise<{ url: string }> {
  const key = `${prefix}/${path}`
  const url = await uploadToR2(key, buffer, contentType)
  return { url }
}
