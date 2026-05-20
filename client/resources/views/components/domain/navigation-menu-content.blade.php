@props([
    'profileHref' => '/profile',
    'accountHref' => '/account',
    'termsHref'   => '/terms',
    'privacyHref' => '/privacy',
    'logoutHref'  => '/logout',
    'logoutMethod' => 'POST',
])

<div {{ $attributes->merge(['class' => 'NavigationMenuContent']) }}>
    <a href="{{ $profileHref }}" class="Button Button--secondary Button--mode-block Button--size-default">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
            <path d="M20 21V19C20 17.9391 19.5786 16.9217 18.8284 16.1716C18.0783 15.4214 17.0609 15 16 15H8C6.93913 15 5.92172 15.4214 5.17157 16.1716C4.42143 16.9217 4 17.9391 4 19V21" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            <circle cx="12" cy="7" r="4" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
        Profile
    </a>

    <a href="{{ $accountHref }}" class="Button Button--secondary Button--mode-block Button--size-default">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
            <path d="M10 13C10.4295 13.5741 10.9774 14.0492 11.6066 14.3929C12.2357 14.7367 12.9315 14.9411 13.6467 14.9923C14.3618 15.0435 15.0796 14.9403 15.7513 14.6897C16.4231 14.4392 17.0331 14.047 17.54 13.54L20.54 10.54C21.4508 9.59699 21.9548 8.33397 21.9434 7.02299C21.932 5.71201 21.4061 4.45794 20.4791 3.53093C19.5521 2.60391 18.298 2.07802 16.987 2.06663C15.676 2.05523 14.413 2.55921 13.47 3.46997L11.75 5.17997" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            <path d="M14 11C13.5705 10.4259 13.0226 9.95081 12.3934 9.60706C11.7642 9.26331 11.0684 9.05889 10.3533 9.00768C9.63816 8.95647 8.92037 9.05966 8.24861 9.31024C7.57685 9.56083 6.96684 9.9530 6.45996 10.46L3.45996 13.46C2.54917 14.403 2.04519 15.666 2.05659 16.977C2.06798 18.288 2.59387 19.5421 3.52089 20.4691C4.4479 21.3961 5.70197 21.922 7.01295 21.9334C8.32393 21.9448 9.58694 21.4408 10.53 20.53L12.24 18.82" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
        Account
    </a>

    <div class="NavigationMenuContent__legal">
        <a href="{{ $termsHref }}" class="Button Button--link-muted Button--size-default">Terms of use</a>
        <a href="{{ $privacyHref }}" class="Button Button--link-muted Button--size-default">Privacy policy</a>
    </div>

    <form method="POST" action="{{ $logoutHref }}">
        @csrf
        @method($logoutMethod)
        <button type="submit" class="Button Button--destructive Button--mode-block Button--size-default">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                <path d="M9 21H5C4.46957 21 3.96086 20.7893 3.58579 20.4142C3.21071 20.0391 3 19.5304 3 19V5C3 4.46957 3.21071 3.96086 3.58579 3.58579C3.96086 3.21071 4.46957 3 5 3H9" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                <polyline points="16,17 21,12 16,7" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                <line x1="21" y1="12" x2="9" y2="12" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
            Logout
        </button>
    </form>
</div>
