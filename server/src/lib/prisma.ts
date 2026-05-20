import { PrismaClient, Prisma } from '../generated/prisma/index.js'

export { Prisma }

// PrismaClient is attached to the `global` object in development to prevent
// exhausting your database connection limit.

const globalForPrisma = global as unknown as { prisma: PrismaClient }

// Use DIRECT_URL to bypass PgBouncer session pooling
// PgBouncer's session pooling causes "prepared statement already exists" errors
const getDatasourceUrl = () => {
  if (process.env.DIRECT_URL) {
    return process.env.DIRECT_URL
  }
  return undefined // Use default from schema.prisma
}

export const prisma =
  globalForPrisma.prisma ||
  new PrismaClient({
    log: process.env.NODE_ENV === 'development' ? ['error', 'warn'] : ['error'],
    datasourceUrl: getDatasourceUrl(),
  })

// Eagerly connect to database on module load (reduces first query latency)
// This ensures the connection pool is ready before the first request
if (process.env.NODE_ENV === 'production') {
  prisma.$connect().catch((e) => {
    console.error('❌ Failed to connect to database:', e)
  })
}

// In development, log queries but filter out health check SELECT 1 queries
if (process.env.NODE_ENV === 'development') {
  prisma.$on('query' as never, (e: any) => {
    // Filter out health check queries to reduce console noise
    if (!e.query.includes('SELECT 1')) {
      console.log('prisma:query', e.query)
    }
  })
}

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma
