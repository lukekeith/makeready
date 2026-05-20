# /schema - Apply Schema Changes

Run this command after making changes to the YAML schema files to generate migrations and apply them locally.

## What This Command Does

1. Validates the YAML schema syntax
2. Generates Atlas HCL from YAML
3. Generates Prisma schema from YAML
4. Creates a new migration if there are changes
5. Applies pending migrations to the local database
6. Regenerates the Prisma client

## Instructions

Execute the following steps in order:

### Step 1: Validate Schema
```bash
npm run schema:validate
```

If validation fails, fix the YAML syntax errors before proceeding.

### Step 2: Generate Schemas
```bash
npm run schema:generate
```

This generates:
- `atlas/.schema.hcl` - Atlas HCL for migrations
- `prisma/schema.prisma` - Prisma schema for ORM

### Step 3: Create Migration
```bash
npm run schema:diff
```

If there are schema changes, a new migration file will be created in `atlas/migrations/`.

**Review the generated migration** before proceeding to ensure it looks correct.

### Step 4: Apply Migration
```bash
npm run migrate:apply
```

This applies the migration to the local database.

### Step 5: Regenerate Prisma Client
```bash
npx prisma generate
```

This updates the Prisma client with the new schema.

### Step 6: Verify
```bash
npm run migrate:status
```

Should show "Migration Status: OK" with no pending files.

## Quick One-Liner (Use with Caution)

For simple changes where you trust the generated migration:

```bash
npm run schema:validate && npm run schema:generate && npm run schema:diff && npm run migrate:apply && npx prisma generate && npm run migrate:status
```

## When to Use This Command

Run `/schema` after:
- Adding new fields to a model in `schema/schema.yaml`
- Adding new models
- Adding new enums in `schema/enums.yaml`
- Modifying relations or indexes
- Any change to the YAML schema files

## Important Notes

- **Local only**: This applies migrations to your local database only
- **Review migrations**: Always check the generated SQL before applying
- **Never skip steps**: Each step depends on the previous one
- **Git commit**: Commit the migration files to version control
