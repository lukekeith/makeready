<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Member pages feature tests.
 *
 * Covers: MEMB-01, MEMB-03, MEMB-04, MEMB-05, MEMB-06, MEMB-07
 *
 * NOTE on Http::fake() ordering: Laravel 12 uses first-match-wins. The setUp()
 * fake is always registered first, so per-test overrides for the SAME URL pattern
 * do NOT win. Strategy: setUp() registers only non-contested fakes (group detail,
 * posts, enrollment, member PATCH stub). Session and group-list fakes are
 * registered per-test via helpers to ensure correct URL priority.
 */
class MemberPagesTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        // Non-contested fakes shared by all tests.
        // Group-list (*/api/groups) and session fakes are intentionally EXCLUDED
        // here and registered per-test to avoid first-match priority conflicts.
        Http::fake([
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

            '*/api/members/member-1' => Http::response([
                'success' => true,
                'member'  => [
                    'id'        => 'member-1',
                    'firstName' => 'Test',
                    'lastName'  => 'User',
                    'phone'     => '+15555555555',
                    'gender'    => 'male',
                    'birthday'  => '1990-01-01',
                    'avatarUrl' => null,
                ],
            ], 200),
        ]);
    }

    /**
     * Build a complete fake set for an authenticated session.
     * Registers session + groups fakes together so first-match ordering is clear.
     *
     * @param  array  $groups  Group data to return from /api/groups
     */
    private function fakeAuthWithGroups(array $groups = []): void
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
            '*/api/members/*/groups' => Http::response([
                'success' => true,
                'data'    => $groups,
            ], 200),
        ]);
    }

    /** Default 2-group list used by most authenticated tests. */
    private function twoGroups(): array
    {
        return [
            ['id' => 'group-1', 'name' => 'Test Group',  'memberCount' => 5, 'avatarUrl' => null],
            ['id' => 'group-2', 'name' => 'Other Group', 'memberCount' => 3, 'avatarUrl' => null],
        ];
    }

    /** Single-group list used by single-group redirect test. */
    private function oneGroup(): array
    {
        return [
            ['id' => 'group-1', 'name' => 'Test Group', 'memberCount' => 5, 'avatarUrl' => null],
        ];
    }

    /**
     * MEMB-01: GET / renders public home page (200 when unauthenticated).
     */
    public function test_public_home_renders(): void
    {
        Http::fake([
            '*/api/members/session' => Http::response(['authenticated' => false], 200),
        ]);

        $response = $this->get('/');

        $response->assertStatus(200);
        $response->assertSee('MakeReady');
    }

    /**
     * MEMB-01: GET / always renders public home (no auth redirect).
     */
    public function test_public_home_always_renders(): void
    {
        $response = $this->get('/');

        $response->assertStatus(200);
        $response->assertSee('MarketingPage', false);
    }

    /**
     * MEMB-03: GET /home returns 302 (redirect to /) when not authenticated.
     * Marked incomplete — covered by AuthMiddlewareTest.
     */
    public function test_authenticated_home_redirects_unauthenticated(): void
    {
        $this->markTestIncomplete(
            'Auth redirect covered by AuthMiddlewareTest. ' .
            'Full integration test requires HomeController to be implemented.'
        );
    }

    /**
     * MEMB-03: GET /home redirects a multi-group member to their first group's
     * home. The group home pager handles navigating between groups, so members
     * no longer land on a separate chooser list.
     */
    public function test_authenticated_home_multi_group_redirect(): void
    {
        $this->fakeAuthWithGroups($this->twoGroups());

        $response = $this->get('/member/home');

        $response->assertRedirect('/member/groups/group-1');
    }

    /**
     * MEMB-03: GET /home redirects to /groups/{id} when member has exactly one group.
     */
    public function test_authenticated_home_single_group_redirect(): void
    {
        $this->fakeAuthWithGroups($this->oneGroup());

        $response = $this->get('/member/home');

        $response->assertRedirect('/member/groups/group-1');
    }

    /**
     * MEMB-07: GET /groups renders group list for authenticated member.
     */
    public function test_groups_list(): void
    {
        $this->fakeAuthWithGroups($this->twoGroups());

        $response = $this->get('/member/groups');

        $response->assertStatus(200);
        $response->assertSee('Test Group');
    }

    /**
     * MEMB-04: GET /groups/{id} renders group home page with group name.
     */
    public function test_group_home_renders(): void
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
        ]);

        $response = $this->get('/member/groups/group-1');

        $response->assertStatus(200);
        $response->assertSee('Test Group');
    }

    /**
     * MEMB-05: GET /profile renders member profile data.
     */
    public function test_profile_view(): void
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
        ]);

        $response = $this->get('/member/profile');

        $response->assertStatus(200);
        $response->assertSee('Test');
        $response->assertSee('User');
    }

    /**
     * MEMB-06: POST /profile updates member and redirects back to /profile.
     */
    public function test_profile_update(): void
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
            '*/api/members/member-1' => Http::response([
                'success' => true,
                'member'  => [
                    'id'        => 'member-1',
                    'firstName' => 'Updated',
                    'lastName'  => 'Name',
                    'phone'     => '+15555555555',
                ],
            ], 200),
        ]);

        $response = $this->post('/member/profile', [
            'first_name' => 'Updated',
            'last_name'  => 'Name',
        ]);

        $response->assertRedirect('/member/profile');
    }

    /**
     * MEMB-06: POST /profile with missing required fields fails validation.
     */
    public function test_profile_update_validates(): void
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
        ]);

        $response = $this->post('/member/profile', [
            // Missing first_name and last_name (required)
        ]);

        $response->assertSessionHasErrors(['first_name', 'last_name']);
    }

    /**
     * Smoke test: public home route name resolves.
     */
    public function test_public_home_route_is_registered(): void
    {
        $this->assertTrue(
            (bool) route('home.public'),
            'home.public route name must be registered'
        );
    }

    /**
     * Smoke test: authenticated home route name resolves.
     */
    public function test_authenticated_home_route_is_registered(): void
    {
        $this->assertTrue(
            (bool) route('home'),
            'home route name must be registered'
        );
    }

    /**
     * Smoke test: groups route name resolves.
     */
    public function test_groups_route_is_registered(): void
    {
        $this->assertTrue(
            (bool) route('groups'),
            'groups route name must be registered'
        );
    }

    /**
     * Smoke test: group home route name resolves.
     */
    public function test_group_home_route_is_registered(): void
    {
        $this->assertTrue(
            (bool) route('group.home', ['groupId' => 'group-1']),
            'group.home route name must be registered'
        );
    }

    /**
     * Smoke test: profile route name resolves.
     */
    public function test_profile_route_is_registered(): void
    {
        $this->assertTrue(
            (bool) route('profile'),
            'profile route name must be registered'
        );
    }
}
