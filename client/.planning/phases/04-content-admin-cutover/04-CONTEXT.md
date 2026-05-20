# Phase 4: Content + Admin + Cutover - Context

**Gathered:** 2026-03-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Build lesson activity pages (video + SOAP journal), study home, preview pages, admin panel with full feature parity, 404/error pages, and execute production cutover from React SPA to Laravel on Railway.

</domain>

<decisions>
## Implementation Decisions

### Lesson Activity Page
- **Single page with Vue handling step transitions** — Blade renders the shell, one large Vue component manages all lesson steps client-side
- Full Vue lesson page island (not Blade per-step) — video, SOAP journal, and step navigation all in one Vue app
- HLS video via hls.js (already installed) in the VideoPlayer Vue component
- SOAP journal via Tiptap Vue component (BulletTextInput) — save behavior matches React app
- Lesson data loaded upfront by controller, passed as props to the Vue lesson island

### Admin Panel
- **Full feature parity** with the React admin page
- Whatever the React admin page does (member management, group settings, etc.) — replicate it
- Protected by member.auth middleware + leader role check

### Production Cutover
- **Replace in-place** — push Laravel to the same Railway service, replacing the React app
- **Keep React deployable** — archive/react-spa branch can be redeployed as rollback
- Update CI/CD workflow for Laravel build (already done in Phase 1)
- Environment variables already configured (Phase 1)

### Study Home, Previews, 404, Errors (Claude's Discretion)
- Study home: Blade page with lesson list, follows established controller + Blade pattern from Phase 3
- Study/lesson previews: Public routes (no auth), Blade-rendered for SSR
- 404 page: Blade template with shared layout
- Error handling: Laravel exception handler with user-friendly Blade error views

### Claude's Discretion
- Exact Vue lesson island component structure (how steps are organized internally)
- Tiptap configuration and toolbar options
- Admin page layout and organization
- Error page design
- Study code entry page
- Preview page data loading

</decisions>

<specifics>
## Specific Ideas

- Lesson page is the most complex page — it needs to feel smooth like an SPA for step transitions
- The React admin page source is at `archive/react-spa:src/pages/admin/`
- Study home source at `archive/react-spa:src/pages/study-home/`
- Lesson source at `archive/react-spa:src/pages/lesson/`
- Preview sources at `archive/react-spa:src/pages/lesson-preview/` and `study-preview/`
- MCP API tools available for endpoint details

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- VideoPlayer Vue component at `resources/js/components/domain/video-player/`
- BulletTextInput Vue component at `resources/js/components/primitive/bullet-text-input/`
- All Blade components available for page composition
- ApiService with get/post/patch/upload methods
- Auth + Home Blade layouts
- Established controller → Blade → component pattern from Phase 3

### Established Patterns
- Controllers fetch all data upfront via ApiService
- Cookie forwarding on all responses
- Vue islands mount via data-vue attributes
- SCSS/BEM for all styling
- PHPUnit tests with Http::fake()

### Integration Points
- routes/web.php: Add study, lesson, preview, admin, and error routes
- resources/js/app.js: Register lesson island Vue component
- Blade layouts: lesson pages may need their own layout or use home layout
- Railway: same service, push triggers deploy

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-content-admin-cutover*
*Context gathered: 2026-03-18*
