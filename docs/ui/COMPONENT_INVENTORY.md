# Component Inventory & Variant Matrices

Companion to [`DESIGN_SYSTEM_PRD.md`](./DESIGN_SYSTEM_PRD.md). This is the canonical catalog the design system must cover. Goal: **catalog ⊇ (web client UI ∪ iPhone UI)** so any group-leader screen is assembled from these.

Legend — **Status**: ✅ exists in `/client` · 🟡 partial / needs extension · 🔴 net-new (port from iOS) · 📦 from iOS (parity source).
Every interactive component supports states: `default · hover · focus-visible · active/pressed · disabled · loading` (+ `error/success` for inputs).

---

## 1. Primitives

| Component | Status | Variants | Sizes | Notes / parity |
|---|---|---|---|---|
| Button | 🟡 (CSS-only) | primary, secondary, ghost, outline, destructive, white, link, link-muted, jump, jump-primary | sm, md, lg, icon; mode: block, action | Wrap as Vue `<Button>` w/ CVA; iOS `.purple/.white/.whitePurple`. Icon + label, icon-only. |
| IconButton | 🟡 | default, brand, white, blur (circle) | sm, md, lg, 48, 64 | iOS ActionButton `.circleBlur 64`, `.swipeLarge 48`. |
| Text / Heading | 🔴 | display, title, heading, subheading, lead, body, body-strong, caption, overline/label | — | Maps to semantic text styles (PRD §6.2) + iOS Typography.swift. |
| Link | 🔴 | default, muted, inline | — | Accent `#5680ff`. |
| Icon | 🟡 | (Lucide set, mapped to iOS names) | xs16, sm20, md24, lg32 | `IconHome/People/Library/Calendar`. |
| Avatar | 🟡 | user, group (circle), fallback initials | sm36, md48, lg72, xl | Image w/ fallback. |
| Badge / Tag / Chip | 🟡 | neutral, brand, error, warning, success, indigo; dot variant | sm, md | Status badges ("UNCONFIRMED"). FilterChip is interactive variant. |
| Divider | 🔴 | horizontal, vertical, inset | — | white-10 hairline. |
| Spinner | 🟡 | inline, overlay | sm, md, lg | iOS CardSpinnerOverlay. |
| ProgressBar | 🟡 | linear, determinate/indeterminate | — | Lesson/theme progress. |
| Skeleton / Shimmer | 🔴 | block, text, circle, card | — | iOS ShimmerView + SkeletonCard*. |
| Image | 🔴 | cover, contain, rounded, ratio (1:1, 3:2, portrait) | — | With fallback + loading shimmer. |
| Toggle / Switch | 🟡 | — | sm, md | reka-ui. |
| Checkbox | 🔴 | — | sm, md | reka-ui. |
| Radio | 🔴 | — | sm, md | reka-ui. |
| Card (base) | 🟡 | flat, elevated, frosted, selectable | — | Frosted = `--surface-overlay`. Parent/child radius (card-depth.scss). |

---

## 2. Forms

| Component | Status | Variants / props | Notes |
|---|---|---|---|
| TextInput | 🟡 (CSS-only) | default, error, success; w/ prefix/suffix icon | Map height → `--control-h-md`; tokenize. |
| Textarea / MultilineInput | 🔴 | autosize | iOS MultilineTextInput / LargeTextInput. |
| SearchField | 🔴 | with clear button | iOS SearchField. |
| Select / MenuInput | 🔴 | single, multi | reka-ui dropdown. iOS MenuInput. |
| DatePickerField | 🔴 | date, date range | iOS DatePickerField. |
| ToggleControl | 🔴 | labeled switch row | iOS ToggleControl. |
| TagInput | 🔴 | — | iOS TagInput. |
| AgeRangeInput | 🔴 | min/max | iOS AgeRangeInput. |
| RichText / MarkdownEditor | 🟡 | toolbar, block styles | iOS RichTextInput/MarkdownEditor/BlockStyleEditor. Reuse Marked/Turndown. |
| BulletTextInput | ✅ | size: Default/Large | Keep. |
| VerifyCode | ✅ | size, theme, mode, length | Keep. |
| Digit / Keypad | ✅ | Digit/Asterisk/Hashtag/Backspace | Keep. |
| FieldGroup | 🔴 | — | Label + control + help/error wrapper. iOS FieldGroup. |
| Label / HelpText / ErrorText | 🟡 | — | Formalize as components. |
| KeyboardToolbar | 🔴 | — | Input accessory bar (iOS). |
| MediaPicker / CoverImagePicker / CameraCapture | 🔴 | — | iOS media inputs. |

---

## 3. Layout & containers

