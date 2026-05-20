<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Route;
use Tests\TestCase;

class JoinBetaTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        config()->set('services.makeready.url', 'https://api.makeready.org');
        config()->set('services.google.client_id', 'google-client-id');
        config()->set('services.google.client_secret', 'google-secret');
    }

    public function test_join_beta_page_uses_google_and_api_backed_faqs(): void
    {
        Http::fake([
            'api.makeready.org/public/faqs/join-beta' => Http::response([
                'success' => true,
                'scope' => 'join-beta',
                'faqs' => [
                    [
                        'id' => 'faq-1',
                        'scope' => 'join-beta',
                        'question' => 'Why do I need to sign in with Google?',
                        'answer' => 'Google sign-in verifies the applicant identity.',
                        'sortOrder' => 10,
                    ],
                ],
                'count' => 1,
            ], 200),
        ]);

        $response = $this->get('/join-beta');

        $response->assertStatus(200);
        $response->assertSee('Continue with Google');
        $response->assertSee('Sign in with Google');
        $response->assertSee('Why do I need to sign in with Google?');
    }

    public function test_join_beta_application_requires_google_session(): void
    {
        $response = $this->get('/join-beta/application');

        $response->assertRedirect('/join-beta');
        $response->assertSessionHas('error', 'Sign in with Google before starting the beta application.');
    }

    public function test_google_auth_redirect_uses_google_authorize_endpoint(): void
    {
        $response = $this->get('/join-beta/auth/google');

        $response->assertRedirect();
        $location = $response->headers->get('Location') ?? '';

        $this->assertStringStartsWith('https://accounts.google.com/o/oauth2/v2/auth?', $location);
        $this->assertStringContainsString('client_id=google-client-id', $location);
        $this->assertStringContainsString('redirect_uri=' . rawurlencode(route('join-beta.auth.google.callback')), $location);
        $this->assertStringContainsString('scope=openid+profile+email', $location);
        $this->assertStringContainsString('state=', $location);
        $this->assertNotEmpty(session('join_beta_google_state'));
    }

    public function test_submit_application_posts_google_token_to_api_and_redirects_to_submitted(): void
    {
        Http::fake([
            'api.makeready.org/api/beta/applications' => Http::response([
                'success' => true,
                'application' => [
                    'id' => 'application-1',
                    'status' => 'PENDING',
                    'applicantEmail' => 'leader@example.org',
                    'organizationName' => 'Example Church',
                ],
            ], 201),
        ]);

        $response = $this->withSession([
            'join_beta_id_token' => 'google-id-token',
            'join_beta_google_user' => ['email' => 'leader@example.org', 'name' => 'Beta Leader'],
        ])->post('/join-beta/application', [
            'organizationName' => 'Example Church',
            'organizationWebsite' => 'https://example.org',
            'phoneNumber' => '+15555550123',
            'groupMemberAgeRange' => 'Adults',
            'numberOfGroups' => 2,
            'estimatedGroupMembers' => 35,
            'groupDescription' => 'We lead adult small groups through weekly study and daily accountability support.',
        ]);

        $response->assertRedirect('/join-beta/submitted');
        $response->assertSessionHas('join_beta_submission.id', 'application-1');
        $response->assertSessionMissing('join_beta_id_token');
        $response->assertSessionMissing('join_beta_google_user');

        Http::assertSent(function ($request) {
            return $request->url() === 'https://api.makeready.org/api/beta/applications'
                && $request['idToken'] === 'google-id-token'
                && $request['organizationName'] === 'Example Church';
        });
    }

    public function test_beta_google_routes_are_registered(): void
    {
        $this->assertTrue(Route::has('join-beta.auth.google'));
        $this->assertTrue(Route::has('join-beta.auth.google.callback'));
        $this->assertFalse(Route::has('join-beta.auth.microsoft'));
        $this->assertFalse(Route::has('join-beta.auth.microsoft.callback'));
    }
}
