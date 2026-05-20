<?php

namespace App\Http\Controllers;

use App\Services\ApiService;
use App\Services\EventLogger;
use App\Services\ActivityTypes;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;

class ProfileController extends Controller
{
    public function __construct(
        private ApiService $api,
        private EventLogger $log,
    ) {}

    /**
     * Show the member profile page.
     * Member data already loaded by CheckMemberSession middleware.
     */
    public function show(Request $request)
    {
        $member = $request->attributes->get('member');

        return view('pages.profile', compact('member'));
    }

    /**
     * Update member profile fields via PATCH to the API.
     */
    public function update(Request $request): RedirectResponse
    {
        $member = $request->attributes->get('member');
        $this->log->logSuccess(ActivityTypes::ACCESS_PROFILE_UPDATED, $request, [
            'message' => "Profile updated", 'memberId' => $member['id'] ?? null,
        ]);

        $request->validate([
            'first_name' => ['required', 'string', 'max:50'],
            'last_name'  => ['required', 'string', 'max:50'],
            'gender'     => ['nullable', 'string'],
            'birthday'   => ['nullable', 'date'],
        ]);

        $result = $this->api->patch(
            "/api/members/{$member['id']}",
            [
                'firstName' => $request->input('first_name'),
                'lastName'  => $request->input('last_name'),
                'gender'    => $request->input('gender'),
                'birthday'  => $request->input('birthday'),
            ],
            $request
        );

        $response = redirect()->route('profile');

        foreach ($result['setCookies'] as $cookie) {
            $response->header('Set-Cookie', $cookie, false);
        }

        if ($result['status'] >= 200 && $result['status'] < 300) {
            return $response->with('success', 'Profile updated successfully.');
        }

        return $response
            ->with('error', $result['body']['message'] ?? 'Failed to update profile.')
            ->withInput();
    }

    /**
     * Upload a member avatar via multipart forwarding to the API.
     * Returns JSON (suitable for AJAX or standard form submit).
     */
    public function uploadAvatar(Request $request): JsonResponse
    {
        $member = $request->attributes->get('member');
        $this->log->logSuccess(ActivityTypes::ACCESS_AVATAR_UPLOADED, $request, [
            'message' => "Avatar uploaded", 'memberId' => $member['id'] ?? null,
        ]);

        $request->validate([
            'avatar' => ['required', 'image', 'max:5120'],
        ]);

        $result = $this->api->upload(
            "/api/members/{$member['id']}/avatar",
            'avatar',
            $request->file('avatar'),
            $request
        );

        $headers = [];
        foreach ($result['setCookies'] as $cookie) {
            $headers['Set-Cookie'][] = $cookie;
        }

        if ($result['status'] >= 200 && $result['status'] < 300) {
            return response()->json([
                'success'   => true,
                'avatarUrl' => $result['body']['data']['url'] ?? $result['body']['avatarUrl'] ?? $result['body']['member']['avatarUrl'] ?? null,
            ], 200, $headers);
        }

        return response()->json([
            'success' => false,
            'message' => $result['body']['message'] ?? 'Failed to upload avatar.',
        ], $result['status'], $headers);
    }
}
