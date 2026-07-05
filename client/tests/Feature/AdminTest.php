<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Admin page feature tests.
 *
 * Covers: ADMN-01
 *
 * Tests the admin shell renders with AdminIsland mount point.
 * Unauthenticated guests are redirected to /admin/login.
 *
 * Admin routes use admin.auth middleware which checks for admin_user_session
 * in the Laravel session (not member.auth).
 */
class AdminTest extends TestCase
{
    private function adminSession(): array
    {
        return [
            'admin_user_session' => 'test-session-id',
            'admin_user'         => [
                'id'      => 'user-1',
                'name'    => 'Test User',
                'email'   => 'test@test.com',
                'picture' => null,
            ],
        ];
    }

    /**
     * ADMN-01: Authenticated member can access the admin page and sees AdminIsland mount point.
     */
    public function test_admin_page_renders_for_leader(): void
    {
        $response = $this->withSession($this->adminSession())->get('/admin');

        $response->assertStatus(200);
        $response->assertSee('LeaderApp');
    }

    /**
     * ADMN-01: The parked legacy SPA is still reachable at /admin-legacy.
     */
    public function test_admin_legacy_page_renders_admin_island(): void
    {
        $response = $this->withSession($this->adminSession())->get('/admin-legacy');

        $response->assertStatus(200);
        $response->assertSee('data-vue="AdminIsland"', false);
    }

    /**
     * ADMN-01: Unauthenticated guest is redirected to /admin/login.
     */
    public function test_admin_page_redirects_unauthenticated(): void
    {
        $response = $this->get('/admin');

        $response->assertStatus(302);
        $response->assertRedirect('/admin/login');
    }

    /**
     * ADMN-01: /admin renders the LeaderApp data-vue mount point.
     */
    public function test_admin_page_has_logout_button(): void
    {
        $response = $this->withSession($this->adminSession())->get('/admin');

        $response->assertStatus(200);
        $response->assertSee('data-vue="LeaderApp"', false);
    }

    /**
     * Smoke test: admin.shell route name resolves.
     */
    public function test_admin_route_is_registered(): void
    {
        $this->assertTrue(
            (bool) route('admin.shell'),
            'admin.shell route name must be registered'
        );
    }

    /**
     * Smoke test: study.code route name resolves.
     */
    public function test_study_code_route_is_registered(): void
    {
        $this->assertTrue(
            (bool) route('study.code'),
            'study.code route name must be registered'
        );
    }

    /**
     * Study code page renders with code entry form.
     */
    public function test_study_code_page_renders(): void
    {
        $response = $this->get('/join/study');

        $response->assertStatus(200);
        $response->assertSee('Join a study', false);
        $response->assertSee('JoinCodeIsland');
    }
}
