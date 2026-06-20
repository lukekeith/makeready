<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Event join flow feature tests.
 *
 * Covers: JOIN-03
 */
class EventJoinTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        Http::fake([
            '*/api/events/code/*' => Http::response([
                'success' => true,
                'event'   => [
                    'id'             => 'event-1',
                    'name'           => 'Test Event',
                    'organizationId' => 'org-1',
                    'code'           => 'EVT123',
                    'date'           => '2026-04-01',
                    'time'           => '10:00 AM',
                    'location'       => '123 Main St',
                    'leader'         => ['firstName' => 'Jane'],
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

            '*/api/events/*/attend' => Http::response([
                'success' => true,
            ], 200),
        ]);
    }

    /**
     * JOIN-03: /event/{code} (info step) renders event details.
     */
    public function test_event_info_step_renders(): void
    {
        $response = $this->get('/join/event/EVT123');

        $response->assertStatus(200);
        $response->assertSee('Test Event');
    }

    /**
     * JOIN-03: /event/{code}/phone renders phone entry step.
     */
    public function test_event_phone_step_renders(): void
    {
        $response = $this->withSession([
            'event.EVT123.eventId'        => 'event-1',
            'event.EVT123.organizationId' => 'org-1',
            'event.EVT123.smsConsent'     => true,
            'event.EVT123.optinDone'      => true,
        ])->get('/join/event/EVT123/phone');

        $response->assertStatus(200);
        $response->assertSee('JoinPhoneIsland', false);
    }

    /**
     * JOIN-03: POST /event/{code}/phone returns JSON redirectUrl.
     */
    public function test_event_phone_submit_returns_redirect(): void
    {
        $response = $this->withSession([
            'event.EVT123.eventId'        => 'event-1',
            'event.EVT123.organizationId' => 'org-1',
            'event.EVT123.smsConsent'     => true,
            'event.EVT123.optinDone'      => true,
        ])->postJson('/join/event/EVT123/phone', [
            'phoneNumber' => '+15551234567',
        ]);

        $response->assertStatus(200);
        $response->assertJsonStructure(['redirectUrl']);
        $this->assertStringContainsString('verify', $response->json('redirectUrl'));
    }

    /**
     * JOIN-03: /event/{code}/verify renders verify step.
     */
    public function test_event_verify_step_renders(): void
    {
        $response = $this->withSession([
            'event.EVT123.eventId'        => 'event-1',
            'event.EVT123.organizationId' => 'org-1',
            'event.EVT123.phone'          => '+15551234567',
        ])->get('/join/event/EVT123/verify');

        $response->assertStatus(200);
        $response->assertSee('JoinVerifyIsland', false);
    }

    /**
     * JOIN-03: POST /event/{code}/verify completes join and returns redirectUrl.
     */
    public function test_event_verify_submit_completes_join(): void
    {
        $response = $this->withSession([
            'event.EVT123.eventId'        => 'event-1',
            'event.EVT123.organizationId' => 'org-1',
            'event.EVT123.phone'          => '+15551234567',
        ])->postJson('/join/event/EVT123/verify', [
            'code' => '123456',
        ]);

        $response->assertStatus(200);
        $response->assertJsonStructure(['redirectUrl']);
        $this->assertStringContainsString('confirmed', $response->json('redirectUrl'));
    }

    /**
     * JOIN-03: /event/{code}/confirmed renders confirmation screen.
     */
    public function test_event_confirmed_step_renders(): void
    {
        $response = $this->get('/join/event/EVT123/confirmed');

        $response->assertStatus(200);
        $response->assertSee("attending!", false);
    }

    /**
     * Smoke test: event join route name resolves.
     */
    public function test_event_join_route_is_registered(): void
    {
        $this->assertTrue(
            (bool) route('join.event', ['id' => 'EVT123']),
            'join.event route name must be registered'
        );
    }

    /**
     * Smoke test: event phone submit route name resolves.
     */
    public function test_event_phone_submit_route_is_registered(): void
    {
        $this->assertTrue(
            (bool) route('join.event.phone.submit', ['id' => 'EVT123']),
            'join.event.phone.submit route name must be registered'
        );
    }
}
