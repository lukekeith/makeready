/**
 * Versioned Seed Runner
 *
 * Runs seed files based on the manifest.yaml configuration.
 * Supports:
 * - Version tracking (only runs new versions)
 * - Override capabilities (v2.0.0 can override v1.0.0 files)
 * - Environment-specific seeds (dev-only data)
 * - Multiple strategies: upsert, merge, replace, append, sync
 */

import { readFileSync, existsSync } from 'fs'
import { createHash } from 'crypto'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'
import * as yaml from 'yaml'
import { PrismaClient } from '../../src/generated/prisma/index.js'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)
const SEEDS_DIR = resolve(__dirname, '../../seeds')

const prisma = new PrismaClient()

// =============================================================================
// Types
// =============================================================================

interface ManifestVersion {
  version: string
  description: string
  files: string[]
  overrides?: string
}

interface Manifest {
  versions: ManifestVersion[]
  current: string
  environments: Record<string, string[]>
}

interface SeedFile {
  version: string
  model: string
  strategy: 'upsert' | 'merge' | 'replace' | 'append' | 'sync'
  upsert_key?: string | string[]
  merge_key?: string
  data?: Record<string, unknown>[]
  updates?: { match: Record<string, unknown>; set: Record<string, unknown> }[]
  deletions?: { match: Record<string, unknown> }[]
  role_mappings?: Record<string, { permissions: string[] | 'ALL' }>
}

interface SeedVersion {
  version: string
  applied_at: Date
  checksum: string
}

// =============================================================================
// Helpers
// =============================================================================

function loadYaml<T>(filePath: string): T {
  if (!existsSync(filePath)) {
    throw new Error(`File not found: ${filePath}`)
  }
  const content = readFileSync(filePath, 'utf-8')
  return yaml.parse(content) as T
}

function computeChecksum(content: string): string {
  return createHash('sha256').update(content).digest('hex').substring(0, 16)
}

