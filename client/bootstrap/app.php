<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        // Trust Railway's reverse proxy so URL generation uses HTTPS
        $middleware->trustProxies(at: '*');

        // Exclude API session cookies from Laravel's encryption so they pass through unmodified.
        $middleware->encryptCookies(except: [
            'makeready_session',
            'connect.sid',
            'mr_preview_device',
        ]);

        // Stamp every request with a traceId so EventLogger can stitch a
        // sequence of events for one request together. Surfaces as the
        // X-Trace-Id response header.
        $middleware->append(\App\Http\Middleware\AssignTraceId::class);

        // Register auth middleware alias for protected routes
        $middleware->alias([
            'member.auth' => \App\Http\Middleware\CheckMemberSession::class,
            'admin.auth' => \App\Http\Middleware\CheckAdminSession::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        // Funnel unhandled exceptions through EventLogger so they land in the
        // dated JSON-Lines log alongside SUCCESS/FAILURE events. Returning
        // false would suppress Laravel's default reporting; we want both, so
        // we just record an extra structured line.
        $exceptions->report(function (\Throwable $e): void {
            $request = request();
            if (! $request) return;
            try {
                app(\App\Services\EventLogger::class)->logFailure(
                    'SYSTEM_UNHANDLED_EXCEPTION',
                    $request,
                    [
                        'message'      => 'Unhandled exception: ' . get_class($e),
                        'errorMessage' => $e->getMessage(),
                        'metadata'     => [
                            'exception' => get_class($e),
                            'file'      => $e->getFile(),
                            'line'      => $e->getLine(),
                        ],
                    ]
                );
            } catch (\Throwable $_) {
                // Logging must never break the app — swallow.
            }
        });
    })->create();
