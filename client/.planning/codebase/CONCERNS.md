# Codebase Concerns

**Analysis Date:** 2025-03-16

## Tech Debt

### Large Store Files with Mixed Concerns

**Files:**
- `src/store/JoinStore.ts` (938 lines)
- `src/store/ui/lesson-activity.ui.ts` (797 lines)
- `src/store/ui/lesson-preview.ui.ts` (613 lines)

**Issue:**
These stores handle too many responsibilities: state management, API communication, form validation, timer management, and multiple business logic flows. Makes debugging and testing difficult.

**Impact:**
- Hard to test individual functions
- Risk of unintended side effects when changing logic
- Difficult for new developers to understand code flow
- Changes to one feature may break another

**Fix approach:**
Break down by logical responsibility:
- Extract API call logic into separate domain services
- Move timer management into dedicated utility
- Separate form validation into standalone validators
- Consider splitting stores along feature boundaries (e.g., phone verification, profile entry, join logic)

---

### Type Safety Issue: Loose Typing in Lesson Activity

**File:** `src/store/ui/lesson-activity.ui.ts` (line 128)

**Issue:**
```typescript
this.requireResponses = (lesson as any).requireResponse ?? lesson.requireResponses ?? true
```

The API returns `requireResponse` (singular) but the interface expects `requireResponses` (plural). Using `as any` bypasses TypeScript checking and masks the API contract mismatch.

**Impact:**
- Silent property mapping errors
- Future API changes could break without warning
- Makes it unclear what the actual data shape is

**Fix approach:**
- Create a mapper function that explicitly handles the API response transformation
- Update the API domain to normalize the response shape
- Add type guards to validate API responses

---

### Unsafe JSON Parsing

**Files:**
- `src/store/JoinStore.ts` (line 145)
- `src/store/EventJoinStore.ts` (line 85)

**Issue:**
```typescript
private loadFromStorage(): PersistedState | null {
  try {
    const stored = sessionStorage.getItem(STORAGE_KEY);
    return stored ? JSON.parse(stored) : null;
  } catch {
    return null;
  }
}
```

While there's a try-catch, there's no schema validation of the parsed data. Corrupted or malicious data could slip through.

**Impact:**
- Silently accepted invalid state could cause runtime errors later
- No validation that parsed object matches expected structure
- Could introduce type safety issues downstream

**Fix approach:**
- Add Zod schema validation after JSON.parse
- Validate that all required fields exist before returning
- Log parsing errors for debugging (currently silent)

---

## Missing Critical Features

### No Comprehensive Error Boundary

**File:** `src/App.tsx`

**Issue:**
The application has no error boundary component to catch React rendering errors. If a component throws an error, the entire app will crash.

**Impact:**
- One component error crashes the entire application
- No graceful fallback UI
- Users see blank screen instead of error message

**Fix approach:**
- Implement React Error Boundary wrapper in `src/App.tsx`
- Create error UI component that shows message and recovery options
- Log errors to monitoring service (Sentry, LogRocket, etc.)

---

## Test Coverage Gaps

### Minimal Unit Test Coverage

**Current tests:**
- `util/__tests__/`: 2 test files (classnames, when utilities)
- `src/store/__tests__/`: 1 test file (JoinStore only)
- `src/lib/__tests__/`: 1 test file (api-client)

**Untested areas:**
- All domain stores (auth, members, activities, groups, etc.)
- All UI stores (lesson-activity, lesson-preview, account, group-home, etc.)
- All page components
- All modal system logic
- Session management
- Event join flow

**Impact:**
- No regression detection when modifying stores
- Difficult to refactor with confidence
- API changes could break silently
- Modal behavior not verified programmatically

**Priority:** HIGH

**Fix approach:**
- Add unit tests for domain stores (focus on API calls and state transitions)
- Add tests for UI stores (focus on computed props and user interactions)
- Test JoinStore edge cases: already-member, pending request, network errors
- Test modal service: stack management, transitions, auto-close behavior
- Add integration tests for multi-step flows (join, lesson, account)

