<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Http;

/**
 * Proxy controller for the admin Vue app to reach the external API.
 *
 * Uses the user's own API session (obtained via Google OAuth token exchange)
 * stored in the Laravel server session. All responses are scoped to the
 * authenticated user — no shared keys, no cross-user data leakage.
 */
class AdminApiProxyController extends Controller
{
    private string $baseUrl;

    public function __construct()
    {
        $this->baseUrl = config('services.makeready.url');
    }

    public function handle(Request $request, string $path): JsonResponse|Response
    {
        $sessionId = session('admin_user_session');

        if (!$sessionId) {
            return response()->json([
                'success' => false,
                'error' => 'Admin session not established. Sign in with Google.',
                'requiresAuth' => true,
            ], 401);
        }

        $endpoint = $this->baseUrl . '/api/' . $path;
        if ($request->getQueryString()) {
            $endpoint .= '?' . $request->getQueryString();
        }

        $headers = [
            'Cookie' => 'connect.sid=' . $sessionId,
            'Accept' => 'application/json',
        ];

        // Export endpoints return binary (ZIP) — stream through without JSON parsing
        if (str_ends_with($path, '/export') && strtolower($request->method()) === 'post') {
            return $this->apiStreamBinary($endpoint, $headers);
        }

        $result = match (strtolower($request->method())) {
            'get'    => $this->apiGet($endpoint, $headers),
            'post'   => $this->apiPost($request, $endpoint, $headers),
            'patch',
            'put'    => $this->apiPatch($request, $endpoint, $headers),
            'delete' => $this->apiDelete($endpoint, $headers),
            default  => ['status' => 405, 'body' => ['error' => 'Method Not Allowed']],
        };

        // If the API says not authenticated, clear the stale session
        if ($result['status'] === 401) {
            session()->forget(['admin_user_session', 'admin_user']);
            $result['body']['requiresAuth'] = true;
        }

        return response()->json($result['body'], $result['status']);
    }

    private function apiGet(string $url, array $headers): array
    {
        $response = Http::withHeaders($headers)->get($url);
        return ['status' => $response->status(), 'body' => $response->json()];
    }

    private function apiPost(Request $request, string $url, array $headers): array
    {
        // Handle file uploads — check common field names
        $fileField = null;
        foreach (['image', 'file', 'avatar'] as $field) {
            if ($request->hasFile($field)) {
                $fileField = $field;
                break;
            }
        }

        if ($fileField) {
            $file = $request->file($fileField);
            $response = Http::withHeaders([
                'Cookie' => $headers['Cookie'],
                'Accept' => 'application/json',
            ])->attach($fileField, $file->getContent(), $file->getClientOriginalName())
              ->post($url);
        } else {
            $response = Http::withHeaders(array_merge($headers, [
                'Content-Type' => 'application/json',
            ]))->post($url, $request->json()->all() ?? []);
        }

        return ['status' => $response->status(), 'body' => $response->json()];
    }

    private function apiStreamBinary(string $url, array $headers): JsonResponse|Response
    {
        $response = Http::withHeaders([
            'Cookie' => $headers['Cookie'],
        ])->withOptions(['stream' => true])->post($url);

        if ($response->status() !== 200) {
            return response()->json(
                $response->json() ?? ['error' => 'Export failed'],
                $response->status()
            );
        }

        $contentType = $response->header('Content-Type') ?? 'application/zip';
        $contentDisposition = $response->header('Content-Disposition') ?? 'attachment; filename="export.zip"';

        return response($response->body(), 200, [
            'Content-Type' => $contentType,
            'Content-Disposition' => $contentDisposition,
        ]);
    }

    private function apiPatch(Request $request, string $url, array $headers): array
    {
        $response = Http::withHeaders(array_merge($headers, [
            'Content-Type' => 'application/json',
        ]))->patch($url, $request->json()->all() ?? []);

        return ['status' => $response->status(), 'body' => $response->json()];
    }

    private function apiDelete(string $url, array $headers): array
    {
        $response = Http::withHeaders($headers)->delete($url);
        return ['status' => $response->status(), 'body' => $response->json()];
    }
}
