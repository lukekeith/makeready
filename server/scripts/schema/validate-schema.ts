/**
 * Schema Validation Script
 *
 * Validates the YAML schema files against a Zod schema definition.
 * Ensures consistency and catches errors before transformation.
 */

import { readFileSync, existsSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'
import { z } from 'zod'
import * as yaml from 'yaml'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)
const SCHEMA_DIR = resolve(__dirname, '../../schema')

// =============================================================================
// Zod Schemas for Validation
// =============================================================================

const FieldTypeSchema = z.enum([
  'uuid',
  'string',
  'text',
  'int',
  'float',
  'boolean',
  'datetime',
  'json',
  'decimal',
  'enum',
  'unsupported',
  'string_array',
])

const FieldSchema = z.object({
  type: FieldTypeSchema,
  primary: z.boolean().optional(),
  unique: z.boolean().optional(),
  nullable: z.boolean().optional(),
  default: z.union([z.string(), z.number(), z.boolean()]).optional(),
  updatedAt: z.boolean().optional(),
  description: z.string().optional(),
  deprecated: z.boolean().optional(),
  deprecation_note: z.string().optional(),
  enum: z.string().optional(),
  db_type: z.string().optional(),
  precision: z.number().optional(),
  scale: z.number().optional(),
})

const RelationTypeSchema = z.enum([
  'one_to_one',
  'one_to_many',
  'many_to_one',
  'many_to_many',
])

const OnDeleteSchema = z.enum(['Cascade', 'SetNull', 'Restrict', 'NoAction']).optional()

const RelationSchema = z.object({
  type: RelationTypeSchema,
  target: z.string(),
  fields: z.array(z.string()).optional(),
  references: z.array(z.string()).optional(),
  name: z.string().optional(),
  onDelete: OnDeleteSchema,
  nullable: z.boolean().optional(),
})

const IndexSchema = z.object({
  fields: z.array(z.string()),
  unique: z.boolean().optional(),
  name: z.string().optional(),
})

const UniqueSchema = z.object({
  fields: z.array(z.string()),
  name: z.string().optional(),
})

const ModelSchema = z.object({
  table_name: z.string(),
  soft_delete: z.boolean().optional(),
  fields: z.record(z.string(), FieldSchema),
  relations: z.record(z.string(), RelationSchema).optional(),
  indexes: z.array(IndexSchema).optional(),
  unique: z.array(UniqueSchema).optional(),
})

const EnumDefinitionSchema = z.object({
  values: z.array(z.string()),
})

const EnumsFileSchema = z.object({
  version: z.string(),
  enums: z.record(z.string(), EnumDefinitionSchema),
})

const ExtensionSchema = z.object({
  name: z.string(),
  description: z.string().optional(),
  schema: z.string().optional(),
})

const ExtensionsFileSchema = z.object({
  version: z.string(),
  extensions: z.array(ExtensionSchema),
})

const GeneratorSchema = z.object({
  provider: z.string(),
  output: z.string(),
})

const DatasourceSchema = z.object({
  provider: z.string(),
  url: z.string(),
  directUrl: z.string().optional(),
})

const MainSchemaFileSchema = z.object({
  version: z.string(),
  database: z.string(),
  imports: z.array(z.string()).optional(),
  generators: z.record(z.string(), GeneratorSchema).optional(),
  datasource: DatasourceSchema.optional(),
  models: z.record(z.string(), ModelSchema),
})

// =============================================================================
// YAML Parser with Import Support
// =============================================================================

function loadYamlFile(filePath: string): unknown {
  if (!existsSync(filePath)) {
    throw new Error(`File not found: ${filePath}`)
  }
  const content = readFileSync(filePath, 'utf-8')
  return yaml.parse(content)
}

// =============================================================================
// Validation Functions
// =============================================================================

function validateEnumsFile(): { valid: boolean; errors: string[] } {
  const errors: string[] = []
  const filePath = resolve(SCHEMA_DIR, 'enums.yaml')

  try {
    const data = loadYamlFile(filePath)
    EnumsFileSchema.parse(data)
    console.log('  ✓ enums.yaml is valid')
  } catch (error) {
    if (error instanceof z.ZodError) {
      errors.push(...error.errors.map(e => `enums.yaml: ${e.path.join('.')} - ${e.message}`))
    } else {
      errors.push(`enums.yaml: ${error}`)
    }
  }

  return { valid: errors.length === 0, errors }
}

function validateExtensionsFile(): { valid: boolean; errors: string[] } {
  const errors: string[] = []
  const filePath = resolve(SCHEMA_DIR, 'extensions.yaml')

  try {
    const data = loadYamlFile(filePath)
    ExtensionsFileSchema.parse(data)
    console.log('  ✓ extensions.yaml is valid')
  } catch (error) {
    if (error instanceof z.ZodError) {
      errors.push(...error.errors.map(e => `extensions.yaml: ${e.path.join('.')} - ${e.message}`))
    } else {
      errors.push(`extensions.yaml: ${error}`)
    }
  }

  return { valid: errors.length === 0, errors }
}

