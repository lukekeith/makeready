/**
 * seed-preview-smoke-test.ts
 *
 * Creates (or refreshes) a single READ activity with two read blocks whose
 * content matches the `/slides` dev preview — so we can open
 *   http://localhost:5173/preview/activity/<id>
 * and see the canonical ActivityPreviewPlayer render real data.
 *
 * Idempotent: re-running wipes this program's blocks/activity/lesson and
 * recreates them. Does NOT touch any other data.
 *
 * Run with:  npx tsx scripts/seed-preview-smoke-test.ts
 */

import { PrismaClient, TemplateActivityType } from '../src/generated/prisma'

const prisma = new PrismaClient()

const PROGRAM_NAME = 'Preview Smoke Test'

// Fixed UUIDs so the preview URL is stable across re-seeds — bookmark it.
const FIXED_PROGRAM_ID  = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
const FIXED_LESSON_ID   = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
const FIXED_ACTIVITY_ID = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
const FIXED_BLOCK_1_ID  = 'dddddddd-dddd-dddd-dddd-dddddddddddd'
const FIXED_BLOCK_2_ID  = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'

async function main() {
  const user = await prisma.user.findFirst({
    orderBy: { createdAt: 'asc' },
    select: { id: true, email: true, name: true },
  })
  if (!user) {
    throw new Error('No User rows in DB — log in once via Google OAuth first, then re-run.')
  }
  console.log(`👤 Using creator: ${user.name ?? user.email} (${user.id})`)

  const [dramatic, gentle] = await Promise.all([
    prisma.textTheme.findUnique({ where: { slug: 'dramatic-reveal' } }),
    prisma.textTheme.findUnique({ where: { slug: 'gentle-fade' } }),
  ])
  if (!dramatic || !gentle) {
    throw new Error('System themes not loaded — run `npm run themes:load` first.')
  }

  // Wipe by fixed ID (or by name as a fallback for older seeds).
  await prisma.studyProgram.deleteMany({
    where: {
      OR: [
        { id: FIXED_PROGRAM_ID },
        { creatorId: user.id, name: PROGRAM_NAME },
      ],
    },
  })

  const program = await prisma.studyProgram.create({
    data: {
      id:          FIXED_PROGRAM_ID,
      name:        PROGRAM_NAME,
      description: 'Auto-generated smoke test for the canonical activity preview.',
      days:        1,
      isPublished: false,
      creatorId:   user.id,
      lessons: {
        create: [{
          id:        FIXED_LESSON_ID,
          dayNumber: 1,
          title:     'Preview smoke test',
          activities: {
            create: [{
              id:           FIXED_ACTIVITY_ID,
              activityType: TemplateActivityType.READ,
              orderNumber:  1,
              title:        'Romans 1:1–6',
              readBlocks: {
                create: [
                  {
                    id:          FIXED_BLOCK_1_ID,
                    orderNumber: 1,
                    title:       'Romans 1:1',
                    contentFormat: 'markdown',
                    themeId:     dramatic.id,
                    backgroundImageUrl: '/themes/mountain.png',
                    content: `# Romans 1:1

1. Paul, a servant of Christ Jesus, called to be an apostle and set apart for the gospel of God—
2. the gospel he promised beforehand through his prophets in the Holy Scriptures
3. regarding his Son, who as to his earthly life was a descendant of David,
4. and who through the Spirit of holiness was appointed the Son of God in power by his resurrection from the dead: Jesus Christ our Lord.
5. Through him we received grace and apostleship to call all the Gentiles to the obedience that comes from faith for his name's sake.
6. And you also are among those Gentiles who are called to belong to Jesus Christ`,
                  },
                  {
                    id:          FIXED_BLOCK_2_ID,
                    orderNumber: 2,
                    title:       'Key Themes',
                    contentFormat: 'markdown',
                    themeId:     gentle.id,
                    backgroundImageUrl: '/themes/apple.png',
                    content: `# Key Themes in Romans 1:1-6

- Paul identifies himself as a **servant** and **apostle** — called, not self-appointed
- The gospel was not new — God promised it through the prophets in the Holy Scriptures
- Jesus is both fully human (descendant of David) and declared Son of God through resurrection
- Grace and apostleship are gifts received, not earned
- The mission is global — all Gentiles are called to the obedience that comes from faith`,
                  },
                ],
              },
            }],
          },
        }],
      },
    },
    include: {
      lessons: { include: { activities: { include: { readBlocks: true } } } },
    },
  })

  const activity = program.lessons[0].activities[0]
  const baseUrl = process.env.CLIENT_BASE_URL || 'http://localhost:5173'

  console.log('')
  console.log('✅ Seed complete.')
  console.log(`   Program:  ${program.name} (${program.id})`)
  console.log(`   Activity: ${activity.title} (${activity.id})`)
  console.log(`   Blocks:   ${activity.readBlocks.length}`)
  console.log('')
  console.log('🌐 Open in a browser logged in as that user:')
  console.log(`   ${baseUrl}/preview/activity/${activity.id}`)
  console.log('')
}

main()
  .catch(err => { console.error(err); process.exit(1) })
  .finally(() => prisma.$disconnect())
