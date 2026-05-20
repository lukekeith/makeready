@props([
    'size'        => 'Default',
    'align'       => 'Center',
    'title'       => '',
    'description' => null,
])

@php
    $classes = cva('EmptyState', [
        'variants' => [
            'size' => [
                'Sm'      => 'EmptyState--size-sm',
                'Default' => 'EmptyState--size-default',
                'Lg'      => 'EmptyState--size-lg',
            ],
            'align' => [
                'Center' => 'EmptyState--align-center',
                'Left'   => 'EmptyState--align-left',
            ],
        ],
        'defaultVariants' => [
            'size'  => 'Default',
            'align' => 'Center',
        ],
    ], ['size' => $size, 'align' => $align]);
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>
    @isset($icon)
        <div class="EmptyState__icon">{{ $icon }}</div>
    @endisset
    <div class="EmptyState__content">
        <h3 class="EmptyState__title">{{ $title }}</h3>
        @if($description)
            <p class="EmptyState__description">{{ $description }}</p>
        @endif
    </div>
    @isset($action)
        <div class="EmptyState__action">{{ $action }}</div>
    @endisset
</div>
