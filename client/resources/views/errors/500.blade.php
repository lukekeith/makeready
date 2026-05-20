{{-- resources/views/errors/500.blade.php --}}
{{-- Custom 500 Server Error page --}}
@extends('layouts.app')

@section('title', 'Something Went Wrong — MakeReady')

@section('content')
<main class="ErrorPage">
    <div class="ErrorPage__container">
        <img src="/mr-logo.svg" alt="MakeReady" class="ErrorPage__logo" />
        <p class="ErrorPage__code">500</p>
        <h1 class="ErrorPage__title">Something Went Wrong</h1>
        <p class="ErrorPage__message">We're working on fixing this. Please try again later.</p>
        <a href="/" class="ErrorPage__link">Go Home</a>
    </div>
</main>
@endsection
