<?php

namespace App\Http\Controllers;

class StudyCodeController extends Controller
{
    /**
     * Show the study code entry page.
     * No authentication required — public entry point for study join flows.
     */
    public function show()
    {
        return view('pages.study-code');
    }
}
