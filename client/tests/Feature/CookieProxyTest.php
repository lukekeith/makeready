<?php

namespace Tests\Feature;

use App\Services\ApiService;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Route;
use Tests\TestCase;

class CookieProxyTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        config()->set('services.makeready.url', 'https://api.makeready.org');
    }

    public function test_controller_passes_single_set_cookie_header_to_browser(): void
    {
        Http::fake([
            'api.makeready.org/api/members/session' => Http::response(
                ['member' => ['id' => 1, 'name' => 'Test User']],
                200,
                ['Set-Cookie' => 'connect.sid=proxy-session; HttpOnly; Path=/']
            ),
        ]);

        Route::get('/_test/proxy', function (\Illuminate\Http\Request $request) {
            $api = app(ApiService::class);
            $result = $api->get('/api/members/session', $request);

            $response = response()->json($result['body'], $result['status']);

            foreach ($result['setCookies'] as $cookieHeader) {
                $response->header('Set-Cookie', $cookieHeader, false);
            }

            return $response;
        });

        $response = $this->get('/_test/proxy');

        $response->assertStatus(200);

        $setCookieHeaders = $response->headers->all('set-cookie');
        $this->assertNotEmpty($setCookieHeaders);
        $this->assertStringContainsString('connect.sid=proxy-session', implode(' ', $setCookieHeaders));
    }

    public function test_controller_passes_set_cookie_header_array_to_browser(): void
    {
        Http::fake([
            'api.makeready.org/api/members/session' => Http::response(
                ['member' => ['id' => 2]],
                200,
                ['Set-Cookie' => 'connect.sid=multi-session; HttpOnly; Path=/']
            ),
        ]);

        Route::get('/_test/proxy-multi', function (\Illuminate\Http\Request $request) {
            $api = app(ApiService::class);
            $result = $api->get('/api/members/session', $request);

            $response = response()->json($result['body'], $result['status']);

            foreach ($result['setCookies'] as $cookieHeader) {
                $response->header('Set-Cookie', $cookieHeader, false);
            }

            return $response;
        });

        $response = $this->get('/_test/proxy-multi');

        $response->assertStatus(200);

        $setCookieHeaders = $response->headers->all('set-cookie');
        $this->assertNotEmpty($setCookieHeaders);
        $this->assertStringContainsString('connect.sid=multi-session', implode(' ', $setCookieHeaders));
    }
}
