{{-- resources/views/pages/join-code.blade.php --}}
{{-- /join/group — enter a group code to begin joining --}}
@extends('layouts.auth')

@section('title', 'Join a Group — MakeReady')
@section('og_title', 'Join a Group on MakeReady')
@section('og_description', 'Enter your group code to join a MakeReady group for personal growth through human connection.')

@section('content')
<div
    data-vue="JoinCodeIsland"
    data-props="{{ json_encode([
        'submitUrl' => route('join.code.submit'),
        'csrfToken' => csrf_token(),
        'homeUrl'   => route('home.public'),
    ], JSON_HEX_TAG) }}"
>
    {{-- Server-rendered fallback (visible before JS loads) --}}
    <div class="JoinCodePage">
        <div class="JoinCodePage__container">
            <img src="/mr-logo.svg" alt="MakeReady" class="JoinCodePage__logo" />
            <h1 class="JoinCodePage__title">Join a group</h1>
            <p class="JoinCodePage__description">Enter the 6-character code shared by your group leader to join their group.</p>
        </div>
    </div>
</div>
@endsection
