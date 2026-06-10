# Twilio A2P 10DLC Campaign Compliance Guide

## Current Status (verified 2026-06-08 via Twilio API)

| Layer | Status | Identifier | Notes |
|---|---|---|---|
| **Brand** | ✅ **APPROVED / VERIFIED** | `BNd9e3607bbb5e796a19490d0e8a432a27` | Standard brand, identity verified — no action needed |
| **Campaign** (attached to our Messaging Service) | ❌ **FAILED** | `QE2c6890da8086d771620e9b13fadeba0b` / CR id `CDUUE97`, use case `LOW_VOLUME` | Rejected in vetting — **error 30886** |
| **Messaging Service** | live | `MG0a5743b83e7f972a517ba92eb206f927` ("Low Volume Mixed A2P Messaging Service") | Pool number `+14697131325` |
| **Twilio account** | active | `ACb3ee…` ("MakeReady", Full, no subaccounts — full SID in `server/.env`) | These are the credentials in `server/.env` |

**Progress since last update:** The earlier blocker (error **30891**, unverifiable opt-in flow) is **resolved** — the brand is approved and the opt-in/website fixes cleared review. The remaining blocker has moved to the **campaign description**.

### Active rejection — error 30886 (Invalid Campaign Description)
> *"Your A2P 10DLC campaign was rejected during vetting because the Campaign Description field does not clearly explain the messaging program. Describe who is sending the messages, who receives them, and why. Make sure the description matches your selected campaign use case, sample messages, and registered brand details."* — flagged field: `USE_CASE_DESCRIPTION`

Likely triggers in the currently-submitted description:
- Describes **two distinct message types** (one-time invites *and* recurring daily activity messages) under a single `LOW_VOLUME` use case.
- States **"approximately one message per enrolled member per day"** — a recurring daily cadence that can read as inconsistent with a low-volume/transactional framing.

### ⚠️ Open discrepancy — support vs. API (chase before resubmitting)
On **2026-06-08**, Twilio Onboarding & Compliance support (Abdul Samad) replied that campaign **`CM0281920784ed1d026de2523662ec1e7e`** is now **approved**. However, that SID **does not exist in our account** (`ACb3ee07…`) — not on the Messaging Service, not at the account-level compliance endpoint, and there are no subaccounts. The only campaign in our account (`QE2c68…` / `CDUUE97`) remains **FAILED**.

This means one of:
1. The approved `CM…` campaign lives in a **different Twilio account/ISV** than the one whose credentials are in `server/.env`, or
2. There is an account/SID mismatch on the support side.

**Until the approved campaign is attached to Messaging Service `MG0a57…` (or we point the server at the account that owns it), live sends will continue to fail.** A live test on 2026-06-08 via `sendCampaignSms` (template `group-invite-v1`) was accepted by Twilio (SID `SMf0e491eb40f71a5cf48fd900735d8ab5`) but returned **undelivered, error 30034 (message from an unregistered number)** — consistent with the attached campaign being FAILED.

**Next action:** Reply to Samad asking which **account SID** campaign `CM0281…` belongs to, and confirm it is linked to a Messaging Service with a sending number. Reconcile against `TWILIO_ACCOUNT_SID` / `TWILIO_MESSAGING_SERVICE_SID` in `server/.env`.

---

## Root Cause Analysis (original 30891 rejection — RESOLVED)

The rejection was for "unverifiable website" which means the Twilio reviewer could not verify:
1. The opt-in flow (SMS consent checkbox) on the website
2. The consistency between the campaign description and what's actually on the site

### Specific Issues Found

1. **Phone step is client-rendered (Vue island)** — The consent checkbox only renders via JavaScript. Twilio's crawler/reviewer may not execute JS, seeing an empty `<div>` instead of the consent flow.

2. **Consent checkbox text mismatch** — The opt-in demo page showed different text than the actual checkbox:
   - Demo page: "I agree to receive text messages from MakeReady for group-related events and daily studies..."
   - Actual checkbox: "I agree to receive SMS messages. Msg & data rates may apply. Reply STOP to cancel."
   - Campaign description: Yet another variation

3. **Boolean flags error in submission** — "Messages will include phone numbers" was checked (true), but our messages don't contain phone numbers. This should be **false**.

### Fixes Applied

1. **Unified consent checkbox text** across all touchpoints (Vue component, opt-in demo page, campaign description)
2. **Added `<noscript>` fallback** on all join pages (group, study, event) showing the consent checkbox in server-rendered HTML
3. **Enhanced sms-opt-in page** with:
   - Step-by-step flow description
   - Where consent is collected (all join URLs)
   - Consent recording details
   - Matching checkbox replica
4. **Updated Privacy Policy and Terms links** shown alongside checkbox

---

