{{-- Site navbar — fixed top bar with logo + animated hamburger menu --}}
<nav class="SiteNavbar" id="site-navbar">
    <div class="SiteNavbar__bar">
        <a href="/" class="SiteNavbar__logo" id="navbar-logo">
            <img src="/logo-mark.svg" alt="MakeReady" width="24" height="24" />
        </a>
        <button class="SiteNavbar__trigger" id="navbar-trigger" aria-label="Menu" aria-expanded="false">
            <span class="SiteNavbar__icon">
                <span class="SiteNavbar__line SiteNavbar__line--top"></span>
                <span class="SiteNavbar__line SiteNavbar__line--bottom"></span>
            </span>
        </button>
    </div>
    <div class="SiteNavbar__menu" id="navbar-menu">
        <div class="SiteNavbar__links">
            <a href="/" class="SiteNavbar__link">Home</a>
            <a href="/for-leaders" class="SiteNavbar__link">For Leaders</a>
            <a href="/for-members" class="SiteNavbar__link">For Members</a>
            <a href="/about" class="SiteNavbar__link">About</a>
            <a href="/join-beta" class="SiteNavbar__link">Join the beta</a>
            <a href="/login" class="SiteNavbar__link">Member Login</a>
            <a href="/contact" class="SiteNavbar__link">Contact</a>
        </div>
        <div class="SiteNavbar__legal">
            <span class="SiteNavbar__legal-label">Legal</span>
            <a href="/privacy" class="SiteNavbar__legal-link">Privacy Policy</a>
            <a href="/terms" class="SiteNavbar__legal-link">Terms & Conditions</a>
            <a href="/sms-terms" class="SiteNavbar__legal-link">SMS Terms</a>
        </div>
    </div>
</nav>

<script>
(function() {
    var trigger = document.getElementById('navbar-trigger');
    var navbar = document.getElementById('site-navbar');
    var isOpen = false;

    function close() {
        isOpen = false;
        trigger.setAttribute('aria-expanded', false);
        navbar.classList.remove('SiteNavbar--open');
        document.body.style.overflow = '';
    }

    trigger.addEventListener('click', function() {
        isOpen = !isOpen;
        trigger.setAttribute('aria-expanded', isOpen);
        if (isOpen) {
            navbar.classList.add('SiteNavbar--open');
            document.body.style.overflow = 'hidden';
        } else {
            close();
        }
    });

    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape' && isOpen) {
            close();
        }
    });
})();
</script>
