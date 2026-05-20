import { prisma } from './prisma.js'

// Characters: A-Z + 2-9 (exclude 0, 1, O, I, L for readability)
const CHARS = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'

/**
 * Generate a random 6-character group code
 * Uses only unambiguous characters (no 0, 1, O, I, L)
 */
export function generateGroupCode(): string {
  let code = ''
  for (let i = 0; i < 6; i++) {
    code += CHARS[Math.floor(Math.random() * CHARS.length)]
  }
  return code
}

/**
 * Generate a unique group code that doesn't exist in the database
 * Retries if collision occurs (extremely unlikely with 30^6 = 729M possibilities)
 */
export async function generateUniqueGroupCode(): Promise<string> {
  let code = generateGroupCode()
  let exists = await prisma.group.findUnique({ where: { code } })

  // Retry until we find a unique code (collision is extremely rare)
  while (exists) {
    code = generateGroupCode()
    exists = await prisma.group.findUnique({ where: { code } })
  }

  return code
}

/**
 * Normalize a group code to uppercase for comparison
 */
export function normalizeGroupCode(code: string): string {
  return code.toUpperCase().trim()
}
