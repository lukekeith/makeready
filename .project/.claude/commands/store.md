# Store Generation Command

Generate or enhance MobX stores for domain data, session state, or UI transformations.

## Usage

```
/store <type> <name> [options]
```

## Arguments

- `<type>` - Store type
  - `domain` - Domain/API store
  - `ui` - UI state store
  - `session` - Session data (usually don't create new ones)

- `<name>` - Store name or path
  - Domain: "customers", "payments", "users"
  - UI: "admin.userManagement", "customer.dashboard"

## Options

- `--api` - API endpoint to integrate (for domain stores)
- `--computed` - Component props to generate (JSON array)
- `--actions` - Action methods to create (JSON array)
- `--observables` - Observable properties (JSON array)
- `--mock` - Generate mock data for development

## Examples

### Domain Store
```
/store domain customers --api "API.Customers"
```
Creates a domain store for the Customers API.

### UI Store
```
/store ui admin.userManagement --observables '["selectedUserId", "searchQuery"]' --computed '["userTable", "userForm"]' --actions '["selectUser", "setSearchQuery", "handleUserUpdate"]'
```
Creates a UI store with observables, computed props, and actions.

### UI Store with Component Props
```
/store ui customer.dashboard --computed '[{"name": "kpiCards", "component": "MeterKpi"}, {"name": "taxEventTable", "component": "TaxGuardianCodesTable"}]'
```
Generates computed properties that return props for specific components.

## What Gets Generated

### Domain Store Structure

```typescript
import { observable, makeObservable } from "mobx";
import { Store } from "../store";
import { ApplicationStore } from "../application.store";
import { createDomainFromAPI } from "util/api";
import { API } from "app/client/api";

export class CustomersDomain extends Store {
  @observable api = createDomainFromAPI(
    this.application,
    API.Customers,
    MOCK.domain?.Customers
  );

  constructor(application: ApplicationStore) {
    super(application);
    makeObservable(this);
  }
}
```

### UI Store Structure

```typescript
import { observable, computed, action, makeObservable } from "mobx";
import { Store } from "../../store";
import { ApplicationStore } from "../../application.store";
import { gatherFieldErrors, getFieldErrors } from "util/errors";

export class UserManagementUI extends Store {
  // Observables - mutable state
  @observable selectedUserId?: string;
  @observable searchQuery: string = "";

  constructor(application: ApplicationStore) {
    super(application);
    makeObservable(this);
  }

  // Computed - derived state for components
  @computed
  get userTable(): IUserTable {
    const api = this.application.domain.users.api.listUsers;
    const users = api.data?.payload || [];

    return {
      mode: api.isLoading ? UserTableCva.mode.loading : void 0,
      error: gatherFieldErrors(getFieldErrors(api.error))?.__system__?.message,
      data: users.filter(u =>
        u.name.toLowerCase().includes(this.searchQuery.toLowerCase())
      ),
      selectedId: this.selectedUserId,
      onSelect: this.selectUser,
      onSearch: this.setSearchQuery,
    };
  }

  @computed
  get userForm(): IUserForm {
    const user = this.application.domain.users.api.getUser.data?.payload;

    return {
      initialData: user,
      isLoading: this.application.domain.users.api.updateUser.isLoading,
      onSubmit: this.handleUserUpdate,
    };
  }

  // Actions - state mutations
  @action
  selectUser = (id: string) => {
    this.selectedUserId = id;
  };

  @action
  setSearchQuery = (query: string) => {
    this.searchQuery = query;
  };

  @action
  handleUserUpdate = async (data: UserFormData) => {
    const result = await this.application.domain.users.api.updateUser(data);
    if (result.success) {
      this.selectedUserId = undefined;
      return true;
    }
    return result.errors;
  };

  @action
  refresh = () => {
    this.application.domain.users.api.listUsers();
  };
}
```

## AI-Enhanced Features

### Smart Computed Props
- Analyzes component interfaces to generate correct prop structure
- Includes loading states from API calls
- Adds error handling with `gatherFieldErrors()`
- Binds action methods automatically
- Filters/transforms domain data for UI

### Intelligent Actions
- Generates CRUD action methods based on domain API
- Includes error handling and validation
- Returns `FormSubmissionResult` for form handlers
- Updates local state on success

### API Integration
- Connects to domain stores via `this.application.domain.{domain}`
- Uses `createDomainFromAPI()` for API client wrapper
- Handles loading/error/data states automatically

### Type Safety
- Imports component interfaces for computed props
- Uses correct types for observables and actions
- Properly typed API responses

## Store Architecture Pattern

```
ApplicationStore (singleton)
├── DomainStore
│   ├── CustomersDomain
│   ├── UsersDomain
│   └── PaymentsDomain
├── SessionStore
│   └── User, auth, URL params
└── UIStore
    ├── admin
    │   ├── UserManagementUI
    │   └── CustomerManagementUI
    └── customer
        └── DashboardUI
```

## Computed Props Pattern

Computed properties transform domain/session data into component-ready props:

```typescript
@computed
get componentProps(): IComponent {
  // 1. Get domain data
  const api = this.application.domain.{domain}.api.{endpoint};
  const data = api.data?.payload;

  // 2. Get session data if needed
  const user = this.application.session.user;

  // 3. Transform for component
  return {
    // State
    mode: api.isLoading ? ComponentCva.mode.loading : void 0,

    // Data
    data: data?.filter(/* transform */),

    // Errors
    error: gatherFieldErrors(getFieldErrors(api.error))?.__system__?.message,

    // Handlers
    onAction: this.handleAction,
    onSelect: this.handleSelect,
  };
}
```

## Actions Pattern

Actions handle user interactions and state changes:

```typescript
@action
handleFormSubmit = async (formData: FormData): Promise<FormSubmissionResult<FormData>> => {
  // 1. Call domain API
  const result = await this.application.domain.{domain}.api.{method}(formData);

  // 2. Handle success
  if (result.success) {
    // Update UI state
    this.selectedId = undefined;

    // Return success
    return true;
  }

  // 3. Handle errors
  return result.errors; // FormErrors
};

@action
handleSelection = (id: string) => {
  // Simple state mutation
  this.selectedId = id;
};

@action
refresh = () => {
  // Trigger data reload
  this.application.domain.{domain}.api.{list}();
};
```

## Best Practices

1. **Separation of concerns**
   - Domain stores: API calls and raw data
   - Session stores: User and auth state
   - UI stores: Component props and transformations

2. **Computed for components**
   - Every computed should return complete component props
   - Include loading, error, data, and handlers
   - Name after component: `userTable`, `userForm`

3. **Actions for mutations**
   - All state changes in actions
   - Async actions for API calls
   - Return results (boolean or errors)

4. **Observable for state**
   - UI state only (selections, filters, search)
   - Not for API responses (use domain stores)

5. **Type safety**
   - Import component interfaces
   - Type all observables and computed
   - Use `FormSubmissionResult` for form handlers

## Validation

The command validates:
- ✅ Store name doesn't conflict
- ✅ Store path is valid (for UI stores)
- ✅ API endpoint exists (for domain stores)
- ✅ Component interfaces exist (for computed props)
- ✅ Parent store structure exists

## Post-Generation

After generating store, the command:
1. ✅ Creates store file
2. ✅ Updates parent store to include new store
3. ✅ Updates barrel exports
4. ✅ Suggests integration in pages/components
5. ✅ Provides usage example

## Example Workflow

```bash
# 1. Create domain store
/store domain notifications --api "API.Notifications"

# 2. Create UI store for admin notifications
/store ui admin.notifications --computed '[{"name": "notificationPanel", "component": "NotificationPanel"}]' --actions '["markAsRead", "clearAll"]'

# 3. Review generated store

# 4. Integrate in page:
"Add the notifications panel to the AdminDashboard page using the admin.notifications store"

# 5. Test
npm run dev
```

## Related Commands

- `/page` - Generate pages that use stores
- `/component` - Generate components that receive store props

## Notes

- Store files go in `app/client/store/`
- Domain stores in `app/client/store/domain/`
- UI stores in `app/client/store/ui/`
- All stores extend base `Store` class
- Singleton ApplicationStore provides access to all stores
- Pages access stores via `Application.domain.{name}` or `Application.ui.{path}`
