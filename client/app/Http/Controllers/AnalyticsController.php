<?php

namespace App\Http\Controllers;

use App\Services\ApiService;
use Illuminate\Http\Request;

/**
 * Member analytics event proxy.
 *
 * Forwards the web tracker's batched events (resources/js/analytics.ts) to the
 * API server's ingestion endpoint with the member's server session attached —
 * the server sets the actor from that session, never from the payload. The
 * route is CSRF-exempt (bootstrap/app.php) because the page-close flush uses
 * navigator.sendBeacon, which cannot send CSRF headers; the endpoint is
 * idempotent (client UUID keys), session-authed, validated, and rate-limited
 * server-side.
 */
class AnalyticsController extends Controller
{
    public function __construct(
        private ApiService $api,
    ) {}

    public function ingestEvents(Request $request)
    {
        $data = $request->json()->all();

        $result = $this->api->post('/api/analytics/events', $data, $request);

        $response = response()->json($result['body'], $result['status']);

        foreach ($result['setCookies'] as $cookie) {
            $response->header('Set-Cookie', $cookie, false);
        }

        return $response;
    }
}
