# Technology Stack

**Analysis Date:** 2026-03-16

## Languages

**Primary:**
- TypeScript 5.6.3 - All source code in `src/`, `ui/`, `util/`, and `shared/` directories

**Supporting:**
- SCSS 1.93.2 - Component styling with modern-compiler API
- CSS3 - Global styles and Tailwind CSS

## Runtime

**Environment:**
- Node.js - No specific version pinned (check with team for recommended version)

**Package Manager:**
- npm - Lock file present (`package-lock.json`)

## Frameworks

**Core:**
- React 18.3.1 - UI framework in `src/App.tsx` and component structure
- React Router 6.26.2 - Navigation and routing in `src/App.tsx`
- MobX 6.13.2 - State management with Domain/Session/UI pattern in `src/store/`

**UI & Styling:**
- Tailwind CSS 3.4.15 - Utility-first CSS framework
- shadcn/ui (via Storybook component library)
- Radix UI primitives - Accessible component foundation (`@radix-ui/*` packages 1.x-2.x)
- Class Variance Authority 0.7.0 - Component variant management (custom wrapper in `util/cva.ts`)

**Forms & Validation:**
- React Hook Form 7.53.0 - Form state management in `src/pages/`
- Zod 3.23.8 - Schema validation
- @hookform/resolvers 3.9.0 - Zod resolver integration

**Editor:**
- Lexical 0.39.0 - Rich text editor library
- @lexical/react 0.39.0 - React bindings for Lexical
- @lexical/list 0.39.0 - List plugin for Lexical

**Media:**
- hls.js 1.6.15 - HLS (HTTP Live Streaming) video playback
- lucide-react 0.454.0 - Icon library
- react-icons 5.5.0 - Additional icon library
- vite-plugin-svgr 4.5.0 - SVG import as React components

**Utilities:**
- clsx 2.1.1 - Conditional classname utility
- tailwind-merge 2.5.4 - Tailwind class merging (used in custom CVA wrapper)

## Testing & Development

**Build Tool:**
- Vite 5.4.10 - Modern build tool configured in `vite.config.ts`
- @vitejs/plugin-react 4.3.4 - React fast refresh plugin

**Test Frameworks:**
- Vitest 4.0.17 - Unit/integration test runner configured in `vitest.config.ts`
- @vitest/coverage-v8 4.0.17 - Code coverage with V8
- Playwright 1.57.0 - End-to-end testing configured in `playwright.config.ts`
- @testing-library/react 16.3.1 - React component testing utilities
- @testing-library/jest-dom 6.9.1 - DOM matchers for assertions
- @testing-library/user-event 14.6.1 - User interaction simulation
- happy-dom 20.3.1 - Lightweight DOM implementation for tests
- jsdom 27.0.1 - Alternative DOM implementation for tests
- Mock Service Worker (msw) 2.12.7 - API mocking for tests

**UI Testing & Storybook:**
- Storybook 8.4.7 - Component documentation and testing
- @storybook/react-vite 8.4.7 - Storybook + Vite integration
- @storybook/react 8.4.7 - React support for Storybook
- @storybook/addon-essentials 8.4.7 - Essential Storybook addons
- @storybook/addon-interactions 8.4.7 - Interaction testing in Storybook
- @storybook/addon-links 8.4.7 - Story linking addon
- @storybook/addon-onboarding 8.4.7 - Onboarding addon
- @storybook/addon-themes 8.4.7 - Theme switching addon
- @storybook/blocks 8.4.7 - Doc blocks for Storybook
- @storybook/test 8.4.7 - Test utilities for stories

**Linting & Code Quality:**
- ESLint 9.15.0 - JavaScript/TypeScript linting
- @typescript-eslint/parser 8.15.0 - TypeScript parser for ESLint
- @typescript-eslint/eslint-plugin 8.15.0 - TypeScript-specific ESLint rules
- eslint-plugin-react-hooks 5.0.0 - React hooks linting rules
- eslint-plugin-react-refresh 0.4.14 - Fast refresh linting
- globals 17.0.0 - Global variable definitions

**CSS Processing:**
- PostCSS 8.4.49 - CSS transformation
- Autoprefixer 10.4.20 - Vendor prefix automation
- tailwindcss-animate 1.0.7 - Animation utilities for Tailwind
- sass-embedded 1.93.2 - SCSS compiler (modern Sass implementation)

**Asset Processing:**
- sharp 0.34.5 - Image processing and optimization

**Server:**
- Express 4.22.1 - HTTP server for production serving in `server.js`
- serve 14.2.5 - Static file serving (also installed as alternative)

## Configuration

**Environment:**
- Environment variables configured via `import.meta.env.VITE_*` pattern (Vite)
- Key variable: `VITE_API_URL` - Backend API URL (defaults to `http://localhost:3001` in dev, `https://api.makeready.org` in production)
- `.env` file present - Contains development configuration
- `.env.production` file present - Contains production configuration

**Build:**
- `vite.config.ts` - Vite build configuration with React plugin, path aliases, and SCSS
- `vitest.config.ts` - Test runner configuration with happy-dom environment
- `tsconfig.json` - TypeScript compiler options with path aliases for `@/*`, `ui/*`, `util/*`, `shared/*`
- `tailwind.config.js` - Tailwind CSS theme and plugin configuration
- `postcss.config.js` - PostCSS plugin configuration (Tailwind, Autoprefixer)
- `eslint.config.js` - ESLint rules and configuration
- `playwright.config.ts` - E2E test configuration (base URL: `http://localhost:4173`)

**Path Aliases (tsconfig.json & vite.config.ts):**
- `@/*` → `./src/*` - Application source
- `ui/*` → `./ui/*` - UI components and stories
- `util/*` → `./util/*` - Utilities and hooks
- `shared/*` → `./shared/*` - Shared types and constants

## Platform Requirements

**Development:**
- Node.js with npm
- Modern browser with ES2020+ support (Vite target)

**Production:**
- Node.js runtime for Express server (`server.js`)
- Modern browser with ES2020+ JavaScript support
- HTTPS connection to API endpoint (`https://api.makeready.org`)

**Browser Support:**
- Modern browsers (ES2020+ required by Vite)
- Mobile browsers (iOS Safari, Chrome mobile for group joining flows)

---

*Stack analysis: 2026-03-16*
