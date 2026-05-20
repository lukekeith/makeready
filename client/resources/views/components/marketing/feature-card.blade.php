@props([
    'image' => null,
])

<article
    class="MarketingFeatureCard {{ $image ? 'MarketingFeatureCard--has-image' : '' }}"
    @if($image) style="background-image: url('{{ $image }}')" @endif
>
    @if($image)
        <div class="MarketingFeatureCard__overlay"></div>
    @endif
    <div class="MarketingFeatureCard__content">
        {{ $slot }}
    </div>
</article>
