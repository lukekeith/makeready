@props([
    'size'     => 'Default',
    'variant'  => 'Default',
    'value'    => '',
    'name'     => null,
    'label'    => null,
    'disabled' => false,
    'min'      => null,
    'max'      => null,
    'required' => false,
])

@php
    $classes = cva('DateInput', [
        'variants' => [
            'size' => [
                'Default' => 'DateInput--size-default',
                'Sm'      => 'DateInput--size-sm',
                'Lg'      => 'DateInput--size-lg',
            ],
            'variant' => [
                'Default' => 'DateInput--default',
                'Outline' => 'DateInput--outline',
            ],
        ],
        'defaultVariants' => [
            'size'    => 'Default',
            'variant' => 'Default',
        ],
    ], ['size' => $size, 'variant' => $variant]);
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>
    @if($label)
        <label class="DateInput__label">{{ $label }}</label>
    @endif
    <div class="DateInput__wrapper">
        <input
            type="date"
            class="DateInput__input"
            @if($name) name="{{ $name }}" @endif
            @if($value) value="{{ $value }}" @endif
            @if($min) min="{{ $min }}" @endif
            @if($max) max="{{ $max }}" @endif
            @if($disabled) disabled @endif
            @if($required) required @endif
        />
    </div>
</div>
