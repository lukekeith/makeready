import { PrismaClient } from '../src/generated/prisma/index.js';
const prisma = new PrismaClient();

async function main() {
  // Check sessions
  const sessions = await prisma.$queryRaw`SELECT sid, expire FROM session LIMIT 5`;
  console.log('Sessions:', JSON.stringify(sessions, null, 2));
  
  // Check recent enrollments
  const enrollments = await prisma.enrollment.findMany({
    take: 3,
    orderBy: { createdAt: 'desc' }
  });
  console.log('Recent enrollments:', enrollments.length);
  
  // Check study programs
  const programs = await prisma.studyProgram.findMany({
    where: { isActive: true },
    select: { id: true, name: true, creatorId: true }
  });
  console.log('Active programs:', JSON.stringify(programs, null, 2));
  
  // Check groups
  const groups = await prisma.group.findMany({
    where: { isActive: true },
    select: { id: true, name: true, creatorId: true }
  });
  console.log('Active groups:', JSON.stringify(groups, null, 2));
}

main().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
