<?php

namespace App\Http\Controllers;

use App\Services\ApiService;
use App\Services\EventLogger;
use App\Services\ActivityTypes;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

class EventJoinController extends Controller
{
    public function __construct(
        private ApiService $api,
        private EventLogger $log,
    ) {}

    /**
     * GET /join/event — show the enter-code page for events.
     */
    public function showEnterCode(): Response
    {
        return response()->view('pages.event-code');
    }

    /**
     * Determine if the identifier is a 6-character join code (vs a full ID).
     */
    private function isCode(string $id): bool
    {
        return strlen($id) === 6;
    }

    /**
     * GET /join/event/{id}/{step?} — render the appropriate event join step.
     */
    public function showStep(Request $request, string $id, ?string $step = null): Response|\Illuminate\Http\RedirectResponse
    {
        $step = $step ?? 'info';

        $validSteps = ['info', 'optin', 'phone', 'verify', 'confirmed'];
        if (! in_array($step, $validSteps)) {
            return redirect()->route('join.event', ['id' => $id]);
        }

        $viewData   = ['id' => $id, 'step' => $step];
        $setCookies = [];

        switch ($step) {
            case 'info':
                $endpoint = $this->isCode($id)
                    ? "/api/events/code/{$id}"
                    : "/api/events/{$id}";
                $result     = $this->api->get($endpoint, $request);
                $setCookies = $result['setCookies'];

                if ($result['status'] !== 200) {
                    $viewData['error'] = $result['body']['message'] ?? 'Event not found.';
                    $viewData['event'] = null;
                    $this->log->logFailure(ActivityTypes::JOIN_EVENT_URL_ACCESSED, $request, [
                        'message' => "Event code lookup failed: {$id}", 'errorMessage' => $viewData['error'],
                        'metadata' => ['code' => $id],
                    ]);
                    break;
                }

                $event = $result['body']['event'] ?? [];
                session()->put("event.{$id}.eventId", $event['id'] ?? null);
                session()->put("event.{$id}.organizationId", $event['organizationId'] ?? null);
                session()->put("event.{$id}.eventName", $event['name'] ?? $event['title'] ?? '');
                $viewData['event'] = $event;
                $this->log->logSuccess(ActivityTypes::JOIN_EVENT_URL_ACCESSED, $request, [
                    'message' => "Event join URL accessed: " . ($event['name'] ?? $event['title'] ?? $id),
                    'eventId' => $event['id'] ?? null,
                    'metadata' => ['code' => $id, 'eventName' => $event['name'] ?? $event['title'] ?? null],
                ]);
                break;

            case 'optin':
                if (! session()->has("event.{$id}.eventId")) {
                    return redirect()->route('join.event', ['id' => $id]);
                }
                $viewData['privacyUrl'] = route('privacy');
                $viewData['termsUrl']   = route('terms');
                break;

            case 'phone':
                if (! session()->get("event.{$id}.optinDone")) {
                    return redirect()->route('join.event', ['id' => $id, 'step' => 'optin']);
                }
                $viewData['ajaxSubmitUrl'] = route('join.event.phone.submit', ['id' => $id]);
                break;

            case 'verify':
                if (! session()->has("event.{$id}.phone")) {
                    return redirect()->route('join.event', ['id' => $id, 'step' => 'phone']);
                }
                $viewData['ajaxVerifyUrl'] = route('join.event.verify.submit', ['id' => $id]);
                $viewData['phone']         = session("event.{$id}.phone");
                break;

            case 'confirmed':
                $viewData['eventId']   = session("event.{$id}.eventId");
                $viewData['eventName'] = session("event.{$id}.eventName", '');
                break;
        }

        $response = response()->view('pages.join-event', $viewData);

        foreach ($setCookies as $cookie) {
            $response->headers->set('Set-Cookie', $cookie, false);
        }

        return $response;
    }

    /**
     * POST /join/event/{id}/optin — record SMS consent and advance to phone step.
     */
    public function submitOptin(Request $request, string $id): \Illuminate\Http\RedirectResponse
    {
        if (! session()->has("event.{$id}.eventId")) {
            return redirect()->route('join.event', ['id' => $id]);
        }

        // SMS consent is OPTIONAL and must not block joining (Twilio A2P). Record
        // the member's actual choice and advance either way.
        session()->put("event.{$id}.smsConsent", $request->boolean('smsConsent'));
        session()->put("event.{$id}.optinDone", true);
        $this->log->logSuccess(ActivityTypes::JOIN_EVENT_OPTIN_SUBMITTED, $request, [
            'message' => 'SMS consent ' . ($request->boolean('smsConsent') ? 'given' : 'declined') . " for event join: {$id}",
            'eventId' => session("event.{$id}.eventId"),
        ]);

        return redirect()->route('join.event', ['id' => $id, 'step' => 'phone']);
    }

