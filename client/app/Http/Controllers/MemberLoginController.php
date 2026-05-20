<?php

namespace App\Http\Controllers;

use App\Services\ApiService;
use App\Services\EventLogger;
use App\Services\ActivityTypes;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class MemberLoginController extends Controller
{
    public function __construct(
        private ApiService $api,
        private EventLogger $log,
    ) {}

    /**
     * Show phone entry step (GET /login).
     */
    public function showPhone(Request $request): View
    {
        return view('pages.login', ['step' => 'phone']);
    }

    /**
     * Submit phone number and trigger SMS (POST /login/phone).
     *
     * Stores phone in session so the verify step can retrieve it.
     * Returns a JSON response with a redirectUrl for the Vue island's AJAX
     * submit handler.
     */
    public function submitPhone(Request $request): JsonResponse
    {
        $phone = $request->input('phoneNumber') ?? $request->input('phone', '');

        // Store phone in session for the verify step.
        session()->put('login.phone', $phone);

        $result = $this->api->post('/api/members/verify-phone', [
            'phoneNumber' => $phone,
        ], $request);

        if ($result['status'] !== 200) {
            $error = $result['body']['error'] ?? $result['body']['message'] ?? 'Failed to send verification code';
            $this->log->logFailure(ActivityTypes::AUTH_MEMBER_LOGIN_PHONE_SUBMITTED, $request, [
                'message' => "Login SMS send failed",
                'errorMessage' => $error,
                'metadata' => ['phoneLast4' => EventLogger::maskPhone($phone)],
            ]);
            return response()->json(['error' => $error], $result['status']);
        }

        $this->log->logSuccess(ActivityTypes::AUTH_MEMBER_LOGIN_PHONE_SUBMITTED, $request, [
            'message' => "Login SMS sent",
            'metadata' => ['phoneLast4' => EventLogger::maskPhone($phone)],
        ]);

        $response = response()->json(['redirectUrl' => route('login.verify')]);

        // Forward any Set-Cookie headers from the API.
        foreach ($result['setCookies'] as $cookie) {
            $response->header('Set-Cookie', $cookie, false);
        }

        return $response;
    }

    /**
     * Show verify code step (GET /login/verify).
     *
     * Reads phone from session. If not present, redirects back to login.
     */
    public function showVerify(Request $request): View|RedirectResponse
    {
        $phone = session('login.phone');

        if (! $phone) {
            return redirect()->route('login');
        }

        return view('pages.login', [
            'step'  => 'verify',
            'phone' => $phone,
        ]);
    }

    /**
     * Submit verification code (POST /login/verify).
     *
     * Confirms the SMS code with the API. On success, clears the login session
     * data and returns a JSON redirect to /home. The API response MUST be
     * forwarded via Set-Cookie — it carries the authenticated session cookie.
     */
    public function submitVerify(Request $request): JsonResponse
    {
        $phone = session('login.phone', '');
        $code  = $request->input('code', '');

        $result = $this->api->post('/api/members/confirm-verification', [
            'phoneNumber' => $phone,
            'code'        => $code,
        ], $request);

        if ($result['status'] !== 200) {
            $error = $result['body']['error'] ?? $result['body']['message'] ?? 'Invalid verification code';
            $this->log->logFailure(ActivityTypes::AUTH_MEMBER_LOGIN_FAILED, $request, [
                'message' => "Login verification failed",
                'errorMessage' => $error,
                'metadata' => ['phoneLast4' => EventLogger::maskPhone($phone)],
            ]);
            return response()->json(['error' => $error], $result['status']);
        }

        $memberId = $result['body']['data']['id'] ?? null;
        $this->log->logSuccess(ActivityTypes::AUTH_MEMBER_LOGIN_VERIFIED, $request, [
            'message' => "Member login verified",
            'memberId' => $memberId,
            'metadata' => ['phoneLast4' => EventLogger::maskPhone($phone)],
        ]);

        // Clear login session data — authentication is now handled by API cookie.
        session()->forget('login');

        $response = response()->json(['redirectUrl' => route('home')]);

        // CRITICAL: forward the API session cookie that authenticates future requests.
        foreach ($result['setCookies'] as $cookie) {
            $response->header('Set-Cookie', $cookie, false);
        }

        return $response;
    }

    /**
     * Logout (POST /logout).
     *
     * Calls the API logout endpoint, flushes the local session, then redirects
     * to the public home page. Forwarding the API's Set-Cookie headers clears
     * the API session cookie in the browser.
     */
    public function logout(Request $request): RedirectResponse
    {
        $this->log->logSuccess(ActivityTypes::AUTH_MEMBER_LOGOUT, $request, [
            'message' => "Member logged out",
        ]);

        $result = $this->api->post('/api/members/logout', [], $request);

        // Flush local session regardless of API response.
        $request->session()->flush();

        $redirect = redirect('/');

        // Forward Set-Cookie headers to clear the API session cookie in the browser.
        foreach ($result['setCookies'] as $cookie) {
            $redirect->header('Set-Cookie', $cookie, false);
        }

        return $redirect;
    }
}
