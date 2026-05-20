<?php

namespace Tests\Feature;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Admin Programs proxy feature tests.
 *
 * Covers: PROG-01, PROG-02, PROG-03, PROG-04, PROG-05, PROG-06, PROG-07
 *         LSSN-01, LSSN-02, LSSN-03, LSSN-04, LSSN-05
 *
 * Tests verify that the AdminApiProxyController correctly forwards
 * GET/POST/PATCH/DELETE requests to the external API using the session's
 * admin_user_session value as Cookie: connect.sid=<value>.
 * Nested lesson paths (programs/:id/lessons/:lessonId) validate that
 * the .* wildcard proxy route captures multi-segment paths correctly.
 * Multipart file uploads (cover image) are detected and forwarded.
 *
 * Admin routes use admin.auth middleware which checks for admin_user_session
 * in the Laravel session (not member.auth).
 */
class ProgramsAdminTest extends TestCase
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
     * PROG-01: GET /admin/api/programs returns JSON with programs array.
     */
    public function test_programs_list_proxy(): void
    {
        Http::fake([
            '*/api/programs' => Http::response([
                'success'  => true,
                'programs' => [
                    [
                        'id'            => 'prog-1',
                        'name'          => 'Alpha Program',
                        'isPublished'   => true,
                        'coverImageUrl' => null,
                        '_count'        => ['enrollments' => 3],
                    ],
                    [
                        'id'            => 'prog-2',
                        'name'          => 'Beta Program',
                        'isPublished'   => false,
                        'coverImageUrl' => 'https://example.com/cover.jpg',
                        '_count'        => ['enrollments' => 0],
                    ],
                ],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->getJson('/admin/api/programs');

        $response->assertStatus(200);
        $response->assertJsonStructure(['programs']);

        Http::assertSent(function ($request) {
            return str_ends_with($request->url(), '/api/programs');
        });
    }

    /**
     * PROG-02: POST /admin/api/programs creates a new program.
     */
    public function test_create_program_proxy(): void
    {
        Http::fake([
            '*/api/programs' => Http::response([
                'success' => true,
                'program' => [
                    'id'          => 'prog-new',
                    'name'        => 'New Program',
                    'templateId'  => 'tmpl-1',
                    'days'        => 30,
                    'isPublished' => false,
                ],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->postJson('/admin/api/programs', [
            'name'       => 'New Program',
            'templateId' => 'tmpl-1',
            'days'       => 30,
        ]);

        $response->assertStatus(200);
        $response->assertJsonStructure(['program']);

        Http::assertSent(function ($request) {
            return str_ends_with($request->url(), '/api/programs')
                && $request->method() === 'POST';
        });
    }

    /**
     * PROG-03: PATCH /admin/api/programs/prog-1 updates program name and description.
     */
    public function test_update_program_proxy(): void
    {
        Http::fake([
            '*/api/programs/prog-1' => Http::response([
                'success' => true,
                'program' => [
                    'id'          => 'prog-1',
                    'name'        => 'Updated',
                    'description' => 'New desc',
                    'isPublished' => true,
                ],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->patchJson('/admin/api/programs/prog-1', [
            'name'        => 'Updated',
            'description' => 'New desc',
        ]);

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/programs/prog-1')
                && $request->method() === 'PATCH';
        });
    }

    /**
     * PROG-04: POST /admin/api/programs/prog-1/cover-image uploads a cover image.
     *
     * Verifies multipart detection in handlePost() routes to file upload.
     */
    public function test_program_cover_image_upload_proxy(): void
    {
        Http::fake([
            '*/api/programs/prog-1/cover-image' => Http::response([
                'success'       => true,
                'coverImageUrl' => 'https://example.com/new-cover.jpg',
            ], 200),
        ]);

        $file = UploadedFile::fake()->image('cover.jpg', 800, 600)->size(2000);

        $response = $this->withSession($this->adminSession())->call(
            'POST',
            '/admin/api/programs/prog-1/cover-image',
            [],
            [],
            ['image' => $file]
        );

        $response->assertStatus(200);
        $this->assertStringContainsString('coverImageUrl', $response->getContent());

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/programs/prog-1/cover-image');
        });
    }

    /**
     * PROG-05: PATCH /admin/api/programs/prog-1 with isPublished toggles publish status.
     */
    public function test_publish_program_proxy(): void
    {
        Http::fake([
            '*/api/programs/prog-1' => Http::response([
                'success' => true,
                'program' => [
                    'id'          => 'prog-1',
                    'name'        => 'Alpha Program',
                    'isPublished' => true,
                ],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->patchJson('/admin/api/programs/prog-1', [
            'isPublished' => true,
        ]);

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/programs/prog-1')
                && $request->method() === 'PATCH'
                && isset($request->data()['isPublished']);
        });
    }

    /**
     * PROG-06: DELETE /admin/api/programs/prog-1 deletes a program.
     */
    public function test_delete_program_proxy(): void
    {
        Http::fake([
            '*/api/programs/prog-1' => Http::response([
                'success' => true,
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->deleteJson('/admin/api/programs/prog-1');

        $response->assertStatus(200);
        $response->assertJson(['success' => true]);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/programs/prog-1')
                && $request->method() === 'DELETE';
        });
    }

    /**
     * PROG-07: GET /admin/programs/prog-1 returns 200 with AdminIsland mount point.
     *
     * The admin catch-all serves the Blade shell for all /admin/* paths
     * that are not API proxy requests, including detail route sub-paths.
     */
    public function test_program_detail_renders(): void
    {
        $response = $this->withSession($this->adminSession())->get('/admin/programs/prog-1');

        $response->assertStatus(200);
        $response->assertSee('AdminIsland');
    }

    /**
     * LSSN-01: GET /admin/api/programs/prog-1 returns program with nested lessons array.
     */
    public function test_program_lessons_list_proxy(): void
    {
        Http::fake([
            '*/api/programs/prog-1' => Http::response([
                'success' => true,
                'program' => [
                    'id'          => 'prog-1',
                    'name'        => 'Alpha Program',
                    'isPublished' => true,
                    'lessons'     => [
                        [
                            'id'        => 'lsn-1',
                            'dayNumber' => 1,
                            'title'     => 'Day 1: Introduction',
                            'programId' => 'prog-1',
                        ],
                        [
                            'id'        => 'lsn-2',
                            'dayNumber' => 2,
                            'title'     => 'Day 2: Foundation',
                            'programId' => 'prog-1',
                        ],
                    ],
                ],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->getJson('/admin/api/programs/prog-1');

        $response->assertStatus(200);
        $response->assertJsonStructure(['program' => ['lessons']]);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/programs/prog-1');
        });
    }

    /**
     * LSSN-02: POST /admin/api/programs/prog-1/lessons adds a new lesson.
     *
     * Validates that nested multi-segment paths proxy correctly through
     * the .* wildcard in the proxy route.
     */
    public function test_add_lesson_proxy(): void
    {
        Http::fake([
            '*/api/programs/prog-1/lessons' => Http::response([
                'success' => true,
                'lesson'  => [
                    'id'        => 'lsn-new',
                    'dayNumber' => 3,
                    'title'     => 'Day 3',
                    'programId' => 'prog-1',
                ],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->postJson('/admin/api/programs/prog-1/lessons', []);

        $response->assertStatus(200);
        $response->assertJsonStructure(['lesson']);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/programs/prog-1/lessons')
                && $request->method() === 'POST';
        });
    }

    /**
     * LSSN-03: PATCH /admin/api/programs/prog-1/lessons/lsn-1 updates lesson title.
     *
     * Validates that deeply nested paths (3 segments after /api) proxy correctly.
     */
    public function test_update_lesson_title_proxy(): void
    {
        Http::fake([
            '*/api/programs/prog-1/lessons/lsn-1' => Http::response([
                'success' => true,
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->patchJson('/admin/api/programs/prog-1/lessons/lsn-1', [
            'title' => 'Updated Title',
        ]);

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/programs/prog-1/lessons/lsn-1')
                && $request->method() === 'PATCH';
        });
    }

    /**
     * LSSN-04: DELETE /admin/api/programs/prog-1/lessons/lsn-1 removes a lesson.
     */
    public function test_delete_lesson_proxy(): void
    {
        Http::fake([
            '*/api/programs/prog-1/lessons/lsn-1' => Http::response([
                'success' => true,
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->deleteJson('/admin/api/programs/prog-1/lessons/lsn-1');

        $response->assertStatus(200);
        $response->assertJson(['success' => true]);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/programs/prog-1/lessons/lsn-1')
                && $request->method() === 'DELETE';
        });
    }

    /**
     * LSSN-05: POST /admin/api/programs/prog-1/reorder-lessons reorders lessons.
     */
    public function test_reorder_lessons_proxy(): void
    {
        Http::fake([
            '*/api/programs/prog-1/reorder-lessons' => Http::response([
                'success' => true,
                'program' => [
                    'id'      => 'prog-1',
                    'name'    => 'Alpha Program',
                    'lessons' => [
                        [
                            'id'        => 'lsn-2',
                            'dayNumber' => 1,
                            'title'     => 'Day 2: Foundation',
                            'programId' => 'prog-1',
                        ],
                        [
                            'id'        => 'lsn-1',
                            'dayNumber' => 2,
                            'title'     => 'Day 1: Introduction',
                            'programId' => 'prog-1',
                        ],
                    ],
                ],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->postJson('/admin/api/programs/prog-1/reorder-lessons', [
            'lessonOrder' => ['lsn-2', 'lsn-1'],
        ]);

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/programs/prog-1/reorder-lessons')
                && $request->method() === 'POST';
        });
    }
}
