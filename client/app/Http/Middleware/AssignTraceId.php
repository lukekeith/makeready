<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Assigns a per-request `traceId` so every log line emitted during the
 * request can be stitched back together. Threaded through `EventLogger`
 * and surfaced on responses as the `X-Trace-Id` header so the browser /
 * admin UI can copy-paste a value to scope its filters.
 *
 * Honours an inbound `X-Trace-Id` header — useful when a chain of services
 * wants a shared id (e.g. iPhone → API → Laravel).
 */
class AssignTraceId
{
    public function handle(Request $request, Closure $next): Response
    {
        $traceId = $request->header('X-Trace-Id');
        if (! $traceId || ! preg_match('/^[A-Za-z0-9_-]{6,64}$/', $traceId)) {
            $traceId = 'req_' . bin2hex(random_bytes(6));
        }

        $request->attributes->set('traceId', $traceId);
        app()->instance('trace.id', $traceId);

        $response = $next($request);
        $response->headers->set('X-Trace-Id', $traceId);
        return $response;
    }
}
