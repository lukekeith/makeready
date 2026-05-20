# Claude Code Instructions

This folder contains instructions for Claude Code to ensure architecture compliance.

## Files

### `CLAUDE.md`
**Main instructions file** - READ THIS FIRST

Contains:
- Architecture overview
- Sub-agent strategy
- Critical rules
- Quick reference
- Decision flow

**Claude should read this at the start of every session.**

### `commands/` Directory

Specialized sub-agent instruction files:

- **`component.md`** - `/component` - Create UI components
- **`page.md`** - `/page` - Create page components
- **store.md`** - `/store` - Create MobX stores
- **`architect.md`** - `/architect` - Review architecture compliance
- **`feature.md`** - `/feature` - Coordinate feature implementation

## How It Works

### 1. Claude Reads CLAUDE.md
At session start, Claude reads the main instructions to understand:
- Project architecture
- Available sub-agents
- Rules and patterns
- What NOT to do

### 2. User Requests Task
User asks Claude to do something:
- "Create a button component"
- "Add user management feature"
- "Review the code"

### 3. Claude Selects Sub-Agent
Claude determines which sub-agent to use:
- Component → `/component`
- Feature → `/feature`
- Review → `/architect`

### 4. Sub-Agent Executes
The sub-agent:
- Reads architecture spec
- Follows strict patterns
- Validates compliance
- Creates correct structure

### 5. Validation
After execution:
- Tests in Storybook
- Checks TypeScript
- Verifies architecture

## Quick Start for Claude

```markdown
# At start of session:
1. Read .claude/CLAUDE.md
2. Note available sub-agents
3. Understand critical rules

# When user requests task:
1. Identify task type
2. Select appropriate sub-agent
3. Follow sub-agent instructions
4. Validate result

# Before completing:
1. Run /architect validate
2. Test in Storybook
3. Confirm compliance
```

## For Developers

### Adding a Sub-Agent

1. Create `commands/[name].md`
2. Define purpose and responsibilities
3. Add template/pattern
4. Add validation checklist
5. Update `CLAUDE.md`
6. Update `../SUB_AGENT_STRATEGY.md`

### Updating Instructions

1. Modify relevant `.md` file
2. Test with Claude
3. Verify behavior
4. Document changes

### Testing Sub-Agents

```markdown
1. Start new Claude session
2. Request task handled by sub-agent
3. Verify correct pattern followed
4. Check for violations
5. Test in Storybook
```

## Architecture Enforcement

These instructions enforce:
- ✅ Components in `ui/`
- ✅ Stores follow Domain/Session/UI pattern
- ✅ Pages import from barrels
- ✅ CVA uses custom wrapper
- ✅ All components have stories
- ✅ No mixing of concerns

## Related Files

- `../.project/ARCHITECTURE_SPEC.md` - Full architecture specification
- `../ARCHITECTURE_COMPLIANCE.md` - Current compliance status
- `../SUB_AGENT_STRATEGY.md` - Detailed sub-agent documentation

## Commands

| Command | Purpose |
|---------|---------|
| `/component` | Create UI component |
| `/page` | Create page component |
| `/store` | Create MobX store |
| `/architect` | Review/refactor code |
| `/feature` | Implement complete feature |

## Success Criteria

Instructions are working when:
- ✅ No architecture violations
- ✅ Consistent code patterns
- ✅ All components in correct locations
- ✅ All components have stories
- ✅ Stores properly separated
- ✅ Pages import correctly

## Maintenance

Review and update when:
- Architecture evolves
- New patterns emerge
- Common mistakes found
- Sub-agents need refinement

---

**Important**: These instructions are critical for maintaining architecture compliance. Do not bypass sub-agents!
