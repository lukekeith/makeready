# Sub-Agent Strategy for MakeReady

## Overview

To prevent architecture violations and ensure compliance with `.project/ARCHITECTURE_SPEC.md`, this project uses **specialized sub-agents** for different tasks.

## Why Sub-Agents?

**Problem**: Without sub-agents, Claude may:
- Put components in wrong locations
- Violate separation of concerns
- Use incorrect patterns
- Skip Storybook stories
- Mix UI and application logic

**Solution**: Sub-agents that:
- Know the architecture specification
- Follow strict patterns
- Validate before executing
- Prevent common mistakes
- Maintain consistency

## Available Sub-Agents

### 1. `/component` - UI Component Generator
**When**: Creating any UI component
**Where**: `ui/components/[category]/`
**Ensures**:
- Proper CVA pattern
- SCSS with BEM naming
- Storybook story
- View-only (no app logic)
- Correct imports

### 2. `/page` - Page Component Generator
**When**: Creating page that connects UI to stores
**Where**: `client/src/pages/`
**Ensures**:
- Imports from `ui` and `util`
- Connects to Application store
- Passes props (never stores)
- Observer pattern
- Lifecycle hooks

### 3. `/store` - MobX Store Generator
**When**: Creating state management
**Where**: `client/src/store/domain/` or `client/src/store/ui/`
**Ensures**:
- Domain/Session/UI separation
- Proper MobX decorators
- Store responsibilities
- No mixed concerns

### 4. `/architect` - Architecture Compliance Reviewer
**When**: Reviewing code, refactoring, validating
**What**: Checks against architecture spec
**Ensures**:
- No violations
- Correct patterns
- Proper structure
- Compliant code

### 5. `/feature` - Feature Implementation Coordinator
**When**: Implementing complete features
**What**: Coordinates other sub-agents
**Ensures**:
- Correct build order
- Integration works
- End-to-end functionality

## Decision Tree

```
What are you doing?

├─ Creating a UI component
│  └─> Use /component
│
├─ Creating a page
│  └─> Use /page
│
├─ Creating a store
│  └─> Use /store
│
├─ Implementing a feature
│  └─> Use /feature
│
├─ Reviewing/refactoring
│  └─> Use /architect
│
└─ Not sure?
   └─> Use /architect review first
```

## Usage Examples

### Example 1: New Component
```
User: "Create a user card component"

Claude: Let me use the /component sub-agent...

Sub-agent:
1. Reads architecture spec
2. Creates ui/components/domain/user-card/
3. Generates component with CVA
4. Creates SCSS with BEM
5. Creates Storybook story
6. Adds to ui/index.ts
7. Validates compliance
```

### Example 2: New Feature
```
User: "Implement user management feature"

Claude: Let me use the /feature sub-agent...

Sub-agent:
1. Plans: UserCard, UserTable, UserForm components
2. Calls /component for each
3. Plans: UsersDomain, UserManagementUI stores
4. Calls /store for each
5. Calls /page for UserManagementPage
6. Integrates everything
7. Tests in Storybook
8. Validates with /architect
```

### Example 3: Architecture Review
```
User: "Review the codebase"

Claude: Let me use the /architect sub-agent...

Sub-agent:
1. Reads .project/ARCHITECTURE_SPEC.md
2. Scans all files
3. Identifies violations
4. Reports issues
5. Suggests fixes
6. Can auto-refactor if requested
```

## Benefits

### 1. Consistency
- Every component follows same pattern
- No variance in code style
- Predictable structure

### 2. Compliance
- Architecture rules enforced
- Separation of concerns maintained
- Prevents common mistakes

### 3. Speed
- Templates speed up creation
- No need to remember patterns
- Automated validation

### 4. Quality
- All components have stories
- All code follows best practices
- Type-safe throughout

### 5. Maintainability
- Easy to understand
- Easy to modify
- Easy to extend

## Integration with Claude Code

### Session Start
```markdown
Before starting work, Claude should:
1. Read .claude/CLAUDE.md
2. Understand available sub-agents
3. Use appropriate sub-agent for task
```

### During Development
```markdown
For any task:
1. Identify task type
2. Select appropriate sub-agent
3. Let sub-agent handle implementation
4. Validate result
```

### Code Review
```markdown
Before completing:
1. Run /architect validate
2. Fix any violations
3. Verify in Storybook
4. Confirm compliance
```

## Sub-Agent Files

All sub-agent instructions are in:
```
.claude/
├── CLAUDE.md              # Main instructions
└── commands/
    ├── component.md       # /component sub-agent
    ├── page.md           # /page sub-agent
    ├── store.md          # /store sub-agent
    ├── architect.md      # /architect sub-agent
    └── feature.md        # /feature sub-agent
```

## Critical Rules

These rules MUST be followed by all sub-agents:

### 1. Component Location
- ✅ MUST: `ui/components/[category]/`
- ❌ NEVER: `client/src/components/`

### 2. Component Imports
- ✅ MUST: Import from `util/` only
- ❌ NEVER: Import from `client/` or `@/`

### 3. Store Separation
- ✅ Domain = API + data
- ✅ Session = Auth + session
- ✅ UI = Props + UI state
- ❌ NEVER mix responsibilities

### 4. Page Imports
- ✅ MUST: Import from `ui` and `util` barrels
- ❌ NEVER: Direct component imports

### 5. Storybook
- ✅ MUST: Every component has story
- ❌ NEVER: Skip story creation

## Validation

After using any sub-agent:
```bash
# Test in Storybook
npm run storybook

# TypeScript check
npm run build:client

# Lint check
npm run lint
```

## Troubleshooting

### "Claude didn't use sub-agent"
**Solution**: Remind Claude to read `.claude/CLAUDE.md`

### "Architecture violation occurred"
**Solution**: Run `/architect review` and fix violations

### "Not sure which sub-agent to use"
**Solution**: Use `/architect` first to understand task

### "Sub-agent created wrong pattern"
**Solution**: Check sub-agent instructions match architecture spec

## Maintenance

### Adding New Sub-Agent
1. Create `.claude/commands/[name].md`
2. Define responsibilities
3. Add to CLAUDE.md
4. Update this document

### Updating Sub-Agent
1. Update command file
2. Update CLAUDE.md if needed
3. Test with example
4. Document changes

## Success Metrics

Sub-agent strategy is working when:
- ✅ No architecture violations
- ✅ All components in correct locations
- ✅ All stores follow patterns
- ✅ All pages import correctly
- ✅ Storybook has all stories
- ✅ Code is maintainable
- ✅ New developers can follow patterns

## Related Documentation

- `.project/ARCHITECTURE_SPEC.md` - Complete architecture
- `.claude/CLAUDE.md` - Main Claude instructions
- `ARCHITECTURE_COMPLIANCE.md` - Current compliance status
- Individual command files in `.claude/commands/`

---

**Remember**: Always use the appropriate sub-agent. They exist to protect the architecture!
