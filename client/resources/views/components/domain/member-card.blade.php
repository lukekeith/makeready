@props([
    'layout'      => 'Default',
    'interactive' => 'False',
    'avatar'      => null,
    'firstName'   => null,
    'lastName'    => null,
    'phoneNumber' => '',
    'email'       => null,
    'role'        => 'member',
    'isActive'    => true,
    'joinedAt'    => null,
])

@php
    $classes = cva('MemberCard', [
        'variants' => [
            'layout' => [
                'Compact'  => 'MemberCard--layout-compact',
                'Default'  => 'MemberCard--layout-default',
                'Detailed' => 'MemberCard--layout-detailed',
            ],
            'interactive' => [
                'True'  => 'MemberCard--interactive',
                'False' => '',
            ],
        ],
        'defaultVariants' => [
            'layout'      => 'Default',
            'interactive' => 'False',
        ],
    ], ['layout' => $layout, 'interactive' => $interactive]);

    $parts    = array_filter([$firstName, $lastName]);
    $fullName = count($parts) ? implode(' ', $parts) : 'Unknown Member';
    $initials = strtoupper(
        implode('', array_filter([
            $firstName ? substr($firstName, 0, 1) : null,
            $lastName  ? substr($lastName, 0, 1)  : null,
        ]))
    ) ?: '?';
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>
    <div class="MemberCard__avatar">
        @if($avatar)
            <img src="{{ $avatar }}" alt="{{ $fullName }}" class="MemberCard__avatar-image" />
        @else
            <div class="MemberCard__avatar-fallback">{{ $initials }}</div>
        @endif
    </div>

    <div class="MemberCard__content">
        <div class="MemberCard__header">
            <h4 class="MemberCard__name">{{ $fullName }}</h4>
            <div class="MemberCard__badges">
                <span class="MemberCard__role MemberCard__role--{{ $role }}">
                    {{ $role === 'leader' ? 'Leader' : 'Member' }}
                </span>
                @if(!$isActive)
                    <span class="MemberCard__status MemberCard__status--inactive">Inactive</span>
                @endif
            </div>
        </div>

        <div class="MemberCard__details">
            <div class="MemberCard__detail">
                <span class="MemberCard__detail-label">Phone:</span>
                <span class="MemberCard__detail-value">{{ $phoneNumber }}</span>
            </div>
            @if($email && $layout !== 'Compact')
                <div class="MemberCard__detail">
                    <span class="MemberCard__detail-label">Email:</span>
                    <span class="MemberCard__detail-value">{{ $email }}</span>
                </div>
            @endif
            @if($joinedAt && $layout === 'Detailed')
                <div class="MemberCard__detail">
                    <span class="MemberCard__detail-label">Joined:</span>
                    <span class="MemberCard__detail-value">{{ $joinedAt }}</span>
                </div>
            @endif
        </div>
    </div>
</div>
