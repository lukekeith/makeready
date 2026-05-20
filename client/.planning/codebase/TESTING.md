# Testing Patterns

**Analysis Date:** 2025-03-16

## Test Framework

**Runner:**
- Vitest v4.0.17
- Config: `vitest.config.ts`
- Environment: happy-dom (lightweight DOM simulation)

**Assertion Library:**
- Vitest's built-in assertion syntax (`expect()`)
- Testing Library integration for React component testing
- Playwright for E2E testing

**Run Commands:**
```bash
npm run test              # Run tests in watch mode
npm run test:run         # Run all tests once
npm run test:ci          # Run with coverage and verbose reporter
npm run test:ui          # Interactive UI for test exploration
npm run test:e2e         # Run Playwright E2E tests
npm run test:e2e:ui      # E2E tests in interactive UI mode
npm run test:e2e:headed  # E2E tests with visible browser
```

## Test File Organization

**Location:**
- Unit tests co-located with source code (same folder as the code being tested)
- E2E tests in `e2e/` directory at project root

**Naming:**
- `.test.ts` or `.test.tsx` suffix (e.g., `classnames.test.ts`, `button.test.tsx`)
- E2E test files: `.spec.ts` suffix (e.g., `critical-paths.spec.ts`)

**Directory Structure:**
```
client/
├── util/__tests__/              # Unit tests for utilities
│   ├── classnames.test.ts
│   ├── when.test.ts
├── ui/components/primitive/button/
│   ├── button.tsx              # Component code
│   ├── button.scss
│   └── button.test.tsx          # Test co-located with component
├── test/                         # Global test setup
│   ├── setup.ts                 # Vitest setup file
│   └── mocks/
│       ├── server.ts            # MSW server setup
│       └── handlers.ts          # API mock handlers
└── e2e/                          # End-to-end tests
    ├── fixtures/
    │   └── test-data.ts         # E2E test constants
    └── tests/
        ├── smoke/
        │   └── critical-paths.spec.ts
        └── join-flow/
            ├── phone-verification.spec.ts
            └── study-join.spec.ts
```

## Test Structure

**Suite Organization:**
```typescript
import { describe, it, expect } from 'vitest';
import { classnames } from '../classnames';

describe('classnames utility', () => {
  describe('basic usage', () => {
    it('combines multiple class names', () => {
      expect(classnames('foo', 'bar')).toBe('foo bar');
    });

    it('combines single class name', () => {
      expect(classnames('foo')).toBe('foo');
    });
  });

  describe('filtering falsy values', () => {
    it('filters out false', () => {
      expect(classnames('foo', false, 'bar')).toBe('foo bar');
    });
  });
});
```

**Patterns:**
- `describe()`: Group related tests by feature/scenario
- `it()`: Single test case with clear description
- Nested describe blocks for organizing related test groups
- No setup/teardown needed for utility tests (see global setup below)

## Mocking

**Framework:** MSW (Mock Service Worker) v2.12.7

**Global Setup:**
- File: `test/setup.ts`
- Executed before all tests (Vitest config `setupFiles: ['./test/setup.ts']`)
- Sets up:
  - MSW server for API mocking
  - Global mocks (window.matchMedia, ResizeObserver, IntersectionObserver)
  - Test library DOM matchers

**API Mocking Pattern:**
```typescript
// test/mocks/handlers.ts - Define all API handlers
import { http, HttpResponse } from 'msw';

const API_URL = 'http://localhost:3001';

export const handlers = [
  http.get(`${API_URL}/api/members/:id`, ({ params }) => {
    const { id } = params;
    return HttpResponse.json({
      success: true,
      member: { id, name: 'Test Member' }
    });
  }),

  http.post(`${API_URL}/api/members`, async ({ request }) => {
    const body = await request.json() as { phoneNumber: string };
    if (!body.phoneNumber) {
      return HttpResponse.json(
        { error: 'Phone number required' },
        { status: 400 }
      );
    }
    return HttpResponse.json({ success: true, id: 'new-id' });
  }),
];

// test/mocks/server.ts - Initialize MSW server
import { setupServer } from 'msw/node';
import { handlers } from './handlers';

export const server = setupServer(...handlers);
```

