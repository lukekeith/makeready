@props([
    'type'        => 'text',
    'value'       => null,
    'name'        => null,
    'placeholder' => null,
    'disabled'    => false,
    'required'    => false,
])

<input
    type="{{ $type }}"
    {{ $attributes->merge(['class' => 'Input']) }}
    @if($name) name="{{ $name }}" @endif
    @if($value !== null) value="{{ $value }}" @endif
    @if($placeholder) placeholder="{{ $placeholder }}" @endif
    @if($disabled) disabled @endif
    @if($required) required @endif
/>
