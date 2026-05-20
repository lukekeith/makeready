<?php

namespace App\Http\Controllers;

use App\Services\ApiService;
use App\Services\EventLogger;
use App\Services\ActivityTypes;
use Illuminate\Http\Request;

class StudyHomeController extends Controller
{
    public function __construct(
        private ApiService $api,
        private EventLogger $log,
    ) {}

    public function show(Request $request, string $groupId, string $studyEnrollmentId)
    {
        $member   = $request->attributes->get('member');
        $memberId = $member['id'] ?? '';

        $this->log->logSuccess(ActivityTypes::ACCESS_STUDY_HOME_VIEWED, $request, [
            'message' => "Study home viewed", 'memberId' => $memberId ?: null,
            'groupId' => $groupId, 'enrollmentId' => $studyEnrollmentId,
        ]);

        $result = $this->api->get(
            "/api/groups/{$groupId}/study-enrollment/{$studyEnrollmentId}?memberId={$memberId}",
            $request
        );

        if ($result['status'] !== 200) {
            abort(404);
        }

        $studyData = $result['body']['enrollment'] ?? $result['body'];

        $response = response()->view(
            'pages.study-home',
            compact('member', 'groupId', 'studyEnrollmentId', 'studyData')
        );

        foreach ($result['setCookies'] as $cookie) {
            $response->header('Set-Cookie', $cookie, false);
        }

        return $response;
    }
}
