# Twilio A2P 10DLC Campaign Submission

Campaign SID: `CM0281920784ed1d026de2523662ec1e7e`
Revision: 2026-06-16 — addresses the three rejection items from Twilio Support (see [`../docs/twilio/A2P-submission.md`](../docs/twilio/A2P-submission.md)):

1. Opt-in proof for paper form + verbal script
2. Web opt-in made optional (no forced consent)
3. Campaign description includes message frequency + HELP keyword

---

## Campaign Description

MakeReady is a platform used by small-group leaders (such as Bible study leaders and ministry facilitators) to communicate with the members of their group. This campaign sends two related transactional SMS types: (1) a one-time group invitation that names the inviter, names the group, and includes a unique join link; and (2) recurring activity messages are also sent to enrolled members, notifying them when the day's group study (such as a reading or study prompt) is ready and linking them to it. Recipients are people whom a group leader has personally invited and who have, on app.makeready.org, entered their phone number and actively checked an unchecked consent box agreeing to receive group invitations and daily activity messages. Message frequency: enrolled recipients receive approximately one message per day (up to about 30 messages per month). Reply HELP for help or STOP to cancel; message and data rates may apply.

---

## Sample Message #1

Luke invited you to join "Young Professionals" on MakeReady! Tap here to join: https://app.makeready.org/join/group/NNNM76. Msg & data rates may apply. Reply STOP to opt out, HELP for help.

---

## Sample Message #2

Luke invited you to join today's "Romans in 30 days" study on MakeReady! Tap here to join: https://app.makeready.org/join/study/MMHHS2. Msg & data rates may apply. Reply STOP to opt out, HELP for help.

---

## How do end-users consent to receive messages?

SMS consent is obtained before any messages are sent, and the on-site checkbox is always optional. All URLs below are publicly accessible with no login required. STEP 1 — PRIOR CONSENT (off-site): Before adding a recipient's phone number, the group leader obtains the recipient's verbal or written consent. The exact verbal script and a printable paper opt-in form are documented in our opt-in proof: https://app.makeready.org/docs/MakeReady-SMS-Optin-Proof.pdf STEP 2 — ON-SITE (optional): The recipient taps the join link and reaches the join flow, where they are offered a non-pre-checked SMS consent checkbox. Checking it is optional and is never a prerequisite for entering their details or completing the join — members can proceed whether or not it is checked. A live example is viewable at: https://app.makeready.org/join/group/NNNM76/optin The consent screen contains: - A non-pre-checked checkbox with the text: "I agree to receive text messages from MakeReady for group-related events and daily studies. Msg & data rates may apply. Reply STOP to opt out." - Links to Privacy Policy and Terms of Service displayed alongside the checkbox - A Continue button that is always enabled, so members can proceed without checking the box Consent is recorded server-side with a timestamp; SMS is sent only to members who opted in, and members who do not opt in still join and simply do not receive SMS. A full walkthrough with screenshots of every step is at: https://app.makeready.org/pages/sms-opt-in
