{{-- resources/views/pages/join-event.blade.php --}}
{{-- /join/event/{id}/{step?} — multi-step event join flow --}}
@extends('layouts.auth')

@php
    $eventName = $event['name'] ?? null;
    $eventCover = $event['coverImageUrl'] ?? null;
    $eventDate = isset($event['date']) ? \Carbon\Carbon::parse($event['date'])->format('M j, Y') : null;
@endphp
@section('title', $eventName ? $eventName . ' — MakeReady' : 'Join Event — MakeReady')
@section('og_title', $eventName ? $eventName . ' on MakeReady' : 'Join an Event on MakeReady')
@section('og_description', $eventName ? 'You\'re invited to ' . $eventName . ($eventDate ? ' on ' . $eventDate : '') . '.' : 'Join an event on MakeReady.')
@if($eventCover)
@section('og_image', $eventCover)
@endif

@section('content')

@if($step === 'info')

    {{-- ─── Info Step ──────────────────────────────────────────────────────────── --}}
    {{-- React: EventJoinInfo → FullScreenContainer → EventJoinPage / EventJoinPage__container / EventJoinPage__content --}}
    <div class="EventJoinPage">
        <div class="EventJoinPage__container">
            <div class="EventJoinPage__cards">
                @if(isset($error))
                    <x-panel.confirmation
                        color="Yellow"
                        title="Event not found"
                        description="The event code you entered does not match any events in our system. Please contact your group leader to get a valid code."
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
                @elseif(isset($event) && $event)
                    @if(isset($event['creator']) && $event['creator'])
                        <x-domain.group-leader-note
                            mode="Invite"
                            :leader-name="$event['creator']['name'] ?? ''"
                            :leader-avatar-url="$event['creator']['picture'] ?? null"
                            message-suffix="to attend this event."
                        />
                    @endif

                    <div class="EventJoinPage__content">
                        <x-domain.event-card
                            :title="$event['name'] ?? ''"
                            :date="$event['date'] ?? null"
                            :time="$event['time'] ?? null"
                            :location="$event['location'] ?? null"
                            :cover-image-url="$event['coverImageUrl'] ?? null"
                            :attendee-count="$event['attendeeCount'] ?? null"
                        />

                        <div class="EventJoinPage__button-wrapper">
                            <x-primitive.button variant="White" mode="Block" onclick="window.location.href='{{ route('join.event', ['id' => $id, 'step' => 'optin']) }}'">
                                Continue
                            </x-primitive.button>
                        </div>
                    </div>
                @else
                    <x-panel.confirmation
                        color="Yellow"
                        title="Event not found"
                        description="The event code you entered does not match any events in our system. Please contact your group leader to get a valid code."
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

                <x-primitive.button variant="LinkMuted" onclick="window.location.href='{{ route('home.public') }}'">
                    <x-slot:leftIcon><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="19" y1="12" x2="5" y2="12"/><polyline points="12 19 5 12 12 5"/></svg></x-slot:leftIcon>
                    Return home
                </x-primitive.button>
            </div>
        </div>
    </div>

@elseif($step === 'optin')

    {{-- ─── Opt-In Step ────────────────────────────────────────────────────────── --}}
    <div class="EventJoinPage">
        <div class="EventJoinPage__container">
            <div class="EventJoinPage__cards">
                <x-panel.confirmation
                    color="Purple"
                    title="Stay in touch"
                    description="Optionally get text updates about this event. This is not required — you can continue without it."
                >
                    <x-slot:icon>
                        <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="2" width="14" height="20" rx="2" ry="2"/><line x1="12" y1="18" x2="12.01" y2="18"/></svg>
                    </x-slot:icon>
                    <x-slot:action>
                        <form
                            method="POST"
                            action="{{ route('join.event.optin.submit', ['id' => $id]) }}"
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
                        <x-primitive.button variant="Secondary" mode="Block" onclick="window.location.href='{{ route('join.event', ['id' => $id]) }}'">
                            Change event
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
    {{-- React: EventJoinPhone → PhoneEntry (full-screen component, rendered directly) --}}
    <div
        data-vue="JoinPhoneIsland"
        data-props="{{ json_encode([
            'ajaxSubmitUrl'  => $ajaxSubmitUrl,
            'title'          => 'Enter your phone',
            'showSmsConsent' => false,
        ]) }}"
    >
        {{-- Server-rendered fallback: visible to crawlers and noscript browsers --}}
        <noscript>
            <div class="EventJoinPage">
                <div class="EventJoinPage__container">
                    <div class="EventJoinPage__cards">
                        <div class="EventJoinPage__content">
                            <div class="StepTitle">
                                <h1 class="StepTitle__heading">Enter your phone</h1>
                                <p class="StepTitle__description">Enter your phone number to join this event. You will receive a verification code via SMS.</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </noscript>
    </div>

@elseif($step === 'verify')

    {{-- ─── Verify Step ────────────────────────────────────────────────────────── --}}
    <div class="EventJoinPage">
        <div class="EventJoinPage__container">
            <div class="EventJoinPage__cards">
                <x-domain.verify-phone-screen
                    :ajax-verify-url="$ajaxVerifyUrl"
                    :phone="$phone ?? null"
                    page-class="EventJoinPage"
                    :home-url="route('home.public')"
                />
            </div>
        </div>
    </div>

@elseif($step === 'confirmed')

    {{-- ─── Confirmed Step ─────────────────────────────────────────────────────── --}}
    <div class="EventJoinPage">
        <div class="EventJoinPage__container">
            <div class="EventJoinPage__cards">
                <x-domain.confirmation-screen
                    title="You're attending!"
                    :description="'You\'ve confirmed your attendance for ' . ($eventName ?? 'this event') . '.'"
                    :home-url="route('home.public')"
                />
            </div>
        </div>
    </div>

@endif

@endsection
