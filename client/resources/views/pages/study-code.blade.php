{{-- resources/views/pages/study-code.blade.php --}}
{{-- /join/study — enter a study code to begin the study join flow --}}
{{-- React: StudyCodePage → JoinCodePage component (same JoinCodePage BEM classes as join-code page) --}}
@extends('layouts.auth')

@section('title', 'Join a Study — MakeReady')
@section('og_title', 'Join a Study on MakeReady')
@section('og_description', 'Enter your study code to join a MakeReady study for personal growth through human connection.')

@section('content')
<div
    data-vue="JoinCodeIsland"
    data-props="{{ json_encode([
        'submitUrl'   => '/join/study/',
        'csrfToken'   => csrf_token(),
        'homeUrl'     => route('home.public'),
        'title'       => 'Join a study',
        'description' => 'Enter the 6-character code shared by your group leader to join the study.',
        'buttonLabel' => 'Join Study',
        'navigateMode' => true,
    ], JSON_HEX_TAG) }}"
>
    {{-- Server-rendered fallback (visible before JS loads) --}}
    <div class="JoinCodePage">
        <div class="JoinCodePage__container">
            <img src="/mr-logo.svg" alt="MakeReady" class="JoinCodePage__logo" />
            <h1 class="JoinCodePage__title">Join a study</h1>
            <p class="JoinCodePage__description">Enter the 6-character code shared by your group leader to join the study.</p>
        </div>
    </div>
</div>
@endsection
