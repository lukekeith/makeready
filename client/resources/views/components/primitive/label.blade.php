@props([
    'for' => null,
])

<label
    {{ $attributes->merge(['class' => 'Label']) }}
    @if($for) for="{{ $for }}" @endif
>{{ $slot }}</label>
