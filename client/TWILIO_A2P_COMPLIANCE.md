# Twilio A2P 10DLC Campaign Compliance Guide

## Current Status: REJECTED → FIXING

Campaign rejected for:
- **Error 30891** — Unverifiable website / opt-in flow not found

## Root Cause Analysis

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

## Checklist Before Resubmission

- [ ] Deploy the code changes (consent text, noscript fallback, enhanced opt-in page)
- [ ] Verify https://app.makeready.org/pages/sms-opt-in loads correctly and shows the checkbox demo
- [ ] Verify https://app.makeready.org/pages/privacy loads correctly
- [ ] Verify https://app.makeready.org/pages/terms loads correctly
- [ ] Verify join flow pages have noscript fallback (view-source on /join/group/*/phone)
- [ ] Update campaign description with the corrected text above
- [ ] Update message flow / consent description with the corrected text above
- [ ] Uncheck "Messages will include phone numbers" (has_embedded_phone → false)
- [ ] Resubmit campaign

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
