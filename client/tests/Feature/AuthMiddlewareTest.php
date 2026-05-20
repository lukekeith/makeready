<?php

namespace Tests\Feature;

use App\Http\Middleware\CheckMemberSession;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Route;
use Tests\TestCase;

class AuthMiddlewareTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        config()->set('services.makeready.url', 'https://api.makeready.org');
    }

    public function test_unauthenticated_request_redirects_to_home(): void
    {
        Http::fake([
            'api.makeready.org/api/members/session' => Http::response([
                'success' => true,
                'authenticated' => false,
            ], 200),
        ]);

        Route::get('/_test/protected', function () {
            return response('Protected content');
        })->middleware(CheckMemberSession::class);

        $response = $this->get('/_test/protected');
        $response->assertRedirect('/');
    }

    public function test_authenticated_request_passes_through(): void
    {
        Http::fake([
            'api.makeready.org/api/members/session' => Http::response([
                'success' => true,
                'authenticated' => true,
                'member' => ['id' => 'clx123', 'firstName' => 'Test'],
            ], 200),
        ]);

        Route::get('/_test/protected', function (\Illuminate\Http\Request $request) {
            return response('Protected content for ' . $request->attributes->get('member')['firstName']);
        })->middleware(CheckMemberSession::class);

        $response = $this->get('/_test/protected');
        $response->assertStatus(200);
        $response->assertSee('Protected content for Test');
    }

    public function test_api_error_redirects_to_home(): void
    {
        Http::fake([
            'api.makeready.org/api/members/session' => Http::response([
                'success' => false,
                'error' => 'Internal error',
            ], 500),
        ]);

        Route::get('/_test/protected', function () {
            return response('Protected content');
        })->middleware(CheckMemberSession::class);

        $response = $this->get('/_test/protected');
        $response->assertRedirect('/');
    }

    public function test_member_data_is_available_in_request_attributes(): void
    {
        Http::fake([
            'api.makeready.org/api/members/session' => Http::response([
                'success' => true,
                'authenticated' => true,
                'member' => [
                    'id' => 'clx456',
                    'firstName' => 'Luke',
                    'phoneNumber' => '+15551234567',
                ],
            ], 200),
        ]);

        Route::get('/_test/protected', function (\Illuminate\Http\Request $request) {
            $member = $request->attributes->get('member');
            return response()->json($member);
        })->middleware(CheckMemberSession::class);

        $response = $this->get('/_test/protected');
        $response->assertStatus(200);
        $response->assertJsonFragment(['firstName' => 'Luke']);
    }
}
