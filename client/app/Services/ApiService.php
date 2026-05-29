<?php

namespace App\Services;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;

class ApiService
{
    private string $baseUrl;
    private EventLogger $log;

    public function __construct()
    {
        // Prefer internal Railway URL for server-to-server calls (bypasses Cloudflare)
        $this->baseUrl = env('API_INTERNAL_URL') ?: config('services.makeready.url');
        $this->log = app(EventLogger::class);
    }

    /**
     * Build the standard headers forwarded to the API on every request.
     *
     * Includes X-Forwarded-Proto so Express honours its `secure` cookie flag
     * even when the Laravel → API call travels over Railway's internal HTTP
     * network. Without this header Express sees req.secure = false and refuses
     * to set the connect.sid session cookie in production.
     */
    private function apiHeaders(Request $request): array
    {
        return [
            'Cookie'            => $this->extractApiCookies($request),
            'Content-Type'      => 'application/json',
            'Accept'            => 'application/json',
            'User-Agent'        => $request->userAgent() ?: 'MakeReady-Client/1.0',
            'X-Forwarded-Proto' => $request->isSecure() ? 'https' : 'http',
        ];
    }

    /**
     * Make an API GET request, forwarding browser cookies.
     *
     * Returns an array with:
     *   - 'status'     int     HTTP status code from API
     *   - 'body'       mixed   Decoded JSON response body
     *   - 'setCookies' array   All Set-Cookie header values from API response
     *
     * NOTE on cookie forwarding: We forward the full Cookie header from the
     * browser request. This works because Laravel's EncryptCookies middleware
     * is configured to exclude API session cookies from encryption (see
     * bootstrap/app.php). TODO: Once the actual API cookie name is confirmed
     * via inspection of a live login response, narrow this to forward only the
     * specific API session cookie rather than the entire Cookie string, to
     * avoid sending Laravel's own encrypted cookies to the external API
     * (see RESEARCH.md Pitfall 6).
     */
    public function get(string $endpoint, Request $request): array
    {
        $start = microtime(true);
        try {
            $response = Http::timeout(10)->withHeaders($this->apiHeaders($request))
                ->get("{$this->baseUrl}{$endpoint}");

            $body = $response->json() ?? [];
            $this->logApiCall('GET', $endpoint, [], $request, $response->status(), $body, $start);
            return [
                'status'     => $response->status(),
                'body'       => $body,
                'setCookies' => $this->extractSetCookies($response),
            ];
        } catch (\Exception $e) {
            \Log::error("ApiService GET {$endpoint} failed: " . $e->getMessage());
            $this->logApiCall('GET', $endpoint, [], $request, 0, [], $start, $e->getMessage());
            return [
                'status'     => 500,
                'body'       => ['error' => 'API request failed', 'message' => $e->getMessage()],
                'setCookies' => [],
            ];
        }
    }

    /**
     * Make an API POST request, forwarding browser cookies.
     *
     * Returns an array with:
     *   - 'status'     int     HTTP status code from API
     *   - 'body'       mixed   Decoded JSON response body
     *   - 'setCookies' array   All Set-Cookie header values from API response
     */
    public function post(string $endpoint, array $data, Request $request, array $extraSetCookies = []): array
    {
        $start = microtime(true);
        try {
            $headers = $this->apiHeaders($request);

            // Merge Set-Cookie values from a prior API call so the second
            // request in a chain (e.g. confirm-verification → join-request)
            // carries the session cookie that was just issued.
            if (! empty($extraSetCookies)) {
                $headers['Cookie'] = $this->mergeCookies($headers['Cookie'], $extraSetCookies);
            }

            $response = Http::timeout(10)->withHeaders($headers)
                ->post("{$this->baseUrl}{$endpoint}", $data);

            $body = $response->json() ?? [];
            $this->logApiCall('POST', $endpoint, $data, $request, $response->status(), $body, $start);
            return [
                'status'     => $response->status(),
                'body'       => $body,
                'setCookies' => $this->extractSetCookies($response),
            ];
        } catch (\Exception $e) {
            \Log::error("ApiService POST {$endpoint} failed: " . $e->getMessage());
            $this->logApiCall('POST', $endpoint, $data, $request, 0, [], $start, $e->getMessage());
            return [
                'status'     => 500,
                'body'       => ['error' => 'API request failed', 'message' => $e->getMessage()],
                'setCookies' => [],
            ];
        }
    }