**Test File Usage:**
```typescript
import { expect, test } from 'vitest';
import { server } from './mocks/server';

// Handlers are automatically registered from test/setup.ts
test('fetches user successfully', async () => {
  const response = await fetch('http://localhost:3001/api/members/123');
  const data = await response.json();
  expect(data.success).toBe(true);
});

// Override handler for specific test if needed
test('shows error on invalid input', async () => {
  server.use(
    http.post('http://localhost:3001/api/members', () => {
      return HttpResponse.json(
        { error: 'Server error' },
        { status: 500 }
      );
    })
  );

  const response = await fetch('http://localhost:3001/api/members', {
    method: 'POST',
    body: JSON.stringify({})
  });
  expect(response.status).toBe(500);
});
```

**Global Browser API Mocks:**
```typescript
// From test/setup.ts
// Mock window.matchMedia for responsive design tests
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: vi.fn().mockImplementation((query: string) => ({
    matches: false,
    media: query,
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
  })),
});

// Mock ResizeObserver (used by Radix UI components)
global.ResizeObserver = vi.fn().mockImplementation(() => ({
  observe: vi.fn(),
  unobserve: vi.fn(),
  disconnect: vi.fn(),
}));

// Mock IntersectionObserver
global.IntersectionObserver = vi.fn().mockImplementation(() => ({
  observe: vi.fn(),
  unobserve: vi.fn(),
  disconnect: vi.fn(),
}));
```

**What to Mock:**
- External APIs (via MSW)
- Browser APIs that don't work in happy-dom (ResizeObserver, IntersectionObserver, matchMedia)
- Optional: Component callbacks and event handlers

**What NOT to Mock:**
- Internal component behavior
- Utility functions (test them directly)
- Store actions (test them in isolation)

## Fixtures and Factories

**Test Data:**
- E2E test data: `e2e/fixtures/test-data.ts`
- Constants for routes and test groups:
  ```typescript
  export const TEST_ROUTES = {
    home: '/',
    join: '/join',
    joinGroup: (code: string) => `/join-code/${code}`,
  };

  export const TEST_GROUPS = {
    valid: { code: 'TEST01', id: 'test-group-id' },
    invalid: { code: 'INVALID' },
  };
  ```

**Location:**
- `e2e/fixtures/test-data.ts`: E2E constants and test data
- Test files reference shared fixtures instead of hardcoding values

## Coverage

**Requirements:**
- Minimum thresholds (from `vitest.config.ts`):
  - Lines: 50%
  - Functions: 50%
  - Branches: 30%
  - Statements: 50%

**View Coverage:**
```bash
npm run test:ci              # Runs with coverage reporter
# Output goes to coverage/ directory
# Open coverage/index.html in browser for detailed report
```

**Coverage Config:**
```typescript
coverage: {
  provider: 'v8',
  reporter: ['text', 'json', 'html', 'lcov'],
  exclude: [
    'node_modules/',
    'dist/',
    '**/*.stories.tsx',      // Storybook stories not counted
    '**/*.d.ts',
    'test/**',               // Test setup files not counted
    'e2e/**',                // E2E tests not counted
    '.storybook/**',
    'storybook-static/**',
    '*.config.{js,ts}',      // Config files not counted
    'server.js',
  ],
  thresholds: {
    lines: 50,
    functions: 50,
    branches: 30,
    statements: 50,
  },
}
```

## Test Types

**Unit Tests:**
- Location: Co-located with source code (e.g., `util/__tests__/`, `ui/components/primitive/button/`)
- Scope: Test single functions/components in isolation
- Approach: Direct function/component testing with mocked dependencies
- Examples: `classnames.test.ts`, `when.test.ts`
- No component mounting for utility tests
- Full DOM for component tests (using Testing Library)

**Integration Tests:**
- Not explicitly structured currently
- Could be added as separate `*.integration.test.ts` files
- Would test store interactions, API integration, multi-component flows

**E2E Tests:**
- Framework: Playwright
- Location: `e2e/` directory
- Config: `playwright.config.ts`
- Target: Real application behavior across full flows
- Approach: Browser automation testing against running app
- Examples:
  - `e2e/tests/smoke/critical-paths.spec.ts` - Critical user flows
  - `e2e/tests/join-flow/phone-verification.spec.ts` - Join flow validation

