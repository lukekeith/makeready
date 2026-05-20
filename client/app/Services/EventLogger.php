<?php

namespace App\Services;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

/**
 * Writes structured events as JSON Lines to the `dated` log channel —
 * `storage/logs/YYYY/MM/DD/app.log`.
 *
 * Verbose flag (LOG_VERBOSE):
 *   - true  → logSuccess() / logActivity() write at INFO level
 *   - false → only logWarning() and logFailure() are persisted; INFO drops
 *
 * Replaces the prior ActivityLogService (which POSTed to a Node ingest).
 */
class EventLogger
{
    private bool $verbose;

    public function __construct()
    {
        $this->verbose = (bool) env('LOG_VERBOSE', false);
    }

    public function logSuccess(string $activityType, Request $request, array $context = []): void
    {
        if (! $this->verbose) return;
        $this->emit('info', 'SUCCESS', $activityType, $request, $context);
    }

    public function logWarning(string $activityType, Request $request, array $context = []): void
    {
        $this->emit('warning', 'WARNING', $activityType, $request, $context);
    }

    public function logFailure(string $activityType, Request $request, array $context = []): void
    {
        $this->emit('error', 'FAILURE', $activityType, $request, $context);
    }

    /**
     * Mask a phone number to show only the last 4 digits.
     * Kept here for back-compat with existing callers (`EventLogger::maskPhone`).
     */
    public static function maskPhone(?string $phone): string
    {
        if (! $phone || strlen($phone) < 4) {
            return '****';
        }
        return '***' . substr($phone, -4);
    }

    private function emit(string $level, string $status, string $activityType, Request $request, array $context): void
    {
        $message = $context['message'] ?? '';
        unset($context['message']);

        $payload = [
            'type'     => $activityType,
            'category' => $this->resolveCategory($activityType),
            'status'   => $status,
            'traceId'  => $request->attributes->get('traceId'),
            'route'    => '/' . ltrim($request->path(), '/'),
            'method'   => $request->method(),
            'ip'       => $request->ip(),
            'userAgent'=> substr($request->userAgent() ?? '', 0, 500),
        ];

        // Promoted context keys (caller-provided) override the defaults.
        foreach (['userId', 'memberId', 'groupId', 'eventId', 'enrollmentId', 'lessonId', 'organizationId', 'errorMessage', 'metadata'] as $key) {
            if (array_key_exists($key, $context)) {
                $payload[$key] = $context[$key];
                unset($context[$key]);
            }
        }

        // Anything still in $context (unknown keys) gets folded into metadata.
        if (! empty($context)) {
            $payload['metadata'] = array_merge($context, $payload['metadata'] ?? []);
        }

        Log::channel('dated')->{$level}($message, $payload);
    }

    private function resolveCategory(string $activityType): string
    {
        if (str_starts_with($activityType, 'AUTH_'))   return 'AUTH';
        if (str_starts_with($activityType, 'JOIN_'))   return 'JOIN';
        if (str_starts_with($activityType, 'SYSTEM_')) return 'SYSTEM';
        return 'ACCESS';
    }
}