---

### E2E Test Coverage

**E2E Tests Exist:**
- `e2e/tests/smoke/critical-paths.spec.ts`
- `e2e/tests/join-flow/study-join.spec.ts`
- `e2e/tests/join-flow/phone-verification.spec.ts`

**Gap:** Only critical paths tested. Missing:
- Lesson activity flow (reading, answering, submitting)
- Account modal workflows
- Edit profile flow
- Error scenarios (network failures, validation errors)
- Mobile-specific behaviors (mobile inputs, selects)

**Fix approach:**
- Add E2E tests for lesson activity (video, read, input steps)
- Test account/profile modal interactions
- Add error scenario tests (API failures, validation)
- Test mobile input/select components

---

## Performance Bottlenecks

### Scripture Fetching in Lesson Activity

**File:** `src/store/ui/lesson-activity.ui.ts` (lines 116-122)

**Issue:**
```typescript
// Fetch scripture for all unique scripture references across activities
const scriptureRefs = this.collectScriptureRefs(lesson)
await Promise.all(
  scriptureRefs.map(ref =>
    this.application.domain.activities.fetchScripture(ref.bookNumber!, ref.chapterStart!)
  )
)
```

All scripture requests are made in parallel on page load. If lesson has many unique verses, this could cause:
- Bandwidth spike
- Browser tab becomes unresponsive
- Slow on poor connections

**Impact:**
- Page load takes longer
- Mobile experience degrades on slow networks
- May timeout on very large lessons

**Fix approach:**
- Implement lazy loading: fetch scripture when user clicks "Read"
- Add request debouncing and caching
- Consider splitting lesson load and scripture load into separate phases
- Add loading indicator with progress feedback

---

### Infinite Scroll with IntersectionObserver

**File:** `src/pages/group-home/group-home.page.tsx` (lines 45-69)

**Issue:**
The infinite scroll works but could trigger excessive API calls if user scrolls rapidly. No debouncing or request cancellation.

**Current:**
- No limit on concurrent requests
- No cancellation if user scrolls back up
- Multiple requests could be in-flight simultaneously

**Impact:**
- Could generate 10+ API requests in quick succession
- Server load increases
- Could trigger rate limiting

**Fix approach:**
- Add request debouncing (wait 100ms after last scroll trigger)
- Implement request cancellation using AbortController
- Track in-flight requests and prevent duplicates
- Add loading state indicator to prevent duplicate clicks

---

## Fragile Areas

### Modal Service Stack Management

**File:** `src/store/ui/modal.service.ts` (lines 39-100)

**Issue:**
Manual modal stack manipulation is error-prone:
- Modal auto-close on high-priority modal open works but could miss edge cases
- No validation that modal being closed exists in stack
- Content transitions use setTimeout (line 205) which could fail silently

**Impact:**
- Modals could become "stuck" in stack if close fails
- Content transitions could leave stale state
- Difficult to debug modal state issues

**Symptoms to watch for:**
- Modal doesn't respond to close button
- Multiple modals visible simultaneously
- Modal content doesn't transition properly

**Safe modification:**
- Always use `isOpen()` check before closing
- Test auto-close behavior on high-priority opens
- Verify modal stack is clean after navigation
- Add debug logging to modal service

**Current test coverage:** Low (no unit tests for modal service)

---

### Join Flow State Persistence

**Files:**
- `src/store/JoinStore.ts` (storage methods)
- `src/pages/public-join/public-join.page.tsx` (sessionStorage usage)

**Issue:**
State is persisted to sessionStorage but not validated on restore:
```typescript
const stored = sessionStorage.getItem(STORAGE_KEY);
return stored ? JSON.parse(stored) : null;
```

If user manually edits sessionStorage or data is corrupted, invalid state loads without error.

