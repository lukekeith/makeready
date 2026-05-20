<?php

namespace App\Logging;

use Monolog\Formatter\FormatterInterface;
use Monolog\LogRecord;

/**
 * Emits one JSON object per log line for the dated daily channel.
 *
 * Schema is intentionally flat (top-level keys: ts, level, type, route, …)
 * so the /admin/logs filter UI can match against any field with a single
 * substring or equality check. Anything caller-provided that doesn't fit
 * the known keys lands under `metadata`.
 */
class JsonLineFormatter implements FormatterInterface
{
    /** Top-level keys promoted out of the log context. */
    private const PROMOTED_KEYS = [
        'type', 'category', 'status', 'traceId',
        'route', 'method', 'ip', 'userAgent',
        'userId', 'memberId', 'groupId', 'eventId', 'enrollmentId',
        'lessonId', 'organizationId', 'errorMessage',
    ];

    public function format(LogRecord $record): string
    {
        $ctx = $record->context;

        $line = [
            'ts'    => $record->datetime->format('Y-m-d\TH:i:s.v\Z'),
            'level' => strtolower($record->level->getName()),
        ];

        foreach (self::PROMOTED_KEYS as $key) {
            if (array_key_exists($key, $ctx) && $ctx[$key] !== null) {
                $line[$key] = $ctx[$key];
            }
        }

        $line['message'] = $record->message;

        // Anything left in context (after stripping the promoted keys) goes
        // into `metadata`. Caller can also pass a literal `metadata` key —
        // that takes precedence for explicitly-shaped payloads.
        $remainder = array_diff_key($ctx, array_flip([...self::PROMOTED_KEYS, 'metadata', 'message']));
        $metadata = $ctx['metadata'] ?? null;
        if (is_array($metadata) && ! empty($remainder)) {
            $metadata = array_merge($remainder, $metadata);
        } elseif (! is_array($metadata)) {
            $metadata = ! empty($remainder) ? $remainder : null;
        }
        if ($metadata !== null && $metadata !== []) {
            $line['metadata'] = $metadata;
        }

        return json_encode($line, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) . "\n";
    }

    public function formatBatch(array $records): string
    {
        return implode('', array_map([$this, 'format'], $records));
    }
}
