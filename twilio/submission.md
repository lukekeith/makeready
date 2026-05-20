# Twilio A2P 10DLC Campaign Submission

Campaign SID: `CM0281920784ed1d026de2523662ec1e7e`

---

## Campaign Description

MakeReady is an invite-only platform for small in-person groups. This campaign sends one transactional SMS type: a group-invite message containing a join link. The recipient has already given the group leader verbal or written consent before the message is sent. The join link takes the recipient to an on-site double-opt-in screen with an unchecked consent checkbox before any further communication. Activity and event reminders are delivered via push notifications, not SMS.

Public pages (no login required):
- SMS opt-in flow documentation: https://app.makeready.org/pages/sms-opt-in
- Live consent form (viewable directly): https://app.makeready.org/join/group/NNNM76/optin
- Privacy Policy: https://app.makeready.org/pages/privacy
- Terms of Service: https://app.makeready.org/pages/terms

---

## Sample Message #1

Luke invited you to join "Young Professionals" on MakeReady! Tap here to join: https://app.makeready.org/join/group/NNNM76. Msg & data rates may apply. Reply STOP to opt out, HELP for help.

---

## Sample Message #2

James invited you to join "Mens Bible Study" on MakeReady! Tap here to join: https://app.makeready.org/join/group/AB12CD. Msg & data rates may apply. Reply STOP to opt out, HELP for help.

---

## How do end-users consent to receive messages?

SMS consent uses a double-opt-in model. All URLs below are publicly accessible with no login required.

STEP 1 — PRIOR CONSENT: The group leader obtains the recipient's verbal or written consent before adding their phone number. The first and only SMS is the group invite itself.

STEP 2 — ON-SITE CONFIRMATION: The recipient taps the join link in the SMS and arrives at the consent screen. A live example is viewable at: https://app.makeready.org/join/group/NNNM76/optin

The consent screen contains:
- A non-pre-checked checkbox with the text: "I agree to receive text messages from MakeReady for group-related events and daily studies. Msg & data rates may apply. Reply STOP to opt out."
- Links to Privacy Policy and Terms of Service displayed alongside the checkbox
- The Continue button is disabled until the checkbox is checked
- Server-side validation rejects the submission if consent is not given

Consent is recorded server-side with a timestamp. A full walkthrough with screenshots of every step is at: https://app.makeready.org/pages/sms-opt-in

Privacy Policy: https://app.makeready.org/pages/privacy
Terms of Service: https://app.makeready.org/pages/terms
