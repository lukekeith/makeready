<?php

namespace App\Http\Controllers;

use App\Services\ApiService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\View\View;

class JoinBetaController extends Controller
{
    public function __construct(private ApiService $api) {}

    public function show(Request $request): View
    {
        return view('pages.marketing.join-beta', [
            'faqs' => $this->faqs('join-beta', $request),
        ]);
    }

    public function redirectToGoogle(): RedirectResponse
    {
        $clientId = config('services.google.client_id');
        if (! $clientId) {
            return redirect('/join-beta')->with('error', 'Google sign-in is not configured yet.');
        }

        $state = bin2hex(random_bytes(24));
        session()->put('join_beta_google_state', $state);
        session()->save();

        $query = http_build_query([
            'client_id' => $clientId,
            'response_type' => 'code',
            'redirect_uri' => route('join-beta.auth.google.callback'),
            'scope' => 'openid profile email',
            'state' => $state,
            'access_type' => 'offline',
            'prompt' => 'select_account',
        ]);

        return redirect()->away("https://accounts.google.com/o/oauth2/v2/auth?{$query}");
    }

    public function handleGoogleCallback(Request $request): RedirectResponse
    {
        $code = $request->query('code');
        $state = $request->query('state');
        if (!$code || !$state || !hash_equals((string) session('join_beta_google_state'), (string) $state)) {
            return redirect('/join-beta')->with('error', 'Google sign-in failed. Please try again.');
        }

        $tokenResponse = Http::asForm()->post('https://oauth2.googleapis.com/token', [
            'code' => $code,
            'client_id' => config('services.google.client_id'),
            'client_secret' => config('services.google.client_secret'),
            'redirect_uri' => route('join-beta.auth.google.callback'),
            'grant_type' => 'authorization_code',
        ]);

        session()->forget('join_beta_google_state');

        if ($tokenResponse->failed()) {
            return redirect('/join-beta')->with('error', 'Google sign-in failed during token exchange.');
        }

        $idToken = $tokenResponse->json('id_token');
        if (!$idToken) {
            return redirect('/join-beta')->with('error', 'Google sign-in did not return an identity token.');
        }

        session()->put('join_beta_id_token', $idToken);
        session()->put('join_beta_google_user', $this->decodeJwtProfile($idToken));
        session()->save();

        return redirect('/join-beta/application');
    }

    public function application(Request $request): View|RedirectResponse
    {
        if (!session('join_beta_id_token')) {
            return redirect('/join-beta')->with('error', 'Sign in with Google before starting the beta application.');
        }

        return view('pages.marketing.join-beta-application', [
            'googleUser' => session('join_beta_google_user', []),
        ]);
    }

    public function submitApplication(Request $request): RedirectResponse
    {
        $idToken = session('join_beta_id_token');
        if (!$idToken) {
            return redirect('/join-beta')->with('error', 'Your Google sign-in expired. Please sign in again.');
        }

        $validated = $request->validate([
            'phoneNumber' => ['nullable', 'string', 'max:40'],
            'organizationName' => ['required', 'string', 'min:2', 'max:200'],
            'organizationWebsite' => ['nullable', 'url', 'max:500'],
            'groupMemberAgeRange' => ['required', 'string', 'min:2', 'max:120'],
            'numberOfGroups' => ['required', 'integer', 'min:1', 'max:500'],
            'estimatedGroupMembers' => ['required', 'integer', 'min:1', 'max:100000'],
            'groupDescription' => ['required', 'string', 'min:20', 'max:5000'],
        ]);

        $result = $this->api->post('/api/beta/applications', [
            ...$validated,
            'idToken' => $idToken,
        ], $request);

        if ($result['status'] === 201 && ($result['body']['success'] ?? false)) {
            session()->forget(['join_beta_id_token', 'join_beta_google_user']);
            session()->put('join_beta_submission', $result['body']['application'] ?? []);
            return redirect('/join-beta/submitted');
        }

        $message = $result['body']['error'] ?? 'Could not submit your beta application. Please try again.';
        return back()->withInput()->withErrors(['application' => $message]);
    }

    public function submitted(): View
    {
        return view('pages.marketing.join-beta-submitted', [
            'application' => session('join_beta_submission', []),
        ]);
    }

    private function faqs(string $scope, Request $request): array
    {
        $result = $this->api->get('/public/faqs/' . rawurlencode($scope), $request);

        if ($result['status'] !== 200 || !($result['body']['success'] ?? false)) {
            return [];
        }

        return $result['body']['faqs'] ?? [];
    }

    private function decodeJwtProfile(string $idToken): array
    {
        $parts = explode('.', $idToken);
        if (count($parts) < 2) {
            return [];
        }

        $payload = $parts[1];
        $payload .= str_repeat('=', (4 - strlen($payload) % 4) % 4);
        $decoded = json_decode(base64_decode(strtr($payload, '-_', '+/')) ?: '', true);

        if (!is_array($decoded)) {
            return [];
        }

        return [
            'email' => $decoded['email'] ?? null,
            'name' => $decoded['name'] ?? null,
        ];
    }
}
