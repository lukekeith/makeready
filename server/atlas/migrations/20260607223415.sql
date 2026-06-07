-- Create index "idx_member_activity_progress_lessonScheduleId_scheduledActivity" to table: "member_activity_progress"
CREATE INDEX "idx_member_activity_progress_lessonScheduleId_scheduledActivity" ON "member_activity_progress" ("lessonScheduleId", "scheduledActivityId", "completedAt");
-- Create index "idx_member_video_progress_lessonScheduleId_scheduledActivityId_" to table: "member_video_progress"
CREATE INDEX "idx_member_video_progress_lessonScheduleId_scheduledActivityId_" ON "member_video_progress" ("lessonScheduleId", "scheduledActivityId", "completedAt");
