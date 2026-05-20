/**
 * YAML to Prisma Schema Transformer
 *
 * Converts the YAML schema definition to Prisma schema format.
 * The generated schema is placed at prisma/schema.prisma
 */

import { readFileSync, writeFileSync, existsSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'
import * as yaml from 'yaml'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)
const SCHEMA_DIR = resolve(__dirname, '../../schema')
const OUTPUT_PATH = resolve(__dirname, '../../prisma/schema.prisma')

// =============================================================================
// Types
// =============================================================================

interface Field {
  type: string
  primary?: boolean
  unique?: boolean
  nullable?: boolean
  default?: string | number | boolean
  updatedAt?: boolean
  description?: string
  deprecated?: boolean
  deprecation_note?: string
  enum?: string
  db_type?: string
  precision?: number
  scale?: number
}

interface Relation {
  type: string
  target: string
  fields?: string[]
  references?: string[]
  name?: string
  onDelete?: string
  nullable?: boolean
}

interface Index {
  fields: string[]
  unique?: boolean
  name?: string
}

interface UniqueConstraint {
  fields: string[]
  name?: string
}

interface Model {
  table_name: string
  soft_delete?: boolean
  fields: Record<string, Field>
  relations?: Record<string, Relation>
  indexes?: Index[]
  unique?: UniqueConstraint[]
}

interface EnumDefinition {
  values: string[]
}

interface Generator {
  provider: string
  output: string
}

interface Datasource {
  provider: string
  url: string
  directUrl?: string
}

interface Schema {
  version: string
  database: string
  generators?: Record<string, Generator>
  datasource?: Datasource
  models: Record<string, Model>
}

interface EnumsFile {
  version: string
  enums: Record<string, EnumDefinition>
}

// =============================================================================
// YAML Loading
// =============================================================================

function loadYaml<T>(filename: string): T {
  const filePath = resolve(SCHEMA_DIR, filename)
  if (!existsSync(filePath)) {
    throw new Error(`File not found: ${filePath}`)
  }
  const content = readFileSync(filePath, 'utf-8')
  return yaml.parse(content) as T
}

// =============================================================================
// Type Mapping
// =============================================================================

function mapFieldTypeToPrisma(field: Field): string {
  const { type, precision, scale, db_type } = field

  switch (type) {
    case 'uuid':
      return 'String'
    case 'string':
      return 'String'
    case 'text':
      return 'String'
    case 'int':
      return 'Int'
    case 'float':
      return 'Float'
    case 'boolean':
      return 'Boolean'
    case 'datetime':
      return 'DateTime'
    case 'json':
      return 'Json'
    case 'decimal':
      return 'Decimal'
    case 'enum':
      return field.enum || 'String'
    case 'unsupported':
      return `Unsupported("${db_type}")`
    case 'string_array':
      return 'String[]'
    default:
      return 'String'
  }
}

function mapDefaultToPrisma(field: Field): string | null {
  const { default: defaultValue, type, enum: enumName } = field

  if (defaultValue === undefined) return null

  // Handle special defaults
  if (typeof defaultValue === 'string') {
    if (defaultValue === 'now()') {
      return '@default(now())'
    }
    if (defaultValue === 'uuid()' || defaultValue === 'uuid_generate_v4()') {
      return '@default(uuid())'
    }
    // Enum default - capitalize
    if (type === 'enum' && enumName) {
      return `@default(${defaultValue})`
    }
    // String literal
    return `@default("${defaultValue}")`
  }

  if (typeof defaultValue === 'boolean') {
    return `@default(${defaultValue})`
  }

  if (typeof defaultValue === 'number') {
    return `@default(${defaultValue})`
  }

  return null
}

// =============================================================================
// Prisma Generation
// =============================================================================

function generateEnumPrisma(name: string, enumDef: EnumDefinition): string {
  const values = enumDef.values.map(v => `  ${v}`).join('\n')
  return `enum ${name} {\n${values}\n}`
}

