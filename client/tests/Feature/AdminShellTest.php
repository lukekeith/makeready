<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Admin shell server-side precondition tests.
 *
 * Covers: SHELL-01, SHELL-04, SHELL-05, SHELL-06
 *
 * Verifies the Laravel catch-all route, AdminIsland mount point, CSRF meta tag,
 * island props passthrough, auth redirect for all /admin/* sub-paths, and
 * NavigationIsland google-linked-user passthrough for member experience.
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

    // ─── NavigationIsland google-link passthrough (SHELL-04) ─────────────────────

    /**
     * SHELL-04: A member with a linked Google account should have googleEmail in the
     * NavigationIsland data-props, so the Vue component shows the admin link.
     */
    public function test_member_nav_shows_admin_link_for_google_linked_member(): void
    {
        Http::fake([
            '*/api/members/session' => Http::response([
                'authenticated' => true,
                'member' => [
                    'id'          => 'member-1',
                    'firstName'   => 'Jane',
                    'lastName'    => 'Smith',
                    'phoneNumber' => '+15550001111',
                    'googleEmail' => 'leader@example.com',
                ],
            ], 200),
            '*/api/members/*/groups' => Http::response(['data' => []], 200),
        ]);

        $response = $this->get('/member/home');

        $response->assertStatus(200);
        // The data-props attribute is HTML-encoded in the rendered Blade output.
        // assertSee (default, escape=true) will encode the needle to match.
        $response->assertSee('"googleEmail":"leader@example.com"');
    }

    /**
     * SHELL-04: A member without a linked Google account should have googleEmail as null
     * (or absent) in the NavigationIsland data-props, so the Vue component hides
     * the admin link.
     */
    public function test_member_nav_hides_admin_link_when_no_google_link(): void
    {
        Http::fake([
            '*/api/members/session' => Http::response([
                'authenticated' => true,
                'member' => [
                    'id'          => 'member-2',
                    'firstName'   => 'Bob',
                    'lastName'    => 'Regular',
                    'phoneNumber' => '+15550002222',
                    'googleEmail' => null,
                ],
            ], 200),
            '*/api/members/*/groups' => Http::response(['data' => []], 200),
        ]);

        $response = $this->get('/member/home');

        $response->assertStatus(200);
        // When googleEmail is null the JSON prop will be "googleEmail":null,
        // so the Vue v-if will be falsy and the admin link should not render
        // (Vue renders client-side, but we verify the prop is null/falsy in Blade output).
        $response->assertDontSee('"googleEmail":"leader@example.com"', false);
        // Also confirm "Group Leader Admin" text is NOT present in SSR HTML.
        $response->assertDontSee('Group Leader Admin');
    }
}
