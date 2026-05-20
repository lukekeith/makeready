// Simple script to print recent console output
console.log("Checking for recent enrollments and errors...");
import { PrismaClient } from '../src/generated/prisma/index.js';
const prisma = new PrismaClient();

async function main() {
  // Check enrollments
  const count = await prisma.enrollment.count();
  console.log(`Total enrollments: ${count}`);
  
  // Check posts
  const posts = await prisma.post.count();
  console.log(`Total posts: ${posts}`);
  
  // Check if there are any lessons with the Genesis program
  const genesis = await prisma.studyProgram.findFirst({
    where: { name: "Genesis" },
    include: {
      lessons: {
        take: 3,
        include: {
          activities: true
        }
      }
    }
  });
  console.log(`Genesis lessons: ${genesis?.lessons.length}`);
  if (genesis?.lessons[0]) {
    console.log(`First lesson has ${genesis.lessons[0].activities.length} activities`);
  }
}

main().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
