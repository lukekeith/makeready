import { PrismaClient } from '../src/generated/prisma/index.js';

const prisma = new PrismaClient();

async function main() {
  await prisma.$executeRaw`
    CREATE TABLE IF NOT EXISTS session (
      sid VARCHAR NOT NULL PRIMARY KEY,
      sess JSON NOT NULL,
      expire TIMESTAMP(6) NOT NULL
    )
  `;
  await prisma.$executeRaw`
    CREATE INDEX IF NOT EXISTS IDX_session_expire ON session (expire)
  `;
  console.log('Session table created');
}

main().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
