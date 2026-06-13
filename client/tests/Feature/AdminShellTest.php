<?php

namespace Tests\Feature;

use Tests\TestCase;

/**
 * Admin shell server-side precondition tests.
 *
 * Covers: SHELL-01, SHELL-05, SHELL-06
 *
 * Verifies the Laravel catch-all route, AdminIsland mount point, CSRF meta tag,
 * island props passthrough, and auth redirect for all /admin/* sub-paths.
 *
 * Admin routes use admin.auth middleware which checks for admin_user_session
 * in the Laravel session (not member.auth).
 */
class AdminShellTest extends TestCase
{
    private function adminSession(): array
    {
        return [
            'admin_user_session' => 'test-session-id',
            'admin_user'         => [
                'id'      => 'user-1',
                'name'    => 'Alex Leader',
                'email'   => 'alex.leader@example.com',
                'picture' => null,
            ],
        ];
    }

    /**
     * SHELL-01: GET /admin mounts the AdminIsland Vue component.
     */
    public function test_admin_page_mounts_admin_island(): void
    {
        $response = $this->withSession($this->adminSession())->get('/admin');

        $response->assertStatus(200);
        $response->assertSee('data-vue="AdminIsland"', false);
    }

    /**
     * SHELL-05: GET /admin/groups is served by the same Blade shell (catch-all works).
     */
    public function test_admin_subpaths_served_by_same_blade_template(): void
    {
        $response = $this->withSession($this->adminSession())->get('/admin/groups');

        $response->assertStatus(200);
        $response->assertSee('data-vue="AdminIsland"', false);
    }

    /**
     * SHELL-05: GET /admin/groups without a session redirects to /admin/login.
     */
    public function test_admin_subpath_redirects_unauthenticated(): void
    {
        $response = $this->get('/admin/groups');

        $response->assertStatus(302);
        $response->assertRedirect('/admin/login');
    }

    /**
     * SHELL-06: Island props contain member data so AdminIsland can bootstrap without an extra API call.
     */
    public function test_admin_island_props_contain_member_data(): void
    {
        $response = $this->withSession($this->adminSession())->get('/admin');

        $response->assertStatus(200);
        $response->assertSee('Alex Leader', false);
    }

    /**
     * SHELL-01: Admin layout includes the CSRF meta tag required for axios requests.
     */
    public function test_admin_layout_contains_csrf_meta(): void
    {
        $response = $this->withSession($this->adminSession())->get('/admin');

        $response->assertStatus(200);
        $response->assertSee('meta name="csrf-token"', false);
    }
}
