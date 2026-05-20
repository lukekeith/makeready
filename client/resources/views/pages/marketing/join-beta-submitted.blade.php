@extends('layouts.marketing')

@section('title', 'Application submitted — MakeReady')
@section('description', 'Your MakeReady beta application has been submitted for review.')

@section('content')
<main class="MarketingPage MarketingPage--narrow">
    <section class="MarketingSubmitted">
        <h5 class="Eyebrow">Submitted</p>
        <h1>Your beta application is in review.</h1>
        <p>Thanks for applying. We created a pending application{{ !empty($application['organizationName']) ? ' for ' . $application['organizationName'] : '' }}. Leader access remains inactive until MakeReady approves the request.</p>
        <div class="MarketingSubmitted__card">
            <span>Status</span>
            <strong>{{ $application['status'] ?? 'PENDING' }}</strong>
        </div>
        <a class="MarketingButton MarketingButton--ghost" href="/">Return home</a>
    </section>
</main>
@endsection
