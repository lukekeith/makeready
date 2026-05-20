# Page Generation Command

Generate a new page component that integrates with MobX stores and uses UI components from the component library.

## Usage

```
/page <name> [options]
```

## Arguments

- `<name>` - Page name (will be converted to PascalCase with "Page" suffix)
  - Examples: "user-profile", "customer-dashboard", "settings"
  - Result: `UserProfilePage`, `CustomerDashboardPage`, `SettingsPage`

## Options

- `--layout` - Specify which layout to use (e.g., "ViewCustomerLayout", "AdminLayout")
- `--store` - UI store path to create (e.g., "admin.userProfile")
- `--route` - Route path for the page (e.g., "/user-profile")
- `--with-store` - Generate UI store for the page
- `--components` - List of UI components to include in the page

## Examples

### Basic Page
```
/page user-profile
```
Creates a basic UserProfile page in `app/client/pages/user-profile/`.

### Page with Layout
```
/page settings --layout ViewCustomerLayout
```
Creates a Settings page using the ViewCustomerLayout.

### Page with Store
```
/page user-management --store admin.userManagement --with-store
```
Creates a UserManagement page and generates the corresponding UI store at `app/client/store/ui/admin/user-management.ui.tsx`.

### Complete Page Setup
```
/page customer-dashboard --layout ViewCustomerLayout --store customer.dashboard --with-store --route /dashboard --components '["Tabs", "KpiContainer", "MeterKpi", "TaxGuardianCodesTable"]'
```

## What Gets Generated

### 1. Page Component File
`app/client/pages/{page-kebab}/{page-kebab}.page.tsx`

**Includes:**
- Imports for UI components and layout
- Import for Application store
- Page CVA definition
- Observer component with forwardRef
- useLifecycle hook for initialization
- Component rendering with store integration

### 2. Page Styles
`app/client/pages/{page-kebab}/{page-kebab}.scss`

**Includes:**
- Page-specific styles
- Layout overrides if needed

### 3. Index Export
`app/client/pages/{page-kebab}/index.ts`

**Includes:**
- Re-export of page component

### 4. UI Store (if --with-store)
`app/client/store/ui/{store-path}.ui.tsx`

**Includes:**
- Store class extending Store base class
- Observable UI state properties
- Computed props for components
- Action methods for event handlers
- Integration with domain stores

### 5. Route Configuration Update
`app/client/route-config.tsx`

**Updates:**
- Adds new route entry with path and component

## Page Template Structure

```typescript
import { observer } from "mobx-react";
import React from "react";
import { Application } from "store/application.store";
import { useLifecycle } from "util/hooks/use-life-cycle";
import { cva, VariantProps } from "util/cva";
import {
  // UI components imported here
} from "ui";

export const {PageName}Cva = cva("{PageName}", {
  variants: { mode: {} },
  defaultVariants: { mode: undefined },
});

export interface I{PageName} extends VariantProps<typeof {PageName}Cva.variants> {
  className?: string;
}

export const {PageName} = observer(
  React.forwardRef<HTMLDivElement, I{PageName}>((props, ref) => {
    const store = Application.ui.{storePath};

    useLifecycle({
      willMount: () => {
        store.refresh();
        return true;
      },
    });

    return (
      <LayoutComponent>
        {/* Page content */}
      </LayoutComponent>
    );
  })
);
```

## UI Store Template Structure

```typescript
import { observable, computed, action, makeObservable } from "mobx";
import { Store } from "../../store";
import { ApplicationStore } from "../../application.store";

export class {PageName}UI extends Store {
  @observable selectedId?: string;
  @observable searchQuery: string = "";

  constructor(application: ApplicationStore) {
    super(application);
    makeObservable(this);
  }

  @computed
  get componentProps(): IComponentProps {
    const api = this.application.domain.{domain}.api.{endpoint};

    return {
      mode: api.isLoading ? ComponentCva.mode.loading : void 0,
      error: gatherFieldErrors(getFieldErrors(api.error))?.__system__?.message,
      data: api.data?.payload,
      onAction: this.handleAction,
    };
  }

  @action
  handleAction = () => {
    // Action implementation
  };

  @action
  refresh = () => {
    // Load data
  };
}
```

## AI-Enhanced Features

### Smart Component Selection
- Analyzes page name to suggest relevant components
- "dashboard" → KPI cards, charts, tables
- "profile" → forms, avatar, tabs
- "settings" → forms, toggles, buttons

### Store Integration
- Automatically creates computed props for selected components
- Generates action methods for common operations
- Connects to relevant domain stores based on page context

### Layout Detection
- Suggests appropriate layout based on page name/route
- Admin pages → AdminLayout
- Customer pages → ViewCustomerLayout
- Auth pages → LoginLayout

### Route Generation
- Converts page name to sensible route path
- Handles nested routes
- Updates route config automatically

## Validation

The command validates:
- ✅ Page name doesn't already exist
- ✅ Layout component exists (if specified)
- ✅ Store path is valid format
- ✅ Components exist in UI library
- ✅ Route doesn't conflict with existing routes

## Post-Generation

After generating files, the command:
1. ✅ Creates page directory and files
2. ✅ Creates UI store if requested
3. ✅ Updates route configuration
4. ✅ Updates UI store barrel exports
5. ✅ Reports file locations
6. ✅ Suggests next steps

## Integration with Existing Pages

Pages follow the established pattern:
- Import from `ui` for components
- Import `Application` singleton for stores
- Use `useLifecycle` for initialization
- Spread computed props to components
- Pass action methods as handlers

## Best Practices

1. **Use layouts** - Always specify a layout component
2. **Create UI stores** - Separate UI logic from pages
3. **Computed props** - Use computed for component props
4. **Lifecycle hooks** - Use useLifecycle for data loading
5. **Spread props** - Use `{...store.componentProps}` pattern

## Example Workflow

```bash
# 1. Generate page with store
/page user-management --layout AdminLayout --store admin.userManagement --with-store

# 2. Review generated files

# 3. Ask Claude to add functionality:
"Add user search, filtering, and edit functionality to the UserManagement page"

# 4. Ask Claude to enhance store:
"Add computed props for UserTable and UserForm components"

# 5. Test the page:
npm run dev
```

## Related Commands

- `/component` - Generate UI components used in pages
- `/store` - Generate or modify stores
- `/route` - Add or modify routes

## Notes

- Pages always go in `app/client/pages/`
- UI stores go in `app/client/store/ui/`
- Pages should never directly call APIs (use stores)
- Pages should be primarily composition (layout + components)
- Business logic belongs in stores, not pages
