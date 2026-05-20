<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Admin Activities proxy feature tests.
 *
 * Covers: ACTV-01, ACTV-02, ACTV-03, ACTV-04, ACTV-05, ACTV-06, ACTV-07, ACTV-08, ACTV-09
 *
 * Tests verify that the AdminApiProxyController correctly forwards
 * GET/POST/PATCH/DELETE requests to the external API using the session's
 * admin_user_session value as Cookie: connect.sid=<value>.
 * Activity endpoints are nested under programs/:id/lessons/:lessonId/activities
 * and under activities/:id for individual activity operations.
 *
 * Admin routes use admin.auth middleware which checks for admin_user_session
 * in the Laravel session (not member.auth).
 */
class ActivitiesAdminTest extends TestCase
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
     * ACTV-01: GET /admin/api/programs/prog-1 returns program with lessons containing activities.
     */
    public function test_get_program_returns_activities(): void
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
                            'id'         => 'lsn-1',
                            'dayNumber'  => 1,
                            'title'      => 'Day 1: Introduction',
                            'programId'  => 'prog-1',
                            'activities' => [
                                [
                                    'id'           => 'act-1',
                                    'activityType' => 'READ',
                                    'title'        => 'Reading',
                                    'orderNumber'  => 1,
                                    'status'       => 'COMPLETE',
                                ],
                            ],
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
     * ACTV-02: POST /admin/api/programs/prog-1/lessons/lsn-1/activities adds a new activity.
     */
    public function test_add_activity(): void
    {
        Http::fake([
            '*/api/programs/prog-1/lessons/lsn-1/activities' => Http::response([
                'success'  => true,
                'activity' => [
                    'id'           => 'act-new',
                    'activityType' => 'READ',
                    'title'        => 'New Reading',
                    'orderNumber'  => 1,
                ],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->postJson('/admin/api/programs/prog-1/lessons/lsn-1/activities', [
            'activityType' => 'READ',
            'title'        => 'New Reading',
        ]);

        $response->assertStatus(200);
        $response->assertJsonStructure(['activity']);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/programs/prog-1/lessons/lsn-1/activities')
                && $request->method() === 'POST';
        });
    }

    /**
     * ACTV-03: PATCH /admin/api/activities/act-1 updates activity title and help fields.
     */
    public function test_update_activity(): void
    {
        Http::fake([
            '*/api/activities/act-1' => Http::response([
                'success'  => true,
                'activity' => [
                    'id'    => 'act-1',
                    'title' => 'Updated',
                ],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->patchJson('/admin/api/activities/act-1', [
            'title'         => 'Updated',
            'isHelpEnabled' => true,
            'helpTitle'     => 'Help',
            'status'        => 'COMPLETE',
        ]);

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/activities/act-1')
                && $request->method() === 'PATCH'
                && isset($request->data()['status']);
        });
    }

    /**
     * ACTV-04: PATCH /admin/api/activities/act-1 with readContent saves plain text.
     */
    public function test_update_read_content(): void
    {
        Http::fake([
            '*/api/activities/act-1' => Http::response([
                'success'  => true,
                'activity' => [
                    'id'          => 'act-1',
                    'readContent' => 'Some plain text content',
                ],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->patchJson('/admin/api/activities/act-1', [
            'readContent' => 'Some plain text content',
            'status'      => 'COMPLETE',
        ]);

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/activities/act-1')
                && $request->method() === 'PATCH'
                && isset($request->data()['readContent']);
        });
    }

    /**
     * ACTV-05: POST /admin/api/activities/act-1/source-references adds a scripture reference.
     */
    public function test_add_source_reference(): void
    {
        Http::fake([
            '*/api/activities/act-1/source-references' => Http::response([
                'success'         => true,
                'sourceReference' => ['id' => 'ref-1'],
                'activity'        => ['id' => 'act-1'],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->postJson('/admin/api/activities/act-1/source-references', [
            'sourceType'       => 'BIBLE_PASSAGE',
            'passageReference' => 'Romans 1:1-5',
            'bookNumber'       => 45,
            'bookName'         => 'Romans',
            'chapterStart'     => 1,
            'verseStart'       => 1,
            'verseEnd'         => 5,
        ]);

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/activities/act-1/source-references')
                && $request->method() === 'POST';
        });
    }

    /**
     * ACTV-06a: POST /admin/api/activities/act-1/read-blocks creates a read block.
     */
    public function test_create_read_block(): void
    {
        Http::fake([
            '*/api/activities/act-1/read-blocks' => Http::response([
                'success'  => true,
                'block'    => ['id' => 'blk-1'],
                'activity' => ['id' => 'act-1'],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->postJson('/admin/api/activities/act-1/read-blocks', [
            'title'       => 'Block 1',
            'content'     => 'Text',
            'orderNumber' => 1,
            'isLocked'    => false,
        ]);

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/activities/act-1/read-blocks')
                && $request->method() === 'POST';
        });
    }

    /**
     * ACTV-06b: PATCH /admin/api/activities/act-1/read-blocks/blk-1 updates a read block.
     */
    public function test_update_read_block(): void
    {
        Http::fake([
            '*/api/activities/act-1/read-blocks/blk-1' => Http::response([
                'success' => true,
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->patchJson('/admin/api/activities/act-1/read-blocks/blk-1', [
            'content' => 'Updated text',
        ]);

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/activities/act-1/read-blocks/blk-1')
                && $request->method() === 'PATCH';
        });
    }

    /**
     * ACTV-06c: DELETE /admin/api/activities/act-1/read-blocks/blk-1 deletes a read block.
     */
    public function test_delete_read_block(): void
    {
        Http::fake([
            '*/api/activities/act-1/read-blocks/blk-1' => Http::response([
                'success'  => true,
                'activity' => ['id' => 'act-1'],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->deleteJson('/admin/api/activities/act-1/read-blocks/blk-1');

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/activities/act-1/read-blocks/blk-1')
                && $request->method() === 'DELETE';
        });
    }

    /**
     * ACTV-06d: PATCH /admin/api/activities/act-1/read-blocks/reorder reorders read blocks.
     */
    public function test_reorder_read_blocks(): void
    {
        Http::fake([
            '*/api/activities/act-1/read-blocks/reorder' => Http::response([
                'success'  => true,
                'activity' => ['id' => 'act-1'],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->patchJson('/admin/api/activities/act-1/read-blocks/reorder', [
            'blockIds' => ['blk-2', 'blk-1'],
        ]);

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/activities/act-1/read-blocks/reorder')
                && $request->method() === 'PATCH';
        });
    }

    /**
     * ACTV-07: DELETE /admin/api/activities/act-1 deletes an activity.
     */
    public function test_delete_activity(): void
    {
        Http::fake([
            '*/api/activities/act-1' => Http::response([
                'success' => true,
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->deleteJson('/admin/api/activities/act-1');

        $response->assertStatus(200);
        $response->assertJson(['success' => true]);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/activities/act-1')
                && $request->method() === 'DELETE';
        });
    }

    /**
     * ACTV-08: POST /admin/api/programs/prog-1/lessons/lsn-1/reorder-activities reorders activities.
     */
    public function test_reorder_activities(): void
    {
        Http::fake([
            '*/api/programs/prog-1/lessons/lsn-1/reorder-activities' => Http::response([
                'success'    => true,
                'activities' => [
                    ['id' => 'act-2', 'orderNumber' => 1],
                    ['id' => 'act-1', 'orderNumber' => 2],
                ],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->postJson('/admin/api/programs/prog-1/lessons/lsn-1/reorder-activities', [
            'activityOrder' => ['act-2', 'act-1'],
        ]);

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/programs/prog-1/lessons/lsn-1/reorder-activities')
                && $request->method() === 'POST';
        });
    }

    /**
     * ACTV-09: POST /admin/api/activities/act-1/reset resets an activity to PENDING state.
     */
    public function test_reset_activity(): void
    {
        Http::fake([
            '*/api/activities/act-1/reset' => Http::response([
                'success'  => true,
                'activity' => [
                    'id'     => 'act-1',
                    'status' => 'PENDING',
                ],
            ], 200),
        ]);

        $response = $this->withSession($this->adminSession())->postJson('/admin/api/activities/act-1/reset');

        $response->assertStatus(200);

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/api/activities/act-1/reset')
                && $request->method() === 'POST';
        });
    }
}
