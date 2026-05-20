import { PrismaClient } from '../src/generated/prisma/index.js';
const prisma = new PrismaClient();

async function main() {
  // Check lessons for each program
  const programs = await prisma.studyProgram.findMany({
    where: { isActive: true },
    include: {
      lessons: {
        orderBy: { dayNumber: 'asc' }
      }
    }
  });
  
  for (const p of programs) {
    console.log(`Program: ${p.name} (${p.id})`);
    console.log(`  Lessons: ${p.lessons.length}`);
    if (p.lessons.length === 0) {
      console.log('  ⚠️ NO LESSONS - This will cause enrollment to fail!');
    }
  }
}

main().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
