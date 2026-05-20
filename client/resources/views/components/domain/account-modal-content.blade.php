@props([
    'view'                  => 'main',
    'isLoading'             => false,
    'loadError'             => null,
    'memberAccountLinkProps' => null,
    'googleAccountLinkProps' => null,
    'formattedNewPhone'     => null,
    'flowError'             => null,
    'resendTimer'           => null,
])

@if($isLoading)
    <div class="AccountModalContent AccountModalContent--loading">
        <x-primitive.loading variant="Bars" color="White" size="Lg" />
    </div>
@elseif($loadError)
    <div class="AccountModalContent AccountModalContent--error">
        <p class="AccountModalContent__error-text">{{ $loadError }}</p>
    </div>
@else
    <div {{ $attributes->merge(['class' => 'AccountModalContent']) }}>
        <div class="AccountModalContent__header">
            <div style="width: 32px;"></div>
            <h2 class="AccountModalContent__header-title">Account</h2>
            <div style="width: 32px;"></div>
        </div>

        @if($view === 'main')
            <div class="AccountModalContent__main">
                <div class="AccountModalContent__links">
                    @if($memberAccountLinkProps)
                        <x-domain.account-link
                            :state="$memberAccountLinkProps['state'] ?? 'LinkMember'"
                            :phone-number="$memberAccountLinkProps['phoneNumber'] ?? null"
                            :avatar-url="$memberAccountLinkProps['avatarUrl'] ?? null"
                            :name="$memberAccountLinkProps['name'] ?? null"
                        />
                    @endif
                    @if($googleAccountLinkProps)
                        <x-domain.account-link
                            :state="$googleAccountLinkProps['state'] ?? 'LinkGoogle'"
                            :avatar-url="$googleAccountLinkProps['avatarUrl'] ?? null"
                            :name="$googleAccountLinkProps['name'] ?? null"
                            :email="$googleAccountLinkProps['email'] ?? null"
                        />
                    @endif
                </div>
            </div>
        @endif

        @if($view === 'success')
            <div class="AccountModalContent__success">
                <div class="AccountModalContent__success-icon">
                    <svg width="64" height="64" viewBox="0 0 24 24" fill="none">
                        <path d="M20 6L9 17L4 12" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                    </svg>
                </div>
                <h1 class="AccountModalContent__success-title">Phone updated</h1>
                <p class="AccountModalContent__success-subtitle">Your phone number has been updated successfully.</p>
            </div>
        @endif
    </div>
@endif
