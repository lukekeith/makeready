# /feature - Feature Implementation Coordinator

Coordinate multiple sub-agents to implement complete features following architecture.

## Purpose

Implement features that span multiple components, stores, and pages while maintaining architecture compliance.

## Task

When implementing a feature:
1. Break down into atomic tasks
2. Coordinate sub-agents in correct order
3. Ensure proper integration
4. Maintain separation of concerns
5. Test in Storybook

## Feature Implementation Flow

```
1. UI Components (/component)
   ↓
2. Domain Stores (/store domain)
   ↓
3. UI Stores (/store ui)
   ↓
4. Pages (/page)
   ↓
5. Integration & Testing
```

## Steps

### 1. **Requirements Analysis**

Ask user:
- What is the feature?
- What data is needed?
- What actions can users perform?
- Are there existing components we can reuse?

### 2. **Component Planning**

Identify needed components:
- **Primitive** - Base components (buttons, inputs, cards)
- **Domain** - Business components (user cards, product lists)
- **Layout** - Page layouts

For each component:
```
/component [name] [category]
```

### 3. **Store Planning**

Identify needed stores:

**Domain Store** (if new API resource):
- API calls
- Raw data storage
- Loading states

**UI Store** (always needed):
- Component props (computed)
- UI state
- Event handlers

For each store:
```
/store domain [resource]
/store ui [section].[feature]
```

### 4. **Page Creation**

Create page that connects everything:
```
/page [page-name]
```

### 5. **Integration**

- Verify imports correct
- Test component composition
- Check prop flow
- Validate in Storybook
- Test page functionality

### 6. **Documentation**

- Update README if needed
- Document new patterns
- Add usage examples

## Example Feature: User Management

### Requirements
- Display list of users
- Filter and search users
- Edit user details
- Create new users

### Implementation Plan

**1. Create UI Components**
```
/component user-card domain
/component user-form domain-form
/component user-table domain
```

Each component:
- View-only (no logic)
- Proper CVA variants
- Storybook story
- Receives props interface

**2. Create Domain Store**
```
/store domain users
```

```typescript
export class UsersDomain {
  @observable users: User[] = [];
  @observable isLoading = false;

  @action async fetchUsers() { ... }
  @action async createUser(data) { ... }
  @action async updateUser(id, data) { ... }
}
```

**3. Create UI Store**
```
/store ui admin.user-management
```

```typescript
export class UserManagementUI {
  @observable selectedUserId?: string;
  @observable searchQuery = "";

  @computed get userTableProps(): IUserTable {
    return {
      data: this.filteredUsers,
      onSelect: this.selectUser,
      onSearch: this.setSearchQuery,
    };
  }

  @computed get userFormProps(): IUserForm {
    return {
      initialData: this.selectedUser,
      onSubmit: this.handleSubmit,
    };
  }
}
```

**4. Create Page**
```
/page user-management
```

```typescript
export const UserManagementPage = observer(() => {
  const { store } = useLifecycle(Application.ui.admin.userManagement);

  return (
    <div>
      <UserTable {...store.userTableProps} />
      {when(store.selectedUserId, (
        <UserForm {...store.userFormProps} />
      ))}
    </div>
  );
});
```

**5. Test**
- Open Storybook: `npm run storybook`
- Test each component in isolation
- Test page with stores
- Verify all interactions work

## Feature Templates

### CRUD Feature
1. Domain component (card/list item)
2. Table/List component
3. Form component (create/edit)
4. Domain store (API calls)
5. UI store (table props, form props)
6. Page (connects all)

### Dashboard Feature
1. Metric cards (primitives)
2. Chart components (domain)
3. Layout component
4. Domain stores (multiple resources)
5. UI store (aggregates data)
6. Page (dashboard layout)

### Auth Feature
1. Form components (primitive)
2. Social buttons (already have)
3. Session store (auth logic)
4. Login/Register pages
5. Protected route wrapper

## Coordination Strategy

### Sequential Tasks (Must wait)
```
1. Create Button component
   ↓ (wait)
2. Create Form that uses Button
   ↓ (wait)
3. Create Page that uses Form
```

### Parallel Tasks (Can do together)
```
1. Create UserCard component
   +
2. Create ProductCard component
   +
3. Create OrderCard component

(All independent, can create simultaneously)
```

## Validation Checklist

After feature implementation:
- [ ] All components in `ui/components/`
- [ ] All components have stories
- [ ] Stories work in Storybook
- [ ] Domain stores only have API/data
- [ ] UI stores have proper computed props
- [ ] Page imports from `ui` and `util`
- [ ] Page passes props (not stores)
- [ ] No architecture violations
- [ ] Feature works end-to-end
- [ ] TypeScript compiles
- [ ] No console errors

## Common Feature Patterns

### Pattern: List + Detail
```
Components:
- ItemCard (display item)
- ItemList (list of cards)
- ItemDetail (detail view)

Stores:
- ItemsDomain (fetch items)
- ItemsUI (list props, selected item)

Page:
- Shows list, click opens detail
```

### Pattern: Wizard/Multi-Step
```
Components:
- WizardStep1, WizardStep2, WizardStep3
- WizardLayout (wraps steps)
- ProgressIndicator

Stores:
- WizardUI (current step, data accumulation)

Page:
- Renders current step
- Handles navigation
```

### Pattern: Real-Time Updates
```
Components:
- LiveDataDisplay

Stores:
- DataDomain (WebSocket connection)
- DataUI (format for display)

Page:
- Connects to live data
- Updates automatically
```

## Anti-Patterns

❌ **Creating page first, then components**
- Components should be reusable
- Build bottom-up, not top-down

❌ **Skipping Storybook**
- Test components in isolation first
- Faster feedback loop

❌ **Mixing concerns in stores**
- Keep Domain/UI/Session separate
- Each has single responsibility

❌ **Creating components without planning**
- Know what props you need
- Design interfaces first

## Success Criteria

Feature is complete when:
1. ✅ All components work in Storybook
2. ✅ All stores follow patterns
3. ✅ Page integrates everything
4. ✅ Feature works end-to-end
5. ✅ No architecture violations
6. ✅ Code is maintainable
7. ✅ Can be extended easily

## When to Use

Use `/feature` for:
- Multi-component features
- Features needing stores
- Complex user workflows
- Dashboard implementations
- CRUD operations
- Auth flows
- Any feature spanning multiple files

Don't use for:
- Single primitive component (use `/component`)
- Simple page (use `/page`)
- Single store (use `/store`)