**E2E Test Pattern:**
```typescript
import { test, expect } from '@playwright/test';
import { TEST_ROUTES, TEST_GROUPS } from '../../fixtures/test-data';

test.describe('Smoke Tests - Critical Paths', () => {
  test('homepage loads successfully', async ({ page }) => {
    await page.goto(TEST_ROUTES.home);

    // Check that page loads
    await expect(page).toHaveTitle(/MakeReady/i);

    // Check content is visible
    const body = page.locator('body');
    await expect(body).toBeVisible();
  });

  test('join group page shows error for invalid code', async ({ page }) => {
    await page.goto(TEST_ROUTES.joinGroup(TEST_GROUPS.invalid.code));

    // Wait for API response
    await page.waitForLoadState('networkidle');

    // Check state after error
    const body = page.locator('body');
    await expect(body).toBeVisible();
  });
});
```

## Common Patterns

**Async Testing - Utility Functions:**
```typescript
describe('when utility', () => {
  it('returns element when condition is true', () => {
    const result = when(true, 'hello');
    expect(result).toBe('hello');
  });

  it('returns null when condition is false', () => {
    const result = when(false, 'hello');
    expect(result).toBeNull();
  });
});
```

**Async Testing - API Calls:**
```typescript
// Tests that call API (mocked by MSW)
test('fetches user data successfully', async () => {
  const response = await apiClient.get<User>('/api/members/123');
  expect(response.id).toBe('123');
  expect(response.name).toBe('Test Member');
});

test('handles API errors', async () => {
  server.use(
    http.get('http://localhost:3001/api/members/:id', () => {
      return HttpResponse.json({ error: 'Not found' }, { status: 404 });
    })
  );

  try {
    await apiClient.get('/api/members/invalid');
    expect.fail('Should have thrown');
  } catch (error) {
    expect(error).toBeDefined();
  }
});
```

**Error Testing - Validation:**
```typescript
describe('phone number validation', () => {
  it('accepts valid E.164 format', () => {
    const isValid = validatePhoneNumber('+15551234567');
    expect(isValid).toBe(true);
  });

  it('rejects invalid format', () => {
    const isValid = validatePhoneNumber('5551234567');
    expect(isValid).toBe(false);
  });

  it('handles null/undefined', () => {
    expect(validatePhoneNumber(null)).toBe(false);
    expect(validatePhoneNumber(undefined)).toBe(false);
  });
});
```

**Conditional Class Testing:**
```typescript
it('works with && operator for conditional classes', () => {
  const isActive = true;
  const isDisabled = false;
  expect(classnames(
    'btn',
    isActive && 'btn--active',
    isDisabled && 'btn--disabled'
  )).toBe('btn btn--active');
});

it('works with ternary operator', () => {
  const isLarge = true;
  expect(classnames(
    'btn',
    isLarge ? 'btn--lg' : 'btn--sm'
  )).toBe('btn btn--lg');
});
```

## Test Skip Patterns

**Test-Only Rules (from eslint.config.js):**
```javascript
{
  files: ['**/*.test.{ts,tsx}', 'e2e/**/*.ts', 'test/**/*.ts'],
  rules: {
    '@typescript-eslint/no-explicit-any': 'off',    // any allowed in tests
    'no-console': 'off',                             // console.log allowed
  },
}
```

**CI Configuration:**
```typescript
// playwright.config.ts
forbidOnly: !!process.env.CI,           // Skip .only() tests in CI
retries: process.env.CI ? 2 : 0,        // Retry flaky tests in CI
workers: process.env.CI ? 1 : undefined, // Sequential in CI, parallel locally
```

## Storybook as Testing Tool

**Stories act as visual tests:**
- Every UI component has a Storybook story
- Stories show component variants and states
- Stories serve as documentation and visual regression tests
- Located in `ui/stories/components/[category]/`

**Story Pattern:**
```typescript
import type { Meta, StoryObj } from '@storybook/react'
import { Button, ButtonCva } from '../../../components/primitive/button/button'

const meta = {
  title: 'Primitive/Button',
  component: Button,
  parameters: {
    layout: 'centered',
    backgrounds: { default: 'dark' },
  },
  tags: ['autodocs'],
  argTypes: {
    variant: {
      control: 'select',
      options: Object.keys(ButtonCva.variant),
    },
  },
} satisfies Meta<typeof Button>

export default meta
type Story = StoryObj<typeof meta>

export const Primary: Story = {
  args: {
    variant: ButtonCva.variant.Primary,
    label: 'Click me',
  },
};

export const Secondary: Story = {
  args: {
    variant: ButtonCva.variant.Secondary,
    label: 'Secondary action',
  },
};
```

---

*Testing analysis: 2025-03-16*
