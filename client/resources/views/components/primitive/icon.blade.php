@props([
    'size' => 'Md',
])

@php
    $classes = cva('Icon', [
        'variants' => [
            'size' => [
                'Xs'  => 'Icon--xs',
                'Sm'  => 'Icon--sm',
                'Md'  => 'Icon--md',
                'Lg'  => 'Icon--lg',
                'Xl'  => 'Icon--xl',
                'Xxl' => 'Icon--2xl',
            ],
        ],
        'defaultVariants' => ['size' => 'Md'],
    ], ['size' => $size]);
@endphp

<span {{ $attributes->merge(['class' => $classes]) }}>{{ $slot }}</span>
