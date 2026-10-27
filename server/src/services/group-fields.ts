/**
 * ui2-groups-edit D7, D8, D12: the PATCH /api/groups/:id rules for the directory pair and the
 * age range. Pure — the route reads the stored enum and applies what these return.
 */
export type DirectoryAccess = 'ALLOWED' | 'NAMES_ONLY' | 'NOT_ALLOWED'

export interface DirectoryInput {
  memberDirectory?: boolean
  memberDirectoryAccess?: DirectoryAccess
}

export interface DirectoryUpdate {
  memberDirectoryAccess: DirectoryAccess
  memberDirectoryEnabled: boolean
}

/**
 * D7: `memberDirectoryAccess` writes the enum and sets the Boolean to (value == ALLOWED); sent with a
 * disagreeing `memberDirectory` it is a conflict. D12: `memberDirectory` alone — true → ALLOWED;
 * false → NOT_ALLOWED only when the stored value is ALLOWED (a stored NAMES_ONLY / NOT_ALLOWED is kept).
 * null = neither key sent, nothing to write.
 */
export function directoryWrite(input: DirectoryInput, stored: DirectoryAccess): DirectoryUpdate | 'conflict' | null {
  const { memberDirectory, memberDirectoryAccess } = input
  if (memberDirectoryAccess !== undefined) {
    const enabled = memberDirectoryAccess === 'ALLOWED'
    if (memberDirectory !== undefined && memberDirectory !== enabled) return 'conflict'
    return { memberDirectoryAccess, memberDirectoryEnabled: enabled }
  }
  if (memberDirectory === undefined) return null
  if (memberDirectory) return { memberDirectoryAccess: 'ALLOWED', memberDirectoryEnabled: true }
  return { memberDirectoryAccess: stored === 'ALLOWED' ? 'NOT_ALLOWED' : stored, memberDirectoryEnabled: false }
}

/** D8: both bounds present and min > max. */
export function isAgeRangeInverted(range: { min?: number | null; max?: number | null } | null | undefined): boolean {
  if (!range) return false
  const { min, max } = range
  return min != null && max != null && min > max
}

export const AGE_RANGE_INVERTED_MESSAGE = 'Minimum age must not exceed maximum age'
export const DIRECTORY_CONFLICT_MESSAGE = 'memberDirectory conflicts with memberDirectoryAccess'
