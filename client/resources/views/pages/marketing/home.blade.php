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
    >
        <x-slot:visual>
            <div class="HeroScreenshots">
                @foreach($content['hero']['screenshots'] as $screenshot)
                <figure class="HeroScreenshots__item">
                    <img src="{{ $screenshot['src'] }}" alt="{{ $screenshot['alt'] }}" loading="lazy">
                </figure>
                @endforeach
            </div>
        </x-slot:visual>
    </x-marketing.hero>

    <section class="MarketingBand MarketingBand--three">
        @foreach($content['band'] as $item)
        <article>
            <span>{{ $item['number'] }}</span>
            <h3>{{ $item['title'] }}</h3>
            <p>{{ $item['caption'] }}</p>
        </article>
        @endforeach
    </section>

    <section class="MarketingSplit">
        <div class="MarketingSplit__media">
            @foreach($content['split']['screenshots'] as $screenshot)
            <x-marketing.iphone-shot
                :src="$screenshot['src']"
                :alt="$screenshot['alt']"
                :width="$screenshot['width']"
            />
            @endforeach
        </div>
        <div class="MarketingSplit__text">
            <h5 class="Eyebrow">{{ $content['split']['eyebrow'] }}</h5>
            <h2>{{ $content['split']['title'] }}</h2>
            <p>{{ $content['split']['body'] }}</p>
        </div>
    </section>

    <section class="MarketingFeatureGrid">
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
        <p>{{ $content['cta_panel']['body'] }}</p>
        <div class="MarketingHero__actions">
            @foreach($content['cta_panel']['buttons'] as $button)
            <a class="MarketingButton MarketingButton--{{ $button['style'] }}" href="{{ $button['href'] }}">{{ $button['text'] }}</a>
            @endforeach
        </div>
    </section>

    <x-marketing.faq :faqs="$faqs" />
</main>
@endsection