async function ensureSeedVersionsTable() {
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "_seed_versions" (
      version VARCHAR PRIMARY KEY,
      applied_at TIMESTAMP DEFAULT NOW(),
      checksum VARCHAR
    )
  `)
}

async function getAppliedVersions(): Promise<Map<string, SeedVersion>> {
  const versions = await prisma.$queryRawUnsafe<SeedVersion[]>(`
    SELECT version, applied_at, checksum FROM "_seed_versions"
  `)
  return new Map(versions.map(v => [v.version, v]))
}

async function markVersionApplied(version: string, checksum: string) {
  await prisma.$executeRawUnsafe(`
    INSERT INTO "_seed_versions" (version, checksum)
    VALUES ($1, $2)
    ON CONFLICT (version) DO UPDATE SET checksum = $2, applied_at = NOW()
  `, version, checksum)
}

// =============================================================================
// Seed Execution
// =============================================================================

async function runPermissionsSeed(seedData: SeedFile) {
  console.log(`    📋 Seeding ${seedData.data?.length || 0} permissions...`)

  if (!seedData.data) return

  for (const perm of seedData.data) {
    await prisma.permission.upsert({
      where: { name: perm.name as string },
      update: {
        resource: perm.resource as string,
        action: perm.action as string,
        description: perm.description as string | undefined,
      },
      create: {
        resource: perm.resource as string,
        action: perm.action as string,
        name: perm.name as string,
        description: perm.description as string | undefined,
      },
    })
  }
}

async function runRolesSeed(seedData: SeedFile) {
  console.log(`    👥 Seeding ${seedData.data?.length || 0} roles...`)

  if (!seedData.data) return

  for (const roleData of seedData.data) {
    const existingRole = await prisma.role.findFirst({
      where: {
        name: roleData.name as string,
        organizationId: null,
      },
    })

    if (existingRole) {
      await prisma.role.update({
        where: { id: existingRole.id },
        data: {
          description: roleData.description as string | undefined,
          isSystem: roleData.isSystem as boolean,
        },
      })
    } else {
      await prisma.role.create({
        data: {
          name: roleData.name as string,
          description: roleData.description as string | undefined,
          isSystem: roleData.isSystem as boolean,
          organizationId: null,
        },
      })
    }
  }
}

async function runRolePermissionsSeed(seedData: SeedFile) {
  if (!seedData.role_mappings) return

  // Get all permissions
  const allPermissions = await prisma.permission.findMany()
  const permissionMap = new Map(allPermissions.map(p => [p.name, p.id]))

  // Get all system roles
  const systemRoles = await prisma.role.findMany({
    where: { organizationId: null, isSystem: true },
  })
  const roleMap = new Map(systemRoles.map(r => [r.name, r.id]))

  for (const [roleName, config] of Object.entries(seedData.role_mappings)) {
    const roleId = roleMap.get(roleName)
    if (!roleId) {
      console.warn(`      ⚠️ Role not found: ${roleName}`)
      continue
    }

    // Clear existing role permissions for sync strategy
    await prisma.rolePermission.deleteMany({
      where: { roleId },
    })

    // Determine which permissions to assign
    let permissionNames: string[]
    if (config.permissions === 'ALL') {
      permissionNames = Array.from(permissionMap.keys())
      console.log(`    ⚡ ${roleName}: ALL (${permissionNames.length} permissions)`)
    } else {
      permissionNames = config.permissions
      console.log(`    🔐 ${roleName}: ${permissionNames.length} permissions`)
    }

    // Create role-permission mappings
    for (const permName of permissionNames) {
      const permId = permissionMap.get(permName)
      if (!permId) {
        console.warn(`      ⚠️ Permission not found: ${permName}`)
        continue
      }

      await prisma.rolePermission.create({
        data: {
          roleId,
          permissionId: permId,
        },
      })
    }
  }
}

function prismaDelegateName(modelName: string): string {
  return modelName.charAt(0).toLowerCase() + modelName.slice(1)
}

async function runGenericSeed(seedData: SeedFile) {
  const model = prismaDelegateName(seedData.model)

  if (!seedData.data) return

  console.log(`    📋 Seeding ${seedData.data.length} ${seedData.model} records...`)

  // Get the Prisma model
  const prismaModel = (prisma as Record<string, unknown>)[model] as {
    upsert: (args: unknown) => Promise<unknown>
    create: (args: unknown) => Promise<unknown>
    deleteMany: (args: unknown) => Promise<unknown>
    findFirst: (args: unknown) => Promise<unknown>
    update: (args: unknown) => Promise<unknown>
  }

  if (!prismaModel) {
    throw new Error(`Model ${seedData.model} not found in Prisma client`)
  }

  for (const deletion of seedData.deletions || []) {
    await prismaModel.deleteMany({ where: deletion.match })
  }

  for (const record of seedData.data) {
    if (seedData.strategy === 'upsert' && seedData.upsert_key) {
      const keys = Array.isArray(seedData.upsert_key)
        ? seedData.upsert_key
        : [seedData.upsert_key]

      const keyValues: Record<string, unknown> = {}
      for (const key of keys) {
        keyValues[key] = record[key]
      }

      const where = keys.length === 1
        ? keyValues
        : { [keys.join('_')]: keyValues }

      await prismaModel.upsert({
        where,
        update: record,
        create: record,
      })
    } else {
      await prismaModel.create({ data: record })
    }
  }
}

async function runSeedFile(filePath: string) {
  const seedData = loadYaml<SeedFile>(filePath)

  if (!seedData.model) {
    console.log('    ↷ No model defined, skipping placeholder seed')
    return
  }

  switch (seedData.model) {
    case 'Permission':
      await runPermissionsSeed(seedData)
      break
    case 'Role':
      await runRolesSeed(seedData)
      break
    case 'RolePermission':
      await runRolePermissionsSeed(seedData)
      break
    default:
      await runGenericSeed(seedData)
  }
}

async function migrateOrganizationOwners() {
  console.log('\n  📦 Migrating organization owners to UserRole...')

  const organizations = await prisma.organization.findMany()
  const ownerRole = await prisma.role.findFirst({
    where: { name: 'Owner', organizationId: null },
  })

  if (!ownerRole) {
    console.log('    ❌ Owner role not found, skipping migration')
    return
  }

  let migratedCount = 0
  for (const org of organizations) {
    const existing = await prisma.userRole.findUnique({
      where: {
        userId_roleId_organizationId: {
          userId: org.ownerId,
          roleId: ownerRole.id,
          organizationId: org.id,
        },
      },
    })

    if (existing) {
      continue
    }

    await prisma.userRole.create({
      data: {
        userId: org.ownerId,
        roleId: ownerRole.id,
        organizationId: org.id,
        assignedBy: org.ownerId,
      },
    })
    migratedCount++
  }

  console.log(`    ✓ Migrated ${migratedCount} organization owners`)
}

// =============================================================================
// Main
// =============================================================================

async function main() {
  const args = process.argv.slice(2)
  const envArg = args.find(a => a.startsWith('--env='))
  const env = envArg?.split('=')[1] || process.env.NODE_ENV || 'development'
  const forceArg = args.includes('--force')

  console.log('🌱 Starting versioned seed runner...\n')
  console.log(`  Environment: ${env}`)
  console.log(`  Force mode: ${forceArg}\n`)

  try {
    // Ensure tracking table exists
    await ensureSeedVersionsTable()

    // Load manifest
    const manifest = loadYaml<Manifest>(resolve(SEEDS_DIR, 'manifest.yaml'))
    console.log(`  Current version: ${manifest.current}`)

    // Get applied versions
    const appliedVersions = await getAppliedVersions()
    console.log(`  Applied versions: ${appliedVersions.size}\n`)

    // Run versioned seeds
    console.log('📋 Running versioned seeds...')
    for (const versionConfig of manifest.versions) {
      const applied = appliedVersions.get(versionConfig.version)

      // Calculate checksum for this version
      const versionDir = resolve(SEEDS_DIR, `v${versionConfig.version}`)
      const contents = versionConfig.files
        .map(f => readFileSync(resolve(versionDir, f), 'utf-8'))
        .join('\n')
      const checksum = computeChecksum(contents)

      // Check if we need to run this version
      if (applied && applied.checksum === checksum && !forceArg) {
        console.log(`  ↷ v${versionConfig.version}: Already applied (checksum match)`)
        continue
      }

      console.log(`\n  📦 v${versionConfig.version}: ${versionConfig.description}`)

      // Run each file in this version
      for (const file of versionConfig.files) {
        const filePath = resolve(versionDir, file)
        console.log(`    📄 ${file}`)
        await runSeedFile(filePath)
      }

      // Mark version as applied
      await markVersionApplied(versionConfig.version, checksum)
    }

    // Run organization owner migration (part of RBAC setup)
    await migrateOrganizationOwners()

    // Run environment-specific seeds
    const envSeeds = manifest.environments[env] || []
    if (envSeeds.length > 0) {
      console.log(`\n📋 Running ${env} environment seeds...`)
      for (const seedPath of envSeeds) {
        const filePath = resolve(SEEDS_DIR, seedPath)
        if (existsSync(filePath)) {
          console.log(`  📄 ${seedPath}`)
          await runSeedFile(filePath)
        }
      }
    }

    // Summary
    console.log('\n═══════════════════════════════════════')
    console.log('✅ Seed runner complete!')
    console.log('═══════════════════════════════════════\n')
  } catch (error) {
    console.error('\n❌ Seed runner failed:', error)
    process.exit(1)
  } finally {
    await prisma.$disconnect()
  }
}

main().catch(console.error)
