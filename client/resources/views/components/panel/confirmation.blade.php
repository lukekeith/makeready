@props([
    'color'       => 'White',
    'title'       => '',
    'description' => '',
])

@php
    $classes = cva('Confirmation', [
        'variants' => [
            'color' => [
                'White'  => 'Confirmation--color-white',
                'Green'  => 'Confirmation--color-green',
                'Red'    => 'Confirmation--color-red',
                'Yellow' => 'Confirmation--color-yellow',
                'Purple' => 'Confirmation--color-purple',
            ],
        ],
        'defaultVariants' => ['color' => 'White'],
    ], ['color' => $color]);
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>
    <x-primitive.icon-circle :variant="$color" size="lg">
        @isset($icon)
            {{ $icon }}
        @else
            <svg width="40" height="40" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M20 6L9 17L4 12" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
        @endisset
    </x-primitive.icon-circle>

    <div class="Confirmation__message">
        <div class="Confirmation__details">
            <h1 class="Confirmation__title">{{ $title }}</h1>
            <p class="Confirmation__description">{{ $description }}</p>
            @isset($action)
                <div class="Confirmation__action">{{ $action }}</div>
            @endisset
        </div>
    </div>
</div>
