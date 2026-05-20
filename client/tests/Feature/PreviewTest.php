<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Preview pages feature tests.
 *
 * Covers: CONT-05, CONT-06
 *
 * Preview pages are PUBLIC — no authentication required.
 * These pages let non-members view study and lesson content before joining.
 *
 * NOTE on Http::fake() ordering: Laravel 12 uses first-match-wins FIFO ordering.
 * All fakes are registered per-test (NOT in setUp) to avoid FIFO priority conflicts.
 */
class PreviewTest extends TestCase
{
    // ─── Helpers ───────────────────────────────────────────────────────────────

    /**
     * Minimal study preview API response.
     */
    private function studyPreviewResponse(): array
    {
        return [
            'program' => [
                'title'       => 'Alpha Preview Study',
                'description' => 'A preview of the Alpha study.',
            ],
            'lessons' => [
                [
                    'id'        => 'lesson-1',
                    'title'     => 'Day 1: Introduction',
                    'dayNumber' => 1,
                ],
                [
                    'id'        => 'lesson-2',
                    'title'     => 'Day 2: The Mission',
                    'dayNumber' => 2,
                ],
            ],
        ];
    }

    /**
     * Minimal lesson preview API response.
     */
    private function lessonPreviewResponse(): array
    {
        return [
            'lesson' => [
                'id'         => 'lesson-1',
                'title'      => 'Day 1: Introduction',
                'dayNumber'  => 1,
                'activities' => [
                    [
                        'id'       => 'act-1',
                        'type'     => 'VIDEO',
                        'title'    => 'Welcome Video',
                        'videoUrl' => 'https://example.com/preview.m3u8',
                    ],
                ],
            ],
        ];
    }

    // ─── Study Preview Tests ────────────────────────────────────────────────────

    /**
     * CONT-05: GET /public/preview/{token} renders study preview page with study name (200).
     */
    public function test_study_preview_renders(): void
    {
        Http::fake([
            '*/public/preview/test-token' => Http::response(
                $this->studyPreviewResponse(),
                200
            ),
        ]);

        $response = $this->get('/public/preview/test-token');

        $response->assertStatus(200);
        $response->assertSee('Alpha Preview Study');
    }

    /**
     * CONT-05: GET /public/preview/{token} returns 404 when API returns 404 (invalid token).
     */
    public function test_study_preview_404_on_invalid_token(): void
    {
        Http::fake([
            '*/public/preview/invalid-token' => Http::response([], 404),
        ]);

        $response = $this->get('/public/preview/invalid-token');

        $response->assertStatus(404);
    }

    /**
     * CONT-05: Study preview page is public — accessible without any session/auth.
     */
    public function test_study_preview_is_public(): void
    {
        Http::fake([
            '*/public/preview/test-token' => Http::response(
                $this->studyPreviewResponse(),
                200
            ),
        ]);

        // No session, no auth — must return 200 not 302
        $response = $this->get('/public/preview/test-token');

        $response->assertStatus(200);
    }

    // ─── Lesson Preview Tests ───────────────────────────────────────────────────

    /**
     * CONT-06: GET /public/preview/{token}/lesson/{lessonId}/1 renders lesson preview
     * with LessonIsland mount point and isPreview=true.
     */
    public function test_lesson_preview_renders(): void
    {
        Http::fake([
            '*/public/preview/test-token/lesson/lesson-1' => Http::response(
                $this->lessonPreviewResponse(),
                200
            ),
        ]);

        $response = $this->get('/public/preview/test-token/lesson/lesson-1/1');

        $response->assertStatus(200);
        $response->assertSee('data-vue="LessonIsland"', false);
        // Blade {{ }} escapes double-quotes to &quot; so JSON keys appear as &quot;isPreview&quot;
        $response->assertSee('&quot;isPreview&quot;:true', false);
    }

    /**
     * CONT-06: Lesson preview page is public — accessible without any session/auth.
     */
    public function test_lesson_preview_no_auth_required(): void
    {
        Http::fake([
            '*/public/preview/test-token/lesson/lesson-1' => Http::response(
                $this->lessonPreviewResponse(),
                200
            ),
        ]);

        // No session, no auth — must return 200 not 302
        $response = $this->get('/public/preview/test-token/lesson/lesson-1/1');

        $response->assertStatus(200);
    }

    // ─── Route Name Smoke Tests ─────────────────────────────────────────────────

    /**
     * Smoke test: preview.study route name resolves.
     */
    public function test_preview_study_route_is_registered(): void
    {
        $this->assertTrue(
            (bool) route('preview.study', ['token' => 'test-token']),
            'preview.study route name must be registered'
        );
    }

    /**
     * Smoke test: preview.lesson route name resolves.
     */
    public function test_preview_lesson_route_is_registered(): void
    {
        $this->assertTrue(
            (bool) route('preview.lesson', ['token' => 'test-token', 'lessonId' => 'lesson-1']),
            'preview.lesson route name must be registered'
        );
    }
}
