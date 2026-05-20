@props([
    'buttonLayout' => 'Horizontal',
    'photoUrl'     => '',
    'groupName'    => '',
    'isPrivate'    => false,
    'memberCount'  => 0,
])

@php
    $classes = cva('GroupInfoCard', [
        'variants' => [
            'buttonLayout' => [
                'Horizontal' => 'GroupInfoCard--button-layout-horizontal',
                'Vertical'   => 'GroupInfoCard--button-layout-vertical',
            ],
        ],
        'defaultVariants' => ['buttonLayout' => 'Horizontal'],
    ], ['buttonLayout' => $buttonLayout]);
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>
    <div class="GroupInfoCard__photo">
        <img src="{{ $photoUrl }}" alt="{{ $groupName }}" class="GroupInfoCard__photo-image" />
        <div class="GroupInfoCard__gradient">
            <div class="GroupInfoCard__details">
                <h2 class="GroupInfoCard__name">{{ $groupName }}</h2>
                <div class="GroupInfoCard__meta">
                    @if($isPrivate)
                        <div class="GroupInfoCard__private">
                            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                                <rect x="3" y="11" width="18" height="11" rx="2" ry="2" stroke="currentColor" stroke-width="2"/>
                                <path d="M7 11V7a5 5 0 0 1 10 0v4" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
                            </svg>
                            <span>Private group</span>
                        </div>
                    @endif
                    <div class="GroupInfoCard__members">
                        <span class="GroupInfoCard__members-count">{{ $memberCount }}</span>
                        <span class="GroupInfoCard__members-label">members</span>
                    </div>
                </div>
            </div>
        </div>
    </div>

    @isset($default)
        <div class="GroupInfoCard__actions">{{ $default }}</div>
    @endisset
    @if(!isset($default) && $slot->isNotEmpty())
        <div class="GroupInfoCard__actions">{{ $slot }}</div>
    @endif
</div>
