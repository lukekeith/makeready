<?php

namespace Tests\Feature;

use Tests\TestCase;

class ComponentSmokeTest extends TestCase
{
    /**
     * Verify that the cva() PHP helper is callable from within a Blade template
     * and returns the expected BEM class strings.
     *
     * This test renders a minimal Blade test view that calls cva() directly,
     * asserting the helper is globally available and produces correct output.
     */
    public function test_cva_helper_is_callable_in_blade_context(): void
    {
        $response = $this->get(route('test.cva'));
        $response->assertStatus(200);
        $response->assertSee('Button Button--primary');
    }

    public function test_cva_returns_primary_button_classes_in_blade(): void
    {
        $response = $this->get(route('test.cva'));
        $response->assertStatus(200);
        $response->assertSee('Button--primary');
        $response->assertSee('Primary Button');
    }

    public function test_cva_returns_default_variant_classes_in_blade(): void
    {
        $response = $this->get(route('test.cva'));
        $response->assertStatus(200);
        $response->assertSee('Badge Badge--default');
        $response->assertSee('Default Badge');
    }

    public function test_cva_returns_base_class_only_in_blade(): void
    {
        $response = $this->get(route('test.cva'));
        $response->assertStatus(200);
        $response->assertSee('Icon');
    }

    // -----------------------------------------------------------------------
    // Primitive component smoke tests
    // -----------------------------------------------------------------------

    public function test_button_renders_primary_variant(): void
    {
        $html = $this->blade(
            '<x-primitive.button variant="Primary" mode="Action">Click me</x-primitive.button>'
        );
        $html->assertSee('Button');
        $html->assertSee('Button--primary');
        $html->assertSee('Click me');
    }

    public function test_button_renders_block_mode(): void
    {
        $html = $this->blade(
            '<x-primitive.button variant="Secondary" mode="Block">Save</x-primitive.button>'
        );
        $html->assertSee('Button--secondary');
        $html->assertSee('Button--mode-block');
    }

    public function test_avatar_renders_with_src(): void
    {
        $html = $this->blade(
            '<x-primitive.avatar src="/photo.jpg" alt="User" fallback="JD" />'
        );
        $html->assertSee('Avatar');
        $html->assertSee('Avatar__image');
        $html->assertSee('/photo.jpg');
    }

    public function test_avatar_renders_fallback_when_no_src(): void
    {
        $html = $this->blade(
            '<x-primitive.avatar fallback="AB" />'
        );
        $html->assertSee('Avatar__fallback');
        $html->assertSee('AB');
    }

    public function test_badge_renders_default_variant(): void
    {
        $html = $this->blade('<x-primitive.badge>New</x-primitive.badge>');
        $html->assertSee('Badge');
        $html->assertSee('Badge--default');
        $html->assertSee('New');
    }

    public function test_badge_renders_success_variant(): void
    {
        $html = $this->blade('<x-primitive.badge variant="Success">OK</x-primitive.badge>');
        $html->assertSee('Badge--success');
    }

    public function test_card_renders_default(): void
    {
        $html = $this->blade('<x-primitive.card>Content</x-primitive.card>');
        $html->assertSee('Card');
        $html->assertSee('Card--default');
        $html->assertSee('Content');
    }

    public function test_icon_renders_with_size(): void
    {
        $html = $this->blade('<x-primitive.icon size="Lg">+</x-primitive.icon>');
        $html->assertSee('Icon');
        $html->assertSee('Icon--lg');
    }

    public function test_loading_renders_spinner(): void
    {
        $html = $this->blade('<x-primitive.loading variant="Spinner" size="Md" />');
        $html->assertSee('Loading');
        $html->assertSee('Loading--spinner');
        $html->assertSee('Loading--md');
    }

    public function test_toggle_renders_enabled(): void
    {
        $html = $this->blade('<x-primitive.toggle enabled="True" />');
        $html->assertSee('Toggle');
        $html->assertSee('Toggle--enabled');
    }

