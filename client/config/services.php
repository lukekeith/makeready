<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    'makeready' => [
        'url' => env('API_URL', 'https://api.makeready.org'),
        'ingest_key' => env('ACTIVITY_LOG_INGEST_KEY', ''),
        'verbose_logging' => env('VERBOSE_LOGGING', false),
    ],

    // Google OAuth for admin panel — token exchanged with API for user session
    'google' => [
        'client_id' => env('GOOGLE_CLIENT_ID'),
        'client_secret' => env('GOOGLE_CLIENT_SECRET'),
        'redirect' => env('GOOGLE_REDIRECT_URI', '/admin/auth/google/callback'),
    ],

    // Microsoft OAuth for beta onboarding.
    'microsoft' => [
        'client_id' => env('MICROSOFT_CLIENT_ID', env('AZURE_CLIENT_ID')),
        'client_secret' => env('MICROSOFT_CLIENT_SECRET', env('AZURE_CLIENT_SECRET')),
        'tenant' => env('MICROSOFT_TENANT_ID', env('AZURE_TENANT_ID', 'organizations')),
    ],

];
