# Coding Conventions

**Analysis Date:** 2025-03-16

## Naming Patterns

**Files:**
- Components: kebab-case in folders (e.g., `button/button.tsx`, `group-card/group-card.tsx`)
- Pages: kebab-case with `.page.tsx` suffix (e.g., `home/home.page.tsx`, `join-code/join-code.page.tsx`)
- Stores: kebab-case with suffix (e.g., `members.domain.ts`, `group-home.ui.ts`)
- Tests: kebab-case with `.test.ts` or `.spec.ts` suffix (e.g., `classnames.test.ts`)
- Stories: kebab-case with `.stories.tsx` suffix (e.g., `button.stories.tsx`)

**Functions:**
- Regular functions: camelCase (e.g., `fetchGroups`, `handleClick`, `submitActivity`)
- Utility functions: camelCase (e.g., `when()`, `whenElse()`, `classnames()`)
- Action methods in stores: camelCase (e.g., `@action fetchMembers()`, `@action updateMember()`)

**Variables:**
- Local variables: camelCase (e.g., `isLoading`, `selectedNav`, `groupData`)
- State properties: camelCase (e.g., `@observable members`, `@observable error`)
- Computed properties: camelCase (e.g., `@computed get memberCount()`)
- Constants: UPPER_SNAKE_CASE (e.g., `API_URL`, `TEST_ROUTES`)
- Interface parameters: prefix with `I` (e.g., `IMember`, `IButton`)

**Types & Interfaces:**
- Component props: `I[ComponentName]` (e.g., `IButton`, `ICard`, `IGroupCard`)
- Data interfaces: `I[EntityName]` (e.g., `IMember`, `IGroup`, `IActivity`)
- Store classes: `[Name]Domain`, `[Name]Session`, `[Name]UI` (e.g., `MembersDomain`, `AuthSession`, `GroupHomeUI`)
- Enum-like objects: PascalCase in CVA definitions (e.g., `Primary`, `Secondary`, `Destructive`)

## Code Style

**Formatting:**
- No automatic formatter configured (ESLint handles it)
- 2-space indentation (standard)
- Semicolons required at end of statements
- Imports organized by: ESM/NPM libraries first, then relative imports

**Linting:**
- ESLint v9.15.0 with TypeScript support
- Config: `eslint.config.js` (flat config format)
- Key rules:
  - `@typescript-eslint/no-unused-vars`: Error (with `_` prefix for intentional unused parameters)
  - `@typescript-eslint/no-explicit-any`: Warn (disabled in tests and Storybook files)
  - `react-refresh/only-export-components`: Warn (disabled for shadcn/ui and Storybook files)
  - `no-console`: Warn (allow `console.warn` and `console.error`, disabled in tests)

## Import Organization

**Order:**
1. React and core libraries (e.g., `import React from 'react'`)
2. External packages (e.g., `import { observer } from 'mobx-react'`, `import { cva } from 'util/cva'`)
3. Internal absolute imports (e.g., `import { Application } from '@/store/ApplicationStore'`)
4. Relative imports (e.g., `import { Button } from '../button'`)
5. Styles (e.g., `import './component.scss'`)

**Path Aliases:**
- `@/*` → `./src/*` (application code)
- `ui` → `./ui/index.ts` (UI components barrel)
- `ui/*` → `./ui/*` (UI subdirectories)
- `util` → `./util/index.ts` (utilities barrel)
- `util/*` → `./util/*` (utility subdirectories)
- `shared/*` → `./shared/*` (shared types/constants)

**Rules:**
- UI components ONLY import from `util/` using relative paths (never from `@/` or `ui/`)
- Pages import from `ui`, `util`, and `@/store` using path aliases
- Never import from `src/components/` - use `ui/components/` instead

## Error Handling

**Patterns:**
- Try-catch blocks in async operations (domain stores, API calls)
- Always log errors with `console.error()` including context message
- Example pattern:
  ```typescript
  try {
    const response = await apiClient.get(`/api/members/${memberId}/groups`);
    if (response.success && response.data) {
      // handle success
    }
  } catch (error) {
    console.error('Error fetching groups:', error);
    // optionally set error state
  }
  ```
- Errors are logged but not always propagated (UI state handles error display)
- Domain stores store error state in `@observable error?: string` property

**Error Message Style:**
- Start with action context (e.g., "Error fetching members:", "Error updating group:")
- Followed by the error object
- No custom error messages currently in place - relies on exception propagation

## Logging

**Framework:** console (no logging library)

**Patterns:**
- `console.error()`: Used in catch blocks to log exceptions with context
- `console.warn()`: Allowed by ESLint (not commonly used in current code)
- `console.log()`: Blocked by ESLint in production code (allowed in tests/Storybook)

**When to Log:**
- Errors in catch blocks only
- No debug logging in production code
- Test and Storybook files can use console freely

**Example:**
```typescript
@action
async fetchMembers() {
  this.isLoading = true;
  try {
    const response = await apiClient.get<MembersResponse>('/api/members');
    this.members = response.data || [];
  } catch (error) {
    console.error('Error fetching members:', error);
  } finally {
    this.isLoading = false;
  }
}
```

## Comments

