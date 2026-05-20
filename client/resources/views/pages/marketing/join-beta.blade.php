@extends('layouts.marketing')

@section('title', 'Join the beta — MakeReady')
@section('description', 'Apply for reviewed MakeReady beta access for group leaders.')

@section('content')
<main class="MarketingPage">
    <section class="MarketingHero MarketingHero--compact">
        <div class="MarketingHero__copy">
            <h5 class="Eyebrow">Join the beta</p>
            <h1>Tell us about the group you lead.</h1>
            <p class="MarketingHero__body">MakeReady is invite-only while we expand. Sign in with Google so your application is tied to a verified identity, then submit your group details for review.</p>
            <div class="MarketingHero__actions">
                <a class="MarketingButton MarketingButton--primary" href="/join-beta/auth/google">Continue with Google</a>
            </div>
        </div>
    </section>

    <section>
        <x-marketing.timeline :items="[
            ['title' => 'Sign in with Google', 'description' => 'Your application is tied to a verified identity.'],
            ['title' => 'Describe your organization and groups', 'description' => 'Tell us about the community you lead.'],
            ['title' => 'Wait for manual review', 'description' => 'Access is activated after MakeReady approves your application.'],
        ]" />
    </section>

    <section class="MarketingSplit">
        <div>
            <h5 class="Eyebrow">What this creates</p>
            <h2>Pending records, not instant access.</h2>
        </div>
        <p>Your submission creates an inactive organization and inactive leader account in MakeReady’s API backend. Nothing is activated until the application is approved.</p>
    </section>

    <x-marketing.faq :faqs="$faqs" />
</main>
@endsection
