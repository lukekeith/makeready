<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Visual fidelity test scaffold.
 *
 * Asserts that each page's root BEM class name appears in the rendered HTML,
 * confirming the Blade template uses the exact same root class as the React page.
 *
 * NOTE: Visual CSS correctness (colour, spacing, layout) cannot be asserted via
 * PHPUnit — that requires a real browser. These tests verify only the HTML class
 * attribute, which is a prerequisite for any SCSS rules to apply at all.
 *
 * NOTE on Http::fake() ordering: Laravel 12 uses first-match-wins FIFO ordering.
 * All fakes are registered per-test (NOT in setUp) to avoid FIFO priority conflicts.
 */
class VisualFidelityTest extends TestCase
{
    // ─── Helpers ───────────────────────────────────────────────────────────────

    /**
     * Register a standard authenticated session fake, optionally merged with extra fakes.
     */
    private function fakeAuth(array $extra = []): void
    {
        Http::fake(array_merge([
            '*/api/members/session' => Http::response([
                'authenticated' => true,
                'member'        => [
                    'id'        => 'member-1',
                    'firstName' => 'Test',
                    'lastName'  => 'User',
                    'phone'     => '+15555555555',
                    'gender'    => 'male',
                    'birthday'  => '1990-01-01',
                    'avatarUrl' => null,
                ],
            ], 200),
        ], $extra));
    }

    /**
     * Register an unauthenticated session fake.
     */
    private function fakeUnauthenticated(): void
    {
        Http::fake([
            '*/api/members/session' => Http::response(['authenticated' => false], 200),
        ]);
    }

    // ─── Public pages (no auth required) ───────────────────────────────────────

    /**
     * VF-01: GET /privacy renders with root class InfoPage.
     */
    public function test_privacy_page_has_root_bem_class(): void
    {
        $response = $this->get('/pages/privacy');

        $response->assertStatus(200);
        $response->assertSee('InfoPage', false);
    }

    /**
     * VF-02: GET /terms renders with root class InfoPage.
     */
    public function test_terms_page_has_root_bem_class(): void
    {
        $response = $this->get('/pages/terms');

        $response->assertStatus(200);
        $response->assertSee('InfoPage', false);
    }

    /**
     * VF-03: GET / (public home) renders with MarketingPage root class.
     */
    public function test_public_home_page_has_root_bem_class(): void
    {
        $this->fakeUnauthenticated();

        $response = $this->get('/');

        $response->assertStatus(200);
        $response->assertSee('MarketingPage', false);
    }

    // ─── Authenticated pages ────────────────────────────────────────────────────

    /**
     * VF-04: GET /home renders with root class MemberHomePage (not HomeAuthenticated).
     *
     * React page: MemberHomePage
     * Previous Blade root class: HomeAuthenticated  ← MISMATCH — must be fixed
     */
    public function test_authenticated_home_has_root_bem_class(): void
    {
        $this->fakeAuth([
            '*/api/groups' => Http::response([
                'success' => true,
                'data'    => [
                    ['id' => 'group-1', 'name' => 'Test Group', 'memberCount' => 5, 'avatarUrl' => null],
                    ['id' => 'group-2', 'name' => 'Other Group', 'memberCount' => 3, 'avatarUrl' => null],
                ],
            ], 200),
        ]);

        $response = $this->get('/member/home');

        $response->assertStatus(200);
        $response->assertSee('MemberHomePage', false);
    }

    /**
     * VF-05: GET /profile renders with root class ProfilePage.
     */
    public function test_profile_page_has_root_bem_class(): void
    {
        $this->fakeAuth();

        $response = $this->get('/member/profile');

        $response->assertStatus(200);
        $response->assertSee('ProfilePage', false);
    }

    /**
     * VF-06: GET /groups/{id} renders with root class GroupHome.
     *
     * React page uses class="GroupHome" on the root element.
     */
    public function test_group_home_has_root_bem_class(): void
    {
        Http::fake([
            '*/api/members/session' => Http::response([
                'authenticated' => true,
                'member'        => [
                    'id'        => 'member-1',
                    'firstName' => 'Test',
                    'lastName'  => 'User',
                    'phone'     => '+15555555555',
                    'gender'    => 'male',
                    'birthday'  => '1990-01-01',
                    'avatarUrl' => null,
                ],
            ], 200),
            '*/api/groups/group-1/public' => Http::response([
                'success' => true,
                'group'   => [
                    'id'          => 'group-1',
                    'name'        => 'Test Group',
                    'memberCount' => 5,
                    'leader'      => ['firstName' => 'John'],
                    'avatarUrl'   => null,
                ],
            ], 200),
            '*/api/groups/group-1/posts*' => Http::response([
                'success' => true,
                'posts'   => [],
            ], 200),
            '*/api/groups/group-1/study-enrollment*' => Http::response([
                'success'    => true,
                'enrollment' => null,
            ], 200),
        ]);

        $response = $this->get('/member/groups/group-1');

        $response->assertStatus(200);
        $response->assertSee('GroupHome', false);
    }

    /**
     * VF-07: GET /groups/{id}/study/{enrollmentId} renders with root class StudyHome.
     *
     * React page uses class="StudyHome" on the root element.
     * Previous Blade root class: StudyHomePage  ← MISMATCH — must be fixed
     */
    public function test_study_home_has_root_bem_class(): void
    {
        Http::fake([
            '*/api/members/session' => Http::response([
                'authenticated' => true,
                'member'        => [
                    'id'        => 'member-1',
                    'firstName' => 'Test',
                    'lastName'  => 'User',
                    'phone'     => '+15555555555',
                    'gender'    => 'male',
                    'birthday'  => '1990-01-01',
                    'avatarUrl' => null,
                ],
            ], 200),
            '*/api/groups/group-1/study-enrollment/enrollment-1*' => Http::response([
                'success'    => true,
                'study'      => [
                    'title'        => 'Alpha Study',
                    'description'  => 'A study about foundations.',
                    'coverImageUrl' => null,
                ],
                'dayNumber'  => 3,
                'progress'   => 60,
                'lessons'    => [],
                'schedule'   => null,
            ], 200),
        ]);

        $response = $this->get('/member/groups/group-1/study/enrollment-1');

        $response->assertStatus(200);
        $response->assertSee('StudyHome', false);
    }

    // ─── Button inner structure ─────────────────────────────────────────────────

    /**
     * VF-08: Button Blade component always wraps content in Button__content span.
     *
     * Verifies the Button Blade component emits Button__content wrapper on all paths,
     * including the standard label path (not just the loading path).
     *
     * NOTE: Visual CSS correctness (colours, spacing) cannot be asserted via PHPUnit.
     * This test verifies only that the required DOM structure is present.
     */
    public function test_button_renders_button_content_wrapper(): void
    {
        $html = $this->blade('<x-primitive.button label="Save" />');

        $html->assertSee('Button__content', false);
        $html->assertSee('Button__label', false);
    }

    /**
     * VF-09: Button Jump variant renders Button__details with label and description.
     */
    public function test_button_jump_variant_renders_button_details(): void
    {
        $html = $this->blade(
            '<x-primitive.button variant="Jump" label="Member Login" description="Sign in with your phone number" />'
        );

        $html->assertSee('Button__content', false);
        $html->assertSee('Button__details', false);
        $html->assertSee('Button__label', false);
        $html->assertSee('Button__description', false);
        $html->assertSee('Member Login', false);
        $html->assertSee('Sign in with your phone number', false);
    }
}
