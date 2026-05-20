@props([
    'size'             => 'Default',
    'passageReference' => '',
    'href'             => null,
])

@php
    $classes = cva('ReadPassageButton', [
        'variants' => [
            'size' => [
                'Default' => 'ReadPassageButton--size-default',
                'Large'   => 'ReadPassageButton--size-large',
            ],
        ],
        'defaultVariants' => ['size' => 'Default'],
    ], ['size' => $size]);

    $iconSize = $size === 'Large' ? 24 : 20;
@endphp

@if($href)
    <a href="{{ $href }}" {{ $attributes->merge(['class' => $classes]) }}>
        <svg class="ReadPassageButton__icon" width="{{ $iconSize }}" height="{{ $iconSize }}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
            <path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z" />
            <path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z" />
        </svg>
        <span class="ReadPassageButton__text">{{ $passageReference }}</span>
    </a>
@else
    <button type="button" {{ $attributes->merge(['class' => $classes]) }}>
        <svg class="ReadPassageButton__icon" width="{{ $iconSize }}" height="{{ $iconSize }}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
            <path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z" />
            <path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z" />
        </svg>
        <span class="ReadPassageButton__text">{{ $passageReference }}</span>
    </button>
@endif
