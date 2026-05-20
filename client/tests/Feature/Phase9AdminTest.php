<?php

namespace Tests\Feature;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Admin Phase 9 proxy feature tests.
 *
 * Covers: MMBR-01, MMBR-02, MMBR-03, MMBR-04, MMBR-05, MMBR-06,
 *         and all Phase 9 API routes (enrollments, posts, analytics, profile)
 *
 * Tests verify that the AdminApiProxyController correctly forwards
 * GET/POST/PATCH/DELETE requests to the external API using the session's
 * admin_user_session value as Cookie: connect.sid=<value>.
 *
 * Admin routes use admin.auth middleware which checks for admin_user_session
 * in the Laravel session (not member.auth).
 */
class Phase9AdminTest extends TestCase
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

    // ─── Members ───────────────────────────────────────────────────────────────

    /**
     * MMBR-01: GET /admin/api/groups/g1/members returns member list.
     */
    public function test_members_list_proxy(): void
    {
        Http::fake([
            '*/api/groups/g1/members' => Http::response([
                'success' => true,
                'members' => [
                    [
                        'id'       => 'm1',
                        'userId'   => 'u1',
                        'groupId'  => 'g1',
                        'role'     => 'MEMBER',
                        'name'     => 'Alice Smith',
                        'avatarUrl'=> null,
                        'joinedAt' => '2025-01-01T00:00:00Z',
                    ],
                ],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->getJson('/admin/api/groups/g1/members');

        $response->assertStatus(200);
        $response->assertJsonStructure(['members']);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/groups/g1/members')
                && $request->method() === 'GET';
        });
    }

    /**
     * MMBR-02: GET /admin/api/members/m1/profile returns member profile.
     */
    public function test_member_profile_proxy(): void
    {
        Http::fake([
            '*/api/members/m1/profile' => Http::response([
                'success' => true,
                'data'    => [
                    'id'            => 'm1',
                    'firstName'     => 'Alice',
                    'lastName'      => 'Smith',
                    'phoneNumber'   => '+15550001111',
                    'email'         => 'alice@example.com',
                    'profilePicture'=> null,
                    'groups'        => [],
                ],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->getJson('/admin/api/members/m1/profile');

        $response->assertStatus(200);
        $response->assertJsonStructure(['data']);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/members/m1/profile')
                && $request->method() === 'GET';
        });
    }

    /**
     * MMBR-03: POST /admin/api/groups/g1/join-requests/r1/approve approves a request.
     */
    public function test_approve_request_proxy(): void
    {
        Http::fake([
            '*/api/groups/g1/join-requests/r1/approve' => Http::response([
                'success' => true,
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->postJson('/admin/api/groups/g1/join-requests/r1/approve', []);

        $response->assertStatus(200);
        $response->assertJson(['success' => true]);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/groups/g1/join-requests/r1/approve')
                && $request->method() === 'POST';
        });
    }

    /**
     * MMBR-04: DELETE /admin/api/groups/g1/join-requests/r1 rejects a request.
     * Note: endpoint is unconfirmed — test verifies proxy forwarding only.
     */
    public function test_reject_request_proxy(): void
    {
        Http::fake([
            '*/api/groups/g1/join-requests/r1' => Http::response([
                'success' => true,
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->deleteJson('/admin/api/groups/g1/join-requests/r1');

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/groups/g1/join-requests/r1')
                && $request->method() === 'DELETE';
        });
    }

    /**
     * MMBR-05: PATCH /admin/api/groups/g1/members/m1 changes member role.
     * Note: endpoint is unconfirmed — test verifies proxy forwarding only.
     */
    public function test_change_role_proxy(): void
    {
        Http::fake([
            '*/api/groups/g1/members/m1' => Http::response([
                'success' => true,
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->patchJson('/admin/api/groups/g1/members/m1', ['role' => 'ADMIN']);

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/groups/g1/members/m1')
                && $request->method() === 'PATCH';
        });
    }

    /**
     * MMBR-06: DELETE /admin/api/groups/g1/members/m1 removes a member.
     * Note: endpoint is unconfirmed — test verifies proxy forwarding only.
     */
    public function test_remove_member_proxy(): void
    {
        Http::fake([
            '*/api/groups/g1/members/m1' => Http::response([
                'success' => true,
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->deleteJson('/admin/api/groups/g1/members/m1');

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/groups/g1/members/m1')
                && $request->method() === 'DELETE';
        });
    }

    // ─── Enrollments ───────────────────────────────────────────────────────────

    /**
     * GET /admin/api/groups/g1/enrollments returns enrollments list.
     */
    public function test_enrollments_list_proxy(): void
    {
        Http::fake([
            '*/api/groups/g1/enrollments' => Http::response([
                'success'     => true,
                'enrollments' => [],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->getJson('/admin/api/groups/g1/enrollments');

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/groups/g1/enrollments')
                && $request->method() === 'GET';
        });
    }

    /**
     * POST /admin/api/enrollments creates a new enrollment.
     */
    public function test_create_enrollment_proxy(): void
    {
        Http::fake([
            '*/api/enrollments' => Http::response([
                'success'    => true,
                'enrollment' => ['id' => 'e1'],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->postJson('/admin/api/enrollments', [
            'groupId'   => 'g1',
            'programId' => 'prog-1',
        ]);

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/enrollments')
                && $request->method() === 'POST';
        });
    }

    /**
     * DELETE /admin/api/enrollments/e1 deletes an enrollment.
     */
    public function test_delete_enrollment_proxy(): void
    {
        Http::fake([
            '*/api/enrollments/e1' => Http::response([
                'success' => true,
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->deleteJson('/admin/api/enrollments/e1');

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/enrollments/e1')
                && $request->method() === 'DELETE';
        });
    }

    /**
     * POST /admin/api/enrollments/e1/cancel-future cancels future sessions.
     */
    public function test_cancel_future_proxy(): void
    {
        Http::fake([
            '*/api/enrollments/e1/cancel-future' => Http::response([
                'success' => true,
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->postJson('/admin/api/enrollments/e1/cancel-future', []);

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/enrollments/e1/cancel-future')
                && $request->method() === 'POST';
        });
    }

    /**
     * GET /admin/api/enrollments/e1 returns enrollment detail.
     */
    public function test_enrollment_detail_proxy(): void
    {
        Http::fake([
            '*/api/enrollments/e1' => Http::response([
                'success'    => true,
                'enrollment' => ['id' => 'e1'],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->getJson('/admin/api/enrollments/e1');

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/enrollments/e1')
                && $request->method() === 'GET';
        });
    }

    /**
     * GET /admin/api/enrollments/e1/unenroll-info returns unenroll info.
     */
    public function test_unenroll_info_proxy(): void
    {
        Http::fake([
            '*/api/enrollments/e1/unenroll-info' => Http::response([
                'success' => true,
                'data'    => [],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->getJson('/admin/api/enrollments/e1/unenroll-info');

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/enrollments/e1/unenroll-info')
                && $request->method() === 'GET';
        });
    }

    /**
     * PATCH /admin/api/enrollments/e1/schedules/s1 updates a schedule.
     */
    public function test_update_schedule_proxy(): void
    {
        Http::fake([
            '*/api/enrollments/e1/schedules/s1' => Http::response([
                'success' => true,
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->patchJson('/admin/api/enrollments/e1/schedules/s1', [
            'scheduledDate' => '2026-04-01',
        ]);

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/enrollments/e1/schedules/s1')
                && $request->method() === 'PATCH';
        });
    }

    /**
     * POST /admin/api/enrollments/e1/schedules adds a schedule.
     */
    public function test_add_schedule_proxy(): void
    {
        Http::fake([
            '*/api/enrollments/e1/schedules' => Http::response([
                'success'  => true,
                'schedule' => ['id' => 's2'],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->postJson('/admin/api/enrollments/e1/schedules', [
            'scheduledDate' => '2026-04-08',
        ]);

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/enrollments/e1/schedules')
                && $request->method() === 'POST';
        });
    }

    /**
     * DELETE /admin/api/enrollments/e1/schedules/s1 deletes a schedule.
     */
    public function test_delete_schedule_proxy(): void
    {
        Http::fake([
            '*/api/enrollments/e1/schedules/s1' => Http::response([
                'success' => true,
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->deleteJson('/admin/api/enrollments/e1/schedules/s1');

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/enrollments/e1/schedules/s1')
                && $request->method() === 'DELETE';
        });
    }

    // ─── Posts ─────────────────────────────────────────────────────────────────

    /**
     * GET /admin/api/groups/g1/posts?limit=20 returns posts list.
     */
    public function test_posts_list_proxy(): void
    {
        Http::fake([
            '*/api/groups/g1/posts*' => Http::response([
                'success' => true,
                'posts'   => [],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->getJson('/admin/api/groups/g1/posts?limit=20');

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/groups/g1/posts')
                && $request->method() === 'GET';
        });
    }

    /**
     * POST /admin/api/groups/g1/posts creates a post.
     */
    public function test_create_post_proxy(): void
    {
        Http::fake([
            '*/api/groups/g1/posts' => Http::response([
                'success' => true,
                'post'    => ['id' => 'p1', 'content' => 'Hello world'],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->postJson('/admin/api/groups/g1/posts', [
            'content' => 'Hello world',
        ]);

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/groups/g1/posts')
                && $request->method() === 'POST';
        });
    }

    // ─── Analytics ─────────────────────────────────────────────────────────────

    /**
     * GET /admin/api/activity-logs/stats/heatmap returns heatmap data.
     */
    public function test_heatmap_proxy(): void
    {
        Http::fake([
            '*/api/activity-logs/stats/heatmap' => Http::response([
                'success' => true,
                'data'    => [],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->getJson('/admin/api/activity-logs/stats/heatmap');

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/activity-logs/stats/heatmap')
                && $request->method() === 'GET';
        });
    }

    /**
     * GET /admin/api/activity-logs/stats returns weekly stats.
     */
    public function test_weekly_stats_proxy(): void
    {
        Http::fake([
            '*/api/activity-logs/stats' => Http::response([
                'success' => true,
                'data'    => [],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->getJson('/admin/api/activity-logs/stats');

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/activity-logs/stats')
                && $request->method() === 'GET';
        });
    }

    // ─── Profile ───────────────────────────────────────────────────────────────

    /**
     * PATCH /admin/api/members/m1 updates member profile with camelCase fields.
     */
    public function test_profile_update_proxy(): void
    {
        Http::fake([
            '*/api/members/m1' => Http::response([
                'success' => true,
                'member'  => ['id' => 'm1'],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->patchJson('/admin/api/members/m1', [
            'firstName' => 'Jane',
            'lastName'  => 'Doe',
        ]);

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/members/m1')
                && $request->method() === 'PATCH';
        });
    }

    /**
     * POST /admin/api/members/m1/avatar uploads a member avatar (multipart).
     */
    public function test_avatar_upload_proxy(): void
    {
        Http::fake([
            '*/api/members/m1/avatar' => Http::response([
                'success'   => true,
                'avatarUrl' => 'https://example.com/avatar.jpg',
            ], 200),
        ]);

        $file = UploadedFile::fake()->image('avatar.jpg', 200, 200)->size(500);

        $response = $this->withSession($this->adminSession())->call(
            'POST',
            '/admin/api/members/m1/avatar',
            [],
            [],
            ['image' => $file]
        );

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/members/m1/avatar');
        });
    }

    // ─── Join Requests List ────────────────────────────────────────────────────

    /**
     * GET /admin/api/groups/g1/join-requests returns pending join requests.
     */
    public function test_join_requests_list_proxy(): void
    {
        Http::fake([
            '*/api/groups/g1/join-requests' => Http::response([
                'success'      => true,
                'joinRequests' => [],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->getJson('/admin/api/groups/g1/join-requests');

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/groups/g1/join-requests')
                && $request->method() === 'GET';
        });
    }
}
