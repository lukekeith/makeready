@props([
    'variant' => 'Default',
    'padding' => 'Default',
])

@php
    $classes = cva('Card', [
        'variants' => [
            'variant' => [
                'Default'  => 'Card--default',
                'Bordered' => 'Card--bordered',
                'Elevated' => 'Card--elevated',
                'Ghost'    => 'Card--ghost',
            ],
            'padding' => [
                'None'    => 'Card--padding-none',
                'Sm'      => 'Card--padding-sm',
                'Default' => 'Card--padding-default',
                'Lg'      => 'Card--padding-lg',
            ],
        ],
        'defaultVariants' => [
            'variant' => 'Default',
            'padding' => 'Default',
        ],
    ], ['variant' => $variant, 'padding' => $padding]);
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>{{ $slot }}</div>
