<?php

namespace App\Http\Controllers;

use App\Services\ApiService;
use App\Services\EventLogger;
use App\Services\ActivityTypes;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

class StudyJoinController extends Controller
{
    public function __construct(
        private ApiService $api,
        private EventLogger $log,
    ) {}

    /**
     * Determine if the identifier is a 6-character join code (vs a full ID).
     */
    private function isCode(string $id): bool
    {
        return strlen($id) === 6;
    }

    /**
     * GET /join/study/{id}/{step?} — render the appropriate study join step.
     */
    public function showStep(Request $request, string $id, ?string $step = null): Response|\Illuminate\Http\RedirectResponse
    {
        $step = $step ?? 'info';

        $validSteps = ['info', 'optin', 'phone', 'verify', 'confirmed'];
        if (! in_array($step, $validSteps)) {
            return redirect()->route('join.study', ['id' => $id]);
        }

        $viewData   = ['id' => $id, 'step' => $step];
        $setCookies = [];

        switch ($step) {
            case 'info':
                $endpoint = $this->isCode($id)
                    ? "/api/lessons/code/{$id}"
                    : "/api/lessons/view/{$id}";
                $result     = $this->api->get($endpoint, $request);
                $setCookies = $result['setCookies'];

                if ($result['status'] !== 200) {
                    $viewData['error']  = $result['body']['message'] ?? 'Study not found.';
                    $viewData['lesson'] = null;
                    $this->log->logFailure(ActivityTypes::JOIN_STUDY_URL_ACCESSED, $request, [
                        'message' => "Study code lookup failed: {$id}", 'errorMessage' => $viewData['error'],
                        'metadata' => ['code' => $id],
                    ]);
                    break;
                }

                $lesson = $result['body']['lesson'] ?? [];
                session()->put("study.{$id}.lessonId", $lesson['id'] ?? null);
                session()->put("study.{$id}.organizationId", $lesson['organizationId'] ?? null);
                $viewData['lesson'] = $lesson;
                $this->log->logSuccess(ActivityTypes::JOIN_STUDY_URL_ACCESSED, $request, [
                    'message' => "Study join URL accessed: {$id}",
                    'lessonId' => $lesson['id'] ?? null,
                    'metadata' => ['code' => $id],
                ]);
                break;

            case 'optin':
                if (! session()->has("study.{$id}.lessonId")) {
                    return redirect()->route('join.study', ['id' => $id]);
                }
                $viewData['privacyUrl'] = route('privacy');
                $viewData['termsUrl']   = route('terms');
                break;

            case 'phone':
                if (! session()->get("study.{$id}.optinDone")) {
                    return redirect()->route('join.study', ['id' => $id, 'step' => 'optin']);
                }
                $viewData['ajaxSubmitUrl'] = route('join.study.phone.submit', ['id' => $id]);
                break;

            case 'verify':
                if (! session()->has("study.{$id}.phone")) {
                    return redirect()->route('join.study', ['id' => $id, 'step' => 'phone']);
                }
                $viewData['ajaxVerifyUrl'] = route('join.study.verify.submit', ['id' => $id]);
                $viewData['phone']         = session("study.{$id}.phone");
                break;

            case 'confirmed':
                $viewData['lessonId'] = session("study.{$id}.lessonId");
                break;
        }

        $response = response()->view('pages.join-study', $viewData);

        foreach ($setCookies as $cookie) {
            $response->headers->set('Set-Cookie', $cookie, false);
        }

        return $response;
    }

    /**
     * POST /join/study/{id}/optin — record SMS consent and advance to phone step.
     */
    public function submitOptin(Request $request, string $id): \Illuminate\Http\RedirectResponse
    {
        if (! session()->has("study.{$id}.lessonId")) {
            return redirect()->route('join.study', ['id' => $id]);
        }

        // SMS consent is OPTIONAL and must not block joining (Twilio A2P). Record
        // the member's actual choice and advance either way.
        session()->put("study.{$id}.smsConsent", $request->boolean('smsConsent'));
        session()->put("study.{$id}.optinDone", true);
        $this->log->logSuccess(ActivityTypes::JOIN_STUDY_OPTIN_SUBMITTED, $request, [
            'message' => 'SMS consent ' . ($request->boolean('smsConsent') ? 'given' : 'declined') . " for study join: {$id}",
            'lessonId' => session("study.{$id}.lessonId"),
        ]);

        return redirect()->route('join.study', ['id' => $id, 'step' => 'phone']);
    }