    /**
     * Make an API PATCH request, forwarding browser cookies.
     *
     * Returns an array with:
     *   - 'status'     int     HTTP status code from API
     *   - 'body'       mixed   Decoded JSON response body
     *   - 'setCookies' array   All Set-Cookie header values from API response
     */
    public function patch(string $endpoint, array $data, Request $request): array
    {
        $start = microtime(true);
        try {
            $response = Http::timeout(10)->withHeaders($this->apiHeaders($request))
                ->patch("{$this->baseUrl}{$endpoint}", $data);

            $body = $response->json() ?? [];
            $this->logApiCall('PATCH', $endpoint, $data, $request, $response->status(), $body, $start);
            return [
                'status'     => $response->status(),
                'body'       => $body,
                'setCookies' => $this->extractSetCookies($response),
            ];
        } catch (\Exception $e) {
            \Log::error("ApiService PATCH {$endpoint} failed: " . $e->getMessage());
            $this->logApiCall('PATCH', $endpoint, $data, $request, 0, [], $start, $e->getMessage());
            return [
                'status'     => 500,
                'body'       => ['error' => 'API request failed', 'message' => $e->getMessage()],
                'setCookies' => [],
            ];
        }
    }

    /**
     * Make an API DELETE request, forwarding browser cookies.
     *
     * Returns an array with:
     *   - 'status'     int     HTTP status code from API
     *   - 'body'       mixed   Decoded JSON response body
     *   - 'setCookies' array   All Set-Cookie header values from API response
     */
    public function delete(string $endpoint, Request $request): array
    {
        $start = microtime(true);
        try {
            $response = Http::timeout(10)->withHeaders($this->apiHeaders($request))
                ->delete("{$this->baseUrl}{$endpoint}");

            $body = $response->json() ?? [];
            $this->logApiCall('DELETE', $endpoint, [], $request, $response->status(), $body, $start);
            return [
                'status'     => $response->status(),
                'body'       => $body,
                'setCookies' => $this->extractSetCookies($response),
            ];
        } catch (\Exception $e) {
            \Log::error("ApiService DELETE {$endpoint} failed: " . $e->getMessage());
            $this->logApiCall('DELETE', $endpoint, [], $request, 0, [], $start, $e->getMessage());
            return [
                'status'     => 500,
                'body'       => ['error' => 'API request failed', 'message' => $e->getMessage()],
                'setCookies' => [],
            ];
        }
    }

    /**
     * Upload a file via multipart/form-data, forwarding browser cookies.
     *
     * Returns an array with:
     *   - 'status'     int     HTTP status code from API
     *   - 'body'       mixed   Decoded JSON response body
     *   - 'setCookies' array   All Set-Cookie header values from API response
     */
    public function upload(string $endpoint, string $fileKey, \Illuminate\Http\UploadedFile $file, Request $request): array
    {
        $start = microtime(true);
        $fileMeta = [
            'fileKey'  => $fileKey,
            'fileName' => $file->getClientOriginalName(),
            'mimeType' => $file->getMimeType(),
            'size'     => $file->getSize(),
        ];
        try {
            $uploadHeaders = $this->apiHeaders($request);
            unset($uploadHeaders['Content-Type']); // Let HTTP client set multipart boundary
            $response = Http::timeout(30)->withHeaders($uploadHeaders)
                ->attach($fileKey, $file->getContent(), $file->getClientOriginalName())
              ->post("{$this->baseUrl}{$endpoint}");

            $body = $response->json() ?? [];
            $this->logApiCall('UPLOAD', $endpoint, $fileMeta, $request, $response->status(), $body, $start);
            return [
                'status'     => $response->status(),
                'body'       => $body,
                'setCookies' => $this->extractSetCookies($response),
            ];
        } catch (\Exception $e) {
            \Log::error("ApiService UPLOAD {$endpoint} failed: " . $e->getMessage());
            $this->logApiCall('UPLOAD', $endpoint, $fileMeta, $request, 0, [], $start, $e->getMessage());
            return [
                'status'     => 500,
                'body'       => ['error' => 'API request failed', 'message' => $e->getMessage()],
                'setCookies' => [],
            ];
        }
    }

