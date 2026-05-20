/**
 * API Key Utilities
 *
 * Functions for generating, hashing, and validating API keys.
 * Keys follow the format: mr_[43 random base62 characters]
 * Total length: 46 characters (~256 bits entropy)
 */

import crypto from 'crypto'

/** API key prefix */
const API_KEY_PREFIX = 'mr_'

/** Length of the random portion (base62 characters) */
const RANDOM_LENGTH = 43

/** Base62 character set (0-9, a-z, A-Z) */
const BASE62_CHARS = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'

/**
 * Generate a cryptographically secure random string in base62
 * @param length - Number of characters to generate
 * @returns Random base62 string
 */
function generateBase62(length: number): string {
  const bytes = crypto.randomBytes(length)
  let result = ''

  for (let i = 0; i < length; i++) {
    // Use modulo to map random byte (0-255) to base62 index (0-61)
    // This introduces slight bias but is acceptable for key generation
    result += BASE62_CHARS[bytes[i] % BASE62_CHARS.length]
  }

  return result
}

/**
 * Generate a new API key
 * @returns Full API key in format: mr_[43 chars]
 */
export function generateApiKey(): string {
  const randomPart = generateBase62(RANDOM_LENGTH)
  return `${API_KEY_PREFIX}${randomPart}`
}

/**
 * Hash an API key using SHA-256
 * @param apiKey - The full API key to hash
 * @returns SHA-256 hash as hex string
 */
export function hashApiKey(apiKey: string): string {
  return crypto.createHash('sha256').update(apiKey).digest('hex')
}

/**
 * Extract the display prefix from an API key
 * Returns first 8 characters (e.g., "mr_abc12")
 * @param apiKey - The full API key
 * @returns Display prefix
 */
export function getKeyPrefix(apiKey: string): string {
  return apiKey.substring(0, 8)
}

/**
 * Validate API key format
 * @param apiKey - String to validate
 * @returns True if valid format
 */
export function isValidApiKeyFormat(apiKey: string): boolean {
  if (!apiKey || typeof apiKey !== 'string') {
    return false
  }

  // Must start with mr_
  if (!apiKey.startsWith(API_KEY_PREFIX)) {
    return false
  }

  // Total length should be 46 (3 for prefix + 43 for random)
  if (apiKey.length !== API_KEY_PREFIX.length + RANDOM_LENGTH) {
    return false
  }

  // Random part should be base62 only
  const randomPart = apiKey.substring(API_KEY_PREFIX.length)
  const base62Regex = /^[0-9a-zA-Z]+$/
  return base62Regex.test(randomPart)
}

/**
 * Extract bearer token from Authorization header
 * @param authHeader - The Authorization header value
 * @returns The API key if Bearer token, null otherwise
 */
export function extractBearerToken(authHeader: string | undefined): string | null {
  if (!authHeader) {
    return null
  }

  const parts = authHeader.split(' ')
  if (parts.length !== 2 || parts[0].toLowerCase() !== 'bearer') {
    return null
  }

  return parts[1]
}
