/**
 * User Preferences Service
 *
 * Generic key-value preference storage that works for both User (Google OAuth)
 * and Member (phone auth) identities.
 *
 * Uses a single UserPreference table with userId OR memberId (exactly one set).
 */

import { prisma } from '../lib/prisma.js'

// ============================================
// Types
// ============================================

/** Identity: exactly one of userId or memberId must be provided */
export interface PreferenceIdentity {
  userId?: string
  memberId?: string
}

/** Default values for known preference keys */
const DEFAULTS: Record<string, string> = {
  bible_translation: 'NASB',
}

// ============================================
// Validation
// ============================================

function validateIdentity(identity: PreferenceIdentity): { userId?: string; memberId?: string } {
  if (identity.userId && identity.memberId) {
    throw new Error('[preferences] Cannot specify both userId and memberId')
  }
  if (!identity.userId && !identity.memberId) {
    throw new Error('[preferences] Must specify either userId or memberId')
  }
  return identity
}

function buildWhere(identity: PreferenceIdentity, key?: string) {
  const where: any = {}
  if (identity.userId) where.userId = identity.userId
  if (identity.memberId) where.memberId = identity.memberId
  if (key) where.key = key
  return where
}

// ============================================
// CRUD operations
// ============================================

/**
 * Get a single preference value.
 * Returns null if not set (use getPreferenceOrDefault for fallback).
 */
export async function getPreference(
  identity: PreferenceIdentity,
  key: string
): Promise<string | null> {
  validateIdentity(identity)

  const pref = await prisma.userPreference.findFirst({
    where: buildWhere(identity, key),
  })

  return pref?.value ?? null
}

/**
 * Get a preference value with fallback to the built-in default.
 * Returns the default if the preference is not set.
 */
export async function getPreferenceOrDefault(
  identity: PreferenceIdentity,
  key: string
): Promise<string> {
  const value = await getPreference(identity, key)
  return value ?? DEFAULTS[key] ?? ''
}

/**
 * Set a preference value. Upserts — creates or updates.
 */
export async function setPreference(
  identity: PreferenceIdentity,
  key: string,
  value: string
): Promise<void> {
  validateIdentity(identity)

  if (identity.userId) {
    await prisma.userPreference.upsert({
      where: { userId_key: { userId: identity.userId, key } },
      create: {
        userId: identity.userId,
        key,
        value,
      },
      update: { value },
    })
  } else if (identity.memberId) {
    await prisma.userPreference.upsert({
      where: { memberId_key: { memberId: identity.memberId, key } },
      create: {
        memberId: identity.memberId,
        key,
        value,
      },
      update: { value },
    })
  }
}

/**
 * Get all preferences for a user/member as a key-value map.
 * Includes defaults for known keys that are not explicitly set.
 */
export async function getAllPreferences(
  identity: PreferenceIdentity
): Promise<Record<string, string>> {
  validateIdentity(identity)

  const prefs = await prisma.userPreference.findMany({
    where: buildWhere(identity),
  })

  // Start with defaults, then overlay with actual values
  const result: Record<string, string> = { ...DEFAULTS }
  for (const pref of prefs) {
    result[pref.key] = pref.value
  }

  return result
}

/**
 * Delete a preference (resets it to the default).
 */
export async function deletePreference(
  identity: PreferenceIdentity,
  key: string
): Promise<void> {
  validateIdentity(identity)

  await prisma.userPreference.deleteMany({
    where: buildWhere(identity, key),
  })
}

/**
 * Get multiple preferences by key. Returns only keys that have stored values.
 */
export async function getPreferencesBatch(
  identity: PreferenceIdentity,
  keys: string[]
): Promise<Record<string, string>> {
  validateIdentity(identity)

  const prefs = await prisma.userPreference.findMany({
    where: { ...buildWhere(identity), key: { in: keys } },
  })

  const result: Record<string, string> = {}
  for (const pref of prefs) {
    result[pref.key] = pref.value
  }
  return result
}

/**
 * Get the default value for a known preference key.
 */
export function getDefault(key: string): string | undefined {
  return DEFAULTS[key]
}
