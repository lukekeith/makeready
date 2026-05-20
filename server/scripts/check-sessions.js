import { PrismaClient } from '../src/generated/prisma/index.js';
const prisma = new PrismaClient();

async function main() {
  const sessions = await prisma.$queryRaw`SELECT sid, expire FROM session LIMIT 5`;
  console.log('Sessions:', JSON.stringify(sessions, null, 2));
}

main().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
