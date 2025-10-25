# /page - Page Component Generator

Create a page component in `client/src/pages/` that connects stores to UI components.

## Required Reading

Before proceeding, read:
1. `.project/ARCHITECTURE_SPEC.md` - State Management section
2. `ARCHITECTURE_COMPLIANCE.md` - Page pattern examples

## Task

Create a page component that:
- ✅ Imports UI components from `ui`
- ✅ Imports utilities from `util`
- ✅ Accesses Application store
- ✅ Passes data to components via props
- ✅ Uses observer pattern
- ✅ Never passes store directly to UI components

## Steps

1. **Create page folder**: `client/src/pages/[page-name]/`

2. **Create page file**: `client/src/pages/[page-name]/[page-name].page.tsx`

3. **Follow this exact pattern**:
   ```typescript
   import React from "react";
   import { observer } from "mobx-react";
   import { Application } from "@/store/ApplicationStore";
   import { Button, Icon } from "ui"; // Import from ui barrel
   import { when, useLifecycle } from "util"; // Import from util barrel

   export const PageName = observer(() => {
     // Use lifecycle if UI store has willMount/willUnmount
     const { store, shouldMount } = useLifecycle(Application.ui.pageName);
     if (!shouldMount) return null;

     // Access store data
     const { isLoading, data, error } = store;

     return (
       <div className="page-container">
         <h1>Page Title</h1>

         {/* Use when() for conditional rendering */}
         {when(isLoading, <LoadingSpinner />)}
         {when(error, <ErrorMessage message={error} />)}

         {/* Pass props from store to components */}
         {when(data, (
           <Button onClick={() => store.handleAction()}>
             Action
           </Button>
         ))}
       </div>
     );
   });
   ```

4. **For pages with UI stores**, access computed props:
   ```typescript
   export const DashboardPage = observer(() => {
     const { store } = useLifecycle(Application.ui.dashboard);

     return (
       <div>
         {/* Pass computed props from UI store */}
         <UserTable {...store.userTableProps} />
         <UserForm {...store.userFormProps} />
       </div>
     );
   });
   ```

5. **Create UI store if needed** (use `/store` command):
   - Location: `client/src/store/ui/[section]/[page-name].ui.ts`
   - Must have computed props matching component interfaces
   - Example:
     ```typescript
     @computed
     get userTableProps(): IUserTable {
       const users = this.application.domain.users.users;
       return {
         data: users,
         loading: this.application.domain.users.isLoading,
         onSelect: this.selectUser,
       };
     }
     ```

6. **Add to route config** (if applicable):
   ```typescript
   // client/src/route-config.tsx
   <Route path="/page-name" element={<PageName />} />
   ```

7. **Optional: Create SCSS file** if page needs custom styles:
   - `client/src/pages/[page-name]/[page-name].page.scss`

## Validation Checklist

Before completing, verify:
- [ ] Located in `client/src/pages/[page-name]/`
- [ ] Imports from `ui` barrel export (not `@/components`)
- [ ] Imports from `util` barrel export
- [ ] Uses `Application` from `@/store/ApplicationStore`
- [ ] Observer wrapper on component
- [ ] Uses `useLifecycle()` if store has lifecycle methods
- [ ] Passes data via props (never passes store to UI components)
- [ ] Uses `when()` for conditional rendering
- [ ] No direct DOM manipulation
- [ ] No component logic (all logic in store)

## Common Patterns

### Simple Page (No Store)
```typescript
export const AboutPage = observer(() => {
  return (
    <div>
      <h1>About Us</h1>
      <p>Content here</p>
    </div>
  );
});
```

### Page with Domain Store
```typescript
export const UsersPage = observer(() => {
  const users = Application.domain.users.users;
  const isLoading = Application.domain.users.isLoading;

  return (
    <div>
      {when(isLoading, <Spinner />)}
      {users.map(user => (
        <UserCard key={user.id} {...user} />
      ))}
    </div>
  );
});
```

### Page with UI Store (Recommended)
```typescript
export const DashboardPage = observer(() => {
  const { store, shouldMount } = useLifecycle(Application.ui.dashboard);
  if (!shouldMount) return null;

  return (
    <div>
      <UserTable {...store.userTableProps} />
      <MetricsPanel {...store.metricsProps} />
    </div>
  );
});
```

### Page with Auth Check
```typescript
export const ProfilePage = observer(() => {
  const { isAuthenticated } = Application.session;

  if (!isAuthenticated) {
    return <Navigate to="/login" />;
  }

  return (
    <div>
      <ProfileForm {...Application.ui.profile.formProps} />
    </div>
  );
});
```

## Anti-Patterns (DO NOT DO)

❌ **Passing store to components**:
```typescript
// WRONG
<UserTable store={Application.domain.users} />

// CORRECT
<UserTable {...Application.ui.users.tableProps} />
```

❌ **Importing from wrong location**:
```typescript
// WRONG
import { Button } from "@/components/ui/button";

// CORRECT
import { Button } from "ui";
```

❌ **Logic in page component**:
```typescript
// WRONG
export const HomePage = observer(() => {
  const [count, setCount] = useState(0);
  const handleClick = () => setCount(count + 1);
  return <Button onClick={handleClick}>{count}</Button>;
});

// CORRECT - Put logic in UI store
export const HomePage = observer(() => {
  const { store } = Application.ui.home;
  return <Button onClick={store.increment}>{store.count}</Button>;
});
```

## Examples

Good examples to reference:
- See provided example in ARCHITECTURE_COMPLIANCE.md
- Pattern: Import → Access Store → Pass Props → Render
