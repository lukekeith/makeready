# Invites acceptance walk

Status: PLANNED — no A9 runtime acceptance yet. Agent walk, not human sign-off.
Source code: 892057828db15d6b34bc18b95f59a45cc49fd187 (registry-only checkpoints may follow).
Plan: walk=risk review=slice. The final merge result is tested separately by the verifier.

Environment: isolated local server/client, an owned scratch database and bucket, test-mode SMS, and an owned headless simulator. No real provider delivery or OAuth claim. Fixtures reset before the actual walk. Credentials are never exported as evidence.

| ID | Acceptance / risk action | Observed result / evidence |
| --- | --- | --- |
| W1 | A7/A9: sign in as Fixtures on Local; Home → Invites renders five statuses | Pending |
| W2 | A7: phone/group local search, single TopNav focus/query behavior, clear and pull refresh; no server q | Pending |
| W3 | A7: four filter menus; draft Clear/cancel do not commit; Save applies; All restores | Pending |
| W4 | A8/A9: Requested filter → selected request; Accept → Cancel makes no mutation | Pending |
| W5 | A6/A8/A9: Accept → Confirm; request becomes accepted; clear Requested filter to inspect Accepted row | Pending |
| W6 | A9: unchanged web client group member list contains that member after approval | Pending |
| W7 | A8/A9: linked and unlinked invite detail metadata and timeline; member/group links use correct destinations | Pending |
| W8 | A5/A8/A9: Sent detail → Resend; one Invitation resent notice and factual test-mode send/event | Pending |
| W9 | A5/A8/A9: Withdraw → Cancel leaves pending row; Confirm changes chips and removes feed row | Pending |
| W10 | A5/A9: withdrawn public token /join link in browser displays invalid/expired outcome | Pending |
| W11 | A8/A9: second request Reject confirms; reopen Rejected with no pending controls | Pending |
| W12 | A1/A6/A9: existing group request entry still routes and answers a request correctly | Pending |

Expected Requested-filter behavior: a committed approval leaves that filtered list; switch to All/Accepted to verify its new status. This preserves filter semantics while proving the scripted status change.

Evidence: screenshots are captured inside UI assertions with keepAlways attachments, plus debug trees; browser captures include DOM and screenshots. Export and preserve evidence before any worktree cleanup. A failed item creates a scoped fix/review/re-walk; no mocked unit test substitutes for this table.
