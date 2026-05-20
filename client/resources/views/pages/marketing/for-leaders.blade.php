@extends('layouts.marketing')

@section('title', $content['meta']['title'])
@section('description', $content['meta']['description'])

@section('content')
<main class="MarketingPage">
    <x-marketing.hero
        :label="$content['hero']['label']"
        :title="$content['hero']['title']"
        :body="$content['hero']['body']"
        :secondary="$content['hero']['secondary']['text']"
        :secondary-href="$content['hero']['secondary']['href']"
    />

    <section class="MarketingSplit MarketingSplit--reverse">
        <div>
            <h5 class="Eyebrow">{{ $content['split']['eyebrow'] }}</h5>
            <h2>{{ $content['split']['title'] }}</h2>
        </div>
        <p>{{ $content['split']['body'] }}</p>
    </section>

    <section class="MarketingFeatureGrid MarketingFeatureGrid--wide">
        @foreach($content['features']['items'] as $feature)
        <article><h3>{{ $feature['title'] }}</h3><p>{{ $feature['description'] }}</p></article>
        @endforeach
    </section>

    <section class="MarketingCtaPanel">
        <h5 class="Eyebrow">{{ $content['cta_panel']['eyebrow'] }}</h5>
        <h2>{{ $content['cta_panel']['title'] }}</h2>
        <p>{{ $content['cta_panel']['body'] }}</p>
        @foreach($content['cta_panel']['buttons'] as $button)
        <a class="MarketingButton MarketingButton--{{ $button['style'] }}" href="{{ $button['href'] }}">{{ $button['text'] }}</a>
        @endforeach
    </section>

    <x-marketing.faq :faqs="$faqs" />
</main>
@endsection
