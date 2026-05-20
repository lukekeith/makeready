@props([
    'src' => null,
    'alt' => 'Avatar',
    'fallback' => '?',
    'size' => 40,
    'loading' => false,
])

@php
    $style = '--avatar-size: ' . $size . 'px';
    if ($src && !$loading) {
        $style .= '; background-image: url(' . e($src) . ')';
    }

    $classes = 'Avatar';
    if ($loading) {
        $classes .= ' Avatar--loading';
    } elseif ($src) {
        $classes .= ' Avatar--has-image';
    }
@endphp

<div {{ $attributes->merge(['class' => $classes, 'style' => $style, 'role' => 'img', 'aria-label' => $alt]) }}>
    @if($loading)
        <div class="Avatar__spinner"></div>
    @elseif(!$src)
        <div class="Avatar__fallback">{{ $fallback }}</div>
    @endif
</div>
