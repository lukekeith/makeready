import 'dotenv/config'
import { PrismaClient } from '../generated/prisma'

const prisma = new PrismaClient()

async function addSearchIndex() {
  try {
    console.log('Adding full-text search column...')

    // Add computed tsvector column
    await prisma.$executeRawUnsafe(`
      ALTER TABLE verses
      ADD COLUMN IF NOT EXISTS search_vector tsvector
      GENERATED ALWAYS AS (to_tsvector('english', text)) STORED
    `)

    console.log('Creating GIN index...')

    // Create GIN index for fast full-text search
    await prisma.$executeRawUnsafe(`
      CREATE INDEX IF NOT EXISTS verses_search_idx
      ON verses USING GIN (search_vector)
    `)

    console.log('✅ Full-text search index added successfully!')

  } catch (error) {
    console.error('Error adding search index:', error)
    throw error
  } finally {
    await prisma.$disconnect()
  }
}

addSearchIndex()