**When to Comment:**
- JSDoc for utility functions and complex logic
- Inline comments for non-obvious intent
- Section headers in configuration/large files (e.g., `// ============================================================================`)
- Avoid obvious comments ("get the name" for `const name = getName()`)

**JSDoc/TSDoc:**
- Utility functions have JSDoc headers explaining purpose, parameters, and return value
- Example (from `util/when.ts`):
  ```typescript
  /**
   * Conditionally renders an element based on a boolean condition
   * Returns null if condition is false
   *
   * @example
   * return (
   *   <div>
   *     {when(isLoading, <Spinner />)}
   *   </div>
   * );
   *
   * @param condition - Boolean condition to evaluate
   * @param element - Element to render if condition is true
   * @returns The element if condition is true, null otherwise
   */
  export function when<T>(condition: boolean, element: T): T | null {
    return condition ? element : null;
  }
  ```

## Function Design

**Size:** Keep functions small and focused (under 50 lines ideal)

**Parameters:**
- Use object destructuring for props (avoid long parameter lists)
- UI component props use `containerProps` for DOM attributes
- Example:
  ```typescript
  export interface IButton {
    variant?: keyof typeof ButtonCva.variant;
    size?: keyof typeof ButtonCva.size;
    label?: string;
    leftIcon?: React.ReactNode;
    onClick?: () => void;
    containerProps?: React.ButtonHTMLAttributes<HTMLButtonElement>;
  }
  ```

**Return Values:**
- Functions return what they're named for (no side effects)
- Async functions return Promises
- Render functions return JSX or null (using `when()` helper)
- Store methods don't return data - they mutate store state

## Module Design

**Exports:**
- Named exports for components, utilities, and store classes
- Barrel exports in `index.ts` files (e.g., `ui/index.ts` re-exports all components)
- Example (from `ui/index.ts`):
  ```typescript
  export { Button, ButtonCva } from './components/primitive/button/button';
  export { Card } from './components/primitive/card/card';
  ```

**Barrel Files:**
- `ui/index.ts`: Central export for all UI components
- `util/index.ts`: Central export for utilities
- Used to keep import paths clean: `import { Button, Icon } from 'ui'`

## Component Patterns

**Observer Pattern:**
- Components wrap with `observer()` from `mobx-react`
- Example:
  ```typescript
  export const Button = observer(
    React.forwardRef<HTMLButtonElement, IButton>((props, ref) => {
      // component code
    })
  );
  ```

**ForwardRef:**
- Components use `React.forwardRef` to expose DOM elements
- Required for UI components that need direct DOM access
- Always set `displayName` property after component definition

**CVA Pattern:**
- Use custom CVA wrapper from `util/cva` (never raw `class-variance-authority`)
- CVA objects provide enum-like access to variants
- Example (from `button.tsx`):
  ```typescript
  export const ButtonCva = cva("Button", {
    variants: {
      variant: { Primary: "Button--primary", Secondary: "Button--secondary" }
    },
    defaultVariants: { variant: "Primary" }
  });

  // Access variants as enums:
  <Button variant={ButtonCva.variant.Primary} />
  ```

**SCSS & BEM Naming:**
- All components have corresponding `.scss` file in same folder
- Use BEM (Block Element Modifier) convention:
  - `.Block`: Component/container (PascalCase matching component name)
  - `.Block__element`: Child element (lowercase with double underscore)
  - `.Block--modifier`: Variant/state (lowercase with double dash)
- Example (from `button.scss`):
  ```scss
  .Button {
    // block styles
    &__label { font-weight: 600; }
    &__icon { margin-right: 8px; }
    &--primary { background: blue; }
    &--loading { opacity: 0.6; }
  }
  ```

## Store Patterns

**Decorator Usage:**
- `@observable`: State properties that can change
- `@action`: Methods that mutate observable state
- `@computed`: Derived properties calculated from observables
- `makeObservable(this)`: Required in constructor to set up reactivity

**Domain Store Pattern:**
- Location: `src/store/domain/[name].domain.ts`
- Responsibility: API calls and raw data management (no UI transforms)
- No direct store access in UI components
- Example pattern:
  ```typescript
  export class MembersDomain extends Store {
    @observable members: IMember[] = [];
    @observable isLoading = false;
    @observable error?: string;

    constructor(application: ApplicationStore) {
      super(application);
      makeObservable(this);
    }

    @computed
    get activeMembers(): IMember[] {
      return this.members.filter(m => m.isActive);
    }

    @action
    async fetchMembers() {
      this.isLoading = true;
      try {
        const response = await apiClient.get<IMember[]>('/api/members');
        this.members = response.data || [];
      } catch (error) {
        console.error('Error fetching members:', error);
      } finally {
        this.isLoading = false;
      }
    }
  }
  ```

**UI Store Pattern:**
- Location: `src/store/ui/[name].ui.ts`
- Responsibility: Computed props for UI components + UI-specific state
- No API calls
- Example pattern:
  ```typescript
  export class AdminUI extends Store {
    @observable selectedUserId?: string;

    @computed
    get userTableProps(): IUserTable {
      const users = this.application.domain.members.members;
      return {
        data: users,
        selectedId: this.selectedUserId,
        onSelect: this.selectUser,
      };
    }

    @action
    selectUser = (id: string) => {
      this.selectedUserId = id;
    };
  }
  ```

---

*Convention analysis: 2025-03-16*