function validateMainSchema(): { valid: boolean; errors: string[] } {
  const errors: string[] = []
  const filePath = resolve(SCHEMA_DIR, 'schema.yaml')

  try {
    const data = loadYamlFile(filePath)
    MainSchemaFileSchema.parse(data)
    console.log('  ✓ schema.yaml structure is valid')

    // Additional semantic validations
    const schema = data as z.infer<typeof MainSchemaFileSchema>
    const modelNames = Object.keys(schema.models)

    // Check relation targets exist
    for (const [modelName, model] of Object.entries(schema.models)) {
      if (model.relations) {
        for (const [relName, relation] of Object.entries(model.relations)) {
          if (!modelNames.includes(relation.target)) {
            errors.push(
              `schema.yaml: ${modelName}.${relName} references non-existent model "${relation.target}"`
            )
          }

          // Check that many_to_one relations have fields/references
          if (relation.type === 'many_to_one' && !relation.fields) {
            errors.push(
              `schema.yaml: ${modelName}.${relName} (many_to_one) must define "fields" and "references"`
            )
          }
        }
      }

      // Check that indexed fields exist
      if (model.indexes) {
        for (const index of model.indexes) {
          for (const field of index.fields) {
            if (!model.fields[field]) {
              errors.push(
                `schema.yaml: ${modelName} index references non-existent field "${field}"`
              )
            }
          }
        }
      }

      // Check that unique constraint fields exist
      if (model.unique) {
        for (const unique of model.unique) {
          for (const field of unique.fields) {
            if (!model.fields[field]) {
              errors.push(
                `schema.yaml: ${modelName} unique constraint references non-existent field "${field}"`
              )
            }
          }
        }
      }
    }

    if (errors.length === 0) {
      console.log('  ✓ schema.yaml relations are valid')
      console.log('  ✓ schema.yaml indexes are valid')
      console.log('  ✓ schema.yaml unique constraints are valid')
    }
  } catch (error) {
    if (error instanceof z.ZodError) {
      errors.push(...error.errors.map(e => `schema.yaml: ${e.path.join('.')} - ${e.message}`))
    } else {
      errors.push(`schema.yaml: ${error}`)
    }
  }

  return { valid: errors.length === 0, errors }
}

function validateEnumReferences(): { valid: boolean; errors: string[] } {
  const errors: string[] = []

  try {
    const enumsData = loadYamlFile(resolve(SCHEMA_DIR, 'enums.yaml')) as z.infer<typeof EnumsFileSchema>
    const schemaData = loadYamlFile(resolve(SCHEMA_DIR, 'schema.yaml')) as z.infer<typeof MainSchemaFileSchema>

    const enumNames = Object.keys(enumsData.enums)

    for (const [modelName, model] of Object.entries(schemaData.models)) {
      for (const [fieldName, field] of Object.entries(model.fields)) {
        if (field.type === 'enum' && field.enum) {
          if (!enumNames.includes(field.enum)) {
            errors.push(
              `schema.yaml: ${modelName}.${fieldName} references non-existent enum "${field.enum}"`
            )
          }
        }
      }
    }

    if (errors.length === 0) {
      console.log('  ✓ All enum references are valid')
    }
  } catch (error) {
    errors.push(`Enum reference validation failed: ${error}`)
  }

  return { valid: errors.length === 0, errors }
}

// =============================================================================
// Main
// =============================================================================

async function main() {
  console.log('🔍 Validating schema files...\n')

  const allErrors: string[] = []

  // Validate enums.yaml
  console.log('📋 Validating enums.yaml...')
  const enumResult = validateEnumsFile()
  allErrors.push(...enumResult.errors)

  // Validate extensions.yaml
  console.log('\n📋 Validating extensions.yaml...')
  const extResult = validateExtensionsFile()
  allErrors.push(...extResult.errors)

  // Validate schema.yaml
  console.log('\n📋 Validating schema.yaml...')
  const schemaResult = validateMainSchema()
  allErrors.push(...schemaResult.errors)

  // Cross-file validation: enum references
  console.log('\n🔗 Validating cross-file references...')
  const enumRefResult = validateEnumReferences()
  allErrors.push(...enumRefResult.errors)

  // Summary
  console.log('\n═══════════════════════════════════════')
  if (allErrors.length === 0) {
    console.log('✅ All schema files are valid!')
    console.log('═══════════════════════════════════════\n')
    process.exit(0)
  } else {
    console.log('❌ Schema validation failed!\n')
    console.log('Errors:')
    for (const error of allErrors) {
      console.log(`  • ${error}`)
    }
    console.log('\n═══════════════════════════════════════\n')
    process.exit(1)
  }
}

main().catch(console.error)
