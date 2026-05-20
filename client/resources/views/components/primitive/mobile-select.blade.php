@props([
    'size'        => 'Default',
    'label'       => '',
    'value'       => '',
    'name'        => null,
    'options'     => [],
    'placeholder' => 'Select option',
    'disabled'    => false,
])

@php
    $classes = cva('MobileSelect', [
        'variants' => [
            'size' => [
                'Default' => 'MobileSelect--size-default',
                'Compact' => 'MobileSelect--size-compact',
            ],
        ],
        'defaultVariants' => ['size' => 'Default'],
    ], ['size' => $size]);
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>
    <label class="MobileSelect__label">{{ $label }}</label>
    <div class="MobileSelect__wrapper">
        <select
            class="MobileSelect__select"
            @if($name) name="{{ $name }}" @endif
            @if($disabled) disabled @endif
        >
            <option value="" @if(!$value) selected @endif disabled>{{ $placeholder }}</option>
            @foreach($options as $option)
                <option
                    value="{{ $option['value'] ?? $option }}"
                    @if($value === ($option['value'] ?? $option)) selected @endif
                >{{ $option['label'] ?? $option }}</option>
            @endforeach
        </select>
        <svg class="MobileSelect__icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="6 9 12 15 18 9" />
        </svg>
    </div>
</div>
