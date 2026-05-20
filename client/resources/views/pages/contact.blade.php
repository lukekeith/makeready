@extends('layouts.auth')

@section('title', 'Contact — MakeReady')
@section('og_title', 'Contact MakeReady')
@section('og_description', 'Get in touch with the MakeReady team.')

@section('content')
<div class="ContactPage">
    <div class="ContactPage__container">
        <h1 class="ContactPage__title">Contact</h1>
        <p class="ContactPage__text">
            Have questions or need help? Reach out to us at
            <a href="mailto:support@makeready.org" class="ContactPage__link">support@makeready.org</a>
        </p>
    </div>
</div>
@endsection