| Component | Status | Notes |
|---|---|---|
| AppShell | 🔴 | Header + scroll content + bottom TabBar + safe-area insets + optional FAB. |
| Page / Screen | 🟡 | Page padding via `--page-pad-x`, max-width. |
| Section | 🔴 | Titled section w/ spacing token. |
| Stack / VStack / HStack | 🔴 | Flex helpers w/ gap tokens. |
| Grid | 🔴 | Responsive card grid (mini cards). |
| FlowLayout | 🔴 | Wrapping chips/tags. iOS FlowLayout. |
| Scroll container | 🔴 | Momentum, overscroll-contain, hidden scrollbar. |
| Spacer / Container / Panel | 🔴 | Frosted panel = `--surface-overlay`. |
| Sticky header | 🟡 | Collapses on scroll (parity). |
| List | 🔴 | Plain + dividered. |
| SectionedList | 🔴 | iOS SectionedTableView. |
| SearchableList | 🔴 | iOS SearchableList; w/ AlphabetScrubber option. |

---

## 4. Panels / Cards — type-specific (iOS parity)

Each card type ships in **Row** and **Mini** sizes + a **Skeleton** variant. Data-driven via documented props (capture shapes in `AUDIT_INTAKE.md`).

| Card | Status | Row spec (from iOS) | Mini spec | States |
|---|---|---|---|---|
| CardStudy | 🔴 | 140h, portrait img right 72×108, title 17 bold, desc 13/70% 2-line, DataComponents | 120×188, img top 120×114, title 12 bold | default, pending (`#201B48` + animated border), unconfirmed badge |
| CardEvent | 🔴 | 140h, date block left 80×116 (28 bold day + 11 month), title 17 bold | 120×188, date top 120×96 | default |
| CardGroup | 🔴 | 104h, circle img 72×72 left, count metadata | 120×188, 72×72 circle centered | default, selected (purple-80 + check, animated) |
| CardVideo | 🔴 | 140h, thumb 116×116 left, title 17 bold, category | 120×188, thumb top + 40×40 play overlay | default |
| CardMember | 🔴 | Avatar + name + role/meta | — | default, pending |
| CardActivity | 🔴 | Icon + activity text + timestamp | — | feed item |
| CardEnrollment | 🔴 | Status + schedule | — | + skeleton |
| CardPost / Announcement | 🔴 | Author + body + media | — | + skeleton |
| CardSearchResult | 🔴 | Type-tagged result | — | — |
| KPI card | 🔴 | Number + label, tappable | — | iOS Kpi. |
| **SwipeableCard** wrapper | 🔴 | Progressive action reveal on swipe | — | + SlideButton actions. iOS SwipeableCard/SlideButton/DirectionalPanGesture. |
| **DataComponent** | 🔴 | icon+value OR number+label, 16px gaps | — | Shared metadata unit across cards. |

---

## 5. Navigation

| Component | Status | Notes |
|---|---|---|
| TabBar (bottom) | 🟡 | 5 tabs + profile; active = brand, inactive = white-70. iOS NavBar. |
| PageHeader | 🟡 | Title + optional tab switcher + actions. iOS PageHeader. |
| TabSlider | 🔴 | Animated segmented tabs. iOS TabSlider. |
| PageTitle | 🔴 | Large title layout. |
| Slide navigation (SlideStack) | 🔴 | Hand-rolled push/pop, leading/trailing. iOS SlideStack — for nested detail/settings. |
| Breadcrumb | 🔴 | If needed (admin-like flows). |
| FilterChipDropdown | 🔴 | Filter row. iOS FilterChipDropdown. |
| Menus | 🔴 | Add, User, Hamburger, ActionCard, contextual. reka-ui menu/popover. |
| FAB / Add button | 🟡 | Header "+" / floating. |

---

## 6. Overlays & feedback

| Component | Status | Notes |
|---|---|---|
| Modal / Dialog | ✅ | `Dialog` (reka-ui, controlled `v-model:open`) + the Pinia store `dialog` type. Centered scale+fade via `.mp-dialog-*` motion tokens. |
| BottomSheet / Menu sheet | ✅ | `BottomSheet` (drag-to-dismiss) + `ActionMenu`; store `sheet`/`menu` types. Grabber + 96px dismiss threshold. |
| Fullscreen flow | ✅ | `openFullscreen`; for wizards (+ `transitionContent` loading bar). |
| Popover | ✅ | `Popover` (reka-ui anchored), `--z-popover`. |
| Tooltip | ✅ | `Tooltip` (reka-ui), delay + side. |
| Toast | ✅ | `toast.store.ts` → `showToast()`; rendered by ModalProvider (bottom queue, max 3, auto-dismiss 4s, optional action). |
| ErrorBanner | ✅ | `toast.store.ts` → `showBanner()`/`error()`; rendered by ModalProvider (top slide-down, 4s, tap-dismiss, retry). iOS ErrorBanner parity. |
| ConfirmationOverlay | ✅ | `ConfirmationOverlay` (composes Dialog; destructive variant). |
| Alert | ✅ | `Alert` (composes Dialog; Info/Error/Success/Warning tone). |
| EmptyState | ✅ | `EmptyState` (tokenized) — icon + title + body + CTA. |
| LoadingOverlay | ✅ | `LoadingOverlay` (Cover/Inline; composes Spinner). |