    /**
     * Single funnel for ApiService log lines. Records the route, HTTP method,
     * elapsed time, redacted request payload, and a truncated response body.
     *
     * Successes log at info level (gated by LOG_VERBOSE); transport exceptions
     * (passed via $exceptionMessage) and any non-2xx status log at error level.
     * Sensitive fields are masked or replaced with `***` — see redact() below.
     */
    private function logApiCall(
        string $method,
        string $endpoint,
        array $requestData,
        Request $request,
        int $status,
        array $responseBody,
        float $startedAt,
        ?string $exceptionMessage = null,
    ): void {
        $durationMs = (int) round((microtime(true) - $startedAt) * 1000);
        $isFailure = $exceptionMessage !== null || $status === 0 || $status >= 400;

        $redactedRequest  = $this->redact($requestData);
        $redactedResponse = $this->summariseResponse($responseBody);

        $context = [
            'message'  => "API {$method} {$endpoint} → " . ($status > 0 ? $status : 'EXCEPTION')
                        . " ({$durationMs}ms)",
            'metadata' => [
                'apiMethod'     => $method,
                'apiEndpoint'   => $endpoint,
                'apiStatus'     => $status,
                'apiDurationMs' => $durationMs,
                'apiRequest'    => $redactedRequest,
                'apiResponse'   => $redactedResponse,
            ],
        ];

        if ($exceptionMessage !== null) {
            $context['errorMessage'] = $exceptionMessage;
        } elseif ($isFailure && isset($responseBody['message'])) {
            $context['errorMessage'] = (string) $responseBody['message'];
        }

        if ($isFailure) {
            $this->log->logFailure(ActivityTypes::ACCESS_API_REQUEST, $request, $context);
        } else {
            $this->log->logSuccess(ActivityTypes::ACCESS_API_REQUEST, $request, $context);
        }
    }

    /**
     * Sensitive keys masked entirely. Phone numbers are masked to last-4 via
     * EventLogger::maskPhone. Comparison is case-insensitive on key names.
     */
    private const REDACT_KEYS = [
        'password', 'token', 'idtoken', 'secret', 'authorization', 'bearer',
        'apikey', 'accesstoken', 'refreshtoken', 'sessionid', 'cookie',
        'code', // SMS verification codes
    ];

    private function redact(mixed $value): mixed
    {
        if (! is_array($value)) return $value;

        $out = [];
        foreach ($value as $k => $v) {
            $kl = strtolower((string) $k);
            if ($kl === 'phonenumber' || $kl === 'phone') {
                $out[$k] = is_string($v) ? EventLogger::maskPhone($v) : $v;
            } elseif (in_array($kl, self::REDACT_KEYS, true)) {
                $out[$k] = '***';
            } elseif (is_array($v)) {
                $out[$k] = $this->redact($v);
            } else {
                $out[$k] = $v;
            }
        }
        return $out;
    }

    /**
     * Truncate large response bodies so a single log line stays scannable.
     * Lists with > 20 items keep the first 20 entries plus a `_truncated` marker.
     */
    private const MAX_RESPONSE_BYTES = 2000;

