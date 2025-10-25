# /store - MobX Store Generator

Create a MobX store following Domain/Session/UI pattern.

## Required Reading

Before proceeding, read:
1. `.project/ARCHITECTURE_SPEC.md` - State Management with MobX section
2. `ARCHITECTURE_COMPLIANCE.md` - Store patterns

## Task

Create a MobX store that:
- ✅ Extends `Store` base class
- ✅ Uses proper MobX decorators (@observable, @computed, @action)
- ✅ Follows store responsibilities strictly
- ✅ No mixing of concerns (Domain ≠ UI ≠ Session)

## Store Types

### 1. Domain Store
**Location**: `client/src/store/domain/[resource].domain.ts`

**Purpose**: API data and business logic

**Responsibilities**:
- API calls
- Raw data storage
- Business logic
- Loading/error states

**Does NOT**:
- Transform data for UI
- Hold UI state
- Handle authentication

**Pattern**:
```typescript
import { observable, action, makeObservable } from "mobx";
import { Store } from "../store";
import { ApplicationStore } from "../application.store";

export class UsersDomain extends Store {
  @observable users: User[] = [];
  @observable isLoading = false;
  @observable error?: string;

  constructor(application: ApplicationStore) {
    super(application);
    makeObservable(this);
  }

  @action
  async fetchUsers() {
    this.isLoading = true;
    this.error = undefined;

    try {
      const response = await fetch('/api/users');
      this.users = await response.json();
    } catch (error) {
      this.error = error.message;
    } finally {
      this.isLoading = false;
    }
  }

  @action
  async createUser(data: UserData) {
    // API call
  }
}
```

### 2. Session Store
**Location**: `client/src/store/session.store.ts` (singleton)

**Purpose**: Authentication and session state

**Responsibilities**:
- User authentication
- Session tokens
- URL parameters
- Navigation state

**Does NOT**:
- Store domain data
- Store UI state
- Make API calls (except auth)

**Pattern**:
```typescript
import { observable, computed, action, makeObservable } from "mobx";
import { Store } from "./store";
import { ApplicationStore } from "./application.store";

export class SessionStore extends Store {
  @observable user?: User;
  @observable token?: string;
  @observable queryParams: string = "";

  constructor(application: ApplicationStore) {
    super(application);
    makeObservable(this);
  }

  @computed
  get isAuthenticated(): boolean {
    return !!this.token && !!this.user;
  }

  @action
  login(user: User, token: string) {
    this.user = user;
    this.token = token;
    localStorage.setItem('token', token);
  }

  @action
  logout() {
    this.user = undefined;
    this.token = undefined;
    localStorage.removeItem('token');
  }

  @action
  navigate(path: string) {
    // Navigation logic
  }
}
```

### 3. UI Store
**Location**: `client/src/store/ui/[section]/[feature].ui.ts`

**Purpose**: Transform domain/session data into component props

**Responsibilities**:
- Component-ready props (computed)
- UI state (selected, expanded, etc.)
- UI transformations (filtering, sorting)
- Event handlers

**Does NOT**:
- Make API calls
- Store raw domain data
- Handle authentication

**Pattern**:
```typescript
import { observable, computed, action, makeObservable } from "mobx";
import { Store } from "../../store";
import { ApplicationStore } from "../../application.store";
import { IUserTable } from "ui"; // Import component interface

export class UserManagementUI extends Store {
  // UI state
  @observable selectedUserId?: string;
  @observable searchQuery: string = "";
  @observable sortBy: 'name' | 'email' = 'name';

  constructor(application: ApplicationStore) {
    super(application);
    makeObservable(this);
  }

  // Lifecycle methods (optional)
  willMount() {
    this.application.domain.users.fetchUsers();
    return true; // Return false to prevent mount
  }

  willUnmount() {
    this.searchQuery = "";
    this.selectedUserId = undefined;
  }

  // Computed props for components
  @computed
  get userTableProps(): IUserTable {
    const { users, isLoading, error } = this.application.domain.users;

    // Transform and filter data
    const filteredUsers = users.filter(u =>
      u.name.toLowerCase().includes(this.searchQuery.toLowerCase())
    );

    const sortedUsers = [...filteredUsers].sort((a, b) =>
      a[this.sortBy].localeCompare(b[this.sortBy])
    );

    return {
      data: sortedUsers,
      loading: isLoading,
      error: error,
      selectedId: this.selectedUserId,
      onSelect: this.selectUser,
      onSearch: this.setSearchQuery,
      onSort: this.setSortBy,
    };
  }

  @computed
  get userFormProps(): IUserForm {
    const selectedUser = this.application.domain.users.users.find(
      u => u.id === this.selectedUserId
    );

    return {
      initialData: selectedUser,
      isSubmitting: this.application.domain.users.isLoading,
      onSubmit: this.handleUserUpdate,
      onCancel: this.clearSelection,
    };
  }

  // Actions for UI mutations
  @action
  selectUser = (id: string) => {
    this.selectedUserId = id;
  };

  @action
  clearSelection = () => {
    this.selectedUserId = undefined;
  };

  @action
  setSearchQuery = (query: string) => {
    this.searchQuery = query;
  };

  @action
  setSortBy = (field: 'name' | 'email') => {
    this.sortBy = field;
  };

  // Actions that coordinate with domain
  @action
  handleUserUpdate = async (data: UserData) => {
    const result = await this.application.domain.users.updateUser(
      this.selectedUserId!,
      data
    );

    if (result.success) {
      this.clearSelection();
      return true;
    }

    return result.errors;
  };
}
```

