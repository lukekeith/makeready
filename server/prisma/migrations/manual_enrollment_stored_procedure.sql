-- Create stored procedure for enrollment creation
-- This runs all enrollment operations in a single transaction on the database server
-- Run this in Supabase SQL Editor or via psql

CREATE OR REPLACE FUNCTION create_enrollment_with_schedules(
  p_user_id UUID,
  p_group_id UUID,
  p_program_id UUID,
  p_start_date TIMESTAMPTZ,
  p_enabled_days TEXT[],
  p_sms_time TEXT DEFAULT NULL,
  p_timezone TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_enrollment_id UUID;
  v_group RECORD;
  v_program RECORD;
  v_lesson RECORD;
  v_schedule_dates TIMESTAMPTZ[];
  v_current_date TIMESTAMPTZ;
  v_end_date TIMESTAMPTZ;
  v_day_of_week INT;
  v_enabled_day_numbers INT[];
  v_idx INT := 0;
  v_schedule_id UUID;
  v_first_lesson_date TIMESTAMPTZ;
  v_formatted_start TEXT;
  v_formatted_time TEXT;
BEGIN
  -- Convert enabled days to day numbers (0=Sun, 1=Mon, etc.)
  v_enabled_day_numbers := ARRAY(
    SELECT CASE day
      WHEN 'Sun' THEN 0
      WHEN 'Mon' THEN 1
      WHEN 'Tue' THEN 2
      WHEN 'Wed' THEN 3
      WHEN 'Thu' THEN 4
      WHEN 'Fri' THEN 5
      WHEN 'Sat' THEN 6
    END
    FROM unnest(p_enabled_days) AS day
  );

  -- Verify group exists and user is creator
  SELECT id, name INTO v_group
  FROM groups
  WHERE id = p_group_id
    AND creator_id = p_user_id
    AND is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Group not found or access denied';
  END IF;

  -- Get program with lesson count
  SELECT sp.id, sp.name, sp.description, sp.days, sp.cover_image_url,
         (SELECT COUNT(*) FROM lessons WHERE study_program_id = sp.id) as lesson_count
  INTO v_program
  FROM study_programs sp
  WHERE sp.id = p_program_id AND sp.is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Study program not found';
  END IF;

  -- Calculate schedule dates
  v_current_date := p_start_date;
  v_schedule_dates := ARRAY[]::TIMESTAMPTZ[];

  WHILE array_length(v_schedule_dates, 1) IS NULL OR array_length(v_schedule_dates, 1) < v_program.lesson_count LOOP
    v_day_of_week := EXTRACT(DOW FROM v_current_date)::INT;
    IF v_day_of_week = ANY(v_enabled_day_numbers) THEN
      v_schedule_dates := array_append(v_schedule_dates, v_current_date);
    END IF;
    v_current_date := v_current_date + INTERVAL '1 day';
  END LOOP;

  v_end_date := v_schedule_dates[array_length(v_schedule_dates, 1)];
  v_first_lesson_date := v_schedule_dates[1];

  -- Create enrollment
  v_enrollment_id := gen_random_uuid();
  INSERT INTO enrollments (id, group_id, study_program_id, start_date, end_date, enabled_days, sms_time, timezone, created_by_id, created_at, updated_at)
  VALUES (v_enrollment_id, p_group_id, p_program_id, p_start_date, v_end_date, array_to_json(p_enabled_days)::TEXT, p_sms_time, p_timezone, p_user_id, NOW(), NOW());

  -- Create lesson schedules and events
  v_idx := 1;
  FOR v_lesson IN
    SELECT id, day_number FROM lessons WHERE study_program_id = p_program_id ORDER BY day_number ASC
  LOOP
    v_schedule_id := gen_random_uuid();

    -- Create lesson schedule
    INSERT INTO lesson_schedules (id, enrollment_id, lesson_id, scheduled_date)
    VALUES (v_schedule_id, v_enrollment_id, v_lesson.id, v_schedule_dates[v_idx]);

    -- Create event for calendar
    INSERT INTO events (id, group_id, type, title, description, date, start_time, lesson_schedule_id, enrollment_id, day_number, is_active, created_at, updated_at)
    VALUES (gen_random_uuid(), p_group_id, 'LESSON', 'Day ' || v_lesson.day_number || ': ' || v_program.name, v_program.description, v_schedule_dates[v_idx], p_sms_time, v_schedule_id, v_enrollment_id, v_lesson.day_number, true, NOW(), NOW());

    v_idx := v_idx + 1;
  END LOOP;

  -- Format dates for welcome post
  v_formatted_start := TO_CHAR(v_first_lesson_date, 'Day, Month DD');
  v_formatted_time := COALESCE(
    TO_CHAR(TO_TIMESTAMP(p_sms_time, 'HH24:MI'), 'HH:MI AM'),
    'the scheduled time'
  );

  -- Create welcome post
  INSERT INTO posts (id, group_id, author_id, type, title, content, image_url, enrollment_id, is_active, created_at, updated_at)
  VALUES (
    gen_random_uuid(),
    p_group_id,
    p_user_id,
    'WELCOME',
    v_program.name || ' starts ' || v_formatted_start || '!',
    v_group.name || ' is beginning the ' || v_program.name || ' study program! Your first lesson link will be texted to you on ' || v_formatted_start || ' at ' || v_formatted_time || '. Get ready for ' || v_program.days || ' days of growth together!',
    v_program.cover_image_url,
    v_enrollment_id,
    true,
    NOW(),
    NOW()
  );

  -- Return enrollment summary
  RETURN jsonb_build_object(
    'id', v_enrollment_id,
    'groupId', p_group_id,
    'studyProgramId', p_program_id,
    'startDate', p_start_date,
    'endDate', v_end_date,
    'enabledDays', array_to_json(p_enabled_days),
    'smsTime', p_sms_time,
    'timezone', p_timezone,
    'createdAt', NOW(),
    'updatedAt', NOW(),
    'createdById', p_user_id,
    'lessonCount', v_program.lesson_count,
    'group', jsonb_build_object('id', p_group_id, 'name', v_group.name),
    'studyProgram', jsonb_build_object('id', p_program_id, 'name', v_program.name, 'days', v_program.days)
  );
END;
$$;
