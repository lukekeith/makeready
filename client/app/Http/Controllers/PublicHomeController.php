<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\Response;

class PublicHomeController extends Controller
{
    /**
     * Public landing page.
     *
     * Check for connect.sid cookie to detect logged-in state without an API call.
     * Member data is fetched client-side via a lightweight Vue island if needed.
     */
    public function index(Request $request): Response
    {
        // Check if the user likely has an active session (cookie exists)
        $hasSession = str_contains($request->header('Cookie', ''), 'connect.sid=');

        return response()->view('pages.public-home', compact('hasSession'));
    }
}