function generateFieldPrisma(fieldName: string, field: Field): string {
  const parts: string[] = []

  // Field name and type
  let prismaType = mapFieldTypeToPrisma(field)

  // Nullable marker
  if (field.nullable) {
    prismaType += '?'
  }

  parts.push(`  ${fieldName.padEnd(20)} ${prismaType}`)

  // Attributes
  const attrs: string[] = []

  // Primary key
  if (field.primary) {
    attrs.push('@id')
  }

  // Unique
  if (field.unique) {
    attrs.push('@unique')
  }

  // Default
  const defaultAttr = mapDefaultToPrisma(field)
  if (defaultAttr) {
    attrs.push(defaultAttr)
  }

  // Updated at
  if (field.updatedAt) {
    attrs.push('@updatedAt')
  }

  // DB type for text
  if (field.type === 'text') {
    attrs.push('@db.Text')
  }

  // Decimal precision
  if (field.type === 'decimal' && field.precision && field.scale) {
    attrs.push(`@db.Decimal(${field.precision}, ${field.scale})`)
  }

  if (attrs.length > 0) {
    parts.push(attrs.join(' '))
  }

  // Comment for description/deprecated
  let comment = ''
  if (field.deprecated) {
    comment = ` // Deprecated${field.deprecation_note ? ' - ' + field.deprecation_note : ''}`
  } else if (field.description) {
    comment = ` // ${field.description}`
  }

  return parts.join(' ') + comment
}

function generateRelationPrisma(
  relName: string,
  relation: Relation,
  modelName: string,
  models: Record<string, Model>
): string {
  const { type, target, fields, references, name, onDelete, nullable } = relation

  // Determine the Prisma type
  let prismaType = target
  if (type === 'one_to_many') {
    prismaType = `${target}[]`
  } else if (nullable || type === 'one_to_one' && !fields) {
    // Optional relations that don't have foreign key fields
    prismaType = `${target}?`
  }

  const parts: string[] = []
  parts.push(`  ${relName.padEnd(20)} ${prismaType}`)

  // Relation attributes
  const attrs: string[] = []

  // Relation decorator for many_to_one
  if (type === 'many_to_one' && fields && references) {
    let relAttr = `@relation(`
    const relParts: string[] = []

    if (name) {
      relParts.push(`"${name}"`)
    }

    relParts.push(`fields: [${fields.join(', ')}]`)
    relParts.push(`references: [${references.join(', ')}]`)

    if (onDelete) {
      relParts.push(`onDelete: ${onDelete}`)
    }

    relAttr += relParts.join(', ') + ')'
    attrs.push(relAttr)
  } else if (name) {
    // Just a relation name
    attrs.push(`@relation("${name}")`)
  }

  if (attrs.length > 0) {
    parts.push(attrs.join(' '))
  }

  return parts.join(' ')
}

function generateIndexPrisma(index: Index): string {
  const fields = index.fields.join(', ')
  if (index.unique) {
    return `  @@unique([${fields}])`
  }
  return `  @@index([${fields}])`
}

function generateModelPrisma(
  modelName: string,
  model: Model,
  models: Record<string, Model>
): string {
  const lines: string[] = []

  lines.push(`model ${modelName} {`)

  // Fields
  for (const [fieldName, field] of Object.entries(model.fields)) {
    lines.push(generateFieldPrisma(fieldName, field))
  }

  // Add soft_delete field if enabled
  if (model.soft_delete) {
    lines.push(generateFieldPrisma('deleted_at', {
      type: 'datetime',
      nullable: true,
      description: 'Soft delete timestamp',
    }))
  }

  // Relations
  if (model.relations) {
    lines.push('') // Blank line before relations
    for (const [relName, relation] of Object.entries(model.relations)) {
      lines.push(generateRelationPrisma(relName, relation, modelName, models))
    }
  }

  // Unique constraints
  if (model.unique) {
    lines.push('') // Blank line before constraints
    for (const unique of model.unique) {
      lines.push(`  @@unique([${unique.fields.join(', ')}])`)
    }
  }

  // Indexes
  if (model.indexes) {
    for (const index of model.indexes) {
      lines.push(generateIndexPrisma(index))
    }
  }

  // Table mapping
  lines.push(`  @@map("${model.table_name}")`)

  lines.push('}')
  return lines.join('\n')
}