    public function test_step_indicator_renders_steps(): void
    {
        $html = $this->blade(
            '<x-primitive.step-indicator :totalSteps="3" :currentStep="2" />'
        );
        $html->assertSee('StepIndicator');
        $html->assertSee('StepIndicator__step--active');
    }

    public function test_social_button_renders_google(): void
    {
        $html = $this->blade('<x-primitive.social-button provider="google" />');
        $html->assertSee('SocialButton');
        $html->assertSee('Google');
    }

    public function test_qr_code_renders_image(): void
    {
        $html = $this->blade('<x-primitive.qr-code dataUrl="data:image/png;base64,abc" />');
        $html->assertSee('QrCode');
        $html->assertSee('QrCode__image');
    }

    public function test_input_renders(): void
    {
        $html = $this->blade('<x-primitive.input type="text" name="email" placeholder="Email" />');
        $html->assertSee('Input');
        // assertSee with second arg false = unescaped match
        $html->assertSee('type="text"', false);
    }

    public function test_label_renders(): void
    {
        $html = $this->blade('<x-primitive.label for="email">Email address</x-primitive.label>');
        $html->assertSee('Label');
        $html->assertSee('Email address');
    }

    public function test_mobile_input_renders(): void
    {
        $html = $this->blade('<x-primitive.mobile-input label="First name" value="" />');
        $html->assertSee('MobileInput');
        $html->assertSee('First name');
    }

    public function test_mobile_select_renders_options(): void
    {
        $options = [['value' => 'male', 'label' => 'Male']];
        $html = $this->blade(
            '<x-primitive.mobile-select label="Gender" value="" :options="$options" />',
            ['options' => $options]
        );
        $html->assertSee('MobileSelect');
        $html->assertSee('Male');
    }

    // -----------------------------------------------------------------------
    // Layout component smoke tests
    // -----------------------------------------------------------------------

    public function test_auth_layout_renders_centered(): void
    {
        $html = $this->blade(
            '<x-layout.auth title="Sign In" layout="Centered">Content</x-layout.auth>'
        );
        $html->assertSee('AuthLayout');
        $html->assertSee('Sign In');
    }

    public function test_auth_layout_renders_split(): void
    {
        $html = $this->blade(
            '<x-layout.auth title="Register" layout="Split" :showBranding="true">Content</x-layout.auth>'
        );
        $html->assertSee('AuthLayout--split');
        $html->assertSee('MakeReady');
    }

    public function test_home_layout_renders(): void
    {
        $html = $this->blade('<x-layout.home title="MakeReady">Main</x-layout.home>');
        $html->assertSee('HomeLayout');
        $html->assertSee('MakeReady');
    }

    // -----------------------------------------------------------------------
    // Domain component smoke tests
    // -----------------------------------------------------------------------

    public function test_navigation_renders_selected_home(): void
    {
        $html = $this->blade('<x-domain.navigation selected="home" initials="JD" />');
        $html->assertSee('Navigation');
        $html->assertSee('Navigation__button--selected');
    }

    public function test_navigation_renders_schedule_selected(): void
    {
        $html = $this->blade('<x-domain.navigation selected="schedule" />');
        $html->assertSee('Navigation__button--selected');
        $html->assertSee('aria-current="page"', false);
    }

    public function test_group_card_renders(): void
    {
        $html = $this->blade(
            '<x-domain.group-card name="Alpha Team" :memberCount="10" memberSince="2024-01-01" />'
        );
        $html->assertSee('GroupCard');
        $html->assertSee('Alpha Team');
    }

    public function test_group_card_shows_private(): void
    {
        $html = $this->blade(
            '<x-domain.group-card name="Secret" :isPrivate="true" :memberCount="5" memberSince="2024-01-01" />'
        );
        $html->assertSee('Private group');
    }

    public function test_account_link_renders_link_google(): void
    {
        $html = $this->blade('<x-domain.account-link state="LinkGoogle" />');
        $html->assertSee('AccountLink');
        $html->assertSee('AccountLink--link-google');
        $html->assertSee('Link your Google account');
    }

