{{-- ui2-enrollment-create D15: a one-at-a-time lesson opened before its day. --}}
@extends('layouts.auth')

@section('title', 'Lesson not available yet — MakeReady')

@section('content')
<div class="LessonNotYetPage">
    <p class="LessonNotYetPage__message">{{ $message }}</p>
</div>
@endsection
