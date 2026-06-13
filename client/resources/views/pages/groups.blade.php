{{-- resources/views/pages/groups.blade.php --}}
{{-- Groups list page — full list of member's groups (no single-group redirect) --}}
@extends('layouts.home')

@section('title', 'Groups — MakeReady')

@php
    $initials = '';
    if (!empty($member['firstName'])) {
        $initials .= strtoupper(substr($member['firstName'], 0, 1));
    }
    if (!empty($member['lastName'])) {
        $initials .= strtoupper(substr($member['lastName'], 0, 1));
    }
    if ($initials === '') {
        $initials = '?';
    }
@endphp

@section('content')
<main class="GroupsPage">
    <div class="GroupsPage__content">
        <x-panel.page-title title="Groups" />

        <div class="GroupsPage__list">
            @if(count($groupList) > 0)
                @foreach($groupList as $group)
                    <a
                        href="{{ route('group.home', ['groupId' => $group['id']]) }}"
                        class="GroupsPage__group-link"
                    >
                        <x-domain.group-list-card
                            interactive="True"
                            :name="$group['name'] ?? ''"
                            :memberCount="$group['memberCount'] ?? 0"
                            :imageUrl="$group['avatarUrl'] ?? null"
                        />
                    </a>
                @endforeach
            @else
                <x-primitive.empty-state
                    title="No groups yet"
                    description="You haven't joined any groups. Use a join code to get started."
                />
            @endif
        </div>
    </div>
</main>
@endsection
