<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\BinaryFileResponse;
use Symfony\Component\HttpFoundation\Response;

/**
 * Dev-only controller that renders Blade pages with mock data for screenshot
 * capture. Reads JSON fixtures from client/capture/{workflow}/{screen}.json,
 * writes their session bag to the Laravel session, rewrites relative asset
 * paths (./foo.jpg) to asset URLs, and returns the real Blade view so the
 * layout, styles, and Vue islands render exactly as users see them.
 *
 * Routes are registered ONLY when app()->environment('local') is true —
 * never mount this in production.
 */
class CaptureController extends Controller
{
    private function captureBase(): string
    {
        // Check shell env, then .env, then convention (sibling capture repo)
        $envPath = getenv('CAPTURE_FIXTURES_PATH') ?: env('CAPTURE_FIXTURES_PATH');
        if ($envPath && is_dir($envPath)) {
            return $envPath;
        }

        // Convention: sibling capture repo at ../capture/fixtures/client
        $sibling = dirname(base_path()) . '/capture/fixtures/client';
        if (is_dir($sibling)) {
            return $sibling;
        }

        return base_path('capture');
    }

    /**
     * GET /_capture/{workflow}/{screen}
     */
    public function show(Request $request, string $workflow, string $screen): Response
    {
        if (! $this->isSafeSegment($workflow) || ! $this->isSafeSegment($screen)) {
            abort(400, 'Invalid capture path.');
        }

        $jsonPath = $this->captureBase() . "/{$workflow}/{$screen}.json";
        if (! file_exists($jsonPath)) {
            abort(404, "Capture JSON not found: {$workflow}/{$screen}.json");
        }

        $spec = json_decode(file_get_contents($jsonPath), true);
        if (! is_array($spec)) {
            abort(500, "Invalid JSON in {$workflow}/{$screen}.json");
        }

        $view = $spec['view'] ?? null;
        $path = $spec['path'] ?? null;
        $step = $spec['step'] ?? 'info';
        $data = $spec['data'] ?? [];

        if (! $view && ! $path) {
            abort(500, "Capture JSON missing required 'view' or 'path' field.");
        }

        $data = $this->rewriteAssets($data, $workflow);

        if (isset($data['session']) && is_array($data['session'])) {
            foreach ($data['session'] as $key => $value) {
                session()->put($key, $value);
            }
            unset($data['session']);
        }

        if ($path) {
            if (! is_string($path) || ! str_starts_with($path, '/') || str_starts_with($path, '//')) {
                abort(500, "Capture JSON contains an invalid 'path' field.");
            }
            session()->save();
            return redirect($path);
        }

        $routing = $this->routingDefaults($workflow, $step);
        $viewData = array_merge($routing, $data, ['step' => $step]);

        if (! isset($viewData['id'])) {
            $viewData['id'] = 'CAPTUR';
        }

        return response()->view($view, $viewData);
    }

    /**
     * GET /_capture/{workflow}/assets/{file}
     */
    public function asset(string $workflow, string $file): BinaryFileResponse
    {
        if (! $this->isSafeSegment($workflow) || ! $this->isSafeSegment($file)) {
            abort(400);
        }
        $path = $this->captureBase() . "/{$workflow}/{$file}";
        if (! file_exists($path)) {
            abort(404);
        }
        return response()->file($path);
    }

    private function rewriteAssets(mixed $value, string $workflow): mixed
    {
        if (is_string($value) && str_starts_with($value, './')) {
            $basename = ltrim(substr($value, 2), '/');
            return url("/_capture/{$workflow}/assets/{$basename}");
        }
        if (is_array($value)) {
            return array_map(fn ($v) => $this->rewriteAssets($v, $workflow), $value);
        }
        return $value;
    }

    /**
     * Technical view variables that the real controllers compute but the
     * capture JSON shouldn't have to carry (route URLs, privacy/terms links).
     */
    private function routingDefaults(string $workflow, string $step): array
    {
        $routeBase = [
            'join-group' => 'join.group',
            'join-study' => 'join.study',
            'join-event' => 'join.event',
        ][$workflow] ?? null;

        if (! $routeBase) {
            return [];
        }

        $fakeId = 'CAPTUR';
        if ($step === 'optin') {
            return [
                'id'         => $fakeId,
                'privacyUrl' => route('privacy'),
                'termsUrl'   => route('terms'),
            ];
        }
        if ($step === 'phone') {
            return [
                'ajaxSubmitUrl' => route("{$routeBase}.phone.submit", ['id' => $fakeId]),
            ];
        }
        if ($step === 'verify') {
            return [
                'ajaxVerifyUrl' => route("{$routeBase}.verify.submit", ['id' => $fakeId]),
            ];
        }
        return [];
    }

    private function isSafeSegment(string $segment): bool
    {
        return $segment !== ''
            && ! str_contains($segment, '/')
            && ! str_contains($segment, '\\')
            && ! str_contains($segment, '..');
    }
}
