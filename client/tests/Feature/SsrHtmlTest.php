<?php

namespace Tests\Feature;

use Tests\TestCase;

class SsrHtmlTest extends TestCase
{
    public function test_response_contains_full_html_structure(): void
    {
        $response = $this->get('/');
        $response->assertStatus(200);
        $response->assertSee('<html', false);
        $response->assertSee('</html>', false);
    }

    public function test_response_contains_main_tag_from_layout(): void
    {
        $response = $this->get('/');
        $response->assertStatus(200);
        $response->assertSee('<main', false);
    }
}