### How to add an overlay (recipe)

Two paths. **Controlled components** for self-contained, locally-driven overlays
(Dialog, BottomSheet, ActionMenu, Popover, Tooltip, Confirmation, Alert) — bind
`v-model:open` from local state; reka-ui handles focus-trap / scroll-lock / ESC.

**Store-driven** for app flows that need stacking, priority, a registry, or
wizard content-swaps (menus, sheets, fullscreen flows):

1. **Build a content component** — a plain `.vue` that renders inside the
   `ModalProvider` chrome and dismisses itself via the store
   (`useModalStore().closeTopmost()`). It receives no props; read app state from
   stores. (Example: `resources/js/components/overlay/overlay-demo-menu/`.)
2. **Register it** in `resources/js/modal-registry.ts` under a stable `contentId`.
3. **Open it** from anywhere:
   ```ts
   const modal = useModalStore()
   modal.openMenu('group-actions', 'demo-menu')   // bottom sheet of actions
   modal.openSheet('filters', 'filters-content')  // draggable sheet
   modal.openDialog('confirm', 'confirm-content') // centered, high-priority
   modal.openFullscreen('enroll', 'enroll-wizard')// flow
   modal.openPopover('info', 'info-content')      // anchored
   ```
   Each maps to a token-driven z-lane; `high` priority (dialog/fullscreen) closes
   `low` (menu/sheet/popover). `transitionContent(id, nextContentId)` swaps inner
   content with a loading bar for multi-step wizards.

**Ephemeral feedback** (never goes through the modal stack):
```ts
const toast = useToastStore()
toast.showToast({ message: 'Saved', tone: 'success' })
toast.showToast({ message: 'Archived', action: { label: 'Undo', onPress } })
toast.error("Couldn't send invite", retryFn)   // top banner, 4s, Retry
```

Mount **one** `<ModalProvider>` near the app root — it teleports the modal stack,
toasts, and banner to `<body>`, and owns ESC, backdrop dismiss, body-scroll lock,
and focus restore. Live demo: the `Overlays/Overlay Manager` story.

---

## 7. Data display

| Component | Status | Notes |
|---|---|---|
| DataComponent | 🔴 | (also §4) shared metadata unit. |
| WeekdayIndicator | 🔴 | Day-of-week selector. iOS WeekdayIndicator. |
| Calendar (split-month) | 🔴 | iOS SplitMonthCalendar + day cells + event list. |
| Charts | 🟡 | Donut, Vertical/Horizontal Bar, Line, HeatMap. Reuse ApexCharts; match iOS visuals. |
| QR code | ✅🟡 | iOS QRCodeGenerator/InviteQRCode. |
| StatusBadge | 🟡 | (see Badge) pending/confirmed/etc. |
| Heatmap (activity) | 🔴 | iOS HeatMapChart. |

---

## 8. Domain (group-leader parity)

Composed from the above; list = the screens that must be buildable (mirrors iOS `Pages/`). Each becomes a layout template (PRD §9) + a Histoire page story.

- **Auth:** phone entry, code verify, join-by-code. ✅ (tokenize)
- **Home/dashboard:** KPIs, weekly bar chart, activity heatmap, activity feed. 📦
- **Groups:** list, group home (posts wall, info, members, enrollments, invite), create/edit group. 📦
- **Members:** member list (searchable + scrubber), member profile / drawer, requests (respond modal), change membership. 📦
- **Enrollment wizard:** select group → select program → schedule → date → confirm; unenroll options. 📦 (fullscreen flow)
- **Library:** programs + media tabs, filters, sort, swipeable cards, infinite scroll. 📦
- **Program/study:** program home, create/edit, day editor, activity editors (read/exegesis/input/youtube), previews/highlight modal. 📦
- **Lesson player:** video / youtube / read / exegesis / input / complete steps + themed content + progress. ✅ (LessonIsland) — extend.
- **Calendar:** split-month + day events + schedule. 📦
- **Search:** global search, results by type, detail pages (lesson/event/post). 📦
- **Media:** library grid, media detail overlay, video player, recorder/teleprompter (web-feasible subset). 📦
- **Bible reader:** reader bridge/overlay, version menu, highlighting. 📦
- **Notifications:** feed. 📦

---

## 9. Interaction patterns to standardize (parity)

Document each as a reusable behavior (spec + tokenized motion):

