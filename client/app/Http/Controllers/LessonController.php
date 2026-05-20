<?php

namespace App\Http\Controllers;

use App\Services\ApiService;
use App\Services\EventLogger;
use App\Services\ActivityTypes;
use Illuminate\Http\Request;

class LessonController extends Controller
{
    public function __construct(
        private ApiService $api,
        private EventLogger $log,
    ) {}

    /**
     * Render the lesson page shell.
     */
    public function show(Request $request, string $groupId, string $lessonScheduleId, int $step = 1)
    {
        $member   = $request->attributes->get('member');

        $this->log->logSuccess(ActivityTypes::ACCESS_LESSON_STARTED, $request, [
            'message' => "Lesson started", 'memberId' => $member['id'] ?? null,
            'groupId' => $groupId, 'lessonId' => $lessonScheduleId,
            'metadata' => ['step' => $step],
        ]);
        $memberId = $member['id'] ?? '';

        $result = $this->api->get(
            "/api/member/lessons/{$lessonScheduleId}?memberId={$memberId}",
            $request
        );

        if ($result['status'] !== 200) {
            abort(404);
        }

        $lessonData = $result['body'];

        $response = response()->view('pages.lesson', compact(
            'member',
            'groupId',
            'lessonScheduleId',
            'lessonData',
            'step',
        ));

        foreach ($result['setCookies'] as $cookie) {
            $response->header('Set-Cookie', $cookie, false);
        }

        return $response;
    }

    /**
     * AJAX proxy: submit a SOAP note for a lesson activity.
     * Proxies POST to /api/member/activities/{activityId}/submit.
     * Returns JSON response with updated lesson data.
     */
    public function submitNote(Request $request, string $groupId, string $lessonScheduleId, string $activityId)
    {
        $member = $request->attributes->get('member');
        $this->log->logSuccess(ActivityTypes::ACCESS_NOTE_SUBMITTED, $request, [
            'message' => "Note submitted", 'memberId' => $member['id'] ?? null,
            'groupId' => $groupId, 'metadata' => ['activityId' => $activityId],
        ]);

        $data = $request->json()->all();

        $result = $this->api->post(
            "/api/member/activities/{$activityId}/submit",
            $data,
            $request
        );

        $response = response()->json($result['body'], $result['status']);

        foreach ($result['setCookies'] as $cookie) {
            $response->header('Set-Cookie', $cookie, false);
        }

        return $response;
    }

    /**
     * AJAX proxy: save video watch progress for a lesson activity.
     * Proxies POST to /api/member/activities/{activityId}/video-progress.
     * Returns JSON response.
     */
    public function saveVideoProgress(Request $request, string $groupId, string $lessonScheduleId, string $activityId)
    {
        $member = $request->attributes->get('member');
        $this->log->logSuccess(ActivityTypes::ACCESS_VIDEO_PROGRESS_SAVED, $request, [
            'message' => "Video progress saved", 'memberId' => $member['id'] ?? null,
            'groupId' => $groupId, 'metadata' => ['activityId' => $activityId],
        ]);

        $data = $request->json()->all();

        $result = $this->api->post(
            "/api/member/activities/{$activityId}/video-progress",
            $data,
            $request
        );

        $response = response()->json($result['body'], $result['status']);

        foreach ($result['setCookies'] as $cookie) {
            $response->header('Set-Cookie', $cookie, false);
        }

        return $response;
    }

    /**
     * AJAX proxy: mark an EXEGESIS highlight as visited for a lesson activity.
     * Proxies POST to /api/member/activities/{activityId}/exegesis-visit.
     */
    public function visitExegesisHighlight(Request $request, string $groupId, string $lessonScheduleId, string $activityId)
    {
        $member = $request->attributes->get('member');

        // Reuse the existing event logger surface — this is still "member accessing lesson activity"
        $this->log->logSuccess(ActivityTypes::ACCESS_API_REQUEST, $request, [
            'message' => "Exegesis highlight visited",
            'memberId' => $member['id'] ?? null,
            'groupId' => $groupId,
            'metadata' => ['activityId' => $activityId],
        ]);

        $data = $request->json()->all();

        $result = $this->api->post(
            "/api/member/activities/{$activityId}/exegesis-visit",
            $data,
            $request
        );

        $response = response()->json($result['body'], $result['status']);

        foreach ($result['setCookies'] as $cookie) {
            $response->header('Set-Cookie', $cookie, false);
        }

        return $response;
    }

    /**
     * AJAX proxy: fetch scripture text from the Bible API.
     * Public route — no auth required.
     * Proxies GET to /api/bible/{translation}/{book}/{chapter}.
     */
    public function fetchScripture(Request $request, string $translation, string $book, string $chapter)
    {
        $result = $this->api->get(
            "/api/bible/{$translation}/{$book}/{$chapter}",
            $request
        );

        return response()->json($result['body'], $result['status']);
    }
}
