# Route-by-Route HTML/CSS Comparison: React SPA vs Laravel Blade

> Generated 2026-03-18 by auditing every React page component on `origin/archive/react-spa`
> against the corresponding Laravel Blade template on `main`.

---

## Legend

| Symbol | Meaning |
|--------|---------|
| MATCH | Blade output is structurally identical to React |
| MINOR | Small differences unlikely to affect visual appearance |
| DIFFERENCES | Structural or class-name mismatches that will affect visual fidelity |
| MAJOR | Fundamentally different structure or content |

---

## Table of Contents

1. [/ — Public Home](#route--public-home)
2. [/login — Member Login](#route-login)
3. [/home — Authenticated Home](#route-home)
4. [/groups — Groups List](#route-groups)
5. [/groups/:groupId — Group Home](#route-groupsgroupid)
6. [/groups/:groupId/study/:id — Study Home](#route-study-home)
7. [/groups/:groupId/lessons/:id/:step — Lesson](#route-lesson)
8. [/join — Enter Group Code](#route-join)
9. [/join/group/:code — Group Info](#route-joingroup)
10. [/join/group/:code/profile — Profile Step](#route-joingroupprofile)
11. [/join/group/:code/phone — Phone Step](#route-joingroupphone)
12. [/join/group/:code/verify — Verify Step](#route-joingroupverify)
13. [/join/group/:code/confirmed — Confirmation](#route-joingroupconfirmed)
14. [/event — Enter Event Code](#route-event)
15. [/event/:code — Event Info](#route-eventcode)
16. [/event/:code/phone — Event Phone](#route-eventcodephone)
17. [/event/:code/verify — Event Verify](#route-eventcodeverify)
18. [/event/:code/confirmed — Event Confirmed](#route-eventcodeconfirmed)
19. [/study — Enter Study Code](#route-study)
20. [/join/study/:identifier — Study Join Info](#route-joinstudyidentifier)
21. [/join/study/:identifier/phone — Study Phone](#route-joinstudyphone)
22. [/join/study/:identifier/verify — Study Verify](#route-joinstudyverify)
23. [/profile — Profile](#route-profile)
24. [/admin — Admin](#route-admin)
25. [/privacy — Privacy Policy](#route-privacy)
26. [/terms — Terms of Service](#route-terms)
27. [/public/preview/:token — Study Preview](#route-study-preview)
28. [/public/preview/:token/lesson/:id/:step — Lesson Preview](#route-lesson-preview)
29. [404 — Not Found](#route-404)

---

## Route: / (Public Home)
**React page:** `src/pages/public-home/public-home.page.tsx`
**Blade template:** `resources/views/pages/public-home.blade.php`
**Status:** DIFFERENCES

**Differences:**
1. **Container element:** React renders `<div class="PublicHomePage__container">`. Blade renders `<main class="PublicHomePage__container">`. The tag name differs (`div` vs `main`) which could affect CSS if tag-qualified selectors exist.
2. **Button rendering — element type:** React renders `<Button variant="JumpPrimary" ... onClick={...} />` which outputs a `<button>` element. Blade renders `<x-primitive.button variant="JumpPrimary" onclick="window.location='...'" />` which also outputs a `<button>` element. **MATCH on element type.**
3. **Button rightIcon:** React passes `rightIcon={<ArrowRight />}` (Lucide SVG). Blade does not pass a `rightIcon` slot. The Jump buttons in React have an arrow icon on the right side; Blade buttons are missing the right arrow icon entirely.
4. **Footer links — element type:** React renders footer links as `<button class="PublicHomePage__link">` with `onClick={() => navigate(...)}`. Blade renders them as `<a href="..." class="PublicHomePage__link">`. Different tag (`button` vs `a`) and different styling implications (buttons have no default underline; anchors may).
5. **Footer link `aria-hidden`:** Blade adds `aria-hidden="true"` on the dot separator. React does not. Minor accessibility difference, visually irrelevant.
6. **Loading state:** React renders a `PublicHomePage PublicHomePage--loading` variant while session loads. Blade does not (server-rendered, no loading state needed). Not a visual difference for final render.

---

## Route: /login
**React page:** `src/pages/member-login/member-login.page.tsx`
**Blade template:** `resources/views/pages/login.blade.php`
**Status:** DIFFERENCES

**Differences:**
1. **Phone step:** React renders `<PhoneEntry>` component directly (full-screen, root class `PhoneEntry`). Blade mounts a Vue island `JoinPhoneIsland` — the Vue component should replicate PhoneEntry's HTML. **Need to verify Vue island output matches React's PhoneEntry HTML.**
2. **Phone step secondary button:** React has `secondaryButtonLabel="Back"` with `onSecondaryClick={handleBack}` navigating to `/`. Blade passes `secondaryButtonLabel="Join a group"` with `secondaryRedirectUrl` to `/join`. **Different label and destination.**
3. **Verify step — back button:** React renders `<button class="MemberLoginPage__back"><ChevronLeft size={24} /></button>` (a `<button>` element with Lucide `ChevronLeft` SVG). Blade renders `<a href="..." class="MemberLoginPage__back">&#8249;</a>` (an `<a>` tag with a text chevron character). Different element, different icon rendering.
4. **Verify step — VerifyCode + Button:** React renders `<VerifyCode>` then `<Button mode="Block" variant="White" label="Verify code" />` then a `<button class="MemberLoginPage__resend">` in sequence inside `MemberLoginPage__content`. Blade mounts a `JoinVerifyIsland` Vue component inside `MemberLoginPage__code-wrapper`. The outer Blade has `MemberLoginPage__title` and `MemberLoginPage__description` but the VerifyCode, Button, and resend link are inside the Vue island. **The h1, p, and code-wrapper are duplicated** — Blade renders them AND the Vue island may also render them.
5. **Error display:** React uses `<div class="MemberLoginPage__error">`. Blade defers to Vue island for error display.

---

## Route: /home
**React page:** `src/pages/home/home.page.tsx`
**Blade template:** `resources/views/pages/home-authenticated.blade.php`
**Status:** DIFFERENCES

**Differences:**
1. **Group card component:** React renders `<GroupCard>` component (class `GroupCard`) with props `name, coverImageUrl, isPrivate, memberCount, memberSince, showChevron="True"`. Blade renders `<x-domain.group-list-card>` (class `GroupListCard`) with props `name, memberCount, imageUrl`. **Completely different component** — GroupCard has a cover image, privacy badge, member-since date, and chevron. GroupListCard is a compact list row with avatar and member count. This is a significant visual mismatch.
2. **Group card wrapper:** React renders each group with just `<GroupCard onClick={...}>`. Blade wraps each in `<a href="..." class="MemberHomePage__group-link">` around a `<x-domain.group-list-card>`. React uses `onClick` handler, Blade uses anchor navigation. The extra `<a>` wrapper is an additional DOM element.
3. **Image field name:** React passes `coverImageUrl={group.coverImageUrl}`. Blade passes `:imageUrl="$group['avatarUrl']"`. Different API field names — `coverImageUrl` (cover photo) vs `avatarUrl` (group avatar thumbnail).
4. **Loading state:** React shows skeleton `<div class="MemberHomePage__skeleton" />` elements (3 of them). Blade has no loading state (server-rendered).
5. **Single-group redirect:** React's useEffect auto-redirects to the group if there's exactly one group. Blade likely does this server-side (in the controller), so this is not a template difference.
6. **Navigation component — structure:** React renders `<Navigation>` with `onNavigate` and `onAvatarClick` callbacks. Blade renders `<x-domain.navigation>` with `homeHref` and `profileHref` as anchor hrefs. Navigation items in React use `<button>` elements with click handlers. Blade uses `<a>` elements with hrefs. **Different interactive elements.**

---

## Route: /groups
**React page:** `src/pages/groups/groups.page.tsx`
**Blade template:** `resources/views/pages/groups.blade.php`
**Status:** MAJOR DIFFERENCES

**Differences:**
1. **Root class:** React has no root BEM class — it uses inline styles (`style={{ width: '100%', maxWidth: '440px', ... }}`). Blade uses `<main class="GroupsPage">`. The React page has no CSS class-based layout at all.
2. **Header:** React renders an inline-styled header with `<h1>My Groups</h1>` and a `<Button variant="Ghost" size="Sm">Logout</Button>`. Blade renders `<x-panel.page-title title="Groups" />` (different title text) with no logout button.
3. **Navigation placement:** React does not render a `<Navigation>` component on this page. Blade renders `<x-domain.navigation>` at the top of the page.
4. **Group card component:** React uses `<GroupListCard>` with `name, memberCount, imageUrl, isActive, onClick, interactive="True"`. Blade also uses `<x-domain.group-list-card>` with matching props. **Component match.**
5. **Group card wrapper:** React renders groups inside an inline-styled flex column. Blade wraps each in `<a class="GroupsPage__group-link">`.
6. **Empty state:** React uses `<EmptyState title="No Groups Yet" description="Create your first group to get started.">`. Blade uses `<x-primitive.empty-state title="No groups yet" description="You haven't joined any groups. Use a join code to get started.">`. **Different text content.**
7. **Error and loading states:** React has inline-styled loading and error states. Blade has none (server-rendered).

---

## Route: /groups/:groupId
**React page:** `src/pages/group-home/group-home.page.tsx`
**Blade template:** `resources/views/pages/group-home.blade.php`
**Status:** DIFFERENCES

**Differences:**
1. **GroupCard back button:** React's `<GroupCard mode="Header" onBack={handleBack}>` renders a `<button>` with click handler. Blade passes `:backHref="route('home')"` but the `group-card.blade.php` component does NOT accept a `backHref` prop — it renders `<button class="GroupCard__back-button">` with no href or onclick. **The back button in Blade is non-functional.**
2. **Study enrollment — next lesson card:** React renders a `<StudyCard mode="LessonList">` for the next available lesson within the studies section. Blade only renders the progress card (`<x-domain.study-card mode="Progress">`) and omits the next lesson card entirely.
3. **Study enrollment — StudyCard click:** React passes `onClick={handleStudyClick}` to the progress StudyCard to navigate to study home. Blade does not pass any click/href to the StudyCard — **the study progress card is not clickable.**
4. **Posts feed — author field names:** React uses `authorName={post.authorName}` and `authorAvatarUrl={post.authorAvatarUrl}`. Blade constructs `authorName` from `$post['author']['firstName'] . ' ' . $post['author']['lastName']` and uses `$post['author']['avatarUrl']`. Different data shape — works if controller transforms correctly, but fragile.
5. **Infinite scroll:** React implements `IntersectionObserver` for infinite scroll with sentinel, loading-more indicator, and end-of-feed message. Blade has none — all posts rendered server-side at once.
6. **Loading state:** React shows `<Loading variant="Bars">` spinner. Blade has none.

---

## Route: /groups/:groupId/study/:studyEnrollmentId
**React page:** `src/pages/study-home/study-home.page.tsx`
**Blade template:** `resources/views/pages/study-home.blade.php`
**Status:** MINOR DIFFERENCES

**Differences:**
1. **StudyCard Header back button:** React passes `onBack={handleBack}` which navigates to `/groups/${groupId}`. Blade passes `:backHref="route('group.home', ...)"`. Need to verify the study-card component accepts and renders the back href. Similar issue to GroupCard — **verify study-card.blade.php handles backHref.**
2. **Lesson links:** React passes `onClick={() => handleLessonClick(lesson.id)}` to each `<StudyCard mode="LessonList">`. Blade wraps each in `<a href="...">`. Different interactive pattern but visually should match since the cards are clickable either way.
3. **Lesson wrapping:** Blade adds `<a class="StudyHome__lesson-link">` wrapper around each StudyCard. React has no wrapper — the StudyCard itself is clickable. The extra `<a>` could affect styling.
4. **Empty state:** React has no explicit empty lessons state. Blade renders `<x-primitive.empty-state>` when no lessons exist.

---

## Route: /groups/:groupId/lessons/:lessonScheduleId/:step
**React page:** `src/pages/lesson/lesson.page.tsx`
**Blade template:** `resources/views/pages/lesson.blade.php`
**Status:** MATCH (delegates to Vue island)

**Notes:**
- React renders `<LessonActivity config={...} />` — a complex shared component.
- Blade mounts `data-vue="LessonIsland"` with all lesson data as props.
- The Vue island should replicate LessonActivity's HTML. **Visual fidelity depends entirely on the LessonIsland Vue component matching the React LessonActivity component.**
- Blade uses `layouts.home` layout which includes no wrapping elements. React has no outer wrapper either. **Layout match.**

---

## Route: /join
**React page:** `src/pages/public-join/public-join.page.tsx` (JoinEnterCode export)
**Blade template:** `resources/views/pages/join-code.blade.php`
**Status:** MINOR DIFFERENCES

**Differences:**
1. **Interactive behavior:** React renders the full `<JoinCodePage>` component with `<VerifyCode>` input (6-character code entry) and a submit button. Blade renders a `data-vue="JoinCodeIsland"` Vue island with a server-rendered fallback.
2. **Server fallback:** The fallback inside the Vue mount point shows `JoinCodePage__container` with logo, title, description — but no code input or button. Once Vue hydrates, this is replaced. **During SSR/no-JS, the join code page is non-functional.**
3. **Invalid group screen:** React shows a `<Confirmation color="Yellow">` with "Invalid Group" message. Blade defers this to Vue island behavior.

---

## Route: /join/group/:code (info step)
**React page:** `src/pages/public-join/public-join.page.tsx` (JoinGroupInfo export)
**Blade template:** `resources/views/pages/join-group.blade.php` (step=info)
**Status:** DIFFERENCES

**Differences:**
1. **GroupLeaderNote — conditional for already-member:** React shows `<GroupLeaderNote mode="Member" recipientName=... memberSince=...>` when user is already a member. Blade always shows `<x-domain.group-leader-note mode="Invite">`. **Missing already-member variant.**
2. **Info card buttons — authenticated state:** React shows different buttons based on auth state: "Accept Invite" (if authenticated), "I am not [name]" (if authenticated), "Continue" / "Change group" (if not). Blade always shows "Continue" and "Change group" regardless of auth state.
3. **Continue button form:** Blade wraps the Continue button in a `<form method="POST">` with CSRF. React uses JavaScript `onClick`. Blade's form element adds additional DOM structure not present in React.
4. **Loading state:** React shows `<Loading variant="Bars" color="Purple" size="Lg">` while fetching group. Blade has no loading state.

---

## Route: /join/group/:code/profile
**React page:** `src/pages/public-join/public-join.page.tsx` (JoinProfile export)
**Blade template:** `resources/views/pages/join-group.blade.php` (step=profile)
**Status:** MINOR DIFFERENCES

**Differences:**
1. **StepTitle description:** React: "Tell us a bit about yourself to complete your profile." Blade: same text. **MATCH.**
2. **Form wrapping:** Blade wraps in `<form method="POST">`. React has no form element — uses JavaScript handlers. The extra `<form>` element in Blade is additional structure.
3. **ProfileForm showSuccessMessage:** Both pass `showSuccessMessage={false}`. **MATCH.**
4. **Button label:** Both show "Next" primary and "Change group" secondary. **MATCH.**

---

## Route: /join/group/:code/phone
**React page:** `src/pages/public-join/public-join.page.tsx` (JoinPhone export)
**Blade template:** `resources/views/pages/join-group.blade.php` (step=phone)
**Status:** DIFFERENCES

**Differences:**
1. **PhoneEntry rendering:** React renders the `<PhoneEntry>` component directly as the full page (no JoinPage wrapper). Blade mounts `data-vue="JoinPhoneIsland"`. **Visual fidelity depends on Vue island matching PhoneEntry exactly.**
2. **SMS consent checkbox:** React renders an `<label class="SmsConsent">` with checkbox and consent text (including links to privacy/terms) as children of PhoneEntry. Blade passes `showSmsConsent: true` and privacy/terms URLs as props to the Vue island. **Need to verify the Vue island renders the SmsConsent HTML identically.**
3. **Secondary button:** React has `secondaryButtonLabel="Change group"` with `onSecondaryClick` navigating to `/join`. Blade does not pass a secondary button label to the Vue island. **Missing "Change group" secondary button.**
4. **PhoneEntry title:** React uses default "Enter your phone". Blade passes `title: "Enter your phone number"`. **Different title text.**

---

## Route: /join/group/:code/verify
**React page:** `src/pages/public-join/public-join.page.tsx` (JoinVerify export)
**Blade template:** `resources/views/pages/join-group.blade.php` (step=verify)
**Status:** DIFFERENCES

**Differences:**
1. **Outer wrapper:** React wraps in `<FullScreenContainer>` which renders `<div class="JoinPage"><div class="JoinPage__container">`. Blade also renders `<div class="JoinPage"><div class="JoinPage__container"><div class="JoinPage__content">`. **MATCH on wrapper structure.**
2. **StepTitle:** React renders `<StepTitle title="Verify phone" description="Enter the 6-digit code sent to ...">`. Blade defers to Vue island — no server-rendered StepTitle. The `JoinVerifyIsland` may or may not render this.
3. **VerifyCode placement:** React renders `<VerifyCode>` in `<div class="JoinPage__code-wrapper">`. Blade mounts `JoinVerifyIsland` inside `JoinPage__content`. **Structure depends on Vue island output.**
4. **Error modal:** React renders `<ErrorModal>` with blurred backdrop when `store.error` is set. Blade defers to Vue island.
5. **Resend button:** React renders `<button class="JoinVerify__resend">`. Blade defers to Vue island.

---

## Route: /join/group/:code/confirmed
**React page:** `src/pages/public-join/public-join.page.tsx` (JoinConfirmation export)
**Blade template:** `resources/views/pages/join-group.blade.php` (step=confirmed)
**Status:** DIFFERENCES

**Differences:**
1. **Confirmation title — conditional:** React shows different titles based on state: "Request submitted" (pending), "You're already a member" (already member), "You're in!" (approved). Blade always shows "Request Sent!". **Missing conditional title.**
2. **Confirmation color — conditional:** React shows `color="White"` for pending, `color="Green"` otherwise. Blade always shows `color="Green"`.
3. **Confirmation icon — conditional:** React shows `<Clock>` for pending, `<Check>` otherwise. Blade shows no icon (falls back to default check SVG in the Confirmation component).
4. **Confirmation description — conditional:** React shows dynamic description based on status with `<strong>` tags for group name. Blade shows static text "Your join request has been sent to the group leader. You'll receive a notification once you're approved."
5. **Action button — conditional:** React shows "Continue" button only when approved or already-member. Blade always shows a "Continue" button.
6. **Study redirect:** React checks for `pendingStudyCode` in sessionStorage and auto-redirects. Blade has no equivalent.

---

## Route: /event
**React page:** `src/pages/public-event-join/public-event-join.page.tsx` (EventJoinEnterCode)
**Blade template:** `resources/views/pages/event-code.blade.php`
**Status:** MINOR DIFFERENCES

**Differences:**
1. **Same pattern as /join:** Blade renders `data-vue="JoinCodeIsland"` with event-specific props (title, description, buttonLabel). React renders `<JoinCodePage>` with same props. **Visual fidelity depends on Vue island.**
2. **Server fallback:** Blade renders static fallback content. React renders interactive JoinCodePage immediately.
3. **Invalid event screen:** React shows `<Confirmation color="Yellow">` with "Event not found". Blade defers to Vue island.

---

## Route: /event/:code (info step)
**React page:** `src/pages/public-event-join/public-event-join.page.tsx` (EventJoinInfo)
**Blade template:** `resources/views/pages/join-event.blade.php` (step=info)
**Status:** DIFFERENCES

**Differences:**
1. **Root class name:** React uses `EventJoinPage` / `EventJoinPage__container` / `EventJoinPage__content`. Blade uses same classes. **MATCH.**
2. **EventCard prop names:** React passes `title, date, time, location, coverImageUrl, attendeeCount`. Blade passes `title` as `$event['name']`. **Field name mismatch:** React expects `title`, Blade uses `name`.
3. **Error fallback link:** React navigates to `/event`. Blade links to `route('join.enter-code')` which is `/join`. **Wrong error recovery destination.**
4. **Loading state:** React shows a loading message. Blade has no loading state.

---

## Route: /event/:code/phone
**React page:** `src/pages/public-event-join/public-event-join.page.tsx` (EventJoinPhone)
**Blade template:** `resources/views/pages/join-event.blade.php` (step=phone)
**Status:** DIFFERENCES

**Differences:**
1. **Same pattern as /join/group/:code/phone.** Blade mounts `JoinPhoneIsland`. React renders `<PhoneEntry>`.
2. **SMS consent:** React renders SmsConsent as children. Blade passes `showSmsConsent: true` as prop.
3. **Missing secondary button:** React has no secondary button on event phone step. Blade also has none. **MATCH on this point.**
4. **Title:** React uses default "Enter your phone". Blade passes "Enter your phone number". **Different title.**

---

## Route: /event/:code/verify
**React page:** `src/pages/public-event-join/public-event-join.page.tsx` (EventJoinVerify)
**Blade template:** `resources/views/pages/join-event.blade.php` (step=verify)
**Status:** DIFFERENCES

**Differences:**
1. **Outer wrapper:** React: `EventJoinPage / EventJoinPage__container / EventJoinPage__content`. Blade: same. **MATCH.**
2. **StepTitle:** React renders `<StepTitle>` with dynamic phone number. Blade renders static `<div class="StepTitle">` with "Enter the 6-digit code sent to your phone" — **phone number not displayed.**
3. **VerifyCode + Button:** React renders VerifyCode, Button, resend button, and ErrorModal all inline. Blade mounts `JoinVerifyIsland` Vue island. **Structure depends on Vue island.**
4. **Code wrapper class:** React uses `EventJoinPage__code-wrapper`. Blade uses same class. **MATCH.**

---

## Route: /event/:code/confirmed
**React page:** `src/pages/public-event-join/public-event-join.page.tsx` (EventJoinConfirmation)
**Blade template:** `resources/views/pages/join-event.blade.php` (step=confirmed)
**Status:** DIFFERENCES

**Differences:**
1. **Confirmation title:** React: "You're attending!" Blade: "You're Registered!" **Different text.**
2. **Confirmation description:** React: "You've confirmed your attendance for **{title}**." (with dynamic event title in bold). Blade: "You have successfully registered for this event. We'll see you there!" **Different text, no dynamic content.**
3. **Confirmation icon:** React passes `<Check strokeWidth={2.5}>`. Blade passes no icon (uses default).

---

## Route: /study
**React page:** `src/pages/study-code/study-code.page.tsx`
**Blade template:** `resources/views/pages/study-code.blade.php`
**Status:** MATCH (same pattern as /join and /event code entry)

**Notes:**
- Both render JoinCodePage with title "Join a study", matching description, and button "Join Study".
- Blade uses `JoinCodeIsland` Vue component. Visual fidelity depends on Vue island.

---

## Route: /join/study/:identifier (info step)
**React page:** `src/pages/study-join/study-join.page.tsx`
**Blade template:** `resources/views/pages/join-study.blade.php` (step=info)
**Status:** DIFFERENCES

**Differences:**
1. **GroupLeaderNote — messageSuffix:** React passes `messageSuffix="to join a study."`. Blade passes `:message-suffix="'to join a study.'"`. **MATCH.**
2. **StudyInfoCard — children:** React passes two `<Button>` children ("Continue" and "Change study"). Blade passes the same. **MATCH.**
3. **Loading state:** React shows `<Loading variant="Bars">`. Blade has none.
4. **Error handling:** React shows `<Confirmation color="Yellow">` for errors. Blade shows a plain `<p>` with error text. **Different error display.**

---

## Route: /join/study/:identifier/phone
**React page:** `src/pages/study-join/study-join.page.tsx` (phone step)
**Blade template:** `resources/views/pages/join-study.blade.php` (step=phone)
**Status:** DIFFERENCES

**Differences:**
1. **Same pattern as other phone steps.** Blade mounts `JoinPhoneIsland`.
2. **Secondary button:** React has `secondaryButtonLabel="Back"` with `onSecondaryClick` going back to info. Blade does not pass a secondary button. **Missing "Back" button.**
3. **Title:** Same mismatch: "Enter your phone" (React) vs "Enter your phone number" (Blade).

---

## Route: /join/study/:identifier/verify
**React page:** `src/pages/study-join/study-join.page.tsx` (verify step)
**Blade template:** `resources/views/pages/join-study.blade.php` (step=verify)
**Status:** MAJOR DIFFERENCES

**Differences:**
1. **Wrapper structure:** React renders the verify step with **inline styles** on a raw div (no BEM classes) — not wrapped in `StudyJoinPage`. Blade mounts `JoinVerifyIsland` without any wrapper (`<div data-vue="JoinVerifyIsland" ...></div>` directly). **Different from other verify steps which have BEM wrappers.**
2. **React verify step has no StepTitle component** — it renders `<h1>` and `<p>` with inline styles directly. Blade defers entirely to Vue island.
3. **Vue island rendering:** The `JoinVerifyIsland` is mounted bare (no `JoinPage__content` or `StepTitle` wrapper). This is correct since React also has no wrapper. But the Vue island needs to provide its own full layout.

---

## Route: /join/study/:identifier/confirmed
**React page:** `src/pages/study-join/study-join.page.tsx` — **React does not have a confirmed step.** On successful verification, React navigates directly to the lesson page.
**Blade template:** `resources/views/pages/join-study.blade.php` (step=confirmed)
**Status:** MAJOR DIFFERENCES

**Differences:**
1. **Route does not exist in React.** The React flow goes: verify -> navigate to lesson. There is no confirmation screen.
2. **Blade shows a Confirmation screen** with "You're In!" and a "Go to Home" button. This is an extra step not present in the React app.
3. **This route should either be removed or the flow should redirect to the lesson like React does.**

---

## Route: /profile
**React page:** `src/pages/profile/profile.page.tsx`
**Blade template:** `resources/views/pages/profile.blade.php`
**Status:** DIFFERENCES

**Differences:**
1. **Header component:** React renders `<PageTitleLinkTitleLink>` with `title="Edit profile"`, `leftLink="Cancel"`, `rightLink="Save"`, `leftLinkMuted`, `rightLinkWhite`. Blade renders `<x-panel.page-title>` with similar props but as attributes. **Need to verify PageTitle component matches React's PageTitleLinkTitleLink output.**
2. **Avatar button:** React uses `<button type="button" class="ProfilePage__avatar-button">` containing `<Avatar>`. Blade uses `<label for="avatar-input" class="ProfilePage__avatar-button">` containing `<x-primitive.avatar>`. Different element type (`button` vs `label`).
3. **Flash messages:** Blade renders `ProfilePage__flash--success` and `ProfilePage__flash--error` divs for server-side flash messages. React has no such elements. **Extra elements in Blade not present in React.**
4. **Google sync button:** React renders `<button class="ProfilePage__google-sync">Use Google photo</button>` when `hasEmail` is true. Blade renders an empty `<div class="ProfilePage__avatar-actions">` with a comment saying it's a placeholder. **Missing Google sync feature.**
5. **Error display:** Blade renders `<div class="ProfilePage__errors">` for validation errors. React shows inline `alert()` calls. **Different error presentation.**
6. **Form wrapping:** Blade wraps content in `<form method="POST" class="ProfilePage__content">`. React has no form element — uses JavaScript handlers on the `<div class="ProfilePage__content">`. Different element type for content wrapper (`form` vs `div`).
7. **Hidden submit button:** Blade has `<button type="submit" class="ProfilePage__save-hidden" style="display:none">`. React has none.

---

## Route: /admin
**React page:** `src/pages/admin/admin.page.tsx`
**Blade template:** `resources/views/pages/admin.blade.php`
**Status:** MAJOR DIFFERENCES

**Differences:**
1. **Root structure:** React renders `<HomeLayout title="MakeReady Admin" ...>` which is a layout component with header, avatar, and content area. Blade renders `<main class="AdminPage">` with inline structure. **Completely different component hierarchy.**
2. **Navigation:** React renders `<HomeLayout>` which presumably includes navigation. Blade renders `<x-domain.navigation>` at the top of AdminPage. Different placement and structure.
3. **Content:** React renders a centered card with "Welcome, {displayName}!", phone number, within `<HomeLayout centerContent>`. Blade renders `<x-panel.page-title title="Admin">`, then name, phone, and logout button in a flat structure.
4. **Logout button:** React renders `<Button variant="Destructive" size="Sm">Logout</Button>` in the header. Blade renders a form with `<x-primitive.button type="submit" variant="Secondary">Log Out</x-primitive.button>` in the content area. **Different variant, different placement.**
5. **Avatar rendering:** React renders `<Avatar>` with `<AvatarImage>` and `<AvatarFallback>` in the HomeLayout header. Blade has no avatar rendering on the admin page (it's in the Navigation component).

---

## Route: /privacy
**React page:** `src/pages/privacy/privacy.page.tsx`
**Blade template:** `resources/views/compliance/privacy.blade.php`
**Status:** MAJOR DIFFERENCES

**Differences:**
1. **Content is completely different.** React has a comprehensive 14-section privacy policy (2,700+ words) covering CCPA/CPRA, international data transfers, breach notification, etc. Blade has a short 7-section policy (~400 words) that reads more like an SMS-specific compliance page.
2. **Back button:** React has a `<button class="PrivacyPage__back">` with `<ChevronLeft>` icon for navigation. Blade has no back button.
3. **Page structure:** React uses `PrivacyPage__content` wrapper containing the back button, title, and sections. Blade has no `PrivacyPage__content` wrapper — content is directly in `PrivacyPage__container`.
4. **Title class name:** React uses `PrivacyPage__title`. Blade uses `PrivacyPage__heading`. **Different class name.**
5. **Section headings:** React uses `PrivacyPage__heading` for `<h2>`. Blade uses `PrivacyPage__subheading`. **Different class name.**
6. **Date:** React: "Last updated: February 4, 2026". Blade: "Last updated: March 2025". **Different date.**
7. **List items:** React uses `<li>` directly inside `PrivacyPage__list`. Blade uses `<li class="PrivacyPage__list-item">`. **Extra class on list items.**
8. **Email address:** React: `privacy@makeready.org`. Blade: `support@makeready.app`. **Different email.**
9. **Footer navigation:** React has no footer nav. Blade has `<nav class="PrivacyPage__nav">` with links to Terms and SMS Opt-In.
10. **Layout:** React extends no layout (renders full page). Blade extends `layouts.app` which adds navigation and footer. **Extra chrome around content.**

---

## Route: /terms
**React page:** `src/pages/terms/terms.page.tsx`
**Blade template:** `resources/views/compliance/terms.blade.php`
**Status:** MAJOR DIFFERENCES

**Differences:**
1. **Content is completely different.** React has a comprehensive 19-section terms of service (3,000+ words) covering eligibility, acceptable use, intellectual property, dispute resolution, DMCA, etc. Blade has a short 8-section terms (~500 words) focused primarily on SMS messaging.
2. **Back button:** React has `<button class="TermsPage__back">` with `<ChevronLeft>`. Blade has none.
3. **Title class name:** React: `TermsPage__title`. Blade: `TermsPage__heading`. **Different class name.**
4. **Section headings:** React: `TermsPage__heading`. Blade: `TermsPage__subheading`. **Different class name.**
5. **Date:** React: "Last updated: February 4, 2026". Blade: "Last updated: March 2025".
6. **List items:** React: `<li>` plain. Blade: `<li class="TermsPage__list-item">`.
7. **Email:** React: `support@makeready.org`. Blade: `support@makeready.app`.
8. **Layout:** Same issue as privacy — Blade uses `layouts.app` adding extra navigation/footer.
9. **Footer navigation:** Blade has `<nav class="TermsPage__nav">`. React has none.

---

## Route: /public/preview/:token
**React page:** `src/pages/study-preview/study-preview.page.tsx`
**Blade template:** `resources/views/pages/study-preview.blade.php`
**Status:** MINOR DIFFERENCES

**Differences:**
1. **StudyCard Header — no back button:** React does not pass `onBack` to the header StudyCard (no back button in preview). Blade does not pass `backHref`. **MATCH.**
2. **Lesson title:** React: `title={\`Day ${lesson.dayNumber}\`}`. Blade: `:title="'Day ' . ($lessonDay ?? '')"`. **MATCH (same output).**
3. **Lesson click:** React uses `onClick={() => handleLessonClick(lesson.id)}`. Blade passes `:href="$lessonHref"`. The StudyCard component may need to handle href-based navigation.
4. **Lesson status:** React passes `status={studyPreviewUI.getLessonStatus(lesson)}`. Blade does not pass a status. **Missing lesson status.**
5. **Error state:** React has a styled error state with `StudyPreview__error` / `StudyPreview__error-title` / `StudyPreview__error-message`. Blade has no error state rendering.
6. **Loading state:** React shows `<Loading>`. Blade has none.
7. **Layout:** React has no layout wrapper. Blade uses `layouts.app` which adds navigation and footer. **Extra chrome.**

---

## Route: /public/preview/:token/lesson/:lessonId/:step
**React page:** `src/pages/lesson-preview/lesson-preview.page.tsx`
**Blade template:** `resources/views/pages/lesson-preview.blade.php`
**Status:** MATCH (delegates to Vue island)

**Notes:**
- Same pattern as the authenticated lesson page. Both mount `LessonIsland` with `isPreview=true`.
- Blade uses `layouts.app` while the authenticated lesson uses `layouts.home`. React uses no layout for either. **Layout difference** — lesson-preview gets navigation/footer from `layouts.app` while React does not.

---

## Route: 404 (Not Found)
**React page:** `src/pages/not-found/not-found.page.tsx`
**Blade template:** `resources/views/errors/404.blade.php`
**Status:** MAJOR DIFFERENCES

**Differences:**
1. **Root class:** React: `NotFoundPage`. Blade: `ErrorPage`. **Different class name.**
2. **Content:** React renders only `<span class="NotFoundPage__text">404</span>` — just the number, no additional text. Blade renders logo, "404", "Page Not Found" title, description text, and a "Go Home" link. **Blade has significantly more content.**
3. **Structure:** React is a minimal fullscreen centered "404" text. Blade is a full error page with logo, heading, description, and navigation link.
4. **Layout:** React renders a bare page. Blade extends `layouts.app` with navigation and footer.

---

## Summary of Cross-Cutting Issues

### 1. Button `<a>` vs `<button>` Throughout
React uses `<button>` with `onClick` handlers everywhere. Blade frequently uses `<a>` tags with `href` for navigation (footer links, group cards, lesson links). This is semantically different and may affect styling if CSS targets `button.ClassName` vs `a.ClassName`.

### 2. Navigation Component — Interactive Elements
React's `<Navigation>` uses `<button>` elements with `onNavigate` and `onAvatarClick` callbacks. Blade's `<x-domain.navigation>` uses `<a>` elements with `href` attributes. The icons render as inline SVGs in both cases. **Functionally equivalent but different element types.**

### 3. Missing Right Arrow Icons on Jump Buttons (Public Home)
The `<ArrowRight>` Lucide icon is passed as `rightIcon` slot in React but not in Blade. All four Jump/JumpPrimary buttons on the public home page are missing their right arrow icons.

### 4. Phone Step Title Mismatch
React defaults to "Enter your phone". Blade consistently passes "Enter your phone number". This affects all phone entry steps across join/event/study flows.

### 5. Layout Wrappers
- `layouts.auth` adds `<body class="AuthPage">` — React has no equivalent body class.
- `layouts.app` adds navigation + footer around content — React public pages have no such chrome.
- `layouts.home` is clean — just body + content. Closest to React's rendering.

### 6. Privacy and Terms Pages — Complete Content Mismatch
The Blade versions are SMS-compliance-focused short pages. The React versions are comprehensive legal documents. These need to be completely replaced with the React content.

### 7. GroupCard vs GroupListCard on Home Page
The authenticated home page (`/home`) uses `GroupCard` in React (large card with cover image) but `GroupListCard` in Blade (compact list row). This is a major visual difference.

### 8. Vue Island Fidelity (Unverified)
Many interactive pages delegate to Vue islands: `JoinCodeIsland`, `JoinPhoneIsland`, `JoinVerifyIsland`, `LessonIsland`. The visual fidelity of these islands compared to their React counterparts has not been audited in this report. **A separate audit of Vue island HTML output is needed.**

---

## Priority Rankings

### Critical (Major visual differences)
1. `/home` — Wrong component (GroupCard vs GroupListCard)
2. `/privacy` — Complete content mismatch
3. `/terms` — Complete content mismatch
4. `/admin` — Completely different structure
5. `404` — Different class names and content

### High (Noticeable differences)
6. `/` (public home) — Missing arrow icons on Jump buttons
7. `/login` verify step — Back button element/icon mismatch, possible duplicate headings
8. `/groups/:groupId` — Non-functional back button, missing next lesson card
9. `/join/group/:code/confirmed` — Missing conditional states
10. `/event/:code/confirmed` — Different text content
11. `/groups` — Wrong root class, different header, navigation mismatch

### Medium (Functional but not identical)
12. `/join/group/:code` (info) — Missing auth-state conditional buttons
13. `/join/group/:code/phone` — Missing secondary button, title mismatch
14. `/join/study/:identifier/verify` — Different wrapper structure
15. `/join/study/:identifier/confirmed` — Route doesn't exist in React
16. `/profile` — Element mismatches (label vs button, form vs div)
17. `/event/:code` (info) — Field name mismatch, wrong error link

### Low (Minor or Vue-island-dependent)
18. `/join` — Vue island dependent
19. `/event` — Vue island dependent
20. `/study` — Vue island dependent
21. `/groups/:groupId/study/:id` — Lesson link wrappers
22. `/public/preview/:token` — Missing lesson status
23. All phone/verify steps — Vue island dependent
