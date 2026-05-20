@props([
    'dataUrl' => '',
    'size'    => 'Default',
    'alt'     => 'QR Code',
])

@php
    $classes = cva('QrCode', [
        'variants' => [
            'size' => [
                'Sm'      => 'QrCode--size-sm',
                'Default' => 'QrCode--size-default',
                'Lg'      => 'QrCode--size-lg',
            ],
        ],
        'defaultVariants' => ['size' => 'Default'],
    ], ['size' => $size]);
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>
    <img src="{{ $dataUrl }}" alt="{{ $alt }}" class="QrCode__image" />
</div>
