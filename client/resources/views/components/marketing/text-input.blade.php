@props([
    'name',
    'label',
    'placeholder' => null,
    'type' => 'text',
    'value' => null,
    'required' => false,
    'optional' => false,
    'multiline' => false,
    'rows' => 5,
    'min' => null,
    'max' => null,
    'minlength' => null,
    'maxlength' => null,
    'autocomplete' => null,
])

<div class="TextInput @if($multiline) TextInput--multiline @endif" data-text-input>
    <label class="TextInput__label" for="input-{{ $name }}">
        {{ $label }}@if($optional) <em>optional</em>@endif
    </label>
    <div class="TextInput__field">
        @if($multiline)
        <textarea
            class="TextInput__input"
            id="input-{{ $name }}"
            name="{{ $name }}"
            rows="{{ $rows }}"
            placeholder=" "
            @if($required) required @endif
            @if($minlength) minlength="{{ $minlength }}" @endif
            @if($maxlength) maxlength="{{ $maxlength }}" @endif
        >{{ $value }}</textarea>
        @else
        <input
            class="TextInput__input"
            id="input-{{ $name }}"
            name="{{ $name }}"
            type="{{ $type }}"
            value="{{ $value }}"
            placeholder=" "
            @if($required) required @endif
            @if($min) min="{{ $min }}" @endif
            @if($max) max="{{ $max }}" @endif
            @if($maxlength) maxlength="{{ $maxlength }}" @endif
            @if($autocomplete) autocomplete="{{ $autocomplete }}" @endif
        >
        @endif
        @if($placeholder)
        <span class="TextInput__placeholder" aria-hidden="true">{{ $placeholder }}</span>
        @endif
    </div>
</div>
