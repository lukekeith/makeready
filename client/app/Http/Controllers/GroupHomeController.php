<?php

namespace App\Http\Controllers;

use App\Services\ApiService;
use App\Services\EventLogger;
use App\Services\ActivityTypes;
use Illuminate\Http\Request;

class GroupHomeController extends Controller
{
    public function __construct(
        private ApiService $api,
        private EventLogger $log,
    ) {}

    public function show(Request $request, string $groupId)
    {
        $member = $request->attributes->get('member');
        $memberId = $member['id'] ?? '';

        $this->log->logSuccess(ActivityTypes::ACCESS_GROUP_HOME_VIEWED, $request, [
            'message' => "Group home viewed", 'memberId' => $memberId ?: null, 'groupId' => $groupId,
        ]);

        // Load all data upfront before rendering
        $groupResult      = $this->api->get("/api/groups/{$groupId}/public", $request);
        // Use /posts/public for members (React uses /posts for leaders, /posts/public for members)
        $postsResult      = $this->api->get("/api/groups/{$groupId}/posts/public?limit=20", $request);
        $enrollmentResult = $this->api->get("/api/groups/{$groupId}/study-enrollment?memberId={$memberId}", $request);

        // Extract with null-safe defaults
        $groupData = null;
        if ($groupResult['status'] === 200 && is_array($groupResult['body'])) {
            $groupData = $groupResult['body']['group'] ?? $groupResult['body']['data'] ?? null;
        }

        // Get memberSince from pre-loaded groups (loaded by middleware)
        if ($groupData) {
            $memberGroups = $request->attributes->get('memberGroups', []);
            foreach ($memberGroups as $g) {
                if (($g['id'] ?? '') === $groupId) {
                    $groupData['memberSince'] = $g['joinedAt'] ?? $g['createdAt'] ?? null;
                    break;
                }
            }
        }

        $postsData = [];
        if ($postsResult['status'] === 200 && is_array($postsResult['body'])) {
            $postsData = $postsResult['body']['posts'] ?? $postsResult['body']['data'] ?? [];
        }

        $enrollmentData = null;
        if ($enrollmentResult['status'] === 200 && is_array($enrollmentResult['body'])) {
            $enrollmentData = $enrollmentResult['body']['enrollment'] ?? $enrollmentResult['body']['data'] ?? null;
        }

        $response = response()->view('pages.group-home', compact(
            'member',
            'groupId',
            'groupData',
            'postsData',
            'enrollmentData'
        ));

        // Forward Set-Cookie headers from all 3 responses
        foreach ($groupResult['setCookies'] as $cookie) {
            $response->header('Set-Cookie', $cookie, false);
        }
        foreach ($postsResult['setCookies'] as $cookie) {
            $response->header('Set-Cookie', $cookie, false);
        }
        foreach ($enrollmentResult['setCookies'] as $cookie) {
            $response->header('Set-Cookie', $cookie, false);
        }

        return $response;
    }
}