function generatePrismaSchema(schema: Schema, enums: EnumsFile): string {
  const lines: string[] = []

  // Header
  lines.push('// Auto-generated Prisma schema from schema/schema.yaml')
  lines.push('// DO NOT EDIT DIRECTLY - Run: npm run schema:generate')
  lines.push('')

  // Generator
  if (schema.generators) {
    for (const [name, gen] of Object.entries(schema.generators)) {
      lines.push(`generator ${name} {`)
      lines.push(`  provider = "${gen.provider}"`)
      lines.push(`  output   = "${gen.output}"`)
      lines.push('}')
      lines.push('')
    }
  }

  // Datasource
  if (schema.datasource) {
    lines.push('datasource db {')
    lines.push(`  provider  = "${schema.datasource.provider}"`)
    // Parse env() format: env(DATABASE_URL) -> env("DATABASE_URL")
    const urlValue = schema.datasource.url.replace(/env\(([^)]+)\)/, 'env("$1")')
    lines.push(`  url       = ${urlValue}`)
    if (schema.datasource.directUrl) {
      const directUrlValue = schema.datasource.directUrl.replace(/env\(([^)]+)\)/, 'env("$1")')
      lines.push(`  directUrl = ${directUrlValue}`)
    }
    lines.push('}')
    lines.push('')
  }

  // Session table notice
  lines.push('// =============================================================================')
  lines.push('// IMPORTANT: Session Table (Not managed by Prisma)')
  lines.push('// =============================================================================')
  lines.push('// The `session` table is required for Express session storage (connect-pg-simple).')
  lines.push('// It is NOT a Prisma model because connect-pg-simple manages it directly.')
  lines.push('//')
  lines.push('// If you run `prisma migrate reset` or drop tables, you MUST recreate it:')
  lines.push('//')
  lines.push('//   CREATE TABLE IF NOT EXISTS session (')
  lines.push('//     sid VARCHAR NOT NULL PRIMARY KEY,')
  lines.push('//     sess JSON NOT NULL,')
  lines.push('//     expire TIMESTAMP(6) NOT NULL')
  lines.push('//   );')
  lines.push('//   CREATE INDEX IF NOT EXISTS IDX_session_expire ON session (expire);')
  lines.push('//')
  lines.push('// Or run: npm run db:ensure-session')
  lines.push('// =============================================================================')
  lines.push('')

  // Enums
  for (const [enumName, enumDef] of Object.entries(enums.enums)) {
    lines.push(generateEnumPrisma(enumName, enumDef))
    lines.push('')
  }

  // Models
  for (const [modelName, model] of Object.entries(schema.models)) {
    lines.push(generateModelPrisma(modelName, model, schema.models))
    lines.push('')
  }

  return lines.join('\n')
}

// =============================================================================
// Main
// =============================================================================

async function main() {
  console.log('🔄 Transforming YAML schema to Prisma...\n')

  try {
    // Load YAML files
    console.log('  📖 Loading schema.yaml...')
    const schema = loadYaml<Schema>('schema.yaml')

    console.log('  📖 Loading enums.yaml...')
    const enums = loadYaml<EnumsFile>('enums.yaml')

    // Generate Prisma schema
    console.log('  🔨 Generating Prisma schema...')
    const prismaSchema = generatePrismaSchema(schema, enums)

    // Write output
    console.log(`  💾 Writing to ${OUTPUT_PATH}...`)
    writeFileSync(OUTPUT_PATH, prismaSchema, 'utf-8')

    // Stats
    const modelCount = Object.keys(schema.models).length
    const enumCount = Object.keys(enums.enums).length

    console.log('\n═══════════════════════════════════════')
    console.log('✅ Prisma schema generated!')
    console.log(`   Models: ${modelCount}`)
    console.log(`   Enums: ${enumCount}`)
    console.log(`   Output: ${OUTPUT_PATH}`)
    console.log('═══════════════════════════════════════\n')
  } catch (error) {
    console.error('\n❌ Failed to generate Prisma schema:', error)
    process.exit(1)
  }
}

main().catch(console.error)
