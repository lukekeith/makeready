{{-- resources/views/pages/profile.blade.php --}}
{{-- Member profile view and edit page --}}
@extends('layouts.home')

@section('title', 'Profile — MakeReady')

@php
    $firstName = $member['firstName'] ?? '';
    $lastName  = $member['lastName'] ?? '';
    $gender    = $member['gender'] ?? '';
    $birthday  = $member['birthday'] ?? '';
    $avatarUrl = $member['profilePicture'] ?? $member['avatarUrl'] ?? null;

    $initials = '';
    if ($firstName) {
        $initials .= strtoupper(substr($firstName, 0, 1));
    }
    if ($lastName) {
        $initials .= strtoupper(substr($lastName, 0, 1));
    }
    if ($initials === '') {
        $initials = '?';
    }
@endphp

@section('content')
{{-- Root class: ProfilePage (matches React ProfilePage) --}}
<div class="ProfilePage">

    {{-- Header — React renders PageTitleLinkTitleLink with "Edit profile", Cancel, Save --}}
    <x-panel.page-title
        title="Edit profile"
        leftLink="Cancel"
        :leftHref="url()->previous()"
        :leftLinkMuted="true"
        rightLink="Save"
        :rightLinkWhite="true"
        rightHref="#save-profile"
        :rightLinkDisabled="false"
    />

    {{-- Form Content — React renders as <div class="ProfilePage__content"> --}}
    <form
        method="POST"
        action="{{ route('profile.update') }}"
        enctype="multipart/form-data"
        id="save-profile"
        class="ProfilePage__content"
    >
        @csrf

        {{-- Flash messages (server-side only — not in React SPA) --}}
        @if(session('success'))
            <div class="ProfilePage__flash ProfilePage__flash--success">
                {{ session('success') }}
            </div>
        @endif
        @if(session('error'))
            <div class="ProfilePage__flash ProfilePage__flash--error">
                {{ session('error') }}
            </div>
        @endif

        {{-- Avatar Upload — React renders as <button class="ProfilePage__avatar-button"> --}}
        <label
            for="avatar-input"
            class="ProfilePage__avatar-button"
            aria-label="Change profile picture"
        >
            <x-primitive.avatar
                :src="$avatarUrl"
                :fallback="$initials"
                :alt="$firstName . ' ' . $lastName"
                :size="210"
                class="ProfilePage__avatar"
            />
        </label>

        {{-- Hidden file input — React uses <input type="file" class="ProfilePage__file-input"> --}}
        <input
            id="avatar-input"
            type="file"
            name="avatar"
            accept="image/*"
            class="ProfilePage__file-input"
            onchange="this.form.submit()"
        />

        {{-- Avatar actions — React renders <div class="ProfilePage__avatar-actions"> --}}
        <div class="ProfilePage__avatar-actions">
            {{-- Google sync placeholder — only shown when member has email (not tracked in Blade session) --}}
        </div>

        {{-- Profile Form — React renders <ProfileForm> component --}}
        <x-domain.profile-form
            :firstName="old('first_name', $firstName)"
            :lastName="old('last_name', $lastName)"
            :gender="old('gender', $gender)"
            :birthday="old('birthday', $birthday)"
            :showSuccessMessage="false"
        />

        @if($errors->any())
            <div class="ProfilePage__errors">
                @foreach($errors->all() as $error)
                    <p class="ProfilePage__error-item">{{ $error }}</p>
                @endforeach
            </div>
        @endif

        {{-- Hidden submit — form submits via Save link or avatar change --}}
        <button type="submit" class="ProfilePage__save-hidden" style="display:none" aria-hidden="true">Save</button>
    </form>

</div>{{-- /.ProfilePage --}}
@endsection
