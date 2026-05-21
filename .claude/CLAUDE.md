# Claude Code Instructions for MakeReady

## 🏗️ Architecture Overview

This is a **monorepo** with four applications sharing a single git repository. Before making ANY changes, you MUST:

1. **Understand the multi-app structure**: Four apps (client, server, iphone, capture) in one repo
2. **Read the architecture spec**: `.project/ARCHITECTURE_SPEC.md`
3. **Use the appropriate sub-agent** for the task
4. **Follow the component patterns** exactly as specified
5. **Never violate separation of concerns**

## 🗂️ Project Structure

This monorepo contains **four applications**:

- **`/client`** - Web app (Laravel 11 + Vue 3 + Pinia + PrimeVue)
- **`/server`** - Backend API (Express + Prisma + PostgreSQL)
- **`/iphone`** - iOS app (Swift/SwiftUI)
- **`/capture`** - Screenshot & visual regression tool (React + Vite + Playwright)

Each app has its own `.claude/CLAUDE.md` with app-specific instructions. The root `.claude/CLAUDE.md` (this file) covers cross-app concerns only.

## 🔗 App Responsibilities & How They Connect

### Data Flow

```
Browser → Client (Laravel :8000) → Server (Express :3010) → PostgreSQL / Cloudflare / Twilio / etc.
iPhone App ──────────────────────→ Server (Express :3010) → PostgreSQL / Cloudflare / Twilio / etc.
Capture Tool → Client (Playwright) & iPhone Simulator (screenshots)
```

### Server (`/server`) — Single Source of Truth

All business logic, data, and external integrations live here. Client and iPhone are consumers only.

- **Stack:** Express + Prisma + PostgreSQL (55 models, 43 route modules, 28 services)
- **Auth:** Google OAuth (admins/leaders), phone SMS verification (members via Twilio)
- **External integrations:** Twilio (SMS/verify), Cloudflare R2 (media storage) + Stream (video), API.Bible, Claude AI (tagging/alt text), APNs (push notifications)
- **RBAC:** Org-scoped roles and permissions (Super Admin, Owner, Admin, Group Leader, Member)
- **Key domains:** Groups, study programs, lessons, activities, enrollments, members, events, posts, Bible content, media library, notes

### Client (`/client`) — Web Frontend + API Proxy

Laravel serves Blade templates with Vue 3 "islands" mounted into server-rendered pages.

- **Stack:** Laravel 11 + Vue 3 + Pinia + PrimeVue + SCSS + ApexCharts
- **Architecture:** Vue "islands" — interactive Vue components mounted into server-rendered Blade pages (not a full SPA except admin)
- **Admin SPA:** Vue Router at `/admin/*` with Pinia stores (domain stores for API data, UI stores for view state)
- **API proxy:** Proxies admin API calls via `/admin/api/{path}` → server at `:3010`
- **Session management:** Client has its OWN Laravel sessions, separate from server sessions — forwards `connect.sid` cookies to the server
- **Member-facing:** Phone login, group join, lesson playback (video, reading, SOAP input)
- **Admin-facing:** Group/program/member management, analytics dashboard, content creation/editor

### iPhone (`/iphone`) — Native iOS App

Mirrors admin/leader functionality from client, connects directly to server API (no client proxy).

- **Stack:** Swift 5 + SwiftUI (iOS 17.0+), @Observable + Actions pattern
- **State:** Centralized `AppState.shared` singleton with normalized entity stores, disk-cached for offline support
- **Auth:** Google OAuth via ASWebAuthenticationSession → exchanges code with server directly
- **Unique features:** Custom video recorder with teleprompter, full Bible reader with search/highlighting, push notifications (APNs) with deep linking
- **Components:** 122 custom SwiftUI components, 239 page files

### Capture (`/capture`) — Internal Dev Tool

Visual regression testing and screenshot capture. Not a production app.

- **Stack:** React + Vite (frontend on :5950) + Express (backend on :5951) + Playwright
- **Purpose:** Manifest-driven screenshot capture for both client (via Playwright) and iPhone (via simulator)
- **Structure:** JSON fixtures define screens, viewports, and expected output per platform
- **No separate deployment** — lives in workspace for dev use only

### Cross-App Impact Guide

Use this table when making changes to understand which apps may be affected:

| Change type | Apps affected | What to check |
|---|---|---|
| Database schema change | server → client, iphone | Both consumers use the same API responses |
| New API endpoint | server + whichever consumer uses it | Client proxy config if admin route |
| Auth flow change | server + client + iphone | Client proxies sessions; iPhone uses direct OAuth |
| UI component (Vue) | client only | Histoire/Storybook stories |
| Study/lesson content model | server → client (lesson player) + iphone (lesson views) | Both render the same content differently |
| Push notifications | server + iphone | Server sends via APNs; iPhone handles deep links |
| Media/video upload | server (R2/Stream) → client + iphone | Both consume Cloudflare URLs |
| Screenshot fixtures | capture only | Update manifest and re-run captures |

---

## 🎯 Decision Flow

```
Task: Create something

1. Is it a UI component?        → Use `/component` (client)
2. Is it a page?                → Use `/page` (client)
3. Is it a store?               → Use `/store` (client)
4. Is it an API endpoint?       → Use `/api` (server)
5. Is it a complete feature?    → Use `/feature` (coordinates multiple)
6. Need to review/refactor?     → Use `/architect`
7. Need Postman collection?     → Use `/postman`
```

---

## 📁 Folder Structure

```
makeready/                   # Monorepo root (.git here)
├── .claude/                # Root-level Claude config (this file)
├── .project/               # Architecture documentation
├── client/                 # Web app - Laravel + Vue 3
│   ├── .claude/           # Client-specific Claude instructions
│   ├── app/               # Laravel controllers, services, middleware
│   ├── routes/            # Laravel route definitions (web.php)
│   ├── resources/
│   │   ├── js/            # Vue components, islands, stores
│   │   ├── css/           # SCSS styles
│   │   └── views/         # Blade templates
│   ├── ui/                # UI components (primitive/domain/layout)
│   ├── util/              # Client utilities (cva, classnames, when)
│   └── src/               # Pages, MobX stores, API client
├── server/                # Backend API
│   ├── .claude/           # Server-specific Claude instructions
│   ├── src/
│   │   ├── routes/        # Express routes (43 modules)
│   │   ├── services/      # Business logic (28 modules)
│   │   └── middleware/    # Auth, API key, bot guard, logging
│   ├── prisma/            # Database schema (55 models)
│   └── schema/            # YAML source of truth for DB schema
├── iphone/               # iOS app
│   ├── .claude/          # iPhone-specific Claude instructions
│   └── MakeReady/        # Swift project
│       ├── State/        # AppState, Actions, EntityStore, Models
│       ├── Pages/        # SwiftUI pages (239 files)
│       ├── Components/   # SwiftUI components (122 files)
│       └── Services/     # Bible, search, push notifications
└── capture/             # Screenshot tool
    ├── fixtures/        # Screenshot specs & output
    ├── runners/         # Platform-specific capture scripts
    ├── src/             # React frontend
    └── server.mjs       # Express backend
```

---

## 📖 Documentation Files

- `.project/ARCHITECTURE_SPEC.md` - Complete architecture specification
- `.project/MONOREPO_GUIDE.md` - Monorepo patterns and setup
- `client/DESIGN_SYSTEM.md` - Design system guidelines
- `client/ICONS.md` - Icon usage guide
