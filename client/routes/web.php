<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\ComplianceController;
use App\Http\Controllers\HomeController;
use App\Http\Controllers\MarketingController;
use App\Http\Controllers\JoinBetaController;
use App\Http\Controllers\MemberLoginController;
use App\Http\Controllers\JoinController;
use App\Http\Controllers\EventJoinController;
use App\Http\Controllers\StudyJoinController;
use App\Http\Controllers\SlidesController;
use App\Http\Controllers\GroupsController;
use App\Http\Controllers\GroupHomeController;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\AdminController;
use App\Http\Controllers\StudyCodeController;
use App\Http\Controllers\StudyHomeController;
use App\Http\Controllers\LessonController;
use App\Http\Controllers\PreviewController;
use App\Http\Controllers\AdminApiProxyController;
use App\Http\Controllers\Admin\LogsController as AdminLogsController;
use App\Http\Controllers\AdminAuthController;
use App\Http\Controllers\CaptureController;

// ─── Public (no auth required) ────────────────────────────────────────────────

Route::get('/', [MarketingController::class, 'home'])->name('home.public');
Route::get('/for-leaders', [MarketingController::class, 'leaders'])->name('marketing.leaders');
Route::get('/for-members', [MarketingController::class, 'members'])->name('marketing.members');
Route::get('/about', [MarketingController::class, 'about'])->name('marketing.about');
Route::get('/join-beta', [JoinBetaController::class, 'show'])->name('join-beta');
Route::get('/join-beta/auth/google', [JoinBetaController::class, 'redirectToGoogle'])->name('join-beta.auth.google');
Route::get('/join-beta/auth/google/callback', [JoinBetaController::class, 'handleGoogleCallback'])->name('join-beta.auth.google.callback');
Route::get('/join-beta/application', [JoinBetaController::class, 'application'])->name('join-beta.application');
Route::post('/join-beta/application', [JoinBetaController::class, 'submitApplication'])->name('join-beta.application.submit');
Route::get('/join-beta/submitted', [JoinBetaController::class, 'submitted'])->name('join-beta.submitted');

// Slides animation test bench (dev only)
Route::get('/slides', [SlidesController::class, 'index'])->name('slides');
Route::get('/slides/themes', [SlidesController::class, 'themes'])->name('slides.themes');

// Member login flow
Route::get('/login', [MemberLoginController::class, 'showPhone'])->name('login');
Route::post('/login/phone', [MemberLoginController::class, 'submitPhone'])->name('login.phone.submit');
Route::get('/login/verify', [MemberLoginController::class, 'showVerify'])->name('login.verify');
Route::post('/login/verify', [MemberLoginController::class, 'submitVerify'])->name('login.verify.submit');
Route::post('/logout', [MemberLoginController::class, 'logout'])->name('logout');

// Group join flow
Route::get('/join/group', [JoinController::class, 'showEnterCode'])->name('join.enter-code');
Route::post('/join/group', [JoinController::class, 'submitCode'])->name('join.code.submit');
Route::get('/join/group/{id}/{step?}', [JoinController::class, 'showStep'])->name('join.group');
Route::post('/join/group/{id}/info', [JoinController::class, 'submitInfo'])->name('join.group.info.submit');
Route::post('/join/group/{id}/optin', [JoinController::class, 'submitOptin'])->name('join.group.optin.submit');
Route::post('/join/group/{id}/profile', [JoinController::class, 'submitProfile'])->name('join.group.profile.submit');
Route::post('/join/group/{id}/phone', [JoinController::class, 'submitPhone'])->name('join.group.phone.submit');
Route::post('/join/group/{id}/verify', [JoinController::class, 'submitVerify'])->name('join.group.verify.submit');

// Event join flow
Route::get('/join/event', [EventJoinController::class, 'showEnterCode'])->name('event.enter-code');
Route::get('/join/event/{id}/{step?}', [EventJoinController::class, 'showStep'])->name('join.event');
Route::post('/join/event/{id}/optin', [EventJoinController::class, 'submitOptin'])->name('join.event.optin.submit');
Route::post('/join/event/{id}/phone', [EventJoinController::class, 'submitPhone'])->name('join.event.phone.submit');
Route::post('/join/event/{id}/verify', [EventJoinController::class, 'submitVerify'])->name('join.event.verify.submit');

