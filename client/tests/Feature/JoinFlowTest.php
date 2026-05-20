<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Group join flow feature tests.
 *
 * Covers: JOIN-01, JOIN-04, JOIN-05, JOIN-06, JOIN-07
 */
class JoinFlowTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        Http::fake([
            '*/api/groups/code/*' => Http::response([
                'success' => true,
                'group'   => [
                    'id'             => 'group-1',
                    'name'           => 'Test Group',
                    'organizationId' => 'org-1',
                    'code'           => 'ABC123',
                    'memberCount'    => 5,
                    'leader'         => ['firstName' => 'John'],
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

            '*/api/groups/*/join-requests' => Http::response([
                'success' => true,
            ], 200),

            '*/api/members/session' => Http::response([
                'authenticated' => true,
                'member'        => ['id' => 'member-1', 'firstName' => 'Test', 'lastName' => 'User'],
            ], 200),
        ]);
    }

    /**
     * JOIN-07: /join renders the enter-code page (public, no auth required).
     */
    public function test_enter_code_page_renders(): void
    {
        $response = $this->get('/join/group');

        $response->assertStatus(200);
        $response->assertSee('join', false);
    }

    /**
     * JOIN-01: /join/group/{code} (info step) renders group name in HTML.
     */
    public function test_group_info_step_renders(): void
    {
        $response = $this->get('/join/group/ABC123');

        $response->assertStatus(200);
        $response->assertSee('Test Group');
    }

    /**
     * JOIN-01: /join/group/{code}/profile renders profile form.
     */
    public function test_profile_step_renders(): void
    {
        $response = $this->withSession([
            'join.ABC123.groupId'        => 'group-1',
            'join.ABC123.organizationId' => 'org-1',
        ])->get('/join/group/ABC123/profile');

        $response->assertStatus(200);
        $response->assertSee('profile', false);
    }

    /**
     * JOIN-06: POST /join/group/{code}/profile stores form data in session and redirects.
     */
    public function test_profile_stored_in_session(): void
    {
        $response = $this->withSession([
            'join.ABC123.groupId'        => 'group-1',
            'join.ABC123.organizationId' => 'org-1',
        ])->post('/join/group/ABC123/profile', [
            '_token'     => csrf_token(),
            'first_name' => 'Jane',
            'last_name'  => 'Doe',
            'gender'     => 'female',
            'birthday'   => '1990-01-01',
        ]);

        $response->assertRedirect(route('join.group', ['id' => 'ABC123', 'step' => 'phone']));
        $response->assertSessionHas('join.ABC123.firstName', 'Jane');
        $response->assertSessionHas('join.ABC123.lastName', 'Doe');
        $response->assertSessionHas('join.ABC123.gender', 'female');
        $response->assertSessionHas('join.ABC123.birthday', '1990-01-01');
    }

    /**
     * JOIN-05: POST /join/group/{code}/phone returns JSON with redirectUrl on success.
     */
    public function test_phone_submit_returns_redirect(): void
    {
        $response = $this->withSession([
            'join.ABC123.groupId'        => 'group-1',
            'join.ABC123.organizationId' => 'org-1',
            'join.ABC123.firstName'      => 'Jane',
            'join.ABC123.lastName'       => 'Doe',
            'join.ABC123.smsConsent'     => true,
        ])->postJson('/join/group/ABC123/phone', [
            'phoneNumber' => '+15551234567',
        ]);

        $response->assertStatus(200);
        $response->assertJsonStructure(['redirectUrl']);
        $this->assertStringContainsString('verify', $response->json('redirectUrl'));
    }

    /**
     * JOIN-05: POST /join/group/{code}/phone without smsConsent returns 422.
     */
    public function test_phone_submit_requires_sms_consent(): void
    {
        $response = $this->withSession([
            'join.ABC123.groupId'        => 'group-1',
            'join.ABC123.organizationId' => 'org-1',
        ])->postJson('/join/group/ABC123/phone', [
            'phoneNumber' => '+15551234567',
            'smsConsent'  => false,
        ]);

        $response->assertStatus(422);
        $response->assertJson(['error' => 'SMS consent is required']);
    }

    /**
     * JOIN-01: POST /join/group/{code}/verify returns JSON redirectUrl to confirmed step.
     */
    public function test_verify_submit_completes_join(): void
    {
        $response = $this->withSession([
            'join.ABC123.groupId'        => 'group-1',
            'join.ABC123.organizationId' => 'org-1',
            'join.ABC123.firstName'      => 'Jane',
            'join.ABC123.lastName'       => 'Doe',
            'join.ABC123.gender'         => 'female',
            'join.ABC123.birthday'       => '1990-01-01',
            'join.ABC123.phone'          => '+15551234567',
        ])->postJson('/join/group/ABC123/verify', [
            'code' => '123456',
        ]);

        $response->assertStatus(200);
        $response->assertJsonStructure(['redirectUrl']);
        $this->assertStringContainsString('confirmed', $response->json('redirectUrl'));
    }

    /**
     * Smoke test: /join route is registered (JOIN-04, JOIN-07).
     * Route is registered — controller existence checked separately.
     */
    public function test_join_route_is_registered(): void
    {
        // We only confirm the route is registered, not that the controller exists.
        // Requesting a route with a missing controller returns 500 in testing
        // (not a routing error), which means routing resolved the route name.
        $this->assertTrue(
            (bool) route('join.enter-code'),
            'join.enter-code route name must be registered'
        );
    }

    /**
     * Smoke test: group join route name resolves.
     */
    public function test_group_join_route_is_registered(): void
    {
        $this->assertTrue(
            (bool) route('join.group', ['id' => 'ABC123']),
            'join.group route name must be registered'
        );
    }
}
