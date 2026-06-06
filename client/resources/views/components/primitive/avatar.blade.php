@props([
    'src' => null,
    'alt' => 'Avatar',
    'name' => null,      // when set, the fallback shows up-to-2-letter initials
    'fallback' => null,  // explicit fallback text (overrides computed initials)
    'size' => 40,
    'loading' => false,
])

@php
    // Built-in fallback: up-to-two-letter initials derived from the name
    // (first + last word, or the first letter of a single word). An explicit
    // `fallback` prop wins for callers that pre-compute their own initials.
    $initials = $fallback;
    if ($initials === null || $initials === '') {
        $parts = array_values(array_filter(
            preg_split('/\s+/', trim((string) $name)),
            fn ($p) => $p !== ''
        ));
        if (count($parts) >= 2) {
            $initials = mb_strtoupper(mb_substr($parts[0], 0, 1) . mb_substr($parts[array_key_last($parts)], 0, 1));
        } elseif (count($parts) === 1) {
            $initials = mb_strtoupper(mb_substr($parts[0], 0, 1));
        } else {
            $initials = '?';
        }
    }

    $style   = '--avatar-size: ' . $size . 'px';
    $classes = 'Avatar' . ($loading ? ' Avatar--loading' : '');
@endphp

<div {{ $attributes->merge(['class' => $classes, 'style' => $style, 'role' => 'img', 'aria-label' => $alt]) }}>
    @if($loading)
        <div class="Avatar__spinner"></div>
    @else
        {{-- Initials fallback is always rendered underneath. A failed image
             (onerror) removes itself to reveal it — we never fall back to the
             browser's native alt text. --}}
        <div class="Avatar__fallback">{{ $initials }}</div>
        @if($src)
            <img
                class="Avatar__image"
                src="{{ $src }}"
                alt=""
                referrerpolicy="no-referrer"
                loading="lazy"
                onerror="this.remove()"
            />
        @endif
    @endif
</div>
