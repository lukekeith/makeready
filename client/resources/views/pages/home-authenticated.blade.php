{{-- resources/views/pages/home-authenticated.blade.php --}}
{{-- Authenticated home page — shows member's groups or redirects to single group --}}
@extends('layouts.home')

@section('title', 'Home — MakeReady')

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
<div class="MemberHomePage">

    {{-- Scrollable content area --}}
    <div class="MemberHomePage__content">
        {{-- Groups List --}}
        <div class="MemberHomePage__groups-list">
            @if(count($groupList) > 0)
                @foreach($groupList as $group)
                    <a
                        href="{{ route('group.home', ['groupId' => $group['id']]) }}"
                        class="MemberHomePage__group-link"
                    >
                        <x-domain.group-card
                            :name="$group['name'] ?? ''"
                            :coverImageUrl="$group['coverImageUrl'] ?? null"
                            :isPrivate="$group['isPrivate'] ?? false"
                            :memberCount="$group['memberCount'] ?? 0"
                            :memberSince="$group['joinedAt'] ?? $group['createdAt'] ?? null"
                            showChevron="True"
                        />
                    </a>
                @endforeach
            @else
                <div class="MemberHomePage__empty-state">
                    <p class="MemberHomePage__empty-title">No groups yet</p>
                    <p class="MemberHomePage__empty-description">
                        Join a group to get started with your journey.
                    </p>
                </div>
            @endif
        </div>
    </div>

    {{-- Fixed Navigation — React renders inside MemberHomePage__navigation-container --}}
    <div class="MemberHomePage__navigation-container" data-vue="NavigationIsland" data-props="{{ json_encode([
        'selected'         => 'home',
        'avatarUrl'        => $member['profilePicture'] ?? $member['avatarUrl'] ?? null,
        'initials'         => $initials ?? '?',
        'homeHref'         => route('home'),
        'profileHref'      => route('profile'),
        'memberName'       => ($member['firstName'] ?? '') . ' ' . ($member['lastName'] ?? ''),
        'memberPhone'      => format_phone($member['phoneNumber'] ?? $member['phone'] ?? null),
        'memberFirstName'  => $member['firstName'] ?? '',
        'memberLastName'   => $member['lastName'] ?? '',
        'memberGender'     => $member['gender'] ?? '',
        'memberBirthday'   => $member['birthday'] ?? '',
        'memberId'         => $member['id'] ?? '',
        'googleEmail'      => $member['googleEmail'] ?? null,
        'googlePicture'    => $member['googlePicture'] ?? $member['profilePicture'] ?? null,
        'logoutUrl'        => route('logout'),
        'csrfToken'        => csrf_token(),
    ], JSON_HEX_TAG) }}"></div>

</div>{{-- /.MemberHomePage --}}
@endsection
