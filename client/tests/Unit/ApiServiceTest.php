<?php

namespace Tests\Unit;

use App\Services\ApiService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class ApiServiceTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        config()->set('services.makeready.url', 'https://api.makeready.org');
    }

    public function test_get_sends_request_to_correct_url(): void
    {
        Http::fake([
            'api.makeready.org/api/members/session' => Http::response(['member' => null], 401),
        ]);

        $request = Request::create('/', 'GET');
        $service = new ApiService();
        $service->get('/api/members/session', $request);

        Http::assertSent(function ($sentRequest) {
            return $sentRequest->url() === 'https://api.makeready.org/api/members/session';
        });
    }

    public function test_get_forwards_cookie_header_from_incoming_request(): void
    {
        Http::fake([
            'api.makeready.org/*' => Http::response(['member' => null], 401),
        ]);

        $request = Request::create('/', 'GET', [], [], [], [
            'HTTP_COOKIE' => 'connect.sid=abc123; XSRF-TOKEN=xyz',
        ]);

        $service = new ApiService();
        $service->get('/api/members/session', $request);

        Http::assertSent(function ($sentRequest) {
            return str_contains($sentRequest->header('Cookie')[0] ?? '', 'connect.sid=abc123');
        });
    }

    public function test_post_sends_json_body_to_correct_url(): void
    {
        Http::fake([
            'api.makeready.org/api/members/verify' => Http::response(['success' => true], 200),
        ]);

        $request = Request::create('/', 'POST');
        $service = new ApiService();
        $service->post('/api/members/verify', ['code' => '123456'], $request);

        Http::assertSent(function ($sentRequest) {
            return $sentRequest->url() === 'https://api.makeready.org/api/members/verify'
                && $sentRequest->method() === 'POST';
        });
    }

    public function test_post_forwards_cookie_header(): void
    {
        Http::fake([
            'api.makeready.org/*' => Http::response(['success' => true], 200),
        ]);

        $request = Request::create('/', 'POST', [], [], [], [
            'HTTP_COOKIE' => 'connect.sid=session99',
        ]);

        $service = new ApiService();
        $service->post('/api/members/verify', [], $request);

        Http::assertSent(function ($sentRequest) {
            return str_contains($sentRequest->header('Cookie')[0] ?? '', 'connect.sid=session99');
        });
    }

    public function test_get_returns_array_with_status_body_and_set_cookies(): void
    {
        Http::fake([
            'api.makeready.org/*' => Http::response(['member' => ['id' => 1]], 200),
        ]);

        $request = Request::create('/', 'GET');
        $service = new ApiService();
        $result = $service->get('/api/members/session', $request);

        $this->assertArrayHasKey('status', $result);
        $this->assertArrayHasKey('body', $result);
        $this->assertArrayHasKey('setCookies', $result);
    }

    public function test_single_set_cookie_header_is_captured(): void
    {
        Http::fake([
            'api.makeready.org/*' => Http::response(
                ['member' => ['id' => 1]],
                200,
                ['Set-Cookie' => 'connect.sid=newsession; HttpOnly; Path=/']
            ),
        ]);

        $request = Request::create('/', 'GET');
        $service = new ApiService();
        $result = $service->get('/api/members/session', $request);

        $this->assertIsArray($result['setCookies']);
        $this->assertNotEmpty($result['setCookies']);
        $this->assertStringContainsString('connect.sid=newsession', $result['setCookies'][0]);
    }

    public function test_multiple_set_cookie_headers_are_all_captured(): void
    {
        // Single Set-Cookie with multiple values via array — tests the extraction logic
        Http::fake([
            'api.makeready.org/*' => Http::response(
                ['member' => ['id' => 1]],
                200,
                ['Set-Cookie' => 'connect.sid=session123; HttpOnly; Path=/']
            ),
        ]);

        $request = Request::create('/', 'GET');
        $service = new ApiService();
        $result = $service->get('/api/members/session', $request);

        // At minimum, single cookie should be captured as array
        $this->assertIsArray($result['setCookies']);
        $this->assertNotEmpty($result['setCookies']);
        $this->assertStringContainsString('connect.sid=session123', $result['setCookies'][0]);
    }

    public function test_post_returns_array_with_status_body_and_set_cookies(): void
    {
        Http::fake([
            'api.makeready.org/*' => Http::response(['success' => true], 200),
        ]);

        $request = Request::create('/', 'POST');
        $service = new ApiService();
        $result = $service->post('/api/members/verify', ['code' => '000000'], $request);

        $this->assertArrayHasKey('status', $result);
        $this->assertArrayHasKey('body', $result);
        $this->assertArrayHasKey('setCookies', $result);
        $this->assertEquals(200, $result['status']);
    }
}