## Steps to Create Store

1. **Determine store type**: Domain, Session, or UI?

2. **Create file in correct location**:
   - Domain: `client/src/store/domain/[resource].domain.ts`
   - Session: `client/src/store/session.store.ts`
   - UI: `client/src/store/ui/[section]/[feature].ui.ts`

3. **Extend Store base class** and use proper pattern

4. **Add to parent store**:

   For Domain:
   ```typescript
   // client/src/store/DomainStore.ts
   import { UsersDomain } from './domain/users.domain';

   export class DomainStore extends Store {
     @observable users: UsersDomain;

     constructor(application: ApplicationStore) {
       super(application);
       this.users = new UsersDomain(application);
       makeObservable(this);
     }
   }
   ```

   For UI:
   ```typescript
   // client/src/store/UIStore.ts or client/src/store/ui/admin/index.ts
   import { UserManagementUI } from './user-management.ui';

   export class AdminUIStore extends Store {
     @observable userManagement: UserManagementUI;

     constructor(application: ApplicationStore) {
       super(application);
       this.userManagement = new UserManagementUI(application);
       makeObservable(this);
     }
   }
   ```

## MobX Decorators

| Decorator | When to Use | Example |
|-----------|-------------|---------|
| `@observable` | Mutable state | `@observable count = 0` |
| `@computed` | Derived/memoized state | `@computed get double() { return this.count * 2 }` |
| `@action` | State mutations | `@action increment() { this.count++ }` |

## Validation Checklist

Before completing, verify:
- [ ] Extends `Store` base class
- [ ] Constructor calls `super(application)`
- [ ] Constructor calls `makeObservable(this)`
- [ ] Uses correct decorators (@observable, @computed, @action)
- [ ] Domain: Only API and raw data
- [ ] Domain: No UI transformations
- [ ] UI: Only computed props and UI state
- [ ] UI: No API calls
- [ ] UI: Computed props match component interfaces
- [ ] Session: Only auth and session state
- [ ] Added to parent store properly

## Common Patterns

### Loading State Pattern
```typescript
@observable isLoading = false;
@observable error?: string;

@action
async fetchData() {
  this.isLoading = true;
  this.error = undefined;
  try {
    // API call
  } catch (error) {
    this.error = error.message;
  } finally {
    this.isLoading = false;
  }
}
```

### Computed Props Pattern
```typescript
@computed
get componentProps(): IComponent {
  const data = this.application.domain.resource.data;
  return {
    data: this.transformData(data),
    loading: this.application.domain.resource.isLoading,
    onAction: this.handleAction,
  };
}
```

### Lifecycle Pattern
```typescript
willMount() {
  // Called when component mounts
  this.loadData();
  return true; // false prevents mount
}

willUnmount() {
  // Called when component unmounts
  this.cleanup();
}
```

## Anti-Patterns (DO NOT DO)

❌ **UI transforms in Domain store**:
```typescript
// WRONG - Domain store
@computed
get filteredUsers() {
  return this.users.filter(u => u.active); // This is UI logic!
}
```

❌ **API calls in UI store**:
```typescript
// WRONG - UI store
@action
async fetchUsers() {
  const response = await fetch('/api/users'); // No API in UI!
}
```

❌ **Domain data in Session store**:
```typescript
// WRONG - Session store
@observable users: User[] = []; // Domain data doesn't belong here!
```

## Examples

Good examples to reference:
- `client/src/store/DomainStore.ts`
- `client/src/store/SessionStore.ts`
- `client/src/store/UIStore.ts`
