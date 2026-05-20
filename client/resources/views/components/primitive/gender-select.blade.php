@props([
    'size'        => 'Default',
    'variant'     => 'Default',
    'value'       => '',
    'name'        => null,
    'label'       => null,
    'placeholder' => 'Select gender',
    'disabled'    => false,
    'required'    => false,
])

@php
    $classes = cva('GenderSelect', [
        'variants' => [
            'size' => [
                'Default' => 'GenderSelect--size-default',
                'Sm'      => 'GenderSelect--size-sm',
                'Lg'      => 'GenderSelect--size-lg',
            ],
            'variant' => [
                'Default' => 'GenderSelect--default',
                'Outline' => 'GenderSelect--outline',
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
        <label class="GenderSelect__label">{{ $label }}</label>
    @endif
    <div class="GenderSelect__wrapper">
        <select
            class="GenderSelect__select"
            @if($name) name="{{ $name }}" @endif
            @if($disabled) disabled @endif
            @if($required) required @endif
        >
            <option value="" @if(!$value) selected @endif disabled>{{ $placeholder }}</option>
            <option value="male" @if($value === 'male') selected @endif>Male</option>
            <option value="female" @if($value === 'female') selected @endif>Female</option>
        </select>
        <svg class="GenderSelect__icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="6 9 12 15 18 9" />
        </svg>
    </div>
</div>
