@extends('layouts.auth')

@section('title', 'Login — MakeReady')

@section('content')
@if($step === 'phone')
    {{-- Phone entry step: JoinPhoneIsland handles phone input + SMS submit --}}
    <div
        data-vue="JoinPhoneIsland"
        data-props="{{ json_encode([
            'ajaxSubmitUrl'         => route('login.phone.submit'),
            'title'                 => 'Enter your phone',
            'showSmsConsent'        => false,
            'secondaryButtonLabel'  => 'Back',
            'secondaryRedirectUrl'  => '/',
        ]) }}"
    ></div>
@elseif($step === 'verify')
    {{-- Verify step: matches React MemberLoginPage verify layout exactly --}}
    <div
        data-vue="LoginVerifyIsland"
        data-props="{{ json_encode([
            'ajaxVerifyUrl' => route('login.verify.submit'),
            'phone'         => $phone,
            'resendUrl'     => route('login.phone.submit'),
            'backUrl'       => route('login'),
        ], JSON_HEX_TAG) }}"
    >
        {{-- Server-rendered fallback --}}
        <div class="MemberLoginPage">
            <div class="MemberLoginPage__container">
                <div class="MemberLoginPage__content">
                    <h1 class="MemberLoginPage__title">Verify phone</h1>
                    <p class="MemberLoginPage__description">Enter the 6-digit code sent to {{ $phone ?? '' }}</p>
                </div>
            </div>
        </div>
    </div>
@endif
@endsection
