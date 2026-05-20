@extends('layouts.marketing')

@section('title', $content['meta']['title'])
@section('description', $content['meta']['description'])

@section('content')
<main class="MarketingPage">
    <x-marketing.hero
        :label="$content['hero']['label']"
        :title="$content['hero']['title']"
        :body="$content['hero']['body']"
        :cta="$content['hero']['cta']['text']"
        :href="$content['hero']['cta']['href']"
        :secondary="$content['hero']['secondary']['text']"
        :secondary-href="$content['hero']['secondary']['href']"
    />

    <section class="MarketingBand MarketingBand--three">
        @foreach($content['band'] as $item)
        <article><span>{{ $item['label'] }}</span><h3>{{ $item['title'] }}</h3><p>{{ $item['caption'] }}</p></article>
        @endforeach
    </section>

    <section class="MarketingSplit">
        <div>
            <h5 class="Eyebrow">{{ $content['split']['eyebrow'] }}</h5>
            <h2>{{ $content['split']['title'] }}</h2>
        </div>
        <p>{{ $content['split']['body'] }}</p>
    </section>

    <x-marketing.faq :faqs="$faqs" />
</main>
@endsection
