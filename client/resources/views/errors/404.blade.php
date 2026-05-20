{{-- resources/views/errors/404.blade.php --}}
{{-- Custom 404 Not Found — matches React NotFoundPage exactly --}}
@extends('layouts.auth')

@section('title', 'Page Not Found — MakeReady')

@section('content')
<div class="NotFoundPage">
    <span class="NotFoundPage__text">404</span>
</div>
@endsection