    /**
     * POST /join/event/{id}/phone — AJAX: send SMS verification and return redirectUrl.
     */
    public function submitPhone(Request $request, string $id): JsonResponse
    {
        // Twilio Verify OTP is transactional (separate from the A2P campaign), so
        // it does not require SMS marketing consent — only that the member passed
        // through the opt-in step.
        if (! session()->get("event.{$id}.optinDone")) {
            return response()->json(['error' => 'Please start from the beginning of the join flow.'], 422);
        }

        $phone = $request->input('phoneNumber', '');
        session()->put("event.{$id}.phone", $phone);

        $organizationId = session("event.{$id}.organizationId");

        $result = $this->api->post('/api/members/verify-phone', [
            'phoneNumber'    => $phone,
            'organizationId' => $organizationId,
        ], $request);

        if ($result['status'] !== 200) {
            $error = $result['body']['message'] ?? 'Failed to send verification code. Please try again.';
            $this->log->logFailure(ActivityTypes::JOIN_EVENT_PHONE_FAILED, $request, [
                'message' => "SMS send failed for event join: {$id}", 'eventId' => session("event.{$id}.eventId"),
                'errorMessage' => $error, 'metadata' => ['phoneLast4' => EventLogger::maskPhone($phone)],
            ]);
            return response()->json(['error' => $error], 422);
        }

        $this->log->logSuccess(ActivityTypes::JOIN_EVENT_PHONE_SUBMITTED, $request, [
            'message' => "SMS sent for event join: {$id}", 'eventId' => session("event.{$id}.eventId"),
            'metadata' => ['phoneLast4' => EventLogger::maskPhone($phone)],
        ]);

        $response = response()->json([
            'redirectUrl' => route('join.event', ['id' => $id, 'step' => 'verify']),
        ]);

        foreach ($result['setCookies'] as $cookie) {
            $response->headers->set('Set-Cookie', $cookie, false);
        }

        return $response;
    }

    /**
     * POST /join/event/{id}/verify — AJAX: confirm verification, register attendance, return redirectUrl.
     */
    public function submitVerify(Request $request, string $id): JsonResponse
    {
        $phone          = session("event.{$id}.phone");
        $organizationId = session("event.{$id}.organizationId");
        $eventId        = session("event.{$id}.eventId");

        $confirmResult = $this->api->post('/api/members/confirm-verification', [
            'phoneNumber'    => $phone,
            'code'           => $request->input('code'),
            'organizationId' => $organizationId,
            'smsConsent'     => session("event.{$id}.smsConsent", false),
        ], $request);

        if ($confirmResult['status'] !== 200) {
            $error = $confirmResult['body']['message'] ?? 'Verification failed. Please try again.';
            $this->log->logFailure(ActivityTypes::JOIN_EVENT_VERIFY_FAILED, $request, [
                'message' => "Verification failed for event join: {$id}", 'eventId' => $eventId,
                'errorMessage' => $error, 'metadata' => ['phoneLast4' => EventLogger::maskPhone($phone)],
            ]);
            return response()->json(['error' => $error], 422);
        }

        $this->log->logSuccess(ActivityTypes::JOIN_EVENT_VERIFY_SUBMITTED, $request, [
            'message' => "Verification succeeded for event join: {$id}", 'eventId' => $eventId,
            'metadata' => ['phoneLast4' => EventLogger::maskPhone($phone)],
        ]);

        // Register event attendance now that the member is verified/authenticated.
        $attendResult = $this->api->post("/api/events/{$eventId}/attend", [], $request);

        // Clear event session data on successful completion.
        session()->forget("event.{$id}");

        $response = response()->json([
            'redirectUrl' => route('join.event', ['id' => $id, 'step' => 'confirmed']),
        ]);

        foreach ($confirmResult['setCookies'] as $cookie) {
            $response->headers->set('Set-Cookie', $cookie, false);
        }
        foreach ($attendResult['setCookies'] as $cookie) {
            $response->headers->set('Set-Cookie', $cookie, false);
        }

        return $response;
    }
}
