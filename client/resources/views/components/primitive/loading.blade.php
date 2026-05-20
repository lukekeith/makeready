@props([
    'variant' => 'Spinner',
    'size'    => 'Md',
    'speed'   => 'Normal',
    'color'   => 'White',
])

@php
    $classes = cva('Loading', [
        'variants' => [
            'variant' => [
                'Spinner' => 'Loading--spinner',
                'Grid'    => 'Loading--grid',
                'Dots'    => 'Loading--dots',
                'Pulse'   => 'Loading--pulse',
                'Bars'    => 'Loading--bars',
            ],
            'size' => [
                'Sm' => 'Loading--sm',
                'Md' => 'Loading--md',
                'Lg' => 'Loading--lg',
                'Xl' => 'Loading--xl',
            ],
            'speed' => [
                'Slow'   => 'Loading--slow',
                'Normal' => 'Loading--normal',
                'Fast'   => 'Loading--fast',
            ],
            'color' => [
                'White'   => 'Loading--white',
                'Dark'    => 'Loading--dark',
                'Primary' => 'Loading--primary',
                'Purple'  => 'Loading--purple',
            ],
        ],
        'defaultVariants' => [
            'variant' => 'Spinner',
            'size'    => 'Md',
            'speed'   => 'Normal',
            'color'   => 'White',
        ],
    ], ['variant' => $variant, 'size' => $size, 'speed' => $speed, 'color' => $color]);
@endphp

<div {{ $attributes->merge(['class' => $classes]) }} role="status" aria-label="Loading">
    <div class="Loading__inner"></div>
</div>
