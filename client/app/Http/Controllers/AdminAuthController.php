<?php

namespace App\Http\Controllers;

use App\Services\ApiService;
use App\Services\EventLogger;
use App\Services\ActivityTypes;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Laravel\Socialite\Facades\Socialite;

/**
 * Google OAuth for the admin panel.
 */
class AdminAuthController extends Controller
{
    public function __construct(
        private ApiService $api,
        private EventLogger $log,
    ) {}

    /**
     * Show the admin login page.
     */
    public function showLogin(Request $request)
    {
        // Already authenticated — go to admin
        if (session('admin_user_session')) {
            return redirect('/admin');
        }

        // Never let the browser cache the auth-gated admin HTML (prevents a stale
        // shell from sticking around after a deploy/edit).
        return response()
            ->view('pages.leader-login', ['error' => session('error')])
            ->header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0');
    }

    /**
     * Redirect to Google OAuth consent screen.
     */
    public function redirectToGoogle()
    {
        $this->log->logSuccess(ActivityTypes::AUTH_ADMIN_OAUTH_INITIATED, request(), [
            'message' => 'Admin Google OAuth initiated',
        ]);

        return Socialite::driver('google')
            ->scopes(['openid', 'profile', 'email'])
            ->with(['access_type' => 'offline'])
            ->redirect();
    }

    /**
     * Handle Google OAuth callback → exchange for API session.
     */
    public function handleCallback(Request $request)
    {
        $code = $request->query('code');
        if (!$code) {
            $this->log->logFailure(ActivityTypes::AUTH_ADMIN_OAUTH_FAILED, $request, [
                'message' => 'Admin OAuth failed — no authorization code',
            ]);
            return redirect('/admin/login')->with('error', 'Google sign-in failed — no authorization code.');
        }

        // Exchange the auth code for tokens directly via Google's token endpoint
        $tokenResponse = Http::asForm()->post('https://oauth2.googleapis.com/token', [
            'code'          => $code,
            'client_id'     => config('services.google.client_id'),
            'client_secret' => config('services.google.client_secret'),
            'redirect_uri'  => config('services.google.redirect'),
            'grant_type'    => 'authorization_code',
        ]);

        if ($tokenResponse->failed()) {
            return redirect('/admin/login')->with('error', 'Google sign-in failed — token exchange error.');
        }

        $idToken = $tokenResponse->json('id_token');
        if (!$idToken) {
            return redirect('/admin/login')->with('error', 'Google sign-in failed — no ID token in response.');
        }

        // Exchange the Google ID token for an API session
        $apiUrl = config('services.makeready.url');
        $result = Http::post("{$apiUrl}/auth/google/token-exchange", [
            'idToken' => $idToken,
        ]);

        if ($result->status() !== 200 || empty($result->json('sessionId'))) {
            $error = $result->json('error') ?? 'Could not establish API session.';
            return redirect('/admin/login')->with('error', "Google sign-in failed — {$error}");
        }

        $body = $result->json();

        // The new /admin is exclusively for group leaders. Gate on the server's
        // canAccessIosApp check (Super Admin / org owner / Owner-Admin-Group Leader
        // role) using the freshly-minted session, BEFORE admitting the user.
        $access = Http::withHeaders([
            'Cookie' => 'connect.sid=' . $body['sessionId'],
        ])->get("{$apiUrl}/auth/leader-access");

        if ($access->status() !== 200 || $access->json('canAccess') !== true) {
            $this->log->logFailure(ActivityTypes::AUTH_ADMIN_OAUTH_FAILED, $request, [
                'message' => 'Admin OAuth blocked — not a group leader: ' . ($body['user']['email'] ?? 'unknown'),
                'metadata' => ['userEmail' => $body['user']['email'] ?? null],
            ]);
            return redirect('/admin/login')->with(
                'error',
                'This area is for group leaders. Your Google account isn\'t a leader on any group yet.'
            );
        }

        // Store the API session in Laravel's server-side session
        session()->put('admin_user_session', $body['sessionId']);
        session()->put('admin_user', $body['user'] ?? null);
        session()->save();

        $this->log->logSuccess(ActivityTypes::AUTH_ADMIN_OAUTH_COMPLETED, $request, [
            'message' => 'Admin OAuth completed: ' . ($body['user']['email'] ?? 'unknown'),
            'userId' => $body['user']['id'] ?? null,
            'metadata' => ['userEmail' => $body['user']['email'] ?? null],
        ]);

        return redirect('/admin');
    }

    /**
     * Clear the admin user session.
     */
    public function logout(Request $request)
    {
        session()->forget(['admin_user_session', 'admin_user']);
        return redirect('/admin');
    }
}
