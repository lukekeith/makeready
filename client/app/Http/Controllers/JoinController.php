<?php

namespace App\Http\Controllers;

use App\Services\ApiService;
use App\Services\EventLogger;
use App\Services\ActivityTypes;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

class JoinController extends Controller
{
    public function __construct(
        private ApiService $api,
        private EventLogger $log,
    ) {}

    /**
     * GET /join — show the enter-code page.
     */
    public function showEnterCode(): Response
    {
        return response()->view('pages.join-code');
    }

    /**
     * POST /join — redirect to the group info step with the submitted code.
     */
    public function submitCode(Request $request): \Illuminate\Http\RedirectResponse
    {
        $code = strtoupper(trim($request->input('code', '')));

        return redirect()->route('join.group', ['id' => $code]);
    }

    /**
     * Determine if the identifier is a 6-character join code (vs a full ID).
     */
    private function isCode(string $id): bool
    {
        return strlen($id) === 6;
    }

    /**
     * GET /join/group/{id}/{step?} — render the appropriate join step.
     */
    public function showStep(Request $request, string $id, ?string $step = null): Response|\Illuminate\Http\RedirectResponse
    {
        $step = $step ?? 'info';

        $validSteps = ['info', 'optin', 'profile', 'phone', 'verify', 'confirmed'];
        if (! in_array($step, $validSteps)) {
            return redirect()->route('join.group', ['id' => $id]);
        }

        $viewData = ['id' => $id, 'step' => $step];
        $setCookies = [];

        switch ($step) {
            case 'info':
                $endpoint = $this->isCode($id)
                    ? "/api/groups/code/{$id}"
                    : "/api/groups/{$id}/public";
                $result = $this->api->get($endpoint, $request);
                $setCookies = $result['setCookies'];

                if ($result['status'] !== 200) {
                    $viewData['error'] = $result['body']['message'] ?? 'Group not found.';
                    $viewData['group'] = null;
                    $this->log->logFailure(ActivityTypes::JOIN_GROUP_URL_ACCESSED, $request, [
                        'message'      => "Group code lookup failed: {$id}",
                        'errorMessage' => $viewData['error'],
                        'metadata'     => ['code' => $id],
                    ]);
                    break;
                }

                $group = $result['body']['group'] ?? [];
                session()->put("join.{$id}.groupId", $group['id'] ?? null);
                session()->put("join.{$id}.organizationId", $group['organizationId'] ?? null);
                $viewData['group'] = $group;
                $this->log->logSuccess(ActivityTypes::JOIN_GROUP_URL_ACCESSED, $request, [
                    'message'  => "Join URL accessed for group: " . ($group['name'] ?? $id),
                    'groupId'  => $group['id'] ?? null,
                    'metadata' => ['code' => $id, 'groupName' => $group['name'] ?? null],
                ]);
                break;

            case 'optin':
                // Bootstrap session if the reviewer (or anyone) visits the
                // optin step directly without going through the info step.
                if (! session()->has("join.{$id}.groupId")) {
                    $endpoint = $this->isCode($id)
                        ? "/api/groups/code/{$id}"
                        : "/api/groups/{$id}/public";
                    $result = $this->api->get($endpoint, $request);
                    $setCookies = $result['setCookies'];

                    if ($result['status'] !== 200) {
                        return redirect()->route('join.group', ['id' => $id]);
                    }

                    $group = $result['body']['group'] ?? [];
                    session()->put("join.{$id}.groupId", $group['id'] ?? null);
                    session()->put("join.{$id}.organizationId", $group['organizationId'] ?? null);
                }
                $viewData['privacyUrl'] = route('privacy');
                $viewData['termsUrl']   = route('terms');
                break;

            case 'profile':
                if (! session()->has("join.{$id}.groupId")) {
                    return redirect()->route('join.group', ['id' => $id]);
                }
                $viewData['firstName'] = session("join.{$id}.firstName", '');
                $viewData['lastName']  = session("join.{$id}.lastName", '');
                $viewData['gender']    = session("join.{$id}.gender", '');
                $viewData['birthday']  = session("join.{$id}.birthday", '');
                break;

            case 'phone':
                if (! session()->has("join.{$id}.groupId")) {
                    return redirect()->route('join.group', ['id' => $id]);
                }
                if (! session()->get("join.{$id}.optinDone")) {
                    return redirect()->route('join.group', ['id' => $id, 'step' => 'optin']);
                }
                $viewData['ajaxSubmitUrl'] = route('join.group.phone.submit', ['id' => $id]);
                break;

            case 'verify':
                if (! session()->has("join.{$id}.phone")) {
                    return redirect()->route('join.group', ['id' => $id, 'step' => 'phone']);
                }
                $viewData['ajaxVerifyUrl'] = route('join.group.verify.submit', ['id' => $id]);
                $viewData['phone']         = session("join.{$id}.phone");
                break;

            case 'confirmed':
                $groupId = session("join.{$id}.groupId");
                if ($groupId) {
                    $result = $this->api->get("/api/groups/{$groupId}/public", $request);
                    $setCookies = $result['setCookies'];
                    $viewData['group'] = $result['body']['group'] ?? [];
                } else {
                    $viewData['group'] = [];
                }
                $viewData['membershipStatus'] = session("join.{$id}.membershipStatus", 'pending_new');
                $viewData['member']           = session("join.{$id}.member");
                $this->log->logSuccess(ActivityTypes::JOIN_GROUP_CONFIRMED, $request, [
                    'message'  => "Join confirmed page viewed for group: " . ($viewData['group']['name'] ?? $id),
                    'groupId'  => $groupId,
                    'metadata' => [
                        'code'             => $id,
                        'membershipStatus' => $viewData['membershipStatus'],
                        'firstName'        => session("join.{$id}.firstName"),
                        'lastName'         => session("join.{$id}.lastName"),
                        'phoneLast4'       => EventLogger::maskPhone(session("join.{$id}.phone")),
                    ],
                ]);
                break;
        }

        $response = response()->view('pages.join-group', $viewData);

        foreach ($setCookies as $cookie) {
            $response->headers->set('Set-Cookie', $cookie, false);
        }

        return $response;
    }

