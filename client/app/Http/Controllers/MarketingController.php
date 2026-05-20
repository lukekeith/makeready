<?php

namespace App\Http\Controllers;

use App\Services\ApiService;
use App\Services\MarketingContentService;
use Illuminate\Http\Request;
use Illuminate\View\View;

class MarketingController extends Controller
{
    public function __construct(
        private ApiService $api,
        private MarketingContentService $content,
    ) {}

    public function home(Request $request): View
    {
        return view('pages.marketing.home', [
            'content' => $this->content->load('home'),
            'faqs' => $this->faqs('home', $request),
        ]);
    }

    public function leaders(Request $request): View
    {
        return view('pages.marketing.for-leaders', [
            'content' => $this->content->load('for-leaders'),
            'faqs' => $this->faqs('for-leaders', $request),
        ]);
    }

    public function members(Request $request): View
    {
        return view('pages.marketing.for-members', [
            'content' => $this->content->load('for-members'),
            'faqs' => $this->faqs('for-members', $request),
        ]);
    }

    public function about(Request $request): View
    {
        return view('pages.marketing.about', [
            'content' => $this->content->load('about'),
            'faqs' => $this->faqs('about', $request),
        ]);
    }

    private function faqs(string $scope, Request $request): array
    {
        $result = $this->api->get('/public/faqs/' . rawurlencode($scope), $request);

        if ($result['status'] !== 200 || !($result['body']['success'] ?? false)) {
            return [];
        }

        return $result['body']['faqs'] ?? [];
    }
}
