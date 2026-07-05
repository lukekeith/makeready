{{-- resources/views/pages/leader.blade.php --}}
{{-- Mobile-web leader app — mounts the LeaderApp Vue island with island props. --}}
@extends('layouts.leader')

@section('title', 'MakeReady')

@section('content')
<div id="leader-app" data-vue="LeaderApp" data-props="{{ json_encode($islandProps) }}"></div>
@endsection