// Study join flow
Route::get('/join/study/{id}/{step?}', [StudyJoinController::class, 'showStep'])->name('join.study');
Route::post('/join/study/{id}/optin', [StudyJoinController::class, 'submitOptin'])->name('join.study.optin.submit');
Route::post('/join/study/{id}/phone', [StudyJoinController::class, 'submitPhone'])->name('join.study.phone.submit');
Route::post('/join/study/{id}/verify', [StudyJoinController::class, 'submitVerify'])->name('join.study.verify.submit');

// Study code entry (public — no auth)
Route::get('/join/study', [StudyCodeController::class, 'show'])->name('study.code');

// Public preview pages (no auth required — for non-members to preview content)
Route::get('/public/preview/{token}', [PreviewController::class, 'studyPreview'])->name('preview.study');
Route::get('/public/preview/{token}/lesson/{lessonId}/{step?}', [PreviewController::class, 'lessonPreview'])->name('preview.lesson');
Route::get('/public/preview/{token}/activity/{activityId}', [PreviewController::class, 'activityPreview'])->name('preview.activity');

// Canonical preview route — no Laravel-level auth. Auth is enforced by the
// API when PreviewController forwards whichever cookies the browser carries
// (the iPhone WKWebView plants `connect.sid` from its OAuth session before
// loading). Desktop admins can use /admin/preview/activity/{id} instead; that
// path uses their Laravel admin session automatically.
Route::get('/preview/activity/{activityId}', [PreviewController::class, 'authenticatedActivityPreview'])
    ->name('preview.activity.authed');

// Authenticated lesson preview — mirrors the activity preview pattern. Auth is
// enforced by the API (/api/lessons/{id}/preview-data returns 404 to non-owners).
// Used by the iPhone's day/lesson "Preview" button and by desktop creators.
Route::get('/preview/lesson/{lessonId}/{step?}', [PreviewController::class, 'authenticatedLessonPreview'])
    ->name('preview.lesson.authed');

// Authenticated full-study preview — study overview with lesson list. Non-owners
// get 404. Used by the program home page's eye icon in the iPhone app.
Route::get('/preview/study/{programId}', [PreviewController::class, 'authenticatedStudyPreview'])
    ->name('preview.study.authed');

// ─── Protected (require member auth) ──────────────────────────────────────────

Route::middleware('member.auth')->prefix('member')->group(function () {
    Route::get('/home', [HomeController::class, 'index'])->name('home');
    Route::get('/groups', [GroupsController::class, 'index'])->name('groups');
    Route::get('/groups/{groupId}', [GroupHomeController::class, 'show'])->name('group.home');
    Route::get('/profile', [ProfileController::class, 'show'])->name('profile');
    Route::post('/profile', [ProfileController::class, 'update'])->name('profile.update');
    Route::post('/profile/avatar', [ProfileController::class, 'uploadAvatar'])->name('profile.avatar');
    Route::get('/groups/{groupId}/study/{studyEnrollmentId}', [StudyHomeController::class, 'show'])->name('study.home');
    Route::get('/groups/{groupId}/lessons/{lessonScheduleId}/{step?}', [LessonController::class, 'show'])->name('lesson.show');
    Route::post('/groups/{groupId}/lessons/{lessonScheduleId}/activity/{activityId}/submit', [LessonController::class, 'submitNote'])->name('lesson.activity.submit');
    Route::post('/groups/{groupId}/lessons/{lessonScheduleId}/activity/{activityId}/video-progress', [LessonController::class, 'saveVideoProgress'])->name('lesson.video.progress');
    Route::post('/groups/{groupId}/lessons/{lessonScheduleId}/activity/{activityId}/exegesis-visit', [LessonController::class, 'visitExegesisHighlight'])->name('lesson.exegesis.visit');
});

