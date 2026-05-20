<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class GroupsController extends Controller
{
    public function index(Request $request)
    {
        $member = $request->attributes->get('member');
        $groupList = $request->attributes->get('memberGroups', []);

        return response()->view('pages.groups', compact('member', 'groupList'));
    }
}
