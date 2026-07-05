<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

/**
 * Mobile-web leader app shell.
 *
 * Renders the LeaderApp Vue island for the new /admin experience (Google-
 * authenticated group leaders). Mirrors AdminController's prop bootstrapping so
 * the island can paint the header/profile without an extra API round-trip.
 */
class LeaderController extends Controller
{
    public function show(Request $request): \Illuminate\Http\Response
    {
        $user = session('admin_user', []);
        $name = $user['name'] ?? '';
        $parts = explode(' ', $name, 2);
        $firstName = $parts[0] ?? '';
        $lastName = $parts[1] ?? '';
        $initials = '';
        if ($firstName) $initials .= strtoupper(substr($firstName, 0, 1));
        if ($lastName) $initials .= strtoupper(substr($lastName, 0, 1));
        if ($initials === '') $initials = '?';

        $islandProps = [
            'avatarUrl'   => $user['picture'] ?? null,
            'initials'    => $initials,
            'memberName'  => $name ?: 'Leader',
            'googleEmail' => $user['email'] ?? null,
            'logoutUrl'   => route('admin.auth.logout'),
            'memberId'    => $user['id'] ?? null,
        ];

        // Never cache the auth-gated app shell — always serve the latest.
        return response()
            ->view('pages.leader', compact('islandProps'))
            ->header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0');
    }
}
