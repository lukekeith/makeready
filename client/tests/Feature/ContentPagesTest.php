<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Content pages feature tests.
 *
 * Covers: CONT-01, CONT-02, CONT-03, CONT-04
 *
 * NOTE: Study code page test (CONT-05) is added by Plan 04-03 Task 2
 * after StudyCodeController is created in Plan 04-02.
 *
 * NOTE on Http::fake() ordering: Laravel 12 uses first-match-wins FIFO ordering.
 * All fakes are registered per-test (NOT in setUp) to avoid FIFO priority conflicts.
 */
class ContentPagesTest extends TestCase
{
    // ─── Helpers ───────────────────────────────────────────────────────────────

    /**
     * Register a standard authenticated session fake plus any additional fakes.
     */
    private function fakeAuth(array $extra = []): void
    {
        Http::fake(array_merge([
            '*/api/members/session' => Http::response([
                'authenticated' => true,
                'member'        => [
                    'id'        => 'member-1',
                    'firstName' => 'Test',
                    'lastName'  => 'User',
                    'phone'     => '+15555555555',
                    'gender'    => 'male',
                    'birthday'  => '1990-01-01',
                    'avatarUrl' => null,
                ],
            ], 200),
        ], $extra));
    }

    /**
     * Minimal study enrollment API response with a lesson list.
     */
    private function studyEnrollmentResponse(): array
    {
        return [
            'success'    => true,
            'study'      => [
                'title'        => 'Alpha Study',
                'description'  => 'A study about foundations.',
                'coverImageUrl' => null,
            ],
            'dayNumber'  => 3,
            'progress'   => 60,
            'lessons'    => [
                [
                    'id'               => 'lesson-1',
                    'lessonScheduleId' => 'schedule-1',
                    'title'            => 'Day 1: Introduction',
                    'dayNumber'        => 1,
                    'status'           => 'complete',
                ],
                [
                    'id'               => 'lesson-2',
                    'lessonScheduleId' => 'schedule-2',
                    'title'            => 'Day 2: The Mission',
                    'dayNumber'        => 2,
                    'status'           => 'next',
                ],
            ],
        ];
    }

    /**
     * Minimal lesson API response with activities.
     */
    private function lessonResponse(): array
    {
        return [
            'success' => true,
            'lesson'  => [
                'id'         => 'lesson-1',
                'title'      => 'Day 1: Introduction',
                'dayNumber'  => 1,
                'activities' => [
                    [
                        'id'       => 'act-1',
                        'type'     => 'VIDEO',
                        'title'    => 'Welcome Video',
                        'videoUrl' => 'https://example.com/video.m3u8',
                    ],
                ],
            ],
        ];
    }

    // ─── Study Home Tests ───────────────────────────────────────────────────────

    /**
     * CONT-01: GET /groups/{groupId}/study/{enrollmentId} renders study home (200).
     */
    public function test_study_home_renders(): void
    {
        $this->fakeAuth([
            '*/api/groups/group-1/study-enrollment/enrollment-1*' => Http::response(
                $this->studyEnrollmentResponse(),
                200
            ),
        ]);

        $response = $this->get('/member/groups/group-1/study/enrollment-1');

        $response->assertStatus(200);
        $response->assertSee('Alpha Study');
    }

    /**
     * CONT-01: GET /groups/{groupId}/study/{enrollmentId} redirects guest (302).
     */
    public function test_study_home_requires_auth(): void
    {
        Http::fake([
            '*/api/members/session' => Http::response(['authenticated' => false], 200),
        ]);

        $response = $this->get('/member/groups/group-1/study/enrollment-1');

        $response->assertStatus(302);
        $response->assertRedirect('/');
    }

    // ─── Lesson Page Tests ──────────────────────────────────────────────────────

    /**
     * CONT-03: GET /groups/{groupId}/lessons/{scheduleId}/1 renders lesson page (200)
     * with LessonIsland mount point.
     */
    public function test_lesson_page_renders_with_island(): void
    {
        $this->fakeAuth([
            '*/api/member/lessons/schedule-1*' => Http::response(
                $this->lessonResponse(),
                200
            ),
        ]);

        $response = $this->get('/member/groups/group-1/lessons/schedule-1/1');

        $response->assertStatus(200);
        $response->assertSee('data-vue="LessonIsland"', false);
    }

    /**
     * CONT-03: GET /groups/{groupId}/lessons/{scheduleId}/1 redirects guest (302).
     */
    public function test_lesson_page_requires_auth(): void
    {
        Http::fake([
            '*/api/members/session' => Http::response(['authenticated' => false], 200),
        ]);

        $response = $this->get('/member/groups/group-1/lessons/schedule-1/1');

        $response->assertStatus(302);
        $response->assertRedirect('/');
    }

    // ─── Route Name Smoke Tests ─────────────────────────────────────────────────

    /**
     * Smoke test: study.home route name resolves.
     */
    public function test_study_home_route_is_registered(): void
    {
        $this->assertTrue(
            (bool) route('study.home', ['groupId' => 'g1', 'studyEnrollmentId' => 'e1']),
            'study.home route name must be registered'
        );
    }

    /**
     * Smoke test: lesson.show route name resolves.
     */
    public function test_lesson_show_route_is_registered(): void
    {
        $this->assertTrue(
            (bool) route('lesson.show', ['groupId' => 'g1', 'lessonScheduleId' => 's1']),
            'lesson.show route name must be registered'
        );
    }

    // ─── Study Code Page Tests (CONT-05) ────────────────────────────────────────

    /**
     * CONT-05: GET /study renders study code entry page (200).
     * Public page — no auth required.
     */
    public function test_study_code_page_renders(): void
    {
        $response = $this->get('/join/study');

        $response->assertStatus(200);
        $response->assertSee('study', false);
    }
}
