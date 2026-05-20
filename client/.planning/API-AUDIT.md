# API Audit: Laravel vs React

Audit of every API call in the Laravel app compared to the React SPA.
Covers endpoint URLs, request parameters, and response field mappings.

---

## 1. HomeController (Member Home / Groups List)

### Laravel (`app/Http/Controllers/HomeController.php`)
| # | Method | Endpoint |
|---|--------|----------|
| 1 | GET | `/api/members/{memberId}/groups` |

**Response fields used:** `body['data']` or `body['groups']`

### React (`src/store/ui/groups-list.ui.ts`)
| # | Method | Endpoint |
|---|--------|----------|
| 1 | GET | `/api/groups` |

**Response fields used:** `response.groups`

### MISMATCH: Endpoint URL
- **Laravel:** `/api/members/{memberId}/groups` (member-scoped)
- **React:** `/api/groups` (authenticated user's groups via session)
- **Impact:** These may be different API endpoints returning different data. The React `GroupsListUI` is the leader's groups list (`/api/groups` returns groups created by authenticated user). The `HomeController` fetches member's group memberships. If the HomeController is only for the member experience, using `/api/members/{id}/groups` is correct. But the React equivalent for member home is actually in `SessionStore.loadSession()` + router logic, not `GroupsListUI`.

### MISMATCH: Response shape
- **Laravel:** Tries `body['data']` then `body['groups']` (defensive)
- **React:** Expects `response.groups` directly
- **Risk:** Low -- Laravel's fallback handles both shapes.

---

## 2. GroupsController (Groups List Page)

### Laravel (`app/Http/Controllers/GroupsController.php`)
| # | Method | Endpoint |
|---|--------|----------|
| 1 | GET | `/api/members/{memberId}/groups` |

**Response fields used:** `body['data']` or `body['groups']`

Same as HomeController -- duplicated logic. React equivalent is the same as above.

---

## 3. GroupHomeController

### Laravel (`app/Http/Controllers/GroupHomeController.php`)
| # | Method | Endpoint |
|---|--------|----------|
| 1 | GET | `/api/groups/{groupId}/public` |
| 2 | GET | `/api/groups/{groupId}/posts?limit=10` |
| 3 | GET | `/api/groups/{groupId}/study-enrollment?memberId={memberId}` |

**Response fields used:**
- Group: `body['group']` or `body['data']`
- Posts: `body['posts']` or `body['data']`
- Enrollment: `body['enrollment']` or `body['data']`

### React (`src/store/ui/group-home.ui.ts`)
| # | Method | Endpoint |
|---|--------|----------|
| 1a | GET | `/api/groups/{groupId}` (leader, authenticated) |
| 1b | GET | `/api/groups/{groupId}/public` (member, fallback) |
| 2a | GET | `/api/groups/{groupId}/posts` (leader) |
| 2b | GET | `/api/groups/{groupId}/posts/public` (member) |
| 3 | GET | `/api/groups/{groupId}/study-enrollment?memberId={memberId}` |

**Response fields used:**
- Group: `response.group`
- Posts: `response.posts`, `response.nextCursor`, `response.hasMore`
- Enrollment: `response.enrollment`

### MISMATCH: Posts endpoint
- **Laravel:** Always uses `/api/groups/{groupId}/posts?limit=10`
- **React:** Uses `/api/groups/{groupId}/posts` for leaders, `/api/groups/{groupId}/posts/public` for members
- **Impact:** HIGH -- Laravel always hits the authenticated posts endpoint. For non-leader members, the React app uses `/posts/public`. If the `/posts` endpoint requires leader auth, non-leader members will get errors or empty data.

### MISMATCH: Posts pagination
- **Laravel:** Hardcodes `?limit=10`, no cursor support
- **React:** Uses `limit=20`, supports cursor-based pagination (`?cursor=...`) for infinite scroll
- **Impact:** MEDIUM -- Laravel fetches only 10 posts with no ability to load more. React supports infinite scroll with cursor pagination.

### MISMATCH: Group endpoint (leader vs member)
- **Laravel:** Always uses `/api/groups/{groupId}/public`
- **React:** Leaders use `/api/groups/{groupId}` (authenticated), members use `/api/groups/{groupId}/public`
- **Impact:** LOW -- Leaders will see the public view in Laravel, but this may miss leader-specific data.

### MISSING in Laravel
- React calls `/api/invites` (POST) and `/api/qrcode/generate` (POST) for invite modal -- not present in Laravel (OK if invite feature is leader-only/iPhone).

---

## 4. StudyHomeController

### Laravel (`app/Http/Controllers/StudyHomeController.php`)
| # | Method | Endpoint |
|---|--------|----------|
| 1 | GET | `/api/groups/{groupId}/study-enrollment/{studyEnrollmentId}?memberId={memberId}` |

**Response fields used:** `body` (entire response body used as `studyData`)

### React (`src/store/ui/study-home.ui.ts`)
| # | Method | Endpoint |
|---|--------|----------|
| 1 | GET | `/api/groups/{groupId}/study-enrollment/{studyEnrollmentId}?memberId={memberId}` |

**Response fields used:** `response.enrollment`

### MATCH: Endpoint URL -- identical.

### MISMATCH: Response field mapping
- **Laravel:** Uses entire `body` as `studyData` (passes raw to Blade)
- **React:** Expects `response.enrollment` (nested under `enrollment` key)
- **Impact:** MEDIUM -- If the API wraps data under `enrollment`, the Blade template receives the wrapper object instead of the enrollment data. The template needs to access `studyData.enrollment` or the controller should extract `body['enrollment']`.

---

## 5. LessonController

### Laravel (`app/Http/Controllers/LessonController.php`)

#### show()
| # | Method | Endpoint |
|---|--------|----------|
| 1 | GET | `/api/member/lessons/{lessonScheduleId}?memberId={memberId}` |

#### submitNote()
| # | Method | Endpoint |
|---|--------|----------|
| 2 | POST | `/api/member/activities/{activityId}/submit` |

#### saveVideoProgress()
| # | Method | Endpoint |
|---|--------|----------|
| 3 | POST | `/api/member/activities/{activityId}/video-progress` |

#### fetchScripture()
| # | Method | Endpoint |
|---|--------|----------|
| 4 | GET | `/api/bible/{translation}/{book}/{chapter}` |

### React (`src/store/domain/activities.domain.ts` + `src/store/ui/lesson-activity.ui.ts`)
| # | Method | Endpoint |
|---|--------|----------|
| 1 | GET | `/api/member/lessons/{lessonScheduleId}?memberId={memberId}` |
| 2 | POST | `/api/member/activities/{lessonActivityId}/submit` |
| 3 | POST | `/api/member/activities/{lessonActivityId}/video-progress` |
| 4 | GET | `/api/bible/{translationCode}/{bookNumber}/{chapter}` |

### MATCH: All endpoints match.

### Request body details:

**submitNote (POST /api/member/activities/{id}/submit):**
- **React sends:** `{ lessonScheduleId, note: { type, content } }` or `{ lessonScheduleId, action: 'start' | 'skip_to_complete' }`
- **Laravel sends:** Whatever the client Vue island sends via `$request->json()->all()` (passthrough)
- **Risk:** LOW -- Laravel proxies the request body as-is, so as long as the Vue island sends the same shape as React, it will work.

**saveVideoProgress (POST /api/member/activities/{id}/video-progress):**
- **React sends:** `{ lessonScheduleId, watchedSeconds, totalDuration? }`
- **Laravel sends:** Whatever the client sends (passthrough)
- **Risk:** LOW -- Same passthrough pattern.

**fetchScripture:**
- **React:** Default translation is `'KJV'`
- **Laravel:** Translation comes from the URL parameter
- **Risk:** LOW -- As long as the Blade/Vue code passes the correct translation.

---

## 6. ProfileController

### Laravel (`app/Http/Controllers/ProfileController.php`)

#### show()
No API call -- uses `member` from middleware session.

#### update()
| # | Method | Endpoint |
|---|--------|----------|
| 1 | PATCH | `/api/members/{memberId}` |

**Request body:** `first_name, last_name, gender, birthday`

#### uploadAvatar()
| # | Method | Endpoint |
|---|--------|----------|
| 2 | Upload (POST) | `/api/members/{memberId}/avatar` |

### React (`src/store/ui/edit-profile.ui.ts`)
| # | Method | Endpoint |
|---|--------|----------|
| 1 | PATCH | `/api/members/{memberId}` |
| 2 | Upload (POST) | `/api/members/{memberId}/avatar` |
| 3 | POST | `/api/members/{memberId}/avatar/sync-google` |

**React request body for PATCH:** `{ firstName, lastName, gender, birthday, profilePicture }`

### MISMATCH: Request field names
- **Laravel sends:** `first_name, last_name, gender, birthday` (snake_case)
- **React sends:** `firstName, lastName, gender, birthday, profilePicture` (camelCase)
- **Impact:** HIGH -- The API likely expects camelCase (since React works). Laravel is sending snake_case field names which the API may not recognize, causing silent update failures.

### MISMATCH: Missing `profilePicture` in update
- **Laravel:** Does not send `profilePicture` in the PATCH body
- **React:** Sends `profilePicture` (new avatar URL after upload) alongside profile fields
- **Impact:** MEDIUM -- If avatar is uploaded separately then profile updated, the profile picture URL won't be persisted via the PATCH call. React does both in sequence.

### MISMATCH: Response field for avatar
- **Laravel:** Reads `body['avatarUrl']` or `body['member']['avatarUrl']`
- **React:** Reads `response.data.url`
- **Impact:** MEDIUM -- If the API returns `{ success: true, data: { url: "..." } }`, Laravel will miss the avatar URL and return `null` to the client.

### MISSING in Laravel
- **`/api/members/{id}/avatar/sync-google`** (POST) -- React has a "Sync from Google" button that copies the Google profile picture to the member account. Not implemented in Laravel.

---

## 7. MemberLoginController

### Laravel (`app/Http/Controllers/MemberLoginController.php`)

#### submitPhone()
| # | Method | Endpoint |
|---|--------|----------|
| 1 | POST | `/api/members/verify-phone` |

**Request body:** `{ phoneNumber }`

#### submitVerify()
| # | Method | Endpoint |
|---|--------|----------|
| 2 | POST | `/api/members/confirm-verification` |

**Request body:** `{ phoneNumber, code }`

#### logout()
| # | Method | Endpoint |
|---|--------|----------|
| 3 | POST | `/api/members/logout` |

### React (`src/store/domain/auth.domain.ts` + SessionStore)
| # | Method | Endpoint |
|---|--------|----------|
| 1 | POST | `/api/members/verify-phone` |
| 2 | POST | `/api/members/confirm-verification` |
| 3 | POST | `/api/members/logout` |
| 4 | GET | `/api/members/session` |
| 5 | GET | `/auth/me/linked-user` |

### MATCH: Login/logout endpoints match.

### MISMATCH: Missing `organizationId` in login verify-phone
- **Laravel login:** Sends `{ phoneNumber }` (no organizationId)
- **React login:** Also sends `{ phoneNumber }` (no organizationId for login -- organizationId is only for join flows)
- **Status:** OK -- both match for login.

### MISMATCH: Missing `organizationId` in login confirm-verification
- **Laravel login:** Sends `{ phoneNumber, code }` (no organizationId)
- **React login:** The login flow does not send organizationId either.
- **Status:** OK -- match.

### MISSING in Laravel: Session endpoint
- React calls `GET /api/members/session` on app init to check auth state. Laravel uses middleware cookie check instead. This is architecturally different but not a bug.

### MISSING in Laravel: Linked user endpoint
- React calls `GET /auth/me/linked-user` to get Google-linked account info. Laravel's profile page only uses middleware-provided member data. If the profile page needs to show Google-linked info, this call is missing.

---

## 8. JoinController (Group Join Flow)

### Laravel (`app/Http/Controllers/JoinController.php`)

#### showStep('info') + showStep('confirmed')
| # | Method | Endpoint |
|---|--------|----------|
| 1 | GET | `/api/groups/code/{code}` |

#### submitPhone()
| # | Method | Endpoint |
|---|--------|----------|
| 2 | POST | `/api/members/verify-phone` |

**Request body:** `{ phoneNumber, organizationId }`

#### submitVerify()
| # | Method | Endpoint |
|---|--------|----------|
| 3 | POST | `/api/members/confirm-verification` |
| 4 | POST | `/api/groups/{groupId}/join-requests` |

**Verify request body:** `{ phoneNumber, code, organizationId, firstName, lastName, gender, birthday }`

### React (`src/store/JoinStore.ts`)
| # | Method | Endpoint |
|---|--------|----------|
| 1 | GET | `/api/groups/code/{code}` |
| 2 | POST | `/api/members/verify-phone` |
| 3 | POST | `/api/members/confirm-verification` |
| 4 | POST | `/api/groups/{groupId}/join-requests` |

### MATCH: All endpoints match.

### MISMATCH: Group code response fields
- **Laravel:** Reads `body['group']` for group data, `body['membershipStatus']`, `body['member']`
- **React:** Reads `response.group`, `response.membershipStatus`, `response.member`, `response.membership`, `response.request`
- **Impact:** LOW -- Laravel reads the same top-level fields. It doesn't use `membership` or `request` sub-objects, but it doesn't need them for its simpler server-rendered flow.

### MISMATCH: confirm-verification request body
- **React sends:** `{ phoneNumber, code, organizationId, firstName, lastName, birthday }` (birthday as ISO string via `new Date(birthday).toISOString()`)
- **Laravel sends:** `{ phoneNumber, code, organizationId, firstName, lastName, gender, birthday }` (birthday as raw form value)
- **Impact:** LOW -- Laravel includes `gender` (React does not). Birthday format may differ (React sends ISO, Laravel sends raw date string). The API should handle both, but worth verifying birthday format.

---

## 9. EventJoinController

### Laravel (`app/Http/Controllers/EventJoinController.php`)

#### showStep('info')
| # | Method | Endpoint |
|---|--------|----------|
| 1 | GET | `/api/events/code/{code}` |

#### submitPhone()
| # | Method | Endpoint |
|---|--------|----------|
| 2 | POST | `/api/members/verify-phone` |

#### submitVerify()
| # | Method | Endpoint |
|---|--------|----------|
| 3 | POST | `/api/members/confirm-verification` |
| 4 | POST | `/api/events/{eventId}/attend` |

### React (`src/store/EventJoinStore.ts`)
| # | Method | Endpoint |
|---|--------|----------|
| 1 | GET | `/api/events/code/{code}` |
| 2 | POST | `/api/members/verify-phone` |
| 3 | POST | `/api/members/confirm-verification` |
| 4 | POST | `/api/events/{eventId}/attend` |

### MATCH: All endpoints and request bodies match.

### MISMATCH: confirm-verification request body
- **Laravel sends:** `{ phoneNumber, code, organizationId }` (no profile fields)
- **React sends:** `{ phoneNumber, code, organizationId }` (no profile fields)
- **Status:** MATCH.

---

## 10. StudyJoinController

### Laravel (`app/Http/Controllers/StudyJoinController.php`)

#### showStep('info')
| # | Method | Endpoint |
|---|--------|----------|
| 1 | GET | `/api/lessons/code/{identifier}` |

#### submitPhone()
| # | Method | Endpoint |
|---|--------|----------|
| 2 | POST | `/api/members/verify-phone` |

#### submitVerify()
| # | Method | Endpoint |
|---|--------|----------|
| 3 | POST | `/api/members/confirm-verification` |

### React
No direct equivalent React store for study join. This appears to be a Laravel-only flow (or the React version was a different mechanism).

### Note
- The `/api/lessons/code/{identifier}` endpoint is not called anywhere in the React app. This may be a new endpoint or a feature that was differently implemented in React.
- No join-request submission after verification (unlike group join which calls `/api/groups/{id}/join-requests`). The study join flow only verifies the phone -- it does not register the member for the study. **This may be a bug** -- after verification, the member is authenticated but not enrolled in anything.

---

## 11. PreviewController

### Laravel (`app/Http/Controllers/PreviewController.php`)

#### studyPreview()
| # | Method | Endpoint |
|---|--------|----------|
| 1 | GET | `/public/preview/{token}` |

#### lessonPreview()
| # | Method | Endpoint |
|---|--------|----------|
| 2 | GET | `/public/preview/{token}/lesson/{lessonId}` |

### React (`src/store/domain/preview.domain.ts`)
| # | Method | Endpoint |
|---|--------|----------|
| 1 | GET | `/public/preview/{token}` |
| 2 | GET | `/public/preview/{token}/lesson/{lessonId}` |

### MATCH: Endpoints match.

### MISMATCH: Study preview response field mapping
- **Laravel:** Reads `body['program']` then `body['study']` then raw `body`; reads `body['lessons']` then `studyData['lessons']`
- **React:** Reads `response.program` (expects `{ success, program }`)
- **Impact:** LOW -- Laravel's fallback chain is more defensive. Both will work if API returns `{ success: true, program: {...} }`.

### MISMATCH: Lesson preview response field mapping
- **Laravel:** Reads `body['lesson']` then raw `body`
- **React:** Reads `response.lesson`
- **Impact:** LOW -- Same defensive fallback pattern.

---

## 12. AdminController

### Laravel (`app/Http/Controllers/AdminController.php`)
No API calls. Just checks `member['role'] === 'leader'` and renders view.

### React
No equivalent -- admin is handled by the iPhone app/leader dashboard.

---

## 13. ComplianceController

### Laravel (`app/Http/Controllers/ComplianceController.php`)
No API calls. Static views (privacy, terms, sms-opt-in).

---

## 14. PublicHomeController

### Laravel (`app/Http/Controllers/PublicHomeController.php`)
No API calls. Static public landing page.

---

## 15. StudyCodeController

### Laravel (`app/Http/Controllers/StudyCodeController.php`)
No API calls. Static study code entry page.

---

## Missing from Laravel (React-only API calls)

| React Store | Endpoint | Purpose |
|---|---|---|
| `SessionStore` | `GET /api/members/session` | Check auth state on app init |
| `SessionStore` | `GET /auth/me/linked-user` | Get Google-linked account info |
| `SessionStore` | `PATCH /api/members/{id}` | Auto-save Google profile pic to member |
| `AccountUI` | `GET /auth/google/link-account/url` | Initiate Google account linking |
| `AccountUI` | `DELETE /api/members/me/linked-user` | Unlink Google account |
| `AccountUI` | `POST /api/verification/send` | Phone change verification (different from join flow) |
| `AccountUI` | `POST /api/verification/verify` | Phone change confirm (different endpoint from join) |
| `EditProfileUI` | `POST /api/members/{id}/avatar/sync-google` | Sync Google profile picture |
| `GroupHomeUI` | `POST /api/invites` | Generate group invite |
| `GroupHomeUI` | `POST /api/qrcode/generate` | Generate QR code for invite |
| `GroupsDomain` | `GET /api/organizations/{orgId}/groups` | List org groups (leader) |
| `GroupsDomain` | `GET /api/groups/{id}` | Get group (authenticated/leader) |
| `MembersDomain` | Various | Full member CRUD (leader features) |

---

## Summary of Critical Issues

### HIGH Priority

1. **ProfileController: snake_case vs camelCase field names**
   - Laravel sends `first_name`, `last_name` in PATCH body
   - API likely expects `firstName`, `lastName` (camelCase, matching React)
   - **Fix:** Change `$request->only(...)` keys to camelCase or map them

2. **GroupHomeController: Posts endpoint for non-leaders**
   - Laravel always calls `/api/groups/{id}/posts`
   - React uses `/api/groups/{id}/posts/public` for non-leader members
   - **Fix:** Check member role and use appropriate endpoint

### MEDIUM Priority

3. **StudyHomeController: Response field extraction**
   - Laravel passes raw `body` as studyData
   - API likely returns `{ success: true, enrollment: {...} }`
   - **Fix:** Extract `body['enrollment']` like React does

4. **ProfileController: Avatar upload response field**
   - Laravel reads `body['avatarUrl']`
   - API likely returns `{ success: true, data: { url: "..." } }`
   - **Fix:** Read `body['data']['url']`

5. **GroupHomeController: Posts pagination**
   - Laravel hardcodes `limit=10`, no cursor support
   - React uses `limit=20` with cursor-based infinite scroll
   - **Fix:** Add cursor pagination support or document the limitation

6. **StudyJoinController: No enrollment after verification**
   - After phone verification, the member is authenticated but not enrolled in the study
   - May need a POST to enroll the member

### LOW Priority

7. **ProfileController: Missing `profilePicture` in PATCH**
   - React sends avatar URL in profile PATCH; Laravel does not

8. **ProfileController: Missing Google sync endpoint**
   - React has "Sync from Google" avatar feature; not in Laravel

9. **Missing `/auth/me/linked-user` call**
   - Profile page may need Google-linked account info for display

10. **Birthday format in join verify**
    - React sends ISO string; Laravel sends raw date -- API should handle both
