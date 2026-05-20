<?php

namespace Tests\Feature;

use Tests\TestCase;

class ProjectBootTest extends TestCase
{
    public function test_home_route_returns_200(): void
    {
        $response = $this->get('/');
        $response->assertStatus(200);
    }

    public function test_response_contains_makeready_text(): void
    {
        $response = $this->get('/');
        $response->assertSee('MakeReady');
    }
}
