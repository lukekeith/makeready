{{-- resources/views/pages/join-study.blade.php --}}
{{-- /join/study/{id}/{step?} — multi-step study join flow --}}
@extends('layouts.auth')

@php
    $studyName = isset($lesson) && is_array($lesson) ? ($lesson['studyProgram']['name'] ?? $lesson['studyProgram']['title'] ?? null) : null;
    $studyCover = isset($lesson) && is_array($lesson) ? ($lesson['studyProgram']['coverImageUrl'] ?? null) : null;
    $studyGroup = isset($lesson) && is_array($lesson) ? ($lesson['group']['name'] ?? null) : null;
@endphp
@section('title', $studyName ? 'Join ' . $studyName . ' — MakeReady' : 'Join Study — MakeReady')
@section('og_title', $studyName ? 'Join ' . $studyName . ' on MakeReady' : 'Join a Study on MakeReady')
@section('og_description', $studyName ? 'You\'ve been invited to join the study "' . $studyName . '"' . ($studyGroup ? ' with ' . $studyGroup : '') . ' on MakeReady.' : 'Join a study on MakeReady for personal growth through human connection.')
@if($studyCover)
@section('og_image', $studyCover)
@endif

@section('content')

@if($step === 'info')

    {{-- ─── Info Step ──────────────────────────────────────────────────────────── --}}
    {{-- React: StudyJoinPage → FullScreenContainer → StudyJoinPage / StudyJoinPage__container / StudyJoinPage__cards --}}
    <div class="StudyJoinPage">
        <div class="StudyJoinPage__container">
            @if(isset($error))
                <x-panel.confirmation
                    color="Yellow"
                    title="Study not found"
                    description="The study link you used does not match any studies in our system. Please contact your group leader to get a valid link."
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
            @elseif(isset($lesson) && $lesson)
                <div class="StudyJoinPage__cards">
                    <x-domain.group-leader-note
                        mode="Invite"
                        :leader-name="$lesson['group']['creator']['name'] ?? $lesson['group']['name'] ?? 'Your group'"
                        :leader-avatar-url="$lesson['group']['creator']['picture'] ?? $lesson['group']['coverImageUrl'] ?? null"
                        :message-suffix="'to join a study.'"
                    />
                    <x-panel.study-info-card
                        :study-name="$lesson['studyProgram']['name'] ?? $lesson['studyProgram']['title'] ?? ''"
                        :cover-image-url="$lesson['studyProgram']['coverImageUrl'] ?? ''"
                        :day-info="isset($lesson['dayNumber']) ? 'Day ' . $lesson['dayNumber'] . ' of ' . ($lesson['studyProgram']['days'] ?? $lesson['studyProgram']['lessonCount'] ?? '?') : null"
                        :group-name="$lesson['group']['name'] ?? null"
                    >
                        <x-primitive.button variant="White" mode="Block" onclick="window.location.href='{{ route('join.study', ['id' => $id, 'step' => 'optin']) }}'">
                            Continue
                        </x-primitive.button>
                        <x-primitive.button variant="Secondary" mode="Block" onclick="window.location.href='{{ route('join.enter-code') }}'">
                            Change study
                        </x-primitive.button>
                    </x-panel.study-info-card>

                    <x-primitive.button variant="LinkMuted" onclick="window.location.href='{{ route('home.public') }}'">
                        <x-slot:leftIcon><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="19" y1="12" x2="5" y2="12"/><polyline points="12 19 5 12 12 5"/></svg></x-slot:leftIcon>
                        Return home
                    </x-primitive.button>
                </div>
            @else
                <x-panel.confirmation
                    color="Yellow"
                    title="Study not found"
                    description="The study link you used does not match any studies in our system. Please contact your group leader to get a valid link."
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
    <div class="StudyJoinPage">
        <div class="StudyJoinPage__container">
            <div class="StudyJoinPage__cards">
                <x-panel.confirmation
                    color="Purple"
                    title="Stay in touch"
                    description="Optionally get text updates about this study. This is not required — you can continue without it."
                >
                    <x-slot:icon>
                        <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="2" width="14" height="20" rx="2" ry="2"/><line x1="12" y1="18" x2="12.01" y2="18"/></svg>
                    </x-slot:icon>
                    <x-slot:action>
                        <form
                            method="POST"
                            action="{{ route('join.study.optin.submit', ['id' => $id]) }}"
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
                            Change study
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

@elseif($step === 'phone')

    {{-- ─── Phone Step ─────────────────────────────────────────────────────────── --}}
    {{-- React: PhoneEntry is a full-screen component rendered directly (no StudyJoinPage wrapper) --}}
    <div
        data-vue="JoinPhoneIsland"
        data-props="{{ json_encode([
            'ajaxSubmitUrl'        => $ajaxSubmitUrl,
            'title'                => 'Enter your phone',
            'showSmsConsent'       => false,
            'secondaryButtonLabel' => 'Back',
            'secondaryRedirectUrl' => route('join.study', ['id' => $id]),
        ]) }}"
    >
        {{-- Server-rendered fallback: visible to crawlers and noscript browsers --}}
        <noscript>
            <div class="StudyJoinPage">
                <div class="StudyJoinPage__container">
                    <div class="StudyJoinPage__cards">
                        <div class="StepTitle">
                            <h1 class="StepTitle__heading">Enter your phone</h1>
                            <p class="StepTitle__description">Enter your phone number to join this study. You will receive a verification code via SMS.</p>
                        </div>
                    </div>
                </div>
            </div>
        </noscript>
    </div>

@elseif($step === 'verify')

    {{-- ─── Verify Step ────────────────────────────────────────────────────────── --}}
    <div class="StudyJoinPage">
        <div class="StudyJoinPage__container">
            <div class="StudyJoinPage__cards">
                <x-domain.verify-phone-screen
                    :ajax-verify-url="$ajaxVerifyUrl"
                    :phone="$phone ?? null"
                    page-class="StudyJoinPage"
                    :home-url="route('home.public')"
                />
            </div>
        </div>
    </div>

@elseif($step === 'confirmed')

    {{-- ─── Confirmed Step ─────────────────────────────────────────────────────── --}}
    <div class="StudyJoinPage">
        <div class="StudyJoinPage__container">
            <div class="StudyJoinPage__cards">
                <x-domain.confirmation-screen
                    title="You're In!"
                    description="You have successfully joined this study. Start learning with your group."
                    :home-url="route('home.public')"
                >
                    <x-slot:action>
                        <x-primitive.button variant="White" mode="Block" onclick="window.location.href='{{ route('home') }}'">
                            Go to Home
                        </x-primitive.button>
                    </x-slot:action>
                </x-domain.confirmation-screen>
            </div>
        </div>
    </div>

@endif

@endsection