## Corrected Campaign Submission Fields

### Campaign Description (40-4096 chars)
```
This campaign sends group invites and activity notifications to members of MakeReady groups. Group leaders invite new members via SMS with a join link. Enrolled members receive notifications about scheduled group activities, daily studies, and events. All opt-in occurs on the MakeReady website at app.makeready.org through an unchecked consent checkbox during the join flow. A demonstration of the opt-in experience is publicly available at https://app.makeready.org/pages/sms-opt-in
```

### Message Flow / How End Users Consent (40-2048 chars)
```
End users provide consent through a non-pre-checked checkbox during the phone entry step of the join flow on app.makeready.org. When joining a group, study, or event, the user enters their phone number and must actively check a checkbox that reads: "I agree to receive text messages from MakeReady for group-related events and daily studies. Msg & data rates may apply. Reply STOP to opt out." Links to our Privacy Policy (app.makeready.org/pages/privacy) and Terms of Service (app.makeready.org/pages/terms) are displayed directly alongside the checkbox. The user cannot proceed without checking the box — submission is blocked with an error message if consent is not given. Consent is recorded server-side with a timestamp. A demonstration of the opt-in experience is available at https://app.makeready.org/pages/sms-opt-in. The opt-in checkbox appears on: app.makeready.org/join/group, app.makeready.org/join/study, and app.makeready.org/join/event.
```

### Sample Messages (provide all 3)
```
Sample 1: Hello James, Luke has invited you to join the Young Professionals group on MakeReady. Tap here to join: https://app.makeready.org/join/group/NNNM76. Msg&Data rates may apply. Reply STOP to opt out, HELP for help.

Sample 2: Hello James, today's activity for Young Professionals is ready! Participate here: https://app.makeready.org/join/study/MMHHS2. Msg&Data rates may apply. Reply STOP to opt out.

Sample 3: Reminder: Young Professionals meets tonight at 7pm. See details: https://app.makeready.org/join/group/NNNM76. Msg&Data rates may apply. Reply STOP to opt out.
```

### Boolean Flags — CORRECTED
- `has_embedded_links`: **true** ✅ (messages contain URLs)
- `has_embedded_phone`: **false** ❌ (was incorrectly checked as true in last submission — messages do NOT contain phone numbers)
- `direct_lending`: **false** ✅
- `age_gated`: **false** ✅

### Privacy Policy URL
```
https://app.makeready.org/pages/privacy
```

### Terms and Conditions URL
```
https://app.makeready.org/pages/terms
```

---

## Checklist

### Original 30891 (opt-in) fix — ✅ DONE (brand approved, opt-in cleared)
- [x] Deploy the code changes (consent text, noscript fallback, enhanced opt-in page)
- [x] Verify https://app.makeready.org/pages/sms-opt-in loads correctly and shows the checkbox demo
- [x] Verify https://app.makeready.org/pages/privacy loads correctly
- [x] Verify https://app.makeready.org/pages/terms loads correctly
- [x] Verify join flow pages have noscript fallback (view-source on /join/group/*/phone)
- [x] Uncheck "Messages will include phone numbers" (has_embedded_phone → false)

### Current 30886 (campaign description) — TODO
- [ ] Resolve the support/API discrepancy: confirm which account SID owns approved campaign `CM0281…` (reply to Samad)
- [ ] Rewrite the campaign **use-case description** so it cleanly matches the `LOW_VOLUME` use case, the two sample messages, and the brand (single coherent program; reconcile the "one msg/member/day" cadence)
- [ ] Update message flow / consent description if needed
- [ ] Resubmit campaign `QE2c68…` (or attach the approved `CM…` campaign to Messaging Service `MG0a57…`)
- [ ] Re-run the live test (`docker exec -e TEST_VERIFICATION_CODES= makeready-server npx tsx src/scripts/send-a2p-test.ts`) and confirm Twilio status `delivered` (not `undelivered`/30034)

---

## Requirements for Approval

### 1. Privacy Policy (`/pages/privacy`) ✅ Already compliant

Contains required statement: "No mobile information will be shared with third parties/affiliates for marketing/promotional purposes."

### 2. Terms of Service (`/pages/terms`) ✅ Already compliant

Contains: program name, description, message frequency, data rates, **STOP** and **HELP** in bold, support contact.

### 3. SMS Opt-In Page (`/pages/sms-opt-in`) ✅ Updated

Publicly visible page showing the SMS opt-in flow with matching checkbox text.

### 4. Opt-In Checkbox ✅ Updated

- NOT pre-checked
- Explicit, unchecked checkbox the user actively selects
- Consistent text across all touchpoints:
  "I agree to receive text messages from MakeReady for group-related events and daily studies. Msg & data rates may apply. Reply STOP to opt out."
