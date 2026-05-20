@extends('layouts.auth')

@section('title', 'MakeReady')

@section('content')
<div class="PublicHomePage">

    {{-- Background image with gradient overlay --}}
    <div class="PublicHomePage__background" aria-hidden="true">
        <img
            src="/home-background-full.png"
            alt=""
            class="PublicHomePage__background-image PublicHomePage__background-image--desktop"
        >
        <img
            src="/home-background.png"
            alt=""
            class="PublicHomePage__background-image PublicHomePage__background-image--mobile"
        >
        <div class="PublicHomePage__background-gradient"></div>
    </div>

    {{-- Main content — semantic <main> used for accessibility/SEO (React renders as <div>) --}}
    <main class="PublicHomePage__container">

        <div class="PublicHomePage__content">
            {{-- Logo --}}
            <div class="PublicHomePage__logo-wrapper">
                <img src="/mr-logo.svg" alt="MakeReady" class="PublicHomePage__logo">
            </div>

            {{-- Title and description --}}
            <div class="PublicHomePage__description">
                <h1 class="PublicHomePage__title">Welcome to MakeReady</h1>
                <p class="PublicHomePage__subtitle">
                    MakeReady is an invite only experience that facilitates personal
                    growth through human connection, accountability, and study.
                </p>
            </div>
        </div>

        {{-- Action buttons — React renders Button components (variant=Jump/JumpPrimary) --}}
        <div class="PublicHomePage__buttons">
            @if($hasSession ?? false)
                {{-- Has session cookie: show My Groups button with member icon --}}
                <div
                    data-vue="HomeProfileButton"
                    data-props="{{ json_encode(['href' => route('home'), 'loginHref' => route('login')], JSON_HEX_TAG) }}"
                >
                    {{-- Server fallback before Vue hydrates --}}
                    <button type="button" class="Button Button--jump-primary" onclick="window.location='{{ route('home') }}'">
                        <span class="Button__content">
                            <div class="Avatar Avatar--loading" style="--avatar-size: 36px">
                                <div class="Avatar__spinner"></div>
                            </div>
                            <span class="Button__details">
                                <span class="Button__label">Member Login</span>
                                <span class="Button__description">Sign in with your phone number</span>
                            </span>
                            <span class="Button__icon Button__icon--right">
                                <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
                            </span>
                        </span>
                    </button>
                </div>
            @else
                {{-- No session: Member Login button --}}
                <x-primitive.button
                    variant="JumpPrimary"
                    label="Member Login"
                    description="Sign in with your phone number"
                    onclick="window.location='{{ route('login') }}'"
                >
                    <x-slot:rightIcon><svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg></x-slot:rightIcon>
                </x-primitive.button>
            @endif

            <x-primitive.button
                variant="Jump"
                label="Join group"
                description="Requires 6 digit group code"
                onclick="window.location='{{ route('join.enter-code') }}'"
            >
                <x-slot:rightIcon><svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg></x-slot:rightIcon>
            </x-primitive.button>

            <x-primitive.button
                variant="Jump"
                label="Join event"
                description="Requires 6 digit event code"
                onclick="window.location='{{ route('event.enter-code') }}'"
            >
                <x-slot:rightIcon><svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg></x-slot:rightIcon>
            </x-primitive.button>

            <x-primitive.button
                variant="Jump"
                label="Join study"
                description="Requires 6 digit study code"
                onclick="window.location='{{ route('study.code') }}'"
            >
                <x-slot:rightIcon><svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg></x-slot:rightIcon>
            </x-primitive.button>
        </div>

        {{-- Footer — React renders as <div class="PublicHomePage__footer"> --}}
        <div class="PublicHomePage__footer">
            <p class="PublicHomePage__copyright">Copyright 2026 MakeReady, LLC</p>
            <div class="PublicHomePage__links">
                <a href="{{ route('privacy') }}" class="PublicHomePage__link">Privacy policy</a>
                <span class="PublicHomePage__link-dot" aria-hidden="true"></span>
                <a href="{{ route('terms') }}" class="PublicHomePage__link">Terms of use</a>
                <span class="PublicHomePage__link-dot" aria-hidden="true"></span>
                <a href="{{ route('sms-opt-in') }}" class="PublicHomePage__link">SMS opt-in</a>
            </div>
        </div>

    </main>{{-- /.PublicHomePage__container --}}
</div>{{-- /.PublicHomePage --}}
@endsection
