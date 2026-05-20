@extends('layouts.marketing')

@section('title', $content['meta']['title'])
@section('description', $content['meta']['description'])

@section('content')
<main class="MarketingPage MarketingPage--narrow">
    <section class="MarketingStatement">
        <h5 class="Eyebrow">{{ $content['statement']['eyebrow'] }}</h5>
        <h1>{{ $content['statement']['title'] }}</h1>
        <p>{{ $content['statement']['body'] }}</p>
    </section>

    <section class="MarketingFeatureGrid MarketingFeatureGrid--2x2">
        @foreach($content['features'] as $feature)
        <x-marketing.feature-card :image="$feature['image'] ?? null">
            <h3>{{ $feature['title'] }}</h3>
            <p>{{ $feature['description'] }}</p>
        </x-marketing.feature-card>
        @endforeach
    </section>

    <section class="MarketingCtaPanel">
        <h5 class="Eyebrow">{{ $content['cta_panel']['eyebrow'] }}</h5>
        <h2>{{ $content['cta_panel']['title'] }}</h2>
        @foreach($content['cta_panel']['buttons'] as $button)
        <a class="MarketingButton MarketingButton--{{ $button['style'] }}" href="{{ $button['href'] }}">{{ $button['text'] }}</a>
        @endforeach
    </section>

    <x-marketing.faq :faqs="$faqs" />
</main>
@endsection
