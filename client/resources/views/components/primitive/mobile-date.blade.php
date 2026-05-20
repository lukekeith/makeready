@props([
    'size'        => 'Default',
    'label'       => '',
    'value'       => '',
    'name'        => null,
    'placeholder' => 'MM/DD/YYYY',
    'min'         => null,
    'max'         => null,
    'disabled'    => false,
])

@php
    $classes = cva('MobileDate', [
        'variants' => [
            'size' => [
                'Default' => 'MobileDate--size-default',
                'Compact' => 'MobileDate--size-compact',
            ],
        ],
        'defaultVariants' => ['size' => 'Default'],
    ], ['size' => $size]);

    if ($value) {
        $classes .= ' MobileDate--floating';
    }
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>
    <div class="MobileDate__wrapper">
        <label class="MobileDate__label">{{ $label }}</label>
        <input
            type="date"
            class="MobileDate__input"
            @if($name) name="{{ $name }}" @endif
            @if($value) value="{{ $value }}" @endif
            @if($min) min="{{ $min }}" @endif
            @if($max) max="{{ $max }}" @endif
            @if($disabled) disabled @endif
            onchange="this.closest('.MobileDate').classList.toggle('MobileDate--floating', this.value.length > 0)"
        />
    </div>
</div>