    public function test_group_home_header_renders(): void
    {
        $html = $this->blade(
            '<x-domain.group-home-header name="My Group" :memberCount="12" />'
        );
        $html->assertSee('GroupHomeHeader');
        $html->assertSee('My Group');
        $html->assertSee('12');
    }

    public function test_invite_header_renders(): void
    {
        $html = $this->blade('<x-domain.invite-header groupName="Youth Group" />');
        $html->assertSee('InviteHeader');
        $html->assertSee('Youth Group');
    }

    public function test_member_card_renders(): void
    {
        $html = $this->blade(
            '<x-domain.member-card firstName="John" lastName="Doe" phoneNumber="+15551234567" />'
        );
        $html->assertSee('MemberCard');
        $html->assertSee('John Doe');
    }

    public function test_scripture_display_renders(): void
    {
        $verses = [['number' => 16, 'text' => 'For God so loved...']];
        $html = $this->blade(
            '<x-domain.scripture-display passageReference="John 3:16" :verses="$verses" />',
            ['verses' => $verses]
        );
        $html->assertSee('ScriptureDisplay');
        $html->assertSee('John 3:16');
        $html->assertSee('For God so loved');
    }

    public function test_study_card_default_mode(): void
    {
        $html = $this->blade('<x-domain.study-card title="Week 1" />');
        $html->assertSee('StudyCard');
        $html->assertSee('Week 1');
    }

    public function test_study_launcher_renders(): void
    {
        $html = $this->blade('<x-domain.study-launcher title="The Gospel" />');
        $html->assertSee('StudyLauncher');
        $html->assertSee('The Gospel');
    }

    public function test_organization_card_renders(): void
    {
        $html = $this->blade(
            '<x-domain.organization-card name="Acme Church" :memberCount="100" :groupCount="5" />'
        );
        $html->assertSee('OrganizationCard');
        $html->assertSee('Acme Church');
    }

    // -----------------------------------------------------------------------
    // Panel component smoke tests
    // -----------------------------------------------------------------------

    public function test_confirmation_renders_white_variant(): void
    {
        $html = $this->blade(
            '<x-panel.confirmation color="White" title="Success" description="You did it!" />'
        );
        $html->assertSee('Confirmation');
        $html->assertSee('Confirmation--color-white');
        $html->assertSee('Success');
        $html->assertSee('You did it!');
    }

    public function test_confirmation_renders_green_variant(): void
    {
        $html = $this->blade(
            '<x-panel.confirmation color="Green" title="Joined!" description="Welcome to the group." />'
        );
        $html->assertSee('Confirmation--color-green');
    }

    public function test_page_title_renders_title(): void
    {
        $html = $this->blade('<x-panel.page-title title="My Profile" />');
        $html->assertSee('PageTitle');
        $html->assertSee('My Profile');
    }

    public function test_page_title_renders_left_icon_slot(): void
    {
        $html = $this->blade(
            '<x-panel.page-title title="Settings"><x-slot:leftIcon><svg><text>X</text></svg></x-slot:leftIcon></x-panel.page-title>'
        );
        $html->assertSee('PageTitle__icon-button');
    }

    public function test_group_info_card_renders(): void
    {
        $html = $this->blade(
            "<x-panel.group-info-card photoUrl=\"/img.jpg\" groupName=\"Men's Group\" :memberCount=\"8\" />"
        );
        $html->assertSee('GroupInfoCard');
        $html->assertSee("Men's Group");
    }

    public function test_study_info_card_renders(): void
    {
        $html = $this->blade(
            '<x-panel.study-info-card coverImageUrl="/cover.jpg" studyName="Romans" dayInfo="Day 3 of 14" />'
        );
        $html->assertSee('StudyInfoCard');
        $html->assertSee('Romans');
        $html->assertSee('Day 3 of 14');
    }
}
