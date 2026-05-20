@extends('layouts.app')

@section('title', 'Home - MakeReady')

@section('content')
<div class="HomePage">
    <h1 class="HomePage__heading">Welcome back{{ $member['firstName'] ? ', ' . $member['firstName'] : '' }}</h1>
    <p class="HomePage__subtext">Your groups and studies will appear here.</p>
</div>
@endsection
