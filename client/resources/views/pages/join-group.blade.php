{{-- resources/views/pages/join-group.blade.php --}}
{{-- /join/group/{id}/{step?} — multi-step group join flow --}}
@extends('layouts.auth')

@section('title', isset($group['name']) ? 'Join ' . $group['name'] . ' — MakeReady' : 'Join Group — MakeReady')
@section('og_title', isset($group['name']) ? 'Join ' . $group['name'] . ' on MakeReady' : 'Join a Group on MakeReady')
@section('og_description', isset($group['name']) ? 'You\'ve been invited to join ' . $group['name'] . ' on MakeReady.' : 'Join a group on MakeReady for personal growth through human connection.')
@if(isset($group['coverImageUrl']) && $group['coverImageUrl'])
@section('og_image', $group['coverImageUrl'])
@endif

@section('content')

@if($step === 'info')

    {{-- ─── Info Step ──────────────────────────────────────────────────────────── --}}
    {{-- React: JoinGroupInfo → FullScreenContainer → JoinPage / JoinPage__container / JoinPage__cards --}}
    <div class="JoinPage">
        <div class="JoinPage__container">
            @if(isset($error))
                <x-panel.confirmation
                    color="Yellow"
                    title="Group not found"
                    description="The group code you entered does not match any groups in our system. Please contact your group leader to get a valid code or request an invite link."
                >
                    <x-slot:icon>
                        <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
                    </x-slot:icon>
                    <x-slot:action>
                        <x-primitive.button variant="White" mode="Block" onclick="window.location.href='{{ route('join.enter-code') }}'">
                            Try again
                        </x-primitive.button>
                        <x-primitive.button variant="Secondary" mode="Block" onclick="window.location.href='{{ route('home.public') }}'">
                            Return home
                        </x-primitive.button>
                    </x-slot:action>
                </x-panel.confirmation>
            @elseif(isset($group) && $group)
                <div class="JoinPage__cards">
                    @if(isset($group['creator']) && $group['creator'])
                        <x-domain.group-leader-note
                            mode="Invite"
                            :leader-name="$group['creator']['name'] ?? ''"
                            :leader-avatar-url="$group['creator']['picture'] ?? $group['coverImageUrl'] ?? null"
                        />
                    @endif

                    <x-panel.group-info-card
                        :photo-url="$group['coverImageUrl'] ?? ''"
                        :group-name="$group['name'] ?? ''"
                        :member-count="$group['memberCount'] ?? 0"
                        :is-private="$group['isPrivate'] ?? false"
                        button-layout="Vertical"
                    >
                        <form method="POST" action="{{ route('join.group.info.submit', ['id' => $id]) }}">
                            @csrf
                            <x-primitive.button type="submit" variant="White" mode="Block">
                                Continue
                            </x-primitive.button>
                        </form>
                        <x-primitive.button variant="Secondary" mode="Block" onclick="window.location.href='{{ route('join.enter-code') }}'">
                            Change group
                        </x-primitive.button>
                    </x-panel.group-info-card>

                    <x-primitive.button variant="LinkMuted" onclick="window.location.href='{{ route('home.public') }}'">
                        <x-slot:leftIcon><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="19" y1="12" x2="5" y2="12"/><polyline points="12 19 5 12 12 5"/></svg></x-slot:leftIcon>
                        Return home
                    </x-primitive.button>
                </div>
            @else
                <x-panel.confirmation
                    color="Yellow"
                    title="Group not found"
                    description="The group code you entered does not match any groups in our system. Please contact your group leader to get a valid code or request an invite link."
                >
                    <x-slot:icon>
                        <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
                    </x-slot:icon>
                    <x-slot:action>
                        <x-primitive.button variant="White" mode="Block" onclick="window.location.href='{{ route('join.enter-code') }}'">
                            Try again
                        </x-primitive.button>
                        <x-primitive.button variant="Secondary" mode="Block" onclick="window.location.href='{{ route('home.public') }}'">
                            Return home
                        </x-primitive.button>
                    </x-slot:action>
                </x-panel.confirmation>
            @endif
        </div>
    </div>

