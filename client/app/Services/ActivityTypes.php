<?php

namespace App\Services;

/**
 * Activity type constants used by EventLogger to avoid magic strings in
 * controllers. Names mirror the server-side `activity-types.ts` for
 * historical reasons; the values are now persisted to local JSON-Lines
 * log files (storage/logs/YYYY/MM/DD/app.log).
 */
class ActivityTypes
{
    // ── AUTH ──────────────────────────────────────────────────────────────────
    const AUTH_MEMBER_LOGIN_PHONE_SUBMITTED = 'AUTH_MEMBER_LOGIN_PHONE_SUBMITTED';
    const AUTH_MEMBER_LOGIN_VERIFIED        = 'AUTH_MEMBER_LOGIN_VERIFIED';
    const AUTH_MEMBER_LOGIN_FAILED          = 'AUTH_MEMBER_LOGIN_FAILED';
    const AUTH_MEMBER_LOGOUT                = 'AUTH_MEMBER_LOGOUT';
    const AUTH_SESSION_CHECK_FAILED         = 'AUTH_SESSION_CHECK_FAILED';
    const AUTH_ADMIN_OAUTH_INITIATED        = 'AUTH_ADMIN_OAUTH_INITIATED';
    const AUTH_ADMIN_OAUTH_COMPLETED        = 'AUTH_ADMIN_OAUTH_COMPLETED';
    const AUTH_ADMIN_OAUTH_FAILED           = 'AUTH_ADMIN_OAUTH_FAILED';

    // ── JOIN: Group ──────────────────────────────────────────────────────────
    const JOIN_GROUP_URL_ACCESSED       = 'JOIN_GROUP_URL_ACCESSED';
    const JOIN_GROUP_INFO_VIEWED        = 'JOIN_GROUP_INFO_VIEWED';
    const JOIN_GROUP_OPTIN_SUBMITTED    = 'JOIN_GROUP_OPTIN_SUBMITTED';
    const JOIN_GROUP_PROFILE_SUBMITTED  = 'JOIN_GROUP_PROFILE_SUBMITTED';
    const JOIN_GROUP_PHONE_SUBMITTED    = 'JOIN_GROUP_PHONE_SUBMITTED';
    const JOIN_GROUP_PHONE_FAILED       = 'JOIN_GROUP_PHONE_FAILED';
    const JOIN_GROUP_VERIFY_SUBMITTED   = 'JOIN_GROUP_VERIFY_SUBMITTED';
    const JOIN_GROUP_VERIFY_FAILED      = 'JOIN_GROUP_VERIFY_FAILED';
    const JOIN_GROUP_CONFIRMED          = 'JOIN_GROUP_CONFIRMED';

    // ── JOIN: Event ──────────────────────────────────────────────────────────
    const JOIN_EVENT_URL_ACCESSED       = 'JOIN_EVENT_URL_ACCESSED';
    const JOIN_EVENT_OPTIN_SUBMITTED    = 'JOIN_EVENT_OPTIN_SUBMITTED';
    const JOIN_EVENT_PHONE_SUBMITTED    = 'JOIN_EVENT_PHONE_SUBMITTED';
    const JOIN_EVENT_PHONE_FAILED       = 'JOIN_EVENT_PHONE_FAILED';
    const JOIN_EVENT_VERIFY_SUBMITTED   = 'JOIN_EVENT_VERIFY_SUBMITTED';
    const JOIN_EVENT_VERIFY_FAILED      = 'JOIN_EVENT_VERIFY_FAILED';
    const JOIN_EVENT_CONFIRMED          = 'JOIN_EVENT_CONFIRMED';

    // ── JOIN: Study ──────────────────────────────────────────────────────────
    const JOIN_STUDY_URL_ACCESSED       = 'JOIN_STUDY_URL_ACCESSED';
    const JOIN_STUDY_OPTIN_SUBMITTED    = 'JOIN_STUDY_OPTIN_SUBMITTED';
    const JOIN_STUDY_PHONE_SUBMITTED    = 'JOIN_STUDY_PHONE_SUBMITTED';
    const JOIN_STUDY_PHONE_FAILED       = 'JOIN_STUDY_PHONE_FAILED';
    const JOIN_STUDY_VERIFY_SUBMITTED   = 'JOIN_STUDY_VERIFY_SUBMITTED';
    const JOIN_STUDY_VERIFY_FAILED      = 'JOIN_STUDY_VERIFY_FAILED';
    const JOIN_STUDY_CONFIRMED          = 'JOIN_STUDY_CONFIRMED';

    // ── ACCESS ───────────────────────────────────────────────────────────────
    const ACCESS_DASHBOARD_VIEWED       = 'ACCESS_DASHBOARD_VIEWED';
    const ACCESS_GROUP_HOME_VIEWED      = 'ACCESS_GROUP_HOME_VIEWED';
    const ACCESS_STUDY_HOME_VIEWED      = 'ACCESS_STUDY_HOME_VIEWED';
    const ACCESS_LESSON_STARTED         = 'ACCESS_LESSON_STARTED';
    const ACCESS_NOTE_SUBMITTED         = 'ACCESS_NOTE_SUBMITTED';
    const ACCESS_VIDEO_PROGRESS_SAVED   = 'ACCESS_VIDEO_PROGRESS_SAVED';
    const ACCESS_PROFILE_UPDATED        = 'ACCESS_PROFILE_UPDATED';
    const ACCESS_AVATAR_UPLOADED        = 'ACCESS_AVATAR_UPLOADED';
    const ACCESS_API_ERROR              = 'ACCESS_API_ERROR';
    const ACCESS_API_REQUEST            = 'ACCESS_API_REQUEST';
}