- Swipe-to-reveal actions on rows/cards (SwipeableCard).
- Slide navigation push/pop (SlideStack), leading vs trailing.
- Pull-to-refresh.
- Long-press / press-and-hold (lesson pause; context actions).
- Drag-to-reorder (iOS Dragula/ReorderHelpers).
- Peek-scroll / rubber-band at content end (preview player).
- Bottom-sheet drag-to-dismiss.
- Tab switch transitions (motion.standard).

---

## 11. Invite, Share & Scoped Access (priority-feature additions)

Drives the two near-term features (PRD §9A). The **web client has almost none of these today** (only `invite-modal.scss` + `join-code-island`); iOS has the full set to port. Build data-driven against a scope descriptor `{ type: 'program' | 'lesson', id, role: 'member' | 'contributor', expiresAt }`.

| Component | Status | Notes / iOS source |
|---|---|---|
| InviteSheet / InvitePage | 🔴 | Code box + QR + copy-link + share + "invite friends". Ports iOS GroupInvitePage / StudyInvitePage. Overlay (bottom sheet) + full page variants. |
| QRCodeDisplay | 🔴 | Renders QR from `/api/qrcode/generate` (brand `#6C47FF`, optional logo, 2x). iOS InviteQRCodeView. (Web has CSS only.) |
| CopyLinkField | 🔴 | Read-only URL + copy button + toast confirm. |
| ShareButton | 🔴 | Web Share API (`navigator.share`) w/ fallback to copy. Replaces iOS native share sheet. |
| InviteMenu / InviteOptions | 🔴 | Menu: Send message, Copy link, QR, Invite members, Invite contacts. iOS InviteMenu. |
| **InviteScopeSelector** | 🔴 | Choose scope: entire study program **or** a single lesson within it. New pattern — list/picker of program → lessons. |
| **RoleSelector** | 🔴 | Choose invitee role: member vs **contributor** (+ future roles). Segmented/radio. |
| InviteContactsList | 🔴 | Searchable contact list w/ phone filter + invite action. iOS InviteContactsPage (web: manual entry / SMS link, no Contacts API). |
| JoinCode entry | ✅ | `join-code-island` — reuse as-is for accept-by-code. |
| **AcceptInviteCard / landing** | 🔴 | Shows inviter, scope ("Day X of {Program}"), role; Accept / Decline. New to both apps. |
| **ScopeBadge** | 🔴 | Badge showing granted scope/role on shared items & in scoped shell ("Contributor · 1 lesson"). |
| **SharedContentList** | 🔴 | "Shared with me" browser — list/grid of content shared with the user, grouped by program/lesson, selectable to open. **New to both apps.** |
| **SharedContentCard** | 🔴 | Card for a shared program or lesson (title, scope, inviter, role, open action). Reuses CardStudy/CardLesson visual + ScopeBadge. |
| InviteStatus / pending list | 🔴 | Leader's view of sent invites (pending/accepted/expired) + revoke. Maps to server Invite status + MembershipEvent. |

### Scoped (contributor) UI shell

| Component | Status | Notes |
|---|---|---|
| **ScopedAppShell** | 🔴 | AppShell variant that renders nav/tabs/content limited to the invite scope. Driven by scope descriptor + permission flags; hides out-of-scope destinations. |
| Permission-aware nav | 🔴 | TabBar/PageHeader items conditionally shown by role/scope. |
| Read-only / restricted states | 🔴 | Editor and detail components must support a `disabled`/`readonly`/`scoped` mode for limited contributors. |

> **Note:** Editing screens reused by contributors (program/day/activity editors) must accept a scope/permission context so the same components serve both full leaders and scoped contributors — no forked editors.

---

## 10. Net-new vs reuse summary

- **Keep as-is:** VerifyCode, Digit/Keypad, BulletTextInput, Modal primitive, modal store, themed content/lesson player, CVA + classnames utils, Histoire config, token scales.
- **Extend:** Button/Input/Badge/Card/Avatar (CSS-only → Vue + tokens + matrices), semantic color tokens (→ dark), modal store (→ sheets/toast/banner), TabBar/PageHeader.
- **Port from iOS (net-new):** type-specific cards (Row/Mini), SwipeableCard, DataComponent, SlideStack nav, ErrorBanner/Confirmation/Alert/Toast, calendar, charts parity, all form inputs not yet present, Skeleton/Shimmer, FlowLayout, Sectioned/SearchableList, AppShell, and the **invite/share/QR set** (InviteSheet, QRCodeDisplay, CopyLinkField, ShareButton, InviteMenu, InviteContactsList).
- **Net-new to BOTH apps (priority feature 2):** InviteScopeSelector, RoleSelector, AcceptInviteCard, SharedContentList, SharedContentCard, ScopeBadge, ScopedAppShell + permission-aware nav. See §11.
