<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <link rel="icon" type="image/svg+xml" href="/logo-mark.svg">
    <title>@yield('title', 'MakeReady')</title>
    <meta name="description" content="@yield('description', 'MakeReady is an invite-only experience for personal growth through human connection, accountability, and study.')">
    <meta property="og:type" content="website">
    <meta property="og:title" content="@yield('og_title', trim($__env->yieldContent('title', 'MakeReady')))">
    <meta property="og:description" content="@yield('og_description', trim($__env->yieldContent('description', 'Personal growth through human connection, accountability, and study.')))">
    <meta property="og:image" content="@yield('og_image', url('/social-share.png'))">
    <meta property="og:url" content="{{ url()->current() }}">
    <meta property="og:site_name" content="MakeReady">
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="@yield('og_title', trim($__env->yieldContent('title', 'MakeReady')))">
    <meta name="twitter:description" content="@yield('og_description', trim($__env->yieldContent('description', 'Personal growth through human connection, accountability, and study.')))">
    <meta name="twitter:image" content="@yield('og_image', url('/social-share.png'))">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:ital,opsz,wght@0,14..32,100..900;1,14..32,100..900&display=swap" rel="stylesheet">
    @vite(['resources/css/app.scss', 'resources/js/app.js'])
</head>
<body class="MarketingBody">
    <header class="MarketingNav" id="marketing-nav">
        <div class="MarketingNav__bar">
            <a class="MarketingNav__brand" href="/" aria-label="MakeReady home">
                <img src="/logo-mark.svg" alt="" width="28" height="28">
                <span>MakeReady</span>
            </a>

            {{-- Desktop links --}}
            <nav class="MarketingNav__links" aria-label="Primary navigation">
                <a href="/" @class(['is-active' => request()->is('/')])>Home</a>
                <a href="/for-leaders" @class(['is-active' => request()->is('for-leaders')])>For Leaders</a>
                <a href="/for-members" @class(['is-active' => request()->is('for-members')])>For Members</a>
                <a href="/about" @class(['is-active' => request()->is('about')])>About</a>
            </nav>

            {{-- Desktop actions --}}
            <div class="MarketingNav__actions">
                <div class="MarketingNav__dropdown" id="join-dropdown">
                    <button
                        class="MarketingNav__action MarketingNav__action--secondary MarketingNav__action--join"
                        aria-haspopup="true"
                        aria-expanded="false"
                        id="join-trigger"
                    >
                        Join
                        <svg class="MarketingNav__chevron" width="12" height="12" viewBox="0 0 12 12" fill="none" aria-hidden="true">
                            <path d="M2 4L6 8L10 4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
                        </svg>
                    </button>
                    <ul class="MarketingNav__dropdown-menu" role="list" aria-labelledby="join-trigger">
                        <li>
                            <a href="{{ url('/join/group') }}" class="MarketingNav__dropdown-item">
                                <svg class="MarketingNav__dropdown-icon" width="16" height="16" viewBox="0 0 16 16" fill="none" aria-hidden="true">
                                    <path d="M10.5 7a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5Z" fill="currentColor" opacity=".4"/>
                                    <path d="M5.5 8a3 3 0 1 0 0-6 3 3 0 0 0 0 6Zm5.75 1c1.8 0 3.25 1.12 3.25 2.5v.5H12v-.5c0-.82-.56-1.55-1.38-2.03.19-.03.38-.47.63-.47ZM5.5 9C3.01 9 1 10.34 1 12v1h9v-1c0-1.66-2.01-3-4.5-3Z" fill="currentColor"/>
                                </svg>
                                Join a Group
                            </a>
                        </li>
                        <li>
                            <a href="{{ url('/join/event') }}" class="MarketingNav__dropdown-item">
                                <svg class="MarketingNav__dropdown-icon" width="16" height="16" viewBox="0 0 16 16" fill="none" aria-hidden="true">
                                    <rect x="1.5" y="3.5" width="13" height="11" rx="2" stroke="currentColor" stroke-width="1.25"/>
                                    <path d="M1.5 6.5h13" stroke="currentColor" stroke-width="1.25"/>
                                    <path d="M5 2v3M11 2v3" stroke="currentColor" stroke-width="1.25" stroke-linecap="round"/>
                                    <rect x="4.5" y="8.5" width="2" height="2" rx=".5" fill="currentColor"/>
                                    <rect x="7.5" y="8.5" width="2" height="2" rx=".5" fill="currentColor"/>
                                    <rect x="10.5" y="8.5" width="2" height="2" rx=".5" fill="currentColor" opacity=".4"/>
                                    <rect x="4.5" y="11" width="2" height="2" rx=".5" fill="currentColor" opacity=".4"/>
                                    <rect x="7.5" y="11" width="2" height="2" rx=".5" fill="currentColor" opacity=".4"/>
                                </svg>
                                Join an Event
                            </a>
                        </li>
                        <li>
                            <a href="{{ url('/join/study') }}" class="MarketingNav__dropdown-item">
                                <svg class="MarketingNav__dropdown-icon" width="16" height="16" viewBox="0 0 16 16" fill="none" aria-hidden="true">
                                    <path d="M2 3.5C2 2.67 2.67 2 3.5 2h7C11.33 2 12 2.67 12 3.5V13l-4-2-4 2V3.5Z" stroke="currentColor" stroke-width="1.25" stroke-linejoin="round"/>
                                    <path d="M12 4h.5C13.33 4 14 4.67 14 5.5V13l-2-1" stroke="currentColor" stroke-width="1.25" stroke-linecap="round" stroke-linejoin="round" opacity=".45"/>
                                    <path d="M5 5.5h4M5 8h3" stroke="currentColor" stroke-width="1.25" stroke-linecap="round" opacity=".5"/>
                                </svg>
                                Join a Study
                            </a>
                        </li>
                    </ul>
                </div>

                <a href="{{ url('/login') }}" class="MarketingNav__action MarketingNav__action--primary">Member Access</a>
            </div>

            {{-- Mobile trigger --}}
            <button class="MarketingNav__trigger" id="marketing-nav-trigger" aria-label="Menu" aria-expanded="false">
                <span class="MarketingNav__icon" aria-hidden="true">
                    <span class="MarketingNav__line MarketingNav__line--top"></span>
                    <span class="MarketingNav__line MarketingNav__line--bottom"></span>
                </span>
            </button>
        </div>

        {{-- Mobile menu --}}
        <div class="MarketingNav__menu" id="marketing-nav-menu" role="dialog" aria-label="Navigation menu">
            <div class="MarketingNav__mobile-links">
                <a href="/" class="MarketingNav__mobile-link">Home</a>
                <a href="/for-leaders" class="MarketingNav__mobile-link">For Leaders</a>
                <a href="/for-members" class="MarketingNav__mobile-link">For Members</a>
                <a href="/about" class="MarketingNav__mobile-link">About</a>
                <a href="{{ url('/login') }}" class="MarketingNav__mobile-link">Member Access</a>
                <a href="{{ url('/join/group') }}" class="MarketingNav__mobile-link">Join a Group</a>
                <a href="{{ url('/join/event') }}" class="MarketingNav__mobile-link">Join an Event</a>
                <a href="{{ url('/join/study') }}" class="MarketingNav__mobile-link">Join a Study</a>
            </div>
            <div class="MarketingNav__legal">
                <span class="MarketingNav__legal-label">Legal</span>
                <a href="/privacy" class="MarketingNav__legal-link">Privacy Policy</a>
                <a href="/terms" class="MarketingNav__legal-link">Terms &amp; Conditions</a>
                <a href="/sms-terms" class="MarketingNav__legal-link">SMS Terms</a>
            </div>
        </div>
    </header>

    <script>
    (function() {
        var trigger = document.getElementById('marketing-nav-trigger');
        var nav = document.getElementById('marketing-nav');
        var isOpen = false;

        function closeMenu() {
            isOpen = false;
            trigger.setAttribute('aria-expanded', 'false');
            nav.classList.remove('MarketingNav--open');
            document.body.style.overflow = '';
        }

        trigger.addEventListener('click', function() {
            isOpen = !isOpen;
            trigger.setAttribute('aria-expanded', String(isOpen));
            if (isOpen) {
                nav.classList.add('MarketingNav--open');
                document.body.style.overflow = 'hidden';
            } else {
                closeMenu();
            }
        });

        // Join dropdown
        var joinTrigger = document.getElementById('join-trigger');
        var joinDropdown = document.getElementById('join-dropdown');

        if (joinTrigger && joinDropdown) {
            joinTrigger.addEventListener('click', function() {
                var expanded = joinTrigger.getAttribute('aria-expanded') === 'true';
                joinTrigger.setAttribute('aria-expanded', String(!expanded));
                joinDropdown.classList.toggle('MarketingNav__dropdown--open', !expanded);
            });

            document.addEventListener('click', function(e) {
                if (!joinDropdown.contains(e.target)) {
                    joinTrigger.setAttribute('aria-expanded', 'false');
                    joinDropdown.classList.remove('MarketingNav__dropdown--open');
                }
            });
        }

        document.addEventListener('keydown', function(e) {
            if (e.key === 'Escape') {
                closeMenu();
                if (joinTrigger) {
                    joinTrigger.setAttribute('aria-expanded', 'false');
                    joinDropdown.classList.remove('MarketingNav__dropdown--open');
                }
            }
        });
    })();
    </script>

    @if(session('error'))
        <div class="MarketingAlert" role="alert">{{ session('error') }}</div>
    @endif

    @yield('content')

    <footer class="MarketingFooter">
        <div>
            <strong>MakeReady</strong>
            <p>Personal growth through human connection, accountability, and study.</p>
        </div>
        <nav aria-label="Footer navigation">
            <a href="/contact">Contact</a>
            <a href="/privacy">Privacy</a>
            <a href="/terms">Terms</a>
            <a href="/sms-terms">SMS Terms</a>
        </nav>
    </footer>
    <div data-vue="ModalProvider"></div>
</body>
</html>
