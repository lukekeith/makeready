<?php

namespace Tests\Feature;

use Tests\TestCase;

class ComplianceTest extends TestCase
{
    // -----------------------------------------------------------------------
    // Privacy page
    // -----------------------------------------------------------------------

    public function test_privacy_returns_200(): void
    {
        $response = $this->get('/pages/privacy');
        $response->assertStatus(200);
    }

    public function test_privacy_contains_third_party_statement(): void
    {
        $response = $this->get('/pages/privacy');
        $response->assertSee('No mobile information will be shared with third parties');
    }

    public function test_privacy_uses_marketing_layout_with_navbar(): void
    {
        $response = $this->get('/pages/privacy');
        $response->assertSee('MarketingNav', false);
        $response->assertSee('MarketingFooter', false);
    }

    // -----------------------------------------------------------------------
    // Terms page
    // -----------------------------------------------------------------------

    public function test_terms_returns_200(): void
    {
        $response = $this->get('/pages/terms');
        $response->assertStatus(200);
    }

    public function test_terms_contains_stop_in_bold(): void
    {
        $response = $this->get('/pages/terms');
        $response->assertSee('<strong>STOP</strong>', false);
    }

    public function test_terms_contains_help_in_bold(): void
    {
        $response = $this->get('/pages/terms');
        $response->assertSee('<strong>HELP</strong>', false);
    }

    public function test_terms_contains_message_and_data_rates(): void
    {
        $response = $this->get('/pages/terms');
        $response->assertSee('Message and data rates may apply');
    }

    public function test_terms_contains_message_frequency(): void
    {
        $response = $this->get('/pages/terms');
        $response->assertSee('Message frequency varies');
    }

    // -----------------------------------------------------------------------
    // SMS opt-in page
    // -----------------------------------------------------------------------

    public function test_sms_opt_in_returns_200(): void
    {
        $response = $this->get('/pages/sms-opt-in');
        $response->assertStatus(200);
    }

    public function test_sms_opt_in_contains_unchecked_checkbox(): void
    {
        $response = $this->get('/pages/sms-opt-in');
        // Checkbox must be present
        $response->assertSee('type="checkbox"', false);
        // The checkbox must NOT have the checked attribute
        $this->assertStringNotContainsString(
            'checked',
            $this->extractCheckboxTag($response->getContent())
        );
    }

    public function test_sms_opt_in_links_to_privacy(): void
    {
        $response = $this->get('/pages/sms-opt-in');
        $response->assertSee('/privacy', false);
    }

    public function test_sms_opt_in_links_to_terms(): void
    {
        $response = $this->get('/pages/sms-opt-in');
        $response->assertSee('/terms', false);
    }

    // -----------------------------------------------------------------------
    // All pages are public (no auth required)
    // -----------------------------------------------------------------------

    public function test_compliance_pages_are_public(): void
    {
        foreach (['/pages/privacy', '/pages/terms', '/pages/sms-opt-in'] as $url) {
            $this->get($url)->assertStatus(200);
        }
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    /**
     * Extract just the <input type="checkbox" ...> tag from the HTML so we
     * can assert that "checked" does not appear on that element specifically.
     */
    private function extractCheckboxTag(string $html): string
    {
        if (preg_match('/<input[^>]+type="checkbox"[^>]*/i', $html, $matches)) {
            return $matches[0];
        }

        return '';
    }
}
