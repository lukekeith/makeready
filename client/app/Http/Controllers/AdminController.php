<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class AdminController extends Controller
{
    public function show(Request $request): \Illuminate\View\View
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

        return view('pages.admin', compact('islandProps'));
    }
}
