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

        // Single-group redirect: take member straight to their only group
        if (count($groupList) === 1) {
            return redirect()->route('group.home', ['groupId' => $groupList[0]['id']]);
        }

        return response()->view('pages.home-authenticated', compact('member', 'groupList'));
    }
}