    /**
     * POST /join/group/{id}/info — advance from info to opt-in step.
     */
    public function submitInfo(Request $request, string $id): \Illuminate\Http\RedirectResponse
    {
        return redirect()->route('join.group', ['id' => $id, 'step' => 'optin']);
    }

    /**
     * POST /join/group/{id}/optin — record SMS consent and advance to profile step.
     */
    public function submitOptin(Request $request, string $id): \Illuminate\Http\RedirectResponse
    {
        if (! session()->has("join.{$id}.groupId")) {
            return redirect()->route('join.group', ['id' => $id]);
        }

        // SMS consent is OPTIONAL and must not block joining (Twilio A2P: consent
        // cannot be a prerequisite to proceed). Record the member's actual choice
        // and advance either way.
        session()->put("join.{$id}.smsConsent", $request->boolean('smsConsent'));
        session()->put("join.{$id}.optinDone", true);

        $this->log->logSuccess(ActivityTypes::JOIN_GROUP_OPTIN_SUBMITTED, $request, [
            'message' => 'SMS consent ' . ($request->boolean('smsConsent') ? 'given' : 'declined') . " for group join: {$id}",
            'groupId' => session("join.{$id}.groupId"),
            'metadata' => ['code' => $id],
        ]);

        return redirect()->route('join.group', ['id' => $id, 'step' => 'profile']);
    }

    /**
     * POST /join/group/{id}/profile — store profile data and advance to phone step.
     */
    public function submitProfile(Request $request, string $id): \Illuminate\Http\RedirectResponse
    {
        $firstName = $request->input('first_name', '');
        $lastName  = $request->input('last_name', '');
        $gender    = $request->input('gender', '');

        session()->put("join.{$id}.firstName", $firstName);
        session()->put("join.{$id}.lastName", $lastName);
        session()->put("join.{$id}.gender", $gender);
        session()->put("join.{$id}.birthday", $request->input('birthday', ''));

        $this->log->logSuccess(ActivityTypes::JOIN_GROUP_PROFILE_SUBMITTED, $request, [
            'message' => "Profile submitted: {$firstName} {$lastName}",
            'groupId' => session("join.{$id}.groupId"),
            'metadata' => ['code' => $id, 'firstName' => $firstName, 'lastName' => $lastName, 'gender' => $gender],
        ]);

        return redirect()->route('join.group', ['id' => $id, 'step' => 'phone']);
    }

