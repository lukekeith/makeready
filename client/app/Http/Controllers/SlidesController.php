<?php

namespace App\Http\Controllers;

use App\Services\ApiService;
use Illuminate\Http\Request;

class SlidesController extends Controller
{
    public function __construct(private ApiService $api)
    {
    }

    /**
     * Render the slides animation test bench.
     * Development only — not linked from any production page.
     */
    public function index()
    {
        return view('pages.slides');
    }

    /**
     * Proxy the public themes list from the Node API.
     * Avoids needing CORS / VITE_ env vars in the browser.
     */
    public function themes(Request $request)
    {
        $result = $this->api->get('/api/themes/public/list', $request);
        return response()->json($result['body'], $result['status']);
    }
}
