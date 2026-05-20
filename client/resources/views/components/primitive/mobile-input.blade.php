@props([
    'size'     => 'Default',
    'label'    => '',
    'value'    => '',
    'name'     => null,
    'type'     => 'text',
    'disabled' => false,
])

@php
    $classes = cva('MobileInput', [
        'variants' => [
            'size' => [
                'Default' => 'MobileInput--size-default',
                'Compact' => 'MobileInput--size-compact',
            ],
        ],
        'defaultVariants' => ['size' => 'Default'],
    ], ['size' => $size]);

    if ($value) {
        $classes .= ' MobileInput--floating';
    }
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>
    <div class="MobileInput__wrapper">
        <label class="MobileInput__label">{{ $label }}</label>
        <input
            type="{{ $type }}"
            class="MobileInput__input"
            @if($name) name="{{ $name }}" @endif
            @if($value) value="{{ $value }}" @endif
            @if($disabled) disabled @endif
            oninput="this.closest('.MobileInput').classList.toggle('MobileInput--floating', this.value.length > 0)"
            onblur="this.closest('.MobileInput').classList.toggle('MobileInput--floating', this.value.length > 0)"
        />
    </div>
</div>
