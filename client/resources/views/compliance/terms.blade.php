@extends('layouts.marketing')

@section('title', 'Terms of Service — MakeReady')
@section('og_title', 'Terms of Service — MakeReady')
@section('og_description', 'Terms and conditions for using the MakeReady platform, including SMS messaging terms.')

@section('content')
<main class="MarketingPage">
<div class="InfoPage">
    <div class="InfoPage__container">
        <div class="InfoPage__content">
            <h1 class="InfoPage__title">Terms of Service</h1>
            <p class="InfoPage__updated">Last updated: February 4, 2026</p>

            <section class="InfoPage__section">
                <h2 class="InfoPage__heading">1. Acceptance of Terms</h2>
                <p class="InfoPage__text">
                    By accessing or using MakeReady ("the Service"), you agree to be bound by these
                    Terms of Service ("Terms"). If you do not agree to these Terms, do not use the
                    Service. These Terms constitute a legally binding agreement between you and
                    MakeReady.
                </p>
            </section>

            <section class="InfoPage__section">
                <h2 class="InfoPage__heading">2. Eligibility</h2>
                <p class="InfoPage__text">
                    You must be at least 13 years of age to use the Service. If you are between 13 and
                    18 years of age, you may only use the Service with the consent and supervision of a
                    parent or legal guardian who agrees to be bound by these Terms. By using the
                    Service, you represent and warrant that you meet these eligibility requirements.
                </p>
            </section>

            <section class="InfoPage__section">
                <h2 class="InfoPage__heading">3. Description of Service</h2>
                <p class="InfoPage__text">
                    MakeReady is a group management platform that enables leaders to organize groups,
                    schedule activities, and communicate with members. The Service includes web and
                    mobile applications and SMS-based notifications. We reserve the right to modify,
                    suspend, or discontinue any part of the Service at any time, with or without notice.
                </p>
            </section>

            <section class="InfoPage__section">
                <h2 class="InfoPage__heading">4. Account Registration and Security</h2>
                <p class="InfoPage__text">
                    To use the Service, you must create an account by providing your phone number and
                    verifying it via SMS. You are responsible for maintaining the security of your
                    account and for all activities that occur under your account. You agree to
                    immediately notify us of any unauthorized use of your account.
                </p>
            </section>

            <section class="InfoPage__section">
                <h2 class="InfoPage__heading">5. SMS Messaging Terms</h2>
                <p class="InfoPage__text">
                    By opting in to SMS notifications during the join process, you agree to the
                    following:
                </p>
                <ul class="InfoPage__list">
                    <li>
                        <strong>Message frequency:</strong> Message frequency varies based on your group
                        activity and leader communications.
                    </li>
                    <li>
                        <strong>Costs:</strong> Message and data rates may apply. Check with your carrier
                        for details.
                    </li>
                    <li>
                        <strong>Opt-out:</strong> You can opt out at any time by replying <strong>STOP</strong> to any SMS
                        message from MakeReady. You will receive a confirmation message and no further
                        messages will be sent.
                    </li>
                    <li>
                        <strong>Help:</strong> Reply <strong>HELP</strong> to any SMS message for assistance, or contact us
                        at
                        <a href="mailto:support@makeready.org" class="InfoPage__link">support@makeready.org</a>.
                    </li>
                </ul>
                <p class="InfoPage__text">
                    SMS messaging is provided via Twilio. Supported carriers include major US carriers.
                    T-Mobile is not liable for delayed or undelivered messages.
                </p>
            </section>

            <section class="InfoPage__section">
                <h2 class="InfoPage__heading">6. User Responsibilities</h2>
                <p class="InfoPage__text">You agree to:</p>
                <ul class="InfoPage__list">
                    <li>Provide accurate and complete information when creating your profile</li>
                    <li>Keep your account information up to date</li>
                    <li>Use the Service only for lawful purposes</li>
                    <li>Not impersonate any person or entity</li>
                    <li>Not interfere with the operation of the Service</li>
                    <li>Not use the Service to transmit spam, malware, or other harmful content</li>
                </ul>
            </section>

            <section class="InfoPage__section">
                <h2 class="InfoPage__heading">7. Acceptable Use Policy</h2>
                <p class="InfoPage__text">
                    You may not use the Service to:
                </p>
                <ul class="InfoPage__list">
                    <li>Harass, bully, threaten, or intimidate other users</li>
                    <li>Post or transmit content that is unlawful, defamatory, obscene, or offensive</li>
                    <li>Send unsolicited messages or spam through the platform</li>
                    <li>Attempt to gain unauthorized access to the Service or other users' accounts</li>
                    <li>Use automated tools, bots, or scripts to access or interact with the Service</li>
                    <li>Reverse engineer, decompile, or disassemble any part of the Service</li>
                    <li>Use the Service for any commercial purpose not expressly permitted by us</li>
                </ul>
                <p class="InfoPage__text">
                    We reserve the right to investigate and take appropriate action against anyone who
                    violates this provision, including removing content and suspending or terminating
                    accounts.
                </p>
            </section>

            <section class="InfoPage__section">
                <h2 class="InfoPage__heading">8. User-Generated Content</h2>
                <p class="InfoPage__text">
                    You may be able to create, post, or share content through the Service, including
                    group names, descriptions, and messages ("User Content"). You retain ownership of
                    your User Content, but by posting it through the Service, you grant MakeReady a
                    non-exclusive, worldwide, royalty-free license to use, display, and distribute your
                    User Content solely for the purpose of operating and providing the Service.
                </p>
                <p class="InfoPage__text">
                    You are solely responsible for your User Content. We do not endorse or guarantee
                    the accuracy of any User Content. We reserve the right to remove any User Content
                    that violates these Terms or is otherwise objectionable, at our sole discretion.
                </p>
            </section>

            <section class="InfoPage__section">
                <h2 class="InfoPage__heading">9. Intellectual Property</h2>
                <p class="InfoPage__text">
                    The Service, including its original content, features, and functionality (excluding
                    User Content), is owned by MakeReady and is protected by copyright, trademark, and
                    other intellectual property laws. You may not copy, modify, distribute, sell, or
                    lease any part of the Service without our prior written consent.
                </p>
                <p class="InfoPage__text">
                    The MakeReady name, logo, and all related names, logos, product and service names,
                    designs, and slogans are trademarks of MakeReady. You may not use such marks
                    without our prior written permission.
                </p>
            </section>

            <section class="InfoPage__section">
                <h2 class="InfoPage__heading">10. Account Termination</h2>
                <p class="InfoPage__text">
                    We reserve the right to suspend or terminate your access to the Service at any
                    time, with or without cause, and with or without notice, for violation of these
                    Terms or for any other reason. You may also request account deletion at any time
                    by contacting us at
                    <a href="mailto:support@makeready.org" class="InfoPage__link">support@makeready.org</a>.
                </p>
                <p class="InfoPage__text">
                    Upon termination, your right to use the Service will immediately cease. Provisions
                    of these Terms that by their nature should survive termination shall survive,
                    including but not limited to ownership provisions, warranty disclaimers,
                    indemnification, and limitations of liability.
                </p>
            </section>

            <section class="InfoPage__section">
                <h2 class="InfoPage__heading">11. Disclaimer of Warranties</h2>
                <p class="InfoPage__text">
                    THE SERVICE IS PROVIDED ON AN "AS IS" AND "AS AVAILABLE" BASIS, WITHOUT WARRANTIES
                    OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO IMPLIED
                    WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND
                    NON-INFRINGEMENT. WE DO NOT WARRANT THAT THE SERVICE WILL BE UNINTERRUPTED,
                    SECURE, OR ERROR-FREE, THAT DEFECTS WILL BE CORRECTED, OR THAT THE SERVICE IS
                    FREE OF VIRUSES OR OTHER HARMFUL COMPONENTS.
                </p>
            </section>

            <section class="InfoPage__section">
                <h2 class="InfoPage__heading">12. Limitation of Liability</h2>
                <p class="InfoPage__text">
                    TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, MAKEREADY AND ITS OFFICERS,
                    DIRECTORS, EMPLOYEES, AND AGENTS SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL,
                    SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, INCLUDING BUT NOT LIMITED TO LOSS OF
                    PROFITS, DATA, OR GOODWILL, ARISING OUT OF OR IN CONNECTION WITH YOUR USE OF THE
                    SERVICE, WHETHER BASED ON WARRANTY, CONTRACT, TORT, NEGLIGENCE, STRICT LIABILITY,
                    OR ANY OTHER LEGAL THEORY, EVEN IF WE HAVE BEEN ADVISED OF THE POSSIBILITY OF
                    SUCH DAMAGES.
                </p>
                <p class="InfoPage__text">
                    IN NO EVENT SHALL OUR TOTAL LIABILITY TO YOU FOR ALL CLAIMS ARISING OUT OF OR
                    RELATING TO THE SERVICE EXCEED THE AMOUNT YOU HAVE PAID US IN THE TWELVE (12)
                    MONTHS PRECEDING THE CLAIM, OR ONE HUNDRED DOLLARS ($100), WHICHEVER IS GREATER.
                </p>
            </section>

            <section class="InfoPage__section">
                <h2 class="InfoPage__heading">13. Indemnification</h2>
                <p class="InfoPage__text">
                    You agree to indemnify, defend, and hold harmless MakeReady and its officers,
                    directors, employees, agents, and affiliates from and against any claims,
                    liabilities, damages, losses, costs, and expenses (including reasonable attorneys'
                    fees) arising out of or in any way connected with: (a) your access to or use of
                    the Service; (b) your violation of these Terms; (c) your violation of any
                    third-party rights, including intellectual property or privacy rights; or (d) your
                    User Content.
                </p>
            </section>

            <section class="InfoPage__section">
                <h2 class="InfoPage__heading">14. Dispute Resolution</h2>
                <p class="InfoPage__text">
                    Any dispute, controversy, or claim arising out of or relating to these Terms or the
                    Service shall first be resolved through good-faith informal negotiation. If the
                    dispute cannot be resolved informally within 30 days, either party may pursue
                    resolution through binding arbitration administered in accordance with the rules of
                    the American Arbitration Association. The arbitration shall be conducted in English
                    and the arbitrator's decision shall be final and binding.
                </p>
                <p class="InfoPage__text">
                    <strong>Class Action Waiver:</strong> You agree that any dispute resolution
                    proceedings will be conducted only on an individual basis and not in a class,
                    consolidated, or representative action. If this class action waiver is found to be
                    unenforceable, then the entirety of this dispute resolution provision shall be null
                    and void.
                </p>
                <p class="InfoPage__text">
                    Nothing in this section shall prevent either party from seeking injunctive or other
                    equitable relief in court for matters related to intellectual property or
                    unauthorized access to the Service.
                </p>
            </section>

            <section class="InfoPage__section">
                <h2 class="InfoPage__heading">15. Governing Law</h2>
                <p class="InfoPage__text">
                    These Terms shall be governed by and construed in accordance with the laws of the
                    State of Texas, without regard to its conflict of law provisions. To the extent
                    that any lawsuit or court proceeding is permitted hereunder, you agree to submit to
                    the personal and exclusive jurisdiction of the state and federal courts located in
                    Texas.
                </p>
            </section>

            <section class="InfoPage__section">
                <h2 class="InfoPage__heading">16. Changes to Terms</h2>
                <p class="InfoPage__text">
                    We may update these Terms of Service from time to time. When we make material
                    changes, we will notify you by updating the "Last updated" date at the top of this
                    page and, where appropriate, provide additional notice (such as an in-app
                    notification or SMS). Your continued use of the Service after any changes
                    constitutes acceptance of the updated Terms.
                </p>
            </section>

            <section class="InfoPage__section">
                <h2 class="InfoPage__heading">17. Severability</h2>
                <p class="InfoPage__text">
                    If any provision of these Terms is found to be unenforceable or invalid by a court
                    of competent jurisdiction, that provision shall be limited or eliminated to the
                    minimum extent necessary so that the remaining provisions of these Terms shall
                    remain in full force and effect.
                </p>
            </section>

            <section class="InfoPage__section">
                <h2 class="InfoPage__heading">18. Entire Agreement</h2>
                <p class="InfoPage__text">
                    These Terms, together with our Privacy Policy, constitute the entire agreement
                    between you and MakeReady regarding your use of the Service and supersede all prior
                    and contemporaneous agreements, proposals, or representations, written or oral,
                    concerning the subject matter of these Terms.
                </p>
            </section>

            <section class="InfoPage__section">
                <h2 class="InfoPage__heading">19. Contact</h2>
                <p class="InfoPage__text">
                    For questions about these Terms of Service, contact us at:
                </p>
                <p class="InfoPage__text">
                    MakeReady<br>
                    Email:
                    <a href="mailto:support@makeready.org" class="InfoPage__link">support@makeready.org</a>
                </p>
            </section>
        </div>
    </div>
</div>
</main>
@endsection
