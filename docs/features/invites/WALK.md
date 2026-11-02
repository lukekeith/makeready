# Invites acceptance walk

Status: IN PROGRESS — actual agent walk, not human sign-off. Final acceptance remains open.
Original walk source: 892057828db15d6b34bc18b95f59a45cc49fd187. Callback/test fix: aa547d20; affected menu proof requires its rebuilt app. Registry-only checkpoints may follow.
Plan: walk=risk review=slice. The final merge result is tested separately by the verifier.

Environment: isolated local server/client, an owned scratch database and bucket, test-mode SMS, and an owned headless simulator. No real provider delivery or OAuth claim. Fixtures reset before the actual walk. Credentials are never exported as evidence.

| ID | Acceptance / risk action | Observed result / evidence |
| --- | --- | --- |
| W1 | A7/A9: sign in as Fixtures on Local; Home → Invites renders five statuses | PASS on actual simulator: five statuses observed in W1 activity, `w123.xcresult` / `walk-w123.log`. Same application source 89205782; later callback-only fix does not affect row rendering. |
| W2 | A7: phone/group local search, single TopNav focus/query behavior, clear and pull refresh; no server q | PARTIAL: formatted phone/group search and clear observed in `w123b.xcresult`; 15 actual feed requests had no q in `walk-evidence/http-invites.jsonl`. Refresh and final shell-focus checks remain. |
| W3 | A7: four filter menus; draft Clear/cancel do not commit; Save applies; All restores | FAILED at original source: visible chip taps opened no menu (`w45b.xcresult`). D2M callback fix delivered; rebuilt four-menu re-walk pending. |
| W4 | A8/A9: Requested filter → selected request; Accept → Cancel makes no mutation | PASS directly: Accept → Cancel kept pending controls; `w45direct.xcresult`. Requested-filter variant awaits fixed menus. |
| W5 | A6/A8/A9: Accept → Confirm; request becomes accepted; clear Requested filter to inspect Accepted row | PARTIAL: direct Confirm popped and David/Women’s row became Accepted; `w45direct.xcresult`. Filtered-list transition awaits fixed menus and a second untouched request. |
| W6 | A9: unchanged web client group member list contains that member after approval | PASS: actual unchanged web Group Home → Members pane showed David Hayes after the iPhone approval. Before response excluded David; after included his exact fixture member ID. Screenshot visually inspected: `walk-evidence/web-member.png`; DOM/response `web-member.html/json`, baseline `web-before.json`. |
| W7 | A8/A9: linked and unlinked invite detail metadata and timeline; member/group links use correct destinations | PARTIAL: linked/unlinked metadata/timeline and existing-member → James Carter profile observed (`w789.xcresult`). Group destination remains in final route walk. |
| W8 | A5/A8/A9: Sent detail → Resend; one Invitation resent notice and factual test-mode send/event | PASS: one resend notice and a new Young Adults timeline entry (`w89.xcresult`). Exactly one POST and one resent event; scratch SMS log SENT with test-prefixed SID, no real SMS. `http-invites.jsonl`, `invite-events.jsonl`. |
| W9 | A5/A8/A9: Withdraw → Cancel leaves pending row; Confirm changes chips and removes feed row | Pending |
| W10 | A5/A9: withdrawn public token /join link in browser displays invalid/expired outcome | Pending |
| W11 | A8/A9: second request Reject confirms; reopen Rejected with no pending controls | Pending |
| W12 | A1/A6/A9: existing group request entry still routes and answers a request correctly | Pending |

Expected Requested-filter behavior: a committed approval leaves that filtered list; switch to All/Accepted to verify its new status. This preserves filter semantics while proving the scripted status change.

Evidence: screenshots are captured inside UI assertions with keepAlways attachments, plus debug trees; browser captures include DOM and screenshots. Export and preserve evidence before any worktree cleanup. A failed item creates a scoped fix/review/re-walk; no mocked unit test substitutes for this table.
