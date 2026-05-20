import { prisma } from './prisma.js'

// Characters: A-Z + 2-9 (exclude 0, 1, O, I, L for readability)
const CHARS = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'

/**
 * Generate a random 6-character study code
 * Uses only unambiguous characters (no 0, 1, O, I, L)
 */
export function generateStudyCode(): string {
  let code = ''
  for (let i = 0; i < 6; i++) {
    code += CHARS[Math.floor(Math.random() * CHARS.length)]
  }
  return code
}

/**
 * Generate a unique study code that doesn't exist in the database
 * Retries if collision occurs (extremely unlikely with 30^6 = 729M possibilities)
 * Note: Study codes are unique within lesson_schedules only
 */
export async function generateUniqueStudyCode(): Promise<string> {
  let code = generateStudyCode()
  let exists = await prisma.lessonSchedule.findUnique({ where: { code } })

  // Retry until we find a unique code (collision is extremely rare)
  while (exists) {
    code = generateStudyCode()
    exists = await prisma.lessonSchedule.findUnique({ where: { code } })
  }

  return code
}

/**
 * Normalize a study code to uppercase for comparison
 */
export function normalizeStudyCode(code: string): string {
  return code.toUpperCase().trim()
}
