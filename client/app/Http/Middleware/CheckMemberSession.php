<?php

namespace App\Http\Middleware;

use App\Services\ApiService;
use App\Services\EventLogger;
use App\Services\ActivityTypes;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class CheckMemberSession
{
    public function __construct(
        private ApiService $api,
        private EventLogger $log,
    ) {}

    public function handle(Request $request, Closure $next): Response
    {
        $setCookies = [];
        $member = null;
        $user = null;
        $sessionType = null; // 'member' or 'user'

        // 1. Try member session first
        $memberResult = $this->api->get('/api/members/session', $request);
        $setCookies = array_merge($setCookies, $memberResult['setCookies']);

        if ($memberResult['status'] === 200
            && !empty($memberResult['body']['authenticated'])
            && $memberResult['body']['authenticated'] === true
        ) {
            $member = $memberResult['body']['member'] ?? null;
            $sessionType = 'member';
        }

        // 2. If no member session, try user (leader) session
        if (!$sessionType) {
            $userResult = $this->api->get('/auth/me', $request);
            $setCookies = array_merge($setCookies, $userResult['setCookies']);

            if ($userResult['status'] === 200 && !empty($userResult['body']['user'])) {
                $user = $userResult['body']['user'];
                $sessionType = 'user';

                // Build a member-like object from the user data so views can render
                $member = [
                    'id' => $user['id'],
                    'firstName' => $user['name'] ? explode(' ', $user['name'], 2)[0] : '',
                    'lastName' => $user['name'] ? (explode(' ', $user['name'], 2)[1] ?? '') : '',
                    'profilePicture' => $user['picture'] ?? null,
                    'avatarUrl' => $user['picture'] ?? null,
                    'email' => $user['email'] ?? null,
                ];
            }
        }

        // 3. No valid session at all — redirect to login
        if (!$sessionType) {
            $this->log->logWarning(ActivityTypes::AUTH_SESSION_CHECK_FAILED, $request, [
                'message' => "Session check failed, redirecting to /",
                'metadata' => ['attemptedRoute' => $request->path()],
            ]);
            return redirect('/');
        }

        // 4. Load groups based on session type
        $memberGroups = [];
        if ($sessionType === 'member' && !empty($member['id'])) {
            $groupsResult = $this->api->get("/api/members/{$member['id']}/groups", $request);
            $setCookies = array_merge($setCookies, $groupsResult['setCookies']);
            if ($groupsResult['status'] === 200 && is_array($groupsResult['body'])) {
                $memberGroups = $groupsResult['body']['data'] ?? $groupsResult['body']['groups'] ?? [];
            }
        } elseif ($sessionType === 'user') {
            $groupsResult = $this->api->get('/api/groups', $request);
            $setCookies = array_merge($setCookies, $groupsResult['setCookies']);
            if ($groupsResult['status'] === 200 && is_array($groupsResult['body'])) {
                $memberGroups = $groupsResult['body']['groups'] ?? $groupsResult['body']['data'] ?? [];
            }
        }

        // Share data with all views
        $request->attributes->set('member', $member);
        $request->attributes->set('memberGroups', $memberGroups);
        $request->attributes->set('sessionType', $sessionType);
        $request->attributes->set('user', $user);

        $response = $next($request);

        // Forward Set-Cookie headers from all API calls
        foreach ($setCookies as $cookieHeader) {
            $response->headers->set('Set-Cookie', $cookieHeader, false);
        }

        return $response;
    }
}
