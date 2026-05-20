@props([
    'spacing'       => 'Comfortable',
    'title'         => 'MakeReady',
    'logo'          => null,
    'user'          => null,
    'centerContent' => false,
])

@php
    $classes = cva('HomeLayout', [
        'variants' => [
            'spacing' => [
                'Comfortable' => 'HomeLayout--comfortable',
                'Compact'     => 'HomeLayout--compact',
            ],
        ],
        'defaultVariants' => ['spacing' => 'Comfortable'],
    ], ['spacing' => $spacing]);

    $mainClass = 'HomeLayout__main';
    if ($centerContent) {
        $mainClass .= ' HomeLayout__main--center';
    }
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>
    <header class="HomeLayout__header">
        <div class="HomeLayout__header-inner">
            @if($logo)
                <div class="HomeLayout__logo">
                    <img src="{{ $logo }}" alt="{{ $title }}" />
                    <span>{{ $title }}</span>
                </div>
            @else
                <h1 class="HomeLayout__title">{{ $title }}</h1>
            @endif

            <div class="HomeLayout__header-actions">
                @if($user && !isset($avatar))
                    <span class="HomeLayout__user-name">{{ $user['name'] ?? '' }}</span>
                @endif
                @isset($avatar){{ $avatar }}@endisset
                @isset($headerActions){{ $headerActions }}@endisset
            </div>
        </div>
    </header>

    <main class="{{ $mainClass }}">
        {{ $slot }}
    </main>
</div>
