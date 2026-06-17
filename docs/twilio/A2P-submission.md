# Twilio A2P 10DLC — Rejection Feedback & Fix Tracker

**Campaign SID:** `CM0281920784ed1d026de2523662ec1e7e`
**Response received:** 2026-06-16 (from Twilio Support — Varun Bhardwaj)
**Status:** ❌ Rejected — 3 issues to fix before resubmitting

Related docs:
- Previous submission text: [`../../twilio/submission.md`](../../twilio/submission.md)
- Compliance history & account status: [`../../client/TWILIO_A2P_COMPLIANCE.md`](../../client/TWILIO_A2P_COMPLIANCE.md)

---

## Fix checklist (verify each before resubmitting)

| # | Issue | Required change | Where | Verify | Status |
|---|---|---|---|---|---|
| 1 | **Opt-in proof missing** (paper form + verbal script) | Provide concrete proof of consent for BOTH the paper form and the verbal script — not just a description. Produce (a) a sample paper opt-in form, (b) the exact verbal script leaders read. Attach/describe in the submission. | Submission package (new artifacts) | Submission includes a paper-form artifact + verbatim verbal script text | ☐ |
| 2 | **Web opt-in = "forced consent"** | Make the SMS consent checkbox **optional**. Users must be able to enter name / DOB / phone and proceed **without** checking it. Only send SMS to those who do opt in. | Client opt-in flow (Vue island + `/join/.../optin`) **and** server-side validation | At `/join/group/NNNM76/optin`: fill details, leave consent **unchecked** → can still Continue/submit | ☐ |
| 3 | **Missing verbiage in campaign description** | Add to the **campaign description** (not just sample messages): (a) expected message frequency, (b) HELP keyword instructions | `twilio/submission.md` Campaign Description | Description text contains a frequency line **and** "Reply HELP for help" | ☐ |
| 4 | **Resubmit** | After 1–3 verified, resubmit the campaign for review | Twilio console | Campaign back in PENDING/IN-REVIEW | ☐ |

---

## ⚠️ Important contradiction to resolve (issue #2)

The current implementation is the **opposite** of what Twilio now requires. Per the previous submission ([`twilio/submission.md`](../../twilio/submission.md) lines 42–43):

> - The Continue button is **disabled until the checkbox is checked**
> - Server-side validation **rejects the submission if consent is not given**

That mandatory-consent design is exactly the **"forced consent"** Twilio is now rejecting. Fixing #2 means a real product change to the join/opt-in flow:
- Consent checkbox becomes optional (default unchecked, form submittable without it).
- The Continue button must no longer depend on the checkbox.
- Server must accept the submission with consent = false (and simply not enrol that phone for SMS).

This needs to be reconciled with the double-opt-in framing in the submission — confirm with Twilio whether the invite-link consent screen can remain, as long as it isn't a gate to completing the form.

---

## Suggested wording for issue #3

Add a frequency + HELP line to the Campaign Description, e.g.:

> Message frequency varies; recipients receive up to a few messages per month. Reply HELP for help, STOP to cancel. Msg & data rates may apply.

(The sample messages already include "Reply STOP to opt out, HELP for help" — the gap is that the **description** field omits frequency and HELP.)

---

## Verbatim Twilio response

> Hi Luke,
>
> Thank you for reaching out to Twilio Support Team. I'm Varun, and I'm happy to assist you today.
>
> I understand how frustrating it can be to run into roadblocks during the verification process. Rest assured, I'm here to help guide you through the necessary compliance updates to move things forward.
>
> Appreciate you for your patience while we reviewed your A2P campaign (SID: CM0281920784ed1d026de2523662ec1e7e). I want to clarify the specific reasons for the campaign rejection and provide guidance on how to proceed:
>
> - **Opt-in Proof Missing:** The required opt-in proof for both the paper form and verbal script was not provided. Please ensure you upload or describe clear evidence of how users provide consent via these methods.
>
> - **Web Opt-in Flow Issue:** In your current web opt-in process, users are required to check the consent box before they can proceed to enter other details (such as name, date of birth, and phone number). This is considered "forced consent." Consent must be optional and not a prerequisite for accessing other parts of your form. Please update your flow so users can proceed without being required to check the consent box.
>
> - **Missing Verbiage:** The campaign description is missing two required elements:
>   - The expected message frequency (e.g., "You will receive up to X messages per month")
>   - The HELP keyword instructions (e.g., "Reply HELP for help")
>
> **Next Steps:**
>
> 1. Update your opt-in documentation to include clear proof for paper and verbal consent.
> 2. Adjust your web opt-in flow to make consent optional, not mandatory for proceeding.
> 3. Revise your campaign description to include the message frequency and HELP keyword information.
> 4. Resubmit your campaign for review.
>
> If you have any questions about these requirements or need further clarification, please let us know. We're here to help you get your campaign approved.
>
> Best regards,
> Varun Bhardwaj
> Twilio Support Team
