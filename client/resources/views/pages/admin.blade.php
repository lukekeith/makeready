{{-- resources/views/pages/admin.blade.php --}}
{{-- Admin page — mounts AdminIsland Vue app with island props --}}
@extends('layouts.admin')

@section('title', 'MakeReady Admin')

@section('content')
<div id="admin-island" data-vue="AdminIsland" data-props="{{ json_encode($islandProps) }}"></div>
@endsection
