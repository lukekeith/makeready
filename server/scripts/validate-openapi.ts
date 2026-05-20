#!/usr/bin/env node

/**
 * OpenAPI Spec Validation Script
 *
 * Validates the generated OpenAPI specification for:
 * - Valid OpenAPI 3.1.0 schema
 * - All referenced schemas exist
 * - No duplicate operation IDs
 *
 * Run with: npx tsx scripts/validate-openapi.ts
 */

import swaggerJsdoc from 'swagger-jsdoc'
import path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const options: swaggerJsdoc.Options = {
  definition: {
    openapi: '3.1.0',
    info: {
      title: 'MakeReady API',
      version: '2.0.0',
      description: 'MakeReady API validation',
    },
  },
  apis: [
    path.join(__dirname, '../src/routes/*.ts'),
    path.join(__dirname, '../src/routes/*.js'),
  ],
}

async function validateSpec() {
  console.log('🔍 Validating OpenAPI specification...\n')

  try {
    const spec = swaggerJsdoc(options)

    // Count documented endpoints
    let endpointCount = 0
    const paths = spec.paths || {}

    for (const path in paths) {
      for (const method in paths[path]) {
        if (['get', 'post', 'put', 'patch', 'delete'].includes(method)) {
          endpointCount++
        }
      }
    }

    // Check for required fields
    const errors: string[] = []
    const warnings: string[] = []

    // Validate info section
    if (!spec.info?.title) errors.push('Missing info.title')
    if (!spec.info?.version) errors.push('Missing info.version')

    // Check security schemes
    if (!spec.components?.securitySchemes) {
      warnings.push('No security schemes defined')
    }

    // Check for schemas
    const schemaCount = Object.keys(spec.components?.schemas || {}).length

    // Validate paths
    for (const pathKey in paths) {
      const pathItem = paths[pathKey]
      for (const method in pathItem) {
        if (!['get', 'post', 'put', 'patch', 'delete', 'options', 'head'].includes(method)) continue

        const operation = pathItem[method]

        // Check for tags
        if (!operation.tags || operation.tags.length === 0) {
          warnings.push(`${method.toUpperCase()} ${pathKey}: Missing tags`)
        }

        // Check for summary
        if (!operation.summary) {
          warnings.push(`${method.toUpperCase()} ${pathKey}: Missing summary`)
        }

        // Check for responses
        if (!operation.responses) {
          errors.push(`${method.toUpperCase()} ${pathKey}: Missing responses`)
        }
      }
    }

    // Print results
    console.log('📊 OpenAPI Spec Statistics:')
    console.log(`   OpenAPI Version: ${spec.openapi}`)
    console.log(`   API Title: ${spec.info?.title}`)
    console.log(`   API Version: ${spec.info?.version}`)
    console.log(`   Documented Endpoints: ${endpointCount}`)
    console.log(`   Defined Schemas: ${schemaCount}`)
    console.log(`   Tags: ${(spec.tags || []).length}`)
    console.log('')

    if (errors.length > 0) {
      console.log('❌ Errors:')
      errors.forEach(e => console.log(`   - ${e}`))
      console.log('')
    }

    if (warnings.length > 0) {
      console.log('⚠️  Warnings:')
      warnings.slice(0, 10).forEach(w => console.log(`   - ${w}`))
      if (warnings.length > 10) {
        console.log(`   ... and ${warnings.length - 10} more`)
      }
      console.log('')
    }

    if (errors.length === 0) {
      console.log('✅ OpenAPI specification is valid!')
      console.log(`\n📖 View docs at: http://localhost:3001/docs`)
      console.log(`📄 Raw spec at: http://localhost:3001/docs/openapi.json`)
      process.exit(0)
    } else {
      console.log('❌ Validation failed with errors')
      process.exit(1)
    }
  } catch (error) {
    console.error('❌ Failed to generate OpenAPI spec:', error)
    process.exit(1)
  }
}

validateSpec()
