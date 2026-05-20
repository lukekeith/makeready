<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Read-only API for the /admin/logs UI.
 *
 * Reads JSON Lines from `storage/logs/YYYY/MM/DD/app.log` for a date range
 * and applies in-memory filters. The dated tree means a single-day query
 * only opens one file, and a 30-day window opens at most 30 — small enough
 * to scan synchronously without paginating files.
 *
 * Returns the matched lines newest-first, plus a small `types` summary so
 * the filter UI can populate its type dropdown from real data.
 */
class LogsController extends Controller
{
    /** Maximum lines returned in a single page. */
    private const MAX_PAGE_SIZE = 500;

    /** Hard cap on day-files scanned per request to keep latency bounded. */
    private const MAX_DAYS = 60;

    public function index(Request $request): JsonResponse
    {
        $from = $this->parseDate($request->query('from')) ?? today();
        $to   = $this->parseDate($request->query('to'))   ?? today();
        if ($from->gt($to)) [$from, $to] = [$to, $from];

        // Clamp to MAX_DAYS to avoid runaway scans.
        if ($from->diffInDays($to) > self::MAX_DAYS) {
            $from = $to->copy()->subDays(self::MAX_DAYS);
        }

        $level   = strtolower((string) $request->query('level', 'all'));
        $type    = $request->query('type');
        $userId  = $request->query('userId');
        $groupId = $request->query('groupId');
        $traceId = $request->query('traceId');
        $q       = trim((string) $request->query('q', ''));
        $limit   = min(self::MAX_PAGE_SIZE, max(1, (int) $request->query('limit', 200)));
        $offset  = max(0, (int) $request->query('offset', 0));

        $matches = [];
        $typesSeen = [];
        $skipped = 0;

        // Walk dates newest-first so the page-1 result is always the latest events.
        $cursor = $to->copy();
        while ($cursor->gte($from)) {
            $path = $this->pathForDate($cursor);
            if (is_file($path)) {
                $this->scanFile($path, $level, $type, $userId, $groupId, $traceId, $q, $matches, $typesSeen, $limit, $offset, $skipped);
                if (count($matches) >= $limit) break;
            }
            $cursor->subDay();
        }

        ksort($typesSeen);

        return response()->json([
            'logs'     => $matches,
            'count'    => count($matches),
            'limit'    => $limit,
            'offset'   => $offset,
            'types'    => array_keys($typesSeen),
            'from'     => $from->toDateString(),
            'to'       => $to->toDateString(),
            'hasMore'  => count($matches) >= $limit,
        ]);
    }

    private function parseDate(?string $s): ?\Illuminate\Support\Carbon
    {
        if (! $s) return null;
        try { return \Illuminate\Support\Carbon::parse($s)->startOfDay(); }
        catch (\Throwable $_) { return null; }
    }

    private function pathForDate(\Illuminate\Support\Carbon $d): string
    {
        return storage_path('logs/' . $d->format('Y/m/d') . '/app.log');
    }

    /**
     * Stream `path` line by line, decoding JSON and applying the filters.
     * Newer events are appended at end-of-file, so we read top-to-bottom
     * then reverse-merge — cheaper than seeking from the tail.
     */
    private function scanFile(
        string $path,
        string $level,
        ?string $type,
        ?string $userId,
        ?string $groupId,
        ?string $traceId,
        string $q,
        array &$matches,
        array &$typesSeen,
        int $limit,
        int $offset,
        int &$skipped,
    ): void {
        $fh = @fopen($path, 'r');
        if (! $fh) return;

        $dayMatches = [];
        try {
            while (($line = fgets($fh)) !== false) {
                $line = rtrim($line, "\r\n");
                if ($line === '') continue;

                $event = json_decode($line, true);
                if (! is_array($event)) continue;

                if (isset($event['type'])) {
                    $typesSeen[(string) $event['type']] = true;
                }

                if ($level !== 'all' && ($event['level'] ?? '') !== $level) continue;
                if ($type    && ($event['type']    ?? '') !== $type)    continue;
                if ($traceId && ($event['traceId'] ?? '') !== $traceId) continue;
                if ($userId  && ($event['userId']  ?? '') !== $userId)  continue;
                if ($groupId && ($event['groupId'] ?? '') !== $groupId) continue;
                if ($q !== '' && stripos($line, $q) === false)          continue;

                $dayMatches[] = $event;
            }
        } finally {
            fclose($fh);
        }

        // Newest-first within this day's file.
        $dayMatches = array_reverse($dayMatches);

        foreach ($dayMatches as $event) {
            if ($skipped < $offset) {
                $skipped++;
                continue;
            }
            $matches[] = $event;
            if (count($matches) >= $limit) return;
        }
    }
}
