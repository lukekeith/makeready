@props([
    'enabled'  => 'True',
    'type'     => 'Default',
    'disabled' => false,
    'name'     => null,
])

@php
    $classes = cva('Toggle', [
        'variants' => [
            'enabled' => [
                'True'  => 'Toggle--enabled',
                'False' => 'Toggle--disabled',
            ],
            'type' => [
                'Default' => 'Toggle--default',
                'Radio'   => 'Toggle--radio',
            ],
        ],
        'defaultVariants' => [
            'enabled' => 'True',
            'type'    => 'Default',
        ],
    ], ['enabled' => $enabled, 'type' => $type]);

    $isEnabled = $enabled === 'True';
    $role      = $type === 'Radio' ? 'radio' : 'switch';
@endphp

<button
    type="button"
    {{ $attributes->merge(['class' => $classes]) }}
    role="{{ $role }}"
    aria-checked="{{ $isEnabled ? 'true' : 'false' }}"
    @if($disabled) disabled @endif
>
    <div class="Toggle__knob"></div>
</button>
