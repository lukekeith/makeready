<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class CheckAdminSession
{
    public function handle(Request $request, Closure $next): Response
    {
        if (!session('admin_user_session')) {
            return redirect('/admin/login');
        }

        return $next($request);
    }
}
