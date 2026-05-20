{{--
    Primitive icon-circle badge. Every color variant uses the same pattern:
    20% alpha background + solid icon color of the same hue. Any SVG you slot
    in inherits the variant color via `stroke: currentColor` / `fill: currentColor`.

    Props:
      variant — one of: purple, green, yellow, red, white (default: white)
      size    — "md" (80×80, default) or "lg" (100×100)

    Example:
        <x-primitive.icon-circle variant="purple">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"
                 stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <rect x="5" y="2" width="14" height="20" rx="2" ry="2"/>
                <line x1="12" y1="18" x2="12.01" y2="18"/>
            </svg>
        </x-primitive.icon-circle>
--}}

@props([
    'variant' => 'white',
    'size'    => 'md',
])

@php
    $classes = 'IconCircle IconCircle--' . strtolower($variant);
    if (strtolower($size) === 'lg') {
        $classes .= ' IconCircle--size-lg';
    }
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>
    <div class="IconCircle__icon">{{ $slot }}</div>
</div>
