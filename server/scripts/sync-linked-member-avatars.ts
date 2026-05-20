/**
 * Sync profile pictures from googlePicture to profilePicture
 *
 * Finds all Members with googlePicture set, downloads the image,
 * uploads to R2 storage, and sets as profilePicture.
 *
 * Usage: npx tsx scripts/sync-linked-member-avatars.ts
 */

import { prisma } from '../src/lib/prisma.js'
import { syncProfilePictureFromUrl } from '../src/services/account-linking.js'

async function main() {
  console.log('🔍 Finding members with googlePicture...\n')

  const members = await prisma.member.findMany({
    where: {
      googlePicture: { not: null },
    },
    select: {
      id: true,
      phoneNumber: true,
      firstName: true,
      lastName: true,
      googlePicture: true,
      profilePicture: true,
    },
  })

  if (members.length === 0) {
    console.log('✅ No members have googlePicture set.')
    return
  }

  console.log(`Found ${members.length} member(s) with googlePicture:\n`)

  let synced = 0
  let skipped = 0
  let failed = 0

  for (const member of members) {
    const name = [member.firstName, member.lastName].filter(Boolean).join(' ') || member.phoneNumber

    console.log(`📷 ${name}`)

    if (member.profilePicture) {
      console.log(`   ⏭️  Already has profilePicture, skipping`)
      skipped++
      continue
    }

    try {
      const success = await syncProfilePictureFromUrl(member.id, member.googlePicture!)
      if (success) {
        console.log(`   ✅ Synced`)
        synced++
      } else {
        console.log(`   ⚠️  Failed`)
        failed++
      }
    } catch (error) {
      console.error(`   ❌ Error:`, error)
      failed++
    }
  }

  console.log(`\n🎉 Done! Synced: ${synced}, Skipped: ${skipped}, Failed: ${failed}`)
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect())