    /**
     * POST /join/group/{id}/phone — AJAX: send SMS verification and return redirectUrl.
     */
    public function submitPhone(Request $request, string $id): JsonResponse
    {
        // Phone verification uses Twilio Verify (transactional OTP), which is
        // separate from the A2P marketing campaign — so it does not require SMS
        // marketing consent. The member must have passed through the opt-in step.
        if (! session()->get("join.{$id}.optinDone")) {
            return response()->json(['error' => 'Please start from the beginning of the join flow.'], 422);
        }

        $phone = $request->input('phoneNumber', '');
        session()->put("join.{$id}.phone", $phone);

        $organizationId = session("join.{$id}.organizationId");

        $result = $this->api->post('/api/members/verify-phone', [
            'phoneNumber'    => $phone,
            'organizationId' => $organizationId,
        ], $request);

        if ($result['status'] !== 200) {
            $error = $result['body']['error'] ?? $result['body']['message'] ?? 'Failed to send verification code. Please try again.';
            $this->log->logFailure(ActivityTypes::JOIN_GROUP_PHONE_FAILED, $request, [
                'message'      => "SMS send failed for group join: {$id}",
                'groupId'      => session("join.{$id}.groupId"),
                'errorMessage' => $error,
                'metadata'     => ['code' => $id, 'phoneLast4' => EventLogger::maskPhone($phone)],
            ]);
            return response()->json(['error' => $error], 422);
        }

        $this->log->logSuccess(ActivityTypes::JOIN_GROUP_PHONE_SUBMITTED, $request, [
            'message' => "SMS verification sent for group join: {$id}",
            'groupId' => session("join.{$id}.groupId"),
            'metadata' => ['code' => $id, 'phoneLast4' => EventLogger::maskPhone($phone)],
        ]);

        $response = response()->json([
            'redirectUrl' => route('join.group', ['id' => $id, 'step' => 'verify']),
        ]);

        foreach ($result['setCookies'] as $cookie) {
            $response->headers->set('Set-Cookie', $cookie, false);
        }

        return $response;
    }

    /**
     * POST /join/group/{id}/verify — AJAX: confirm verification, submit join request, return redirectUrl.
     */
    public function submitVerify(Request $request, string $id): JsonResponse
    {
        $phone          = session("join.{$id}.phone");
        $firstName      = session("join.{$id}.firstName");
        $lastName       = session("join.{$id}.lastName");
        $gender         = session("join.{$id}.gender");
        $birthday       = session("join.{$id}.birthday");
        $organizationId = session("join.{$id}.organizationId");
        $groupId        = session("join.{$id}.groupId");

        $payload = [
            'phoneNumber'    => $phone,
            'code'           => $request->input('code'),
            'organizationId' => $organizationId,
            'firstName'      => $firstName,
            'lastName'       => $lastName,
            'gender'         => $gender,
            'smsConsent'     => session("join.{$id}.smsConsent", false),
            'groupId'        => $groupId,
        ];

        // API expects ISO 8601 datetime; form submits YYYY-MM-DD. Omit when empty.
        if (! empty($birthday)) {
            $payload['birthday'] = strlen($birthday) === 10
                ? $birthday.'T00:00:00.000Z'
                : $birthday;
        }

        $confirmResult = $this->api->post('/api/members/confirm-verification', $payload, $request);

        if ($confirmResult['status'] !== 200) {
            $error = $confirmResult['body']['message'] ?? 'Verification failed. Please try again.';
            $this->log->logFailure(ActivityTypes::JOIN_GROUP_VERIFY_FAILED, $request, [
                'message'      => "Verification failed for group join: {$id}",
                'groupId'      => $groupId,
                'errorMessage' => $error,
                'metadata'     => [
                    'code'       => $id,
                    'phoneLast4' => EventLogger::maskPhone($phone),
                    'firstName'  => $firstName,
                    'lastName'   => $lastName,
                ],
            ]);
            return response()->json(['error' => $error], 422);
        }

        // Resolve membership status from the API response so the confirmed
        // step can render the right screen (request submitted vs request
        // pending vs already a member). See _join-confirmed.blade.php.
        $body          = $confirmResult['body'] ?? [];
        $joinRequest   = $body['joinRequest']   ?? null;
        $member        = $body['data']          ?? null;
        $alreadyMember = (bool) ($body['alreadyMember'] ?? false);
        $wasNewRequest = (bool) ($body['wasNewRequest'] ?? false);

        $membershipStatus = match (true) {
            $alreadyMember || $joinRequest === null         => 'member',
            ($joinRequest['status'] ?? '') === 'approved'   => 'approved',
            $wasNewRequest === false                        => 'pending_duplicate',
            default                                         => 'pending_new',
        };

        session()->put("join.{$id}.membershipStatus", $membershipStatus);
        session()->put("join.{$id}.member", $member);

        $this->log->logSuccess(ActivityTypes::JOIN_GROUP_VERIFY_SUBMITTED, $request, [
            'message' => "Verification + join request succeeded: {$firstName} {$lastName} → group {$id} ({$membershipStatus})",
            'groupId' => $groupId,
            'metadata' => [
                'code'             => $id,
                'phoneLast4'       => EventLogger::maskPhone($phone),
                'firstName'        => $firstName,
                'lastName'         => $lastName,
                'membershipStatus' => $membershipStatus,
                'joinRequest'      => $joinRequest,
            ],
        ]);

        $response = response()->json([
            'redirectUrl' => route('join.group', ['id' => $id, 'step' => 'confirmed']),
        ]);

        foreach ($confirmResult['setCookies'] as $cookie) {
            $response->headers->set('Set-Cookie', $cookie, false);
        }

        return $response;
    }
}
