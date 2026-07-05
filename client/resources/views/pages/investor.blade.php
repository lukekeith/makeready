{{-- resources/views/pages/investor.blade.php --}}
{{-- Public unlisted investor timeline. Data source: docs/future/timeline.json --}}
@extends('layouts.home')

@section('title', 'MakeReady — Development Timeline')
@section('description', 'MakeReady product development timeline and 12-month roadmap.')

@section('head')
    <meta name="robots" content="noindex, nofollow">
@endsection

@section('content')
    <div data-vue="InvestorTimeline"></div>
@endsection
