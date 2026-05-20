import { PrismaClient } from '../src/generated/prisma/index.js';
const prisma = new PrismaClient();

async function main() {
  const enrollments = await prisma.enrollment.findMany({
    take: 3,
    orderBy: { createdAt: 'desc' },
    include: { studyProgram: { select: { name: true } } }
  });
  console.log("Recent enrollments:", JSON.stringify(enrollments, null, 2));
  
  const posts = await prisma.post.findMany({
    take: 3,
    orderBy: { createdAt: 'desc' }
  });
  console.log("Recent posts:", JSON.stringify(posts, null, 2));
}

main().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