@elseif($step === 'optin')

    {{-- ─── Opt-In Step ────────────────────────────────────────────────────────── --}}
    <div class="JoinPage">
        <div class="JoinPage__container">
            <div class="JoinPage__cards">
                <x-panel.confirmation
                    color="Purple"
                    title="Stay in touch"
                    description="Optionally get text updates about your group. This is not required — you can continue without it."
                >
                    <x-slot:icon>
                        <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="2" width="14" height="20" rx="2" ry="2"/><line x1="12" y1="18" x2="12.01" y2="18"/></svg>
                    </x-slot:icon>
                    <x-slot:action>
                        <form
                            method="POST"
                            action="{{ route('join.group.optin.submit', ['id' => $id]) }}"
                            class="JoinOptin"
                            data-optin-form
                        >
                            @csrf
                            <label class="SmsConsent">
                                <input
                                    type="checkbox"
                                    name="smsConsent"
                                    value="1"
                                    class="SmsConsent__checkbox"
                                    data-optin-checkbox
                                />
                                <span class="SmsConsent__text">
                                    I agree to receive text messages from MakeReady for group-related events and daily studies. Msg &amp; data rates may apply. Reply <strong>STOP</strong> to opt out.
                                    <br>
                                    <a class="SmsConsent__link" href="{{ $privacyUrl }}">Privacy Policy</a>
                                    |
                                    <a class="SmsConsent__link" href="{{ $termsUrl }}">Terms</a>
                                </span>
                            </label>
                            @if(session('error'))
                                <p class="JoinOptin__error" role="alert">{{ session('error') }}</p>
                            @endif
                            <x-primitive.button
                                type="submit"
                                variant="White"
                                mode="Block"
                            >
                                Continue
                            </x-primitive.button>
                        </form>
                        <x-primitive.button variant="Secondary" mode="Block" onclick="window.location.href='{{ route('join.enter-code') }}'">
                            Change group
                        </x-primitive.button>
                    </x-slot:action>
                </x-panel.confirmation>

                <x-primitive.button variant="LinkMuted" onclick="window.location.href='{{ route('home.public') }}'">
                    <x-slot:leftIcon><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="19" y1="12" x2="5" y2="12"/><polyline points="12 19 5 12 12 5"/></svg></x-slot:leftIcon>
                    Return home
                </x-primitive.button>
            </div>
        </div>
    </div>

@elseif($step === 'profile')

    {{-- ─── Profile Step ───────────────────────────────────────────────────────── --}}
    {{-- React: JoinProfile → FullScreenContainer → JoinPage / JoinPage__container / JoinPage__content --}}
    <div class="JoinPage">
        <div class="JoinPage__container">
            <div class="JoinPage__cards">
                <div class="JoinPage__content">
                    <div class="StepTitle">
                        <h1 class="StepTitle__heading">Enter your info</h1>
                        <p class="StepTitle__description">Tell us a bit about yourself to complete your profile.</p>
                    </div>

                    <form method="POST" action="{{ route('join.group.profile.submit', ['id' => $id]) }}">
                        @csrf
                        <x-domain.profile-form
                            :first-name="$firstName ?? ''"
                            :last-name="$lastName ?? ''"
                            :gender="$gender ?? ''"
                            :birthday="$birthday ?? ''"
                            :show-success-message="false"
                        />

                        <div class="JoinPage__button-wrapper">
                            <x-primitive.button type="submit" variant="White" mode="Block">
                                Next
                            </x-primitive.button>
                            <x-primitive.button variant="Secondary" mode="Block" onclick="window.location.href='{{ route('join.enter-code') }}'">
                                Change group
                            </x-primitive.button>
                        </div>
                    </form>
                </div>

                <x-primitive.button variant="LinkMuted" onclick="window.location.href='{{ route('home.public') }}'">
                    <x-slot:leftIcon><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="19" y1="12" x2="5" y2="12"/><polyline points="12 19 5 12 12 5"/></svg></x-slot:leftIcon>
                    Return home
                </x-primitive.button>
            </div>
        </div>
    </div>