// Leader admin — public auth routes (no middleware)
Route::prefix('admin')->name('admin.')->group(function () {
    Route::get('/login', [AdminAuthController::class, 'showLogin'])->name('login');
    Route::get('/auth/google', [AdminAuthController::class, 'redirectToGoogle'])->name('auth.google');
    Route::get('/auth/google/callback', [AdminAuthController::class, 'handleCallback'])->name('auth.google.callback');
    Route::post('/auth/logout', [AdminAuthController::class, 'logout'])->name('auth.logout');
});

// Leader admin — protected (requires Google auth)
Route::middleware('admin.auth')->prefix('admin')->name('admin.')->group(function () {
    // Local Laravel-side logs viewer. Must come before the API proxy catch-all
    // so /admin/api/logs is served from disk instead of forwarded to the Node API.
    Route::get('/api/logs', [AdminLogsController::class, 'index'])->name('api.logs');

    // API proxy — must come before the catch-all Blade route
    Route::match(['GET', 'POST', 'PATCH', 'PUT', 'DELETE'], '/api/{path}', [AdminApiProxyController::class, 'handle'])
        ->where('path', '.*')
        ->name('api.proxy');

    // Canonical activity preview — uses the admin's API session automatically.
    // Must come before the catch-all Blade route.
    Route::get('/preview/activity/{activityId}', [PreviewController::class, 'authenticatedActivityPreview'])
        ->name('preview.activity.authed');

    // Canonical lesson preview — same pattern.
    Route::get('/preview/lesson/{lessonId}/{step?}', [PreviewController::class, 'authenticatedLessonPreview'])
        ->name('preview.lesson.authed');

    // Canonical study preview — full program overview.
    Route::get('/preview/study/{programId}', [PreviewController::class, 'authenticatedStudyPreview'])
        ->name('preview.study.authed');

    Route::get('/{any?}', [AdminController::class, 'show'])
        ->where('any', '.*')
        ->name('shell');
});

// ─── Public content routes ─────────────────────────────────────────────────────

Route::get('/api/bible/{translation}/{book}/{chapter}', [LessonController::class, 'fetchScripture'])->name('lesson.scripture');

// Lightweight session check for client-side components (no middleware overhead)
Route::get('/api/member-session', function (\Illuminate\Http\Request $request) {
    $api = app(\App\Services\ApiService::class);
    $result = $api->get('/api/members/session', $request);
    return response()->json($result['body'], $result['status']);
});

// ─── Pages (public, no auth required) ────────────────────────────────────────

Route::get('/privacy', [ComplianceController::class, 'privacy'])->name('privacy');
Route::get('/terms', [ComplianceController::class, 'terms'])->name('terms');
Route::get('/sms-terms', [ComplianceController::class, 'smsOptIn'])->name('sms-opt-in');
Route::get('/contact', fn () => view('pages.contact'))->name('contact');

Route::get('/pages/privacy', [ComplianceController::class, 'privacy'])->name('legacy.privacy');
Route::get('/pages/terms', [ComplianceController::class, 'terms'])->name('legacy.terms');
Route::get('/pages/sms-opt-in', [ComplianceController::class, 'smsOptIn'])->name('legacy.sms-opt-in');
Route::get('/pages/contact', fn () => view('pages.contact'))->name('legacy.contact');

// ─── Test routes (PHPUnit smoke tests only) ────────────────────────────────────

if (app()->environment('testing')) {
    Route::get('/test/cva', fn () => view('test.cva-test'))->name('test.cva');
}

// ─── Screenshot capture (local-only) ───────────────────────────────────────────

if (app()->environment('local')) {
    Route::get('/_capture/{workflow}/assets/{file}', [CaptureController::class, 'asset'])
        ->where('file', '[A-Za-z0-9._-]+')
        ->name('capture.asset');
    Route::get('/_capture/{workflow}/{screen}', [CaptureController::class, 'show'])
        ->name('capture.show');
}