**Impact:**
- User sees stale/corrupted data
- Form validation could fail unexpectedly
- Phone number format could be wrong
- Could cause join flow to fail mid-way

**Symptoms:**
- Stored data doesn't match current code structure
- Browser tab closed and reopened = corrupted state
- User reports "form data disappeared"

**Safe modification:**
- Always validate restored state against current schema
- Consider clearing storage if validation fails
- Log warnings when data doesn't match expected shape
- Add version field to stored data for migrations

---

### Timer/Interval Cleanup

**Resend Timer:**
The resend timer in multiple stores uses `setInterval` that must be cleaned up:

**Files:**
- `src/store/JoinStore.ts` (lines 699-720)
- `src/store/ui/join-flow.ui.ts` (lines 142-162)
- `src/store/ui/account.ui.ts` (lines 407-427)
- `src/store/EventJoinStore.ts` (lines 469-489)

**Current Safety:** Good - uses `stopResendTimer()` and cleanup in `willUnmount()`

**Risk:**
- If page unmounts before cleanup, timer continues running
- Calling `setInterval` multiple times without clearing previous could leak timers
- Navigation away could leave orphaned intervals

**Safe modification:**
- Always check `if (this.resendInterval)` before creating new interval
- Force stop timer in `cleanup()` method
- Test timer behavior on rapid navigation

---

## Scaling Limits

### No Pagination for Group Posts

**File:** `src/pages/group-home/group-home.page.tsx`

**Current:** Infinite scroll loads all posts into memory

**Limits:**
- If group has 1000+ posts, page becomes slow
- Memory usage grows unbounded
- Browser could run out of memory on old devices

**Scaling issue:**
- No windowing/virtualization of posts
- All post DOM nodes remain in memory
- Each post has full details loaded

**Fix approach:**
- Implement virtual scrolling (react-window)
- Keep only visible posts + buffer in DOM
- Lazy load post details (comments, reactions) on expand

---

### Scripture Caching

**File:** `src/store/domain/activities.domain.ts`

**Issue:**
Scripture is fetched but unclear if it's cached. If user opens same lesson twice, scripture fetches again.

**Impact:**
- Redundant API requests
- Slower lesson load times
- Wasted bandwidth

**Fix approach:**
- Implement caching with verse reference as key
- Add cache invalidation (if server data changes)
- Consider IndexedDB for persistent cache across sessions

---

## Security Considerations

### Phone Number Exposure in Logs

**Files:**
- Multiple stores with `console.error()` calls

**Issue:**
API errors containing phone numbers or user data could be logged. Example:
```typescript
console.error("Failed to verify code:", err);
```

Error might contain: `"Error: Invalid code for +1234567890"`

**Impact:**
- PII leak in browser console/logs
- Could be sent to analytics/logging services
- Visible to anyone with browser access

**Fix approach:**
- Sanitize error messages before logging
- Never log full phone numbers or verification codes
- Remove sensitive data from error objects
- Use error IDs instead of full error messages

---

### CSRF Protection

**File:** `src/lib/api-client.ts`

**Issue:**
API requests use `credentials: 'include'` for session cookies but no CSRF token in headers.

**Current safety:** Depends on server enforcing CSRF checks

**Risk:** If server doesn't properly validate CSRF, could be vulnerable

**Fix approach:**
- Verify server implements CSRF token validation
- Add CSRF token to request headers if not already done
- Implement SameSite cookie policy verification

---

### Environment Variables

**Files:**
- `src/lib/api-client.ts` (line 8)

**Issue:**
```typescript
const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:3001';
```

Fallback to hardcoded localhost could leak internal IPs in production if env var missing.

**Impact:**
- Accidental exposure of internal development URL
- Security misconfiguration goes unnoticed

**Fix approach:**
- Remove hardcoded fallback
- Throw error if env var not set
- Add validation at app startup

---

## Known Bugs & Edge Cases

### Already-Member Error Handling

**File:** `src/store/JoinStore.ts` (lines 765-776)

