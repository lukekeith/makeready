{{-- resources/views/pages/event-code.blade.php --}}
{{-- /join/event — enter an event code to begin the event join flow --}}
{{-- React: EventJoinEnterCode → JoinCodePage component with event-specific props --}}
@extends('layouts.auth')

@section('title', 'Join an Event — MakeReady')
@section('og_title', 'Join an Event on MakeReady')
@section('og_description', 'Enter your event code to join a MakeReady event.')

@section('content')
<div
    data-vue="JoinCodeIsland"
    data-props="{{ json_encode([
        'submitUrl'    => '/join/event/',
        'csrfToken'    => csrf_token(),
        'homeUrl'      => route('home.public'),
        'title'        => 'Join an event',
        'description'  => 'Enter the 6-character code shared by your group leader to join an event.',
        'buttonLabel'  => 'Find Event',
        'navigateMode' => true,
    ], JSON_HEX_TAG) }}"
>
    {{-- Server-rendered fallback (visible before JS loads) --}}
    <div class="JoinCodePage">
        <div class="JoinCodePage__container">
            <img src="/mr-logo.svg" alt="MakeReady" class="JoinCodePage__logo" />
            <h1 class="JoinCodePage__title">Join an event</h1>
            <p class="JoinCodePage__description">Enter the 6-character code shared by your group leader to join an event.</p>
        </div>
    </div>
</div>
@endsection
