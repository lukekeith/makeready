#!/usr/bin/env bash
# SPEC D5: no type a kept file needs may be declared under Pages/ or Components/.
set -euo pipefail
cd "$(dirname "$0")/../MakeReady"
types="GroupInviteData GroupInviteResponse LessonInviteData LessonInviteResponse LessonInviteProgram LessonInviteGroup BibleVersion BibleTranslationsResponse SplitCalendarEvent SplitCalendarDay SplitCalendarMonth SplitMonthSection CalendarActivityIcon CalendarFormatters ActivityLogResponse ActivityLogEntry ActivityLogPagination AnyCodable LessonActivityStatus ReadBlockSelectionStyle BibleVerseTextLayout StudyProgram UserGroup"
fail=0
for t in $types; do
  if grep -rqE "^\s*(public )?(final )?(struct|enum|class) $t\b" Pages Components; then echo "still in UI: $t"; fail=1; fi
done
exit $fail
