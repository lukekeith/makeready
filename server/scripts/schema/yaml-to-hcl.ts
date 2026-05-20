/**
 * YAML to Atlas HCL Transformer
 *
 * Converts the YAML schema definition to Atlas HCL format for migration generation.
 * The generated HCL file is placed at atlas/.schema.hcl
 */

import { readFileSync, writeFileSync, existsSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'
import * as yaml from 'yaml'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)
const SCHEMA_DIR = resolve(__dirname, '../../schema')
const OUTPUT_PATH = resolve(__dirname, '../../atlas/.schema.hcl')

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

interface Schema {
  version: string
  database: string
  models: Record<string, Model>
}

interface EnumsFile {
  version: string
  enums: Record<string, EnumDefinition>
}

interface Extension {
  name: string
  description?: string
  schema?: string
}

interface ExtensionsFile {
  version: string
  extensions: Extension[]
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

// Map of FK fields: model.fieldName -> target referenced field type
type ForeignKeyFieldMap = Map<string, string>

function buildForeignKeyFieldMap(models: Record<string, Model>): ForeignKeyFieldMap {
  const fkFields = new Map<string, string>()

  for (const [modelName, model] of Object.entries(models)) {
    if (!model.relations) continue

    for (const [relName, relation] of Object.entries(model.relations)) {
      // Only process many_to_one relations that have FK fields
      if (relation.type !== 'many_to_one' || !relation.fields || !relation.references) {
        continue
      }

      const targetModel = models[relation.target]
      if (!targetModel) continue

      // For each FK field, get the type of the referenced field
      for (let i = 0; i < relation.fields.length; i++) {
        const fkFieldName = relation.fields[i]
        const refFieldName = relation.references[i]
        const refField = targetModel.fields[refFieldName]

        if (refField) {
          // Store as "modelName.fieldName" -> referenced field type
          fkFields.set(`${modelName}.${fkFieldName}`, refField.type)
        }
      }
    }
  }

  return fkFields
}

function mapFieldTypeToHcl(
  field: Field,
  fieldName: string,
  modelName?: string,
  fkFields?: ForeignKeyFieldMap
): string {
  // Check if this field is an FK that should use the referenced column's type
  if (modelName && fkFields) {
    const fkType = fkFields.get(`${modelName}.${fieldName}`)
    if (fkType === 'uuid') {
      return 'uuid'
    }
  }

  const { type, precision, scale, db_type } = field

  switch (type) {
    case 'uuid':
      return 'uuid'
    case 'string':
      return 'varchar'
    case 'text':
      return 'text'
    case 'int':
      return 'integer'
    case 'float':
      return 'sql("double precision")'
    case 'boolean':
      return 'boolean'
    case 'datetime':
      return 'timestamp'
    case 'json':
      return 'jsonb'
    case 'decimal':
      if (precision && scale) {
        return `sql("decimal(${precision},${scale})")`
      }
      return 'decimal'
    case 'enum':
      // Enums use the enum.EnumName reference in Atlas HCL
      const enumName = field.enum || fieldName
      return `enum.${enumName}`
    case 'unsupported':
      // Wrap in sql() if contains special characters like parentheses
      const dbType = db_type || 'text'
      if (dbType.includes('(') || dbType.includes(' ')) {
        return `sql("${dbType}")`
      }
      return dbType
    case 'string_array':
      return 'sql("text[]")'
    default:
      return 'text'
  }
}

function mapDefaultToHcl(field: Field): string | null {
  const { default: defaultValue, type } = field

  if (defaultValue === undefined) return null

  // Handle special defaults
  if (typeof defaultValue === 'string') {
    if (defaultValue === 'now()') {
      return 'sql("now()")'
    }
    if (defaultValue === 'uuid()') {
      return 'sql("gen_random_uuid()")'
    }
    if (defaultValue === 'uuid_generate_v4()') {
      return 'sql("uuid_generate_v4()")'
    }
    if (defaultValue.startsWith('env(')) {
      return null // Environment variables not supported in HCL schema
    }
    // String literals
    return `"${defaultValue}"`
  }

  if (typeof defaultValue === 'boolean') {
    return defaultValue ? 'true' : 'false'
  }

  if (typeof defaultValue === 'number') {
    return String(defaultValue)
  }

  return null
}

// =============================================================================
// HCL Generation
// =============================================================================

function generateEnumHcl(name: string, enumDef: EnumDefinition): string {
  const values = enumDef.values.map(v => `"${v}"`).join(', ')
  return `enum "${name}" {
  schema = schema.public
  values = [${values}]
}`
}

function generateColumnHcl(
  fieldName: string,
  field: Field,
  isPrimary: boolean,
  tableName: string,
  modelName?: string,
  fkFields?: ForeignKeyFieldMap
): string {
  const lines: string[] = []
  const hclType = mapFieldTypeToHcl(field, fieldName, modelName, fkFields)

  lines.push(`  column "${fieldName}" {`)
  lines.push(`    type = ${hclType}`)

  // Nullable
  if (!isPrimary && field.nullable !== false && !field.primary) {
    if (field.nullable === true) {
      lines.push(`    null = true`)
    }
  }

  // Default value
  const defaultHcl = mapDefaultToHcl(field)
  if (defaultHcl) {
    lines.push(`    default = ${defaultHcl}`)
  }

  // Comment for deprecated fields
  if (field.deprecated) {
    lines.push(`    comment = "DEPRECATED: ${field.deprecation_note || 'This field is deprecated'}"`)
  } else if (field.description) {
    lines.push(`    comment = "${field.description.replace(/"/g, '\\"')}"`)
  }

  lines.push(`  }`)
  return lines.join('\n')
}

function generateIndexHcl(tableName: string, index: Index, indexNum: number): string {
  const indexName = index.name || `idx_${tableName}_${index.fields.join('_')}`
  const columns = index.fields.map(f => `column.${f}`).join(', ')

  if (index.unique) {
    return `  index "${indexName}" {
    unique  = true
    columns = [${columns}]
  }`
  }

  return `  index "${indexName}" {
    columns = [${columns}]
  }`
}

function generateUniqueConstraintHcl(tableName: string, unique: UniqueConstraint): string {
  const constraintName = unique.name || `${tableName}_${unique.fields.join('_')}_key`
  const columns = unique.fields.map(f => `column.${f}`).join(', ')

  return `  unique "${constraintName}" {
    columns = [${columns}]
  }`
}

function generateForeignKeyHcl(
  tableName: string,
  relName: string,
  relation: Relation,
  models: Record<string, Model>
): string | null {
  // Only generate FK for many_to_one relations
  if (relation.type !== 'many_to_one' || !relation.fields || !relation.references) {
    return null
  }

  const targetModel = models[relation.target]
  if (!targetModel) return null

  const fkName = `fk_${tableName}_${relName}`
  const columns = relation.fields.map(f => `column.${f}`).join(', ')
  const refColumns = relation.references.map(f => `column.${f}`).join(', ')

  // Map onDelete to Atlas HCL format (e.g., SetNull -> SET_NULL, Cascade -> CASCADE)
  const onDeleteMap: Record<string, string> = {
    'Cascade': 'CASCADE',
    'SetNull': 'SET_NULL',
    'NoAction': 'NO_ACTION',
    'Restrict': 'RESTRICT',
  }
  const onDelete = onDeleteMap[relation.onDelete || 'NoAction'] || 'NO_ACTION'

  return `  foreign_key "${fkName}" {
    columns     = [${columns}]
    ref_columns = [table.${targetModel.table_name}.${refColumns}]
    on_delete   = ${onDelete}
  }`
}

function generateTableHcl(
  modelName: string,
  model: Model,
  models: Record<string, Model>,
  fkFields: ForeignKeyFieldMap
): string {
  const lines: string[] = []
  const tableName = model.table_name

  lines.push(`table "${tableName}" {`)
  lines.push(`  schema = schema.public`)

  // Add soft_delete field if enabled
  const fields = { ...model.fields }
  if (model.soft_delete && !fields.deleted_at) {
    fields.deleted_at = {
      type: 'datetime',
      nullable: true,
      description: 'Soft delete timestamp',
    }
  }

  // Find primary key
  let primaryKeyField: string | null = null
  for (const [fieldName, field] of Object.entries(fields)) {
    if (field.primary) {
      primaryKeyField = fieldName
    }
  }

  // Generate columns
  for (const [fieldName, field] of Object.entries(fields)) {
    lines.push(generateColumnHcl(fieldName, field, field.primary || false, tableName, modelName, fkFields))
  }

  // Primary key
  if (primaryKeyField) {
    lines.push(`  primary_key {`)
    lines.push(`    columns = [column.${primaryKeyField}]`)
    lines.push(`  }`)
  }

  // Foreign keys
  if (model.relations) {
    for (const [relName, relation] of Object.entries(model.relations)) {
      const fkHcl = generateForeignKeyHcl(tableName, relName, relation, models)
      if (fkHcl) {
        lines.push(fkHcl)
      }
    }
  }

  // Unique constraints
  if (model.unique) {
    for (const unique of model.unique) {
      lines.push(generateUniqueConstraintHcl(tableName, unique))
    }
  }

  // Single-field unique constraints from field definitions
  for (const [fieldName, field] of Object.entries(fields)) {
    if (field.unique && !field.primary) {
      lines.push(`  unique "${tableName}_${fieldName}_key" {`)
      lines.push(`    columns = [column.${fieldName}]`)
      lines.push(`  }`)
    }
  }

  // Indexes
  if (model.indexes) {
    let indexNum = 0
    for (const index of model.indexes) {
      lines.push(generateIndexHcl(tableName, index, indexNum++))
    }
  }

  // Soft delete partial indexes
  if (model.soft_delete) {
    lines.push(`  index "idx_${tableName}_active" {`)
    lines.push(`    columns = [column.deleted_at]`)
    lines.push(`    where   = "deleted_at IS NULL"`)
    lines.push(`  }`)
  }

  lines.push(`}`)
  return lines.join('\n')
}

function generateSchemaHcl(
  schema: Schema,
  enums: EnumsFile,
  extensions: ExtensionsFile
): string {
  const lines: string[] = []

  // Build FK field map to ensure FK columns use correct types
  const fkFields = buildForeignKeyFieldMap(schema.models)

  // Header
  lines.push('// Auto-generated Atlas HCL schema from schema/schema.yaml')
  lines.push('// DO NOT EDIT DIRECTLY - Run: npm run schema:generate')
  lines.push('')

  // Schema definition
  lines.push('schema "public" {')
  lines.push('}')
  lines.push('')

  // Extensions - Note: Atlas free tier doesn't support extension management
  // Extensions are installed separately (uuid-ossp, vector, etc.)
  // They are listed here as comments for documentation
  if (extensions.extensions.length > 0) {
    lines.push('// Required extensions (install manually):')
    for (const ext of extensions.extensions) {
      lines.push(`// - ${ext.name}${ext.description ? `: ${ext.description}` : ''}`)
    }
    lines.push('')
  }

  // Enums
  for (const [enumName, enumDef] of Object.entries(enums.enums)) {
    lines.push(generateEnumHcl(enumName, enumDef))
    lines.push('')
  }

  // Tables
  for (const [modelName, model] of Object.entries(schema.models)) {
    lines.push(generateTableHcl(modelName, model, schema.models, fkFields))
    lines.push('')
  }

  // Session table (not managed by Prisma)
  lines.push(`// Session table for connect-pg-simple (not managed by Prisma)`)
  lines.push(`table "session" {`)
  lines.push(`  schema = schema.public`)
  lines.push(`  column "sid" {`)
  lines.push(`    type = varchar`)
  lines.push(`  }`)
  lines.push(`  column "sess" {`)
  lines.push(`    type = jsonb`)
  lines.push(`  }`)
  lines.push(`  column "expire" {`)
  lines.push(`    type = sql("timestamp(6)")`)
  lines.push(`  }`)
  lines.push(`  primary_key {`)
  lines.push(`    columns = [column.sid]`)
  lines.push(`  }`)
  lines.push(`  index "idx_session_expire" {`)
  lines.push(`    columns = [column.expire]`)
  lines.push(`  }`)
  lines.push(`}`)
  lines.push('')

  // Seed versions tracking table
  lines.push(`// Seed version tracking table`)
  lines.push(`table "_seed_versions" {`)
  lines.push(`  schema = schema.public`)
  lines.push(`  column "version" {`)
  lines.push(`    type = varchar`)
  lines.push(`  }`)
  lines.push(`  column "applied_at" {`)
  lines.push(`    type    = timestamp`)
  lines.push(`    default = sql("now()")`)
  lines.push(`  }`)
  lines.push(`  column "checksum" {`)
  lines.push(`    type = varchar`)
  lines.push(`    null = true`)
  lines.push(`  }`)
  lines.push(`  primary_key {`)
  lines.push(`    columns = [column.version]`)
  lines.push(`  }`)
  lines.push(`}`)

  return lines.join('\n')
}

// =============================================================================
// Main
// =============================================================================

async function main() {
  console.log('🔄 Transforming YAML schema to Atlas HCL...\n')

  try {
    // Load YAML files
    console.log('  📖 Loading schema.yaml...')
    const schema = loadYaml<Schema>('schema.yaml')

    console.log('  📖 Loading enums.yaml...')
    const enums = loadYaml<EnumsFile>('enums.yaml')

    console.log('  📖 Loading extensions.yaml...')
    const extensions = loadYaml<ExtensionsFile>('extensions.yaml')

    // Generate HCL
    console.log('  🔨 Generating HCL...')
    const hcl = generateSchemaHcl(schema, enums, extensions)

    // Write output
    console.log(`  💾 Writing to ${OUTPUT_PATH}...`)
    writeFileSync(OUTPUT_PATH, hcl, 'utf-8')

    // Stats
    const modelCount = Object.keys(schema.models).length
    const enumCount = Object.keys(enums.enums).length
    const extensionCount = extensions.extensions.length

    console.log('\n═══════════════════════════════════════')
    console.log('✅ Atlas HCL schema generated!')
    console.log(`   Models: ${modelCount}`)
    console.log(`   Enums: ${enumCount}`)
    console.log(`   Extensions: ${extensionCount}`)
    console.log(`   Output: ${OUTPUT_PATH}`)
    console.log('═══════════════════════════════════════\n')
  } catch (error) {
    console.error('\n❌ Failed to generate HCL:', error)
    process.exit(1)
  }
}

main().catch(console.error)
