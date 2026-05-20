@props([
    'size'        => 'Default',
    'layout'      => 'Vertical',
    'avatarUrl'   => null,
    'name'        => '',
    'createdYear' => null,
])

@php
    $classes = cva('GroupLeaderInfo', [
        'variants' => [
            'size' => [
                'Default' => 'GroupLeaderInfo--size-default',
                'Compact' => 'GroupLeaderInfo--size-compact',
            ],
            'layout' => [
                'Vertical'   => 'GroupLeaderInfo--vertical',
                'Horizontal' => 'GroupLeaderInfo--horizontal',
            ],
        ],
        'defaultVariants' => [
            'size'   => 'Default',
            'layout' => 'Vertical',
        ],
    ], ['size' => $size, 'layout' => $layout]);

    // Compute initials
    $parts    = explode(' ', trim($name));
    $initials = '';
    if (count($parts) === 1) {
        $initials = strtoupper(substr($parts[0], 0, 1));
    } else {
        $initials = strtoupper(substr($parts[0], 0, 1) . substr(end($parts), 0, 1));
    }
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>
    <p class="GroupLeaderInfo__label">Group leader information</p>
    <div class="GroupLeaderInfo__content">
        <div class="GroupLeaderInfo__avatar">
            @if($avatarUrl)
                <img src="{{ $avatarUrl }}" alt="{{ $name }}" class="GroupLeaderInfo__avatar-image" />
            @else
                <span class="GroupLeaderInfo__avatar-initials">{{ $initials }}</span>
            @endif
        </div>
        <div class="GroupLeaderInfo__details">
            <h3 class="GroupLeaderInfo__name">{{ $name }}</h3>
            @if($createdYear)
                <p class="GroupLeaderInfo__date">Started group in {{ $createdYear }}</p>
            @endif
        </div>
    </div>
</div>
