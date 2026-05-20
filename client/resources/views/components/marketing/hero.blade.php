@props([
    'label',
    'title',
    'body',
    'cta' => 'Join the beta',
    'href' => '/join-beta',
    'secondary' => null,
    'secondaryHref' => null,
])

<section class="MarketingHero {{ (isset($visual) && $visual->isNotEmpty()) ? 'MarketingHero--split' : '' }}">
    <div class="MarketingHero__copy">
        <h5 class="Eyebrow">{{ $label }}</p>
        <h1>{{ $title }}</h1>
        <p class="MarketingHero__body">{{ $body }}</p>
        <div class="MarketingHero__actions">
            <a class="MarketingButton MarketingButton--primary" href="{{ $href }}">{{ $cta }}</a>
            @if($secondary && $secondaryHref)
                <a class="MarketingButton MarketingButton--ghost" href="{{ $secondaryHref }}">{{ $secondary }}</a>
            @endif
        </div>
    </div>
    @if(isset($visual) && $visual->isNotEmpty())
    <div class="MarketingHero__visual">
        {{ $visual }}
    </div>
    @endif
</section>