**Issue:**
```typescript
if (err instanceof Error && err.message.includes("already a member")) {
  // Treat as success — set membership so confirmation page can redirect
  this.groupMembership = {
    id: "",
    role: "member",
    joinedAt: new Date().toISOString(),
    groupName: this.groupPreview?.name || "",
  };
  return;
}
```

Checking error message string is fragile. If API changes error message, code breaks silently.

**Impact:**
- Brittle error detection
- If error message changes, already-member flow breaks
- Users see wrong message/flow

**Fix approach:**
- Use error code/status instead of message text
- Implement error type/enum on server
- Add tests for already-member scenario

---

### Lesson Preview vs Activity Duplication

**Files:**
- `src/store/ui/lesson-preview.ui.ts` (613 lines)
- `src/store/ui/lesson-activity.ui.ts` (797 lines)

**Issue:**
These stores have nearly identical code for managing lesson steps, scripture, reading, video, etc. Duplicated logic makes maintenance harder.

**Impact:**
- Bug fixes must be made in both places
- Easy to miss one when updating
- Inconsistent behavior between preview and activity
- Code bloat

**Fix approach:**
- Extract shared lesson stepping logic into base class or mixin
- Create shared scripture/video utilities
- Inherit common behavior in both UI stores
- Reduces code from ~1400 to ~700 lines

---

## Dependencies at Risk

### Lexical Editor Version

**Package:** `@lexical/react`, `@lexical/list`, `lexical@0.39.0`

**Risk:** Lexical 0.x is pre-1.0 and could have breaking changes

**Impact:** If app uses Lexical for content editing, updates could break functionality

**Mitigation:** Lock version in package.json (already done)

**Plan:** Monitor lexical releases, plan migration to 1.0 when stable

---

### Sharp for Image Processing

**Package:** `sharp@0.34.5`

**Issue:** Sharp is in devDependencies but may be needed at runtime if image processing happens client-side

**Impact:** Vite may not bundle sharp properly, could cause "module not found" in production

**Fix:** If used at runtime, move to dependencies

---

## Monitoring & Observability

### No Error Tracking

**Issue:** Application has no error tracking service (Sentry, LogRocket, etc.)

**Blind spots:**
- Production errors go undetected
- Users experience failures without developers knowing
- No error trends/patterns visible
- Difficult to debug user-reported issues

**Impact:** CRITICAL for production app

**Fix approach:**
- Integrate error tracking service (Sentry recommended)
- Capture and report unhandled errors
- Track API errors separately
- Monitor performance metrics

---

### Missing Loading States

**Files:** Various pages

**Issue:** Some async operations don't show loading indicators

**Locations:**
- Session load in App.tsx
- Modal content loads
- API errors sometimes show but not all

**Impact:** Users unsure if action succeeded or failed

---

## Type Safety

### Generic Type Usage

**Total `as any`/`as unknown` casts:** 134 instances in src/

**Hotspots:**
- API error handling casts errors to `ApiError`
- Lesson activity data transformations
- Component prop destructuring

**Impact:** Missed type errors, harder to refactor

**Priority:** Medium (not critical but improves code quality)

---

## Recommendations by Priority

### Priority: CRITICAL
1. Add error boundary to App.tsx
2. Implement error tracking service
3. Add comprehensive unit tests for stores
4. Fix JSON parsing to validate schema

### Priority: HIGH
1. Break down large store files
2. Remove `as any` type casts
3. Add test coverage for modal service
4. Implement scripture caching

### Priority: MEDIUM
1. Add error handling for lesson preview load
2. Implement lazy loading for scripture
3. Add virtual scrolling for group posts
4. Audit PII in error logs

### Priority: LOW
1. Refactor duplicated lesson stepping logic
2. Add request debouncing to infinite scroll
3. Update environment variable fallback
4. Add Lexical migration plan

---

*Concerns audit: 2025-03-16*