@elseif($step === 'phone')

    {{-- ─── Phone Step ─────────────────────────────────────────────────────────── --}}
    {{-- React: JoinPhone → PhoneEntry (full-screen component, not wrapped in JoinPage) --}}
    <div
        data-vue="JoinPhoneIsland"
        data-props="{{ json_encode([
            'ajaxSubmitUrl'        => $ajaxSubmitUrl,
            'title'                => 'Enter your phone',
            'showSmsConsent'       => false,
            'secondaryButtonLabel' => 'Change group',
            'secondaryRedirectUrl' => route('join.enter-code'),
        ]) }}"
    >
        {{-- Server-rendered fallback: visible to crawlers and noscript browsers --}}
        <noscript>
            <div class="JoinPage">
                <div class="JoinPage__container">
                    <div class="JoinPage__cards">
                        <div class="JoinPage__content">
                            <div class="StepTitle">
                                <h1 class="StepTitle__heading">Enter your phone</h1>
                                <p class="StepTitle__description">Enter your phone number to join this group. You will receive a verification code via SMS.</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </noscript>
    </div>

@elseif($step === 'verify')

    {{-- ─── Verify Step ────────────────────────────────────────────────────────── --}}
    <div class="JoinPage">
        <div class="JoinPage__container">
            <div class="JoinPage__cards">
                <x-domain.verify-phone-screen
                    :ajax-verify-url="$ajaxVerifyUrl"
                    :phone="$phone ?? null"
                    page-class="JoinPage"
                    :home-url="route('home.public')"
                />
            </div>
        </div>
    </div>

@elseif($step === 'confirmed')

    {{-- ─── Confirmed Step ───────────────────────────────────────────────────────
         Four explicit branches based on the membershipStatus session value
         resolved by JoinController::submitVerify from the API response:

           pending_new       → first-time pending request (just created)
           pending_duplicate → user re-ran the flow; leader hasn't reviewed yet
           approved          → request was approved (rare — usually `member`)
           member            → user already had an active membership

         Default falls through to `pending_new` if the status is unset, which
         keeps existing in-flight sessions from regressing. --}}
    @php
        $status    = $membershipStatus ?? 'pending_new';
        $groupName = $group['name'] ?? 'this group';
        $groupId   = $group['id'] ?? '';
    @endphp
    <div class="JoinPage">
        <div class="JoinPage__container">
            <div class="JoinPage__cards">
                @if($status === 'member')
                    <x-domain.confirmation-screen
                        title="You're already a member"
                        :description="'You\'re already a member of ' . $groupName . '.'"
                        :home-url="route('home.public')"
                    >
                        <x-slot:action>
                            <x-primitive.button variant="White" mode="Block" onclick="window.location.href='{{ route('group.home', ['groupId' => $groupId]) }}'">
                                Continue
                            </x-primitive.button>
                        </x-slot:action>
                    </x-domain.confirmation-screen>
                @elseif($status === 'approved')
                    <x-domain.confirmation-screen
                        title="You're in!"
                        :description="'Welcome to ' . $groupName . '!'"
                        :home-url="route('home.public')"
                    >
                        <x-slot:action>
                            <x-primitive.button variant="White" mode="Block" onclick="window.location.href='{{ route('group.home', ['groupId' => $groupId]) }}'">
                                Continue
                            </x-primitive.button>
                        </x-slot:action>
                    </x-domain.confirmation-screen>
                @elseif($status === 'pending_duplicate')
                    <x-domain.confirmation-screen
                        color="White"
                        title="Request pending approval"
                        :description="'We already received your request to join ' . $groupName . '. The group leader hasn\'t reviewed it yet — we\'ll text you once they do.'"
                        :home-url="route('home.public')"
                    >
                        <x-slot:icon>
                            <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
                        </x-slot:icon>
                    </x-domain.confirmation-screen>
                @else
                    {{-- pending_new (default) --}}
                    <x-domain.confirmation-screen
                        color="White"
                        title="Request submitted"
                        :description="'Your request to join ' . $groupName . ' has been submitted. The group leader will review your request.'"
                        :home-url="route('home.public')"
                    >
                        <x-slot:icon>
                            <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
                        </x-slot:icon>
                    </x-domain.confirmation-screen>
                @endif
            </div>
        </div>
    </div>

@endif

@endsection
