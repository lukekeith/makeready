@props([
    'layout'      => 'Default',
    'interactive' => 'False',
    'name'        => '',
    'ownerName'   => null,
    'memberCount' => 0,
    'groupCount'  => 0,
    'createdAt'   => null,
])

@php
    $classes = cva('OrganizationCard', [
        'variants' => [
            'layout' => [
                'Compact'  => 'OrganizationCard--layout-compact',
                'Default'  => 'OrganizationCard--layout-default',
                'Detailed' => 'OrganizationCard--layout-detailed',
            ],
            'interactive' => [
                'True'  => 'OrganizationCard--interactive',
                'False' => '',
            ],
        ],
        'defaultVariants' => [
            'layout'      => 'Default',
            'interactive' => 'False',
        ],
    ], ['layout' => $layout, 'interactive' => $interactive]);
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>
    <div class="OrganizationCard__header">
        <h3 class="OrganizationCard__name">{{ $name }}</h3>
        @if($ownerName)
            <p class="OrganizationCard__owner">Owner: {{ $ownerName }}</p>
        @endif
    </div>

    <div class="OrganizationCard__stats">
        <div class="OrganizationCard__stat">
            <span class="OrganizationCard__stat-value">{{ $memberCount }}</span>
            <span class="OrganizationCard__stat-label">{{ $memberCount === 1 ? 'Member' : 'Members' }}</span>
        </div>
        <div class="OrganizationCard__stat-divider"></div>
        <div class="OrganizationCard__stat">
            <span class="OrganizationCard__stat-value">{{ $groupCount }}</span>
            <span class="OrganizationCard__stat-label">{{ $groupCount === 1 ? 'Group' : 'Groups' }}</span>
        </div>
    </div>

    @if($layout === 'Detailed' && $createdAt)
        <div class="OrganizationCard__details">
            <div class="OrganizationCard__detail">
                <span class="OrganizationCard__detail-label">Created:</span>
                <span class="OrganizationCard__detail-value">{{ $createdAt }}</span>
            </div>
        </div>
    @endif
</div>
