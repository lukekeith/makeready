<?php

namespace Tests\Feature;

use Tests\TestCase;

/**
 * Error pages feature tests.
 *
 * Covers: INFR-03, INFR-04
 *
 * Tests that 404 and 500 error views render branded, user-friendly content.
 */
class ErrorPagesTest extends TestCase
{
    /**
     * INFR-03: A non-existent route returns 404 with the NotFoundPage class.
     * React renders a minimal fullscreen "404" text — no extra content.
     */
    public function test_404_page_renders_with_content(): void
    {
        $response = $this->get('/this-route-does-not-exist-xyz');

        $response->assertStatus(404);
        $response->assertSee('NotFoundPage', false);
        $response->assertSee('404');
    }

    /**
     * INFR-03: The 404 page uses the NotFoundPage BEM class (matches React).
     */
    public function test_404_page_has_not_found_class(): void
    {
        $response = $this->get('/this-route-does-not-exist-xyz');

        $response->assertStatus(404);
        $response->assertSee('NotFoundPage__text', false);
    }

    /**
     * INFR-03: The 404 page shows the error code.
     */
    public function test_404_page_shows_error_code(): void
    {
        $response = $this->get('/this-route-does-not-exist-xyz');

        $response->assertStatus(404);
        $response->assertSee('404');
    }

    /**
     * INFR-04: The 500 error view renders user-friendly content.
     * Tests the view directly since triggering a real 500 requires withoutExceptionHandling.
     */
    public function test_500_error_view_renders(): void
    {
        $view = $this->view('errors.500');

        $view->assertSee('Something Went Wrong');
        $view->assertSee('MakeReady');
    }

    /**
     * INFR-04: The 500 error view shows the error code.
     */
    public function test_500_error_view_shows_error_code(): void
    {
        $view = $this->view('errors.500');

        $view->assertSee('500');
    }

    /**
     * INFR-04: The 500 error view has a go home link.
     */
    public function test_500_error_view_has_go_home_link(): void
    {
        $view = $this->view('errors.500');

        $view->assertSee('Go Home');
    }
}
