@props([
    'mode'          => 'Default',
    'name'          => '',
    'coverImageUrl' => null,
    'isPrivate'     => false,
    'memberCount'   => 0,
    'memberSince'   => null,
    'alertText'     => null,
    'showChevron'   => 'False',
    'backHref'      => null,
])

@php
    $classes = cva('GroupCard', [
        'variants' => [
            'mode' => [
                'Default' => 'GroupCard--default',
                'Header'  => 'GroupCard--header',
            ],
            'showChevron' => [
                'True'  => 'GroupCard--with-chevron',
                'False' => '',
            ],
        ],
        'defaultVariants' => [
            'mode'        => 'Default',
            'showChevron' => 'False',
        ],
    ], ['mode' => $mode, 'showChevron' => $showChevron]);

    if ($coverImageUrl) {
        $classes .= ' GroupCard--with-cover';
    } else {
        $classes .= ' GroupCard--without-cover';
    }

    $isHeaderMode = $mode === 'Header';

    // Format memberSince date
    $memberSinceFormatted = '';
    if ($memberSince) {
        $d = is_string($memberSince) ? new DateTime($memberSince) : $memberSince;
        $memberSinceFormatted = $d->format('F j, Y');
    }
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>
    @if($coverImageUrl)
        <img src="{{ $coverImageUrl }}" alt="{{ $name }}" class="GroupCard__cover-image" />
        <div class="GroupCard__gradient"></div>
    @endif

    <div class="GroupCard__top">
        @if($isHeaderMode)
            <button class="GroupCard__back-button" aria-label="Go back" @if($backHref) onclick="window.location.href='{{ $backHref }}'" @endif>
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <path d="M15 18L9 12L15 6" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
                </svg>
            </button>
        @else
            @if($alertText)
                <div class="GroupCard__alert">{{ $alertText }}</div>
            @endif
        @endif
    </div>

    <div class="GroupCard__bottom">
        <h3 class="GroupCard__title">{{ $name }}</h3>
        @if($memberSinceFormatted)
            <p class="GroupCard__joined">
                <span class="GroupCard__joined-label">Member since </span>
                <span class="GroupCard__joined-date">{{ $memberSinceFormatted }}</span>
            </p>
        @endif
        <div class="GroupCard__details">
            <div class="GroupCard__detail">
                @if($isPrivate)
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <rect x="3" y="11" width="18" height="11" rx="2" stroke="white" stroke-width="2" />
                        <path d="M7 11V7C7 4.23858 9.23858 2 12 2C14.7614 2 17 4.23858 17 7V11" stroke="white" stroke-width="2" stroke-linecap="round" />
                    </svg>
                @else
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <rect x="3" y="11" width="18" height="11" rx="2" stroke="white" stroke-width="2" />
                        <path d="M7 11V7C7 4.23858 9.23858 2 12 2C14.0503 2 15.8124 3.2341 16.584 5" stroke="white" stroke-width="2" stroke-linecap="round" />
                    </svg>
                @endif
                <span>{{ $isPrivate ? 'Private group' : 'Public group' }}</span>
            </div>
            <div class="GroupCard__detail">
                <span class="GroupCard__member-count">{{ $memberCount }}</span>
                <span>members</span>
            </div>
        </div>
    </div>

    @if($showChevron === 'True')
        <div class="GroupCard__chevron">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M9 18L15 12L9 6" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
            </svg>
        </div>
    @endif
</div>
