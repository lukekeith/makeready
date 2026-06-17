# Twilio A2P 10DLC Campaign Submission

Campaign SID: `CM0281920784ed1d026de2523662ec1e7e`
Revision: 2026-06-16 — addresses the three rejection items from Twilio Support (see [`../docs/twilio/A2P-submission.md`](../docs/twilio/A2P-submission.md)):

1. Opt-in proof for paper form + verbal script
2. Web opt-in made optional (no forced consent)
3. Campaign description includes message frequency + HELP keyword

---

## Campaign Description

MakeReady is a platform used by small-group leaders (such as Bible study leaders and ministry facilitators) to communicate with the members of their group. This campaign sends two related transactional SMS types: (1) a one-time group invitation that names the inviter, names the group, and includes a unique join link; and (2) recurring activity messages are also sent to enrolled members, notifying them when the day's group study (such as a reading or study prompt) is ready and linking them to it. Recipients are people whom a group leader has personally invited and who have, on app.makeready.org, entered their phone number and actively checked an unchecked consent box agreeing to receive group invitations and daily activity messages. Message volume is approximately one message per enrolled member per day. Recipients can reply STOP at any time to opt out and HELP for assistance.

---

## Sample Message #1

Luke invited you to join "Young Professionals" on MakeReady! Tap here to join: https://app.makeready.org/join/group/NNNM76. Msg & data rates may apply. Reply STOP to opt out, HELP for help.

---

## Sample Message #2

Luke invited you to join today's "Romans in 30 days" study on MakeReady! Tap here to join: https://app.makeready.org/join/study/MMHHS2. Msg & data rates may apply. Reply STOP to opt out, HELP for help.

---

## How do end-users consent to receive messages?

SMS consent uses a double-opt-in model. All URLs below are publicly accessible with no login required. STEP 1 — PRIOR CONSENT: The group leader obtains the recipient's verbal or written consent before adding their phone number. The first and only SMS is the group invite itself. STEP 2 — ON-SITE CONFIRMATION: The recipient taps the join link in the SMS and arrives at the consent screen. A live example is viewable at: https://app.makeready.org/join/group/NNNM76/optin The consent screen contains: - A non-pre-checked checkbox with the text: "I agree to receive text messages from MakeReady for group-related events and daily studies. Msg & data rates may apply. Reply STOP to opt out." - Links to Privacy Policy and Terms of Service displayed alongside the checkbox - The Continue button is disabled until the checkbox is checked - Server-side validation rejects the submission if consent is not given Consent is recorded server-side with a timestamp. A full walkthrough with screenshots of every step is at: https://app.makeready.org/pages/sms-opt-in
