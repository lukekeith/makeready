<?php

namespace Tests\Feature;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Admin Groups proxy feature tests.
 *
 * Covers: GRP-01, GRP-02, GRP-03, GRP-04, GRP-05, GRP-06, GRP-07
 *
 * Tests verify that the AdminApiProxyController correctly forwards
 * GET/POST/PATCH/DELETE requests to the external API using the session's
 * admin_user_session value as Cookie: connect.sid=<value>.
 * Multipart file uploads (cover image) are detected and forwarded.
 *
 * Admin routes use admin.auth middleware which checks for admin_user_session
 * in the Laravel session (not member.auth).
 */
class GroupsAdminTest extends TestCase
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
     * GRP-01: GET /admin/api/groups returns JSON with groups array.
     */
    public function test_groups_list_proxy(): void
    {
        Http::fake([
            '*/api/groups' => Http::response([
                'success' => true,
                'groups'  => [
                    [
                        'id'              => 'grp-1',
                        'name'            => 'Alpha Group',
                        'isPrivate'       => false,
                        'allowInvites'    => true,
                        'memberDirectory' => true,
                        'coverImageUrl'   => null,
                        'memberCount'     => 5,
                    ],
                    [
                        'id'              => 'grp-2',
                        'name'            => 'Beta Group',
                        'isPrivate'       => true,
                        'allowInvites'    => false,
                        'memberDirectory' => false,
                        'coverImageUrl'   => 'https://example.com/cover.jpg',
                        'memberCount'     => 12,
                    ],
                ],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->getJson('/admin/api/groups');

        $response->assertStatus(200);
        $response->assertJsonStructure(['groups']);

        Http::assertSent(function ($request) {
            return str_ends_with($request->url(), '/api/groups');
        });
    }

    /**
     * GRP-02: POST /admin/api/groups creates a new group.
     */
    public function test_create_group_proxy(): void
    {
        Http::fake([
            '*/api/groups' => Http::response([
                'success' => true,
                'group'   => [
                    'id'              => 'grp-new',
                    'name'            => 'New Group',
                    'isPrivate'       => false,
                    'allowInvites'    => true,
                    'memberDirectory' => true,
                    'coverImageUrl'   => null,
                    'memberCount'     => 0,
                ],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->postJson('/admin/api/groups', ['name' => 'New Group']);

        $response->assertStatus(200);
        $response->assertJsonStructure(['group']);

        Http::assertSent(function ($request) {
            return str_ends_with($request->url(), '/api/groups')
                && $request->method() === 'POST';
        });
    }

    /**
     * GRP-03: PATCH /admin/api/groups/grp-1 updates group name and description.
     */
    public function test_update_group_proxy(): void
    {
        Http::fake([
            '*/api/groups/grp-1' => Http::response([
                'success' => true,
                'group'   => [
                    'id'          => 'grp-1',
                    'name'        => 'Updated',
                    'description' => 'New desc',
                ],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->patchJson('/admin/api/groups/grp-1', [
            'name'        => 'Updated',
            'description' => 'New desc',
        ]);

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/groups/grp-1')
                && $request->method() === 'PATCH';
        });
    }

    /**
     * GRP-04: PATCH /admin/api/groups/grp-1 updates group settings fields.
     */
    public function test_update_group_settings_proxy(): void
    {
        Http::fake([
            '*/api/groups/grp-1' => Http::response([
                'success' => true,
                'group'   => [
                    'id'              => 'grp-1',
                    'isPrivate'       => true,
                    'allowInvites'    => false,
                    'memberDirectory' => false,
                    'maxMembers'      => 50,
                ],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->patchJson('/admin/api/groups/grp-1', [
            'isPrivate'       => true,
            'allowInvites'    => false,
            'memberDirectory' => false,
            'maxMembers'      => 50,
        ]);

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/groups/grp-1')
                && $request->method() === 'PATCH';
        });
    }

    /**
     * GRP-05: POST /admin/api/groups/grp-1/cover-image uploads a cover image.
     *
     * Verifies multipart detection in handlePost() routes to file upload.
     */
    public function test_cover_image_upload_proxy(): void
    {
        Http::fake([
            '*/api/groups/grp-1/cover-image' => Http::response([
                'success'       => true,
                'coverImageUrl' => 'https://example.com/new-cover.jpg',
            ], 200),
        ]);

        $file = UploadedFile::fake()->image('cover.jpg', 800, 600)->size(2000);

        $response = $this->withSession($this->adminSession())->call(
            'POST',
            '/admin/api/groups/grp-1/cover-image',
            [],
            [],
            ['image' => $file]
        );

        $response->assertStatus(200);
        $this->assertStringContainsString('coverImageUrl', $response->getContent());

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/groups/grp-1/cover-image');
        });
    }

    /**
     * GRP-06: DELETE /admin/api/groups/grp-1 deletes a group.
     */
    public function test_delete_group_proxy(): void
    {
        Http::fake([
            '*/api/groups/grp-1' => Http::response([
                'success' => true,
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->deleteJson('/admin/api/groups/grp-1');

        $response->assertStatus(200);
        $response->assertJson(['success' => true]);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/groups/grp-1')
                && $request->method() === 'DELETE';
        });
    }

    /**
     * GRP-07: GET /admin/groups/grp-1 returns 200 with the LeaderApp mount point.
     *
     * The /admin catch-all serves the new LeaderApp shell for all /admin/* paths
     * that are not API proxy requests, including detail route sub-paths.
     */
    public function test_group_detail_renders(): void
    {
        $response = $this->withSession($this->adminSession())->get('/admin/groups/grp-1');

        $response->assertStatus(200);
        $response->assertSee('data-vue="LeaderApp"', false);
    }
}
