@props([
    'variant' => 'Default',
    'size' => 'Default',
])

@php
    $classes = cva('Badge', [
        'variants' => [
            'variant' => [
                'Default'     => 'Badge--default',
                'Primary'     => 'Badge--primary',
                'Secondary'   => 'Badge--secondary',
                'Destructive' => 'Badge--destructive',
                'Outline'     => 'Badge--outline',
                'Success'     => 'Badge--success',
                'Warning'     => 'Badge--warning',
            ],
            'size' => [
                'Sm'      => 'Badge--size-sm',
                'Default' => 'Badge--size-default',
                'Lg'      => 'Badge--size-lg',
            ],
        ],
        'defaultVariants' => [
            'variant' => 'Default',
            'size'    => 'Default',
        ],
    ], ['variant' => $variant, 'size' => $size]);
@endphp

<span {{ $attributes->merge(['class' => $classes]) }}>{{ $slot }}</span>
