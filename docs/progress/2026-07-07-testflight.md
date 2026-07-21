# TestFlight — What to Test (2026-07-07)

Window: since previous archive 2026-06-19 10:36 → archive 2026-07-07 15:21 (build 259).

---

This release introduces study syncing: when a study program's creator edits lessons and taps the Published badge (or the new Publish button in the Export & Publish dialog), the app now shows exactly what changed since the last publish and cuts a new version that enrolled groups can receive. Each group enrollment has a new Study Sync screen (the circular-arrows icon on the enrollment schedule, also offered as a toggle when confirming a new enrollment) where leaders turn syncing on, choose Automatic or Approval mode, see a count of pending lesson and activity changes, and open Review Changes to approve or reject each changed lesson individually with toggles. Leaders are kept in the loop by a new unread-notifications banner on the Home dashboard and action buttons on notification rows that jump straight to the affected enrollment's sync screen.

Please focus testing on the full publish-and-sync loop: edit a published study's lessons, publish from the program page, confirm the notification banner and feed appear, then open Study Sync on an enrolled group and approve some (not all) changes in Review Changes — verify partial approvals stick, remaining changes stay pending, dates of unapproved lessons don't move, and members who already completed a lesson still see the version they finished.
