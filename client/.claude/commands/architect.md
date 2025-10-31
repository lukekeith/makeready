# /architect - Architecture Compliance Reviewer

Review code against architecture specification and enforce compliance.

## Purpose

Ensure all code follows the architecture patterns defined in `.project/ARCHITECTURE_SPEC.md`.

## Task

When invoked, perform a comprehensive architecture review:

1. **Read Architecture Spec**
   - Read `.project/ARCHITECTURE_SPEC.md` in full
   - Read `ARCHITECTURE_COMPLIANCE.md` for current state

2. **Check Component Compliance**
   - ✅ All components in `ui/components/[category]/`
   - ✅ No components in `client/src/components/`
   - ✅ All components use custom CVA wrapper from `util/cva`
   - ✅ All components have Storybook stories in `ui/stories/`
   - ✅ All components exported from `ui/index.ts`
   - ✅ Components only import from `util/`
   - ✅ Observer + forwardRef pattern used
   - ✅ SCSS uses BEM naming

3. **Check Store Compliance**
   - ✅ Domain stores only have API and raw data
   - ✅ UI stores only have computed props and UI state
   - ✅ Session store only has auth and session
   - ✅ No cross-contamination of responsibilities
   - ✅ All stores extend Store base class
   - ✅ All stores use makeObservable(this)

4. **Check Page Compliance**
   - ✅ Pages in `client/src/pages/`
   - ✅ Pages import from `ui` barrel
   - ✅ Pages import from `util` barrel
   - ✅ Pages access Application store
   - ✅ Pages pass props (never pass store to components)
   - ✅ Pages use observer wrapper
   - ✅ Pages use `when()` for conditionals

5. **Check Import Patterns**
   - ✅ UI components never import from `client/` or `@/`
   - ✅ UI components only import from `util/`
   - ✅ Pages import from `ui` and `util` barrels
   - ✅ No direct component imports (use barrels)

6. **Check File Structure**
   - ✅ `.storybook/` at root
   - ✅ `ui/` properly structured
   - ✅ `util/` has all utilities
   - ✅ No orphaned files

## Commands

### `/architect review`
Perform full architecture review and report violations.

**Output**:
- List all violations found
- Categorize by severity (critical/warning)
- Provide fix recommendations
- Show compliant examples

### `/architect refactor [path]`
Refactor non-compliant code to follow architecture.

**Steps**:
1. Identify violations in specified path
2. Present refactoring plan
3. Execute refactoring
4. Verify compliance
5. Test in Storybook

### `/architect validate`
Quick validation check (no refactoring).

**Checks**:
- Component locations correct?
- Store separation maintained?
- Import patterns correct?
- Storybook stories exist?

## Violations to Check

### Critical Violations ❌

These MUST be fixed immediately:

1. **Components in wrong location**
   ```
   ❌ client/src/components/ui/Button.tsx
   ✅ ui/components/primitive/button/button.tsx
   ```

2. **UI components importing from client**
   ```typescript
   ❌ import { Application } from "@/store/ApplicationStore";
   ✅ // No application imports in UI components!
   ```

3. **Raw CVA usage**
   ```typescript
   ❌ import { cva } from "class-variance-authority";
   ✅ import { cva } from "util/cva";
   ```

4. **Store responsibility violations**
   ```typescript
   ❌ // Domain store with UI logic
   @computed get filteredUsers() { ... }

   ❌ // UI store with API calls
   @action async fetchUsers() { ... }
   ```

5. **Passing stores to components**
   ```typescript
   ❌ <UserTable store={Application.domain.users} />
   ✅ <UserTable {...Application.ui.users.tableProps} />
   ```

### Warnings ⚠️

These should be fixed but aren't blocking:

1. **Missing Storybook stories**
2. **Non-BEM SCSS naming**
3. **Missing containerProps**
4. **Direct imports instead of barrels**
5. **Missing lifecycle methods**

## Refactoring Patterns

### Pattern 1: Move Component from client to ui

**Before**:
```
client/src/components/ui/Button.tsx
```

**After**:
```
ui/components/primitive/button/
├── button.tsx
├── button.scss
```

**Steps**:
1. Create new folder in `ui/components/[category]/`
2. Refactor component to follow CVA pattern
3. Create SCSS file
4. Create Storybook story
5. Add to `ui/index.ts`
6. Update all imports in pages
7. Delete old file

### Pattern 2: Split Store Responsibilities

**Before** (Domain store with UI logic):
```typescript
export class UsersDomain {
  @observable users = [];

  @computed get activeUsers() {
    return this.users.filter(u => u.active); // UI logic!
  }
}
```

**After**:
```typescript
// Domain store - Just data
export class UsersDomain {
  @observable users = [];
}

// UI store - Transform for components
export class UsersUI {
  @computed get userTableProps(): IUserTable {
    const users = this.application.domain.users.users;
    return {
      data: users.filter(u => u.active),
      onSelect: this.selectUser,
    };
  }
}
```

### Pattern 3: Fix Page Imports

**Before**:
```typescript
import { Button } from "@/components/ui/button";
import { Application } from "@/store/ApplicationStore";

export const HomePage = () => {
  return <Button store={Application} />;
};
```

**After**:
```typescript
import { observer } from "mobx-react";
import { Button } from "ui";
import { Application } from "@/store/ApplicationStore";

export const HomePage = observer(() => {
  return <Button onClick={() => Application.ui.home.action()} />;
});
```

## Output Format

When reporting violations, use this format:

```
## Architecture Compliance Report

### Critical Violations (MUST FIX) ❌

**1. Components in wrong location**
- ❌ client/src/components/ui/Button.tsx
- ❌ client/src/components/ui/Icon.tsx

**Fix**: Move to ui/components/primitive/

---

**2. UI component importing from client**
- ❌ ui/components/card/card.tsx imports from "@/store"

**Fix**: Remove store imports. Pass data via props.

---

### Warnings ⚠️

**1. Missing Storybook stories**
- ⚠️ ui/components/domain/user-card/ has no story

**Fix**: Create ui/stories/components/domain/user-card.stories.tsx

---

### Compliant ✅

- ✅ ui/components/primitive/button/ - Fully compliant
- ✅ ui/components/primitive/icon/ - Fully compliant
- ✅ Store separation maintained
- ✅ Page imports correct

---

### Recommendations

1. Run `/architect refactor client/src/components` to fix critical issues
2. Create missing Storybook stories
3. Review store responsibilities
4. Test in Storybook after fixes
```

## Validation After Refactoring

After refactoring, verify:
- [ ] `npm run storybook` works
- [ ] All stories load
- [ ] No TypeScript errors
- [ ] No console errors
- [ ] Components work in pages
- [ ] Stores work correctly

## When to Use

Invoke `/architect` when:
- Starting work on the project (review first!)
- After receiving unfamiliar code
- Before major refactoring
- When unsure about patterns
- When Claude hasn't been following architecture
- After adding new features (compliance check)

## Prevention

To prevent violations in future:
- Always use `/component`, `/page`, `/store` commands
- Never create components manually
- Read CLAUDE.md before each session
- Review examples before coding
