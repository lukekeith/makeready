@props(['items' => []])

<section class="MarketingScreenshotRow" aria-label="Product screenshots">
    @foreach($items as $item)
    <figure class="MarketingScreenshotRow__item">
        <div class="IphoneFrame">
            <img
                src="{{ $item['src'] }}"
                alt="{{ $item['label'] }}"
                loading="lazy"
                class="IphoneFrame__screen"
            >
            <img
                src="/iphone-17-pro-max.png"
                alt=""
                aria-hidden="true"
                class="IphoneFrame__overlay"
            >
        </div>
    </figure>
    @endforeach
</section>
