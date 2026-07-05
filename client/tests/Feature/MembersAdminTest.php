<?php

namespace Tests\Feature;

use Tests\TestCase;

/**
 * Members admin page feature tests.
 *
 * Covers: MLIST-07
 *
 * Admin routes use admin.auth middleware which checks for admin_user_session
 * in the Laravel session (not member.auth).
 */
class MembersAdminTest extends TestCase
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

    public function test_admin_members_route_returns_200(): void
    {
        // /admin/members is now served by the new LeaderApp catch-all (the legacy
        // Members section lives at /admin-legacy/members).
        $response = $this->withSession($this->adminSession())->get('/admin/members');

        $response->assertStatus(200);
        $response->assertSee('data-vue="LeaderApp"', false); // Vue island mount point
    }
}
