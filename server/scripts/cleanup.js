import { PrismaClient } from '../src/generated/prisma/index.js';
const prisma = new PrismaClient();

async function main() {
  // Delete all enrollments and related data
  const deleted = await prisma.enrollment.deleteMany({});
  console.log(`Deleted ${deleted.count} enrollments (cascades to lesson schedules, events, posts)`);
}

main().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
