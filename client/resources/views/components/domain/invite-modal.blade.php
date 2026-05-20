@props([
    'groupName'    => '',
    'qrCodeDataUrl' => null,
    'inviteLink'   => '',
    'isCopied'     => false,
])

@php
    $displayLink = strlen($inviteLink) > 40
        ? substr($inviteLink, 0, 37) . '...'
        : $inviteLink;
@endphp

<div {{ $attributes->merge(['class' => 'InviteModal']) }}>
    <div class="InviteModal__header">
        <h2 class="InviteModal__title">Invite to {{ $groupName }}</h2>
    </div>

    <div class="InviteModal__qr-container">
        @if($qrCodeDataUrl)
            <x-primitive.qr-code
                :data-url="$qrCodeDataUrl"
                size="Lg"
                :alt="'QR code to join ' . $groupName"
            />
        @else
            <div class="InviteModal__qr-loading">
                <span>Loading QR code...</span>
            </div>
        @endif
    </div>

    <div class="InviteModal__link-container">
        <span class="InviteModal__link-label">Invite Link</span>
        <span class="InviteModal__link-text">{{ $displayLink }}</span>
    </div>

    <x-primitive.button variant="Primary" mode="Block">
        {{ $isCopied ? 'Copied!' : 'Copy Link' }}
    </x-primitive.button>
</div>
