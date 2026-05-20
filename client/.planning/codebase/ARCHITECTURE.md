# Architecture

**Analysis Date:** 2026-03-16

## Pattern Overview

**Overall:** MobX-based reactive state management with layered separation of concerns (Domain/Session/UI stores), React Router navigation, and component-driven UI architecture.

**Key Characteristics:**
- Domain-driven store structure separating API calls from UI state transformations
- Observer pattern throughout for reactive UI updates
- Centralized modal service for consistent overlay handling
- Type-safe CVA variants for component theming
- Router-based page navigation with URL-driven state
- Session-based authentication with phone verification support

## Layers

**Store Layer (`src/store/`):**
- Purpose: Centralized state management via MobX, organized by domain/session/ui concerns
- Location: `src/store/`
- Contains: ApplicationStore (root), DomainStore (API/data), SessionStore (auth), UIStore (component state)
- Depends on: apiClient, Store base class
- Used by: Pages and ModalRegistry

**Page Layer (`src/pages/`):**
- Purpose: Connect stores to UI components, handle routing logic, manage page lifecycle
- Location: `src/pages/`
- Contains: Page components for each route, each typically wrapping UI components with store data
- Depends on: Application store, UI components, apiClient
- Used by: React Router in App.tsx

**UI Component Layer (`ui/components/`):**
- Purpose: Reusable, presentation-only components with no business logic or store access
- Location: `ui/components/`
- Contains: Primitive (base), domain (business-specific), layout (page structure), panel (auxiliary) components
- Depends on: util/ (CVA, classnames, when), style files
- Used by: Pages and other components

**Utility Layer (`util/`):**
- Purpose: Shared helper functions and custom wrappers
- Location: `util/`
- Contains: CVA wrapper (type-safe variants), classnames helper, when() conditional renderer, custom hooks
- Depends on: class-variance-authority, clsx
- Used by: UI components

**API Layer (`src/lib/api-client.ts`):**
- Purpose: Centralized HTTP communication with automatic session credential handling
- Location: `src/lib/`
- Contains: apiClient singleton with GET/POST/PATCH/DELETE/upload methods
- Depends on: fetch API, environment variables (VITE_API_URL)
- Used by: Domain stores exclusively

## Data Flow

**User Interaction Flow:**

1. User interacts with UI component (e.g., clicks button)
2. Component calls handler from page props
3. Page handler calls Action on UI store or domain store
4. Domain store makes API call via apiClient if needed
5. Store state updates via MobX @action decorator
6. Observer-wrapped components re-render with new state

**Page Mount Lifecycle:**

1. Router navigates to page component
2. Page component wraps useLifecycle() hook on UI store
3. useLifecycle calls store.willMount() which loads initial data
4. useLifecycle returns shouldMount=false during load, preventing render
5. Once loaded, shouldMount=true, page renders with store data
6. Page unmounts, useLifecycle calls store.willUnmount() for cleanup

**Authentication Flow:**

1. Member logs in via phone verification (JoinStore or login page)
2. Session store receives member data and auth token
3. apiClient automatically includes session cookies on all requests
4. Protected routes check session.isMemberAuthenticated
5. Logout action clears session and redirects to public home

**State Management:**

- **Domain Stores** (`src/store/domain/`): Hold raw data from API (users, groups, lessons, etc.). No UI transforms. Handle all API calls.
- **Session Store** (`src/store/SessionStore.ts`): Holds authenticated member info, auth state, organizational context
- **UI Stores** (`src/store/ui/`): Compute derived props for components, manage component-level state (filters, selections, pagination), handle no API calls directly

## Key Abstractions

**Modal Service:**
- Purpose: Centralized modal/menu stack management avoiding scattered useState modals
- Examples: `src/store/ui/modal.service.ts`, `ui/components/layout/modal-provider/`
- Pattern: Application.ui.modal.openMenu/openFullscreen to trigger, ModalRegistry to render

**Custom CVA Wrapper:**
- Purpose: Type-safe enum-like access to component variants with intellisense
- Examples: `util/cva.ts`, `ui/components/primitive/button/button.tsx`
- Pattern: ButtonCva.variant.Primary access instead of string literals

**useLifecycle Hook:**
- Purpose: Safe store lifecycle management with proper mount guard and willUnmount cleanup
- Examples: `util/hooks/use-lifecycle.ts`
- Pattern: const { store, shouldMount } = useLifecycle(Application.ui.home)

**API Client Singleton:**
- Purpose: Centralized HTTP with automatic credential handling and error normalization
- Examples: `src/lib/api-client.ts`
- Pattern: apiClient.get/post/patch/delete with typed responses

## Entry Points

**Application Entry (`src/main.tsx`):**
- Location: `src/main.tsx`
- Triggers: Vite dev/build process
- Responsibilities: Creates React root, renders App component, initializes Application singleton (available as window.app for debugging)

**App Component (`src/App.tsx`):**
- Location: `src/App.tsx`
- Triggers: Application startup via main.tsx
- Responsibilities: Sets up React Router, mounts ModalRegistry provider, defines all route mappings

**Store Initialization (`src/store/ApplicationStore.ts`):**
- Location: `src/store/ApplicationStore.ts`
- Triggers: Module import in main.tsx
- Responsibilities: Creates singleton Application instance with all domain/session/ui stores, provides window.app debug access

## Error Handling

**Strategy:** Try/catch in actions with MobX state updates, error messages stored in store for UI display

**Patterns:**

- Domain stores catch API errors, store in error state, log to console
- UI stores propagate domain errors to component props
- API errors include status code and message for user-friendly display
- Network errors handled gracefully with fallback message
- Session errors (401) trigger logout and redirect to login page

## Cross-Cutting Concerns

**Logging:** console.log/error in domain/UI stores, debug helper window.session() in main.tsx shows join flow state

**Validation:** Form validation via React Hook Form in component pages (e.g., phone format validation in phone-entry component, profile validation in profile-form)

**Authentication:** SessionStore holds isMemberAuthenticated flag, apiClient includes credentials automatically, pages check session before rendering protected content

**Navigation:** React Router handles all navigation, pages redirect on auth state changes, window.location.href used for full-page redirects (logout, join flow completion)

---

*Architecture analysis: 2026-03-16*
