<?php

namespace App\Http\Controllers;

use App\Services\ApiService;
use Illuminate\Http\Request;

class PreviewController extends Controller
{
    public function __construct(private ApiService $api)
    {
    }

    /**
     * Render the study preview page.
     * Public endpoint — no authentication required.
     * Fetches study data via the public preview API token.
     */
    public function studyPreview(Request $request, string $token)
    {
        $result = $this->api->get(
            "/public/preview/{$token}",
            $request
        );

        if ($result['status'] !== 200) {
            abort(404);
        }

        $body      = $result['body'];
        $studyData = $body['program'] ?? $body['study'] ?? $body;
        $lessons   = $body['lessons'] ?? $studyData['lessons'] ?? [];

        $response = response()->view(
            'pages.study-preview',
            compact('token', 'studyData', 'lessons')
        );

        foreach ($result['setCookies'] as $cookie) {
            $response->header('Set-Cookie', $cookie, false);
        }

        return $response;
    }

    /**
     * Render the lesson preview page shell.
     * Public endpoint — no authentication required.
     * Mounts LessonIsland with isPreview=true to disable note saving.
     */
    public function lessonPreview(Request $request, string $token, string $lessonId, int $step = 1)
    {
        $result = $this->api->get(
            "/public/preview/{$token}/lesson/{$lessonId}",
            $request
        );

        if ($result['status'] !== 200) {
            abort(404);
        }

        $body       = $result['body'];
        $lessonData = $body['lesson'] ?? $body;

        $response = response()->view(
            'pages.lesson-preview',
            compact('token', 'lessonId', 'lessonData', 'step')
        );

        foreach ($result['setCookies'] as $cookie) {
            $response->header('Set-Cookie', $cookie, false);
        }

        return $response;
    }

    /**
     * Render a standalone single-activity preview page.
     * Public endpoint — no authentication required.
     * Mounts LessonIsland with singleActivity=true to hide all navigation chrome.
     */
    public function activityPreview(Request $request, string $token, string $activityId)
    {
        $result = $this->api->get(
            "/public/preview/{$token}/activity/{$activityId}",
            $request
        );

        if ($result['status'] !== 200) {
            abort(404);
        }

        $body         = $result['body'];
        $activityData = $body['activity'] ?? $body;

        $response = response()->view(
            'pages.activity-preview',
            compact('token', 'activityData')
        );

        foreach ($result['setCookies'] as $cookie) {
            $response->header('Set-Cookie', $cookie, false);
        }

        return $response;
    }

    /**
     * Render the canonical authenticated read-activity preview.
     * Used by the iPhone (loaded inside a WKWebView with its planted session cookie)
     * and by group leaders in a desktop browser.
     * Auth is enforced by the API: if /api/activities/{id}/preview-data returns
     * non-200, we 404 here (covers unauthenticated requests and non-owned activities).
     */
    public function authenticatedActivityPreview(Request $request, string $activityId)
    {
        // Auth strategy:
        //   1. If the user is signed in as an admin (Google OAuth via /admin/login),
        //      Laravel has their real API session ID stashed under `admin_user_session`.
        //      Forward that directly as `connect.sid` — no second login needed.
        //   2. Otherwise (e.g. iPhone WKWebView with a planted session cookie),
        //      fall back to forwarding whatever cookies the browser carries.
        $result = $this->fetchActivityPreview($request, $activityId);

        if ($result['status'] !== 200) {
            abort(404);
        }

        $activityData = $result['body']['activity'] ?? $result['body'];

        $response = response()->view(
            'pages.activity-preview-authed',
            compact('activityData')
        );

        foreach ($result['setCookies'] as $cookie) {
            $response->header('Set-Cookie', $cookie, false);
        }

        return $response;
    }

    private function fetchActivityPreview(Request $request, string $activityId): array
    {
        return $this->fetchAuthedPreview($request, "/api/activities/{$activityId}/preview-data");
    }

    /**
     * Render the canonical authenticated full-lesson preview — mirrors
     * authenticatedActivityPreview but for an entire Lesson (every activity,
     * read-blocks, themes, videos).
     *
     * Used by the iPhone "Preview" button on day/lesson views (loaded inside
     * WKWebView with its planted `connect.sid`) and by desktop creators via
     * /admin/preview/lesson/{id}. Auth is enforced by the API: non-owners or
     * unauthenticated callers get a 404 response here.
     */
    public function authenticatedLessonPreview(Request $request, string $lessonId, int $step = 1)
    {
        $result = $this->fetchAuthedPreview($request, "/api/lessons/{$lessonId}/preview-data");

        if ($result['status'] !== 200) {
            abort(404);
        }

        $lessonData = $result['body']['lesson'] ?? $result['body'];

        $response = response()->view(
            'pages.lesson-preview-authed',
            compact('lessonData', 'lessonId', 'step')
        );

        foreach ($result['setCookies'] as $cookie) {
            $response->header('Set-Cookie', $cookie, false);
        }

        return $response;
    }

    /**
     * Render the canonical authenticated study overview — mirrors the public
     * studyPreview but keyed on programId (not a token) and gated by the API's
     * creator-ownership check. Renders the same `pages.study-preview` view so
     * the overview layout stays identical between the token and authed flows.
     */
    public function authenticatedStudyPreview(Request $request, string $programId)
    {
        $result = $this->fetchAuthedPreview($request, "/api/programs/{$programId}/preview-data");

        if ($result['status'] !== 200) {
            abort(404);
        }

        $body      = $result['body'];
        $studyData = $body['program'] ?? $body;
        $lessons   = $body['lessons'] ?? $studyData['lessons'] ?? [];

        // Pass null token to the Blade so any token-specific affordances
        // (e.g. copy-link buttons) can hide themselves for the authed flow.
        $token = null;

        $response = response()->view(
            'pages.study-preview',
            compact('token', 'studyData', 'lessons')
        );

        foreach ($result['setCookies'] as $cookie) {
            $response->header('Set-Cookie', $cookie, false);
        }

        return $response;
    }

    /**
     * Shared auth-forwarding helper for canonical previews. If the caller has
     * a Laravel admin session, forward that as `connect.sid` to the API. Any
     * other context (iPhone WKWebView with a planted cookie, for example)
     * falls back to forwarding the browser's cookies verbatim.
     */
    private function fetchAuthedPreview(Request $request, string $endpoint): array
    {
        $adminSessionId = $request->session()->get('admin_user_session');

        if ($adminSessionId) {
            try {
                $response = \Illuminate\Support\Facades\Http::timeout(10)->withHeaders([
                    'Cookie' => 'connect.sid=' . $adminSessionId,
                    'Accept' => 'application/json',
                ])->get(config('services.makeready.url') . $endpoint);
                return [
                    'status'     => $response->status(),
                    'body'       => $response->json() ?? [],
                    'setCookies' => [],
                ];
            } catch (\Throwable $e) {
                \Log::error('Preview admin-session fetch failed: ' . $e->getMessage());
                return ['status' => 500, 'body' => ['error' => $e->getMessage()], 'setCookies' => []];
            }
        }

        return $this->api->get($endpoint, $request);
    }
}
