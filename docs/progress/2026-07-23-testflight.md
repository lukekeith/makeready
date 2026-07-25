This build is mostly about editing enrollments on the leader side — once a group is enrolled in a study, a leader can now change how and when it runs instead of deleting and recreating it — plus polish across the study/lesson editors and the unenroll flow. Most of what's new lives on the enrollment screens.

Edit an enrollment (new). Tapping an enrollment opens a menu with "Edit lessons" and "Edit enrollment." The edit flow lets you change the group, the study, and the schedule (days of the week, time, start date), with a preview of what will change before you save. The menu is reachable from Program Home, the Groups → Enrolled tab, and a member's home; the group/study pickers pre-select the current values; and "Edit enrollment" is disabled (with a short note) for studies another leader created.
How to test: from a group with an active enrollment, open the menu (try all three entry points). Edit the days/time/start date and try switching group and study — you should see a preview of the impact before saving. Save and reopen to confirm it stuck. Also move back and forth through the steps, including on a group with no join code, and confirm smooth transitions, working back chevrons, and no infinite spinner. On another leader's study, confirm "Edit enrollment" is greyed out.

Switch a study back to Draft — confirmation. Turning a published study back to Draft while groups are enrolled now warns that enrolled groups keep their lessons and only new sign-ups are blocked — no group is removed.
How to test: publish a study, enroll a group, tap the Published badge, choose "Switch to Draft." Expect a confirmation naming how many groups are enrolled; Cancel keeps it published, Confirm switches to draft, and the enrolled group is unaffected. With nothing enrolled, it should switch straight to draft with no prompt.

Unenroll polish. Unenrolling now shows a green checkmark (was a warning triangle) and removes the group from the Enrolled tab immediately.
How to test: Groups → Enrolled → swipe an enrollment → trash → confirm. Expect a green checkmark and the row disappearing right away, no refresh needed.

Study/lesson editor changes. The Program Home "Studies" tab is renamed "Lessons"; the Read editor's "+" is now labeled "Add Bible verse" / "Add custom text" buttons; activity titles are capped so an over-long title can't fail to save; and overlapping Exegesis highlights now merge instead of erroring.
How to test: confirm the "Lessons" tab and the two labeled Add buttons; type an activity title past ~200 characters and save (it should stop at the limit and save, not error); in an Exegesis lesson, highlight over an existing highlight and confirm it merges with no "couldn't save" error.

Also: the Select Group card's selected style now matches Select Program, and (Debug builds only) switching to the Local server environment on Profile is more reliable with a connection test.

Please focus testing on the Edit-enrollment flow (all three entry points, changing group/study/schedule, the preview, and the disabled state for studies you don't own), the Switch-to-Draft confirmation, unenrolling from Groups → Enrolled, and the Read/Exegesis editor changes.
