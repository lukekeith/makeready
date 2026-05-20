<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Member login flow feature tests.
 *
 * Covers: MEMB-02
 */
class MemberLoginTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        Http::fake([
            '*/api/members/verify-phone' => Http::response([
                'success' => true,
            ], 200),

            '*/api/members/confirm-verification' => Http::response([
                'success'       => true,
                'authenticated' => true,
                'member'        => ['id' => 'member-1', 'firstName' => 'Test', 'lastName' => 'User'],
            ], 200),

            '*/api/members/logout' => Http::response([
                'success' => true,
            ], 200),
        ]);
    }

    /**
     * MEMB-02: /login renders phone entry page (200).
     */
    public function test_login_page_renders(): void
    {
        $response = $this->get('/login');

        $response->assertStatus(200);
    }

    /**
     * MEMB-02: POST /login/phone returns JSON redirectUrl to verify step.
     */
    public function test_phone_submit_returns_redirect_to_verify(): void
    {
        $response = $this->postJson('/login/phone', [
            'phoneNumber' => '+15551234567',
        ]);

        $response->assertStatus(200);
        $response->assertJson(['redirectUrl' => route('login.verify')]);
    }

    /**
     * MEMB-02: /login/verify renders verify code page when phone is in session.
     */
    public function test_verify_page_renders(): void
    {
        $this->withSession(['login' => ['phone' => '+15551234567']]);

        $response = $this->get('/login/verify');

        $response->assertStatus(200);
    }

    /**
     * MEMB-02: GET /login/verify redirects to /login when no phone in session.
     */
    public function test_verify_page_redirects_without_session(): void
    {
        $response = $this->get('/login/verify');

        $response->assertRedirect(route('login'));
    }

    /**
     * MEMB-02: POST /login/verify succeeds and returns JSON redirect to /home.
     */
    public function test_verify_submit_redirects_to_home(): void
    {
        $response = $this->withSession(['login' => ['phone' => '+15551234567']])
            ->postJson('/login/verify', ['code' => '123456']);

        $response->assertStatus(200);
        $response->assertJson(['redirectUrl' => route('home')]);
    }

    /**
     * MEMB-02: POST /logout clears session and redirects to /.
     */
    public function test_logout_clears_session_and_redirects(): void
    {
        $response = $this->withSession(['login' => ['phone' => '+15551234567']])
            ->post('/logout');

        $response->assertRedirect('/');
        // Session should be cleared.
        $response->assertSessionMissing('login');
    }

    /**
     * Smoke test: login route name resolves.
     */
    public function test_login_route_is_registered(): void
    {
        $this->assertTrue(
            (bool) route('login'),
            'login route name must be registered'
        );
    }

    /**
     * Smoke test: login verify route name resolves.
     */
    public function test_login_verify_route_is_registered(): void
    {
        $this->assertTrue(
            (bool) route('login.verify'),
            'login.verify route name must be registered'
        );
    }

    /**
     * Smoke test: logout route name resolves.
     */
    public function test_logout_route_is_registered(): void
    {
        $this->assertTrue(
            (bool) route('logout'),
            'logout route name must be registered'
        );
    }
}