    private function summariseResponse(array $body): array
    {
        $redacted = $this->redact($body);

        // List-shaped responses: cap at 20 items.
        if (array_is_list($redacted) && count($redacted) > 20) {
            $redacted = array_merge(array_slice($redacted, 0, 20), [
                ['_truncated' => true, '_totalItems' => count($redacted)],
            ]);
        }

        $json = json_encode($redacted);
        if ($json !== false && strlen($json) > self::MAX_RESPONSE_BYTES) {
            return [
                '_truncated' => true,
                '_totalBytes' => strlen($json),
                '_preview'   => substr($json, 0, self::MAX_RESPONSE_BYTES),
            ];
        }
        return $redacted;
    }

    /**
     * Extract ALL Set-Cookie headers from an API response.
     *
     * The Http facade's ->header('Set-Cookie') returns only the first value
     * because Symfony's HeaderBag::get() collapses multi-value headers.
     * We use ->headers() to access the underlying PSR-7 response and retrieve
     * every Set-Cookie header individually via Guzzle's header collection,
     * which preserves multiple values.
     *
     * @param  \Illuminate\Http\Client\Response  $response
     * @return string[]
     */
    private function extractSetCookies(\Illuminate\Http\Client\Response $response): array
    {
        $psrResponse = $response->toPsrResponse();
        $cookies = $psrResponse->getHeader('Set-Cookie');

        // In local development (non-HTTPS), strip the Secure flag from API cookies
        // so the browser will send them back over HTTP.
        if (app()->environment('local') || !request()->isSecure()) {
            $cookies = array_map(function (string $cookie) {
                return preg_replace('/;\s*Secure/i', '', $cookie);
            }, $cookies);
        }

        return $cookies;
    }

    /**
     * Extract only API-relevant cookies from the browser request.
     *
     * Laravel's EncryptCookies middleware decrypts Laravel cookies before
     * the request reaches controllers, but the raw Cookie header still
     * contains the original (encrypted) Laravel cookies. Forwarding ALL
     * cookies to the API can cause issues — we allowlist only the cookies
     * the API needs: connect.sid (session) and mr_preview_device (preview
     * device-locking).
     */
    private function extractApiCookies(Request $request): string
    {
        $raw = $request->header('Cookie', '');
        $pairs = [];

        // Cookies the backend API needs — add new names here as needed
        $allowlist = ['connect.sid', 'mr_preview_device'];

        foreach (explode(';', $raw) as $segment) {
            $segment = trim($segment);
            if ($segment === '') continue;

            $eqPos = strpos($segment, '=');
            $name  = $eqPos !== false ? substr($segment, 0, $eqPos) : $segment;

            if (in_array($name, $allowlist, true)) {
                $value = $eqPos !== false ? substr($segment, $eqPos + 1) : '';
                $pairs[] = $name . '=' . urldecode($value);
            }
        }

        return implode('; ', $pairs);
    }

    /**
     * Merge Set-Cookie header values into an existing Cookie header string.
     *
     * Parses name=value from each Set-Cookie line and overrides matching
     * names already in the Cookie header. This lets a second API call in
     * a chain carry the session cookie that the first call just issued
     * (e.g. confirm-verification returns a new connect.sid that the
     * subsequent join-request call needs).
     */
    private function mergeCookies(string $cookieHeader, array $setCookies): string
    {
        // Parse existing cookie header into name→value map
        $cookies = [];
        foreach (explode(';', $cookieHeader) as $segment) {
            $segment = trim($segment);
            if ($segment === '') continue;
            $eqPos = strpos($segment, '=');
            if ($eqPos !== false) {
                $cookies[substr($segment, 0, $eqPos)] = substr($segment, $eqPos + 1);
            }
        }

        // Extract name=value from each Set-Cookie header (ignore attributes after first ;)
        foreach ($setCookies as $setCookie) {
            $parts = explode(';', $setCookie, 2);
            $nameValue = trim($parts[0]);
            $eqPos = strpos($nameValue, '=');
            if ($eqPos !== false) {
                $cookies[substr($nameValue, 0, $eqPos)] = substr($nameValue, $eqPos + 1);
            }
        }

        $pairs = [];
        foreach ($cookies as $name => $value) {
            $pairs[] = "{$name}={$value}";
        }
        return implode('; ', $pairs);
    }
}
