<?php

namespace App\Http\Controllers;

use Illuminate\View\View;

class ComplianceController extends Controller
{
    public function privacy(): View
    {
        return view('compliance.privacy');
    }

    public function terms(): View
    {
        return view('compliance.terms');
    }

    public function smsOptIn(): View
    {
        return view('compliance.sms-opt-in');
    }
}