    /**
     * POST /join/study/{id}/phone — AJAX: send SMS verification and return redirectUrl.
     */
    public function submitPhone(Request $request, string $id): JsonResponse
    {
        // Twilio Verify OTP is transactional (separate from the A2P campaign), so
        // it does not require SMS marketing consent — only that the member passed
        // through the opt-in step.
        if (! session()->get("study.{$id}.optinDone")) {
            return response()->json(['error' => 'Please start from the beginning of the join flow.'], 422);
        }

        $phone = $request->input('phoneNumber', '');
        session()->put("study.{$id}.phone", $phone);

        $organizationId = session("study.{$id}.organizationId");

        $result = $this->api->post('/api/members/verify-phone', [
            'phoneNumber'    => $phone,
            'organizationId' => $organizationId,
        ], $request);

        if ($result['status'] !== 200) {
            $error = $result['body']['error'] ?? $result['body']['message'] ?? 'Failed to send verification code. Please try again.';
            $this->log->logFailure(ActivityTypes::JOIN_STUDY_PHONE_FAILED, $request, [
                'message' => "SMS send failed for study join: {$id}", 'lessonId' => session("study.{$id}.lessonId"),
                'errorMessage' => $error, 'metadata' => ['phoneLast4' => EventLogger::maskPhone($phone)],
            ]);
            return response()->json(['error' => $error], 422);
        }

        $this->log->logSuccess(ActivityTypes::JOIN_STUDY_PHONE_SUBMITTED, $request, [
            'message' => "SMS sent for study join: {$id}", 'lessonId' => session("study.{$id}.lessonId"),
            'metadata' => ['phoneLast4' => EventLogger::maskPhone($phone)],
        ]);

        $response = response()->json([
            'redirectUrl' => route('join.study', ['id' => $id, 'step' => 'verify']),
        ]);

        foreach ($result['setCookies'] as $cookie) {
            $response->headers->set('Set-Cookie', $cookie, false);
        }

        return $response;
    }

    /**
     * POST /join/study/{id}/verify — AJAX: confirm verification and return redirectUrl.
     */
    public function submitVerify(Request $request, string $id): JsonResponse
    {
        $phone          = session("study.{$id}.phone");
        $organizationId = session("study.{$id}.organizationId");

        $confirmResult = $this->api->post('/api/members/confirm-verification', [
            'phoneNumber'    => $phone,
            'code'           => $request->input('code'),
            'organizationId' => $organizationId,
            'smsConsent'     => session("study.{$id}.smsConsent", false),
        ], $request);

        if ($confirmResult['status'] !== 200) {
            $error = $confirmResult['body']['message'] ?? 'Verification failed. Please try again.';
            $this->log->logFailure(ActivityTypes::JOIN_STUDY_VERIFY_FAILED, $request, [
                'message' => "Verification failed for study join: {$id}", 'lessonId' => session("study.{$id}.lessonId"),
                'errorMessage' => $error, 'metadata' => ['phoneLast4' => EventLogger::maskPhone($phone)],
            ]);
            return response()->json(['error' => $error], 422);
        }

        $this->log->logSuccess(ActivityTypes::JOIN_STUDY_VERIFY_SUBMITTED, $request, [
            'message' => "Verification succeeded for study join: {$id}",
            'lessonId' => session("study.{$id}.lessonId"),
            'metadata' => ['phoneLast4' => EventLogger::maskPhone($phone)],
        ]);

        $response = response()->json([
            'redirectUrl' => route('join.study', ['id' => $id, 'step' => 'confirmed']),
        ]);

        foreach ($confirmResult['setCookies'] as $cookie) {
            $response->headers->set('Set-Cookie', $cookie, false);
        }

        return $response;
    }
}
