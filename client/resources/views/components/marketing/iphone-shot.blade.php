@props([
    'src',
    'alt'   => '',
    'width' => '280px',
])

<div class="IphoneShot" style="width: {{ $width }}">
    <img
        class="IphoneShot__screenshot"
        src="{{ $src }}"
        alt="{{ $alt }}"
        loading="lazy"
    >
    <img
        class="IphoneShot__overlay"
        src="/iphone-17-pro-max.png"
        alt=""
        aria-hidden="true"
    >
</div>
