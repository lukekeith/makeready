@props([
    'layout'         => 'Centered',
    'title'          => 'Create an account',
    'description'    => 'Enter your email below to create your account',
    'showTerms'      => true,
    'termsUrl'       => '/terms',
    'privacyUrl'     => '/privacy',
    'showBranding'   => false,
    'brandingQuote'  => 'Preparing men for the future, to become leaders in their families and communities.',
    'brandingAuthor' => 'Scott Stickane',
])

@php
    $classes = cva('AuthLayout', [
        'variants' => [
            'layout' => [
                'Centered' => '',
                'Split'    => 'AuthLayout--split',
                'Minimal'  => 'AuthLayout--minimal',
            ],
        ],
        'defaultVariants' => ['layout' => 'Centered'],
    ], ['layout' => $layout]);
@endphp

@if($layout === 'Split')
    <div {{ $attributes->merge(['class' => $classes]) }}>
        @if($showBranding)
            <div class="AuthLayout__branding">
                <div class="AuthLayout__branding-logo">MakeReady</div>
                <blockquote class="AuthLayout__branding-quote">
                    <p>{{ $brandingQuote }}</p>
                    <footer>{{ $brandingAuthor }}</footer>
                </blockquote>
            </div>
        @endif
        <div class="AuthLayout__panel">
            <div class="AuthLayout__inner">
                <div class="AuthLayout__header">
                    <h1 class="AuthLayout__title">{{ $title }}</h1>
                    <p class="AuthLayout__description">{{ $description }}</p>
                </div>
                <div class="AuthLayout__body">
                    @isset($emailForm){{ $emailForm }}@endisset
                    {{ $slot }}
                    @isset($socialButtons)
                        <div class="AuthLayout__social">{{ $socialButtons }}</div>
                    @endisset
                </div>
                @if($showTerms)
                    <p class="AuthLayout__terms">
                        By clicking continue, you agree to our
                        <a href="{{ $termsUrl }}">Terms of Service</a>
                        and
                        <a href="{{ $privacyUrl }}">Privacy Policy</a>.
                    </p>
                @endif
            </div>
        </div>
    </div>
@else
    <div {{ $attributes->merge(['class' => $classes]) }}>
        <div class="AuthLayout__inner">
            <div class="AuthLayout__header">
                <h1 class="AuthLayout__title">{{ $title }}</h1>
                <p class="AuthLayout__description">{{ $description }}</p>
            </div>
            <div class="AuthLayout__body">
                @isset($emailForm){{ $emailForm }}@endisset
                {{ $slot }}
                @isset($socialButtons)
                    <div class="AuthLayout__social">{{ $socialButtons }}</div>
                @endisset
            </div>
            @if($showTerms && $layout !== 'Minimal')
                <p class="AuthLayout__terms">
                    By clicking continue, you agree to our
                    <a href="{{ $termsUrl }}">Terms of Service</a>
                    and
                    <a href="{{ $privacyUrl }}">Privacy Policy</a>.
                </p>
            @endif
        </div>
    </div>
@endif
