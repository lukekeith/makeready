<?php

namespace App\Http\Controllers;

use App\Services\EventLogger;
use App\Services\ActivityTypes;
use Illuminate\Http\Request;

class HomeController extends Controller
{
    public function __construct(private EventLogger $log) {}

    public function index(Request $request)
    {
        $member = $request->attributes->get('member');
        $groupList = $request->attributes->get('memberGroups', []);

        $this->log->logSuccess(ActivityTypes::ACCESS_DASHBOARD_VIEWED, $request, [
            'message' => "Dashboard viewed",
            'memberId' => $member['id'] ?? null,
            'metadata' => ['groupCount' => count($groupList)],
        ]);

        // Members land on a group home; the in-page pager handles navigating
        // between groups when they belong to more than one.
        if (count($groupList) >= 1) {
            return redirect()->route('group.home', ['groupId' => $groupList[0]['id']]);
        }

        // No groups yet — show the empty/authenticated home.
        return response()->view('pages.home-authenticated', compact('member', 'groupList'));
    }
}
