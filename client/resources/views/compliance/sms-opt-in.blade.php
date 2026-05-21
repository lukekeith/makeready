@extends('layouts.marketing')

@section('title', 'SMS Opt-In — MakeReady')
@section('og_title', 'SMS Opt-In — MakeReady')
@section('og_description', 'How MakeReady obtains SMS consent from group members.')

@section('content')
<main class="MarketingPage">
<div class="InfoPage">
    <div class="InfoPage__container">

        <header class="InfoPage__header">
            <h1 class="InfoPage__title">How We Obtain SMS Consent</h1>
            <p class="InfoPage__intro">
                MakeReady requires explicit, affirmative consent before sending any SMS messages
                to group members. Consent is collected on-site during the group join flow at
                <a class="InfoPage__link" href="https://app.makeready.org/join/group">app.makeready.org/join/group</a>.
                Below is a demonstration of the consent experience members see when joining a group, study, or event.
            </p>
            <p class="InfoPage__intro">
                The MakeReady SMS program uses a <strong>double-opt-in</strong> consent model:
                (1) the group leader obtains the recipient's verbal or written consent out-of-band
                <em>before</em> adding their phone number, and (2) the recipient confirms consent on-site
                via the unchecked checkbox shown below before any further messages are sent.
            </p>
        </header>

        <section class="InfoPage__section">
            <h2 class="InfoPage__subheading">Walkthrough — Join Group Flow</h2>
            <p class="InfoPage__text">
                Below are live screenshots of each step a member sees when joining a group at
                <code>app.makeready.org/join/group/{code}</code>. Swipe or scroll horizontally.
                The consent checkbox appears on <strong>Step 2 (SMS Consent)</strong> —
                it is never pre-checked and the Continue button remains disabled until the member
                checks the box.
            </p>

            @php
                $carousel = [
                    [
                        'src'     => 'screenshots/join-group/01-info.png',
                        'step'    => 1,
                        'title'   => 'Group Info',
                        'caption' => 'The member arrives via their leader\'s invite link and sees the group details.',
                        'alt'     => 'Step 1 — Group info screen showing who invited the member.',
                    ],
                    [
                        'src'     => 'screenshots/join-group/02-optin.png',
                        'step'    => 2,
                        'title'   => 'SMS Consent',
                        'caption' => 'Unchecked consent checkbox with exact Twilio copy and Privacy/Terms links. Continue is disabled until checked.',
                        'alt'     => 'Step 2 — SMS consent screen with unchecked checkbox, exact Twilio consent copy, Privacy/Terms links, and a disabled Continue button.',
                        'featured' => true,
                    ],
                    [
                        'src'     => 'screenshots/join-group/03-profile.png',
                        'step'    => 3,
                        'title'   => 'Profile',
                        'caption' => 'The member enters their name, gender, and birthday.',
                        'alt'     => 'Step 3 — Profile entry screen.',
                    ],
                    [
                        'src'     => 'screenshots/join-group/04-phone.png',
                        'step'    => 4,
                        'title'   => 'Phone Number',
                        'caption' => 'The member enters their phone number to receive the verification code.',
                        'alt'     => 'Step 4 — Phone entry screen.',
                    ],
                    [
                        'src'     => 'screenshots/join-group/05-verify.png',
                        'step'    => 5,
                        'title'   => 'Verification',
                        'caption' => 'The member receives a one-time SMS code and enters it to confirm ownership of the phone.',
                        'alt'     => 'Step 5 — Verification code entry screen.',
                    ],
                    [
                        'src'     => 'screenshots/join-group/06-confirmed.png',
                        'step'    => 6,
                        'title'   => 'Confirmed',
                        'caption' => 'The join request is submitted to the group leader for approval.',
                        'alt'     => 'Step 6 — Confirmation screen.',
                    ],
                ];
            @endphp

            <div class="InfoPage__carousel" data-carousel aria-label="MakeReady join-group flow screenshots">
                <button
                    type="button"
                    class="InfoPage__carousel-nav InfoPage__carousel-nav--prev"
                    data-carousel-prev
                    aria-label="Previous screenshot"
                >
                    <svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                        <polyline points="15 18 9 12 15 6" />
                    </svg>
                </button>
                <div class="InfoPage__carousel-track" data-carousel-track>
                    @foreach ($carousel as $shot)
                        <figure class="InfoPage__carousel-card @if($shot['featured'] ?? false) InfoPage__carousel-card--featured @endif">
                            <div class="InfoPage__carousel-phone">
                                <img
                                    src="{{ asset($shot['src']) }}"
                                    alt="{{ $shot['alt'] }}"
                                    class="InfoPage__carousel-image"
                                    loading="lazy"
                                />
                            </div>
                            <figcaption class="InfoPage__carousel-caption">
                                <span class="InfoPage__carousel-step">Step {{ $shot['step'] }}</span>
                                <span class="InfoPage__carousel-title">{{ $shot['title'] }}</span>
                                <span class="InfoPage__carousel-desc">{{ $shot['caption'] }}</span>
                            </figcaption>
                        </figure>
                    @endforeach
                </div>
                <button
                    type="button"
                    class="InfoPage__carousel-nav InfoPage__carousel-nav--next"
                    data-carousel-next
                    aria-label="Next screenshot"
                >
                    <svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                        <polyline points="9 18 15 12 9 6" />
                    </svg>
                </button>
                <p class="InfoPage__carousel-hint">← swipe to see each step →</p>
            </div>

            <script>
                (function () {
                    document.querySelectorAll('[data-carousel]').forEach(function (carousel) {
                        var track = carousel.querySelector('[data-carousel-track]');
                        var prev  = carousel.querySelector('[data-carousel-prev]');
                        var next  = carousel.querySelector('[data-carousel-next]');
                        if (!track || !prev || !next) return;

                        function step() {
                            var card = track.querySelector('.InfoPage__carousel-card');
                            if (!card) return track.clientWidth;
                            var style = window.getComputedStyle(track);
                            var gap = parseFloat(style.columnGap || style.gap || 0) || 0;
                            return card.getBoundingClientRect().width + gap;
                        }

                        function update() {
                            var atStart = track.scrollLeft <= 1;
                            var atEnd   = track.scrollLeft + track.clientWidth >= track.scrollWidth - 1;
                            prev.disabled = atStart;
                            next.disabled = atEnd;
                            prev.classList.toggle('is-hidden', atStart);
                            next.classList.toggle('is-hidden', atEnd);
                        }

                        prev.addEventListener('click', function () {
                            track.scrollBy({ left: -step(), behavior: 'smooth' });
                        });
                        next.addEventListener('click', function () {
                            track.scrollBy({ left: step(), behavior: 'smooth' });
                        });
                        track.addEventListener('scroll', update, { passive: true });
                        window.addEventListener('resize', update);
                        update();
                    });
                })();
            </script>
        </section>

        <section class="InfoPage__section">
            <h2 class="InfoPage__subheading">Exact Consent Language</h2>
            <p class="InfoPage__text">
                The consent checkbox on the SMS Consent step is <strong>never pre-checked</strong>,
                and the <strong>Continue button stays disabled until the box is checked</strong>.
                If the member bypasses the JavaScript gate, the server also rejects the submission
                and returns the member to this step with the error message:
                <em>"Please agree to receive SMS messages to continue."</em>
            </p>
            <div class="InfoPage__demo" aria-label="Exact consent copy shown to members">
                <div class="InfoPage__demo-frame">
                    <div class="InfoPage__demo-content">
                        <label class="InfoPage__checkbox-label">
                            <input
                                type="checkbox"
                                class="InfoPage__checkbox"
                                disabled
                                aria-label="SMS consent checkbox (demo — not interactive)"
                            >
                            <span class="InfoPage__checkbox-text">
                                I agree to receive text messages from MakeReady for group-related
                                events and daily studies. Msg &amp; data rates may apply.
                                Reply <strong>STOP</strong> to opt out.
                                <br>
                                <a class="InfoPage__link" href="{{ route('privacy') }}">Privacy Policy</a>
                                |
                                <a class="InfoPage__link" href="{{ route('terms') }}">Terms</a>
                            </span>
                        </label>
                    </div>
                    <p class="InfoPage__demo-note">
                        ☝ This checkbox is a non-interactive replica of the one shown in the carousel above.
                    </p>
                </div>
            </div>
        </section>

        <section class="InfoPage__section">
            <h2 class="InfoPage__subheading">Where Consent Is Collected</h2>
            <p class="InfoPage__text">
                The same SMS consent checkbox appears on all join flows:
            </p>
            <ul class="InfoPage__list">
                <li class="InfoPage__list-item">
                    <strong>Join Group:</strong>
                    <a class="InfoPage__link" href="https://app.makeready.org/join/group">app.makeready.org/join/group</a>
                </li>
                <li class="InfoPage__list-item">
                    <strong>Join Study:</strong>
                    <a class="InfoPage__link" href="https://app.makeready.org/join/study">app.makeready.org/join/study</a>
                </li>
                <li class="InfoPage__list-item">
                    <strong>Join Event:</strong>
                    <a class="InfoPage__link" href="https://app.makeready.org/join/event">app.makeready.org/join/event</a>
                </li>
            </ul>
            <p class="InfoPage__text">
                The login flow (<a class="InfoPage__link" href="https://app.makeready.org/login">app.makeready.org/login</a>)
                does <strong>not</strong> display the SMS consent checkbox because login is for existing members
                who have already given consent during the join process.
            </p>
        </section>

        <section class="InfoPage__section">
            <h2 class="InfoPage__subheading">What Members Agree To</h2>
            <p class="InfoPage__text">
                When a member checks the consent checkbox and joins a group, they agree to:
            </p>
            <ul class="InfoPage__list">
                <li class="InfoPage__list-item">Receive SMS notifications from their group leader via MakeReady</li>
                <li class="InfoPage__list-item">Messages related to group events, daily studies, and group activity</li>
                <li class="InfoPage__list-item">That message and data rates may apply</li>
                <li class="InfoPage__list-item">
                    MakeReady does <strong>not</strong> share mobile phone numbers or opt-in
                    information with third parties or affiliates for marketing or promotional purposes.
                </li>
            </ul>
            <p class="InfoPage__text">
                Message frequency varies based on group activity and leader communications.
            </p>
        </section>

        <section class="InfoPage__section">
            <h2 class="InfoPage__subheading">Sample Messages</h2>
            <p class="InfoPage__text">
                Below is a representative example of the SMS message recipients receive
                from MakeReady. The brand name, opt-out keyword, help keyword, and
                rate-disclosure footer are present in every message.
            </p>
            <div class="InfoPage__demo" aria-label="Sample SMS — group invite">
                <div class="InfoPage__demo-frame">
                    <p class="InfoPage__text" style="margin: 0;">
                        <strong>Group invite (sent by a group leader):</strong>
                    </p>
                    <p class="InfoPage__text" style="margin-top: 0.5rem;">
                        <em>"Luke invited you to join &ldquo;Young Professionals&rdquo; on MakeReady!
                        Tap here to join: https://app.makeready.org/join/group/NNNM76.
                        Msg &amp; data rates may apply. Reply <strong>STOP</strong> to opt out,
                        <strong>HELP</strong> for help."</em>
                    </p>
                </div>
            </div>
            <p class="InfoPage__text">
                The recipient has given the group leader prior verbal or written consent
                before this message is sent. Tapping the join link delivers them to the
                on-site opt-in flow shown above, where they confirm consent on the website
                before any further communication.
            </p>
        </section>

        <section class="InfoPage__section">
            <h2 class="InfoPage__subheading">Consent Recording</h2>
            <p class="InfoPage__text">
                Consent is validated both client-side and server-side. When a member checks the
                consent checkbox and submits the form, the server records:
            </p>
            <ul class="InfoPage__list">
                <li class="InfoPage__list-item">The <code>smsConsent</code> boolean (must be <code>true</code>)</li>
                <li class="InfoPage__list-item">A <code>smsConsentAt</code> timestamp of when consent was given</li>
                <li class="InfoPage__list-item">The phone number associated with the consent</li>
            </ul>
            <p class="InfoPage__text">
                If the <code>smsConsent</code> value is not <code>true</code>, the server rejects
                the request and returns an error.
            </p>
        </section>

        <section class="InfoPage__section">
            <h2 class="InfoPage__subheading">How to Opt Out</h2>
            <p class="InfoPage__text">
                Members can opt out at any time by replying <strong>STOP</strong> to any message.
                They can also get help by replying <strong>HELP</strong> or contacting us at
                <a class="InfoPage__link" href="mailto:support@makeready.org">support@makeready.org</a>.
            </p>
        </section>

        <section class="InfoPage__section">
            <h2 class="InfoPage__subheading">More Information</h2>
            <p class="InfoPage__text">
                For complete details on how we handle your data and the terms of our SMS program,
                please review:
            </p>
            <ul class="InfoPage__list">
                <li class="InfoPage__list-item">
                    <a class="InfoPage__link" href="{{ route('privacy') }}">Privacy Policy</a>
                    — how we collect and protect your information
                </li>
                <li class="InfoPage__list-item">
                    <a class="InfoPage__link" href="{{ route('terms') }}">Terms of Service</a>
                    — full terms of the MakeReady SMS messaging program
                </li>
            </ul>
        </section>

    </div>
</div>
</main>
@endsection
