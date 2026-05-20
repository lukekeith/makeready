<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Study join flow feature tests.
 *
 * Covers: JOIN-02
 */
class StudyJoinTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        Http::fake([
            '*/api/lessons/code/*' => Http::response([
                'success' => true,
                'lesson'  => [
                    'id'             => 'lesson-1',
                    'code'           => 'study-abc',
                    'dayNumber'      => 1,
                    'organizationId' => 'org-1',
                    'studyProgram'   => [
                        'id'            => 'sp-1',
                        'name'          => 'Test Study',
                        'title'         => 'Test Study',
                        'description'   => 'A test study program',
                        'days'          => 14,
                        'coverImageUrl' => 'https://example.com/cover.jpg',
                    ],
                    'group'          => [
                        'id'   => 'group-1',
                        'code' => 'GRP123',
                        'name' => 'Test Group',
                        'creator' => [
                            'id'      => 'creator-1',
                            'name'    => 'Test Leader',
                            'picture' => null,
                        ],
                    ],
                ],
            ], 200),

            '*/api/lessons/*' => Http::response([
                'success' => true,
                'lesson'  => [
                    'id'             => 'lesson-1',
                    'code'           => 'study-abc',
                    'dayNumber'      => 1,
                    'organizationId' => 'org-1',
                    'studyProgram'   => [
                        'id'            => 'sp-1',
                        'name'          => 'Test Study',
                        'title'         => 'Test Study',
                        'description'   => 'A test study program',
                        'days'          => 14,
                        'coverImageUrl' => 'https://example.com/cover.jpg',
                    ],
                    'group'          => [
                        'id'   => 'group-1',
                        'code' => 'GRP123',
                        'name' => 'Test Group',
                        'creator' => [
                            'id'      => 'creator-1',
                            'name'    => 'Test Leader',
                            'picture' => null,
                        ],
                    ],
                ],
            ], 200),

            '*/api/members/verify-phone' => Http::response([
                'success' => true,
            ], 200),

            '*/api/members/confirm-verification' => Http::response([
                'success'       => true,
                'authenticated' => true,
                'member'        => ['id' => 'member-1', 'firstName' => 'Test'],
            ], 200),
        ]);
    }

    /**
     * JOIN-02: /join/study/{identifier} (info step) renders study details.
     */
    public function test_study_info_step_renders(): void
    {
        $response = $this->get('/join/study/study-abc');

        $response->assertStatus(200);
        $response->assertSee('Test Study');
    }

    /**
     * JOIN-02: /join/study/{identifier}/phone renders phone entry step.
     */
    public function test_study_phone_step_renders(): void
    {
        $response = $this->withSession([
            'study.study-abc.lessonId'       => 'lesson-1',
            'study.study-abc.organizationId' => 'org-1',
            'study.study-abc.smsConsent'     => true,
        ])->get('/join/study/study-abc/phone');

        $response->assertStatus(200);
        $response->assertSee('JoinPhoneIsland', false);
    }

    /**
     * JOIN-02: POST /join/study/{identifier}/phone returns JSON redirectUrl.
     */
    public function test_study_phone_submit_returns_redirect(): void
    {
        $response = $this->withSession([
            'study.study-abc.lessonId'       => 'lesson-1',
            'study.study-abc.organizationId' => 'org-1',
            'study.study-abc.smsConsent'     => true,
        ])->postJson('/join/study/study-abc/phone', [
            'phoneNumber' => '+15551234567',
        ]);

        $response->assertStatus(200);
        $response->assertJsonStructure(['redirectUrl']);
        $this->assertStringContainsString('verify', $response->json('redirectUrl'));
    }

    /**
     * JOIN-02: /join/study/{identifier}/verify renders verify step.
     */
    public function test_study_verify_step_renders(): void
    {
        $response = $this->withSession([
            'study.study-abc.lessonId'       => 'lesson-1',
            'study.study-abc.organizationId' => 'org-1',
            'study.study-abc.phone'          => '+15551234567',
        ])->get('/join/study/study-abc/verify');

        $response->assertStatus(200);
        $response->assertSee('JoinVerifyIsland', false);
    }

    /**
     * JOIN-02: POST /join/study/{identifier}/verify confirms verification.
     */
    public function test_study_verify_submit_completes(): void
    {
        $response = $this->withSession([
            'study.study-abc.lessonId'       => 'lesson-1',
            'study.study-abc.organizationId' => 'org-1',
            'study.study-abc.phone'          => '+15551234567',
        ])->postJson('/join/study/study-abc/verify', [
            'code' => '123456',
        ]);

        $response->assertStatus(200);
        $response->assertJsonStructure(['redirectUrl']);
        $this->assertStringContainsString('confirmed', $response->json('redirectUrl'));
    }

    /**
     * JOIN-02: /join/study/{identifier}/confirmed renders confirmation.
     */
    public function test_study_confirmed_step_renders(): void
    {
        $response = $this->get('/join/study/study-abc/confirmed');

        $response->assertStatus(200);
        $response->assertSee("You're In!");
    }

    /**
     * Smoke test: study join route name resolves.
     */
    public function test_study_join_route_is_registered(): void
    {
        $this->assertTrue(
            (bool) route('join.study', ['id' => 'study-abc']),
            'join.study route name must be registered'
        );
    }

    /**
     * Smoke test: study phone submit route name resolves.
     */
    public function test_study_phone_submit_route_is_registered(): void
    {
        $this->assertTrue(
            (bool) route('join.study.phone.submit', ['id' => 'study-abc']),
            'join.study.phone.submit route name must be registered'
        );
    }
}
