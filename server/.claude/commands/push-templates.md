# /push-templates - Push Templates to Production

Push system templates from YAML files in `templates/` to the production database.

## Instructions

### Step 1: Link Railway (if not already linked)

```bash
railway link -p b69d7c6d-dedf-44f9-a416-3949f32d2870 -s f5dc2315-9c49-4c85-b32d-99418eeba49d -e 47a94190-6ea6-48fd-b9db-9973f4f5912a
```

### Step 2: Import to Production

```bash
railway run npm run templates:import
```

Review the output and confirm success.

## Template Files

| File | Template | ID |
|------|----------|----|
| `templates/soap.yaml` | SOAP | `a0000000-...-000000000001` |
| `templates/oia.yaml` | OIA | `a0000000-...-000000000002` |
| `templates/read-only.yaml` | Read Only | `a0000000-...-000000000006` |
| `templates/custom.yaml` | Custom | `a0000000-...-000000000007` |

## What the Script Does

1. Reads all `*.yaml` files from `templates/`
2. Upserts each `LessonTemplate` record (by fixed UUID)
3. Replaces all activities for each template (delete + recreate)
4. Deactivates system templates NOT in YAML files (e.g., DBS, HEAR, Video Study)
5. Prints summary of created/updated/deactivated counts
