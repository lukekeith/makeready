import { prisma } from '../src/lib/prisma.js'

async function check() {
  // Members with googlePicture
  const withGooglePic = await prisma.member.count({ where: { googlePicture: { not: null } } })

  // Members linked to Users
  const linkedToUser = await prisma.member.count({ where: { userId: { not: null } } })

  // Members linked to Users where User has picture
  const linkedWithPic = await prisma.member.findMany({
    where: {
      userId: { not: null },
      linkedUser: { picture: { not: null } }
    },
    select: {
      id: true,
      firstName: true,
      lastName: true,
      phoneNumber: true,
      profilePicture: true,
      linkedUser: { select: { email: true, picture: true } }
    }
  })

  console.log('Members with googlePicture:', withGooglePic)
  console.log('Members linked to User:', linkedToUser)
  console.log('Members linked to User with picture:', linkedWithPic.length)

  if (linkedWithPic.length > 0) {
    console.log('\nDetails:')
    for (const m of linkedWithPic) {
      const name = [m.firstName, m.lastName].filter(Boolean).join(' ') || m.phoneNumber
      const hasProfilePic = m.profilePicture ? 'YES' : 'NO'
      console.log(`  - ${name} | profilePicture: ${hasProfilePic} | User: ${m.linkedUser?.email}`)
    }
  }
}

check().finally(() => prisma.$disconnect())
