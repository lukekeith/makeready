@props([
    'mode'          => 'Invite',
    'leaderName'    => null,
    'leaderAvatarUrl' => null,
    'recipientName' => null,
    'messageSuffix' => 'to join a private group.',
    'groupName'     => null,
    'memberSince'   => null,
])

@php
    $classes = cva('GroupLeaderNote', [
        'variants' => [
            'variant' => [
                'Default' => 'GroupLeaderNote--default',
            ],
            'mode' => [
                'Invite' => 'GroupLeaderNote--invite',
                'Member' => 'GroupLeaderNote--member',
            ],
        ],
        'defaultVariants' => [
            'variant' => 'Default',
            'mode'    => 'Invite',
        ],
    ], ['variant' => 'Default', 'mode' => $mode]);

    $isMemberMode = $mode === 'Member';

    // Compute initials
    $nameForInitials = $isMemberMode ? $recipientName : $leaderName;
    $initials = '';
    if ($nameForInitials) {
        $parts    = explode(' ', trim($nameForInitials));
        $initials = strtoupper(implode('', array_map(fn($p) => substr($p, 0, 1), $parts)));
        $initials = substr($initials, 0, 2);
    }
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>
    @if(!$isMemberMode)
        <x-primitive.avatar
            :src="$leaderAvatarUrl"
            :alt="$leaderName ?? ''"
            :fallback="$initials"
            :size="80"
            class="GroupLeaderNote__avatar"
        />
    @endif
    <div class="GroupLeaderNote__content">
        @if($recipientName)
            <p class="GroupLeaderNote__recipient">{{ $recipientName }},</p>
        @endif
        @if($isMemberMode)
            <p class="GroupLeaderNote__text">
                You have been a member of <strong>{{ $groupName }}</strong> since {{ $memberSince }}.
            </p>
        @else
            <p class="GroupLeaderNote__text">
                You have been invited by <strong>{{ $leaderName }}</strong> {{ $messageSuffix }}
            </p>
        @endif
    </div>
</div>
